class_name ManageBoard
extends VBoxContainer
## The hour before opening, as a component: one line per SKU (stock, wholesale cost, restock +/-,
## the shelf price against its fair band), the modules you could buy, and the button that opens the
## night. It emits engine actions; the screen dispatches them.

signal action(a: Dictionary)
signal open_night()

const STEP := Vector2(15, 13)
const PRICE_STEP := 0.10
## One SKU row's height; the scroll window is a whole multiple of it (see ManageBoard.tscn).
const ROW_H := 13

## Restock quantities the player has clicked up this session (UI intent, echoed as `restock` actions).
var _pending: Dictionary = {}

func _ready() -> void:
	Palette.prepare()
	var rule := get_node_or_null("Rule") as ColorRect
	if rule != null:
		rule.color = Palette.RULE
	_text("%Section", Strings.MANAGE_SECTION)
	_text("%ModuleHead", Strings.MANAGE_MODULES)
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

func _build_rows(options: Array) -> void:
	var box := get_node_or_null("%Rows") as VBoxContainer
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for entry in options:
		box.add_child(_row(entry))

func _row(entry: Dictionary) -> HBoxContainer:
	var sku_id := String(entry.get("sku_id", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	# Rows are a whole number of pixels tall so the scroll boundary never slices one in half.
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.add_child(_label(String(entry.get("name", "")), 62, Palette.TEXT))
	row.add_child(_label("x%d" % int(entry.get("stock", 0)), 22, Palette.TEXT_DIM))
	row.add_child(_label(Strings.WHOLESALE % Palette.money(float(entry.get("cost", 0.0))), 58, Palette.TEXT_DIM))
	# Only "+": a restock is a purchase the reducer has already made. There is no un-buy action in
	# docs/05 section 3, so a "-" here could only ever dispatch something illegal.
	var qty := int(_pending.get(sku_id, 0))
	var qty_label := _label("+%d" % qty, 22, Palette.AMBER_SOFT if qty > 0 else Palette.TEXT_DIM)
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
	row.add_child(_label("%s-%s" % [_short(lo), _short(hi)], 70, Palette.TEXT_DIM))
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
		row.add_child(_label(String(m.get("name", "")), 94, Palette.TEXT_DIM if owned else Palette.TEXT))
		row.add_child(_label(String(m.get("desc", "")), 196, Palette.TEXT_DIM))
		if owned:
			row.add_child(_label(Strings.MANAGE_OWNED, 54, Palette.GOOD))
		else:
			var buy := _button(Palette.money(float(m.get("cost", 0.0))), _on_buy.bind(String(m.get("id", ""))))
			buy.custom_minimum_size = Vector2(54, 13)
			row.add_child(buy)
		box.add_child(row)

func _label(text: String, width: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.theme_type_variation = &"SmallLabel"
	l.add_theme_color_override("font_color", col)
	l.clip_text = true
	return l

func _button(text: String, cb: Callable) -> PixelButton:
	var b := PixelButton.new()
	b.text = text
	b.theme_type_variation = &"ChoiceButton"
	b.add_theme_font_size_override("font_size", Palette.FONT_SMALL)
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
