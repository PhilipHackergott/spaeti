import { resolveFinale, type SpatiState } from '../engine';

// The ending tapestry (narrative-design §6b): the main ending + a "where are they now" epilogue for every
// character you met, recoloured by the main ending you reached.
export function EndScreen({ s, onMenu }: { s: SpatiState; onMenu: () => void }) {
  const f = resolveFinale(s);
  return (
    <div className="menu" style={{ maxWidth: 600 }}>
      <div className="big">{f.title}</div>
      <p className="subtle">{f.line}</p>

      {f.epilogues.length > 0 && (
        <div style={{ textAlign: 'left', margin: '16px 0' }}>
          <div className="subtle" style={{ marginBottom: 6 }}>The corner, after:</div>
          {f.epilogues.map((e, i) => (
            <div className="epi" key={i}>
              <div className="who">{e.character}</div>
              <div className="what">{e.line}</div>
            </div>
          ))}
        </div>
      )}

      <div className="row"><span className="name">Days</span><span>{Math.min(s.day, s.config.seasonDays)}/{s.config.seasonDays}</span></div>
      <div className="row"><span className="name">Cash</span><span>€ {s.cash.toFixed(2)}</span></div>
      <div className="row"><span className="name">Kiez-Trust</span><span>{s.reputation.kiez}</span></div>
      <div className="row"><span className="name">Integrity</span><span>{s.reputation.integrity}</span></div>
      <div className="opts"><button className="btn-primary" onClick={onMenu}>New game</button></div>
    </div>
  );
}
