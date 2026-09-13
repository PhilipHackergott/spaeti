extends "res://tests/TestCase.gd"
## Every component in the pool loads and instantiates, every screen renders every capture preset
## from docs/02-art-pipeline.md without touching the engine, and the mock read-model keeps the shape
## docs/05-engine-api.md section 5 promises. This is the test that stops a screenshot run from dying
## on a typo three minutes into a capture loop.

const COMPONENTS := [
	"res://components/PixelPanel.tscn",
	"res://components/PixelButton.tscn",
	"res://components/Meter.tscn",
	"res://components/ItemSlot.tscn",
	"res://components/Shelf.tscn",
	"res://components/Till.tscn",
	"res://components/ServePanel.tscn",
	"res://components/DialogueBox.tscn",
	"res://components/Portrait.tscn",
	"res://components/WantBubble.tscn",
	"res://components/SceneLayers.tscn",
	"res://components/Hud.tscn",
	"res://components/TallyRow.tscn",
	"res://components/SummaryTally.tscn",
	"res://components/ManageBoard.tscn",
	"res://components/Modal.tscn",
	"res://components/Transition.tscn",
	"res://components/Fx.tscn",
	"res://components/QueueStrip.tscn",
	"res://components/StatsStrip.tscn",
	"res://components/DiceResult.tscn",
]

const SCENE_PRESETS := {
	"res://scenes/Title.tscn": ["title"],
	"res://scenes/Night.tscn": ["empty_counter", "customer_at_counter", "dialogue_choice", "serving", "pfand", "late_night",
		"queue_waiting", "talk_lines", "talk_choice", "talk_result"],
	"res://scenes/Manage.tscn": ["manage"],
	"res://scenes/Summary.tscn": ["summary"],
	"res://scenes/Main.tscn": ["title", "customer_at_counter", "dialogue_choice", "serving", "pfand", "empty_counter", "late_night", "manage", "summary",
		"queue_waiting", "talk_lines", "talk_choice", "talk_result"],
}

## The keys `Rules.view(state)` must hand a scene (docs/05 section 5).
const VIEW_KEYS := [
	"phase", "day", "weekday_name", "clock_ms", "night_progress", "time_label", "cash", "pfand_held",
	"pfand_rate", "reputation", "hud", "active", "queue_len", "dialogue", "shelf", "summary", "manage", "ending",
	# docs/06-dialogue-and-stats.md section 4: the line, the conversation and the character sheet.
	"queue", "talk", "player",
]

func test_components_instantiate() -> void:
	for path in COMPONENTS:
		var packed := load(path) as PackedScene
		assert_true(packed != null, "load " + path)
		if packed == null:
			continue
		var inst := packed.instantiate()
		assert_true(inst != null, "instantiate " + path)
		_dispose(inst)

## COMPONENTS is written by hand, so a new widget in the pool used to go untested until someone
## remembered to add it. This is the reminder: the directory is the truth.
func test_the_pool_list_is_complete() -> void:
	var dir := DirAccess.open("res://components")
	assert_true(dir != null, "components/ is readable")
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		assert_true(COMPONENTS.has("res://components/" + file), "test_scenes.gd::COMPONENTS lists " + file)

func test_scenes_apply_every_capture_preset() -> void:
	for path in SCENE_PRESETS:
		var packed := load(path) as PackedScene
		assert_true(packed != null, "load " + path)
		if packed == null:
			continue
		for preset in SCENE_PRESETS[path]:
			var inst := packed.instantiate()
			assert_true(inst.has_method("apply_capture_preset"), path + " has apply_capture_preset")
			# Main is the shell (it owns which screen is on); only the screens themselves render a view.
			if path != "res://scenes/Main.tscn":
				assert_true(inst.has_method("render"), path + " has render")
			inst.call("apply_capture_preset", preset)
			_dispose(inst)

func test_every_documented_preset_has_a_screen() -> void:
	for preset in MockView.PRESETS:
		var found := false
		for path in SCENE_PRESETS:
			if path == "res://scenes/Main.tscn":
				continue
			if SCENE_PRESETS[path].has(preset):
				found = true
		assert_true(found, "preset rendered by a screen: " + str(preset))

