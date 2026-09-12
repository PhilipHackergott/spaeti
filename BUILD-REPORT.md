# Späti Simulator — Build Report (living)

> A running account of **what's built, what's in the game now, and what's left.** Updated as the MVP grows.
> Source of truth for *state* is `project-state.json`; this is the human-readable companion.

| | |
|---|---|
| **Stage** | build → test (playtest round 1 done) |
| **Build version** | M5 "finished-feeling" + M2b (Pixi scene) + balance pass + content-depth |
| **Last updated** | 2026-05-26 |
| **Verification** | ✅ `tsc --noEmit` clean · ✅ **22/22 vitest green** · ✅ `vite build` OK (Pixi bundles) |
| **Substrate** | 2D HD-pixel (Coffee Talk Tokyo look). The scene is a **real PixiJS 8** layer; visuals are procedural placeholders behind an **asset-manifest seam** — Gemini PNGs swap in with no code change. |
| **Art dependency** | None blocking. Fully playable on placeholders; drop PNGs into `app/public/assets/` (see `ASSET-SPEC.md`) and they replace placeholders live. |

---

## How it's put together

Pure split per the factory rules (`docs/stack-and-conventions.md`):

```
engine/   pure, deterministic, framework-free — the whole sim
  ↑ consumes
ui/       React + Zustand DOM HUD / menus / modals / dialogue
render/   the ONE Pixi swap-point — a real PixiJS 8 scene (art-ready)
state/    Zustand store: dispatch → engine.reduce → save
audio/    synth Web Audio (no files); UI-only
```

**Render split (recorded decision):** the **scene** (behind-the-counter view) is PixiJS; **everything else** (HUD, menus, modals, dialogue) stays DOM. So art lands as a clean swap, *not* a UI migration — `render/SceneStage.tsx` is the single isolated swap-point.

A whole season is reconstructable from `{ config, seed, action-log }`. RNG is seeded mulberry32; the
reducer is `structuredClone`-pure. The headless `sim/autoPlayer` plays full seasons for balance/determinism tests.

---

## What's in the game now (component inventory)

### Core management loop ✅
- **Phases:** `manage → night → summary → end`, one **28-day season**.
- **Manage:** set per-SKU prices, restock (+5 / +20), **Build & Customize**, toggle Sunday opening.
- **Night:** real-time tick driver (pause + 1–8× speed), customers arrive on a **time-of-night curve**, serve the one at the counter what they want, take **Pfand** (deposit), watch queue/clock/cash. Balking on impatience.
- **Summary:** nightly P&L (revenue, tips, COGS, rent/fines, Pfand paid, profit, cash).
- **End:** the ending tapestry (below).

### Economy ✅
- **23 SKUs** across drinks / snacks / tobacco / essentials / hot, each with cost, fair band, demand, perishability, age-restriction, Pfand deposit, and module-gating.
- **Price elasticity tiers** (steal / fair / high / gouge) → satisfaction, tips, Kiez-Trust deltas, balk chance.
- **8 customer archetypes** with weighted wants, patience, budget, price tolerance, tip behaviour, and per-third arrival curves (incl. an underage archetype for the restricted-sale ethics beat).
- **Pfand**: payout on take-back, credit applied against restock orders.
- **Reputation triple:** Kiez-Trust · Profit · Integrity (drives traffic, story gating, and the ending).
- **Difficulty as financial pressure:** Cozy / Normal / Tight = start-cash + rent (not traffic). Sim-verified ladder.

### Build & Customize (ongoing pillar) ✅
- **26 modules + décor**, unlocking **gradually** (gated by day / Kiez-Trust / prerequisite), several **tiered** (Fridge I→II, Signage I→II, Coffee→Espresso bar).
- Functional **modules** (capacity, traffic, hot drinks, ice-cream, grocery, vapes, security cam, Pfandautomat…) and a parallel **décor** track (posters, plants, fairy lights, rug, jukebox, outdoor seating, Berlin mural).
- **Community systems** that switch the corner from a till to a *place*: foodsharing fridge, the bench (dwell), open-mic events.
- **Illegal "extra menu" dark path** (below).

