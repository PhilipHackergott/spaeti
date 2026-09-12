# Game Design Document — Späti Simulator (working title)

> Original-concept design artifact (the "rulebook we write ourselves"). Feeds `/spec` →
> `03-mvp-spec.md` + `04-build-plan.md`. See root `CLAUDE.md` → "The original-concept track".
> Substrate: **3D** (React Three Fiber). This doc is a design foundation, not a final spec — open
> decisions are flagged ⚑.

---

## 1. Vision

You run a **Späti** — a Berlin late-night corner kiosk — through a changing season in a gentrifying
Kiez. It's a **cozy economy-management sim** (stock the fridges, price the goods, handle the Pfand,
keep the till and the lights on) **fused with a choice-driven narrative**: every customer who walks
through the door at 2am is a small Berlin story, and the ones who keep coming back are arcs. You're
balancing a viable little business against the soul of the place — and against a landlord, a chain
store, and a neighborhood that's quietly turning over.

**One-line pitch:** *Papers, Please* warmth meets *Coffee Talk* heart, behind the counter of a Berlin Späti.

### Pillars
1. **The counter is the stage.** Every story walks through your door; the game's drama is the parade of people.
2. **A real little business, legible.** Stock, price, cash, Pfand, rent — numbers that genuinely matter but never need a spreadsheet.
3. **Make it *yours* — an evolving shop.** Continuously **build up your offering (modules) and customize the
   space** — a core, recurring loop right beside pricing/stock, not a one-time upgrade list (see §4c).
4. **Berlin, bittersweet.** The city's humor, grit, and the slow ache of change. Small kindnesses against big forces.

### What it is *not*
Not a twitchy rush sim, not photoreal, not a tycoon spreadsheet. Cozy pace, stylized look, story-forward.

---

## 2. Art direction → see **[`art-direction.md`](art-direction.md)** (authoritative)

