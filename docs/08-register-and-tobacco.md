# 08 — The register: scan to ring, and the tobacco wall

*Späti vertical slice. Extends `docs/05-engine-api.md` (the pure reducer), `docs/06-dialogue-and-stats.md`
(the talk at the register) and `docs/04-component-catalog.md` (the pool). Every number is base-grid pixels
on the 480×270 canvas shown ×4. Read this before touching `godot/engine/rules.gd` or adding a component.*

**The governing decision: the register is a reducer, not a minigame.** Every physical gesture — a bottle
dragged over the scanner, a pack taken off the wall, a quantity nudged from 1 to 2 — is one action dictionary
with a legality rule, and the whole ring-up is judged by one pure function. **Drag is a skin over
`scan{uid}`**; click-to-scan is the primary path and the keyboard walks the same verbs. A headless test can
play a whole shift, and a night still replays exactly from `{config, seed, actions}`.

---

## 1. One customer, start to finish

**22:41. Nadia** is at the counter — night-shift nurse, bust seated behind the laminate at
`PORTRAIT_CENTRE_X_RING 210`. Her talk graph ran its four lines and you took the friendly answer. On the last
`talk_advance` the node's `serve:true` fires the engine-internal `place_basket`: **the screen changes mode, not
scene.** The DialogueBox slides down and out over 140 ms and, in the same beat, her items *drop onto the
counter* — a 14×36 Mate bottle and a 30×34 Pfand crate with `×3` on it — each landing with a 2-px squash and a
soft glass tick, 60 ms apart. This is the hook: **her order becomes objects in front of you.**

The frame now reads:

| Zone | Rect (base px) | What is in it |
|---|---|---|
| Hud | `(2,2,·,20)` | clock · cash · "Night 3 · 2 waiting" (`set_compact(true)`: right plate down) |
| **OrderCard** | `ORDER_RECT (4,56,132,106)` | her words, one `RequestChip` per line (Tab swaps it for `StatsStrip`) |
| Portrait | centre x 210, bottom y 200 | Nadia, `expression` from the talk, breathing |
| **CounterTray** | `TRAY_RECT (6,172,272,42)` | 7 slots, pitch 38, sprites bottom-aligned on y 210 |
| **Scanner** | `SCANNER_RECT (284,174,52,48)` | the drop target |
| **RegisterDisplay** | `REGISTER_RECT (340,30,138,232)` | lines, Pfand row, TOTAL, three buttons |
| DialogueBox | bottom edge on `DIALOGUE_RECT`, `DIALOGUE_W_RING 264` | hidden until somebody speaks |

The OrderCard, in her voice:

```
  Nadia
  1×  [bottle]  Mate              ✓
  2×  [▲]       Cigarettes
  1×  [▤]       Papers, long
  3×  Pfand
```

`[▲]` is a 16×16 mark on deep red — **no brand name.** The Mate is the only thing on the counter with a real
object; the cigarettes and the papers exist only as words, because she cannot reach the wall behind you.

**The drag.** Press on the Mate. It lifts 2 px, casts a 1-px `Palette.SHADOW` ellipse and follows the cursor
snapped to whole game pixels. The scanner's glass goes to `Palette.ACCENT` at 30 % the moment the carried
item's centre enters its 60×56 hot zone (4-px bleed all round — at ×4 that is 240 screen px, generous).
Release: the item hops 4 px into the well, the glass flashes white for 2 frames, a two-tone rising beep
(880→1320 Hz, 40 ms), and a line slides into the register from the right:

```
  Mate                1     1,80
```

The total counts up from `0,00` to `1,80` over 180 ms (the same ramp `TallyRow.play` uses). The tray sprite
stays where it is at 55 % alpha with a `Palette.GOOD` tick — the counter is the physical truth, the register is
the claim. On the OrderCard the Mate chip ticks. **One gesture, three confirmations: sound, line, tick.**
A press-and-release without moving 3 px does exactly the same thing.

**Turning around.** Press **Turn around** in the register foot (or `Q`). The whole frame slides left over
160 ms and the tobacco wall slides in from the right — a pivot, not a fade, so your body did something.
Fluorescent cool-white replaces the amber counter light. Three shelves of facings with a price rail under
each. The OrderCard rides along, docked at `ORDER_RECT_WALL (4,4,132,62)`, and the running total rides along
in a small plate at `WALL_TOTAL_RECT (372,6,104,16)` — the red mark and the money never leave the screen.

You hover **Adler** (deep red, white chevron): it lifts 2 px and its rail highlights. You click it twice —
two packs into the **hand strip** at `WALL_HAND_RECT (8,232,240,26)`, which now shows `▲ ▲`, because she said
two. One more click on the long cream booklet. **Back** (or `Q`, or Esc) pivots you home and the three items
land on the tray where there was space, with the same drop tick. While you are turned around her patience runs
at `BACK_PATIENCE_MULT 1.15` — the wall costs something — but any basket containing tobacco was granted
`TOBACCO_PATIENCE_BONUS_MS 4000` at spawn, so the trip is a rhythm, not a panic.

