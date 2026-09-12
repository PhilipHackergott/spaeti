class_name SummaryTally
extends VBoxContainer
## The nightly P&L, built from `view.summary` as a stack of TallyRows and played in order so the
## night reads as a story: what came in, what went out, what is left.

const ROW_SCENE := preload("res://components/TallyRow.tscn")

var _rows: Array[TallyRow] = []

func _ready() -> void:
	Palette.prepare()

## `s` is a NightSummary: {day, revenue, tips, cogs, bills_due, pfand_paid, profit, cash_after, sales, lost, kiez_delta}
func set_summary(s: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_rows.clear()
	if s.is_empty():
		return
	_add("Umsatz", float(s.get("revenue", 0.0)), "in")
	_add("Trinkgeld", float(s.get("tips", 0.0)), "in")
	_add("Einkauf", float(s.get("cogs", 0.0)), "out")
	_add("Miete + Strom", float(s.get("bills_due", 0.0)), "out")
	_add("Pfand ausgezahlt", float(s.get("pfand_paid", 0.0)), "out")
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Palette.EDGE
	add_child(rule)
	_add("Gewinn", float(s.get("profit", 0.0)), "total")

func play() -> void:
	for i in _rows.size():
		_rows[i].play(0.10 * float(i))

func _add(label: String, value: float, kind: String) -> void:
	var row: TallyRow = ROW_SCENE.instantiate()
	row.row_label = label
	row.value = value
	row.kind = kind
	add_child(row)
	_rows.append(row)
