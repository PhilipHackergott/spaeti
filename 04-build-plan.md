# Build Plan — Späti Simulator (working title)

> Stage 3 (Specification), the *how*. See `factory-reference/docs/03-specification.md` + `factory-reference/docs/stack-and-conventions.md`.
> Pairs with `03-mvp-spec.md` + `game-design-document.md` + `narrative-design.md`. Original concept.

## Stack — `react-ts-pixi` (substrate LOCKED 2026-05-25)
**2D HD hand-drawn pixel art — a Berlin Späti × *Coffee Talk Tokyo*** (the default stack; `art-direction.md`
is authoritative). The 3D-diorama (R3F) avenue is **parked**. The **pure `engine/`, deterministic+seeded,
thin UI/render, Vitest/Playwright** contract holds. Renderer: Pixi at an **HD logical canvas (~960×540,
integer nearest-neighbor)** for crisp pixels + legible dialogue/HUD; layered planes (counter / character /
backdrop) for Coffee-Talk depth. The `render/` layer stays behind a thin interface so `engine/` is render-agnostic.

## Engine design (the heart — pure, deterministic) — `engine/`
This is a **sim**, not an adversarial ruleset; the engine owns all economy + narrative state.
- **State shape:** `SpatiState = { day, weekday, act, clockMs, phase: 'manage'|'night'|'summary'|'beat'|'end',
  cash, pfandFloat, inventory: Record<SkuId,{stock,price}>, upgrades:Set<UpgradeId>,
  kiezTrust, profitStanding, integrity:Set<Flag>,
  community:{ unlocked:Set<SystemId>, bonds:Record<CharId,number>, credit:Record<CharId,number>, board:Request[] },
  risk:{ openSunday:boolean, ordnungsamtHeat:number, darkPath:boolean },
  arcs:Record<ArcId,{ step:0..7, localOutcome?:OutcomeId }>, story:{flags:Set},
  queue: Customer[], active?: Customer, rngState, log[] }`.
- **Action set:** the spec verbs (`grabItem, ringUp, takePayment, givePfand, setPrice, orderStock,
  buyUpgrade, chooseVignetteOption, openNight, closeNight`) + community verbs (`extendCredit, doFavour,
  postcard/fulfilRequest, hostEvent, joinCollectiveAction`) + `setSundayOpen` + `tick(dt)` (advances the
  clock, spawns customers, **rolls the Ordnungsamt check on Sunday nights**, fires beats — all seeded).
- **Community-evolution gating:** an `unlocked:Set<SystemId>` grows as engagement flags trip (side-arc steps
  / Kiez-Trust thresholds / caring choices); each community system is **default-off content** that switches
  on, so the game's *systems* expand with the arc (GDD §4b). `legalActions(state)` only offers unlocked systems.
- **Endings = the tapestry resolver:** `resolveFinale(state)` = `mainEnding(state)` (from
  `{cash,kiezTrust,integrity,flags}`) **+** `Σ over met chars` `epilogue[mainEnding][arc.localOutcome]` —
  a pure function composing the main ending with every met character's branch outcome (narrative §6b).
- **Risk systems (pure, seeded):** Sunday-open raises demand + a Sunday markup but `tick` rolls an
  inspection→fine vs `ordnungsamtHeat` (mitigated by Reisebedarf-only / a Kiez-Trust lookout); the illegal
  "extra menu" (`risk.darkPath`) adds margin + a bust roll + Integrity hits + unlocks dark arc branches.
- **Reducer contract:** `reduce(state, action) -> state` (pure). `tick` is a pure function of
  `(state, dt)` using `rngState` — no wall-clock, no I/O. The render loop calls `tick` with frame dt.
