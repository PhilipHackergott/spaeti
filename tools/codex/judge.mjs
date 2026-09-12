#!/usr/bin/env node
// tools/codex/judge.mjs — Codex as art director: score a candidate image against the concept art.
//
//   node tools/codex/judge.mjs --candidate shots/night.png [--reference img ...] [--context "what this is"]
//        [--rubric docs/judge-rubric.md] [--out judge/night.json] [--threshold 80] [--effort max]
//
// Writes a strict JSON verdict (tools/codex/verdict.schema.json). Exit 0 if overall >= threshold else 1.
// Default references = the four concept-art images (protagonist target state + three Coffee Talk frames).
import fs from 'node:fs';
import path from 'node:path';
import { REPO, CODEX_MODEL_HERO, parseArgs, asList } from '../paths.mjs';
import { runCodex } from './run.mjs';

const a = parseArgs(process.argv.slice(2));
if (!a.candidate) { console.error('need --candidate image'); process.exit(2); }
if (!fs.existsSync(path.resolve(REPO, String(a.candidate)))) {
  // A missing candidate must never reach the judge: Codex then scores "nothing" with zero placeholders.
  console.error(`judge: candidate not found: ${a.candidate}`);
  process.exit(2);
}
// The generated Berlin-Späti interaction concept (astra) becomes reference 2 as soon as it exists; the user's OG
// interaction image stays reference 1 — the judge is told which is which.
// Prefer the grid-snapped 16:9 ×4 version (the concept at the game's real density and framing) when it exists.
const GENERATED_CONCEPT = fs.existsSync(path.resolve(REPO, 'concept-art/generated/night_interaction-grid.png'))
  ? 'concept-art/generated/night_interaction-grid.png' : 'concept-art/generated/night_interaction.png';
export const DEFAULT_REFS = [
  'concept-art/main character target state.png',
  ...(fs.existsSync(path.resolve(REPO, GENERATED_CONCEPT)) ? [GENERATED_CONCEPT] : []),
  'concept-art/coffee talk references/{AE54C7E9-D717-4471-98C0-FA7E2F50E019}.png',
  'concept-art/coffee talk references/{4CDFA375-6F38-4B90-AEF3-ECDFC2454419}.png',
  'concept-art/coffee talk references/{351D15A9-2F56-4AAC-9DEE-F76504500AB7}.png',
];
const refs = asList(a.reference).length ? asList(a.reference) : DEFAULT_REFS;
const hasConcept = refs.includes(GENERATED_CONCEPT);
const rubric = fs.readFileSync(path.resolve(REPO, a.rubric || 'docs/judge-rubric.md'), 'utf8');
const threshold = Number(a.threshold || 80);
const context = a.context || 'A screenshot of the game as rendered by Godot.';
const outFile = a.out || `judge/${path.basename(String(a.candidate), '.png')}.json`;

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

const r = await runCodex({ prompt, images: [a.candidate, ...refs], schema: 'tools/codex/verdict.schema.json',
  sandbox: 'read-only', model: a.model || CODEX_MODEL_HERO, effort: a.effort, timeout: a.timeout ? Number(a.timeout) : 1500, quiet: true });  // composed 1080p frames at max effort took >600 s under load
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
verdict._meta = { candidate: a.candidate, references: refs, context, threshold, model: a.model || CODEX_MODEL_HERO, seconds: r.seconds, tokens: r.tokens };
fs.mkdirSync(path.dirname(path.resolve(REPO, outFile)), { recursive: true });
fs.writeFileSync(path.resolve(REPO, outFile), JSON.stringify(verdict, null, 2));
console.log(JSON.stringify({ overall: verdict.overall, verdict: verdict.verdict, axes: verdict.axes,
  top_fixes: verdict.fixes.slice(0, 3).map((f) => f.what), out: outFile, seconds: r.seconds }, null, 2));
process.exit(verdict.overall >= threshold ? 0 : 1);
