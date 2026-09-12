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
godot/engine/storyflow.gd   class_name StoryFlow   schedule_beats(s, rng) (called by open_night) · on_customer_active(s) · apply_beat_choice(s, idx) · apply_vignette_choice(s, idx) · current_dialogue(s) -> Dictionary|{}
godot/engine/talk.gd        class_name Talk       the conversation at the register (§8 / docs/06): node_of(s), view(s), dialogue_view(s), choice_views(s, node), success_chance(dc, mod)
godot/engine/finale.gd      class_name Finale      main_ending(s)->String · resolve_finale(s)->Dictionary{main, epilogues:[{character, line}]}
godot/engine/content/registry.gd  class_name Content   SKUS, SKU_BY_ID, ARCHETYPES, ARCHETYPE_BY_ID, UPGRADES, UPGRADE_BY_ID, STRANDS, STRAND_BY_ID, VIGNETTES, VIGNETTE_BY_ID, CHARACTERS (§6)
godot/engine/content/{skus,customers,upgrades,story,vignettes,characters}.gd   const DATA: Array[Dictionary] — data only
godot/engine/content/dialogues.gd  const DATA: Dictionary — the branching conversation graphs (§8 / docs/06 §3)
godot/state/session.gd      autoload `Session` (§7)
godot/sim/auto_player.gd    class_name AutoPlayer  the headless competent-shopkeeper policy for tests (port app/src/sim/autoPlayer.ts)
```

## 2. State (`Dictionary`) — keys and types

```
config:  { difficulty:"cozy"|"normal"|"tight", seed:int, night_len_ms:int, season_days:int, start_cash:float, rent_per_day:float }
day:int (1-based)   weekday:int (0=Mon…6=Sun)   phase:"manage"|"night"|"summary"|"end"   clock_ms:int (within the night)
cash:float   pfand_held:int (bottles awaiting wholesaler credit)
inventory: { sku_id: { stock:int, price:float } }        upgrades: Array[String]
reputation: { kiez:float 0..100, profit:float 0..100, integrity:float 0..100 }
open_sunday:bool   ordnungsamt_heat:float
arrivals: Array[{ time_ms:int, archetype_id:String, want:String, character_id:String|"" , beat_id:String|"", vignette_id:String|"" }]  (sorted by time_ms)
next_arrival:int   queue: Array[Customer]   active: Customer|null   next_customer_id:int
tally: { revenue, cogs, tips, pfand_paid, sales:int, lost:int }
summaries: Array[{ day, revenue, cogs, tips, bills_due, pfand_paid, profit, cash_after, sales, lost, kiez_delta }]
story: { flags:Array[String], met:Array[String], strands:{ id:{ cur:String|"", outcome:String|"", last_day:int } },
         main_outcome:String|"", pending:{ strand:String, beat:String }|{}, seen_vignettes:Array[String], pending_vignette:String|"" }
