class_name Assets
extends RefCounted
## The asset seam. `Assets.texture(id)` returns the real bitmap from res://assets/<id>.png when the
## art lane has produced it, and a generated placeholder of the EXACT base-pixel size from
## docs/asset-spec.json when it has not. Every component asks for art through here, so final art
## drops in with no code change and every screen is capturable today.

const ROOT := "res://assets/"

## id -> base-pixel size, mirrored from docs/asset-spec.json. A placeholder must occupy the same
## footprint as the final art, or the composition would shift the day the art lands.
## The mirror is not trusted to stay honest by hand: test_scenes.gd::test_asset_sizes_match_the_spec
## reads docs/asset-spec.json and fails the moment this table and the spec disagree.
const SIZES := {
	"scene/backdrop": Vector2i(480, 270),
	"scene/counter": Vector2i(480, 130),
	"scene/title": Vector2i(480, 270),
	"char/you_neutral": Vector2i(144, 174),
	"char/lena_neutral": Vector2i(144, 174),
	"char/lena_warm": Vector2i(144, 174),
	"char/lena_upset": Vector2i(144, 174),
	"char/juergen_neutral": Vector2i(144, 174),
	"char/juergen_warm": Vector2i(144, 174),
	"char/mehmet_neutral": Vector2i(144, 174),
	"char/brandt_neutral": Vector2i(144, 174),
	"char/tobias_neutral": Vector2i(144, 174),
	"char/schulz_neutral": Vector2i(144, 174),
	"char/nadia_neutral": Vector2i(144, 174),
	"char/mehmet_warm": Vector2i(144, 174),
	"char/mehmet_wary": Vector2i(144, 174),
	"char/brandt_wary": Vector2i(144, 174),
	"char/tobias_warm": Vector2i(144, 174),
	"char/tobias_upset": Vector2i(144, 174),
	"char/schulz_wary": Vector2i(144, 174),
	"char/nadia_warm": Vector2i(144, 174),
	"char/nadia_upset": Vector2i(144, 174),
	"char/oneoff_clubber_neutral": Vector2i(144, 174),
	"char/oneoff_tourist_neutral": Vector2i(144, 174),
	"sku/beer": Vector2i(14, 36),
	"sku/mate": Vector2i(14, 36),
	"sku/cola": Vector2i(14, 36),
	"sku/water": Vector2i(14, 36),
	"sku/chips": Vector2i(26, 32),
	"sku/chocolate": Vector2i(30, 14),
	"sku/gummi": Vector2i(24, 28),
	"sku/cigarettes": Vector2i(22, 30),
	"sku/lighter": Vector2i(10, 24),
	"sku/coffee": Vector2i(22, 22),
	"sku/energy": Vector2i(14, 36),
	"sku/schrippe": Vector2i(26, 30),
	"sku/tobacco": Vector2i(26, 30),
	"sku/papers": Vector2i(22, 26),
	"sku/tp": Vector2i(26, 30),
	"sku/condoms": Vector2i(22, 26),
	"sku/batteries": Vector2i(24, 26),
	"sku/painkillers": Vector2i(22, 26),
	"sku/currywurst": Vector2i(26, 30),
	"sku/icecream": Vector2i(14, 36),
	"sku/milk": Vector2i(14, 36),
	"sku/eggs": Vector2i(26, 30),
	"sku/vape": Vector2i(14, 36),
	"ui/icon_clock": Vector2i(16, 16),
	"ui/icon_cash": Vector2i(16, 16),
	"ui/icon_pfand": Vector2i(16, 16),
	"ui/icon_trust": Vector2i(16, 16),
	"ui/icon_profit": Vector2i(16, 16),
}

const FALLBACK_SIZE := Vector2i(32, 32)
const NEIGHBOURS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static var _cache: Dictionary = {}

static func path_of(id: String) -> String:
	return ROOT + id + ".png"

## True once the art lane has produced (and Godot has imported) the real bitmap.
static func is_real(id: String) -> bool:
	return id != "" and ResourceLoader.exists(path_of(id))

