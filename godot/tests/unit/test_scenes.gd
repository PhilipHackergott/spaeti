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
	# The ring-up (docs/08-register-and-tobacco.md section 4.1).
	"res://components/BrandMark.tscn",
	"res://components/StepChip.tscn",
	"res://components/DragItem.tscn",
	"res://components/DragLayer.tscn",
	"res://components/CounterTray.tscn",
	"res://components/Scanner.tscn",
	"res://components/RegisterPanel.tscn",
	"res://components/OrderCard.tscn",
	"res://components/TobaccoWall.tscn",
]

const SCENE_PRESETS := {
	"res://scenes/Title.tscn": ["title"],
	"res://scenes/Night.tscn": ["empty_counter", "customer_at_counter", "dialogue_choice", "serving", "pfand", "late_night",
		"queue_waiting", "talk_lines", "talk_choice", "talk_result",
		"register_counter", "register_wall", "register_error"],
	"res://scenes/Manage.tscn": ["manage"],
	"res://scenes/Summary.tscn": ["summary"],
	"res://scenes/Ending.tscn": ["ending"],
	"res://scenes/Main.tscn": ["title", "customer_at_counter", "dialogue_choice", "serving", "pfand", "empty_counter", "late_night", "manage", "summary",
		"queue_waiting", "talk_lines", "talk_choice", "talk_result", "ending",
		"register_counter", "register_wall", "register_error"],
}