rng_state:int   log: Array[{ ts:int, kind:String, text:String, data:Dictionary }]
Customer = { id:int, archetype_id:String, want:String, patience_left_ms:int, character_id:String|"", beat_id:String|"", vignette_id:String|"", expression:String ("neutral"|"warm"|"wary"|"upset") }
```
Use `""`/`{}` for "none" (JSON-safe; never `null` inside arrays). Money is float euros rounded to cents by the reducer.

## 3. Actions (`{ "type": ..., ... }`) — exactly these

`open_night` · `tick{dt_ms}` · `serve_active{give:Array[sku_id], pfand_bottles:int}` · `skip_active` · `set_price{sku, price}` ·
`restock{sku, qty}` · `buy_upgrade{id}` · `set_sunday_open{open}` · `resolve_beat{choice:int}` · `resolve_vignette{choice:int}` ·
`close_night` · `advance_day` · `talk_next` · `talk_advance` · `talk_choose{choice:int}` (§8)

Semantics = `app/src/engine/rules.ts` (port it function by function, including the Sunday/Ordnungsamt roll, the
illegal "extra menu" bleed/raid, perishables, `cash < -200 → end`). `legal_actions(s)` returns the action
dictionaries the UI may offer *right now* (e.g. no `serve_active` while a beat is pending; no `restock` you
cannot afford). `tick` is the only action the render loop sends on its own; everything else is a player intent.

## 4. Story at the counter (the one design change)

- `open_night` → `StoryFlow.schedule_beats`: for every strand whose next beat is eligible (`after_day`, `min_kiez`,
  `requires_flag`, ≤ 1 beat/strand/day, main arc first by `priority`), inject **one arrival** for that character
  (`character_id`, `beat_id`, a `want` from the character's own wants) at a time on that character's curve. On quiet
  nights (no cast beat), schedule at most one eligible **one-off vignette** onto a random ordinary arrival (`vignette_id`).
  Cap: ≤ 2 story arrivals per night so the loop stays a shop, not a visual novel.
- When such a customer becomes `active` (in `tick`), the reducer sets `story.pending = {strand, beat}` (or
  `story.pending_vignette`) and logs `kind:"beat"`. While pending, `legal_actions` offers only `resolve_beat` /
  `resolve_vignette`. Resolving applies the choice's `cash/kiez/profit/integrity/flags/outcome/next`, sets the
  customer's `expression` from the choice (`warm` if kiez ≥ 0 and integrity ≥ 0, `upset` if kiez < 0, else `neutral`),
  clears pending, and the customer stays active so the normal serve (`serve_active` / `skip_active`) follows.
- `story.met` gains the character on first beat. `Finale.resolve_finale` composes `main_outcome` + each met
  character's `epilogue[main][outcome]`.

## 5. `Rules.view(s)` — the read-model scenes render from (no logic in scenes)

```
{ phase, day, weekday_name, clock_ms, night_progress:float 0..1, time_label:"22:40", cash, pfand_held, pfand_rate:float (= Rules.PFAND_PER_BOTTLE — the Till quotes this, never a literal),
  reputation, hud:{ kiez_label, profit_label },
  active: {} | { customer, archetype:{id,name}, want:{sku_id,name,price,stock,icon:"sku/beer"}, portrait:"char/lena", expression, patience:float 0..1, is_story:bool },
  queue_len:int,
  queue: Array[{ customer_id, character_id, name, portrait, expression, is_story:bool }],   (FIFO — §8 / docs/06 §4)
  talk: {} | { speaker, portrait, expression, lines, line:int, choices:[{label, check:{stat,dc,mod,chance}|{}, locked, reason}], last_check },
  player: { stats:{str,dex,con,int,wis,cha}, mods:{…} },
  dialogue: {} | { speaker, portrait:"char/lena", expression, lines:Array[String], choices:Array[{label}], kind:"beat"|"vignette"|"talk" },   (a projection of `talk` — §8)
  shelf: Array[{ sku_id, name, price, stock, icon, restricted, tier }],   (every SKU in inventory, registry order)
  summary: {} | the last NightSummary,  manage:{ restock_options:[{sku_id,name,cost,stock,price,fair_lo,fair_hi}], modules:Economy.module_options(s) },
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
signal event(entry: Dictionary)   # every new `log` entry, in order — the FX/SFX stream (kinds: open, arrive, serve, tip, balk, pfand, ethics, beat, upgrade, ordnungsamt, raid, close)
var paused: bool                  # when true, _process does not tick
func new_game(config := {}) -> void     func dispatch(action: Dictionary) -> bool   # false = illegal (state unchanged)
func view() -> Dictionary               # Rules.view(state), memoised per state
func _process(delta): if state.phase == "night" and not paused: dispatch({type:"tick", dt_ms: int(delta*1000)})
func save() / load_save() -> JSON in user://autosave.json (`load` shadows a GDScript global) (slice: optional)
```

## 8. Talking to guests, the queue and the six stats → **`docs/06-dialogue-and-stats.md`**

The slice's core interaction (user decision 2026-09-12) is a branching conversation at the register,
rolled against six D&D stats. It is specified in full in `docs/06-dialogue-and-stats.md`; what it adds
to the contract above is:

- **State:** `player: { stats: {str,dex,con,int,wis,cha} }` and `talk: {} | { customer_id, dialogue_id,
  node, line, last_check, history, kind }`. Both round-trip through `from_json` like everything else.
- **Actions:** `talk_next` · `talk_advance` · `talk_choose{choice}`. `talk_end` stays engine-internal
  (`next:""` ends the conversation: the guest leaves and their want is auto-served if it is in stock).
- **Read-model:** `view.queue` (FIFO, each guest with a portrait id), `view.talk`, `view.player`.
- **Content:** `engine/content/dialogues.gd` — one graph per regular plus the generic `oneoff`.
- **Checks:** `Rules.modifier(score)` (5e), `Rules.roll_check(n, {stat,dc})` — one d20 off the state's
  own `rng_state`, logged as `kind:"check"` with `{stat, roll, mod, dc, success}`. A night therefore
  still replays exactly from `{config, seed, actions}`, every die included.
- **One box, one source (supersedes §4's delivery, not its rules):** a pending beat or vignette now
  opens as a **one-node talk**, and `view.dialogue` is a projection of `view.talk`, so the two can never
  disagree. `resolve_beat` / `resolve_vignette` remain legal as aliases of `talk_choose` on that talk.
  The one behavioural difference stands: ending a **beat** leaves the customer at the counter for the
  ordinary serve (§4), while ending a **graph talk** dismisses them.
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
