# 05 — Engine ↔ UI contract (both lanes build against this; change it only with a build-log note)

The engine is a **pure reducer over a plain `Dictionary`** so it round-trips through JSON, replays from
`{config, seed, actions}`, and runs headless in tests. Scenes never mutate state; they `dispatch` actions
through the `Session` autoload and re-render from the new state. Names are snake_case GDScript; the shapes
are a 1:1 port of `app/src/engine/types.ts` (read it) with **one deliberate change**: story beats fire *at the
counter*, not as morning text (see §4).

## 1. Files

```
godot/engine/rng.gd         class_name Rng        seeded PRNG (port app/src/engine/rng.ts): next()->float [0,1), range(a,b), pick(arr), weighted_index(weights), state()->int, from_state(int)
godot/engine/state.gd       class_name SpatiState  static new_game(config: Dictionary) -> Dictionary · clone(s) -> Dictionary (duplicate(true)) · to_json(s)->String · from_json(String)->Dictionary · DEFAULT_CONFIG
godot/engine/rules.gd       class_name Rules       static apply(s, action: Dictionary) -> Dictionary (PURE: returns a new state; an illegal action returns `s` itself, unchanged) · tick(s, dt_ms) · legal_actions(s) -> Array[Dictionary] · view(s) -> Dictionary (derived read-model, §5)
godot/engine/economy.gd     class_name Economy     price_tier(sku_def, price)->String("steal"|"fair"|"high"|"gouge") · satisfaction(...) · tip_for(...) · kiez_delta(...) · night_traffic(s)->int · module_options(s)->Array
godot/engine/season.gd      class_name Season      the year (§11): of_day/index_of_day/day_in_season/first_day_of/length_of · of_step/last_step_of/step_is_due · letter_of/index_of · of_state/day_in_season_of_state. PURE, no deps — ONE calendar for the reducer, the registry and the tests
godot/engine/storyflow.gd   class_name StoryFlow   schedule_beats(s, rng) (called by open_night) · on_customer_active(s) · apply_beat_choice(s, idx) · apply_vignette_choice(s, idx) · current_dialogue(s) -> Dictionary|{}
godot/engine/talk.gd        class_name Talk       the conversation at the register (§8 / docs/06): node_of(s), view(s), dialogue_view(s), choice_views(s, node), success_chance(dc, mod)
godot/engine/finale.gd      class_name Finale      main_ending(s)->String · resolve_finale(s)->Dictionary{main, epilogues:[{character, line}]}
                                                       season-aware dialogue selection (§11.2 / docs/06 §8): dialogue_id_for(character_id, state={}), arc_dialogue_id(), arc_tree_id(), arc_step_of(), arc_title_for_step()
godot/engine/content/registry.gd  class_name Content   SKUS, SKU_BY_ID, ARCHETYPES, ARCHETYPE_BY_ID, UPGRADES, UPGRADE_BY_ID, STRANDS, STRAND_BY_ID, VIGNETTES, VIGNETTE_BY_ID, CHARACTERS (§6),
                                                       BRANDS/BRAND_BY_ID/BRANDS_BY_SKU/BRAND_BY_ICON + brand(), brands_for(), brand_spoken(), brand_logo(), brand_phrase(), brand_by_icon() (docs/08 §2)
godot/engine/content/brands.gd    const DATA: Array[Dictionary] — the 22-row tobacco catalogue: 8 cigarettes, 4 pouches, 6 paper variants, 4 filter variants (docs/08 §2)
godot/engine/content/{skus,customers,upgrades,story,vignettes,characters}.gd   const DATA: Array[Dictionary] — data only
godot/engine/content/dialogues.gd  const DATA: Dictionary — the branching conversation graphs (§8 / docs/06 §3)
godot/state/session.gd      autoload `Session` (§7)
godot/sim/auto_player.gd    class_name AutoPlayer  the headless competent-shopkeeper policy for tests (port app/src/sim/autoPlayer.ts)
```

## 2. State (`Dictionary`) — keys and types