### Narrative — Truby ✅
- **Main arc** (priority, day-gated strand): inherit late Onkel Cem's Späti → the Lindner Group's offer → the squeeze → the **sell-or-stand** climax.
- **12 cast side-strands**, each a branching arc → a **local outcome**:
  - **Lena** (artist) → found_voice / sold_out_art · **"Bottle" Jürgen** (Pfand collector) → seen / vanished · **Mehmet** (döner neighbour, ally) → reconciled / estranged
  - **Yusuf** (latchkey teen) → mentored / adrift · **Frau Schmidt** (widow) → watched_over / forgotten
  - **Aylin & Jonas** (techno couple) → together / drifted · **Karim** (new arrival) → belongs / isolated · **Achim** (old punk) → elder_agitator / fossil *(new)*
  - **Tobias** (transplant, fake-ally) → threw_in / moved_on · **Nadia** (night nurse) → held / burned_out · **Robin** (queer youth) → chosen_family / fled · **Frau Schulz** (GDR Oma) → living_history / forgotten *(new)*
- **Morning beats**: ≤1 strand beat/day, priority-ordered (core cast outranks the texture strands), gated by day / Kiez-Trust / flag; shown in a Coffee-Talk **dialogue overlay** that blocks until you choose. With the full cast you meet someone most mornings; lighter runs leave room for vignettes.
- **Ending tapestry** (`resolveFinale`): one of four endings — **Institution / Held the Line / Sold Out / Pushed Out** — woven with a *"where are they now"* epilogue for **every character you met**, each line recoloured by the ending you reached (4 × outcome matrices per strand).

### One-off vignettes (the parade of strangers) ✅
- **21 self-contained city scenes** (lost tourist, club kids, Pfand kid, match night, last-call drunk, beat cop, someone in the cold, busker, exam-week student, drunk philosopher, 5am proposal, lost wedding guest, film-crew location scout, the pigeon situation, power-cut sing-along, "realness" influencer, two-Berlins Wendekind, …).
- Fire on **quiet mornings** when no cast beat is due (so the cast is never crowded out), chosen **deterministically** from seed+day, **never repeat**, and gated by day / Kiez-Trust / weekday / flag.
- Small consequences (cash / Kiez / Profit / Integrity / flags); some set visible flags (gig flyers, live music) that show on the corner status.
- Reuse the same dialogue overlay; auto-dismissed if a day advances unanswered (never lingers onto the finale).

### Render — Pixi scene (M2b framework) ✅ *(new)*
- The behind-the-counter view is a **real PixiJS 8 scene** at the HD logical canvas (960×540, nearest-neighbour), built from **layered sprites loaded via the asset manifest**, with **procedurally-drawn placeholder layers** (night window + warm street windows, stocked fridge/shelves, neon "SPÄTI", wood counter, a per-archetype customer silhouette + want bubble) for any PNG not yet generated.
- A `HEAD`-probe loader shows the real PNG the instant it exists in `public/assets/`; otherwise the placeholder. **Zero code change to swap in art.** HMR-safe (app destroyed/recreated cleanly).
- **Dialogue portraits**: the beat/vignette overlay shows the cast PNG when present (manifest `portraitFor` resolver) and a **procedural initials avatar** otherwise — so named cast read distinctly and one-off strangers still have a face.

### Risk & legibility ✅ *(new — tuned this round)*
- **Sunday / Ordnungsamt gamble**: opening Sundays spikes demand but raises **heat**; an inspection can fine you. Heat shown in the top bar. *(sim: ~+11% trade, occasional fine — a mild +EV gamble.)*
- **Illegal dark path** (`extra menu`): genuinely **more money** (+45% in the sweep) bought with a **nightly Integrity bleed** + a **rare-but-brutal police raid** (8%/night, 4% with the security cam) → crashes Integrity and locks in **Sold Out**. A real temptation, not a trap.
- **Underage / restricted sales surfaced**: the Night UI flags `🔞 underage · ID?` and a ⚠ on the Sell button, so the player can make the Integrity call the engine has always tracked. *(This fixed a balance bug — see the playtest report.)*
- **"Your corner" status panel** (Manage): expected traffic, passive Kiez/night, active community systems, flavour flags, Ordnungsamt heat, dark-path warning — the community-evolution pillar at a glance.

