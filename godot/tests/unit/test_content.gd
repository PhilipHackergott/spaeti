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

# ───────────────────────── docs/09 §6 — the cast, as data ─────────────────────────
## Eleven persona cards, one frozen expression vocabulary, and DCs that make a check feel like a coin.
## Everything below is content integrity: nothing here can crash a night, and every one of them would
## ship silently — a card with no `stake`, a face the art lane was never asked to draw, a DC 18 check
## that reads as a tax. The cast is the slice's product; these are its acceptance criteria.

## The eleven guests: everyone with a persona card. `you`, `brandt` and the one-off silhouettes are in
## the registry for their portraits and are deliberately NOT guests (docs/09 §2.11).
const GUESTS := ["lena", "juergen", "mehmet", "schulz", "achim", "karim", "nadia", "tobias",
	"robin", "aylin", "bley"]
const SEASONS := ["summer", "autumn", "winter", "spring"]
## docs/09 §0: checks sit at DC 11-13 and the lowest LOCKING gate per stat is 11-15. Nothing below 11
## (a free choice dressed as a roll) and nothing above 15 (aspiration the player cannot read).
const DC_MIN := 11
const DC_MAX := 15

func test_all_eleven_guests_carry_a_complete_persona_card() -> void:
	for id in GUESTS:
		var ch := Content.character(id)
		assert_false(ch.is_empty(), "%s is in the cast registry" % id)
		if ch.is_empty():
			continue
		for key in ["age", "job", "strand_id", "story", "stake", "arc_link", "voice", "quirk",
				"signature_prop", "schedule", "basket", "order_line", "pays", "pfand", "arc"]:
			assert_true(ch.has(key), "%s's card declares %s" % [id, key])
		assert_true(int(ch.get("age", 0)) >= 18, "%s has an age (%d)" % [id, int(ch.get("age", 0))])
		assert_true(String(ch.get("job", "")).length() > 2, "%s has a job" % id)
		assert_true(String(ch.get("story", "")).length() > 80, "%s's story is a paragraph, not a label" % id)
		assert_true(String(ch.get("order_line", "")).length() > 8, "%s says a sentence when they order" % id)
		# The two MANDATORY clauses (docs/09 §2): a guest with no relationship to the Späti and no
		# relationship to the developer pressure is decoration. Neither may be written as a shrug.
		assert_true(String(ch.get("stake", "")).length() > 30, "%s has a stake in the Späti" % id)
		assert_true(String(ch.get("arc_link", "")).length() > 30, "%s is tied to the main arc" % id)
		assert_false(Content.strand(String(ch.get("strand_id", ""))).is_empty(),
			"%s's strand_id names a real strand (%s)" % [id, ch.get("strand_id", "")])
		assert_true((ch.get("basket", []) as Array).size() >= 3, "%s orders enough to ring up" % id)

func test_every_card_lays_out_trubys_seven_steps_across_the_year() -> void:
	# Summer 1-2 · Autumn 3-4 · Winter 5-6 · Spring 7 (docs/09 §2). The step titles are BEAT IDS a
	# later season ships — "The Night He Doesn't Come" is shippable, "Battle" is not — so a card with
	# four seasons is a season's worth of work already specified, not a promise to design one later.
	for id in GUESTS:
		var arc: Dictionary = Content.character(id).get("arc", {})
		var steps := 0
		for season in SEASONS:
			assert_true(arc.has(season), "%s's arc covers %s" % [id, season])
			for step in (arc.get(season, []) as Array):
				steps += 1
				assert_true(String(step).length() > 3, "%s/%s: step titles are beat ids" % [id, season])
		assert_eq(steps, 7, "%s lays out all seven steps (got %d)" % [id, steps])
		assert_eq((arc.get("spring", []) as Array).size(), 1, "%s: spring is step 7 alone" % id)

func test_every_cast_colour_is_its_own() -> void:
	# The QueueStrip's chips are code-drawn silhouettes in the speaker's `colour`, never shrunken
	# portraits — which is the whole reason two guests may not share a hue. Eleven distinct chips is
	# how a queue of named regulars reads as a queue of people.
	var seen: Dictionary = {}
	var re := RegEx.create_from_string("^#[0-9a-f]{6}$")
	for ch in Content.CHARACTERS:
		var colour := String(ch["colour"])
		assert_true(re.search(colour) != null, "%s's colour is a #rrggbb string (%s)" % [ch["id"], colour])
		assert_false(seen.has(colour), "%s's colour is its own (%s clashes with %s)"
			% [ch["id"], colour, seen.get(colour, "")])
		seen[colour] = String(ch["id"])

