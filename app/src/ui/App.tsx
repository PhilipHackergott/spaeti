import { useEffect, useState } from 'react';
import type { Difficulty } from '../engine';
import { useGame, hasSave, loadHistory } from '../state/store';
import { audio } from '../audio/sound';
import { TopBar } from './TopBar';
import { ManageScreen } from './ManageScreen';
import { NightScreen } from './NightScreen';
import { SummaryScreen } from './SummaryScreen';
import { EndScreen } from './EndScreen';
import { BeatOverlay } from './BeatOverlay';
import { Overlays } from './Overlays';
import { useUI } from './uiStore';
import './theme.css';

const DIFF_NOTE: Record<Difficulty, string> = {
  cozy: 'More cash, gentle rent — to soak in the stories.',
  normal: 'A fair fight between the books and the block.',
  tight: 'Thin margins. Every Pfand counts.',
};

function Menu({ onStart, onContinue }: { onStart: (d: Difficulty) => void; onContinue: () => void }) {
  const [showHist, setShowHist] = useState(false);
  const hist = showHist ? loadHistory() : [];
  return (
    <div className="menu">
      <div className="big">SPÄTI&nbsp;SIMULATOR</div>
      <p className="subtle">
        A Berlin late-night kiosk. Run the counter, build up your shop, hear the city's stories.
        <br /><span style={{ fontSize: 12 }}>Dev build — placeholder art (HD pixel art / Coffee Talk Tokyo lands via the asset manifest).</span>
      </p>

      {hasSave() && (
        <div className="opts" style={{ marginBottom: 4 }}>
          <button className="btn-primary" onClick={onContinue}>▶ Continue</button>
        </div>
      )}

      <div className="subtle" style={{ marginTop: 14, fontSize: 12 }}>New season</div>
      <div className="opts">
        {(['cozy', 'normal', 'tight'] as Difficulty[]).map((d) => (
          <button key={d} className={d === 'normal' ? 'btn-primary' : ''} title={DIFF_NOTE[d]} onClick={() => onStart(d)}>
            {d[0].toUpperCase() + d.slice(1)}
          </button>
        ))}
      </div>
      <div className="subtle" style={{ fontSize: 11, marginTop: 6 }}>{DIFF_NOTE.normal}</div>

      <div style={{ marginTop: 18 }}>
        <button onClick={() => setShowHist((v) => !v)}>{showHist ? 'Hide' : 'Past seasons'}</button>
        {showHist && (
          <div className="history">
            {hist.length === 0 ? <div className="subtle">No finished seasons yet.</div> : hist.map((h, i) => (
              <div key={i}>
                {new Date(h.ts).toLocaleDateString()} · {h.difficulty} · day {h.day} · €{h.cash} · Kiez {h.kiez} · <b>{h.ending}</b>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

export function App() {
  const s = useGame((g) => g.s);
  const newGame = useGame((g) => g.newGame);
  const continueGame = useGame((g) => g.continueGame);
  const [view, setView] = useState<'menu' | 'game'>('menu');

  const start = (d: Difficulty) => { audio.start(); newGame(d); setView('game'); };
  const cont = () => { audio.start(); continueGame(); setView('game'); };
  const toMenu = () => { useUI.getState().close(); setView('menu'); };

  // Esc toggles the pause menu in-game (closes story beats are left to their own choices).
  useEffect(() => {
    if (view !== 'game') return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== 'Escape') return;
      const ui = useUI.getState();
      if (ui.overlay === 'none') ui.open('pause'); else ui.close();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [view]);

  if (view === 'menu') return <Menu onStart={start} onContinue={cont} />;
  return (
    <div className="app">
      <TopBar s={s} />
      {s.phase === 'manage' && <ManageScreen />}
      {s.phase === 'night' && <NightScreen />}
      {s.phase === 'summary' && <SummaryScreen />}
      {s.phase === 'end' && <EndScreen s={s} onMenu={toMenu} />}
      <BeatOverlay />
      <Overlays onQuitToMenu={toMenu} />
    </div>
  );
}
