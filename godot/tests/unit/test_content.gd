extends "res://tests/TestCase.gd"
## Content integrity: the registries must be internally consistent or a night silently misbehaves —
## a want nobody stocks, a branch that points at a beat that was never written, a portrait-less face.

func test_registry_loads() -> void:
	assert_true(Content.SKUS.size() >= 18, "SKU catalogue ported (got %d)" % Content.SKUS.size())
	assert_eq(Content.SKU_BY_ID.size(), Content.SKUS.size(), "SKU ids unique")
	assert_eq(Content.ARCHETYPE_BY_ID.size(), Content.ARCHETYPES.size(), "archetype ids unique")
	assert_eq(Content.UPGRADE_BY_ID.size(), Content.UPGRADES.size(), "upgrade ids unique")
	assert_eq(Content.STRAND_BY_ID.size(), Content.STRANDS.size(), "strand ids unique")
	assert_eq(Content.VIGNETTE_BY_ID.size(), Content.VIGNETTES.size(), "vignette ids unique")
	assert_eq(Content.CHARACTER_BY_ID.size(), Content.CHARACTERS.size(), "character ids unique")
	assert_true(Content.VIGNETTES.size() >= 20, "the one-off pool is stocked (%d)" % Content.VIGNETTES.size())
	assert_true(Content.STRANDS.size() >= 13, "the cast is ported (%d strands)" % Content.STRANDS.size())

func test_every_want_and_unlock_names_a_real_sku() -> void:
	for arch in Content.ARCHETYPES:
		for sku_id in (arch["wants"] as Dictionary):
			assert_false(Content.sku(sku_id).is_empty(), "%s wants a real SKU: %s" % [arch["id"], sku_id])
	for ch in Content.CHARACTERS:
		for sku_id in (ch["wants"] as Dictionary):
			assert_false(Content.sku(sku_id).is_empty(), "%s wants a real SKU: %s" % [ch["id"], sku_id])
	for up in Content.UPGRADES:
		for sku_id in (up["effects"] as Dictionary).get("unlocks_sku", []):
			assert_false(Content.sku(sku_id).is_empty(), "%s unlocks a real SKU: %s" % [up["id"], sku_id])
	for sku in Content.SKUS:
		var gate: String = sku.get("unlocked_by", "")
		if gate != "":
			assert_false(Content.upgrade(gate).is_empty(), "%s is gated by a real upgrade" % sku["id"])

func test_every_upgrade_prerequisite_exists() -> void:
	for up in Content.UPGRADES:
		var requires: String = up.get("requires", "")
		if requires != "":
			assert_false(Content.upgrade(requires).is_empty(), "%s requires a real upgrade" % up["id"])

func test_every_strand_branch_lands_on_a_written_beat() -> void:
	for strand in Content.STRANDS:
		var beats: Dictionary = strand["beats"]
		assert_true(beats.has(strand["start"]), "%s starts on a written beat" % strand["id"])
		for beat_id in beats:
			var beat: Dictionary = beats[beat_id]
			assert_eq(beat["id"], beat_id, "%s: beat key matches its id" % strand["id"])
			assert_true((beat["lines"] as Array).size() >= 1, "%s/%s has lines" % [strand["id"], beat_id])
			assert_true((beat["choices"] as Array).size() >= 1, "%s/%s has a choice" % [strand["id"], beat_id])
			for choice in beat["choices"]:
				assert_true(str(choice["label"]).length() > 0, "%s/%s: choices are labelled" % [strand["id"], beat_id])
				var next: String = choice.get("next", "")
				if next != "":
					assert_true(beats.has(next), "%s/%s -> %s exists" % [strand["id"], beat_id, next])

func test_beat_ids_are_unique_registry_wide() -> void:
	# A customer at the counter carries only `beat_id`; Content.BEAT_STRAND has to resolve it uniquely.
	var total := 0
	for strand in Content.STRANDS:
		total += (strand["beats"] as Dictionary).size()
	assert_eq(Content.BEAT_STRAND.size(), total, "no two strands share a beat id")

func test_every_strand_outcome_has_an_epilogue_in_every_ending() -> void:
	var endings := ["institution", "held", "soldout", "pushedout"]
	for strand in Content.STRANDS:
		if strand["id"] == "main":
			continue
		var outcomes := {}
		for beat_id in (strand["beats"] as Dictionary):
			for choice in strand["beats"][beat_id]["choices"]:
				if choice.get("outcome", "") != "":
					outcomes[choice["outcome"]] = true
		assert_true(outcomes.size() >= 2, "%s branches to at least two outcomes" % strand["id"])
		for ending in endings:
			var table: Dictionary = (strand["epilogue"] as Dictionary).get(ending, {})
			for outcome in outcomes:
				assert_true(str(table.get(outcome, "")).length() > 0,
					"%s: epilogue[%s][%s] is written" % [strand["id"], ending, outcome])

func test_every_cast_arrival_can_be_staged() -> void:
	# Whoever a beat names must resolve to a real archetype (patience/budget) and some portrait.
	for strand in Content.STRANDS:
		var strand_arch: String = strand["archetype_id"]
		assert_false(Content.archetype(strand_arch).is_empty(), "%s has a real archetype" % strand["id"])
		for beat_id in (strand["beats"] as Dictionary):
			var beat: Dictionary = strand["beats"][beat_id]
			var character_id: String = beat.get("character_id", strand["character_id"])
			var archetype_id: String = beat.get("archetype_id", strand_arch)
			var portrait := Content.portrait_for(character_id, archetype_id)
			assert_true(portrait.begins_with("char/"), "%s/%s has a portrait (%s)" % [strand["id"], beat_id, portrait])

func test_every_character_has_a_portrait_and_expressions() -> void:
	for ch in Content.CHARACTERS:
		assert_true(str(ch["portrait"]).begins_with("char/"), "%s has a portrait id" % ch["id"])
		assert_true((ch["expressions"] as Array).has("neutral"), "%s has a neutral face" % ch["id"])
		assert_false(Content.archetype(ch["archetype_id"]).is_empty(), "%s has a real archetype" % ch["id"])
		assert_eq(Content.portrait_asset(ch["id"], "", "neutral"), ch["portrait"] + "_neutral", "%s neutral asset id" % ch["id"])
		# An expression this character never drew falls back to neutral, never to a missing file.
		assert_eq(Content.portrait_asset(ch["id"], "", "nonexistent"), ch["portrait"] + "_neutral", "%s falls back" % ch["id"])
	assert_eq(Content.portrait_for("nobody_at_all", "tourist"), "char/oneoff_tourist", "unknown faces borrow the archetype's")

func test_every_vignette_is_playable() -> void:
	for v in Content.VIGNETTES:
		assert_true((v["lines"] as Array).size() >= 1, "%s has lines" % v["id"])
		assert_true((v["choices"] as Array).size() >= 2, "%s offers a real choice" % v["id"])
		assert_true(str(v["speaker"]).length() > 0, "%s has a speaker" % v["id"])
