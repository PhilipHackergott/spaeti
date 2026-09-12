import type { Vignette } from '../types';

// One-off "slices of the city" — the parade of strangers who pass a Berlin Späti counter at night.
// Unlike the cast STRANDS (ongoing arcs that feed the ending tapestry), these are self-contained: a single
// scene, a small choice, a small consequence. They fire on QUIET mornings when no cast beat is due, so the
// place always feels alive without crowding the main story. Coffee-Talk tone: brief, warm, a little wry.
// Choices reuse the engine Choice type (cash/kiez/profit/integrity/flags); `next`/`outcome` are ignored.
export const VIGNETTES: Vignette[] = [
  {
    id: 'tourist_lost', afterDay: 2, speaker: 'Lost tourist',
    lines: ['"Entschuldigung — Berghain? My phone is dead." He shows you a battery icon and a hopeful smile.'],
    choices: [
      { label: 'Draw him a little map on the receipt.', kiez: 1 },
      { label: 'Sell him a charger cable for €9.', cash: 9, profit: 1, kiez: -1 },
      { label: '"No idea, sorry." (You do know.)', kiez: -0.5 },
    ],
  },
  {
    id: 'club_kids', weekday: 5, speaker: 'Club kids',
    lines: ['Three of them, glitter and big coats, on the way out. "Wasser? And gum. And… do you have plasters?"'],
    choices: [
      { label: 'Ring it all up, fair price.', cash: 6, profit: 1 },
      { label: 'Tap water\'s free — take it.', kiez: 1 },
    ],
  },
  {
    id: 'pfand_kid', afterDay: 3, speaker: 'Pfand kid',
    lines: ['A small kid heaves a clinking bag onto the counter, eyes on the sweets. "Is it enough for the gummi bears?"'],
    choices: [
      { label: 'Count every bottle, honestly.', kiez: 1, integrity: 1 },
      { label: 'Round down. Business is business.', cash: 1, profit: 1, integrity: -2 },
    ],
  },
  {
    id: 'breakup_cry', afterDay: 4, speaker: 'Heartbroken regular',
    lines: ['She buys the good ice cream and a small wine, eyes red. "He kept the flat. I kept the cat." A wet laugh.'],
    choices: [
      { label: 'Listen for a minute. Slide a tissue over.', kiez: 1, integrity: 1 },
      { label: 'Ring it up gently and let her be.', kiez: 0.5 },
    ],
  },
  {
    id: 'match_night', weekday: 5, afterDay: 5, speaker: 'Match-night crowd',
    lines: ['Union are playing. The fridge empties fast and the queue\'s out the door, scarves everywhere.'],
    choices: [
      { label: 'Hold prices — these are your people.', kiez: 1 },
      { label: 'Quietly bump the beer price tonight.', cash: 8, profit: 2, kiez: -2 },
    ],
  },
  {
    id: 'drunk_one_more', afterDay: 4, speaker: 'Last-call regular',
    lines: ['He sways at the counter. "One more Sterni, Chef. Just one." His keys are already on the floor and he hasn\'t noticed.'],
    choices: [
      { label: 'Cut him off; call him a taxi.', kiez: 1, integrity: 2 },
      { label: 'Sell it. Not your business.', cash: 2, integrity: -2 },
    ],
  },
  {
    id: 'flyers_up', afterDay: 5, speaker: 'Promoter',
    lines: ['"Can I put these up? Small night, friends\' band, nothing big." A fistful of risograph flyers.'],
    choices: [
      { label: 'Sure — the window\'s the Kiez\'s noticeboard.', kiez: 1, flags: ['flyers_up'] },
      { label: '"I just cleaned the glass."', kiez: -1 },
    ],
  },
  {
    id: 'old_friends', afterDay: 6, minKiez: 35, speaker: 'Cem\'s old friends',
    lines: ['Two old men linger by the counter. "We played Skat with your uncle. Right there, that crate was the table."', 'They look at you, then at the place, like they\'re checking it\'s still standing.'],
    choices: [
      { label: 'Pull up two crates. Hear the stories.', kiez: 1, integrity: 1 },
      { label: 'Smile, but you\'re slammed tonight.', kiez: -0.5 },
    ],
  },
  {
    id: 'delivery_mixup', afterDay: 7, speaker: 'Wholesaler note',
    lines: ['The morning crate has two extra cases nobody billed you for. The driver\'s long gone.'],
    choices: [
      { label: 'Call it in — that\'s someone\'s mistake.', integrity: 2, kiez: 0.5 },
      { label: 'Shelf it quietly. Free margin.', cash: 14, profit: 1, integrity: -3 },
    ],
  },
  {
    id: 'beat_cop', afterDay: 6, speaker: 'Beat cop',
    lines: ['The neighbourhood Polizistin leans in out of the drizzle. "Quiet night? Cem always had a coffee on for me."'],
    choices: [
      { label: 'Pour her one, on the house.', cash: -1, kiez: 1, integrity: 1 },
      { label: '"Machine\'s off. Sorry, Frau Wachtmeisterin."', kiez: -0.5 },
    ],
  },
  {
    id: 'cold_outside', afterDay: 12, speaker: 'Someone in the cold',
    lines: ['It\'s below zero. A figure stands in the doorway warmth a beat too long, not buying, not leaving.'],
    choices: [
      { label: 'Hot drink, no charge. Stay as long as you like.', cash: -1, kiez: 2, integrity: 2 },
      { label: '"Customers only." Nod at the door.', kiez: -2, integrity: -2 },
    ],
  },
  {
    id: 'busker', afterDay: 8, minKiez: 40, speaker: 'Street musician',
    lines: ['A busker with a battered guitar tilts his head at the bench out front. "Mind if I play a few? People stop, people buy."'],
    choices: [
      { label: 'Go on — give the corner a soundtrack.', kiez: 1, flags: ['busker'] },
      { label: '"Neighbours\'ll complain." Wave him on.', kiez: -0.5 },
    ],
  },
  {
    id: 'student_exam', afterDay: 9, speaker: 'Exam-week student',
    lines: ['Red-eyed, third Mate of the night. "If I fail statistics I\'m moving back to Schwaben. Wish me luck, ja?"'],
    choices: [
      { label: '"Toi toi toi." Throw in a chocolate.', cash: -1, kiez: 1 },
      { label: 'Ring up the Mate. "Viel Erfolg."', cash: 2, profit: 0.5 },
    ],
  },
  {
    id: 'drunk_philosopher', afterDay: 4, speaker: 'Late-night philosopher',
    lines: ['He gestures with a Sterni at the night. "A Späti, my friend, is the last truly democratic space in Berlin. Rich, poor, all thirsty at 3am. Discuss."'],
    choices: [
      { label: '"Profound. That\'ll be €2.40."', cash: 2.4, profit: 0.5 },
      { label: 'Lean in and argue the point.', kiez: 1 },
    ],
  },
  {
    id: 'proposal_5am', afterDay: 8, speaker: 'Trembling romantic',
    lines: ['"Okay okay — I\'m proposing. Tonight. Here, kind of. Do you have anything that looks like champagne and isn\'t twelve euros?"'],
    choices: [
      { label: 'Find the fanciest Sekt; chill two cups, on the house.', cash: -2, kiez: 2, integrity: 1 },
      { label: 'Sell the Sekt. "Viel Glück." Mean it.', cash: 6, profit: 1 },
    ],
  },
  {
    id: 'wedding_guest', afterDay: 6, speaker: 'Lost wedding guest',
    lines: ['A man in a rumpled suit, boutonnière wilting. "I have lost the wedding. The whole wedding. Also my phone. Also, possibly, my shoes."'],
    choices: [
      { label: 'Let him charge his phone behind the counter.', kiez: 1 },
      { label: 'Sell him flip-flops and a water. Godspeed.', cash: 5, profit: 1 },
    ],
  },
  {
    id: 'film_crew', afterDay: 12, minKiez: 45, speaker: 'Location scout',
    lines: ['Clipboard, lanyard, espresso breath. "Love the GRIT here. We\'d shoot two nights, you close to the public, we pay — and you\'re basically in a film. Très authentic."'],
    choices: [
      { label: '"This corner\'s for the Kiez, not a backdrop." Decline.', kiez: 2 },
      { label: 'Take the location fee; close for two nights.', cash: 40, profit: 1, kiez: -2 },
    ],
  },
  {
    id: 'pigeon_situation', afterDay: 3, speaker: 'The pigeon situation',
    lines: ['A pigeon has entered. It is not leaving. It has, in fact, opinions about the Schrippe basket. A small crowd gathers to advise.'],
    choices: [
      { label: 'Calmly shepherd it out with a newspaper. A local hero.', kiez: 1 },
      { label: 'Sell snacks to the crowd while the drama unfolds.', cash: 4, profit: 1 },
    ],
  },
  {
    id: 'power_cut', afterDay: 14, speaker: 'Stromausfall',
    lines: ['The whole block goes dark. For a moment, silence — then someone in the queue starts humming, and the candle-phones come out. The fridge ticks, warming.'],
    choices: [
      { label: 'Hand out candles; let the sing-along happen.', cash: -1, kiez: 2, integrity: 1 },
      { label: 'Sell torches and warm beer at a markup. Survival.', cash: 8, profit: 1, kiez: -1 },
    ],
  },
  {
    id: 'influencer', afterDay: 9, speaker: '"Realness" influencer',
    lines: ['Ring light up, narrating to her phone: "…and THIS is the real, undiscovered Berlin, you guys—" She turns. "Can you say something authentic? For the content?"'],
    choices: [
      { label: '"We\'re a späti. We sell beer. Bitte." (She loves it.)', kiez: 1, profit: 0.5 },
      { label: 'Pose, plug the shop, ride the algorithm.', cash: 3, profit: 1, kiez: -1 },
    ],
  },
  {
    id: 'wendekind', afterDay: 16, speaker: 'Two Berlins',
    lines: ['An older man stares a long time at the street. "I grew up on the other side of where the Wall ran. Right there." He points at nothing anyone else can see. "Sometimes I still feel it."'],
    choices: [
      { label: 'Pour a coffee and just listen.', cash: -1, kiez: 1, integrity: 1 },
      { label: '"Different times now." Ring him up gently.', cash: 2 },
    ],
  },
];

export const VIGNETTE_BY_ID: Record<string, Vignette> = Object.fromEntries(VIGNETTES.map((v) => [v.id, v]));
