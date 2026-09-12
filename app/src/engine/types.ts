// Pure engine types for Späti Simulator. No React/Pixi/DOM here.
// The whole sim is reconstructable from { config, seed, action-log }.

export type SkuCategory = 'drinks' | 'snacks' | 'tobacco' | 'essentials' | 'hot';

export interface SkuDef {
  id: string;
  name: string;
  category: SkuCategory;
  cost: number; // wholesale cost per unit
  basePrice: number; // suggested retail (the "fair" centre)
  fairLo: number; // below → customers feel it's a steal (faster sellout, slight goodwill)
  fairHi: number; // above → balk chance + Kiez-Trust dip
  demand: number; // base demand weight (how often wanted)
  perishable?: boolean; // decays between nights if overstocked
  restricted?: boolean; // age-gated (alcohol/tobacco/vapes) — underage = integrity beat
  deposit?: number; // Pfand deposit if this is a returnable bottle
  unlockedBy?: string; // UpgradeId gating this SKU (e.g. ice-cream needs the freezer)
}

export interface SkuState {
  stock: number;
  price: number; // player-set
}

export type CustomerArchetypeId = string;

export interface CustomerArchetype {
  id: CustomerArchetypeId;
  name: string;
  /** weighted wants: pick 1 SKU by these weights (keyed by SkuId) */
  wants: Record<string, number>;
  patienceMs: number; // how long before they balk
  budget: number; // max they'll spend (soft)
  priceTolerance: number; // multiplier on fairHi they'll accept before balking (1 = strict)
  kiezSensitivity: number; // how much gouging/short stock hurts Kiez-Trust with them
  tipBase: number; // base tip on a good serve
  /** time-of-night spawn weights across the night's [early, mid, late] thirds */
  curve: [number, number, number];
  underage?: boolean; // for the restricted-item ethics beat
}

export interface Customer {
  id: number;
  archetypeId: CustomerArchetypeId;
  want: string; // a SkuId
  patienceLeftMs: number;
}

export type UpgradeId = string;
export interface UpgradeDef {
  id: UpgradeId;
  name: string;
  cost: number;
  kind: 'module' | 'decor'; // module = functional offering; decor = customization (cosmetic + small effect)
  tier?: number; // for levelled modules (Fridge I/II/III)
  requires?: UpgradeId; // prerequisite module that must be owned first
  availableDay?: number; // not offered before this day
  availableKiez?: number; // not offered below this Kiez-Trust
  /** declarative effects applied while owned (kept legible; expanded over build) */
  effects: {
    trafficMult?: number; // more customers per night
    kiezPerNight?: number; // passive Kiez-Trust
    stockCap?: number; // raises restock capacity / shelf space
    fewerRiskEvents?: boolean;
    unlocksSku?: string[]; // SKUs this enables (ice-cream/grocery/vapes/...)
    illegal?: boolean; // the "extra menu" dark path
    unlocksSystem?: string; // a community system (favours/board/events/...)
  };
  note?: string;
}

export type Phase = 'manage' | 'night' | 'summary' | 'end';
export type Weekday = 0 | 1 | 2 | 3 | 4 | 5 | 6; // 0=Mon … 6=Sun
export type Difficulty = 'cozy' | 'normal' | 'tight';

export interface Reputation {
  kiez: number; // Kiez-Trust (community standing)
  profit: number; // Profit-standing
  integrity: number; // 0..100; lower = compromised
}

/** Per-night accumulators (reset at openNight, settled at closeNight). */
export interface NightTally {
  revenue: number;
  cogs: number;
  tips: number;
  pfandPaid: number;
  sales: number;
  lost: number; // balked customers
}

export interface NightSummary {
  day: number;
  revenue: number;
  cogs: number;
  tips: number;
  billsDue: number;
  pfandPaid: number;
  profit: number;
  cashAfter: number;
  sales: number;
  lost: number;
  kiezDelta: number;
}

export interface Arrival {
  timeMs: number;
  archetypeId: CustomerArchetypeId;
  want: string;
}

export interface SpatiConfig {
  difficulty: Difficulty;
  seed: number;
  nightLenMs: number; // compressed night length
  seasonDays: number; // total days in the run
  startCash: number;
  rentPerDay: number;
}

