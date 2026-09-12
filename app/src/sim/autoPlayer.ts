// Headless "competent shopkeeper" policy — drives engine tests + the balance sim (npm run sim).
// NOT shipped. It plays the whole manage→night→close→advance loop deterministically.
import { reduce } from '../engine/rules';
import { legalView } from '../engine/legal';
import { SKU_BY_ID } from '../engine/content';
import type { SpatiState } from '../engine/types';

const round2 = (v: number) => Math.round(v * 100) / 100;

function clampToFair(skuId: string, price: number): number {
  const def = SKU_BY_ID[skuId];
  if (!def) return price;
  return round2(Math.max(def.fairLo, Math.min(def.fairHi, price)));
}

/** Manage phase: price = cost×markup clamped to the fair band; restock everything to `par`. */
export function manage(s0: SpatiState, markup = 2.8, par = 22): SpatiState {
  let s = s0;
  for (const skuId of Object.keys(s.inventory)) {
    const def = SKU_BY_ID[skuId];
    if (!def) continue;
    s = reduce(s, { type: 'setPrice', sku: skuId, price: clampToFair(skuId, def.cost * markup) });
    const need = par - s.inventory[skuId].stock;
    if (need > 0) s = reduce(s, { type: 'restock', sku: skuId, qty: need });
  }
  return s;
}

/** Open → tick the whole night, serving the wanted SKU if in stock (else wave off) → close. */
export function playNight(s0: SpatiState, dtMs = 1000): SpatiState {
  let s = reduce(s0, { type: 'openNight' });
  let guard = 0;
  while (s.phase === 'night' && guard++ < 100_000) {
    s = reduce(s, { type: 'tick', dtMs });
    const lv = legalView(s);
    if (lv.hasActive) {
      // A competent, honest shopkeeper serves the want if stocked — but refuses underage restricted sales
      // (the Integrity beat). The dark-path sweeps still drive Integrity down via the illegal "extra menu".
      s = (lv.activeWantInStock && !lv.activeIllegalSale)
        ? reduce(s, { type: 'serveActive', give: [lv.activeWant!] })
        : reduce(s, { type: 'skipActive' });
    }
    if (s.clockMs >= s.config.nightLenMs && !s.active && s.queue.length === 0 && s.nextArrival >= s.arrivals.length) break;
  }
  return reduce(s, { type: 'closeNight' });
}

export interface SeasonResult {
  survived: boolean;
  days: number;
  endCash: number;
  kiez: number;
  integrity: number;
  totalProfit: number;
  final: SpatiState;
}

/** Optional shopkeeper strategy knobs — used by the balance sweeps to exercise the risk systems. Default
 *  (no policy) = the fair-pricing, no-upgrades, weekdays-only baseline the determinism/season tests rely on. */
export interface SeasonPolicy {
  markup?: number;
  openSundays?: boolean; // take the Sunday/Ordnungsamt gamble
  buyDarkPath?: boolean; // buy the illegal "extra menu" as soon as it's available/affordable
  buySecurity?: boolean; // buy the security cam (buys down raid/risk odds)
}

export function playSeason(s0: SpatiState, policy: SeasonPolicy = {}): SeasonResult {
  const markup = policy.markup ?? 2.5;
  let s = s0;
  let totalProfit = 0;
  let guard = 0;
  while (s.phase !== 'end' && guard++ < 1000) {
    if (s.phase === 'manage') {
      if (policy.openSundays && !s.openSunday) s = reduce(s, { type: 'setSundayOpen', open: true });
      if (policy.buySecurity) s = reduce(s, { type: 'buyUpgrade', id: 'security' }); // no-op until available/affordable
      if (policy.buyDarkPath) s = reduce(s, { type: 'buyUpgrade', id: 'extra_menu' });
      s = manage(s, markup);
    }
    if (s.phase === 'manage') s = playNight(s);
    if (s.phase === 'summary') {
      totalProfit += s.summaries[s.summaries.length - 1].profit;
      s = reduce(s, { type: 'advanceDay' });
    }
  }
  return {
    survived: s.cash >= 0,
    days: s.day,
    endCash: round2(s.cash),
    kiez: s.reputation.kiez,
    integrity: s.reputation.integrity,
    totalProfit: round2(totalProfit),
    final: s,
  };
}
