#!/usr/bin/env node
// tools/codex/judge.mjs — Codex as art director: score a candidate image against the concept art.
//
//   node tools/codex/judge.mjs --candidate shots/night.png [--reference img ...] [--context "what this is"]
//        [--rubric docs/judge-rubric.md] [--out judge/night.json] [--threshold 80] [--effort high] [--full] [--refs=full]
//
// Writes a strict JSON verdict (tools/codex/verdict.schema.json). Exit 0 if overall >= threshold else 1.
//
// LEAN BY DEFAULT (2026-09-13): three 1080p judges in a row timed out at 1500 s; the same frame at half size with
// three references and effort `high` came back in 45 s with a full verdict. So a candidate >= 1920 px wide is
// judged from a LOSSLESS half-size copy (the game is 480x270 game pixels at x4 — every 2x2 block of the x2 copy is
// one game pixel; nearest sampling at exactly 1/2 loses nothing), the generated concept is attached at x2 too, and
// only ONE Coffee Talk frame rides along. `--full` judges the file as given; `--refs=full` attaches all three frames.
import fs from 'node:fs';
import path from 'node:path';
import { REPO, CODEX_MODEL_HERO, parseArgs, asList, pngInfo } from '../paths.mjs';
import { runCodex } from './run.mjs';
import { snapImage } from '../godot/img.mjs';

const a = parseArgs(process.argv.slice(2));
if (!a.candidate) { console.error('need --candidate image'); process.exit(2); }
const candidateAbs = path.resolve(REPO, String(a.candidate));
if (!fs.existsSync(candidateAbs)) {
  // A missing candidate must never reach the judge: Codex then scores "nothing" with zero placeholders.
  console.error(`judge: candidate not found: ${a.candidate}`);
  process.exit(2);
}
const exists = (rel) => fs.existsSync(path.resolve(REPO, rel));
// The generated Berlin-Späti interaction concept (astra) is reference 2 as soon as it exists; the user's OG
// interaction image stays reference 1 — the judge is told which is which. Prefer the grid-snapped 16:9 version
// (the concept at the game's real density and framing), at x2 when that copy exists (see LEAN above).
const GENERATED_CONCEPT = ['concept-art/generated/night_interaction-grid-x2.png', 'concept-art/generated/night_interaction-grid.png',
  'concept-art/generated/night_interaction.png'].find(exists);
const COFFEE_TALK = [
  'concept-art/coffee talk references/{AE54C7E9-D717-4471-98C0-FA7E2F50E019}.png',
  'concept-art/coffee talk references/{4CDFA375-6F38-4B90-AEF3-ECDFC2454419}.png',
  'concept-art/coffee talk references/{351D15A9-2F56-4AAC-9DEE-F76504500AB7}.png',
];
export const DEFAULT_REFS = [
  'concept-art/main character target state.png',
  ...(GENERATED_CONCEPT ? [GENERATED_CONCEPT] : []),
  ...(a.refs === 'full' ? COFFEE_TALK : COFFEE_TALK.slice(0, 1)),
];
const refs = asList(a.reference).length ? asList(a.reference) : DEFAULT_REFS;
const hasConcept = refs.some((r) => r.includes('night_interaction'));
const rubric = fs.readFileSync(path.resolve(REPO, a.rubric || 'docs/judge-rubric.md'), 'utf8');
const threshold = Number(a.threshold || 80);
let context = a.context || 'A screenshot of the game as rendered by Godot.';
const outFile = a.out || `judge/${path.basename(String(a.candidate), '.png')}.json`;
const effort = a.effort || 'high';   // `max` on a composed frame never returned inside 25 min on this account

// Lean candidate: lossless half of a x4 frame.
let candidate = String(a.candidate);
let lean = false;
const info = pngInfo(candidateAbs);
if (!a.full && info.width >= 1920 && info.width % 2 === 0 && info.height % 2 === 0) {
  const half = `judge/tmp/${path.basename(candidate, '.png')}-x2.png`;
  snapImage({ in: candidate, out: half, w: info.width / 2, h: info.height / 2, mode: 'exact', filter: 'nearest' });
  candidate = half;
  lean = true;
  context += ` NOTE ON SCALE: the candidate is shown at half size (${info.width / 2}x${info.height / 2}). The game renders 480x270 game pixels at x4 = 1080p; this copy is the lossless x2 of that frame, so every 2x2 block is ONE game pixel. Judge pixel discipline on the 480x270 grid — crisp 2x2 blocks are not a defect.${hasConcept && GENERATED_CONCEPT?.includes('-x2') ? ' The generated concept (image 3) is at the same x2 scale.' : ''}`;
}

const prompt = `You are the art director for "Späti", a 2D HD pixel-art game whose locked visual target is
"a Berlin Späti (late-night kiosk) version of Coffee Talk". You judge how close a CANDIDATE image is to
that target and give concrete, actionable fixes. Be strict and specific — a vague "improve shading" is useless;
"the counter top is a flat brown fill; the reference has 4-5 tone wood grain with a warm highlight band
along the front edge" is useful.

IMAGE ORDER: image 1 is the CANDIDATE. Images 2..${refs.length + 1} are REFERENCES (image 2 = the protagonist
"target state" — the canonical style + character;${hasConcept ? ' image 3 = the generated Berlin-Späti interaction concept — the canonical composed target for the Night screen (set dressing, framing, palette);' : ''} the rest = Coffee Talk frames for framing, UI and palette).

CANDIDATE CONTEXT: ${context}

RUBRIC:
${rubric}

Score every axis 0-100 (use -1 only for an axis that genuinely does not apply to this candidate, e.g.
character_fidelity for a bottle sprite). "overall" is your holistic call, not an average. verdict: pass (>= ${threshold},
ship it), revise (fixable — list the fixes in priority order), reject (wrong medium/style, start over).
List up to 8 fixes, most impactful first, each with what/where/how. Reply ONLY with the JSON object.`;

const r = await runCodex({ prompt, images: [candidate, ...refs], schema: 'tools/codex/verdict.schema.json',
  sandbox: 'read-only', model: a.model || CODEX_MODEL_HERO, effort, timeout: a.timeout ? Number(a.timeout) : 900, quiet: true });
let verdict = null;
try { verdict = JSON.parse(r.last); } catch { /* handled below */ }
if (r.blocked) {
  console.error(`judge: BLOCKED (${r.blocked}): ${r.blockLine}`);
  process.exit(75);
}
if (!verdict) {
  console.error(`judge: no JSON verdict (exit ${r.code}, ${r.seconds}s)\n${r.log.slice(-1500)}`);
  process.exit(3);
}
verdict._meta = { candidate: a.candidate, judged: candidate, lean, references: refs, context, threshold,
  model: a.model || CODEX_MODEL_HERO, effort, seconds: r.seconds, tokens: r.tokens };
fs.mkdirSync(path.dirname(path.resolve(REPO, outFile)), { recursive: true });
fs.writeFileSync(path.resolve(REPO, outFile), JSON.stringify(verdict, null, 2));
console.log(JSON.stringify({ overall: verdict.overall, verdict: verdict.verdict, axes: verdict.axes,
  top_fixes: verdict.fixes.slice(0, 3).map((f) => f.what), out: outFile, seconds: r.seconds, lean }, null, 2));
process.exit(verdict.overall >= threshold ? 0 : 1);