Then you scan them. Each one, separately. The second Adler does not add a line: it bumps the existing line to
`2` with a stepped ×-ping. Total `18,80`.

**The wrong pack.** Say you grabbed **Nordstern** (navy, star). Nothing stops you — the wall does not know
what she wants. It lands, you scan it, and the register line carries the navy mark against her red chip: the
chip does *not* tick and the line takes a 1-px `Palette.WARN` edge. The tell is there if you read it. Press
**Ring up** anyway and the reducer **rejects the first bad ring-up**: the drawer does not open, her portrait
switches to `wary`, a one-line correction floats over the counter in the DialogueBox — *"That was the red one,
love. The one with the bird."* — patience docks `CORRECTION_MS 8000`, the register stays open and the offending
line keeps its flag. Press **×** on it (or drag the line back onto the tray) to unscan, fix, ring again. **One
free correction per customer.** The second `ring_up` commits exactly as rung, money and all. *Forgiving once,
consequential twice — Coffee Talk pace, not Overcooked.*

**The finish.** Total `19,35` after the Pfand. Ring up: the drawer chunks, the lines wipe right-to-left over
200 ms, `Fx` pops a coin for `serve` and again for `tip`, the tray clears, Nadia says her goodbye in a one-line
box and slides out, the QueueStrip un-greys. Empty counter, amber light, 22:43.

---

## 2. The tobacco catalogue

**Brands are variants of an existing SKU, not new SKUs.** `inventory["cigarettes"]` keeps one stock number and
one price for the wholesaler and the ManageBoard; a brand carries identity only — a name, a **mark** (a shape a
26×34 pack can hold and a 16×16 chip can repeat) and a colour. Per-brand stock and per-brand prices are
explicitly out of the slice (§7). New content file `godot/engine/content/tobacco.gd`, shape
`{id, sku, name, mark, colour, band}`:

**Cigarettes** — `sku:"cigarettes"`, 8,00 €, pack sprite **26×34**.

| id | Name | Mark (the whole shape, ≤ 16×16 blocks) | Colour | Band |
|---|---|---|---|---|
| `adler` | Adler | blunt white chevron wedge, 3 blocks | `#b2372f` deep red | `#efe6d2` |
| `nordstern` | Nordstern | 8-point star, one core block + 4 arms | `#1e3a63` navy | `#ffffff` |
| `kranich` | Kranich | S-hook crane neck, 2 blocks | `#2f7a5f` jade | `#efe6d2` |
| `luxor` | Luxor | stepped pyramid, 3 rows | `#c9a227` gold | `#3a2a12` |
| `elbe` | Elbe | two stacked ripples | `#2e7d8c` teal | `#efe6d2` |
| `bergmann` | Bergmann | notched triangle peak | `#5a6b8c` slate | `#d8d2c4` |
| `fuchs` | Fuchs | two ear triangles over a muzzle block | `#d2691e` orange | `#2a1a12` |
| `perle` | Perle | filled circle with one highlight block | `#c8c3bb` pearl | `#4a4238` |

**Rolling tobacco** — `sku:"tobacco"`, 11,00 €, soft pouch **28×26**.

| id | Name | Mark | Colour | Band |
|---|---|---|---|---|
| `dreiringe` | Drei Ringe | three rings in a row | `#6b7a3a` olive | `#efe6d2` |
| `altepost` | Alte Post | posthorn spiral | `#7a4a26` brown | `#e8dcc0` |
| `zunder` | Zunder | 4-block flint spark | `#2a2a30` charcoal | `#d8712c` |
| `kiezgold` | Kiez Gold | 3-block crown | `#5e1b2c` maroon | `#d8a83c` |

**Papers** — `sku:"papers"`, 1,00 €. Two lengths × three kinds = 6 variants; **the length is in the
silhouette, not a label**: `lang` **20×30**, `kurz` **20×24**. Kinds: **Feder** (cream, ultra-thin),
**Braun** (kraft, unbleached), **Kohle** (black, charcoal). Ids `pap_feder_lang` … `pap_kohle_kurz`.

**Filters** — `sku:"filters"`, a **new SKU** (§3.6), 1,00 €, box **22×22**. Two gauges × two kinds:
`fil_slim`, `fil_slim_kohle`, `fil_reg`, `fil_reg_kohle` — "slim / regular" × "regular / charcoal".

**Two content invariants, both tested (§6):** every brand's `(mark, colour)` pair is unique, **no two marks
are separable by colour alone** (the shape always carries the answer — the colour-blind rule `Meter` already
obeys), and **all twelve brand colours differ by ≥ 40 RGB Euclidean distance** (the minimum above is 45.1 —
the swatch game must be winnable). The two tests catch opposite failure modes; ship both.

