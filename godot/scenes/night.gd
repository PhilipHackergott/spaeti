extends Screen
## The night at the counter — the hero screen. Composition follows the Coffee Talk frame:
## full-frame set, the customer's bust centred behind the counter band, the dialogue box across the
## counter, the want bubble beside the customer, the HUD tucked in the corners, and the serve panel
## sliding in over the right half. Every one of those is a component; this file only arranges them
## and turns clicks into engine actions.
##
## It renders `Session.view()` in the real game and `MockView.view(preset)` for a capture — the SAME
## `render()`, never a second path (docs/04). The only capture-only branch is `_advance_phase`, which
## would otherwise dispatch a `close_night` into a screenshot.

const BUBBLE_RIGHT := Vector2(340, 74)
const BUBBLE_LEFT := Vector2(44, 62)

## The night ends itself. Session ticks every frame, so `render` is the place both transitions are
## noticed — these two latches keep each one firing exactly once per night.
var _closing: bool = false
var _leaving: bool = false
## Who is at the counter right now: when it changes, a half-filled till belongs to nobody.
var _active_id: int = -1

func _ready() -> void:
	super._ready()
	# The bust belongs BETWEEN backdrop and counter, so the counter hides the lower body. It is
	# authored as a child of this scene (inspectable) and mounted into the set's character slot here.
	var layers := _layers()
	var portrait := _portrait()
	if layers != null and portrait != null:
		layers.mount(portrait)   # position is re-derived from the counter edge, so it need not survive
	_seat_portrait()
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
	if toggle != null:
		toggle.text = Strings.SERVE
		if not toggle.pressed.is_connected(toggle_serve):
			toggle.pressed.connect(toggle_serve)
	_connect_events()

## The FX/SFX stream: every new log entry, in order (docs/05 §7). Visual only for now.
func _connect_events() -> void:
	var s := session()
	var fx := _fx()
	if s == null or fx == null:
		return
	if s.has_signal("event") and not s.is_connected("event", fx.on_event):
		s.connect("event", fx.on_event)

func render(v: Dictionary) -> void:
	if v.is_empty():
		return
	# 06:00 with an empty counter closes the books; once the reducer is in `summary` the shell takes over.
	if not _capture_mode and _advance_phase(v):
		return
	var layers := _layers()
	if layers != null:
		layers.set_time(float(v.get("night_progress", 0.3)))
		layers.rain_drops = 8 + int(float(v.get("night_progress", 0.3)) * 16.0)
	var hud := get_node_or_null("%Hud") as Hud
	if hud != null:
		hud.render(v)
	var active: Dictionary = v.get("active", {})
	_notice_customer(active)
	var portrait := _portrait()
	if portrait != null:
		portrait.set_from_active(active)
		_seat_portrait()
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

## Closes the night when the clock has run out and nobody is left waiting, and hands over to the
## summary screen once the reducer has moved on. Returns true when the screen is in transition and
## should not keep drawing this frame's (already stale) counter.
func _advance_phase(v: Dictionary) -> bool:
	match String(v.get("phase", "")):
		"night":
			_leaving = false
			if float(v.get("night_progress", 0.0)) < 1.0:
				_closing = false
				return false
			# Whoever is still at the counter is served first; the last balk clears it either way.
			var counter_clear := (v.get("active", {}) as Dictionary).is_empty() and int(v.get("queue_len", 0)) == 0
			if not _closing and counter_clear:
				_closing = true
				dispatch({"type": "close_night"})
				return true
			return false
		"summary", "end":
			if not _leaving:
				_leaving = true
				request_screen.emit("summary")
			return true
	return false

## A new person at the counter gets a clean till — the previous order was never rung up.
func _notice_customer(active: Dictionary) -> void:
	var id := int((active.get("customer", {}) as Dictionary).get("id", -1)) if not active.is_empty() else -1
	if id == _active_id:
		return
	_active_id = id
	var panel := _serve()
	if panel == null:
		return
	var t := panel.till()
	if t != null:
		t.clear()

## The bust sits bottom-centred against the counter's real occlusion line (docs/02 "Night framing").
## With the serve panel open it steps left, or the panel would cover it (verify round 3: Jürgen was
## ~55 % hidden in the `pfand` capture).
func _seat_portrait() -> void:
	var layers := _layers()
	var portrait := _portrait()
	if layers == null or portrait == null:
		return
	var panel := _serve()
	var serving := panel != null and panel.is_open
	portrait.place_behind(layers.counter_edge(), Palette.PORTRAIT_CENTRE_X_SERVING if serving else Palette.PORTRAIT_CENTRE_X)

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

## With the serve panel open the counter chrome moves left so nothing is hidden behind it.
func _place_bubble(serve_open: bool) -> void:
	var bubble := get_node_or_null("%WantBubble") as WantBubble
	if bubble != null:
		bubble.position = BUBBLE_LEFT if serve_open else BUBBLE_RIGHT
	var box := _dialogue()
	if box != null:
		var r := Palette.DIALOGUE_RECT
		box.size = Vector2(float(Palette.DIALOGUE_W_SERVING if serve_open else r.size.x), float(r.size.y))
	var hud := get_node_or_null("%Hud") as Hud
	if hud != null:
		hud.set_compact(serve_open)
	_seat_portrait()

## The plain order a customer speaks when no story beat is pending. Presentation only — the engine
## read-model carries `dialogue` just for beats and vignettes (docs/05 §4).
func _order_line(active: Dictionary) -> Dictionary:
	var want: Dictionary = active.get("want", {})
	return {
		"speaker": _speaker_name(active),
		"portrait": String(active.get("portrait", "")),
		"expression": String(active.get("expression", "neutral")),
		"lines": [Strings.ORDER_LINE % String(want.get("name", ""))],
		"choices": [],
		"kind": "order",
	}

## The name the cast registry gives them ("'Bottle' Jürgen"), else the archetype's ("Kiez regular").
## A read of the content registry, never a rule — the engine still owns every word.
func _speaker_name(active: Dictionary) -> String:
	var character_id := String((active.get("customer", {}) as Dictionary).get("character_id", ""))
	if character_id != "":
		var c := Content.character(character_id)
		if not c.is_empty():
			return String(c.get("name", character_id))
	var arch_name := String((active.get("archetype", {}) as Dictionary).get("name", ""))
	return arch_name if arch_name != "" else Strings.SOMEONE

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
		var t := panel.till()
		if t != null:
			t.clear()
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

func _fx() -> Fx:
	return get_node_or_null("%Fx") as Fx
