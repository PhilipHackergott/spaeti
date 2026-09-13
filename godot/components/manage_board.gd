class_name ManageBoard
extends VBoxContainer
## The hour before opening, as a component: one line per SKU (stock, wholesale cost, restock +/-,
## the shelf price against its fair band), the modules you could buy, and the button that opens the
## night. It emits engine actions; the screen dispatches them.

signal action(a: Dictionary)
signal open_night()

const STEP := Vector2(15, 15)
const PRICE_STEP := 0.10
## The FLOOR for a SKU row's cells, not the row's height: at Jersey@16 the label's line height wins
## and a row measures 18 px. Nothing snaps the scroll window to a multiple of that, and nothing
## should — `%Body` takes whatever the modal leaves (167 px) and the wheel scrolls in ~20-px notches,
## so a boundary row is sliced at almost any scroll offset whatever the window's height. The sliver
## IS the scroll affordance; one notch brings the row fully in (measured 2026-09-13). What the board
## does owe the player is a dead band above the foot, so a click that slips off a half-visible price
## stepper cannot land on "Open up" instead (`FootGap` in the .tscn).
const ROW_H := 15

## The stock each SKU had when tonight's manage hour opened. The "+N" on a row is the ENGINE's delta
## against it, never a count of clicks: a refused restock (broke) must print nothing, and the tally
## must reset with the day instead of following the player to night 5.
var _base_stock: Dictionary = {}
var _base_day: int = -1

## Is this hour's board actually actionable? Every board intent is MANAGE-only in the reducer
## (`set_price` / `restock` / `buy_upgrade` / `open_night` all hand the same state back outside phase
## "manage"), and `Rules.view` builds the `manage` block for every phase — so at the season's end the
## board drew 57 live controls over zero legal actions. A partial dict (a test, the mock) stays live.
var _live: bool = true
## Whether the corner currently opens on a Sonntag — the last value the read-model handed over. UI
## state only: the board flips it by emitting `set_sunday_open`, the reducer decides.
var _sunday_open: bool = false

func _ready() -> void:
	Palette.prepare()
	var rule := get_node_or_null("Rule") as ColorRect
	if rule != null:
		rule.color = Palette.RULE
	_text("%Section", Strings.MANAGE_SECTION)
	_text("%ModuleHead", Strings.MANAGE_MODULES)
	_text("%StandingHead", Strings.MANAGE_STANDING)
	var open := get_node_or_null("%OpenNight") as Button
	if open != null:
		open.text = Strings.OPEN_UP
		if not open.pressed.is_connected(_on_open):
			open.pressed.connect(_on_open)
	var sunday := get_node_or_null("%SundayToggle") as Button
	if sunday != null and not sunday.pressed.is_connected(_on_sunday):
		sunday.pressed.connect(_on_sunday)

func _text(unique: String, value: String) -> void:
	var l := get_node_or_null(unique) as Label
	if l != null:
		l.text = value

func render(v: Dictionary) -> void:
	var cash := get_node_or_null("%Cash") as Label
	if cash != null:
		cash.text = Strings.CASH % Palette.money(float(v.get("cash", 0.0)))
	_live = String(v.get("phase", "manage")) == "manage"
	var manage: Dictionary = v.get("manage", {})
	var options: Array = manage.get("restock_options", [])
	var day := int(v.get("day", 0))
	if day != _base_day:
		_base_day = day
		_base_stock = {}
		for e in options:
			_base_stock[String((e as Dictionary).get("sku_id", ""))] = int((e as Dictionary).get("stock", 0))
	_build_rows(options)
	_build_modules(manage.get("modules", []))
	_build_standing(manage.get("status", {}))
	var open := get_node_or_null("%OpenNight") as Button
	if open != null:
		open.disabled = not _live
	_render_sunday(bool(manage.get("open_sunday", false)))

func _build_rows(options: Array) -> void:
	var box := get_node_or_null("%Rows") as VBoxContainer
	if box == null:
		return
	var slot := _focus_slot(box)
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for entry in options:
		box.add_child(_row(entry))
	_restore_focus(box, slot)

## A press re-renders the board and the rebuild frees the very button that was pressed; the keyboard
## ring goes with it, and Godot only walks the ring FROM an owner — so after one Enter on a "+" no
## key brought the focus back at all (measured 2026-09-13). Remember which cell held it, put it back
## on the same one. (-1, -1) means "not ours": never steal the focus from somewhere else.
func _focus_slot(box: Container) -> Vector2i:
	if not is_inside_tree():
		return Vector2i(-1, -1)   # the tests render a DETACHED board: there is no viewport
	var f := get_viewport().gui_get_focus_owner()
	if f == null or f.get_parent() == null or f.get_parent().get_parent() != box:
		return Vector2i(-1, -1)
	return Vector2i(f.get_parent().get_index(), f.get_index())

