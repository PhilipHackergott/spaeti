# 00 — The pipeline: who does what

This repo is built by a small fleet, not one hand. Roles are fixed so the work stays consistent:

| Role | Who | Does |
|---|---|---|
| **Orchestrator** | Claude *Fable 5.1* | Plans, splits work into lanes, runs the loops, judges when to stop, keeps the docs honest. |
| **Operators** | Claude *Opus* subagents | Write the Godot code (engine, components, scenes), wire assets, run tests/captures, write docs. |
| **Art + art director** | **Codex** — `gpt-6-astra` (effort `max`) for concept art, scene layers, portraits and every judgement; `gpt-5.6-sol` for props, icons, textures | Generates every bitmap asset (built-in `image_gen`) and scores every capture against the concept art. Codex never edits game code. |
| **Engine** | **Godot 4.7.2** (standard build, GDScript) | The game. Open `godot/` in the editor — every screen is a real `.tscn` you can inspect. |
| **3D** | Blender 5.2 | On standby only: pre-rendering props to pixel sprites if a category needs it. Not used for the slice. |

## The two loops

```
ASSET LOOP (per asset)                    SCENE LOOP (per screen / preset)
spec entry ─▶ art.mjs ─▶ Codex image_gen   scene.tscn ─▶ shot.mjs (Godot, windowed) ─▶ 1920x1080 PNG
   ▲              │                             ▲                        │
   │              ▼                             │                        ▼
   └── feedback ◀ judge.mjs (Codex, vs refs)    └── operator fixes ◀ judge.mjs (Codex, vs refs)
```

Both loops stop on `overall ≥ threshold` (80 for assets, 85 for the hero screens) or when two rounds in a
row stop improving — a "dry" loop is reported, never silently accepted.

## Commands (all from the repo root, Node 18+)

| Command | What |
|---|---|
| `node tools/codex/art.mjs --id char/lena_neutral` | Generate one asset from `docs/asset-spec.json` → `godot/assets/char/lena_neutral.png` (raw in `art/raw/`). |
| `node tools/codex/judge.mjs --candidate shots/night.png --context "..."` | Score an image vs the concept art → `judge/night.json`; exit 0 = pass. |
| `node tools/codex/run.mjs --prompt "..." [--image=x.png]` | Any other Codex call (read-only by default). |
| `node tools/godot/shot.mjs --scene res://scenes/Night.tscn --out shots/night.png --preset customer_at_counter` | Capture a scene at the base grid, upscaled to 1080p. |
| `node tools/godot/test.mjs [--filter x]` | Headless unit tests (`godot/tests/unit/test_*.gd`). |
| `node tools/godot/img.mjs --in a.png --out b.png --w 160 --h 200` | Snap any image to the pixel grid. |

Hard-won rules these wrappers encode (do not bypass them by calling `codex`/`godot` raw):
- Codex on native Windows: prompt via stdin **and close it**, `--image=FILE` (never `-i FILE`), `danger-full-access`
  when it must write (there is no OS sandbox in this build; `workspace-write` silently degrades to read-only).
- Godot: **never** capture headless — it cannot render and hangs. Captures render into a 480×270 SubViewport and
  are integer-upscaled, so they are independent of the window/monitor.

## Where things go

```
godot/           the Godot project (see docs/01-godot-conventions.md)
godot/assets/    grid-snapped art, committed (id = path)     art/raw/   native gpt-image output, git-ignored
shots/           captures, git-ignored                        judge/     verdict JSON, git-ignored
docs/            these docs + the living build log (03) and component catalog (04)
tools/           the wrappers above                           app/       the superseded web prototype (reference only)
```

## Gates

The factory's human gate still applies: the slice is presented for approval when the hero screens pass the
judge and the loop is playable end to end. Nothing is pushed anywhere; commits land on `godot-vertical-slice`.
