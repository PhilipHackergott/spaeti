import type { SpatiState } from './types';
import { ARCHETYPE_BY_ID } from './content/customers';
import { SKU_BY_ID } from './content/skus';

/** What the UI/AI may do right now. Kept small; the reducer is the source of truth. */
export interface LegalView {
  canOpenNight: boolean;
  canCloseNight: boolean;
  canAdvanceDay: boolean;
  inNight: boolean;
  hasActive: boolean;
  /** SKUs currently in stock (servable). */
  inStock: string[];
  /** the active customer's wanted SKU, if any. */
  activeWant: string | null;
  activeWantInStock: boolean;
  activeUnderage: boolean; // the customer looks underage
  activeWantRestricted: boolean; // the wanted SKU is age-restricted (alcohol/tobacco/vape)
  /** selling the wanted item would be an underage restricted sale — the Integrity beat */
  activeIllegalSale: boolean;
}

export function legalView(s: SpatiState): LegalView {
  const inStock = Object.entries(s.inventory).filter(([, v]) => v.stock > 0).map(([id]) => id);
  const want = s.active?.want ?? null;
  const arch = s.active ? ARCHETYPE_BY_ID[s.active.archetypeId] : null;
  const wantDef = want ? SKU_BY_ID[want] : null;
  const underage = !!arch?.underage;
  const restricted = !!wantDef?.restricted;
  return {
    canOpenNight: s.phase === 'manage',
    canCloseNight: s.phase === 'night',
    canAdvanceDay: s.phase === 'summary',
    inNight: s.phase === 'night',
    hasActive: !!s.active,
    inStock,
    activeWant: want,
    activeWantInStock: want != null && (s.inventory[want]?.stock ?? 0) > 0,
    activeUnderage: underage,
    activeWantRestricted: restricted,
    activeIllegalSale: underage && restricted,
  };
}
