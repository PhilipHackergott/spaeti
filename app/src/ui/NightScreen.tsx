import { useEffect, useRef, useState } from 'react';
import { useGame } from '../state/store';
import { SKU_BY_ID, legalView } from '../engine';
import { SceneStage } from '../render/SceneStage';
import { useUI } from './uiStore';
import { audio } from '../audio/sound';

const fmtClock = (ms: number) => {
  const tot = Math.floor(ms / 1000);
  return `${String(Math.floor(tot / 60)).padStart(2, '0')}:${String(tot % 60).padStart(2, '0')}`;
};

export function NightScreen() {
  const s = useGame((g) => g.s);
  const [paused, setPaused] = useState(false);
  const [speed, setSpeed] = useState(2); // gentle real-time, 2× by default for playtesting
  const pausedRef = useRef(paused); pausedRef.current = paused;
  const speedRef = useRef(speed); speedRef.current = speed;

  // Real-time tick driver — advances the night clock; serving is the player's clicks (below).
  useEffect(() => {
    let raf = 0;
    let last = performance.now();
    const frame = (now: number) => {
      const dt = Math.min(120, now - last);
      last = now;
      const g = useGame.getState();
      // Freeze the clock while a story beat or any shell overlay (pause/settings) is up.
      const blocked = useUI.getState().overlay !== 'none' || g.s.story.pending != null || g.s.story.pendingVignette != null;
      if (g.s.phase === 'night' && !pausedRef.current && !blocked && g.s.clockMs < g.s.config.nightLenMs) {
        g.dispatch({ type: 'tick', dtMs: dt * speedRef.current });
      }
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, []);

  const active = s.active;
  const lv = legalView(s);
  const wantInStock = active ? (s.inventory[active.want]?.stock ?? 0) > 0 : false;
  const wantDef = active ? SKU_BY_ID[active.want] : null;
  const wantPrice = active ? s.inventory[active.want]?.price : 0;
  const nightDone = s.clockMs >= s.config.nightLenMs && !s.active && s.queue.length === 0 && s.nextArrival >= s.arrivals.length;
  const dispatch = useGame((g) => g.dispatch);

  return (
    <div className="card">
      <div style={{ display: 'flex', gap: 16, alignItems: 'center', marginBottom: 10 }}>
        <span className="big" style={{ fontSize: 22 }}>{fmtClock(s.clockMs)}</span>
        <span className="subtle">/ {fmtClock(s.config.nightLenMs)}</span>
        <span className="subtle">queue: {s.queue.length} · served: {s.tally.sales} · lost: {s.tally.lost}</span>
        <button onClick={() => setPaused((p) => !p)}>{paused ? '▶ Resume' : '⏸ Pause'}</button>
        <button onClick={() => setSpeed((x) => (x >= 8 ? 1 : x * 2))}>{speed}×</button>
      </div>

      <SceneStage s={s} />

      <div className="serve">
        {active ? (
          <>
            <span style={{ alignSelf: 'center' }}>
              Wants <b>{wantDef?.name}</b> (€{wantPrice?.toFixed(2)})
              {lv.activeIllegalSale && <span className="tag locked" style={{ marginLeft: 8 }}>🔞 looks underage · ID?</span>}
            </span>
            <button className={lv.activeIllegalSale ? '' : 'btn-primary'} disabled={!wantInStock}
              title={lv.activeIllegalSale ? 'Selling a restricted item to a minor — Integrity hit' : undefined}
              onClick={() => { audio.sfx(lv.activeIllegalSale ? 'error' : 'coin'); dispatch({ type: 'serveActive', give: [active.want] }); }}>
              {wantInStock ? `Sell €${wantPrice?.toFixed(2)}${lv.activeIllegalSale ? ' ⚠' : ''}` : 'Out of stock'}
            </button>
            <button disabled={!wantInStock} onClick={() => { audio.sfx('clink'); dispatch({ type: 'serveActive', give: [active.want], pfandBottles: 1 }); }}>Sell + take 1 Pfand</button>
            <button onClick={() => { audio.sfx('click'); dispatch({ type: 'skipActive' }); }}>Wave off</button>
          </>
        ) : (
          <span className="subtle">{nightDone ? 'The night is over.' : 'Quiet for a moment…'}</span>
        )}
        <button style={{ marginLeft: 'auto' }} className={nightDone ? 'btn-primary' : ''} onClick={() => { audio.sfx('register'); dispatch({ type: 'closeNight' }); }}>
          Close up
        </button>
      </div>

      <div className="log" style={{ marginTop: 12 }}>
        {s.log.slice(-6).map((l, i) => <div key={i}>{l.text}</div>)}
      </div>
    </div>
  );
}
