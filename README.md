# Späti Simulator (working title)

A narrative management sim: you inherit a Berlin Späti from your late Onkel Cem and run it
through four seasons while the Kiez gentrifies around you. Serve the night, price the shelves,
decide who you are to the neighbourhood — and find out what's left of the corner at the end.

**Look:** a Berlin Späti version of *Coffee Talk Tokyo* — HD hand-drawn pixel art at a 960×540
logical canvas. **Feel:** cozy-but-pointed; the numbers are a management sim, the point is the people.

---

## Run it

```bash
cd app
npm install
npm run dev        # http://localhost:5173
```

Other scripts: `npm test` (vitest), `npm run sim` (headless balance sweep),
`npm run build` (tsc --noEmit && vite build), `npm run lint` (tsc --noEmit).

Requires Node 18+. Nothing platform-specific — macOS, Windows and Linux all work.

## State of play

Milestones 1–5 + 2b are built: the game is **playable end-to-end with placeholder art**.
22 vitest tests green, `tsc` clean, `vite build` clean. It sits at the project's test gate —
mechanically sound and verified by a headless balance sweep, but **not yet played by a human for feel**.

The one real gap is **art**: every sprite is procedural placeholder. The rendering framework is
art-ready behind an asset-manifest seam — drop PNGs in and they appear, no code changes.
See [`app/src/assets/ASSET-SPEC.md`](app/src/assets/ASSET-SPEC.md) for exact sizes and prompts.

## The documentation

Read in roughly this order:

| Doc | What it is |
|---|---|
| [`game-design-document.md`](game-design-document.md) | The design bible — pillars, the full management sim, community evolution, the Build & Customize loop, Sunday/Ordnungsamt risk, the illegal dark path |
| [`narrative-design.md`](narrative-design.md) | The story, built on John Truby's *Anatomy of Story* — a 22-step main arc across four seasons, ~14 side strands each a complete 7-step arc, four endings and the "ending tapestry" |
| [`art-direction.md`](art-direction.md) | The locked visual target and the honest asset constraint |
| [`03-mvp-spec.md`](03-mvp-spec.md) | Scope line, rules to implement, content catalog, screens, acceptance criteria |
| [`04-build-plan.md`](04-build-plan.md) | Stack, engine design, milestones, test plan |
| [`BUILD-REPORT.md`](BUILD-REPORT.md) | Living report — what's built, full UI/component/modal map, changelog |
| [`05-playtest-report.md`](05-playtest-report.md) | Round-1 findings, including the two balance bugs found and fixed |
| [`01-candidate-brief.md`](01-candidate-brief.md) | The original concept pitch and scoring |
| [`concept-art/`](concept-art/) | Protagonist, cast and counter studies, plus the *Coffee Talk* references |

## How the code is arranged

```
app/src/
  engine/     PURE, deterministic game rules — no React, no Pixi, no DOM.
              Seeded RNG, night-loop reducer, economy, story flow, finale.
              content/ holds the data: SKUs, customers, upgrades, story, vignettes.
  render/     PixiJS 8 scene (SceneStage.tsx) — layered sprites from the asset manifest.
  ui/         React screens and overlays (night, manage, summary, end, shell).
  state/      Zustand store, autosave, run history.
  sim/        Headless auto-player used for balance sweeps.
  audio/      Fully synthesized Web Audio — no sound files.
```

**The rule that matters:** the engine is framework-agnostic and never imports UI or render code.
UI consumes the engine; never the reverse. Keep it that way.

## `factory-reference/`

This game was built in a larger "factory" repo with shared playbooks. The documents those docs
cite are vendored into [`factory-reference/`](factory-reference/) so this repo stands alone —
they are reference material, not part of the game.
