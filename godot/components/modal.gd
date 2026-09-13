class_name Modal
extends Control
## The one overlay shell: a dimmed backdrop that swallows clicks, a titled frame in the middle, an
## Esc/close route out. Pause, Settings and Manage all live inside this — never a second overlay look.

signal closed()

## Who had the keyboard before we opened, so closing hands it straight back.
var _focus_return: Control = null

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
	# docs/04 rule 1 reaches components too: both surfaces are Palette tokens, not hexes.
	var dim := get_node_or_null("%Dim") as ColorRect
	if dim != null:
		dim.color = Palette.MODAL_DIM
	var rule := get_node_or_null("Frame/Box/Rule") as ColorRect
	if rule != null:
		rule.color = Palette.RULE
	var close := get_node_or_null("%Close") as Button
	if close != null and not close.pressed.is_connected(close_modal):
		close.pressed.connect(close_modal)
	_refresh()

func open() -> void:
	visible = true
	_trap_focus(true)
	if not Palette.reduce_motion and is_inside_tree():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.14)
	else:
		modulate.a = 1.0

func close_modal() -> void:
	_trap_focus(false)
	visible = false
	closed.emit()

## The Dim stops the MOUSE; nothing stopped the keyboard. Godot's Tab ring only skips controls that
## are invisible or unfocusable, so with the Title's Settings frame up one Tab landed on "Quit"
## behind the dim and Enter ended the process. `focus_behavior_recursive` is the lever: the screen
## behind us goes FOCUS_BEHAVIOR_DISABLED, our own subtree FOCUS_BEHAVIOR_ENABLED (it overrides the
## disabled ancestor), and close puts both back to INHERITED plus the focus where we found it.
func _trap_focus(on: bool) -> void:
	# The flags are set tree or no tree (a test instantiates the screen loose); only the focus owner
	# itself needs a viewport.
	var behind := get_parent() as Control
	if on:
		if is_inside_tree():
			_focus_return = get_viewport().gui_get_focus_owner()
		focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
		if behind != null:
			behind.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
		if is_inside_tree():
			_grab_first.call_deferred()   # deferred: the content is reparented and laid out this frame
	else:
		if behind != null:
			behind.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		if _focus_return != null and is_instance_valid(_focus_return) and _focus_return.is_inside_tree():
			_focus_return.grab_focus()
		_focus_return = null

## First focusable control inside the frame, so the keyboard starts where the eye is.
func _grab_first() -> void:
	if not visible or not is_inside_tree():
		return
	var first := _first_focusable(content())
	if first == null:
		first = get_node_or_null("%Close") as Control
	if first != null and first.is_visible_in_tree():
		first.grab_focus()

func _first_focusable(root: Node) -> Control:
	if root == null:
		return null
	for ch in root.get_children():
		var c := ch as Control
		# A disabled Button keeps FOCUS_ALL in Godot, so it would still swallow the opening focus.
		if c != null and c.is_visible_in_tree() and c.get_focus_mode_with_override() == Control.FOCUS_ALL and not (c is BaseButton and (c as BaseButton).disabled):
			return c
		var deeper := _first_focusable(ch)
		if deeper != null:
			return deeper
	return null

## Where a screen puts its rows.
func content() -> Control:
	return get_node_or_null("%Content") as Control

func add_content(n: Node) -> void:
	var c := content()
	if c == null or n == null or n.get_parent() == c:
		return
	var keep_owner := n.owner
	if n.is_inside_tree() and n.get_parent() != null:
		n.reparent(c, false)   # keeps `owner`, so %-names inside still resolve
	else:
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
		c.add_child(n)
	if keep_owner != null:
		n.owner = keep_owner

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
