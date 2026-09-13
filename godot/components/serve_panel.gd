class_name ServePanel
extends PanelContainer
## Coffee Talk's brew panel, Berlin edition: it slides in over the right half of the screen, shows the
## whole shelf as ItemSlots and a Till underneath. Picking fills the till; "Ring up" turns the till
## into the engine action. The panel keeps only the selection — never game state.

signal serve(action: Dictionary)
signal waved_off()
signal closed()

const SHOWN_X := 228
const HIDDEN_X := 482
const SLIDE_MS := 220

var _shelf_items: Array = []
var _pfand_available: int = 0
var is_open: bool = false
## The order the shelf was last scrolled to, "<customer id>:<sku>". The reveal fires ONCE per order:
## the night ticks ~60x/s and every tick re-renders (Session.changed -> Screen.refresh), so revealing
## on every render pinned the scroll to the want's page — nothing further than one window away was
## pickable (measured: one render snapped scroll_vertical 180 -> 0).
var _revealed_for: String = ""

func _ready() -> void:
	Palette.prepare()
	var divider := get_node_or_null("Box/Divider") as ColorRect
	if divider != null:
		divider.color = Palette.RULE
	var head := get_node_or_null("Box/Head/Title") as Label
	if head != null:
		head.text = Strings.SERVE_PANEL
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
	# What the person at the counter brought in — NOT `view.pfand_held`, which is the shop's own crate.
	# Paying out against the crate let one press double it on every serve (docs/05 §5).
	_pfand_available = int((view.get("active", {}) as Dictionary).get("bottles", 0))
	var shelf := get_node_or_null("%Shelf") as Shelf
	var t := till()
	if t != null:
		# The view always carries the rate (docs/05 §5); 0 would be a bug worth seeing, not a silent
		# fallback into the engine's constant from a component.
		t.set_pfand_rate(float(view.get("pfand_rate", 0.0)))
		t.set_pfand_available(_pfand_available)
	if shelf != null:
		shelf.set_items(_shelf_items, t.counts() if t != null else {})
		# The shelf is taller than its window (17 SKUs, 23 once the modules land), so the thing they
		# actually asked for is scrolled into view instead of being hidden three rows down — ONCE per
		# order. After that the scroll belongs to the player: upselling a beer onto a Mate order, or
		# substituting when the want is out of stock, means reaching rows the want's page does not hold.
		var a: Dictionary = view.get("active", {})
		var want_sku := String((a.get("want", {}) as Dictionary).get("sku_id", ""))
		var order := "%d:%s" % [int((a.get("customer", {}) as Dictionary).get("id", -1)), want_sku]
		if order != _revealed_for:
			_revealed_for = order
			_reveal(want_sku)   # "" is a no-op, so an empty counter just re-arms the next arrival
	var want := get_node_or_null("%Want") as Label
	if want != null:
		var active: Dictionary = view.get("active", {})
		if active.is_empty():
			want.text = Strings.NOBODY_WAITING
		else:
			var who := String(active.get("archetype", {}).get("name", Strings.SOMEONE))
			var w: Dictionary = active.get("want", {})
			want.text = Strings.WANT_LINE % [who, String(w.get("name", ""))]

## Scrolls the shelf so `sku_id`'s slot is inside the window. Safe outside the tree and for "".
func _reveal(sku_id: String) -> void:
	if sku_id == "":
		return
	var scroll := get_node_or_null("%ShelfScroll") as ScrollContainer
	var shelf := get_node_or_null("%Shelf") as Shelf
	if scroll == null or shelf == null:
		return
	var slot := shelf.slot_for(sku_id)
	if slot != null:
		scroll.ensure_control_visible(slot)

func open(instant: bool = false) -> void:
	is_open = true
	visible = true
	_revealed_for = ""   # re-opening re-centres on the want; the next render does the scrolling
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
	# A staged tray has to be a legal one: the guest brought at least what the capture puts in it.
	t.set_pfand_available(maxi(pfand_bottles, _pfand_available))
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
	# One press takes every empty THIS guest put on the counter; a second press puts them back. No
	# `maxi(1, …)`: with nothing on the counter there is nothing to take, and the button says so.
	t.set_pfand(0 if t.pfand_bottles > 0 else _pfand_available)

func _on_wave() -> void:
	waved_off.emit()
