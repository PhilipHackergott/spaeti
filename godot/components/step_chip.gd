class_name StepChip
extends Panel
## A one-glyph plate for a table row: the register's `-` / `+` / `x` (docs/08-register-and-tobacco.md
## section 4.1), and anything else that has to be pressable inside a row the font does not fit.
##
## **Why it is not a `Button`.** Jersey 10 at 16 px has a 23-px line box, and a themed `Button` adds
## its own padding on top: a `Button` in this project cannot be shorter than about 31 px, and a
## register line is 18. A Control never shrinks below its own minimum, so a 15x18 stepper silently
## became a 15x31 one the moment it entered a tree — printing over the row underneath and, worse,
## swallowing the clicks meant for it. A `Panel` has no intrinsic minimum: it is exactly the rect you
## give it, the glyph is a clipped child, and the row stays a row.
##
## It is still a real control: focusable, `ui_accept`able, with the same `pressed` signal a Button
## has, so a scene wires it identically and the reachability test cannot tell them apart.

signal pressed()

## The glyph is printed from a Label whose own line box is taller than the plate; the plate clips it,
## and this is how far up the glyph starts so it sits centred anyway.
const GLYPH_TOP := -4

var _enabled: bool = true

func _ready() -> void:
	Palette.prepare()
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if not focus_entered.is_connected(_refresh):
		focus_entered.connect(_refresh)
	if not focus_exited.is_connected(_refresh):
		focus_exited.connect(_refresh)
	_refresh()

## Everything a row needs to say about a stepper: what it prints, where it sits, and whether it is
## on offer. One call, because a half-placed chip is a click that lands on the wrong line.
func set_chip(glyph: String, r: Rect2i, on: bool) -> void:
	position = Vector2(r.position)
	size = Vector2(r.size)
	custom_minimum_size = Vector2(r.size)
	_enabled = on
	var label := _label()
	if label == null:
		return
	label.text = glyph
	label.position = Vector2(0, float(GLYPH_TOP))
	label.size = Vector2(float(r.size.x), float(r.size.y - GLYPH_TOP * 2))
	label.custom_minimum_size = label.size
	_refresh()

func set_enabled(on: bool) -> void:
	_enabled = on
	_refresh()

func is_enabled() -> bool:
	return _enabled

## What a click does, exposed so the keyboard and a headless driver press the same thing a finger does.
func press() -> void:
	if not _enabled:
		return
	pressed.emit()

func _gui_input(event: InputEvent) -> void:
	if not _enabled:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		press()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		press()
		accept_event()

func _refresh() -> void:
	var focused := is_inside_tree() and has_focus()
	var edge := Palette.ACCENT if focused else (Palette.EDGE if _enabled else Palette.RULE)
	add_theme_stylebox_override("panel", Palette.tight_box(Palette.INK_DEEP if _enabled else Palette.INK, edge))
	var label := _label()
	if label != null:
		label.add_theme_color_override("font_color", Palette.TEXT if _enabled else Palette.TEXT_DIM)

func _label() -> Label:
	return get_node_or_null("%Glyph") as Label
