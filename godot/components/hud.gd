class_name Hud
extends Control
## The corner cluster: clock / cash / Pfand top-left, Kiez-Trust and Profit meters top-right. Small,
## tucked into the corners, never over the customer's face (art-direction.md section 1).

func _ready() -> void:
	Palette.prepare()
	# The three corner icons are fixed, so they are wired once here rather than exported.
	_set_icon("LeftPlate/TopLeft/Stats/ClockBox/Icon", "ui/icon_clock")
	_set_icon("LeftPlate/TopLeft/Stats/CashBox/Icon", "ui/icon_cash")
	_set_icon("LeftPlate/TopLeft/Stats/PfandBox/Icon", "ui/icon_pfand")

func _set_icon(path: String, id: String) -> void:
	var t := get_node_or_null(path) as TextureRect
	if t != null:
		t.texture = Assets.texture(id)

## Renders straight from the read-model (docs/05 section 5).
func render(view: Dictionary) -> void:
	_set_label("%Clock", String(view.get("time_label", "--:--")))
	_set_label("%Cash", Palette.money(float(view.get("cash", 0.0))))
	_set_label("%Pfand", "%d" % int(view.get("pfand_held", 0)))
	_set_label("%Day", "Tag %d · %s" % [int(view.get("day", 1)), String(view.get("weekday_name", ""))])
	var queue := int(view.get("queue_len", 0))
	var q := get_node_or_null("%Queue") as Label
	if q != null:
		q.text = "%d wartend" % queue
		q.visible = queue > 0
	var rep: Dictionary = view.get("reputation", {})
	var hud: Dictionary = view.get("hud", {})
	var trust := get_node_or_null("%Trust") as Meter
	if trust != null:
		trust.fill = Palette.TRUST
		trust.icon_id = "ui/icon_trust"
		trust.set_reading(float(rep.get("kiez", 0.0)) / 100.0, String(hud.get("kiez_label", "Kiez")))
	var profit := get_node_or_null("%Profit") as Meter
	if profit != null:
		profit.fill = Palette.PROFIT
		profit.icon_id = "ui/icon_profit"
		profit.set_reading(float(rep.get("profit", 0.0)) / 100.0, String(hud.get("profit_label", "Profit")))

## While the serve panel owns the right half, the meters step aside instead of being covered.
func set_compact(on: bool) -> void:
	var plate := get_node_or_null("RightPlate") as Control
	if plate != null:
		plate.visible = not on

func _set_label(unique: String, text: String) -> void:
	var l := get_node_or_null(unique) as Label
	if l != null:
		l.text = text
