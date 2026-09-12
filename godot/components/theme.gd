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

# --- typography (VT323, sized to the 480x270 grid; crisp at x4) ------------------------
const FONT_SMALL := 12
const FONT_BODY := 16
const FONT_LEAD := 24
const FONT_TITLE := 48

# --- layout of the base grid (every scene composes against these) ----------------------
const BASE := Vector2i(480, 270)
const COUNTER_H := 100                       # the counter band hides the customer's lower body
const COUNTER_TOP := BASE.y - COUNTER_H      # 170
const DIALOGUE_RECT := Rect2i(40, 196, 400, 66)
const HUD_MARGIN := 4
const SERVE_RECT := Rect2i(236, 10, 240, 250)
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

## The shared Theme, with the pixel font forced to render unfiltered (the .ttf importer
## defaults to antialiased + hinted, which turns VT323 to mush at x4). Doing it here keeps
## the fix inside the component pool instead of an .import file another lane may rewrite.
static func theme() -> Theme:
	if _theme == null:
		_theme = load(THEME_PATH) as Theme
		if _theme != null:
			_pixelate(_theme.default_font)
	return _theme

## Call once from any scene root's _ready(). Idempotent.
static func prepare() -> void:
	theme()

static func _pixelate(f: Font) -> void:
	var ff := f as FontFile
	if ff == null:
		return
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
