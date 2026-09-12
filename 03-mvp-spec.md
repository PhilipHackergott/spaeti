# MVP Spec — Späti Simulator (working title)

> Stage 3 (Specification), the *what*. See `factory-reference/docs/03-specification.md`. Original-concept track
> (no rulebook — design is ours; this spec is derived from `game-design-document.md` + `narrative-design.md`).
> **Substrate LOCKED (2026-05-25):** **2D HD hand-drawn pixel art — a Berlin Späti × *Coffee Talk Tokyo***
> (`react-ts-pixi`, HD logical canvas). 3D parked; vector mockups superseded. See `art-direction.md`.
> ⚑ marks an open decision the build/test stages resolve.

## Pitch & target experience
**Run a Berlin Späti through a changing season.** A cozy economy-management sim fused with
choice-driven Berlin-story vignettes. The feeling: the warm, bittersweet hum of a late-night corner
kiosk — restocking the fridge, the parade of strangers at 3am, the slow pressure of a neighborhood
turning over. Calm, characterful, a little melancholy. *Coffee Talk* heart, *Papers, Please* counter.

## Scope line (the core loop the MVP delivers — with its full base content set)
The MVP delivers **the full night loop** — *open → serve customers (need → ring up → pay → Pfand) →
narrative beats → close → nightly P&L → between-night management (restock, pricing, upgrades)* — over
**one complete season arc** (the gentrification storyline) in **one späti interior**, with the
**complete base content set** that makes it replayable: the SKU catalog, the regular cast + their arcs,
the one-off customer pool, the events, and the meta-arc's branch points + endings. We cut whole
**modules** (a second location, staff/hiring, more seasons/years, multiplayer) — **never depth within
the loop**. A vignette game with 5 customers is a tech demo; the MVP ships the cast.

## Rules to implement

### Components & state
- **The späti:** an interior with a counter, **fridge wall** + **shelves** holding the SKU catalog, a
  **till** (cash balance), a **Pfand crate** (returned bottles), and **upgrade slots**.
- **Clock & calendar:** a night = dusk→dawn, compressed to **~8–12 min** (⚑ tuned). Nights advance a
  **calendar** of **N days** (⚑ ~21–30) split into **3 acts** (Summer/Autumn/Winter). Bills land on dates.
- **Money:** `cash` (the till + bank, one pool for MVP). **Pfand float** (deposits owed/holding).
- **Reputation:** two soft meters — **Kiez Trust** and **Profit-standing** — plus an **Integrity** flag set.
- **SKU:** `{id, name, category, cost, price(player-set), stock, demandWeight, perishable?, fairBand}`.
- **Customer (instance):** `{archetypeId, wants[], patience, budget, vignetteId?, mood}`.

### The night loop (turn/real-time structure)
1. **Pre-night (paused management):** review last night's P&L; **restock order** (wholesaler screen);
   **adjust prices**; **buy an upgrade**; read any scripted story beat (letter/visit). Press **Open**.
2. **Open (gentle real-time, pausable ⚑):** customers spawn on **time-of-night curves**. The player:
   - reads the customer's **want**, **grabs the item(s)** off the shelf/fridge (the 3D interaction),
   - **rings up** at the till, **takes payment** and **gives change / pays out Pfand**,
   - optionally engages a **vignette** (dialogue choices) when one is attached.
