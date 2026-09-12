class_name DiceResult
extends Control
## The d20 pop beside the dialogue box (docs/06-dialogue-and-stats.md section 5): a code-drawn die
## with the raw roll in it, the sum spelled out, and the verdict in GOOD/BAD.
##
##     [14]  d20 14 + 2 = 16
##           vs 12 — success
##
## It renders `view.talk.last_check` = {stat, roll, mod, dc, success} — the arithmetic is the engine's
## (docs/06 section 2) and is only PRINTED here; a UI that re-added roll + mod could disagree with the
## reducer that already applied the outcome. The `Fx` layer plays the same moment as a burst from the
## `check` log event, so the pop is felt even if the reader is looking at the portrait.
##
## Colourblind-safe by construction: the sum, the DC and the word "success"/"failed" all say it.

## The last check rendered, so a per-frame re-render does not restart the pop.
var _current: Dictionary = {}

func _ready() -> void:
	Palette.prepare()
	position = Vector2(Palette.DICE_RECT.position)
	custom_minimum_size = Vector2(Palette.DICE_RECT.size)
	size = Vector2(Palette.DICE_RECT.size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := get_node_or_null("Plate") as PanelContainer
	if plate != null:
		plate.add_theme_stylebox_override("panel", Palette.box(Palette.INK_DEEP, Palette.ACCENT, 2, 3))
	var shape := get_node_or_null("%Shape") as Polygon2D
	if shape != null:
		shape.color = Palette.DICE_FILL
	var roll := get_node_or_null("%Roll") as Label
	if roll != null:
		roll.add_theme_color_override("font_color", Palette.DICE_NUMBER)
	visible = false

## `check` is `view.talk.last_check`. Empty hides the pop.
func show_check(check: Dictionary) -> void:
	if check.is_empty():
		_current = {}
		visible = false
		return
	var fresh := not _same(check)
	_current = check.duplicate(true)
	visible = true
	var roll := int(check.get("roll", 0))
	var mod := int(check.get("mod", 0))
	var dc := int(check.get("dc", 0))
	var success := bool(check.get("success", false))
	_set_label("%Roll", Strings.NUMBER % roll, Palette.DICE_NUMBER)
	_set_label("%Line", Strings.dice_line(roll, mod, roll + mod), Palette.TEXT)
	_set_label("%Verdict", Strings.dice_verdict(dc, success), Palette.GOOD if success else Palette.BAD)
	if fresh:
		pop()

## The emphasis: a 3-px stepped hop and a fade-in. Also what `Fx`'s `check` event triggers, so a roll
## announced by the log stream and a roll read out of the view are the same beat.
func pop() -> void:
	if not is_inside_tree() or Palette.reduce_motion:
		modulate.a = 1.0
		position = Vector2(Palette.DICE_RECT.position)
		return
	var home := Vector2(Palette.DICE_RECT.position)
	modulate.a = 0.0
	position = Palette.snap(home + Vector2(0, 3))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.16)
	tw.tween_method(_hop.bind(home), 3.0, 0.0, 0.22)

func _hop(offset: float, home: Vector2) -> void:
	position = Palette.snap(home + Vector2(0, roundf(offset)))

func _same(check: Dictionary) -> bool:
	if _current.is_empty():
		return false
	for key in ["stat", "roll", "mod", "dc", "success"]:
		if String(check.get(key, "")) != String(_current.get(key, "")):
			return false
	return true

func _set_label(unique: String, text_value: String, colour: Color) -> void:
	var l := get_node_or_null(unique) as Label
	if l == null:
		return
	l.text = text_value
	l.add_theme_color_override("font_color", colour)
