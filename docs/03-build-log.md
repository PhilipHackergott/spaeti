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

- **Promoted (provisional, orchestrator's eye — Codex judge unavailable):** `char/you_neutral` = the r2 render recovered via `--auto-bg` (158×230, real alpha). Visibly closer to the target than the 66-point r1 (younger, compact hair, simpler rendering). Known flaw: a small brand-like chest mark → regenerate with the sharpened prompt when Codex returns, then re-judge. r1 kept as `art/raw/char/you_neutral-r1.png`.
- **Re-promoted:** the very first session's candidate 4 (`art/raw/char/you_neutral.png`, 155×230 after `--auto-bg`) replaces r2 as the provisional portrait — same likeness, no brand mark, softer clusters. r2 kept as `you_neutral-r2.png`. Codex re-judge pending the spend cap.

## 2026-09-12 — provisional visual review of the first captures (orchestrator, Codex judge capped)
Probe captures before the verify phase: `shots/probe-night.png` (customer_at_counter), `shots/probe-title.png`.
**Night ≈ 70 (provisional):** framing matches the OG interaction concept (counter edge ≈ y 210, dialogue box over the
band, cup + phone on the counter, wall of stuff, SPÄTI neon, Pfand crate, register). Fixes in priority order:
1. **The customer bust is missing** — `char/lena_neutral` was never generated (spend cap) *and* the placeholder is not
   visible. A missing portrait must render as an obvious silhouette placeholder (hashed colour, id label), never nothing.
2. HUD is oversized: two text lines at ~30 screen px, placeholder circle icons, the second line ("Tag 3 · Donnerstag · 2
   wartend") runs into the SPÄTI neon. Target: one compact line per corner, 16-px icons from `assets/ui`, text 4×(8–10 px).
3. Dialogue box too tall for its text (fills the whole counter band); Coffee Talk's is ≈ 60 % of that height with the body
   text ~1/3 of the box. Keep the name colour + ▾.
4. Want bubble + "Bedienen" read well; keep. Counter: the dark oval smudge right of the phone (also noted by the counter operator).
**Title ≈ 82 (provisional):** strong. Subtitle should read "eine Nacht **im** Kiez"; consider a 1-px dark outline on the
menu text over the bright window. Menu placement over the shop window is Coffee-Talk-appropriate.
**Language decision needed (user):** UI chrome came out fully German (Neues Spiel / Bedienen / Tag · Donnerstag); the GDD
specified an English base with German flavour words. Flagged; string-level either way.

## 2026-09-12 — component pool + scenes (operator: components lane)

**Built.** The whole pool in `godot/components/` (17 scene components + 4 code-only ones) and all five screens
in `godot/scenes/`, replacing the bootstrap Main. Contracts are in `docs/04-component-catalog.md` (rewritten).

- `theme.gd` (`class_name Palette`) + `Theme.tres` — the only place a colour, font size or layout constant lives.
  VT323 at 12/16/24/48; the font's import defaults (antialias + hinting) are overridden **at runtime** in
  `Palette.theme()` rather than in the `.import` file, so no other lane's re-import can undo it. Every stylebox
  has `anti_aliasing = false`.
- `assets.gd` (`class_name Assets`) — the art seam. `texture(id)` returns the real PNG if the art lane has made
  it, otherwise a generated placeholder at the **exact** base-pixel size from `docs/asset-spec.json` (bust
  silhouette for `char/*`, room for `scene/*`, bottle for props, disc for icons; hashed colour, id stamped with
  a built-in 3×5 font). Art drops in with no code change; `portrait()` does the `_expression → _neutral` fallback.
- `mock_view.gd` (`class_name MockView`) — read-models shaped exactly like `Rules.view()` for all nine presets, so
  the screens ran, captured and were judged before touching the engine lane's files.
- Screens: Title / Night / Manage / Summary + Main (shell + Transition). Each root has `render(view)` and
  `apply_capture_preset(name)`; `dispatch(action)` uses `/root/Session` when it exists (it now does) and prints
  otherwise. **A capture preset never reads Session** — determinism per docs/02.

**Captured and eyeballed all nine presets** (`shots/*.png`), fixing the composition until it matched the Coffee
Talk frames: full-frame set → bust centred behind the counter band → dark translucent dialogue box across the
counter (coloured speaker name, white body, blinking ▾) → choices stacked above it → want bubble beside the
customer → HUD in the corners → serve panel sliding over the right half with a shelf of ItemSlots and a Till.

**Tests.** `godot/tests/unit/test_scenes.gd`: every component loads + instantiates, every screen applies every
preset, the mock view keeps the docs/05 §5 keys and stays JSON-safe, placeholders keep their spec sizes, Palette
tokens hold. Full suite: **55 run, 0 failed** (with the engine lane's tests).

**Gotchas worth keeping**
- `remove_child()` + `add_child()` **clears a node's `owner`**, which silently unregisters its scene-unique name —
  `%Portrait` stopped resolving and the customer vanished from every Night capture. Use `reparent()` (and restore
  `owner`) whenever a scene hands a node to a component slot (`SceneLayers.mount`, `Modal.add_content`).
- Godot's TTF importer antialiases and hints by default; VT323 looks like mush at ×4 until you turn all three off
  (antialiasing NONE, hinting NONE, subpixel DISABLED).
- **VT323 has no `▾` (U+25BE)** — the continue mark is a `Polygon2D`. It does have `€`, `×`, `·` and the umlauts.
- Exported setters run *before* a scene's children exist, so components resolve nodes lazily with
  `get_node_or_null("%X")` and re-apply in `_ready()`; tweens are guarded by `is_inside_tree()` so a component
  instantiated headless in a test cannot crash.
- The art lane's `scene/counter.png` came in at 480×**123**, not the spec's 480×100 — `SceneLayers` now
  bottom-aligns the counter band to whatever height the art is (and exposes `counter_top()`).
- `shot.mjs` runs with the autoloads live, so a scene that reads `Session` would capture live state; hence the
  capture-mode branch in `Screen.view()`.

**Not done / for the next round**
- Portraits: only `char/you_neutral` exists, so every customer in the captures is a placeholder silhouette —
  `customer_at_counter` and `dialogue_choice` cannot pass the judge's ≥ 85 until Lena/Jürgen/one-offs land.
  SKU props and the five `ui/icon_*` are placeholders too.
- No `judge.mjs` run from this lane (the art lane owns Codex); the shots are eyeballed against the reference only.
- Audio, pause menu, settings content, save/continue are still stubs; `Title → Fortsetzen` is disabled by design.
- The Till lists at most two picked lines + a Pfand line (the panel has no room for more); a bigger order shows
  "+N more".

---

## 2026-09-12 — Verification pass (engine lane + component/screen lane)

Read-only audit of the two lanes that just landed. Everything below was **run**, not read off the reports.

**Green.** `node tools/godot/test.mjs` → **55 run, 0 failed, 2856 asserts**, exit 0, no ERROR/WARNING/leak lines.
All 17 component `.tscn` and all 5 screens load + instantiate (`test_scenes.gd` enumerates them). All **nine**
presets captured with `shot.mjs` → `shots/verify-<preset>.png`, 1920×1080, `err=0`, no engine messages.

**Contract (docs/05).** `godot/engine/` is clean of `Node|Input|OS.|Time.|get_ticks|randf|randi|get_tree`
(the only hits are the seeded `Rng.randi_below` and its one caller in `storyflow.gd`). `Rules.apply` clones
first and `return s` on every illegal branch. §2 state keys, §3's twelve actions and §5's seventeen `view()`
keys all match exactly. `Session` is registered in `[autoload]`. Every `portrait` id in `characters.gd` has a
`_neutral` entry in `docs/asset-spec.json`. `docs/04` documents all 21 component scripts + `Theme.tres`.

**Blocking**
1. `components/assets.gd` `portrait()` — the `_neutral` fallback is gated on `is_real()`, so with no art on
   disk `char/oneoff_clubber_warm` reaches `_placeholder()`, misses `SIZES`, and renders at `FALLBACK_SIZE`
   32×32. `shots/verify-serving.png` shows the customer as a tiny blob floating over the neon instead of a
   bust behind the counter. Violates §6. Fix: resolve the expression before asking for a texture (fall back
   when `not is_real(a) and not SIZES.has(a)`, or route through the already-tested `Content.portrait_asset()`).
2. `components/assets.gd` `SIZES` has drifted from `docs/asset-spec.json`: `char/{brandt,tobias,schulz,nadia}_neutral`
   are missing (→ 32×32 busts in the live game, same failure as 1) and `scene/counter` says 480×100 where the
   spec says 480×130 and the shipped PNG is 480×123.
3. `engine/rules.gd WEEKDAY_NAMES` is English ("Thu") and `hud.kiez_label` is `"Kiez-Trust %d"`, but
   `mock_view.gd` fakes `"Donnerstag"` / `"Kiez 62"`. `hud.gd` prints both verbatim, so every judged capture
   shows text the engine will never produce (and the real label overflows the HUD plate).
   `test_mock_view_matches_the_contract` only checks key presence, so nothing catches it.
4. Raw colour literals in scene files — `scenes/Summary.tscn:25,52,61`, `scenes/Title.tscn:45` — against
   docs/04 rule 1. (Components also carry raw colours: `scene_layers.gd:36-38`, `modal.gd:22`, `meter.gd:23`.)

**Non-blocking, worth a round**
- `night.gd::_place_bubble` moves the want bubble, dialogue box and HUD out of the serve panel's half but not
  the `Portrait`: in `verify-pfand.png` Jürgen is ~55 % hidden behind the panel.
- **VT323 at `FONT_BODY 16` drops the middle stroke of `M m W w`** (verified on ×2 crops): "Mate"→"Nate",
  "Miete"→"Niete", "Umsatz"→"Unsatz", "Wasser"→"Masser", "im Kiez"→"in Kiez". Every screen is affected.
- `assets.gd::_stamp_id` clips on narrow props — `sku/coffee` reads "FFEE", `sku/chocolate` "COLATE",
  `sku/cigarettes` "TTES" in `verify-serving.png`.
- `verify-manage.png`: the restock list clips a row mid-height at the scroll boundary; reads as a fault.
- `docs/05 §7` still documents `Session.load()`; the implementation is `load_save()`.
- `docs/asset-spec.json` has no `_warm/_upset/_wary` entries for mehmet/brandt/tobias/schulz/nadia although
  `characters.gd` declares those expressions. `char/you_neutral` shipped 155×230 vs the spec's 190×230.
- `late_night` *does* differ from `empty_counter` (mean channel delta ≈ 17 over the lower frame) — the grade is
  just subtle. Not a bug.

## 2026-09-12 — FIXER lane: the four blocking verifier findings

**Fixed**
1. `components/assets.gd::portrait()` resolves the **expression before the texture**: `pid_exp` that is neither
   real art nor a `SIZES` entry falls back to `pid_neutral` (docs/05 §6). The `serving` clubber
   (`char/oneoff_clubber` + `"warm"`) is a 190×230 bust behind the counter again instead of a 32×32 blob —
   `shots/fix-serving.png`.
2. `Assets.SIZES` re-mirrored on `docs/asset-spec.json`: added `char/{brandt,tobias,schulz,nadia}_neutral`
   (190×230) and corrected `scene/counter` to 480×130. New `test_asset_sizes_match_the_spec` parses
   `docs/asset-spec.json` (via `ProjectSettings.globalize_path`) and fails on any drift in either direction,
   so the hand-mirror cannot rot again.
3. `Rules.WEEKDAY_NAMES` is German (`Montag…Sonntag`) — the whole UI is German — and `mock_view.gd` now prints
   the engine's own strings: `"Kiez-Trust 62"` (was `"Kiez 62"`) and `"Mittwoch"` (day 3, since day 1 is a
   Montag). New `test_mock_view_speaks_the_engines_language` compares the mock's `hud.kiez_label`,
   `hud.profit_label` and `weekday_name` against `Rules.view(SpatiState.new_game())`, not just key presence.
   The real label does **not** overflow the HUD plate: `shots/fix-customer_at_counter.png` shows
   "Kiez-Trust 62" + the 8-cell bar inside the right plate.
4. No screen writes a colour any more. New `Palette.SCRIM / DIM / RULE`; `Summary.tscn`'s Dim + two Rules and
   `Title.tscn`'s Vignette lost their `color = Color(...)` lines and are painted from the tokens in
   `summary.gd` / `title.gd` `_ready()`. New `test_scenes_write_no_colours` greps every screen `.tscn`.
   Re-captured: `shots/fix-summary.png`, `shots/fix-title.png`.

Editor placeholders that had gone stale were corrected with them (`Hud.tscn` "Tag 3 · Mittwoch",
`Meter.tscn` "Kiez-Trust 62", `Summary.tscn` Sub "Mittwoch · 23 verkauft"); all are overwritten by `render()`.

`node tools/godot/test.mjs` → **59 run, 0 failed** (55 before + 4 new).

**Not done / gotchas**
- `scene/counter` still has three numbers: the spec and `Assets.SIZES` now agree on 480×130, but the shipped
  `godot/assets/scene/counter.png` is 480×123. Only the placeholder uses `SIZES` (`SceneLayers.counter_top()`
  measures the real texture), so nothing moved — but the art lane owns closing that 7-px gap.
- Components still carry raw colours (`scene_layers.gd` DUSK/DEEP/DAWN, `modal.gd`, `meter.gd`'s `fill`
  default, `Hud.tscn`'s `fill = Color(...)`). Rule 1 says a component may not write a raw hex either; out of
  scope for this pass, and `hud.gd` overwrites the meter fills from `Palette` at render time.
- The non-blocking findings (VT323 losing the middle stroke of `M/W`, `_stamp_id` clipping narrow props, the
  portrait hiding behind the serve panel in `pfand`) were left alone — not this lane.

## 2026-09-12 — verification pass (read-only lane)

Ran, did not read: `node tools/godot/test.mjs` → **59 run / 0 failed / 2968 asserts**, exit 0, no `ERROR`,
`SCRIPT ERROR` or leak lines in the full log. Captured all nine `docs/02` presets fresh via
`tools/godot/shot.mjs` (`shots/verify-<preset>.png`, plus `shots/verify-main.png` through the Main shell) —
all `err=0`, all 1920×1080 — and looked at every PNG (plus 1:1 crops of the till, the HUD plate, the manage
row list and the wordmark). Grepped `godot/engine/` for `Node|Input|OS.|Time.|get_ticks|randf|randi`: the only
hit is the seeded `Rng.randi_below`. Grepped `godot/scenes/` for `StyleBoxFlat`/`Color(`: none. State keys,
the 12 actions, `legal_actions` gating and `view()` keys match docs/05 §2/§3/§5; `Session` is registered in
`[autoload]`.

**Blocking (found by reading what the captures cannot show — every one of these is live-Session only):**
1. `components/till.gd:106,109` hardcodes the Pfand rate at `0,08` while `Rules.PFAND_PER_BOTTLE = 0.15`.
   The `pfand` capture therefore shows "Pfand 6 x 0,08 → −0,48 €, Total 0,72 €" where the engine will take
   €0.90 and leave €0.30. Fix: read the rate from the engine (add `pfand_rate` to `Rules.view()` or use
   `Rules.PFAND_PER_BOTTLE`), including the literal in the row label.
2. `components/manage_board.gd:66` re-implements `Economy.price_tier` with `hi * 1.15`; the engine uses
   `hi * 1.25`. Prices in that band are painted "gouge" red while the rules still call them "high".
   Fix: put `tier` on each `manage.restock_options` entry (`Economy.price_tier`) and delete `_tier()`.
3. Nothing ever dispatches `close_night` and no screen leaves Night. Manage→Night and Summary→Manage are
   wired; Night→Summary is not, so a live run reaches the first night and stays there. Fix: in `night.gd`,
   on `night_progress >= 1.0` (or `v.phase != "night"`) dispatch `close_night` and
   `request_screen.emit("summary")`.
4. `components/dialogue_box.gd::show_dialogue` resets `_line_index = 0` and restarts the typewriter on every
   call, and `night.gd::render` calls it on every `Session.changed` — i.e. 60×/s during the night. Live, the
   line never types out and `advance()` cannot stick. Fix: no-op when the incoming speaker+lines+choices equal
   what is displayed.

**Non-blocking:** `mock_view.gd` invents archetypes the registry does not have (`pfand_sammler`, `clubber`,
"Studentin") and German SKU names (`Wasser`, `Schoki`, `Kippen`, `Feuer`) where `skus.gd` says `Water`,
`Chocolate`, `Cigarettes`, `Lighter` — so every capture shows text the engine cannot produce, which is exactly
what docs/04 claims `test_mock_view_speaks_the_engines_language` prevents (it only checks the two HUD labels
and the weekday). · A new game stocks **17** SKUs; the mock shelf shows 10, and `Shelf` is an unbounded
5-wide grid inside a 240×252 `ServePanel` — 4 rows will push the Till out of the panel. · `night.gd:136`
invents a speaker name from the character id (`juergen` → "Juergen", not "'Bottle' Jürgen"); `view.active`
should carry the character's `name`. · 8 expressions declared in `content/characters.gd`
(`mehmet_warm/wary`, `brandt_wary`, `tobias_warm/upset`, `schulz_wary`, `nadia_warm/upset`) have no
`docs/asset-spec.json` entry, so the art lane has no work item and they will silently render `_neutral`. ·
The Manage restock list clips mid-widget: the row after Kaffee is sliced, leaving 8-px button stubs above the
divider. · VT323 at 12/16 px: `8` reads as `B` ("0,0B", "B,50") and `M` reads as `N` ("Nittwoch", "Nate",
"Nave off") — money and names are the worst places for it; it is crisp at 24/48 (the Manage header's
"Mittwoch" is correct). · `late_night` rain is 0.10–0.26-alpha cyan streaks over the whole frame, so it is
invisible in the capture and, per the layer order, falls *inside* the shop. · `_stamp_id` keeps the tail of
an id, so placeholders read "FFEE", "COLATE", "TTES". · `project.godot` does not set
`snap_2d_transforms_to_pixel`, which docs/01 says is on. · `test_scenes.gd::COMPONENTS` is a hand-written
list — a new `.tscn` in the pool is not tested until someone adds it.

## 2026-09-12 — Fixer lane: the four blocking findings

All four are fixed; `node tools/godot/test.mjs` = **61 run, 0 failed, 3022 asserts** (2 new tests).

1. **The till quoted a deposit the reducer does not pay.** `Rules.view()` now carries
   **`pfand_rate` (= `Rules.PFAND_PER_BOTTLE`, 0.15)** — a contract addition to docs/05 §5 (noted here
   because the fixer lane does not own that doc; someone should paste the key into §5's read-model block).
   `till.gd` gained `pfand_rate` + `set_pfand_rate()` and formats both the row label and the total from it
   (the two `0.08` literals and the hardcoded "0,08" string are gone); `serve_panel.gd::render` feeds it from
   the view. `MockView` publishes `Rules.PFAND_PER_BOTTLE` too, so captures cannot drift. `shots/fix-pfand.png`
   now reads `Pfand 6 x 0,15 → -0,90 €`, `Total 0,30 €` — exactly what `serve_active` will charge.
2. **The Manage board re-derived the price tier.** `Rules._restock_options` now puts
   `tier: Economy.price_tier(def, price)` on every entry (alongside `fair_lo/fair_hi`); `manage_board.gd`
   colours from `entry["tier"]` and `_tier()` (the 1.15-vs-1.25 copy) is deleted. `MockView._restock()` carries
   the matching tiers and a new assert checks them against `Economy.price_tier` for both the mock and the real
   read-model. `shots/fix-manage.png`: Cola 1,70 in a 1,20–1,60 band is now amber "high", not red.
3. **The loop ran into the first night and stopped.** `night.gd::render` now calls `_advance_phase(v)`
   (skipped in capture mode): at `night_progress >= 1.0` with an empty counter (`active` empty, `queue_len` 0)
   it dispatches `close_night`, and on `phase == "summary"` it emits `request_screen("summary")`. Two latches
   (`_closing`, `_leaving`) keep each transition firing once even though `Session._process` re-renders every
   frame. Manage→Night→Summary→Manage is now closed. A customer mid-beat holds the night open on purpose
   (patience does not run during a conversation) — the choice still has to be made.
4. **The typewriter restarted 60×/s.** `dialogue_box.gd` keeps `_current` and `show_dialogue()` returns early
   when speaker/portrait/kind/lines/choices are unchanged (`_same_dialogue`), so a beat now types out once and
   `advance()` sticks; `clear()` resets it. `show_final()` (captures) is unaffected —
   `shots/fix-dialogue_choice.png` is identical to before.

Also, minimally: `screen.gd::session()` returns `null` when the screen is not inside the tree (an absolute
`/root/Session` path errors out there) — needed so a component/screen instantiated by a test or a capture can
call `dispatch()` without spewing engine errors.

New tests in `tests/unit/test_scenes.gd`: `test_night_screen_closes_the_night_and_hands_over` (renders an
over-time night, then a summary view twice, and asserts one `request_screen`) and
`test_dialogue_survives_being_re_rendered` (re-sending the same beat does not rewind the line; a different one
does). `VIEW_KEYS` gained `pfand_rate`, and `test_mock_view_speaks_the_engines_language` now checks the rate
and every restock tier against the engine.

**Not done / for other lanes:** docs/05 §5's read-model block still lists the old key set (no `pfand_rate`, no
`tier` on `restock_options`) — outside this lane's ownership. · `content/skus.gd` carries a per-SKU `deposit`
(beer 0.08) that nothing reads; either the reducer should use it per SKU or it should go, because it is what
the till's wrong 0,08 was copied from. · The non-blocking list above (mock vocabulary, Manage row clipping,
VT323 `8`/`M`, placeholder stamps) is untouched.

## 2026-09-12 — VERIFIER lane (second pass, after the FIXER round)

Everything below was established by running things, not by reading the previous lanes' reports.

**Tests.** `node tools/godot/test.mjs` → **61 run, 0 failed, 3022 asserts**, exit 0. A full re-run scanned for
`SCRIPT ERROR|ERROR:|WARNING|leaked|Parse Error` — **zero hits**; the leaked-instance warnings the component
lane reported are gone.

**Captures.** All nine documented presets re-captured from scratch (stale `verify-*.png` deleted first) with
`shot.mjs` → `shots/verify-<preset>.png`, every one `err=0`, 1920×1080, no engine messages. `Main.tscn` also
captures (`verify-main.png`). Every PNG was read and inspected; two were re-cropped at ×2/×3 for glyph and
clipping checks.

**Contract (docs/05) — verified directly.**
- `godot/engine/` grep for `Node|Input|OS.|Time.|get_ticks|randf|randi|Engine.|SceneTree`: the only hits are
  `Rng.randi_below` and its one caller in `storyflow.gd`. Pure.
- `Rules.apply` clones first and `return s` on every illegal branch; `test_night.gd` asserts it with
  `is_same()` (identity), not `==`. All twelve §3 actions handled, no thirteenth.
- `SpatiState.new_game` emits exactly the §2 keys, `active` as `{}`.
- `Rules.view()` carries every §5 key — **plus `pfand_rate`**, an 18th key (see below).
- `Session` registered in `[autoload]`; §7 API matches (`load` → `load_save`, the documented deviation).
- Every `portrait` id in `characters.gd` has a `_neutral` entry in `docs/asset-spec.json` (the art lane's
  brandt/tobias/schulz/nadia rows have landed).
- `godot/scenes/` greps clean for `StyleBoxFlat` / `Color(` / `add_theme_*_override` in both `.gd` and `.tscn`.
- `docs/04-component-catalog.md` documents all 21 component scripts + `Theme.tres` + all 5 screens — complete.
- Summary capture satisfies the P&L identity by arithmetic: 142,80 + 8,40 − 61,20 − 35,00 − 4,80 = **+50,20**.
- `late_night` really is graded cold (mean B 66,8 > R 55,5) against `empty_counter`'s warm (R 81,0 > B 48,2).

**BLOCKING — 1 finding**
1. **`components/theme.gd::_pixelate` destroys glyphs: `M m W w 8` lose their middle stroke at every size.**
   Verified on ×3 crops of `verify-serving.png` and `verify-summary.png`: "Mate"→"Nate", "Wasser"→"Masser",
   "Miete + Strom"→"Niete + Stron", "MODULE"→"NODULE", "Mittwoch"→"Nittwoch", and — worst — **"1,80"→"1,B0"**,
   **"x18"→"x1B"**. Prices and stock counts read as the wrong characters on every screen. `Title.tscn` really
   does say "eine Nacht im Kiez"; the frame shows "in Kiez". Cause: `_pixelate` sets `hinting = HINTING_NONE`
   *and* `antialiasing = FONT_ANTIALIASING_NONE`, so VT323's one-unit middle stems land between pixel centres
   and are dropped with nothing to snap or smooth them. The previous lane logged this as non-blocking; it is
   not — no hero capture can reach the judge's ≥ 85 while the product names and the money are misspelled.
   Fix, cheapest first: (a) keep antialiasing off but set `ff.hinting = TextServer.HINTING_NORMAL` and
   `ff.force_autohinter = true` so stems snap to the grid; (b) if that does not restore all five glyphs, sweep
   `FONT_SMALL/BODY/LEAD/TITLE` for a size where VT323 keeps them and re-capture; (c) the certain fix is to
   drop VT323 for a genuine bitmap pixel font (Pixel Operator / m5x7 / m6x11, OFL) whose glyphs are defined on
   the pixel grid and cannot lose a stroke. Re-verify by cropping "Mate", "Wasser", "1,80" at ×3.

**NON-BLOCKING**
- `assets.gd::_stamp_id` clips the id on narrow props: `sku/coffee` reads "FFEE", `sku/chocolate` "COLATE",
  `sku/cigarettes` "TTES" in `verify-serving.png`. Placeholder-only; it disappears when the art lands.
- `verify-manage.png`: the restock list clips row 6 mid-height at the scroll boundary — reads as a rendering
  fault rather than a scroll affordance. Clip on a row boundary or fade the last row.
- `verify-pfand.png`: `night.gd::_place_bubble` relocates the bubble/dialogue/HUD out of the serve panel's
  half but not the `Portrait` — Jürgen sits ~55 % behind the panel.
- `docs/05 §5` lists 17 `view()` keys; the implementation and `test_scenes.gd::VIEW_KEYS` carry 18.
  Add `pfand_rate` to §5 (the till must quote the reducer's deposit, so the key is right — the doc is stale).
- `components/till.gd` and `components/serve_panel.gd` reference `Rules.PFAND_PER_BOTTLE` as a default. A
  component reaching into the engine; the view already carries the value, so default to `0.0`.
- Shipped art drifts from `docs/asset-spec.json`: `char/you_neutral.png` is 155×230 (spec 190×230) and
  `scene/counter.png` is 480×123 (spec 480×130). Placeholders use the spec size, so layout shifts when real
  art lands. Art lane owns it.
- `docs/asset-spec.json` still has no `_warm/_upset/_wary` entries for mehmet/brandt/tobias/schulz/nadia,
  although `characters.gd` declares those expressions (they fall back to `_neutral`, no crash).
- Components still write raw colours (`scene_layers.gd` DUSK/DEEP/DAWN, `modal.gd`, `meter.gd`, `Hud.tscn`),
  against docs/04 rule 1. Scenes are clean.
- Language is mixed: the chrome is German (Laden, Nachbestellen, Kasse, Aufmachen, Gewinn, Bedienen) while all
  dialogue and every module name/description is English ("Second fridge", "Patience +15 % when it rains").
  The GDD flags localisation scope as an open decision (⚑) — it needs one before the content lane writes more.
- `late_night` is graded correctly but the rain layer is invisible in the capture; docs/02 asks for rain.

## 2026-09-12 — outstanding after foundations verify round 3 (orchestrator → integration lane)
Two fix rounds cleared 8 blocking findings (portrait fallback, SIZES drift, mock/engine text mismatch, scene colour
literals, Till Pfand rate, manage tier thresholds, close_night never dispatched, dialogue typewriter restart). Left open:
- **BLOCKING — font glyphs destroyed:** `theme.gd::_pixelate` sets `hinting = NONE` **and** `antialiasing = NONE`; VT323's
  one-unit middle stems fall between pixel centres and vanish at 16 px: "Mate"→"Nate", "Mittwoch"→"Nittwoch", "8"→"B",
  "MODULE"→"NODULE" on every screen. Try `hinting = LIGHT`/`NORMAL` first (cheapest); if stems still drop, replace the face
  with a bitmap-native pixel font at a native size (Pixel Operator (CC0) 8/16 px, or m5x7/m6x11) and record the licence.
- Portrait is not moved when the ServePanel opens → Jürgen's bust ~55 % hidden in `pfand`; shift the bust left (~x 120) when the panel is shown.
- `late_night` rain (26 × 1-px cyan streaks at α 0.1–0.26, drawn inside the shop) is invisible — draw it in the window/door region, brighter, before the counter.
- `Assets._stamp_id` keeps the tail of an id on narrow placeholders ("FFEE", "TTES") — strip `sku/`, shrink, or wrap.
- Manage restock list clips row 6 mid-widget at the scroll boundary — size the viewport to whole rows.
- `night.gd` capitalises `character_id` for the speaker name ("Juergen") — use the registry's display name.
- `project.godot` lacks `rendering/2d/snap/snap_2d_transforms_to_pixel=true` although docs/01 states it — add it.
- Components still hold raw colours (scene_layers DUSK/DEEP/DAWN, modal dim, meter fill, Hud.tscn fill) — move to `Palette`.
- Shipped art is smaller than its spec box (you_neutral 155×230, counter 480×123); placeholders use the spec size, so
  layout must anchor busts by bottom-centre and the counter by bottom edge, not by the spec rectangle.
- Language is mixed (German chrome, English dialogue/modules) → string table + English base per GDD (see integration brief).

## 2026-09-12 evening — new Codex account + model tiers (orchestrator)
- Codex switched to the user's personal account (`scarxful@gmail.com`, plan prolite) after the WK workspace spend cap; calls work again.
- **`gpt-6-astra` is available** and is now the design + judging model (concept art, scene layers, portraits, every verdict);
  `gpt-5.6-sol` keeps the small image work. Wired into `tools/paths.mjs` (`CODEX_MODEL_HERO/SMALL`), `art.mjs` (per-kind
  tier), `judge.mjs` (astra + the generated concept as reference 3), `docs/asset-spec.json` (`modelByKind`, new kind
  `concept`, entry `concept/night_interaction`).
- Art round 2 (sol, six lanes) was already running when astra arrived; its SKU/icon lanes stay valid (sol is the right tier),
  its portrait/scene results are provisional until astra re-does the hero assets against the generated concept.

- **Concept painting landed** (`concept-art/generated/night_interaction.png`, astra, 1536×1024, 187 s / 28k tokens): Lena at the counter in the Späti set, on one grid — by eye the composed target we wanted. Wired as reference 2 for scene/backdrop, scene/counter and char/lena_* and auto-added to every judge call. A false positive in the block detector (matched "usage limits" in echoed doc text) had aborted the run after the image existed — detector now only reads Codex `ERROR` lines.

- **Concept r2 promoted** (astra **79**: composition 82, palette 85, pixel 65, Lena 87, Berlin 93; r1 = 76). Canonical: `concept-art/generated/night_interaction.png` (raw 1536×1024) + `night_interaction-grid.png` (16:9 centre crop snapped to 480×270 and shown ×4 — the judge prefers this one; it is the Night screen at real density). The judge's remaining fixes target the raw painting's microtexture, which the snap removes; stop iterating the concept here.

## 2026-09-12 evening — calibration ladder on the concept (astra judging)
| candidate | overall | pixel_rendering | note |
|---|---|---|---|
| concept r1 raw (1536×1024) | 76 | 61 | too fine/inconsistent grid, Lena staged low |
| concept r2 raw | 79 | 65 | composition fixed; microtexture remains |
| r2 → 16:9 crop → snap 480×270 → ×4 nearest (**the game's presentation**) | **81** | 74 | "density objection resolved; microtexture reduced, not resolved" |
| + median-cut quantise 96 colours | 79* | 76 | marginal: "fewer colours do not reorganise painted texture into authored clusters" (*fidelity 55 was a context slip — Lena judged as 'You') |
Conclusion: the snap is worth +2 to +5; palette quantisation is **optional, not standard** (a few points, some banding). The remaining
gap to "authored clusters" has to come from **generation discipline** (the TRUE-PIXEL-ART / 4–6-tone / stepped-contour clauses
that moved the backdrop 61→79) plus the judge loop — and astra as generator. `--quantize` and `--despeckle` stay available in `img.gd`.

## 2026-09-12 — art round 2: sku/beer, sku/mate, sku/cola, sku/water, sku/chips (art operator)

Round 1 of these five never ran (spend cap + the cross-lane `~/.codex/generated_images` bug). Both are fixed, so
this is the first real pass. All five now sit at `godot/assets/sku/<id>.png` with a real alpha channel, judged at
x25/x29 nearest upscale with the prop context ("only pixel_rendering, palette_lighting and berlin_reskin apply;
the pipeline trims sprites, so margins are irrelevant"). **Five of five pass ≥ 80; no asset is blocked.**

- **sku/beer — 1 round, 84 pass** (palette 80, pixel 85, berlin 91). Green stubby bottle, gold crown cap, blank
  cream paper band, amber-lime highlight left / slate rim right. Snapped 9x36 (the drawn bottle is slimmer than
  the 14x36 spec box — the engine must anchor SKUs bottom-centre, not by the spec rectangle). Remaining fixes
  (not worth another round): consolidate a few near-identical glass shades; the left highlight is a touch lime
  rather than amber; the paper label's outer columns are lit symmetrically.
- **sku/mate — 2 rounds, 84 pass** (palette 81, pixel 88, berlin 83; r1 was 78). r2 fixed the luminous yellow
  label slab and the opaque-looking grey neck collar. Snapped 10x36. Remaining: pale glass highlights still
  compete with the label; the blue neck reflection reads slightly like an insert; the blank label makes it read
  as "a brown bottle" — the judge suggests a 3-pixel dark-olive leaf mark to make the SKU distinct (no lettering).
- **sku/cola — 1 round, 82 pass** (palette 80, pixel 84, **berlin 94** — explicitly asked about brand resemblance
  and it came back clean: generic contour bottle, plain red band, no script/swirl). Snapped 10x36. Remaining: the
  lower body collapses into near-black browns (lift one connected 2–3-px brown cluster a value step); the pale
  neck reflection reads like a metal sleeve.
- **sku/water — 2 rounds + a re-snap, 83 pass** (palette 81, pixel 84, berlin 92; r1 73, r2-lanczos 78). r2
  restored the navy contour and the warm-ivory left reflection the first render lacked. Snapped 11x36. Remaining:
  the label reads as a flat cuff with too heavy a bottom shadow; the cream reflection is a long solid stripe.
- **sku/chips — 2 rounds, 84 pass** (palette 80, pixel 86, berlin 90; r1 78). r2 deepened the hot orange to
  paprika red, made the crimped seals legible (3–4 one-pixel crimp marks + a crease) and turned the "gold badge"
  into an asymmetric curled crisp with an ochre underside. Snapped 23x32. Remaining: a few bright orange folds on
  the right fight the cool-right lighting; the crisp can still read as a crescent.

**The finding worth keeping — for these tiny sprites the snap filter is worth more than another generation.**
`mate` and `water` were stuck at 78 with the identical top verdict ("numerous near-identical shades → a
downsampled-gradient look instead of deliberate clusters"). That is the *Lanczos* downscale inventing intermediate
tones between the model's flat blocks, not the prompt. Re-snapping the **same** raw with `--filter nearest` lifted
`pixel_rendering` 76 → 88 (mate) and 75 → 84 (water) and both to a pass, for zero Codex calls. Recommendation:
try `"filter": "nearest"` first on any prop under ~40 base px whose raw is already large flat blocks; keep lanczos
for busts and scene layers. `beer` (85) and `cola` (84) were left on lanczos only because they already passed and
`godot/tools/img.gd` was mid-edit by another lane when the A/B would have run — worth the two snaps later.

**Spec changes (`docs/asset-spec.json`, my five entries only; ids/sizes/kind untouched):** rewrote the `prompt`
for `sku/mate`, `sku/water`, `sku/chips` — each now names an explicit closed palette ("USE ONLY THESE 7/9
COLOURS", every neighbouring pair strongly separated in value so it survives the downscale), asks for the
near-black contour **two blocks thick** (a 1-block outline is eaten by the downscale), and pins the light as one
connected warm column left / one 1-block cool rim inside the contour right. Added `"filter": "nearest"` to
`sku/mate` and `sku/water`, and `"bgTol": 0.25` to `sku/mate`.

**Pipeline note (cost the mate round its first snap):** gpt-image painted a *checkerboard* background for `mate`
r1 plus faint ghost smudges across the canvas. `--auto-bg` keyed the checkerboard but the ghosts survived, so the
tight trim kept the full 1024x1536 canvas and the bottle snapped to 14x**21** — a correct-looking file that is
silently a third of the sprite. Raising `--bg-tol` to 0.25 recovered it (430x1514 → 10x36). **Always check the
snapped `width`/`height` in `art.mjs`'s JSON against the raw's subject aspect; a wrong aspect there means the trim
failed, not that the art is wrong.** The r2 prompts now also forbid any mark, glow, halo or smudge outside the
subject for exactly this reason.

- **Incident 20:52–20:58:** adding `--despeckle` to `img.gd` introduced a GDScript parse error (`var p := o + d` with an untyped loop var) that broke EVERY snap for ~4 min — the art lanes logged 11 `img.gd failed` results (raws are kept; re-snap with `art.mjs --reuse-raw`). Fixed (typed loop), verified, committed. `judge.mjs` now refuses a missing candidate instead of returning a zero-filled verdict.

- Ladder completed: +quantise 64 → **81** (pixel 76); +quantise 96 + 2× despeckle → **82** (pixel 77, Lena judged as NPC: fidelity 85). Astra: "further progress needs targeted cluster redraws". **Decision: the standard chain is snap-only; `--quantize` / `--despeckle` are opt-in polish** (≈ +1 each, some banding risk). The lever for ≥ 85 is the generation prompt (TRUE-PIXEL-ART clauses) + astra as generator + the judge loop.

## 2026-09-12 — INTEGRATION lane (resumed): the Jersey font, a real playthrough, the verify leftovers

`node tools/godot/test.mjs` -> **66 run, 0 failed**. `node tools/godot/play.mjs` -> **PLAY ok steps=15**,
zero engine error lines, night 1 finished and night 2 open.

### 1. The font: VT323 is gone, Jersey is in — and the sizes were MEASURED, not assumed

VT323 is an outline face. At 16 base px its one-unit middle stems fall between pixel centres and simply
vanish: "Mate"->"Nate", "MODULES"->"NODULES", "Mittwoch"->"Nittwoch", "1,80"->"1,B0", "x18"->"x1B"
(`shots/probe3-night.png`, `shots/probe3-manage.png`). Hinting NORMAL, the previous lane's patch, kept the
stems but at the cost of a smeared, un-pixel look — and 16 px of VT323 is about twice Coffee Talk's body.

Jersey (OFL, `godot/assets/fonts/OFL-Jersey.txt`) replaced it. The brief said "each face only at its native
size (10/20/25)"; **that turned out to be wrong on this family**, and the way we found out is a new tool:

- `godot/tools/FontProbe.tscn` + `font_probe.gd` prints one sample in every face at every candidate size.
  Captured with `shot.mjs` and read at x2/x3: `shots/fontprobe.png`, `fontprobe2.png`, `fontprobe3.png`.
- **Jersey 10 @10 is BROKEN** — "KIEZ" renders "HIEZ" (the K loses its diagonal). @14 is broken too
  ("Wasser"->"Wassor"). It is clean at **12 / 16 / 20 / 25 / 50**.
- **@12 draws every letter but not every NUMBER**: "22:41"->"ZZ41", "84,50"->"84.50" (2 reads as Z, the
  comma flattens to a dot). Unusable for a clock and for money, which is most of this game's text.
- **Jersey 20 @20 loses the middle bar of an `8`** ("1,80"->"1,00"). It is clean at 25/50, so it earns no
  slot in the ladder; the file and its licence stay.
- **Jersey 25 @50** is a caps-only display face and is perfect — the wordmark, nothing else.

So the ladder is **one text size**, like Coffee Talk: `FONT_TINY = FONT_SMALL = FONT_BODY = 16`,
`FONT_LEAD = 20`, `FONT_TITLE = 50`. Jersey 10 @16 has an 8-px cap where VT323 @16 had 11, so this is
*smaller* on screen than what the review complained about, not bigger. Antialiasing NONE, hinting NONE,
subpixel DISABLED — set in the three `.import` files **and** forced in `Palette.theme()`, which now walks
`get_font_type_list()` instead of only `default_font`, so neither half can rot alone.

Everything that assumed 16-px VT323 was re-laid out and re-read at 1080p:
`DIALOGUE_RECT` 40,196,400x64 (a 12-px speaker line + two 16-px body lines + padding; docs/02 asks for
y 196-262) with the choices stacked 60 px above it; the HUD's `Meta` line dropped the weekday (at one text
size the corner cannot hold clock + cash + Pfand + weekday AND leave the other corner to the meters — the
weekday is on the Manage title and the Summary sub-line); a new `StepButton` theme variation with zero
vertical padding so a Manage row is one row tall; the Modal frame widened to 12..468 so a module
description stops clipping mid-word; `ManageBoard` now **measures** a built row and sizes its scroll window
to `ROWS_VISIBLE` whole rows (`_fit_scroll_to_whole_rows`) instead of trusting a constant that went stale
the moment the font changed — which is also the fix for "row 6 sliced at the boundary".

**The Shelf became a list.** At one text size a 42-px grid tile can print a name OR a price, never both, and
the shelf is 17 SKUs (23 with the modules). It is now one full-width `ItemSlot` row per SKU (icon well 18x26,
clipped so a 36-px bottle cannot stretch the row; name / price / stock / badge as columns) inside a scroll
window in the ServePanel — and `ServePanel.render()` **scrolls to the SKU the customer asked for**, so what
you need is never three rows down. The panel grew to x 228..476 to fit it.

Read at 1080p, word by word: `shots/f6-title.png`, `f6-summary.png`, `f9-manage.png`, `f2-dialogue_choice.png`,
`f4-pfand.png`, `play-06-first-customer.png`, `play-08-picked.png`, `play-11-beat-choice.png`. No dropped
stems, no 8->B, no 2->Z; the P&L reads 142,80 + 8,40 - 61,20 - 35,00 - 4,80 = +50,20.

### 2. The playthrough tool — the proof the loop is playable

`godot/tools/playthrough.gd` + `Playthrough.tscn` + `tools/godot/play.mjs` (the spawn/lock/watchdog pattern
copied from `shot.mjs`, WINDOWED, `--timeout 240`). It boots the real `scenes/Main.tscn` into the same
480x270 SubViewport `shot.gd` uses and plays it through the screens' **own** handlers — `MockView` is never
touched, every number logged comes from `Session.view()`:

New game -> Manage -> a real `restock` off the board (asserted against the engine's stock) -> Open up ->
wait for the first customer -> Serve -> pick the wanted SKU through `ItemSlot._gui_input` -> Ring up
(asserted against `tally.sales`) -> answer the story beat on the real DialogueBox, having first checked that
`legal_actions` offers no `serve_active` while it is pending (docs/05 §4) -> Wave off -> let the night run
itself to 06:00 (`night.gd` dispatches `close_night`; the tool only answers beats) -> Summary -> Next day
(asserted: the day advanced) -> Open up -> night 2.

15 steps, a 1920x1080 PNG after each (`shots/play-NN-<step>.png`) and a row per step in
`shots/play-log.json` ({step, name, screen, phase, day, clock, cash, active, pending}).

Two things it taught us immediately:
- **`SceneTreeTimer` runs on SCALED time.** The first run's watchdog was a `create_timer(225)` and fired
  after ~56 real seconds the moment `Engine.time_scale` went to 4. The budget is a wall clock now
  (`Time.get_ticks_msec()`), checked by every wait in the tool.
- **A capture must wait for the screen to stop moving.** With a 6-frame settle, the Summary shot caught
  the tally mid-count and printed "Profit -36,73" and "Rent 47,80" for a night whose real numbers are
  -47,14 and 48,00. A half-animated number in a proof shot is indistinguishable from an arithmetic bug,
  so `_shot()` settles 28 frames; the summary now reconciles on the face of it
  (1,30 + 0,06 - 0,50 - 48,00 = -47,14, cash 420,91 - 48,00 = 372,91).
- Speeding the night up is `Engine.time_scale` and **nothing in the game**: Session still ticks itself,
  arrivals still ride their curve, patience still runs, `night.gd` still closes the books.

No flow bug was left standing: the previous lane's `close_night` / screen-handover wiring held up under a
real run, and the one thing the tool could not do at first — reach a Manage restock button — was a real
finding (the board's runtime rows did not fill the board's width, so every column sat left-packed and the
module description clipped). Fixed.

### 3. The verify-round-3 leftovers

- **Portrait vs. the ServePanel.** `Portrait.place_behind(counter_edge_y, centre_x)` now anchors the bust by
  its **bottom-centre** (shipped art is narrower than its spec box — `you_neutral` is 155 against a 190 spec
  — so a left-anchored bust drifts), and `night.gd` seats it at `PORTRAIT_CENTRE_X_SERVING` (118) while the
  panel is open. Jürgen is fully visible in `shots/f4-pfand.png`; the want bubble stands down while the
  panel names the order in its own header.
- **Rain.** The `Rain` node moved *before* `Counter` in `SceneLayers.tscn` and the streaks are now drawn
  inside `Palette.RAIN_RECT` (372,4 106x200 — the door/window opening) at alpha 0.55 instead of 26 cyan
  hairlines at 0.10 sprayed over the whole frame. Visible in `f6-summary.png` and every night capture.
- **`Assets._stamp_id`** keeps the leaf name and its HEAD: "COFFEE", not "FFEE"; "CIGA", not "TTES".
- **Manage restock list** sized to whole rows (above).
- **Speaker names** already came from the registry ("'Bottle' Jürgen"); verified live in `f4-pfand.png`.
- **`project.godot`** gained `rendering/2d/snap/snap_2d_transforms_to_pixel=true`, which docs/01 always
  claimed was on.
- **Raw colours are gone from the pool as well as the screens.** `SceneLayers` (DUSK/DEEP/DAWN -> `TINT_*`,
  the neon bloom, the rain), `Modal` (the dimmer and its hairline), `Meter` (the unlit cell), `ServePanel`
  (the divider), `ManageBoard` (the rule), `Transition`, `WantBubble` — every one is a `Palette` token
  assigned in `_ready()`, and not one `.tscn` in `components/` contains the word `Color(` any more.
- **Busts and the counter** are both bottom-anchored, so the shipped art being smaller than its spec box
  moves nothing.

### 4. Strings, and what the tests now hold

`tests/unit/test_strings.gd` (new, 4 tests) is what `strings.gd` always claimed existed: no `.gd` under
`scenes/` or `components/` may set a label to a literal, the stray German chrome words may not come back,
the format strings must keep their `%s`/`%d` slots, and the composed lines (`hud_line`, `summary_sub`) must
read as sentences. `.tscn` placeholders stay exempt — docs/01 wants the editor tree to show reality, and
`render()` overwrites them. It found three real leftovers: the Summary screen and `SummaryTally` were still
German ("Umsatz/Gewinn/Kasse/Weiter"), and `ItemSlot`/`DialogueBox` were formatting `"x%d"` and `"%d. %s"`
in place. All four now come from the table.

`test_scenes.gd` gained `test_the_pool_list_is_complete`, which reads `components/` off disk and fails if a
`.tscn` is missing from `COMPONENTS` — the hand-written list the last two verify rounds flagged. `Fx.tscn` was
the first thing it caught.

### Not done / for other lanes

- **`MockView` still invents vocabulary the engine cannot produce** — archetypes "Pfandsammler", "Clubber",
  "Studentin" and German SKU names — so the nine capture presets show words a live run never will (the live
  ones read "Broke student", "Kiez regular", "Sterni (beer)"). `test_mock_view_speaks_the_engines_language`
  only checks the two HUD labels, the weekday, the Pfand rate and the tiers. The playthrough captures are
  now the honest reference; someone should either fix the mock against `Content.ARCHETYPES` or retire the
  mock presets in favour of `play-*.png`.
- **13 SKUs had no `Assets.SIZES` entry** until this pass (energy, schrippe, tobacco, papers, tp, condoms,
  batteries, painkillers, currywurst, icecream, milk, eggs, vape); the art lane added the spec rows during
  this lane and the mirror now matches. None of them has a PNG yet, so the shelf shows stamped placeholders
  below the fold.
- `docs/05 §5`'s read-model block still lists the pre-`pfand_rate` key set (17 keys; the code and the tests
  carry 18, plus `tier` on each `restock_options` entry).
- `content/skus.gd` still carries a per-SKU `deposit` that nothing reads.
- The `Serve` toggle sits under the serve panel when the panel is open — harmless (it is behind it), but it
  should probably become a close affordance.
- A neglected night piles up a long queue ("18 waiting" in `play-11-beat-choice.png`) and Kiez-Trust drops
  fast; that is the balance lane's read, not a bug, but the number is worth a look.

## 2026-09-12 late — session restart + the real-Späti brief (orchestrator)
- The Claude session restarted; art round 2 (6 lanes) and the review/polish fleet died mid-flight (no completion records). Surviving work: 10 neutral portraits (astra 62–76), SKUs (mate 84, water 83, chips 84, gummi 79, chocolate 74), scene r3 rounds (backdrop 64, counter 59, title 67 under astra). Variant files purged from godot/assets (raws kept).
- **User feedback with six real Späti photos:** the set still read as a wooden tavern. Rewrote `docs/art-style-brief.md` (set section: fluorescent light, white/metal shelving, the cigarette wall, glass fridges, cluttered laminate counter with a white register, graffiti facade, bench — explicit NOT-list: wood panelling, beams, pendant lamps, café props) and the concept/backdrop/counter/title prompts. `concept-art/spaeti-references/` is a drop folder auto-attached to scene/concept generations. Next: concept r3 → scene layers with astra against the new brief.

## 2026-09-12 — ENGINE lane: guests, the queue, branching dialogue and the six stats (docs/06)

`node tools/godot/test.mjs` -> **98 run, 0 failed** (was 66 before this lane and the UI lane landed
together), including the 25 new ones in `test_dialogue.gd`.

### What the engine now does

- **`state.player.stats`** — `{str:10, dex:11, con:12, int:13, wis:12, cha:14}` from
  `SpatiState.DEFAULT_STATS`, plus `Rules.modifier(score)` (5e, `floorf` — integer division would turn
  a 9's -1 into 0), `Rules.stat_score/stat_mod/stat_name`, `Rules.STAT_IDS/STAT_NAMES`.
- **Checks** — `Rules.roll_check(n, {stat, dc})` draws one d20 off the state's own `rng_state` and
  threads it back, so **a night still replays exactly from `{config, seed, actions}`, every die
  included**. It logs `kind:"check"` with `data:{stat, roll, mod, dc, success}` — that is the entry the
  d20 pop reads off `Session.event`. A **gate** (`requires:{stat,min}`) rolls nothing: below `min` the
  choice is *shown but locked*, and `talk_choose` on it is an illegal action.
- **`engine/content/dialogues.gd`** — graphs for `lena` (7 nodes, CHA 12 + WIS 12), `juergen` (6 nodes,
  a STR 12 gate on the Pfand crate + WIS 13 to notice he is sleeping in the Hof), `mehmet` (7 nodes,
  INT 13 on the rent letter + CHA 13 to get him knocking on doors), and the generic `oneoff` whose one
  node substitutes `{want}` with the SKU name. Choices wear their own stat tag (`[Charisma 12] …`).
- **`state.talk`** + `talk_next` / `talk_advance` / `talk_choose{choice}`, with `talk_end` internal:
  `next:""` ends the conversation, the guest leaves and **their want is auto-served if it is in stock**,
  so a night of pure talking still moves cash. `serve:false` on a choice is "you turned them away".
- **`view.queue` / `view.talk` / `view.player`** — every guest waiting carries a `portrait` from the
  characters registry (one-offs wear their archetype's bust), FIFO.

### The one structural decision: ONE box, ONE source

Rather than letting `view.dialogue` and `view.talk` describe the counter separately, **a pending beat
or vignette now opens as a one-node talk** (`Talk.KIND_BEAT` / `KIND_VIGNETTE`), and `view.dialogue` is
a literal projection of `view.talk` (same speaker/portrait/expression/lines, choices reduced to
labels). They cannot disagree because there is only one lookup. `resolve_beat` / `resolve_vignette`
survive as **aliases of `talk_choose`** on that talk — which is why the shipped DialogueBox and
`playthrough.gd` kept working while docs/06 landed. The behavioural split of docs/05 §4 is preserved:
ending a **beat** leaves the customer at the counter for the ordinary serve; ending a **graph talk**
dismisses them. New `godot/engine/talk.gd` (`class_name Talk`) owns node resolution and both views.

### Things that only showed up once it ran

- **The AutoPlayer cannot blindly "choose 0" any more** — a gated choice is illegal, and a policy that
  stops on one would hang the night loop (TICK_GUARD 100000 with a never-clearing counter). Two
  belts: `AutoPlayer.play_talk` takes *the first choice that is not locked*, and
  `test_dialogue.gd::test_every_graph_is_playable` fails any node whose **choice 0 is gated**.
- **Conversations must cost no game time.** `play_talk` runs a whole tree inside one tick; if it had
  spent a tick per line, 40+ guests x 4 steps would have dragged the night clock hours past 06:00.
- **`_dialogue_pending` now includes an open talk**, so patience freezes and `serve_active` /
  `skip_active` are refused mid-sentence — the same rule a pending beat always had.
- **The underage/restricted refusal moved into the engine.** `talk_end`'s auto-serve will not sell a
  restricted SKU to a `kid`; without that, every season quietly bled Integrity the moment the
  AutoPlayer started talking to everyone instead of hand-picking the serve.

### The end-to-end run, and the one seam it caught

`node tools/godot/play.mjs` -> **PLAY ok steps=15** (after the fix below). Read at 1080p:
`shots/play-11-beat-choice.png` (the intro beat, its first line, the choice "1 Open up.", the QueueStrip
along the right edge — every word of it out of `view.talk` / `view.queue`), `play-12-beat-resolved.png`
(pending cleared and **the same customer still at the counter**, which is the docs/05 §4 rule the
one-node-talk had to preserve) and `play-13-summary.png` (1,30 + 0,06 − 0,50 − 48,00 = **−47,14**, cash
420,91 − 48,00 = **372,91** — identical to the pre-docs/06 baseline, so nothing moved in the money path).

- **Fixed in `godot/tools/playthrough.gd` (outside this lane, flagged):** the run died at step 11 with
  "the beat offered 0 choices, not 1" *while the choice was plainly on screen*. `dialogue_box.gd` now
  wraps each choice in a row (`Choice1`, `Choice2`, …) so the stat tag can sit beside the button as a
  sibling, but `_choice_buttons()` collected only **direct** `Button` children of `%Choices` and found
  none. It walks the rows now. A harness that reports "no choices" for a rendered choice is worse than
  a red test, so it did not seem right to leave it for the next lane.

### Still open for the UI lane

**`night.gd` gates "Next guest" on `active.is_empty() and talk.is_empty()`** (line ~271), on the premise
that "`talk_next` is legal only with a clear counter". It is not: the reducer pulls the head of the
queue up on `tick` by itself, so `active` is almost never empty on a busy night and the affordance stays
disabled — which is why `play-12` reads "21 waiting". The engine offers `talk_next` whenever there is
*anybody* to take (queued **or** already standing at the counter) and no talk is open, so the gate
should be `talk.is_empty()` alone.

`docs/05-engine-api.md` gained **§8** (the docs/06 delta: state, actions, read-model, checks, the
one-box rule) — the old §8 test list is now §9 — plus `talk.gd`/`dialogues.gd` in §1, the three actions
in §3 and `queue`/`talk`/`player` in the §5 read-model.

## 2026-09-12 — art round 3: char/lena_neutral, char/juergen_neutral, char/mehmet_neutral, char/oneoff_clubber_neutral, char/oneoff_tourist_neutral (art operator)

Five neutral NPC busts, judged by astra as NPCs against their own briefs (the protagonist image is the
rendering bar only), at ×5 nearest upscale, threshold 80. **One pass, four at 77–79** — every one of them
is up 4–21 points, and the blocking axis is the same on all four: `pixel_rendering`.

- **char/juergen_neutral — 3 rounds, 84 PASS** (composition 91, palette 86, **pixel 87**, fidelity 81; was 63).
  His prompt was the only one of the five with no TRUE-PIXEL-ART clause and no background clause — that alone
  explained the 39 pixel score and the green fringe. Remaining: the neutral still leans weary rather than guarded;
  the bottle bag reads as silver-blue cords more than sheet plastic.
- **char/mehmet_neutral — 3 rounds, 79** (composition 93, fidelity 89, pixel 78, palette 73; was 64). Best of the
  near-misses on identity. Remaining: skin still reads a touch salmon; facial transitions still fragment.
- **char/lena_neutral — 3 rounds, 79** (composition 92, palette 85, fidelity 88, pixel 73; was 74). The Mate bottle
  finally reads as translucent amber glass. Remaining: intermediate shades soften contours; the denim seam
  highlights are too long and bright and compete with the face.
- **char/oneoff_clubber_neutral — 3 rounds, 78** (composition 92, palette 85, fidelity 83, pixel 74; was 72).
  Remaining: the face keeps drifting back to manga (elongated glossy eyes, modelled lips) and a cream/magenta
  halo survives around the silhouette.
- **char/oneoff_tourist_neutral — 3 rounds, 78** (r3 kept; r4 was 77 — it fixed the age and the wet hair but lost
  palette 80→74 and pixel 76→69). Remaining: mottled shading, a diffuse grey/yellow halo.

**The finding that moved everything: `--filter nearest` is right for busts too, not just small props.**
Re-snapping the *existing* raws with nearest instead of lanczos, with zero Codex calls, moved
lena 74→77, juergen **63→75** (pixel 39→72), mehmet 64→79, clubber 72→74, tourist 74→78. Lanczos at a 5–6×
downscale invents the exact intermediate tones every verdict complains about. All five spec entries now carry
`"filter": "nearest"`; the art-pipeline doc's "keep lanczos for busts and scene layers" line is wrong and should
be flipped to "nearest by default, lanczos only if a raw is genuinely painterly and the nearest snap aliases".

**Palette quantisation is a wash, confirmed on a bust.** clubber r3 snapped to 31 colours (`--quantize 32
--despeckle 1`) scored **76 — exactly the same as the un-quantised 76**: pixel_rendering 68→74, palette_lighting
85→75. Fewer colours do not reorganise painted texture into authored clusters, they just posterise. Standard chain
stays snap-only (this is now the second independent measurement, after the concept ladder).

**Two transparency traps, both costing a round:**
- `char/mehmet_neutral` r4 came back with a painted grey-and-white **checkerboard** background. The wrapper's 2%
  transparency check *passed* (the border flood-fill removed 1.0M pixels) but the white checker squares connected
  through his white paper hat and pale skin and **erased half his face** — a plausible-looking 170×230 sprite that
  is silently ruined. Check `opaque` pixel count against the previous round, not just `transparentFrac`. Fixed by
  hoisting the background demand to the FIRST paragraph of the prompt (r5 came back with a flat key colour).
- After keying, `juergen` r1 and `mehmet` r5 kept 35–43 **bright green fringe pixels** the judge saw and named.
  `--key-tol 0.45` removed all of them on mehmet at a cost of 61 opaque pixels; the entry now carries
  `"keyTol": 0.45`. Worth a fringe count on every keyed portrait before promoting it.

**Judge-context note:** the pipeline trims sprites tight, so every bust touches its canvas edges by construction.
Without a context line saying so, the judge deducts for "no headroom / sleeves cut by the sides" on every portrait
(it cost mehmet 10 composition points). The NPC portrait context now states the trim, the bottom crop, and that the
protagonist reference is the *rendering* bar only and not an identity to match.

**Spec changes (my five entries only, ids/sizes/kind untouched):** all five prompts rebuilt around one shared,
proven RENDERING / LIGHT / FRAMING / BACKGROUND block (the clause set that produced juergen's 87) plus a per-character
identity paragraph, an explicit five-tone anti-orange skin ramp, and a hard **palette budget** ("at most 28 colours,
each covering a large connected area"); `"filter": "nearest"` on all five; `"keyTol": 0.45` and `"bgTol": 0.10` on
mehmet. `char/you_neutral` and the rest of the cast were not touched.

**Honest gap:** four of five are 1–3 points short and it is all cluster discipline. Two more generation rounds did
+1 to +4 each, so a third is unlikely to clear it by prompt alone — the remaining lever is either a targeted
cluster redraw of the face region or accepting 77–79 for one-off NPCs and spending the rounds on the hero screens.

## 2026-09-12 — REGISTER lane: the queue, the six stats, the checks on screen (docs/06 §5)

`node tools/godot/test.mjs` → **99 run, 0 failed** (66 → 99: the engine lane's `test_dialogue.gd` and eight new
screen tests). `node tools/godot/play.mjs` → **PLAY ok steps=13 guests=66** — a whole night played as a
conversation loop. `node tools/godot/play.mjs --serve 1` → **PLAY ok steps=16 guests=65**: the old till branch
still rings people up.

### What the night screen is now

The Night scene is the **register**. Three columns that may never trade places, and the rectangles are arithmetic,
not taste — `test_scenes.gd::test_the_register_columns_do_not_overlap` checks every one of them against the two
things that were already nailed down (the SPÄTI neon at x 124–224 / y 20–62, and the bust bottom-centred on
x 250 at up to 190 wide, so x 155–345):

| | where | what |
|---|---|---|
| right | `DICE_RECT` 346,42 132×42 · `QUEUE_RECT` 346,86 132×84 | the d20 pop, then the line: the next guest's name over their busts, "Next guest" underneath. Its bottom **is** `COUNTER_TOP`, so the guests stand at the counter's right end rather than float over it. |
| left | `STATS_RECT` 2,64 136×98 · `SERVE_TOGGLE_RECT` 2,21 62×18 | the six stats (Tab), below the neon and left of the bust; the demoted Serve toggle above them, clear of both HUD plates. |
| centre | `DIALOGUE_RECT`, width 400 / **300** / 188 | the conversation. It gives the right column back (`DIALOGUE_W_QUEUE` 300) whenever a line is on screen, so the choices stop short of the queue; 188 while the serve panel owns the half. |

**Three new components** (docs/04 has the contracts):

- **QueueStrip** — the line, FIFO, head of the line edged and underlined in amber, the rest stepped back,
  `QUEUE_SLOTS` chips then a "+N". Click anywhere on it, or the "Next guest" `PixelButton`, → `talk_next`.
  The chips are **code-drawn silhouettes in the speaker's own colour**, not shrunken portraits: a 190×230 bust
  cannot go in a 28-px slot without scaling it (which kills the pixel grid, docs/01) or cropping it to a nostril.
  The first capture's head-over-a-rectangle read as an abstract logo; one stepped collar row fixed it.
- **StatsStrip** — six rows of name / value / modifier, default hidden behind **Tab** (taken in `_input`, before
  the GUI, so Tab does not also walk the focus ring), forced open in the `queue_waiting` capture. It PRINTS
  `view.player.mods`; re-deriving `floor((v-10)/2)` in the UI would be a second source of truth the first time a
  module grants a bonus.
- **DiceResult** — the pop beside the box: a code-drawn d20 with the raw roll in it, `d20 14 + 2 = 16` over
  `vs 12 — success` in GOOD/BAD. Fed from `view.talk.last_check`, and re-popped by the `check` log event, which
  `Fx` answers at the same anchor with accent ticks tinted by the verdict.

**CheckChoice** lives inside `DialogueBox`: a choice is a **row** now, not a button — the line in a `ChoiceButton`
plus, when it rolls, its tag beside it in `Palette.ACCENT` ("[Charisma 12]"). A label cannot colour half of itself,
and an overlay ran under long choices. A **gate** is shown, greyed and told why on its own line underneath
("locked: needs Strength 12"): "locked: …" + "Strength 12 needed" does not fit across a 300-px counter on one row,
and a clipped explanation is worse than none. A gate is information, so it keeps a readable `disabled` box of its
own — the Theme has no `disabled` style for `ChoiceButton`, so it fell back to the generic one and all but
vanished over Lena's face (capture 2).

### The talk flow

`night.gd` renders `view.talk` through the SAME DialogueBox: one line, the one **the engine** says we are on
(`talk.line`), plus the choices when the node has reached them. Two cursors over one conversation is how a click
ends up a line ahead of the reducer, so the box's own line walk is not used here — a click or Space that runs out
of words dispatches `talk_advance`, a choice dispatches `talk_choose`, and the Portrait follows
`view.talk.expression` rather than the customer's (the guest reacts line by line; `active.expression` only moves
when a choice is finally applied).

Four new capture presets — `queue_waiting` · `talk_lines` · `talk_choice` · `talk_result` — and all nine old ones
still render (re-captured and read at 1080p: `shots/r5-*.png`). The four pre-register night presets keep an
**empty** `queue` on purpose: they are the serve screen's reference shots, and drawing a line into them would
quietly change nine captures.

### What the captures taught us (four rounds, every PNG read at 1080p)

1. `HudPlate` is half-transparent because it sits on the dark top band. Over the fridge and the door it leaves
   16-px text unreadable — the stats sheet, the queue's name and the d20 plate all carry an `INK_DEEP` ground now.
2. The Choices container was 57 px tall and three choices are 68; row 3 sat inside the dialogue box. It is 101 now.
3. The continue ▾ was authored at the 400-px box's corner and floated in the wood at 300. It follows `size.x`, via
   the `resized` signal — the screen resizes the box *after* handing it a line.
4. "Next guest" at the top of the right column covered the want bubble (x 340–426, y 74–120) in
   `customer_at_counter`. It moved to the bottom of the strip; nothing on the right column collides now.
5. The same button was live inside the `dialogue_choice` choice stack: a pending beat that never opened as a
   talk blocks `talk_next` too (docs/05 §4), and its choices are drawn full-width. `can_start` now requires an
   empty `view.dialogue` as well.
6. `Assets.portrait` returned a stamped placeholder for `char/lena_warm` next to the finished `lena_neutral`,
   which reads as a broken character rather than an unfinished expression. docs/05 §6 always said a missing
   expression falls back to `_neutral`; it does now whenever the neutral PNG is real.

### The driver

`tools/godot/playthrough.gd` + `play.mjs` play the register: wait for a guest → "Next guest" (the strip's own
button) → advance the lines → choose (preferring a choice that **rolls**, so the d20 is exercised) → the
conversation ends → the next guest, all night, then 06:00 → Summary → night 2. `_can_talk()` is
`view.has("talk")`, so this lane and the engine lane could land independently: on an engine without the
conversation the driver falls through to the **old till branch** (Serve → pick → Ring up), which `--serve` also
forces on an engine that has it. It asserts what docs/06 §4 promises — no `serve_active` is offered while a
conversation is open — and the log rows now carry `queue` and `talking`.

### Two things the two lanes now both own, and one guard each

- **Stat names.** `Rules.STAT_NAMES` exists because the engine composes a locked choice's `reason`;
  `Strings.STAT_NAMES` exists because the table owns every word the UI writes.
  `test_scenes.gd::test_the_two_stat_tables_agree` fails the moment they disagree.
- **The lock sentence.** The engine writes "Strength 12 needed" into `choice.reason`; the box frames it with
  `Strings.locked()` → "locked: Strength 12 needed", so the word *locked* is still written in exactly one place.
  `MockView`'s gate is shaped like a real one (empty `check`, the engine's wording) and the same test pins it to
  `Talk.choice_views`. **The cleaner fix is the engine's:** if `view.talk.choices[].requires = {stat, min}` rode
  along, `Strings.locked_reason()` would own the whole sentence ("locked: needs Strength 12") and it would be
  translatable. The box already prefers `requires` when it is there.

### Not done / for other lanes

- **The live night never shows a line.** `queue` was 0 at every step of a 66-guest night: the reducer pulls the
  head of the queue to the counter on its own tick (`Rules._take_next`), and arrivals are spread far enough apart
  that nobody ever waits. So the queue strip is, in a real run, the "Next guest" button — the *line* only appears
  in the `queue_waiting` capture. Either arrivals need to bunch up (balance) or `_take_next` should stop
  auto-promoting while the register is idle (engine). Worth a decision before the slice is shown.
- For the same reason the playthrough's `talk-lines` and `talk-check` frames did not fire on night 1 with the
  default seed: the nameless parade's graph is one line with its choices already open, and no regular's graph
  (the ones with checks) came up. The four capture presets are the reference shots for those two moments.
- `char/lena_warm` / `_upset` and the other expressions are still unpainted; the fallback hides it now, which also
  means the art lane's expression work will show up with no code change (and no capture will flag it missing).
- The stats strip is 136 px wide because "Constitution" is 12 characters at the pool's one text size. It fits, but
  it is the widest thing on the left edge; a three-letter ladder (STR/DEX/…) would free 60 px if the left column
  ever needs them.

## 2026-09-12 late — the line, the Späti names, wrapper guards (orchestrator, inline while subagents were throttled)
- **Queue rule:** `Rules._tick` no longer promotes the head of the queue; guests wait for `talk_next` and their patience runs in
  line (`_age_queue`; story guests wait forever). `config.auto_take_next=true` keeps the old behaviour for serve-loop tests/sims
  (test_night, test_story, one rails test use it). AutoPlayer now takes the head itself. 99/99 tests.
- **Stats renamed (display only):** Muscle · Hands · Stamina · Brains · Kiez Sense · Schnauze; ids unchanged; both tables + labels.
- **Wrapper:** nearest snap is the default for busts/props (portrait lane measured +3…+15); >55 %-transparent busts rejected (the
  checkerboard-through-the-whites trap); `fringe` counted and auto-widened key pass. Five untouched portraits re-snapped with nearest.
- **Art:** title r4 **86 pass** (the user's style reference; composition 94 / palette 92 / Berlin 91). Concept r3 (real-Späti set)
  74 with Lanczos — "the set correction succeeds", pixel 52 — promoted as the canonical set reference; nearest re-judge pending.
  Backdrop r5 / counter r5 generating on the corrected brief with the title + concept attached.

- **Verdicts (astra), 23:xx:** current backdrop 65 (pix 43), current counter 68 (pix 51) — set right, shading "blended"; counter r5 (Lanczos) 65; portraits after nearest re-snap: you 73 · brandt 76 · tobias 75 · schulz 74 · nadia 68 (demo cast: lena 79, juergen 84 pass, mehmet 79, clubber 78, tourist 78). Scene entries switched to `filter: nearest`; counter r6 rendered on a flat key (edge-to-edge, no dark glow) — `trim` must stay ON for keyed strips (off → the whole canvas is height-fitted into a thumbnail).
- **Promoted `scene/backdrop` = r5 (astra 74 nearest; composition 85, Berlin 91, pixel 64)** over the previous canonical (65). Nearest snap confirmed on full frames too (concept r3: 74 Lanczos → 77 nearest; counter r5: 65 → 72). Counter r6 (flat key, edge-to-edge) judging; quantise A/B on the backdrop judging; several concurrent astra judges returned no JSON — keep ≤ 4 Codex sessions at once.
- Quantise A/B on the constructed backdrop r5: 48 colours + despeckle = **74, identical** to the plain nearest snap ("posterization, not authored clusters") — experiment closed; snap-only is final.
- `shot.mjs` now ALWAYS re-imports before capturing: a promoted PNG without an import cache loaded as the placeholder (caught on the first captures after the backdrop promotion).
- **Expressions live:** lena_warm/upset, juergen_warm, mehmet_warm generated on-model (neutral raw as identity ref); `talk_result` capture shows Lena switching to warm after a passed check. mehmet_wary rendering. Judges on composed 1080p frames time out at 600 s under 5 concurrent sessions → default 1500 s; run composed judges one at a time.
- **Expression set complete for the demo cast:** lena {neutral,warm,upset}, juergen {neutral,warm}, mehmet {neutral,warm,wary} — every expression the dialogue graphs reference has an on-model astra portrait; the Portrait swaps them per node (proved in `talk_result`).
- **Promoted `scene/counter` = r6** (flat-key render, bottom-anchored cover crop → exactly 480×130, edge to edge; same construction as r5 which scored 72 vs the previous canonical 68). Verdict rerunning solo after a 600 s timeout.
- **HUD:** an 8-px spacer before the night/queue tail (`Hud.tscn` `Gap`) — "[Pfand] 12 Night 3" read as one number-word run at 16 px. Gallery refreshed with the r5 + r6 frames (`docs/gallery/night-*.png`). Three astra judges in flight, one at a time per frame: old-counter hero (baseline), counter r6 alone, the true current hero frame (`final-dialogue_choice`).
- **Autosave wired:** `Session.dispatch` saves after every non-`tick` action (`user://autosave.json`); the title's Continue was live-but-dead before (nothing ever called `save()`). Verified: `play.mjs` leaves a night-2 save with 252 log entries. `Assets.SIZES["scene/counter"]` corrected to 480×130 (the size test caught the spec drift). 99/99.
- **00:09 — two judges timed out at 1500 s** (hero baseline on the old counter; counter r6 alone), both while three astra sessions ran (plus the user's interactive `codex`). On the personal account since 20:24 a verdict has not once come back with ≥ 3 sessions open. Next: lean payload — half-size candidate (`shots/*-x2.png`, lossless: each 4×4 game pixel → 2×2), concept grid at ×2, one Coffee Talk frame instead of three, effort `high` — and strictly one Codex session at a time.
- **00:14 — lean judge works:** `final-dialogue_choice` at ×2 (960×540 lossless), 3 refs, effort high → verdict in **45 s**: **71 revise** (composition 62 · palette 65 · pixel 76 · character 77 · ui 63 · Berlin 84). Top fixes: (1) the dialogue stack eats ~42 % of the frame — shrink/merge choices into the box, show the countertop with Lena's hands; (2) Lena reads as an oversized portrait behind overlays, not a person at the counter (forearms/elbow on the counter); (3) flat grey light — warm face/hand, cyan fridge clusters, magenta door reflections; (4) shelf/counter/till material detail; (5) HUD is a crowded debug strip, request bubble competes; (6) expression specificity; (7) clutter. `judge.mjs` made lean by default (docs/02).
- **00:39 — stalls, not payload:** the same lean judge that returned in 45 s at 00:13 sat for 900 s at 00:24 with nothing after its first reasoning item (rollout: one `reasoning`, no message). Policy now: kill and retry — `judge.mjs` runs up to 3 attempts of 420 s each. Meanwhile the hero frame was reworked on the judge's first two fixes: choices inside the dialogue panel (stack 42 % → ~31 % of the frame, the countertop with Lena's hand/bottle/cup/phone visible), three HUD plates, the request bubble in the panel's language, SPÄTI board clear. 99/99.
- **00:41 — v3 verdict 74** (composition 62→72, ui 63→73, pixel 76→81, Berlin 84→89; palette 65, character 74). Remaining: character grounding, counter visibility, lighting depth. **Round 2 (code-side, 00:50):** every bust re-snapped to **144×174** (the OG framing table's ~145 px; heads were 36 % of the frame, now ~27 %, the bottle hand shows above the counter), dialogue panel ~75 px (3-px padding, flat rows with no vertical padding), HUD plates inset 5/4, Serve toggle shown only when serving is legal (or the panel is open), bubble price in full text colour. 99/99. v4 judging.
- **01:06 — astra stalls are not quota:** the v4 judge stalled three times at 420 s (each rollout: five messages, one reasoning item, then silence); the account's rate-limit snapshot shows 23 % of the weekly window, no secondary limit, no spend control; a text-only astra probe answers in 4 s. So the stall is specific to vision requests at effort `high` with the strict output schema. Probing the same judge at effort `medium`. Meanwhile the Claude review → verify → fix fleet (Opus, three lenses: engine / scenes / docs-vs-code) is running on the tree; the orchestrator commits its result.
- **01:20 — the stall is the strict output schema on astra.** Same lean payload: with `--output-schema` four astra runs stalled (420/420/420/300 s); without it (`--no-schema`, shape given in the prompt) astra answered in 42 s. A single-image no-schema probe: 8 s; sol with the schema: 30 s. `judge.mjs` gained `--no-schema` plus a key normaliser. **Two verdicts on v4 (bust 144×174):** sol 76 (composition 82 · palette 68 · pixel 79 · character 78 · ui 61 · Berlin 91); astra 70 (composition 66 — "Lena looks submerged behind the counter": the smaller bust sinks its shoulders and bottle hand behind the cut; palette 63; ui 62). Both: warm interior light missing (flat cold tint), HUD reads as RPG status bars, panel heavy. Astra also: the porcelain cup + saucer on the counter is café-coded — replace with a takeaway cup (counter regen).
- **01:45 — round 3 (code-side):** the flat time-of-night tint became a SHAPED light (`light_pool.gdshader`: a warm fluorescent pool over the counter and the customer falling off in 4 stepped bands into the cool night at the fridge and the door; six Palette tokens by night phase). Found the real "submerged" cause: the r6 counter strip's top 37 rows are wall, so flush-with-the-bottom put the laminate edge at y 177 and left a 4-px countertop sliver above the choice panel → `Palette.COUNTER_LIFT = 20` raises the layer; the band is now ~24 px, the props ride up, and the bust seats at its natural top (shoulders, forearm, bottle hand above the cut). HUD `set_focus`: during a talk or a story beat only the clock and the night/queue line stay (both judges: "RPG status bars"). Panel alpha 0.88 → 0.82. `judge.mjs`: astra defaults to `--no-schema`. 99/99. v5 judging.
- **01:22 — v5 verdict (astra, no schema, 55 s): 73.** Trajectory on the composed hero frame: 71 → 74 → 70/74 → 73 — code-side changes have plateaued; every remaining fix is art: Lena's pose (elbows/forearms on the laminate, longer locks, head tilt — per the concept), a deeper countertop surface (45–55 game px, props with contact shadows), stronger light zones (warm cream on laminate + upward skin, darker periphery, cyan rim), material clusters on packs/laminate/register, Berlin cues outside (OPEN neon, door stickers, tagged plaster, bench, Pfand crate), takeaway cup instead of the café cup. Also: the Mate card competes during dialogue → hide/collapse it while a conversation is open. Counter r7 (takeaway cup, crate, newspaper, prop weights, laminate edge within the top 20 rows) and Lena r5 (leaning pose framed for the 30-px overlap) generating.
- **01:43 — round 4 (art):** Lena r5 (astra, 293 s): leaning pose, both forearms on the counter line, bottle standing on it, longer locks; counter r7 (389 s): takeaway cup, newspaper, Pfand crate, phone, kitchen roll, till, card reader on one laminate plane, edge in the top 10 rows. v7 (both swapped in, lift still 20) judged **72** — the r7 edge sits 27 px higher so the lift now hid the forearms again (composition 72, character 68, palette 62 "predominantly gray", ui 76 ↑). `COUNTER_LIFT` → 0 for r7; light pool alphas raised (night warm 0.17, edge 0.30); PORTRAIT_TOP_MIN 24 → 14. Lena warm/upset regenerating from the r5 raw so the expression swap keeps the pose.
- **01:55 — v8 verdict 73** (composition 74 ↑ · palette 61 ↓ · pixel 73 · character 71 · ui 73 · Berlin 87). "Make Lena visibly lean on the counter; her arms disappear behind its back edge" — the behind-the-counter layering cannot show forearms ON the laminate. Decision: a LEANING staging — the sprite ends at the forearms' underside (the generator paints only the key colour below the counter line, so `trim` cuts there) and is layered IN FRONT of the counter with the forearm line a few px onto the laminate. Lena r6 generating that way, with warm ivory/amber highlight clusters (the judge: "make the warm pool visible through surface shading rather than a translucent wash"). Also queued (after the fleet releases night.gd): hide the Mate card during a conversation, quieter panel border, HUD inset.
