extends Screen
## Title: the full-frame title art, the wordmark, and a vertical menu in the pixel font. Continue is
## disabled until there is a save (slice: always). Nothing here knows the rules; New game asks the
## Session for a new game if it exists and then asks Main for the night.

func _ready() -> void:
	super._ready()
	var art := get_node_or_null("%Art") as TextureRect
	if art != null:
		art.texture = Assets.texture("scene/title")
	# The vignette over the art is a Palette token, not a colour in the .tscn (docs/04 rule 1).
	var vignette := get_node_or_null("Vignette") as ColorRect
	if vignette != null:
		vignette.color = Palette.SCRIM
	_wire("%NewGame", _on_new_game)
	_wire("%Continue", _on_continue)
	_wire("%Settings", _on_settings)
	_wire("%Quit", _on_quit)
	var cont := get_node_or_null("%Continue") as Button
	if cont != null:
		cont.disabled = true
	var new_game := get_node_or_null("%NewGame") as Button
	if new_game != null and is_inside_tree():
		new_game.grab_focus()

func render(_v: Dictionary) -> void:
	pass

func _wire(unique: String, cb: Callable) -> void:
	var b := get_node_or_null(unique) as Button
	if b != null and not b.pressed.is_connected(cb):
		b.pressed.connect(cb)

func _on_new_game() -> void:
	var s := session()
	if s != null and s.has_method("new_game"):
		s.new_game({})
	request_screen.emit("manage")

func _on_continue() -> void:
	request_screen.emit("night")

func _on_settings() -> void:
	var modal := get_node_or_null("%SettingsModal") as Modal
	if modal != null:
		modal.open()

func _on_quit() -> void:
	if is_inside_tree():
		get_tree().quit()
