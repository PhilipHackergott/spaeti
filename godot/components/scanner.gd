class_name Scanner
extends Control
## The glass on the counter (docs/08-register-and-tobacco.md section 1, section 4.1). Drag an item over
## it and the glass arms; release and the item is `scan{uid}`. It is a member of the
## `Palette.DROP_TARGETS` group, so `DragLayer` finds it without anybody wiring a reference.
##
## Its hot zone bleeds `Palette.SCANNER_BLEED` px on every side — at x4 that is 16 screen px of slack
## on each edge, which is the difference between a generous drop and a fiddly one.
##
## It emits an INTENT, never an action: `scanned(uid)`. The scene turns that into the dictionary, so a
## component can never invent a uid the reducer has not got on `active.counter`.

signal scanned(uid: int)
## Pressed or `ui_accept`ed with nothing in flight: the keyboard's "drop what I am carrying here".
signal activated()

var _armed: bool = false

## Has `_boot` run? See `_boot`.
var _booted: bool = false

func _ready() -> void:
	_boot()

## docs/04 rule 2 (tree-optional): the work `_ready` does is done on FIRST USE instead of waiting for
## a tree that a capture, a test or a driver may never give this instance. Idempotent.
func _boot() -> void:
	if _booted:
		return
	_booted = true
	Palette.prepare()
	position = Vector2(Palette.SCANNER_RECT.position)
	custom_minimum_size = Vector2(Palette.SCANNER_RECT.size)
	size = Vector2(Palette.SCANNER_RECT.size)
	# Reachable by pointer AND by keyboard: the focus ring is what makes "Space drops it here" a real
	# path rather than a mouse-only convenience (docs/08 section 4.2).
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(Palette.DROP_TARGETS)
	var plate := get_node_or_null("%Plate") as PanelContainer
	if plate != null:
		plate.add_theme_stylebox_override("panel", Palette.box(Palette.INK_DEEP, Palette.EDGE, 2, 1))
	var art := get_node_or_null("%Art") as TextureRect
	if art != null:
		art.texture = Assets.texture("prop/scanner")
		var sz := Assets.size_of("prop/scanner")
		art.size = Vector2(sz)
		art.position = Palette.snap((Vector2(Palette.SCANNER_RECT.size) - Vector2(sz)) * 0.5)
	set_armed(false)

## The rect a drop is tested against: the glass plus the bleed, in the screen's base-pixel space.
func hot_zone() -> Rect2:
	_boot()
	return get_global_rect().grow(float(Palette.SCANNER_BLEED))

## The scanner takes any counter item that has not been scanned yet. It does NOT take the Pfand crate:
## empties are a deposit, not a sale, and the register's Pfand row is where they go (docs/08 3.5).
func accepts(payload: Dictionary) -> bool:
	return String(payload.get("kind", "")) == "item" and int(payload.get("uid", -1)) >= 0

## `DragLayer` calls this after it has picked this target; it is also what the keyboard path calls.
func take(payload: Dictionary) -> void:
	if not accepts(payload):
		return
	flash()
	scanned.emit(int(payload.get("uid", -1)))

## The glass goes accent the moment a carried item's centre enters the hot zone.
func set_armed(on: bool) -> void:
	_boot()
	_armed = on
	var glass := get_node_or_null("%Glass") as ColorRect
	if glass == null:
		return
	glass.color = Palette.ACCENT if on else Palette.NIGHT_DEEP
	glass.modulate.a = 0.30 if on else 1.0

func is_armed() -> bool:
	return _armed

## Two frames of white on a successful read — the first of the three confirmations (sound, line, tick).
func flash() -> void:
	var glass := get_node_or_null("%Glass") as ColorRect
	if glass == null or not is_inside_tree() or Palette.reduce_motion:
		return
	glass.color = Palette.TEXT_WHITE
	var tw := create_tween()
	tw.tween_interval(2.0 / 60.0)
	tw.tween_callback(set_armed.bind(_armed))

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		activated.emit()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		activated.emit()
		accept_event()