## The keys `Rules.view(state)` must hand a scene (docs/05 section 5).
const VIEW_KEYS := [
	"phase", "day", "weekday_name", "clock_ms", "night_progress", "time_label", "cash", "pfand_held",
	"pfand_rate", "reputation", "hud", "active", "queue_len", "dialogue", "shelf", "summary", "manage", "ending",
	# docs/06-dialogue-and-stats.md section 4: the line, the conversation and the character sheet.
	"queue", "talk", "player",
	# docs/08-register-and-tobacco.md section 3.3: the counter, the register, her words and the wall.
	"counter", "register", "order", "view_mode", "wall",
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

# ── the ring-up (docs/08-register-and-tobacco.md) ─────────────────────────────────────────────

## The three columns of the register mode, kept as arithmetic instead of an eyeball: the tray never
## runs into the glass, the glass never into the register, the card never into the counter band or
## the HUD, and the narrowed dialogue box stops short of the register the way it stops short of the
## queue. Every rect is a `Palette` constant, so this is the table checking itself.
func test_the_ring_up_columns_do_not_overlap() -> void:
	var frame := Rect2i(Vector2i.ZERO, Palette.BASE)
	for rect in [Palette.ORDER_RECT, Palette.TRAY_RECT, Palette.SCANNER_RECT, Palette.REGISTER_RECT,
			Palette.ORDER_RECT_WALL, Palette.WALL_HAND_RECT, Palette.WALL_BACK_RECT, Palette.WALL_TOTAL_RECT]:
		assert_true(frame.encloses(rect), "the ring-up stays inside the frame: " + str(rect))
	assert_false(Palette.TRAY_RECT.intersects(Palette.SCANNER_RECT), "the tray never runs into the glass")
	assert_false(Palette.TRAY_RECT.intersects(Palette.REGISTER_RECT), "nor into the register")
	assert_false(Palette.SCANNER_RECT.intersects(Palette.REGISTER_RECT), "the glass clears the register")
	assert_false(Palette.ORDER_RECT.intersects(Palette.TRAY_RECT), "the card clears the counter band")
	assert_false(Palette.ORDER_RECT.intersects(Palette.REGISTER_RECT), "and the register column")
	assert_false(Palette.ORDER_RECT.intersects(Rect2i(0, 0, Palette.BASE.x, 22)), "and the HUD")
	assert_true(Palette.DIALOGUE_RECT.position.x + Palette.DIALOGUE_W_RING <= Palette.REGISTER_RECT.position.x,
			"the box narrowed for the ring-up stops short of the register")
	# Every row of the register column inside the panel, and no two of them stacked on each other.
	# REGISTER_BANNER_RECT is deliberately NOT in this list: since 2026-09-13 the tell shares the title's
	# slot (the word "Register" stands down while it is up) so the basket's fifth line has a row. The two
	# are mutually exclusive, which the next assertion pins instead of the overlap rule.
	assert_eq(Palette.REGISTER_BANNER_RECT, Palette.REGISTER_HEAD_RECT, "the tell stands where the title does")
	var rows: Array = [Palette.REGISTER_HEAD_RECT, Palette.CHECK_ID_RECT,
		Palette.REGISTER_LINES_RECT, Palette.REGISTER_SUBTOTAL_RECT, Palette.PFAND_ROW_RECT,
		Palette.REGISTER_TOTAL_RECT, Palette.TURN_AROUND_RECT, Palette.RING_UP_RECT, Palette.WAVE_OFF_RECT]
	for i in rows.size():
		assert_true(Palette.REGISTER_RECT.encloses(rows[i]), "inside the register column: " + str(rows[i]))
		for j in range(i + 1, rows.size()):
			assert_false((rows[i] as Rect2i).intersects(rows[j]),
					"%s and %s do not stack" % [str(rows[i]), str(rows[j])])
	# Seven slots at pitch 38 fit the tray exactly, and the last one does not hang off the end.
	assert_true(Palette.TRAY_RECT.encloses(Palette.tray_slot_rect(Palette.TRAY_SLOTS - 1)),
			"the last tray slot is inside the tray")
	# ...and every wall facing is on screen, at the footprint the catalogue declares.
	for row in 3:
		var sku_ids: Array = [["cigarettes"], ["tobacco"], ["papers", "filters"]][row]
		var col := 0
		for sku_id in sku_ids:
			for brand in Content.brands_for(String(sku_id)):
				var cell := Palette.wall_cell_rect(row, col, BrandMark.facing_size(brand))
				assert_true(frame.encloses(cell), "wall facing on screen: " + String((brand as Dictionary)["id"]))
				assert_false(cell.intersects(Palette.WALL_HAND_RECT), "and clear of the hand strip")
				col += 1

## A 16-px register line cannot hold a 20-px button, and a Control never shrinks below its own
## minimum — so the row's controls are measured, not assumed (the Serve toggle latched 6 px taller
## exactly this way, test_a_step_button_keeps_its_height_in_every_state).
func test_a_register_line_fits_the_row_it_is_in() -> void:
	var panel := (load("res://components/RegisterPanel.tscn") as PackedScene).instantiate() as RegisterPanel
	panel.call("_ready")
	panel.set_can_serve(true)
	panel.render(MockView.view("register_error")["register"])
	# The panel's own rows keep the rects Palette authored for them.
	for unique in ["%TurnAround", "%RingUp", "%WaveOff", "%CheckId", "%PfandDown", "%PfandUp"]:
		var n := panel.get_node(unique) as Control
		assert_true(n.size.y <= 20.0, "%s is %d px tall" % [unique, int(n.size.y)])
	# A StepChip has NO intrinsic minimum — that is the whole reason it exists — so the row's rect
	# survives entering a tree, where a Button's would have grown to 31 px.
	for unique in ["%PfandDown", "%PfandUp"]:
		var chip := panel.get_node(unique) as StepChip
		assert_true(chip != null, unique + " is a row chip, not a Button")
		if chip != null:
			assert_eq(chip.get_combined_minimum_size(), Vector2(chip.size), unique + " is exactly its rect")
	var host := panel.get_node("%Lines") as Control
	assert_true(host.get_child_count() >= 2, "the error preset rings two lines")
	for i in host.get_child_count():
		var row := host.get_child(i) as Control
		for c in row.get_children():
			var control := c as Control
			if control == null:
				continue
			# A LABEL may be taller than its row — Jersey's line box is 23 px and it prints from the
			# top — but anything the pointer or the focus ring can land on must fit, or it covers the
			# row underneath and the click goes to the wrong line.
			if control.focus_mode != Control.FOCUS_NONE or control.mouse_filter == Control.MOUSE_FILTER_STOP:
				assert_true(control.size.y <= float(Palette.REGISTER_ROW_H),
						"%s is %d px tall in a %d-px row" % [String(control.name), int(control.size.y), Palette.REGISTER_ROW_H])
			assert_true(control.position.x + control.size.x <= float(Palette.REGISTER_LINES_RECT.size.x),
					"%s stays inside the 130-px line" % String(control.name))
		assert_true(row.position.y + row.size.y <= float(Palette.REGISTER_LINES_RECT.size.y),
				"row %d stays inside the list" % i)
	_dispose(panel)

## The tray cannot overflow, and that is a fact about the REDUCER, not a hope about the content:
## docs/08 section 3.1 caps a basket at 3 placed + 3 fetched + 1 crate, which is exactly seven.
func test_the_tray_holds_the_reducers_whole_basket() -> void:
	assert_eq(Palette.TRAY_SLOTS, 7, "3 placed + 3 fetched + 1 crate")
	var tray := (load("res://components/CounterTray.tscn") as PackedScene).instantiate() as CounterTray
	tray.call("_ready")
	var rows: Array = []
	var source: Array = MockView.view("register_counter")["counter"]
	for i in Palette.TRAY_SLOTS:
		var row: Dictionary = (source[i % source.size()] as Dictionary).duplicate(true)
		row["uid"] = 100 + i
		row["slot"] = i
		rows.append(row)
	tray.render(rows)
	assert_eq(tray.filled_slots().size(), Palette.TRAY_SLOTS, "a full basket fills the tray and no more")
	var frame := Rect2(Vector2.ZERO, Vector2(Palette.BASE))
	for slot in tray.filled_slots():
		assert_true(frame.encloses(slot.get_global_rect()), "every slot is on screen: " + String(slot.name))
		assert_eq(slot.focus_mode, Control.FOCUS_ALL, "and focusable, so the keyboard reaches it")
	assert_true(tray.slot_for(103) != null, "the tray finds a slot by the uid the view names")
	assert_true(tray.slot_for(999) == null, "and finds nothing for a uid it was never given")
	_dispose(tray)

## THE anti-soft-lock test (docs/08 section 6). For every action the read-model makes legal, the
## screen must offer a control that is (1) on the frame, (2) not greyed, and (3) the node a pointer at
## its own centre would actually land on. Today's soft-lock shipped because a driver pressed buttons
## by NAME; nothing here names one.
func test_the_register_puts_every_action_on_a_control_you_can_hit() -> void:
	var night := _ring_night("register_counter")
	var v: Dictionary = MockView.view("register_counter")
	var wanted := _ring_up_actions(v)
	assert_true(wanted.size() >= 8, "the counter offers a real set of actions, not one button")
	for action in wanted:
		var controls: Array = night.call("controls_for", action)
		assert_false(controls.is_empty(), "a live control offers " + JSON.stringify(action))
		if controls.is_empty():
			continue
		var c := controls[0] as Control
		var r := c.get_global_rect()
		assert_true(Rect2(Vector2.ZERO, Vector2(Palette.BASE)).encloses(r),
				"it is inside 480x270: %s at %s" % [JSON.stringify(action), str(r)])
		var hit := night.call("control_at", r.get_center()) as Control
		assert_true(hit == c or (hit != null and c.is_ancestor_of(hit)),
				"and nothing covers it: %s hits %s" % [JSON.stringify(action), str(hit)])
	_dispose(night)

## The pointer, for real. A press and a release on the slot the READ-MODEL names, at the rect the
## screen actually draws, must produce exactly `scan{uid}` — asserted as a dictionary, not as "the
## button called Slot2 was pressed".
func test_a_click_on_the_counter_scans_the_uid_the_view_names() -> void:
	var night := _ring_night("register_counter")
	var seen: Array = []
	night.connect("acted", func(a: Dictionary) -> void: seen.append(a))
	var v: Dictionary = MockView.view("register_counter")
	var uid := -1
	for row in v["counter"]:
		var r: Dictionary = row
		if String(r.get("kind", "")) == "item" and not bool(r.get("scanned", false)):
			uid = int(r["uid"])
			break
	assert_true(uid >= 0, "the preset has something left to scan")
	var controls: Array = night.call("controls_for", {"type": "scan", "uid": uid})
	assert_false(controls.is_empty(), "and a control that offers it")
	if controls.is_empty():
		_dispose(night)
		return
	var slot := controls[0] as Button
	# The pointer part: the node under a click at the slot's own centre IS this slot.
	var hit: Control = night.call("control_at", slot.get_global_rect().get_center())
	assert_true(hit == slot or (hit != null and slot.is_ancestor_of(hit)), "a click there lands on the slot")
	slot.pressed.emit()
	assert_eq(seen.size(), 1, "one press, one action")
	if seen.is_empty():
		_dispose(night)
		return
	assert_eq(String((seen[0] as Dictionary)["type"]), "scan", "and the action is a scan")
	assert_eq(int((seen[0] as Dictionary)["uid"]), uid, "of the uid the read-model named")
	_dispose(night)

## Drag is a SKIN over `scan{uid}` (docs/08 section 4.2), and this is what proves it: a real
## `InputEventMouseButton` + `InputEventMouseMotion` past the 3-px grab threshold lifts the item, and
## releasing it over the scanner's hot zone emits the SAME dictionary the click did.
func test_drag_is_a_skin_over_scan() -> void:
	var night := _ring_night("register_counter")
	var seen: Array = []
	night.connect("acted", func(a: Dictionary) -> void: seen.append(a))
	var tray := night.get_node_or_null("%CounterTray") as CounterTray
	var drag := night.get_node_or_null("%DragLayer") as DragLayer
	var scanner := night.get_node_or_null("%Scanner") as Scanner
	assert_true(tray != null and drag != null and scanner != null, "the counter has a tray, a layer and a glass")
	if tray == null or drag == null or scanner == null:
		_dispose(night)
		return
	var slot: Button = tray.filled_slots()[2]   # the first unscanned item in the register_counter preset
	var uid := int(slot.get_meta("uid", -1))
	var index := int(slot.get_meta("slot", -1))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(4, 4)
	tray.call("_on_slot_input", press, index)
	assert_false(drag.is_dragging(), "a press alone is not a drag")
	var move := InputEventMouseMotion.new()
	move.position = Vector2(4 + Palette.DRAG_GRAB_PX + 2.0, 4)
	tray.call("_on_slot_input", move, index)
	assert_true(drag.is_dragging(), "past the grab threshold the item is in the air")
	# The glass arms only while the carried item is actually over it.
	drag.move_to(scanner.get_global_rect().get_center())
	assert_true(scanner.is_armed(), "the glass arms under the carried item")
	drag.release_at(scanner.get_global_rect().get_center())
	assert_false(drag.is_dragging(), "the release ends the drag")
	assert_eq(seen.size(), 1, "a drop is one action, not two")
	if not seen.is_empty():
		assert_eq(seen[0], {"type": "scan", "uid": uid}, "and it is the same scan a click makes")
	# A miss springs home and moves nothing.
	tray.call("_on_slot_input", press, index)
	tray.call("_on_slot_input", move, index)
	drag.release_at(Vector2(2, 2))
	assert_false(drag.is_dragging(), "a miss ends the drag too")
	assert_eq(seen.size(), 1, "and dispatches nothing at all")
	_dispose(night)

## THE RELEASE ITSELF, not a call to `release_at`. The press that starts a drag is taken by the tray
## SLOT, so Godot keeps the mouse grab there for the whole gesture: the drop target under the cursor
## never sees a button event at all, and the scanner's `_gui_input` fires on a PRESS, which during a
## drag has already happened somewhere else. So nothing ended a real pointer drag - the item hung on
## the cursor, `is_dragging()` stayed true for the rest of the night, the glass stayed armed, and
## `Turn around` (which stands down mid-drag, docs/08 section 3.2) was dead from then on. It shipped
## because every test above calls `release_at()` by hand; the pointer probe found it in ten seconds.
##
## The second half is the other end of the same gesture: a drag that ends on the GLASS releases
## OUTSIDE the slot, so the slot's own `pressed` never fires and the guard that exists to swallow
## that release was never spent - the slot then ate the next real click on it in silence.
func test_the_mouse_up_ends_the_drag_and_the_slot_still_takes_the_next_click() -> void:
	var night := _ring_night("register_counter")
	var seen: Array = []
	night.connect("acted", func(a: Dictionary) -> void: seen.append(a))
	var tray := night.get_node_or_null("%CounterTray") as CounterTray
	var drag := night.get_node_or_null("%DragLayer") as DragLayer
	var scanner := night.get_node_or_null("%Scanner") as Scanner
	assert_true(tray != null and drag != null and scanner != null, "the counter has a tray, a layer and a glass")
	if tray == null or drag == null or scanner == null:
		_dispose(night)
		return
	var slot: Button = tray.filled_slots()[2]
	var uid := int(slot.get_meta("uid", -1))
	var index := int(slot.get_meta("slot", -1))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(4, 4)
	var move := InputEventMouseMotion.new()
	move.position = Vector2(4 + Palette.DRAG_GRAB_PX + 2.0, 4)
	tray.call("_on_slot_input", press, index)
	tray.call("_on_slot_input", move, index)
	assert_true(drag.is_dragging(), "the item is in the air")
	drag.move_to(scanner.get_global_rect().get_center())
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = scanner.get_global_rect().get_center()
	drag.call("_input", up)
	assert_false(drag.is_dragging(), "the mouse-UP ends the drag by itself - nobody calls release_at")
	assert_eq(seen.size(), 1, "and it is one scan, not none and not two")
	if not seen.is_empty():
		assert_eq(seen[0], {"type": "scan", "uid": uid}, "of the uid that was carried")
	# The slot the drag left is still a live click target: a fresh press spends the drag guard.
	tray.call("_on_slot_input", press, index)
	tray.call("_on_slot_pressed", index)
	assert_eq(seen.size(), 2, "the slot a drag started on still takes the next click")
	_dispose(night)

## The crate is a DEPOSIT, not a sale: the scanner refuses it and the Pfand row takes it, and the row
## is the hot zone, so a crate dropped on Ring up is a miss (docs/08 section 3.5).
func test_the_crate_belongs_to_the_pfand_row_and_not_to_the_glass() -> void:
	var night := _ring_night("register_counter")
	var seen: Array = []
	night.connect("acted", func(a: Dictionary) -> void: seen.append(a))
	var scanner := night.get_node_or_null("%Scanner") as Scanner
	var reg := night.get_node_or_null("%RegisterPanel") as RegisterPanel
	var crate := {"kind": "crate", "uid": 1, "count": 3}
	assert_false(scanner.accepts(crate), "the glass does not read a crate of empties")
	assert_true(reg.accepts(crate), "the Pfand row does")
	assert_false(reg.accepts({"kind": "item", "uid": 3}), "and it does not take a pack of cigarettes")
	var row := night.get_node_or_null("%RegisterPanel/PfandRow") as Control
	assert_true(reg.hot_zone().has_point(row.get_global_rect().get_center()), "the hot zone is the ROW")
	assert_false(reg.hot_zone().has_point((night.get_node("%RegisterPanel/RingUp") as Control).get_global_rect().get_center()),
			"and not the whole panel")
	reg.take(crate)
	assert_eq(seen.size(), 1, "the drop is one action")
	if not seen.is_empty():
		assert_eq(seen[0], {"type": "set_pfand", "bottles": 3}, "and it is the count the crate carried")
	_dispose(night)

## Turned around: every in-stock facing and the way back are on the frame and hittable, the OrderCard
## rides along in the corner, and the money is still on screen (docs/08 section 1).
func test_the_wall_offers_every_facing_and_the_way_back() -> void:
	var night := _ring_night("register_wall")
	var v: Dictionary = MockView.view("register_wall")
	var wall := night.get_node_or_null("%TobaccoWall") as TobaccoWall
	assert_true(wall != null and wall.visible, "turning around opens the wall")
	var wanted := _ring_up_actions(v)
	assert_true(wanted.size() >= 20, "a wall with 22 facings offers most of them")
	for action in wanted:
		var controls: Array = night.call("controls_for", action)
		assert_false(controls.is_empty(), "a live control offers " + JSON.stringify(action))
		if controls.is_empty():
			continue
		var c := controls[0] as Control
		assert_true(Rect2(Vector2.ZERO, Vector2(Palette.BASE)).encloses(c.get_global_rect()),
				"it is inside 480x270: " + JSON.stringify(action))
		var hit := night.call("control_at", c.get_global_rect().get_center()) as Control
		assert_true(hit == c or (hit != null and c.is_ancestor_of(hit)),
				"and nothing covers it: " + JSON.stringify(action))
	# Out of stock is visible, not hidden: the facing greys where it stands.
	var out_of_stock := wall.cell_for("cigarettes", "bergmann")
	assert_true(out_of_stock != null and out_of_stock.disabled, "an empty row stays on the wall, greyed")
	var card := night.get_node_or_null("%OrderCard") as OrderCard
	assert_true(card != null and card.visible, "the card rides along")
	assert_eq(Vector2i(card.position), Palette.ORDER_RECT_WALL.position, "docked in the wall's corner")
	assert_false(night.get_node_or_null("%CounterTray").visible, "and the counter is behind you")
	assert_false(night.get_node_or_null("%RegisterPanel").visible, "register column too")
	_dispose(night)

## The wrong pack: the line is flagged BEFORE you press Ring up, the reducer's own sentence is on
## screen, and the way to fix it is reachable. That is what makes one free correction fair rather
## than a gotcha (docs/08 section 1, section 3.4).
func test_the_wrong_pack_is_flagged_before_you_ring_up() -> void:
	var night := _ring_night("register_error")
	var v: Dictionary = MockView.view("register_error")
	var register: Dictionary = v["register"]
	var flagged := -1
	for i in (register["lines"] as Array).size():
		if not bool((register["lines"][i] as Dictionary)["matches"]):
			flagged = i
	assert_true(flagged >= 0, "the preset rings the navy pack against her red chip")
	var reg := night.get_node_or_null("%RegisterPanel") as RegisterPanel
	var row := (night.get_node_or_null("%RegisterPanel/Lines") as Control).get_child(flagged) as Control
	var name_label := row.get_node_or_null("Name") as Label
	assert_eq(name_label.get_theme_color("font_color"), Palette.WARN, "the flagged line wears the warning colour")
	var ok_label := ((night.get_node_or_null("%RegisterPanel/Lines") as Control).get_child(0) as Control).get_node_or_null("Name") as Label
	assert_eq(ok_label.get_theme_color("font_color"), Palette.TEXT, "and a matching line does not")
	var banner := night.get_node_or_null("%RegisterPanel/Banner") as Label
	assert_true(banner.visible, "the register flags itself beside the line it flagged")
	assert_eq(banner.text, Strings.CORRECTION, "with the short tell a 130-px column can hold")
	# ...and her actual words go over the counter, in the box, where there is room for a sentence.
	var box := night.get_node_or_null("%DialogueBox") as Control
	assert_true(box.visible, "she says it out loud")
	# The REDUCER chose the complaint; the STRING TABLE chose the words (docs/08 §3.4). Both halves
	# are asserted, so neither the bucket nor the sentence can drift without this failing.
	assert_eq(String(register["correction_kind"]), "wrong_brand", "the reducer named the bucket")
	assert_eq((box.get_node_or_null("%Body") as Label).text,
			String(Strings.CORRECTION_BY_KIND[String(register["correction_kind"])]),
			"and the box says it in the string table's words, not its own")
	# ...and the fix is one press away, on a control a pointer can reach.
	var seen: Array = []
	night.connect("acted", func(a: Dictionary) -> void: seen.append(a))
	var controls: Array = night.call("controls_for", {"type": "register_remove", "line": flagged})
	assert_false(controls.is_empty(), "the flagged line can be unrung")
	if controls.is_empty():
		_dispose(night)
		return
	var remove := controls[0] as StepChip
	assert_true(remove != null, "and it is a row chip, sized to the row")
	var hit: Control = night.call("control_at", remove.get_global_rect().get_center())
	assert_true(hit == remove, "and a click at its centre lands on it")
	remove.press()
	assert_eq(seen.size(), 1, "one press, one action")
	if not seen.is_empty():
		assert_eq(seen[0], {"type": "register_remove", "line": flagged}, "which unrings THAT line")
	# Her line covers the counter band while it is up (mode exclusivity), so it has to go away again —
	# otherwise the tray she is telling you to fix is unreachable for the rest of the customer.
	night.set("_capture_mode", false)
	night.call("_on_dialogue_finished")
	night.call("render", v)
	assert_false((night.get_node_or_null("%DialogueBox") as Control).visible, "a click puts her line away")
	var tray := night.get_node_or_null("%CounterTray") as CounterTray
	var slot: Button = tray.filled_slots()[2]
	var back: Control = night.call("control_at", slot.get_global_rect().get_center())
	assert_true(back == slot, "and the counter is yours again")
	# The restricted line is what Check ID is about, and the verb is live until it is used.
	assert_false((night.get_node_or_null("%RegisterPanel/CheckId") as Button).disabled, "Check ID is on offer")
	assert_true(reg.register.has("id_checked"), "and the panel reads the engine's answer, never its own")
	_dispose(night)

## The chip on the order card and the facing on the wall are the SAME pixels (docs/08 section 2), and
## the code-drawn fallback ships the mechanic before the art does: every brand in the catalogue draws
## a mark, and no two marks are the same shape.
func test_a_brand_mark_draws_the_shape_the_catalogue_names() -> void:
	var seen := {}
	for brand in Content.BRANDS:
		var row: Dictionary = brand
		var shape := BrandMark.shape_of(String(row["mark"]))
		assert_true(shape.size() > 0, String(row["id"]) + " draws something")
		assert_ne(shape, BrandMark.UNKNOWN, String(row["id"]) + "'s mark names a shape the pool can draw")
		seen[JSON.stringify(shape)] = int(seen.get(JSON.stringify(shape), 0)) + 1
		# Every block of every shape fits the 16x16 window the facing reserves at (4,6).
		for b in shape:
			var blocks: Array = b
			assert_true(int(blocks[0]) + int(blocks[2]) <= BrandMark.GRID, String(row["id"]) + " fits its grid")
			assert_true(int(blocks[1]) + int(blocks[3]) <= BrandMark.GRID, String(row["id"]) + " fits its grid")
	# Cigarettes and rolling tobacco are the matching game; one shape each, no repeats.
	var smoked := 0
	for brand in Content.BRANDS:
		if String((brand as Dictionary)["family"]) in ["cigarettes", "tobacco"]:
			smoked += 1
	assert_eq(smoked, 12, "twelve packs and pouches are the puzzle")
	var mark := (load("res://components/BrandMark.tscn") as PackedScene).instantiate() as BrandMark
	var adler: Dictionary = Content.brand("adler")
	mark.set_brand(adler, 16)
	assert_eq(Vector2i(mark.size), Vector2i(16, 16), "a chip is its asked-for size")
	assert_true(mark.get_child_count() >= 1, "and it draws something")
	if Assets.is_real(String(adler["icon"])):
		# The shipping path: the chip is LITERALLY the facing's own 16x16 window, cropped 1:1, so the
		# chip on the card and the pack on the wall can never be two different pictures.
		var crop := mark.get_child(0) as TextureRect
		assert_true(crop != null and crop.texture is AtlasTexture, "a real pack is cropped, not redrawn")
		if crop != null and crop.texture is AtlasTexture:
			assert_eq((crop.texture as AtlasTexture).region,
					Rect2(Rect2i(BrandMark.WINDOW_POS, Vector2i(BrandMark.WINDOW, BrandMark.WINDOW))),
					"out of the documented window at (4,6)")
	else:
		assert_true(mark.get_child_count() > 1, "and without art it is drawn from {mark, colour}")
	# The fallback is exercised whatever the art lane has shipped: this is what makes the puzzle
	# playable and testable on day one (docs/08 section 2, "Fallback").
	var drawn := (load("res://components/BrandMark.tscn") as PackedScene).instantiate() as BrandMark
	drawn.set_brand({"mark": String(adler["mark"]), "colour": String(adler["colour"]), "icon": ""}, 16)
	assert_true(drawn.get_child_count() > 1, "a brand with no art still draws its mark")
	_dispose(drawn)
	mark.set_facing(adler)
	assert_eq(Vector2i(mark.size), BrandMark.facing_size(adler), "a facing is the catalogue's footprint")
	assert_eq(Vector2i(mark.size), Assets.size_of(String(adler["icon"])), "which is the spec's footprint too")
	# A wall cell carries only the identity; the catalogue fills in the facing (`BrandMark.merge`).
	var cell := {"sku_id": "cigarettes", "brand": "adler", "name": "Adler",
		"mark": String(adler["mark"]), "colour": String(adler["colour"]), "stock": 4, "row": 0, "col": 0}
	var merged := BrandMark.merge(cell)
	assert_eq(String(merged["icon"]), String(adler["icon"]), "merge finds the facing the view did not carry")
	assert_eq(String(merged["name"]), "Adler", "and the VIEW wins wherever it said something")
	_dispose(mark)

## The card prints the swatch and the CATEGORY, never the brand name — unless the engine says the
## customer used it. That is the difference between reading a list and running a shop (docs/08 §2).
func test_the_order_card_keeps_the_brand_name_to_itself() -> void:
	var card := (load("res://components/OrderCard.tscn") as PackedScene).instantiate() as OrderCard
	card.call("_ready")
	var order: Array = MockView.view("register_counter")["order"]
	card.render(order, "Nadia")
	var chips := card.get_node_or_null("%Chips") as Control
	assert_eq(chips.get_child_count(), order.size(), "one chip per basket line")
	for i in order.size():
		var entry: Dictionary = order[i]
		var what := (chips.get_child(i) as Control).get_node_or_null("What") as Label
		assert_true(what != null, "a chip says what it is")
		if what == null:
			continue
		if bool(entry.get("name_shown", false)):
			assert_eq(what.text, String(entry["brand_name"]), "a named request prints the BRAND's name")
		else:
			var sku_name := String(entry["name"])
			var expected := sku_name if sku_name != "" else Strings.PFAND
			assert_eq(what.text, expected, "an unnamed one prints the SKU's own word, never the brand's")
			# The real leak test: ask the CATALOGUE what that brand is called and assert the chip does
			# not say it. `entry.brand_name` is "" here — the engine already withheld it — so checking
			# against the row alone would pass no matter what the card printed.
			var secret := String(Content.brand(String(entry["brand"])).get("name", ""))
			if secret != "":
				assert_false(what.text.contains(secret), "and never leaks the brand: " + secret)
		var tick := (chips.get_child(i) as Control).get_node_or_null("Tick") as ColorRect
		assert_eq(tick.visible, bool(entry["satisfied"]), "the tick is the reducer's, not the card's")
	assert_eq((card.get_node_or_null("%Who") as Label).text, "Nadia", "and it is in her name")
	_dispose(card)

## docs/08 §6: the register presets are checked KEY FOR KEY against a real `Rules.view(state)`. The
## mock is what every capture and half the component tests render, so a mock that drifts from the
## reducer means the screens are tuned against a shape the game never produces — which is exactly how
## the OrderCard came to print the SKU's name where the brand's name belonged (2026-09-13).
func test_the_mock_register_rows_carry_the_engines_own_keys() -> void:
	var real := _a_real_register_view()
	assert_false((real["order"] as Array).is_empty(), "the real read-model put a basket on the counter")
	assert_false((real["counter"] as Array).is_empty(), "…and items on the tray")
	var mock: Dictionary = MockView.view("register_counter")
	for section in ["order", "counter"]:
		var want: Dictionary = (real[section] as Array)[0]
		for row in (mock[section] as Array):
			for key in want:
				assert_true((row as Dictionary).has(key),
					"mock %s row carries the engine's `%s`" % [section, key])
	for key in (real["register"] as Dictionary):
		assert_true((mock["register"] as Dictionary).has(key), "mock register carries `%s`" % key)
	# …and the wall, which only exists while you are turned around.
	var turned := Rules.apply(_a_real_register_state(), {"type": "turn_around", "on": true})
	var real_cell: Dictionary = (((Rules.view(turned)["wall"] as Dictionary)["shelves"] as Array)[0] as Dictionary)["cells"][0]
	var mock_cell: Dictionary = ((MockView.view("register_wall")["wall"]["shelves"] as Array)[0] as Dictionary)["cells"][0]
	for key in real_cell:
		assert_true(mock_cell.has(key), "mock wall cell carries the engine's `%s`" % key)

## The reducer may not import `Strings`, so it mirrors the table — and a mirror that drifts is worse
## than no mirror. Same contract as `test_the_two_stat_tables_agree`.
func test_the_two_ask_tables_agree() -> void:
	assert_eq(Rules.ASK_CIGS, Strings.ASK_CIGS, "the cigarette line")
	assert_eq(Rules.ASK_POUCH, Strings.ASK_POUCH, "the pouch line")
	assert_eq(Rules.ASK_ITEM, Strings.ASK_ITEM, "everything else")
	assert_eq(Rules.ASK_PFAND, Strings.ASK_PFAND, "the deposit")
	assert_eq(Rules.ASK_MARK_PHRASE, Strings.ASK_MARK_PHRASE, "pointing at a mark")
	assert_eq(Rules.ASK_POINT, Strings.ASK_POINT, "pointing at an object")
	# The correction is the same sentence on both sides, so the box can take the words from the table
	# without the reducer and the screen ever disagreeing about what she said.
	for kind in Rules.CORRECTION_LINES:
		assert_eq(String(Strings.CORRECTION_BY_KIND.get(kind, "")), String(Rules.CORRECTION_LINES[kind]),
			"the correction table agrees on `%s`" % kind)

## The two verbs the NIGHT dispatches for the player rather than offering as a control: the clock
## ticks itself, and `night.gd` closes the books at 06:00. Everything else must be pressable.
const SCREENLESS := ["tick", "close_night"]

## docs/08 §6's standing reachability rule, on the REAL read-model instead of the mock. The mock
## version of this test can only check the shapes somebody typed into `MockView`; this one checks the
## shapes the REDUCER emits, in states the game actually reaches — at the counter and at the wall.
##
## This is the test that would have caught today's soft-lock, and it is the one that now holds the
## line after `serve_active` left the counter's offer (docs/08 §3.6) and both quantity steps joined
## it: an action the engine offers with nothing on screen to press IS the soft-lock, whichever
## direction the drift came from.
func test_every_legal_action_at_a_real_register_has_a_control() -> void:
	var counter := _a_real_register_state()
	var wall := Rules.apply(counter, {"type": "turn_around", "on": true})
	assert_eq(String(wall.get("view_mode", "")), "wall", "the guest let us turn around")
	for s in [counter, wall]:
		var night := _night_on(Rules.view(s))
		var checked := 0
		for entry in Rules.legal_actions(s):
			var action: Dictionary = entry
			if String(action["type"]) in SCREENLESS:
				continue
			checked += 1
			var controls: Array = night.call("controls_for", action)
			assert_false(controls.is_empty(), "a live control offers " + JSON.stringify(action))
			if controls.is_empty():
				continue
			var c := controls[0] as Control
			var r := c.get_global_rect()
			assert_true(Rect2(Vector2.ZERO, Vector2(Palette.BASE)).encloses(r),
				"it is inside 480x270: %s at %s" % [JSON.stringify(action), str(r)])
			var hit := night.call("control_at", r.get_center()) as Control
			assert_true(hit == c or (hit != null and c.is_ancestor_of(hit)),
				"and nothing covers it: %s hits %s" % [JSON.stringify(action), str(hit)])
		assert_true(checked >= 4, "the state offers a real set of actions, not one button")
		_dispose(night)

## Both chips on a register row are real: the reducer offers the step UP and the step DOWN, and each
## one routes to its own control. Advertising only one of them left a pressable "−" whose action the
## engine never admitted was legal, which is how `play.mjs` got stuck putting a quantity back.
func test_a_register_row_offers_both_of_its_steps() -> void:
	var s := _a_real_register_state()
	var uid := -1
	for entry in Rules.legal_actions(s):
		if String((entry as Dictionary)["type"]) == "scan":
			uid = int((entry as Dictionary)["uid"])
			break
	assert_true(uid >= 0, "there is something on the counter to scan")
	s = Rules.apply(s, {"type": "scan", "uid": uid})
	var qty := int(((Rules.view(s)["register"] as Dictionary)["lines"] as Array)[0]["qty"])
	var offered: Array = []
	for entry in Rules.legal_actions(s):
		var a: Dictionary = entry
		if String(a["type"]) == "register_set_qty" and int(a["line"]) == 0:
			offered.append(int(a["qty"]))
	assert_true(offered.has(qty + 1), "the + step is offered")
	assert_true(offered.has(qty - 1) or qty == 1, "and so is the - step, unless the row is at 1")
	var night := _night_on(Rules.view(s))
	var up: Array = night.call("controls_for", {"type": "register_set_qty", "line": 0, "qty": qty + 1})
	var down: Array = night.call("controls_for", {"type": "register_set_qty", "line": 0, "qty": maxi(1, qty - 1)})
	assert_false(up.is_empty(), "a control sends the row up")
	assert_false(down.is_empty(), "and a different one sends it down")
	# At a quantity of 1 there is nowhere to step down TO, so `control_for` sends both to the "+".
	if qty > 1 and not up.is_empty() and not down.is_empty():
		assert_ne(up[0], down[0], "and they are not the same chip")
	_dispose(night)

## Both steps the PFAND row takes, each to its own chip - the register line's rule, one row down.
## Offering "all of them at once" instead described a control the screen does not have: `control_for`
## routed that entry to the `+` chip, pressing `+` staged ONE bottle, and the ring came back
## `wrong_count` on a register the driver had every reason to believe was exact. `-` was meanwhile a
## live, enabled chip whose action the engine never admitted was legal - the mirror image, again.
## (Pointer probe, 2026-09-13. `set_pfand{all}` stays LEGAL: it is what the crate's drag dispatches.)
func test_the_pfand_row_offers_both_of_its_steps() -> void:
	var s := _a_real_register_state()
	(s["active"] as Dictionary)["bottles"] = 3
	s = Rules.apply(s, {"type": "set_pfand", "bottles": 1})
	assert_eq(int(((s["active"] as Dictionary)["register"] as Dictionary)["pfand_bottles"]), 1, "one empty staged")
	var offered: Array = []
	for entry in Rules.legal_actions(s):
		var a: Dictionary = entry
		if String(a["type"]) == "set_pfand":
			offered.append(int(a["bottles"]))
	assert_true(offered.has(2), "the + step is offered")
	assert_true(offered.has(0), "and so is the - step")
	assert_false(offered.has(3), "and never a jump no chip on the row can make in one press")
	var night := _night_on(Rules.view(s))
	var up: Array = night.call("controls_for", {"type": "set_pfand", "bottles": 2})
	var down: Array = night.call("controls_for", {"type": "set_pfand", "bottles": 0})
	assert_false(up.is_empty(), "a chip sends the row up")
	assert_false(down.is_empty(), "and a different one sends it down")
	if not up.is_empty() and not down.is_empty():
		assert_ne(up[0], down[0], "and they are not the same chip")
		var seen: Array = []
		night.connect("acted", func(a: Dictionary) -> void: seen.append(a))
		(up[0] as StepChip).press()
		assert_eq(seen, [{"type": "set_pfand", "bottles": 2}],
			"and pressing it produces the DICTIONARY the engine advertised, not a different one")
	_dispose(night)

## A Night rendered from a view — the real one, here, rather than a capture preset.
func _night_on(v: Dictionary) -> Node:
	var night := (load("res://scenes/Night.tscn") as PackedScene).instantiate()
	night.call("_ready")
	night.call("render", v)
	return night

## A real night, walked to the point where a guest is standing at the counter with her basket on it.
func _a_real_register_state() -> Dictionary:
	var s := SpatiState.new_game({"seed": 7})
	s["phase"] = "night"
	s["queue"] = [SpatiState.new_customer(1, String(Content.character("robin")["archetype_id"]), "mate", 90000, "robin")]
	s = Rules.apply(s, {"type": "talk_next"})
	var guard := 0
	while Talk.is_open(s) and guard < 40:
		guard += 1
		var advanced := false
		for a in Rules.legal_actions(s):
			if String(a["type"]) == "talk_advance":
				s = Rules.apply(s, a)
				advanced = true
				break
		if not advanced:
			s = Rules.apply(s, {"type": "talk_choose", "choice": 0})
	return s

func _a_real_register_view() -> Dictionary:
	return Rules.view(_a_real_register_state())

# ── helpers ───────────────────────────────────────────────────────────────────────────────────

## A Night wound up the way the game winds it up: `_ready` (the runner has no tree, so it is called by
## hand, exactly as the ManageBoard test does) and then a capture preset.
func _ring_night(preset: String) -> Node:
	var night := (load("res://scenes/Night.tscn") as PackedScene).instantiate()
	night.call("_ready")
	night.call("apply_capture_preset", preset)
	return night

## The actions docs/08 section 3.2 makes legal in THIS read-model. It stands in for
## `Rules.legal_actions` until the engine lane lands it, and every entry is DERIVED from the view —
## the whole point of the exercise is that nothing here is typed out by hand.
func _ring_up_actions(v: Dictionary) -> Array:
	var out: Array = []
	var register: Dictionary = v.get("register", {})
	if String(v.get("view_mode", "counter")) == "wall":
		var wall: Dictionary = v.get("wall", {})
		for shelf in wall.get("shelves", []):
			for cell in (shelf as Dictionary).get("cells", []):
				var c: Dictionary = cell
				if int(c.get("stock", 0)) > 0:
					out.append({"type": "take_from_wall", "sku": String(c["sku_id"]), "brand": String(c["brand"])})
		for held in wall.get("hand", []):
			out.append({"type": "put_back", "uid": int((held as Dictionary)["uid"])})
		out.append({"type": "turn_around", "on": false})
		return out
	for row in v.get("counter", []):
		var r: Dictionary = row
		if String(r.get("kind", "")) == "item" and not bool(r.get("scanned", false)):
			out.append({"type": "scan", "uid": int(r["uid"])})
	var lines: Array = register.get("lines", [])
	for i in lines.size():
		out.append({"type": "register_remove", "line": i})
		out.append({"type": "register_set_qty", "line": i, "qty": int((lines[i] as Dictionary).get("qty", 1)) + 1})
	if int(register.get("pfand_bottles", 0)) > 0:
		out.append({"type": "set_pfand", "bottles": int(register["pfand_bottles"]) - 1})
	if not bool(register.get("id_checked", false)):
		out.append({"type": "check_id"})
	out.append({"type": "turn_around", "on": true})
	# `talk_next` stays legal with a guest at the counter (docs/06 section 4) — the register mode
	# collapses the LINE, never the verb, and this is the entry that proves it.
	out.append({"type": "talk_next"})
	if bool(register.get("can_ring", false)):
		out.append({"type": "ring_up"})
	out.append({"type": "skip_active"})
	return out
