class_name DialogueBox
extends Control
## The centrepiece (art-direction.md section 5): a dark translucent box across the counter with the
## speaker's name in their own colour, white body text typed out, a blinking continue mark, and the
## choices listed INSIDE the same panel under the last line (2026-09-13: they used to stack above it as
## bordered chips, and the whole thing covered 42 % of the frame). The box keeps its bottom edge on
## `Palette.DIALOGUE_RECT` and grows upward only as far as its content needs. It renders `view.dialogue` (docs/05 section 5) and emits the index
## the player chose — `resolve_beat` / `resolve_vignette` are built by the scene, not here.

signal choice(index: int)
signal advanced()
signal finished()

const CHOICE_SCENE := preload("res://components/PixelButton.tscn")
## The bottom edge never moves: the counter band ends where Coffee Talk's text box ends.
const BOTTOM_Y := Palette.DIALOGUE_RECT.position.y + Palette.DIALOGUE_RECT.size.y

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
	# The screen resizes the box AFTER handing it a line (the queue and the serve panel each take a
	# column back), so the mark has to follow the edge rather than be placed once per line.
	if not resized.is_connected(_update_mark):
		resized.connect(_update_mark)
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
		var now: Dictionary = choices[i]
		var was_choice: Dictionary = had[i]
		if String(now.get("label", "")) != String(was_choice.get("label", "")):
			return false
		# A gate that just opened (or a DC that moved) is a different moment, even at the same words.
		if bool(now.get("locked", false)) != bool(was_choice.get("locked", false)):
			return false
		if _tag_text(now) != _tag_text(was_choice):
			return false
	return true

## The scene owns the WIDTH (the queue and the serve panel each take a column back); the box owns its
## height. Setting the size directly from outside would fight `_fit_height`.
func set_width(w: float) -> void:
	if size.x != w:
		size.x = w
		_fit_height()

## Bottom edge fixed at `BOTTOM_Y`; height = what the panel's content needs, never less than the authored
## 64 px (one speaker line + up to two body lines), so the plain box keeps Coffee Talk's proportions
## and only a choice list grows it. Deferred once as well, because an autowrapped label reports its
## line count for the width it had when it was last laid out.
var _fit_pending: bool = false

func _fit_height() -> void:
	_apply_height()
	if not _fit_pending:
		_fit_pending = true
		call_deferred("_fit_deferred")

func _fit_deferred() -> void:
	_fit_pending = false
	_apply_height()

func _apply_height() -> void:
	var box := get_node_or_null("%Box") as Control
	if box == null:
		return
	var h := maxf(float(Palette.DIALOGUE_RECT.size.y), box.get_combined_minimum_size().y)
	if h != size.y or position.y != float(BOTTOM_Y) - h:
		size.y = h
		position.y = float(BOTTOM_Y) - h

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
	_fit_height()

func _reveal_all() -> void:
	_typing = false
	var body := _body()
	if body != null:
		body.visible_characters = -1
	_revealed = 0.0
	if _line_index >= _lines.size() - 1 and not _choices.is_empty():
		_build_choices()
	_update_mark()

## One row per choice: the line itself in a ChoiceButton, and — when the choice rolls or is gated —
## its tag beside it (docs/06 section 2). The tag is a SIBLING, not text inside the button: a label
## cannot colour half of itself, and an overlay would run under a long choice.
func _build_choices() -> void:
	var box := _choices_node()
	if box == null or box.get_child_count() > 0:
		return
	for i in _choices.size():
		box.add_child(_choice_row(_choices[i], i))
	box.visible = true
	_update_mark()
	_fit_height()

