class_name ServePanel
extends PanelContainer
## Coffee Talk's brew panel, Berlin edition: it slides in over the right half of the screen, shows the
## whole shelf as ItemSlots and a Till underneath. Picking fills the till; "Ring up" turns the till
## into the engine action. The panel keeps only the selection — never game state.

signal serve(action: Dictionary)
signal waved_off()
signal closed()

const SHOWN_X := 236
const HIDDEN_X := 482
const SLIDE_MS := 220

var _shelf_items: Array = []
var _pfand_available: int = 0
var is_open: bool = false

func _ready() -> void:
	Palette.prepare()
	position = Vector2(HIDDEN_X, position.y)
	var shelf := get_node_or_null("%Shelf") as Shelf
	if shelf != null and not shelf.picked.is_connected(_on_picked):
		shelf.picked.connect(_on_picked)
	var t := till()
	if t != null:
		if not t.ring_up.is_connected(_on_ring):
			t.ring_up.connect(_on_ring)
		if not t.pfand_toggled.is_connected(_on_pfand):
			t.pfand_toggled.connect(_on_pfand)
		if not t.waved_off.is_connected(_on_wave):
			t.waved_off.connect(_on_wave)

## Fills the shelf from the read-model and names who is waiting.
func render(view: Dictionary) -> void:
	_shelf_items = view.get("shelf", [])
	_pfand_available = int(view.get("pfand_held", 0))
	var shelf := get_node_or_null("%Shelf") as Shelf
	var t := till()
	if shelf != null:
		shelf.set_items(_shelf_items, t.counts() if t != null else {})
	var want := get_node_or_null("%Want") as Label
	if want != null:
		var active: Dictionary = view.get("active", {})
		if active.is_empty():
			want.text = "no one waiting"
		else:
			var who := String(active.get("archetype", {}).get("name", "Kunde"))
			var w: Dictionary = active.get("want", {})
			want.text = "%s: %s" % [who, String(w.get("name", "?"))]

func open(instant: bool = false) -> void:
	is_open = true
	visible = true
	_slide(SHOWN_X, instant)

func close(instant: bool = false) -> void:
	is_open = false
	_slide(HIDDEN_X, instant)
	closed.emit()

func till() -> Till:
	return get_node_or_null("%Till") as Till

## Preset helper: put the given skus in the till (and this many empties in the Pfand tray).
func preload_picks(sku_ids: Array, pfand_bottles: int = 0) -> void:
	var t := till()
	if t == null:
		return
	t.clear()
	for id in sku_ids:
		for entry in _shelf_items:
			if String(entry.get("sku_id", "")) == String(id):
				t.add_sku(entry)
				break
	t.set_pfand(pfand_bottles)
	var shelf := get_node_or_null("%Shelf") as Shelf
	if shelf != null:
		shelf.set_counts(t.counts())

func _slide(to_x: int, instant: bool) -> void:
	if instant or Palette.reduce_motion or not is_inside_tree():
		position = Vector2(to_x, position.y)
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:x", float(to_x), SLIDE_MS / 1000.0)

func _on_picked(sku_id: String) -> void:
	var t := till()
	if t == null:
		return
	for entry in _shelf_items:
		if String(entry.get("sku_id", "")) == sku_id:
			t.add_sku(entry)
			break
	var shelf := get_node_or_null("%Shelf") as Shelf
	if shelf != null:
		shelf.set_counts(t.counts())

func _on_ring(give: Array, pfand_bottles: int) -> void:
	serve.emit({"type": "serve_active", "give": give, "pfand_bottles": pfand_bottles})

func _on_pfand(_bottles: int) -> void:
	var t := till()
	if t == null:
		return
	# One press takes the whole crate the customer put on the counter; a second press puts it back.
	t.set_pfand(0 if t.pfand_bottles > 0 else maxi(1, _pfand_available))

func _on_wave() -> void:
	waved_off.emit()
