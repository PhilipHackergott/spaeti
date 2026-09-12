class_name DialogueBox
extends Control
## The centrepiece (art-direction.md section 5): a dark translucent box across the counter with the
## speaker's name in their own colour, white body text typed out, a blinking continue mark, and the
## choices stacked just above it. It renders `view.dialogue` (docs/05 section 5) and emits the index
## the player chose — `resolve_beat` / `resolve_vignette` are built by the scene, not here.

signal choice(index: int)
signal advanced()
signal finished()

const CHOICE_SCENE := preload("res://components/PixelButton.tscn")

## Typewriter speed. The capture presets always render instantly, so a screenshot is never half-typed.
@export var chars_per_second: float = 45.0

var _lines: Array = []
var _line_index: int = 0
var _choices: Array = []
var _typing: bool = false
var _revealed: float = 0.0
## The dialogue currently on screen. `night.gd::render` re-sends the same one on every Session tick
## (~60x/s during the night), so without this the typewriter would restart from character 0 forever
## and `advance()` would be undone on the next frame.
var _current: Dictionary = {}

func _ready() -> void:
	Palette.prepare()
	# Coffee Talk's body is white against the coloured speaker name; the colour is a Palette token,
	# never a Color() in the .tscn (docs/04 rule 1).
	var body := _body()
	if body != null:
		body.add_theme_color_override("font_color", Palette.TEXT_WHITE)
	var mark := get_node_or_null("%Continue") as Polygon2D
	if mark != null:
		mark.color = Palette.AMBER_SOFT
		_blink(mark)
	set_process(true)

## `d` is `view.dialogue`: {speaker, portrait, expression, lines, choices, kind}. Empty hides the box.
func show_dialogue(d: Dictionary, instant: bool = false) -> void:
	if d.is_empty():
		clear()
		return
	if _same_dialogue(d):
		return
	_current = d.duplicate(true)
	visible = true
	_lines = d.get("lines", [])
	_choices = d.get("choices", [])
	_line_index = 0
	var speaker := get_node_or_null("%Speaker") as Label
	if speaker != null:
		speaker.text = String(d.get("speaker", ""))
		speaker.add_theme_color_override("font_color", Palette.speaker_colour(_character_of(d)))
	_clear_choices()
	_show_line(instant)

## Capture helper: jump straight to the last line with the choices already stacked, so a screenshot
## of `dialogue_choice` shows the decision the way the player meets it.
func show_final(d: Dictionary) -> void:
	show_dialogue(d, true)
	if _lines.is_empty():
		return
	_line_index = _lines.size() - 1
	_show_line(true)

func clear() -> void:
	visible = false
	_current = {}
	_lines = []
	_choices = []
	_typing = false
	_clear_choices()

## Click / space: finish the line, then walk to the next, then offer the choices.
func advance() -> void:
	if _typing:
		_reveal_all()
		return
	if _line_index < _lines.size() - 1:
		_line_index += 1
		_show_line(false)
		advanced.emit()
		return
	if not _choices.is_empty() and _choices_node().get_child_count() == 0:
		_build_choices()
		return
	if _choices.is_empty():
		finished.emit()

## Same speaker, same words, same choices = the same moment; only a real change retypes.
func _same_dialogue(d: Dictionary) -> bool:
	if _current.is_empty():
		return false
	for key in ["speaker", "portrait", "kind"]:
		if String(d.get(key, "")) != String(_current.get(key, "")):
			return false
	var lines: Array = d.get("lines", [])
	var was: Array = _current.get("lines", [])
	if lines.size() != was.size():
		return false
	for i in lines.size():
		if String(lines[i]) != String(was[i]):
			return false
	var choices: Array = d.get("choices", [])
	var had: Array = _current.get("choices", [])
	if choices.size() != had.size():
		return false
	for i in choices.size():
		if String((choices[i] as Dictionary).get("label", "")) != String((had[i] as Dictionary).get("label", "")):
			return false
	return true

func is_typing() -> bool:
	return _typing

func _process(delta: float) -> void:
	if not _typing:
		return
	var body := _body()
	if body == null:
		return
	_revealed += chars_per_second * delta
	body.visible_characters = int(_revealed)
	if _revealed >= float(body.text.length()):
		_reveal_all()

func _show_line(instant: bool) -> void:
	var body := _body()
	if body == null:
		return
	body.text = String(_lines[_line_index]) if _line_index < _lines.size() else ""
	_revealed = 0.0
	body.visible_characters = 0
	_typing = not (instant or Palette.reduce_motion)
	if not _typing:
		_reveal_all()
	_update_mark()

func _reveal_all() -> void:
	_typing = false
	var body := _body()
	if body != null:
		body.visible_characters = -1
	_revealed = 0.0
	if _line_index >= _lines.size() - 1 and not _choices.is_empty():
		_build_choices()
	_update_mark()

func _build_choices() -> void:
	var box := _choices_node()
	if box == null or box.get_child_count() > 0:
		return
	for i in _choices.size():
		var entry: Dictionary = _choices[i]
		var btn: PixelButton = CHOICE_SCENE.instantiate()
		btn.theme_type_variation = &"ChoiceButton"
		btn.text = Strings.CHOICE_NUMBER % [i + 1, String(entry.get("label", ""))]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.action = {"choice": i}
		btn.pressed.connect(_on_choice.bind(i))
		box.add_child(btn)
	box.visible = true
	_update_mark()

func _clear_choices() -> void:
	var box := _choices_node()
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.visible = false

func _on_choice(index: int) -> void:
	choice.emit(index)

func _update_mark() -> void:
	var mark := get_node_or_null("%Continue") as Polygon2D
	if mark == null:
		return
	mark.visible = not _typing and _choices_node() != null and _choices_node().get_child_count() == 0

func _blink(mark: Polygon2D) -> void:
	if Palette.reduce_motion or not is_inside_tree():
		return
	var tw := create_tween().set_loops()
	tw.tween_property(mark, "modulate:a", 0.25, 0.55)
	tw.tween_property(mark, "modulate:a", 1.0, 0.55)

func _body() -> Label:
	return get_node_or_null("%Body") as Label

func _choices_node() -> VBoxContainer:
	return get_node_or_null("%Choices") as VBoxContainer

func _character_of(d: Dictionary) -> String:
	var pid := String(d.get("portrait", ""))
	return pid.substr(pid.rfind("/") + 1)

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()
