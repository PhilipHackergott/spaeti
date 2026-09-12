class_name StatsStrip
extends Control
## The player's character sheet, compact (docs/06-dialogue-and-stats.md section 1): six stats with
## their value and their D&D 5e modifier, down the left edge of the register screen.
##
## It is a READING, not a control: nothing here can change a stat, and the modifier is the engine's
## (`view.player.mods`), never re-derived — a strip that computed its own floor((v-10)/2) would be a
## second source of truth the moment a module or a story beat starts granting bonuses.
##
## Default hidden, toggled with Tab (`Night` owns the key, this owns the panel), and always on in the
## `queue_waiting` capture so the sheet is visible in at least one reference shot.

## The six rows live in the .tscn (they are fixed, and the user wants to select them in the editor);
## this only fills them. Row node names are the stat ids capitalised — "str" -> "Str".
func _ready() -> void:
	Palette.prepare()
	position = Vector2(Palette.STATS_RECT.position)
	custom_minimum_size = Vector2(Palette.STATS_RECT.size)
	size = Vector2(Palette.STATS_RECT.size)
	# The HUD plate is half-transparent because it sits on the dark top band; this one sits over the
	# fridge and the shelf, where a 50%-alpha ground leaves 16-px text unreadable (first capture).
	var plate := get_node_or_null("Plate") as PanelContainer
	if plate != null:
		plate.add_theme_stylebox_override("panel", Palette.box(Palette.INK_DEEP, Palette.EDGE, 2, 3))
	# The names are the string table's, not the .tscn placeholders' (docs/04: one source for words).
	for stat_id in Strings.STAT_ORDER:
		var name_label := _cell(String(stat_id), "Name")
		if name_label != null:
			name_label.text = Strings.stat_name(String(stat_id))

## `player` is `view.player` = {stats:{id:int}, mods:{id:int}} (docs/06 section 4). An empty dictionary
## (an engine that has not shipped §1 yet) leaves the strip hidden rather than printing six zeroes.
func render(player: Dictionary) -> void:
	var stats: Dictionary = player.get("stats", {})
	var mods: Dictionary = player.get("mods", {})
	for stat_id in Strings.STAT_ORDER:
		var id := String(stat_id)
		var value_label := _cell(id, "Value")
		if value_label != null:
			value_label.text = Strings.NUMBER % int(stats.get(id, 0))
		var mod_label := _cell(id, "Mod")
		if mod_label != null:
			var mod := int(mods.get(id, 0))
			mod_label.text = Strings.MODIFIER % mod
			# Colour is the SECOND cue: the sign is already in the text, so a colourblind player
			# reads the same thing (docs/04: shape + label carry the meaning).
			mod_label.add_theme_color_override("font_color", Palette.GOOD if mod > 0 else (Palette.BAD if mod < 0 else Palette.TEXT_DIM))

## True when the strip has anything to show at all.
func has_stats(player: Dictionary) -> bool:
	return not (player.get("stats", {}) as Dictionary).is_empty()

func set_shown(on: bool) -> void:
	visible = on

func toggle() -> bool:
	visible = not visible
	return visible

func _cell(stat_id: String, cell: String) -> Label:
	var rows := get_node_or_null("%Rows") as Control
	if rows == null:
		return null
	return rows.get_node_or_null(stat_id.capitalize() + "/" + cell) as Label
