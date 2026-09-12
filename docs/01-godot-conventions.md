# 01 — Godot conventions (read before touching `godot/`)

**Godot 4.7.2 standard build, GDScript only.** No C#, no addons, no asset-store downloads. Everything must
run from the CLI (`tools/godot/*.mjs`) *and* open cleanly in the editor.

## Layout — and the one rule about it

```
godot/
  project.godot        480×270 base grid, canvas_items stretch, integer scale, nearest filter. Do not change without a doc note.
  engine/              PURE game rules. RefCounted classes. No Node, no scene, no Input, no OS, no wall clock.
    content/           the data registries (SKUs, customers, vignettes/arcs, events, upgrades) — data, not logic
  components/          THE central pool of reusable scenes (+ their scripts). Every visible thing is built from these.
  scenes/              composed screens (Main, Title, Manage, Night, Summary). They arrange components; they do not restyle them.
  state/               the Session autoload — the only mutable game object (docs/05-engine-api.md §7)
  sim/                 AutoPlayer — the headless shopkeeper policy used by tests
  assets/              grid-snapped art (from tools/codex/art.mjs); fonts/ holds the pixel font + its licence
  audio/               synthesized or generated sound (later)
  tools/               shot.gd / img.gd — pipeline helpers, not game code
  tests/               run.gd (runner), TestCase.gd (base), unit/test_*.gd
```

**The rule:** a screen never draws its own widget. If a screen needs a panel, a button, a portrait frame, a
meter, a dialogue box, an item slot — it instantiates the component from `components/`. If the component does
not exist, *add it to the pool* (and to `docs/04-component-catalog.md`), then use it. Never a second look for the
same thing: one `DialogueBox`, one `Portrait`, one `Panel`, one `PixelButton`, one `Meter`, one `ItemSlot`.

## Engine purity (the factory's golden rule, in GDScript)

- `engine/` scripts `extends RefCounted` (or nothing) and `class_name` them (`SpatiState`, `Rules`, `Rng`, …).
- State is a plain `Dictionary`/`RefCounted` graph that round-trips through `JSON.stringify` / `to_json()`; the
  reducer is `Rules.apply(state, action) -> state` plus `Rules.tick(state, dt_ms)`. All randomness through the
  engine's seeded `Rng` stored *in* the state — a night is replayable from `{config, seed, actions}`.
- `Rules.legal_actions(state)` gates the UI and drives the headless auto-player.
- Hook points in order: `on_spawn → on_serve → on_pfand → on_beat_check → on_close_night → on_advance_day`.
  Content registries are default-off: an empty registry still ticks.
- Port the *rules* from `app/src/engine/*.ts` (the superseded prototype implements `03-mvp-spec.md` faithfully);
  do not port its UI. The spec + GDD + narrative docs are the authority when they disagree.

## Scenes must be inspectable

Build node trees in `.tscn` files with real nodes and exported properties — the user wants to select a node in
the editor and see it. Scripts add behaviour and fill *lists* at runtime (the shelf's item slots, the queue);
they do not build the whole screen in `_ready()`. Name nodes for what they are (`DialogueBox`, `Portrait`,
`Shelf`, `Till`), never `Node2D2`.

Every scene root that the pipeline screenshots implements
`func apply_capture_preset(name: String) -> void` with the presets listed in `docs/02-art-pipeline.md`
(e.g. `customer_at_counter`, `dialogue_choice`, `summary`). Presets set deterministic state (fixed seed, fixed
customer, fixed clock) so the judge compares like with like.

## Pixel discipline

- Base grid **480×270**, shown ×4. Position everything on integer pixels (`round()` positions; `snap_2d_transforms_to_pixel` is on).
- Textures are nearest-filtered project-wide; never enable per-sprite filtering, never scale sprites non-integer at runtime.
- UI chrome (dialogue box, panels, buttons, meters) is **code-drawn** with `StyleBoxFlat`/`StyleBoxTexture` in the Coffee Talk
  language: dark translucent rounded boxes, 1-px light edge, coloured speaker name, white body. Bitmap *icons* come from the asset spec.
- One pixel font (OFL/CC0 — record the licence in `assets/fonts/LICENSE.txt`), sized to the grid (8–12 px), `subpixel_positioning` off,
  hinting none, antialiasing off → crisp at ×4.
- Palette tokens live in one place: `components/Theme.tres` (+ `engine`-free `components/theme.gd` constants). Chrome never uses a raw hex.

## Tests

`node tools/godot/test.mjs` runs `godot/tests/unit/test_*.gd` headless. Tests `extends "res://tests/TestCase.gd"`
(string path, not `class_name`, so they resolve without an import pass) and define `test_*` methods. Engine
changes ship with tests. Scenes get a "loads and instantiates" test (`load("res://scenes/X.tscn").instantiate()`).

## Style

Tabs for indentation (Godot default). Static typing everywhere (`var x: int`, `-> void`). `class_name` on every
reusable script. After adding a `class_name`, run `node tools/godot/test.mjs` (it re-imports so the class cache updates).
Keep comments as dense as the surrounding code — say *why*, not what.

## Do not

- Do not edit `project.godot` casually (input map / autoloads are fine; resolution and filters are decisions).
- Do not put game logic in scenes or components; they read engine state and emit engine actions.
- Do not touch `app/` (the superseded prototype) except to read it.
- Do not add addons, plugins, or anything fetched from the asset library.
