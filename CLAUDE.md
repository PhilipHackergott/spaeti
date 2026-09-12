# Project: Späti Simulator (working title)

This is one **original game concept** project inside the BoardGameMVPs factory (not a board-game
adaptation — see the concept note in `01-candidate-brief.md`). It is self-contained: its state,
stage artifacts, and `app/` code all live in this folder.

- **Slug:** spaeti (provisional working codename — renameable)
- **Working title:** "Späti Simulator"
- **Current stage/status:** see `project-state.json` (source of truth).
- **Factory rules:** the root `factory-reference/FACTORY-CLAUDE.md` and `factory-reference/docs/` govern how this project advances.

## What this is

You run a **Späti** (late-night corner kiosk) in Berlin. A blend of **sim / economy management**
(stock the fridges, set prices, handle Pfand/deposits, manage cash, margins, rent, opening hours)
and a **narrative experience** that tells typical Berlin stories through the parade of regulars and
late-night characters who come through the door. Ideally rendered in stylized **3D** from behind
the counter.

**IP/realism note:** real-world products and brands (e.g. specific drinks) become **generic
stand-ins** ("Sterni"-like, "Mate"-like) — original by design. Confirmed at analysis.

## Artifacts (created stage by stage)

| Stage | File |
|-------|------|
| 1 Discovery | `01-candidate-brief.md` |
| 2 Analysis | `02-market-analysis.md` |
| 3 Specification | `03-mvp-spec.md`, `04-build-plan.md` |
| 4 Build | `app/` + `app/README.md` + `art-direction.md` (visual-cohesion design doc) |
| 5 Test | `05-playtest-report.md` |
| Close | `retrospective.md` |

The build target is the "definition of done" in `factory-reference/knowledge/playbooks/target-state.md`:
finished-feeling, content-rich, and tuned on the first build — not a flat, thin slice.

## Working in this folder

- Advance only via the stage commands (`/find /analyze /spec /build /test /learn`) — each stops at
  a human gate. Never skip or bundle stages.
- The `app/` follows `factory-reference/docs/stack-and-conventions.md` (pure `engine/` + thin UI/render). The
  rendering substrate is a **new** one for the factory: 3D via **React Three Fiber** is the
  provisional recommendation (confirmed at spec). The engine/UI/render split still holds — the
  `render/` layer becomes an R3F scene instead of a Pixi scene. A single bounded interior set makes
  this the lower-risk of the two 3D pilots.
- Keep `project-state.json` and the root `registry/projects.json` in sync after every change.
