import { useGame } from '../state/store';
import { SKU_BY_ID, moduleOptions, cornerStatus, nightTraffic, type ModuleOption } from '../engine';
import { audio } from '../audio/sound';

function ModuleRow({ o }: { o: ModuleOption }) {
  const dispatch = useGame((g) => g.dispatch);
  const tag = o.owned ? <span className="tag owned">owned</span>
    : o.def.kind === 'decor' ? <span className="tag decor">décor</span>
    : <span className="tag">module{o.def.tier && o.def.tier > 1 ? ` ·T${o.def.tier}` : ''}</span>;
  return (
    <div className="row">
      <span className="name">{o.def.name} {tag}<br /><span className="muted">{o.def.note}</span></span>
      {o.owned ? <span className="muted">✓</span> : (
        <span style={{ textAlign: 'right' }}>
          <button className={o.available && o.affordable ? 'btn-primary' : ''} disabled={!o.available || !o.affordable}
            onClick={() => { audio.sfx('register'); dispatch({ type: 'buyUpgrade', id: o.def.id }); }}>
            € {o.def.cost}
          </button>
          <div className="muted">{!o.available ? o.reason : !o.affordable ? 'too pricey' : ''}</div>
        </span>
      )}
    </div>
  );
}

export function ManageScreen() {
  const s = useGame((g) => g.s);
  const dispatch = useGame((g) => g.dispatch);
  const opts = moduleOptions(s);
  const modules = opts.filter((o) => o.def.kind === 'module');
  const decor = opts.filter((o) => o.def.kind === 'decor');
  const corner = cornerStatus(s);

  return (
    <>
      <div className="card corner-status">
        <h2>Your corner — day {s.day}</h2>
        <div className="chips">
          <span className="chip">~{nightTraffic(s)} expected tonight</span>
          {corner.kiezPerNight > 0 && <span className="chip kiez">+{corner.kiezPerNight} Kiez/night</span>}
          {corner.systems.map((sys) => <span key={sys} className="chip kiez">{sys}</span>)}
          {corner.flags.map((f) => <span key={f} className="chip">{f}</span>)}
          {corner.heat > 0 && <span className="chip warn">Ordnungsamt heat {corner.heat}</span>}
          {corner.illegal && <span className="chip warn">⚠ Extra menu — Integrity bleeding{corner.hasSecurity ? ', cam lowers raid odds' : ', raid risk'}</span>}
        </div>
        {corner.systems.length === 0 && corner.flags.length === 0 && (
          <div className="muted" style={{ fontSize: 12 }}>Still just a till. Build community modules + welcome the regulars to turn this corner into a place.</div>
        )}
      </div>

      <div className="cols">
        <div className="card">
          <h2>Prices &amp; Stock</h2>
          {Object.entries(s.inventory).map(([id, inv]) => {
            const def = SKU_BY_ID[id];
            return (
              <div className="row" key={id}>
                <span className="name">{def?.name ?? id} <span className="muted">· stock {inv.stock}</span></span>
                <span>
                  € <input className="priceinput" type="number" step="0.1" min="0" value={inv.price}
                    onChange={(e) => dispatch({ type: 'setPrice', sku: id, price: parseFloat(e.target.value) || 0 })} />
                  <button onClick={() => { audio.sfx('click'); dispatch({ type: 'restock', sku: id, qty: 5 }); }}>+5</button>
                  <button onClick={() => { audio.sfx('click'); dispatch({ type: 'restock', sku: id, qty: 20 }); }}>+20</button>
                </span>
              </div>
            );
          })}
        </div>

        <div className="card">
          <h2>Build &amp; Customize</h2>
          <div className="muted" style={{ fontSize: 12, marginBottom: 6 }}>Grow your offering + make the place yours. New options unlock over the season.</div>
          {modules.map((o) => <ModuleRow key={o.def.id} o={o} />)}
          <h2 style={{ marginTop: 14 }}>Décor</h2>
          {decor.map((o) => <ModuleRow key={o.def.id} o={o} />)}
        </div>
      </div>

      <div className="card" style={{ marginTop: 14, display: 'flex', alignItems: 'center', gap: 16 }}>
        <label>
          <input type="checkbox" checked={s.openSunday} onChange={(e) => dispatch({ type: 'setSundayOpen', open: e.target.checked })} />
          {' '}Open Sundays <span className="muted">(big demand · Ordnungsamt fine risk)</span>
        </label>
        <button className="btn-primary" style={{ marginLeft: 'auto' }} onClick={() => { audio.sfx('door'); dispatch({ type: 'openNight' }); }}>Open tonight ▶</button>
      </div>
    </>
  );
}
