class_name BrandMark
extends Control
## THE one place a brand's mark is drawn (docs/08-register-and-tobacco.md section 2, section 4.1).
##
## A brand is a VARIANT of a SKU, and its whole identity is a shape and a colour. The matching game is
## honest only if the chip on the order card and the facing on the wall are literally the same pixels,
## so both come from here: `set_brand` draws the 16x16 mark window, `set_facing` draws the pack, pouch,
## booklet or box that window is cut out of.
##
## TWO PATHS, one API (docs/08 section 2, "The mark texture costs zero assets"):
##   * shipping — `AtlasTexture(pack, Rect2i(4, 6, 16, 16))`, 1:1, no scaling, legal on the pixel grid;
##   * fallback — when `Assets.is_real(icon)` is false the mark is DRAWN from `{mark, colour}`, so the
##     puzzle is playable and testable on day one and never breaks on art.
## A pixel crop is never resampled, so below 16 px the mark is drawn rather than shrunk — the shapes
## are authored on an 8x8 core (docs/08 section 7: every one of them survives it) and stepped up by
## whole blocks, which is the only way a 12-px chip stays on the grid.
##
## Colours arrive as VALUES through the read-model (`view.counter[].colour`, the wall's cells), never
## as a hex typed into a component — `Palette` still owns every colour this file chooses for itself.

## The mark window inside a facing: fixed at (4,6), 16x16, for every pack/pouch/booklet/box.
const WINDOW_POS := Vector2i(4, 6)
const WINDOW := 16
## The authoring grid every shape is drawn on. 8 divides 16 and 8, which is why those are the sizes.
const GRID := 8

## The shape a `mark` description resolves to, as whole blocks on the 8x8 grid: [x, y, w, h].
## The KEY is a word out of `brands.gd`'s prose description — the data stays the engine lane's, and a
## new brand draws itself the moment its mark names a shape this table knows.
const SHAPES := {
	"chevron": [[0, 2, 2, 2], [2, 4, 2, 2], [4, 4, 2, 2], [6, 2, 2, 2]],
	"star": [[3, 3, 2, 2], [3, 0, 2, 3], [3, 5, 2, 3], [0, 3, 3, 2], [5, 3, 3, 2]],
	"hook": [[2, 0, 4, 2], [2, 2, 2, 2], [2, 4, 4, 2], [4, 6, 2, 2]],
	"pyramid": [[3, 1, 2, 2], [2, 3, 4, 2], [1, 5, 6, 2]],
	"ripple": [[0, 2, 3, 1], [3, 1, 2, 1], [5, 2, 3, 1], [0, 5, 3, 1], [3, 4, 2, 1], [5, 5, 3, 1]],
	"peak": [[3, 1, 2, 2], [2, 3, 2, 2], [4, 3, 2, 2], [1, 5, 6, 2]],
	"ear": [[1, 0, 2, 3], [5, 0, 2, 3], [2, 3, 4, 3], [3, 6, 2, 2]],
	"circle": [[2, 1, 4, 6], [1, 2, 6, 4]],
	"ring": [[0, 3, 2, 2], [3, 3, 2, 2], [6, 3, 2, 2]],
	"spiral": [[1, 1, 6, 2], [1, 3, 2, 3], [3, 4, 4, 2], [5, 2, 2, 2]],
	"spark": [[0, 0, 2, 2], [6, 0, 2, 2], [0, 6, 2, 2], [6, 6, 2, 2], [3, 3, 2, 2]],
	"crown": [[0, 2, 2, 4], [3, 1, 2, 5], [6, 2, 2, 4], [0, 6, 8, 2]],
	"booklet": [[1, 0, 6, 6], [1, 6, 6, 2]],
	"box": [[1, 0, 2, 2], [3, 0, 2, 2], [5, 0, 2, 2], [0, 2, 8, 5]],
}
## Searched in this order: "narrow box, three plain round tips" and "tall booklet, single thin foot
## band" both want the shape word in the phrase, not the first table key that happens to appear in it.
const SHAPE_WORDS := ["chevron", "star", "hook", "pyramid", "ripple", "peak", "ear", "circle",
	"ring", "spiral", "spark", "crown", "booklet", "box"]
## A mark this table cannot read still has to LOOK like a mark, or a content typo draws nothing at all
## and the matching game quietly becomes unwinnable.
const UNKNOWN := [[1, 1, 6, 6], [3, 3, 2, 2]]

## The brand row as the read-model handed it over: {mark, colour, band, size, icon}. Every key is
## optional — `view.counter` carries mark + colour and nothing else, and that is enough to draw.
var brand: Dictionary = {}
## 8 / 12 / 16 for a chip; 0 means "draw the whole facing at its own footprint".
var mark_px: int = WINDOW

func _ready() -> void:
	Palette.prepare()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()

## The chip: a swatch of the brand's own colour with its mark punched out in the band colour — which
## is exactly what the atlas window of the facing contains, so chip and facing cannot disagree.
func set_brand(row: Dictionary, px: int = WINDOW) -> void:
	brand = row
	mark_px = clampi(px, GRID, WINDOW)
	_rebuild()

## The whole facing (pack / pouch / booklet / box) at its documented footprint.
func set_facing(row: Dictionary) -> void:
	brand = row
	mark_px = 0
	_rebuild()

## The footprint a facing occupies: the brand row's own `size` first (brands.gd carries the intended
## one), then `Assets.size_of` for the facing id, so the wall's grid is right before the art lands.
static func facing_size(row: Dictionary) -> Vector2i:
	var declared: Array = row.get("size", [])
	if declared.size() == 2:
		return Vector2i(int(declared[0]), int(declared[1]))
	return Assets.size_of(String(row.get("icon", "")))

