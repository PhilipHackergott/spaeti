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
**Which tree a guest gets is season-aware** — `Content.dialogue_id_for(character_id, state)` prefers
`<char>_<season letter><step>` (`lena_s2`), falls back to `<char>`, then to `oneoff`. See §8.

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

## 8. Seasons, arc steps and the tree selector (the cast's seven steps, made playable)

docs/09 §2 gives every guest a **seven-step arc keyed to the year** — summer 1–2 · autumn 3–4 ·
winter 5–6 · spring 7 — and the eight new trees of §4 **are each guest's step 1**. This section is
how those steps actually reach the counter. The calendar itself is `engine/season.gd` (docs/05 §11);
everything below is what the reducer does with it.

### 8.1 The tree-id convention

**`<character>_<season letter><step>`** — `lena_s2`, `achim_a3`, `bley_w5`, `karim_p7`.

| season | letter | steps |
|---|---|---|
| summer | `s` | 1, 2 |
| autumn | `a` | 3, 4 |
| winter | `w` | 5, 6 |
| spring | `p` | 7 |

Spring is **`p`** because summer already owns `s` and two tree ids may not collide. **The letter comes
from the STEP's season, never from the calendar** — so a guest who is catching up on a summer step in
February still opens `lena_s2`, the tree that was written for that step. A step number therefore names
exactly one tree, for ever, and `Content.arc_tree_id(character_id, step)` is the only place the
spelling is built.

### 8.2 The selector

```gdscript
Content.dialogue_id_for(character_id: String, s: Dictionary = {}) -> String
```

Three tiers, first hit wins:

1. **`<char>_<letter><step>`** — the tree written for the arc step this guest is **on**;
2. **`<char>`** — their plain tree, which *is* step 1 for the eight new guests;
3. **`oneoff`** — the nameless parade's (and `oneoff_minor` when a minor asks for a restricted SKU).

It is **data-driven**: existence is `Content.DIALOGUES.has(id)` every time, never a hard-coded list of
who has what. A content lane ships `karim_a3` and it is live on the next night with no engine edit.
An **unwritten** step falls back to tier 2, not to the parade — a guest with a gap in their arc still
sounds like themselves. `s` is optional so a content test or a tool still resolves tiers 2–3.

Supporting calls, all pure: `arc_step_of(character_id, s)` (the ledger, 0 for a face with no persona
card), `arc_dialogue_id(character_id, s)` (tier 1 alone, or `""`), `arc_tree_id(character_id, step)`
(§8.1), `arc_title_for_step(character_id, step)` (the beat id the persona card names for that step —
authoring metadata the card overlay prints; the reducer never reads it).

`Rules._open_talk` passes the state, so `talk_next` opens whatever the selector names.

### 8.3 The arc ledger — `step` and `season_seen`

`state.story.strands[id]` carries `step` (1..7, the step this guest plays **next**) and `season_seen`
(the season the last one actually happened in, `""` until they have been met). Three rules, all of
them in `StoryFlow.advance_step`:

- **A step advances when the encounter resolves** — a beat answered (`apply_beat_choice`) *or* the
  guest's own tree closed (`Rules._end_talk` → `StoryFlow.advance_step_for`). An encounter is an
  encounter: a guest who walks in as another strand's speaker still moves their own arc.
- **At most one step per night per guest.** `last_day` is the guard, and it is stamped by *every*
  encounter whether or not the step moved. That is the same field `StoryFlow.eligible_beats` reads, so
  "one step a night" and "never the same guest twice in a night" are one rule with one source.
- **Never a skip.** It is `+1`, never "jump to whatever the season says". An arc whose season passed
  unplayed therefore **catches up one step per encounter**: nobody talks to Achim until deep in the
  winter, and the night he walks in he plays step 1, then step 2, then step 3 — not step 5. The other
  half of that rule is `Season.step_is_due`, which keeps a late step due and an early one shut.

