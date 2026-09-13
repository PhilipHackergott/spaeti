class_name WantBubble
extends Control
## The little speech bubble beside the customer: what they are asking for, as an icon + name + price.
## It is the only place the player needs to look to know what to grab, so it is never covered by the
## serve panel (the scene moves it left when the panel slides in).

@export var line: String = "":
	set(v):
		line = v
		_refresh()

## The guest is a minor asking for a restricted SKU. Nothing else on the frame says so — the "18"
## badge lives on the shelf's ItemSlots, and a player who cannot see who they are selling to cannot
## make the Integrity decision the counter puts in front of them.
@export var age_flag: bool = false:
	set(v):
		age_flag = v
		_refresh()

var _want: Dictionary = {}

func _ready() -> void:
	Palette.prepare()
	var tail := get_node_or_null("%Tail") as Polygon2D
	if tail != null:
		tail.color = Palette.INK_DEEP   # the same ink as the dialogue panel (one UI language, not a wooden bubble)
	_refresh()

## `want` is `view.active.want`: {sku_id, name, price, stock, icon}.
func set_want(want: Dictionary, said: String = "") -> void:
	_want = want
	if said != "":
		line = said
	visible = not want.is_empty()
	_refresh()

func _refresh() -> void:
	var icon := get_node_or_null("%Icon") as TextureRect
	if icon == null:
		return
	icon.texture = Assets.texture(String(_want.get("icon", "")))
	var name_label := get_node_or_null("%Name") as Label
	if name_label != null:
		name_label.text = String(_want.get("name", ""))
	var price := get_node_or_null("%Price") as Label
	if price != null:
		price.text = Palette.money(float(_want.get("price", 0.0)))
		price.add_theme_color_override("font_color", Palette.TEXT)   # the price is the answer, not a caption
	var said := get_node_or_null("%Line") as Label
	if said != null:
		said.text = line
		said.visible = line != ""
	var age := get_node_or_null("%Age") as Label
	if age != null:
		age.text = Strings.RESTRICTED          # the same age gate the shelf stamps on the SKU
		age.add_theme_color_override("font_color", Palette.BAD)
		age.visible = age_flag
