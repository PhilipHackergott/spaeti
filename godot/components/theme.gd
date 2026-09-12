class_name Palette
extends RefCounted
## The ONLY place a colour, a font size or a screen-layout constant is written down
## (docs/01-godot-conventions.md -> "Palette tokens live in one place").
## `Theme.tres` carries the same values for the parts Godot themes can express (fonts, button
## and panel styleboxes); everything a StyleBox cannot say (tints, meter colours, speaker
## colours, the counter line) is read from here. Components never write a raw hex.

# --- the set: Coffee Talk warmth vs. the Berlin night (art-direction.md 1) -------------
const WOOD_DEEP := Color("2a1a12")
const WOOD := Color("4a2e1e")
const WOOD_LIGHT := Color("7a4b2c")
const AMBER := Color("e8a24a")
const AMBER_SOFT := Color("f2c77a")
const NIGHT := Color("16263c")
const NIGHT_DEEP := Color("0b1220")
const COLD := Color("2b4a6b")
const NEON_MAGENTA := Color("ff4fd8")
const NEON_CYAN := Color("5be7ff")
const RED_HOODIE := Color("c0392b")

# --- chrome (dark translucent boxes, 1-px light edge) ---------------------------------
const INK := Color(0.047, 0.039, 0.055, 0.86)
const INK_DEEP := Color(0.031, 0.027, 0.039, 0.94)
const EDGE := Color(0.97, 0.92, 0.82, 0.30)
## Full-frame veils and the hairline inside a card. They live here because a screen may not write a
## colour of its own (docs/04 rule 1); each screen assigns them to its ColorRects in _ready().
const SCRIM := Color(0.031, 0.027, 0.039, 0.28)   # over title art, so the wordmark stays legible
const DIM := Color(0.031, 0.027, 0.039, 0.62)     # behind a card/modal: the set recedes
const RULE := Color(0.97, 0.92, 0.82, 0.22)       # the 1-px separator inside a card
const CHOICE_FILL := Color(0.97, 0.92, 0.82, 0.05) # a choice row inside the dialogue panel: a breath lighter than the ink, no box of its own
const TEXT := Color("f4e7d2")
const TEXT_WHITE := Color("ffffff")
const TEXT_DIM := Color("9c8c7d")
const SHADOW := Color(0, 0, 0, 0.55)

# --- semantics (shape + label carry the meaning too: colourblind-safe) -----------------
const GOOD := Color("6fd08c")
const WARN := Color("e8c34a")
const BAD := Color("e0645f")
const TRUST := Color("5be7ff")
const PROFIT := Color("6fd08c")
const PFAND := Color("9fd4ff")
## The check/gate accent: a stat tag on a dialogue choice and the d20 pop are the same colour, so a
## roll is recognisable before it is read (the value and the word carry the meaning too).
const ACCENT := NEON_CYAN
## The d20 itself: a code-drawn polygon filled with the accent, its number punched out in the night.
const DICE_FILL := NEON_CYAN
const DICE_NUMBER := NIGHT_DEEP

# --- the set (docs/04 rule 1: a COMPONENT may not write a raw hex either) --------------
## Time-of-night tint, dusk -> deep night -> cold pre-dawn (SceneLayers.set_time).
const TINT_DUSK := Color(0.95, 0.62, 0.30, 0.12)
const TINT_DEEP := Color(0.10, 0.16, 0.32, 0.20)
const TINT_DAWN := Color(0.18, 0.42, 0.66, 0.30)
## The SPÄTI sign's bloom over the backdrop.
const NEON_GLOW := Color(1.0, 0.31, 0.85, 0.10)
## The shaped light on the set (light_pool.gdshader): the warm pool over the counter by night phase, and
## the cool edge it falls off into. Both judges (2026-09-13) scored the flat tint "predominantly cold
## grey-blue" — the target has a warm interior against the blue night.
const LIGHT_POOL_DUSK := Color(1.0, 0.80, 0.52, 0.20)
const LIGHT_POOL_NIGHT := Color(1.0, 0.84, 0.58, 0.17)
const LIGHT_POOL_DAWN := Color(0.90, 0.88, 0.80, 0.06)
const LIGHT_EDGE_DUSK := Color(0.45, 0.30, 0.24, 0.10)
const LIGHT_EDGE_NIGHT := Color(0.08, 0.14, 0.32, 0.30)
const LIGHT_EDGE_DAWN := Color(0.18, 0.42, 0.66, 0.30)
## Rain on the GLASS. It is drawn in the door/window opening only and BEHIND the counter, because rain
## inside the shop is a bug — and at this alpha it is actually visible at x4 (verify round 3).
const RAIN := Color(0.72, 0.90, 1.0, 0.55)
const RAIN_RECT := Rect2i(372, 4, 106, 200)
## The full-frame dimmer a Modal puts behind its frame.
const MODAL_DIM := Color(0.0, 0.0, 0.0, 0.55)
## A meter's unlit cell, so an empty bar still reads as a scale.
const METER_EMPTY := Color(0.031, 0.027, 0.039, 0.94)

