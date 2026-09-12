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
]

const SCENE_PRESETS := {
	"res://scenes/Title.tscn": ["title"],
	"res://scenes/Night.tscn": ["empty_counter", "customer_at_counter", "dialogue_choice", "serving", "pfand", "late_night"],
	"res://scenes/Manage.tscn": ["manage"],
	"res://scenes/Summary.tscn": ["summary"],
	"res://scenes/Main.tscn": ["title", "customer_at_counter", "dialogue_choice", "serving", "pfand", "empty_counter", "late_night", "manage", "summary"],
}

## The keys `Rules.view(state)` must hand a scene (docs/05 section 5).
const VIEW_KEYS := [
	"phase", "day", "weekday_name", "clock_ms", "night_progress", "time_label", "cash", "pfand_held",
	"pfand_rate", "reputation", "hud", "active", "queue_len", "dialogue", "shelf", "summary", "manage", "ending",
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

func _dispose(n: Node) -> void:
	if n == null:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.free()
