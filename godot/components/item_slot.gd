class_name ItemSlot
extends PanelContainer
## One SKU on the shelf: icon, name, price (coloured by its price tier) and stock. Clicking or
## pressing it emits `picked` with the sku id — the ServePanel turns that into a till line, the
## scene turns the till into a `serve_active` action. The slot itself knows nothing about the rules.

signal picked(sku_id: String)

## One entry of `view.shelf` (docs/05 section 5): {sku_id, name, price, stock, icon, restricted, tier}.
@export var sku: Dictionary = {}:
	set(v):
		sku = v
		_refresh()

## How many of this SKU are already in the till (drawn as a corner badge).
@export var count: int = 0:
	set(v):
		count = maxi(0, v)
		_refresh()

func _ready() -> void:
	Palette.prepare()
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh()

func sku_id() -> String:
	return String(sku.get("sku_id", ""))

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_emit()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		_emit()
		accept_event()

func _emit() -> void:
	if sku_id() == "" or int(sku.get("stock", 0)) <= 0:
		return
	grab_focus()
	picked.emit(sku_id())

func _refresh() -> void:
	var icon := get_node_or_null("%Icon") as TextureRect
	if icon == null:
		return
	var stock := int(sku.get("stock", 0))
	icon.texture = Assets.texture(String(sku.get("icon", "")))
	icon.modulate = Color(1, 1, 1, 1) if stock > 0 else Color(1, 1, 1, 0.35)
	var name_label := get_node_or_null("%Name") as Label
	if name_label != null:
		name_label.text = String(sku.get("name", ""))
	var price := get_node_or_null("%Price") as Label
	if price != null:
		price.text = ("%.2f" % float(sku.get("price", 0.0))).replace(".", ",")
		price.add_theme_color_override("font_color", Palette.tier_colour(String(sku.get("tier", "fair"))))
	var stock_label := get_node_or_null("%Stock") as Label
	if stock_label != null:
		stock_label.text = "x%d" % stock
		stock_label.add_theme_color_override("font_color", Palette.TEXT_DIM if stock > 0 else Palette.BAD)
	var badge := get_node_or_null("%Badge") as Label
	if badge != null:
		badge.text = str(count) if count > 0 else ("18" if bool(sku.get("restricted", false)) else "")
		badge.visible = badge.text != ""
		badge.add_theme_color_override("font_color", Palette.AMBER_SOFT if count > 0 else Palette.BAD)
	theme_type_variation = &"SlotPanelPicked" if count > 0 else &"SlotPanel"
