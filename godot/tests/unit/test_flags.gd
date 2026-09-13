extends "res://tests/TestCase.gd"
## docs/09 §4.10 — the flag economy, from the WRITE side.
##
## `test_content.gd::test_every_flag_read_is_a_flag_some_choice_writes` guards the other direction: a
## gate that names a flag nobody sets is an unreachable branch. This file guards the direction that
## actually rots: a choice that SETS a flag nobody ever consumes. Nothing fails at runtime — the flag
## lands in `story.flags`, the save file grows, and the branch the writer had in mind never happens.
## "A flag nobody reads is a lie in the save file."
##
## A flag counts as read when any ONE of these consumes it:
##   1. a beat's or vignette's `requires_flag`  — a real gate (StoryFlow.eligible_beats);
##   2. an `Economy.FLAG_LABEL` entry           — the Manage screen's corner-status panel prints it;
##   3. a `Content.FLAG_READERS` declaration    — the reader is written and scheduled (the seasonal
##      trees and later arc beats of docs/09 §2) but has not shipped yet. The value names the beat.
## Kind 3 is a promise with a deadline, so this file also fails on a DEAD declaration: the day a real
## gate lands, its row here has to go, or the table drifts into fiction of its own.

const NAMESPACES := ["kiez_", "main_"]

## Every flag any choice writes, across all three content tables (dialogues, strands, vignettes).
func _flags_written() -> Dictionary:
	var out: Dictionary = {}
	for id in Content.DIALOGUES:
		for node_id in (Content.DIALOGUES[id]["nodes"] as Dictionary):
			for choice in (Content.DIALOGUES[id]["nodes"][node_id]["choices"] as Array):
				for key in ["effects", "effects_success", "effects_fail"]:
					for f in ((choice as Dictionary).get(key, {}) as Dictionary).get("flags", []):
						out[String(f)] = "%s/%s" % [id, node_id]
	for strand in Content.STRANDS:
		for beat_id in (strand["beats"] as Dictionary):
			for choice in ((strand["beats"][beat_id] as Dictionary).get("choices", []) as Array):
				for f in (choice as Dictionary).get("flags", []):
					out[String(f)] = "%s/%s" % [strand["id"], beat_id]
	for v in Content.VIGNETTES:
		for choice in (v.get("choices", []) as Array):
			for f in (choice as Dictionary).get("flags", []):
				out[String(f)] = String(v["id"])
	return out

## Reader kind 1: every `requires_flag` gate in the content, with where the gate sits.
func _flags_gated() -> Dictionary:
	var out: Dictionary = {}
	for strand in Content.STRANDS:
		for beat_id in (strand["beats"] as Dictionary):
			var f := String((strand["beats"][beat_id] as Dictionary).get("requires_flag", ""))
			if f != "":
				out[f] = "%s/%s" % [strand["id"], beat_id]
	for v in Content.VIGNETTES:
		var vf := String(v.get("requires_flag", ""))
		if vf != "":
			out[vf] = String(v["id"])
	return out

func test_every_flag_set_has_a_reader() -> void:
	var written := _flags_written()
	var gated := _flags_gated()
	assert_true(written.size() >= 60, "the cast writes a real set of flags (%d)" % written.size())
	for f in written:
		var flag := String(f)
		var read := gated.has(flag) or Economy.FLAG_LABEL.has(flag) or Content.FLAG_READERS.has(flag)
		assert_true(read, "%s (set at %s) is read by a gate, a FLAG_LABEL, or a declared reader"
			% [flag, written[flag]])

func test_no_declared_reader_is_dead() -> void:
	# Two ways a row here rots: the flag it names was renamed or deleted, or a REAL gate took over and
	# the declaration is now a second, stale answer to "who reads this?".
	var written := _flags_written()
	var gated := _flags_gated()
	for f in Content.FLAG_READERS:
		var flag := String(f)
		assert_true(written.has(flag), "FLAG_READERS declares a reader for '%s', which some choice sets" % flag)
		assert_false(gated.has(flag),
			"'%s' has a real gate at %s now — delete its FLAG_READERS row" % [flag, gated.get(flag, "")])
		assert_false(Economy.FLAG_LABEL.has(flag),
			"'%s' is printed by FLAG_LABEL now — delete its FLAG_READERS row" % flag)
		assert_true(Content.flag_reader(flag).length() > 8,
			"'%s' names the beat that will consume it, not a shrug" % flag)

