import type { Action, Arrival, CustomerArchetype, SpatiState } from './types';
import { makeRng, weightedIndex, type Rng } from './rng';
import { ARCHETYPES, ARCHETYPE_BY_ID } from './content/customers';
import { SKU_BY_ID } from './content/skus';
import { UPGRADE_BY_ID } from './content/upgrades';
import { kiezDelta, nightTraffic, priceTier, satisfaction, tipFor } from './economy';
import { applyBeatChoice, applyVignetteChoice, fireEligible } from './storyflow';

const PFAND_PER_BOTTLE = 0.15;

function log(s: SpatiState, kind: string, text: string): void {
  s.log.push({ ts: s.day * 1_000_000 + Math.round(s.clockMs), kind, text });
}

function pickWant(rng: Rng, arch: CustomerArchetype, available: string[]): string {
  const entries = Object.entries(arch.wants).filter(([id]) => available.includes(id));
  if (entries.length === 0) return available.length ? rng.pick(available) : 'water';
  const idx = weightedIndex(rng, entries.map(([, w]) => w));
  return entries[idx][0];
}

function buildArrivals(s: SpatiState, rng: Rng): Arrival[] {
  const n = nightTraffic(s);
  const len = s.config.nightLenMs;
  const available = Object.keys(s.inventory);
  const archWeights = ARCHETYPES.map((a) => a.curve[0] + a.curve[1] + a.curve[2]);
  const out: Arrival[] = [];
  for (let i = 0; i < n; i++) {
    const arch = ARCHETYPES[weightedIndex(rng, archWeights)];
    const third = weightedIndex(rng, arch.curve);
    const timeMs = rng.range((third / 3) * len, ((third + 1) / 3) * len);
    out.push({ timeMs, archetypeId: arch.id, want: pickWant(rng, arch, available) });
  }
  out.sort((a, b) => a.timeMs - b.timeMs);
  return out;
}

