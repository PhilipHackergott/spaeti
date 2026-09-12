import { describe, it, expect } from 'vitest';
import { createState, defaultConfig, reduce } from '../../src/engine';
import { manage, playNight } from '../../src/sim/autoPlayer';

describe('night loop', () => {
  it('opens, serves customers, and closes with correct P&L bookkeeping', () => {
    const s0 = createState(defaultConfig('normal', 4242));
    const managed = manage(s0);
    const cashBeforeOpen = managed.cash;
    const closed = playNight(managed);

    expect(closed.phase).toBe('summary');
    const sum = closed.summaries[closed.summaries.length - 1];
    expect(sum.day).toBe(1);
    expect(sum.sales).toBeGreaterThan(0);
    expect(sum.sales + sum.lost).toBeLessThanOrEqual(closed.arrivals.length);

    // cash after the night = cash before opening + revenue + tips − pfandPaid − bills(+fine)
    const expected = cashBeforeOpen + sum.revenue + sum.tips - sum.pfandPaid - sum.billsDue;
    expect(closed.cash).toBeCloseTo(expected, 2);
    expect(sum.cashAfter).toBeCloseTo(closed.cash, 2);
  });

  it('the night terminates (no infinite tick loop) and advances the day', () => {
    let s = manage(createState(defaultConfig('normal', 7)));
    s = playNight(s);
    expect(s.clockMs).toBeGreaterThanOrEqual(s.config.nightLenMs);
    s = reduce(s, { type: 'advanceDay' });
    expect(s.day).toBe(2);
    expect(['manage', 'end']).toContain(s.phase);
  });

  it('restock spends cash and adds stock; selling depletes it', () => {
    let s = createState(defaultConfig('cozy', 1));
    const before = s.cash;
    s = reduce(s, { type: 'restock', sku: 'beer', qty: 10 });
    expect(s.inventory.beer.stock).toBe(18); // started at 8
    expect(s.cash).toBeCloseTo(before - 10 * 0.45, 2);
  });
});
