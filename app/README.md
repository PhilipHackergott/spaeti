# Späti Simulator — app

2D HD hand-drawn pixel art (Berlin Späti × *Coffee Talk Tokyo*). React + TypeScript + PixiJS + Zustand +
Vite, pure `engine/` + thin UI/render. See `../game-design-document.md`, `../narrative-design.md`,
`../art-direction.md`, `../03-mvp-spec.md`, `../04-build-plan.md`.

## Run
```bash
npm install
npm test        # vitest — engine + sim (the M1 deliverable)
npm run sim     # the balance sweep (tests/sim)
npm run dev     # the PLAYABLE game (placeholder art; pick difficulty → manage → night → summary)
npm run build   # tsc --noEmit && vite build
```

## Status — Milestones 1–3 done (playable, placeholder art). 16 tests green; tsc + vite build clean.
- **M3 (narrative — Truby):** `engine/content/story.ts` + `storyflow.ts` + `finale.ts` — a strand/beat
  system: the **main arc** (priority strand gated by day milestones: Cem's keys → Brandt's offer →
  the squeeze → the sell-or-stand climax) + **branching side strands** (Lena, "Bottle" Jürgen, Mehmet)
  each reaching a **local outcome**, and the **ending tapestry** (`resolveFinale` = the main ending + a
  per-met-character epilogue, recoloured by the main ending). Morning beats show as a Coffee-Talk
  **dialogue overlay** (`ui/BeatOverlay.tsx`); the End screen renders the tapestry. (More of the ~14-strand
  cast + one-off vignettes fill in on the same spine.)

- **M2 (playable UI):** Zustand store + React screens — a main menu, the **Manage** screen (prices, stock/
  restock, the **Build & Customize** shop = modules + décor with gradual gating), the **Night** (real-time
  pausable tick driver; serve the active customer; Pfand), the nightly **Summary**, and an **End** screen.
  `src/render/SceneStage.tsx` is the isolated scene placeholder — it becomes the Coffee-Talk Pixi scene
  when assets land (a clean swap, not a migration). Art-independent: runs today with labelled placeholders.

## Status — Milestone 1 (engine + content spine + tests).
- `src/engine/` — **pure, deterministic, seeded** sim: the night loop (open → spawn customers on a
  time-of-night curve → serve → Pfand → close → nightly P&L → advance day), pricing/elasticity, reputation
  (Kiez-Trust / Profit / Integrity), the Sunday/Ordnungsamt fine gamble, content registries
  (`content/`: SKUs, customer archetypes, upgrade modules). Reconstructable from `{config, seed, action-log}`.
- `src/sim/autoPlayer.ts` — headless competent-shopkeeper policy (drives tests + balance).
- `tests/` — deterministic full-night + full-season sims, P&L bookkeeping, pricing tiers, Pfand, determinism.

## Art workflow (pixel art is generated externally — Gemini)
The look (HD hand-drawn pixel art, Coffee Talk Tokyo style) is **authored art**, not code. Generate PNGs to
**`src/assets/ASSET-SPEC.md`** and drop them in **`public/assets/...`** using the ids in
`src/assets/manifest.ts`. The render layer (M2) shows a labelled placeholder until each file exists, so the
build runs with zero art today.

## Next milestones (see `../04-build-plan.md`)
M2 art-direction + the Coffee-Talk counter scene (Pixi, HD logical canvas) with placeholder→Gemini assets ·
M3 interactive night · M4 content + community evolution · M5 sound + shell + the ending tapestry · M6 balance.