### How a customer phrases it

English base with the Kiez's own nouns left in German, per the `strings.gd` header. The archetype owns the
register; the engine formats the line **once, at spawn**, into `order[i].said`, so the talk graph, the
OrderCard and any test read one string and can never disagree.

| `archetype.speech` | Who | Line | The chip shows |
|---|---|---|---|
| `"mark"` **(default)** | strangers — the brief's case | "Two of the ones with the eagle. Cigarettes." | mark + colour + category |
| `"name"` | regulars (Mehmet, Jürgen) | "Two Adler, bitte." | mark + colour + **name** |
| `"colour"` | drunks, tourists at 04:00 | "Two red ones. Cigarettes." | colour swatch + `?` |

`config.brand_hint` is the global override: `"both"` on night 1 as a tutorial, `"name"` as a mercy setting,
`""` (default) lets the archetype decide. **In `mark` mode the chip prints the swatch and the category and
never the brand name — that is the difference between reading a list and running a shop.**

Templates in `Strings`: `ASK_CIGS "%d× %s — cigarettes."` · `ASK_POUCH "%d× %s — rolling tobacco."` ·
`ASK_PAPERS "Papers, %s, the %s ones."` · `ASK_FILTERS "Filters, %s, %s."` ·
`ASK_MARK_PHRASE "the ones with the %s"` · `ASK_TAIL "That's it."`

**The mark texture costs zero assets.** Every pack and pouch sprite must place its mark inside a **fixed 16×16
window at (4,6)**, and `BrandMark` draws `AtlasTexture(pack, Rect2i(4,6,16,16))` — 1:1, no scaling, legal on
the pixel grid. The chip and the facing are literally the same pixels, so the matching game is honest by
construction. **Fallback:** when `Assets.is_real(pack)` is false, `BrandMark` **draws the mark from
`{mark, colour}`** instead, so the puzzle is playable and testable on day one and never breaks on art.

---

## 3. Engine contract additions (docs/05 style)

### 3.1 State

```
active.basket:   Array[{ sku:String, brand:String, qty:int, said:String, placed:bool }]
active.counter:  Array[{ uid:int, sku:String, brand:String, kind:"item"|"crate", count:int, scanned:bool, origin:"customer"|"wall" }]
active.register: { lines: Array[{ sku:String, brand:String, qty:int, uids:Array[int] }],
                   pfand_bottles:int, id_checked:bool, corrections:int, flagged:Array[int] }
active.hand:     Array[{ uid, sku, brand }]         # carried back from the wall, HAND_MAX 4
view_mode:       "counter" | "wall"                 # TOP LEVEL
next_item_uid:   int                                # TOP LEVEL
last_verdict:    {} | { ok, accuracy:float, missing:[], extra:[], wrong_brand:[], wrong_count:[], refused:[] }
```

**Everything that dies with the customer lives under `active`** — verified against `rules.gd:237`, where
`_next_customer` does `n["active"] = {}`. Nesting makes counter/register desync structurally impossible rather
than a thing you must remember to clear. **`view_mode` and `next_item_uid` stay top level on purpose:** which
way your body is facing, and the uid counter, must survive a customer leaving while you are at the wall.
`brand` is `""` for non-tobacco. `active.want` remains `basket[0].sku`, which keeps `{want}` substitution,
`WantBubble` and the docs/06 §7 auto-serve working untouched. All JSON-safe; everything round-trips
`from_json`.

**Reducer caps, not UI caps:** a basket is **≤ 4 distinct lines, ≤ 6 units, ≤ 3 placed units**. The tray
therefore cannot overflow its 7 slots (3 placed + 3 fetched + 1 crate) and a content mistake cannot break the
frame. Tested.

### 3.2 Actions

| Action | Legal when |
|---|---|
| `scan{uid}` | night · `active` · no talk open · `view_mode=="counter"` · uid on `active.counter` · `not scanned` |
| `register_remove{line}` | line in range; every uid on it returns to `scanned:false` |
| `register_set_qty{line, qty}` | line in range · `1 ≤ qty ≤ 9` · `qty ≤ inventory[sku].stock`; lowering below `uids.size()` un-scans the last uid |
| `turn_around{on:bool}` | `active` · no talk open · no drag in flight; costs `TURN_MS 1200` of night clock |
| `take_from_wall{sku, brand}` | `view_mode=="wall"` · `inventory[sku].stock > 0` · `hand.size() < HAND_MAX` |
| `put_back{uid}` | `view_mode=="wall"` · `origin=="wall"` · `not scanned` |
| `set_pfand{bottles}` | `0 ≤ bottles ≤ active.bottles` (the existing `_serve` clamp, unchanged) |
| `check_id` | `active` · `not id_checked` — a real Späti verb, free in the reducer |
| `ring_up` | `view_mode=="counter"` · (`lines` non-empty **or** `pfand_bottles > 0`) |
| `skip_active` | unchanged — "Wave off" |
| `serve_active{give, pfand_bottles}` | **legacy alias** (§3.6): expands `give` into lines, then rings up |