`step` **saturates at 7**: once the spring step has played, that tree stays the guest's voice for the
rest of the run. `season_seen` is *not* the step's own season — an arc that missed the summer plays
its summer steps in the winter, and the ledger records both facts, which is what an overlay needs to
say "step 2 of 7, and she is playing it in February".

### 8.4 Scheduling a step

`StoryFlow.schedule_beats` (called by `open_night`) turns the due step into an **arrival**, under four
invariants:

- **A strand's current beat is its current arc step.** The gates are the four it always had —
  `after_day`, `min_kiez`, `requires_flag`, one beat per strand per day — **plus the season**:
  `Season.step_is_due(progress.step, season_of_today)`.
- **One story guest at a time.** `StoryFlow.MAX_STORY_ARRIVALS = 1`. A night carries one cast
  encounter and the rest of the queue is the parade. (It was 2 before the arcs; with seven steps per
  guest the pacing is the rotation below, not the number of beats crammed into one night.)
- **Never the same face twice in a night.** A beat may be spoken by someone else's face — the main
  arc's `squeeze` is Mehmet's — so two eligible beats can name one person, and two Mehmets in one
  queue is a bug the player can see. The guard is a per-night set of scheduled `character_id`s, kept
  deliberately independent of the cap so raising the cap later cannot reintroduce the double.
- **The main arc outranks the cast; inside the cast, fairness outranks priority.** `eligible_beats`
  sorts by: the main arc (priority ≥ 100) → whoever has been **unseen longest** (`last_day` ascending)
  → `priority` → registry order. That middle key is what turns a one-a-night cap into a **rotation**:
  sorting on `priority` alone starved the bottom of the table completely — measured over a 28-night
  season, Herr Bley (priority 4, the lowest) never walked in once. Every key is a pure function of
  state, so the schedule still replays byte-for-byte from `{config, seed, actions}`.

### 8.5 What a content lane writes

**Status (2026-09-13): all 77 are shipped.** Eleven guests × seven steps — the eleven plain trees
(which *are* step 1) plus the sixty-six step trees, written by four content lanes and integrated in
one pass. `test_arcs.gd` §12 is the sweep that holds them to one bar; the rules below are what it
asserts, and a twelfth guest joins the sweep the day their persona card lands.

`godot/engine/content/dialogues.gd` → **`lena_s2`** is the worked example: Lena's summer step 2, *The
Honest Piece*. Five nodes · one d20 check at DC 12 (a coin, not a tax) · one gate that is **locked** at
day-one stats · an expression change per node · the order woven into the first line · choice 0 never
gated · four flags (`lena_honest_piece`, `lena_named_it`, `lena_wall_offer`, `lena_hung_it`) that
autumn's step 3 reads back, each with its reader declared in `Content.FLAG_READERS`. Copy its shape.

Two things a lane must keep in mind, both of which have already shipped as bugs once:

1. **The basket is truncated before the tokens are substituted.** `Rules._place_basket` cuts to the
   reducer's caps (4 lines / 6 units / 3 placed) and drops any SKU the shop has not unlocked, and
   `Talk._apply` leaves a token it cannot match **alone** — so a `{brand.*}` whose row was cut does not
   fail, it *prints*. Write the token-bearing rows first on the persona card, and assert against
   `Rules.view`, never against the authored table (`test_arcs.gd`, `test_tokens.gd`).
2. **A step that is not written is not a gap in the arc, it is a fallback to tier 2.** Ship steps in
   order where you can; a hole between `lena_s2` and `lena_a4` means her step 3 plays her step-1 tree.

`godot/tests/unit/test_arcs.gd` is the contract: the season map, the selector's three tiers, step
advancement (including the catch-up rule and the one-a-night guard), the scheduling invariants, and a
headless full-season run in which every guest reaches the step their season and their written arc
allow. Sections 8–11 are the four content lanes' own acceptance tests; **§12 is the integrator's
sweep**, which asserts the same properties over the cast *as a whole* — derived from `GUESTS` ×
`Season.STEPS` and `Content.STRANDS`, never from a list of what some lane happened to write. That
distinction is not bookkeeping: a lane's own test asks for the tree the lane meant to write, so a
tree id one letter out passes the lane and fails only here.