func test_mock_view_matches_the_contract() -> void:
	for preset in MockView.PRESETS:
		var v: Dictionary = MockView.view(preset)
		for key in VIEW_KEYS:
			assert_true(v.has(key), "%s view has %s" % [preset, key])
		# The engine builds `queue_len` and `queue` off the same `s["queue"]` (rules.gd), so they can
		# never disagree — and a mock that prints "2 waiting" over a frame with nobody in the line
		# makes the capture a lie.
		assert_eq(int(v["queue_len"]), (v["queue"] as Array).size(), "%s queue_len agrees with the line" % preset)
		assert_true(v["shelf"] is Array, preset + " shelf is an array")
		assert_true(v["reputation"] is Dictionary, preset + " reputation is a dictionary")
		# JSON-safe: no nulls anywhere in the read-model.
		assert_false(JSON.stringify(v).contains("null"), preset + " has no null")
	var d: Dictionary = MockView.view("dialogue_choice")["dialogue"]
	assert_eq(d["choices"].size(), 2, "dialogue_choice offers two options")
	assert_true(MockView.view("customer_at_counter")["active"].has("want"), "a customer wants something")

func test_assets_fall_back_to_placeholders() -> void:
	for id in ["scene/backdrop", "scene/counter", "char/lena_neutral", "sku/beer", "ui/icon_clock"]:
		var tex := Assets.texture(id)
		assert_true(tex != null, "texture for " + id)
		if tex == null:
			continue
		if Assets.is_real(id):
			continue  # real art has landed; its size is the art lane's business
		var want: Vector2i = Assets.size_of(id)
		assert_eq(Vector2i(tex.get_size()), want, id + " keeps its base-pixel size")
	assert_true(Assets.portrait("char/nobody", "warm") != null, "unknown portrait still resolves")

## docs/05 §6: an expression we have neither art nor a spec entry for falls back to _neutral — and
## keeps the bust's real footprint. Before this was enforced the `serving` clubber ("warm") came back
## at Assets.FALLBACK_SIZE, a 32px blob floating over the set.
func test_portrait_falls_back_to_neutral_at_full_size() -> void:
	var neutral := Assets.texture("char/oneoff_clubber_neutral")
	var warm := Assets.portrait("char/oneoff_clubber", "warm")
	assert_true(warm != null and neutral != null, "both portraits resolve")
	if warm == null or neutral == null:
		return
	assert_eq(Vector2i(warm.get_size()), Vector2i(neutral.get_size()), "a missing expression keeps the bust size")
	# Only a PLACEHOLDER owes the spec its exact footprint; once the art lane ships the real bust its
	# own size is the truth (docs/04 rule 3), so the spec comparison is placeholder-only.
	if not Assets.is_real("char/oneoff_clubber_neutral"):
		assert_eq(Vector2i(warm.get_size()), Assets.size_of("char/oneoff_clubber_neutral"), "and that is the spec size")

## Assets.SIZES is a hand-written mirror of docs/asset-spec.json. This is what keeps it honest: a
## drifted entry renders a placeholder at the wrong footprint and the composition moves when art lands.
func test_asset_sizes_match_the_spec() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../docs/asset-spec.json").simplify_path()
	var f := FileAccess.open(path, FileAccess.READ)
	assert_true(f != null, "docs/asset-spec.json readable at " + path)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	assert_true(parsed is Dictionary and (parsed as Dictionary).has("assets"), "asset-spec.json parses")
	if not (parsed is Dictionary and (parsed as Dictionary).has("assets")):
		return
	var spec_ids := {}
	for entry in (parsed as Dictionary)["assets"]:
		var id := String(entry["id"])
		# `kind: "concept"` rows are reference paintings for the art loop (concept-art/generated/*),
		# not bitmaps a component ever asks `Assets` for — they carry no w/h and own no footprint.
		if String(entry.get("kind", "")) == "concept":
			continue
		spec_ids[id] = true
		assert_true(Assets.SIZES.has(id), "Assets.SIZES knows " + id)
		if Assets.SIZES.has(id):
			assert_eq(Assets.size_of(id), Vector2i(int(entry["w"]), int(entry["h"])), id + " size matches the spec")
	for id in Assets.SIZES:
		assert_true(spec_ids.has(id), "Assets.SIZES invents nothing: " + str(id))

