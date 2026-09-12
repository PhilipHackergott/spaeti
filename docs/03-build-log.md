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
