extends Screen
## Title: the full-frame title art, the wordmark, and a vertical menu in the pixel font. Every word
## comes from `Strings` (the .tscn carries the same text only so the editor shows reality).
## "New game" starts a real season on the Session and hands the shell the Manage screen — the hour
## before opening night 1. "Continue" is live only when there is an autosave to load.

func _ready() -> void:
	super._ready()
	var art := get_node_or_null("%Art") as TextureRect
	if art != null:
		art.texture = Assets.texture("scene/title")
	# The vignette over the art is a Palette token, not a colour in the .tscn (docs/04 rule 1).
	var vignette := get_node_or_null("Vignette") as ColorRect
	if vignette != null:
		vignette.color = Palette.SCRIM
	_text("%Name", Strings.WORDMARK)
	_text("%Sub", Strings.SUBTITLE)
	_text("%Version", Strings.VERSION)
	_text("%Note", Strings.SETTINGS_NOTE)
	_wire("%NewGame", Strings.NEW_GAME, _on_new_game)
	_wire("%Continue", Strings.CONTINUE, _on_continue)
	_wire("%Settings", Strings.SETTINGS, _on_settings)
	_wire("%Quit", Strings.QUIT, _on_quit)
	var cont := get_node_or_null("%Continue") as Button
	if cont != null:
		cont.disabled = not _has_save()
	var modal := get_node_or_null("%SettingsModal") as Modal
	var box := get_node_or_null("%SettingsBox") as Control
	if modal != null:
		modal.title = Strings.SETTINGS
		if box != null and box.get_parent() != modal.content():
			modal.add_content(box)
	var motion := get_node_or_null("%ReduceMotion") as CheckBox
	if motion != null:
		motion.text = Strings.REDUCE_MOTION
		motion.button_pressed = Palette.reduce_motion
		if not motion.toggled.is_connected(_on_reduce_motion):
			motion.toggled.connect(_on_reduce_motion)
	var new_game := get_node_or_null("%NewGame") as Button
	if new_game != null and is_inside_tree():
		new_game.grab_focus()

func render(_v: Dictionary) -> void:
	pass

func _text(unique: String, value: String) -> void:
	var n := get_node_or_null(unique)
	if n != null and "text" in n:
		n.set("text", value)

func _wire(unique: String, label: String, cb: Callable) -> void:
	var b := get_node_or_null(unique) as Button
	if b == null:
		return
	b.text = label
	if not b.pressed.is_connected(cb):
		b.pressed.connect(cb)

func _has_save() -> bool:
	var s := session()
	return s != null and s.has_method("has_save") and bool(s.call("has_save"))

func _on_new_game() -> void:
	var s := session()
	if s != null and s.has_method("new_game"):
		s.new_game({})
	# A fresh season starts in `manage` (SpatiState.new_game) — the hour before night 1 opens.
	request_screen.emit("manage")

func _on_continue() -> void:
	var s := session()
	if s == null or not s.has_method("load_save") or not s.load_save():
		return
	request_screen.emit(_screen_for(String(view().get("phase", "manage"))))

func _on_settings() -> void:
	var modal := get_node_or_null("%SettingsModal") as Modal
	if modal != null:
		modal.open()

func _on_reduce_motion(on: bool) -> void:
	Palette.reduce_motion = on

func _on_quit() -> void:
	if is_inside_tree():
		get_tree().quit()

func _screen_for(phase: String) -> String:
	match phase:
		"night":
			return "night"
		"summary":
			return "summary"
	return "manage"
