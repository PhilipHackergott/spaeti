class_name SceneLayers
extends Control
## The set: backdrop, neon glow, the customer slot, the counter band, rain on the glass and the
## time-of-night tint — in that order, so a bust mounted in `Characters` stands behind the counter
## exactly like Coffee Talk. Everything here is either a generated asset (Assets) or code-drawn FX;
## no scene ever draws its own backdrop.

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

const DUSK := Color(0.95, 0.62, 0.30, 0.12)
const DEEP := Color(0.10, 0.16, 0.32, 0.20)
const DAWN := Color(0.18, 0.42, 0.66, 0.30)
const RAIN_SPEED := 90.0

var _rng := RandomNumberGenerator.new()
var _speeds: Array[float] = []

func _ready() -> void:
	Palette.prepare()
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

func _refresh_art() -> void:
	var back := get_node_or_null("%Backdrop") as TextureRect
	if back == null:
		return
	back.texture = Assets.texture(backdrop_id)
	var counter := get_node_or_null("%Counter") as TextureRect
	if counter != null:
		var tex := Assets.texture(counter_id)
		counter.texture = tex
		if tex != null:
			# The counter band is always flush with the bottom of the frame, whatever height the
			# art turns out to be, so the customer's lower body is hidden exactly as in Coffee Talk.
			counter.size = tex.get_size()
			counter.position = Vector2(0, float(Palette.BASE.y) - tex.get_size().y)

func _refresh_tint() -> void:
	var tint := get_node_or_null("%Tint") as ColorRect
	if tint == null:
		return
	var c: Color
	if night_progress < 0.5:
		c = DUSK.lerp(DEEP, night_progress / 0.5)
	else:
		c = DEEP.lerp(DAWN, (night_progress - 0.5) / 0.5)
	tint.color = c
	var glow := get_node_or_null("%NeonGlow") as ColorRect
	if glow != null:
		glow.color = Color(Palette.NEON_MAGENTA.r, Palette.NEON_MAGENTA.g, Palette.NEON_MAGENTA.b, 0.10)

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
	# Seeded so a capture of the same preset always has the same streaks.
	_rng.seed = 1337
	for i in rain_drops:
		var streak := Line2D.new()
		streak.width = 1.0
		streak.default_color = Color(Palette.NEON_CYAN.r, Palette.NEON_CYAN.g, Palette.NEON_CYAN.b, _rng.randf_range(0.10, 0.26))
		streak.add_point(Vector2.ZERO)
		streak.add_point(Vector2(-1, _rng.randf_range(5.0, 11.0)))
		streak.position = Vector2(float(_rng.randi_range(0, Palette.BASE.x)), float(_rng.randi_range(-40, Palette.COUNTER_TOP)))
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
		if y > float(Palette.COUNTER_TOP):
			y = -12.0
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
