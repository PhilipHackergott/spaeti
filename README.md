# Späti (working title)

A narrative management sim: you inherit a Berlin Späti from your late Onkel Cem and run it through a changing
season while the Kiez gentrifies around you. Serve the night, price the shelves, decide who you are to the
neighbourhood.

**Look:** a Berlin Späti version of *Coffee Talk* — HD hand-drawn pixel art on a 480×270 grid shown ×4.
**Feel:** cozy-but-pointed; the numbers are a management sim, the point is the people.

## Run it

Open `godot/` in **Godot 4.7.2** (standard build) and press Play — or from the repo root with Node 18+:

```bash
node tools/godot/test.mjs                                   # headless unit tests
node tools/godot/shot.mjs --scene res://scenes/Night.tscn --out shots/night.png --preset customer_at_counter
node tools/codex/judge.mjs --candidate shots/night.png      # Codex scores it against the concept art
node tools/codex/art.mjs --id char/lena_neutral             # Codex generates an asset from docs/asset-spec.json
```

Requires the Godot binary (path in `tools/paths.mjs`, or `GODOT_BIN`) and a signed-in Codex CLI for the art tools.

## State of play

**Rebuilding from the ground up in Godot** on branch `godot-vertical-slice`: the target for this round is a
vertical slice whose screens match the concept art (judged by Codex) with the full night loop playable.
Progress and scores: `docs/03-build-log.md`.

`app/` is the earlier web prototype (Pixi/React) — playable end-to-end with placeholder art, superseded. It is
kept only as the reference implementation of the rules for the port.

## The documentation

| Doc | What it is |
|---|---|
| `docs/00-pipeline.md` | Who does what: Claude orchestrates/codes, Codex generates + judges art, Godot renders. Commands. |
| `docs/01-godot-conventions.md` | Layout, engine purity, the central component pool, pixel discipline, tests. |
| `docs/02-art-pipeline.md` | The asset loop and the scene loop, presets, thresholds. |
| `docs/03-build-log.md` · `docs/04-component-catalog.md` | Living log · the component pool inventory. |
| `game-design-document.md` | The design bible — pillars, the management sim, community evolution, Sunday/Ordnungsamt risk. |
| `narrative-design.md` | The story (Truby): 22-step main arc, ~14 side strands, four endings, the ending tapestry. |
| `art-direction.md` | The locked visual target. |
| `03-mvp-spec.md` · `04-build-plan.md` | Scope, rules, content catalog, acceptance criteria · engine design + milestones. |
| `concept-art/` | The protagonist target state + the Coffee Talk references (the bar), plus superseded vector studies. |
| `01-candidate-brief.md` · `05-playtest-report.md` · `BUILD-REPORT.md` | The pitch · round-1 findings on the web prototype · its build report. |

## `factory-reference/`

This game was born in a larger "factory" repo with shared playbooks; those docs are vendored here so the repo
stands alone. Their stack/tooling sections describe the old web substrate and are superseded by `docs/`.
