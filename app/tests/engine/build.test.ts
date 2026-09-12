import { describe, it, expect } from 'vitest';
import { createState, defaultConfig, reduce, moduleOptions } from '../../src/engine';

describe('Build & Customize (ongoing expansion, GDD §4c)', () => {
  it('modules/décor unlock gradually — gating is reported', () => {
    const s = createState(defaultConfig('cozy', 1)); // day 1, cash 600
    const by = Object.fromEntries(moduleOptions(s).map((o) => [o.def.id, o]));
    expect(by.posters.available).toBe(true); // day-1 décor
    expect(by.posters.affordable).toBe(true);
    expect(by.coffee_machine.available).toBe(false); // day-gated
    expect(by.coffee_machine.reason).toContain('day 3');
    expect(by.bigger_fridge_2.available).toBe(false); // needs the tier-1 first
    expect(by.bigger_fridge_2.reason).toContain('Bigger fridge');
  });

  it('buyUpgrade enforces prerequisite + day/Kiez gating', () => {
    let s = createState(defaultConfig('cozy', 1));
    const before = s.cash;
    s = reduce(s, { type: 'buyUpgrade', id: 'espresso_bar' }); // needs coffee_machine + day 13
    expect(s.cash).toBe(before);
    expect(s.upgrades).not.toContain('espresso_bar');

    s = reduce(s, { type: 'buyUpgrade', id: 'bench' }); // no gating
    expect(s.upgrades).toContain('bench');

    s = reduce(s, { type: 'buyUpgrade', id: 'bigger_fridge' }); // tier-1, day 1 ok
    expect(s.upgrades).toContain('bigger_fridge');
    const cash2 = s.cash;
    s = reduce(s, { type: 'buyUpgrade', id: 'bigger_fridge_2' }); // tier-2 needs day 9 → rejected on day 1
    expect(s.cash).toBe(cash2);
  });

  it('buying a module unlocks its SKUs into the inventory', () => {
    let s = createState(defaultConfig('cozy', 1));
    s = { ...s, day: 3 }; // reach coffee_machine availability
    expect(s.inventory.coffee).toBeUndefined();
    s = reduce(s, { type: 'buyUpgrade', id: 'coffee_machine' });
    expect(s.upgrades).toContain('coffee_machine');
    expect(s.inventory.coffee).toBeDefined();
  });
});
