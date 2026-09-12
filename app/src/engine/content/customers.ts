import type { CustomerArchetype } from '../types';

// Customer archetypes (base game). `wants` are weighted SkuId picks; `curve` weights spawns across the
// night's [early, mid, late] thirds. The recurring story characters (narrative-design.md) layer on top
// of these as flagged vignettes later — these archetypes drive the minute-to-minute serving sim.
export const ARCHETYPES: CustomerArchetype[] = [
  {
    id: 'regular', name: 'Kiez regular',
    wants: { beer: 3, mate: 2, cigarettes: 2, water: 1, schrippe: 1 },
    patienceMs: 9000, budget: 12, priceTolerance: 1.25, kiezSensitivity: 1.4, tipBase: 0.2, curve: [1, 1, 0.8],
  },
  {
    id: 'tourist', name: 'Lost tourist',
    wants: { water: 3, beer: 2, chips: 2, cola: 1, chocolate: 1 },
    patienceMs: 7000, budget: 20, priceTolerance: 1.9, kiezSensitivity: 0.4, tipBase: 0.6, curve: [1, 1, 0.4],
  },
  {
    id: 'raver', name: 'After-club raver',
    wants: { mate: 3, energy: 2, water: 2, gummi: 1, chips: 1 },
    patienceMs: 6000, budget: 14, priceTolerance: 1.5, kiezSensitivity: 0.8, tipBase: 0.4, curve: [0, 0.4, 1.8],
  },
  {
    id: 'nurse', name: 'Night-shift nurse',
    wants: { coffee: 3, water: 2, painkillers: 1, schrippe: 1, chocolate: 1 },
    patienceMs: 8000, budget: 10, priceTolerance: 1.1, kiezSensitivity: 1.1, tipBase: 0.3, curve: [0.5, 1, 1],
  },
  {
    id: 'student', name: 'Broke student',
    wants: { mate: 3, beer: 2, gummi: 1, schrippe: 1 },
    patienceMs: 10000, budget: 6, priceTolerance: 1.0, kiezSensitivity: 1.2, tipBase: 0.05, curve: [0.8, 1, 0.9],
  },
  {
    id: 'insomniac', name: 'Insomniac',
    wants: { cigarettes: 2, cola: 2, chips: 2, chocolate: 1, papers: 1 },
    patienceMs: 11000, budget: 15, priceTolerance: 1.3, kiezSensitivity: 1.0, tipBase: 0.2, curve: [0.3, 1, 1.2],
  },
  {
    id: 'party', name: 'Party group',
    wants: { beer: 4, chips: 2, energy: 1, gummi: 1 },
    patienceMs: 6500, budget: 25, priceTolerance: 1.4, kiezSensitivity: 0.9, tipBase: 0.5, curve: [0.5, 1.4, 0.7],
  },
  {
    id: 'kid', name: 'Kassenkind', // tries to buy a restricted item — the ethics beat
    wants: { beer: 3, energy: 1 },
    patienceMs: 7000, budget: 8, priceTolerance: 1.1, kiezSensitivity: 0.6, tipBase: 0.1, curve: [1, 0.7, 0.2],
    underage: true,
  },
];

export const ARCHETYPE_BY_ID: Record<string, CustomerArchetype> = Object.fromEntries(
  ARCHETYPES.map((a) => [a.id, a]),
);