```
config:  { difficulty:"cozy"|"normal"|"tight", seed:int, night_len_ms:int, season_days:int, start_cash:float, rent_per_day:float,
`story_slots` (optional, default 2; saves from before it fall back to 1)  how many story guests StoryFlow may schedule into one night. Testbuild pacing: 56-day season x 2 slots fits all fourteen strands (docs/06 section 8.7).
           auto_take_next:bool }   (default false, and absent from SpatiState.DEFAULT_CONFIG — true makes `tick` promote the head of the queue instead of waiting for `talk_next`; serve-loop sims/tests only, docs/06 §7)
day:int (1-based)   weekday:int (0=Mon…6=Sun)   phase:"manage"|"night"|"summary"|"end"   clock_ms:int (within the night)
cash:float   pfand_held:int (bottles awaiting wholesaler credit)
inventory: { sku_id: { stock:int, price:float } }        upgrades: Array[String]
reputation: { kiez:float 0..100, profit:float 0..100, integrity:float 0..100 }
open_sunday:bool   ordnungsamt_heat:float
arrivals: Array[{ time_ms:int, archetype_id:String, want:String, character_id:String|"" , beat_id:String|"", vignette_id:String|"", bottles:int }]  (sorted by time_ms)
next_arrival:int   queue: Array[Customer]   active: Customer|null   next_customer_id:int
tally: { revenue, cogs, tips, pfand_paid, sales:int, lost:int }
summaries: Array[{ day, revenue, cogs, tips, bills_due, pfand_paid, profit, cash_after, sales, lost, kiez_delta }]
story: { flags:Array[String], met:Array[String], strands:{ id:{ cur:String|"", outcome:String|"", last_day:int, step:int 1..7, season_seen:String|"" } },   (the arc ledger — §11.1, docs/06 §8)
         main_outcome:String|"", pending:{ strand:String, beat:String }|{}, seen_vignettes:Array[String], pending_vignette:String|"" }
rng_state:int   log: Array[{ ts:int, kind:String, text:String, data:Dictionary }]
Customer = { (plus the register's own `basket` / `counter` / `register` / `hand`, §10.1) id:int, archetype_id:String, want:String, patience_left_ms:int, character_id:String|"", beat_id:String|"", vignette_id:String|"", expression:String ("neutral"|"warm"|"wary"|"upset"), bottles:int (empties THEY carried in — 0..Rules.PFAND_MAX_RETURN; `serve_active` clamps `pfand_bottles` to it. NOT `pfand_held`, which is the shop's crate) }
```
Use `""`/`{}` for "none" (JSON-safe; never `null` inside arrays). Money is float euros rounded to cents by the reducer.

## 3. Actions (`{ "type": ..., ... }`) — exactly these

`open_night` · `tick{dt_ms}` · `serve_active{give:Array[sku_id], pfand_bottles:int}` · `skip_active` · `set_price{sku, price}` ·
`restock{sku, qty}` · `buy_upgrade{id}` · `set_sunday_open{open}` · `resolve_beat{choice:int}` · `resolve_vignette{choice:int}` ·
`close_night` · `advance_day` · `talk_next` · `talk_advance` · `talk_choose{choice:int}` (§8) ·
`scan{uid}` · `register_remove{line}` · `register_set_qty{line, qty}` · `turn_around{on}` · `take_from_wall{sku, brand}` · `put_back{uid}` · `set_pfand{bottles}` · `check_id` · `ring_up` (§10)

Semantics = `app/src/engine/rules.ts` (port it function by function, including the Sunday/Ordnungsamt roll, the
illegal "extra menu" bleed/raid, perishables, `cash < -200 → end`). `legal_actions(s)` returns the action
dictionaries the UI may offer *right now* (e.g. no `serve_active` while a beat is pending; no `restock` you
cannot afford). `set_price` / `restock` / `buy_upgrade` / `set_sunday_open` are manage-only; the reducer rejects
them in night/summary/end. `tick` is the only action the render loop sends on its own; everything else is a player intent. It ages the waiting
line (`_age_queue`) rather than advancing it, unless `config.auto_take_next` is true (§2).

## 4. Story at the counter (the one design change)