## A mock that prints text the engine cannot produce makes every capture a lie. The values the
## screens print verbatim must be the engine's own (docs/05 §5).
func test_mock_view_speaks_the_engines_language() -> void:
	var s := SpatiState.new_game({})
	s["reputation"]["kiez"] = 62.0
	s["reputation"]["profit"] = 48.0
	var engine_hud: Dictionary = Rules.view(s)["hud"]
	var mock: Dictionary = MockView.view("customer_at_counter")
	assert_eq(String(mock["hud"]["kiez_label"]), String(engine_hud["kiez_label"]), "the Kiez label is the engine's")
	assert_eq(String(mock["hud"]["profit_label"]), String(engine_hud["profit_label"]), "the Profit label is the engine's")
	assert_true(Rules.WEEKDAY_NAMES.has(String(mock["weekday_name"])), "the weekday is one the engine names")
	assert_eq(String(mock["weekday_name"]), String(Rules.WEEKDAY_NAMES[(int(mock["day"]) - 1) % 7]), "day and weekday agree")
	assert_eq(float(mock["pfand_rate"]), Rules.PFAND_PER_BOTTLE, "the till quotes the deposit the reducer pays")
	assert_eq(float(Rules.view(s)["pfand_rate"]), Rules.PFAND_PER_BOTTLE, "and the engine hands it to the screens")
	# The Manage board colours from this tier; it may never re-derive the bands (docs/01, docs/05 section 5).
	for entry in mock["manage"]["restock_options"]:
		assert_true(entry.has("tier"), String(entry["sku_id"]) + " carries the engine's tier")
		assert_eq(String(entry["tier"]), Economy.price_tier(entry, float(entry["price"])), String(entry["sku_id"]) + " tier is Economy's verdict")
	for entry in Rules.view(s)["manage"]["restock_options"]:
		assert_eq(String(entry["tier"]), Economy.price_tier(Content.sku(String(entry["sku_id"])), float(entry["price"])), "the read-model tiers the real inventory")

## docs/04 rule 1: a screen may not write a colour — every token lives in components/theme.gd.
func test_scenes_write_no_colours() -> void:
	for path in SCENE_PRESETS:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_true(f != null, "readable " + path)
		if f == null:
			continue
		var text := f.get_as_text()
		f.close()
		assert_false(text.contains("Color("), path + " writes no raw colour (use Palette)")

func test_palette_is_the_only_place_with_values() -> void:
	assert_eq(Palette.money(1.8), "1,80 €", "money is German")
	assert_eq(Palette.money(-2.5), "-2,50 €", "negative money")
	assert_ne(Palette.speaker_colour("lena"), Palette.speaker_colour("juergen"), "speakers differ")
	assert_eq(Palette.COUNTER_TOP, 170, "the counter band is the bottom 100px")
	assert_true(Palette.theme() != null, "Theme.tres loads")

## The night has to end itself: nothing else dispatches `close_night`, and before this the clock ran
## past 06:00 forever and day 2 never came (the engine tests never touch the scenes).
func test_night_screen_closes_the_night_and_hands_over() -> void:
	var packed := load("res://scenes/Night.tscn") as PackedScene
	assert_true(packed != null, "Night.tscn loads")
	if packed == null:
		return
	var night := packed.instantiate()
	var seen: Array = []
	night.connect("request_screen", func(name: String) -> void: seen.append(name))
	var v: Dictionary = MockView.view("late_night")
	v["night_progress"] = 0.81
	night.call("render", v)
	assert_false(bool(night.get("_closing")), "a night still running is not closed")
	v["night_progress"] = 1.0
	v["active"] = {}
	v["queue_len"] = 0
	night.call("render", v)
	assert_true(bool(night.get("_closing")), "06:00 with a clear counter closes the night")
	assert_eq(seen.size(), 0, "closing the night is not a screen change")
	var after: Dictionary = MockView.view("summary")
	night.call("render", after)
	night.call("render", after)
	assert_eq(seen.size(), 1, "the summary is requested exactly once, not once per frame")
	assert_eq(String(seen[0]), "summary", "and it is the summary screen")
	_dispose(night)

## `night.gd::render` re-sends the same dialogue on every Session tick (~60x/s). Restarting the
## typewriter each time made a beat unreadable and undid `advance()` on the next frame.
func test_dialogue_survives_being_re_rendered() -> void:
	var packed := load("res://components/DialogueBox.tscn") as PackedScene
	assert_true(packed != null, "DialogueBox.tscn loads")
	if packed == null:
		return
	var box := packed.instantiate()
	var d: Dictionary = MockView.view("dialogue_choice")["dialogue"]
	box.call("show_dialogue", d, false)
	box.call("advance")  # the first press finishes the typewriter…
	box.call("advance")  # …the second walks to the next line
	var line := int(box.get("_line_index"))
	assert_eq(line, 1, "advance walks to the second line")
	box.call("show_dialogue", d.duplicate(true), false)
	assert_eq(int(box.get("_line_index")), line, "the same dialogue re-rendered does not rewind")
	var other := d.duplicate(true)
	other["lines"] = ["Ganz anderer Satz."]
	box.call("show_dialogue", other, false)
	assert_eq(int(box.get("_line_index")), 0, "a different dialogue does start over")
	_dispose(box)

