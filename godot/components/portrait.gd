class_name Portrait
extends Control
## A character bust at the counter. The texture is placed at its NATIVE size on integer pixels — never
## scaled — so the pixel grid survives; the counter band in SceneLayers hides the lower body, exactly
## like Coffee Talk. Expression ids and the fallback chain live in Assets.portrait().

@export var portrait_id: String = "char/lena":
	set(v):
		portrait_id = v
		_refresh()

@export var expression: String = "neutral":
	set(v):
		expression = v
		_refresh()

## Idle 1-px breathing. Off when Palette.reduce_motion is set.
@export var breathe: bool = true

var _breath: Tween = null

func _ready() -> void:
	Palette.prepare()
	_refresh()
	_start_breathing()

## Seats the bust by its BOTTOM-CENTRE against the counter: `Palette.PORTRAIT_OVERLAP` base pixels of
## it sit BEHIND the counter layer (docs/02 "Night framing"), with the top clamped to
## `Palette.PORTRAIT_TOP_MIN` so a bust taller than the table assumes keeps its hair inside the frame.
## Bottom-centre, never a spec rectangle: the shipped art is narrower than its placeholder box
## (`char/you_neutral` is 155 px against a 190-px spec), so a left-anchored bust drifts off centre.
## Call it with `SceneLayers.counter_edge()`; it is idempotent and safe outside the tree.
func place_behind(counter_edge_y: int, centre_x: int = Palette.PORTRAIT_CENTRE_X) -> void:
	var bust := get_node_or_null("%Bust") as TextureRect
	var has_art := bust != null and bust.texture != null
	var h := int(bust.size.y) if has_art else int(size.y)
	var w := int(bust.size.x) if has_art else int(size.x)
	if h <= 0:
		return
	var top := counter_edge_y + Palette.PORTRAIT_OVERLAP - h
	position = Palette.snap(Vector2(float(centre_x - w / 2), float(maxi(Palette.PORTRAIT_TOP_MIN, top))))

## Seats a LEANING bust: layered in front of the counter, its bottom edge (the forearms' underside, where
## the sprite ends) `Palette.LEAN_ONTO` px below the counter's back edge, i.e. on the laminate. Bottom-centre
## like place_behind; the top is only clamped if the sprite is taller than the frame above the counter.
func place_on(counter_edge_y: int, centre_x: int = Palette.PORTRAIT_CENTRE_X) -> void:
	var bust := get_node_or_null("%Bust") as TextureRect
	var has_art := bust != null and bust.texture != null
	var h := int(bust.size.y) if has_art else int(size.y)
	var w := int(bust.size.x) if has_art else int(size.x)
	if h <= 0:
		return
	var top := counter_edge_y + Palette.LEAN_ONTO - h
	position = Palette.snap(Vector2(float(centre_x - w / 2), float(maxi(Palette.PORTRAIT_TOP_MIN, top))))

## "leaning" or "behind" — the staging of the bust currently shown (Assets.STAGING mirrors the spec).
func staging() -> String:
	return Assets.staging(portrait_id, expression)

## How many base pixels of the bust the counter actually hides, given where it now sits. The framing
## table wants 25-35; a taller bust than the table assumes reports more, and that is the art's to fix.
func overlap_behind(counter_edge_y: int) -> int:
	var bust := get_node_or_null("%Bust") as TextureRect
	var h := int(bust.size.y) if bust != null and bust.texture != null else int(size.y)
	return int(position.y) + h - counter_edge_y

## `active` is `view.active` — empty hides the bust.
func set_from_active(active: Dictionary) -> void:
	if active.is_empty():
		visible = false
		return
	visible = true
	portrait_id = String(active.get("portrait", "char/oneoff_clubber"))
	expression = String(active.get("expression", "neutral"))

func _refresh() -> void:
	var bust := get_node_or_null("%Bust") as TextureRect
	if bust == null:
		return
	var tex := Assets.portrait(portrait_id, expression)
	bust.texture = tex
	if tex != null:
		bust.size = tex.get_size()
		custom_minimum_size = tex.get_size()
		size = tex.get_size()

## Slide + fade in from the side of the counter (Coffee Talk's customer entrance).
func slide_in(instant: bool = false) -> void:
	visible = true
	var bust := get_node_or_null("%Bust") as TextureRect
	if bust == null:
		return
	if instant or Palette.reduce_motion or not is_inside_tree():
		bust.modulate.a = 1.0
		bust.position = Vector2.ZERO
		return
	bust.modulate.a = 0.0
	bust.position = Vector2(0, 6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bust, "modulate:a", 1.0, 0.25)
	tw.tween_method(_set_entry_offset, 6.0, 0.0, 0.25)

func slide_out(instant: bool = false) -> void:
	var bust := get_node_or_null("%Bust") as TextureRect
	if bust == null:
		return
	if instant or Palette.reduce_motion or not is_inside_tree():
		visible = false
		return
	var tw := create_tween()
	tw.tween_property(bust, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void: visible = false)

func _set_entry_offset(v: float) -> void:
	var bust := get_node_or_null("%Bust") as TextureRect
	if bust != null:
		bust.position = Vector2(0, roundf(v))

func _start_breathing() -> void:
	if not breathe or Palette.reduce_motion or not is_inside_tree():
		return
	var bust := get_node_or_null("%Bust") as TextureRect
	if bust == null:
		return
	_breath = create_tween().set_loops()
	# Stepped, not eased: the bust may only ever sit on whole pixels.
	_breath.tween_method(_set_breath, 0.0, 1.0, 2.4)
	_breath.tween_method(_set_breath, 1.0, 0.0, 2.4)

func _set_breath(t: float) -> void:
	var bust := get_node_or_null("%Bust") as TextureRect
	if bust != null:
		bust.position = Vector2(0, -roundf(t))
