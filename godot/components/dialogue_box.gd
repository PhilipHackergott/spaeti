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
## The rows are built and on screen. The SCREEN decides what to do with that (the night anchors the
## keyboard on them); the box only says when.
signal choices_shown()

const CHOICE_SCENE := preload("res://components/PixelButton.tscn")
## An inline BRAND MARK. `{logo.<sku>}` substitutes a brand's FACING ASSET ID into a spoken line
## (docs/09 §1 rule 3): the token is a PICTURE, not a word, so the box DRAWS it with `BrandMark` —
## the one place a mark is ever drawn (docs/08 §4.1) — instead of printing "tob/pack_fuchs" into the
## middle of a sentence, which is what shipped until 2026-09-13 and reads as a bug in four lines.
## Recognition is DATA-DRIVEN (`Content.brand_by_icon`), never a guess about the shape of the string:
## a word is a glyph because the catalogue says that id is a facing, not because it contains a slash.
const GLYPH_SCENE := preload("res://components/BrandMark.tscn")
## The mark window is 16x16 and a pixel crop is never resampled (docs/08 §2), so the glyph is drawn at
## its own size and the body's 16-px line box is exactly tall enough to seat it.
const GLYPH_PX := 16
## Punctuation that may ride on the end of a token without being part of the asset id — "…the fox.
## {logo.cigarettes}." ends a sentence, and the full stop still has to print.
const GLYPH_TRAIL := ".,;:!?)\"'"

## The word-flow that replaces the plain Body label on a line that carries a mark. Built only for
## those lines: every other line in the game keeps the single autowrapped Label it always had.
var _rich: HFlowContainer = null
## [{node, start:int, len:int, glyph:bool}] — where each piece sits in the line's character count, so
## the typewriter can reveal a mixed row of words and marks in one pass.
var _rich_parts: Array = []
var _rich_chars: int = 0
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
	# The height comes from the panel's minimum size, and an autowrapped choice row only reports its real
	# line count AFTER the container has laid it out at its final width. Both measurements in `_fit_height`
	# can therefore still be the wrap-at-no-width guess (a two-choice node measured 765 px): the box grew
	# past the top of the frame and its STOP rect swallowed the clicks over the whole counter. The panel
	# says when its minimum has actually settled, so the height is re-applied then instead of trusted once.
	var panel := get_node_or_null("%Box") as Control
	if panel != null and not panel.minimum_size_changed.is_connected(_apply_height):
		panel.minimum_size_changed.connect(_apply_height)
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
	_clear_rich()
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
	if not _rich_parts.is_empty():
		_reveal_rich(int(_revealed))
		if _revealed >= float(_rich_chars):
			_reveal_all()
		return
	body.visible_characters = int(_revealed)
	if _revealed >= float(body.text.length()):
		_reveal_all()

func _show_line(instant: bool) -> void:
	var body := _body()
	if body == null:
		return
	var text := String(_lines[_line_index]) if _line_index < _lines.size() else ""
	# The plain Label stays the body of record even when the flow is what is on screen: the capture
	# tests and `test_scenes.gd` read `%Body`, and a line that is drawn elsewhere must still be
	# readable there rather than silently becoming an empty string.
	body.text = text
	body.visible_characters = 0
	_build_rich(text)
	body.visible = _rich_parts.is_empty()
	_revealed = 0.0
	_typing = not (instant or Palette.reduce_motion)
	if not _typing:
		_reveal_all()
	elif not _rich_parts.is_empty():
		_reveal_rich(0)
	_update_mark()
	_fit_height()

func _reveal_all() -> void:
	_typing = false
	var body := _body()
	if body != null:
		body.visible_characters = -1
	if not _rich_parts.is_empty():
		_reveal_rich(_rich_chars)
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
	choices_shown.emit()

## The keyboard's way in. Godot only walks the focus ring FROM an existing owner, so a choice list
## with nothing focused is a mouse-only decision (probed 2026-09-13: eight keys, no focus, nothing
## moved). The box knows WHICH row can be pressed; it does not decide when — the screen does.
func focus_first_choice() -> void:
	var box := _choices_node()
	if box == null or not visible or not box.visible or not is_inside_tree():
		return
	for row in box.get_children():
		var btn := (row as Node).get_node_or_null("Line") as Button
		if btn != null and not btn.disabled and btn.is_visible_in_tree():
			btn.grab_focus()
			return

## Pick the choice a row's printed number names (`Strings.CHOICE_NUMBER`, "1." / "2."). The box that
## writes the number owns the lookup, and it COUNTS GATES because the screen does: with "2." locked,
## "3." is still `choices[2]`. False when the number names nothing pickable, so the caller leaves the
## key unhandled instead of swallowing it.
func choose_number(n: int) -> bool:
	var box := _choices_node()
	if box == null or not box.visible or n < 1 or n > box.get_child_count():
		return false
	var btn := box.get_child(n - 1).get_node_or_null("Line") as Button
	if btn == null or btn.disabled:
		return false
	_on_choice(n - 1)
	return true

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