- **Legal-move generation / validation:** `legalActions(state)` (what's serveable/affordable now) for
  the UI to gate buttons and for the headless auto-player.
- **Determinism / seed strategy:** a serializable seeded RNG threaded through `rngState`; a season
  reconstructs from `{config, seed, action-log}`. (Reuse the RNG pattern from `magical-athlete/engine/rng.ts`.)

## Content spine (crawl `factory-reference/knowledge/playbooks/content-depth.md` + `patterns/engine.md`)
*Build the skeleton in M1, fill the catalog in M4.*
- **Content registry (`engine/content/`):** typed data tables — `skus.ts`, `customers.ts` (archetypes +
  demand profiles + spawn curves), `vignettes.ts` (**branching** scene = `{id, arc, trigger, lines,
  options:[{label, effects, nextFlag, branch?}]}`), `arcs.ts` (each recurring char = a **7-step** arc + its
  **branch local outcomes** + an `epilogue[mainEnding][localOutcome]` table — feeds `resolveFinale`),
  `events.ts`, `upgrades.ts` (the ~12+ modules incl. ice-cream/grocery/vapes/illegal/crazy + which
  **community system** each unlocks), `community.ts` (favours/credit, bench/dwell, board requests, events,
  bonds, collective action), the main-arc 22-step graph + ending predicates.
- **Fixed hook points + resolution order:** `onSpawn` (pick archetype) → `onServe` (price/elasticity/
  satisfaction) → `onPfand` → `onBeatCheck` (which vignette/event triggers this tick) → `onCloseNight`
  (P&L + reputation + flags) → `onAdvanceDay` (bills, act transitions, ending check). Each customer/
  vignette stores its state clone-safe.
- **Default-off contract:** an empty registry ⇒ a bare shop with no customers/story (base sim still
  ticks + tests pass). Content is purely additive data.
- **Shared predicates:** one `priceVsFair(sku)`, one `canAfford`, one `meetsEndingCond(state, ending)`,
  one `flagsSatisfied(req, state)` — reused across UI, sim, and endings.

## Render plan (R3F)
- **Scene (`render/`):** `<SpatiScene>` = `Room` (procedural box geometry: floor/walls/ceiling/window
  wall), `Counter`, `FridgeWall` (instanced drink props, emissive glow), `Shelving` (instanced snack/
  essential props), `Register`, `NeonSign` (emissive, breathing), `Doorway` + `StreetBackdrop` (low-poly
  exterior + time-of-night tint + animated headlights), `Customers[]` (the active customer walks
  door→counter→leaves). Camera rig fixed-ish behind the counter (⚑ orbit).
- **Input → engine actions:** **raycast picking** for grabbing products off the shelf/fridge (R3F's
  `onPointerDown` on instanced meshes, resolved to a `skuId`); the till + dialogue are React DOM
  overlays dispatching `ringUp/takePayment/chooseVignetteOption`. Keep the *act of grabbing* in 3D; keep
  *typing/choosing* in DOM. Reduced-motion path: simplify the customer walk + disable headlights/rain.
- **Projection:** render is a pure function of engine state + animation-only local state (tweens for the
  walk, coin pop, tally). No game logic in the scene.

## UI plan (React)
- **Shared shell first:** ONE `<Modal>`/overlay primitive (backdrop, themed panel, Esc/backdrop close,
  focus trap, scroll-lock, reduce-motion) + atoms — `<Ticket>` (order), `<MoneyTag>`, `<RepMeter>`,
  `Button`, `Panel`, `Tooltip`. Then drop screens into it.
- **Component tree:** `App` → `MainMenu` | `Game`(`<Canvas lazy>` + `HUD`) | `ManageScreen`(restock/
  price/upgrades, on the shared shell) | `NightlySummary` (Continue-gated tally) | `BeatScreen`
  (vignette/act/ending) | `PauseMenu` | `SettingsMenu` | `HistoryOverlay`.
- **Zustand store** wires dispatch → engine, holds session/UI state + the typed FX event stream the
  render layer animates from.

## Design / art-direction (crawl `factory-reference/knowledge/playbooks/target-state.md`)
Write `projects/spaeti/art-direction.md` **before screens** (M2): the night-diorama concept; palette as
named tokens synced `:root` ↔ `render/theme.ts`; one display + one body face; the **ONE customer model
recipe** + **ONE product-prop recipe**; HUD ticket/panel/button recipes; the **lighting recipe**
(emissive neon + fridge spill + warm key + exterior time-tint); motion + a11y; a component audit
checklist. (DOM-HUD exemplar: `cull-the-crown/art-style.md`; adapt for a 3D scene + DOM HUD split.)

## Presentation & game-feel (crawl `factory-reference/knowledge/playbooks/visual-first-try.md`)
Bake the look in from M1.
- **fx:** adapt the `fx/` kit (`cull-the-crown/app/src/fx/`) for **DOM-HUD juice** (coin/tally pops,
  meter ticks, ticket slides) + light 3D tweens (customer walk, door spill, sign flicker). No GLSL needed.
- **`render/theme.ts`:** palette + material/light tokens + the time-of-night ramp; **the living exterior
  is the background win** (#1 first-try).
- **Flow:** **no auto-switch** — `closeNight` defers to a Continue-gated `NightlySummary` that animates
  the P&L + reputation deltas; act breaks + endings are authored `BeatScreen`s; **legible fail** animates
  the cause (eviction notice / empty till) then gates. Reuse the gate/transition shape from
  `cull-the-crown/ui/{CombatGate,TransitionLayer}.tsx`.

## Sound (crawl `factory-reference/knowledge/playbooks/audio-and-sound.md`)
Adapt the synthesized engine — copy `cull-the-crown/app/src/audio/chiptune.ts`, **re-voice to warm
lo-fi night ambience** (sparse pads, soft keys) + the SFX kit (door chime, fridge hum bed, register,
coin, **bottle clink**, shelf grab, vignette notify). Music **ducks under dialogue**. Settings mixer
(Music + SFX sliders + mute, persisted); mute double-gates; **engine pinned to `globalThis`** (HMR-safe).

## Shell, settings & persistence (crawl `factory-reference/knowledge/playbooks/front-of-house-shell.md`)
Reuse the shapes from `cull-the-crown/app/src/ui/{App,PauseMenu,SettingsMenu,PastRunsOverlay}.tsx`:
main menu (New/Continue/History/Settings/How-to), **Pause that stops the clock + 3D ticker**, Settings
(mixer + a11y toggles), Rules ("How a Späti works"). **Persistence:** autosave the JSON-serializable
`SpatiState` (per night + on close) in the store → Continue + finished-seasons history; clear on new.

## "AI" / behavior plan (adapted — no opponent)
Two pieces stand in for the AI:
1. **Customer behavior model** — archetype-driven spawn curves + want lists + patience + balk/elasticity
   rolls (all seeded, in the engine). This is the "agent" the player reads.
2. **Headless auto-player** (for balance, not shipped) — a simple competent shopkeeper policy used by
   the sim harness (restock to par, `price = cost × markup`, serve nearest/most-impatient first). The
   "difficulty ladder" = the **Cozy/Normal/Tight** economic config, off one shared economy model.

## Balance & tuning (crawl `factory-reference/knowledge/playbooks/balance-and-tuning.md`)
- **Sim harness:** `tests/sim/` AI-vs-economy sweep, `npm run sim` → a survival/profit table +
  `balance-sim.json`. Method: N ≥ 600 seasons/rung across `{Cozy, Normal, Tight}`; metrics = survival
  rate, end-cash distribution, per-SKU sell-through, arc-reachability.
- **Targets (from the spec):** Normal survivable ≈70% with a modest positive trend; Tight clearly lower;
  Cozy higher; **no degenerate SKU/price**, **no dead content**. First tuning pass in the build (markups,
  fairBands, rent slope, patience, spawn rates) + a one-paragraph balance note; feel issues flag for `/test`.

## Test plan
- **Engine (Vitest):** pricing/elasticity, Pfand settle, P&L correctness, vignette effects + flag
  transitions, ending-predicate selection, and **at least one full-season simulation** (deterministic).
- **Sim (`npm run sim`):** the economy sweep (0 errors / 0 non-terminating seasons) + the rung-ladder
  assertion (Cozy ≥ Normal ≥ Tight survival).
- **E2E (Playwright):** happy path — boot → manage → open → **serve a customer via real pointer**
  (raycast grab → ring → pay) → close → summary; screenshot the **canvas** for the night look + a HUD
  screenshot. A dev seam (`window.__spati`) to set seed/skip to a beat.

## Milestones (each independently demoable — target-state shape)
1. **Engine + content spine + tests** — full sim (clock/spawn/serve/Pfand/P&L), the branching-arc + unlock +
   risk + `resolveFinale` systems headless; registry + hook points; full-season sim green. No UI.
2. **Art-direction + shared shell + the Coffee-Talk counter** — the **2D HD-pixel side-counter** scene
   (Coffee Talk Tokyo re-skin) at the HD logical canvas, with **placeholder pixel portraits/props via the
   asset-manifest seam** (finals commissioned/AI-pixel later); the dialogue box; `<Modal>` + atoms +
   `render/theme.ts`; layered planes + subtle life (neon/rain/steam).
3. **Interactive night loop** — serve (grab→ring→pay→Pfand) via real pointer; clock; nightly-summary gate;
   one regular's **branching** arc end-to-end; the **Sunday/Ordnungsamt** toggle+risk.
4. **Content catalog + community evolution + economic ladder** — fill all SKUs / the ~12+ upgrade modules /
   ~14 branching strands (+ epilogues) / one-offs / events / the 22-step main arc & endings; wire the
   **community-systems unlock chain** (favours/credit, bench, board, events, bonds, collective action) +
   the **illegal dark path**; Cozy/Normal/Tight off the shared economy model.
5. **Feel + sound + shell + the ending tapestry** — juice + outcome beats; the **finale montage**
   (`resolveFinale`: main ending + every met char's epilogue); audio engine (warm lo-fi + SFX + mixer +
   mute); front-of-house shell + autosave/continue/history; run the visual-first-try checklist.
6. **Balance harness + first tuning pass** — `npm run sim`; survival targets; ensure every strand+branch +
   each community system + the Sunday/dark-path are reachable & non-degenerate; balance note.
7. **Acceptance pass** — all acceptance criteria + visual-first-try checklist + `target-state.md` self-check.

## Risks / unknowns
- **Substrate undecided** → M2 spikes BOTH avenues behind the `render/` interface and picks one; keep
  `engine/` render-agnostic so the choice never blocks logic.
- **Narrative volume is the cost center** → build the vignette/arc registry + a writing style guide first;
  the ~14 branching strands + per-ending epilogues + one-off pool ARE the deliverable, not a garnish.
- **Mechanics-as-theme pacing** → the community-systems must unlock at a rate that *feels* like growing into
  the Kiez (not a dump) — a `/test` tuning knob.
- **"Cozy but not boring" pace** → the gentle real-time clock is a `/test` knob; keep it pausable.
- **(Avenue A only) Three.js bundle weight** → lazy-load the canvas; mid-laptop + mobile sanity check.

## Targets & wrapping
Web first (`targets: web, desktop, mobile`). Tauri/Capacitor wraps deferred until the web MVP passes its
gate. Mobile: confirm the raycast-grab interaction works by touch + the canvas perf holds (Draco/LOD only
if needed) — a `/test` item, not an MVP blocker.
