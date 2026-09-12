import { describe, it, expect } from 'vitest';
import { createState, defaultConfig, pickEnding, type SpatiState } from '../../src/engine';
import { playSeason, type SeasonPolicy } from '../../src/sim/autoPlayer';

// Balance sweep for the RISK systems (illegal dark path + Sunday/Ordnungsamt). A handful of seeds on Normal;
// asserts the systems pull in the directions the design intends — not exact numbers (tuning stays a /test job).
const SEEDS = [3000, 3001, 3002];

interface Agg { cash: number; integ: number; sales: number; raids: number; allSoldout: boolean; allGood: boolean; finals: SpatiState[] }
function run(policy: SeasonPolicy): Agg {
  let cash = 0, integ = 0, sales = 0, raids = 0;
  let allSoldout = true, allGood = true;
  const finals: SpatiState[] = [];
  for (const seed of SEEDS) {
    const r = playSeason(createState(defaultConfig('normal', seed)), policy);
    cash += r.endCash; integ += r.integrity;
    sales += r.final.summaries.reduce((a, x) => a + x.sales, 0);
    raids += r.final.log.filter((l) => l.kind === 'raid').length;
    const e = pickEnding(r.final);
    if (e !== 'soldout') allSoldout = false;
    if (e !== 'institution' && e !== 'held') allGood = false;
    finals.push(r.final);
  }
  const n = SEEDS.length;
  return { cash: cash / n, integ: integ / n, sales: sales / n, raids, allSoldout, allGood, finals };
}

describe('risk-system balance (dark path + Sunday)', () => {
  const baseline = run({});
  const dark = run({ buyDarkPath: true });

  it('honest play protects Integrity and earns a good ending', () => {
    expect(baseline.integ).toBeGreaterThan(60); // refusing minors + fair prices keeps your hands clean
    expect(baseline.allGood).toBe(true); // institution / held, never soldout
  });

  it('the dark path is a real temptation — more money, worse soul', () => {
    expect(dark.cash).toBeGreaterThan(baseline.cash); // fat margins: genuinely more cash
    expect(dark.integ).toBeLessThan(45); // …bought with Integrity (nightly bleed + raids)
    expect(dark.allSoldout).toBe(true); // which locks in the Sold Out ending
  });

  it('the security cam buys down raid losses', () => {
    const guarded = run({ buyDarkPath: true, buySecurity: true });
    expect(guarded.raids).toBeLessThanOrEqual(dark.raids); // fewer brutal raids over the season
  });

  it('opening Sundays trades risk for more trade', () => {
    const sunday = run({ openSundays: true });
    expect(sunday.sales).toBeGreaterThan(baseline.sales); // the Sunday spike means more customers served
  });
});
