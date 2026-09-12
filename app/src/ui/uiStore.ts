import { create } from 'zustand';

export type Overlay = 'none' | 'pause' | 'settings' | 'rules';
const RM = 'spaeti_reduce_motion';

function loadRM(): boolean { try { return localStorage.getItem(RM) === '1'; } catch { return false; } }
function applyRM(v: boolean): void { try { document.body.classList.toggle('reduce-motion', v); } catch { /* ignore */ } }

interface UIState {
  overlay: Overlay;
  reduceMotion: boolean;
  open: (o: Overlay) => void;
  close: () => void;
  toggleReduceMotion: () => void;
}

export const useUI = create<UIState>((set, get) => ({
  overlay: 'none',
  reduceMotion: loadRM(),
  open: (o) => set({ overlay: o }),
  close: () => set({ overlay: 'none' }),
  toggleReduceMotion: () => {
    const v = !get().reduceMotion;
    try { localStorage.setItem(RM, v ? '1' : '0'); } catch { /* ignore */ }
    applyRM(v);
    set({ reduceMotion: v });
  },
}));

applyRM(loadRM());
