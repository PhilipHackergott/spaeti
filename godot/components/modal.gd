class_name Modal
extends Control
## The one overlay shell: a dimmed backdrop that swallows clicks, a titled frame in the middle, an
## Esc/close route out. Pause, Settings and Manage all live inside this — never a second overlay look.

signal closed()

@export var title: String = "":
	set(v):
		title = v
		_refresh()

@export var closable: bool = true:
	set(v):
		closable = v
		_refresh()

func _ready() -> void:
	Palette.prepare()
	var dim := get_node_or_null("%Dim") as ColorRect
	if dim != null:
		dim.color = Color(0, 0, 0, 0.55)
	var close := get_node_or_null("%Close") as Button
	if close != null and not close.pressed.is_connected(close_modal):
		close.pressed.connect(close_modal)
	_refresh()

func open() -> void:
	visible = true
	if not Palette.reduce_motion and is_inside_tree():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.14)
	else:
		modulate.a = 1.0

func close_modal() -> void:
	visible = false
	closed.emit()

## Where a screen puts its rows.
func content() -> Control:
	return get_node_or_null("%Content") as Control

func add_content(n: Node) -> void:
	var c := content()
	if c != null:
		c.add_child(n)

func clear_content() -> void:
	var c := content()
	if c == null:
		return
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()

func _refresh() -> void:
	var t := get_node_or_null("%Title") as Label
	if t != null:
		t.text = title
	var close := get_node_or_null("%Close") as Button
	if close != null:
		close.visible = closable

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not closable:
		return
	if event.is_action_pressed("ui_cancel"):
		close_modal()
		get_viewport().set_input_as_handled()
