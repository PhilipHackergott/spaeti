# 03 — Build log (living; newest at the bottom)

Operators append here as they go: decisions, scores, what worked, what did not. Keep entries short and dated.

## 2026-09-12 — pipeline bring-up (orchestrator)

- **Pivot recorded:** the web prototype in `app/` is superseded. New game = `godot/` (Godot 4.7.2, GDScript),
  built from the ground up to the *Coffee Talk × Berlin Späti* target. Gameplay follows `03-mvp-spec.md` /
  `04-build-plan.md` / `game-design-document.md` / `narrative-design.md`; the 3D/R3F and Pixi substrates are gone.
- **Codex** installed (`codex-cli 0.154.0`), signed in via SSO (ChatGPT Business). Model `gpt-5.6-sol`, effort `max`
  (`ultra` exists above it; switch with `CODEX_EFFORT=ultra`). Verified: vision input reads the concept art
  correctly; built-in `image_gen` produced a transparent 256² pixel-art bottle and saved it to a named path.
- **Three Windows traps found and fixed in the wrappers:** open stdin hangs `codex exec` forever; `-i FILE...`
  swallows the prompt; `workspace-write` degrades to read-only (use `danger-full-access`). Godot: headless cannot
  render (capture hangs) → captures are windowed into a SubViewport; the wrapper has a watchdog.