### 8.6 How a step reads the step before it

A step that reads nothing is a scene that happens to be numbered. The read has to live somewhere the
engine already looks, and **a dialogue tree cannot gate on a flag** — a choice carries only `check`
and `requires`, both of which test the player's stats, never `story.flags`. So the read lives on the
**beat**: every beat from step 2 onward carries a `requires_flag` naming a flag an earlier beat in the
same strand wrote. `StoryFlow.eligible_beats` enforces it, which makes the read real rather than
decorative — an unearned step is not scheduled.

That mechanism is also the most dangerous thing in the content, and the reason it is asserted
exhaustively rather than by inspection:

> **`eligible_beats` skips a strand whose current beat wants a flag the player never set, and nothing
> else can move `cur`.** A gate reachable down a branch that never sets it is therefore not a shorter
> arc — it is a guest who silently stops existing for the rest of the run, with no symptom the player
> or the log can show.

The rule, stated once for all fourteen strands, is **not** "the beat before it sets the flag". It is:

- **On every path that can reach a beat, its `requires_flag` is already held.** `test_arcs.gd
  ::test_no_gate_anywhere_can_freeze_a_strand` walks every branch of every strand carrying the flags
  that path actually set. A gate may legitimately read *three* steps back — Herr Bley's step 5 gates
  on `bley_talks`, which his step 2 wrote on both its branches — and only the walk can tell that apart
  from a freeze. The practical way to satisfy it stays the simple one: have **every** choice of a beat
  set the flag its successor gates on, not just the top line.
- **Only a TERMINAL beat may be left unreachable.** That is the spring, where an arc is allowed to
  fork on whether you ever listened — `bley/b_patron` on `bley_tip`, `schulz/sc_corner` and
  `achim/a_elder` on `<guest>_listen`. It is not a freeze: step 6 has already recorded an outcome, and
  the step-7 *tree* still plays, because the selector reads the ledger and not the beat chain.

Two consequences worth knowing before writing a gate. A gate flag is a **kind-1 reader** (docs/09
§4.10) and therefore must **not** also carry a `Content.FLAG_READERS` row —
`test_flags.gd::test_no_declared_reader_is_dead` fails the build on the duplicate, so promoting a
declared flag to a real gate means deleting its row in the same commit. And a strand needs **seven
beats**, one per step: `eligible_beats` skips a strand whose `cur` has run out, so a three-beat chain
freezes the arc on step 4 however long the year is.

### 8.7 Pacing — what a year of a given length actually delivers

Measured on the headless top-line run (`test_arcs.gd` §7's harness, seed 5), with all 77 steps and all
fourteen seven-beat chains in place. The step each guest is **on** when the calendar runs out:

| `season_days` | steps reached | verdict |
|---|---|---|
| **28** (shipped) | 2–4 — typically **3** | roughly **40%** of the written arcs are reachable in a shipped run |
| 56 | 5–7 | most arcs land, a few stall one step short of the spring |
| **112** | **7 for all eleven** | the whole cast plays its spring |

This is arithmetic, not a bug: fourteen strands compete for **one** story slot a night
(`MAX_STORY_ARRIVALS = 1`), and `Season.step_is_due` lets a strand take at most two steps per season,
so a seven-step arc needs two encounters in each of three seasons. Fourteen strands × two nights per
season ≈ 28 nights *per season*, i.e. 112 in the year.

**It is still an open product decision, and it is now a content decision rather than a machinery one.**
`SpatiState.DEFAULT_CONFIG` is untouched at 28. The three levers: grow `season_days`; put
`MAX_STORY_ARRIVALS` back to 2 (which costs the "one story guest at a time" feel the brief asked for);
or accept that a 28-night run is one *season* of an arc and that the spring is what a long game is
for. Whichever is chosen, the machinery and the content are both ready for it — `test_arcs.gd`
§12's year runs at 112 precisely so it measures the arcs rather than the calendar.