### Front-of-house shell ✅ *(new)*
- **Title menu** with difficulty pick (+ one-line note), **Continue** (if a save exists), and a **Past seasons** history list.
- **Pause menu** (Esc or ☰): Resume / Settings / How-to / Save & quit / Abandon. Pausing (or any overlay/beat) **freezes the night clock**.
- **Settings**: Music & SFX sliders, mute, reduce-motion — all persisted.
- **How a Späti works** rules panel.

### Sound ✅ *(new)*
- Fully **synthesized** Web Audio (no audio files, IP-clean): a gentle lo-fi night-ambience loop + an SFX kit (coin, register, Pfand clink, door, click, beat, error).
- Music/SFX **mixer + mute**, persisted; **gesture-gated** (starts on first click); HMR-safe singleton.

### Persistence ✅ *(new)*
- **Autosave** after every meaningful action (throttled — not every animation frame); **Continue** restores mid-season; the save is cleared at season end.
- **Finished-runs history** (last 20): date, difficulty, day, cash, Kiez, ending.

### Tests ✅ — 22 green
`engine/night` (P&L bookkeeping) · `engine/economy` (tiers / Pfand) · `engine/build` (gradual-unlock gating) ·
`engine/determinism` (byte-identical season per seed) · `engine/story` (arc + branches + tapestry + **vignettes fire/resolve-once/never-block**) · `sim/season` (difficulty ladder Cozy>Normal>Tight, Normal survivable) · **`sim/balance`** (dark path = more cash + crashed Integrity → Sold Out; security cuts raids; Sunday = more trade).

---

## What's left

### Build (this stage)
- **Real art drop** *(art-gated, not code-gated)*: generate the scene layers (`scene/backdrop|shelves|counter`) + cast portraits (`char/<id>_neutral`) with Gemini, drop into `app/public/assets/` per `ASSET-SPEC.md` — they replace the placeholders live.
- **Optional content depth**: remaining cast strands toward the designed ~14; widen the vignette bank; more events/upgrades. *(Scheduled as an autonomous 2am pass.)*
- **Perf**: the sim suite is ~62s (structuredClone per tick over full seasons) — consider a lighter headless tick path.
- **Polish from the playtest**: Kiez-Trust saturates at 100 with fair play (consider soft cap/decay); Sunday is mildly +EV (watch for auto-pick).

### Later stages
- **Human play-through** — the one thing automation can't judge (feel/pacing), best done once art lands.
- **Optional backfill** — `02-market-analysis.md` (deferred at the analysis gate).
- **Ship** — desktop/mobile wrap.

---

## Changelog
- **2026-05-26 · Content-depth pass:** **+7 cast strands** (Aylin & Jonas, Karim, Achim, Tobias, Nadia, Robin, Frau Schulz — toward the designed ~14; now 12 side + main, each a full branching arc with a 4-ending epilogue matrix); **+8 vignettes** (now 21); **+4 build modules/décor** (community noticeboard, Mate-on-tap, photo booth, vinyl corner — now 26); portrait ids + speaker map for the new cast. Tapestry test made robust to a packed cast; vignette test isolates the quiet-morning channel. Still 22 tests, all green.
- **2026-05-25 · M2b scene + balance + test round 1:** rebuilt `SceneStage` as a **real PixiJS 8** scene (manifest-loaded layers + procedural placeholders, HD nearest-neighbour, art-ready swap); **dialogue portrait slots** (PNG-or-avatar). **Balance pass**: found & fixed two bugs — Integrity always hit 0 (→ every ending was Sold Out) because underage restricted sales weren't surfaced (now in `legalView` + the Night UI), and the dark path was a pure trap (retuned to *more money, worse soul*). Added `sim/balance` tests. Wrote `05-playtest-report.md`. 18→22 tests; tsc/build/tests green.
- **2026-05-25 · M5 "finished-feeling":** sound (synth engine + mixer), persistence (autosave / Continue / history), front-of-house shell (menu / pause / settings / rules / Esc), **one-off vignette system + 13-scene pool**, **illegal dark-path consequence** (Integrity bleed + raid risk), **Sunday/Ordnungsamt heat surfaced**, **"Your corner" community-status panel**, **2 new cast strands** (Yusuf, Frau Schmidt) with full ending tapestry. 16→18 tests. tsc/build/tests all green.
- **2026-05-25 · M3 narrative:** Truby main arc + 3 side strands + ending tapestry; Coffee-Talk dialogue overlay; tapestry end screen.
- **2026-05-25 · M2 + Build&Customize:** playable UI (menu / Manage / Night / Summary / End); gradual-unlock module/décor shop.
- **2026-05-25 · M1 foundation:** pure deterministic engine + content registries + economy + autoPlayer sim + asset-manifest seam.