## docs/06 section 4: the read-model the register screen renders. The four new presets have to carry
## a line, a conversation and a sheet that are actually shaped like the contract, or the captures are
## a drawing of an engine nobody is building.
func test_mock_view_carries_the_register_contract() -> void:
	var waiting: Dictionary = MockView.view("queue_waiting")
	assert_eq((waiting["queue"] as Array).size(), 3, "three guests are in the line")
	assert_true((waiting["active"] as Dictionary).is_empty(), "and nobody is at the counter")
	assert_eq(int(waiting["queue_len"]), (waiting["queue"] as Array).size(), "queue_len agrees with the line")
	for guest in waiting["queue"]:
		for key in ["customer_id", "character_id", "name", "portrait", "expression", "is_story"]:
			assert_true((guest as Dictionary).has(key), "a queue row carries " + str(key))
	for preset in ["talk_lines", "talk_choice", "talk_result"]:
		var talk: Dictionary = MockView.view(preset)["talk"]
		assert_false(talk.is_empty(), preset + " has a conversation open")
		for key in ["speaker", "portrait", "expression", "lines", "line", "choices", "last_check"]:
			assert_true(talk.has(key), "%s talk carries %s" % [preset, key])
		assert_true(int(talk["line"]) < (talk["lines"] as Array).size(), preset + " points at a line that exists")
	assert_true((MockView.view("talk_lines")["talk"]["choices"] as Array).is_empty(), "lines come before choices")
	var choices: Array = MockView.view("talk_choice")["talk"]["choices"]
	assert_eq(choices.size(), 3, "the decision offers three")
	assert_false(((choices[1] as Dictionary)["check"] as Dictionary).is_empty(), "one of them rolls")
	assert_true(bool((choices[2] as Dictionary)["locked"]), "and one of them is a gate")
	var check: Dictionary = MockView.view("talk_result")["talk"]["last_check"]
	assert_eq(int(check["roll"]) + int(check["mod"]), 16, "14 + 2 = 16")
	assert_true(bool(check["success"]), "16 beats DC 12")

## The sheet is a READING: the modifier is the engine's, and the strip prints it rather than deriving
## it (docs/06 section 1). This checks the mock's own arithmetic so the capture cannot teach a lie.
func test_mock_player_modifiers_are_the_5e_rule() -> void:
	var player: Dictionary = MockView.view("queue_waiting")["player"]
	assert_eq((player["stats"] as Dictionary).size(), 6, "six stats")
	for stat_id in Strings.STAT_ORDER:
		var id := String(stat_id)
		assert_true((player["stats"] as Dictionary).has(id), "the sheet has " + id)
		assert_eq(int(player["mods"][id]), int(floorf((float(player["stats"][id]) - 10.0) / 2.0)), id + " modifier is floor((v-10)/2)")
		assert_ne(Strings.stat_name(id), id, id + " has a name the player reads")

## A rolled choice wears its stat tag in the accent colour; a gate is SHOWN, disabled and told why
## (docs/06 section 2). Before this the gate was just another button the player could press.
func test_dialogue_box_tags_checks_and_greys_gates() -> void:
	var packed := load("res://components/DialogueBox.tscn") as PackedScene
	assert_true(packed != null, "DialogueBox.tscn loads")
	if packed == null:
		return
	var box := packed.instantiate()
	var talk: Dictionary = MockView.view("talk_choice")["talk"]
	box.call("show_dialogue", {
		"speaker": String(talk["speaker"]), "portrait": String(talk["portrait"]),
		"expression": "neutral", "lines": [String((talk["lines"] as Array)[0])],
		"choices": talk["choices"], "kind": "talk",
	}, true)
	var rows := box.get_node_or_null("%Choices")
	assert_true(rows != null and rows.get_child_count() == 3, "three choice rows")
	if rows == null or rows.get_child_count() != 3:
		_dispose(box)
		return
	var plain := rows.get_child(0)
	assert_true(plain.get_node_or_null("Tag") == null, "a plain choice wears no tag")
	var rolled := rows.get_child(1)
	var tag := rolled.get_node_or_null("Tag") as Label
	assert_true(tag != null, "the rolled choice wears a tag")
	if tag != null:
		assert_eq(tag.text, Strings.check_tag("cha", 12), "and the tag names the stat and the DC")
		assert_eq(tag.get_theme_color("font_color"), Palette.ACCENT, "in the accent colour")
	var gate := rows.get_child(2)
	var gate_button := gate.get_node_or_null("Line") as Button
	var gate_tag := gate.get_node_or_null("Tag") as Label
	assert_true(gate_button != null and gate_button.disabled, "the gate is shown but not pressable")
	assert_true(gate_tag != null, "the gate says why")
	if gate_tag != null:
		assert_eq(gate_tag.text, Strings.locked("%s %d needed" % [Rules.stat_name("str"), 12]), "the gate says locked: Strength 12 needed")
		assert_eq(gate_tag.get_theme_color("font_color"), Palette.TEXT_DIM, "greyed, not accented")
	# The authored label carries the tag inline ("[Charisma 12] Pay me..."); printing it twice is how
	# a 300-px choice row ends up clipped, so the button keeps only the words.
	if gate_button != null:
		assert_false(gate_button.text.contains("["), "the bracket tag is not repeated inside the button")
	_dispose(box)

