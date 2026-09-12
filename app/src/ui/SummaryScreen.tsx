import { useGame } from '../state/store';
import { audio } from '../audio/sound';

export function SummaryScreen() {
  const s = useGame((g) => g.s);
  const dispatch = useGame((g) => g.dispatch);
  const sum = s.summaries[s.summaries.length - 1];
  if (!sum) return null;
  const Line = ({ k, v, good }: { k: string; v: string; good?: boolean }) => (
    <div className="row"><span className="name">{k}</span><span style={{ color: good === undefined ? undefined : good ? 'var(--kiez)' : 'var(--warn)' }}>{v}</span></div>
  );
  return (
    <div className="card" style={{ maxWidth: 460, margin: '24px auto' }}>
      <h2>Night {sum.day} — closing up</h2>
      <Line k="Revenue" v={`€ ${sum.revenue.toFixed(2)}`} />
      <Line k="Tips" v={`€ ${sum.tips.toFixed(2)}`} />
      <Line k="Cost of goods" v={`− € ${sum.cogs.toFixed(2)}`} />
      <Line k="Rent / fines" v={`− € ${sum.billsDue.toFixed(2)}`} />
      <Line k="Pfand paid out" v={`− € ${sum.pfandPaid.toFixed(2)}`} />
      <Line k="Profit" v={`€ ${sum.profit.toFixed(2)}`} good={sum.profit >= 0} />
      <Line k="Sales / lost" v={`${sum.sales} / ${sum.lost}`} />
      <Line k="Cash" v={`€ ${sum.cashAfter.toFixed(2)}`} good={sum.cashAfter >= 0} />
      <div className="center" style={{ marginTop: 14 }}>
        <button className="btn-primary" onClick={() => { audio.sfx('click'); dispatch({ type: 'advanceDay' }); }}>Continue →</button>
      </div>
    </div>
  );
}