func _restore_focus(box: Container, slot: Vector2i) -> void:
	if slot.x < 0 or slot.x >= box.get_child_count():
		return
	var row := box.get_child(slot.x)
	if slot.y < 0 or slot.y >= row.get_child_count():
		return
	var c := row.get_child(slot.y) as Control
	if c != null and c.focus_mode != Control.FOCUS_NONE and not (c is BaseButton and (c as BaseButton).disabled):
		c.grab_focus()
## The board's BODY (rows, modules, standing) is one ScrollContainer that takes whatever height the modal
## leaves; the foot with "Open up" sits outside it and is therefore always on screen (2026-09-13: with a
## fixed five-row window and the module list below it, the foot was off the bottom of the frame in the
## real game, and there was no way out of the Manage hour with a mouse).

func _row(entry: Dictionary) -> HBoxContainer:
	var sku_id := String(entry.get("sku_id", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# ROW_H is a floor (see above): the real row is 18 px and the window boundary may slice it.
	row.custom_minimum_size = Vector2(0, ROW_H)
	var name_label := _label(String(entry.get("name", "")), 78, Palette.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_label("x%d" % int(entry.get("stock", 0)), 22, Palette.TEXT_DIM))
	row.add_child(_label(Strings.WHOLESALE % Palette.money(float(entry.get("cost", 0.0))), 56, Palette.TEXT_DIM))
	# Only "+": a restock is a purchase the reducer has already made. There is no un-buy action in
	# docs/05 section 3, so a "-" here could only ever dispatch something illegal.
	var stock := int(entry.get("stock", 0))
	var qty := maxi(0, stock - int(_base_stock.get(sku_id, stock)))
	var qty_label := _label("+%d" % qty, 20, Palette.AMBER_SOFT if qty > 0 else Palette.TEXT_DIM)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(qty_label)
	var plus := _button("+", _on_restock.bind(sku_id, 1))
	# The engine's verdict (view.manage.restock_options[].affordable = Rules.can_restock) — a live "+"
	# the reducer refuses is a button that does nothing, and it used to print a receipt for it.
	plus.disabled = not _live or not bool(entry.get("affordable", true))
	row.add_child(plus)
	var price := float(entry.get("price", 0.0))
	var lo := float(entry.get("fair_lo", 0.0))
	var hi := float(entry.get("fair_hi", 0.0))
	# The band is the engine's verdict (view.manage.restock_options[].tier) — never re-derived here.
	var price_label := _label(Palette.money(price), 54, Palette.tier_colour(String(entry.get("tier", "fair"))))
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price_label)
	row.add_child(_button("-", _on_price.bind(sku_id, price, -PRICE_STEP)))
	row.add_child(_button("+", _on_price.bind(sku_id, price, PRICE_STEP)))
	row.add_child(_label("%s-%s" % [_short(lo), _short(hi)], 62, Palette.TEXT_DIM))
	return row

func _build_modules(modules: Array) -> void:
	var box := get_node_or_null("%Modules") as VBoxContainer
	if box == null:
		return
	var slot := _focus_slot(box)   # a "buy" press frees its own button in exactly the same way
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	# Two passes: this hour's decisions first, the season's roadmap under them. The body opens on the
	# rows you can act on, and the locked ones are what you scroll down to.
	for m in modules:
		if _actionable(m):
			box.add_child(_module_row(m))
	for m in modules:
		if not _actionable(m):
			box.add_child(_module_row(m))
	_restore_focus(box, slot)

## Owned or buyable now — the two states this hour can act on. Anything else is still gated by day /
## Kiez-Trust / a prerequisite and carries the engine's `reason`.
static func _actionable(m: Dictionary) -> bool:
	var owned := bool(m.get("owned", false))
	return owned or bool(m.get("available", not owned))

func _module_row(m: Dictionary) -> HBoxContainer:
	# The read-model's shape (docs/05 §5, Economy.module_options): {def, owned, available, affordable, reason}
	# — the module's own words live in `def` (id, name, cost, note). 2026-09-13: the board read flat
	# name/desc/cost keys and drew 27 blank rows at 0,00 € that pushed "Open up" off the modal; the
	# scripted playthrough never saw it because it presses the button by name.
	var def: Dictionary = m.get("def", m)
	var owned := bool(m.get("owned", false))
	var available := bool(m.get("available", not owned))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label(String(def.get("name", "")), 96, Palette.TEXT if (owned or available) else Palette.TEXT_DIM))
	if owned or available:
		# The description takes whatever the board has left over: the module strings are the engine's
		# and any fixed width clipped "...fewer warm-beer balks" mid-word.
		var desc := _label(String(def.get("note", def.get("desc", ""))), 180, Palette.TEXT_DIM)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
		if owned:
			row.add_child(_label(Strings.MANAGE_OWNED, 54, Palette.GOOD))
		else:
			var buy := _button(Palette.money(float(def.get("cost", 0.0))), _on_buy.bind(String(def.get("id", ""))))
			buy.custom_minimum_size = Vector2(58, ROW_H)
			buy.disabled = not _live or not bool(m.get("affordable", true))
			row.add_child(buy)
		return row
	# STILL LOCKED. `Economy.unlock_reason` already worked out WHY ("unlocks on day 3", "needs Bigger
	# fridge", "needs Kiez-Trust 60") and the board used to drop that string together with the whole
	# row: on day 1 the player saw 4 of 26 modules and the season's "the list grows" progression was
	# invisible as progression. The reason takes the note's place — until it unlocks it is the only
	# thing worth saying — and it is never clipped, so it keeps the note's 180-px floor off the row
	# (96 + 173 + 58 on a 400-px board would have put the reason past the right edge, and the body has
	# no horizontal scroll).
	var why := _label(String(m.get("reason", "")), 0, Palette.TEXT_DIM)
	why.clip_text = false
	why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(why)
	# The price where the buy button sits on an actionable row — a LABEL, not a disabled button: there
	# is nothing legal to press (`_buy_upgrade` refuses a locked id), and a dead control invites a click.
	var cost := _label(Palette.money(float(def.get("cost", 0.0))), 58, Palette.TEXT_DIM)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cost)
	return row