## The line is FIFO, the first guest is the one the button takes, and a line longer than the strip
## ends in a "+N" chip instead of running off the frame.
func test_queue_strip_shows_the_line_fifo() -> void:
	var packed := load("res://components/QueueStrip.tscn") as PackedScene
	assert_true(packed != null, "QueueStrip.tscn loads")
	if packed == null:
		return
	var strip := packed.instantiate()
	var queue: Array = MockView.view("queue_waiting")["queue"]
	strip.call("set_queue", queue, true)
	var chips := strip.get_node_or_null("%Chips")
	assert_true(chips != null and chips.get_child_count() == 3, "one chip per waiting guest")
	var first_name := strip.get_node_or_null("%Name") as Label
	assert_true(first_name != null, "the strip names who is next")
	if first_name != null:
		assert_eq(first_name.text, String((queue[0] as Dictionary)["name"]), "and it is the FIRST in line")
	var long_queue: Array = queue.duplicate()
	for i in 9:
		long_queue.append((queue[2] as Dictionary).duplicate())
	strip.call("set_queue", long_queue, true)
	assert_eq(chips.get_child_count(), Palette.QUEUE_SLOTS, "a long line fills the strip and no more")
	assert_eq(chips.get_child(Palette.QUEUE_SLOTS - 1).name, StringName("More"), "the last chip is the overflow")
	var took: Array = []
	strip.connect("talk_next", func() -> void: took.append(1))
	strip.call("_on_next")
	assert_eq(took.size(), 1, "the strip asks for the next guest")
	# With somebody already at the counter `talk_next` is illegal (docs/06 section 4).
	strip.call("set_queue", long_queue, false)
	strip.call("_on_next")
	assert_eq(took.size(), 1, "and stays quiet while a conversation is open")
	var button := strip.get_node_or_null("%NextGuest") as Button
	assert_true(button != null and not button.visible, "the Next guest button hides while they talk")
	# `talk_next` also opens the conversation with whoever is already at the counter, so "take the next
	# guest" is offered with an EMPTY line too - the strip is then the button alone.
	strip.call("set_queue", [], true)
	assert_true(strip.visible and button.visible, "an empty line still offers the guest at the counter")
	assert_false((strip.get_node_or_null("Plate") as Control).visible, "but there is no line to draw")
	# ...and the button says WHICH of the two `talk_next` means, because with somebody at the counter it
	# starts THEIR conversation and leaves the line exactly where it was.
	strip.call("set_queue", [], true, true)
	assert_eq(button.text, Strings.TALK_TO_GUEST, "with a guest at the counter the button says what it does")
	strip.call("set_queue", queue, true, false)
	assert_eq(button.text, Strings.NEXT_GUEST, "with a clear counter it takes the head of the line")
	# And a click on the LINE never silently talks to the person at the counter instead.
	strip.call("set_queue", queue, true, true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	strip.call("_gui_input", click)
	assert_eq(took.size(), 1, "clicking the line does not start the counter's conversation")
	strip.call("set_queue", [], false)
	assert_false(strip.visible, "nobody to take and nobody waiting is no strip at all")
	_dispose(strip)

## The d20 pop prints the engine's arithmetic and nothing else (docs/06 section 2).
func test_dice_result_prints_the_roll() -> void:
	var packed := load("res://components/DiceResult.tscn") as PackedScene
	assert_true(packed != null, "DiceResult.tscn loads")
	if packed == null:
		return
	var dice := packed.instantiate()
	dice.call("show_check", MockView.view("talk_result")["talk"]["last_check"])
	assert_true(dice.visible, "a check that happened is shown")
	assert_eq((dice.get_node_or_null("%Roll") as Label).text, "14", "the die carries the raw roll")
	assert_eq((dice.get_node_or_null("%Line") as Label).text, Strings.dice_line(14, 2, 16), "d20 14 + 2 = 16")
	assert_eq((dice.get_node_or_null("%Verdict") as Label).text, Strings.dice_verdict(12, true), "vs 12, success")
	assert_eq((dice.get_node_or_null("%Verdict") as Label).get_theme_color("font_color"), Palette.GOOD, "in the good colour")
	dice.call("show_check", {"stat": "wis", "roll": 3, "mod": -1, "dc": 14, "success": false})
	assert_eq((dice.get_node_or_null("%Line") as Label).text, Strings.dice_line(3, -1, 2), "a negative modifier subtracts in words")
	assert_eq((dice.get_node_or_null("%Verdict") as Label).get_theme_color("font_color"), Palette.BAD, "a miss is BAD")
	dice.call("show_check", {})
	assert_false(dice.visible, "no check, no pop")
	_dispose(dice)

## The engine composes the second half of a gate's reason (Talk.choice_views) and names the stats for
## it; the string table names them for the UI. Two tables, one set of words - this is what stops them
## drifting, and what makes Strings.locked(reason) frame a sentence the engine can actually produce.
func test_the_two_stat_tables_agree() -> void:
	for stat_id in Strings.STAT_ORDER:
		var id := String(stat_id)
		assert_true(Rules.STAT_IDS.has(id), "the engine knows the stat " + id)
		assert_eq(Strings.stat_name(id), Rules.stat_name(id), id + " is named the same on both sides")
	assert_eq(Strings.STAT_ORDER.size(), Rules.STAT_IDS.size(), "six on both sides")
	# And the mock's locked gate is worded exactly like a real one.
	var s := SpatiState.new_game({})
	var node := {"speaker": "juergen", "expression": "neutral", "lines": ["Lift it?"],
			"choices": [{"label": "Lift the crate.", "requires": {"stat": "str", "min": 12}}]}
	var gate: Dictionary = (Talk.choice_views(s, node) as Array)[0]
	assert_true(bool(gate["locked"]), "STR 10 cannot pass a STR 12 gate")
	var mock_gate: Dictionary = (MockView.view("talk_choice")["talk"]["choices"] as Array)[2]
	assert_eq(String(mock_gate["reason"]), String(gate["reason"]), "the mock's gate says what a real one says")
	assert_true((mock_gate["check"] as Dictionary).is_empty(), "and a gate is not a roll")

## The register columns may not collide: the queue over neither the SPÄTI neon (SceneLayers' glow at
## x 124-224, y 20-62) nor the active bust (bottom-centred on x 250, up to 190 wide), and the sheet
## clear of both HUD plates. This is the rule the brief set, kept as arithmetic instead of an eyeball.
func test_the_register_columns_do_not_overlap() -> void:
	var neon := Rect2i(124, 20, 100, 42)
	var bust := Rect2i(Palette.PORTRAIT_CENTRE_X - 95, 0, 190, Palette.COUNTER_TOP)
	for rect in [Palette.QUEUE_RECT, Palette.DICE_RECT]:
		assert_false(rect.intersects(neon), "the right column clears the SPÄTI sign")
		assert_false(rect.intersects(bust), "the right column clears the active bust")
	assert_false(Palette.STATS_RECT.intersects(bust), "the sheet clears the bust")
	assert_false(Palette.STATS_RECT.intersects(neon), "the sheet clears the sign")
	# Both HUD plates live in the top 20 px (docs/04: one compact line per corner).
	var hud := Rect2i(0, 0, Palette.BASE.x, 20)
	assert_false(Palette.STATS_RECT.intersects(hud), "the sheet clears the HUD")
	assert_false(Palette.SERVE_TOGGLE_RECT.intersects(hud), "so does the demoted serve toggle")
	assert_false(Palette.SERVE_TOGGLE_RECT.intersects(Palette.STATS_RECT), "and the two of them do not stack")
	# The dialogue box gives the right column back when the line is up, or the choices run under it.
	assert_true(Palette.DIALOGUE_RECT.position.x + Palette.DIALOGUE_W_QUEUE <= Palette.QUEUE_RECT.position.x,
			"the narrowed dialogue box stops short of the queue")
	assert_eq(Palette.QUEUE_RECT.position.y + Palette.QUEUE_RECT.size.y, Palette.COUNTER_TOP,
			"the line stands at the counter, not over it")
	# The authored rects are not the whole story: the box keeps its bottom on DIALOGUE_RECT and GROWS
	# UPWARD for a choice list (measured in-tree: 126 px for the three-choice `talk_choice` node, one of
	# them a gate), and it is a later sibling, so it prints over the sheet unless the sheet gives way.
	for h in [Palette.DIALOGUE_RECT.size.y, 96, 126, 140]:
		var bottom: int = Palette.DIALOGUE_RECT.position.y + Palette.DIALOGUE_RECT.size.y
		var grown := Rect2i(Palette.DIALOGUE_RECT.position.x, bottom - h, Palette.DIALOGUE_W_QUEUE, h)
		var sheet := Rect2i(Vector2i(Palette.STATS_RECT.position.x, int(Palette.stats_top(float(bottom - h)))), Palette.STATS_RECT.size)
		assert_false(sheet.intersects(grown), "the sheet clears a %d-px dialogue box" % h)
		assert_false(sheet.intersects(hud), "and never climbs under the HUD to do it")

## The whole conversation, driven the way a player drives it: the box shows the line the ENGINE is on,
## a click asks for the next one, and a choice becomes `talk_choose` (docs/06 section 4).
func test_night_drives_a_conversation() -> void:
	var packed := load("res://scenes/Night.tscn") as PackedScene
	assert_true(packed != null, "Night.tscn loads")
	if packed == null:
		return
	var night := packed.instantiate()
	# A capture preset renders instantly, which is also the only way a typewriter-free assertion can
	# see the choices: outside the tree there is no _process to finish typing the line.
	night.call("apply_capture_preset", "talk_lines")
	var v: Dictionary = MockView.view("talk_lines")
	var box := night.get_node_or_null("%DialogueBox")
	var body := box.get_node_or_null("%Body") as Label
	assert_eq(body.text, String((v["talk"]["lines"] as Array)[int(v["talk"]["line"])]), "the box shows the engine's line")
	var speaker := box.get_node_or_null("%Speaker") as Label
	assert_eq(speaker.text, String(v["talk"]["speaker"]), "and who is saying it")
	assert_eq(box.get_node_or_null("%Choices").get_child_count(), 0, "lines come before choices")
	# The portrait follows the NODE's expression, not the customer's.
	night.call("apply_capture_preset", "talk_result")
	assert_eq(String(night.get_node_or_null("%Portrait").get("expression")), String(MockView.view("talk_result")["talk"]["expression"]), "the bust reacts with the node")
	assert_true(night.get_node_or_null("%DiceResult").visible, "the roll is on screen beside the box")
	night.call("apply_capture_preset", "talk_choice")
	assert_eq(box.get_node_or_null("%Choices").get_child_count(), 3, "the decision is on the counter")
	assert_false(night.get_node_or_null("%DiceResult").visible, "and the previous roll is gone")
	_dispose(night)

## The queue owns the right column, so the box gives it up — and the want bubble stands down, because
## a guest who is TALKING does not also mime their order in a speech balloon.
func test_night_hands_the_right_column_to_the_queue() -> void:
	var packed := load("res://scenes/Night.tscn") as PackedScene
	if packed == null:
		return
	var night := packed.instantiate()
	night.call("render", MockView.view("customer_at_counter"))
	var box := night.get_node_or_null("%DialogueBox") as Control
	assert_eq(int(box.size.x), Palette.DIALOGUE_RECT.size.x, "no line, full-width box")
	assert_true(night.get_node_or_null("%WantBubble").visible, "and the order is in the bubble")
	night.call("render", MockView.view("talk_choice"))
	assert_eq(int(box.size.x), Palette.DIALOGUE_W_QUEUE, "with a line waiting the box steps back")
	assert_false(night.get_node_or_null("%WantBubble").visible, "the bubble stands down while they talk")
	assert_true(night.get_node_or_null("%QueueStrip").visible, "and the line is visible")
	# ...and the sheet steps up out of the grown box. Outside the tree the box cannot measure its own
	# content (no theme, so no font, so no line height), so the height is staged by hand and the chrome
	# is placed explicitly — what is under test is that the SCENE reads the box's real edge, not that a
	# signal fires (in the running game `_ready` also wires `resized`, since the fit is a frame late).
	var stats := night.get_node_or_null("%StatsStrip") as Control
	night.call("_place_chrome", MockView.view("talk_choice"))
	assert_eq(int(stats.position.y), Palette.STATS_RECT.position.y, "a one-line box leaves the sheet where it was authored")
	box.size.y = 126.0
	night.call("_place_chrome", MockView.view("talk_choice"))
	assert_true(int(stats.position.y) < Palette.STATS_RECT.position.y, "a grown box pushes the sheet up")
	assert_false(Rect2i(Vector2i(stats.position), Palette.STATS_RECT.size).intersects(Rect2i(40, 134, Palette.DIALOGUE_W_QUEUE, 126)),
			"far enough up that the choices no longer cover Kiez Sense and Schnauze")
	box.size.y = float(Palette.DIALOGUE_RECT.size.y)
	night.call("_place_chrome", MockView.view("talk_choice"))
	assert_eq(int(stats.position.y), Palette.STATS_RECT.position.y, "and it drops back when the choices are gone")
	# The sheet is default-hidden behind Tab; `queue_waiting` is the capture that opens it for the
	# reader, which is the preset's job, not the read-model's — so it is the PRESET that is checked.
	night.call("apply_capture_preset", "queue_waiting")
	assert_true(night.get_node_or_null("%StatsStrip").visible, "queue_waiting shows the sheet without Tab")
	assert_false(night.get_node_or_null("%DialogueBox").visible, "and nobody is talking")
	_dispose(night)

## A per-render `ensure_control_visible` pinned the shelf to the want's page (measured in-tree: the
## scroll snapped 180 -> 0 on one render), so 10 of the 17 SKUs could not be reached — no upsell, no
## substitute for an out-of-stock want. The reveal is armed once per order, then the scroll is theirs.
func test_shelf_reveals_once_per_order() -> void:
	var panel := load("res://components/ServePanel.tscn").instantiate() as ServePanel
	var v: Dictionary = MockView.view("serving")
	panel.render(v)
	var armed: String = panel._revealed_for
	assert_ne(armed, "", "the first render of an order arms the reveal")
	panel.render(v)
	assert_eq(panel._revealed_for, armed, "re-rendering the same order does not scroll again")
	var next_v: Dictionary = v.duplicate(true)
	next_v["active"]["customer"]["id"] = int(next_v["active"]["customer"]["id"]) + 1
	panel.render(next_v)
	assert_ne(panel._revealed_for, armed, "the next customer re-arms it")
	panel.open(true)
	assert_eq(panel._revealed_for, "", "and re-opening the panel re-centres on the want")
	_dispose(panel)

func _dispose(n: Node) -> void:
	if n == null:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.free()

## 2026-09-13, reported by the user: "I can't get out of the store setup screen." The board read the
## module list with the wrong keys (27 blank rows at 0,00 €) and had no scrolling body, so "Open up"
## sat below the modal's bottom edge in the real game — the scripted playthrough presses the button by
## name and never noticed. Two contracts, checked on the REAL read-model, not the mock:
##   1. every module row the board draws carries the engine's name and cost;
##   2. the foot with "Open up" is outside the scrolling body, and the fixed parts of the board fit the
##      modal frame however long the lists get.
func test_manage_board_names_its_modules_and_keeps_open_up_on_screen() -> void:
	var s := SpatiState.new_game({})
	var v := Rules.view(s)
	var board := (load("res://components/ManageBoard.tscn") as PackedScene).instantiate() as ManageBoard
	board.render(v)
	var modules := board.get_node("%Modules") as VBoxContainer
	var expected := 0
	for m in v["manage"]["modules"]:
		if bool(m["owned"]) or bool(m["available"]):
			expected += 1
	assert_true(expected > 0, "day 1 offers at least one module")
	assert_eq(modules.get_child_count(), expected, "one row per module the hour can act on (owned or available)")
	for row in modules.get_children():
		var name_label := row.get_child(0) as Label
		assert_true(name_label != null and name_label.text != "", "a module row names its module")
		var last := row.get_child(row.get_child_count() - 1)
		if last is Button:
			assert_ne(String((last as Button).text), Palette.money(0.0), "a buy button quotes the module's real cost")
	# The foot is pinned: not inside any ScrollContainer. The body scrolls: the module list IS inside one.
	var open_up := board.get_node("%OpenNight") as Control
	var n: Node = open_up
	var foot_scrolls := false
	while n != null and n != board:
		if n is ScrollContainer:
			foot_scrolls = true
		n = n.get_parent()
	assert_false(foot_scrolls, "Open up is outside the scrolling body, so it is always on screen")
	n = modules
	var body_scrolls := false
	while n != null and n != board:
		if n is ScrollContainer:
			body_scrolls = true
		n = n.get_parent()
	assert_true(body_scrolls, "the module list scrolls instead of growing the board")
	# Fixed parts (head + body minimum + foot) fit the modal's content area whatever the lists hold.
	var body := board.get_node("%Body") as Control
	var head := board.get_node("Head") as Control
	var foot := board.get_node("Foot") as Control
	var fixed := head.get_combined_minimum_size().y + body.custom_minimum_size.y + foot.get_combined_minimum_size().y
	var modal_content := 254.0 - 48.0   # Modal.tscn frame 8..262 minus title row, rule and paddings
	assert_true(fixed <= modal_content, "head + body minimum + foot (%d) fit the modal (%d)" % [int(fixed), int(modal_content)])
	_dispose(board)
