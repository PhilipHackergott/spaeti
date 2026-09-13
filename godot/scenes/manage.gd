extends Screen
## Manage (the hour before opening): the ManageBoard inside the pool's Modal, over the dimmed night
## set. The screen only wires the board's intents to `dispatch` — the board draws, the engine decides.

func _ready() -> void:
	super._ready()
	var modal := _modal()
	var board := _board()
	if modal != null and board != null and board.get_parent() != modal.content():
		modal.add_content(board)
	if modal != null:
		modal.closable = false
		modal.visible = true
	if board != null:
		if not board.action.is_connected(dispatch):
			board.action.connect(dispatch)
		if not board.open_night.is_connected(_on_open_night):
			board.open_night.connect(_on_open_night)
	refresh()
	# Deferred: `apply_capture_preset` runs right after `add_child`, so `_capture_mode` is not set yet
	# and an immediate grab would draw a focus ring into the judged `manage` frame.
	_seed_focus.call_deferred()

## Godot walks the focus ring only FROM an owner, and nothing on this board ever took focus, so the
## whole hour was mouse-only (Title is the one screen that seeds it, title.gd). "Open up" is the
## anchor because it is the one control OUTSIDE the lists the board rebuilds on every dispatch.
func _seed_focus() -> void:
	if not is_inside_tree() or _capture_mode:
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	var board := _board()
	if board == null:
		return
	var open_up := board.get_node_or_null("%OpenNight") as Control
	if open_up != null and open_up.is_visible_in_tree() and not (open_up as Button).disabled:
		open_up.grab_focus()

func render(v: Dictionary) -> void:
	if v.is_empty():
		return
	var layers := get_node_or_null("%SceneLayers") as SceneLayers
	if layers != null:
		layers.set_time(0.0)
	var modal := _modal()
	if modal != null:
		modal.title = Strings.MANAGE_TITLE % [int(v.get("day", 1)), String(v.get("weekday_name", ""))]
	var board := _board()
	if board != null:
		board.render(v)

func _on_open_night() -> void:
	# A refused `open_night` must never hand the shell a screen: outside the manage hour the reducer
	# returns the state unchanged, and the Night screen then has nothing it can do.
	if dispatch({"type": "open_night"}):
		request_screen.emit("night")

func _modal() -> Modal:
	return get_node_or_null("%Modal") as Modal

func _board() -> ManageBoard:
	return get_node_or_null("%ManageBoard") as ManageBoard
