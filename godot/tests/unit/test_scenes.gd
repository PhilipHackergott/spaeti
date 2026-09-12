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
	"reputation", "hud", "active", "queue_len", "dialogue", "shelf", "summary", "manage", "ending",
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

func test_palette_is_the_only_place_with_values() -> void:
	assert_eq(Palette.money(1.8), "1,80 €", "money is German")
	assert_eq(Palette.money(-2.5), "-2,50 €", "negative money")
	assert_ne(Palette.speaker_colour("lena"), Palette.speaker_colour("juergen"), "speakers differ")
	assert_eq(Palette.COUNTER_TOP, 170, "the counter band is the bottom 100px")
	assert_true(Palette.theme() != null, "Theme.tres loads")

func _dispose(n: Node) -> void:
	if n == null:
		return
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	n.free()