# -- the inline mark -----------------------------------------------------------------------------

## The brand whose facing this word names, or {} — plus the punctuation that was riding on it.
## A word is a glyph because `Content.brand_by_icon` KNOWS that id, which is the same rule the rest
## of the project follows: never trust the shape of a name, ask the read-model.
static func glyph_of(word: String) -> Dictionary:
	var trimmed := word
	var trail := ""
	while trimmed.length() > 0 and GLYPH_TRAIL.contains(trimmed.right(1)):
		trail = trimmed.right(1) + trail
		trimmed = trimmed.left(trimmed.length() - 1)
	var row := Content.brand_by_icon(trimmed)
	if row.is_empty():
		return {}
	return {"row": row, "trail": trail}

## Does this line carry a mark at all? Almost none do, and the ones that do not must keep the single
## autowrapped Label they have always had — the flow below is a different layout, and switching every
## line to it to serve four would be a rewrite of how the whole game reads.
static func line_has_mark(text: String) -> bool:
	for word in text.split(" ", false):
		if not glyph_of(String(word)).is_empty():
			return true
	return false

## Lay the line out as a WORD FLOW: one Label per word, one `BrandMark` per facing id, wrapped by an
## `HFlowContainer` at the box's own width. Godot's Label cannot hold an image and `RichTextLabel`'s
## `[img]` needs a file on disk — which would lose `BrandMark`'s code-drawn fallback, the thing that
## lets the mechanic ship before the art does (docs/08 §2). So the words are split instead.
func _build_rich(text: String) -> void:
	_clear_rich()
	if not line_has_mark(text):
		return
	var host := _rich_node()
	if host == null:
		return
	var cursor := 0
	for raw in text.split(" ", false):
		var word := String(raw)
		var hit := glyph_of(word)
		if hit.is_empty():
			host.add_child(_word_label(word))
			_rich_parts.append({"node": host.get_child(host.get_child_count() - 1), "start": cursor,
				"len": word.length(), "glyph": false})
			cursor += word.length() + 1
			continue
		var chip: BrandMark = GLYPH_SCENE.instantiate()
		host.add_child(chip)
		chip.set_brand(hit["row"] as Dictionary, GLYPH_PX)
		chip.custom_minimum_size = Vector2(GLYPH_PX, GLYPH_PX)
		_rich_parts.append({"node": chip, "start": cursor, "len": 1, "glyph": true})
		cursor += 2
		# The full stop that ended the sentence is not part of the picture, so it prints beside it —
		# with no leading space, which is why it is its own zero-gap label rather than the next word.
		var trail := String(hit["trail"])
		if trail != "":
			var tail := _word_label(trail)
			host.add_child(tail)
			_rich_parts.append({"node": tail, "start": cursor, "len": trail.length(), "glyph": false})
			cursor += trail.length()
	_rich_chars = cursor
	host.visible = true

## One word, in the body's own face and colour — a flow row has to look exactly like the Label it
## replaced or the four lines that carry a mark would read in a different font from every other line.
func _word_label(word: String) -> Label:
	var l := Label.new()
	l.text = word
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", Palette.TEXT_WHITE)
	l.visible_characters = 0
	return l

## Reveal `n` characters across the mixed row — the same typewriter, counting a mark as one character.
func _reveal_rich(n: int) -> void:
	for entry in _rich_parts:
		var part: Dictionary = entry
		var node: Node = part["node"]
		if not is_instance_valid(node):
			continue
		var shown := n - int(part["start"])
		if bool(part["glyph"]):
			(node as Control).visible = shown > 0
			continue
		var label := node as Label
		label.visible_characters = -1 if shown >= int(part["len"]) else maxi(0, shown)

func _clear_rich() -> void:
	_rich_parts = []
	_rich_chars = 0
	if _rich == null or not is_instance_valid(_rich):
		return
	for c in _rich.get_children():
		_rich.remove_child(c)
		c.queue_free()
	_rich.visible = false

## The flow lives beside the Body label in the same VBox, built on first use — a box that never meets
## a mark never grows the node at all.
func _rich_node() -> HFlowContainer:
	if _rich != null and is_instance_valid(_rich):
		return _rich
	var body := _body()
	if body == null or body.get_parent() == null:
		return null
	_rich = HFlowContainer.new()
	_rich.name = "RichBody"
	_rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The gap between children IS the space between words, measured off the real face rather than
	# guessed — Jersey 10's space is not the 4 px a theme constant would have assumed.
	_rich.add_theme_constant_override("h_separation", _space_px(body))
	_rich.add_theme_constant_override("v_separation", 0)
	_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var host := body.get_parent()
	host.add_child(_rich)
	host.move_child(_rich, body.get_index() + 1)
	_rich.visible = false
	return _rich

## The width of one space in the body's own font.
static func _space_px(body: Label) -> int:
	var f := body.get_theme_font("font")
	if f == null:
		return 4
	return int(f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, body.get_theme_font_size("font_size")).x)

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