- **Base grid decided: 480×270 ×4.** Matches the pixel density of the target image and Coffee Talk.
- **Vertical-slice scope (what "done" means for this round):** Title → New game → opening beat (Cem's keys) →
  one full night at the counter (customers on the curve incl. Lena S1-beat-1, Jürgen S2-beat-1 with Pfand, two
  one-offs; grab → ring up → pay → change/Pfand; dialogue with choices) → close → nightly P&L → Manage (restock +
  prices) → next night. Engine ported and tested; the component pool built; every hero screen judged ≥ 85 against
  the concept art. Out of scope this round: audio, the full 22-step arc, all 14 strands, save/history, Cozy/Tight.

## 2026-09-12 — art calibration: char/you_neutral (orchestrator)
- Round 1 (checkerboard, rejected): style/identity very close to the target but no real alpha. Round 2 (real alpha, 7 min, 66k tokens): judge **66/100** — composition 82, palette 70, pixel_rendering 67, character_fidelity 59: older/longer-haired/more stubble than the target, painterly hair noise, too orange. The judge's fixes were folded into `docs/art-style-brief.md` (portrait rendering paragraph) and the `you_neutral` prompt; the character fleet re-runs it with that feedback. Lesson: run-to-run identity drift is the main risk for portraits — 3 rounds + keep-best is the right loop.

## 2026-09-12 — art: scene/title

- **`scene/title`** — 2 generation rounds (a 3rd was blocked, see below). Best **74/100** (round 2, `art/raw/scene/title-r2.png` → promoted to `godot/assets/scene/title.png`; round 1 kept as `art/raw/scene/title-r1.png`). Axes r2: composition 82, palette_lighting 88, pixel_rendering 57, character_fidelity 69, berlin_reskin 87, ui_style n/a.
  - **R1 = 49** (pixel_rendering **18**): the spec's prose prompt produced a gorgeous but *smooth painterly illustration* — anti-aliased, bloomed, speckled — with a mushy protagonist and the neon sign filling the title-safe zone. Confirms `02-art-pipeline.md`: for `scene` assets the model defaults to "digital painting", it does **not** infer pixel art from the style brief alone.
  - **Spec change (round 2):** rewrote the `scene/title` prompt in `docs/asset-spec.json` with four explicit blocks — (a) *render as true pixel art*, "every art pixel a solid uniform square block, no AA/blur/bloom/gradient/noise"; (b) *simplify to read at 480×270* (few big shapes, dark masses, no micro-detail); (c) *composition* — storefront in the lower two thirds, upper third a calm dark facade/sky band for the title overlay, sign small and low, essential content inside the middle 84% of the canvas (the 16:9 centre crop eats 8% top and bottom); (d) a *literal protagonist sprite description* (red hood at the neck, brown torso panels, near-black shoulders, one red band per sleeve, chunky hair tufts, rim light). That single rewrite moved pixel_rendering 18 → 57 and overall 49 → 74.
  - **Spec change (round 3, written but unexercised):** the prompt now also names the pipeline reality — "this canvas is downscaled 3.2× onto a 480×270 grid, nothing thinner than ~5 canvas px" — plus *light as stepped clusters, never glow*, readable fridge props with dark gaps between bottle groups, and reflections as short horizontal clusters. **Not yet validated by a generation.**
  - **Remaining gaps (below the 80 threshold):** ① residual sub-pixel softness in the awning, fridge contents, facade texture and rain streaks — the 1536→480 Lanczos step (3.2×, non-integer) mushes anything fine, so the fix lives in the prompt's coarseness, not the snapper; ② smooth bloom around the sign/windows/doorway instead of stepped tone ramps; ③ the protagonist reads by colour more than by design (silhouette and jacket panels want a cleaner cluster break); ④ the window fridges tend toward vertical colour noise; ⑤ the SPÄTI fascia is still bright enough to compete with a logo — the storefront wants pushing down another ~12–16 base px.
  - **Blocker:** round 3 could not run — Codex returned `You hit your spend cap set by the owner of your workspace` (wrapper fails fast: 5 s, 0 tokens, "No image file was written"). Re-run `node tools/codex/art.mjs --id scene/title --variant r3` once the cap is lifted; the improved prompt is already in the spec and the feedback above is the text to pass with `--feedback`.

## 2026-09-12 — art: scene/counter

- **scene/counter — 1 round, UNJUDGED (Codex spend cap), kept.** `godot/assets/scene/counter.png` = 480×123,
  real alpha (0 semi-transparent pixels, 30% clear), no key bleed (the only greenish pixels are the crate's
  bottles; `keyedPixels=0`, the model used true alpha). Content is right: worn warm-brown counter top with an
  amber lamp highlight along the front edge, dark plank front face, Pfand crate of empty green bottles far left,
  cup+saucer left of centre, phone centre, compact cash register far right. Solid counter band = rows 47–122
  (76 px ≈ 28% of the 270 screen, matching the target image's ≈24%); crate/register rise 47 px above it.
- **Spec change (before round 1):** rewrote the `scene/counter` prompt — added "straight-on view from just above
  the counter top, front edge perfectly horizontal, full canvas width"; a low-profile rule (nothing rises more
  than ⅓ of the strip above the counter top, nothing in the top half of the canvas) so the trimmed strip stays in
  the 90–130 px band; and "hard, un-antialiased pixel edge with no glow, no soft fade, no coloured halo" against
  the background. Both worked first try (height 123, zero semi-transparent pixels).
- **Remaining fixes (need a round 2 when Codex billing is restored):** (1) the wood reads photographic/noisy —
  17 705 unique colours over 41 218 opaque pixels, i.e. continuous gradients rather than 4–6 flat tone clusters
  per material; re-prompt for flat cluster shading, banded grain, no gradients/noise. (2) A dark oval smudge
  right of the phone reads as a hole, not deliberate wear. (3) The phone is nearly invisible against the wood —
  needs a lighter rim/screen edge. (4) The register's display carries a tiny blue glyph that could read as text.
  (5) Berlin cues are thin (the crate is the only one) — a sticker or techno flyer taped to the counter front
  would earn `berlin_reskin`. (6) Check in the Night capture that the far-left crate does not crowd the bust.
- **Blocker:** `judge.mjs` (and any Codex call) now returns "You hit your spend cap set by the owner of your
  workspace" — reproduced 3× incl. a bare `run.mjs` ping. No score for this asset; nothing else can be generated
  or judged until the cap is raised.

## 2026-09-12 — art: sku/chocolate, sku/gummi, sku/cigarettes, sku/lighter, sku/coffee (shelf SKUs)

- **0 rounds completed, 0 scores: Codex is hard-blocked** — `art.mjs` returned "No image file was written" for
  all five ids; a bare `run.mjs` ping prints `ERROR: You hit your spend cap set by the owner of your workspace`
  (the first chocolate attempt burned 29 179 tokens before the cap bit; every call after it fails in 3–7 s with
  0 tokens). Retried once after a wait per the rules — same result. No image was produced, so nothing was
  judged and nothing was written to `godot/assets/sku/` by this lane.
- **Spec changes (done, ready for the first unblocked run):** rewrote the `prompt` for all five ids in
  `docs/asset-spec.json`. The generic "Coffee Talk material shading" prop text is the wrong instruction for a
  10–30 base-px sprite (it invites the same painterly detail that scored `char/you_neutral` 66/100). Each prompt
  now ends with a shared clause: draw the whole canvas as ONE coarse pixel sprite readable at its exact base
  size (WxH named explicitly), big uniform square pixels, ≤ 6–8 flat colours, hard near-black 1-px outline,
  bold high-contrast blocks, no fine texture / gradients / anti-aliasing / cast shadow / sub-pixel highlights,
  amber key from upper left + cool blue fill right, one light + one dark tone per material, subject fills the
  canvas, and an explicit ban on text, letters, numbers, logos, barcodes, health warnings and seals (real
  brands are a hard failure). Subjects were also simplified to what survives a ~30× downscale (chocolate: one
  folded corner + two chunky squares; gummi: one window with 2–3 big bears; cigarettes: navy box + one broad
  white band; lighter: magenta column + steel cap, key colour left at the default `00ff00`; coffee: white cup +
  wide kraft sleeve + domed lid + a 2–3 px steam curl).
- **Note for whoever unblocks this:** `godot/assets/sku/lighter.png` currently holds a 10×15 fully-opaque
  placeholder that is a downscaled crop of the protagonist portrait (untracked, written by another lane at
  15:27). It must be overwritten by the real 10×24 sprite — it is not art from this lane.

## 2026-09-12 — art: sku/beer, sku/mate, sku/cola, sku/water, sku/chips (BLOCKED — Codex spend cap)
- **Blocker:** every `codex exec` in this lane returns `ERROR: You hit your spend cap set by the owner of your
  workspace.` (exit 1, ~2 s, 0 tokens). Verified with `tools/codex/run.mjs` on a trivial ping three times, including
  the mandated 60 s wait-and-retry. So **0 generation rounds and 0 judge rounds ran** for all five SKUs; there is no
  score to report and nothing was written to `art/raw/sku/` or `godot/assets/sku/`. Needs the workspace owner to
  raise the cap, then this lane re-runs unchanged.
- `godot/assets/sku/{beer,mate,cola,water,chips,lighter}.png` currently hold the **code-drawn placeholders** another
  lane dropped in at 15:27; they were left untouched so the shelf panel still renders. They are placeholders, not
  judged art — replace them when the cap lifts.
- **Spec changes made anyway (the substantive fix, ready for the first run):** all five `sku/*` prompts in
  `docs/asset-spec.json` were rewritten. Rationale = the calibration bottle's **64/100** (mixed pixel densities,
  noisy gradient glass, acidic contrast). These sprites are 14x36 / 26x32 base px generated at 1024–1536 px, i.e. a
  ~30–70x downscale, so a "render a nice bottle" prompt cannot survive it. Each prompt now: (a) states the true
  logical sprite size and demands a **true NxM logical-pixel sprite nearest-neighbour-upscaled so one logical pixel
  = one large square block** (~73 canvas px), nothing off-grid or sub-block; (b) bans anti-aliasing, gradients,
  dithering, speckles, stray single pixels, fine texture, crinkle/glass texture and drop shadows; (c) fixes the
  silhouette as a symmetric stepped contour with a 1-block near-black outline and names block counts for cap / neck
  / body / seals; (d) pins **exactly 5 tones** per material with ONE warm amber highlight column down the LEFT and
  ONE cool blue rim column 1 block wide down the RIGHT (the brief's amber-inside / blue-night-outside light); (e)
  makes every label a **flat colour band with NO text, letters, numbers, logo or picture** (chips gets one bold
  8x5-block crisp blob), explicitly brandless — the cola prompt additionally forbids any resemblance to a real
  cola brand. Asset `id`, `w`/`h`, `kind`, `gen` and `filter` are unchanged.
- Remaining fixes for the first real round (carried from the calibration verdict, to feed as `--feedback` if
  round 1 still misses): thick-glass heel at the bottle base as one dark contour + one olive arc + a near-black
  cavity; keep highlights muted amber/olive rather than yellow-green; no disconnected orange contour specks.

## 2026-09-12 — art: ui/icon_clock, ui/icon_cash, ui/icon_pfand, ui/icon_trust, ui/icon_profit (BLOCKED)
- **Blocked before any icon landed: Codex is out of budget.** Every `art.mjs`/`run.mjs` call now returns
  `ERROR: You hit your spend cap set by the owner of your workspace.` (exit 1, 2 s, 0 tokens). Verified with a
  one-line `run.mjs` probe, waited 60 s, probed again — same. No generation and no judging is possible until an
  owner raises the cap. Nothing was left behind: `art/raw/ui/` and `godot/assets/ui/` are clean.
- `ui/icon_clock` 1 round attempted → no image (cap). `ui/icon_cash`, `ui/icon_pfand` 1 round each → images
  returned but **contaminated** (see below). `ui/icon_trust`, `ui/icon_profit` 1 round each → no image (cap).
  No asset was judged; no score exists for any of the five.
- **Pipeline hazard found — `art.mjs`'s `~/.codex/generated_images` fallback is not concurrency-safe.** When
  Codex does not copy the PNG to the exact path, `newestGenerated()` takes the newest file from the shared
  generated-images folder. With more than one art lane running in the repo, that is *another lane's* image:
  `icon_cash` and `icon_pfand` came back byte-identical (md5 `a333de2f…`) and both were actually the
  counter/backdrop scene from a different lane — a 1536x1024 full-bleed scene snapped into a 16x16 "icon".
  Both were deleted. Fixes to consider: stamp the prompt with a unique token the model must put in the filename,
  or have the fallback only accept files created inside the run's own window *and* matching the requested aspect.
  Until then: **run `art.mjs` one asset at a time and always LOOK at `art/raw/<id>.png` before trusting it.**
- **Spec change (kept, worth having when generation resumes):** all five icon prompts in `docs/asset-spec.json`
  were rewritten pre-emptively against the known 16-px failure mode — each now demands "a STRICT 16-by-16 grid of
  large flat square pixels, every art pixel one 64x64 block of the 1024 canvas, no anti-aliasing, 4 flat colours
  plus one near-black outline (#160f14)", plus a per-icon block-level description (clock hands as whole pixels;
  cash = banknote slab + two coins; Pfand = crate box with three 2-px bottles; trust = two sleeved forearms
  clasping in a single 6x5 block, no individual fingers; profit = till body + 2x2 cream keypad + mint display) and
  an explicit "no text/numerals/symbols" clause. ids, sizes, kind, mode/filter untouched.

## 2026-09-12 — art: char/lena_neutral, char/lena_warm, char/lena_upset (art operator) — BLOCKED
- **Blocker: Codex is unavailable — "You hit your spend cap set by the owner of your workspace."** Verified with a
  bare `run.mjs` ping (exit 1, 2 s, 0 tokens), waited 75 s, re-pinged: same error. No generation and no judging was
  possible, so all three Lena portraits have **0 completed rounds / no score** and no asset at `godot/assets/char/`.
- `char/lena_neutral` round 1 returned `ok:true` but the image was **not Lena** — a counter/backdrop from another
  operator's run. Cause: with several art lanes running in parallel, `art.mjs`'s `newestGenerated()` fallback pulls
  the newest file out of the *shared* `~/.codex/generated_images/` tree, so a lane whose own codex call writes
  nothing silently adopts another lane's image (here: snapped to 190x49, an obvious tell). The bogus
  `art/raw/char/lena_neutral.png`, `godot/assets/char/lena_neutral.png` and its orphaned `.import` were deleted.
  **Pipeline fix wanted:** scope the fallback to the session id of this run (or stamp/verify the file), and treat a
  wildly wrong post-trim aspect ratio for a `portrait` as a failure.
- **Spec changes made (ready for whoever resumes):** all three prompts in `docs/asset-spec.json` rewritten against the
  calibration verdict — explicit "early twenties, soft roundish face, pale peach-pink freckled skin, large readable
  eyes with one highlight, thin brows, small mouth", a short choppy bob under the beanie (no long mane), and a hard
  RENDERING paragraph (flat 4–6-tone clusters, 1-px contours; no painterly strands, no speckle noise, no gradients,
  no semi-realistic illustration; never orange, never crushed to black; nothing cropped by an edge). `lena_warm` and
  `lena_upset` now carry the full design inline plus an IDENTITY clause, and a `$resumeNote` telling the operator to
  switch their `refs` to `["concept-art/main character target state.png", "art/raw/char/lena_neutral.png"]` and add
  the "image 2 is THIS character" line **once the neutral portrait exists** (refs must not point at a missing file).
- **Remaining for all three:** generate, judge (threshold 80), keep-best, delete variants. Nothing to keep this round.

## 2026-09-12 — art: char/juergen_neutral, char/juergen_warm

- **`char/juergen_neutral`** — **0 completed generation rounds, no score.** 4 invocations of `tools/codex/art.mjs --id char/juergen_neutral` (2+1+2+1 codex attempts): the first burned 87 s / 31 k tokens and returned no image and no final message; every attempt after that failed in 2–6 s with 0 tokens. A direct probe through `tools/codex/run.mjs` (tiny image_gen request) returned the real cause: `ERROR: You hit your spend cap set by the owner of your workspace.` Same blocker as `scene/title` round 3. **Nothing was produced; no asset exists at `godot/assets/char/juergen_neutral.png`.**
- **`char/juergen_warm`** — not attempted: it depends on the neutral portrait as its identity reference.
- **Spec changes (written, unexercised — both ready for the re-run):**
  - `char/juergen_neutral` prompt rewritten from one prose sentence into five labelled blocks that pre-empt every penalty the `you_neutral` calibration took: *same hand as image 1* (density/proportion/outline/cast consistency); **FACE** — simple readable construction, age told by "three or four deliberate one-pixel crease lines", stubble as "ONE flat cool-grey cluster with a hard edge — never dots or strands"; **HEAD** — cap + "chunky clusters, never individual strands"; **CLOTHES** — olive parka, rust-orange scarf as the single saturated accent, the bottle bag kept small in the lower-left corner so it does not crowd the face; **EXPRESSION** — "quietly present and guarded… not stern, not scowling"; **LIGHT/RENDERING** — pale faintly ruddy peach skin with lifted shadows, "never orange, never half-buried in black", narrow amber rim left + restrained cool-blue edge right, 4–6 flat clusters per material, explicit bans on gradients, airbrush, strand hair, speckle noise, AA. Rationale: Jürgen is *meant* to be old and weathered, so the calibration's "older/heavier face" penalty must be re-aimed — the fix is to forbid painterly wrinkle *texture*, not age.
  - `char/juergen_warm` given `refs: ["concept-art/main character target state.png", "art/raw/char/juergen_neutral.png"]` and a prompt that states "IMAGE 2 IS THIS EXACT CHARACTER — reproduce his exact face, head shape, cap, hair tufts, scarf, parka, colours, outline weight, pixel density and framing pixel for pixel; change ONLY the expression", then lists the expression delta (closed crinkled smile, eyes meeting the viewer, inner brows lifted, crow's feet) and an explicit do-not list. **Ordering dependency:** this entry now references `art/raw/char/juergen_neutral.png`, so the neutral MUST be generated first or the `--image=` argument points at a missing file.
- **Pipeline bug found (worth fixing before the next parallel art wave):** `art.mjs`'s `~/.codex/generated_images` fallback is not safe when several art operators run concurrently — it takes the *newest* PNG written since the attempt started, regardless of which session produced it. During this pass it snapped another operator's `you_neutral-r2` bitmap into `godot/assets/char/juergen_neutral.png` (byte-identical, md5 `abd8516657120bbde7de64b3a1a01796`) while still reporting `ok:false`. The bogus file and its `.import` were deleted. Suggested fixes: scope the fallback to the session id `codex exec` prints, and delete the snapped output when an attempt ends in failure.
- **Re-run recipe once the spend cap is lifted:** `node tools/codex/art.mjs --id char/juergen_neutral --retries 1`, judge against `concept-art/main character target state.png` with the portrait context (character_fidelity vs his design brief, pixel_rendering, palette_lighting, composition as bust framing only; ui_style/berlin_reskin n/a; margins irrelevant — the snapper trims), then `--variant r2`/`r3` on the judge's fixes; only then `--id char/juergen_warm`.

## 2026-09-12 — art: scene/backdrop

- **`scene/backdrop` — 2 generation rounds, best 84 (pass, threshold 80), r2 promoted to `godot/assets/scene/backdrop.png`.**
  Axes r2: composition 85, palette_lighting 88, pixel_rendering 79, berlin_reskin 96 (character_fidelity / ui_style N/A).
  R1 = 72: the model returned a **smooth painted illustration**, not pixel art (soft glows, anti-aliased edges,
  photographic glass highlights, painterly noise → pixel_rendering 61), and the SPÄTI neon sat against the top edge
  so the 16:9 centre crop sliced it. R2 fixed both.
- **Spec changes to `scene/backdrop.prompt`** (id/size/kind/mode/filter untouched), three edits:
  1. *Composition zoning before round 1* — explicit three-band layout (fridge wall left, calm dressed wood middle,
     glass door + rainy street right), "the bottom third will be covered by the counter, put nothing readable there",
     SPÄTI neon high in the **middle-left**, lamps at the outer edges so the middle stays dimmer.
  2. *Pixel-art discipline + crop safety (round 2)* — the prompt now opens with "TRUE PIXEL ART, NOT A SMOOTH
     ILLUSTRATION": one locked ~480x270 grid, hard nearest-neighbour edges, 4–6 flat tones per material, ordered
     dithering only for falloff, 1-px dark outlines, and an explicit ban on bloom/blur/gradients/photographic glass.
     Plus **"the canvas is centre-cropped to 16:9 — compose inside the middle 16:9 band, treat the top ~15% and
     bottom ~15% as expendable margin, nothing readable touches the top or bottom edge."** *This crop-safety clause
     is worth copying into every `crop: "16:9"` scene entry* — it is a pipeline-level trap, not a one-off.
  3. *Glow discipline + character read (for round 3)* — every light source built from 4–6 stepped colour bands
     instead of bloom; a ≥10 art-px low-contrast halo reserved where the 150x230 bust stands, hooks/notices/bright
     packets pushed outward, fridge interiors one value step darker and pale-cyan rather than white.
- **Round 3 never ran: Codex hit the workspace spend cap** (`art.mjs` failed in 5 s with 0 tokens; `run.mjs` on a
  trivial prompt returns "You hit your spend cap set by the owner of your workspace"). The r3 prompt edits are
  already committed to the spec, so the round is a single re-run once the cap lifts.
- **Remaining fixes on the shipped r2** (all from the judge, none blocking at 84): soft bloom around both pendant
  lamps / neon / fridge glow / wet-window reflections is still continuous rather than stepped (main drag on
  pixel_rendering 79); the centre lacks a reserved halo — the bust will cross a few shelf edges, key hooks and
  bright snack packets, and the shelf run behind it wants to be one value step darker; the fridge whites still pull
  focus left of the intended warm centre; small merchandise occasionally degrades into single-pixel confetti; some
  shelves want a 1–2 px contact shadow to separate from the wall. Verify the halo issue against the real composite
  once `char/*` + `scene/counter` are layered in `scenes/Night.tscn` — it may resolve itself under the counter mask.

## 2026-09-12 — art: char/mehmet_neutral, char/oneoff_clubber_neutral, char/oneoff_tourist_neutral (art operator) — BLOCKED

- **Blocker: Codex is unavailable — `ERROR: You hit your spend cap set by the owner of your workspace.`** Confirmed
  with a bare `tools/codex/run.mjs` ping (exit 1, 3 s, 0 tokens), waited 90 s, re-pinged: identical error. This is an
  account/workspace cap, not a transient rate limit, so it does not clear on its own. **All three portraits: 0
  completed generation rounds, no judge score, no asset at `godot/assets/char/`.** Same blocker as the Lena, Jürgen,
  SKU and UI-icon lanes.
- **Attempts made:** one parallel wave (all three at once) then one sequential retry for `char/mehmet_neutral`.
  The parallel wave returned `ok:false` for all three in 49–83 s each (`"No image file was written (codex said:
  (nothing))"` ×2, `"background was NOT transparent"` ×1) — those were spend-cap failures surfacing as empty codex
  replies. The sequential retry failed in 5 s / 0 tokens, which is what made the real cause obvious.
- **Cross-lane contamination reproduced (third independent sighting).** `art.mjs`'s `newestGenerated()` fallback
  takes the newest PNG in the *shared* `~/.codex/generated_images/` tree since the attempt began, so with several art
  lanes live a lane whose own call produces nothing silently adopts a neighbour's bitmap. It wrote byte-identical
  74 712-byte files to `godot/assets/char/mehmet_neutral.png` and `godot/assets/char/oneoff_clubber_neutral.png`
  (same bytes as `you_neutral-r2.png`), plus a 1.5 MB foreign `art/raw/char/mehmet_neutral.png`. All of them and
  their orphaned `.import` files were deleted; nothing of mine is left in `godot/assets/`. **Operating rule until
  it is fixed: run art lanes sequentially, never in parallel.** Suggested fix (matches the other lanes'): scope the
  fallback to the session id `codex exec` prints, verify the snapped result's aspect against the spec, and delete
  the snapped output whenever an attempt ends `ok:false`.
- **Spec changes made in `docs/asset-spec.json` (ready for whoever resumes; id/kind/sizes untouched):** all three
  prompts rewritten to pre-empt the `you_neutral` calibration penalties, each ending in one shared hard RENDERING
  paragraph — "draw a TRUE PIXEL-ART SPRITE, not a painted illustration… imagine a 190x230 sprite blown up, every
  cluster a hard-edged block of one flat colour"; no strand-by-strand hair, no speckle noise, no gradients/airbrush/
  AA; 4–6 flat tones per material with 1-px dark contours; pale peach-pink skin with lifted shadows, never orange,
  never buried in black, amber only as a narrow rim with a restrained cool-blue edge opposite; simple face (small
  eyes with one highlight pixel, thin brows, small mouth, ears exposed), "quietly present, not stern"; and a FRAMING
  clause — hair must not touch the top edge, both shoulders fully inside the left/right edges, cut only at the bottom
  (the `you_neutral` verdict docked it for shoulders sliced by the frame, which trimming cannot recover).
  Per-character content was also made concrete instead of prose: **Mehmet** — moustache as clean block shapes not
  wispy hairs, age told by "two or three deliberate pixel lines" of laugh line, deep-teal shirt as his one accent
  under a charcoal apron, çay glass with a small steam wisp; **clubber** — glitter as "a handful of single bright
  pixels (not sparkle noise)", eyeliner as one thick simple line, magenta-pink bomber as the single saturated
  accent, bleached tufts with dark roots; **tourist** — yellow rain jacket as the accent, damp hair in chunky
  clumps, and a cyan phone glow under the chin as the signature lighting note played against the warm rim.
- **Re-run recipe once the cap is lifted (sequentially, one id at a time):**
  `node tools/codex/art.mjs --id char/<id> --retries 1` → upscale ×4 with `tools/godot/img.mjs --filter nearest`
  into `shots/asset-char-<id>.png` → `tools/codex/judge.mjs --reference "concept-art/main character target state.png"
  --threshold 80` with the portrait context (character_fidelity vs the design brief, pixel_rendering,
  palette_lighting, composition as bust framing only; ui_style/berlin_reskin N/A; margins irrelevant — the snapper
  trims) → `--variant r2`/`r3` on the judge's fixes, max 3 rounds, keep best, delete the losing variants from
  `godot/assets/`.

## 2026-09-12 — Engine lane: the pure GDScript port (docs/05-engine-api.md §1–§8)

**Built.** The whole engine contract, ported 1:1 from the superseded TS prototype (`app/src/engine/*`),
rules only, no UI. `godot/engine/rng.gd` (mulberry32, bit-identical to `rng.ts` — verified against
reference draws from Node in `test_rng.gd`), `state.gd` (`SpatiState`: DEFAULT_CONFIG = normal / seed 1 /
`night_len_ms` 300000 / 28 days / €420 / €48 rent, `new_game` · `clone` · `to_json` · `from_json`),
`economy.gd`, `storyflow.gd`, `finale.gd`, `rules.gd` (`apply` / `tick` / `legal_actions` / `view`), the
content registry (`content/registry.gd` = `Content` + six data scripts: **all 23 SKUs, 8 archetypes, 27
upgrades, 13 strands, 22 vignettes**, plus the new `content/characters.gd` with the 8 named cast + the 2
one-off portraits, portrait ids matching `docs/asset-spec.json`), the `Session` autoload (registered in
`[autoload]`; nothing else in `project.godot` touched), `sim/auto_player.gd`, and the six unit tests.
`node tools/godot/test.mjs` → **49 tests, 0 failed, 2585 asserts**, no errors or warnings.

**The counter-fired story (§4) works end to end.** `open_night` → `StoryFlow.schedule_beats` injects the
due cast beat as a real arrival (character's own wants, a time on their archetype's curve, ≤ 2 story
arrivals a night, main arc first); the beat goes pending the moment that customer becomes `active`;
`legal_actions` then offers only `resolve_beat`/`resolve_vignette` (serve/skip are refused by the
reducer too); resolving applies cash/kiez/profit/integrity/flags/outcome/next, sets the expression, and
leaves the same customer at the counter for the ordinary serve. A full 28-day AutoPlayer season resolves
all 13 strands and composes a 12-line ending tapestry.

**Decisions worth knowing (all inside the contract, none of them free choices for the UI lane):**
- **Patience freezes while a beat is pending** — otherwise the story customer balks mid-sentence. A
  conversation is not a queue timer.
- **Beat ids are unique registry-wide** and `Content.BEAT_STRAND` maps beat → strand, because a customer
  carries only `beat_id`. `test_content.gd` asserts the uniqueness so a new beat cannot break it.
- **A beat may name its own speaker**: `character_id`/`archetype_id` on the beat override the strand's
  (Mehmet brings the news about Frau Schmidt; the main arc's `intro` is narration over `char/you`,
  `offer`/`climax` are Frau Brandt). Characters with no registry entry (yusuf, schmidt, aylinjonas,
  karim, achim, robin) fall back to their archetype's one-off portrait, per §6.
- **`story.met` holds the strand's display name** (as in the prototype) because `Finale` keys the
  tapestry off exactly that string.
- **Log entries carry `data: {}`** and the rule for it is *whole numbers are ints, never 2.0* — JSON
  types every number as float, so `from_json` re-integers integral floats in `data` (and every declared
  int field elsewhere). Without that pass the season does not round-trip byte-identically.
- **P&L identity holds on every closed night**: `profit = revenue + tips − cogs − bills(incl. fines) −
  pfand`. Note COGS is booked at sale time but paid at restock time, so `cash_after ≠ cash_before +
  profit` by design — the test checks the identity, not that link.

**Not done / for others.** No scenes, components or assets (other lanes). `Session.save()`/`load_save()`
write `user://autosave.json` — `load` is a global GDScript function, so the loader is `load_save()`, not
`load()`. `Rules.view().active` carries two keys beyond §5 (`want.restricted`, `underage`) so the UI can
render the underage-restricted ethics moment without reaching into the registry. `legal_actions` in the
manage phase emits a representative `set_price` (current price) and `restock {qty: 1}` per SKU — the
screen supplies its own number in the same shape. Portraits `char/brandt|tobias|schulz|nadia` are
referenced but not yet in `docs/asset-spec.json`; until the art lane draws them they resolve to a
missing file, not a crash (expression fallback is `_neutral`).

**Gotchas for the next operator.** Heredocs through the Bash tool mangled two of the larger data files —
write GDScript with the editor tools, not shell heredocs. `static func _static_init()` works in 4.7 and
is how the registry builds its id→row maps at class load. `Dictionary ==` is unreliable for "did the
reducer change anything"; `is_same()` is the identity test the "illegal action returns the same state"
contract relies on (`Session.dispatch` uses it).

## 2026-09-12 — art: char/you_neutral (art operator)
- **char/you_neutral — 1 attempted round (r2), best kept = the 66/100 baseline.** The r2 generation *landed the
  hard part*: looking at `art/raw/char/you_neutral-r2.png`, the identity drift is gone — boyish mid-20s face,
  short tousled crop with exposed ears, pale peach skin, flat cel clusters instead of painterly strand noise,
  correct taupe/charcoal jacket with red armbands. But it came back **colour type 2 with a painted grey-and-white
  checkerboard** instead of alpha (`transparentFrac < 0.02`), so the wrapper rejected it — per `02-art-pipeline.md`
  a checkerboard is unrecoverable and must be regenerated. The retry, and every call after it, died on
  `ERROR: You hit your spend cap set by the owner of your workspace` — **Codex is hard-blocked**, so neither a
  third generation nor any judging was possible. Canonical `godot/assets/char/you_neutral.png` therefore still
  holds the round-0 baseline (158×230, real alpha, judge 66); the r2 variant was removed from `godot/assets/`
  and its native PNG kept at `art/raw/char/you_neutral-r2.png` as visual evidence for the next round.
- **Spec changes** (`docs/asset-spec.json` → `char/you_neutral.prompt`): added a *rendering-discipline* clause
  (flat 4–6-tone clusters, chunky hair tufts with a 1-px contour, pale peach skin with lifted shadows, no
  gradients/speckle/anti-aliasing, "visual-novel portrait, not a realistic painting") and a *background* clause
  (real alpha, never a painted checkerboard, flat `#00ff00` fallback, blank chest patch — no logo shapes; the r2
  copied a Quiksilver-like mark off the reference).
- **Remaining fixes for the next round** (re-run `--variant r3` with the sharpened prompt once the cap lifts):
  transparency is the only blocker on r2's look; then re-judge — identity, hair, skin and flatness all read fixed
  by eye, so the ≥ 80 gate looks reachable in one more generation.

## 2026-09-12 — art fleets round 1: results, the spend cap, two wrapper bugs (orchestrator)
- **Scores:** scene/backdrop **84 pass** (r2; palette 88, berlin 96, pixel 79) · scene/title r2 **74** (pixel 57, fidelity 69; r1 was 49) · scene/counter generated (480×123, real alpha, no key bleed) but **unjudged** · char/you_neutral baseline 66; its r2 render is by eye the best likeness so far but came back on a painted checkerboard.
- **HARD BLOCKER:** every Codex call now fails with *"You hit your spend cap set by the owner of your workspace"* (WK ChatGPT Business admin setting). Generation and judging are down until an owner raises it. The wrappers now surface this as `BLOCKED (spend-cap)` / exit 75 and abort instead of retrying.
- **Bug 1 (cross-lane contamination):** `art.mjs` fell back to the newest PNG under `~/.codex/generated_images/` across *all* sessions — with ten lanes running, Lena adopted the counter strip and every SKU adopted the protagonist. All six SKU files were purged. Fix: the fallback is scoped to the run's own `session id` (parsed from Codex's header).
- **Bug 2 (evidence loss):** a rejected raw was deleted on retry and the real error hidden. Fix: rejected raws are shelved as `<id>-att<N>.png`, every attempt's error is reported.
- **Transparency, solved on our side:** the model paints checkerboards more often than it uses alpha and ignored the flat-key fallback. `img.gd --auto-bg` now flood-fills the background from the border (up to two colours estimated from the top edge, so a bust cut at the bottom edge is safe) — recovers checkerboard renders in ~1.5 s with no Codex call. Applied to every transparent asset automatically.
