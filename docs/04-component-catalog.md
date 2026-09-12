# 04 — Component catalog (the central pool in `godot/components/`)

Every visible thing on every screen is one of these. Adding a component = add it here with its contract.
Screens compose; they never restyle. If you find yourself writing a `Panel` inside a scene, stop and use `Panel.tscn`.

| Component | Scene / script | Contract (exports · signals · methods) | Used by |
|---|---|---|---|
| _(fill in as built)_ | | | |

## Planned pool for the slice (operators build these first, then screens)

- `Theme` — `Theme.tres` + `theme.gd` palette/typography tokens (the only place a hex lives).
- `PixelFont` — the one font resource, sized to the grid.
- `Panel` — Coffee-Talk dark translucent rounded box (StyleBoxFlat), padding preset, optional title.
- `PixelButton` — label + icon, hover/pressed/disabled states, keyboard focus ring, `pressed` signal.
- `DialogueBox` — speaker name (coloured) + typewriter body + continue ▾ + up to 3 `ChoiceButton`s; `advance()`, `show_choices()`, signal `choice(index)`.
- `Portrait` — a character bust with expression states (`set_character(id)`, `set_expression(name)`), slide-in/out, idle breathing.
- `WantBubble` — the customer's request (SKU icons × qty + short line).
- `SceneLayers` — backdrop / midground / counter parallax stack + time-of-night tint + rain + neon flicker.
- `Hud` — corner cluster: clock, cash, Pfand float, Kiez-Trust/Profit meters (icons from `assets/ui`).
- `Meter` — icon + label + segmented bar (colourblind-safe: shape ≠ hue).
- `ItemSlot` / `Shelf` — SKU icon + price + stock badge; `Shelf` lays out slots from the registry; `picked(sku_id)`.
- `Till` — ring-up tray: picked items, total, pay/change/Pfand buttons.
- `TallyRow` / `SummaryTally` — animated P&L rows for the nightly summary.
- `Modal` — one overlay shell (backdrop, focus trap, Esc) used by Pause/Settings/Manage.
- `Transition` — fade/dusk-to-night wipes between scenes.
