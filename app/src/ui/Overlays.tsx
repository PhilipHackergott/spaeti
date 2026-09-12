import { useState } from 'react';
import { useUI } from './uiStore';
import { useGame } from '../state/store';
import { audio } from '../audio/sound';

function Panel({ title, children, onClose }: { title: string; children: React.ReactNode; onClose: () => void }) {
  return (
    <div className="overlay">
      <div className="overlay-box">
        <div className="overlay-head"><h2>{title}</h2><button onClick={onClose}>✕</button></div>
        {children}
      </div>
    </div>
  );
}

function SettingsPanel() {
  const ui = useUI();
  const [m, setM] = useState(audio.settings.musicVol);
  const [s, setS] = useState(audio.settings.sfxVol);
  const [muted, setMuted] = useState(audio.settings.muted);
  return (
    <Panel title="Settings" onClose={() => ui.open('pause')}>
      <div className="row"><span className="name">Music</span>
        <input type="range" min="0" max="1" step="0.05" value={m} onChange={(e) => { const v = +e.target.value; setM(v); audio.setMusicVol(v); }} /></div>
      <div className="row"><span className="name">SFX</span>
        <input type="range" min="0" max="1" step="0.05" value={s} onChange={(e) => { const v = +e.target.value; setS(v); audio.setSfxVol(v); audio.sfx('click'); }} /></div>
      <div className="row"><span className="name">Mute all</span>
        <input type="checkbox" checked={muted} onChange={(e) => { setMuted(e.target.checked); audio.setMuted(e.target.checked); }} /></div>
      <div className="row"><span className="name">Reduce motion</span>
        <input type="checkbox" checked={ui.reduceMotion} onChange={() => ui.toggleReduceMotion()} /></div>
    </Panel>
  );
}

function RulesPanel() {
  const ui = useUI();
  return (
    <Panel title="How a Späti works" onClose={() => ui.open('pause')}>
      <p className="subtle">You run a Berlin late-night kiosk over one season.</p>
      <ul style={{ fontSize: 13, lineHeight: 1.6, color: 'var(--text)' }}>
        <li><b>Manage</b> (between nights): set prices, restock, and <b>Build &amp; Customize</b> your shop (new modules + décor unlock over time). Choose whether to open Sundays (big demand, Ordnungsamt fine risk).</li>
        <li><b>Night</b>: customers arrive — serve the one at the counter what they want, take Pfand, keep them happy. Watch the clock, queue, and your cash.</li>
        <li><b>Reputation</b>: <span style={{ color: 'var(--kiez)' }}>Kiez-Trust</span> (community), <span style={{ color: 'var(--profit)' }}>Profit</span>, <span style={{ color: 'var(--integ)' }}>Integrity</span>. Fair prices + kindness build trust; gouging and cutting corners cost it.</li>
        <li><b>Story</b>: regulars and the neighbourhood's fate play out in morning conversations. Your choices — and how you ran the place — decide the ending and what becomes of everyone.</li>
      </ul>
    </Panel>
  );
}

export function Overlays({ onQuitToMenu }: { onQuitToMenu: () => void }) {
  const ui = useUI();
  const saveNow = useGame((g) => g.saveNow);
  if (ui.overlay === 'none') return null;
  if (ui.overlay === 'settings') return <SettingsPanel />;
  if (ui.overlay === 'rules') return <RulesPanel />;
  // pause
  return (
    <Panel title="Paused" onClose={() => ui.close()}>
      <div className="overlay-opts">
        <button className="btn-primary" onClick={() => ui.close()}>Resume</button>
        <button onClick={() => ui.open('settings')}>Settings</button>
        <button onClick={() => ui.open('rules')}>How to play</button>
        <button onClick={() => { saveNow(); ui.close(); onQuitToMenu(); }}>Save &amp; quit</button>
        <button onClick={() => { ui.close(); onQuitToMenu(); }}>Abandon to menu</button>
      </div>
    </Panel>
  );
}