## A rolled choice puts its tag on the same line (it is short: "[Charisma 12]"). A GATE puts its
## reason underneath instead, because "locked: needs Strength 12" plus the choice itself does not fit
## across a 300-px counter - and a clipped explanation is worse than no explanation at all.
func _choice_row(entry: Dictionary, index: int) -> BoxContainer:
	var locked := bool(entry.get("locked", false))
	var row: BoxContainer = (VBoxContainer.new() if locked else HBoxContainer.new())
	row.name = "Choice%d" % (index + 1)
	row.add_theme_constant_override("separation", 0 if locked else 4)
	var btn: PixelButton = CHOICE_SCENE.instantiate()
	btn.name = "Line"
	btn.theme_type_variation = &"ChoiceButton"
	# Inside the panel a choice is a LINE, not a chip: the Theme's bordered ChoiceButton box stays for hover
	# and focus (the player must see what they are about to pick), the resting state is flat.
	btn.add_theme_stylebox_override("normal", Palette.flat_row())
	btn.text = Strings.CHOICE_NUMBER % [index + 1, _plain_label(entry)]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# WRAP, never clip. With a line waiting the box is 300 px (`DIALOGUE_W_QUEUE`), which leaves ~272 px
	# of button after the panel margins and the row padding — 26 of the 139 authored choices are longer
	# than that, and clipping ended them mid-word in the middle of a sentence the player has to read to
	# choose it. The box is bottom-pinned and `_fit_height`/`_fit_deferred` re-measure from the combined
	# minimum size (deferred on purpose, because an autowrapped control only reports its line count
	# after a layout pass), so a wrapped row simply grows the panel upward.
	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.action = {"choice": index}
	# A gate is SHOWN and greyed, never hidden: the player has to be able to see the door they cannot
	# open yet (docs/06 section 2). Disabled also keeps it out of the keyboard's focus chain.
	btn.disabled = locked
	btn.focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	if locked:
		# The Theme has no `disabled` box for a ChoiceButton, so a greyed choice fell back to the
		# generic one and all but vanished over the bust (second capture: row 3 sat on Lena's face).
		# A gate has to stay READABLE - it is information, not a disabled control.
		btn.add_theme_stylebox_override("disabled", Palette.flat_row(Palette.INK, Palette.RULE))
		btn.add_theme_color_override("font_disabled_color", Palette.TEXT_DIM)
	else:
		btn.pressed.connect(_on_choice.bind(index))
	row.add_child(btn)
	var tag := _tag_text(entry)
	if tag != "":
		var l := Label.new()
		l.name = "Tag"
		l.text = tag
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# The tag carries its own ground for the same reason the choice does: it is printed over the
		# set, and cyan-on-anything is not a contract you can keep.
		l.add_theme_stylebox_override("normal", Palette.box(Palette.INK, Palette.RULE, 2, 4))
		if locked:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Accent = a die will be rolled; dim = a door that is shut. Both also say so in words.
		l.add_theme_color_override("font_color", Palette.TEXT_DIM if locked else Palette.ACCENT)
		row.add_child(l)
	return row

## The choice's own words, with any authored "[Charisma 12]" prefix taken off — the tag is rendered
## separately and in its own colour, and printing it twice is how a label ends up clipped.
static func _plain_label(entry: Dictionary) -> String:
	var label := String(entry.get("label", ""))
	if label.begins_with("["):
		var close := label.find("]")
		if close > 0:
			return label.substr(close + 1).strip_edges()
	return label

## "[Charisma 12]" for a roll, "locked: needs Strength 12" for a gate, "" for a plain line. The engine
## may hand us its own `reason`; when it does not, the string table composes one from `requires`.
static func _tag_text(entry: Dictionary) -> String:
	if bool(entry.get("locked", false)):
		# Prefer the gate itself: then the WHOLE sentence is the string table's and can be translated.
		var requires: Dictionary = entry.get("requires", {})
		if not requires.is_empty():
			return Strings.locked_reason(String(requires.get("stat", "")), int(requires.get("min", 0)))
		# Otherwise the engine already wrote the half that names the stat and the number
		# (Talk.choice_views), and the table frames it so "locked" is still written in one place.
		var reason := String(entry.get("reason", ""))
		if reason != "":
			return Strings.locked(reason)
		var gate: Dictionary = entry.get("check", {})
		if not gate.is_empty():
			return Strings.locked_reason(String(gate.get("stat", "")), int(gate.get("dc", 0)))
		return ""
	var check: Dictionary = entry.get("check", {})
	if check.is_empty():
		return ""
	return Strings.check_tag(String(check.get("stat", "")), int(check.get("dc", 0)))

func _clear_choices() -> void:
	var box := _choices_node()
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	box.visible = false
	_fit_height()

func _on_choice(index: int) -> void:
	choice.emit(index)

func _update_mark() -> void:
	var mark := get_node_or_null("%Continue") as Polygon2D
	if mark == null:
		return
	# The box is not always 400 wide any more (the serve panel and the queue each take a column back),
	# so the mark is placed against the CURRENT inside edge instead of the .tscn corner it was authored
	# in - the first register capture had it floating in the wood, 90 px past the box.
	mark.position = Palette.snap(Vector2(size.x - 14.0, size.y - 10.0))
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
