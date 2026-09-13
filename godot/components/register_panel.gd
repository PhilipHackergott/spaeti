class_name RegisterPanel
extends Control
## The right column once a basket is on the counter (docs/08-register-and-tobacco.md section 1,
## section 4.1). It supersedes `Till` on the shipped Night screen: one row per rung line (mark, name,
## a `-` qty `+` stepper, a delete and the line total), the Pfand row, the subtotal and the TOTAL, and
## the three stacked verbs — Turn around, Ring up, Wave off — with Check ID beside the title.
##
## **It emits finished action dictionaries and nothing else.** A component may not invent a quantity
## that moves cash, so every stepper reports the number it WANTS and the reducer clamps it (docs/08
## section 3.2: `register_set_qty` is `1..9` and `<= stock`; `set_pfand` is clamped to `active.bottles`).
##
## `matches` and the correction banner are the REDUCER's opinion, read straight off `view.register` —
## a screen cannot decide a line is wrong, it can only print that the engine thinks so.
##
## It is also the Pfand crate's drop target: its hot zone is `Palette.PFAND_ROW_RECT`, not the whole
## panel, so dropping a crate on "Ring up" does nothing at all.
##
## **Every child is positioned by hand, and no row is a `Container`.** A Container lays its children
## out on a tree notification, so outside a tree every button inside one sits at (0,0) with no size —
## and the reachability test (docs/08 section 6) has to measure the REAL rects on a Night that never
## entered a tree. Manual rects are also what docs/01 asks for: whole pixels, authored once.

signal action(a: Dictionary)

## The row's steppers are `StepChip`s, not `Button`s: a themed Button in this project cannot be
## shorter than about 31 px (Jersey's 23-px line box plus the theme's own padding) and a register line
## is 18, so a Button silently grew the moment it entered a tree and swallowed the row under it.
const STEP_SCENE := preload("res://components/StepChip.tscn")

## `view.register` (docs/08 section 3.3). Display only; the panel never mutates it.
var register: Dictionary = {}
## How many empties the guest actually brought — `view.active.bottles`. The row may not stage more.
var pfand_available: int = 0
## Is `turn_around` on offer? Illegal mid-talk and mid-drag, so the scene is the one that knows.
var can_turn: bool = false
## Is there a guest at the counter at all? `ring_up` / `skip_active` are meaningless without one.
var can_serve: bool = false
## The signature of the lines currently drawn, so a per-frame render is not a per-frame rebuild — a
## rebuilt row loses the focus ring between two frames, and the keyboard path with it.
var _lines_sig: String = ""

## The line row, in base pixels across `Palette.REGISTER_LINES_RECT`'s 130: 8 mark, 46 name, three
## 12-px chips around a 10-px count, and 24 for the money (Jersey's digits are 4 px wide, so "18,80"
## fits in 20). Named so the arithmetic is checkable rather than eyeballed.
const MARK_X := 0
const MARK_PX := 8
const NAME_X := 9
const NAME_W := 46
const DOWN_X := 56
const STEP_W := 12
const QTY_X := 69
const QTY_W := 10
const UP_X := 80
const REMOVE_X := 93
const TOTAL_X := 106
const TOTAL_W := 24
## The Pfand row's own columns, across the same 130.
const PF_LABEL_W := 42
const PF_DOWN_X := 44
const PF_VALUE_X := 57
const PF_VALUE_W := 14
const PF_UP_X := 72
const PF_AMOUNT_X := 86
const PF_AMOUNT_W := 44

## Has `_boot` run? See `_boot`.
var _booted: bool = false

func _ready() -> void:
	_boot()

