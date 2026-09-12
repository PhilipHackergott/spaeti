import type { Difficulty, SpatiConfig, SpatiState } from './types';
import { SKUS } from './content/skus';
import { fireEligible, seedStory } from './storyflow';

export function defaultConfig(difficulty: Difficulty, seed: number): SpatiConfig {
  const presets: Record<Difficulty, { startCash: number; rentPerDay: number }> = {
    cozy: { startCash: 600, rentPerDay: 35 },
    normal: { startCash: 420, rentPerDay: 48 },
    tight: { startCash: 300, rentPerDay: 68 },
  };
  return {
    difficulty,
    seed,
    nightLenMs: 9 * 60 * 1000, // a 9-minute compressed night
    seasonDays: 28,
    ...presets[difficulty],
  };
}

export function createState(config: SpatiConfig): SpatiState {
  const inventory: SpatiState['inventory'] = {};
  for (const sku of SKUS) {
    if (sku.unlockedBy) continue; // gated SKUs appear when the upgrade is bought
    inventory[sku.id] = { stock: 8, price: sku.basePrice };
  }
  const state: SpatiState = {
    config,
    day: 1,
    weekday: 0, // Monday
    phase: 'manage',
    clockMs: 0,
    cash: config.startCash,
    pfandHeld: 0,
    inventory,
    upgrades: [],
    reputation: { kiez: 50, profit: 50, integrity: 75 },
    openSunday: false,
    ordnungsamtHeat: 0,
    arrivals: [],
    nextArrival: 0,
    queue: [],
    active: null,
    nextCustomerId: 1,
    tally: { revenue: 0, cogs: 0, tips: 0, pfandPaid: 0, sales: 0, lost: 0 },
    summaries: [],
    story: seedStory(),
    rngState: config.seed >>> 0,
    log: [],
  };
  fireEligible(state); // day-1 morning beat (Cem's keys) becomes pending
  return state;
}

/** Act/season label from the calendar (Summer → Autumn → Winter thirds). */
export function actOf(state: SpatiState): 'summer' | 'autumn' | 'winter' {
  const f = state.day / state.config.seasonDays;
  return f <= 1 / 3 ? 'summer' : f <= 2 / 3 ? 'autumn' : 'winter';
}
