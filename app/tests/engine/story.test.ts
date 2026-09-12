import { describe, it, expect } from 'vitest';
import { createState, defaultConfig, reduce, resolveFinale, type SpatiState } from '../../src/engine';

// Walk the story calendar (skipping the economy night), resolving each morning beat with `choice`.
function walkStory(seed: number, choice: (strand: string, beatDay: number) => number): SpatiState {
  let s = createState(defaultConfig('cozy', seed));
  let guard = 0;
  while (s.phase !== 'end' && guard++ < 300) {
    while (s.story.pending) s = reduce(s, { type: 'resolveBeat', choice: choice(s.story.pending.strand, s.day) });
    s = reduce({ ...s, phase: 'summary' }, { type: 'advanceDay' });
  }
  while (s.story.pending) s = reduce(s, { type: 'resolveBeat', choice: choice(s.story.pending.strand, s.day) });
  return s;
}

describe('narrative (Truby strands + main arc + tapestry)', () => {
  it('the main arc fires day-1 and the cast strands play to branching outcomes', () => {
    const s0 = createState(defaultConfig('cozy', 1));
    expect(s0.story.pending).toEqual({ strand: 'main' }); // Cem's keys, morning of day 1

    const s = walkStory(1, () => 0); // always the first choice (incl. climax → 'sell')
    expect(s.phase).toBe('end');
    expect(s.story.mainOutcome).toBe('sell');
    expect(s.story.strands.lena.outcome).toBe('found_voice');
    expect(s.story.strands.juergen.outcome).toBe('seen');
    expect(s.story.strands.mehmet.outcome).toBe('reconciled');
    expect(s.story.met).toEqual(expect.arrayContaining(['Onkel Cem', 'Lena', '"Bottle" Jürgen', 'Mehmet']));
  });

  it('the finale weaves the main ending with an epilogue per met character', () => {
    const s = walkStory(1, () => 0); // climax choice 0 = sell → soldout
    const f = resolveFinale(s);
    expect(f.ending).toBe('soldout');
    // the load-bearing core cast always resolves (higher priority than the texture strands)
    const names = f.epilogues.map((e) => e.character);
    for (const who of ['Lena', '"Bottle" Jürgen', 'Mehmet', 'Yusuf', 'Frau Schmidt']) expect(names).toContain(who);
    // a rich tapestry: many of the ~12 side strands resolve in a full playthrough, each with a real line
    expect(f.epilogues.length).toBeGreaterThanOrEqual(8);
    for (const e of f.epilogues) expect(e.line.length).toBeGreaterThan(0);
  });

  it('choosing "stand" at the climax reaches a different ending', () => {
    // pick the SECOND option everywhere there is one (climax → 'stand')
    const s = walkStory(1, () => 1);
    expect(s.story.mainOutcome).toBe('stand');
    const f = resolveFinale(s);
    expect(['institution', 'held']).toContain(f.ending); // not soldout
  });

  it('one-off vignettes surface on quiet mornings, resolve once, and never repeat', () => {
    // A packed cast can legitimately leave no quiet mornings; vignettes are the texture that fills
    // lighter runs (and the late season after the cast arcs close). Retire the cast to isolate the
    // vignette channel and exercise it on guaranteed-quiet mornings.
    let s = createState(defaultConfig('cozy', 5));
    for (const id of Object.keys(s.story.strands)) s.story.strands[id].cur = null;
    s.story.pending = null;
    const seen = new Set<string>();
    let guard = 0;
    while (s.phase !== 'end' && guard++ < 60) {
      if (s.story.pendingVignette) {
        expect(seen.has(s.story.pendingVignette)).toBe(false); // never repeats within a run
        seen.add(s.story.pendingVignette);
        s = reduce(s, { type: 'resolveVignette', choice: 0 });
      }
      s = reduce({ ...s, phase: 'summary' }, { type: 'advanceDay' });
    }
    expect(seen.size).toBeGreaterThan(0); // the parade of strangers shows up on quiet mornings
  });

  it('a pending vignette never blocks the next morning\'s cast beat', () => {
    // Walk WITHOUT ever answering vignettes; the cast strands must still all reach their outcomes.
    let s = createState(defaultConfig('cozy', 1));
    let guard = 0;
    while (s.phase !== 'end' && guard++ < 300) {
      while (s.story.pending) s = reduce(s, { type: 'resolveBeat', choice: 0 });
      s = reduce({ ...s, phase: 'summary' }, { type: 'advanceDay' }); // leaves any vignette unanswered
    }
    expect(s.story.mainOutcome).toBe('sell');
    expect(s.story.strands.yusuf.outcome).toBe('mentored');
    expect(s.story.strands.schmidt.outcome).toBe('watched_over');
    expect(s.story.pendingVignette).toBeNull(); // cleared at end, no overlay over the finale
  });
});
