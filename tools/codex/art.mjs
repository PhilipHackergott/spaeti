#!/usr/bin/env node
// tools/codex/art.mjs — generate ONE asset with Codex's built-in image_gen, then snap it to the pixel grid.
//
//   node tools/codex/art.mjs --id char/lena_neutral [--spec docs/asset-spec.json] [--feedback "..."]
//        [--retries 1] [--effort max] [--variant v2] [--no-snap]
//
// Flow: style brief + asset prompt + reference images → Codex generates → raw PNG lands in art/raw/<id>.png
// (native gpt-image size, git-ignored) → godot/tools/img.gd snaps it to the base grid → godot/assets/<id>.png.
// Prints ONE json line: {id, ok, raw, out, width, height, hasAlpha, seconds, tokens, attempts, error?}. Exit 0 on ok.
import fs from 'node:fs';
import path from 'node:path';
import { REPO, RAW_ART_DIR, CODEX_GENERATED, CODEX_MODEL_HERO, CODEX_MODEL_SMALL, parseArgs, pngInfo, fwd } from '../paths.mjs';
import { runCodex } from './run.mjs';
import { snapImage } from '../godot/img.mjs';

const a = parseArgs(process.argv.slice(2));
if (!a.id) { console.error('need --id <asset id from docs/asset-spec.json>'); process.exit(2); }
const spec = JSON.parse(fs.readFileSync(path.resolve(REPO, a.spec || 'docs/asset-spec.json'), 'utf8'));
const entry = spec.assets.find((e) => e.id === a.id);
if (!entry) { console.error(`unknown asset id ${a.id}`); process.exit(2); }
const brief = fs.readFileSync(path.resolve(REPO, spec.styleBrief || 'docs/art-style-brief.md'), 'utf8');
const suffix = a.variant ? `-${a.variant}` : '';
const raw = path.join(RAW_ART_DIR, `${entry.id}${suffix}.png`);
// `concept` assets are target paintings, not game sprites: kept at native size under concept-art/generated/.
const isConcept = entry.kind === 'concept';
const out = isConcept
  ? path.join(REPO, 'concept-art', 'generated', `${path.basename(entry.id)}${suffix}.png`)
  : path.join(REPO, 'godot', 'assets', `${entry.id}${suffix}.png`);
// Model tier: per-asset override → per-kind table in the spec → hero (astra) for scenes/portraits/concepts, small (sol) otherwise.
const model = a.model || entry.model || (spec.modelByKind && spec.modelByKind[entry.kind])
  || (['prop', 'icon', 'texture'].includes(entry.kind) ? CODEX_MODEL_SMALL : CODEX_MODEL_HERO);
fs.mkdirSync(path.dirname(raw), { recursive: true });
fs.mkdirSync(path.dirname(out), { recursive: true });
// References: the entry's own (or the spec defaults) + every photo in the user's reference drop folder for scene/concept
// work. Missing files are skipped with a warning — a stale path must never abort a 10-minute generation.
const dropDir = spec.referenceDir ? path.join(REPO, spec.referenceDir) : '';
const dropRefs = dropDir && fs.existsSync(dropDir) && ['scene', 'concept'].includes(entry.kind)
  ? fs.readdirSync(dropDir).filter((f) => /\.(png|jpe?g)$/i.test(f)).slice(0, 6).map((f) => path.join(spec.referenceDir, f)) : [];
const refs = [...((entry.refs && entry.refs.length ? entry.refs : spec.defaultRefs) || []), ...dropRefs]
  .filter((r) => { const ok = fs.existsSync(path.resolve(REPO, r)); if (!ok) console.error(`art: skipping missing reference ${r}`); return ok; });
const retries = Number(a.retries ?? 1);
const kindNotes = (spec.kinds && spec.kinds[entry.kind]) || '';
// Chroma key used as the transparency fallback (flat backdrop the model paints when it does not use real alpha).
const keyColour = String(entry.key || spec.defaultKey || '00ff00').replace('#', '');

