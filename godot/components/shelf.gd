class_name Shelf
extends GridContainer
## The grid of ItemSlots, filled from `view.shelf` (registry order). The shelf owns no rules: it
## re-uses its slots, keeps them in the same cells between renders, and forwards the pick.

signal picked(sku_id: String)

const SLOT_SCENE := preload("res://components/ItemSlot.tscn")

var _slots: Dictionary = {}

func _ready() -> void:
	Palette.prepare()

## `items` is `view.shelf`. `counts` maps sku_id -> quantity already in the till.
func set_items(items: Array, counts: Dictionary = {}) -> void:
	var wanted := items.size()
	while get_child_count() < wanted:
		var slot: ItemSlot = SLOT_SCENE.instantiate()
		slot.picked.connect(_on_picked)
		add_child(slot)
	while get_child_count() > wanted:
		var extra := get_child(get_child_count() - 1)
		remove_child(extra)
		extra.queue_free()
	_slots.clear()
	for i in wanted:
		var slot := get_child(i) as ItemSlot
		if slot == null:
			continue
		var entry: Dictionary = items[i]
		slot.sku = entry
		slot.count = int(counts.get(entry.get("sku_id", ""), 0))
		_slots[String(entry.get("sku_id", ""))] = slot

func set_counts(counts: Dictionary) -> void:
	for sku_id in _slots:
		var slot: ItemSlot = _slots[sku_id]
		slot.count = int(counts.get(sku_id, 0))

func slot_for(sku_id: String) -> ItemSlot:
	return _slots.get(sku_id, null)

func _on_picked(sku_id: String) -> void:
	picked.emit(sku_id)
