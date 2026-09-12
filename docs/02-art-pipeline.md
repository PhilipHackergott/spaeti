# 02 — Art pipeline: Codex generates, Codex judges, Godot shows

The look is **locked**: HD hand-drawn pixel art, "a Berlin Späti version of Coffee Talk" (`art-direction.md`).
`concept-art/main character target state.png` is the bar. Codex's built-in `image_gen` produces every bitmap;
Codex also scores every result. No hand-painting, no stock, no vector mock-ups.

## The base grid decision

Coffee Talk and the target image sit at ≈ 4 screen pixels per art pixel at 1080p. So the game runs on a
**480×270 base grid, integer-scaled ×4** (`project.godot`). Every asset is sized in base pixels
(`docs/asset-spec.json`), generated large by gpt-image, then **snapped** to the grid by `godot/tools/img.gd`
(Lanczos downscale → hard alpha). Generating at 1024–1536 px and downscaling ≈ 4–6× is what turns the
model's uneven "fake pixels" into one clean grid. If a result looks mushy, the fix is a *different prompt*
(coarser, higher-contrast pixel clusters), not bilinear filtering in the engine.

## Per-asset loop (`tools/codex/art.mjs`)

1. `docs/asset-spec.json` entry → prompt = **style brief** (`docs/art-style-brief.md`) + kind notes + asset
   text + hard requirements (size, transparency, no text) + reference images attached (`--image=`).
2. Codex generates with `image_gen` and copies the raw PNG to `art/raw/<id>.png` (git-ignored; keeps
   re-snapping cheap). If it forgets the copy, the wrapper pulls the newest file from `~/.codex/generated_images/`.
3. `img.gd` snaps to `godot/assets/<id>.png` (`fit` for sprites with `trim`, `cover`+`crop` for layers, `exact` for icons).
4. `tools/codex/judge.mjs --candidate godot/assets/<id>.png --reference <the target state> --context "<kind + brief>"`
   scores it. **≥ 80 → keep**. Otherwise re-run `art.mjs --feedback "<the judge's top fixes>"` (max 3 rounds;
   log the best score and stop — never loop blind).
5. Record every asset's final score + rounds in `docs/03-build-log.md`.

Sequencing that matters: generate **`char/you_neutral` first** and judge it against the target image — it
calibrates the pipeline. Then Lena/Jürgen neutral (they anchor the cast style), *then* their expressions
(same design, different face — attach the neutral portrait as an extra `refs` image so it stays on-model).

## Per-scene loop (`tools/godot/shot.mjs` + `judge.mjs`)

Every screenshot goes through the same judge with the full four-image reference set. Presets each scene must
support via `apply_capture_preset(name)`:

| Scene | Presets |
|---|---|
| `scenes/Title.tscn` | `title` |
| `scenes/Night.tscn` | `empty_counter` (dusk, no customer), `customer_at_counter` (Lena neutral, want bubble), `dialogue_choice` (Lena, 2 options open), `serving` (shelf panel open, beer + mate picked), `pfand` (Jürgen at the counter with bottles), `late_night` (2:30, cola-blue exterior, rain) |
| `scenes/Manage.tscn` | `manage` |
| `scenes/Summary.tscn` | `summary` (a finished night's P&L tally) |

Thresholds: hero screens (`customer_at_counter`, `dialogue_choice`, `title`) **≥ 85**; the rest ≥ 80.
The operator fixes what the verdict names (layout, layering, colour tokens, a regenerated asset via `art.mjs`)
and re-captures. Stop when the threshold is met or two consecutive rounds fail to raise `overall` — then write
the gap down honestly in the build log instead of polishing forever.

## What is *not* generated

Dialogue box, panels, buttons, meters, the want bubble, rain/steam/neon flicker — all code-drawn in Godot
(`StyleBoxFlat`, `Line2D`, `GPUParticles2D`/simple tweens). Reason: the imagegen skill itself says UI chrome
belongs in native code, and it keeps every screen consistent for free. The pixel font is a downloaded OFL font,
not generated.

## Adding an asset

Add an entry to `docs/asset-spec.json` (id = path under `godot/assets/`, base-pixel size, kind, prompt, refs),
run `art.mjs`, judge it, reference it from a component. Never leave an asset only in `art/raw/` or `~/.codex/`.
