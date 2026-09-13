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
	"res://scenes/Ending.tscn": ["ending"],
	"res://scenes/Main.tscn": ["title", "customer_at_counter", "dialogue_choice", "serving", "pfand", "empty_counter", "late_night", "manage", "summary",
		"queue_waiting", "talk_lines", "talk_choice", "talk_result", "ending"],
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

## 2026-09-13, the same class of bug as "Open up" below the modal: the box measured its own height from
## `%Box.get_combined_minimum_size()` the moment the choice rows were added — before the container had laid
## them out at their real width, where an autowrapped row still reports the wrap-at-no-width guess. A
## two-choice node came out 765 px tall with its top at y=-505: the speaker and the spoken line were off the
## frame and the box's MOUSE_FILTER_STOP rect covered the counter (the d20 plate and the queue strip stopped
## taking clicks). The measurement is only trustworthy once the panel's minimum has SETTLED, so the box
## re-applies its height then; the gallery never showed it because every capture preset changes the width
## afterwards, which re-measures.
func test_dialogue_box_reapplies_its_height_when_the_panel_settles() -> void:
	var packed := load("res://components/DialogueBox.tscn") as PackedScene
	assert_true(packed != null, "DialogueBox.tscn loads")
	if packed == null:
		return
	var box := packed.instantiate()
	# The runner has no SceneTree to add it to (run.gd IS the SceneTree, and its tests run from `_init`),
	# so the component's own `_ready` — where it subscribes to its panel — is called here instead.
	box.call("_ready")
	var talk: Dictionary = MockView.view("talk_choice")["talk"]
	box.call("show_final", {
		"speaker": String(talk["speaker"]), "portrait": String(talk["portrait"]),
		"expression": "neutral", "lines": [String((talk["lines"] as Array)[0])],
		"choices": talk["choices"], "kind": "talk",
	})
	var panel := box.get_node("%Box") as Control
	var subscribed := false
	for c in panel.minimum_size_changed.get_connections():
		if (c["callable"] as Callable).get_object() == box:
			subscribed = true
	assert_true(subscribed, "the box listens for its panel's minimum to settle")
	# Whatever a premature measurement left behind…
	box.set("size", Vector2(box.get("size").x, 765.0))
	box.set("position", Vector2(box.get("position").x, float(DialogueBox.BOTTOM_Y) - 765.0))
	# …the settled minimum puts the box back on the counter.
	panel.minimum_size_changed.emit()
	var want := maxf(float(Palette.DIALOGUE_RECT.size.y), panel.get_combined_minimum_size().y)
	assert_eq(int(box.get("size").y), int(want), "the height is re-applied from the settled minimum")
	assert_true(box.get("position").y >= 0.0, "the box's top stays inside the 270-px frame")
	assert_eq(int(box.get("position").y + box.get("size").y), int(DialogueBox.BOTTOM_Y), "and its bottom edge never moves")
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

