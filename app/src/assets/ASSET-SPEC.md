# Späti — Pixel-Art Asset Spec (for generating with Gemini)

> **Goal:** a *Berlin Späti version of **Coffee Talk Tokyo*** — **HD hand-drawn-looking pixel art**, warm
> and cozy, bittersweet night. **Benchmark:** `projects/spaeti/concept-art/main character target state.png`
> (the protagonist already nailed it) + `concept-art/coffee talk references/`. Generate to that style.
> Drop finished PNGs into **`projects/spaeti/app/public/assets/<folder>/<id>.png`** using the **exact ids
> below** (they match `src/assets/manifest.ts`); the game shows a placeholder until each file exists.

## Global style
- **HD pixel art, hand-drawn feel** — crisp pixels, rich shading, NOT blocky/retro, NOT vector/smooth-3D.
- **Framing:** fixed **side-on, behind-the-counter** (player looks across the counter; the character you're
  serving is centred behind/at it — exactly like the Coffee Talk screenshot).
- **Palette:** deep warm browns + amber counter light vs. cool blue night through the window; neon
  magenta/cyan accents; soft rim-light on faces; a little grain. Berlin Kiez props (U-Bahn sign, techno
  flyer, football scarf, plants, a Pfand crate, a Mate fridge).
- **Logical canvas 960×540 (HD pixel).** Author at **1920×1080 (2×)** so it's crisp on big screens.
- **Transparency:** PNG with alpha for all character + prop + UI sprites; the scene layers are full-frame PNGs.

## 1. Scene (the späti interior) — 3 layered PNGs, each 1920×1080
| id (→ file) | what |
|---|---|
| `scene/backdrop` → `public/assets/scene/backdrop.png` | back wall + the **window** with cold night/rain + neon spill; framed pictures, vintage phone |
| `scene/shelves` → `public/assets/scene/shelves.png` | the glowing **fridge wall** + product shelves + the hanging **SPÄTI neon sign** (drawn over the backdrop) |
| `scene/counter` → `public/assets/scene/counter.png` | the **wood counter** in the foreground (bottom ~30%), with room for a cup/phone/goods on top |
*(Layering them lets us parallax slightly. If easier, a single combined `scene/backdrop.png` is fine to start.)*

## 2. Character portraits — bust facing the player, transparent bg, ~**560–760 px tall** (in 1080 space)
Drawn to sit **behind the counter, centred**, head-and-shoulders (like Hendry in the reference). Each
recurring character needs **4 expression states** (filename suffix): `_neutral`, `_warm`, `_wary`, `_upset`.
Start with `_neutral` for each; add the others as you go.

| id base | character (see `narrative-design.md` / `concept-art/cast.svg`) |
|---|---|
| `char/you` | **The protagonist (Cem's nephew)** — match `main character target state.png` exactly (wavy brown hair, red/black layered Quiksilver-style jacket). |
| `char/mehmet` | Döner neighbour, big grey-black moustache, apron + paper hat. |
| `char/lena` | Broke art student, beanie, paint-flecked, reddish hair. |
| `char/juergen` | "Bottle" Jürgen — weathered, knit cap, worn coat, a bag of bottles. |
| `char/brandt` | Frau Brandt — sharp blazer + bob, cool, a tablet. |
| `char/tobias` | New-money transplant — undercut + beard, hoodie, AirPod. |
| `char/schulz` | East-Berlin Oma — headscarf, glasses, cardigan, sharp eyes. |
| `char/nadia` | Night nurse — teal scrubs, hair tied back, tired-kind, a coffee cup. |

## 3. UI (HD pixel, legible at 1080p)
| id → file | what |
|---|---|
| `ui/dialogue_box` → `public/assets/ui/dialogue_box.png` | the bottom dialogue panel (coloured name + white body + ▾) — Coffee-Talk style, ~1600×220 |
| `ui/panel` → `public/assets/ui/panel.png` | a 9-slice-able cozy panel/frame for the order ticket + menus |
| `ui/icon_clock`, `ui/icon_cash` → `public/assets/ui/*.png` | small HUD icons, ~48×48 |

## 4. (Optional, later) Counter props + SKU icons
Cup, phone, beer/Mate bottles, a Pfand crate, and small ~32×32 pixel icons per SKU (`beer`, `mate`, …;
ids match `engine/content/skus.ts`) for the order ticket. Not needed to run; nice for polish.

## Naming = the manifest
Filenames must match the ids in `src/assets/manifest.ts` (e.g. id `char/you_neutral` →
`public/assets/char/you_neutral.png`). To add a new asset, add a file **and** one line to the manifest.
