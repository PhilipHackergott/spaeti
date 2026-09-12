import { describe, it, expect } from 'vitest';
import { createState, defaultConfig, priceTier, reduce, SKU_BY_ID } from '../../src/engine';
import { satisfaction } from '../../src/engine/economy';

describe('pricing & elasticity', () => {
  it('classifies price tiers around the fair band', () => {
    const beer = SKU_BY_ID.beer; // fairLo 1.0, fairHi 1.9
    expect(priceTier(beer, 0.9)).toBe('steal');
    expect(priceTier(beer, 1.2)).toBe('fair');
    expect(priceTier(beer, 2.2)).toBe('high'); // ≤ fairHi*1.25 = 2.375
    expect(priceTier(beer, 3.0)).toBe('gouge');
  });

  it('satisfaction rewards getting the want, fair price, and promptness', () => {
    const good = satisfaction(true, 'fair', 1);
    const bad = satisfaction(false, 'gouge', 0);
    expect(good).toBeGreaterThan(bad);
    expect(good).toBeGreaterThan(0.7);
    expect(bad).toBeLessThan(0.3);
  });
});

describe('Pfand', () => {
  it('restock applies bottle-deposit credit toward the order', () => {
    let s = createState(defaultConfig('normal', 1));
    s = { ...s, pfandHeld: 10 }; // 10 bottles * €0.15 = €1.50 credit
    const before = s.cash;
    s = reduce(s, { type: 'restock', sku: 'beer', qty: 10 }); // cost 10*0.45 = 4.50 → 3.00 after credit
    expect(s.cash).toBeCloseTo(before - 3.0, 2);
    expect(s.pfandHeld).toBe(0);
  });

  it('returning bottles at serve pays out deposit and banks the bottles', () => {
    let s = createState(defaultConfig('normal', 99));
    s = reduce(s, { type: 'openNight' });
    s = reduce(s, { type: 'tick', dtMs: 120_000 }); // pop arrivals + set an active
    expect(s.active).not.toBeNull();
    const before = s.cash;
    const want = s.active!.want;
    s = reduce(s, { type: 'serveActive', give: [want], pfandBottles: 2 });
    expect(s.pfandHeld).toBe(2);
    expect(s.tally.pfandPaid).toBeCloseTo(0.3, 2);
    // cash changed by: + price(want) + tip − 0.30 payout ; so it differs from `before` by the payout net of sale
    expect(s.cash).not.toBe(before);
  });
});