`place_basket` and `_correction` stay engine-internal. `legal_actions` emits one `scan` per unscanned uid, one
`take_from_wall` per in-stock facing **only while `view_mode=="wall"`**, and `register_*` per real line index —
never an index out of range, and nothing register-shaped while a talk is open.

### 3.3 Read-model (`Rules.view`)

```
view.counter:   [{ uid, sku_id, name, brand, mark, colour, icon, kind, count, scanned, slot }]
view.register:  { lines:[{ sku_id, name, brand, mark, colour, qty, unit_price, line_total, restricted, matches:bool }],
                  pfand_bottles, pfand_line:float, subtotal, total, can_ring:bool,
                  id_checked:bool, correction:String }
view.order:     [{ said, qty, category, brand, mark, colour, name_shown:bool, satisfied:bool, icon }]
view.view_mode: String
view.wall:      {} | { shelves:[{ label, price, cells:[{ sku_id, brand, name, mark, colour, stock, row, col }] }], hand:[…] }
```

`matches` and `satisfied` are **derived in the engine, never in the UI** — the ticks and the amber edges are
the reducer's opinion, so a screen cannot lie about correctness. `total` includes `−pfand_line` and may go
negative.

### 3.4 Correctness at `ring_up`

`Economy.order_accuracy(basket, lines, arch)` compares two multisets keyed `(sku, brand)` and returns five
buckets plus a score:

- **missing** — an order key with `got < want`.
- **extra** — a rung key absent from the order; the units are **voided**: no revenue, no stock movement. The
  shop never quietly profits from your mistake. She catches it ("I didn't take that").
- **wrong_brand** — right `sku`, wrong `brand`. Its own bucket, weighted **half** of `extra`: reaching for the
  navy pack is a different sin from inventing a sale.
- **wrong_count** — right key, wrong quantity; the delta counts.
- **refused** — a `restricted` line when `arch.underage` **and** `id_checked`: the line is dropped at ring-up,
  logged `kind:"ethics"` with `data.refused`, never charged, and removed from *both* sides before scoring, so
  doing the right thing is not scored as `missing`. Integrity +1, kiez `−0.2 × kiez_sensitivity` (they are
  annoyed, and that is the price of the spine).

```
errors   = missing + extra + 0.5*wrong_brand + wrong_count_delta
accuracy = clamp(1 - errors / max(1, wanted_units), 0, 1)
```

**The compatibility mapping is exact, so `test_economy.gd` stays green.**
`Economy.satisfaction(got_wanted:bool, …)` widens to `satisfaction(accuracy:float, …)` with
`s := 0.25 + 0.45 * accuracy` — preserving `economy.gd:34`'s endpoints (`false → 0.25`, `true → 0.70`) exactly —
and every existing call site passes `1.0` / `0.0`. The kiez miss-penalty generalises `rules.gd:284` from
`0.3 * kiez_sensitivity` to **`0.3 * kiez_sensitivity * (1 - accuracy)`**. One number, one path; the
half-weight for `wrong_brand` lives in the error weighting above and is not double-counted anywhere else.

**Money follows the register, not the order.** Under-ring and you are short; over-ring and the extras are
voided and you pay in Kiez-Trust. `unit_price = inventory[sku].price` (no per-brand delta in the slice).
Stock decrements per surviving rung unit. Restricted × underage **without** an ID check keeps today's path
exactly: −8 Integrity once per line, one `ethics` log entry.

**The one free correction.** The first `ring_up` whose `accuracy < 1.0` is **rejected**: the state returns with
`active.register.corrections = 1`, `active.expression = "wary"`, `active.register.correction` set to an
in-character line, `patience_left_ms -= CORRECTION_MS 8000`, the offending line indices in
`active.register.flagged`, and the register still open. The second `ring_up` commits as rung. `corrections` is
per customer and dies with `active`.

`ring_up` finally stashes `last_verdict`, logs `serve` / `tip` / `misring` (the diff rides in `data`, which is
what the DialogueBox reads to pick her reaction line) and calls `_next_customer`.

### 3.5 Pfand

