class_name Screen
extends Control
## Base for every composed screen (Title / Night / Manage / Summary). It owns the three things all
## screens share and nothing else:
##   * `view()`  — the read-model: Session's if the autoload exists, otherwise the mock preset, so
##                 every screen runs, renders and captures before the engine lane lands.
##   * `dispatch(action)` — the ONE way a screen talks back. With Session it dispatches for real and
##                 re-renders; without it, it prints the action so the screen is still demoable.
##   * `apply_capture_preset(name)` — docs/02-art-pipeline.md. Subclasses extend it for UI state
##                 (panel open, picks in the till) that the read-model does not carry.

signal request_screen(screen_name: String)

## Used when there is no Session: which MockView preset this screen shows on its own.
@export var default_preset: String = ""

var _view: Dictionary = {}
var _capture_mode: bool = false

func _ready() -> void:
	Palette.prepare()
	if _view.is_empty() and default_preset != "":
		_view = MockView.view(default_preset)
	_connect_session()
	refresh()

func session() -> Node:
	# Autoloads are children of /root — `Engine.has_singleton` would never see them. A screen the tests
	# or a capture instantiate outside the tree has no Session at all (an absolute path would error).
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/Session")

func view() -> Dictionary:
	# A capture preset is deterministic by definition: it never reads the live Session.
	if _capture_mode:
		return _view
	var s := session()
	if s != null and s.has_method("view"):
		return s.view()
	return _view

func refresh() -> void:
	# A screen Main has already swapped out stays connected to Session for the rest of the frame.
	# Rendering it would re-seat its live nodes from the CAPTURE MOCK — `view()` falls back to `_view`
	# once `session()` is out of reach — instead of the real read-model. A detached screen draws
	# nothing, so it renders nothing.
	if not is_inside_tree():
		return
	render(view())

## Is the shell's pause overlay up? A screen that takes keys of its own (Night: Tab and Space) must
## stand still behind it — the Dim stops the mouse, nothing stops the keyboard.
func is_paused() -> bool:
	var s := session()
	return s != null and bool(s.get("paused"))

## Subclasses override. Never mutates state; reads the dictionary and sets nodes.
func render(_v: Dictionary) -> void:
	pass

func apply_capture_preset(preset_name: String) -> void:
	_capture_mode = true
	_view = MockView.view(preset_name)
	render(_view)

## Returns whether the REDUCER took the action. A screen must never navigate on a refusal: that is
## how "Open up" at the end of a season walked the player onto a Night screen the engine had already
## finished with (2026-09-13). Callers that do not care may ignore the value.
func dispatch(action: Dictionary) -> bool:
	var s := session()
	if s != null and s.has_method("dispatch"):
		var ok: bool = s.dispatch(action)
		refresh()
		return ok
	# No Session (a capture preset, or a screen instantiated outside the tree): there is nothing to
	# refuse, so the demo path navigates exactly as it always did.
	print("[dispatch] ", JSON.stringify(action))
	return true

## Which screen belongs to a reducer phase. THE route table — a "next" press follows the phase the
## reducer actually returned, never a hard-coded name: `advance_day` can end the season (day past
## `season_days`, or cash < -200) under any of them.
static func screen_for(phase: String) -> String:
	match phase:
		"night":
			return "night"
		"summary":
			return "summary"
		"end":
			return "end"
	return "manage"

func _connect_session() -> void:
	var s := session()
	if s == null:
		return
	if s.has_signal("changed") and not s.is_connected("changed", _on_session_changed):
		s.connect("changed", _on_session_changed)

func _on_session_changed(_prev: Dictionary, _next: Dictionary) -> void:
	refresh()
