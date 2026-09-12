import type { SpatiState } from './types';
import { STRANDS } from './content/story';

export type Ending = 'institution' | 'held' | 'soldout' | 'pushedout';
export interface Finale {
  ending: Ending;
  title: string;
  line: string;
  epilogues: { character: string; line: string }[]; // the tapestry — only characters you met + resolved
}

const ENDING_TEXT: Record<Ending, { title: string; line: string }> = {
  institution: { title: 'An Institution', line: 'Solvent and beloved — the Späti is the heart of the Kiez, and you belong here. Cem would be proud.' },
  held: { title: 'Held the Line', line: 'Scarred and a little broke, but the doors are open and the Kiez is intact. You stayed.' },
  soldout: { title: 'Sold Out', line: 'You made the money. Cem\'s corner is someone else\'s show-flat now, and the nights are quiet wherever you are.' },
  pushedout: { title: 'Pushed Out', line: 'The till ran dry and the lights went off.' },
};

export function pickEnding(s: SpatiState): Ending {
  if (s.cash < 0) return 'pushedout';
  if (s.story.mainOutcome === 'sell' || s.reputation.integrity < 40) return 'soldout';
  if (s.reputation.kiez >= 65 && (s.story.mainOutcome === 'stand' || s.reputation.kiez >= 78)) return 'institution';
  return 'held';
}

/** The ending tapestry (narrative-design §6b): the main ending + an epilogue for every character you met. */
export function resolveFinale(s: SpatiState): Finale {
  const ending = pickEnding(s);
  const { title, line } = ENDING_TEXT[ending];
  const epilogues: Finale['epilogues'] = [];
  for (const st of STRANDS) {
    if (st.id === 'main') continue;
    const p = s.story.strands[st.id];
    if (!p || !p.outcome || !s.story.met.includes(st.character)) continue;
    const epi = st.epilogue[ending]?.[p.outcome];
    if (epi) epilogues.push({ character: st.character, line: epi });
  }
  return { ending, title, line, epilogues };
}
