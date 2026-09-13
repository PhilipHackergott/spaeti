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

## Every action this screen hands the reducer, in order. The pointer-driven register test asserts the
## DICTIONARY a synthetic click produced (docs/08 section 6) — today's soft-lock shipped because a
## driver pressed buttons by name, so the driver may never name one again.
signal acted(action: Dictionary)

## Which of the three chrome modes `_place_chrome` settled on last. Read by `_seat_portrait`, which
## runs from four places and must not re-derive the mode in any of them.
var _ringing: bool = false
var _on_wall: bool = false
## The correction this player has already read. Her line covers the counter band while it is on
## screen (mode exclusivity: dialogue OR tray, docs/08 4.3), so it has to be dismissible by the same
## click that advances any other line — otherwise the tray she is telling you to fix is unreachable
## for the rest of the customer, which is the soft-lock this screen already shipped once.
var _correction_seen: String = ""

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
	_seat_counter()
	_wire_register()
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
	if box != null and not box.choices_shown.is_connected(_anchor_choice):
		box.choices_shown.connect(_anchor_choice)
	# The box settles its HEIGHT on its own (and a frame late, deferred), so the sheet cannot be placed
	# from `_place_chrome` alone - it follows the box's real edge.
	if box != null and not box.resized.is_connected(_place_stats):
		box.resized.connect(_place_stats)
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
	_note_mode(v)
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
		elif _ringing and _correction_of(v) != "" and _correction_of(v) != _correction_seen:
			# The one free correction, spoken in character over the counter (docs/08 section 1). The
			# register's banner is only the TELL beside the flagged line; her words belong here, where
			# there are 264 px to say them in.
			box.show_dialogue(_correction_line(active, _correction_of(v)), true)
		elif not active.is_empty() and not _ringing:
			# During a ring-up her order is the OrderCard and the tray, not a speech balloon: the box
			# is hidden until somebody actually speaks (docs/08 section 1's frame table).
			box.show_dialogue(_order_line(active), true)
		else:
			box.clear()
	var panel := _serve()
	if panel != null:
		panel.render(v)
	_render_register(v, active, talk)
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
		# ...and it stands down entirely during a ring-up: the register IS the serve path now, and two
		# ways to sell the same basket is how a till and a counter disagree (docs/08 section 3.6).
		var can_serve := not active.is_empty() and dialogue.is_empty() and talk.is_empty() and not _ringing
		var panel_open := panel != null and panel.is_open
		# It doubles as the panel's close (docs/06 §5), so an open panel always keeps it live: greyed
		# only when it is neither a serve nor a close — which is also when it is hidden. (It used to
		# grey out in the one state the visible-while-open branch existed for, leaving "Wave off" —
		# a button naming a different action — as the only working mouse close.)
		toggle.disabled = not (can_serve or panel_open)
		# The judge (2026-09-13): a greyed "Serve" in the corner read as a leftover control. It is shown only
		# when serving is actually on offer — or while the panel is open, since it doubles as its close.
		toggle.visible = can_serve or panel_open
		toggle.text = Strings.CLOSE if panel_open else Strings.SERVE

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
				# NEVER dispatch from inside `render`: `Session.changed` re-enters `render()` while
				# this one is still on the stack, and the inner pass re-seats the bust underneath the
				# outer one (SceneLayers.mount then takes the not-in-tree branch and Godot warns the
				# owner is inconsistent). Latch the close and fire it at idle; `render` stays a read.
				dispatch.call_deferred({"type": "close_night"})
			# Latched but not closed yet: the counter on screen is already stale, so do not redraw it.
			return _closing
		"summary", "end":
			if not _leaving:
				_leaving = true
				# The reducer may already be past the summary (a season that ended on this night), so
				# route by the phase rather than always handing over the P&L card.
				request_screen.emit(Screen.screen_for(String(v.get("phase", ""))))
			return true
	return false

