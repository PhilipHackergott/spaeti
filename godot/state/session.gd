extends Node
## The `Session` autoload (docs/05-engine-api.md §7) — the ONLY mutable game object.
## Scenes never touch `state`: they `dispatch()` actions and re-render from `view()`.
## `event` replays every new log entry in order, which is the FX/SFX stream (kinds: open, arrive,
## serve, tip, balk, pfand, ethics, beat, check, upgrade, ordnungsamt, raid, close).

signal changed(prev: Dictionary, next: Dictionary)
signal event(entry: Dictionary)

const SAVE_PATH := "user://autosave.json"

var state: Dictionary = {}
## While true `_process` stops ticking the night (menus, dialogue takeovers, the editor).
var paused: bool = false

var _view_cache: Dictionary = {}
var _view_valid: bool = false

func _ready() -> void:
	if state.is_empty():
		new_game()

func new_game(config: Dictionary = {}) -> void:
	var prev := state
	state = SpatiState.new_game(config)
	_view_valid = false
	changed.emit(prev, state)

## Returns false when the action was illegal — the reducer handed back the same state, unchanged.
func dispatch(action: Dictionary) -> bool:
	var prev := state
	var next := Rules.apply(prev, action)
	if is_same(next, prev):
		return false
	var from := (prev["log"] as Array).size() if prev.has("log") else 0
	state = next
	_view_valid = false
	changed.emit(prev, next)
	var entries: Array = next["log"]
	for i in range(from, entries.size()):
		event.emit(entries[i])
	# Autosave on every player action (never on the per-frame tick): the title's "Continue" resumes the
	# exact frame — mid-conversation included, which is what test_dialogue round-trips.
	if String(action.get("type", "")) != "tick":
		save()
	return true

## Rules.view(state), memoised until the next successful dispatch — a screen may call it per frame.
func view() -> Dictionary:
	if not _view_valid:
		_view_cache = Rules.view(state)
		_view_valid = true
	return _view_cache

func legal_actions() -> Array:
	return Rules.legal_actions(state)

func _process(delta: float) -> void:
	if state.is_empty() or paused:
		return
	if state["phase"] == "night":
		dispatch({"type": "tick", "dt_ms": int(delta * 1000.0)})

func save() -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(SpatiState.to_json(state))
	f.close()
	return true

## Is there something for the title's "Continue" to load?
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var loaded := SpatiState.from_json(f.get_as_text())
	f.close()
	if loaded.is_empty():
		return false
	var prev := state
	state = loaded
	_view_valid = false
	changed.emit(prev, state)
	return true