function buildPrompt(feedback) {
  return `You are producing ONE production art asset for a game with your built-in image_gen tool.
Use the built-in tool (not any CLI fallback). Do not ask questions. Do not produce alternatives — one image.

=== STYLE BRIEF (applies to every asset) ===
${brief}

=== THIS ASSET: ${entry.id} (${entry.kind}) ===
${entry.prompt}
${kindNotes ? `\nKIND NOTES: ${kindNotes}` : ''}
${refs.length ? `\nThe attached image(s) are STYLE/CONTENT REFERENCES (image 1 = the canonical "target state").` : ''}

=== HARD REQUIREMENTS ===
- Generate at ${entry.gen || 'the largest size the tool supports for this aspect'} (${entry.aspect || 'square'}). We downscale to the pixel grid ourselves, so DO NOT resize, DO NOT post-process, DO NOT add any margin.
- ${entry.transparent ? `TRANSPARENT background: call image_gen with its transparent-background option so the PNG has a REAL alpha channel. NEVER paint a checkerboard, grey or white "transparency" pattern — that is a hard failure. If the tool cannot produce alpha, render the background as ONE flat, solid, un-shaded #${keyColour} fill (we key that exact colour out) and keep every edge pixel hard (no anti-aliasing against the background). Nothing but the subject — no floor shadow blob, no backdrop, no frame.` : 'Full-bleed opaque image that fills the whole canvas edge to edge.'}
- ${entry.allowText ? `The ONLY text allowed, spelled exactly: ${entry.allowText}` : 'NO text, letters, numbers, logos or watermarks anywhere.'}
- No borders, frames, mockup chrome, UI overlays, "sprite sheet" grids or multiple views — unless the asset text above explicitly asks for a sheet.
- Copy the generated file (unchanged) to exactly this path, creating folders as needed: ${fwd(raw)}
- Finish by replying with exactly one line: SAVED ${fwd(raw)}  — or FAILED <reason>.
${feedback ? `\n=== FEEDBACK FROM THE PREVIOUS ATTEMPT (fix these) ===\n${feedback}\n` : ''}`;
}

// Only ever look inside THIS run's session folder: with several lanes generating at once, "newest PNG anywhere"
// happily adopts another lane's image (it did — a counter strip became "Lena").
function newestGenerated(since, sessionId) {
  if (!sessionId) return null;
  const d = path.join(CODEX_GENERATED, sessionId);
  if (!fs.existsSync(d)) return null;
  let best = null;
  for (const f of fs.readdirSync(d)) {
    if (!f.toLowerCase().endsWith('.png')) continue;
    const p = path.join(d, f);
    const st = fs.statSync(p);
    if (st.mtimeMs >= since && (!best || st.mtimeMs > best.mtimeMs)) best = { p, mtimeMs: st.mtimeMs };
  }
  return best ? best.p : null;
}
// Rejected attempts are kept beside the canonical raw so the evidence (and a possibly-salvageable image) survives.
function shelveRaw(rawPath, attempt) {
  if (!fs.existsSync(rawPath)) return null;
  const shelved = rawPath.replace(/\.png$/i, `-att${attempt}.png`);
  fs.renameSync(rawPath, shelved);
  return fwd(shelved);
}

const started = Date.now();
let feedback = a.feedback || '';
let attempts = 0;
let result = { id: entry.id, ok: false, errors: [] };
let totalTokens = 0;
// --reuse-raw: skip generation when art/raw/<id>.png already exists (re-snap after a spec/grid change).
const reuse = !!a['reuse-raw'] && fs.existsSync(raw);
while (attempts <= retries) {
  attempts++;
  let r = { last: '', tokens: '', sessionId: '' };
  if (!reuse || attempts > 1) {
    if (fs.existsSync(raw)) shelveRaw(raw, attempts - 1);
    const t0 = Date.now();
    r = await runCodex({ prompt: buildPrompt(feedback), images: refs, sandbox: 'danger-full-access', cwd: REPO,
      model, effort: a.effort, timeout: a.timeout ? Number(a.timeout) : 900, quiet: true });
    totalTokens += Number(String(r.tokens).replace(/[.,]/g, '')) || 0;
    if (r.blocked) {
      // Spend cap / auth / rate limit: retrying cannot help — report the real reason and stop.
      result.error = `BLOCKED (${r.blocked}): ${r.blockLine}`;
      result.errors.push(result.error);
      result.blocked = r.blocked;
      break;
    }
    if (!fs.existsSync(raw)) {
      // Codex sometimes leaves the file only under ~/.codex/generated_images/<this session> — take the newest one from there.
      const fallback = newestGenerated(t0 - 1000, r.sessionId);
      if (fallback) fs.copyFileSync(fallback, raw);
    }
  }
  if (!fs.existsSync(raw)) {
    feedback = `No image file was written (codex said: ${r.last.slice(0, 300) || '(nothing)'}). Generate the image and copy it to the exact path.`;
    result.error = feedback;
    result.errors.push(`attempt ${attempts}: ${feedback}`);
    continue;
  }
  const rawInfo = pngInfo(raw);
  if (a['no-snap'] || isConcept) {
    if (isConcept) fs.copyFileSync(raw, out);
    result = { ...result, ok: true, raw: fwd(raw), out: isConcept ? fwd(out) : undefined, ...rawInfo, attempts, model };
    break;
  }
  // Nearest is the default for everything but full-frame scene layers: at a 5–6× downscale Lanczos invents exactly
  // the intermediate tones the judge calls "painterly" (measured: +3 to +15 points on five busts, zero Codex calls).
  const filter = entry.filter || (entry.kind === 'scene' ? 'lanczos' : 'nearest');
  const snapOpts = (keyTol) => ({ in: raw, out, w: entry.w, h: entry.h, mode: entry.mode || (entry.transparent ? 'fit' : 'cover'),
    filter, crop: entry.crop, 'alpha-threshold': entry.transparent ? (entry.alphaThreshold ?? 0.5) : undefined,
    trim: entry.transparent && entry.trim !== false ? 1 : undefined,
    key: entry.transparent ? keyColour : undefined, 'key-tol': entry.transparent ? keyTol : undefined, 'auto-key': entry.transparent ? 1 : undefined,
    'auto-bg': entry.transparent ? 1 : undefined, 'bg-tol': entry.transparent ? (entry.bgTol ?? 0.16) : undefined,
    anchor: entry.anchor, 'alpha-orphans': entry.transparent ? 1 : undefined });
  let snap = snapImage(snapOpts(entry.keyTol ?? 0.18));
  // Green fringe after keying is common (35–43 edge pixels seen); widen the key tolerance once and take the cleaner result.
  if (entry.transparent && snap.fringe > 20) {
    const wider = snapImage(snapOpts(0.45));
    if (wider.fringe < snap.fringe) snap = { ...wider, fringeBefore: snap.fringe };
  }
  // Transparency trap: a painted checkerboard whose white squares connect through the subject's whites lets the
  // border flood-fill erase half a face while still "passing" the 2% rule. A bust or prop is mostly opaque
  // inside its trimmed box — reject when it is not.
  const maxTransparent = entry.kind === 'portrait' ? 0.55 : entry.kind === 'prop' ? 0.75 : 1.0;
  if (entry.transparent && snap.transparentFrac > maxTransparent) {
    feedback = `The snapped sprite is ${Math.round(snap.transparentFrac * 100)}% transparent — the background removal ate into the subject (a painted checkerboard or a backdrop that touches the subject's light areas). Use image_gen's real alpha, or a flat solid #${keyColour} background that NO part of the subject shares.`;
    result.error = feedback;
    result.errors.push(`attempt ${attempts}: ${feedback} (kept as ${shelveRaw(raw, attempts)})`);
    if (fs.existsSync(out)) fs.unlinkSync(out);
    continue;
  }
  // Transparency is judged on real pixels after Godot decoded (and possibly keyed) the file — not on the PNG header.
  if (entry.transparent && snap.transparentFrac < 0.02) {
    feedback = `The background was NOT transparent (under 2% transparent pixels after decoding, and neither the flat #${keyColour} key colour nor a flat/checker backdrop the border flood-fill could remove). Use image_gen's transparent-background option, or a single flat solid #${keyColour} background that no part of the subject touches.`;
    result.error = feedback;
    result.errors.push(`attempt ${attempts}: ${feedback} (kept as ${shelveRaw(raw, attempts)})`);
    if (fs.existsSync(out)) fs.unlinkSync(out);
    continue;
  }
  result = { id: entry.id, ok: true, raw: fwd(raw), out: fwd(out), rawSize: `${rawInfo.width}x${rawInfo.height}`,
    width: snap.width, height: snap.height, transparentFrac: snap.transparentFrac, keyedPixels: snap.keyedPixels,
    fringe: snap.fringe, fringeBefore: snap.fringeBefore, filter, attempts, model };
  break;
}
result.seconds = Math.round((Date.now() - started) / 1000);
result.tokens = totalTokens;
console.log(JSON.stringify(result));
process.exit(result.ok ? 0 : (result.blocked ? 75 : 1));