---

## UI elements, components & modals (full map)

**Top-level:** `App.tsx` routes between the **Title menu** and the in-game view, owns the Esc-to-pause handler, and renders the persistent `TopBar` + the current phase screen + the two overlay layers (`BeatOverlay`, `Overlays`).

### Full screens (phase-routed)
| Screen | File | What's on it |
|---|---|---|
| **Title menu** | `ui/App.tsx` (`Menu`) | Title, difficulty pick (Cozy/Normal/Tight + note), **Continue** (if a save exists), **Past seasons** history list (date · difficulty · day · cash · Kiez · ending). |
| **Manage** | `ui/ManageScreen.tsx` | "Your corner" status panel; **Prices & Stock** card (per-SKU price input + restock +5/+20); **Build & Customize** card (modules + décor rows w/ gating reasons); Sunday-open toggle; **Open tonight ▶**. |
| **Night** | `ui/NightScreen.tsx` | Clock + `/` target, queue/served/lost counters, **Pause** + **speed (1–8×)**; the **Pixi scene**; serve controls (**Sell**, **Sell + take Pfand**, **Wave off**, with the `🔞 underage · ID?` flag + ⚠), **Close up**; rolling event log. |
| **Summary** | `ui/SummaryScreen.tsx` | Nightly P&L card (revenue, tips, COGS, rent/fines, Pfand paid, profit, sales/lost, cash) + **Continue →**. |
| **End** | `ui/EndScreen.tsx` | The **ending tapestry**: main ending title + line, a "where are they now" epilogue per met character, final stats, **New game**. |

### Modals / overlays (float above a screen, block input)
| Overlay | File | Trigger | Contents |
|---|---|---|---|
| **Dialogue** | `ui/BeatOverlay.tsx` | A cast morning beat **or** a one-off vignette is pending | Portrait (PNG or initials avatar) + speaker (+ "passing by" tag for vignettes) + lines + choice buttons; **freezes the night**. |
| **Pause** | `ui/Overlays.tsx` | Esc / ☰ | Resume · Settings · How to play · Save & quit · Abandon to menu; **freezes the night**. |
| **Settings** | `ui/Overlays.tsx` | from Pause | Music & SFX sliders, Mute all, Reduce motion (all persisted). |
| **How a Späti works** | `ui/Overlays.tsx` | from Pause | Rules / how-to-play primer. |

### Persistent / shared components
- **TopBar** (`ui/TopBar.tsx`) — day/weekday/act, cash, the three reputation meters (Kiez / Profit / Integrity), the **Ordnungsamt heat** badge, difficulty, and the **☰ menu** button.
- **SceneStage** (`render/SceneStage.tsx`) — the Pixi scene (the one render swap-point).
- **Portrait** (`ui/BeatOverlay.tsx`) — PNG-or-avatar portrait, reused by every dialogue.
- **Meter / Panel / ModuleRow** — small reusable bits (top-bar meters, modal frame, Build & Customize row).
- **uiStore** (`ui/uiStore.ts`) — overlay state + reduce-motion; **store** (`state/store.ts`) — game state, dispatch, save/continue/history; **audio** (`audio/sound.ts`) — synth engine + mixer.