- `open_night` → `StoryFlow.schedule_beats`: for every strand whose next beat is eligible (`after_day`, `min_kiez`,
  `requires_flag`, ≤ 1 beat/strand/day, **the beat's arc step being due in this season** — §11 / docs/06 §8 — main
  arc first, then whoever has been unseen longest), inject **one arrival** for that character
  (`character_id`, `beat_id`, a `want` from the character's own wants) at a time on that character's curve. On quiet
  nights (no cast beat), schedule at most one eligible **one-off vignette** onto a random ordinary arrival (`vignette_id`).
  Cap: **one story guest at a time** (`MAX_STORY_ARRIVALS = 1`) so the loop stays a shop, not a visual novel,
  and never the same face twice in one night (docs/06 §8.4).
- When such a customer becomes `active` (in `tick`), the reducer sets `story.pending = {strand, beat}` (or
  `story.pending_vignette`) and logs `kind:"beat"`. While pending, `legal_actions` offers only `resolve_beat` /
  `resolve_vignette`. Resolving applies the choice's `cash/kiez/profit/integrity/flags/outcome/next`, sets the
  customer's `expression` from the choice (`warm` if kiez ≥ 0 and integrity ≥ 0, `upset` if kiez < 0, else `neutral`),
  clears pending, and the customer stays active so the normal serve (`serve_active` / `skip_active`) follows.
- `story.met` gains the character on first beat. `Finale.resolve_finale` composes `main_outcome` + each met
  character's `epilogue[main][outcome]`.

## 5. `Rules.view(s)` — the read-model scenes render from (no logic in scenes)

```
{ phase, day, weekday_name, season:"summer"|"autumn"|"winter"|"spring", day_in_season:int (§11), clock_ms, night_progress:float 0..1, time_label:"22:40", cash, pfand_held, pfand_rate:float (= Rules.PFAND_PER_BOTTLE — the Till quotes this, never a literal),
  reputation, hud:{ kiez_label, profit_label },
  active: {} | { customer, archetype:{id,name}, want:{sku_id,name,price,stock,icon:"sku/beer"}, portrait:"char/lena", expression, patience:float 0..1, is_story:bool, underage:bool, bottles:int },
  queue_len:int,
  queue: Array[{ customer_id, character_id, name, portrait, expression, is_story:bool }],   (FIFO — §8 / docs/06 §4)
  talk: {} | { speaker, portrait, expression, lines, line:int, choices:[{label, check:{stat,dc,mod,chance}|{}, locked, reason}], last_check },
  player: { stats:{str,dex,con,int,wis,cha}, mods:{…} },
  dialogue: {} | { speaker, portrait:"char/lena", expression, lines:Array[String], choices:Array[{label}], kind:"beat"|"vignette"|"talk" },   (a projection of `talk` — §8)
  shelf: Array[{ sku_id, name, price, stock, icon, restricted, tier }],   (every SKU in inventory, registry order)
  summary: {} | the last NightSummary,  manage:{ restock_options:[{sku_id,name,cost,stock,price,fair_lo,fair_hi,tier,affordable}], modules:Economy.module_options(s), status:Economy.corner_status(s), open_sunday:bool },
  ending: {} | Finale.resolve_finale(s) when phase=="end" }
```

## 6. Characters registry (`content/characters.gd`)

`{ id:"lena", name:"Lena", portrait:"char/lena", expressions:["neutral","warm","upset"], archetype_id:"student", colour:"#e8a1b8", wants:{mate:3,...} }`
for `you, lena, juergen, mehmet, brandt, tobias, schulz, nadia` + one-off archetype portraits
(`oneoff_clubber`, `oneoff_tourist`). `portrait` + `_` + expression = the asset id under `godot/assets/`; a missing
expression falls back to `_neutral`; a missing portrait falls back to the archetype's one-off portrait.

## 7. `Session` autoload (`godot/state/session.gd`) — the only mutable game object

```
var state: Dictionary            signal changed(prev: Dictionary, next: Dictionary)
signal event(entry: Dictionary)   # every new `log` entry, in order — the FX/SFX stream (kinds: open, arrive, serve, tip, balk, pfand, ethics, beat, check, upgrade, ordnungsamt, raid, close, misring (§10.4); `check` is the only kind with TWO listeners — `Fx` and the `DiceResult` pop, fanned out in `scenes/night.gd::_on_log_event`)
var paused: bool                  # when true, _process does not tick
func new_game(config := {}) -> void     func dispatch(action: Dictionary) -> bool   # false = illegal (state unchanged)
func view() -> Dictionary               # Rules.view(state), memoised per state
func _process(delta): if state.phase == "night" and not paused: dispatch({type:"tick", dt_ms: int(delta*1000)})
func save() / load_save() -> JSON in user://autosave.json (`load` shadows a GDScript global). `dispatch` autosaves after every non-`tick` action; Title → Continue calls `load_save()`.
```

## 8. Talking to guests, the queue and the six stats → **`docs/06-dialogue-and-stats.md`**

The slice's core interaction (user decision 2026-09-12) is a branching conversation at the register,
rolled against six D&D stats. It is specified in full in `docs/06-dialogue-and-stats.md`; what it adds
to the contract above is:

- **State:** `player: { stats: {str,dex,con,int,wis,cha} }` and `talk: {} | { customer_id, dialogue_id,
  node, line, last_check, history, kind }`. Both round-trip through `from_json` like everything else.
- **Actions:** `talk_next` · `talk_advance` · `talk_choose{choice}`. `talk_end` stays engine-internal
  (`next:""` ends the conversation). **Superseded in part by §10.4:** the guest leaves and their want is
  auto-served only when they have **no basket**; a guest whose basket is on the counter stays standing and
  is rung up on the register.
- **Read-model:** `view.queue` (FIFO, each guest with a portrait id), `view.talk`, `view.player`.
- **Content:** `engine/content/dialogues.gd` — one graph per regular plus the generic `oneoff`.
- **Checks:** `Rules.modifier(score)` (5e), `Rules.roll_check(n, {stat,dc})` — one d20 off the state's
  own `rng_state`, logged as `kind:"check"` with `{stat, roll, mod, dc, success}`. A night therefore
  still replays exactly from `{config, seed, actions}`, every die included.
- **One box, one source (supersedes §4's delivery, not its rules):** a pending beat or vignette now
  opens as a **one-node talk**, and `view.dialogue` is a projection of `view.talk`, so the two can never
  disagree. `resolve_beat` / `resolve_vignette` remain legal as aliases of `talk_choose` on that talk.
  The one behavioural difference stands: ending a **beat** leaves the customer at the counter for the
  ordinary serve (§4), while ending a **graph talk** dismisses them — **unless their basket is on the
  counter**, in which case the register is the serve and they stay (§10.4).
- **`legal_actions`:** while a talk is open, only `talk_advance` / `talk_choose` (plus those legacy
  aliases); a locked gate is never offered. Otherwise `talk_next` whenever there is somebody to take.

## 9. Tests the engine lane must ship (`godot/tests/unit/`)

`test_rng.gd` (determinism, distribution sanity) · `test_economy.gd` (tiers, tips, kiez deltas) · `test_night.gd` (open →
ticks → serve/skip → close; P&L identity `profit = revenue + tips − cogs − bills − pfand − fines`) · `test_story.gd`
(beats fire at the counter, gating, choices apply, pending blocks serve, finale composes) · `test_determinism.gd`
(same seed + same actions ⇒ identical `to_json`; a full 7-night AutoPlayer season) · `test_content.gd` (every SKU
referenced by a want exists; every strand's `next` beat exists; every character has a portrait id) ·
`test_dialogue.gd` (docs/06 §6 — seeded checks, gates, effects, the auto-serve on `next:""`, the FIFO
queue view, and a whole night talked through by the AutoPlayer).

## 10. The register: scan to ring, and the tobacco wall → **`docs/08-register-and-tobacco.md`**

Since 2026-09-13 the serve is not a panel, it is a **till**. `docs/08` is the full specification; what it
adds to the contract above is below. **The governing rule is unchanged: the register is a reducer, not a
minigame** — every gesture is one action dictionary and the whole ring-up is judged by one pure function.

### 10.1 State

Everything that dies with the customer lives under `active`, so counter/register desync is structurally
impossible rather than something to remember to clear:

```
active.basket:   Array[{ sku:String, brand:String, qty:int, said:String, placed:bool }]
active.counter:  Array[{ uid:int, sku:String, brand:String, kind:"item"|"crate", count:int, scanned:bool, origin:"customer"|"wall" }]
active.register: { lines: Array[{ sku, brand, qty, uids:Array[int] }], pfand_bottles:int, id_checked:bool,
                   corrections:int, flagged:Array[int], correction:String, correction_kind:String }
active.hand:     Array[{ uid, sku, brand }]          # carried back from the wall, HAND_MAX 4
view_mode:       "counter" | "wall"                  # TOP LEVEL — which way your body faces
next_item_uid:   int                                 # TOP LEVEL
last_verdict:    {} | { ok, accuracy:float, errors:float, wanted_units:int,
                        missing:[], extra:[], wrong_brand:[], wrong_count:[], refused:[] }
```

`view_mode` and `next_item_uid` are top level on purpose: both must survive a customer leaving while you are
turned around. `active.want` stays `basket[0].sku`. All JSON-safe; `_normalise` gives every new key a default,
so a pre-`docs/08` save still loads and still round-trips byte-identically.

**Reducer caps, not UI caps:** ≤ 4 distinct goods lines, ≤ 6 units, ≤ 3 placed. The tray therefore cannot
overflow its 7 slots (3 placed + 3 fetched + 1 crate) and a content mistake cannot break the frame.

### 10.2 Actions

`scan{uid}` · `register_remove{line}` · `register_set_qty{line, qty}` · `turn_around{on:bool}` ·
`take_from_wall{sku, brand}` · `put_back{uid}` · `set_pfand{bottles}` · `check_id` · `ring_up`

Legality is in docs/08 §3.2. `place_basket` and the correction stay engine-internal. Two notes that are
contract, not detail:

- **`legal_actions` advertises BOTH quantity steps** for every register line (`qty+1` and `qty−1`, each in
  range). The row has a "−" and a "+" and each routes to its own control; advertising one of them left a
  pressable chip whose action the engine never admitted was legal — a soft-lock from the other direction.
- **`serve_active` is no longer OFFERED** at the counter (docs/08 §3.6 demotes `ServePanel`/`Shelf`/`Till` to a
  `play.mjs --serve` debug affordance). It stays **legal** as the alias the AutoPlayer's serve-loop sims and
  `config.auto_take_next` dispatch by hand. Every action `legal_actions` emits must map to a visible control
  (§10.5), and `serve_active` has none on the shipped Night screen.

### 10.3 Read-model additions

```
view.view_mode: "counter" | "wall"
view.counter:   [{ uid, sku_id, name, brand, mark, colour, icon, kind, count, scanned, origin, slot }]
view.register:  { lines:[{ sku_id, name, brand, mark, colour, icon, qty, unit_price, line_total,
                           restricted, matches:bool, flagged:bool }],
                  pfand_bottles, pfand_line, subtotal, total (may be negative), can_ring,
                  id_checked, corrections, flagged:Array[int], correction:String, correction_kind:String }
view.order:     [{ sku_id, said, qty, name, category, brand, brand_name, mark, colour, icon,
                   name_shown:bool, satisfied:bool }]
view.wall:      {} | { shelves:[{ sku_id, label, price, stock, row, cells:[{ sku_id, brand, name, mark,
                                  colour, icon, stock, row, col }] }], hand:[…], hand_max:int }
```

`matches` and `satisfied` are **derived in the engine, never in the UI**: the ticks and the amber edges are the
reducer's opinion, so no screen can lie about correctness. `brand_name` is **withheld** (`""`) unless the
speech tier says the customer used it — a component may not decide how much a guest gave away.

**`view.wall` is THREE shelves, not one per SKU** (docs/08 §4.3): cigarettes · rolling tobacco · papers +
filters together, ten facings on the bottom rail with `col` running across the whole row. The row index is
layout, and `Palette.wall_cell_rect` knows exactly three rows — a fourth shelf drew its cells on top of the
third, both clickable, the later one swallowing the other's clicks.

### 10.4 Two rules that changed behaviour elsewhere

- **The talk ending is the sale STARTING, not the sale.** §8's "ending a graph talk dismisses them and
  auto-serves their want" applied when a guest had one `want` and the sentence was the only way to take their
  money. A guest whose **basket is on the counter** now stays standing when the box slides away, and the
  player scans and rings up. The old path survives for a guest with **no basket** — the parade served by
  `serve_active`, the serve-loop sims, `config.auto_take_next`. Without this every authored tree rang itself
  up and the whole register was unreachable for all eleven of the cast.
- **`Economy.satisfaction(accuracy: float, …)`** widens the old bool: `s := 0.25 + 0.45 × accuracy`, which
  preserves the old endpoints exactly, and the kiez miss-penalty generalises to `0.3 × kiez_sensitivity ×
  (1 − accuracy)`. One number, one path. `test_economy.gd` stays green unchanged, which is the point.

`log` gains one kind: **`misring`** (the rejected ring-up; `data` carries `accuracy_pct` and the per-bucket
counts). `components/fx.gd` ignores unknown kinds, so it is silent until someone gives it a pop.

### 10.5 The standing rule this section exists to protect

**Every entry `legal_actions` emits must map to a visible, focusable control, and every control must dispatch
an action the engine admits is legal.** Both directions, because both have now failed in this project:
`test_scenes.gd::test_every_legal_action_at_a_real_register_has_a_control` walks a **real** guest to the
counter and to the wall and checks the first; the "−" chip that no `legal_actions` advertised was the second.
`tools/godot/play.mjs` enforces the same rule per run, pointer-first: it reads `legal_actions`, asks
`Night.controls_for(action)` which node offers it, synthesises a real move-press-release at that node's own
rect centre, and asserts the state moved — **never a press by node name**, which is exactly how the original
soft-lock shipped.

---

## 11. The season model (`engine/season.gd`, `class_name Season`)

`config.season_days` is cut into **four equal quarters** — and those quarters are the year the cast's
seven-step arcs are keyed to (docs/09 §2). One calendar, in one file, dependency-free and pure: the
reducer, the content registry, `StoryFlow` and the tests all read it, so none of them can disagree
about what month it is while each looks right on its own. (It replaces the dead three-act `act_of`,
which had no spring to put step 7 in and which nothing ever called.)

```
Season.NAMES    ["summer", "autumn", "winter", "spring"]          registry order IS chronological
Season.LETTERS  summer "s" · autumn "a" · winter "w" · SPRING "p"  (summer already owns "s")
Season.STEPS    summer [1,2] · autumn [3,4] · winter [5,6] · spring [7]   ← the 2/2/2/1 split, once

of_day(day, season_days) -> String            index_of_day(day, season_days) -> 0..3
day_in_season(day, season_days) -> int        first_day_of(index, season_days) -> int
length_of(index, season_days) -> int          index_of(season) -> int | -1     letter_of(season) -> String
of_step(step) -> String                       last_step_of(season) -> int
step_is_due(step, season) -> bool             FIRST_STEP = 1   LAST_STEP = 7
of_state(s) / index_of_state(s) / day_in_season_of_state(s) / season_days_of(s)
```

**The map, for the shipped 28-night season:** summer **1–7** · autumn **8–14** · winter **15–21** ·
spring **22–28**. The arithmetic is integer — `index = (day − 1) × 4 / season_days`, clamped — so the
quarters stay as even as an odd `season_days` allows, every season has at least one day in it even at
`season_days = 4`, and a day *past* the end (the reducer sets `phase = "end"` on `day > season_days`
and `view` still renders that state) clamps to spring instead of running off the table.

**`step_is_due(step, season)` is the arc rule** and lives here because it is a property of the
calendar, not of any strand: a step opens in **its own season** and **stays open for ever after**.
Step 5 may not play in the summer; step 1 still plays in the spring if nobody ever talked to that
guest. That is what makes a missed season a catch-up rather than a skip (docs/06 §8).

`Rules.view(s)` carries two derived keys so no screen ever divides days by four on its own:

```
season: "summer"|"autumn"|"winter"|"spring"      day_in_season: int (1-based, "day 3 of autumn")
```

`SpatiState.season_of(s)` / `SpatiState.day_in_season(s)` are the same two values for a caller that
holds a state rather than a view.

### 11.1 The arc ledger, in state

`story.strands[id]` gains two keys (docs/06 §8 owns the rules; §2 above owns the shape):

```
step: int 1..7        the Truby step this guest plays NEXT — never skipped, at most one a night
season_seen: String   the season the last one actually HAPPENED in ("" until they have been met)
```

`season_seen` is **not** the step's own season: an arc that missed the summer plays its summer steps
in the winter, and the ledger records both facts. `from_json` reads both with defaults, so a save
written before the seasons loads with every guest on step 1 and nothing seen — which is exactly where
they were — and `step` is re-integered like every other int in the file.

### 11.2 The season-aware tree selector

```
Content.dialogue_id_for(character_id: String, s: Dictionary = {}) -> String
```

Three tiers, first hit wins: **`<char>_<season-letter><step>`** → **`<char>`** → **`oneoff`**. The
state argument is optional so a content test or a tool still resolves tiers 2–3. See docs/06 §8 for
the convention and the supporting calls (`arc_tree_id`, `arc_step_of`, `arc_dialogue_id`,
`arc_title_for_step`).