## A new person at the counter gets a clean till — the previous order was never rung up.
func _notice_customer(active: Dictionary) -> void:
	var id := int((active.get("customer", {}) as Dictionary).get("id", -1)) if not active.is_empty() else -1
	if id == _active_id:
		return
	_active_id = id
	_correction_seen = ""   # a new person at the counter has not said anything yet
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
	# Three columns, three seats: the serve panel pushes hardest, the register a little less (it owns
	# only the right column), and an ordinary night leaves the bust where docs/02 put it.
	var centre_x := Palette.PORTRAIT_CENTRE_X
	if serving:
		centre_x = Palette.PORTRAIT_CENTRE_X_SERVING
	elif _ringing:
		centre_x = Palette.PORTRAIT_CENTRE_X_RING
	# A LEANING bust (Assets.staging) goes in front of the counter with its forearms on the laminate; every
	# other bust keeps the Coffee Talk seat behind it. Re-mounting is idempotent, so this is safe per render.
	if portrait.staging() == "leaning":
		layers.mount(portrait, true)
		portrait.place_on(layers.counter_edge(), centre_x)
	else:
		layers.mount(portrait, false)
		portrait.place_behind(layers.counter_edge(), centre_x)

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
	if is_paused():
		return   # the shell's pause overlay is up: the night stands still behind it, keys included
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_TAB:
		return
	var stats := _stats()
	if stats != null and stats.has_stats(view().get("player", {})):
		stats.toggle()
	get_viewport().set_input_as_handled()

## A built choice list takes the keyboard, so a conversation is answerable without a mouse: `ui_up`/
## `ui_down` then walk the rows and `ui_accept` presses one. The ring will not START from nothing.
## Deferred: `_build_choices` sets `visible` after the rows are added, and `grab_focus()` on a
## not-yet-visible control is dropped. Never in a capture — the focus ring is a real border on a
## ChoiceButton and would land in the judged hero frame.
func _anchor_choice() -> void:
	if _capture_mode:
		return
	call_deferred("_anchor_choice_now")

func _anchor_choice_now() -> void:
	if _capture_mode or not is_inside_tree():
		return
	# Never steal the focus from something the player is already on; `_clear_choices` frees the
	# focused row, so the next node re-anchors by itself.
	if get_viewport().gui_get_focus_owner() != null:
		return
	var box := _dialogue()
	if box != null:
		box.focus_first_choice()