## The Sunday decision, in the pinned foot beside "Open up" (never in the scrolling body — that is
## the lesson the missing Open-up button taught). `legal_actions` offers `set_sunday_open` EVERY
## manage hour, so the plate is always there and the label carries the state: gating it on "tonight
## is Sonntag" would give the player one hour in seven to make a standing decision.
func _render_sunday(open_sunday: bool) -> void:
	_sunday_open = open_sunday
	var b := get_node_or_null("%SundayToggle") as Button
	if b == null:
		return
	b.text = Strings.SUNDAY_OPEN if open_sunday else Strings.SUNDAY_CLOSED
	b.add_theme_color_override("font_color", Palette.WARN if open_sunday else Palette.TEXT_DIM)
	b.disabled = not _live

func _on_sunday() -> void:
	action.emit({"type": "set_sunday_open", "open": not _sunday_open})

## What the corner has BECOME: the systems the modules switched on, and the conversation branches that
## left a mark (`Economy.corner_status`). Engine strings, printed — a choice the player made in a talk
## is otherwise written into `story.flags` and never read back anywhere they can see it.
func _build_standing(status: Dictionary) -> void:
	var box := get_node_or_null("%Standing") as VBoxContainer
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	var head := get_node_or_null("%StandingHead") as Label
	var lines: Array = []
	# What the Sunday gamble has cost so far. It only ever moves when `open_sunday` is on, so a corner
	# that keeps Ladenschluss never sees the line (Economy.corner_status).
	var heat := float(status.get("heat", 0.0))
	if heat > 0.0:
		lines.append(Strings.MANAGE_HEAT % int(heat))
	lines.append_array(status.get("systems", []))
	lines.append_array(status.get("flags", []))
	if head != null:
		head.visible = not lines.is_empty()   # an empty header over nothing is just noise
	box.visible = not lines.is_empty()
	for line in lines:
		var row := _label(String(line), 0, Palette.TEXT_DIM)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.clip_text = false
		box.add_child(row)

func _label(text: String, width: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, ROW_H)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.theme_type_variation = &"SmallLabel"
	l.add_theme_color_override("font_color", col)
	l.clip_text = true
	return l

func _button(text: String, cb: Callable) -> PixelButton:
	var b := PixelButton.new()
	b.text = text
	# StepButton is the pool's zero-padding stepper: without it a -/+ is 19 px tall and a SKU row
	# stops being a whole ROW_H (docs/04 Theme).
	b.theme_type_variation = &"StepButton"
	b.custom_minimum_size = STEP
	# `_live` is set at the top of `render`, before any row is built.
	b.disabled = not _live
	b.pressed.connect(cb)
	return b

## Only the intent: the row's "+N" is read back out of the next view, so the label can only ever
## report stock the reducer actually moved.
func _on_restock(sku_id: String, delta: int) -> void:
	if delta <= 0:
		return
	action.emit({"type": "restock", "sku": sku_id, "qty": delta})

func _on_price(sku_id: String, price: float, delta: float) -> void:
	action.emit({"type": "set_price", "sku": sku_id, "price": snappedf(maxf(0.0, price + delta), 0.01)})

func _on_buy(id: String) -> void:
	action.emit({"type": "buy_upgrade", "id": id})

func _on_open() -> void:
	open_night.emit()

func _short(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")
