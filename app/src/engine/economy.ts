import type { CustomerArchetype, SkuDef, SpatiState, UpgradeDef, UpgradeId } from './types';
import { UPGRADES, UPGRADE_BY_ID } from './content/upgrades';

export type PriceTier = 'steal' | 'fair' | 'high' | 'gouge';

export function priceTier(sku: SkuDef, price: number): PriceTier {
  if (price < sku.fairLo) return 'steal';
  if (price <= sku.fairHi) return 'fair';
  if (price <= sku.fairHi * 1.25) return 'high';
  return 'gouge';
}

/** Promptness 0..1 from patience remaining at serve time. */
export function satisfaction(gotWanted: boolean, tier: PriceTier, promptness: number): number {
  let s = gotWanted ? 0.7 : 0.25;
  s += { steal: 0.25, fair: 0.15, high: -0.05, gouge: -0.35 }[tier];
  s += 0.15 * Math.max(0, Math.min(1, promptness));
  return Math.max(0, Math.min(1, s));
}

export function tipFor(arch: CustomerArchetype, total: number, sat: number): number {
  if (sat < 0.5) return 0;
  // round to cents
  return Math.round(arch.tipBase * total * sat * 100) / 100;
}

export function kiezDelta(arch: CustomerArchetype, tier: PriceTier, balked: boolean): number {
  const base = { steal: 0.4, fair: 0.2, high: -0.2, gouge: -0.8 }[tier];
  const v = balked ? -1.0 * arch.kiezSensitivity : base * arch.kiezSensitivity;
  return Math.round(v * 10) / 10;
}

export function ownsUpgrade(state: SpatiState, id: UpgradeId): boolean {
  return state.upgrades.includes(id);
}

export interface ModuleOption {
  def: UpgradeDef;
  owned: boolean;
  available: boolean; // unlocked (gating met) and not owned
  affordable: boolean;
  reason: string; // why locked (empty if available/owned)
}

/** The Build & Customize shop view (GDD §4c): what's owned / available now / still locked, and why. */
export function unlockReason(state: SpatiState, def: UpgradeDef): string {
  if (def.requires && !state.upgrades.includes(def.requires))
    return `needs ${UPGRADE_BY_ID[def.requires]?.name ?? def.requires}`;
  if (def.availableDay && state.day < def.availableDay) return `unlocks on day ${def.availableDay}`;
  if (def.availableKiez && state.reputation.kiez < def.availableKiez) return `needs Kiez-Trust ${def.availableKiez}`;
  return '';
}

export function moduleOptions(state: SpatiState): ModuleOption[] {
  return UPGRADES.map((def) => {
    const owned = state.upgrades.includes(def.id);
    const reason = owned ? '' : unlockReason(state, def);
    return { def, owned, available: !owned && reason === '', affordable: state.cash >= def.cost, reason };
  });
}


// Community systems a module can switch on (GDD §4b) → a friendly label for the UI.
const SYSTEM_LABEL: Record<string, string> = {
  dwell: 'The bench draws a crowd',
  community: 'Foodsharing fridge',
  events: 'Open-mic nights',
  board: 'Community noticeboard',
};
// Vignette/strand flags that visibly change the corner → a friendly label.
const FLAG_LABEL: Record<string, string> = {
  flyers_up: 'Gig flyers in the window',
  busker: 'Live music out front',
  lena_credit: "Lena's tab",
};

export interface CornerStatus {
  kiezPerNight: number; // passive Kiez-Trust gained each night from modules/décor
  trafficMult: number; // combined foot-traffic multiplier from modules
  systems: string[]; // active community systems (labels)
  flags: string[]; // visible corner flavour from story/vignette flags (labels)
  illegal: boolean; // the "extra menu" dark path is running
  hasSecurity: boolean; // security cam buys down the raid odds
  heat: number; // Ordnungsamt attention
}

/** A legible roll-up of "what your corner has become" — drives the Manage-screen standing panel. Pure. */
export function cornerStatus(state: SpatiState): CornerStatus {
  let kiezPerNight = 0, trafficMult = 1, illegal = false, hasSecurity = false;
  const systems: string[] = [];
  for (const id of state.upgrades) {
    const e = UPGRADE_BY_ID[id]?.effects;
    if (!e) continue;
    kiezPerNight += e.kiezPerNight ?? 0;
    trafficMult *= e.trafficMult ?? 1;
    if (e.illegal) illegal = true;
    if (e.fewerRiskEvents) hasSecurity = true;
    if (e.unlocksSystem && SYSTEM_LABEL[e.unlocksSystem]) systems.push(SYSTEM_LABEL[e.unlocksSystem]);
  }
  const flags = state.story.flags.filter((f) => FLAG_LABEL[f]).map((f) => FLAG_LABEL[f]);
  return {
    kiezPerNight: Math.round(kiezPerNight * 10) / 10,
    trafficMult: Math.round(trafficMult * 100) / 100,
    systems, flags, illegal, hasSecurity, heat: state.ordnungsamtHeat,
  };
}

/** Expected customer count for one night (deterministic inputs; rng adds the per-customer schedule). */
export function nightTraffic(state: SpatiState): number {
  // A busy Späti serves dozens a night; difficulty lives in the *financials* (rent/start-cash), not traffic.
  const base = 65;
  let mult = 1;
  for (const id of state.upgrades) mult *= UPGRADE_BY_ID[id]?.effects.trafficMult ?? 1;
  // Kiez-Trust nudges foot traffic; Sunday is a big spike (everyone else is shut).
  mult *= 1 + Math.max(-0.3, Math.min(0.4, (state.reputation.kiez - 50) / 200));
  if (state.weekday === 6 && state.openSunday) mult *= 1.6;
  return Math.round(base * mult);
}