## docs/04 rule 2 (tree-optional): the work `_ready` does is done on FIRST USE instead of waiting for
## a tree that a capture, a test or a driver may never give this instance. Idempotent.
func _boot() -> void:
	if _booted:
		return
	_booted = true
	Palette.prepare()
	position = Vector2(Palette.REGISTER_RECT.position)
	custom_minimum_size = Vector2(Palette.REGISTER_RECT.size)
	size = Vector2(Palette.REGISTER_RECT.size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(Palette.DROP_TARGETS)
	var plate := get_node_or_null("%Plate") as PanelContainer
	if plate != null:
		plate.add_theme_stylebox_override("panel", Palette.box(Palette.INK_DEEP, Palette.EDGE, 3, 2))
		plate.size = Vector2(Palette.REGISTER_RECT.size)
	_place()
	_text("%Head", Strings.REGISTER)
	_text("%SubtotalLabel", Strings.SUBTOTAL)
	_text("%TotalLabel", Strings.TOTAL)
	_text("%PfandLabel", Strings.PFAND)
	_wire("%CheckId", Strings.CHECK_ID, _on_check_id)
	_wire("%TurnAround", Strings.TURN_AROUND, _on_turn)
	_wire("%RingUp", Strings.RING_UP, _on_ring)
	_wire("%WaveOff", Strings.WAVE_OFF, _on_wave)
	_wire_chip("%PfandDown", Strings.STEP_DOWN, _on_pfand.bind(-1))
	_wire_chip("%PfandUp", Strings.STEP_UP, _on_pfand.bind(1))
	render({})

## Every child sits on its authored Palette rect, converted into the panel's own space — so the whole
## column is one table of constants (docs/04 rule 1) and a screen never nudges a node by hand.
func _place() -> void:
	_at("%Head", Palette.REGISTER_HEAD_RECT)
	_at("%CheckId", Palette.CHECK_ID_RECT)
	_at("%Banner", Palette.REGISTER_BANNER_RECT)
	_at("%Lines", Palette.REGISTER_LINES_RECT)
	_at("%Empty", Rect2i(Palette.REGISTER_LINES_RECT.position,
		Vector2i(Palette.REGISTER_LINES_RECT.size.x, Palette.REGISTER_ROW_H)))
	_at("%SubtotalRow", Palette.REGISTER_SUBTOTAL_RECT)
	_at("%PfandRow", Palette.PFAND_ROW_RECT)
	_at("%TotalRow", Palette.REGISTER_TOTAL_RECT)
	_at("%TurnAround", Palette.TURN_AROUND_RECT)
	_at("%RingUp", Palette.RING_UP_RECT)
	_at("%WaveOff", Palette.WAVE_OFF_RECT)
	var w := Palette.REGISTER_SUBTOTAL_RECT.size.x
	var row_h := Palette.REGISTER_ROW_H
	_local("%SubtotalLabel", Rect2i(0, 0, 80, row_h))
	_local("%Subtotal", Rect2i(80, 0, w - 80, row_h))
	_local("%PfandLabel", Rect2i(0, 0, PF_LABEL_W, row_h))
	_local("%PfandDown", Rect2i(PF_DOWN_X, 0, STEP_W, Palette.PFAND_ROW_RECT.size.y))
	_local("%PfandValue", Rect2i(PF_VALUE_X, 0, PF_VALUE_W, row_h))
	_local("%PfandUp", Rect2i(PF_UP_X, 0, STEP_W, Palette.PFAND_ROW_RECT.size.y))
	_local("%PfandAmount", Rect2i(PF_AMOUNT_X, 0, PF_AMOUNT_W, row_h))
	_local("%TotalLabel", Rect2i(0, 0, 54, Palette.REGISTER_TOTAL_RECT.size.y))
	_local("%Total", Rect2i(54, 0, Palette.REGISTER_TOTAL_RECT.size.x - 54, Palette.REGISTER_TOTAL_RECT.size.y))

## A node on an absolute base-grid rect, in the panel's own space.
func _at(unique: String, r: Rect2i) -> void:
	var n := get_node_or_null(unique) as Control
	if n == null:
		return
	n.position = Vector2(r.position - Palette.REGISTER_RECT.position)
	n.size = Vector2(r.size)
	n.custom_minimum_size = Vector2(r.size)

## A node on a rect inside its own row.
func _local(unique: String, r: Rect2i) -> void:
	var n := get_node_or_null(unique) as Control
	if n == null:
		return
	n.position = Vector2(r.position)
	n.size = Vector2(r.size)
	n.custom_minimum_size = Vector2(r.size)

# -- rendering -----------------------------------------------------------------------------------

## `r` is `view.register`. An empty dictionary is the pre-basket state: the panel says so and offers
## nothing, rather than showing three live buttons over a counter with nobody at it.
func render(r: Dictionary) -> void:
	_boot()
	register = r
	var lines: Array = r.get("lines", [])
	_build_lines(lines)
	var empty := get_node_or_null("%Empty") as Label
	if empty != null:
		empty.text = Strings.REGISTER_EMPTY
		empty.visible = lines.is_empty()
	_money("%Subtotal", float(r.get("subtotal", 0.0)), Palette.TEXT)
	_money("%Total", float(r.get("total", 0.0)), Palette.AMBER_SOFT)
	_money("%PfandAmount", -float(r.get("pfand_line", 0.0)), Palette.PFAND)
	var bottles := int(r.get("pfand_bottles", 0))
	var pfand_value := get_node_or_null("%PfandValue") as Label
	if pfand_value != null:
		pfand_value.text = Strings.QTY % bottles
		pfand_value.add_theme_color_override("font_color", Palette.PFAND if bottles > 0 else Palette.TEXT_DIM)
	var down := get_node_or_null("%PfandDown") as StepChip
	if down != null:
		down.set_enabled(bottles > 0 and can_serve)
	var up := get_node_or_null("%PfandUp") as StepChip
	if up != null:
		up.set_enabled(bottles < pfand_available and can_serve)
	var banner := get_node_or_null("%Banner") as Label
	if banner != null:
		# The reducer wrote the sentence (docs/08 section 3.4), in character. The panel only frames it —
		# and when it rejected a ring-up without words, the table still has one.
		# The banner is the TELL, right above the lines it flagged; her actual words go in the
		# DialogueBox, where there are 264 px to say them in (docs/08 section 1). A 130-px column can
		# hold "Check that again." and nothing longer, and a truncated apology is worse than none.
		banner.text = Strings.CORRECTION
		banner.visible = String(r.get("correction", "")) != "" or int(r.get("corrections", 0)) > 0
		banner.add_theme_color_override("font_color", Palette.WARN)
	var check := get_node_or_null("%CheckId") as Button
	if check != null:
		var checked := bool(r.get("id_checked", false))
		check.text = Strings.ID_CHECKED if checked else Strings.CHECK_ID
		check.disabled = checked or not can_serve
	var ring := get_node_or_null("%RingUp") as Button
	if ring != null:
		ring.disabled = not can_serve or not bool(r.get("can_ring", false))
	var wave := get_node_or_null("%WaveOff") as Button
	if wave != null:
		wave.disabled = not can_serve
	var turn := get_node_or_null("%TurnAround") as Button
	if turn != null:
		turn.disabled = not can_turn

func set_pfand_available(n: int) -> void:
	pfand_available = maxi(0, n)

func set_can_turn(on: bool) -> void:
	can_turn = on

func set_can_serve(on: bool) -> void:
	can_serve = on

## One row per line. Rows are rebuilt rather than reused because the reducer re-keys them on every
## `register_remove` — an index is not an identity here — but ONLY when the lines actually changed.
func _build_lines(lines: Array) -> void:
	var host := get_node_or_null("%Lines") as Control
	if host == null:
		return
	var sig := JSON.stringify(lines) + str(can_serve)
	if sig == _lines_sig and host.get_child_count() == lines.size():
		return
	_lines_sig = sig
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
	for i in lines.size():
		host.add_child(_line_row(lines[i], i))

func _line_row(entry: Dictionary, index: int) -> Control:
	var row := Control.new()
	row.name = "Line%d" % index
	row.position = Vector2(0.0, float(index * Palette.REGISTER_ROW_H))
	row.size = Vector2(float(Palette.REGISTER_LINES_RECT.size.x), float(Palette.REGISTER_ROW_H))
	row.custom_minimum_size = row.size
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := BrandMark.new()
	mark.name = "Mark"
	mark.set_brand(entry, MARK_PX)
	mark.position = Vector2(float(MARK_X), float((Palette.REGISTER_ROW_H - MARK_PX) / 2))
	row.add_child(mark)
	var shown := String(entry.get("name", entry.get("sku_id", "")))
	if bool(entry.get("restricted", false)):
		# The age gate rides on the LINE, not on the person: this is the row Check ID is about.
		shown = Strings.RESTRICTED + " " + shown
	var name_label := _cell(shown, Rect2i(NAME_X, 0, NAME_W, Palette.REGISTER_ROW_H), HORIZONTAL_ALIGNMENT_LEFT)
	name_label.name = "Name"
	# The reducer's verdict, printed and never re-derived: a line that does not match what she asked
	# for is flagged BEFORE you press Ring up, which is what makes one free correction fair.
	name_label.add_theme_color_override("font_color",
		Palette.TEXT if bool(entry.get("matches", true)) else Palette.WARN)
	row.add_child(name_label)
	var qty := int(entry.get("qty", 1))
	row.add_child(_step("Down", Strings.STEP_DOWN, DOWN_X, _on_qty.bind(index, qty - 1), qty <= 1))
	var qty_label := _cell(Strings.NUMBER % qty, Rect2i(QTY_X, 0, QTY_W, Palette.REGISTER_ROW_H), HORIZONTAL_ALIGNMENT_CENTER)
	qty_label.name = "Qty"
	row.add_child(qty_label)
	row.add_child(_step("Up", Strings.STEP_UP, UP_X, _on_qty.bind(index, qty + 1), qty >= 9))
	row.add_child(_step("Remove", Strings.REMOVE, REMOVE_X, _on_remove.bind(index), false))
	var total := _cell(_plain_money(float(entry.get("line_total", 0.0))),
		Rect2i(TOTAL_X, 0, TOTAL_W, Palette.REGISTER_ROW_H), HORIZONTAL_ALIGNMENT_RIGHT)
	total.name = "Total"
	row.add_child(total)
	return row

func _cell(value: String, r: Rect2i, align: int) -> Label:
	var l := Label.new()
	l.theme_type_variation = &"SmallLabel"
	# clip_text FIRST, then the text, then the rect. A Label's minimum width is its text until it is
	# told to clip, and a Control never shrinks below a minimum it has already been given — so setting
	# the size before the clip leaves a 24-px money column 30 px wide, over the chip beside it.
	l.clip_text = true
	l.text = value
	l.position = Vector2(r.position)
	l.size = Vector2(r.size)
	l.custom_minimum_size = Vector2(r.size)
	l.horizontal_alignment = align
	# TOP, not CENTER: the font's line box is 23 px and a register row is 18, so centring would push
	# the glyphs down into the row underneath. Printed from the top they sit exactly on their row.
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _step(node_name: String, glyph: String, x: int, cb: Callable, off: bool) -> StepChip:
	var chip := STEP_SCENE.instantiate() as StepChip
	chip.name = node_name
	chip.set_chip(glyph, Rect2i(x, 0, STEP_W, Palette.REGISTER_ROW_H), not off and can_serve)
	chip.pressed.connect(cb)
	return chip

## A `StepChip` authored in the .tscn, given its glyph and its handler.
func _wire_chip(unique: String, glyph: String, cb: Callable) -> void:
	var chip := get_node_or_null(unique) as StepChip
	if chip == null:
		return
	chip.set_chip(glyph, Rect2i(Vector2i(chip.position), Vector2i(chip.size)), true)
	if not chip.pressed.is_connected(cb):
		chip.pressed.connect(cb)

# -- what a control means ------------------------------------------------------------------------

## The control that OFFERS this action, or null. The reachability test asks this instead of looking
## for a node called "RingUp": today's soft-lock shipped because a driver pressed buttons by name.
func control_for(a: Dictionary) -> Control:
	match String(a.get("type", "")):
		"ring_up":
			return get_node_or_null("%RingUp") as Control
		"skip_active":
			return get_node_or_null("%WaveOff") as Control
		"turn_around":
			return get_node_or_null("%TurnAround") as Control if bool(a.get("on", true)) else null
		"check_id":
			return get_node_or_null("%CheckId") as Control
		"register_remove":
			return _row_control(int(a.get("line", -1)), "Remove")
		"register_set_qty":
			var line := int(a.get("line", -1))
			var want := int(a.get("qty", 0))
			var lines: Array = register.get("lines", [])
			if line < 0 or line >= lines.size():
				return null
			var have := int((lines[line] as Dictionary).get("qty", 1))
			return _row_control(line, "Down" if want < have else "Up")
		"set_pfand":
			var bottles := int(a.get("bottles", 0))
			var up := bottles > int(register.get("pfand_bottles", 0))
			return get_node_or_null("%PfandUp" if up else "%PfandDown") as Control
	return null

func _row_control(index: int, which: String) -> Control:
	var host := get_node_or_null("%Lines") as Control
	if host == null or index < 0 or index >= host.get_child_count():
		return null
	var row := host.get_child(index) as Control
	return row.get_node_or_null(which) as Control if row != null else null

## Which line the focus ring is standing on, or -1. The keyboard's Delete / `-` / `+` act on THIS,
## so a key can never quietly edit a line the player is not looking at.
func focused_line() -> int:
	if not is_inside_tree():
		return -1
	var focused := get_viewport().gui_get_focus_owner()
	var host := get_node_or_null("%Lines") as Control
	if focused == null or host == null:
		return -1
	var n: Node = focused
	while n != null and n.get_parent() != host:
		n = n.get_parent()
	return host.get_children().find(n) if n != null else -1

# -- the Pfand crate's drop target ---------------------------------------------------------------

## The ROW, not the panel: a crate dropped on "Ring up" is a miss, and it should feel like one.
func hot_zone() -> Rect2:
	_boot()
	var row := get_node_or_null("%PfandRow") as Control
	return row.get_global_rect().grow(2.0) if row != null else Rect2()

func accepts(payload: Dictionary) -> bool:
	return String(payload.get("kind", "")) == "crate"

func take(payload: Dictionary) -> void:
	if not accepts(payload):
		return
	action.emit({"type": "set_pfand", "bottles": int(payload.get("count", 0))})

# -- intents -------------------------------------------------------------------------------------

func _on_ring() -> void:
	action.emit({"type": "ring_up"})

func _on_wave() -> void:
	action.emit({"type": "skip_active"})

func _on_turn() -> void:
	action.emit({"type": "turn_around", "on": true})

func _on_check_id() -> void:
	action.emit({"type": "check_id"})

func _on_qty(index: int, qty: int) -> void:
	action.emit({"type": "register_set_qty", "line": index, "qty": qty})

func _on_remove(index: int) -> void:
	action.emit({"type": "register_remove", "line": index})

func _on_pfand(delta: int) -> void:
	var want := clampi(int(register.get("pfand_bottles", 0)) + delta, 0, pfand_available)
	action.emit({"type": "set_pfand", "bottles": want})

# -- small helpers -------------------------------------------------------------------------------

func _text(unique: String, value: String) -> void:
	var l := get_node_or_null(unique) as Label
	if l != null:
		l.text = value

func _money(unique: String, value: float, col: Color) -> void:
	var l := get_node_or_null(unique) as Label
	if l == null:
		return
	l.text = Palette.money(value)
	l.add_theme_color_override("font_color", col)

## A line total is already inside a money column, so it drops the euro sign the way a receipt does —
## at 130 px the symbol costs a character of the product name (docs/08 section 1's own mock-up).
func _plain_money(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")

func _wire(unique: String, label: String, cb: Callable) -> void:
	var b := get_node_or_null(unique) as Button
	if b == null:
		return
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	if not b.pressed.is_connected(cb):
		b.pressed.connect(cb)
