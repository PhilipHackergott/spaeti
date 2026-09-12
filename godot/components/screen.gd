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
	# Autoloads are children of /root — `Engine.has_singleton` would never see them.
	return get_node_or_null("/root/Session")

func view() -> Dictionary:
	var s := session()
	if s != null and s.has_method("view"):
		return s.view()
	return _view

func refresh() -> void:
	render(view())

## Subclasses override. Never mutates state; reads the dictionary and sets nodes.
func render(_v: Dictionary) -> void:
	pass

func apply_capture_preset(preset_name: String) -> void:
	_capture_mode = true
	_view = MockView.view(preset_name)
	render(_view)

func dispatch(action: Dictionary) -> void:
	var s := session()
	if s != null and s.has_method("dispatch"):
		s.dispatch(action)
		refresh()
	else:
		print("[dispatch] ", JSON.stringify(action))

func _connect_session() -> void:
	var s := session()
	if s == null:
		return
	if s.has_signal("changed") and not s.is_connected("changed", _on_session_changed):
		s.connect("changed", _on_session_changed)

func _on_session_changed(_prev: Dictionary, _next: Dictionary) -> void:
	refresh()