export function reduce(prev: SpatiState, action: Action): SpatiState {
  const s: SpatiState = structuredClone(prev);
  switch (action.type) {
    case 'openNight': {
      if (s.phase !== 'manage') return prev;
      const rng = makeRng(s.rngState);
      s.arrivals = buildArrivals(s, rng);
      s.rngState = rng.state();
      s.phase = 'night';
      s.clockMs = 0;
      s.nextArrival = 0;
      s.queue = [];
      s.active = null;
      s.tally = { revenue: 0, cogs: 0, tips: 0, pfandPaid: 0, sales: 0, lost: 0 };
      log(s, 'open', `Night ${s.day} opens — ${s.arrivals.length} customers expected.`);
      return s;
    }
    case 'tick': {
      if (s.phase !== 'night') return prev;
      s.clockMs += action.dtMs;
      while (s.nextArrival < s.arrivals.length && s.arrivals[s.nextArrival].timeMs <= s.clockMs) {
        const a = s.arrivals[s.nextArrival++];
        const arch = ARCHETYPE_BY_ID[a.archetypeId];
        s.queue.push({ id: s.nextCustomerId++, archetypeId: a.archetypeId, want: a.want, patienceLeftMs: arch.patienceMs });
      }
      if (s.active) {
        s.active.patienceLeftMs -= action.dtMs;
        if (s.active.patienceLeftMs <= 0) {
          const arch = ARCHETYPE_BY_ID[s.active.archetypeId];
          s.tally.lost++;
          s.reputation.kiez += kiezDelta(arch, 'fair', true);
          log(s, 'balk', `${arch.name} got tired of waiting and left.`);
          s.active = null;
        }
      }
      if (!s.active && s.queue.length) s.active = s.queue.shift()!;
      return s;
    }
    case 'serveActive': {
      if (s.phase !== 'night' || !s.active) return prev;
      const arch = ARCHETYPE_BY_ID[s.active.archetypeId];
      const want = s.active.want;
      let total = 0;
      let gotWanted = false;
      let worstTier = priceTier(SKU_BY_ID[want] ?? SKU_BY_ID.water, s.inventory[want]?.price ?? 0);
      const tierRank = { steal: 0, fair: 1, high: 2, gouge: 3 } as const;
      for (const id of action.give) {
        const inv = s.inventory[id];
        const def = SKU_BY_ID[id];
        if (!inv || !def || inv.stock <= 0) continue; // can't give what you don't have
        inv.stock -= 1;
        total += inv.price;
        s.tally.revenue += inv.price;
        s.tally.cogs += def.cost;
        s.cash += inv.price;
        if (id === want) gotWanted = true;
        const t = priceTier(def, inv.price);
        if (tierRank[t] > tierRank[worstTier]) worstTier = t;
        if (def.restricted && arch.underage) {
          s.reputation.integrity = Math.max(0, s.reputation.integrity - 8);
          log(s, 'ethics', `Sold ${def.name} to a minor — Integrity hit.`);
        }
      }
      // Pfand payout
      const bottles = action.pfandBottles ?? 0;
      if (bottles > 0) {
        const payout = Math.round(bottles * PFAND_PER_BOTTLE * 100) / 100;
        s.cash -= payout;
        s.tally.pfandPaid += payout;
        s.pfandHeld += bottles;
      }
      const promptness = s.active.patienceLeftMs / Math.max(1, arch.patienceMs);
      const overBudget = total > arch.budget;
      const sat = overBudget ? 0.2 : satisfaction(gotWanted, worstTier, promptness);
      const tip = tipFor(arch, total, sat);
      s.cash += tip;
      s.tally.tips += tip;
      s.reputation.kiez = clamp(s.reputation.kiez + kiezDelta(arch, worstTier, false) - (gotWanted ? 0 : 0.3 * arch.kiezSensitivity));
      s.reputation.profit = clamp(s.reputation.profit + (total > 0 ? 0.2 : 0));
      s.tally.sales++;
      s.active = null;
      if (s.queue.length) s.active = s.queue.shift()!;
      return s;
    }
    case 'skipActive': {
      if (!s.active) return prev;
      s.reputation.kiez = clamp(s.reputation.kiez - 0.1);
      s.active = null;
      if (s.queue.length) s.active = s.queue.shift()!;
      return s;
    }
    case 'setPrice': {
      const inv = s.inventory[action.sku];
      if (inv) inv.price = Math.max(0, Math.round(action.price * 100) / 100);
      return s;
    }
    case 'restock': {
      const def = SKU_BY_ID[action.sku];
      const inv = s.inventory[action.sku];
      if (!def || !inv || action.qty <= 0) return prev;
      let cost = action.qty * def.cost;
      // Pfand credit applies toward the order.
      const credit = s.pfandHeld * PFAND_PER_BOTTLE;
      if (credit > 0) {
        const used = Math.min(credit, cost);
        cost -= used;
        s.pfandHeld -= Math.round((used / PFAND_PER_BOTTLE));
        if (s.pfandHeld < 0) s.pfandHeld = 0;
      }
      cost = Math.round(cost * 100) / 100;
      if (cost > s.cash) return prev; // can't afford
      s.cash -= cost;
      inv.stock += action.qty;
      return s;
    }
    case 'buyUpgrade': {
      const def = UPGRADE_BY_ID[action.id];
      if (!def || s.upgrades.includes(action.id) || def.cost > s.cash) return prev;
      // gradual-availability gating (GDD §4c): prerequisite / day / Kiez-Trust
      if (def.requires && !s.upgrades.includes(def.requires)) return prev;
      if (def.availableDay && s.day < def.availableDay) return prev;
      if (def.availableKiez && s.reputation.kiez < def.availableKiez) return prev;
      s.cash -= def.cost;
      s.upgrades.push(action.id);
      for (const id of def.effects.unlocksSku ?? []) {
        if (!s.inventory[id]) s.inventory[id] = { stock: 0, price: SKU_BY_ID[id]?.basePrice ?? 1 };
      }
      log(s, 'upgrade', `Bought ${def.name}.`);
      return s;
    }
    case 'setSundayOpen': {
      s.openSunday = action.open;
      return s;
    }
    case 'resolveBeat': {
      applyBeatChoice(s, action.choice);
      return s;
    }
    case 'resolveVignette': {
      applyVignetteChoice(s, action.choice);
      return s;
    }
    case 'closeNight': {
      if (s.phase !== 'night') return prev;
      const billsDue = s.config.rentPerDay;
      s.cash -= billsDue;
      // Sunday / Ordnungsamt gamble
      let fine = 0;
      if (s.weekday === 6 && s.openSunday) {
        const rng = makeRng(s.rngState ^ 0x9e3779b9);
        if (rng.next() < Math.min(0.6, 0.1 + s.ordnungsamtHeat / 100)) {
          fine = 50 + Math.round(s.ordnungsamtHeat);
          s.cash -= fine;
          log(s, 'ordnungsamt', `Ordnungsamt inspection — fined €${fine} for Sunday trading.`);
        }
        s.ordnungsamtHeat += 10;
        s.rngState = rng.state();
      }
      // The illegal "extra menu" dark path: fat margins by day (trafficMult), but the corner gets dirtier —
      // a nightly Integrity bleed and a real bust risk (a raid: heavy fine + Kiez/Integrity hit). The security
      // cam (fewerRiskEvents) buys down the odds. This is what pushes a greedy run toward the 'soldout' ending.
      const hasIllegal = s.upgrades.some((id) => UPGRADE_BY_ID[id]?.effects.illegal);
      if (hasIllegal) {
        s.reputation.integrity = clamp(s.reputation.integrity - 1.5);
        const hasSecurity = s.upgrades.some((id) => UPGRADE_BY_ID[id]?.effects.fewerRiskEvents);
        const dark = makeRng((s.rngState ^ 0x2545f491) >>> 0);
        if (dark.next() < (hasSecurity ? 0.04 : 0.08)) {
          const raid = 120 + Math.round(dark.next() * 80);
          s.cash -= raid;
          fine += raid;
          s.reputation.kiez = clamp(s.reputation.kiez - 6);
          s.reputation.integrity = clamp(s.reputation.integrity - 8);
          log(s, 'raid', `Police raid — the "extra menu" cost you €${raid} and the block's trust.`);
        }
      }
      let kiezGain = 0;
      for (const id of s.upgrades) kiezGain += UPGRADE_BY_ID[id]?.effects.kiezPerNight ?? 0;
      s.reputation.kiez = clamp(s.reputation.kiez + kiezGain);
      const profit = Math.round((s.tally.revenue + s.tally.tips - s.tally.cogs - billsDue - s.tally.pfandPaid - fine) * 100) / 100;
      s.summaries.push({
        day: s.day, revenue: round2(s.tally.revenue), cogs: round2(s.tally.cogs), tips: round2(s.tally.tips),
        billsDue: billsDue + fine, pfandPaid: round2(s.tally.pfandPaid), profit, cashAfter: round2(s.cash),
        sales: s.tally.sales, lost: s.tally.lost, kiezDelta: round2(kiezGain),
      });
      s.phase = 'summary';
      log(s, 'close', `Night ${s.day} closed — profit €${profit.toFixed(2)}, cash €${s.cash.toFixed(2)}.`);
      return s;
    }
    case 'advanceDay': {
      if (s.phase !== 'summary') return prev;
      for (const id of Object.keys(s.inventory)) {
        if (SKU_BY_ID[id]?.perishable) s.inventory[id].stock = Math.floor(s.inventory[id].stock * 0.5);
      }
      s.day += 1;
      s.weekday = ((s.weekday + 1) % 7) as SpatiState['weekday'];
      s.clockMs = 0;
      s.story.pendingVignette = null; // a vignette is a one-morning thing; drop any that went unanswered
      if (s.day > s.config.seasonDays || s.cash < -200) s.phase = 'end';
      else {
        s.phase = 'manage';
        fireEligible(s); // the new day's morning beat — a cast beat, else maybe a vignette
      }
      return s;
    }
    default:
      return prev;
  }
}

function clamp(v: number, lo = 0, hi = 100): number {
  return Math.max(lo, Math.min(hi, Math.round(v * 10) / 10));
}
function round2(v: number): number {
  return Math.round(v * 100) / 100;
}