3. **Beats:** scripted **vignettes** (a regular's arc step, a meta-arc moment) and **random events**
   fire during the night (see Content).
4. **Close (dawn):** **nightly summary** — revenue, COGS, bills amortized, Pfand settled, profit,
   **reputation deltas**, **story flags** gained. Bank it; advance the calendar.

### Actions (the verbs)
`grabItem(skuId)` · `ringUp()` · `takePayment()` · `givePfand(bottles)` · `setPrice(skuId, price)` ·
`orderStock(skuId, qty, supplierId)` · `buyUpgrade(upgradeId)` · `chooseVignetteOption(vignetteId, optionId)` ·
`openNight()` · `closeNight()` · `advanceClock(dt)` (engine-internal tick).

### Resolution rules (the "math", kept legible)
- **Demand / sale:** a customer wants SKUs by their archetype's `wants` + time-of-night weight. **Price
  elasticity:** selling **above `fairBand.hi`** → chance of balk + **Kiez-Trust** dip; **below
  `fairBand.lo`** → margin loss + faster sellout. Tourists tolerate +; regulars penalize gouging more.
- **Satisfaction** = correct items + served before `patience` runs out (+ a good vignette choice) →
  **tip**, **reputation+**, higher **return** probability. Stock-out or overcharge → reputation−.
- **Pfand:** returns pay out deposit cash now; bottles in the crate convert to **wholesaler credit** at
  the next restock. Treating the Flaschensammler well = Kiez-Trust.
- **Nightly P&L:** `profit = revenue + tips − COGS − billsDue − netPfandPayout`. Negative cash past a
  grace threshold + a missed rent = a **fail/branch** (see endings).
- **Determinism:** all randomness (spawns, balk rolls, event selection) draws from an **injected seed**
  → a night is replayable from `{config, seed, action-log}`.

### Edge cases
Exact change vs. shortfall; customer leaves mid-serve (patience expired) → partial/no sale + mood hit;
selling a **restricted** item (alcohol/tobacco) to the **underage** archetype → Integrity choice, legal
risk flag; stock = 0 mid-night; till can't make change → improvise/lose sale; an event during a serve
(queue it, don't drop the customer).

### Community evolution, Sunday opening & the dark path  (the systems that grow play toward the Kiez)
*(Full design in GDD §4b + §4.9–4.10; this is the spec-level contract.)*
- **Community evolution (mechanics-as-theme):** the game **starts as the lean shopkeeping loop and unlocks
  community systems as you engage** (favours/credit · the bench/dwell · a community board of requests ·
  hosting events · relationship bonds · Act-II/III collective action vs. the developer). Each is gated by
  engagement flags (side-arc progress / Kiez-Trust / caring choices) and built **default-off on the content
  spine**. The **breadth of community systems embraced is an input to Kiez-Trust → the main ending**.
- **Sunday opening (Ladenschluss):** you may **open Sundays** for big demand + a markup, but each Sunday
  rolls an **Ordnungsamt-inspection → fine** risk (scales with brazenness; repeats escalate). Mitigations:
  trade only *Reisebedarf* goods; a Kiez-Trust **lookout** tip-off; or eat the risk.
- **Under-the-counter goods (illegal "extra menu"):** highest margins, but a **bust** risk + a heavy
  **Integrity** hit + it **gates dark branches** of the main + side arcs. A real "win dirty" lever the
  endings remember.

### Modules deferred / cut for the MVP (and why) — at the module level
- **Second location / expansion to a chain** — doubles art+sim; the one späti is the game.
- **Staff / hiring / scheduling** — a whole subsystem; you *are* the counter in the MVP.
- **Multiple years / seasons beyond the one arc** — one season tells the story; more is content later.
- **Online / leaderboards / accounts** — out (single-player narrative sim).
- **Twitchy "rush" mode** — off-tone; the MVP is cozy-paced.

## Content catalog & depth (crawl `factory-reference/knowledge/playbooks/content-depth.md`)
*The writing + the cast are the product. All of the below are **data on a registry** read at fixed hook
points (default-off ⇒ a bare shop), so depth is additive.*

- **SKUs — ~18–22** across 5 categories: **Drinks** (beer "Sterni"-like, "Mate"-like, soft, water,
  energy), **Snacks** (chips, chocolate, gummi, Schrippe), **Tobacco** (cigarettes, tobacco, papers),
  **Essentials** (TP, condoms, batteries, lighter, painkillers), **Hot** (coffee, microwave currywurst —
  upgrade-gated). Each spans the **price/margin/demand-curve/perishability** axes.
- **Narrative — designed in full in [`narrative-design.md`](narrative-design.md)** (Truby method; see
  `factory-reference/knowledge/playbooks/narrative-and-story.md`). MVP narrative content:
  - **Main arc** = Truby's **22 steps** across the four seasons (the gentrification drama: inherit the
    Späti from the late Onkel Cem → fight the Lindner Group / Frau Brandt → the climactic sell-out-or-
    stand decision → reconciliation with Cem). Delivered as season/decision-point beats over the run.
  - **~14 recurring side characters**, each a **branching 7-step** arc with a **local outcome** +
    **per-main-ending epilogue** (Lena, Bottle-Jürgen, Mehmet, Aylin & Jonas, Frau Schulz, Karim, Achim,
    Tobias, Nadia, Robin, Esra & Nilay, Herr Bley, Diego & Frau Pohl, Bruno — Berlin's diversity, eras,
    subcultures). **Most customers are one-off**; the recurring few carry the branching + endings.
  - **The ending tapestry** — the finale = the **main ending** + a **"where are they now" epilogue for
    every met character**, each recoloured by the chosen main ending (`narrative-design.md` §6b).
  - **~25–35 one-off "curiosity" vignettes** (procedurally drawn night texture; some graduate to strands).
- **Events — ~8** risk/reward or flavor interrupts: power flicker, big delivery, a robbery scare, a
  health inspector, a street party (demand spike), a competing chain flyer, a busker out front, rain.
- **Endings — 4 main** (step-21 moral decision → step-22): **Institution / Held the Line / Sold Out /
  Pushed Out** from `{cash, kiezTrust, integrity, flags}` — each composes the side-epilogue tapestry.
- **Upgrade modules — ~12+** (GDD §4.8): *safe* (fridge, coffee, **ice-cream**, **grocery section**,
  signage, security, bench), *regulated* (**vapes**, fireworks), *illegal* (**under-the-counter "extra
  menu"**), and *crazy* (**Pfandautomat**, vinyl crate, photo-booth, open-mic, Foodsharing fridge, claw
  machine, Mate-on-tap). Several **unlock community systems**.
- **Community systems** (unlock with engagement, GDD §4b): favours/credit · bench/dwell · community board ·
  hosting events · relationship bonds · collective action. + **Sunday-opening/Ordnungsamt** risk system.
- **Design axes spanned:** margin-vs-goodwill, scarcity/time-of-night, perishability, integrity choices,
  reputation tradeoff (Kiez↔Profit). **Under-served axis worth opening (⚑):** *supplier relationships*
  (reliability/credit arcs) — flag for post-MVP.

## Modes & "difficulty" (adapted — no adversarial AI)
Single-player. There is **no opponent**; the "difficulty" is the **economy + time pressure curve**.
Ship a **3-rung economic ladder** off one shared model: **Cozy / Normal / Tight** (starting cash, rent
slope, demand variance, patience). This is the analogue of the difficulty ladder and is **sim-verified**
(see Balance): Normal must be *survivable with competent play*, Tight meaningfully harder, Cozy forgiving
— no setting trivially auto-wins or is unwinnable.

## Screens & flow
`Main menu → (New / Continue) → Pre-night management → Night (3D) → Nightly summary → repeat → Act
break beat → … → Ending screen → Main menu.`
- **Night (3D):** the interior; React HUD overlays — **order ticket**, **till/change**, **clock**,
  **cash**, the **active customer** + dialogue. The 3D is for atmosphere + grabbing goods; dense UI is DOM.
- **Outcomes are beats, not cuts:** the **Nightly Summary** is a **Continue-gated** screen that *shows
  what changed* (animated P&L tally, reputation deltas, flags). **Act breaks** and the **Ending** are
  authored beats with a Continue, never an auto-switch. A failed-rent moment **animates the cause**
  (the notice, the empty till) before gating to its branch.

## Player states & feedback
The UI always shows: **whose need is active** (the customer + their want bubble), **time left on the
night**, **cash/Pfand**, and the **patience** of the waiting customer. **Plan-relevant state surfaced
redundantly:** low-stock SKUs flagged on the shelf *and* in the restock screen; a restricted item shows
an **age-check** badge at the point of sale; price-vs-fairBand shown when setting price. Rejected/blocked
actions explain why ("no change for €50", "out of stock"). Forced choices (a waiting impatient customer)
draw the eye (highlight + gentle motion).

## Look, feel & flow (crawl `factory-reference/knowledge/playbooks/visual-first-try.md` + `target-state.md`)
Original assets; CC0/procedural only (IP-clean). Commit up front to:
- **`art-direction.md`** — the **stylized low-poly night-diorama** concept; **palette as tokens** (deep
  night blues/teals + warm interior pool; neon magenta/orange; fridge cyan glow) synced between
  `:root` (DOM HUD) and **`render/theme.ts`** (3D materials/lights); one display + one body face; **the
  ONE customer model recipe** (body × tint × one signature accessory); **the ONE product-prop recipe**;
  HUD panel/ticket/button recipes; lighting recipe (emissive neon + fridge spill + warm key + time-of-
  night exterior); a component audit checklist. ⚑ Decide **fixed vs. light-orbit camera** and **rigged
  vs. billboarded customers** in milestone 2 (prototype both).
- **Reusable UI primitives:** ONE `<Modal>`/overlay shell + atoms (`<Ticket>`, `<MoneyTag>`, Button,
  Panel, tooltip) built before screens.
- **Living background:** the night *is* the living background — animated exterior (passing headlights,
  distant U-Bahn glow, drifting rain ⚑), the fridge hum flicker, a breathing neon sign.
- **Game-feel budget:** coin/till pop on payment, a satisfying *clunk* + bottle-clink on Pfand, a soft
  bell + light spill when the door opens, gentle card-/ticket-slide for dialogue. The key "number-go-up"
  beat = the **nightly P&L tally** animating + the Kiez-Trust meter ticking.
- **Transitions & outcomes:** dusk→night→dawn establishing beat; warm act-break vignettes; **legible
  fail** (animate the empty till / the eviction notice, then gate). Reward-collection = the profit tally.
- **Accessibility:** colorblind-safe (shape ≠ hue; reputation uses icon+label not just colour), keyboard-
  operable management screens, text scaling, **reduce-motion** + a **disable-headlights/rain** toggle.

## Sound (crawl `factory-reference/knowledge/playbooks/audio-and-sound.md`)
Synthesized, IP-clean, zero-asset.
- **Music:** a **lo-fi night-ambience loop** (warm, sparse); a slightly different **management/menu** cue;
  music **ducks under dialogue**. ⚑ optional act-tinted variations.
- **SFX:** door chime, fridge hum (ambient bed), register cha-ching, coin/change, **bottle clink** (Pfand),
  shelf grab, a soft notification for a new vignette, distant street ambience.
- **Mixer:** independent **Music + SFX sliders + mute**, persisted; engine pinned to `globalThis` (HMR-safe).

## Shell, settings & persistence (crawl `factory-reference/knowledge/playbooks/front-of-house-shell.md`)
- **Main menu:** New game · **Continue** (when a save exists) · **Past runs/history** (ledger of finished
  seasons + ending reached) · Settings · About/Rules ("How a Späti works").
- **Pause** (during a night) that **freezes the clock + 3D ticker**: Resume / Settings / How-to / Save &
  quit / Abandon season.
- **Settings:** audio mixer + reduce-motion + animated-exterior toggle + camera ⚑ + text size.
- **Persistence:** autosave the JSON-serializable sim state (per night + on close); **Continue**; a
  finished-seasons history. Clear/new on a new season.

## Balance & tuning (crawl `factory-reference/knowledge/playbooks/balance-and-tuning.md`)
- **Sim harness (`npm run sim`):** a **headless economy auto-player** runs full seasons with a simple
  shopkeeper policy (sane restock + price = cost×markup + serve-fastest) across seeds × the 3 economic
  rungs.
- **Targets:** on **Normal**, the competent policy should **survive ≥ ~70%** of seeds with a modest
  positive trend (not trivially rich, not doomed); **Tight** clearly lower, **Cozy** clearly higher
  (the "ladder climbs" analogue). **No degenerate SKU/strategy** (e.g., one product that auto-wins, or a
  price that's always optimal) — flatten outliers. **No dead content:** every SKU sells in some viable
  build; every regular's arc is reachable.
- A **first tuning pass** runs in the build (markups, fairBands, rent slope, patience, spawn rates);
  AI-blind/feel issues flag for `/test`. Write a one-paragraph balance note.

## Acceptance criteria (each testable — becomes the playtest checklist)
- [ ] A full night plays start→finish: customers spawn on the curve, can be served (grab → ring → pay →
      Pfand), and the night closes with a correct, itemized P&L.
- [ ] The **full base content set** is present and reachable: all ~18–22 SKUs purchasable/sellable;
      the one-off pool and all ~8 events fire.
- [ ] **Narrative complete (Truby):** the **main arc** plays through its mapped **22 beats** across the
      four seasons; **every shipped recurring strand (~14) plays to a 7-step completion AND reaches each of
      its branch local outcomes**; the one-off curiosity pool fires. (Per `narrative-design.md`.)
- [ ] **The ending tapestry composes** — the finale = the chosen **main ending** + a **"where are they now"
      epilogue for every met character**, recoloured by that main ending (`narrative-design.md` §6b);
      all 4 main endings reachable from `{cash, kiezTrust, integrity, flags}`.
- [ ] **Community evolution works:** new community systems (favours/credit, bench/dwell, community board,
      events, bonds, collective action) **unlock as you engage**, and the breadth embraced measurably feeds
      Kiez-Trust → the ending (GDD §4b).
- [ ] **Sunday/Ordnungsamt** (open-Sunday demand + inspection-fine risk + mitigations) and the **illegal
      "extra menu" dark path** (bust risk + Integrity hit + gated dark branches) both function.
- [ ] **Pricing elasticity, Pfand, restock, the ~12+ upgrade modules, and all reputation meters
      (Kiez-Trust / Profit / Integrity)** observably affect play.
- [ ] **Economic ladder sim-verified:** Normal survivable / Tight harder / Cozy easier per the targets;
      no degenerate SKU or dead content (balance note committed).
- [ ] **Shell complete:** menu + Continue + history + Pause-that-freezes + settings mixer; autosave/continue works.
- [ ] **Not silent:** music loop + the SFX set wired; mixer + mute persist.
- [ ] **Matches `art-direction.md`**: the **2D HD hand-drawn pixel art** (Coffee-Talk-Tokyo × Berlin Späti)
      look at the HD logical canvas — side-counter framing, pixel portraits, dialogue box, legible HUD at 1080p+.
- [ ] Runs at a steady frame rate on a mid laptop.

## Out of scope (MVP) — whole modules, not depth
Second location/chain, staff/hiring, multi-year play, online/leaderboards/accounts, monetization
plumbing, a twitchy rush mode, supplier-relationship arcs (flagged for later). The one-späti, one-season
game still ships **content-complete and tuned**.