> **Style LOCKED (2026-05-25): HD hand-drawn pixel art — a Berlin Späti version of *Coffee Talk Tokyo*** (2D).
> The 3D-diorama avenue is **parked**; the flat-vector concept boards are **superseded for style** (kept only
> as character/layout briefs). Full spec + the honest asset-sourcing plan (commission / AI-pixel — Claude
> can't hand-draw to this bar) live in `art-direction.md`.
> **Concept art:** the **[protagonist concept sheet](concept-art/protagonist.svg)** (Cem's nephew, designed
> from the user's reference photo), the main-cast **[portrait/casting board](concept-art/cast.svg)**, and the
> **[2D/2.5D counter mockup](concept-art/counter-2d.svg)** (viewer: **[concept-art/index.html](concept-art/index.html)**).

**(Avenue A) Style:** stylized **low-poly**, warm and night-lit — a cozy lit **diorama** you look into, not a
realistic store. Chunky, readable props; flat materials with strong lighting doing the work.

- **Camera:** mostly fixed, **behind the counter looking toward the door** (the player's POV as the
  shopkeeper), with a gentle constrained orbit/dolly. A subtle reframe when a customer reaches the
  counter. (⚑ Decision: fully fixed vs. light orbit — lean fixed for clarity + cheapness.)
- **Palette:** deep night blues/teals for the room, warmed by interior light — **fridge glow
  (cyan-white), a flickering ceiling tube, neon signage (magenta/orange), the till lamp**. High
  contrast between the warm interior pool of light and the cold street outside the glass.
- **Lighting is the mood.** Emissive neon, the cool spill from the drink fridges, a warm key over the
  counter. Time-of-night shifts the exterior (dusk → deep night → pre-dawn grey) and the street life beyond the glass.
- **Props & signage:** shelves of stylized product (generic stand-ins — a green **"Sterni"-like** beer,
  a yellow **"Mate"-like** bottle), a register, a coffee machine, a chip rack, a fridge wall, postcards
  and stickers on the glass, a hand-written "Pfand hier abgeben" sign. The bottle-return crate by the door.
- **Characters:** low-poly with **silhouette-first** reads — body type × clothing tint × **one signature
  accessory/prop** (headphones, a tote bag, a beer crate, a dog) makes each archetype instantly legible
  on a tiny budget. (⚑ Decision: full rigged 3D characters from a CC0 pack, **or** stylized flat/billboarded
  "cut-out" figures that dodge rigging entirely — billboards are cheaper and stylish; prototype both.)
- **UI:** warm, slightly hand-made HUD (chalk/marker feel) layered as React DOM over the 3D — order
  ticket, till, clock, cash. The 3D is for *atmosphere and the act of grabbing goods*; dense info is DOM.

**Reference vibe (mood, not to copy):** Coffee Talk, Unpacking's tactile coziness, the night palette of
*Disco Elysium* exteriors, the diorama framing of *Moncage* / *Tiny Glade*.

---

## 3. Narrative structure

> **The full narrative is designed in [`narrative-design.md`](narrative-design.md)** — built with
> **John Truby's *Anatomy of Story*** per the factory rule (`factory-reference/knowledge/playbooks/narrative-and-story.md`):
> the **main arc** = Truby's **22 steps** (a dramatic gentrification story across the four seasons,
> with a humanized developer-opponent and a reconciliation with the late Onkel Cem); **~14 recurring side
> characters** = branching Truby **7-step** arcs; **most customers are one-off** texture. The **finale is a
> tapestry** — the main ending + a "where are they now" **epilogue for every met character**, each
> recoloured by your chosen main ending (design-doc §6b). **Cast portraits:**
> [`concept-art/cast.svg`](concept-art/cast.svg). This section is the summary; the design doc is authoritative.

Story is delivered as **vignettes** — micro-scenes triggered when a customer comes to the counter —
layered into longer character **arcs (each a 7-step strand)** and one season-long **main arc (the 22
steps)**. The aim: *one gripping dramatic main story* + *many curiosity side stories that bring Berlin
to life* (its diversity, quirks, history — see the 10+ strands + the one-off bank in the design doc).

### Three layers
1. **One-off atmosphere customers** (the majority): a quick need + a line or two of flavor. Texture, humor, world-building. Mostly procedural from a written pool.
2. **Recurring regulars** (the heart): a small cast with **multi-visit arcs** that advance based on your choices and the calendar. The relationships are the game.
3. **The meta-arc** (the spine): **gentrification pressure** over a season — a rent-hike notice, a developer eyeing the building, a slick chain "Spätkauf" opening down the block. Your money + reputation + key flags steer the ending.

### Starter cast (illustrative; content-expandable)
- **Mehmet** — runs the döner place next door, has watched the Kiez change for 20 years; the player's mentor/conscience.
- **Lena** — broke art student, charming, always 50 cents short; the "extend credit?" recurring choice.
- **Der Flaschensammler ("Bottle Jürgen")** — collects bottles for deposit; quiet dignity; a barometer of how you treat people who have little.
- **Tobias** — new-money startup transplant; tips big, doesn't know the neighborhood; comic + poignant.
- **Aylin & Jonas** — the techno couple, in at 6am still glowing; recurring warmth.
- **Frau Brandt** — the landlord's agent who delivers the bad news; not a villain, just the machine.
- **"Kassenkind"** — an obviously-underage kid trying to buy beer; a clean recurring ethics beat.

### Choice & consequence
Choices are **dialogue** *and* **business** decisions, scored along two soft axes:
- **Kiez trust** (community standing) ↔ **Profit** (margin/cash). Many choices trade them off.
- A quieter **Integrity** flag track (sell to the kid? buy from the sketchy supplier? shelter the runaway? sell out to the developer?).

These feed reputation tiers (which change who visits and how the Kiez treats you) and the meta-arc flags.

### Shape (acts = seasons)
- **Act I — Summer:** learn the ropes, meet the regulars, the späti is yours. Light pressure. Ends on the rent-hike notice.
- **Act II — Autumn:** the chain store opens; competition + the first real money squeeze; arcs deepen. Decision point #1 (how to respond — undercut? double down on community? cut a deal?).
- **Act III — Winter:** the crunch; the building's fate is decided. Decision point #2 + the climax.
- **Endings (≈3–4):** *Institution* (beloved & solvent — the dream), *Sold Out* (took the developer's money — rich, hollow), *Pushed Out* (couldn't make rent — but how you're remembered varies by Kiez trust), *Held the Line* (survived, scarred, the Kiez intact). Endings are a function of `{cash, kiezTrust, integrity, key flags}`.

### Themes
Community vs. commerce; belonging and change; the night as a great leveler; small kindnesses against big forces. German flavor words used naturally (Pfand, Kiez, Feierabend, Schultheiss-style brands as stand-ins) over an English base. (⚑ Decision: localization scope; sprinkle vs. full bilingual.)

---

## 4. Management-sim — nuts & bolts

The sim is deliberately **legible**: a handful of interacting systems, no spreadsheet required.

### 4.1 Time
- The unit of play is a **night**: open at **dusk**, close at **dawn**. A night is compressed to ~**8–12 minutes** of real time with a visible clock (⚑ pace tuned in test).
- Customers arrive on **time-of-night curves** (early-evening errands → late-night drinks → pre-dawn stragglers).
- Nights advance the **calendar** (days → weeks → the three seasonal acts). Rent/utility bills land on the calendar.
- (⚑ **Core pace decision:** real-time ticking clock vs. a calmer "next customer" turn beat. Recommend a *gentle* real-time clock that you can pause to manage — cozy, not frantic.)

### 4.2 Inventory & SKUs
A SKU has: `category`, `cost` (wholesale), `price` (you set), `stock`, `demandProfile` (who wants it × time-of-night weight), optional `perishable`, `margin = price − cost`.

Categories (≈15–20 SKUs at MVP):
- **Drinks** — beer (Sterni-like), Mate-like, soft drinks, water, energy drink.
- **Snacks** — chips, chocolate, gummi, Schrippe/baked.
- **Tobacco** — cigarettes, rolling tobacco, papers.
- **Essentials** — TP, condoms, batteries, lighter, painkillers.
- **Hot (upgrade)** — coffee, microwave currywurst.

### 4.3 Restock & suppliers (between nights)
- Order stock from a **wholesaler** screen; **bulk discounts**, delivery next open.
- Multiple suppliers vary on price/reliability; a **sketchy supplier** option is cheaper but risk-bearing (quality/legal/quietly hurts Kiez trust if discovered) — an Integrity lever.
- Cash on delivery vs. short credit (cash-flow tension).

### 4.4 Pricing & demand
- Set price per SKU. **Elasticity:** price above the "fair" band → fewer sales + grumbling (Kiez trust dip); below → margin loss + faster sellout.
- **Context modifiers:** tourists tolerate higher prices; regulars *notice* gouging; late-night scarcity raises willingness-to-pay (the classic Späti markup).

### 4.5 Pfand (bottle deposit) — a signature mini-system
- Customers **return bottles** for their **deposit** (you pay out cash now); you reclaim bottles for **wholesaler credit** later. It's a **cash-flow + goodwill** lever, not busywork.
- The Flaschensammler arc lives here: accept his bottles graciously (Kiez trust) or not.

### 4.6 Cash / till
- A **till** with a running balance; take payment, **give change/Pfand**. Mostly **cash** (the Berlin reality: "Nur Bargeld").
- Light risk events: a fake bill, a till left open, a late-night robbery scare — rare, flavor + stakes, not punishing. (⚑ keep gentle.)

### 4.7 Customers (the serving act)
Each customer = `{ want(s), patience, payment, optional vignette }`.
- Serve loop: customer states a need → you **grab the item(s)** off the shelf (the 3D interaction) → **ring up** → **take payment, give change/Pfand** → satisfaction resolves.
- **Satisfaction** = correct + reasonably prompt + (sometimes) a good dialogue choice → tips, reputation, repeat visits. Stock-outs and overcharging cost trust.

### 4.8 Economy & progression
- **Nightly P&L:** `revenue − COGS − (rent/utilities amortized) − Pfand float ± events = profit → bank`.
- **Bills:** rent (rises with the meta-arc), electricity, the occasional repair.
- **Upgrade modules** (spend profit; each adds a system, SKUs, or revenue — some carry risk):
  - *Safe builders:* bigger/extra **fridge** (more stock+SKUs), **coffee machine**, **ice-cream freezer**
    (summer revenue), **grocery section** (milk/eggs/bread → daytime + Sunday demand), better **signage**
    (foot traffic), **security** (fewer risk events), the **bench out front** (Kiez-Trust + dwell).
  - *High-margin / regulated:* **vapes & e-cigs** (trendy, profitable; selling to the underage archetype is
    an Integrity + legal-risk beat); **fireworks** (Silvester-only, semi-legal).
  - *Under-the-counter (illegal):* a discreet **"extra menu"** (soft drugs) — fattest margins in the game,
    but a serious bust risk + a heavy Integrity/ending lever (see §4.10).
  - *The crazy ones (flavour + a twist each):* a **Pfandautomat** (reverse-vending; automates Pfand), a
    **vinyl/techno crate**, a **photo-booth (Passbild)**, an **open-mic/karaoke corner** (ties to busker S14),
    a **community/Foodsharing fridge** (Kiez-Trust, no margin), a **claw machine**, a **Mate-on-tap** tap.
  - Upgrades gate content, ease (or complicate) the sim, and several **unlock community systems** (§4b).
- **Reputation tiers** unlock regulars' arcs and shift the customer mix.

### 4.9 Opening hours & the Sunday gamble (Ladenschluss)
- Germany restricts **Sunday/holiday retail**; spätis survive on loopholes (the *Reisebedarf* — "travel
  needs" — exemption). **You choose whether to open on Sundays.** Open = **big demand** (almost everything
  else is shut → high traffic + a Sunday markup); but each Sunday carries a **chance of an Ordnungsamt
  inspection → a fine** that scales with how brazenly you trade. Repeat offenses raise the risk + penalty
  and can escalate toward a closure threat.
- **Levers:** trade only *Reisebedarf*-flavoured goods to lower risk; a **lookout/tip-off** (a Kiez-Trust
  perk — a regular warns you the Amt is about); or just eat the risk for the cash. Risk/reward + Integrity +
  pure Berlin texture. (⚑ tune fine size + inspection odds in test.)

### 4.10 Under-the-counter goods (the dark path)
- The **"extra menu"** upgrade moves illegal goods for fat margins — the fastest cash in the game and a
  tempting answer to the rent squeeze. But it's a **major risk + Integrity lever:** a real **bust** chance
  (fines → confiscation → the landlord/developer using it against you), it **costs Kiez-Trust** if the wrong
  people notice, and it **gates dark branches** of the main + side arcs. A clean way to "win dirty" that the
  moral arc — and the **endings + side epilogues** — remember.

---

## 4b. The community evolution — the game grows from shop to Kiez *(mechanics-as-theme)*
The hero's arc — *"I see the Späti as a transaction" → "I belong by taking responsibility for it"* — is
expressed **mechanically**, not just in dialogue: the game **starts as a lean shopkeeping sim and accretes
community systems as you engage**, so by the end you're playing a richer, different game *about the Kiez*.

- **Act I (transactional):** the bare loop — stock, price, **serve**, Pfand, till, cash (§4.1–4.8). Numbers in, numbers out.
- **As you engage** (advance side strands · spend Kiez-Trust · make caring choices), new **community systems
  unlock**, each tied to a character/beat and each pulling play *away from* pure transaction:
  - **Favours & credit** (a tab for Lena; small favours) → a **trust economy** beside cash.
  - **The bench / dwell** → the front becomes a **social space** (regulars linger, meet, more vignettes).
  - **A community board** → regulars post **requests**; fulfilling them deepens bonds + opens beats.
  - **Hosting events** → a Kiez **Stammtisch**, an open-mic (S14), a Pfand-drive, a fundraiser.
  - **Relationship bonds** → tracked per regular; grant perks (the Sunday lookout, supplier intros) **and**
    gate that character's arc + tapestry epilogue.
  - **Collective action (Act II–III)** → organize the tenants vs. the developer: a petition, the
    **Kiezversammlung**, mutual aid — the systems that make the climactic *stand* possible.
- **Why it matters:** the **breadth of community systems you've embraced** is itself an input to **Kiez-Trust
  → the main ending → the tapestry** (`narrative-design.md` §6b). Stay transactional → *Sold Out / Pushed
  Out*; let the game *become about the Kiez* → *Institution*. The mechanics and the moral are one gesture.
  (Built default-off on the content spine, gated by engagement flags — see `04-build-plan.md`.)

## 4c. Build & Customize — the ongoing expansion loop *(a core pillar, not a one-off)*
Expanding and customizing the Späti is a **constant activity across the whole run**, sitting beside the
daily pricing/stock management — there should *always* be a tempting next thing to save up for.

- **Modules trickle out, they don't dump.** The ~12+ upgrade modules (§4.8) become **available gradually**
  — gated by **day reached · Kiez-Trust · cash tier · a prerequisite module** — so the "Build" shop always
  has a fresh next goal rather than emptying in week one.
- **Tiered modules.** Key modules **level up** (e.g. Fridge I→II→III, Signage I→II, Coffee→Espresso bar) —
  ongoing investment that keeps paying into capacity / revenue / draw.
- **Customization (décor) is a parallel track.** Cosmetic-leaning items you buy + place — posters, plants,
  fairy lights, a Berlin mural, a retro jukebox, a rug, seating — that **express who you are** and give
  small effects (Kiez-Trust, dwell, foot-traffic, mood). This is how the player *makes the place theirs*
  and is itself part of the community-evolution arc (§4b) — a cared-for space reads as belonging.
- **Loop shape:** earn → choose the next **module or customization** → it changes how the night plays
  (new SKUs, more capacity, more draw, more dwell) → which funds the next. Always-on progression.
- **Data:** every module/décor item is a registry entry with availability gating (`availableDay /
  availableKiez / requires / cost`) + effects; the "Build & Customize" screen reads `availableModules(state)`.

## 5. Core gameplay loop

**A night:**
1. **Pre-night (management):** review last night's P&L; place a restock order; adjust prices; spend on an upgrade; read any narrative beat (a letter, a visit). 
2. **Open:** customers arrive on the night curve. Serve them — grab goods, ring up, change/Pfand — while the clock ticks and the till fills.
3. **Beats:** scripted **vignettes** fire (a regular's arc advances; a meta-arc moment); occasional **random events** (power flicker, a big delivery, a drunk, the Flaschensammler).
4. **Close (dawn):** **nightly summary** — profit, reputation deltas, story flags gained. Bank it; advance the calendar.

**Across a run:** nights → bills come due → arcs progress → **community systems unlock (§4b)** so the game
shifts from shopkeeping toward Kiez-tending → seasonal decision points → the **finale weaves the main ending
with every met character's epilogue** (`narrative-design.md` §6b). ~**2–4 hours** for a full season at MVP (⚑ tune length).

---

## 6. Simple-3D implementation spec (R3F)

Targets the factory's stack with the engine/UI/render split intact (see `docs/stack-and-conventions.md` → "3D concepts").

### 6.1 Scene graph (one interior set)
```
<Canvas> (lazy-loaded after the React shell boots)
├── Environment        # night HDRI/skybox spill + ambient
├── Room               # PROCEDURAL geometry: floor/walls/ceiling boxes, the window wall
│   ├── Counter        # the play focus (where ringing-up happens)
│   ├── FridgeWall     # instanced drink props (emissive cyan interior glow)
│   ├── Shelving        # instanced snack/essential props (clickable to grab)
│   ├── Register + TillLamp
│   └── Neon signage    # emissive materials (the mood)
├── Doorway + StreetBackdrop  # low-poly exterior + parallax night sky; time-of-night tint
├── Customers[]        # CC0 low-poly figures OR billboarded cut-outs; door→counter→leave
└── Rig (camera)       # fixed-ish behind counter, constrained orbit, soft reframe on approach
```

### 6.2 Engine / render / UI split
- **`engine/` (pure, seeded, deterministic):** all sim + narrative state and reducers — `state.ts`
  (inventory, prices, cash/till, time, customer queue, reputation, integrity, calendar, story flags,
  rng seed), `rules.ts` (`advanceTime`, `serveCustomer`, `ringUp`, `takePayment`, `returnPfand`,
  `restock`, `setPrice`, `buyUpgrade`, `resolveVignetteChoice`, `closeNight`), `setup.ts`,
  `content/` (SKUs, customers, vignettes, suppliers, upgrades, arcs as **data registries** — the
  content-depth playbook applies: the writing is the product).
- **`render/` (R3F):** projects engine state → the scene (which customer is at the counter, what's on
  shelves, time-of-night lighting); emits intents (grab item, point at till) back as engine actions.
- **`ui/` (React DOM over the canvas):** the order ticket, till, clock, cash HUD, dialogue overlay,
  and all management screens (restock, pricing, upgrades, nightly summary, menus). Dense info = DOM.
- **`state/` (Zustand):** session/UI glue + dispatch to the engine (factory pattern).

### 6.3 Assets (zero-art-team plan)
- **Procedural geometry** for the room, counter, shelves, signage (boxes/extrusions in code) — a Späti *is* mostly boxes.
- **CC0 packs** (Kenney / Quaternius / KayKit + Universal Animation Library) for customer figures + small props; instanced shelf products.
- **Emissive materials** for neon/fridge glow (free, high-impact mood).
- **Synthesized audio** (factory audio playbook): lo-fi night-ambience loop, door chime, fridge hum, register cha-ching, bottle clink, coin, distant traffic/U-Bahn, optional rain. Music ducks during dialogue.
- **Perf:** one low-poly room + instancing → trivially 60fps; fine on mobile. Lazy-load the canvas; Draco/LOD only if needed.

### 6.4 MVP build slice ("simple 3D")
- One späti interior, fixed camera, time-of-night lighting.
- ~15–20 SKUs across 4 categories; restock + pricing + Pfand + till.
- The full night loop (pre-night management → serve → beats → nightly summary) with a gentle clock.
- ~6–8 recurring characters (2–3 beats each) + a written pool of one-off atmosphere customers.
- One season meta-arc (rent-hike/gentrification) with 2 decision points and 3 endings.
- Kiez-trust ↔ Profit reputation + Integrity flags; cash economy + rent; ~3 upgrades.
- Synth audio + cozy night vibe; front-of-house shell + autosave/continue (factory playbooks).

---

## 7. Risks & open decisions (⚑)
- **Narrative volume is the cost center** — a vignette game lives on quantity+quality of writing. Build the **content registry first**; treat the writing as the deliverable, not a garnish.
- **Character rendering:** full rigged 3D vs. billboarded cut-outs (cheaper, stylish). Prototype both early.
- **Pace model:** gentle real-time clock vs. turn-per-customer. Recommend pausable real-time.
- **Tone calibration:** funny-warm without being twee; Berlin-specific without caricature. A writing style guide before content scaling.
- **Scope creep:** resist adding a second location / staff management in MVP — one counter, one season.

---

## 8. Why this is the right first 3D pilot
A single bounded interior is the cheapest possible 3D for the factory; the look (stylized, night-lit
diorama) is exactly what procedural + CC0 + emissive lighting does *well*; and the design leans on the
factory's proven strengths (data-driven content, synth audio, the front-of-house shell). The only new
muscle is R3F itself — and this is the lowest-risk place to build it.