## A colour out of the read-model. Values, never literals — and a row that carries none falls back to
## a Palette token rather than to an invented hex.
static func colour_of(row: Dictionary, key: String, fallback: Color) -> Color:
	var raw := String(row.get(key, ""))
	if raw != "" and Color.html_is_valid(raw):
		return Color.html(raw)
	return fallback

## A read-model row, completed from the brand catalogue. `view.wall`'s cells carry the identity the
## player needs (mark, colour, name) but not the facing's `icon`, `band` or `size`, and a component
## that guessed those would be inventing content — so the static registry fills the gaps and anything
## the VIEW said wins, which keeps the engine the authority on everything it chose to say.
static func merge(row: Dictionary) -> Dictionary:
	var base: Dictionary = Content.brand(String(row.get("brand", row.get("id", "")))).duplicate(true)
	for k in row:
		var v: Variant = row[k]
		if v is String and String(v) == "":
			continue
		base[k] = v
	return base

## Which shape a mark description draws.
static func shape_of(mark: String) -> Array:
	var lower := mark.to_lower()
	for word in SHAPE_WORDS:
		if lower.contains(String(word)):
			return SHAPES[word]
	return UNKNOWN

# -- drawing -------------------------------------------------------------------------------------

func _rebuild() -> void:
	# A mark is DECORATION and must never eat a click: it sits inside tray slots, register rows, wall
	# cells and order chips, every one of which is the thing the pointer is actually aiming at. Set
	# here and not only in `_ready`, because a runtime-built mark may never enter a tree at all.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in get_children():
		remove_child(c)
		c.queue_free()
	if brand.is_empty():
		custom_minimum_size = Vector2.ZERO
		return
	if mark_px == 0:
		_build_facing()
	else:
		_build_chip(mark_px)

## A 16 (or 12, or 8) px chip. With real art it is the atlas crop; without it, the drawn mark.
func _build_chip(px: int) -> void:
	custom_minimum_size = Vector2(px, px)
	size = Vector2(px, px)
	var icon := String(brand.get("icon", brand.get("pack_id", "")))
	if px == WINDOW and Assets.is_real(icon):
		add_child(_atlas(icon, Rect2i(WINDOW_POS, Vector2i(WINDOW, WINDOW)), Vector2.ZERO))
		return
	var body := colour_of(brand, "colour", Palette.TEXT_DIM)
	_block(self, Vector2.ZERO, Vector2i(px, px), body)
	_draw_mark(self, Vector2.ZERO, px, _ink(body))
	_edge(self, Vector2i(px, px))

## The facing itself: the real sprite when it exists, else the silhouette in the brand's colour with
## its band and its mark in the documented 16x16 window at (4,6).
func _build_facing() -> void:
	var sz := facing_size(brand)
	custom_minimum_size = Vector2(sz)
	size = Vector2(sz)
	var icon := String(brand.get("icon", brand.get("pack_id", "")))
	if Assets.is_real(icon):
		var art := TextureRect.new()
		art.name = "Art"
		art.texture = Assets.texture(icon)
		art.size = Vector2(sz)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art)
		return
	var body := colour_of(brand, "colour", Palette.TEXT_DIM)
	var band := colour_of(brand, "band", _ink(body))
	_block(self, Vector2.ZERO, sz, body)
	# The band is the lower third of a pack or a pouch and a foot strip on a booklet or a box; both are
	# "the bottom of the silhouette", so one rule draws both and the proportion does the talking.
	var band_h := maxi(2, int(round(float(sz.y) / 5.0)))
	_block(self, Vector2(0, float(sz.y - band_h)), Vector2i(sz.x, band_h), band)
	_draw_mark(self, Vector2(WINDOW_POS), WINDOW, band)
	_edge(self, sz)

## The mark, on the 8x8 grid, stepped up by whole blocks and centred in its window.
func _draw_mark(parent: Control, at: Vector2, px: int, col: Color) -> void:
	var block := maxi(1, px / GRID)
	var inset := Vector2(float(px - GRID * block) * 0.5, float(px - GRID * block) * 0.5)
	for b in shape_of(String(brand.get("mark", ""))):
		var r: Array = b
		_block(parent, at + inset + Vector2(float(int(r[0]) * block), float(int(r[1]) * block)),
			Vector2i(int(r[2]) * block, int(r[3]) * block), col)

## A whole-pixel block. ColorRects, not a `_draw()`, so a chip is a real node tree the user can open
## in the editor — the same choice `QueueStrip` made for its silhouettes.
func _block(parent: Control, at: Vector2, block_size: Vector2i, col: Color) -> void:
	var r := ColorRect.new()
	r.color = col
	r.position = Palette.snap(at)
	r.size = Vector2(block_size)
	r.custom_minimum_size = Vector2(block_size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

## A 1-px contour, so a pale facing (Perle, Feder) does not dissolve into the shelf behind it.
func _edge(parent: Control, sz: Vector2i) -> void:
	var line := ReferenceRect.new()
	line.name = "Edge"
	line.border_color = Palette.SHADOW
	line.border_width = 1.0
	line.editor_only = false
	line.size = Vector2(sz)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

## An atlas crop of the real art, placed 1:1.
func _atlas(icon: String, region: Rect2i, at: Vector2) -> TextureRect:
	var tex := AtlasTexture.new()
	tex.atlas = Assets.texture(icon)
	tex.region = Rect2(region)
	var rect := TextureRect.new()
	rect.name = "Mark"
	rect.texture = tex
	rect.position = Palette.snap(at)
	rect.size = Vector2(region.size)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

## What to print a mark in when the row carries no band colour: the readable extreme of the body.
static func _ink(body: Color) -> Color:
	return Palette.INK_DEEP if body.get_luminance() > 0.5 else Palette.TEXT
