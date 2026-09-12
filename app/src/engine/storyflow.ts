import type { SpatiState, StoryState } from './types';
import { STRANDS, STRAND_BY_ID } from './content/story';
import { VIGNETTES, VIGNETTE_BY_ID } from './content/vignettes';

const clamp = (v: number) => Math.max(0, Math.min(100, Math.round(v * 10) / 10));

// Deterministic 32-bit hash (so vignette selection is pure — keyed on seed+day, never touches rngState).
function hash2(a: number, b: number): number {
  let h = (a ^ 0x9e3779b9) >>> 0;
  h = Math.imul(h ^ ((b + 0x6d2b79f5) >>> 0), 2654435761) >>> 0;
  h ^= h >>> 15;
  return h >>> 0;
}

const VIGNETTE_CHANCE = 60; // % of quiet (no cast beat) mornings that surface a vignette

export function seedStory(): StoryState {
  const strands: StoryState['strands'] = {};
  for (const st of STRANDS) strands[st.id] = { cur: st.start, outcome: null, lastDay: -1 };
  return { flags: [], met: [], strands, mainOutcome: null, pending: null, seenVignettes: [], pendingVignette: null };
}

/** Set the day's morning beat: a cast strand beat if any is due (priority order), else — on a quiet day — a
 *  one-off vignette. ≤1 of either per day. Pure mutation; vignette pick is seed+day deterministic. */
export function fireEligible(s: SpatiState): void {
  if (s.story.pending || s.story.pendingVignette) return;
  const order = [...STRANDS].sort((a, b) => (b.priority ?? 0) - (a.priority ?? 0));
  for (const st of order) {
    const p = s.story.strands[st.id];
    if (!p || p.cur == null || p.lastDay === s.day) continue;
    const beat = st.beats[p.cur];
    if (!beat) continue;
    if (beat.afterDay && s.day < beat.afterDay) continue;
    if (beat.minKiez && s.reputation.kiez < beat.minKiez) continue;
    if (beat.requiresFlag && !s.story.flags.includes(beat.requiresFlag)) continue;
    s.story.pending = { strand: st.id };
    return;
  }
  fireVignette(s); // no cast beat today → maybe a stranger
}

/** On a quiet morning, deterministically surface an unseen, eligible vignette (or nothing). */
function fireVignette(s: SpatiState): void {
  if (s.story.pending || s.story.pendingVignette) return;
  if (hash2(s.config.seed, s.day) % 100 >= VIGNETTE_CHANCE) return;
  const eligible = VIGNETTES.filter((v) => {
    if (s.story.seenVignettes.includes(v.id)) return false;
    if (v.afterDay && s.day < v.afterDay) return false;
    if (v.minKiez && s.reputation.kiez < v.minKiez) return false;
    if (v.requiresFlag && !s.story.flags.includes(v.requiresFlag)) return false;
    if (v.weekday != null && s.weekday !== v.weekday) return false;
    return true;
  });
  if (eligible.length === 0) return;
  const pick = eligible[hash2(s.config.seed ^ 0x85ebca6b, s.day) % eligible.length];
  s.story.pendingVignette = pick.id;
}

/** Resolve the pending vignette with the chosen option. Pure mutation. */
export function applyVignetteChoice(s: SpatiState, choiceIndex: number): void {
  const id = s.story.pendingVignette;
  if (!id) return;
  const v = VIGNETTE_BY_ID[id];
  const choice = v ? (v.choices[choiceIndex] ?? v.choices[0]) : undefined;
  if (choice) {
    if (choice.cash) s.cash = Math.round((s.cash + choice.cash) * 100) / 100;
    if (choice.kiez) s.reputation.kiez = clamp(s.reputation.kiez + choice.kiez);
    if (choice.profit) s.reputation.profit = clamp(s.reputation.profit + choice.profit);
    if (choice.integrity) s.reputation.integrity = clamp(s.reputation.integrity + choice.integrity);
    for (const f of choice.flags ?? []) if (!s.story.flags.includes(f)) s.story.flags.push(f);
  }
  if (!s.story.seenVignettes.includes(id)) s.story.seenVignettes.push(id);
  s.story.pendingVignette = null;
}

/** Resolve the pending beat with the chosen option. Pure mutation. */
export function applyBeatChoice(s: SpatiState, choiceIndex: number): void {
  const pend = s.story.pending;
  if (!pend) return;
  const st = STRAND_BY_ID[pend.strand];
  const p = st ? s.story.strands[pend.strand] : undefined;
  if (!st || !p || p.cur == null) { s.story.pending = null; return; }
  const beat = st.beats[p.cur];
  const choice = beat?.choices[choiceIndex] ?? beat?.choices[0];
  if (!choice) { s.story.pending = null; return; }

  if (choice.cash) s.cash = Math.round((s.cash + choice.cash) * 100) / 100;
  if (choice.kiez) s.reputation.kiez = clamp(s.reputation.kiez + choice.kiez);
  if (choice.profit) s.reputation.profit = clamp(s.reputation.profit + choice.profit);
  if (choice.integrity) s.reputation.integrity = clamp(s.reputation.integrity + choice.integrity);
  for (const f of choice.flags ?? []) if (!s.story.flags.includes(f)) s.story.flags.push(f);
  if (choice.outcome) {
    p.outcome = choice.outcome;
    if (st.id === 'main') s.story.mainOutcome = choice.outcome;
  }
  if (!s.story.met.includes(st.character)) s.story.met.push(st.character);
  p.lastDay = s.day;
  p.cur = choice.next ?? null;
  s.story.pending = null;
}
