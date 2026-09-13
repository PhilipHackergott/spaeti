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

## Every flag a graph writes, across all three content tables. The WRITE side of `story.flags`.
func _flags_written() -> Dictionary:
	var out: Dictionary = {}
	for id in Content.DIALOGUES:
		for node_id in (Content.DIALOGUES[id]["nodes"] as Dictionary):
			for choice in (Content.DIALOGUES[id]["nodes"][node_id]["choices"] as Array):
				for key in ["effects", "effects_success", "effects_fail"]:
					for f in ((choice as Dictionary).get(key, {}) as Dictionary).get("flags", []):
						out[String(f)] = true
	for strand in Content.STRANDS:
		for beat_id in (strand["beats"] as Dictionary):
			for choice in ((strand["beats"][beat_id] as Dictionary).get("choices", []) as Array):
				for f in (choice as Dictionary).get("flags", []):
					out[String(f)] = true
	for v in Content.VIGNETTES:
		for choice in (v.get("choices", []) as Array):
			for f in (choice as Dictionary).get("flags", []):
				out[String(f)] = true
	return out

## Every `requires_flag` gate anywhere in the content, i.e. the other half of the READ side.
func _flags_gated() -> Dictionary:
	var out: Dictionary = {}
	for strand in Content.STRANDS:
		for beat_id in (strand["beats"] as Dictionary):
			var f := String((strand["beats"][beat_id] as Dictionary).get("requires_flag", ""))
			if f != "":
				out[f] = true
	for v in Content.VIGNETTES:
		var f := String(v.get("requires_flag", ""))
		if f != "":
			out[f] = true
	return out

## A flag nobody writes is an unreachable gate; a label for a flag nobody writes can never appear.
## Both are typos you cannot see at runtime — the branch simply never happens.
func test_every_flag_read_is_a_flag_some_choice_writes() -> void:
	var written := _flags_written()
	assert_true(written.size() >= 20, "the content writes a real set of flags (%d)" % written.size())
	for f in Economy.FLAG_LABEL:
		assert_true(written.has(String(f)), "FLAG_LABEL '%s' is a flag some choice actually sets" % f)
	for f in _flags_gated():
		assert_true(written.has(f), "requires_flag '%s' is reachable — some choice sets it" % f)

## The nine dialogue flags were write-only: the regulars' branches wrote them and nothing ever read
## them back. Each regular's tree must leave at least one mark the player can be shown.
func test_each_regulars_branches_leave_a_mark() -> void:
	var gated := _flags_gated()
	for id in ["lena", "juergen", "mehmet"]:
		var consumed := 0
		for node_id in (Content.DIALOGUES[id]["nodes"] as Dictionary):
			for choice in (Content.DIALOGUES[id]["nodes"][node_id]["choices"] as Array):
				for key in ["effects", "effects_success", "effects_fail"]:
					for f in ((choice as Dictionary).get(key, {}) as Dictionary).get("flags", []):
						if Economy.FLAG_LABEL.has(String(f)) or gated.has(String(f)):
							consumed += 1
		assert_true(consumed > 0, "%s's conversation leaves a mark somebody reads" % id)

## A choice has to be READABLE to be choosable. With a line waiting the box is `DIALOGUE_W_QUEUE` (300),
## which after the panel margins (8+8) and the row padding (6+6) leaves ~272 px of button — and a rolled
## choice gives up the tag's width beside it. The row wraps rather than clips now, but it may not wrap
## past the two lines the bottom-pinned box can afford, so this measures every authored label against
## the real font instead of trusting an eyeball. (26 of 139 rows exceed ONE line today; none exceed two.)
const CHOICE_LINES := 2

func test_no_authored_choice_outgrows_the_counter() -> void:
	var font := load("res://assets/fonts/Jersey10-Regular.ttf") as Font
	assert_true(font != null, "the body face loads")
	if font == null:
		return
	var inner := Palette.DIALOGUE_W_QUEUE - 16 - Palette.PAD * 2   # panel margins, then the row's own
	for row in _authored_choices():
		var choice: Dictionary = row["choice"]
		var text := Strings.CHOICE_NUMBER % [int(row["index"]) + 1, _plain(String(choice.get("label", "")))]
		var room := inner
		var check: Dictionary = choice.get("check", {})
		if not check.is_empty():
			# The tag rides on the same row: separation + its own padded box (Palette.box pad 4 + 4).
			var tag := Strings.check_tag(String(check.get("stat", "")), int(check.get("dc", 0)))
			room -= 4 + int(ceilf(font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.FONT_BODY).x)) + 8
		var w := int(ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.FONT_BODY).x))
		assert_true(w <= room * CHOICE_LINES,
			"%s wraps in %d lines or fewer (%d px in %d): %s" % [row["where"], CHOICE_LINES, w, room * CHOICE_LINES, text])

## Every choice a player can be shown, from all three content tables, with where it came from.
func _authored_choices() -> Array:
	var out: Array = []
	for id in Content.DIALOGUES:
		for node_id in (Content.DIALOGUES[id]["nodes"] as Dictionary):
			var choices: Array = Content.DIALOGUES[id]["nodes"][node_id]["choices"]
			for i in choices.size():
				out.append({"where": "%s/%s" % [id, node_id], "index": i, "choice": choices[i]})
	for strand in Content.STRANDS:
		for beat_id in (strand["beats"] as Dictionary):
			var beat_choices: Array = (strand["beats"][beat_id] as Dictionary).get("choices", [])
			for i in beat_choices.size():
				out.append({"where": "%s/%s" % [strand["id"], beat_id], "index": i, "choice": beat_choices[i]})
	for v in Content.VIGNETTES:
		var vc: Array = v.get("choices", [])
		for i in vc.size():
			out.append({"where": String(v["id"]), "index": i, "choice": vc[i]})
	return out

## The same strip the box does (`DialogueBox._plain_label`): an authored "[Schnauze 12] " prefix is
## rendered as the tag beside the row, never inside it.
func _plain(label: String) -> String:
	if label.begins_with("["):
		var close := label.find("]")
		if close > 0:
			return label.substr(close + 1).strip_edges()
	return label