func test_flag_names_obey_the_namespace() -> void:
	# `<character_id>_<event>` strand-local · `kiez_*` corner-wide · `main_*` the 22-step arc. Lower
	# snake throughout, because a flag is a dictionary key in the save file and case drift is silent.
	var ids: Dictionary = {}
	for ch in Content.CHARACTERS:
		ids[String(ch["id"])] = true
	for strand in Content.STRANDS:
		ids[String(strand["id"])] = true
	var re := RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	for f in _flags_written():
		var flag := String(f)
		assert_true(re.search(flag) != null, "'%s' is lower snake" % flag)
		var scoped := false
		for prefix in NAMESPACES:
			if flag.begins_with(prefix):
				scoped = true
		for id in ids:
			if flag.begins_with(String(id) + "_"):
				scoped = true
		if not scoped:
			# The prototype's short-form strand flags (j_welcome, m_trust, y_grace) predate the rule
			# and are grandfathered; anything NEW has to carry its owner's id.
			assert_true(flag in ["heard_offer", "refused_early", "sold", "stood", "took_fund",
				"flyers_up", "busker", "j_welcome", "m_trust", "y_grace"],
				"'%s' is namespaced to a character, a strand, kiez_ or main_" % flag)

func test_the_lever_is_reachable_without_any_single_guest() -> void:
	# docs/09 §4.10: `main_lever_hint` is set by three INDEPENDENT routes — Bley's clause, Tobias's
	# March date, Aylin's fence notice — and read once, at the main arc's step 17. That is what keeps
	# the lever a discovery instead of a required node: no one guest can lock the player out of it.
	var setters: Dictionary = {}
	for id in Content.DIALOGUES:
		for node_id in (Content.DIALOGUES[id]["nodes"] as Dictionary):
			for choice in (Content.DIALOGUES[id]["nodes"][node_id]["choices"] as Array):
				for key in ["effects", "effects_success", "effects_fail"]:
					for f in ((choice as Dictionary).get(key, {}) as Dictionary).get("flags", []):
						if String(f) == "main_lever_hint":
							setters[String(id)] = true
	for strand in Content.STRANDS:
		for beat_id in (strand["beats"] as Dictionary):
			for choice in ((strand["beats"][beat_id] as Dictionary).get("choices", []) as Array):
				for f in (choice as Dictionary).get("flags", []):
					if String(f) == "main_lever_hint":
						setters[String(strand["id"])] = true
	assert_true(setters.size() >= 3, "three independent routes set the lever hint (%s)" % str(setters.keys()))

func test_each_new_guest_leaves_a_countable_mark() -> void:
	# docs/09 §4.10 budgets 2-5 flags per guest PER SEASON. Each tree below is that guest's season-1
	# tree and covers BOTH summer arc steps, so the shipped spend is 3-7 — under two and the
	# conversation leaves no mark at all; run away above eight and no later season can read them back,
	# which is exactly how kind-3 declarations pile up into fiction.
	for id in ["schulz", "achim", "karim", "nadia", "tobias", "robin", "aylin", "bley"]:
		var spent: Dictionary = {}
		for node_id in (Content.DIALOGUES[id]["nodes"] as Dictionary):
			for choice in (Content.DIALOGUES[id]["nodes"][node_id]["choices"] as Array):
				for key in ["effects", "effects_success", "effects_fail"]:
					for f in ((choice as Dictionary).get(key, {}) as Dictionary).get("flags", []):
						if not String(f).begins_with("main_"):
							spent[String(f)] = true
		assert_true(spent.size() >= 2 and spent.size() <= 8,
			"%s's tree spends 2-8 strand flags (got %d: %s)" % [id, spent.size(), str(spent.keys())])
