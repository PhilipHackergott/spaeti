extends Screen
## The night at the counter — the hero screen. Composition follows the Coffee Talk frame:
## full-frame set, the customer's bust centred behind the counter band, the dialogue box across the
## counter, the want bubble beside the customer, the HUD tucked in the corners, and the serve panel
## sliding in over the right half. Every one of those is a component; this file only arranges them
## and turns clicks into engine actions.
##
## Since docs/06 it is also the REGISTER screen: the guests queue at the right end of the counter
## (QueueStrip), you take them one at a time (`talk_next`), the conversation runs on the DialogueBox
## (`talk_advance` / `talk_choose`), a roll pops as a d20 beside it (DiceResult) and the six stats sit
## on the left behind Tab (StatsStrip). The serve panel is still there and still works — it is just a
## small toggle under the HUD now instead of the point of the screen.
##
## It renders `Session.view()` in the real game and `MockView.view(preset)` for a capture — the SAME
## `render()`, never a second path (docs/04). The only capture-only branch is `_advance_phase`, which
## would otherwise dispatch a `close_night` into a screenshot.

const BUBBLE_RIGHT := Vector2(340, 74)

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
		# Demoted (docs/06 §5): a small plate under the HUD, out of the conversation's way — and it
		# stays put when the panel slides in, so it doubles as the close affordance.
		toggle.position = Vector2(Palette.SERVE_TOGGLE_RECT.position)
		toggle.size = Vector2(Palette.SERVE_TOGGLE_RECT.size)
		if not toggle.pressed.is_connected(toggle_serve):
			toggle.pressed.connect(toggle_serve)
	var queue := _queue()
	if queue != null and not queue.talk_next.is_connected(_on_talk_next):
		queue.talk_next.connect(_on_talk_next)
	if box != null and not box.finished.is_connected(_on_dialogue_finished):
		box.finished.connect(_on_dialogue_finished)
	_connect_events()

## The FX/SFX stream: every new log entry, in order (docs/05 §7). Visual only for now. It is routed
## through here rather than straight into `Fx` because one kind has a second listener: a `check`
## (docs/06 §2) both bursts and re-pops the d20 plate, and neither may depend on the other existing.
func _connect_events() -> void:
	var s := session()
	if s == null:
		return
	if s.has_signal("event") and not s.is_connected("event", _on_log_event):
		s.connect("event", _on_log_event)

func _on_log_event(entry: Dictionary) -> void:
	var fx := _fx()
	if fx != null:
		fx.on_event(entry)
	if String(entry.get("kind", "")) == "check":
		var dice := _dice()
		if dice != null and dice.visible:
			dice.pop()

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
	var talk: Dictionary = v.get("talk", {})
	_notice_customer(active)
	var portrait := _portrait()
	if portrait != null:
		portrait.set_from_active(active)
		# While a conversation is open the NODE's expression is the truth (docs/06 §3): the guest
		# reacts line by line, and `active.expression` only moves when a choice is finally applied.
		if not talk.is_empty() and not active.is_empty():
			portrait.expression = String(talk.get("expression", String(active.get("expression", "neutral"))))
		_seat_portrait()
	var dialogue: Dictionary = v.get("dialogue", {})
	var box := _dialogue()
	if box != null:
		if not talk.is_empty():
			box.show_dialogue(_talk_dialogue(talk), _capture_mode)
		elif not dialogue.is_empty():
			box.show_dialogue(dialogue, _capture_mode)
		elif not active.is_empty():
			box.show_dialogue(_order_line(active), true)
		else:
			box.clear()
	var panel := _serve()
	if panel != null:
		panel.render(v)
	var dice := _dice()
	if dice != null:
		dice.show_check(talk.get("last_check", {}) as Dictionary if not talk.is_empty() else {})
	var stats := _stats()
	if stats != null:
		var player: Dictionary = v.get("player", {})
		stats.render(player)
		# An engine that has not shipped docs/06 §1 yet hands no stats at all; an empty sheet is not
		# a sheet, so Tab has nothing to open rather than six zeroes to show.
		if player.is_empty():
			stats.set_shown(false)
	_place_chrome(v)
	var toggle := get_node_or_null("%ServeToggle") as Button
	if toggle != null:
		# `legal_actions` offers no serve at all while the story (or a conversation) holds the counter,
		# docs/05 §4 + docs/06 §4 — the button says so instead of dispatching something illegal.
		toggle.disabled = active.is_empty() or not dialogue.is_empty() or not talk.is_empty()

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
		"pfand":
			if panel != null:
				panel.open(true)
				panel.preload_picks(["beer"], 6)
		"queue_waiting":
			# The one capture where the sheet is on screen without Tab being pressed (docs/06 section 5).
			if panel != null:
				panel.close(true)
			var stats := _stats()
			if stats != null:
				stats.set_shown(true)
		_:
			if panel != null:
				panel.close(true)
	var layers := _layers()
	if layers != null and preset_name == "late_night":
		layers.rain_drops = 26
	# The chrome is laid out LAST: opening or closing the panel moves the box, the bust and the line.
	_place_chrome(view())

