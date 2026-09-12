# 06 — Guests, the queue, branching dialogue and the six stats (the slice's core, user decision 2026-09-12)

**What the vertical slice demonstrates:** *talking to Späti guests.* Guests arrive and **queue at the register**; you
take them **one by one**; each is a **D&D-style branching conversation** whose choices may be **gated or rolled
against the player's six stats**. No other interaction is required for the slice (the serve/till loop stays in the
engine and may remain reachable, but it is not the focus). Story volume stays small: **three regulars + one generic
one-off** are enough to prove the concept.

## 1. The player's stats (`state.player`)

```
player: { stats: { str:int, dex:int, con:int, int:int, wis:int, cha:int } }      // 8..18, default 10/11/12/13/12/14
modifier(stat) = floor((stat - 10) / 2)                                          // D&D 5e
```
Names shown in the UI: **Strength, Dexterity, Constitution, Intelligence, Wisdom, Charisma** (Strings). Some matter in
conversation (CHA persuade, WIS notice, INT reason), some in physical tasks (STR lift the crate, DEX catch the
falling bottle, CON the 3-am shift). `SpatiState.new_game(config)` seeds the defaults; a later character-creation
screen may replace them — not in this slice.

## 2. Checks (pure, seeded)

```
check = { stat:"cha", dc:13 }                              // on a choice
roll: d20 from the state's Rng (+ modifier) ≥ dc → success
result logged: { kind:"check", data:{ stat, roll, mod, dc, success } }   → the UI shows the die + total
```
A choice may instead carry `requires: { stat:"str", min:12 }` — a **gate**: shown but locked (greyed, with the
requirement) when the stat is below `min`; no roll.

## 3. Dialogue graphs (`engine/content/dialogues.gd`, data only)

```
DIALOGUES = {
  "lena": { start:"hello", nodes:{
     "hello": { speaker:"lena", expression:"neutral", lines:["Mate, bitte. …I'm fifty cents short again."],
                choices:[
                  { label:"On the house.", effects:{ kiez:+1, cash:-1.8 }, next:"thanks" },
                  { label:"[Charisma 12] Pay me in a sketch.", check:{stat:"cha", dc:12}, next:"sketch_ok", next_fail:"sketch_no" },
                  { label:"Cash only, Lena.", effects:{ kiez:-1 }, next:"" } ] },
     ... } },
  "juergen": …   (a STR 12 gate to lift his crate; a WIS check to notice he is cold),
  "mehmet":  …   (an INT check on the rent letter; a CHA check),
  "oneoff":  { start:"order", nodes:{ "order": { lines:["{want}, please."], choices:[{label:"Here you go.", next:""},{label:"We're out.", effects:{kiez:-0.5}, next:""}] } } }
}
```
`next:""` ends the conversation. `expression` per node drives the Portrait. `{want}` is substituted with the guest's
wanted SKU name. Effects use the existing reducer paths (`kiez`, `profit`, `integrity`, `cash`, `flags`).
Each regular's tree is **5–8 nodes with 2 checks/gates**; that is the whole story budget for the slice.

## 4. State, actions, view

```
state.talk = {} | { customer_id:int, dialogue_id:String, node:String, line:int, last_check:{}|{...}, history:Array[String] }
actions:  talk_next              // start with the first guest in the queue (FIFO) — the customer becomes active and talk opens
          talk_advance           // next line of the current node (or opens the choices when lines are exhausted)
          talk_choose{choice:int} // resolve: gate/roll → effects → next node (or end)
          talk_end               // (engine-internal when next=="") the guest leaves; their want is auto-served if in stock
view.queue = Array[{ customer_id, character_id, name, portrait, expression, is_story:bool }]   // everyone waiting, FIFO
view.talk  = {} | { speaker, portrait, expression, lines:Array[String], line:int, choices:Array[{ label, check:{stat,dc,mod,chance}|{}, locked:bool, reason:String }], last_check:{}|{ stat, roll, mod, dc, success } }
view.player = { stats:{...}, mods:{...} }
```
While `state.talk` is open, `legal_actions` offers only `talk_advance` / `talk_choose`. The old `resolve_beat` /
`resolve_vignette` paths route through the same graph (a beat = a one-node dialogue) so the DialogueBox has ONE source.

## 5. The register screen (Night scene) for the slice

- **The queue is visible:** small busts (or heads) of the waiting guests lined up at the right edge of the counter,
  FIFO left→right, with the one being served at the centre. A "Next guest" button (or clicking the first in line) →
  `talk_next`.
- **Conversation:** the DialogueBox shows lines; choices show their stat tag in the label (`[Charisma 12]`), locked
  gates greyed with the reason, and after a roll a small **d20 pop** with `roll + mod vs DC → success/fail`.
- **Stats panel:** a compact six-stat strip (name, value, modifier) — visible in the HUD or on a toggle (`Tab`).
- The serve panel may stay reachable but is not part of the demo path.

## 6. Tests the engine lane ships

`test_dialogue.gd`: checks are deterministic per seed; a gate locks below min; effects apply; `next:""` ends and the
guest leaves (auto-serve applied); `talk_next` is illegal with an empty queue; the queue view is FIFO and shows
portraits; a full night's playthrough with the AutoPlayer choosing choice 0 never throws.
