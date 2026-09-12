class_name Till
extends PanelContainer
## The ring-up tray: what you have picked off the shelf, the running total, the Pfand you are taking
## back, and the three things you can do about it. It emits intents only — the scene decides which
## engine action they become (`serve_active` with `give` + `pfand_bottles`, or `skip_active`).

signal ring_up(lines: Array, pfand_bottles: int)
signal pfand_toggled(bottles: int)
signal waved_off()
signal line_removed(sku_id: String)

## [{sku_id, name, price, qty}] — UI selection, never game state.
var lines: Array = []
var pfand_bottles: int = 0

const MAX_ROWS := 3

func _ready() -> void:
	Palette.prepare()
	var ring := get_node_or_null("%RingUp") as Button
	if ring != null and not ring.pressed.is_connected(_on_ring):
		ring.pressed.connect(_on_ring)
	var pf := get_node_or_null("%PfandButton") as Button
	if pf != null and not pf.pressed.is_connected(_on_pfand):
		pf.pressed.connect(_on_pfand)
	var wave := get_node_or_null("%WaveOff") as Button
	if wave != null and not wave.pressed.is_connected(_on_wave):
		wave.pressed.connect(_on_wave)
	_refresh()

func set_lines(l: Array) -> void:
	lines = l.duplicate(true)
	_refresh()

func add_sku(entry: Dictionary) -> void:
	var id := String(entry.get("sku_id", ""))
	for line in lines:
		if String(line.get("sku_id", "")) == id:
			line["qty"] = int(line.get("qty", 1)) + 1
			_refresh()
			return
	lines.append({
		"sku_id": id,
		"name": String(entry.get("name", id)),
		"price": float(entry.get("price", 0.0)),
		"qty": 1,
	})
	_refresh()

func set_pfand(bottles: int) -> void:
	pfand_bottles = maxi(0, bottles)
	_refresh()

func clear() -> void:
	lines.clear()
	pfand_bottles = 0
	_refresh()

func counts() -> Dictionary:
	var out := {}
	for line in lines:
		out[String(line.get("sku_id", ""))] = int(line.get("qty", 1))
	return out

func total() -> float:
	var sum := 0.0
	for line in lines:
		sum += float(line.get("price", 0.0)) * float(int(line.get("qty", 1)))
	return sum

func give_list() -> Array:
	var out: Array = []
	for line in lines:
		for _i in int(line.get("qty", 1)):
			out.append(String(line.get("sku_id", "")))
	return out

func _on_ring() -> void:
	ring_up.emit(give_list(), pfand_bottles)

func _on_pfand() -> void:
	pfand_toggled.emit(pfand_bottles)

func _on_wave() -> void:
	waved_off.emit()

func _refresh() -> void:
	var rows := get_node_or_null("%Lines") as VBoxContainer
	if rows == null:
		return
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	if lines.is_empty() and pfand_bottles == 0:
		rows.add_child(_row("nothing picked yet", "", Palette.TEXT_DIM))
	else:
		var shown := mini(lines.size(), MAX_ROWS)
		for i in shown:
			var line: Dictionary = lines[i]
			var qty := int(line.get("qty", 1))
			var label := ("%dx %s" % [qty, String(line.get("name", ""))]) if qty > 1 else String(line.get("name", ""))
			rows.add_child(_row(label, Palette.money(float(line.get("price", 0.0)) * float(qty)), Palette.TEXT))
		if lines.size() > shown:
			rows.add_child(_row("+%d more" % (lines.size() - shown), "", Palette.TEXT_DIM))
		if pfand_bottles > 0:
			rows.add_child(_row("Pfand %d x 0,08" % pfand_bottles, "-" + Palette.money(pfand_bottles * 0.08), Palette.PFAND))
	var total_label := get_node_or_null("%Total") as Label
	if total_label != null:
		total_label.text = Palette.money(total() - pfand_bottles * 0.08)
	var ring := get_node_or_null("%RingUp") as Button
	if ring != null:
		ring.disabled = lines.is_empty() and pfand_bottles == 0

func _row(left: String, right: String, col: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := Label.new()
	a.text = left
	a.theme_type_variation = &"SmallLabel"
	a.add_theme_color_override("font_color", col)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.clip_text = true
	row.add_child(a)
	var b := Label.new()
	b.text = right
	b.theme_type_variation = &"SmallLabel"
	b.add_theme_color_override("font_color", col)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(b)
	return row