# --- typography (Jersey, a bitmap-native pixel family) ---------------------------------
## VT323 is an outline face: at 16 base px its one-unit middle stems fell between pixel centres and
## simply vanished ("Mate"->"Nate", "MODULES"->"NODULES", "8"->"B"). Jersey is drawn ON a pixel grid,
## but ONLY at the sizes where its grid divides evenly — measured, not assumed, with
## `godot/tools/FontProbe.tscn` (shots/fontprobe*.png, build log 2026-09-12):
##   Jersey 10 -> CLEAN at 16 / 20 / 25 / 50 · BROKEN at 10 ("KIEZ"->"HIEZ") and 14 ("Wasser"->"Wassor")
##                 12 draws every letter but not every NUMBER: "22:41"->"ZZ41", "84,50"->"84.50" (the
##                 comma flattens to a dot and 2 to a Z), which is unusable for a clock and for money
##   Jersey 20 -> BROKEN at 20 ("8"->"0"); clean at 25/50, so it earns no slot here (kept for its licence)
##   Jersey 25 -> caps-only display face, perfect at 50: the wordmark, nothing else
## Rule: a size here is one of the measured-clean sizes. Anything else is re-probed before it ships.
## The whole ladder is much smaller than VT323's was at the same numbers — Jersey 10 @16 has an 8-px
## cap where VT323 @16 had 11 — which is the Coffee Talk body size the review asked for.
## So there is exactly ONE text size, like Coffee Talk: everything a player reads is 16, and only the
## lead and the wordmark step up. A "small" token stays, because half the pool asks for one.
const FONT_TINY := 16    # Jersey 10 @16 — the HUD corner line
const FONT_SMALL := 16   # Jersey 10 @16 — table cells, badges, captions (dim, not smaller)
const FONT_BODY := 16    # Jersey 10 @16 — dialogue, buttons, item names
const FONT_LEAD := 20    # Jersey 10 @20 — modal titles, the P&L bottom line
const FONT_TITLE := 50   # Jersey 25 @50 — the wordmark only

