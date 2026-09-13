extends "res://tests/TestCase.gd"
## The brand catalogue's content invariants (docs/08 §2, §6). A brand is how the player tells one pack
## from another across a counter at 03:00, so the failures this guards are content failures, not code
## failures: two brands that only a colour tells apart, a colour pair no eye resolves, a variant that
## names a SKU nobody stocks. The two mark/colour tests catch OPPOSITE failure modes — ship both.

## docs/08 §2: "all twelve brand colours differ by ≥ 40 RGB Euclidean distance".
const MIN_COLOUR_DISTANCE := 40.0
## The two families whose identity IS the swatch game; papers and filters are told apart by silhouette.
const SWATCH_FAMILIES := ["cigarettes", "tobacco"]
const VARIANT_FAMILIES := ["papers", "filters"]
## docs/08 §2: every facing places its mark in a fixed 16×16 window at (4,6), and `BrandMark` crops
## exactly that. A facing too small to hold the window would crop into its own neighbours.
const MARK_WINDOW := Vector2i(16, 16)
const MARK_ORIGIN := Vector2i(4, 6)

func test_the_catalogue_is_stocked_and_its_ids_are_unique() -> void:
	assert_true(Content.BRANDS.size() >= 22, "the catalogue is ported (%d rows)" % Content.BRANDS.size())
	assert_eq(Content.BRAND_BY_ID.size(), Content.BRANDS.size(), "brand ids unique")
	for row in Content.BRANDS:
		var id: String = row["id"]
		assert_eq(Content.brand(id).get("id", ""), id, "%s round-trips through Content.brand" % id)

func test_every_brand_row_is_complete() -> void:
	# The read-model hands `mark`, `colour` and `icon` straight to BrandMark, and `spoken` straight
	# into a talk line; a missing key would surface as a blank pack or the word "null" in dialogue.
	for row in Content.BRANDS:
		var id: String = row["id"]
		for key in ["id", "sku", "family", "name", "spoken", "mark", "colour", "band", "size", "icon"]:
			assert_true(row.has(key), "%s declares %s" % [id, key])
		assert_true(String(row["name"]).length() > 0, "%s is named" % id)
		assert_true(String(row["spoken"]).length() > 0, "%s has a phrase a customer can say" % id)
		assert_false(String(row["spoken"]).contains("_"), "%s: `spoken` is a phrase, not an id" % id)
		assert_true(SWATCH_FAMILIES.has(row["family"]) or VARIANT_FAMILIES.has(row["family"]),
			"%s is in a known family (%s)" % [id, row["family"]])
		assert_true(String(row["icon"]).begins_with("tob/"), "%s's facing is a tob/ asset" % id)
		for hex in [row["colour"], row["band"]]:
			assert_true(_is_hex(String(hex)), "%s: %s is a #rrggbb string" % [id, hex])

func test_no_two_brands_are_separable_by_colour_alone() -> void:
	# The shape ALWAYS carries the answer: `speech:"colour"` exists, and a colour-blind player must be
	# able to win the matching game on silhouette. So marks are unique, which makes (mark, colour)
	# unique for free — the pair test is the weaker of the two and is asserted second, on purpose.
	var by_mark := {}
	var pairs := {}
	for row in Content.BRANDS:
		var mark: String = row["mark"]
		assert_true(mark.length() > 0, "%s has a mark" % row["id"])
		assert_false(by_mark.has(mark), "mark '%s' is unique (%s vs %s)" % [mark, row["id"], by_mark.get(mark, "")])
		by_mark[mark] = row["id"]
		var pair := "%s|%s" % [mark, row["colour"]]
		assert_false(pairs.has(pair), "(mark, colour) is unique for %s" % row["id"])
		pairs[pair] = row["id"]
	assert_eq(by_mark.size(), Content.BRANDS.size(), "every brand has its own shape")

func test_the_swatch_colours_are_far_enough_apart() -> void:
	# docs/08 §2: the twelve cigarette + rolling-tobacco colours, ≥ 40 apart in RGB. The catalogue's
	# real minimum is 45.11 (kranich/elbe); this fails the day somebody tunes one a shade closer.
	var swatch: Array = []
	for row in Content.BRANDS:
		if SWATCH_FAMILIES.has(row["family"]):
			swatch.append(row)
	assert_eq(swatch.size(), 12, "twelve swatch brands (%d)" % swatch.size())
	var worst := 1000.0
	var worst_pair := ""
	for i in swatch.size():
		for j in range(i + 1, swatch.size()):
			var d := _rgb_distance(String(swatch[i]["colour"]), String(swatch[j]["colour"]))
			if d < worst:
				worst = d
				worst_pair = "%s/%s" % [swatch[i]["id"], swatch[j]["id"]]
	assert_true(worst >= MIN_COLOUR_DISTANCE,
		"closest swatch pair %s is %.2f apart (min %.1f)" % [worst_pair, worst, MIN_COLOUR_DISTANCE])

