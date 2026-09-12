import type { UpgradeDef } from '../types';

// Build & Customize (GDD §4c) — an ONGOING loop: modules + décor unlock GRADUALLY (gated by day /
// Kiez-Trust / a prerequisite), several are TIERED, and a parallel décor track lets you make the place
// yours. `kind: 'module'` = functional offering; `kind: 'decor'` = customization (cosmetic + small effect).
export const UPGRADES: UpgradeDef[] = [
  // ── modules: capacity / offering / draw (trickle out across the season) ──
  { id: 'bigger_fridge', name: 'Bigger fridge', cost: 200, kind: 'module', tier: 1, effects: { stockCap: 12 }, note: 'More cold stock + shelf space.' },
  { id: 'bigger_fridge_2', name: 'Walk-in fridge', cost: 350, kind: 'module', tier: 2, requires: 'bigger_fridge', availableDay: 9, effects: { stockCap: 24 }, note: 'Serious cold capacity.' },
  { id: 'signage', name: 'Neon signage', cost: 180, kind: 'module', tier: 1, effects: { trafficMult: 1.2 }, note: 'More foot traffic.' },
  { id: 'signage_2', name: 'Big neon sign', cost: 320, kind: 'module', tier: 2, requires: 'signage', availableDay: 11, effects: { trafficMult: 1.15 }, note: 'Seen from down the block.' },
  { id: 'coffee_machine', name: 'Coffee machine', cost: 300, kind: 'module', tier: 1, availableDay: 3, effects: { unlocksSku: ['coffee', 'currywurst'] }, note: 'Hot drinks + currywurst.' },
  { id: 'espresso_bar', name: 'Espresso bar', cost: 450, kind: 'module', tier: 2, requires: 'coffee_machine', availableDay: 13, effects: { trafficMult: 1.2, kiezPerNight: 1 }, note: 'A reason to linger.' },
  { id: 'ice_cream_freezer', name: 'Ice-cream freezer', cost: 250, kind: 'module', availableDay: 4, effects: { unlocksSku: ['icecream'] }, note: 'Summer revenue.' },
  { id: 'grocery_section', name: 'Grocery section', cost: 220, kind: 'module', availableDay: 6, effects: { unlocksSku: ['milk', 'eggs'], trafficMult: 1.1 }, note: 'Daytime + Sunday demand.' },
  { id: 'vape_stand', name: 'Vape stand', cost: 150, kind: 'module', availableDay: 7, effects: { unlocksSku: ['vape'] }, note: 'High margin; minors = Integrity/legal beat.' },
  { id: 'security', name: 'Security cam', cost: 220, kind: 'module', availableDay: 5, effects: { fewerRiskEvents: true }, note: 'Fewer risk events.' },
  { id: 'pfandautomat', name: 'Pfandautomat', cost: 350, kind: 'module', availableDay: 9, effects: {}, note: 'Reverse-vending; automates Pfand.' },
  { id: 'bench', name: 'Bench out front', cost: 120, kind: 'module', effects: { kiezPerNight: 1, unlocksSystem: 'dwell' }, note: 'The Kiez gathers.' },
  // ── the illegal dark path ──
  { id: 'extra_menu', name: '"Extra menu" (illegal)', cost: 100, kind: 'module', availableDay: 5, effects: { illegal: true, trafficMult: 1.4 }, note: 'Fat margins; nightly Integrity bleed + rare brutal raid; gates dark branches.' },
  // ── décor / customization (parallel track — make it yours) ──
  { id: 'posters', name: 'Posters & stickers', cost: 40, kind: 'decor', effects: { kiezPerNight: 0.5 }, note: 'Techno flyers, football scarves — character.' },
  { id: 'plants', name: 'Plants', cost: 60, kind: 'decor', availableDay: 2, effects: { kiezPerNight: 0.5 }, note: 'A little life.' },
  { id: 'fairy_lights', name: 'Fairy lights', cost: 50, kind: 'decor', availableDay: 3, effects: { kiezPerNight: 0.5 }, note: 'Cozy glow.' },
  { id: 'rug', name: 'Old rug', cost: 70, kind: 'decor', availableDay: 4, effects: { kiezPerNight: 0.5 }, note: 'It really ties the Späti together.' },
  { id: 'jukebox', name: 'Retro jukebox', cost: 180, kind: 'decor', availableDay: 8, effects: { trafficMult: 1.1, kiezPerNight: 0.5 }, note: 'People stay for the tunes.' },
  { id: 'outdoor_seating', name: 'Outdoor seating', cost: 140, kind: 'decor', requires: 'bench', availableDay: 6, effects: { kiezPerNight: 1, trafficMult: 1.05 }, note: 'Sit, drink, talk.' },
  { id: 'berlin_mural', name: 'Berlin mural', cost: 220, kind: 'decor', availableDay: 11, availableKiez: 60, effects: { kiezPerNight: 1.5 }, note: 'A local artist (Lena?) paints the wall — a landmark.' },
  // ── community systems (GDD §4b) ──
  { id: 'foodsharing_fridge', name: 'Foodsharing fridge', cost: 80, kind: 'module', availableDay: 5, effects: { kiezPerNight: 2, unlocksSystem: 'community' }, note: 'No margin; pure Kiez-Trust.' },
  { id: 'open_mic', name: 'Open-mic corner', cost: 200, kind: 'module', availableDay: 13, effects: { kiezPerNight: 1, unlocksSystem: 'events' }, note: 'Host events; the busker arc.' },
  { id: 'noticeboard', name: 'Community noticeboard', cost: 60, kind: 'module', availableDay: 4, effects: { kiezPerNight: 1, unlocksSystem: 'board' }, note: 'Flatshares, lost cats, gigs — the Kiez talks.' },
  { id: 'mate_tap', name: 'Mate on tap', cost: 280, kind: 'module', availableDay: 10, effects: { trafficMult: 1.15 }, note: 'A Berlin pilgrimage; pulls the late crowd.' },
  // ── more décor / customization ──
  { id: 'photo_booth', name: 'Photo booth', cost: 240, kind: 'decor', availableDay: 8, effects: { trafficMult: 1.1, kiezPerNight: 0.5 }, note: 'Analog strips; people linger and return.' },
  { id: 'vinyl_corner', name: 'Vinyl crate corner', cost: 160, kind: 'decor', availableDay: 9, effects: { kiezPerNight: 1 }, note: 'Crates to dig through; the music nerds adopt you.' },
];

export const UPGRADE_BY_ID: Record<string, UpgradeDef> = Object.fromEntries(UPGRADES.map((u) => [u.id, u]));
