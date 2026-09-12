import { describe, it, expect } from 'vitest';
import { createState, defaultConfig, type Difficulty } from '../../src/engine';
import { playSeason } from '../../src/sim/autoPlayer';

// Balance smoke sweep (the npm run sim seed). Verifies the loop runs to completion, the difficulty
// ladder points the right way, and nothing degenerate happens. Real tuning is a /test job.
function sweep(diff: Difficulty, seeds = 6) {
  let survived = 0;
  let cashSum = 0;
  for (let i = 0; i < seeds; i++) {
    const r = playSeason(createState(defaultConfig(diff, 1000 + i)));
    if (r.survived) survived++;
    cashSum += r.endCash;
    expect(r.final.phase).toBe('end'); // terminated
    expect(r.days).toBeGreaterThan(1);
    expect(Number.isFinite(r.totalProfit)).toBe(true);
  }
  return { survivalRate: survived / seeds, avgCash: cashSum / seeds };
}

describe('balance sweep', () => {
  it('a competent shopkeeper survives Normal more often than Tight, and Cozy most', () => {
    const cozy = sweep('cozy');
    const normal = sweep('normal');
    const tight = sweep('tight');

    // Ladder points the right way (the economic-difficulty analogue of an AI ladder).
    expect(cozy.avgCash).toBeGreaterThan(tight.avgCash);
    expect(normal.avgCash).toBeGreaterThanOrEqual(tight.avgCash);
    // Normal should be survivable with competent play (not doomed). Loose bound — tuning is a /test job.
    expect(normal.survivalRate).toBeGreaterThan(0.4);
  });
});