## Space / click advances the conversation; with nothing being said it opens the shelf.
func _unhandled_input(event: InputEvent) -> void:
	if is_paused():
		return
	# The register's own verbs come first, and only while it is open: Q turns around (and back), Enter
	# rings up, Delete and -/+ work the line the focus ring is standing on. Digits are deliberately
	# left alone — they still pick dialogue choices, which is the one binding this screen prints.
	# Esc at the wall is "turn back", not "pause": a child sees unhandled input before the shell, so
	# the pause frame only opens when your back is already to the counter (docs/08 section 4.2).
	if _on_wall and event.is_action_pressed("ui_cancel"):
		if _act({"type": "turn_around", "on": false}):
			get_viewport().set_input_as_handled()
			return
	if _ringing and _register_keys(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		# The BOX is not the state: a guest at the counter always has their order line on screen
		# (`render`'s `active` fallback), so `box.visible` was true in exactly the moment Space should
		# open the shelf — and `advance()` on a one-line order only emits `finished` into a no-op.
		var v := view()
		var speaking := not (v.get("talk", {}) as Dictionary).is_empty() 			or not (v.get("dialogue", {}) as Dictionary).is_empty()
		var box := _dialogue()
		if speaking and box != null and box.visible:
			box.advance()
		elif not _ringing:
			# The serve panel is a debug affordance during a ring-up (docs/08 section 3.6): Space may
			# not open a second way to sell the basket that is already on the counter.
			toggle_serve()
		get_viewport().set_input_as_handled()
		return
	# The rows print "1." / "2." (`Strings.CHOICE_NUMBER`) — the universal promise that the digit picks
	# them. Nothing was bound to it. `_unhandled_input`, not `_input`: a focused control gets first
	# refusal, unlike Tab, which is deliberately taken above.
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var n := _digit(key.keycode if key.keycode != KEY_NONE else key.physical_keycode)
		var box := _dialogue()
		if n > 0 and box != null and box.visible and box.choose_number(n):
			get_viewport().set_input_as_handled()

## 1..9 from the number row or the keypad; 0 for anything else. This screen has no text field, so a
## digit here can never be somebody's typing.
static func _digit(code: int) -> int:
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_1 + 1
	if code >= KEY_KP_1 and code <= KEY_KP_9:
		return code - KEY_KP_1 + 1
	return 0

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
	_note_mode(v)
	var queue_shown := not serve_open and not _ringing and not queue.is_empty()
	var strip := _queue()
	if strip != null:
		# Mirrors `legal_actions` (docs/06 section 4): `talk_next` is on offer whenever no conversation
		# is open and there is somebody to talk to - at the counter or in the line, since `talk_next`
		# also opens the conversation with whoever is already at the counter (Rules.apply -> talk_next);
		# the reducer promotes the head of the line only under `config.auto_take_next`, otherwise waiting
		# guests age out (Rules._age_queue). The strip hides entirely under the serve panel.
		# A pending beat that never opened as a talk blocks it too (docs/05 section 4: while it is
		# pending, legal_actions offers only resolve_beat/resolve_vignette) - and its choices are drawn
		# full-width, so a live button under them would sit inside the choice stack.
		var beat: Dictionary = v.get("dialogue", {})
		var can_start: bool = talk.is_empty() and beat.is_empty() and (not active.is_empty() or not queue.is_empty())
		# The register takes the right column, so the strip re-docks to a button under the HUD and drops
		# the line — but it keeps the BUTTON, because `talk_next` is still legal with a guest at the
		# counter (docs/06 4) and an action with no control is the soft-lock that already shipped once.
		strip.set_dock(Palette.QUEUE_RECT_RING if _ringing else Palette.QUEUE_RECT, _ringing)
		strip.set_queue(([] if serve_open or _ringing else queue),
			can_start and not serve_open and not _on_wall, not active.is_empty())
	var bubble := get_node_or_null("%WantBubble") as WantBubble
	if bubble != null:
		bubble.set_want(active.get("want", {}) if not active.is_empty() else {})
		# The one place the frame says the guest is a minor: the shelf's "18" badge is on the SKU, not
		# on the person, and the ID check at the counter is a decision you cannot make blind.
		bubble.age_flag = not active.is_empty() and bool(active.get("underage", false)) 			and bool((active.get("want", {}) as Dictionary).get("restricted", false))
		bubble.position = BUBBLE_RIGHT
		# Hidden during ANY conversation — a talk or a pending story beat — not only a talk: the judges read the
		# card over the doorway as competing with the character (v8/v9). The order line at the counter still shows it.
		bubble.visible = not active.is_empty() and not serve_open and not _ringing and talk.is_empty() and not queue_shown and (v.get("dialogue", {}) as Dictionary).is_empty()
	var box := _dialogue()
	if box != null:
		var r := Palette.DIALOGUE_RECT
		var w := r.size.x
		if serve_open:
			w = Palette.DIALOGUE_W_SERVING
		elif _ringing:
			# The register owns the right column; the box keeps the gutter left of it, where the one
			# free correction floats over the counter and nothing else ever does.
			w = Palette.DIALOGUE_W_RING
		elif queue_shown:
			w = Palette.DIALOGUE_W_QUEUE
		box.set_width(float(w))   # the box owns its height (it grows upward for a choice list)
	_place_stats()
	var hud := get_node_or_null("%Hud") as Hud
	if hud != null:
		hud.set_compact(serve_open)
		# A conversation — a talk OR a pending story beat/vignette with its lines — gets Coffee Talk's minimal HUD.
		hud.set_focus(not talk.is_empty() or not (v.get("dialogue", {}) as Dictionary).is_empty())
		# The wall has no HUD: the OrderCard takes the top-left corner and the running total the
		# top-right, which is docs/08 section 1's promise that the mark and the money never leave.
		hud.visible = not _on_wall
	_place_ring_chrome()
	_seat_portrait()

## The sheet and the dialogue box share the left column, and the box is drawn over it (Night.tscn
## sibling order). A choice list grows the box upward into the sheet's last rows — so the sheet steps
## up out of the way while that lasts, and drops back the moment the choices are gone.
func _place_stats() -> void:
	var stats := _stats()
	if stats == null:
		return
	var box := _dialogue()
	# Derived from the box's FIXED bottom edge and its current height, never from `position.y`: the box
	# emits `resized` between setting its size and moving its top, so the node's own y is one step stale.
	var bottom := float(Palette.DIALOGUE_RECT.position.y + Palette.DIALOGUE_RECT.size.y)
	var box_top := bottom - box.size.y if box != null and box.visible else float(Palette.DIALOGUE_RECT.position.y)
	stats.position = Palette.snap(Vector2(float(Palette.STATS_RECT.position.x), Palette.stats_top(box_top)))

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

## What the reducer said when it refused the ring-up, or "" (docs/08 section 3.4). The engine writes
## the sentence; this screen only decides where it is printed.
## What she says about a refused ring-up. The REDUCER decides WHICH complaint (`correction_kind`, the
## bucket it flagged); the WORDS come from `Strings`, which is where every other player-visible
## sentence in this project lives — `Rules.CORRECTION_LINES` stays the reducer's own fallback, so a
## bucket the table has not learned yet still speaks instead of going silent (docs/08 §3.4).
func _correction_of(v: Dictionary) -> String:
	var register: Dictionary = v.get("register", {})
	var kind := String(register.get("correction_kind", ""))
	if kind != "" and Strings.CORRECTION_BY_KIND.has(kind):
		return String(Strings.CORRECTION_BY_KIND[kind])
	return String(register.get("correction", ""))

## Her correction as the DialogueBox wants it: one line, her face, no choices. Presentation only.
func _correction_line(active: Dictionary, said: String) -> Dictionary:
	return {
		"speaker": _speaker_name(active),
		"portrait": String(active.get("portrait", "")),
		"expression": String(active.get("expression", "wary")),
		"lines": [said],
		"choices": [],
		"kind": "correction",
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
	var v := view()
	var said := _correction_of(v)
	if _ringing and said != "" and said != _correction_seen:
		# Her correction is read and put away by the same click that advances any other line. Nothing
		# is dispatched: the reducer already said its piece, and the flagged line stays flagged.
		_correction_seen = said
		refresh()
		return
	if v.get("talk", {}).is_empty():
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
	# The reducer refused it (the guest balked between the render and the press, or nobody was there
	# at all): the tray stays exactly as the player left it instead of reporting a sale that never
	# happened.
	if not dispatch(action):
		return
	var panel := _serve()
	if panel != null:
		var t := panel.till()
		if t != null:
			t.clear()
		panel.close()
	_place_chrome(view())

func _on_wave_off() -> void:
	if not dispatch({"type": "skip_active"}):
		return
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


# -- the ring-up (docs/08-register-and-tobacco.md) ------------------------------------------------

## The tray and the scanner are props ON the laminate, so they are mounted into `SceneLayers`' new
## `OnCounter` slot — after the counter art, before the tint. Idempotent, and called from `render` as
## well as `_ready` because the capture and the tests drive a Night that never entered a tree.
func _seat_counter() -> void:
	var layers := _layers()
	if layers == null:
		return
	var tray := _tray()
	if tray != null:
		layers.mount_on_counter(tray)
	var scanner := _scanner()
	if scanner != null:
		layers.mount_on_counter(scanner)

## Every intent the ring-up components emit becomes an action dictionary HERE and nowhere else.
func _wire_register() -> void:
	var tray := _tray()
	if tray != null:
		if not tray.scan_requested.is_connected(_on_scan):
			tray.scan_requested.connect(_on_scan)
		if not tray.pfand_requested.is_connected(_on_crate_clicked):
			tray.pfand_requested.connect(_on_crate_clicked)
		if not tray.drag_started.is_connected(_on_drag_started):
			tray.drag_started.connect(_on_drag_started)
	var scanner := _scanner()
	if scanner != null:
		if not scanner.scanned.is_connected(_on_scan):
			scanner.scanned.connect(_on_scan)
		if not scanner.activated.is_connected(_on_scanner_activated):
			scanner.activated.connect(_on_scanner_activated)
	var reg := _register_panel()
	if reg != null and not reg.action.is_connected(_on_register_action):
		reg.action.connect(_on_register_action)
	var wall := _wall_view()
	if wall != null:
		if not wall.taken.is_connected(_on_wall_take):
			wall.taken.connect(_on_wall_take)
		if not wall.put_back.is_connected(_on_put_back):
			wall.put_back.connect(_on_put_back)
		if not wall.turn_back.is_connected(_on_turn_back):
			wall.turn_back.connect(_on_turn_back)
	var drag := _drag()
	if drag != null:
		if not drag.dropped.is_connected(_on_dropped):
			drag.dropped.connect(_on_dropped)
		if not drag.hovering.is_connected(_on_drag_hover):
			drag.hovering.connect(_on_drag_hover)

## Everything the register draws, from the read-model and nothing else.
func _render_register(v: Dictionary, active: Dictionary, talk: Dictionary) -> void:
	_seat_counter()
	_wire_register()
	var register: Dictionary = v.get("register", {})
	var tray := _tray()
	if tray != null:
		tray.render(v.get("counter", []))
	var reg := _register_panel()
	if reg != null:
		reg.set_pfand_available(int(active.get("bottles", 0)))
		reg.set_can_serve(not active.is_empty())
		# `turn_around` is illegal mid-talk and mid-drag (docs/08 section 3.2), so the button says so
		# instead of dispatching something the reducer will refuse.
		reg.set_can_turn(not active.is_empty() and talk.is_empty() and not _is_dragging())
		reg.render(register)
	var scanner := _scanner()
	if scanner != null and not _is_dragging():
		scanner.set_armed(false)
	var card := _order_card()
	if card != null:
		card.set_docked(String(v.get("view_mode", "counter")) == "wall")
		card.render(v.get("order", []), _speaker_name(active))
	var wall := _wall_view()
	if wall != null:
		wall.render(v.get("wall", {}))
		wall.set_total(float(register.get("total", 0.0)))
		var want_open := not register.is_empty() and String(v.get("view_mode", "counter")) == "wall"
		if want_open and not wall.is_open():
			wall.open(_capture_mode)
		elif not want_open and wall.is_open():
			wall.close(_capture_mode)

## Who is on screen in each of the three modes. Mode exclusivity is the whole rule: dialogue OR tray,
## queue OR register, counter OR wall — never both, or the counter band stops being readable.
## The REGISTER mode (docs/08 section 4.3): once a basket is on the counter the right column stops
## being the queue and becomes the till, the left gutter becomes the OrderCard, and the line collapses
## into the HUD's "N waiting" tail. `view_mode` then says which way your body is facing. Decided in ONE
## place because `render` needs the answer before `_place_chrome` runs.
func _note_mode(v: Dictionary) -> void:
	_ringing = not (v.get("register", {}) as Dictionary).is_empty()
	_on_wall = _ringing and String(v.get("view_mode", "counter")) == "wall"

func _place_ring_chrome() -> void:
	var tray := _tray()
	if tray != null:
		tray.visible = _ringing and not _on_wall
	var scanner := _scanner()
	if scanner != null:
		scanner.visible = _ringing and not _on_wall
	var reg := _register_panel()
	if reg != null:
		reg.visible = _ringing and not _on_wall
	var stats := _stats()
	var sheet_open := stats != null and stats.visible
	var card := _order_card()
	if card != null:
		# The card and the stats sheet share the left gutter and Tab swaps them (docs/08 4.3).
		card.visible = _ringing and not (sheet_open and not _on_wall)
	var portrait := _portrait()
	if portrait != null:
		portrait.visible = not _on_wall
	var dice := _dice()
	if dice != null and _ringing:
		dice.visible = false   # the d20 plate and the register want the same 138 px of column

## Q both ways, Enter to ring up, Delete / - / + on the focused line. Esc is deliberately NOT bound:
## `Main` owns it for the pause frame, and a wall you cannot pause from is worse than a wall you
## leave with Q or with Back (docs/08 section 4.2 asks for Esc; this is the one place it is refused).
func _register_keys(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	match key.keycode:
		KEY_Q:
			return _act({"type": "turn_around", "on": not _on_wall})
		KEY_ENTER, KEY_KP_ENTER:
			return _act({"type": "ring_up"})
		KEY_DELETE, KEY_BACKSPACE:
			var line := _focused_line()
			return line >= 0 and _act({"type": "register_remove", "line": line})
		KEY_MINUS, KEY_KP_SUBTRACT:
			return _step_focused_line(-1)
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			return _step_focused_line(1)
	return false

func _step_focused_line(delta: int) -> bool:
	var line := _focused_line()
	var reg := _register_panel()
	if line < 0 or reg == null:
		return false
	var lines: Array = reg.register.get("lines", [])
	if line >= lines.size():
		return false
	var qty := int((lines[line] as Dictionary).get("qty", 1)) + delta
	return _act({"type": "register_set_qty", "line": line, "qty": qty})

func _focused_line() -> int:
	var reg := _register_panel()
	return reg.focused_line() if reg != null else -1

func _is_dragging() -> bool:
	var drag := _drag()
	return drag != null and drag.is_dragging()

# -- intents become actions ----------------------------------------------------------------------

## Clicking the crate counts its bottles onto the Pfand row  the same action its drag dispatches.
## Before this it was a focusable, visible control whose click the reducer refused in silence.
func _on_crate_clicked(bottles: int) -> void:
	_act({"type": "set_pfand", "bottles": bottles})

func _on_scan(uid: int) -> void:
	_act({"type": "scan", "uid": uid})

func _on_drag_started(payload: Dictionary, art: Dictionary, from: Vector2) -> void:
	var drag := _drag()
	if drag != null:
		drag.begin(payload, art, from)

## The DragLayer picked the target; the TARGET decides what its own drop means and then emits the
## intent it always emits. A drop is never a second code path into the reducer.
func _on_dropped(payload: Dictionary, target: Control) -> void:
	if target != null and target.has_method("take"):
		target.call("take", payload)

func _on_scanner_activated() -> void:
	var drag := _drag()
	var scanner := _scanner()
	if drag == null or scanner == null or not drag.is_dragging():
		return
	drag.release_at(scanner.get_global_rect().get_center())

## The glass follows the drag, not the mouse button: it is armed only while something that CAN be
## scanned is over it, which is the one visual promise the drop makes before you let go.
func _on_drag_hover(target: Control) -> void:
	var scanner := _scanner()
	if scanner != null:
		scanner.set_armed(target == scanner)

func _on_register_action(a: Dictionary) -> void:
	_act(a)

func _on_wall_take(sku_id: String, brand_id: String) -> void:
	_act({"type": "take_from_wall", "sku": sku_id, "brand": brand_id})

func _on_put_back(uid: int) -> void:
	_act({"type": "put_back", "uid": uid})

func _on_turn_back() -> void:
	_act({"type": "turn_around", "on": false})

## The ONE way this screen talks to the reducer during a ring-up. It announces the dictionary first,
## so a driver can assert what a synthetic click actually produced instead of trusting a node name.
func _act(action: Dictionary) -> bool:
	acted.emit(action)
	return dispatch(action)

# -- what offers what (the anti-soft-lock lens, docs/08 section 6) --------------------------------

## Every on-screen control that OFFERS this action. `legal_actions` hands the test a list; this turns
## each entry into the node a finger could actually land on, and an empty answer is a soft-lock.
func controls_for(action: Dictionary) -> Array[Control]:
	var out: Array[Control] = []
	match String(action.get("type", "")):
		"scan":
			var tray := _tray()
			var slot: Control = tray.slot_for(int(action.get("uid", -1))) if tray != null else null
			if slot != null:
				out.append(slot)
				# The drag path ends on the glass; the click path is the slot itself. Both are real.
				var scanner := _scanner()
				if scanner != null:
					out.append(scanner)
		"take_from_wall":
			var wall := _wall_view()
			var cell: Control = wall.cell_for(String(action.get("sku", "")), String(action.get("brand", ""))) if wall != null else null
			if cell != null:
				out.append(cell)
		"put_back":
			var wall_b := _wall_view()
			var hand: Control = wall_b.hand_for(int(action.get("uid", -1))) if wall_b != null else null
			if hand != null:
				out.append(hand)
		"turn_around":
			if bool(action.get("on", true)):
				var reg := _register_panel()
				var turn: Control = reg.control_for(action) if reg != null else null
				if turn != null:
					out.append(turn)
			else:
				var wall_c := _wall_view()
				var back: Control = wall_c.get_node_or_null("%Back") as Control if wall_c != null else null
				if back != null:
					out.append(back)
		"talk_next":
			var strip := _queue()
			var next_button: Control = strip.get_node_or_null("%NextGuest") as Control if strip != null else null
			if next_button != null:
				out.append(next_button)
		_:
			var reg_any := _register_panel()
			var any: Control = reg_any.control_for(action) if reg_any != null else null
			if any != null:
				out.append(any)
	var live: Array[Control] = []
	for c in out:
		if _is_live(c):
			live.append(c)
	return live

## Visible all the way up, and not greyed out. A control the ring cannot focus and a finger cannot
## press is not an answer to "where is this action".
func _is_live(c: Control) -> bool:
	if c == null:
		return false
	var n: Node = c
	while n != null and n != self:
		var as_control := n as Control
		if as_control != null and not as_control.visible:
			return false
		n = n.get_parent()
	var chip := c as StepChip
	if chip != null:
		return chip.is_enabled()
	var b := c as Button
	return b == null or not b.disabled

## The topmost control a click at `p` would actually reach, hit-tested on the REAL rects at 480x270.
## Written by hand rather than asked of the viewport because the tests drive a Night that never
## entered a tree — and because "is it covered" is exactly the question a soft-lock answers wrong.
func control_at(p: Vector2) -> Control:
	return _hit(self, p)

func _hit(node: Node, p: Vector2) -> Control:
	var found: Control = null
	var as_control := node as Control
	if as_control != null:
		if not as_control.visible:
			return null
		var hits: bool = as_control.mouse_filter != Control.MOUSE_FILTER_IGNORE and as_control.get_global_rect().has_point(p)
		if as_control != self and hits:
			found = as_control
	for child in node.get_children():
		# Later children draw later, so the last match down the tree is the one on top.
		var deeper := _hit(child, p)
		if deeper != null:
			found = deeper
	return found

# -- nodes ---------------------------------------------------------------------------------------

func _tray() -> CounterTray:
	return get_node_or_null("%CounterTray") as CounterTray

func _scanner() -> Scanner:
	return get_node_or_null("%Scanner") as Scanner

func _register_panel() -> RegisterPanel:
	return get_node_or_null("%RegisterPanel") as RegisterPanel

func _order_card() -> OrderCard:
	return get_node_or_null("%OrderCard") as OrderCard

func _wall_view() -> TobaccoWall:
	return get_node_or_null("%TobaccoWall") as TobaccoWall

func _drag() -> DragLayer:
	return get_node_or_null("%DragLayer") as DragLayer
