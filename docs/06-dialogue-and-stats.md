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
Names shown in the UI (the Späti-flavoured set, §7): **Muscle** (str) · **Hands** (dex) · **Stamina** (con) ·
**Brains** (int) · **Kiez Sense** (wis) · **Schnauze** (cha) — `Strings.STAT_NAMES` and `Rules.STAT_NAMES`, kept
identical by `test_scenes.gd::test_the_two_stat_tables_agree`. The ids stay D&D so the mechanics read as 5e. Some
matter in conversation (Schnauze persuade, Kiez Sense notice, Brains reason), some in physical tasks (Muscle lifts
the crate, Hands catch the falling bottle, Stamina is the 3-am shift). `SpatiState.new_game(config)` seeds the defaults; a later character-creation
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
const DATA: Dictionary = {                       # re-exported as Content.DIALOGUES
  "lena": { start:"hello", nodes:{
     "hello": { speaker:"lena", expression:"neutral", lines:["Mate, bitte. …I'm fifty cents short again."],
                choices:[
                  { label:"On the house.", effects:{ kiez:+1, cash:-1.8 }, next:"thanks" },
                  { label:"[Schnauze 12] Pay me in a sketch.", check:{stat:"cha", dc:12}, next:"sketch_ok", next_fail:"sketch_no" },
                  { label:"Cash only, Lena.", effects:{ kiez:-1 }, next:"" } ] },
     ... } },
  "juergen": …   (a STR 12 gate to lift his crate; a WIS check to notice he is cold),
  "mehmet":  …   (an INT check on the rent letter; a CHA check),
  "oneoff":  { start:"order", nodes:{ "order": { lines:["{want}, please."], choices:[{label:"Here you go.", next:""},{label:"We're out.", effects:{kiez:-0.5}, next:"", serve:false}] } } },
  "oneoff_minor": … (the same parade, under age, asking for something restricted: "Ausweis, bitte." or sell it anyway)
}
```
`next:""` ends the conversation. A choice may also carry `serve:false` — the guest then leaves **without** the
auto-serve (you turned them away) — or `sell_restricted:true`, which is the one line that knowingly sells a
restricted SKU to a minor (it routes through the ordinary serve: −8 Integrity and an `ethics` log entry, exactly
like `serve_active`). `expression` per node drives the Portrait. `{want}` is substituted with the guest's
wanted SKU name. Effects use the existing reducer paths (`kiez`, `profit`, `integrity`, `cash`, `flags`).
Each regular's tree is **5–8 nodes with 2 checks/gates**; that is the whole story budget for the slice.

## 4. State, actions, view

```
state.talk = {} | { customer_id:int, dialogue_id:String, node:String, line:int, last_check:{}|{...}, history:Array[String] }
actions:  talk_next              // start with the first guest in the queue (FIFO) — the customer becomes active and talk opens
          talk_advance           // next line of the current node (or opens the choices when lines are exhausted)
          talk_choose{choice:int} // resolve: gate/roll → effects → next node (or end)
          talk_end               // (engine-internal when next=="") ends the conversation. The guest leaves and their
                                 //   want is auto-served ONLY IF THEY HAVE NO BASKET — the nameless parade, the
                                 //   serve-loop sims, `config.auto_take_next`. A guest whose basket is on the counter
                                 //   STAYS STANDING: the talk ending is the sale starting, and the register is the
                                 //   serve (docs/08 §1, docs/05 §10.4). Leaving the old behaviour in place meant every
                                 //   authored tree rang itself up and the register was unreachable for the whole cast.
