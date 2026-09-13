# 07 — Gate summary: the guest-interaction vertical slice (2026-09-13, branch `godot-vertical-slice`)

*Updated 2026-09-13 (late): the register, the tobacco wall and the eleven-guest cast landed — docs/08 + docs/09.*

**What this round set out to prove:** a Coffee-Talk-style Späti where guests queue at the register, you take them one
by one, and each conversation is a D&D-style branching tree whose choices roll or gate against six stats — rendered as
HD pixel art that Codex (gpt-6-astra) both generates and judges against the concept art. Built from the ground up in
Godot 4.7.2; every screen is a real `.tscn` you can open in the editor.

## What is built and verified

| Piece | State | Proof |
|---|---|---|
| Pure GDScript engine (rules, economy, story, finale, seeded RNG) | done | `node tools/godot/test.mjs` → **205 tests, 0 failed** |
| Six stats (Muscle · Hands · Stamina · Brains · Kiez Sense · Schnauze) + d20 checks + gates, deterministic per seed | done | `test_dialogue.gd`; a mid-conversation save round-trips byte-identically |
| Dialogue graphs: Lena (7 nodes, 2 checks), Jürgen (6, 1 check + 1 gate), Mehmet (8, 2 checks), generic one-off, minor/restricted refusal | done | `engine/content/dialogues.gd`; flag-gated branches; every graph playable; unread flags now surface on the Manage board |
| **The line:** guests wait at the register until you take them; patience runs in line | done | `tools/godot/play.mjs` → `PLAY ok steps=20 guests=65`; autosave on every action (Title → Continue) |
| Register screen: QueueStrip (Talk to them / Next guest), StatsStrip (Tab), DialogueBox with the choices inside the panel, stat tags + locked gates, DiceResult pop | done | `docs/gallery/night-*.png` |
| Expression portraits driving the Portrait per node | done | lena {neutral, warm, upset} · juergen {neutral, warm} · mehmet {neutral, warm, wary} — `night-talk_result.png` shows the swap |
| **Leaning staging:** a bust whose sprite ends at the forearms sits in front of the counter with the forearms on the laminate | done (all three regulars) | `Assets.STAGING`, `SceneLayers` slot `Leaners`, `Portrait.place_on`; Lena ×3, Jürgen ×2, Mehmet ×3 regenerated with the key colour below the counter line |
| **The register: scan → ring** (docs/08). Her basket lands on the laminate as OBJECTS; click or drag each onto the glass; lines, quantity steppers, Pfand row, TOTAL; one free correction on a bad ring-up | done | `test_register.gd` (34 tests); `play.mjs` captures `register-counter` → `qty-wrong` → `qty-fixed` → `register-ok`, all pointer-driven |
| **The tobacco wall:** turn around (Q / Turn around), take the facing she asked for, come back; 22-brand catalogue, marks drawn from `{mark, colour}` when the art is not there | done | `test_brands.gd` (9), `play-14-wall.png` — three rails, 8 packs / 4 pouches / 6 booklets + 4 filter boxes |
| **Correctness is the reducer's**: `Economy.order_accuracy` scores missing / extra / wrong_brand / wrong_count / refused into one accuracy, and `matches` / `satisfied` are derived in the engine so no screen can lie about them | done | `test_register.gd`, `test_economy.gd` green **unchanged** (the `0.25 + 0.45×accuracy` mapping is exact) |
| **Eleven persona cards + 8 new dialogue trees**, six-expression vocabulary, Truby arcs, the flag economy | done | `test_content.gd` (21), `test_tokens.gd` (6), `test_flags.gd` (5); every guest walkable out of the shop on the top line |
| **The brand is spoken, not listed:** a regular names it ("1x Kranich — cigarettes."), a stranger points at it ("1x the ones with the pearl — cigarettes."), and the chip never leaks the name the engine withheld | done | `test_a_regular_names_the_brand_and_a_stranger_points_at_it`; `{logo.*}` renders as an inline `BrandMark` glyph, not an asset id |
| **The two-way reachability rule:** every action `legal_actions` emits has a visible control, and every control dispatches an action the engine admits is legal | done | `test_every_legal_action_at_a_real_register_has_a_control` (counter + wall, on the REAL read-model); `play.mjs` enforces it per run, pressing rect centres and never node names |
| Component pool (26 components, one Theme, one string table, measured pixel font, stepped light-pool shader) | done | `docs/04-component-catalog.md`; tests enforce no raw colours / literals |
| Art pipeline: Codex generates, Codex judges, Godot snaps to the 480×270 grid | done | `docs/00`, `02`; `tools/codex/*.mjs`, `tools/godot/*.mjs` |
| Review fleet (Opus reviewers → skeptics → one fixer) | done | 30 findings → 24 confirmed → 24 fixed, suite 99 → 108 (docs/03, 02:12) |
| **UI-reachability audit** (five probes drive the REAL game by pointer/keyboard → skeptics → one fixer) | done | 43 findings → 34 confirmed → 34 fixed, suite 109 → 123: an **Ending screen** for phase `end` (was a dead Manage board), the shell connects `request_screen` before the first render, a **pause menu** (Esc: Resume / Back to title / Quit), keyboard can pick dialogue choices (anchor focus, digit keys), Ring up / Wave off disabled at an empty counter, the serve panel releases focus when closed, Continue validates the save, locked modules listed with their unlock reason, a Sonntag toggle for the Sunday system, refused actions never navigate (docs/03, 03:30) |