## Tab toggles the six stats. It is taken in `_input`, BEFORE the GUI sees it, so Tab does not also
## walk the focus ring: a sheet that opens while the focus jumps to the next choice is worse than no
## sheet at all. Nothing else on this screen wants Tab.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_TAB:
		return
	var stats := _stats()
	if stats != null and stats.has_stats(view().get("player", {})):
		stats.toggle()
	get_viewport().set_input_as_handled()

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
	_place_chrome(view())

## Where the counter chrome sits, given who owns the right half of the frame. The three states are
## mutually exclusive on purpose - two things may never share the column:
##   * serve panel open: the box shrinks to `DIALOGUE_W_SERVING`, the bust steps left, and the queue
##     and the want bubble stand down (the panel covers x 228..476 anyway);
##   * the queue on screen: the box gives the right column back (`DIALOGUE_W_QUEUE`) so the choices
##     stop short of the line, and the bubble stands down (the guest is talking, not miming);
##   * neither: the full-width box the serve screen always had.
func _place_chrome(v: Dictionary) -> void:
	var panel := _serve()
	var serve_open := panel != null and panel.is_open
	var active: Dictionary = v.get("active", {})
	var talk: Dictionary = v.get("talk", {})
	var queue: Array = v.get("queue", [])
	var queue_shown := not serve_open and not queue.is_empty()
	var strip := _queue()
	if strip != null:
		# Mirrors `legal_actions` (docs/06 section 4): `talk_next` is on offer whenever no conversation
		# is open and there is somebody to talk to - at the counter or in the line, since the reducer
		# pulls the head of the queue up on its own tick. The strip hides entirely under the serve panel.
		# A pending beat that never opened as a talk blocks it too (docs/05 section 4: while it is
		# pending, legal_actions offers only resolve_beat/resolve_vignette) - and its choices are drawn
		# full-width, so a live button under them would sit inside the choice stack.
		var beat: Dictionary = v.get("dialogue", {})
		var can_start: bool = talk.is_empty() and beat.is_empty() and (not active.is_empty() or not queue.is_empty())
		strip.set_queue(([] if serve_open else queue), can_start and not serve_open)
	var bubble := get_node_or_null("%WantBubble") as WantBubble
	if bubble != null:
		bubble.set_want(active.get("want", {}) if not active.is_empty() else {})
		bubble.position = BUBBLE_RIGHT
		bubble.visible = not active.is_empty() and not serve_open and talk.is_empty() and not queue_shown
	var box := _dialogue()
	if box != null:
		var r := Palette.DIALOGUE_RECT
		var w := r.size.x
		if serve_open:
			w = Palette.DIALOGUE_W_SERVING
		elif queue_shown:
			w = Palette.DIALOGUE_W_QUEUE
		box.set_width(float(w))   # the box owns its height (it grows upward for a choice list)
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

## The ONE place a choice becomes an action. A conversation (docs/06 section 4) is `talk_choose`; the
## older beat/vignette paths stay exactly as they were, because the engine still routes them by name.
func _on_choice(index: int) -> void:
	if not view().get("talk", {}).is_empty():
		dispatch({"type": "talk_choose", "choice": index})
		return
	var kind := String(view().get("dialogue", {}).get("kind", "beat"))
	dispatch({"type": "resolve_vignette" if kind == "vignette" else "resolve_beat", "choice": index})

## Clicking the line (or "Next guest") takes the first guest waiting, FIFO.
func _on_talk_next() -> void:
	dispatch({"type": "talk_next"})

## The DialogueBox ran out of words with nothing to choose. In a conversation that is the cue to ask
## the engine for the next line (`talk_advance`): the engine owns `talk.line`, the box only shows it.
func _on_dialogue_finished() -> void:
	if _capture_mode:
		return
	if view().get("talk", {}).is_empty():
		return
	dispatch({"type": "talk_advance"})

## `view.talk` as the DialogueBox wants it: ONE line, the one the engine says we are on, plus the
## choices if the node has reached them. The box's own line walk is deliberately not used here; two
## cursors over one conversation is how a click ends up a line ahead of the reducer.
func _talk_dialogue(talk: Dictionary) -> Dictionary:
	var lines: Array = talk.get("lines", [])
	var index := clampi(int(talk.get("line", 0)), 0, maxi(0, lines.size() - 1))
	return {
		"speaker": String(talk.get("speaker", "")),
		"portrait": String(talk.get("portrait", "")),
		"expression": String(talk.get("expression", "neutral")),
		"lines": ([String(lines[index])] if not lines.is_empty() else []),
		"choices": talk.get("choices", []),
		"kind": "talk",
	}

func _on_serve(action: Dictionary) -> void:
	dispatch(action)
	var panel := _serve()
	if panel != null:
		var t := panel.till()
		if t != null:
			t.clear()
		panel.close()
	_place_chrome(view())

func _on_wave_off() -> void:
	dispatch({"type": "skip_active"})
	var panel := _serve()
	if panel != null:
		var t := panel.till()
		if t != null:
			t.clear()
		panel.close()
	_place_chrome(view())

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

func _queue() -> QueueStrip:
	return get_node_or_null("%QueueStrip") as QueueStrip

func _stats() -> StatsStrip:
	return get_node_or_null("%StatsStrip") as StatsStrip

func _dice() -> DiceResult:
	return get_node_or_null("%DiceResult") as DiceResult