view.queue = Array[{ customer_id, character_id, name, portrait, expression, is_story:bool }]   // everyone waiting, FIFO
view.talk  = {} | { speaker, portrait, expression, lines:Array[String], line:int, choices:Array[{ label, check:{stat,dc,mod,chance}|{}, locked:bool, reason:String }], last_check:{}|{ stat, roll, mod, dc, success } }
view.player = { stats:{...}, mods:{...} }
```
While `state.talk` is open, `legal_actions` offers only `talk_advance` / `talk_choose`. The old `resolve_beat` /
`resolve_vignette` paths route through the same graph (a beat = a one-node dialogue) so the DialogueBox has ONE source.

### Tokens in an authored line (docs/09 §0)

`Talk.node_of` substitutes into BOTH the node's `lines` and each choice's `label`, from one map built once per node by
`Talk.subs_for(s)`. Substitution is **per BASKET LINE**, not per character — Achim orders three different tobacco
products in one breath and a single `habits.brand` field cannot serve that sentence:

| token | resolves to | via |
|---|---|---|
| `{want}` | the SKU the guest came in for — the original, still what a plain order says | `Talk.want_name_of` |
| `{qty.<sku>}` | how many of that line she asked for | the basket row |
| `{brand.<sku>}` | the noun phrase she SAYS — "Drei Ringe tobacco", "long Feder papers" | `Content.brand_spoken` |
| `{logo.<sku>}` | the facing's **ASSET ID** — an inline mark GLYPH, never spoken text | `Content.brand_logo` |

Three rules the authored lines obey, each of which has already been broken once:

1. **`spoken` is a whole noun phrase, not a bare name.** `long {brand.papers}` renders "long long Feder papers". Write
   `{brand.papers}` and let the catalogue carry the length.
2. **`{logo.*}` is a picture.** It resolves to `tob/pack_fuchs`, so the **DialogueBox draws it** as a 16×16 `BrandMark`
   in the middle of the sentence (docs/04). A box that printed it instead put an asset id into four of the cast's
   order lines.
3. **A token whose basket line does not exist is left ALONE, not blanked** — so a tree is never *broken* by a basket
   that lacks the SKU, it just prints `{brand.filters}` onto the counter at 03:00. `test_tokens.gd` is what fails the
   build for that, and `::test_no_token_survives_to_the_screen` is the one that checks the REAL `Rules.view` rather
   than the authored table: the reducer's 4-line basket cap can truncate away the very row a line speaks about.

`Content.brand_phrase(id)` is the fourth accessor, added with the `mark` speech tier: the article-free logo phrase
("eagle", "fox", "cream booklet") that fills `Strings.ASK_MARK_PHRASE`. It has no token of its own — it is what the
ENGINE composes `order[i].said` from, not something an author writes into a line.

## 5. The register screen (Night scene) for the slice

- **The queue is visible:** small busts (or heads) of the waiting guests lined up at the right edge of the counter,
  FIFO left→right, with the one being served at the centre. A "Next guest" button (or clicking the first in line) →
  `talk_next`.
- **Conversation:** the DialogueBox shows lines; choices show their stat tag in the label (`[Schnauze 12]`), locked
  gates greyed with the reason, and after a roll a small **d20 pop** with `roll + mod vs DC → success/fail`.
- **Stats panel:** a compact six-stat strip (name, value, modifier) — visible in the HUD or on a toggle (`Tab`).
- The serve panel is **off the shipped screen** since docs/08 §3.6: the demo path is the REGISTER (scan → wall →
  ring up), and `ServePanel` / `Shelf` / `Till` are a `play.mjs --serve` debug affordance so they never rot untested.

## 6. Tests the engine lane ships

`test_dialogue.gd`: checks are deterministic per seed; a gate locks below min; effects apply; `next:""` ends and the
guest leaves (auto-serve applied); `talk_next` is illegal with an empty queue; the queue view is FIFO and shows
portraits; a full night's playthrough with the AutoPlayer choosing choice 0 never throws.

## 7. Decisions after the first build (2026-09-12 late)

- **Stat display names are Späti-flavoured** (ids unchanged): Muscle (str) · Hands (dex) · Stamina (con) · Brains (int) ·
  Kiez Sense (wis) · **Schnauze** (cha — the Berliner Schnauze). Choice tags read "[Schnauze 12] …". Both name tables
  (`Rules.STAT_NAMES`, `Strings.STAT_*`) carry the same words; `test_scenes.gd::test_the_two_stat_tables_agree` guards it.
- **The line is real:** the reducer no longer promotes the head of the queue on `tick`. Guests wait at the register until
  `talk_next` takes them; while they wait their patience runs (`Rules._age_queue`) and they may give up on the line
  (a smaller Kiez-Trust hit than a balk at the counter). Story guests never give up (their beat is tonight's
  conversation). `config.auto_take_next = true` restores the old behaviour for serve-loop sims.
- A beat/vignette opens as a one-node talk (`engine/talk.gd`); `view.dialogue` is a projection of `view.talk`; the legacy
  `resolve_beat/resolve_vignette` are aliases of `talk_choose`. Ending a **graph** talk dismisses the guest and auto-serves
  their want (refusing an underage restricted sale); ending a **beat** talk leaves them at the counter for the ordinary serve.
