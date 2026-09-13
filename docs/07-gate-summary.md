# 07 — Gate summary: the guest-interaction vertical slice (2026-09-12, branch `godot-vertical-slice`)

**What this round set out to prove:** a Coffee-Talk-style Späti where guests queue at the register, you take them one
by one, and each conversation is a D&D-style branching tree whose choices roll or gate against six stats — rendered as
HD pixel art that Codex (gpt-6-astra) both generates and judges against the concept art. Built from the ground up in
Godot 4.7.2; every screen is a real `.tscn` you can open in the editor.

## What is built and verified

| Piece | State | Proof |
|---|---|---|
| Pure GDScript engine (rules, economy, story, finale, seeded RNG) | done | `node tools/godot/test.mjs` → **99 tests, 0 failed** |
| Six stats + d20 checks + gates, deterministic per seed | done | `test_dialogue.gd`; a mid-conversation save round-trips byte-identically |
| Dialogue graphs: Lena (7 nodes, 2 checks), Jürgen (6, 1 check + 1 gate), Mehmet (8, 2 checks), generic one-off | done | `engine/content/dialogues.gd`; flag-gated branches; every graph playable |
| **The line:** guests wait at the register until you take them; patience runs in line | done | `tools/godot/play.mjs` → `PLAY ok steps=13, guests=67` |
| Register screen: QueueStrip (FIFO, Next guest), StatsStrip (Tab), DialogueBox with stat tags + locked gates, DiceResult pop | done | `docs/gallery/night-*.png` |
| Expression portraits driving the Portrait per node | done | lena {neutral, warm, upset} · juergen {neutral, warm} · mehmet {neutral, warm, wary} — `night-talk_result.png` shows the swap |
| Component pool (18 components, one Theme, one string table, measured pixel font) | done | `docs/04-component-catalog.md`; tests enforce no raw colours / literals |
| Art pipeline: Codex generates, Codex judges, Godot snaps to the 480×270 grid | done | `docs/00`, `02`; `tools/codex/*.mjs`, `tools/godot/*.mjs` |

## Judge scores (gpt-6-astra, rubric in `docs/judge-rubric.md`; 85 = hero bar, 80 = asset bar)

| Asset / screen | Score | Note |
|---|---|---|
| Title key art (r4) | **86 pass** | the user's chosen style reference |
| Concept painting r3 (real-Späti set) at game density | 77 | set fidelity 86–94; rendering is the gap |
| Backdrop (r5, promoted) | 74 | Berlin 91, composition 85, pixel 64 |
| Counter (r6, edge-to-edge, flat key) | not scored | two judges timed out (600 s, 1500 s) under concurrency; r5, the same construction, scored 72 |
| Jürgen neutral | **84 pass** | |
| Lena / Mehmet neutral | 79 / 79 | one point short, both after 3 rounds |
| One-offs (clubber, tourist) | 78 / 78 | |
| You / Brandt / Tobias / Schulz / Nadia | 73 / 76 / 75 / 74 / 68 | outside the demo path; nearest re-snap only |
| **Hero screen (`dialogue_choice`, composed)** | pending | three 1080p runs timed out (600/1500/1500 s, 3 sessions open); lean solo rerun (half-size lossless, 3 refs, effort high) in flight |

Pattern across every verdict: set, palette and character fidelity score 85–95; **pixel rendering scores 60–79** —
astra paints "softly modelled" shading where the target has authored clusters. Measured levers: nearest-neighbour
snapping (+3…+15), prompt discipline; not palette quantisation (±0) or despeckling (+1).

## Honest gaps

- The hero screens have not yet been judged ≥ 85; the composed frame is the number that matters and is in flight.
- SKU sprites and HUD icons were parked when the slice refocused on conversation (the serve panel still works; 6 SKUs
  have sprites, the rest are placeholders; HUD icons are placeholder discs).
- No audio, no character-creation screen (stats are defaults), only three regulars have trees. Autosave lands on every player action; the title's Continue resumes it.
- Codex concurrency: more than ~4 simultaneous astra sessions makes verdicts queue and time out; the wrappers now
  default to 1500 s for composed frames.

## How to run

Open `godot/` in Godot 4.7.2 → Play. Title → New game → Manage → Open up → guests queue → Next guest → talk (Space/click
advances; choices show `[Schnauze 12]`-style tags; locked gates are greyed) → dawn → Summary → Next day. `Tab` shows the
stats strip. Headless: `node tools/godot/test.mjs`. Windowed (Godot cannot render headless, so it needs a
desktop session): `node tools/godot/play.mjs` → `shots/play-NN-<step>.png` + `shots/play-log.json`.