# --- layout of the base grid (every scene composes against these) ----------------------
const BASE := Vector2i(480, 270)
const COUNTER_H := 100                       # the counter band hides the customer's lower body
const COUNTER_TOP := BASE.y - COUNTER_H      # 170
## Coffee Talk proportions (concept-art/coffee talk references): the box sits ON the counter band
## instead of filling it. A speaker line + two body lines + the panel's own padding come to 64 px,
## which lands on docs/02's "over the counter band, y≈196–262" almost exactly.
const DIALOGUE_RECT := Rect2i(40, 196, 400, 64)
## The box is also narrowed to this while the serve panel owns the right half.
const DIALOGUE_W_SERVING := 188
const HUD_MARGIN := 2
## One compact line per corner (18 px incl. the plate's 1-px padding), clear of the SPÄTI neon, which
## the backdrop puts at y 21-37. The 16-px icons, not the text, are what set this height.
const HUD_LINE_H := 18
const ICON := 16
## The serve panel owns the right half from here; it is 8 px wider than it was so a full shelf ROW and
## the scroll bar fit side by side (the shelf is 17 SKUs and grows to 23 with the modules).
const SERVE_RECT := Rect2i(228, 8, 248, 256)
## How many base pixels of a customer's bust sit behind the counter layer (docs/02 framing table).
## `Portrait.place_behind()` derives the bust's y from this and the counter art's real opaque edge;
## the clamp keeps the hair inside the frame when the art is taller than the table assumes.
## How far the counter layer is raised above the bottom of the frame (2026-09-13, both judges: "a narrow
## grey strip above the dialogue panel", "Lena looks submerged behind the counter"). The r6 strip's own top
## 37 rows are the wall behind the counter, so flush-with-the-bottom hid the countertop under the panel.
const COUNTER_LIFT := 0   # r7 carries its laminate edge in its top 10 rows; the 20-px lift was for r6 (37 rows of wall above the edge)
const PORTRAIT_OVERLAP := 30
const PORTRAIT_TOP_MIN := 14   # 2026-09-13: with the 144x174 busts the clamp, not the overlap, decided the seat; 14 lets the forearms clear the counter edge
## The bust is anchored by its BOTTOM-CENTRE, never by a spec rectangle: shipped art is narrower than
## the 190-px placeholder box (you_neutral is 155), so a left-anchored bust would slide off centre.
## docs/02 "Night framing" puts the customer at x 250; with the serve panel open it steps left so the
## panel cannot cover it (verify round 3: Jürgen was ~55 % hidden in `pfand`).
const PORTRAIT_CENTRE_X := 250
const PORTRAIT_CENTRE_X_SERVING := 118
const PAD := 6
const GAP := 4

# --- the register screen (docs/06-dialogue-and-stats.md section 5) ----------------------
## The night is a CONVERSATION screen now, so the frame is split into three columns that may never
## trade places: the queue owns the right edge, the six stats the left edge, and the bust + the
## dialogue box keep the middle. Every rectangle below was measured against the two things already
## nailed down — the SPÄTI neon (x 124-224, y 20-62, SceneLayers.NeonGlow) and the active bust
## (bottom-centred on PORTRAIT_CENTRE_X 250, up to 190 px wide, so x 155-345) — because the brief is
## explicit that the queue may cover neither.
## The right column, top to bottom: the d20 result, then the line (name over busts) with the
## "Next guest" button under it. The button sits at the BOTTOM of the strip on purpose - the want
## bubble stands at y 74..120 beside the bust, and a button at the top of the column covered it.
const DICE_RECT := Rect2i(346, 42, 132, 42)
## The queue strip's own rect holds all three of its parts (button / name / chips), so the line does
## not reflow when the button hides — its bottom sits exactly on COUNTER_TOP, i.e. the guests stand
## at the counter's right end rather than floating over it.
const QUEUE_RECT := Rect2i(346, 86, 132, 84)
const QUEUE_CHIP := Vector2i(28, 38)
const QUEUE_GAP := 5
## Four slots: three guests and, when the night has piled up, a "+N" chip. More than that is a number,
## not a queue you can read at 480x270.
const QUEUE_SLOTS := 4
## Six stats down the left edge, BELOW the neon (y 62) and LEFT of the bust (x 155). Toggled with Tab.
const STATS_RECT := Rect2i(2, 64, 136, 98)
## The sheet steps UP when a choice list grows the dialogue box into its column, but never past this:
## the HUD owns the top 20 px, and a sheet under the clock is no more readable than one under the box.
const STATS_TOP_MIN := 22
## The serve panel is a secondary affordance now (docs/06 section 5: "reachable, not the demo path"),
## so its toggle is a small plate tucked under the HUD instead of a button in the middle of the set.
const SERVE_TOGGLE_RECT := Rect2i(5, 25, 62, 18)   # under the inset HUD (which now ends at y 22)
## The dialogue box hands the right column back to the queue whenever the line is on screen.
const DIALOGUE_W_QUEUE := 300

# --- accessibility --------------------------------------------------------------------
## Scenes and components check this before starting rain / flicker / breathing tweens.
static var reduce_motion: bool = false

const THEME_PATH := "res://components/Theme.tres"
static var _theme: Theme = null

