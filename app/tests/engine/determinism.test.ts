import { describe, it, expect } from 'vitest';
import { createState, defaultConfig } from '../../src/engine';
import { playSeason } from '../../src/sim/autoPlayer';

describe('determinism', () => {
  it('same {config, seed} → byte-identical season outcome', () => {
    const cfg = defaultConfig('normal', 0xc0ffee);
    const a = playSeason(createState(cfg));
    const b = playSeason(createState(cfg));
    expect(JSON.stringify(a.final)).toBe(JSON.stringify(b.final));
    expect(a.endCash).toBe(b.endCash);
    expect(a.final.rngState).toBe(b.final.rngState);
  });

  it('different seeds → different outcomes (the RNG actually varies)', () => {
    const a = playSeason(createState(defaultConfig('normal', 1)));
    const b = playSeason(createState(defaultConfig('normal', 2)));
    expect(a.final.rngState).not.toBe(b.final.rngState);
  });
});
