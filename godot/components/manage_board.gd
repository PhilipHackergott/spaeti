class_name ManageBoard
extends VBoxContainer
## The hour before opening, as a component: one line per SKU (stock, wholesale cost, restock +/-,
## the shelf price against its fair band), the modules you could buy, and the button that opens the
## night. It emits engine actions; the screen dispatches them.

signal action(a: Dictionary)
signal open_night()

const STEP := Vector2(15, 15)
const PRICE_STEP := 0.10
## The floor for a SKU row. The REAL height is whatever the theme's label and StepButton come out at,
## so it is measured from the first built row and the scroll window is sized to a whole multiple of
## that — the list can then never slice a row in half at its boundary (verify round 3 caught it doing
## exactly that, and a hand-tuned constant went stale again the moment the font changed).
const ROW_H := 15
const ROWS_VISIBLE := 5

## Restock quantities the player has clicked up this session (UI intent, echoed as `restock` actions).
var _pending: Dictionary = {}

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

func _text(unique: String, value: String) -> void:
	var l := get_node_or_null(unique) as Label
	if l != null:
		l.text = value

func render(v: Dictionary) -> void:
	var cash := get_node_or_null("%Cash") as Label
	if cash != null:
		cash.text = Strings.CASH % Palette.money(float(v.get("cash", 0.0)))
	var manage: Dictionary = v.get("manage", {})
	_build_rows(manage.get("restock_options", []))
	_build_modules(manage.get("modules", []))
	_build_standing(manage.get("status", {}))

func _build_rows(options: Array) -> void:
	var box := get_node_or_null("%Rows") as VBoxContainer
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for entry in options:
		box.add_child(_row(entry))
	_fit_scroll_to_whole_rows(box)

## Sizes the scroll window to ROWS_VISIBLE whole rows, measured off a real row rather than guessed.
func _fit_scroll_to_whole_rows(box: VBoxContainer) -> void:
	var scroll := get_node_or_null("Scroll") as ScrollContainer
	if scroll == null or box.get_child_count() == 0:
		return
	var first := box.get_child(0) as Control
	if first == null:
		return
	var h := maxi(ROW_H, int(ceilf(first.get_combined_minimum_size().y)))
	var sep := box.get_theme_constant("separation")
	scroll.custom_minimum_size = Vector2(0, h * ROWS_VISIBLE + sep * (ROWS_VISIBLE - 1))

func _row(entry: Dictionary) -> HBoxContainer:
	var sku_id := String(entry.get("sku_id", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Rows are a whole number of pixels tall so the scroll boundary never slices one in half.
	row.custom_minimum_size = Vector2(0, ROW_H)
	var name_label := _label(String(entry.get("name", "")), 78, Palette.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_label("x%d" % int(entry.get("stock", 0)), 22, Palette.TEXT_DIM))
	row.add_child(_label(Strings.WHOLESALE % Palette.money(float(entry.get("cost", 0.0))), 56, Palette.TEXT_DIM))
	# Only "+": a restock is a purchase the reducer has already made. There is no un-buy action in
	# docs/05 section 3, so a "-" here could only ever dispatch something illegal.
	var qty := int(_pending.get(sku_id, 0))
	var qty_label := _label("+%d" % qty, 20, Palette.AMBER_SOFT if qty > 0 else Palette.TEXT_DIM)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(qty_label)
	row.add_child(_button("+", _on_restock.bind(sku_id, 1)))
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
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for m in modules:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var owned := bool(m.get("owned", false))
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_label(String(m.get("name", "")), 96, Palette.TEXT_DIM if owned else Palette.TEXT))
		# The description takes whatever the board has left over: the module strings are the engine's
		# and any fixed width clipped "...fewer warm-beer balks" mid-word.
		var desc := _label(String(m.get("desc", "")), 180, Palette.TEXT_DIM)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc)
		if owned:
			row.add_child(_label(Strings.MANAGE_OWNED, 54, Palette.GOOD))
		else:
			var buy := _button(Palette.money(float(m.get("cost", 0.0))), _on_buy.bind(String(m.get("id", ""))))
			buy.custom_minimum_size = Vector2(58, ROW_H)
			row.add_child(buy)
		box.add_child(row)

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
	b.pressed.connect(cb)
	return b

## `_pending` counts what you have actually bought tonight — the label is a receipt, not an intent.
func _on_restock(sku_id: String, delta: int) -> void:
	if delta <= 0:
		return
	_pending[sku_id] = int(_pending.get(sku_id, 0)) + delta
	action.emit({"type": "restock", "sku": sku_id, "qty": delta})

func _on_price(sku_id: String, price: float, delta: float) -> void:
	action.emit({"type": "set_price", "sku": sku_id, "price": snappedf(maxf(0.0, price + delta), 0.01)})

func _on_buy(id: String) -> void:
	action.emit({"type": "buy_upgrade", "id": id})

func _on_open() -> void:
	open_night.emit()

func _short(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")
