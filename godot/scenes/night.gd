extends Screen
## The night at the counter — the hero screen. Composition follows the Coffee Talk frame:
## full-frame set, the customer's bust centred behind the counter band, the dialogue box across the
## counter, the want bubble beside the customer, the HUD tucked in the corners, and the serve panel
## sliding in over the right half. Every one of those is a component; this file only arranges them
## and turns clicks into engine actions.

const BUBBLE_RIGHT := Vector2(336, 62)
const BUBBLE_LEFT := Vector2(44, 62)

func _ready() -> void:
	super._ready()
	# The bust belongs BETWEEN backdrop and counter, so the counter hides the lower body. It is
	# authored as a child of this scene (inspectable) and mounted into the set's character slot here.
	var layers := _layers()
	var portrait := _portrait()
	if layers != null and portrait != null and portrait.get_parent() != layers.get_node_or_null("%Characters"):
		var pos := portrait.position
		layers.mount(portrait)
		portrait.position = pos
	var box := _dialogue()
	if box != null:
		if not box.choice.is_connected(_on_choice):
			box.choice.connect(_on_choice)
	var panel := _serve()
	if panel != null:
		if not panel.serve.is_connected(_on_serve):
			panel.serve.connect(_on_serve)
		if not panel.waved_off.is_connected(_on_wave_off):
			panel.waved_off.connect(_on_wave_off)
	var toggle := get_node_or_null("%ServeToggle") as Button
	if toggle != null and not toggle.pressed.is_connected(toggle_serve):
		toggle.pressed.connect(toggle_serve)

func render(v: Dictionary) -> void:
	if v.is_empty():
		return
	var layers := _layers()
	if layers != null:
		layers.set_time(float(v.get("night_progress", 0.3)))
		layers.rain_drops = 8 + int(float(v.get("night_progress", 0.3)) * 16.0)
	var hud := get_node_or_null("%Hud") as Hud
	if hud != null:
		hud.render(v)
	var active: Dictionary = v.get("active", {})
	var portrait := _portrait()
	if portrait != null:
		portrait.set_from_active(active)
	var dialogue: Dictionary = v.get("dialogue", {})
	var box := _dialogue()
	if box != null:
		if not dialogue.is_empty():
			box.show_dialogue(dialogue, _capture_mode)
		elif not active.is_empty():
			box.show_dialogue(_order_line(active), true)
		else:
			box.clear()
	var bubble := get_node_or_null("%WantBubble") as WantBubble
	if bubble != null:
		bubble.set_want(active.get("want", {}) if not active.is_empty() else {})
		bubble.visible = not active.is_empty()
	var panel := _serve()
	if panel != null:
		panel.render(v)
		_place_bubble(panel.is_open)
	var toggle := get_node_or_null("%ServeToggle") as Button
	if toggle != null:
		toggle.disabled = active.is_empty() or not dialogue.is_empty()

func apply_capture_preset(preset_name: String) -> void:
	super.apply_capture_preset(preset_name)
	var panel := _serve()
	var box := _dialogue()
	match preset_name:
		"dialogue_choice":
			if panel != null:
				panel.close(true)
			if box != null:
				box.show_final(MockView.view(preset_name).get("dialogue", {}))
		"serving":
			if panel != null:
				panel.open(true)
				panel.preload_picks(["beer", "mate"])
			_place_bubble(true)
		"pfand":
			if panel != null:
				panel.open(true)
				panel.preload_picks(["beer"], 6)
			_place_bubble(true)
		_:
			if panel != null:
				panel.close(true)
	var layers := _layers()
	if layers != null and preset_name == "late_night":
		layers.rain_drops = 26

## Space / click advances the conversation; with nothing being said it opens the shelf.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		var box := _dialogue()
		if box != null and box.visible:
			box.advance()
		else:
			toggle_serve()
		get_viewport().set_input_as_handled()

func toggle_serve() -> void:
	var panel := _serve()
	if panel == null:
		return
	if panel.is_open:
		panel.close()
	else:
		panel.render(view())
		panel.open()
	_place_bubble(panel.is_open)

func _place_bubble(serve_open: bool) -> void:
	var bubble := get_node_or_null("%WantBubble") as WantBubble
	if bubble != null:
		bubble.position = BUBBLE_LEFT if serve_open else BUBBLE_RIGHT

## The plain order a customer speaks when no story beat is pending. Presentation only — the engine
## read-model carries `dialogue` just for beats and vignettes (docs/05 section 4).
func _order_line(active: Dictionary) -> Dictionary:
	var want: Dictionary = active.get("want", {})
	var customer: Dictionary = active.get("customer", {})
	var character_id := String(customer.get("character_id", ""))
	var speaker := character_id.capitalize() if character_id != "" else String(active.get("archetype", {}).get("name", "Kunde"))
	return {
		"speaker": speaker,
		"portrait": String(active.get("portrait", "")),
		"expression": String(active.get("expression", "neutral")),
		"lines": ["%s, bitte." % String(want.get("name", "Eine Mate"))],
		"choices": [],
		"kind": "order",
	}

func _on_choice(index: int) -> void:
	var kind := String(view().get("dialogue", {}).get("kind", "beat"))
	dispatch({"type": "resolve_vignette" if kind == "vignette" else "resolve_beat", "choice": index})

func _on_serve(action: Dictionary) -> void:
	dispatch(action)
	var panel := _serve()
	if panel != null:
		var t := panel.till()
		if t != null:
			t.clear()
		panel.close()
		_place_bubble(false)

func _on_wave_off() -> void:
	dispatch({"type": "skip_active"})
	var panel := _serve()
	if panel != null:
		panel.close()
		_place_bubble(false)

func _layers() -> SceneLayers:
	return get_node_or_null("%SceneLayers") as SceneLayers

func _portrait() -> Portrait:
	return get_node_or_null("%Portrait") as Portrait

func _dialogue() -> DialogueBox:
	return get_node_or_null("%DialogueBox") as DialogueBox

func _serve() -> ServePanel:
	return get_node_or_null("%ServePanel") as ServePanel
