import type { SpatiState } from '../engine';
import { actOf } from '../engine';
import { useUI } from './uiStore';

const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

function Meter({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <span className="meter">
      {label} <span className="bar"><i style={{ width: `${Math.max(0, Math.min(100, value))}%`, background: color }} /></span>
    </span>
  );
}

export function TopBar({ s }: { s: SpatiState }) {
  const openMenu = useUI((u) => u.open);
  const heat = s.ordnungsamtHeat ?? 0;
  return (
    <div className="topbar">
      <span className="title">SPÄTI</span>
      <span className="stat">Day {s.day}/{s.config.seasonDays} · {WEEKDAYS[s.weekday]} · <span className="muted">{actOf(s)}</span></span>
      <span className="stat">€ {s.cash.toFixed(2)}</span>
      <span className="meters">
        <Meter label="Kiez" value={s.reputation.kiez} color="var(--kiez)" />
        <Meter label="Profit" value={s.reputation.profit} color="var(--profit)" />
        <Meter label="Integrity" value={s.reputation.integrity} color="var(--integ)" />
      </span>
      {heat > 0 && <span className="heat" title="Ordnungsamt attention — Sunday/late trading risk">⚠ Heat {heat}</span>}
      <span className="muted">{s.config.difficulty}</span>
      <button className="menu-btn" style={{ marginLeft: 'auto' }} onClick={() => openMenu('pause')} title="Menu / pause">☰</button>
    </div>
  );
}
