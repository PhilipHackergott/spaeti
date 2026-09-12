import { useState } from 'react';
import { useGame } from '../state/store';
import { STRAND_BY_ID, VIGNETTE_BY_ID } from '../engine';
import { audio } from '../audio/sound';
import { portraitFor, assetUrl } from '../assets/manifest';

// The dialogue box (Coffee-Talk style placeholder). Shows whenever a story beat OR a one-off city vignette
// is pending, and blocks the game until the player chooses. Portrait is a placeholder until Gemini art lands.
export function BeatOverlay() {
  const s = useGame((g) => g.s);
  const dispatch = useGame((g) => g.dispatch);

  // A cast strand beat takes precedence over a one-off vignette (they're never both set, but be explicit).
  const pend = s.story.pending;
  if (pend) {
    const strand = STRAND_BY_ID[pend.strand];
    const cur = s.story.strands[pend.strand]?.cur;
    const beat = strand && cur ? strand.beats[cur] : undefined;
    if (!beat) return null;
    return (
      <Scene speaker={beat.speaker} lines={beat.lines}
        choices={beat.choices.map((c) => c.label)}
        onChoose={(i) => { audio.sfx('beat'); dispatch({ type: 'resolveBeat', choice: i }); }} />
    );
  }

  const vid = s.story.pendingVignette;
  if (vid) {
    const v = VIGNETTE_BY_ID[vid];
    if (!v) return null;
    return (
      <Scene speaker={v.speaker} lines={v.lines} tag="passing by"
        choices={v.choices.map((c) => c.label)}
        onChoose={(i) => { audio.sfx('beat'); dispatch({ type: 'resolveVignette', choice: i }); }} />
    );
  }

  return null;
}

// Portrait slot: the cast PNG when present (manifest seam), else a procedural initials avatar. Vignette
// strangers have no portrait id, so they always show the avatar — fine for one-off faces.
function Portrait({ speaker }: { speaker: string }) {
  const id = portraitFor(speaker);
  const [broken, setBroken] = useState(false);
  if (id && !broken) {
    return (
      <div className="beat-portrait">
        <img src={assetUrl(id)} alt={speaker} onError={() => setBroken(true)} />
      </div>
    );
  }
  const initials = speaker.replace(/[^A-Za-zÄÖÜäöü ]/g, '').split(' ').filter(Boolean).slice(0, 2).map((w) => w[0]).join('').toUpperCase() || '…';
  let h = 0; for (let i = 0; i < speaker.length; i++) h = (h * 31 + speaker.charCodeAt(i)) >>> 0;
  const hue = ['#8a6a44', '#6a5d92', '#4fa24f', '#c89a3a', '#6fb8e0', '#e05a8a'][h % 6];
  return <div className="beat-portrait"><div className="beat-avatar" style={{ background: hue }}>{initials}</div></div>;
}

function Scene({ speaker, lines, choices, onChoose, tag }: {
  speaker: string; lines: string[]; choices: string[]; onChoose: (i: number) => void; tag?: string;
}) {
  return (
    <div className="beat-backdrop">
      <Portrait speaker={speaker} />
      <div className="beat-box">
        <div className="beat-speaker">{speaker}{tag && <span className="beat-tag"> · {tag}</span>}</div>
        {lines.map((l, i) => <p key={i} className="beat-line">{l}</p>)}
        <div className="beat-choices">
          {choices.map((label, i) => (
            <button key={i} className="btn-primary" onClick={() => onChoose(i)}>{label}</button>
          ))}
        </div>
      </div>
    </div>
  );
}
