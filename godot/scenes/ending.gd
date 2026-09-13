extends Screen
## The season's end — the one screen phase "end" had none of. `Rules.view` has been composing
## `ending` (Finale.resolve_finale) since the engine landed and nothing rendered it: a finished or
## bankrupt season dropped the player onto a Manage board where every action is refused, and the
## authored finale was unreachable content (2026-09-13).
##
## `legal_actions` is empty at "end" — there is no action left to take — so the ONE control here is a
## screen change, and it is pinned in the foot OUTSIDE the scrolling body: however long the epilogue
## tapestry grows, it can never push the way out off the card (the Open-up lesson).

func _ready() -> void:
	super._ready()
	# The veil and the two hairlines are Palette tokens, never colours in the .tscn (docs/04 rule 1).
	_paint("Dim", Palette.DIM)
	_paint("Card/Box/Rule", Palette.RULE)
	_paint("Card/Box/Rule2", Palette.RULE)
	var kicker := get_node_or_null("%Kicker") as Label
	if kicker != null:
		kicker.text = Strings.ENDING_TITLE
	var back := get_node_or_null("%BackToTitle") as Button
	if back != null:
		back.text = Strings.BACK_TO_TITLE
		if not back.pressed.is_connected(_on_back):
			back.pressed.connect(_on_back)
		# The keyboard needs an anchor: Godot only walks the focus ring FROM an owner, and with none
		# a finished season is mouse-only.
		if is_inside_tree() and get_viewport().gui_get_focus_owner() == null:
			back.grab_focus()

func render(v: Dictionary) -> void:
	if v.is_empty():
		return
	var layers := get_node_or_null("%SceneLayers") as SceneLayers
	if layers != null:
		layers.set_time(1.0)
	# The engine's own words (Finale.ENDING_TEXT), read with the keys the read-model actually hands
	# over — reading keys that were never there is exactly what broke the Manage board.
	var ending: Dictionary = v.get("ending", {})
	var title := get_node_or_null("%Title") as Label
	if title != null:
		title.text = String(ending.get("title", ""))
	var line := get_node_or_null("%Line") as Label
	if line != null:
		line.text = String(ending.get("line", ""))
	_build_epilogues(ending.get("epilogues", []))

## One row per met-and-resolved character (narrative-design §6b). Cleared first: `render` runs on
## every `changed`, and an appended tapestry would grow without end.
func _build_epilogues(epilogues: Array) -> void:
	var box := get_node_or_null("%Epilogues") as VBoxContainer
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	for entry in epilogues:
		var e: Dictionary = entry
		box.add_child(_epilogue_row(String(e.get("character", "")), String(e.get("line", ""))))

func _epilogue_row(character_id: String, text: String) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var who := Label.new()
	who.theme_type_variation = &"SmallLabel"
	# The cast registry's name, in the speaker's own colour — a read of content, never a rule
	# (the same read `night.gd::_speaker_name` makes).
	var c := Content.character(character_id)
	who.text = String(c.get("name", character_id))
	who.add_theme_color_override("font_color", Palette.speaker_colour(character_id))
	row.add_child(who)
	var body := Label.new()
	body.theme_type_variation = &"SmallLabel"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = text
	body.add_theme_color_override("font_color", Palette.TEXT_DIM)
	row.add_child(body)
	return row

func _on_back() -> void:
	# No action to dispatch: "end" is terminal in the reducer, so the way on is a screen, not an intent.
	request_screen.emit("title")

func _paint(path: String, col: Color) -> void:
	var r := get_node_or_null(path) as ColorRect
	if r != null:
		r.color = col
