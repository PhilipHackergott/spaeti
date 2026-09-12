class_name TallyRow
extends HBoxContainer
## One line of the nightly P&L: a label on the left, money on the right, counted up when the summary
## plays. `sign_hint` only colours and prefixes the number — the arithmetic is the engine's.

@export var row_label: String = "Revenue":
	set(v):
		row_label = v
		_refresh()

@export var value: float = 0.0:
	set(v):
		value = v
		_shown = v
		_refresh()

## "in" = money towards you (green), "out" = money away (red), "total" = the bottom line (amber, big).
@export_enum("in", "out", "total", "plain") var kind: String = "in":
	set(v):
		kind = v
		_refresh()

var _shown: float = 0.0

func _ready() -> void:
	Palette.prepare()
	_refresh()

## Count the number up from zero (staggered by the SummaryTally).
func play(delay: float = 0.0, duration: float = 0.45) -> void:
	if Palette.reduce_motion or not is_inside_tree():
		_shown = value
		_refresh()
		return
	_shown = 0.0
	_refresh()
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(_set_shown, 0.0, value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_shown(v: float) -> void:
	_shown = v
	_refresh()

func _refresh() -> void:
	var l := get_node_or_null("%Label") as Label
	if l == null:
		return
	l.text = row_label
	var v := get_node_or_null("%Value") as Label
	if v == null:
		return
	var prefix := ""
	var col := Palette.TEXT
	match kind:
		"in":
			prefix = "+"
			col = Palette.GOOD
		"out":
			prefix = "-"
			col = Palette.BAD
		"total":
			prefix = "+" if _shown >= 0.0 else "-"
			col = Palette.AMBER_SOFT if _shown >= 0.0 else Palette.BAD
		_:
			prefix = ""
			col = Palette.TEXT
	v.text = prefix + Palette.money(absf(_shown))
	v.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_color", Palette.TEXT if kind == "total" else Palette.TEXT_DIM)
	var size := Palette.FONT_LEAD if kind == "total" else Palette.FONT_BODY
	v.add_theme_font_size_override("font_size", size)
	l.add_theme_font_size_override("font_size", size)
