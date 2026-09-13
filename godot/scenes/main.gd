extends Control
## The shell: it owns which screen is on, and the fade between them. It holds no game state — the
## Session autoload does, once the engine lane lands; until then every screen runs on MockView.

const SCREENS := {
	"title": preload("res://scenes/Title.tscn"),
	"night": preload("res://scenes/Night.tscn"),
	"manage": preload("res://scenes/Manage.tscn"),
	"summary": preload("res://scenes/Summary.tscn"),
	# The season's end (day past `season_days`, or cash < -200). It had no screen at all: the shell
	# sent the player to Manage, where the reducer refuses every action (2026-09-13).
	"end": preload("res://scenes/Ending.tscn"),
}

## Which screen a capture preset belongs to, so `shot.mjs` can also be pointed at Main.
const PRESET_SCREEN := {
	"title": "title",
	"empty_counter": "night",
	"customer_at_counter": "night",
	"dialogue_choice": "night",
	"serving": "night",
	"pfand": "night",
	"late_night": "night",
	# The register screen (docs/06-dialogue-and-stats.md section 5).
	"queue_waiting": "night",
	"talk_lines": "night",
	"talk_choice": "night",
	"talk_result": "night",
	"manage": "manage",
	"summary": "summary",
	"ending": "end",
}

var current_screen: String = ""
## True while `_swap` is mounting a screen. A screen may ask for another one from its own first
## render (`add_child` runs `_ready` -> `Screen.refresh()` -> `render()`), and answering that inline
## would free the node in the middle of its own `_ready`.
var _swapping: bool = false

func _ready() -> void:
	Palette.prepare()
	_build_pause()
	show_screen("title", true)

## The pause overlay lives in the SHELL, not in a screen: Main is the one node that outlives every
## `_swap`, and until 2026-09-13 there was no route out of a running season at all — Manage's board
## modal is deliberately `closable = false`, Night and Summary carry no modal, and `Strings.PAUSED` /
## `RESUME` / `BACK_TO_TITLE` plus `Session.paused` were all declared and never used. Alt+F4 was it.
func _build_pause() -> void:
	var pause := _pause()
	if pause == null:
		return
	pause.title = Strings.PAUSED
	var menu := get_node_or_null("%PauseMenu") as Control
	if menu != null and menu.get_parent() != pause.content():
		pause.add_content(menu)
	_wire("%Resume", Strings.RESUME, close_pause)
	_wire("%BackToTitle", Strings.BACK_TO_TITLE, _on_back_to_title)
	_wire("%QuitGame", Strings.QUIT, _on_quit_game)
	if not pause.closed.is_connected(_on_pause_closed):
		pause.closed.connect(_on_pause_closed)

func _wire(unique: String, label: String, cb: Callable) -> void:
	var b := get_node_or_null(unique) as Button
	if b == null:
		return
	b.text = label
	if not b.pressed.is_connected(cb):
		b.pressed.connect(cb)

## Esc belongs to the shell. A child Modal (the pause frame itself, or Manage's board) sees unhandled
## input before its parent, so the Esc that CLOSES the overlay is already consumed by the time it
## would reach here — this can only ever open it.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# The Title already carries Settings and Quit; a second overlay there would be the second look.
	if current_screen == "" or current_screen == "title":
		return
	var pause := _pause()
	if pause == null or pause.visible:
		return
	open_pause()
	get_viewport().set_input_as_handled()

func open_pause() -> void:
	var pause := _pause()
	if pause == null:
		return
	_set_paused(true)
	pause.open()

## THE one exit: Resume, the frame's ×, and Esc all land here, and it is idempotent. `Session.paused`
## is cleared in exactly this function — left true it would stop `_process` ticking the night for
## ever, which is the one way this fix could itself soft-lock the game.
func close_pause() -> void:
	_set_paused(false)
	var pause := _pause()
	if pause != null and pause.visible:
		pause.close_modal()

func _on_pause_closed() -> void:
	_set_paused(false)

func _on_back_to_title() -> void:
	# No explicit save: `Session.dispatch` autosaves after every non-tick action, so Continue resumes.
	close_pause()
	show_screen("title")

func _on_quit_game() -> void:
	if is_inside_tree():
		get_tree().quit()

## NOT `get_tree().paused`, which would freeze the Modal's own fade and its buttons. `Session.paused`
## is the switch docs/05 §7 documents and `Session._process` already honours; look the autoload up
## defensively (a capture or a test runs without one).
func _set_paused(on: bool) -> void:
	var s := get_node_or_null("/root/Session")
	if s != null:
		s.set("paused", on)

func _pause() -> Modal:
	return get_node_or_null("%Pause") as Modal

func show_screen(screen_name: String, instant: bool = false) -> void:
	if not SCREENS.has(screen_name):
		push_warning("Main: unknown screen " + screen_name)
		return
	close_pause()   # a swap may never leave the overlay standing over the new screen
	var transition := get_node_or_null("%Transition") as Transition
	if instant or transition == null:
		_swap(screen_name)
	else:
		transition.cover_then(func() -> void: _swap(screen_name))

func apply_capture_preset(preset_name: String) -> void:
	var target: String = PRESET_SCREEN.get(preset_name, "night")
	_swap(target)
	var screen := _screen()
	if screen != null and screen.has_method("apply_capture_preset"):
		screen.apply_capture_preset(preset_name)

func _swap(screen_name: String) -> void:
	var host := get_node_or_null("%Screens") as Control
	if host == null:
		return
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
	var inst: Node = SCREENS[screen_name].instantiate()
	# `add_child` runs the screen's `_ready` -> `Screen.refresh()` -> `render()` synchronously, and a
	# screen whose FIRST render redirects (Night asks for the summary when the reducer is already past
	# the night) emits `request_screen` from inside that call. Connected afterwards, the emit went to a
	# signal with no listener and the latch made sure it was never asked again — the shell stranded the
	# player on a screen where `legal_actions` is empty (2026-09-13).
	current_screen = screen_name
	if inst.has_signal("request_screen"):
		inst.connect("request_screen", _on_request_screen)
	_swapping = true
	host.add_child(inst)
	_swapping = false

func _on_request_screen(screen_name: String) -> void:
	if screen_name == current_screen:
		return   # already there; a per-render re-emit must be idempotent, not a swap loop
	if _swapping:
		# It came from inside `_swap`'s own `add_child`: swapping here would free the screen while its
		# `_ready` is still running (measured: the rest of `_ready` then runs on a detached node).
		show_screen.call_deferred(screen_name)
		return
	show_screen(screen_name)

func _screen() -> Node:
	var host := get_node_or_null("%Screens") as Control
	if host == null or host.get_child_count() == 0:
		return null
	return host.get_child(0)
