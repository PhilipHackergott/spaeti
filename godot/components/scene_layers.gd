class_name SceneLayers
extends Control
## The set, in draw order: backdrop, neon glow, RAIN ON THE GLASS, the customer slot, the counter
## band, the time-of-night tint — so a bust mounted in `Characters` stands behind the counter exactly
## like Coffee Talk, and the rain runs down the door/window *behind* everyone instead of falling
## inside the shop (verify round 3: it was drawn over the whole frame at α 0.1 and was invisible).
## Everything here is either a generated asset (Assets) or code-drawn FX; no scene draws its own set.

@export var backdrop_id: String = "scene/backdrop":
	set(v):
		backdrop_id = v
		_refresh_art()

@export var counter_id: String = "scene/counter":
	set(v):
		counter_id = v
		_refresh_art()

## 0 = dusk (warm amber), 0.5 = deep night (blue), 1 = pre-dawn (cold cola-blue).
@export_range(0.0, 1.0, 0.01) var night_progress: float = 0.3:
	set(v):
		night_progress = clampf(v, 0.0, 1.0)
		_refresh_tint()

@export var raining: bool = true:
	set(v):
		raining = v
		_rebuild_rain()

@export var rain_drops: int = 16:
	set(v):
		rain_drops = clampi(v, 0, 64)
		_rebuild_rain()

@export var neon: bool = true

const RAIN_SPEED := 90.0

var _rng := RandomNumberGenerator.new()
var _speeds: Array[float] = []
## Cached result of counter_edge(); -1 = not measured yet (the art may still be a placeholder).
var _edge: int = -1

func _ready() -> void:
	Palette.prepare()
	# Every colour on the set is a Palette token — a component may not write a hex either (docs/04 rule 1).
	var glow := get_node_or_null("%NeonGlow") as ColorRect
	if glow != null:
		glow.color = Palette.NEON_GLOW
	_refresh_art()
	_refresh_tint()
	_rebuild_rain()
	_flicker()
	set_process(raining and not Palette.reduce_motion)

## Where the customer bust goes: in front of the backdrop, behind the counter.
func mount(node: Node) -> void:
	var slot := get_node_or_null("%Characters") as Control
	if slot == null or node == null or node.get_parent() == slot:
		return
	# reparent() keeps `owner`; remove_child()+add_child() would clear it and with it the node's
	# scene-unique name (%Portrait would stop resolving and the bust would vanish).
	var keep_owner := node.owner
	if node.is_inside_tree() and node.get_parent() != null:
		node.reparent(slot, false)
	else:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		slot.add_child(node)
	if keep_owner != null:
		node.owner = keep_owner

func set_time(progress: float) -> void:
	night_progress = progress

## Where the counter band starts on screen — the line a bust is cut off at.
func counter_top() -> int:
	var counter := get_node_or_null("%Counter") as TextureRect
	if counter == null or counter.texture == null:
		return Palette.COUNTER_TOP
	return Palette.BASE.y - int(counter.texture.get_size().y)

## The row where the counter art actually becomes OPAQUE across the frame — the real occlusion line,
## which is lower than `counter_top()` because the crate, cup and register stand above the surface.
## A bust is placed against this (`Portrait.place_behind`), so the framing survives a counter asset of
## any height (docs/02 "Night framing"). Measured once from the texture's alpha and cached.
func counter_edge() -> int:
	var counter := get_node_or_null("%Counter") as TextureRect
	if counter == null or counter.texture == null:
		return Palette.COUNTER_TOP
	if _edge < 0:
		_edge = int(counter.position.y) + _opaque_row(counter.texture)
	return _edge

## First row that is opaque across (almost) the whole width. Sampled every 4th column — the art is
## pixel clusters, not noise, so a 4-px stride cannot miss a solid band.
static func _opaque_row(tex: Texture2D) -> int:
	var img := tex.get_image()
	if img == null:
		return 0
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var samples := int(ceil(float(w) / 4.0))
	for y in h:
		var opaque := 0
		for x in range(0, w, 4):
			if img.get_pixel(x, y).a > 0.8:
				opaque += 1
		if opaque >= samples - 1:
			return y
	return 0

