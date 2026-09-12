class_name Meter
extends HBoxContainer
## Icon + label + segmented bar. Colourblind-safe by construction: the icon and the number carry the
## meaning, the segments carry the amount, the hue is decoration. Used by the HUD for Kiez-Trust and
## Profit, and by any panel that needs a 0..1 reading.

@export var icon_id: String = "ui/icon_trust":
	set(v):
		icon_id = v
		_refresh()

@export var label_text: String = "Kiez":
	set(v):
		label_text = v
		_refresh()

## 0..1. The bar lights `round(value * segments)` cells.
@export_range(0.0, 1.0, 0.01) var value: float = 0.6:
	set(v):
		value = clampf(v, 0.0, 1.0)
		_refresh()

@export var fill: Color = Color(0.357, 0.906, 1.0):
	set(v):
		fill = v
		_refresh()

@export var segments: int = 8:
	set(v):
		segments = maxi(1, v)
		_rebuild()

const SEG_SIZE := Vector2(4, 6)

func _ready() -> void:
	Palette.prepare()
	_rebuild()

func set_reading(v: float, text: String) -> void:
	label_text = text
	value = v

func _rebuild() -> void:
	var bar := get_node_or_null("%Bar") as HBoxContainer
	if bar == null:
		return
	while bar.get_child_count() > segments:
		var last := bar.get_child(bar.get_child_count() - 1)
		bar.remove_child(last)
		last.queue_free()
	while bar.get_child_count() < segments:
		var cell := ColorRect.new()
		cell.custom_minimum_size = SEG_SIZE
		cell.color = Palette.INK_DEEP
		bar.add_child(cell)
	_refresh()

func _refresh() -> void:
	var icon := get_node_or_null("%Icon") as TextureRect
	if icon == null:
		return
	icon.texture = Assets.texture(icon_id)
	var lab := get_node_or_null("%Label") as Label
	if lab != null:
		lab.text = label_text
	var bar := get_node_or_null("%Bar") as HBoxContainer
	if bar == null:
		return
	var lit := int(round(value * float(bar.get_child_count())))
	for i in bar.get_child_count():
		var cell := bar.get_child(i) as ColorRect
		if cell == null:
			continue
		# Empty cells keep a visible dark body so the bar reads as a scale, not as floating blocks.
		cell.color = fill if i < lit else Palette.INK_DEEP