static func size_of(id: String) -> Vector2i:
	return SIZES.get(id, FALLBACK_SIZE)

## The one call every component makes. Never returns null for a non-empty id.
static func texture(id: String) -> Texture2D:
	if id == "":
		return null
	if _cache.has(id):
		return _cache[id]
	var tex: Texture2D = null
	if ResourceLoader.exists(path_of(id)):
		tex = load(path_of(id)) as Texture2D
	if tex == null:
		tex = _placeholder(id)
	_cache[id] = tex
	return tex

## Portrait id from the read-model ("char/lena") + expression -> "char/lena_warm", falling back to
## _neutral and then to whatever the id resolves to as a placeholder (docs/05 section 6).
static func portrait(portrait_id: String, expression: String = "neutral") -> Texture2D:
	var pid := portrait_id if portrait_id != "" else "char/oneoff_clubber"
	var exp_name := expression if expression != "" else "neutral"
	# Resolve the EXPRESSION first, then ask for a texture. An expression we have neither art nor a
	# documented size for is not a portrait we know at all, so it falls back to _neutral (docs/05 §6)
	# — otherwise the placeholder would come back at FALLBACK_SIZE and the bust would shrink to 32px.
	var id := pid + "_" + exp_name
	var neutral := pid + "_neutral"
	# docs/05 section 6: a missing expression falls back to _neutral. There are two ways it can be
	# missing - no spec entry at all (a placeholder would then collapse to FALLBACK_SIZE), or a spec
	# entry whose PNG the art lane has not drawn yet while the neutral one IS on disk. The second is
	# the common case mid-production, and a stamped placeholder beside a finished bust reads as a
	# broken character rather than as an unfinished expression (talk_result, first capture).
	if not is_real(id) and (not SIZES.has(id) or is_real(neutral)):
		id = neutral
	return texture(id)

static func clear_cache() -> void:
	_cache.clear()

# --- placeholders ---------------------------------------------------------------------------
# Flat, obviously-unfinished shapes in a hashed colour with the id stamped on them. They carry the
# right silhouette (bust / bottle / room) so framing and legibility can be judged before art lands.