export interface LogEntry {
  ts: number; // day*1e6 + clockMs (coarse ordering)
  kind: string;
  text: string;
}

export interface SpatiState {
  config: SpatiConfig;
  day: number; // 1-based
  weekday: Weekday;
  phase: Phase;
  clockMs: number; // within the current night
  cash: number;
  pfandHeld: number; // bottles awaiting wholesaler credit
  inventory: Record<string, SkuState>;
  upgrades: UpgradeId[];
  reputation: Reputation;
  openSunday: boolean; // whether the player opens on Sundays (Ladenschluss gamble)
  ordnungsamtHeat: number; // rises with brazen Sunday trading → fine risk
  arrivals: Arrival[]; // this night's deterministic schedule (sorted by timeMs)
  nextArrival: number; // index into arrivals
  queue: Customer[];
  active: Customer | null;
  nextCustomerId: number;
  tally: NightTally;
  summaries: NightSummary[];
  story: StoryState;
  rngState: number;
  log: LogEntry[];
}

// ── Narrative (Truby): strands = ordered, branching beats; the main arc is a priority strand. ──
export interface Choice {
  label: string;
  cash?: number; kiez?: number; profit?: number; integrity?: number;
  flags?: string[]; // story flags this choice sets
  outcome?: string; // sets the strand's local outcome (for the ending tapestry)
  next?: string; // branch to this beat id; omit → the strand ends after this beat
}
export interface Beat {
  id: string;
  speaker: string;
  lines: string[]; // shown in the dialogue box
  choices: Choice[]; // ≥1; a single "Continue" choice for non-decision beats
  afterDay?: number; // earliest day this beat may fire
  minKiez?: number; // gate by Kiez-Trust
  requiresFlag?: string; // gate by a story flag
}
export interface Strand {
  id: string;
  character: string; // display name
  start: string; // first beat id
  priority?: number; // higher fires first when several are eligible the same day (main arc = high)
  beats: Record<string, Beat>;
  /** epilogue[mainEnding][localOutcome] → the "where are they now" line (the tapestry, §6b). */
  epilogue: Record<string, Record<string, string>>;
}
export interface StrandProgress {
  cur: string | null; // current beat id; null = strand finished
  outcome: string | null; // local outcome chosen
  lastDay: number; // last day a beat of this strand fired (≤1 beat/strand/day)
}
export interface StoryState {
  flags: string[];
  met: string[]; // characters encountered (drive the tapestry)
  strands: Record<string, StrandProgress>;
  mainOutcome: string | null; // 'sell' | 'stand' | … set at the climax
  pending: { strand: string } | null; // a strand beat awaiting the player's choice (blocks the UI)
  seenVignettes: string[]; // one-off city scenes already played (never repeat)
  pendingVignette: string | null; // a one-off vignette awaiting choice (blocks the UI like a beat)
}

/** A one-off "slice of the city" scene from the parade of strangers — no ongoing arc, fires on quiet
 *  mornings when no cast beat is due. Reuses Choice (cash/kiez/profit/integrity/flags; next/outcome ignored). */
export interface Vignette {
  id: string;
  speaker: string;
  lines: string[];
  choices: Choice[];
  afterDay?: number; // earliest day it may fire
  minKiez?: number; // gate by Kiez-Trust
  requiresFlag?: string; // gate by a story flag
  weekday?: Weekday; // optional: only on this weekday (e.g. weekend crowds)
}

export type Action =
  | { type: 'openNight' }
  | { type: 'tick'; dtMs: number }
  | { type: 'serveActive'; give: string[]; pfandBottles?: number }
  | { type: 'skipActive' } // wave the customer off (no sale)
  | { type: 'setPrice'; sku: string; price: number }
  | { type: 'restock'; sku: string; qty: number }
  | { type: 'buyUpgrade'; id: UpgradeId }
  | { type: 'setSundayOpen'; open: boolean }
  | { type: 'resolveBeat'; choice: number }
  | { type: 'resolveVignette'; choice: number }
  | { type: 'closeNight' }
  | { type: 'advanceDay' };