## Character -> the colour their name is printed in inside the DialogueBox (Coffee Talk's
## coloured speaker name). Ids match engine/content/characters.gd (docs/05 6).
const SPEAKER := {
	"you": Color("e8a24a"),
	"lena": Color("e8a1b8"),
	"juergen": Color("7fc8f2"),
	"mehmet": Color("8fd694"),
	"brandt": Color("d0a05a"),
	"tobias": Color("b39ddb"),
	"schulz": Color("cfc4b4"),
	"nadia": Color("ffd27f"),
}

const TIER := {
	"steal": Color("5be7ff"),
	"fair": Color("6fd08c"),
	"high": Color("e8c34a"),
	"gouge": Color("e0645f"),
}

## The shared Theme, with EVERY face in it forced to render unfiltered. The .ttf importer defaults to
## antialiased + hinted, which smears a pixel face at x4; the .import files say so too, but doing it
## here keeps the fix inside the component pool instead of a file another lane may regenerate.
static func theme() -> Theme:
	if _theme == null:
		_theme = load(THEME_PATH) as Theme
		if _theme != null:
			_pixelate_theme(_theme)
	return _theme

## Walks the default font AND every type variation's font (Jersey 10 / 20 / 25 all appear).
static func _pixelate_theme(t: Theme) -> void:
	_pixelate(t.default_font)
	for type_name in t.get_font_type_list():
		for font_name in t.get_font_list(type_name):
			_pixelate(t.get_font(font_name, type_name))

## Call once from any scene root's _ready(). Idempotent.
static func prepare() -> void:
	theme()

static func _pixelate(f: Font) -> void:
	var ff := f as FontFile
	if ff == null:
		return
	# A bitmap-native face at its native size needs NO hinting and NO smoothing: every stem is already
	# on a whole pixel. (VT323 needed the autohinter because it is not; that is why it is gone.)
	ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	ff.hinting = TextServer.HINTING_NONE
	ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	ff.force_autohinter = false

static func speaker_colour(character_id: String) -> Color:
	return SPEAKER.get(character_id, AMBER_SOFT)

static func tier_colour(tier: String) -> Color:
	return TIER.get(tier, TEXT_DIM)

## A Coffee-Talk chrome box: dark translucent fill, 1-px light edge, small radius.
## A choice ROW inside the dialogue panel (docs/06 §2, 2026-09-13): no box of its own — a faint fill, a
## hairline under it, no vertical padding — so two choices cost 2 x 17 px, not a stack of bordered chips
## that covered the counter (the judge: "the dialogue stack consumes ~42 % of the frame").
static func flat_row(fill: Color = CHOICE_FILL, rule: Color = RULE) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = rule
	sb.border_width_bottom = 1
	sb.content_margin_left = PAD
	sb.content_margin_right = PAD
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	sb.anti_aliasing = false
	return sb

static func box(fill: Color = INK, edge: Color = EDGE, radius: int = 3, pad: int = PAD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = edge
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = maxi(2, pad - 2)
	sb.content_margin_bottom = maxi(2, pad - 2)
	return sb

## Berlin money: "12,40 EUR" with a comma, like every price tag in the Kiez.
static func money(v: float) -> String:
	var s := "%.2f" % absf(v)
	return ("-" if v < 0.0 else "") + s.replace(".", ",") + " €"

## Where the character sheet's TOP edge belongs, given the dialogue box's current one. The box keeps
## its bottom on DIALOGUE_RECT and grows UPWARD for a choice list (dialogue_box.gd), it starts at the
## same x as the sheet, and it is a later sibling in Night.tscn - so a grown box prints over the
## sheet's last rows at exactly the moment the sheet is wanted (Tab during a conversation, to read
## Schnauze before picking a "[Schnauze 12]" line). The sheet gives way instead, and only then.
static func stats_top(box_top: float) -> float:
	return maxf(float(STATS_TOP_MIN), minf(float(STATS_RECT.position.y), box_top - float(STATS_RECT.size.y)))

static func snap(p: Vector2) -> Vector2:
	return Vector2(roundf(p.x), roundf(p.y))