func test_the_expression_vocabulary_is_frozen_and_honest() -> void:
	# TWO failure modes, and the second is the quiet one. A tree naming a face outside the six is a
	# typo that falls back to neutral and looks like the character never reacted. A character LISTING
	# a face the art lane has not drawn is worse: a stamped placeholder standing next to a finished
	# bust reads as a broken character rather than as an unfinished expression (docs/09 §3).
	assert_eq(Content.EXPRESSIONS.size(), 6, "six ids, identical across the whole cast")
	for wanted in ["neutral", "warm", "wary", "upset", "surprised", "tired"]:
		assert_true(Content.EXPRESSIONS.has(wanted), "the vocabulary carries %s" % wanted)
	for ch in Content.CHARACTERS:
		for expression in (ch["expressions"] as Array):
			assert_true(Content.EXPRESSIONS.has(String(expression)),
				"%s lists %s, which is in the frozen six" % [ch["id"], expression])
			var asset := String(ch["portrait"]) + "_" + String(expression)
			assert_true(Assets.is_real(asset),
				"%s lists %s because %s is on disk" % [ch["id"], expression, asset])
	for id in Content.DIALOGUES:
		for node_id in (Content.DIALOGUES[id]["nodes"] as Dictionary):
			var expression := String((Content.DIALOGUES[id]["nodes"][node_id] as Dictionary).get("expression", "neutral"))
			assert_true(Content.EXPRESSIONS.has(expression),
				"%s/%s names a face from the frozen six (%s)" % [id, node_id, expression])

func test_every_new_tree_changes_the_face_it_is_speaking_with() -> void:
	# A tree whose every node is `neutral` is a tree with no performance in it: the bust is the only
	# thing on screen that can react, and `Portrait` follows the NODE, never the customer.
	for id in ["schulz", "achim", "karim", "nadia", "tobias", "robin", "aylin", "bley"]:
		var faces: Dictionary = {}
		for node_id in (Content.DIALOGUES[id]["nodes"] as Dictionary):
			faces[String((Content.DIALOGUES[id]["nodes"][node_id] as Dictionary)["expression"])] = true
		assert_true(faces.size() >= 3, "%s's tree wears at least three faces (got %s)" % [id, str(faces.keys())])

func test_every_roll_is_a_real_coin_and_every_gate_is_actually_locked() -> void:
	# docs/09 §0: a check below DC 11 is a free choice dressed as a roll, above 13 it is a tax; and a
	# gate whose `min` is already met on night one reads as a choice, not as aspiration. The defaults
	# are 10/11/12/13/12/14, so the lowest LOCKING min per stat is exactly one above its default.
	var defaults: Dictionary = SpatiState.new_game({"seed": 1})["player"]["stats"]
	var gates := 0
	for id in Content.DIALOGUES:
		for node_id in (Content.DIALOGUES[id]["nodes"] as Dictionary):
			for choice in (Content.DIALOGUES[id]["nodes"][node_id]["choices"] as Array):
				var where := "%s/%s" % [id, node_id]
				var check: Dictionary = (choice as Dictionary).get("check", {})
				if not check.is_empty():
					var stat := String(check["stat"])
					assert_true(Rules.STAT_IDS.has(stat), "%s rolls one of the six stats (%s)" % [where, stat])
					var dc := int(check["dc"])
					assert_true(dc >= DC_MIN and dc <= DC_MAX, "%s: DC %d is in %d..%d" % [where, dc, DC_MIN, DC_MAX])
					var chance := Talk.success_chance(dc, Rules.modifier(int(defaults[stat])))
					assert_true(chance >= 0.4 and chance <= 0.7,
						"%s: %d%% is a coin, not a tax" % [where, int(round(chance * 100.0))])
				var requires: Dictionary = (choice as Dictionary).get("requires", {})
				if not requires.is_empty():
					gates += 1
					var gate_stat := String(requires["stat"])
					assert_true(Rules.STAT_IDS.has(gate_stat), "%s gates on one of the six (%s)" % [where, gate_stat])
					var minimum := int(requires["min"])
					assert_true(minimum >= DC_MIN and minimum <= DC_MAX,
						"%s: a min of %d is in %d..%d" % [where, minimum, DC_MIN, DC_MAX])
					assert_true(minimum > int(defaults[gate_stat]),
						"%s: %s %d is LOCKED on night one (default %d)"
						% [where, Rules.stat_name(gate_stat), minimum, int(defaults[gate_stat])])
	assert_true(gates >= 11, "the cast really does gate things behind the stats (%d gates)" % gates)