Arithmetic unchanged (`PFAND_PER_BOTTLE 0.15`, `PFAND_MAX_RETURN 6`, clamped to `active.bottles` inside
`_serve`), with two new faces. **It is a ticket line, not only a register row:** her empties get an OrderCard
chip like any other request, so *forgetting the deposit scores as `missing`* and returning it is part of the
order. Physically it is **one crate sprite** (30×34) in tray slot 0 with a `×3` badge — not three loose
bottles, which would eat the tray. Dragging the crate onto the register's Pfand row `PFAND_ROW_RECT
(344,154,130,16)` dispatches `set_pfand{bottles: count}`; the row's `−`/`+` `StepButton`s tune it. Two input
paths, one action, one clamp — in the reducer, where a component cannot invent a quantity that moves cash.

### 3.6 New SKU, and the old path

`skus.gd` gains **`filters`** — `{"id":"filters","name":"Filters","category":"tobacco","cost":0.35,
"base_price":1.0,"fair_lo":0.8,"fair_hi":1.6,"demand":0.5,"icon":"sku/filters"}`. It is a real SKU, so it
appears on the ManageBoard with stock and a price band like everything else. (`cigarettes`, `tobacco`,
`papers` and `vape` already exist; `filters` is genuinely new.)

**The single-want path is kept, not retired — precisely:** `ring_up` *lowers to* the existing `_serve` core
(expand surviving lines into a flat `give` array, pass the accuracy struct), so there is one money path, one
`serve` log entry, one `_next_customer`. `serve_active{give, pfand_bottles}` therefore stays legal and remains
what **docs/06 §7's auto-serve on `next:""` dispatches** and what `AutoPlayer` uses; a customer served that way
never populates `active.counter`, so `test_night.gd` and `test_dialogue.gd` keep passing unchanged.
**`ServePanel` / `Shelf` / `Till` are demoted to a debug affordance behind `play.mjs --serve`** — they leave
the shipped Night screen, and `SERVE_TOGGLE_RECT` goes with them.

---

## 4. Components, layout and drag

### 4.1 New pool entries (add to `docs/04`)

| Component | Contract |
|---|---|
| **BrandMark** | `set_brand({mark, colour, pack_id})`; sizes 8 / 12 / 16. Shipping path: `AtlasTexture(pack, Rect2i(4,6,16,16))`. Fallback: code-drawn from `{mark, colour}` when `Assets.is_real(pack)` is false. **The one place a mark is drawn.** |
| **DragItem** | One carried sprite: lift 2 px, 1-px `Palette.SHADOW` ellipse, `Palette.snap()` per `_process`. No state. |
| **DragLayer** | `begin(payload:Dictionary, texture_id:String, from:Vector2)`, `is_dragging()`, `cancel()`; signal `dropped(payload, at)`. Hit-tests the group `"drop_targets"` on release, topmost `accepts(payload)` wins; springs home over `DRAG_SPRING_MS 120` on a miss. |
| **CounterTray** | `render(view.counter)`; 7 focusable slots on `TRAY_RECT`, pitch 38, sprites bottom-aligned y 210, scanned slots at 55 % + tick. Signals `scan_requested(uid)`, `drag_started(uid)`. Mounted into the new `SceneLayers` slot **`OnCounter`**. |
| **Scanner** | `SCANNER_RECT`, in group `"drop_targets"`. `set_armed(bool)`, `flash()`; signal `scanned(uid)`. 4-px hot-zone bleed on every side. |
| **RegisterDisplay** | `render(view.register)` on `REGISTER_RECT`. Supersedes **Till** on the shipped screen. Rows: mark · name · `−` qty `+` (the existing `StepButton` theme variation) · `×` · line total; then the Pfand row, a rule, TOTAL in `FONT_LEAD 20` (count-up reuses `TallyRow.play`'s ramp), then three stacked 130×18 buttons — **Turn around** (344,202), **Ring up** (344,222), **Wave off** (344,242). Signals carry finished action dictionaries: `action(Dictionary)`. |
| **OrderCard** / **RequestChip** | `render(view.order)` on `ORDER_RECT`; ≤ 5 chips (4 lines + Pfand) at 20 px, ticked when `satisfied`. Re-docks to `ORDER_RECT_WALL` while `view_mode=="wall"`. |
| **TobaccoWall** / **WallCell** | Full-frame `Control`. `render(view.wall)`, `open()` / `close()`; each cell a focusable `PixelButton`, signal `taken(sku, brand)`. |

Reused unchanged: `Portrait`, `DialogueBox`, `QueueStrip`, `Hud`, `StatsStrip`, `Fx`, `PixelButton`,
`PixelPanel`, `Modal`, `Assets`, `Palette`, `Strings`. New layout constants are **named in `Palette`** beside
the shipped ones — `ORDER_RECT`, `ORDER_RECT_WALL`, `TRAY_RECT`, `TRAY_SLOTS 7`, `TRAY_PITCH 38`,
`SCANNER_RECT`, `REGISTER_RECT`, `PFAND_ROW_RECT`, `WALL_HAND_RECT`, `WALL_BACK_RECT`, `WALL_TOTAL_RECT`,
`DIALOGUE_W_RING 264`, `PORTRAIT_CENTRE_X_RING 210` — never an ad-hoc rect in a scene.

### 4.2 Drag: manual and pointer-driven, **not** Godot's built-in DnD

**Use `DragLayer`.** Godot's `_get_drag_data` / `_can_drop_data` / `_drop_data` was evaluated and **rejected**;
the four reasons are recorded here so the next person does not try it again:

1. `get_global_mouse_position()` returns **fractional** base pixels (0.25 steps at ×4) — the preview shimmers
   off the grid unless it re-snaps every frame.
2. `set_drag_preview()` **reparents the preview outside the screen's tree**, so it renders unthemed.
3. Drag data must be a **plain Dictionary** (`{kind:"item", uid:int}`), never a node reference: the night
   re-renders every frame and the tray rebuilds under the drag.
4. Godot starts a drag only after a few *screen* pixels of motion — **sub-base-pixel at ×4** — and it offers
   **no keyboard path and no headless driver**, while this project's entire test culture is synthesising
   `InputEvent`s into a SubViewport (§6).

`DragLayer` answers all four: it snaps with `Palette.snap()` every `_process`, keeps the theme, carries a plain
payload, and uses a **3-px grab threshold** — under that it is a click, and a click on a tray item scans it.

**Click-to-scan is the primary path; drag is the feel, never the requirement.** **Keyboard is the same verbs:**
`Tab` / arrows walk tray → scanner → register lines → Pfand row → the three buttons behind a 1-px
`Palette.ACCENT` focus box; `Space` on a tray slot scans it (or picks it up, so it rides the focus box, and
`Space` on the scanner drops it); `Q` turns around, `Esc` turns back; `Delete` removes a line; `+` / `−` change
its qty; `Enter` rings up. Pointer, click and key all emit **the same action dictionary** — there is no path a
mouse can reach that a key cannot.

### 4.3 Where it sits, and how the turn-around is staged

`Night._place_chrome` gains a third mutually-exclusive mode beside today's two:
**`talk`** (box 400 / 300, queue right, no tray) · **`register`** (box hidden until somebody speaks, then
`DIALOGUE_W_RING 264` bottom-left; OrderCard owns the left gutter and Tab swaps it for `StatsStrip`; tray +
scanner own the counter band; the register owns the right column, replacing `DICE_RECT` / `QUEUE_RECT`, and the
queue collapses into the Hud's existing "N waiting" tail) · **`wall`**.

`SceneLayers` gains one slot: **`OnCounter`, after `Counter`, before `Tint`** — that is where `CounterTray`
mounts, and it is the whole reason items read as sitting *on* the laminate in front of the bust, exactly as in
the reference photo.

**The wall is a full-frame overlay inside `Night`, not a second `SceneLayers` set.** It has no rain, no neon,
no counter and no bust, so a whole layer stack would be dead weight; and it is a camera turn, not a location —
the night keeps ticking, patience keeps running, one screen owns the state machine and one `render(view)`
drives everything. It enters with a 160-ms horizontal pivot (shop +480, wall −480 → 0), instant under
`Palette.reduce_motion`, and it **remembers its focused cell between trips**.

Wall grid (480×270): **shelf 1** cigarettes, 8 facings 26×34 at y 66, pitch 52, x₀ 32, price rail y 102–118 ·
**shelf 2** rolling tobacco, 4 pouches 28×26 at y 130, pitch 72, x₀ 118, rail y 152–168 · **shelf 3** papers +
filters, 10 facings (20×30 / 20×24 / 22×22) bottom-aligned y 208, pitch 42, x₀ 40, rail y 210–226. Price rails
are 16 px tall because 16 is the only body text size (docs/01), and they carry the parent SKU's price — one
price per rail, exactly like the reference photo. Hand strip `(8,232,240,26)`, **Back** `(400,232,72,20)`,
running total `(372,6,104,16)`, OrderCard `(4,4,132,62)`.

---

## 5. Art list (`docs/asset-spec.json` entry sketches)

All props: `"kind":"prop"`, `"transparent":true`, `"filter":"lanczos"` — **the repo's prop convention;
`nearest` is the *scene* value, and `sku/beer` and `sku/cigarettes`, the closest analogues to a pack sprite,
are both lanczos.** Model comes from `modelByKind`: `gpt-5.6-sol` for props and icons, `gpt-6-astra` for the
scene. Every prompt inherits the shipped discipline verbatim from `sku/cigarettes`: *a TRUE pixel sprite drawn
on a strict block grid at exactly w×h blocks, every block one flat colour, every edge on a block boundary, at
most 6 flat colours plus one near-black `#160f14` 1-block contour all round, one warm lighter column on the
left and one cool darker column on the right, no anti-aliasing / gradients / dithering / sub-block detail, and
absolutely **NO text, letters, numbers, logos, barcodes, health warnings or seals**.*

