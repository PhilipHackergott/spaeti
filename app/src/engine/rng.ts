// Deterministic PRNG (mulberry32) — the ONLY source of randomness in the engine, so a season is
// fully reproducible from { config, seed, action-log }. State is a single uint32 in SpatiState.rngState
// and threaded through every action. (Pattern shared with magical-athlete/engine/rng.ts.)

export interface Rng {
  next(): number; // float in [0, 1)
  int(maxExclusive: number): number; // integer in [0, maxExclusive)
  range(min: number, max: number): number; // float in [min, max)
  pick<T>(arr: readonly T[]): T;
  state(): number; // current serializable state
}

export function makeRng(seed: number): Rng {
  let a = seed >>> 0;
  const next = (): number => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return {
    next,
    int: (maxExclusive: number) => Math.floor(next() * maxExclusive),
    range: (min: number, max: number) => min + next() * (max - min),
    pick: <T>(arr: readonly T[]): T => arr[Math.floor(next() * arr.length)],
    state: () => a >>> 0,
  };
}

/** Weighted pick: returns the index chosen proportional to `weights`. */
export function weightedIndex(rng: Rng, weights: readonly number[]): number {
  const total = weights.reduce((s, w) => s + Math.max(0, w), 0);
  if (total <= 0) return 0;
  let r = rng.next() * total;
  for (let i = 0; i < weights.length; i++) {
    r -= Math.max(0, weights[i]);
    if (r < 0) return i;
  }
  return weights.length - 1;
}