func test_every_new_tree_locks_at_least_one_door() -> void:
	# docs/09 §4: 5-8 nodes · >= 1 d20 check · >= 1 gate that is locked at default stats. The gate is
	# what makes an upgrade mean something; a tree of pure rolls has nothing to aspire to.
	for id in ["schulz", "achim", "karim", "nadia", "tobias", "robin", "aylin", "bley"]:
		var checks := 0
		var gates := 0
		for node_id in (Content.DIALOGUES[id]["nodes"] as Dictionary):
			for choice in (Content.DIALOGUES[id]["nodes"][node_id]["choices"] as Array):
				if not (choice as Dictionary).get("check", {}).is_empty():
					checks += 1
				if not (choice as Dictionary).get("requires", {}).is_empty():
					gates += 1
		assert_true(checks >= 1, "%s rolls at least one d20 (got %d)" % [id, checks])
		assert_true(gates >= 1, "%s locks at least one door (got %d)" % [id, gates])

func test_the_order_is_woven_into_the_first_node() -> void:
	# docs/09 §4: the order is spoken in the FIRST node, so the basket landing on the counter is the
	# answer to something the guest actually said. The register reads `basket`; the player reads this.
	for id in GUESTS:
		var graph: Dictionary = Content.DIALOGUES.get(id, {})
		assert_false(graph.is_empty(), "%s has a tree" % id)
		if graph.is_empty():
			continue
		var start: Dictionary = graph["nodes"][String(graph["start"])]
		var opening := ""
		for line in (start["lines"] as Array):
			opening += String(line) + " "
		var names_something := false
		for entry in Content.basket_for(id):
			var sku_id := String((entry as Dictionary)["sku"])
			var sku_name := String(Content.sku(sku_id).get("name", ""))
			if opening.contains("{qty." + sku_id + "}") or opening.contains("{brand." + sku_id + "}") \
					or opening.contains("{logo." + sku_id + "}") or opening.to_lower().contains(sku_name.to_lower()):
				names_something = true
		assert_true(names_something, "%s's opening node says what they came in for" % id)

func test_every_guest_can_be_walked_out_of_the_shop() -> void:
	# The soft-lock rule, run rather than read: take each guest, walk the TOP LINE the way the headless
	# AutoPlayer does, and assert the reducer always has something legal to offer until the talk ends.
	# `test_every_graph_is_playable` proves the graph is well-formed; this proves it is escapable, which
	# is a different property and the one that shipped broken last time.
	for id in GUESTS:
		var s := SpatiState.new_game({"seed": 7})
		s["phase"] = "night"
		s["active"] = SpatiState.new_customer(1, String(Content.character(id)["archetype_id"]), "mate", 10000, id)
		s = Rules.apply(s, {"type": "talk_next"})
		assert_eq(String(s["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + id, "%s opens their own tree" % id)
		var steps := 0
		while Talk.is_open(s) and steps < 40:
			steps += 1
			var actions := Rules.legal_actions(s)
			assert_true(actions.size() > 0, "%s: the counter is never soft-locked (step %d)" % [id, steps])
			if actions.is_empty():
				break
			var before := SpatiState.to_json(s)
			var advanced := false
			for a in actions:
				if String(a["type"]) == "talk_advance":
					s = Rules.apply(s, a)
					advanced = true
					break
			if advanced:
				assert_ne(SpatiState.to_json(s), before, "%s: talk_advance moved the state" % id)
				continue
			s = Rules.apply(s, {"type": "talk_choose", "choice": 0})
			assert_ne(SpatiState.to_json(s), before, "%s: choice 0 moved the state" % id)
		assert_false(Talk.is_open(s), "%s's top line reaches the door in %d steps" % [id, steps])
		assert_true((s["active"] as Dictionary).is_empty(), "%s leaves the counter" % id)