| id | kind | w×h | gen / aspect | one-line prompt |
|---|---|---|---|---|
| `tob/pack_adler` … `tob/pack_perle` (8) | prop | 26×34 | 1024x1024 / square | upright flip-top cigarette pack, straight-on front, flat `<colour>` body, a broad flat `<band>` band across the lower third, and **one** flat two-tone `<mark>` emblem occupying exactly 16×16 blocks with its top-left corner at block (4,6) |
| `tob/pouch_dreiringe` … `tob/pouch_kiezgold` (4) | prop | 28×26 | 1024x1024 / square | soft rolling-tobacco pouch face-on with a folded flap and rounded corners, flat `<colour>` body, `<band>` foot strip, one `<mark>` emblem 16×16 blocks at block (4,6) |
| `tob/paper_feder_lang` / `_braun_lang` / `_kohle_lang` (3) | prop | 20×30 | 1024x1536 / portrait | slim tall booklet of rolling papers face-on, `<cream / kraft-brown / matte-black>` cover, one thin darker band at the foot |
| `tob/paper_feder_kurz` / `_braun_kurz` / `_kohle_kurz` (3) | prop | 20×24 | 1024x1024 / square | the same booklet, visibly **shorter** — the length is the silhouette, never a label |
| `tob/filter_slim` / `_slim_kohle` / `_reg` / `_reg_kohle` (4) | prop | 22×22 | 1024x1024 / square | small flip-top box of cigarette filters, `<colour>` body, cream lid, three round filter ends showing at the top edge |
| `prop/scanner` | prop | 44×40 | 1024x1024 / square | squat counter barcode scanner seen slightly from above, dark grey wedge body, dark-red glass window across the top face, one cable stub |
| `prop/pfand_crate` | prop | 30×34 | 1024x1024 / square | low plastic Pfand crate holding three stubby empty green bottles, front view |
| `scene/tobacco_wall` | scene · `gpt-6-astra` | 480×270 | 1536x1024 / landscape · `"mode":"cover"` · `"filter":"nearest"` · `"transparent":false` | the tobacco wall of a real Berlin Späti seen straight-on from the **shopkeeper's side**: floor-to-ceiling white metal rails, per-row price strips, a backlit blank brand board above, vape boxes on the right rails, cool-white fluorescent light, shallow depth. **Leave the rails EMPTY — the packs are sprites.** |
| `ui/icon_scan` | icon | 16×16 | 1024x1024 / square · `"mode":"exact"` | four thick barcode bars crossed by one red horizontal line |

