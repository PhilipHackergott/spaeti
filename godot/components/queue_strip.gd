class_name QueueStrip
extends Control
## The line at the register (docs/06-dialogue-and-stats.md section 5): the guests who are waiting,
## FIFO, lined up at the right end of the counter with the first one highlighted. Clicking the strip
## — or the button under them — is `talk_next`: "Next guest" with a clear counter, "Talk to them" when
## somebody is already standing there (the reducer promotes nobody on tick unless `auto_take_next`).
##
## The chips are code-drawn busts, not shrunken portraits: a 144x174 bust cannot be put in a 28-px
## slot without either scaling it (which kills the pixel grid, docs/01) or cropping it down to a
## nostril. So a chip is a silhouette in the speaker's own colour — the same colour the DialogueBox
## prints their name in — and the first guest's NAME is spelled out above the line.
##
## It owns no state: `set_queue()` takes `view.queue` and re-draws. The chips are built at runtime
## because a queue is a list (docs/01 "scripts fill lists; they do not build the screen").

signal talk_next()

var _queue: Array = []
var _can_start: bool = false
## Somebody is already standing at the counter, so `talk_next` means "talk to THEM", not "take the head
## of the line" — the same action, two meanings, and the strip has to print the one it will do.
var _at_counter: bool = false

func _ready() -> void:
	Palette.prepare()
	position = Vector2(Palette.QUEUE_RECT.position)
	custom_minimum_size = Vector2(Palette.QUEUE_RECT.size)
	size = Vector2(Palette.QUEUE_RECT.size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The line stands against the door and the neon outside; without a ground of its own the first
	# guest's name was unreadable over the window (first capture).
	var plate := get_node_or_null("Plate") as PanelContainer
	if plate != null:
		plate.add_theme_stylebox_override("panel", Palette.box(Palette.INK_DEEP, Palette.EDGE, 2, 2))
	var btn := _next_button()
	if btn != null:
		btn.text = Strings.NEXT_GUEST
		btn.action = {"type": "talk_next"}
		if not btn.pressed.is_connected(_on_next):
			btn.pressed.connect(_on_next)
	_rebuild()

## `queue` is `view.queue` (FIFO, first = next to be served). `can_start` mirrors `legal_actions`:
## true when `talk_next` is on offer, which is whenever no conversation is open and there is anybody
## to talk to - at the counter OR in the line, because `talk_next` also opens the conversation with
## whoever is already at the counter (Rules.apply -> talk_next -> _open_talk); the reducer promotes
## the head of the line by itself only under `config.auto_take_next`, otherwise they age out in the
## line (Rules._age_queue, docs/06 section 7). So the button and the line are shown independently: the
## strip can be a button with nobody behind it, or a line with the counter busy, or both.
##
## `at_counter` is which of the two `talk_next` means right now, and the button says so: a button
## labelled "Next guest" that starts THIS guest's conversation and leaves the line untouched is the
## same word for two different things.
func set_queue(queue: Array, can_start: bool, at_counter: bool = false) -> void:
	_queue = queue
	_can_start = can_start
	_at_counter = at_counter
	visible = not queue.is_empty() or can_start
	var btn := _next_button()
	if btn != null:
		btn.visible = can_start
		btn.text = Strings.TALK_TO_GUEST if at_counter else Strings.NEXT_GUEST
	var plate := get_node_or_null("Plate") as Control
	if plate != null:
		plate.visible = not queue.is_empty()
	_rebuild()

func is_empty() -> bool:
	return _queue.is_empty()

## The strip authors its button at this inset inside `Palette.QUEUE_RECT` — under the line, because
## the want bubble stands beside the bust at y 74..120 and a button at the top of the column covered it.
const BUTTON_INSET := Rect2i(8, 64, 116, 18)

## Where the strip stands. The register mode (docs/08 4.3) has no room for the LINE — the register
## owns the right column and the HUD's "N waiting" tail carries the count — but `talk_next` is still
## legal with a guest at the counter, so the strip re-docks to a button-sized plate instead of
## disappearing. Collapsing a list is fine; hiding a legal action is not.
func set_dock(r: Rect2i, button_only: bool = false) -> void:
	position = Vector2(r.position)
	custom_minimum_size = Vector2(r.size)
	size = Vector2(r.size)
	var btn := _next_button()
	if btn == null:
		return
	var inset := Rect2i(Vector2i.ZERO, r.size) if button_only else BUTTON_INSET
	btn.position = Vector2(inset.position)
	btn.custom_minimum_size = Vector2(inset.size)
	btn.size = Vector2(inset.size)

# ── the line ──────────────────────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	var chips := _chips()
	if chips == null:
		return
	for c in chips.get_children():
		chips.remove_child(c)
		c.queue_free()
	var name_label := get_node_or_null("%Name") as Label
	if name_label != null:
		name_label.visible = not _queue.is_empty()
		if not _queue.is_empty():
			name_label.text = _who(_queue[0], name_label)
			name_label.add_theme_color_override("font_color", _colour_of(_queue[0]))
	# Three guests, then a "+N" chip: past that the line is a number, not something you read.
	var shown := mini(_queue.size(), Palette.QUEUE_SLOTS if _queue.size() <= Palette.QUEUE_SLOTS else Palette.QUEUE_SLOTS - 1)
	for i in shown:
		chips.add_child(_chip(_queue[i], i == 0))
	if _queue.size() > shown:
		chips.add_child(_overflow(_queue.size() - shown))

## Who is at the head of the line — their name, and their JOB when the plate is wide enough to hold
## both (docs/09 §5 step 1: the cheapest proof that the cast reads as eleven distinct people and not
## as eleven coloured silhouettes). The job comes from the persona card, so it is content, never a
## word this component invents. MEASURED, not guessed: the label is 132 px and `clip_text` would
## otherwise end "painting student" mid-word, which reads worse than the name on its own.
func _who(guest: Dictionary, label: Label) -> String:
	var who := String(guest.get("name", Strings.SOMEONE))
	var job := String(Content.character(String(guest.get("character_id", ""))).get("job", ""))
	if job == "":
		return who
	var both := Strings.queue_who(who, job)
	var font := label.get_theme_font("font")
	if font == null:
		return who
	var width := font.get_string_size(both, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x
	return both if width <= label.size.x else who

## One waiting guest: a dark plate with a bust silhouette in their speaker colour. The first in line
## keeps full opacity, an amber edge and an amber floor line; the rest step back.
func _chip(guest: Dictionary, first: bool) -> Control:
	var chip := Panel.new()
	chip.name = "Guest%d" % int(guest.get("customer_id", 0))
	chip.custom_minimum_size = Vector2(Palette.QUEUE_CHIP)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", Palette.box(Palette.INK_DEEP, Palette.AMBER if first else Palette.EDGE, 2, 0))
	var colour := _colour_of(guest)
	var w := Palette.QUEUE_CHIP.x
	# Head, collar, shoulders. A square over a single rectangle read as an abstract logo in the first
	# capture; one stepped row in between is all it takes for it to read as a person.
	_block(chip, Vector2(float((w - 10) / 2), 4.0), Vector2(10, 9), colour)          # the head
	_block(chip, Vector2(float((w - 16) / 2), 15.0), Vector2(16, 3), colour)         # the collar
	_block(chip, Vector2(float((w - 22) / 2), 18.0), Vector2(22, 14), colour)        # the shoulders
	if first:
		_block(chip, Vector2(3.0, float(Palette.QUEUE_CHIP.y - 4)), Vector2(22, 1), Palette.AMBER)
	else:
		chip.modulate.a = 0.72
	return chip

## "+7": the rest of the line, when it is longer than the strip.
func _overflow(count: int) -> Control:
	var chip := Panel.new()
	chip.name = "More"
	chip.custom_minimum_size = Vector2(Palette.QUEUE_CHIP)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", Palette.box(Palette.INK_DEEP, Palette.EDGE, 2, 0))
	chip.modulate.a = 0.72
	var l := Label.new()
	l.name = "Count"
	l.text = Strings.QUEUE_MORE % count
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", Palette.TEXT_DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chip.add_child(l)
	return chip

## A whole-pixel block of the silhouette. ColorRects, not a _draw(), so the chip is a real node tree
## the user can open in the editor — and the colour is always a Palette token (docs/04 rule 1).
func _block(parent: Control, at: Vector2, block_size: Vector2i, colour: Color) -> void:
	var r := ColorRect.new()
	r.color = colour
	r.position = Palette.snap(at)
	r.size = Vector2(block_size)
	r.custom_minimum_size = Vector2(block_size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)

## The colour the DialogueBox would print their name in. The nameless parade has no entry, so it gets
## the dim text colour instead of the default amber — otherwise every one-off looks like the highlight.
func _colour_of(guest: Variant) -> Color:
	var g: Dictionary = guest
	var character_id := String(g.get("character_id", ""))
	return Palette.speaker_colour(character_id) if character_id != "" else Palette.TEXT

# ── input ─────────────────────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		# Clicking the LINE while somebody is at the counter would talk to the person at the counter and
		# leave the line exactly where it was — the one thing the click cannot be allowed to mean. The
		# button is still there and still says what it does.
		if _at_counter and not _queue.is_empty():
			return
		_on_next()
		accept_event()

func _on_next() -> void:
	if _can_start:
		talk_next.emit()

func _chips() -> HBoxContainer:
	return get_node_or_null("%Chips") as HBoxContainer

func _next_button() -> PixelButton:
	return get_node_or_null("%NextGuest") as PixelButton
