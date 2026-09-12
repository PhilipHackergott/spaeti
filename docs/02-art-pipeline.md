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

**Transparency reality (found on the first portrait):** the model may paint a *checkerboard* instead of using alpha —
the PNG comes back RGB (colour type 2) and looks transparent to a human. The wrapper measures real transparent pixels
after Godot decodes the file and rejects <2%. The prompt now demands image_gen's transparent-background option and,
failing that, a flat `#00ff00` backdrop which `img.gd --auto-key` removes. A checkerboard is unrecoverable → regenerate.

Sequencing that matters: generate **`char/you_neutral` first** and judge it against the target image — it
calibrates the pipeline. Then Lena/Jürgen neutral (they anchor the cast style), *then* their expressions
(same design, different face — attach the neutral portrait as an extra `refs` image so it stays on-model).

## The Night framing — measured off the OG interaction concept (`concept-art/main character target state.png`)

The user confirmed this image is the target for **character interaction**: a bust behind a counter band, the
shop behind. Proportions in base pixels (480×270), read straight off the reference:

| Element | Reference | Base-grid target |
|---|---|---|
| Counter top edge | 78–79 % of height | **y ≈ 210–213**; the band below it is plain wood, so a taller counter asset is simply anchored to the bottom and clipped |
| Counter objects | cup at 30 % x, phone at 50 % x, sitting *on* the edge | cup x≈145, phone x≈240, both just below the edge |
| Character bust | centred at 52 % x; hair top at ~10 %; shoulders ~30 % wide; cut by the counter at the chest/hip line | centre **x≈250**, hair top **y≈24–30**, ~145 px wide; the portrait's bottom 25–35 px sit *behind* the counter layer |
| Hanging lamps | three across the top, pooling warm light | in the backdrop, top 15 % |
| Wall of stuff | eye-level shelves/pictures either side of the head, calmer directly behind the face | backdrop composition rule (§asset-spec) |
| Dialogue box | not in this image — take it from the Coffee Talk frames | over the counter band, y≈196–262, x≈40–440 |

Who stands there: **the customer** (Lena, Jürgen, …) — per `art-direction.md` the player is the shopkeeper looking
across the counter. "You" appears on the title art and as the small speaker avatar when the player's lines show.
The set dressing is the Berlin kiosk (fridges, Pfand crate, SPÄTI neon, rainy door), not the café's jukebox/mugs.

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

## Model tiers + the generated concept (2026-09-12, user decision)

- **`gpt-6-astra`** (the strongest image model) does the *design* work: the concept art, the scene layers, the
  portraits — and **every judgement** (`judge.mjs` defaults to it). **`gpt-5.6-sol`** does the small image work:
  props, icons, textures. The tier is chosen per asset kind in `docs/asset-spec.json` → `modelByKind`
  (override per asset with `"model"`, or `art.mjs --model`).
- **Step 0 of the scene loop is now a concept painting:** `art.mjs --id concept/night_interaction` asks astra for the
  Berlin-Späti version of the OG interaction image (Lena at the counter, the kiosk set, no UI). It is saved at native
  size to `concept-art/generated/night_interaction.png` and never snapped. From then on `judge.mjs` automatically adds it
  as reference 3 (after the OG image), so captures are scored against a *composed* target, not only a character study.
  Scene layers are regenerated by astra with the concept attached as a reference so backdrop, counter and cast converge
  on one frame.

**Post-snap polish (measured on the concept, astra judging):** snap alone 81 → `--quantize 96` 79–81 → `--quantize 96 --despeckle 2`
82. About +1 per step, with banding/detail risk — so the **standard chain is snap-only**; `img.gd --quantize=N` (median-cut
palette) and `--despeckle=K` (orphan-pixel cleanup) are opt-in when a judge verdict names speckle or gradient noise.
The remaining gap to "authored clusters" is a generation problem: keep the TRUE-PIXEL-ART / 4–6-tone / stepped-contour
clauses in every scene and portrait prompt and let astra iterate against the judge.

**Snap filter, measured (portrait lane, astra judging):** re-snapping the same raws with `nearest` instead of Lanczos moved
five busts by +3 to +15 (Jürgen's pixel_rendering 39 → 72) with zero Codex calls — at a 5–6× downscale Lanczos invents the
intermediate tones the judge calls painterly. **Default is now `nearest` for everything except full-frame scene layers**
(`art.mjs`); set `"filter"` per entry to override. Two more guards from the same round: a bust that comes out more than
55 % transparent (prop: 75 %) is rejected — that is the signature of a painted checkerboard whose white squares connected
through the subject and let the flood-fill eat it; and every keyed sprite reports a `fringe` count (opaque pixels still near
the key colour) — above 20 the wrapper re-snaps once with a wider key tolerance and keeps the cleaner result.
