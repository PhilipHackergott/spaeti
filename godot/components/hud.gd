class_name Hud
extends Control
## The corner cluster — ONE compact line per corner (the orchestrator's review: the old two-line
## plate ran into the SPÄTI neon at y 21-37 and printed at 12 px).
##   top-left  : [clock] 22:40  [cash] 84,50 €  [Pfand] 12   Night 3 · 2 waiting
##   top-right : [trust] 62 ▮▮▮▮▮▯▯▯   [profit] 48 ▮▮▮▮▯▯▯▯
## 16-px icon slots (the sizes `docs/asset-spec.json` gives `ui/icon_*`), text at Palette.FONT_TINY
## (16 base px, the one text size — 12 could not tell 2 from Z in a clock). Both plates sit in the
## top 18 px, so nothing crosses the neon.
## The meters print the number, not the engine's full label — the icon carries the identity and the
## bar the amount (colourblind-safe by construction); the engine's `hud.kiez_label` becomes the
## tooltip, so the read-model's own words are still what the HUD says.

func _ready() -> void:
	Palette.prepare()
	# The three corner icons are fixed, so they are wired once here rather than exported.
	_set_icon("%LeftPlate/Line/ClockBox/Icon", "ui/icon_clock")
	_set_icon("%LeftPlate/Line/CashBox/Icon", "ui/icon_cash")
	_set_icon("%LeftPlate/Line/PfandBox/Icon", "ui/icon_pfand")

func _set_icon(path: String, id: String) -> void:
	var t := get_node_or_null(path) as TextureRect
	if t != null:
		t.texture = Assets.texture(id)

## Renders straight from the read-model (docs/05 §5).
func render(view: Dictionary) -> void:
	_set_label("%Clock", String(view.get("time_label", "--:--")))
	_set_label("%Cash", Palette.money(float(view.get("cash", 0.0))))
	_set_label("%Pfand", "%d" % int(view.get("pfand_held", 0)))
	_set_label("%Meta", Strings.hud_line(int(view.get("day", 1)), int(view.get("queue_len", 0))))
	var rep: Dictionary = view.get("reputation", {})
	var hud: Dictionary = view.get("hud", {})
	_meter("%Trust", "ui/icon_trust", Palette.TRUST, float(rep.get("kiez", 0.0)), String(hud.get("kiez_label", "")))
	_meter("%Profit", "ui/icon_profit", Palette.PROFIT, float(rep.get("profit", 0.0)), String(hud.get("profit_label", "")))

## While the serve panel owns the right half, the meters step aside instead of being covered.
func set_compact(on: bool) -> void:
	var plate := get_node_or_null("%RightPlate") as Control
	if plate != null:
		plate.visible = not on

func _meter(unique: String, icon_id: String, fill: Color, value: float, label: String) -> void:
	var m := get_node_or_null(unique) as Meter
	if m == null:
		return
	m.fill = fill
	m.icon_id = icon_id
	m.tooltip_text = label
	m.set_reading(value / 100.0, "%d" % int(floorf(value + 0.5)))

func _set_label(unique: String, text: String) -> void:
	var l := get_node_or_null(unique) as Label
	if l != null:
		l.text = text