## Judge scores (gpt-6-astra, rubric in `docs/judge-rubric.md`; 85 = hero bar, 80 = asset bar)

| Asset / screen | Score | Note |
|---|---|---|
| Title key art (r4) | **86 pass** | the user's chosen style reference |
| Concept painting r3 (real-Späti set) at game density | 77 | set fidelity 86–94; rendering is the gap |
| Backdrop r6 (promoted) | 77 | r5 was 74; composition 81, Berlin 87, palette 73, pixel 75 |
| Counter r7 (promoted) | not scored alone | takeaway cup, newspaper, Pfand crate, prop weights; judged inside the composed frame |
| Jürgen neutral | **84 pass** | the behind-the-counter version; the leaning r5 is judged only inside composed frames |
| Lena / Mehmet neutral | 79 / 79 | Lena since regenerated ×3 in the leaning format (composed only) |
| One-offs (clubber, tourist) | 78 / 78 | |
| You / Brandt / Tobias / Schulz / Nadia | 73 / 76 / 75 / 74 / 68 | outside the demo path |
| Register view (composed, real playthrough) | 68 | first round; ui 57 (opaque panels), composition 63, placeholder SKU sprite on the tray |
| Tobacco wall view | 61 | first round; sparse stock, heavy price bars, marks weak at pack scale |
| **Hero screen (`dialogue_choice`, composed)** | **75** (v11) | trajectory 71 → 74 → 70/74 → 73 → 72 → 73 → 70 → 74 → 75 over eleven rounds; v11 = Lena drawn at 160 px leaning, counter edge 8 px lower (composition 77, character 75, Berlin 89, palette 63, ui 71) |

What moved the composed score: the choices inside the panel (+3), the three HUD plates → minimal HUD in conversation,
the leaning staging (character fidelity 63 → 74). What did not: the light-pool overlay (read as "washed-out grey"),
palette quantisation, despeckling. The judge oscillates ±3 between runs and has asked for both a smaller and a
larger Lena; take single-run deltas under 4 as noise.

**The ceiling is rendering, not design.** Across every verdict, set, palette family, Berlin fidelity and UI language
score 85–91; `pixel_rendering` scores 73–81 and `palette_lighting` 61–73 — astra paints "softly modelled" shading and
a grey ambient where the target has authored clusters and a warm pool against the blue night. Every fix the judge still
lists is art: warm highlight clusters on skin and laminate, connected shadow clusters in the face and hair, varied stock
instead of repeated rectangles, contact shadows, wet-pavement reflections. Those need a better pixel-art generator or a
human pass over the raws; another round of prompt discipline is not going to close 11 points.