## 2026-09-13, same class as "I can't get out of the store setup screen": a control the player must
## not reach is still reachable. The Modal's Dim swallows the MOUSE (mouse_filter STOP) but Godot's
## focus ring only skips invisible/unfocusable controls, so with the Title's Settings frame open one
## Tab landed on "Quit" behind the dim and Enter called get_tree().quit(). Verified live with a
## windowed probe (Tab ring + arrow neighbours); here we pin the lever the ring obeys:
## `focus_behavior_recursive` DISABLED on the screen behind, ENABLED on the frame, both released on
## close. The test runner has no live viewport (run.gd works in `_init`), so this is the contract.
func test_modal_traps_the_keyboard_behind_its_dim() -> void:
	var title := (load("res://scenes/Title.tscn") as PackedScene).instantiate() as Control
	var modal := title.get_node("%SettingsModal") as Modal
	assert_eq(modal.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_INHERITED, "a shut frame claims nothing")
	modal.open()
	assert_eq(title.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED, "an open frame takes the keyboard off the screen behind it")
	assert_eq(modal.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_ENABLED, "and keeps its own rows focusable through that")
	modal.close_modal()
	assert_eq(title.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_INHERITED, "closing gives the menu its keyboard back")
	assert_eq(modal.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_INHERITED, "and the frame stops claiming it")
	_dispose(title)

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
	# Every module gets a row: the actionable ones first, the season's locked roadmap under them.
	assert_eq(modules.get_child_count(), (v["manage"]["modules"] as Array).size(), "every module gets a row")
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
	var body := board.get_node("%Body") as ScrollContainer
	# The body is taller than its window (17 SKUs + modules = ~406 px of content in a 167-px window)
	# and every +/-/Buy in it is a tab stop: without `follow_focus` the ring walks controls the
	# container clips away and the scrollbar never moves (measured: 28 of 56 stops invisible).
	assert_true(body.follow_focus, "the scrolling body tracks the focus ring instead of walking clipped controls")
	var head := board.get_node("Head") as Control
	var foot := board.get_node("Foot") as Control
	# A dead band between the scrolling body and the foot: the boundary row is sliced at almost any
	# scroll offset, and without it a click 2 px low on a half-visible price "+" started the night.
	var gap := board.get_node("FootGap") as Control
	assert_true(gap.custom_minimum_size.y >= 4.0, "the foot keeps a dead band above it")
	assert_eq(gap.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and the band itself takes no clicks")
	var fixed := head.get_combined_minimum_size().y + body.custom_minimum_size.y + gap.custom_minimum_size.y + foot.get_combined_minimum_size().y
	var modal_content := 254.0 - 48.0   # Modal.tscn frame 8..262 minus title row, rule and paddings
	assert_true(fixed <= modal_content, "head + body minimum + foot (%d) fit the modal (%d)" % [int(fixed), int(modal_content)])
	_dispose(board)

## 2026-09-13: the season's end had no screen. `_advance_day` sets phase "end" (day past
## `season_days`, or cash < -200), `legal_actions` is then empty — and the shell sent the player to
## Manage, whose "Open up" pushed them on to a Night screen the reducer had finished with. The
## finale `Rules.view` composes was rendered by nothing. On the REAL read-model, never the mock.
func test_the_season_ends_on_a_screen_with_a_way_out() -> void:
	var s := SpatiState.new_game({"season_days": 1})
	s = Rules.apply(s, {"type": "open_night"})
	s = Rules.apply(s, {"type": "close_night"})
	s = Rules.apply(s, {"type": "advance_day"})
	assert_eq(String(s["phase"]), "end", "a one-night season ends on the first advance_day")
	assert_true((Rules.legal_actions(s) as Array).is_empty(), "the reducer offers nothing at the end")
	var v := Rules.view(s)
	var ending: Dictionary = v["ending"]
	assert_false(ending.is_empty(), "phase end carries the finale")
	# Every phase the reducer can reach has a screen the shell knows.
	var screens: Dictionary = (load("res://scenes/main.gd") as GDScript).get_script_constant_map()["SCREENS"]
	for phase in ["manage", "night", "summary", "end"]:
		assert_true(screens.has(Screen.screen_for(phase)), "phase %s routes to a screen Main has" % phase)
	var screen := (load("res://scenes/Ending.tscn") as PackedScene).instantiate() as Screen
	# `_ready` by hand: the runner has no tree (tests/run.gd works from `_init`), so nothing calls it.
	screen.call("_ready")
	screen.render(v)
	assert_eq((screen.get_node("%Title") as Label).text, String(ending["title"]), "the card carries the engine's ending")
	assert_eq((screen.get_node("%Line") as Label).text, String(ending["line"]), "and its words")
	var back := screen.get_node("%BackToTitle") as Button
	assert_true(back.visible and not back.disabled, "the one control is live")
	assert_ne(back.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and it takes the pointer")
	# Pinned outside the scrolling body: however long the tapestry grows, the way out stays on screen.
	var n: Node = back
	var scrolls := false
	while n != null and n != screen:
		if n is ScrollContainer:
			scrolls = true
		n = n.get_parent()
	assert_false(scrolls, "the way out is outside the scrolling body")
	var seen: Array[String] = []
	screen.request_screen.connect(func(name: String) -> void: seen.append(name))
	back.pressed.emit()
	assert_eq(seen, ["title"], "and it leads back to the title")
	_dispose(screen)

## The tapestry: one row per met-and-resolved character, rebuilt (never appended) on every render.
func test_the_ending_lists_its_epilogues() -> void:
	var screen := (load("res://scenes/Ending.tscn") as PackedScene).instantiate() as Screen
	var v := MockView.view("ending")
	screen.render(v)
	var rows := screen.get_node("%Epilogues") as VBoxContainer
	assert_eq(rows.get_child_count(), (v["ending"]["epilogues"] as Array).size(), "one row per epilogue")
	screen.render(v)
	assert_eq(rows.get_child_count(), (v["ending"]["epilogues"] as Array).size(), "re-rendering rebuilds, never appends")
	screen.render(Rules.view(SpatiState.new_game({})))
	assert_eq(rows.get_child_count(), 0, "a view with no finale leaves no tapestry behind")
	_dispose(screen)

## A screen may ask for another one from its FIRST render — `add_child` runs `_ready` ->
## `Screen.refresh()` -> `render()` — and the shell used to connect `request_screen` on the line
## AFTER `add_child`, so that request went to a signal with no listener and Night's `_leaving` latch
## made sure it was never asked again (2026-09-13).
func test_main_hears_a_redirect_from_a_screens_first_render() -> void:
	var src := FileAccess.get_file_as_string("res://scenes/main.gd")
	var connect_at := src.find("inst.connect(\"request_screen\"")
	var add_at := src.find("host.add_child(inst)")
	assert_true(connect_at >= 0 and add_at >= 0, "main._swap still has both lines")
	assert_true(connect_at < add_at, "request_screen is connected before add_child runs the screen's _ready")
	# ...and the shell answers it without freeing a screen inside its own `_ready`.
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	main.call("_swap", "night")   # outside the tree: `_ready` has not run, so no first render yet
	var night := main.call("_screen") as Screen
	var v := MockView.view("summary")
	v["phase"] = "end"
	night.render(v)               # the render `_ready` would have done
	assert_eq(String(main.get("current_screen")), "end", "the redirect is heard and routed by phase")
	_dispose(main)

## 2026-09-13: the rows print "1." / "2." and no digit was bound to them, and nothing on the Night
## screen ever took focus — so with eight keys pressed at a live choice node the focus owner stayed
## null and the conversation could only be answered with a mouse. `choose_number` counts GATES,
## because the printed number does: with "2." locked, "3." is still `choices[2]`.
func test_dialogue_box_picks_the_choice_its_number_prints() -> void:
	var box := (load("res://components/DialogueBox.tscn") as PackedScene).instantiate() as DialogueBox
	box.call("_ready")
	box.show_final({
		"speaker": "Lena", "portrait": "char/lena", "expression": "neutral", "kind": "talk",
		"lines": ["..."],
		"choices": [
			{"label": "a"},
			{"label": "b", "locked": true, "requires": {"stat": "str", "min": 12}},
			{"label": "c"},
		],
	})
	var picked: Array[int] = []
	box.choice.connect(func(i: int) -> void: picked.append(i))
	assert_true(box.choose_number(3), "the row printed '3.' is pickable")
	assert_eq(picked, [2], "and it is choices[2] — the gate is counted, exactly as the label counts it")
	assert_false(box.choose_number(2), "a gate is not pickable by its number")
	assert_false(box.choose_number(4), "a number with no row does nothing")
	# The screen anchors the keyboard off this signal; without it the ring has nowhere to start.
	var announced := false
	for c in box.choices_shown.get_connections():
		announced = true
	assert_true(box.has_method("focus_first_choice"), "the box can hand the keyboard its first live row")
	assert_false(announced, "nothing is wired to a loose box — the SCREEN connects choices_shown")
	_dispose(box)

## 2026-09-13: "Ring up" and "Wave off" were live at an empty counter. The reducer refuses
## `serve_active`/`skip_active` while `active` is empty (rules.gd), but the scene cleared the tray and
## closed the panel regardless — the UI reported a sale that moved no cash and no `sales`. On the REAL
## read-model: the two buttons must agree with what `legal_actions` actually offers.
func test_till_buttons_agree_with_the_reducers_offer() -> void:
	var s := Rules.apply(SpatiState.new_game({"seed": 7}), {"type": "open_night"})
	assert_true((s["active"] as Dictionary).is_empty(), "nobody is at the counter when the night opens")
	var panel := (load("res://components/ServePanel.tscn") as PackedScene).instantiate() as ServePanel
	panel.render(Rules.view(s))
	var t := panel.till()
	t.add_sku({"sku_id": "beer", "name": "Sterni", "price": 1.2})
	assert_eq(t.lines.size(), 1, "the shelf still stages a tray")
	assert_true((t.get_node("%RingUp") as Button).disabled, "Ring up is dead with nobody to serve")
	assert_true((t.get_node("%WaveOff") as Button).disabled, "Wave off is dead with nobody to wave off")
	# …and both come back the moment somebody is standing there.
	var s2 := Rules.apply(SpatiState.new_game({"seed": 7, "auto_take_next": true}), {"type": "open_night"})
	var guard := 0
	while (s2["active"] as Dictionary).is_empty() and guard < 600:
		s2 = Rules.tick(s2, 1000)
		guard += 1
	assert_false((s2["active"] as Dictionary).is_empty(), "a guest reaches the counter")
	panel.render(Rules.view(s2))
	t.add_sku({"sku_id": "beer", "name": "Sterni", "price": 1.2})
	assert_false((t.get_node("%RingUp") as Button).disabled, "a staged tray rings up for a real guest")
	assert_false((t.get_node("%WaveOff") as Button).disabled, "and that guest can be waved off")
	_dispose(panel)

## 2026-09-13, the Manage bug's twin: a control the player cannot see still took their input.
## `close()` only slid the panel to x 482, so "Wave off" kept FOCUS_ALL off-screen and ate every
## `ui_accept` the night reads in `_unhandled_input` — one mouse wave-off killed Space for the rest
## of the night, and an arrow key could fill an invisible till.
func test_a_closed_serve_panel_leaves_the_ui() -> void:
	var panel := (load("res://components/ServePanel.tscn") as PackedScene).instantiate() as ServePanel
	panel.render(MockView.view("serving"))
	panel.open(true)
	assert_true(panel.visible, "an open panel is on screen")
	panel.close(true)
	assert_false(panel.visible, "a closed panel is out of the UI, not just off the screen")
	assert_false(panel.is_open, "and it says so")
	panel.open(true)
	assert_true(panel.visible, "re-opening puts it back")
	_dispose(panel)

## 2026-09-13: once "New game" was pressed there was no pause, no Esc and no route back to the Title
## — Manage's board modal is `closable = false`, Night and Summary carry no modal at all, and
## `Strings.PAUSED`/`RESUME`/`BACK_TO_TITLE` plus `Session.paused` were declared and never used. The
## only exit from a running season was the OS window. The overlay belongs to the shell, which is the
## one node that survives every `_swap`.
func test_a_running_game_always_has_a_pause_route() -> void:
	var main := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	main.call("_build_pause")
	var pause := main.get_node("%Pause") as Modal
	assert_true(pause != null, "the shell carries the pool's Modal, not a second overlay look")
	assert_true(pause.closable, "and this one answers Esc, unlike Manage's board frame")
	assert_false(pause.visible, "it is down at rest")
	assert_eq(pause.title, Strings.PAUSED, "the title comes from the table the constant was dead in")
	for pair in [["%Resume", Strings.RESUME], ["%BackToTitle", Strings.BACK_TO_TITLE], ["%QuitGame", Strings.QUIT]]:
		var b := main.get_node(String(pair[0])) as Button
		assert_eq(b.text, String(pair[1]), String(pair[0]) + " names itself from Strings")
		assert_false(b.disabled, String(pair[0]) + " is live")
		assert_true(b.pressed.get_connections().size() > 0, String(pair[0]) + " does something")
		# The rows are inside the frame, so the Modal's focus trap covers them.
		var n: Node = b
		var inside := false
		while n != null:
			if n == pause:
				inside = true
			n = n.get_parent()
		assert_true(inside, String(pair[0]) + " lives inside the pause frame")
	main.call("open_pause")
	assert_true(pause.visible, "Esc opens it")
	main.call("close_pause")
	assert_false(pause.visible, "and Resume / × / Esc put it away again")
	_dispose(main)

## 2026-09-13: at the season's end the board still drew 57 live controls over ZERO legal actions —
## `Rules.view` builds the `manage` block for every phase and the board never looked at it. Belt and
## braces behind the routing fix: whichever way a player reaches this board, it goes read-only when
## the reducer will refuse it. On the REAL read-model, both directions, so the gate cannot rot into
## always-off.
func test_the_manage_board_is_read_only_outside_the_manage_hour() -> void:
	var s := SpatiState.new_game({"season_days": 1})
	s = Rules.apply(s, {"type": "open_night"})
	s = Rules.apply(s, {"type": "close_night"})
	s = Rules.apply(s, {"type": "advance_day"})
	assert_eq(String(s["phase"]), "end", "a one-night season ends on the first advance_day")
	var board := (load("res://components/ManageBoard.tscn") as PackedScene).instantiate() as ManageBoard
	board.call("_ready")
	board.render(Rules.view(s))
	var live: Array[String] = []
	_live_buttons(board, live)
	assert_true(live.is_empty(), "no live control while every board action is refused: " + str(live))
	board.render(Rules.view(SpatiState.new_game({})))
	live.clear()
	_live_buttons(board, live)
	assert_true(live.has("OpenNight"), "the hour before opening is still fully playable")
	assert_true(live.size() > 1, "and so are its rows")
	_dispose(board)

func _live_buttons(n: Node, out: Array[String]) -> void:
	if n is Button and not (n as Button).disabled:
		out.append(String(n.name))
	for c in n.get_children():
		_live_buttons(c, out)

## 2026-09-13: `set_sunday_open` is legal every manage hour (rules.gd::legal_actions) and had NO
## control anywhere — so `open_sunday` stayed false for the life of every run and the whole Sunday /
## Ordnungsamt system (the ×1.6 traffic spike, the roll, the fine, `ordnungsamt_heat`) was unreachable
## content. The general lens: every distinct legal action of the manage hour must have a control.
func test_every_legal_manage_action_has_a_control() -> void:
	var s := SpatiState.new_game({})
	var board := (load("res://components/ManageBoard.tscn") as PackedScene).instantiate() as ManageBoard
	board.call("_ready")   # the runner has no tree, so the foot's connections are made by hand
	board.render(Rules.view(s))
	var emitted: Array[Dictionary] = []
	board.action.connect(func(a: Dictionary) -> void: emitted.append(a))
	var opened := false
	board.open_night.connect(func() -> void: opened = true)
	_press_all(board)
	var seen := {"open_night": opened}
	for a in emitted:
		seen[String(a["type"])] = true
	for want in Rules.legal_actions(s):
		assert_true(seen.has(String(want["type"])), "the board offers a control for " + String(want["type"]))
	# ...and the one it never had emits what the reducer will actually take.
	var sunday := board.get_node("%SundayToggle") as Button
	assert_false(sunday.disabled, "the Sunday plate is live in the manage hour")
	var flip := {}
	for a in emitted:
		if String(a["type"]) == "set_sunday_open":
			flip = a
	assert_eq(bool(flip["open"]), true, "a shut corner offers to open on Sundays")
	assert_eq(bool(Rules.apply(s, flip)["open_sunday"]), true, "and the reducer takes it")
	# Pinned in the foot with "Open up", outside the scrolling body, so it can never be pushed off.
	var n: Node = sunday
	var scrolls := false
	while n != null and n != board:
		if n is ScrollContainer:
			scrolls = true
		n = n.get_parent()
	assert_false(scrolls, "the Sunday plate is pinned in the foot, not in the scrolling body")
	_dispose(board)

func _press_all(n: Node) -> void:
	if n is Button and not (n as Button).disabled:
		(n as Button).pressed.emit()
	for c in n.get_children():
		_press_all(c)

## 2026-09-13: locked modules were dropped from the board entirely, so `Economy.unlock_reason`'s
## strings ("unlocks on day 3", "needs Bigger fridge", "needs Kiez-Trust 60") were computed and
## thrown away — a day-1 player saw 4 of 26 modules and had no way to learn the rest existed, which
## also made the season's "the list grows" progression invisible as progression.
func test_manage_board_shows_why_a_module_is_still_locked() -> void:
	var s := SpatiState.new_game({})
	var v := Rules.view(s)
	var board := (load("res://components/ManageBoard.tscn") as PackedScene).instantiate() as ManageBoard
	board.render(v)
	var modules := board.get_node("%Modules") as VBoxContainer
	var actionable := 0
	var reasons := {}
	for m in v["manage"]["modules"]:
		if bool(m["owned"]) or bool(m["available"]):
			actionable += 1
		else:
			assert_ne(String(m["reason"]), "", "the engine says why a locked module is locked")
			reasons[String(m["reason"])] = true
	assert_true(actionable > 0 and reasons.size() > 0, "day 1 has both buyable and locked modules")
	assert_eq(modules.get_child_count(), (v["manage"]["modules"] as Array).size(), "every module gets a row")
	for i in modules.get_child_count():
		var row := modules.get_child(i) as HBoxContainer
		var last := row.get_child(row.get_child_count() - 1)
		var is_action := last is Button or String((last as Label).text) == Strings.MANAGE_OWNED
		assert_eq(is_action, i < actionable, "actionable rows first, the locked roadmap under them")
		if not is_action:
			var why := row.get_child(1) as Label
			assert_true(reasons.has(why.text), "a locked row prints the engine's reason: " + why.text)
			assert_false(why.clip_text, "and it is never clipped off the right edge")
	_dispose(board)

## 2026-09-13: `StepButton` defined four styleboxes and left `disabled` to the base Button's 3-px
## padded box, which raises the minimum from 18 to 24 px — and a Control never shrinks below a size
## it already has, so the FIRST disabled frame latched the Serve toggle 6 px taller than
## `Palette.SERVE_TOGGLE_RECT` for the rest of the night. It also slices a greyed SKU row out of
## ROW_H, which matters now that the board greys itself outside the manage hour.
func test_a_step_button_keeps_its_height_in_every_state() -> void:
	var t := Palette.theme()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		assert_true(t.has_stylebox(state, "StepButton"), "StepButton defines its own " + state + " box")
		if t.has_stylebox(state, "StepButton"):
			assert_eq(t.get_stylebox(state, "StepButton").get_minimum_size().y, 0.0,
				state + " adds no vertical padding, so the plate is the font's own height")
