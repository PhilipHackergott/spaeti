# 04 — Component catalog (the central pool in `godot/components/`)

Every visible thing on every screen is one of these. Adding a component = add it here with its contract.
Screens compose; they never restyle. If you find yourself writing a `PanelContainer` with its own stylebox
inside a scene, stop: use a component, or add one here first.

**Three rules this pool enforces**

1. **One look.** Every colour, font size and screen constant lives in `components/theme.gd` (`class_name Palette`)
   and `components/Theme.tres`. A component may not write a raw hex; a scene may not write a stylebox — nor a
   `Color(...)` on a `ColorRect`. A screen that needs a veil or a hairline assigns the token in `_ready()`
   (`($Dim as ColorRect).color = Palette.DIM`); `test_scenes.gd::test_scenes_write_no_colours` greps every
   screen `.tscn` and fails if the word `Color(` reappears.
2. **Tree-optional.** Components find their own nodes with `get_node_or_null("%Name")` (never `@onready`) and guard
   every tween with `is_inside_tree()`, so `render()` works on an instance that was never added to a tree — which is
   how `tests/unit/test_scenes.gd` exercises them headless.
3. **Art-optional.** Nothing loads a texture directly; everything goes through `Assets.texture(id)`, which returns a
   placeholder of the exact base-pixel size until the art lane's PNG exists. Art lands with **no code change**.

## The pool