static func _placeholder(id: String) -> ImageTexture:
	var sz := size_of(id)
	var img := Image.create_empty(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := _hash_colour(id)
	if id.begins_with("char/"):
		col = Color.from_hsv(col.h, 0.26, 0.44, 1.0)
		_draw_bust(img, col)
		_outline(img, Color(0.06, 0.04, 0.05, 1.0))
	elif id.begins_with("scene/"):
		_draw_room(img, id, col)
	elif id.begins_with("ui/"):
		_draw_icon(img, col)
		_outline(img, Color(0.06, 0.04, 0.05, 1.0))
	else:
		_draw_prop(img, col)
		_outline(img, Color(0.06, 0.04, 0.05, 1.0))
	_stamp_id(img, id)
	return ImageTexture.create_from_image(img)

static func _hash_colour(id: String) -> Color:
	var h := absi(id.hash())
	return Color.from_hsv(float(h % 360) / 360.0, 0.40, 0.56, 1.0)

static func _rect(img: Image, r: Rect2i, col: Color) -> void:
	var clipped := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	img.fill_rect(clipped, col)

static func _disc(img: Image, c: Vector2i, rad: int, col: Color) -> void:
	for y in range(maxi(0, c.y - rad), mini(img.get_height(), c.y + rad + 1)):
		for x in range(maxi(0, c.x - rad), mini(img.get_width(), c.x + rad + 1)):
			var dx := x - c.x
			var dy := y - c.y
			if dx * dx + dy * dy <= rad * rad:
				img.set_pixel(x, y, col)

## Head-and-shoulders silhouette: the placeholder has to stand at the counter like a Coffee Talk bust.
static func _draw_bust(img: Image, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var dark := col.darkened(0.35)
	var shoulder_top := int(h * 0.58)
	_rect(img, Rect2i(int(w * 0.08), shoulder_top, int(w * 0.84), h - shoulder_top), dark)
	_rect(img, Rect2i(int(w * 0.02), shoulder_top + int(h * 0.10), int(w * 0.96), h), dark)
	_rect(img, Rect2i(int(w * 0.42), int(h * 0.44), int(w * 0.16), int(h * 0.18)), col.darkened(0.15))
	_disc(img, Vector2i(w / 2, int(h * 0.28)), int(h * 0.20), col)
	_rect(img, Rect2i(int(w * 0.30), int(h * 0.09), int(w * 0.40), int(h * 0.11)), col.darkened(0.5))

static func _draw_room(img: Image, id: String, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if id == "scene/counter":
		_rect(img, Rect2i(0, 0, w, h), Color(0.29, 0.18, 0.11, 1.0))
		_rect(img, Rect2i(0, 0, w, 3), Color(0.48, 0.30, 0.17, 1.0))
		_rect(img, Rect2i(0, 3, w, 2), Color(0.16, 0.10, 0.06, 1.0))
		_rect(img, Rect2i(0, h - 16, w, 16), Color(0.13, 0.08, 0.05, 1.0))
		return
	_rect(img, Rect2i(0, 0, w, h), Color(0.16, 0.10, 0.07, 1.0))
	_rect(img, Rect2i(0, 0, w, int(h * 0.16)), Color(0.11, 0.07, 0.05, 1.0))
	_rect(img, Rect2i(int(w * 0.02), int(h * 0.06), int(w * 0.26), int(h * 0.52)), Color(0.10, 0.16, 0.26, 1.0))
	_rect(img, Rect2i(int(w * 0.04), int(h * 0.10), int(w * 0.22), 6), Color(1.0, 0.31, 0.85, 1.0))
	_rect(img, Rect2i(int(w * 0.72), int(h * 0.08), int(w * 0.24), int(h * 0.46)), Color(0.14, 0.24, 0.30, 1.0))
	for i in 3:
		var y := int(h * (0.24 + 0.13 * i))
		_rect(img, Rect2i(int(w * 0.34), y - 10, int(w * 0.30), 10), col.darkened(0.45))
		_rect(img, Rect2i(int(w * 0.32), y, int(w * 0.36), 2), Color(0.35, 0.22, 0.13, 1.0))
	_rect(img, Rect2i(0, int(h * 0.63), w, h - int(h * 0.63)), Color(0.09, 0.06, 0.04, 1.0))

static func _draw_prop(img: Image, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if h > w + 4:
		_rect(img, Rect2i(1, int(h * 0.28), w - 2, h - int(h * 0.28) - 1), col)
		_rect(img, Rect2i(int(w * 0.32), 1, maxi(2, int(w * 0.36)), int(h * 0.30)), col.darkened(0.15))
		_rect(img, Rect2i(1, int(h * 0.52), w - 2, maxi(3, int(h * 0.20))), col.lightened(0.30))
	else:
		_rect(img, Rect2i(1, 1, w - 2, h - 2), col)
		_rect(img, Rect2i(2, int(h * 0.40), w - 4, maxi(2, int(h * 0.25))), col.lightened(0.30))

static func _draw_icon(img: Image, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	_disc(img, Vector2i(w / 2, h / 2), mini(w, h) / 2 - 1, col)
	_rect(img, Rect2i(w / 2 - 1, 3, 2, h / 2 - 2), col.darkened(0.55))

## One dark pixel around every opaque silhouette (the style brief's clean 1-px outline).
static func _outline(img: Image, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var edge: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in NEIGHBOURS:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
					continue
				if img.get_pixel(n.x, n.y).a > 0.5:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		img.set_pixel(p.x, p.y, col)

# --- the 3x5 stamp font (a placeholder says what it is without needing a font resource) -------

const GLYPHS := {
	"A": [0b010, 0b101, 0b111, 0b101, 0b101], "B": [0b110, 0b101, 0b110, 0b101, 0b110],
	"C": [0b011, 0b100, 0b100, 0b100, 0b011], "D": [0b110, 0b101, 0b101, 0b101, 0b110],
	"E": [0b111, 0b100, 0b110, 0b100, 0b111], "F": [0b111, 0b100, 0b110, 0b100, 0b100],
	"G": [0b011, 0b100, 0b101, 0b101, 0b011], "H": [0b101, 0b101, 0b111, 0b101, 0b101],
	"I": [0b111, 0b010, 0b010, 0b010, 0b111], "J": [0b001, 0b001, 0b001, 0b101, 0b010],
	"K": [0b101, 0b101, 0b110, 0b101, 0b101], "L": [0b100, 0b100, 0b100, 0b100, 0b111],
	"M": [0b101, 0b111, 0b111, 0b101, 0b101], "N": [0b101, 0b111, 0b111, 0b111, 0b101],
	"O": [0b010, 0b101, 0b101, 0b101, 0b010], "P": [0b110, 0b101, 0b110, 0b100, 0b100],
	"Q": [0b010, 0b101, 0b101, 0b110, 0b011], "R": [0b110, 0b101, 0b110, 0b101, 0b101],
	"S": [0b011, 0b100, 0b010, 0b001, 0b110], "T": [0b111, 0b010, 0b010, 0b010, 0b010],
	"U": [0b101, 0b101, 0b101, 0b101, 0b011], "V": [0b101, 0b101, 0b101, 0b101, 0b010],
	"W": [0b101, 0b101, 0b111, 0b111, 0b101], "X": [0b101, 0b101, 0b010, 0b101, 0b101],
	"Y": [0b101, 0b101, 0b010, 0b010, 0b010], "Z": [0b111, 0b001, 0b010, 0b100, 0b111],
	"0": [0b111, 0b101, 0b101, 0b101, 0b111], "1": [0b010, 0b110, 0b010, 0b010, 0b111],
	"2": [0b110, 0b001, 0b010, 0b100, 0b111], "3": [0b111, 0b001, 0b011, 0b001, 0b111],
	"4": [0b101, 0b101, 0b111, 0b001, 0b001], "5": [0b111, 0b100, 0b110, 0b001, 0b110],
	"6": [0b011, 0b100, 0b110, 0b101, 0b010], "7": [0b111, 0b001, 0b010, 0b010, 0b010],
	"8": [0b010, 0b101, 0b010, 0b101, 0b010], "9": [0b010, 0b101, 0b011, 0b001, 0b110],
	"/": [0b001, 0b001, 0b010, 0b100, 0b100], "_": [0b000, 0b000, 0b000, 0b000, 0b111],
	"-": [0b000, 0b000, 0b111, 0b000, 0b000], ".": [0b000, 0b000, 0b000, 0b000, 0b010],
	" ": [0b000, 0b000, 0b000, 0b000, 0b000],
}

static func _stamp_id(img: Image, id: String) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if w < 20 or h < 12:
		return
	# On a bust the label goes on the chest: the bottom of the image is behind the counter.
	var baseline := h - 9 if not id.begins_with("char/") else int(h * 0.68)
	# The CATEGORY is already obvious from the silhouette (bust / bottle / room / disc), so the stamp
	# carries the leaf name and keeps its HEAD when it still will not fit. Keeping the tail is what
	# printed "FFEE", "COLATE" and "TTES" on the narrow props (verify round 3).
	var text := id.substr(id.rfind("/") + 1).to_upper()
	var max_chars := int((w - 4) / 4)
	if max_chars <= 0:
		return
	if text.length() > max_chars:
		text = text.substr(0, max_chars)
	var tw := text.length() * 4
	var x0 := maxi(1, (w - tw) / 2)
	var y0 := baseline
	_rect(img, Rect2i(x0 - 2, y0 - 2, tw + 3, 9), Color(0, 0, 0, 0.62))
	for i in text.length():
		var rows: Array = GLYPHS.get(text[i], GLYPHS[" "])
		for r in 5:
			var bits: int = rows[r]
			for c in 3:
				if (bits >> (2 - c)) & 1:
					var px := x0 + i * 4 + c
					var py := y0 + r
					if px >= 0 and py >= 0 and px < w and py < h:
						img.set_pixel(px, py, Color(0.95, 0.88, 0.76, 0.95))
