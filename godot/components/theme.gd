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

# --- the set (docs/04 rule 1: a COMPONENT may not write a raw hex either) --------------
## Time-of-night tint, dusk -> deep night -> cold pre-dawn (SceneLayers.set_time).
const TINT_DUSK := Color(0.95, 0.62, 0.30, 0.12)
const TINT_DEEP := Color(0.10, 0.16, 0.32, 0.20)
const TINT_DAWN := Color(0.18, 0.42, 0.66, 0.30)
## The SPÄTI sign's bloom over the backdrop.
const NEON_GLOW := Color(1.0, 0.31, 0.85, 0.10)
## Rain on the GLASS. It is drawn in the door/window opening only and BEHIND the counter, because rain
## inside the shop is a bug — and at this alpha it is actually visible at x4 (verify round 3).
const RAIN := Color(0.72, 0.90, 1.0, 0.55)
const RAIN_RECT := Rect2i(372, 4, 106, 200)
## The full-frame dimmer a Modal puts behind its frame.
const MODAL_DIM := Color(0.0, 0.0, 0.0, 0.55)
## A meter's unlit cell, so an empty bar still reads as a scale.
const METER_EMPTY := Color(0.031, 0.027, 0.039, 0.94)

# --- typography (Jersey, a bitmap-native pixel family; each face ONLY at its own native size) ------
## VT323 is an outline face: at 16 base px its one-unit middle stems fell between pixel centres and
## simply vanished ("Mate"->"Nate", "MODULES"->"NODULES", "8"->"B"). The Jersey faces are drawn ON a
## 10 / 20 / 25 px grid, so at those exact sizes every stem lands on a whole pixel and nothing drops.
## Rule: a size here is either a face's native size or an INTEGER multiple of it. Nothing else.
const FONT_TINY := 10    # Jersey 10 @10 -> 40 screen px at x4
const FONT_SMALL := 10   # Jersey 10 @10
const FONT_BODY := 10    # Jersey 10 @10 - Coffee Talk's body is this small; 16 was twice its size
const FONT_LEAD := 20    # Jersey 20 @20
const FONT_TITLE := 50   # Jersey 25 @50 (integer 2x, so the wordmark is a doubled pixel, not a blur)

# --- layout of the base grid (every scene composes against these) ----------------------
const BASE := Vector2i(480, 270)
const COUNTER_H := 100                       # the counter band hides the customer's lower body
const COUNTER_TOP := BASE.y - COUNTER_H      # 170
## Coffee Talk proportions (concept-art/coffee talk references): the box is ~60% of the counter band
## and seats on the wood instead of filling it. At Jersey 10 a speaker line + two body lines need
## 12 + 2x12 + 10 padding = 46 px, so the box is 48 and sits lower on the wood than it did at 16 px.
const DIALOGUE_RECT := Rect2i(40, 210, 400, 48)
## The box is also narrowed to this while the serve panel owns the right half.
const DIALOGUE_W_SERVING := 188
const HUD_MARGIN := 2
## One compact line per corner (18 px incl. the plate's 1-px padding), clear of the SPÄTI neon, which
## the backdrop puts at y 21-37. The 16-px icons, not the 10-px text, set this height.
const HUD_LINE_H := 18
const ICON := 16
const SERVE_RECT := Rect2i(236, 10, 240, 250)
## How many base pixels of a customer's bust sit behind the counter layer (docs/02 framing table).
## `Portrait.place_behind()` derives the bust's y from this and the counter art's real opaque edge;
## the clamp keeps the hair inside the frame when the art is taller than the table assumes.
const PORTRAIT_OVERLAP := 30
const PORTRAIT_TOP_MIN := 24
## The bust is anchored by its BOTTOM-CENTRE, never by a spec rectangle: shipped art is narrower than
## the 190-px placeholder box (you_neutral is 155), so a left-anchored bust would slide off centre.
## docs/02 "Night framing" puts the customer at x 250; with the serve panel open it steps left so the
## panel cannot cover it (verify round 3: Jürgen was ~55 % hidden in `pfand`).
const PORTRAIT_CENTRE_X := 250
const PORTRAIT_CENTRE_X_SERVING := 118
const PAD := 6
const GAP := 4

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

static func snap(p: Vector2) -> Vector2:
	return Vector2(roundf(p.x), roundf(p.y))