| Component | Scene / script (`class_name`) | Contract | Used by |
|---|---|---|---|
| **Palette** | `theme.gd` (`Palette`) | Tokens only, no nodes. Colours (`WOOD_DEEP…NEON_CYAN`, `INK`, `EDGE`, `SCRIM` (title veil) / `DIM` (behind a card) / `RULE` (1-px separator), `TEXT`, `GOOD/WARN/BAD`, `SPEAKER`, `TIER`), sizes (`FONT_SMALL 12 / FONT_BODY 16 / FONT_LEAD 24 / FONT_TITLE 48`), layout (`BASE 480×270`, `COUNTER_H/COUNTER_TOP`, `DIALOGUE_RECT`, `SERVE_RECT`), `static var reduce_motion`. Methods: `theme()` (loads Theme.tres and forces the pixel font to antialias-off / hinting-none / subpixel-off), `prepare()`, `speaker_colour(id)`, `tier_colour(tier)`, `box(...)->StyleBoxFlat`, `money(float)->"1,80 €"`, `snap(Vector2)`. | everything |
| **Theme** | `Theme.tres` | The one Theme: VT323 at 16 + styleboxes for `Button` (normal/hover/pressed/disabled/focus) and `PanelContainer`, plus type variations `DialoguePanel`, `BubblePanel`, `SlotPanel`, `SlotPanelPicked`, `ChoiceButton`, `TitleButton`, `HudPlate`, `FlatPanel`, `SpeakerLabel`, `SmallLabel`, `LeadLabel`, `TitleLabel`. Every box has `anti_aliasing = false`. | every scene root sets `theme` |
| **Assets** | `assets.gd` (`Assets`) | `texture(id)->Texture2D` (real PNG or generated placeholder), `portrait(portrait_id, expression)` — it resolves the EXPRESSION first (an id with neither a PNG nor a `SIZES` entry falls back to `_neutral`, docs/05 §6) so a missing expression keeps the bust's 190×230 footprint instead of collapsing to `FALLBACK_SIZE` —, `is_real(id)`, `size_of(id)` (mirrors `docs/asset-spec.json`; `test_scenes.gd::test_asset_sizes_match_the_spec` reads the spec and fails on any drift), `clear_cache()`. Placeholders: bust silhouette for `char/*`, room for `scene/*`, bottle/box for props, disc for `ui/*` — each in a hashed colour with the id stamped in a built-in 3×5 font. | every component that shows art |
| **MockView** | `mock_view.gd` (`MockView`) | `PRESETS`, `presets()`, `view(preset) -> Dictionary` shaped **exactly** like `Rules.view(state)` (docs/05 §5) for all nine capture presets, with the **same strings** the engine formats (`"Kiez-Trust 62"`, a German weekday from `Rules.WEEKDAY_NAMES`) — `test_scenes.gd::test_mock_view_speaks_the_engines_language` compares the values against `Rules.view()`, so a capture can never show text the engine cannot produce. Mock data only — no rules. | `Screen.apply_capture_preset`, tests |
| **Screen** | `screen.gd` (`Screen`, extends Control) | Base for composed screens. `@export default_preset`, `view()` (Session's when `/root/Session` exists, else the mock — a capture preset always wins), `render(v)` (override), `refresh()`, `dispatch(action)` (Session, else prints), `apply_capture_preset(name)`, signal `request_screen(name)`. | Title, Night, Manage, Summary |
| **PixelPanel** | `PixelPanel.tscn` / `pixel_panel.gd` (`PixelPanel`) | The generic dark translucent box. `@export title`, `@export variation` (`&"DialoguePanel"`, `&"SlotPanel"`, …), `content()`, `add_content(n)`, `clear_content()`. | ad-hoc panels |
| **PixelButton** | `PixelButton.tscn` / `pixel_button.gd` (`PixelButton`) | `extends Button`. `@export icon_id` (through Assets), `@export action: Dictionary` (an engine action), signal `activated(action)` on top of `pressed`. Focus ring from the Theme, so the keyboard works. | every clickable |
| **Meter** | `Meter.tscn` / `meter.gd` (`Meter`) | Icon + label + segmented bar; colourblind-safe (icon + number carry the meaning). `@export icon_id/label_text/value 0..1/fill/segments`, `set_reading(value, text)`. | Hud |
| **ItemSlot** | `ItemSlot.tscn` / `item_slot.gd` (`ItemSlot`) | One SKU: icon, name, price (coloured by `tier`), stock, corner badge (till count, or `18` when restricted). `@export sku: Dictionary` (a `view.shelf` entry), `@export count`, signal `picked(sku_id)`; click or `ui_accept`, out-of-stock slots dim and do not emit. 44×44. | Shelf |
| **Shelf** | `Shelf.tscn` / `shelf.gd` (`Shelf`) | 5-column grid of ItemSlots. `set_items(items, counts := {})`, `set_counts(counts)`, `slot_for(sku_id)`, signal `picked(sku_id)`. Re-uses slots between renders. | ServePanel |
| **Till** | `Till.tscn` / `till.gd` (`Till`) | The ring-up tray. `set_lines/add_sku/set_pfand/set_pfand_rate/clear/counts/total/give_list`; signals `ring_up(give, pfand_bottles)`, `pfand_toggled`, `waved_off`, `line_removed`. Shows at most `MAX_ROWS` lines + a "+N more" row + the Pfand line, which prices the deposit from `pfand_rate` (fed from `view.pfand_rate`, never a literal — the tray must quote what the reducer pays); "Ring up" disables when the tray is empty. | ServePanel |
| **ServePanel** | `ServePanel.tscn` / `serve_panel.gd` (`ServePanel`) | Coffee Talk's brew panel: slides in over the right half (`SHOWN_X 236 → HIDDEN_X 482`), header names who is waiting, Shelf above, Till below. `render(view)`, `open(instant)`, `close(instant)`, `till()`, `preload_picks(sku_ids, pfand_bottles)` (capture presets); signals `serve(action)` — a ready-made `serve_active` — `waved_off`, `closed`. | Night |
| **DialogueBox** | `DialogueBox.tscn` / `dialogue_box.gd` (`DialogueBox`) | The centrepiece: coloured speaker name, white typewriter body (`chars_per_second`), a blinking code-drawn ▾ (a `Polygon2D`, because VT323 has no ▾ glyph), choices stacked just above the box. `show_dialogue(view.dialogue, instant)` (idempotent: the same speaker + lines + choices re-sent is ignored, so the per-frame render never restarts the typewriter), `show_final(d)` (capture: last line + choices), `advance()`, `clear()`, `is_typing()`; signals `choice(index)`, `advanced`, `finished`. Click or Space advances. | Night |
| **Portrait** | `Portrait.tscn` / `portrait.gd` (`Portrait`) | The bust, placed at its **native** size on integer pixels (never scaled). `@export portrait_id/expression/breathe`, `set_from_active(view.active)`, `slide_in()`, `slide_out()`; idle breathing is a stepped 1-px bob (rounded, so it stays on the grid) and stops under `Palette.reduce_motion`. | Night |
| **WantBubble** | `WantBubble.tscn` / `want_bubble.gd` (`WantBubble`) | Icon + name + price + optional line, with a code-drawn tail. `set_want(view.active.want, said := "")`, `@export line`. | Night |
| **SceneLayers** | `SceneLayers.tscn` / `scene_layers.gd` (`SceneLayers`) | The set, in draw order: `Backdrop → NeonGlow → Characters → Counter → Rain → Tint`. `@export backdrop_id/counter_id/night_progress/raining/rain_drops/neon`, `set_time(0..1)` (dusk → deep night → cold pre-dawn), `counter_top()`, **`mount(node)`** — puts a bust in the character slot *behind the counter*; it uses `reparent()` so the node keeps its `owner` (and therefore its `%unique name`). The counter art is always flush with the bottom of the frame whatever its height. Rain is seeded (1337) so a capture is reproducible; rain and neon flicker stop under `reduce_motion`. | Night, Manage, Summary |
| **Hud** | `Hud.tscn` / `hud.gd` (`Hud`) | Corner cluster on two low-alpha plates: clock / cash / Pfand + day + queue top-left, two Meters top-right. `render(view)`, `set_compact(on)` (hides the right plate while the serve panel owns that half). | Night |
| **TallyRow** | `TallyRow.tscn` / `tally_row.gd` (`TallyRow`) | One P&L line. `@export row_label/value/kind` (`in`/`out`/`total`/`plain` → sign, colour and size), `play(delay, duration)` counts the number up. | SummaryTally |
| **SummaryTally** | `SummaryTally.tscn` / `summary_tally.gd` (`SummaryTally`) | Builds the rows from a NightSummary: Umsatz, Trinkgeld, Einkauf, Miete+Strom, Pfand, rule, Gewinn. `set_summary(s)`, `play()` (staggered). | Summary |
| **ManageBoard** | `ManageBoard.tscn` / `manage_board.gd` (`ManageBoard`) | The pre-opening board: one row per SKU (stock, wholesale cost, restock −/+, price coloured from the engine's `tier` (`view.manage.restock_options[].tier`) against its fair band, price −/+, the band itself), the module list, and "Aufmachen". `render(view)`; signals `action(Dictionary)` (`restock` / `set_price` / `buy_upgrade`) and `open_night()`. Rows are built at runtime; the shell is in the `.tscn`. | Manage |
| **Modal** | `Modal.tscn` / `modal.gd` (`Modal`) | The one overlay shell: dimmer, centred frame, title, close button, Esc. `@export title/closable`, `open()`, `close_modal()`, `content()`, `add_content(n)` (reparents, keeping `owner`), `clear_content()`; signal `closed`. | Manage, Title (settings) |
| **Transition** | `Transition.tscn` / `transition.gd` (`Transition`) | Full-frame fade. `cover()`, `reveal()`, `cover_then(Callable)`; signals `covered`, `revealed`. | Main |

## The screens (`godot/scenes/`)

| Scene | Root | What it composes | Presets |
|---|---|---|---|
| `Main.tscn` / `main.gd` | Control | The shell: `%Screens` host + `Transition`. `show_screen(name, instant)`, `apply_capture_preset(p)` (maps preset → screen), `PRESET_SCREEN`. Boots to Title. | all (delegates) |
| `Title.tscn` / `title.gd` | Screen | `scene/title` art + a gradient scrim + wordmark + vertical menu (Neues Spiel / Fortsetzen (disabled) / Einstellungen → Modal / Beenden). | `title` |
| `Night.tscn` / `night.gd` | Screen | SceneLayers (Portrait mounted into its character slot) + Hud + WantBubble + DialogueBox + ServeToggle + ServePanel. Turns choices into `resolve_beat`/`resolve_vignette`, the till into `serve_active`, "Wave off" into `skip_active`. Ends the night itself: at `night_progress ≥ 1` with a clear counter it dispatches `close_night`, and on `phase == "summary"` it requests the summary screen (each latched once). When no beat is pending it shows the customer's plain order line (presentation only). | `empty_counter`, `customer_at_counter`, `dialogue_choice`, `serving`, `pfand`, `late_night` |
| `Manage.tscn` / `manage.gd` | Screen | SceneLayers (dimmed by the Modal) + Modal + ManageBoard mounted into it. | `manage` |
| `Summary.tscn` / `summary.gd` | Screen | SceneLayers + dim + centred card with SummaryTally + Weiter (`advance_day`). | `summary` |

Capture: `node tools/godot/shot.mjs --scene res://scenes/Night.tscn --out shots/x.png --preset customer_at_counter`.
Test: `node tools/godot/test.mjs --filter scenes` loads and instantiates every component, applies every preset to
every screen, and checks the mock read-model against the docs/05 §5 key list.
