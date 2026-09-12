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
import { REPO, RAW_ART_DIR, CODEX_GENERATED, parseArgs, pngInfo, fwd } from '../paths.mjs';
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
const out = path.join(REPO, 'godot', 'assets', `${entry.id}${suffix}.png`);
fs.mkdirSync(path.dirname(raw), { recursive: true });
fs.mkdirSync(path.dirname(out), { recursive: true });
const refs = (entry.refs && entry.refs.length ? entry.refs : spec.defaultRefs) || [];
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

function newestGenerated(since) {
  if (!fs.existsSync(CODEX_GENERATED)) return null;
  let best = null;
  for (const dir of fs.readdirSync(CODEX_GENERATED)) {
    const d = path.join(CODEX_GENERATED, dir);
    if (!fs.statSync(d).isDirectory()) continue;
    for (const f of fs.readdirSync(d)) {
      if (!f.toLowerCase().endsWith('.png')) continue;
      const p = path.join(d, f);
      const st = fs.statSync(p);
      if (st.mtimeMs >= since && (!best || st.mtimeMs > best.mtimeMs)) best = { p, mtimeMs: st.mtimeMs };
    }
  }
  return best ? best.p : null;
}

const started = Date.now();
let feedback = a.feedback || '';
let attempts = 0;
let result = { id: entry.id, ok: false };
let totalTokens = 0;
// --reuse-raw: skip generation when art/raw/<id>.png already exists (re-snap after a spec/grid change).
const reuse = !!a['reuse-raw'] && fs.existsSync(raw);
while (attempts <= retries) {
  attempts++;
  let r = { last: '', tokens: '' };
  if (!reuse || attempts > 1) {
    if (fs.existsSync(raw)) fs.unlinkSync(raw);
    const t0 = Date.now();
    r = await runCodex({ prompt: buildPrompt(feedback), images: refs, sandbox: 'danger-full-access', cwd: REPO,
      effort: a.effort, timeout: a.timeout ? Number(a.timeout) : 600, quiet: true });
    totalTokens += Number(String(r.tokens).replace(/[.,]/g, '')) || 0;
    if (!fs.existsSync(raw)) {
      // Codex sometimes leaves the file only under ~/.codex/generated_images — take the newest one from this run.
      const fallback = newestGenerated(t0 - 1000);
      if (fallback) fs.copyFileSync(fallback, raw);
    }
  }
  if (!fs.existsSync(raw)) {
    feedback = `No image file was written (codex said: ${r.last.slice(0, 300) || '(nothing)'}). Generate the image and copy it to the exact path.`;
    result.error = feedback;
    continue;
  }
  const rawInfo = pngInfo(raw);
  if (a['no-snap']) {
    result = { ...result, ok: true, raw: fwd(raw), ...rawInfo, attempts };
    break;
  }
  const snap = snapImage({ in: raw, out, w: entry.w, h: entry.h, mode: entry.mode || (entry.transparent ? 'fit' : 'cover'),
    filter: entry.filter || 'lanczos', crop: entry.crop, 'alpha-threshold': entry.transparent ? (entry.alphaThreshold ?? 0.5) : undefined,
    trim: entry.transparent && entry.trim !== false ? 1 : undefined,
    key: entry.transparent ? keyColour : undefined, 'key-tol': entry.transparent ? (entry.keyTol ?? 0.18) : undefined, 'auto-key': entry.transparent ? 1 : undefined });
  // Transparency is judged on real pixels after Godot decoded (and possibly keyed) the file — not on the PNG header.
  if (entry.transparent && snap.transparentFrac < 0.02) {
    feedback = `The background was NOT transparent (under 2% transparent pixels after decoding, and it was not the flat #${keyColour} key colour either). Use image_gen's transparent-background option, or a single flat solid #${keyColour} background. Never a checkerboard.`;
    result.error = feedback;
    continue;
  }
  result = { id: entry.id, ok: true, raw: fwd(raw), out: fwd(out), rawSize: `${rawInfo.width}x${rawInfo.height}`,
    width: snap.width, height: snap.height, transparentFrac: snap.transparentFrac, keyedPixels: snap.keyedPixels, attempts };
  break;
}
result.seconds = Math.round((Date.now() - started) / 1000);
result.tokens = totalTokens;
console.log(JSON.stringify(result));
process.exit(result.ok ? 0 : 1);
