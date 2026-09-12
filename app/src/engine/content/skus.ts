import type { SkuDef } from '../types';

// Starter SKU catalogue (base game). Prices in euros. `deposit` = Pfand on returnable bottles.
// `unlockedBy` gates a SKU behind an upgrade module (ice-cream/grocery/vapes/hot). Real-brand stand-ins.
export const SKUS: SkuDef[] = [
  // — Drinks —
  { id: 'beer', name: 'Sterni (beer)', category: 'drinks', cost: 0.45, basePrice: 1.2, fairLo: 1.0, fairHi: 1.9, demand: 1.6, deposit: 0.08, restricted: true },
  { id: 'mate', name: 'Mate', category: 'drinks', cost: 0.85, basePrice: 1.8, fairLo: 1.5, fairHi: 2.8, demand: 1.4, deposit: 0.15 },
  { id: 'cola', name: 'Cola', category: 'drinks', cost: 0.5, basePrice: 1.5, fairLo: 1.2, fairHi: 2.4, demand: 1.0, deposit: 0.25 },
  { id: 'water', name: 'Water', category: 'drinks', cost: 0.2, basePrice: 0.9, fairLo: 0.7, fairHi: 1.6, demand: 1.1, deposit: 0.25 },
  { id: 'energy', name: 'Energy drink', category: 'drinks', cost: 0.7, basePrice: 1.8, fairLo: 1.5, fairHi: 2.9, demand: 0.7 },
  // — Snacks —
  { id: 'chips', name: 'Chips', category: 'snacks', cost: 0.7, basePrice: 1.8, fairLo: 1.5, fairHi: 2.7, demand: 0.9 },
  { id: 'chocolate', name: 'Chocolate', category: 'snacks', cost: 0.55, basePrice: 1.4, fairLo: 1.1, fairHi: 2.2, demand: 0.8 },
  { id: 'gummi', name: 'Gummi bears', category: 'snacks', cost: 0.5, basePrice: 1.3, fairLo: 1.0, fairHi: 2.0, demand: 0.7 },
  { id: 'schrippe', name: 'Schrippe', category: 'snacks', cost: 0.1, basePrice: 0.4, fairLo: 0.3, fairHi: 0.7, demand: 0.5, perishable: true },
  // — Tobacco (restricted) —
  { id: 'cigarettes', name: 'Cigarettes', category: 'tobacco', cost: 6.5, basePrice: 8.0, fairLo: 7.5, fairHi: 9.0, demand: 1.0, restricted: true },
  { id: 'tobacco', name: 'Rolling tobacco', category: 'tobacco', cost: 9.0, basePrice: 11.0, fairLo: 10.5, fairHi: 12.5, demand: 0.5, restricted: true },
  { id: 'papers', name: 'Rolling papers', category: 'tobacco', cost: 0.4, basePrice: 1.0, fairLo: 0.8, fairHi: 1.6, demand: 0.5 },
  // — Essentials —
  { id: 'tp', name: 'Toilet paper', category: 'essentials', cost: 0.6, basePrice: 1.5, fairLo: 1.2, fairHi: 2.4, demand: 0.4 },
  { id: 'condoms', name: 'Condoms', category: 'essentials', cost: 1.5, basePrice: 3.5, fairLo: 3.0, fairHi: 5.0, demand: 0.4 },
  { id: 'batteries', name: 'Batteries', category: 'essentials', cost: 1.0, basePrice: 3.0, fairLo: 2.5, fairHi: 4.5, demand: 0.3 },
  { id: 'lighter', name: 'Lighter', category: 'essentials', cost: 0.3, basePrice: 1.2, fairLo: 1.0, fairHi: 2.0, demand: 0.6 },
  { id: 'painkillers', name: 'Painkillers', category: 'essentials', cost: 1.2, basePrice: 3.0, fairLo: 2.5, fairHi: 4.5, demand: 0.4 },
  // — Upgrade-gated —
  { id: 'coffee', name: 'Coffee', category: 'hot', cost: 0.3, basePrice: 2.0, fairLo: 1.6, fairHi: 3.0, demand: 0.9, unlockedBy: 'coffee_machine' },
  { id: 'currywurst', name: 'Currywurst', category: 'hot', cost: 1.2, basePrice: 3.5, fairLo: 3.0, fairHi: 5.0, demand: 0.7, unlockedBy: 'coffee_machine' },
  { id: 'icecream', name: 'Ice cream', category: 'snacks', cost: 0.5, basePrice: 2.0, fairLo: 1.6, fairHi: 3.2, demand: 0.6, perishable: true, unlockedBy: 'ice_cream_freezer' },
  { id: 'milk', name: 'Milk', category: 'essentials', cost: 0.6, basePrice: 1.5, fairLo: 1.2, fairHi: 2.2, demand: 0.5, perishable: true, unlockedBy: 'grocery_section' },
  { id: 'eggs', name: 'Eggs', category: 'essentials', cost: 1.0, basePrice: 2.5, fairLo: 2.0, fairHi: 3.5, demand: 0.4, perishable: true, unlockedBy: 'grocery_section' },
  { id: 'vape', name: 'Vape', category: 'tobacco', cost: 4.0, basePrice: 8.0, fairLo: 7.0, fairHi: 11.0, demand: 0.5, restricted: true, unlockedBy: 'vape_stand' },
];

export const SKU_BY_ID: Record<string, SkuDef> = Object.fromEntries(SKUS.map((s) => [s.id, s]));