**25 entries: 23 props, 1 scene, 1 icon.** The register chrome, the tray slots, the price rails, the order
chips and every mark are **code-drawn** (docs/02: chrome is never generated); brand colours arrive through the
read-model as values, never as a `Color(…)` literal in a `.tscn`, so `test_scenes_write_no_colours` stays
green. The existing `sku/cigarettes`, `sku/tobacco` and `sku/papers` icons stay exactly as they are — they are
the ManageBoard's parent-SKU icons; the `tob/*` sprites are the wall and tray facings.

**Family consistency without a pipeline change.** `tools/codex/art.mjs` is **per-id**; sheet-generating eight
packs in one call and slicing them is an unbudgeted tool change, so do not assume it. Instead: generate
`tob/pack_adler` first, get it judged, then **add the approved PNG to every other pack's `refs`** so the eight
share one palette weight and one outline weight. Same for the six booklets off `tob/paper_feder_lang`. If the
art lane later wants the single-call sheet, cost the `art.mjs` change explicitly first.

---

## 6. Tests

**`test_register.gd` (reducer, headless).** `scan` twice on one uid is illegal and returns `s` **itself**
(identity, not a copy); `scan` is illegal while `view_mode=="wall"` and while a talk is open.
`take_from_wall` respects stock and `HAND_MAX 4`; `take_from_wall` → `put_back` round-trips (stock, lines and
`to_json` unchanged but for `next_item_uid`). `register_set_qty` clamps 1..9 and to stock and un-scans surplus
uids; `register_remove` returns every uid to `scanned:false`; out-of-range indices change nothing. **Each
accuracy bucket** — exact / missing / extra / wrong_brand / wrong_count / refused — lands in its own bucket
with the documented score, and `extra` moves **no** revenue and **no** stock. The **first bad `ring_up` is
rejected**: no drawer, `corrections == 1`, `expression == "wary"`, `patience_left_ms` down by 8000, register
still open; the second commits. `turn_around` advances `clock_ms` by `TURN_MS 1200` and is illegal mid-talk and
mid-drag. `set_pfand` clamps to `active.bottles`; the deposit is `PFAND_PER_BOTTLE × bottles` exactly.
Restricted × underage: −8 Integrity **once per line**; with `check_id` the line is `refused`, never charged,
and not scored as missing. The caps hold: no generated basket exceeds 4 lines / 6 units / 3 placed. The P&L
identity `profit = revenue + tips − cogs − bills − pfand − fines` still balances after 20 basket serves.

**`test_economy.gd` must stay green unchanged** — that is the whole point of the `0.25 + 0.45 × accuracy`
mapping.

