# 07 — Gate summary: the guest-interaction vertical slice (2026-09-13, branch `godot-vertical-slice`)

**What this round set out to prove:** a Coffee-Talk-style Späti where guests queue at the register, you take them one
by one, and each conversation is a D&D-style branching tree whose choices roll or gate against six stats — rendered as
HD pixel art that Codex (gpt-6-astra) both generates and judges against the concept art. Built from the ground up in
Godot 4.7.2; every screen is a real `.tscn` you can open in the editor.

## What is built and verified

| Piece | State | Proof |
|---|---|---|
| Pure GDScript engine (rules, economy, story, finale, seeded RNG) | done | `node tools/godot/test.mjs` → **108 tests, 0 failed** |
| Six stats (Muscle · Hands · Stamina · Brains · Kiez Sense · Schnauze) + d20 checks + gates, deterministic per seed | done | `test_dialogue.gd`; a mid-conversation save round-trips byte-identically |
| Dialogue graphs: Lena (7 nodes, 2 checks), Jürgen (6, 1 check + 1 gate), Mehmet (8, 2 checks), generic one-off, minor/restricted refusal | done | `engine/content/dialogues.gd`; flag-gated branches; every graph playable; unread flags now surface on the Manage board |
| **The line:** guests wait at the register until you take them; patience runs in line | done | `tools/godot/play.mjs` → `PLAY ok steps=13, guests=66`; autosave on every action (Title → Continue) |
| Register screen: QueueStrip (Talk to them / Next guest), StatsStrip (Tab), DialogueBox with the choices inside the panel, stat tags + locked gates, DiceResult pop | done | `docs/gallery/night-*.png` |
| Expression portraits driving the Portrait per node | done | lena {neutral, warm, upset} · juergen {neutral, warm} · mehmet {neutral, warm, wary} — `night-talk_result.png` shows the swap |
| **Leaning staging:** a bust whose sprite ends at the forearms sits in front of the counter with the forearms on the laminate | done (Lena, Jürgen) | `Assets.STAGING`, `SceneLayers` slot `Leaners`, `Portrait.place_on`; Mehmet regenerating in the format |
| Component pool (18 components, one Theme, one string table, measured pixel font, stepped light-pool shader) | done | `docs/04-component-catalog.md`; tests enforce no raw colours / literals |
| Art pipeline: Codex generates, Codex judges, Godot snaps to the 480×270 grid | done | `docs/00`, `02`; `tools/codex/*.mjs`, `tools/godot/*.mjs` |
| Review fleet (Opus reviewers → skeptics → one fixer) | done | 30 findings → 24 confirmed → 24 fixed, suite 99 → 108 (docs/03, 02:12) |

## Judge scores (gpt-6-astra, rubric in `docs/judge-rubric.md`; 85 = hero bar, 80 = asset bar)

| Asset / screen | Score | Note |
|---|---|---|
| Title key art (r4) | **86 pass** | the user's chosen style reference |
| Concept painting r3 (real-Späti set) at game density | 77 | set fidelity 86–94; rendering is the gap |
| Backdrop r6 (promoted) | 77 | r5 was 74; composition 81, Berlin 87, palette 73, pixel 75 |
| Counter r7 (promoted) | not scored alone | takeaway cup, newspaper, Pfand crate, prop weights; judged inside the composed frame |
| Jürgen neutral | **84 pass** | behind-the-counter version |
| Lena / Mehmet neutral | 79 / 79 | Lena since regenerated ×3 in the leaning format (composed only) |
| One-offs (clubber, tourist) | 78 / 78 | |
| You / Brandt / Tobias / Schulz / Nadia | 73 / 76 / 75 / 74 / 68 | outside the demo path |
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
- Mehmet still uses the behind-the-counter seat while Lena and Jürgen lean — visible when the queue advances to him;
  his leaning neutral is generating, warm/wary follow.
- No audio, no character-creation screen (stats are defaults), only three regulars have trees.
- Lena's warm sprite is 9 px taller than neutral, so her head lifts on the expression swap.

## How to run

Open `godot/` in Godot 4.7.2 → Play. Title → New game (or Continue) → Manage → Open up → guests queue → Talk to them
(Space/click advances; choices show `[Schnauze 12]`-style tags; locked gates are greyed) → dawn → Summary → Next day.
`Tab` shows the stats strip. Headless: `node tools/godot/test.mjs`. Windowed (Godot cannot render headless, so it needs
a desktop session): `node tools/godot/play.mjs` → `shots/play-NN-<step>.png` + `shots/play-log.json`.
