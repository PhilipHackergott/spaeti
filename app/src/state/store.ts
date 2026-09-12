import { create } from 'zustand';
import { createState, defaultConfig, pickEnding, reduce, type Action, type Difficulty, type SpatiState } from '../engine';

const SAVE = 'spaeti_save';
const HIST = 'spaeti_history';
const freshSeed = () => (Date.now() & 0x7fffffff) >>> 0;

function writeSave(s: SpatiState): void {
  try {
    if (s.phase === 'end') localStorage.removeItem(SAVE);
    else localStorage.setItem(SAVE, JSON.stringify(s));
  } catch { /* ignore */ }
}
export function loadSave(): SpatiState | null {
  try { const r = localStorage.getItem(SAVE); return r ? (JSON.parse(r) as SpatiState) : null; } catch { return null; }
}
export function hasSave(): boolean { return loadSave() != null; }

export interface HistoryEntry { ts: number; day: number; cash: number; kiez: number; ending: string; difficulty: string }
export function loadHistory(): HistoryEntry[] {
  try { const r = localStorage.getItem(HIST); return r ? (JSON.parse(r) as HistoryEntry[]) : []; } catch { return []; }
}
function pushHistory(s: SpatiState): void {
  try {
    const h = loadHistory();
    h.unshift({ ts: Date.now(), day: Math.min(s.day, s.config.seasonDays), cash: Math.round(s.cash), kiez: s.reputation.kiez, ending: pickEnding(s), difficulty: s.config.difficulty });
    localStorage.setItem(HIST, JSON.stringify(h.slice(0, 20)));
  } catch { /* ignore */ }
}

interface GameStore {
  s: SpatiState;
  dispatch: (a: Action) => void;
  newGame: (difficulty: Difficulty, seed?: number) => void;
  continueGame: () => void;
  saveNow: () => void;
}

export const useGame = create<GameStore>((set, get) => ({
  s: createState(defaultConfig('normal', freshSeed())),
  dispatch: (a) => {
    const prevPhase = get().s.phase;
    const ns = reduce(get().s, a);
    if (a.type !== 'tick') writeSave(ns); // don't thrash localStorage every animation frame
    if (ns.phase === 'end' && prevPhase !== 'end') pushHistory(ns);
    set({ s: ns });
  },
  newGame: (difficulty, seed) => {
    const ns = createState(defaultConfig(difficulty, seed ?? freshSeed()));
    writeSave(ns);
    set({ s: ns });
  },
  continueGame: () => { const sv = loadSave(); if (sv) set({ s: sv }); },
  saveNow: () => writeSave(get().s),
}));
