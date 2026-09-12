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

func render(v: Dictionary) -> void:
	if v.is_empty():
		return
	var layers := get_node_or_null("%SceneLayers") as SceneLayers
	if layers != null:
		layers.set_time(0.0)
	var modal := _modal()
	if modal != null:
		modal.title = "Laden — Tag %d, %s" % [int(v.get("day", 1)), String(v.get("weekday_name", ""))]
	var board := _board()
	if board != null:
		board.render(v)

func _on_open_night() -> void:
	dispatch({"type": "open_night"})
	request_screen.emit("night")

func _modal() -> Modal:
	return get_node_or_null("%Modal") as Modal

func _board() -> ManageBoard:
	return get_node_or_null("%ManageBoard") as ManageBoard