## Pipeline findings worth keeping (docs/02, docs/03)

- Astra + a strict `--output-schema` stalls on vision requests (four of four); the same request with the JSON shape in
  the prompt answers in ~45 s. `judge.mjs` runs astra without the schema, from a lossless half-size candidate, three
  references, effort `high`, 2–3 attempts × 300–420 s. sol judges in ~30 s and scores 2–6 points higher.
- Busts are 144×174 (the OG framing table's ~145 px); the first build had them at 190 (heads at 36 % of the frame).
- A bust generated with the key colour below the counter line trims to the forearms and can sit in front of the counter.

## Honest gaps

- The hero screen has not been judged ≥ 85 and, per the pattern above, will not be with this generator.
- SKU sprites were parked when the slice refocused on conversation (6 SKUs have sprites, the rest are placeholders);
  HUD icons are real now (sol, 16×16): clock, cash, Pfand, trust, profit.
- The one-off guests (clubber, tourist) and the five non-demo portraits still use the behind-the-counter seat; the
  three regulars lean.
- No audio, no character-creation screen (stats are defaults).
- **All eleven guests have a leaning identity portrait on disk** (art wave 1 done 2026-09-13 morning); expression wave 2 — the 27 expressions the new trees actually use — is generating and lands one array edit per file in `characters.gd` (`test_content.gd` fails any claim without a file).
- **Three one-off silhouettes are still unremapped:** six archetypes point at `char/oneoff_clubber`, and
  `oneoff_lateworker` / `dogwalker` / `kassenkind` are in neither `docs/asset-spec.json` nor `Assets.SIZES` (both
  orchestrator-owned). Order of operations is recorded at `characters.gd:358`.
- **The basket cap truncates four persona cards.** `BASKET_MAX_LINES 4` against five authored rows drops Lena's
  filters, Achim's lighter, Robin's gummi bears and Aylin's water. No token breaks — the rows are ordered so the
  lines a tree speaks about lead — but **row order is load-bearing** until the cap goes to 5, and the OrderCard's
  ≤ 5-chip budget is what it costs.
- **`speech:"colour"`** (docs/08 §2's third tier) is designed and not built: a colour word would have to be
  invented in the reducer from a hex. It degrades to `mark`, and docs/08 §7 already lists it as a planned cut.
- **Per-brand stock and per-brand prices are out of the slice** by decision: one stock number and one price per
  parent SKU. "We're out of Adler, take the Nordstern?" is a named stretch.
- The bottom wall rail quotes the **papers** price for both papers and filters — the cost of docs/08 §4.3's "one
  price per rail" when two SKUs share a shelf. A second rail is the fix if the judge reads it as wrong.
- **`Esc` does not turn you back** from the wall (docs/08 §4.2 asks for it): the shell owns `ui_cancel` for the
  pause frame, and a wall you cannot pause from is worse. `Q` and `Back` both work, in both directions.
- Lena's warm sprite is 9 px taller than neutral, so her head lifts on the expression swap.

## How to run

Open `godot/` in Godot 4.7.2 → Play. Title → New game (or Continue) → Manage (the board scrolls; Open up is pinned in the foot; Esc pauses anywhere in a run) → Open up → guests queue → Talk to them
(Space/click advances; choices show `[Schnauze 12]`-style tags; locked gates are greyed) → dawn → Summary → Next day.
When the conversation ends she stays at the counter with her basket on the laminate: click or drag each item onto
the scanner, press **Turn around** (or `Q`) for anything on the tobacco wall, take the facing her chip shows, come
back, and **Ring up** (or `Enter`). The first wrong ring-up is refused once and she says why. `Tab` shows the stats
strip (it shares the left gutter with her order card). Headless: `node tools/godot/test.mjs`. Windowed (Godot cannot render headless, so it needs
a desktop session): `node tools/godot/play.mjs` → `shots/play-NN-<step>.png` + `shots/play-log.json`.