func _refresh_art() -> void:
	var back := get_node_or_null("%Backdrop") as TextureRect
	if back == null:
		return
	back.texture = Assets.texture(backdrop_id)
	var counter := get_node_or_null("%Counter") as TextureRect
	if counter != null:
		var tex := Assets.texture(counter_id)
		counter.texture = tex
		_edge = -1  # a new counter asset re-measures its own occlusion line
		if tex != null:
			# The counter band hangs from `COUNTER_LIFT` above the bottom of the frame (its lowest rows are
			# under the dialogue panel anyway), whatever height the art turns out to be, so the customer's
			# lower body is hidden exactly as in Coffee Talk and a real countertop band stays readable.
			counter.size = tex.get_size()
			counter.position = Vector2(0, float(Palette.BASE.y - Palette.COUNTER_LIFT) - tex.get_size().y)

const LIGHT_SHADER := preload("res://components/light_pool.gdshader")

## The time-of-night light is SHAPED, not flat (2026-09-13): a warm fluorescent pool over the counter and
## the customer that falls off, in stepped bands, into the cool night at the fridge and the door. The
## ColorRect keeps a flat colour only as the fallback when the shader is unavailable (headless import).
func _refresh_tint() -> void:
	var tint := get_node_or_null("%Tint") as ColorRect
	if tint == null:
		return
	var warm: Color
	var cool: Color
	if night_progress < 0.5:
		var t := night_progress / 0.5
		warm = Palette.LIGHT_POOL_DUSK.lerp(Palette.LIGHT_POOL_NIGHT, t)
		cool = Palette.LIGHT_EDGE_DUSK.lerp(Palette.LIGHT_EDGE_NIGHT, t)
	else:
		var t2 := (night_progress - 0.5) / 0.5
		warm = Palette.LIGHT_POOL_NIGHT.lerp(Palette.LIGHT_POOL_DAWN, t2)
		cool = Palette.LIGHT_EDGE_NIGHT.lerp(Palette.LIGHT_EDGE_DAWN, t2)
	var mat := tint.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = LIGHT_SHADER
		tint.material = mat
	tint.color = Color.WHITE   # the shader paints; the rect's own colour must not multiply into it
	mat.set_shader_parameter("warm", warm)
	mat.set_shader_parameter("cool", cool)
	mat.set_shader_parameter("centre", Vector2(float(Palette.PORTRAIT_CENTRE_X) / float(Palette.BASE.x), 0.62))
	mat.set_shader_parameter("radius", 0.62)
	mat.set_shader_parameter("steps", 4)

func _rebuild_rain() -> void:
	var rain := get_node_or_null("%Rain") as Node2D
	if rain == null:
		return
	for c in rain.get_children():
		rain.remove_child(c)
		c.queue_free()
	_speeds.clear()
	if not raining:
		return
	# Seeded so a capture of the same preset always has the same streaks. They fall inside
	# `Palette.RAIN_RECT` — the door/window opening on the right of the backdrop — and nowhere else.
	_rng.seed = 1337
	var r := Palette.RAIN_RECT
	for i in rain_drops:
		var streak := Line2D.new()
		streak.width = 1.0
		streak.default_color = Palette.RAIN
		streak.add_point(Vector2.ZERO)
		streak.add_point(Vector2(-1, _rng.randf_range(4.0, 9.0)))
		streak.position = Vector2(float(_rng.randi_range(r.position.x, r.end.x - 1)), float(_rng.randi_range(r.position.y - 40, r.end.y)))
		rain.add_child(streak)
		_speeds.append(_rng.randf_range(0.7, 1.4))
	set_process(not Palette.reduce_motion)

func _process(delta: float) -> void:
	var rain := get_node_or_null("%Rain") as Node2D
	if rain == null or not raining:
		return
	for i in rain.get_child_count():
		var streak := rain.get_child(i) as Line2D
		if streak == null:
			continue
		var speed: float = _speeds[i] if i < _speeds.size() else 1.0
		var y := streak.position.y + RAIN_SPEED * speed * delta
		if y > float(Palette.RAIN_RECT.end.y):
			y = float(Palette.RAIN_RECT.position.y - 12)
		streak.position = Vector2(streak.position.x, roundf(y))

func _flicker() -> void:
	var glow := get_node_or_null("%NeonGlow") as ColorRect
	if glow == null or not neon or Palette.reduce_motion or not is_inside_tree():
		return
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.55, 1.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "modulate:a", 1.0, 0.12)
	tw.tween_property(glow, "modulate:a", 0.75, 0.09)
	tw.tween_property(glow, "modulate:a", 1.0, 2.3).set_trans(Tween.TRANS_SINE)