func test_every_brand_names_a_real_sku() -> void:
	# A brand is a variant of an existing SKU (docs/08 §2) — it never invents stock or a price.
	for row in Content.BRANDS:
		var sku_id: String = row["sku"]
		assert_false(Content.sku(sku_id).is_empty(), "%s names a real SKU: %s" % [row["id"], sku_id])
		assert_eq(Content.sku(sku_id).get("category", ""), "tobacco",
			"%s's SKU %s is behind the tobacco wall" % [row["id"], sku_id])

func test_every_papers_and_filters_variant_maps_to_its_sku() -> void:
	# The variant lives in the id, not in a parallel `variant` field: a paper "brand" in a basket IS a
	# pap_* id and a filter "brand" IS a fil_* id, so one lookup answers "what is this facing".
	for row in Content.BRANDS:
		var id: String = row["id"]
		if id.begins_with("pap_"):
			assert_eq(row["sku"], "papers", "%s is a papers variant" % id)
			assert_eq(row["family"], "papers", "%s is in the papers family" % id)
		elif id.begins_with("fil_"):
			assert_eq(row["sku"], "filters", "%s is a filters variant" % id)
			assert_eq(row["family"], "filters", "%s is in the filters family" % id)
		else:
			assert_true(SWATCH_FAMILIES.has(row["family"]), "%s is a named brand, not a variant" % id)
	assert_eq(Content.brands_for("cigarettes").size(), 8, "eight cigarette brands")
	assert_eq(Content.brands_for("tobacco").size(), 4, "four rolling tobaccos")
	assert_eq(Content.brands_for("papers").size(), 6, "three kinds x two lengths of papers")
	assert_eq(Content.brands_for("filters").size(), 4, "two gauges x two kinds of filters")
	assert_eq(Content.brands_for("mate"), [], "a SKU with no brands has no facings")

func test_the_filters_sku_exists_and_is_priced_like_papers() -> void:
	# docs/08 §3.6: `filters` is a genuinely new SKU, so it reaches the ManageBoard with stock and a
	# price band like everything else — that is the whole reason it is a SKU and not a brand.
	var fil := Content.sku("filters")
	assert_false(fil.is_empty(), "the filters SKU is in the catalogue")
	assert_eq(fil["category"], "tobacco", "filters sit in the tobacco category")
	assert_almost(float(fil["cost"]), 0.35, 0.0001, "filters cost 0,35")
	assert_almost(float(fil["base_price"]), 1.0, 0.0001, "filters open at 1,00")
	assert_almost(float(fil["fair_lo"]), 0.8, 0.0001, "fair band floor")
	assert_almost(float(fil["fair_hi"]), 1.6, 0.0001, "fair band ceiling")
	assert_eq(fil["icon"], "sku/filters", "the ManageBoard's parent icon")
	var inventory: Dictionary = SpatiState.new_game()["inventory"]
	assert_true(inventory.has("filters"), "filters are stocked from night 1")
	assert_false(inventory.has("vape"), "and the gated SKUs still wait for their upgrade")

func test_every_facing_can_hold_the_mark_window() -> void:
	# BrandMark crops AtlasTexture(facing, Rect2i(4, 6, 16, 16)) 1:1. A facing smaller than that crops
	# into nothing, and the matching game stops being honest by construction.
	for row in Content.BRANDS:
		var size: Array = row["size"]
		assert_eq(size.size(), 2, "%s declares a [w, h]" % row["id"])
		assert_true(int(size[0]) >= MARK_ORIGIN.x + MARK_WINDOW.x,
			"%s is wide enough for the mark window (%d)" % [row["id"], int(size[0])])
		assert_true(int(size[1]) >= MARK_ORIGIN.y + MARK_WINDOW.y,
			"%s is tall enough for the mark window (%d)" % [row["id"], int(size[1])])

func test_the_accessors_answer_for_real_ids_and_shrug_at_the_rest() -> void:
	# `brand` is "" on every non-tobacco basket line, so "" must be a quiet miss, never a crash and
	# never the string "null" leaking into a spoken line.
	assert_eq(Content.brand_spoken("zunder"), "Zunder tobacco", "a pouch says its name")
	assert_eq(Content.brand_spoken("pap_feder_lang"), "long Feder papers", "a booklet says its length")
	assert_eq(Content.brand_spoken("fil_slim_kohle"), "slim charcoal filters", "a filter box says its gauge")
	assert_eq(Content.brand_logo("adler"), "tob/pack_adler", "the logo resolves to the facing asset")
	assert_eq(Content.brand(""), {}, "an unbranded line resolves to no row")
	assert_eq(Content.brand_spoken(""), "", "an unbranded line says nothing")
	assert_eq(Content.brand_logo(""), "", "an unbranded line shows no mark")
	assert_eq(Content.brand_spoken("nachtfalter"), "", "a retired placeholder id is a quiet miss")

func _is_hex(s: String) -> bool:
	if s.length() != 7 or not s.begins_with("#"):
		return false
	return s.substr(1).is_valid_hex_number(false)

func _rgb_distance(a: String, b: String) -> float:
	var ca := Color.html(a)
	var cb := Color.html(b)
	return Vector3(ca.r8 - cb.r8, ca.g8 - cb.g8, ca.b8 - cb.b8).length()