**`test_content_tobacco.gd`.** Every brand has a pack asset id present in *both* `docs/asset-spec.json` and
`Assets.SIZES`; **the 16×16 mark window at (4,6) fits inside every declared size**; every `(mark, colour)`
pair is unique and **no two marks are separable by colour alone**; **all twelve brand colours differ by ≥ 40
RGB distance**; every variant a basket can generate resolves to a SKU and a brand; every phrase template
formats with its args.

**`test_determinism.gd`.** A 7-night `AutoPlayer` season that includes wall trips and corrections round-trips
to an identical `to_json`.

**`test_scenes.gd`.** `MockView` gains `register_mixed`, `register_wrong`, `register_pfand` and
`tobacco_wall`, checked key-for-key against a **real `Rules.view(state)`** by the existing comparison test.
Every new component instantiates and `render()`s headless; no `Color(` and no literal strings in any new
`.tscn` / `.gd`; `Assets.size_of` matches the spec for every new id.

**`test_register_reachability.gd` (standing, enforced per build).** For every state the `AutoPlayer` reaches,
each entry of `legal_actions` must map to a **visible, focusable** control (`Night.controls_for(action)`
non-empty); and `ui_focus_next` ×40 from a cold start must reach the tray, the scanner, the wall toggle, every
register line, the Pfand row and Ring up, never focusing an invisible or disabled node.

**`playthrough.gd` / `play.mjs --register` (pointer-driven, enforced per run) — and the anti-soft-lock rule.**
Today's soft-lock shipped because the driver pressed buttons **by node name**. The register driver may not.
For each step it (1) reads `Rules.legal_actions(state)`, (2) finds the on-screen node that **offers** that
action, (3) synthesises a real `InputEventMouseMotion` + `InputEventMouseButton` at its global rect centre — a
genuine press-move-release for `scan` — and (4) asserts the state actually changed. Full run: take a guest →
walk the talk → the basket lands → drag the Mate to the scanner → turn around → take 2× Adler and a booklet →
turn back → scan all three → `+` a line → Ring up → assert `tally.sales` +1, `cash` moved and
`active.counter.is_empty()`. Two guards run after **every** step: `legal_actions().size() > 0` unless the night
has ended (soft-lock), and a failure if `DragLayer.is_dragging()` persists past 2 s (stuck drag). A
`register_wrong` variant asserts the correction fires **once and only once**. Keep both this and the
reachability test: one enforces per run, the other per build.

---

## 7. Risks, and what to cut

| Risk | Mitigation |
|---|---|
| Drag jitters off the pixel grid at ×4 | manual `DragLayer` + `Palette.snap()` per frame; never Godot's built-in preview (§4.2) |
| The turn-around turns cosy into Overcooked | `TURN_MS 1200`, `BACK_PATIENCE_MULT 1.15` (not 1.35), `+4000 ms` patience on any basket containing tobacco, and the wall remembers its focused cell |
| Correctness feels punishing | one free correction, spoken in character, with the wrong line already flagged **before** you press Ring up; extras are voided rather than silently profitable |
| 23 new sprites is a whole art-lane round | marks cost zero assets (atlas crops), `BrandMark`'s code-drawn fallback ships the mechanic before the art does, and family consistency comes from shared `refs`, not a new tool |
| The counter band is crowded | mode exclusivity: dialogue **or** tray, never both; the tray drops to 5 slots + "+N" if it still reads busy |
| Mark legibility at 16×16 | chevron, 8-point star, crane hook, pyramid, ripples, peak, ears, circle, rings, spiral, spark and crown all survive an 8×8 core; the **crane hook is weakest** — swap it for a wing chevron if the judge cannot read it |
| Colour-only matching excludes colour-blind players | the shape is always sufficient; `speech:"colour"` is the *hard* tier and its chip always carries a `?` affordance to ask again |

**Explicitly out of the slice:** per-brand stock and per-brand prices. One stock number and one price per parent
SKU keeps the wholesaler, the ManageBoard and `restock` untouched. "We're out of Adler, take the Nordstern?" is
a named stretch, and a brand `price_delta` is the first thing to add when it lands.

**Cut in this order if time is short:** brand `price_delta` (already out) → `filters` entirely (4 variants, 4
sprites) → the `speech:"colour"` tier → the qty `−`/`+` (one line per physical unit) → the Pfand crate **drag**
(keep the row's buttons) → **drag entirely** (click-to-scan is already the primary path and the actions are
identical — zero reducer change) → brands 5–8 (four is enough to make matching real) → the wall backdrop art
(draw the rails from `Palette` tokens and let the pack sprites be the art) → the wall itself (tobacco rings up
from the tray like everything else and the turn-around becomes v1.1). **The reducer contract in §3 does not
change under any of these cuts** — which is the point of putting it first. The last cut costs the most feel, so
it is last.
