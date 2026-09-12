# Candidate Brief — Späti Simulator (working title)

> Stage 1 (Discovery). Produced inline (no subagent), per standing preference. See `factory-reference/docs/01-discovery.md`.
> **Concept note:** this is an **original, born-digital game concept**, not a board-game adaptation.
> The discovery template's adaptation fields (designer/publisher/BGG rank) don't apply; they are
> repurposed below, and the 1–5 rubric is reinterpreted for an original concept. No stats fabricated.

## Title & identity
- **Name:** Späti Simulator *(provisional working title)*
- **Designer / Publisher:** Original — this factory.
- **Year:** 2026 (concept).
- **Genre:** Shop / economy **management sim** fused with a **choice-driven narrative** (vignette) game.
- **Perspective:** stylized **3D** from behind the counter (single interior set) + 2D/UI management layer.
- **Setting:** a Späti (late-night corner kiosk) in Berlin.

## At a glance (repurposed for a born-digital concept)
- **Platform / mode:** web-first (factory standard), single-player.
- **Comparable video games (orientation, not competitors-of-record — analysis confirms):**
  - *Papers, Please* — the defining "counter + management + moral/narrative vignettes" lineage.
  - *Coffee Talk*, *VA-11 HALL-A* — cozy, dialogue-driven "serve people, hear their stories" sims.
  - *Beholder*, *Night Shift*-likes — neighborhood/regime texture and small-business pressure.
  - Cozy/management-sim trend (e.g. *Lemonade*/shop-tycoon-likes) — the eco-management appetite.
- **Market signal:** narrative-management sims and cozy-shop sims are a proven, currently-warm niche; a **Berlin Späti** is a fresh, culturally specific hook with strong identity. The specificity is double-edged — strong charm and word-of-mouth, smaller total audience than a generic shop sim.

## The core loop
You open the Späti each evening: **stock the fridges and shelves** (beer, a Mate-like drink,
snacks, cigarettes, the essentials), **set prices**, **manage cash and the Pfand (bottle-deposit)
system**, and keep the lights on against rent and margins. As night falls, **customers come
through the door** — and each is a small Berlin story: the 6am techno crowd, the lonely artist, the
tourist who can't find an ATM, the Kiez regular with the latest gossip, the landlord. You serve
them, make small choices in **branching dialogue**, and those choices — plus how you run the shop —
shape both your bottom line and the unfolding neighborhood narrative (a gentrification arc, the
regulars' lives, your own). A "day/night" cycle advances the season; you're balancing **a viable
business** against **the soul of the place**.

## Why digital (the experience it enables)
This is a place and a feeling more than a ruleset: the specific, bittersweet texture of running a
late-night Berlin kiosk — the rhythm of restocking, the parade of strangers, the slow pressure of
a changing neighborhood. Digital lets the management sim (inventory, pricing, cash, Pfand) and the
narrative vignettes interlock — your business decisions change which stories you get, and the
stories change your business. It's an *atmosphere* and an *empathy machine*, the kind of thing
games do better than any other medium.

## 3D feasibility (the headline question)
- **Tech:** achievable. **React Three Fiber** slots into the factory's exact stack; the pure
  `engine/` is untouched and `render/` becomes an R3F scene.
- **Why this is the *easier* 3D pilot:** it's a **single, constrained interior set** — a counter,
  shelves/fridges, a door customers walk through. That is dramatically more asset-feasible than an
  open world. Procedural geometry handles the room (a Späti is mostly boxes, shelves, and signage);
  CC0 packs (Kenney/Quaternius/KayKit) + the Universal Animation Library cover the few characters;
  audio is synthesized as usual.
- **The only real asset wrinkle:** the customers (people are the hardest thing to fake). Stylized
  low-poly characters from CC0 packs, or even a charming 2.5D / stylized-silhouette treatment,
  resolve this without an art team. Photoreal is out of scope and unnecessary — stylized *suits*
  this material.

## Scoring (1–5; rubric reinterpreted for an original born-digital concept)
| Criterion | Score | Note |
|-----------|:----:|------|
| Digital fit | 5 | Management + interlocking branching narrative is a natural, proven digital form. |
| MVP scope | 4 | Single location, bounded systems. Not trivial (sim **and** narrative content), but the smallest *coherent* slice is clear: one shop, a handful of stock lines, a starter cast of regulars. |
| Design clarity | 4 | Counter-sim + vignette structure is well-understood (Papers Please lineage); the loop is legible and easy to prototype. |
| Visual feasibility | 4 | One interior set; procedural + CC0 carries it; stylized look fits the tone. Characters are the only wrinkle and have known cheap solutions. |
| Demand signal | 3 | Niche but passionate; cozy/narrative-sim trend is favorable; Berlin specificity is strong identity at the cost of a smaller TAM. |
| **Total** | **20 / 25** | Focused, distinctive, and the most shippable of the two. |

## Top risk
Narrative content is the cost center — a vignette game lives or dies on the *quality and quantity* of its writing/characters; thin content reads as a tech demo no matter how good the shop sim is.

## Top opportunity
A genuinely fresh, culturally rich setting that almost no game occupies, on a constrained set that makes it the **lowest-risk way to prove the factory's 3D pipeline** — while telling stories people will want to share.

## Natural player mode (note, not scored)
Single-player (sim + narrative). No multiplayer needed or natural.

## IP first impression (note, not scored)
**Original (clean).** The Berlin setting is cultural, not IP. Real products/brands become generic stand-ins (a Mate-like drink, a Sterni-like beer). No licensing required. Analysis confirms.

## Recommendation
**Pursue — and make this the factory's first 3D pilot.** It scores highest, has the most contained scope, and its single-interior set is the cheapest way to de-risk 3D in this factory. The one thing to plan for explicitly from spec onward: **treat the writing/character content as the core deliverable**, with a data-driven vignette registry (the factory's content-depth playbook applies directly), so the narrative is rich, not a thin demo.
