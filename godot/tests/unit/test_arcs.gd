extends "res://tests/TestCase.gd"
## THE SEASON MACHINERY (docs/05 §11, docs/06 §8, docs/09 §2/§6) — the contract four content lanes
## write arcs against, so every rule they are told to rely on is asserted here rather than described.
##
##   1. the YEAR      `config.season_days` cut into four quarters, `view.season` / `view.day_in_season`;
##   2. the SELECTOR  `Content.dialogue_id_for(character_id, state)` → `<char>_<letter><step>`, else
##                    `<char>`, else `oneoff` — data-driven, never a list of who has what;
##   3. the LEDGER    `story.strands[id].step` (1..7) + `.season_seen`: one step per encounter, at most
##                    one a night per guest, and NEVER a skip — a missed season is caught up a step at
##                    a time, which is the rule the whole "arcs keyed to the year" idea rests on;
##   4. SCHEDULING    one story guest at a time, never the same face twice in a night, and never a step
##                    before its season;
##   5. the EXAMPLE   `lena_s2` walked end to end through the REAL read-model.

const GUESTS := ["lena", "juergen", "mehmet", "schulz", "achim", "karim", "nadia", "tobias",
	"robin", "aylin", "bley"]
const SEASONS := ["summer", "autumn", "winter", "spring"]
## The shipped season is 28 nights, which at one story guest a night is not enough calendar for eleven
## seven-step arcs (measured: the cast lands on step 2-4). The harness therefore drives a LONG year —
## the machinery is what is under test here, not the shipped pacing.
##
## Why 112 and not the 56 this started at: `Season.step_is_due` lets a strand take AT MOST TWO steps
## per season (summer opens 1-2, autumn 3-4, winter 5-6), so a seven-step arc needs two encounters in
## each of three seasons, and `MAX_STORY_ARRIVALS` is 1 — one strand-encounter a night, full stop.
## Fourteen strands wanting two nights of a season each need 28 nights in it, i.e. 112 in the year.
## At 56 the cast simply ran out of calendar and every long chain stalled one step short of the
## spring. The number is a property of (strands x steps / arrivals per night), not a magic constant:
## if the cap ever goes back to 2, half of this is recoverable. (See the PACING seam in docs/06 §8.4.)
const FULL_SEASON_DAYS := 112

func _fresh(days: int = 28, seed_value: int = 5) -> Dictionary:
	return SpatiState.new_game({"seed": seed_value, "season_days": days})

func _strand_of(character_id: String) -> String:
	return String(Content.character(character_id).get("strand_id", ""))

func _progress(s: Dictionary, character_id: String) -> Dictionary:
	return (s["story"]["strands"] as Dictionary)[_strand_of(character_id)]

## Put a guest on a given arc step, on a given day, and open their conversation. The queue (not a
## hand-placed `active`) so `_take_next` runs `_place_basket` and the tokens have a basket to speak.
func _at_the_counter(character_id: String, step: int, day: int, days: int = 28) -> Dictionary:
	var s := _fresh(days)
	s["day"] = day
	s["phase"] = "night"
	_progress(s, character_id)["step"] = step
	s["queue"] = [SpatiState.new_customer(1, String(Content.character(character_id)["archetype_id"]),
		"mate", 10000, character_id)]
	return Rules.apply(s, {"type": "talk_next"})

# ───────────────────────────── 1. the year ─────────────────────────────

func test_the_year_is_four_equal_quarters_of_season_days() -> void:
	# The shipped 28: summer 1-7 · autumn 8-14 · winter 15-21 · spring 22-28. Integer maths, so the
	# quarters are as even as `season_days` allows and a day PAST the end (the reducer's `end` phase
	# sits on `day == season_days + 1`, and `Rules.view` still renders it) clamps to spring.
	for row in [[1, "summer"], [7, "summer"], [8, "autumn"], [14, "autumn"],
			[15, "winter"], [21, "winter"], [22, "spring"], [28, "spring"], [29, "spring"], [400, "spring"]]:
		assert_eq(Season.of_day(int(row[0]), 28), String(row[1]), "day %d of 28 is %s" % [row[0], row[1]])
	assert_eq(Season.of_day(0, 28), "summer", "day 0 cannot exist, and answers summer rather than crashing")
	for row in [[1, 1], [7, 7], [8, 1], [14, 7], [15, 1], [22, 1], [28, 7]]:
		assert_eq(Season.day_in_season(int(row[0]), 28), int(row[1]),
			"day %d is day %d of its season" % [row[0], row[1]])
	# Every day of every plausible season length lands in a real season, and every season is non-empty
	# even when `season_days` does not divide by four — a season with no days in it is a dead arc.
	for days in [1, 2, 4, 7, 10, 13, 28, 29, 56, 84]:
		var seen: Dictionary = {}
		for day in range(1, days + 1):
			var season := Season.of_day(day, days)
			assert_true(SEASONS.has(season), "%d/%d is a real season (%s)" % [day, days, season])
			assert_true(Season.day_in_season(day, days) >= 1, "%d/%d is at least day 1 of it" % [day, days])
			seen[season] = true
		if days >= 4:
			assert_eq(seen.size(), 4, "a %d-day season has all four in it" % days)

func test_the_read_model_carries_the_season() -> void:
	var s := _fresh()
	for day in [1, 9, 16, 25]:
		s["day"] = day
		var v := Rules.view(s)
		assert_eq(String(v["season"]), Season.of_day(day, 28), "view.season on day %d" % day)
		assert_eq(int(v["day_in_season"]), Season.day_in_season(day, 28), "view.day_in_season on day %d" % day)
	# One calendar: the state helper, the Season model and the read-model may never disagree.
	s["day"] = 17
	assert_eq(SpatiState.season_of(s), Rules.view(s)["season"], "state and view read the same calendar")
	assert_eq(SpatiState.day_in_season(s), int(Rules.view(s)["day_in_season"]), "and the same day of it")

# ───────────────────────────── 2. the seven steps ─────────────────────────────

func test_trubys_seven_steps_are_keyed_to_the_year() -> void:
	# Summer 1-2 · autumn 3-4 · winter 5-6 · spring 7 (docs/09 §2) — and the persona cards' `arc`
	# dictionaries are laid out against the same table, so the two can never drift.
	for row in [[1, "summer"], [2, "summer"], [3, "autumn"], [4, "autumn"],
			[5, "winter"], [6, "winter"], [7, "spring"]]:
		assert_eq(Season.of_step(int(row[0])), String(row[1]), "step %d belongs to %s" % [row[0], row[1]])
	var steps := 0
	for season in SEASONS:
		steps += (Season.STEPS[season] as Array).size()
	assert_eq(steps, Season.LAST_STEP, "the four seasons own all seven steps and no more")
	for id in GUESTS:
		var arc: Dictionary = Content.character(id).get("arc", {})
		for season in SEASONS:
			assert_eq((arc[season] as Array).size(), (Season.STEPS[season] as Array).size(),
				"%s's card gives %s exactly the steps the calendar does" % [id, season])
		for step in range(Season.FIRST_STEP, Season.LAST_STEP + 1):
			assert_true(Content.arc_title_for_step(id, step).length() > 3,
				"%s's step %d has a beat id on the card" % [id, step])

func test_a_step_is_due_from_its_own_season_onward_and_never_before() -> void:
	# THE CATCH-UP RULE, as a predicate. A step opens in its own season and stays open for ever after,
	# so a season that passed unplayed is not skipped — it is caught up one step per encounter.
	assert_true(Season.step_is_due(1, "summer"), "step 1 plays in the summer")
	assert_true(Season.step_is_due(1, "spring"), "and STILL plays in the spring if it never did")
	assert_false(Season.step_is_due(3, "summer"), "step 3 may not play before the autumn")
	assert_false(Season.step_is_due(7, "winter"), "and step 7 may not play before the spring")
	for step in range(Season.FIRST_STEP, Season.LAST_STEP + 1):
		for season in SEASONS:
			assert_eq(Season.step_is_due(step, season),
				Season.index_of(season) >= Season.index_of(Season.of_step(step)),
				"step %d in %s" % [step, season])
	assert_false(Season.step_is_due(1, "hochsommer"), "a season that is not one answers no, not yes")

# ───────────────────────────── 3. the selector ─────────────────────────────

func test_the_tree_id_convention() -> void:
	# `<character>_<season letter><step>`, the letter taken from the STEP's season. Summer `s` · autumn
	# `a` · winter `w` · SPRING `p`, because summer already owns `s` and two ids may not collide.
	assert_eq(Content.arc_tree_id("lena", 2), "lena_s2", "summer step 2")
	assert_eq(Content.arc_tree_id("achim", 3), "achim_a3", "autumn step 3")
	assert_eq(Content.arc_tree_id("bley", 5), "bley_w5", "winter step 5")
	assert_eq(Content.arc_tree_id("karim", 7), "karim_p7", "spring step 7")
	var letters: Dictionary = {}
	for season in SEASONS:
		var letter := Season.letter_of(season)
		assert_eq(letter.length(), 1, "%s has a one-letter prefix (%s)" % [season, letter])
		assert_false(letters.has(letter), "%s's letter is its own (%s clashes with %s)"
			% [season, letter, letters.get(letter, "")])
		letters[letter] = season
	# Every id the convention can produce is unique across the whole cast and all seven steps.
	var ids: Dictionary = {}
	for id in GUESTS:
		for step in range(Season.FIRST_STEP, Season.LAST_STEP + 1):
			var tree := Content.arc_tree_id(id, step)
			assert_false(ids.has(tree), "%s is one guest's one step" % tree)
			ids[tree] = true
	assert_eq(ids.size(), GUESTS.size() * Season.LAST_STEP, "77 ids for eleven seven-step arcs")

func test_the_selector_prefers_the_step_tree_then_the_plain_one_then_the_parade() -> void:
	var s := _fresh()
	# Tier 2: step 1 and no `lena_s1` written, so she opens her plain tree — which IS her step 1.
	assert_eq(int(_progress(s, "lena")["step"]), 1, "a new game starts every arc on step 1")
	assert_eq(Content.dialogue_id_for("lena", s), "lena", "step 1 falls back to the plain tree")
	# Tier 1: the one tree the cast lane has written so far.
	_progress(s, "lena")["step"] = 2
	assert_eq(Content.dialogue_id_for("lena", s), "lena_s2", "step 2 opens the step-2 tree")
	# Tier 2 again: an UNWRITTEN step must NOT fall through to somebody else's tree or to the parade —
	# that guest still sounds like themselves. This used to be pinned to `lena` step 3, which the cast
	# lanes have since written; the rule is a property of the selector, not of who is behind on their
	# arc, so the example is found in the data instead of named here. When the last hole in the 77 is
	# filled there is no example left to find, and the assertion becomes the goal state itself.
	var hole_id := ""
	var hole_step := 0
	for id in GUESTS:
		for step in range(Season.FIRST_STEP, Season.LAST_STEP + 1):
			if hole_id == "" and step > Season.FIRST_STEP and not Content.DIALOGUES.has(Content.arc_tree_id(id, step)):
				hole_id = String(id)
				hole_step = step
	if hole_id != "":
		_progress(s, hole_id)["step"] = hole_step
		assert_eq(Content.dialogue_id_for(hole_id, s), hole_id,
			"%s's unwritten step %d keeps the plain tree" % [hole_id, hole_step])
		_progress(s, hole_id)["step"] = Season.FIRST_STEP
	else:
		for id in GUESTS:
			for step in range(Season.FIRST_STEP + 1, Season.LAST_STEP + 1):
				assert_true(Content.DIALOGUES.has(Content.arc_tree_id(id, step)),
					"no holes left: %s is written" % Content.arc_tree_id(id, step))
	# Tier 3: a face with no tree at all.
	assert_eq(Content.dialogue_id_for("nobody_at_all", s), Content.DIALOGUE_FALLBACK, "strangers get the parade")
	assert_eq(Content.dialogue_id_for("", s), Content.DIALOGUE_FALLBACK, "and so does an empty id")
	assert_eq(Content.dialogue_id_for("brandt", s), Content.DIALOGUE_FALLBACK,
		"Frau Brandt is a main-arc beat, not a guest with a tree")
	# No state at all (a content test, a tool): tiers 2 and 3 still answer.
	assert_eq(Content.dialogue_id_for("lena"), "lena", "a stateless call still resolves the plain tree")
	assert_eq(Content.dialogue_id_for("nobody_at_all"), Content.DIALOGUE_FALLBACK, "and the fallback")
	# DATA-DRIVEN, not a list: every guest on every step resolves to a tree that EXISTS, whether or not
	# the cast lane has written that step yet. The day `karim_a3` lands it is live with no engine edit.
	for id in GUESTS:
		for step in range(Season.FIRST_STEP, Season.LAST_STEP + 1):
			_progress(s, id)["step"] = step
			var chosen := Content.dialogue_id_for(id, s)
			assert_true(Content.DIALOGUES.has(chosen), "%s step %d resolves to a written tree (%s)" % [id, step, chosen])
			var written := Content.arc_tree_id(id, step)
			assert_eq(chosen, written if Content.DIALOGUES.has(written) else id,
				"%s step %d takes tier 1 when it exists and tier 2 when it does not" % [id, step])

func test_the_reducer_opens_the_tree_the_selector_names() -> void:
	# The selector is only worth anything if `talk_next` actually uses it. Same guest, same night, one
	# field of state apart.
	var plain := _at_the_counter("lena", 1, 3)
	assert_eq(String(plain["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + "lena", "step 1 opens `lena`")
	var stepped := _at_the_counter("lena", 2, 3)
	assert_eq(String(stepped["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + "lena_s2", "step 2 opens `lena_s2`")
	assert_ne(String(Talk.view(plain)["lines"][0]), String(Talk.view(stepped)["lines"][0]),
		"and the two say different things")

# ───────────────────────────── 4. the arc ledger ─────────────────────────────

func test_a_new_game_starts_every_arc_on_step_one_with_nothing_seen() -> void:
	var s := _fresh()
	for strand in Content.STRANDS:
		var p: Dictionary = s["story"]["strands"][strand["id"]]
		assert_eq(int(p["step"]), Season.FIRST_STEP, "%s starts on step 1" % strand["id"])
		assert_eq(String(p["season_seen"]), "", "%s has not been seen in any season yet" % strand["id"])

func test_a_resolved_beat_advances_the_arc_one_step() -> void:
	var s := _fresh()
	s["day"] = 4
	s["story"]["pending"] = {"strand": "lena", "beat": "l_meet"}
	s["story"]["strands"]["lena"]["cur"] = "l_meet"
	s["active"] = SpatiState.new_customer(1, "student", "mate", 10000, "lena", "l_meet")
	s = Rules.apply(s, {"type": "resolve_beat", "choice": 0})
	var p: Dictionary = s["story"]["strands"]["lena"]
	assert_eq(int(p["step"]), 2, "the beat resolved, so the arc is on step 2")
	assert_eq(String(p["season_seen"]), "summer", "and it happened in the summer")
	assert_eq(int(p["last_day"]), 4, "stamped with the night it happened on")

func test_a_closed_tree_advances_the_arc_too() -> void:
	# An encounter is an encounter: the eight new trees ARE their guest's step 1, so walking one out is
	# a step even on a night no strand beat was scheduled.
	var s := _at_the_counter("achim", 1, 9)
	assert_eq(int(_progress(s, "achim")["step"]), 1, "still on step 1 while he is talking")
	s = AutoPlayer.play_talk(s)
	assert_false(Talk.is_open(s), "the tree closed")
	var p: Dictionary = _progress(s, "achim")
	assert_eq(int(p["step"]), 2, "and the arc moved on one step")
	assert_eq(String(p["season_seen"]), "autumn", "day 9 of 28 is the autumn")

func test_an_arc_moves_at_most_one_step_a_night() -> void:
	# Both halves of the guard: a second beat on the same night, and a tree closed after a beat already
	# advanced them. Two conversations in one night is one step, or the arcs run at double speed on any
	# night the scheduler hiccups.
	var s := _fresh()
	s["day"] = 6
	assert_true(StoryFlow.advance_step(s, "lena"), "the first encounter of the night counts")
	assert_eq(int(s["story"]["strands"]["lena"]["step"]), 2, "step 2")
	assert_false(StoryFlow.advance_step(s, "lena"), "the second does not")
	assert_eq(int(s["story"]["strands"]["lena"]["step"]), 2, "still step 2")
	s["day"] = 7
	assert_true(StoryFlow.advance_step(s, "lena"), "tomorrow it counts again")
	assert_eq(int(s["story"]["strands"]["lena"]["step"]), 3, "step 3")
	# And through the real path: a beat, then her own tree, on one night.
	var night := _fresh()
	night["day"] = 4
	night["phase"] = "night"
	night["story"]["strands"]["lena"]["cur"] = "l_meet"
	night["queue"] = [SpatiState.new_customer(1, "student", "mate", 10000, "lena", "l_meet")]
	night = Rules.apply(night, {"type": "talk_next"})     # the beat, opened as a one-node talk
	night = AutoPlayer.play_talk(night)
	assert_eq(int(_progress(night, "lena")["step"]), 2, "the beat moved her to step 2")
	night = Rules.apply(night, {"type": "talk_next"})     # and now her tree, same night
	assert_true(Talk.is_open(night), "her own tree opens after the beat")
	night = AutoPlayer.play_talk(night)
	assert_eq(int(_progress(night, "lena")["step"]), 2, "which does not move her again tonight")

func test_an_arc_never_skips_a_step_even_when_a_season_passes_unplayed() -> void:
	# THE CATCH-UP RULE, run rather than read. Nobody talks to Achim all summer and all autumn; the
	# first time he walks in is deep in the winter, and he plays step 1 — not step 5.
	var s := _at_the_counter("achim", 1, 20)
	assert_eq(Season.of_state(s), "winter", "day 20 of 28 is the winter")
	assert_eq(String(s["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + "achim",
		"he opens his step-1 tree, in the winter, because that is the step he is on")
	s = AutoPlayer.play_talk(s)
	var p: Dictionary = _progress(s, "achim")
	assert_eq(int(p["step"]), 2, "one step per encounter — not a jump to the step the date implies")
	assert_eq(String(p["season_seen"]), "winter", "`season_seen` records WHEN, not which season owns the step")
	assert_eq(Season.of_step(int(p["step"])), "summer", "and step 2 is still a summer step")
	# The schedule agrees: his next beat is due, because a step that is late is still due.
	s["day"] = 21
	s["story"]["strands"]["achim"]["cur"] = "a_meet"
	var due := false
	for entry in StoryFlow.eligible_beats(s):
		if String((entry["strand"] as Dictionary)["id"]) == "achim":
			due = true
	assert_true(due, "a late arc keeps walking in until it has caught up")

func test_the_ledger_saturates_at_step_seven() -> void:
	var s := _fresh()
	s["story"]["strands"]["lena"]["step"] = Season.LAST_STEP
	s["day"] = 27
	assert_true(StoryFlow.advance_step(s, "lena"), "the last step still resolves")
	assert_eq(int(s["story"]["strands"]["lena"]["step"]), Season.LAST_STEP,
		"and the arc stays on 7 — the spring tree is her voice from then on")

func test_a_face_with_no_card_moves_nothing() -> void:
	var s := _fresh()
	s["day"] = 5
	assert_false(StoryFlow.advance_step_for(s, ""), "the nameless parade has no arc")
	assert_false(StoryFlow.advance_step_for(s, "nobody_at_all"), "nor does a stranger")
	assert_false(StoryFlow.advance_step(s, "no_such_strand"), "nor does a strand that is not there")

func test_the_ledger_survives_the_save_seam() -> void:
	var s := _fresh()
	s["day"] = 16
	StoryFlow.advance_step(s, "bley")
	StoryFlow.advance_step(s, "bley")  # same night: no move, but `last_day` is stamped
	s["day"] = 17
	StoryFlow.advance_step(s, "bley")
	var text := SpatiState.to_json(s)
	var back := SpatiState.from_json(text)
	assert_eq(SpatiState.to_json(back), text, "the arc ledger round-trips byte-for-byte")
	var p: Dictionary = back["story"]["strands"]["bley"]
	assert_eq(typeof(p["step"]), TYPE_INT, "step comes back an int, not 3.0")
	assert_eq(int(p["step"]), 3, "and on the step it went in on")
	assert_eq(String(p["season_seen"]), "winter", "with the season it was last seen in")
	# A save written before the seasons landed has neither key, and must load as "everyone on step 1".
	var old := JSON.parse_string(text) as Dictionary
	for strand_id in (old["story"]["strands"] as Dictionary):
		(old["story"]["strands"][strand_id] as Dictionary).erase("step")
		(old["story"]["strands"][strand_id] as Dictionary).erase("season_seen")
	var loaded := SpatiState.from_json(JSON.stringify(old))
	assert_false(loaded.is_empty(), "a pre-season save still loads")
	assert_eq(int(loaded["story"]["strands"]["bley"]["step"]), Season.FIRST_STEP, "on step 1")
	assert_eq(String(loaded["story"]["strands"]["bley"]["season_seen"]), "", "having been seen nowhere")

# ───────────────────────────── 5. scheduling ─────────────────────────────

func test_no_step_is_scheduled_before_its_season() -> void:
	var s := _fresh()
	s["day"] = 3                                   # summer
	s["story"]["strands"]["bley"]["step"] = 5      # a winter step
	for entry in StoryFlow.eligible_beats(s):
		assert_ne(String((entry["strand"] as Dictionary)["id"]), "bley", "a winter step is not due in the summer")
	s["day"] = 16                                  # winter
	var due := false
	for entry in StoryFlow.eligible_beats(s):
		if String((entry["strand"] as Dictionary)["id"]) == "bley":
			due = true
	assert_true(due, "and it is due the moment the winter arrives")

func test_the_rotation_reaches_the_bottom_of_the_table() -> void:
	# The cap is one guest a night, so the ORDER of `eligible_beats` is the pacing. Sorting on
	# `priority` alone starved the lowest-priority strand completely — Herr Bley (priority 4) never
	# walked in once over a whole season. Whoever has been unseen longest goes first.
	var s := _fresh()
	s["day"] = 12
	for strand in Content.STRANDS:
		(s["story"]["strands"][strand["id"]] as Dictionary)["last_day"] = 11
	s["story"]["strands"]["bley"]["last_day"] = 2      # unseen for nine nights
	s["story"]["strands"]["main"]["cur"] = ""          # the main arc is not in the running tonight
	var first := StoryFlow.eligible_beats(s)
	assert_false(first.is_empty(), "somebody is due")
	assert_eq(String((first[0]["strand"] as Dictionary)["id"]), "bley",
		"the guest nobody has seen for nine nights goes first, whatever their priority")
	# The main arc still outranks the whole cast: its beats are pinned to day milestones.
	s["story"]["strands"]["main"]["cur"] = "squeeze"
	s["story"]["strands"]["main"]["last_day"] = 11
	s["day"] = 14
	assert_eq(String((StoryFlow.eligible_beats(s)[0]["strand"] as Dictionary)["id"]), "main",
		"but the main arc is still first in the queue")

func test_one_story_guest_at_a_time_and_never_the_same_face_twice() -> void:
	# Day 14 with the main arc on `squeeze` — a beat SPOKEN BY MEHMET — and Mehmet's own strand due as
	# well. Two eligible beats, one face: the queue may not hold two Mehmets.
	var s := _fresh()
	s["day"] = 14
	s["reputation"]["kiez"] = 70.0
	s["story"]["strands"]["main"]["cur"] = "squeeze"
	var named: Dictionary = {}
	for entry in StoryFlow.eligible_beats(s):
		var beat: Dictionary = entry["beat"]
		var strand: Dictionary = entry["strand"]
		named[String(beat.get("character_id", strand.get("character_id", "")))] = true
	assert_true(named.has("mehmet"), "two eligible beats really do name Mehmet tonight")
	s = Rules.apply(s, {"type": "open_night"})
	_assert_schedule_is_sane(s, "day 14")

## The two scheduling invariants, asserted on the arrivals the reducer actually built.
func _assert_schedule_is_sane(s: Dictionary, where: String) -> void:
	var story_arrivals := 0
	var faces: Dictionary = {}
	for a in s["arrivals"]:
		var character_id := String((a as Dictionary).get("character_id", ""))
		if String((a as Dictionary).get("beat_id", "")) != "":
			story_arrivals += 1
		if character_id == "":
			continue
		assert_false(faces.has(character_id),
			"%s: %s is in the queue once, not twice" % [where, character_id])
		faces[character_id] = true
	assert_true(story_arrivals <= StoryFlow.MAX_STORY_ARRIVALS,
		"%s: %d story arrivals, cap is %d" % [where, story_arrivals, StoryFlow.MAX_STORY_ARRIVALS])

# ───────────────────────────── 6. the worked example ─────────────────────────────

func test_lenas_step_two_is_a_template_a_content_lane_can_copy() -> void:
	var tree: Dictionary = Content.DIALOGUES["lena_s2"]
	var nodes: Dictionary = tree["nodes"]
	assert_eq(nodes.size(), 5, "five nodes (docs/09 §4: 5-8)")
	var checks := 0
	var gates := 0
	var faces: Dictionary = {}
	var flags: Dictionary = {}
	var defaults: Dictionary = _fresh()["player"]["stats"]
	for node_id in nodes:
		var node: Dictionary = nodes[node_id]
		assert_eq(String(node["speaker"]), "lena", "%s is spoken by Lena, so her basket answers for it" % node_id)
		faces[String(node["expression"])] = true
		for choice in (node["choices"] as Array):
			var c: Dictionary = choice
			if not (c.get("check", {}) as Dictionary).is_empty():
				checks += 1
			var requires: Dictionary = c.get("requires", {})
			if not requires.is_empty():
				gates += 1
				assert_true(int(requires["min"]) > int(defaults[String(requires["stat"])]),
					"%s's gate is LOCKED at day-one stats" % node_id)
			for key in ["effects", "effects_success", "effects_fail"]:
				for f in ((c.get(key, {}) as Dictionary).get("flags", []) as Array):
					flags[String(f)] = true
	assert_eq(checks, 1, "one d20 coin")
	assert_eq(gates, 1, "one gate")
	assert_true(faces.size() >= 3, "and a face change per beat (got %s)" % str(faces.keys()))
	assert_true(flags.size() >= 3, "flags a later step reads (got %d)" % flags.size())
	for f in flags:
		assert_true(Content.flag_reader(String(f)).length() > 8,
			"%s names the step that will read it" % f)
	# The order is woven into the first node, exactly as a step-1 tree's is.
	var opening := ""
	for line in (nodes[String(tree["start"])]["lines"] as Array):
		opening += String(line)
	assert_true(opening.contains("{brand.tobacco}"), "she says what she came in for")

func test_lenas_step_two_plays_end_to_end_through_the_read_model() -> void:
	# Never trust a name, assert against the read-model: `_place_basket` truncates her five-row basket
	# to the reducer's four-line cap, and a token whose row was dropped does not fail — it PRINTS.
	var s := _at_the_counter("lena", 2, 5)
	assert_eq(String(s["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + "lena_s2", "her step-2 tree opened")
	var any := RegEx.create_from_string("\\{([^}]*)\\}")
	var steps := 0
	while Talk.is_open(s) and steps < 40:
		steps += 1
		var talk: Dictionary = Rules.view(s)["talk"]
		var shown: Array = (talk["lines"] as Array).duplicate()
		for choice in (talk["choices"] as Array):
			shown.append(String((choice as Dictionary)["label"]))
		for text in shown:
			for m in any.search_all(String(text)):
				fail("lena_s2/%s: %s reached the box unsubstituted — %s"
					% [String(s["talk"]["node"]), m.get_string(0), String(text)])
		var advanced := Rules.apply(s, {"type": "talk_advance"})
		s = advanced if not is_same(advanced, s) else Rules.apply(s, {"type": "talk_choose", "choice": 0})
	assert_false(Talk.is_open(s), "the tree closed in %d steps" % steps)
	assert_true((s["story"]["flags"] as Array).has("lena_honest_piece"), "the top line leaves its mark")
	var p: Dictionary = _progress(s, "lena")
	assert_eq(int(p["step"]), 3, "and step 2 played, so she is on step 3 — The Gallerist, in the autumn")
	assert_eq(Season.of_step(int(p["step"])), "autumn", "which is where the card said it would be")

# ───────────────────────────── 7. a whole year, headless ─────────────────────────────

## A season driven for the STORY rather than the till: every guest is talked out, everyone else is
## waved through, and the night log is dropped after each close (it is append-only and every `apply`
## deep-copies the state, so keeping a whole season of it makes this run ten times slower and proves
## nothing about arcs). The register has its own end-to-end runs in test_determinism/test_register.
func _play_story_season(s0: Dictionary, days: int) -> Dictionary:
	var s := s0
	var talked: Dictionary = {}
	var steps_at_dawn: Dictionary = {}
	for i in days:
		if s["phase"] != "manage":
			break
		s = Rules.apply(s, {"type": "open_night"})
		var where := "night %d (%s)" % [int(s["day"]), Season.of_state(s)]
		_assert_schedule_is_sane(s, where)
		# Who the player actually MET tonight, recorded as they reach the counter rather than inferred
		# from the arrivals: `_assert_schedule_is_sane` proves the queue was built right, this proves the
		# night was PLAYED right. Ordinary arrivals carry `character_id: ""` (rules.gd `_build_arrivals`),
		# so every name in here came through `schedule_beats` and the cap is the one it enforces.
		var faces_tonight: Dictionary = {}
		for strand in Content.STRANDS:
			steps_at_dawn[strand["id"]] = int((s["story"]["strands"][strand["id"]] as Dictionary)["step"])
		var guard := 0
		while s["phase"] == "night" and guard < 6000:
			guard += 1
			if Talk.is_open(s):
				s = AutoPlayer.play_talk(s)
				continue
			if not (s["story"]["pending"] as Dictionary).is_empty() or s["story"]["pending_vignette"] != "":
				s = AutoPlayer.resolve_dialogue(s)
				continue
			var active: Dictionary = s["active"]
			if not active.is_empty():
				if String(active.get("character_id", "")) != "":
					faces_tonight[String(active["character_id"])] = true
				var cid := int(active["id"])
				if String(active.get("character_id", "")) != "" and int(talked.get(cid, 0)) < 2:
					talked[cid] = int(talked.get(cid, 0)) + 1
					var opened := Rules.apply(s, {"type": "talk_next"})
					if not is_same(opened, s):
						s = opened
						continue
				var want := String(active["want"])
				var in_stock := int(((s["inventory"] as Dictionary).get(want, {}) as Dictionary).get("stock", 0)) > 0
				var illegal := bool(Content.archetype(String(active["archetype_id"])).get("underage", false)) \
					and bool(Content.sku(want).get("restricted", false))
				if in_stock and not illegal:
					s = Rules.apply(s, {"type": "serve_active", "give": [want], "pfand_bottles": 0})
				else:
					s = Rules.apply(s, {"type": "skip_active"})
				continue
			if not (s["queue"] as Array).is_empty():
				var took := Rules.apply(s, {"type": "talk_next"})
				if not is_same(took, s):
					s = took
					continue
			if int(s["clock_ms"]) >= int(s["config"]["night_len_ms"]) \
					and (s["queue"] as Array).is_empty() \
					and int(s["next_arrival"]) >= (s["arrivals"] as Array).size():
				break
			s = Rules.tick(s, 5000)
		# ONE STEP A NIGHT, NEVER A SKIP — checked on every strand, on every night of the year.
		var season := Season.of_state(s)
		for strand in Content.STRANDS:
			var p: Dictionary = s["story"]["strands"][strand["id"]]
			var moved := int(p["step"]) - int(steps_at_dawn[strand["id"]])
			assert_true(moved == 0 or moved == 1,
				"%s: %s moved %d steps in one night" % [where, strand["id"], moved])
			assert_true(Season.index_of(Season.of_step(int(p["step"]))) <= Season.index_of(season) + 1,
				"%s: %s is on step %d, which is more than one season ahead of the calendar"
				% [where, strand["id"], int(p["step"])])
		# ONE STORY GUEST AT A TIME, asserted on the night as played. Fourteen strands compete for a
		# single slot now, so this is the invariant that would rot first if `MAX_STORY_ARRIVALS` or the
		# `tonight` set in `schedule_beats` were ever loosened.
		assert_true(faces_tonight.size() <= StoryFlow.MAX_STORY_ARRIVALS,
			"%s: %d named guests reached the counter, cap is %d (%s)"
			% [where, faces_tonight.size(), StoryFlow.MAX_STORY_ARRIVALS, str(faces_tonight.keys())])
		s = Rules.apply(s, {"type": "close_night"})
		s["log"] = []
		# THE SAVE SEAM, every night of the year rather than once at the end. The arc ledger added two
		# keys to every strand (`step`, `season_seen`) and `from_json` has to re-integer one of them; a
		# drift there is invisible until a player loads a save and a guest repeats a scene.
		var json := SpatiState.to_json(s)
		assert_eq(SpatiState.to_json(SpatiState.from_json(json)), json,
			"%s: the saved night round-trips byte for byte" % where)
		if s["phase"] == "summary":
			s = Rules.apply(s, {"type": "advance_day"})
	return s

## How far a strand's written chain goes when every answer is the top line (which is what the headless
## policy takes): the number of beats, and therefore the step it can reach. `1 +` because a strand
## starts ON step 1 and its first resolved beat is what moves it to 2.
func _chain_length(strand_id: String) -> int:
	var strand := Content.strand(strand_id)
	var seen: Dictionary = {}
	var cur := String(strand.get("start", ""))
	while cur != "" and not seen.has(cur):
		seen[cur] = true
		var beat := Content.beat(strand_id, cur)
		if beat.is_empty():
			break
		cur = String(((beat["choices"] as Array)[0] as Dictionary).get("next", ""))
	return seen.size()

## The till is rigged OPEN — no rent, a deep float — so the year is ended by the CALENDAR and never by
## `cash < -200`. This harness waves the parade through rather than working the register, which is not
## a solvent way to run a Spati; solvency has its own end-to-end run in test_determinism.gd, and a
## season that died in the autumn would test the arcs only as far as the autumn.
func _story_config(days: int) -> Dictionary:
	return {"seed": 5, "season_days": days, "night_len_ms": 60000,
		"start_cash": 20000.0, "rent_per_day": 0.0}

## ONE YEAR, ASKED MANY QUESTIONS. Five tests wanted a full headless year and each ran its own — five
## identical 112-night simulations of the same seeded state, which is most of this file's runtime and
## exactly one fact. The year is a pure function of `_story_config`, so it is computed once per process
## and read by everyone. (`static` is the SCRIPT's: the runner news up a fresh TestCase per method, so
## an instance variable would cache nothing.) Callers may only READ it — a test that mutated the
## returned state would be editing every other test's fixture.
static var _YEAR: Dictionary = {}

func _the_year() -> Dictionary:
	if _YEAR.is_empty():
		_YEAR = _play_story_season(SpatiState.new_game(_story_config(FULL_SEASON_DAYS)), FULL_SEASON_DAYS + 2)
	return _YEAR

func test_a_headless_full_season_walks_every_guest_through_their_arc() -> void:
	var final := _the_year()
	assert_eq(String(final["phase"]), "end", "the year ran out")
	assert_eq(Season.of_state(final), "spring", "and ended in the spring")
	for id in GUESTS:
		var p := _progress(final, id)
		var name := String(Content.character(id)["name"])
		assert_true((final["story"]["met"] as Array).has(String(Content.strand(_strand_of(id))["character"])),
			"%s turned up at the counter" % name)
		# EVERY GUEST REACHES THEIR SEASON-APPROPRIATE STEP — as far as their written arc goes. By the
		# spring that is step 7, and a strand with a three-beat chain can only reach step 4; the cap is
		# the content, never the machinery, which is the line the content lanes are here to move.
		var reachable := mini(Season.LAST_STEP, 1 + _chain_length(_strand_of(id)))
		assert_true(int(p["step"]) >= reachable,
			"%s reached step %d of the %d their written arc allows by the spring" % [name, int(p["step"]), reachable])
		assert_true(SEASONS.has(String(p["season_seen"])),
			"%s's ledger says which season last saw them (%s)" % [name, p["season_seen"]])
	# Bley's is the only seven-beat strand shipped, so he is the proof the whole ladder runs.
	assert_eq(int(_progress(final, "bley")["step"]), Season.LAST_STEP,
		"Herr Bley's seven beats carried his arc to step 7")
	assert_eq(SpatiState.to_json(SpatiState.from_json(SpatiState.to_json(final))), SpatiState.to_json(final),
		"and the whole year round-trips")

func test_the_season_run_is_reproducible() -> void:
	var cfg := _story_config(28)
	cfg["seed"] = 8
	var a := _play_story_season(SpatiState.new_game(cfg), 30)
	var b := _play_story_season(SpatiState.new_game(cfg), 30)
	assert_eq(SpatiState.to_json(a), SpatiState.to_json(b), "the arcs are as deterministic as the night is")

# ─────────────── 8. the content lane: Tobias · Aylin · Herr Bley, all seven steps ───────────────
## Three arcs written out end to end — `tobias_s2` … `tobias_p7`, `aylin_s2` … `aylin_p7`,
## `bley_s2` … `bley_p7` — plus the strand beats that schedule them. Everything docs/06 §8.5 asks a
## content lane for is asserted here on THIS lane's guests rather than described: the step trees exist
## and are selected, they keep the authoring budget, the flags they write are read, every step after
## the first GATES on a flag an earlier step wrote, and each tree survives the real read-model.

## character id -> strand id. Aylin's strand kept its two-person id when Jonas went offstage.
const LANE := {"tobias": "tobias", "aylin": "aylinjonas", "bley": "bley"}
## The seven beats of each strand, in the order the persona cards name them (docs/09 §2.8/§2.10/§2.11).
const LANE_BEATS := {
	"tobias": ["t_meet", "t_destination", "t_fund", "t_six", "t_choice", "t_care", "t_throws"],
	"aylinjonas": ["aj_meet", "aj_plans", "aj_onebag", "aj_sundays", "aj_turn", "aj_magic", "aj_eight"],
	"bley": ["b_water", "b_youngman", "b_eleven", "b_tuesday", "b_armour", "b_seen", "b_patron"],
}
## THE ONE DELIBERATE EXCEPTION to "gate only on a flag every branch writes". Herr Bley's spring beat
## is the fork his card names — *A Quiet Patron*, **or** he relapses into the coat — so `bley_tip` is
## an OPTIONAL flag on purpose: the player who never let him say what page eleven does never gets the
## envelope. Everywhere else an optional gate would freeze an arc, which is why this list has one row.
const LANE_OPTIONAL_GATE := {"b_patron": "bley_tip"}

func _lane_step_trees(character_id: String) -> Array:
	var out: Array = []
	for step in range(Season.FIRST_STEP + 1, Season.LAST_STEP + 1):
		out.append(Content.arc_tree_id(character_id, step))
	return out

## Every flag any of this lane's trees or strand beats writes → where it was written.
func _lane_flags_written() -> Dictionary:
	var out: Dictionary = {}
	for character_id in LANE:
		var id := String(character_id)
		var trees: Array = [id]
		trees.append_array(_lane_step_trees(id))
		for tree_id in trees:
			var nodes: Dictionary = (Content.DIALOGUES[tree_id] as Dictionary)["nodes"]
			for node_id in nodes:
				for choice in ((nodes[node_id] as Dictionary)["choices"] as Array):
					for key in ["effects", "effects_success", "effects_fail"]:
						for f in (((choice as Dictionary).get(key, {}) as Dictionary).get("flags", []) as Array):
							out[String(f)] = "%s/%s" % [tree_id, node_id]
		var strand := Content.strand(String(LANE[character_id]))
		for beat_id in (strand["beats"] as Dictionary):
			for choice in (((strand["beats"] as Dictionary)[beat_id] as Dictionary).get("choices", []) as Array):
				for f in ((choice as Dictionary).get("flags", []) as Array):
					out[String(f)] = "%s/%s" % [strand["id"], beat_id]
	return out

## Reader kind 1, registry-wide: every `requires_flag` gate in the content, and where it sits.
func _lane_flags_gated() -> Dictionary:
	var out: Dictionary = {}
	for strand in Content.STRANDS:
		for beat_id in (strand["beats"] as Dictionary):
			var f := String(((strand["beats"] as Dictionary)[beat_id] as Dictionary).get("requires_flag", ""))
			if f != "":
				out[f] = "%s/%s" % [strand["id"], beat_id]
	for v in Content.VIGNETTES:
		var vf := String(v.get("requires_flag", ""))
		if vf != "":
			out[vf] = String(v["id"])
	return out

func test_every_step_of_the_tobias_aylin_bley_arcs_is_written_and_selected() -> void:
	# Step 1 is the plain tree (docs/06 §8.2 tier 2) and stays unwritten as `<char>_s1`; steps 2-7 are
	# tier 1 and must EXIST, or the guest silently replays step 1 — audible, and no test would see it.
	var s := _fresh()
	for character_id in LANE:
		var id := String(character_id)
		assert_true(Content.DIALOGUES.has(id), "%s keeps their plain tree, which IS step 1" % id)
		for step in range(Season.FIRST_STEP, Season.LAST_STEP + 1):
			_progress(s, id)["step"] = step
			var tree_id := Content.arc_tree_id(id, step)
			assert_eq(tree_id, "%s_%s%d" % [id, Season.letter_of(Season.of_step(step)), step],
				"the id convention holds for %s step %d" % [id, step])
			assert_true(Content.arc_title_for_step(id, step).length() > 3,
				"%s's card names step %d" % [id, step])
			if step == Season.FIRST_STEP:
				assert_eq(Content.dialogue_id_for(id, s), id, "%s step 1 opens the plain tree" % id)
				continue
			assert_true(Content.DIALOGUES.has(tree_id), "%s is written" % tree_id)
			assert_eq(Content.dialogue_id_for(id, s), tree_id, "%s step %d selects %s" % [id, step, tree_id])

func test_the_tobias_aylin_bley_trees_keep_the_authoring_budget() -> void:
	# docs/09 §4: 5-8 nodes · >= 1 d20 check · >= 1 gate LOCKED at day-one stats · a face change per
	# beat · the order woven into the first node · choice 0 never gated · flags a later step reads.
	# Plus the one docs/09 §3 rule a tree can break silently: a face the art lane never drew for THIS
	# character falls back to `_neutral`, and the bust simply never reacts.
	var defaults: Dictionary = _fresh()["player"]["stats"]
	for character_id in LANE:
		var id := String(character_id)
		var on_disk: Array = Content.character(id)["expressions"]
		for tree_id in _lane_step_trees(id):
			var tree: Dictionary = Content.DIALOGUES[tree_id]
			var nodes: Dictionary = tree["nodes"]
			assert_true(nodes.size() >= 5 and nodes.size() <= 8,
				"%s is 5-8 nodes (got %d)" % [tree_id, nodes.size()])
			var checks := 0
			var gates := 0
			var faces: Dictionary = {}
			var flags: Dictionary = {}
			for node_id in nodes:
				var node: Dictionary = nodes[node_id]
				assert_eq(String(node["speaker"]), id,
					"%s/%s is spoken by %s, so their basket answers for it" % [tree_id, node_id, id])
				var face := String(node["expression"])
				assert_true(on_disk.has(face),
					"%s/%s wears a face %s actually has on disk (%s)" % [tree_id, node_id, id, face])
				faces[face] = true
				var choices: Array = node["choices"]
				assert_false((choices[0] as Dictionary).has("requires"),
					"%s/%s: choice 0 is never gated — the AutoPlayer has to get out" % [tree_id, node_id])
				for choice in choices:
					var c: Dictionary = choice
					if not (c.get("check", {}) as Dictionary).is_empty():
						checks += 1
					var requires: Dictionary = c.get("requires", {})
					if not requires.is_empty():
						gates += 1
						assert_true(int(requires["min"]) > int(defaults[String(requires["stat"])]),
							"%s/%s: the gate is LOCKED at day-one stats" % [tree_id, node_id])
					for key in ["effects", "effects_success", "effects_fail"]:
						for f in ((c.get(key, {}) as Dictionary).get("flags", []) as Array):
							flags[String(f)] = true
			assert_true(checks >= 1, "%s rolls at least one d20 (got %d)" % [tree_id, checks])
			assert_true(gates >= 1, "%s locks at least one door (got %d)" % [tree_id, gates])
			assert_true(faces.size() >= 3, "%s wears at least three faces (got %s)" % [tree_id, str(faces.keys())])
			assert_true(flags.size() >= 2, "%s leaves a mark a later step can read (got %d)" % [tree_id, flags.size()])
			var opening := ""
			for line in ((nodes[String(tree["start"])] as Dictionary)["lines"] as Array):
				opening += String(line)
			var speaks_the_basket := false
			for entry in Content.basket_for(id):
				var sku_id := String((entry as Dictionary)["sku"])
				if opening.contains("{qty." + sku_id + "}") or opening.contains("{brand." + sku_id + "}") \
						or opening.contains("{logo." + sku_id + "}"):
					speaks_the_basket = true
			assert_true(speaks_the_basket, "%s weaves the order into its first node" % tree_id)

func test_every_flag_the_tobias_aylin_bley_arcs_write_is_read() -> void:
	# docs/09 §4.10: a flag nobody reads is a lie in the save file. Three reader kinds, exactly one per
	# flag — and a flag that has BOTH a real gate and a FLAG_READERS row is the dead declaration
	# `test_flags.gd::test_no_declared_reader_is_dead` fails on, so it is caught here first.
	var written := _lane_flags_written()
	var gated := _lane_flags_gated()
	assert_true(written.size() >= 60, "three seven-step arcs leave a real set of marks (%d)" % written.size())
	for f in written:
		var flag := String(f)
		var read := gated.has(flag) or Economy.FLAG_LABEL.has(flag) or Content.FLAG_READERS.has(flag)
		assert_true(read, "%s (set at %s) is read by a gate, a FLAG_LABEL or a declared reader"
			% [flag, written[flag]])
		if gated.has(flag):
			assert_false(Content.FLAG_READERS.has(flag),
				"%s has a real gate at %s now — delete its FLAG_READERS row" % [flag, gated[flag]])
		assert_true(RegEx.create_from_string("^(tobias|aylin|bley|main|took)_[a-z0-9_]+$").search(flag) != null,
			"%s is namespaced to one of this lane's guests (or main_/took_)" % flag)

func test_each_step_of_this_lanes_arcs_reads_a_flag_an_earlier_step_wrote() -> void:
	# THE BRANCHING CONTRACT. A step's strand beat is what schedules it, and every beat after the first
	# carries `requires_flag` — so the arc genuinely reads back what the player did rather than merely
	# counting nights. The flag has to be one EVERY branch of an earlier beat wrote, or a player who
	# answered differently freezes the strand for ever (`eligible_beats` skips an ungated-flag beat and
	# `cur` never moves). The single documented exception is Herr Bley's optional spring fork.
	for character_id in LANE:
		var strand_id := String(LANE[character_id])
		var order: Array = LANE_BEATS[strand_id]
		var guaranteed: Dictionary = {}   # flags EVERY branch of an earlier beat wrote
		var somewhere: Dictionary = {}    # flags SOME branch of an earlier beat wrote
		for i in order.size():
			var beat_id := String(order[i])
			var beat := Content.beat(strand_id, beat_id)
			assert_false(beat.is_empty(), "%s/%s is written" % [strand_id, beat_id])
			var flag := String(beat.get("requires_flag", ""))
			if i == 0:
				assert_eq(flag, "", "%s/%s is step 1 and gates on nothing" % [strand_id, beat_id])
			elif LANE_OPTIONAL_GATE.has(beat_id):
				assert_eq(flag, String(LANE_OPTIONAL_GATE[beat_id]),
					"%s/%s keeps its documented optional fork" % [strand_id, beat_id])
				assert_true(somewhere.has(flag),
					"%s: the optional gate %s is reachable from an earlier beat" % [strand_id, flag])
			else:
				assert_ne(flag, "", "%s/%s reads a flag an earlier step wrote" % [strand_id, beat_id])
				assert_true(guaranteed.has(flag),
					"%s/%s gates on %s, which EVERY branch of an earlier beat writes"
					% [strand_id, beat_id, flag])
			# Collect what this beat writes, splitting "every branch" from "some branch".
			var shared: Dictionary = {}
			var first := true
			for choice in (beat["choices"] as Array):
				var here: Dictionary = {}
				for f in ((choice as Dictionary).get("flags", []) as Array):
					here[String(f)] = true
					somewhere[String(f)] = beat_id
				if first:
					shared = here
					first = false
				else:
					for f in shared.keys():
						if not here.has(f):
							shared.erase(f)
			for f in shared:
				guaranteed[String(f)] = beat_id

func test_this_lanes_strands_run_all_seven_beats_in_the_cards_order() -> void:
	# One beat per arc step, on the top line, ending after the spring one — so `_chain_length` (and the
	# full-season run that leans on it) sees seven, and the card's beat titles line up with the data.
	for character_id in LANE:
		var id := String(character_id)
		var strand_id := String(LANE[character_id])
		var strand := Content.strand(strand_id)
		var order: Array = LANE_BEATS[strand_id]
		assert_eq((strand["beats"] as Dictionary).size(), Season.LAST_STEP,
			"%s carries one beat per step (got %d)" % [strand_id, (strand["beats"] as Dictionary).size()])
		assert_eq(String(strand["start"]), String(order[0]), "%s starts on its step-1 beat" % strand_id)
		var cur := String(strand["start"])
		for i in order.size():
			assert_eq(cur, String(order[i]), "%s step %d is %s" % [strand_id, i + 1, order[i]])
			var beat := Content.beat(strand_id, cur)
			assert_true((beat["lines"] as Array).size() >= 1, "%s/%s has lines" % [strand_id, cur])
			cur = String(((beat["choices"] as Array)[0] as Dictionary).get("next", ""))
		assert_eq(cur, "", "%s's chain ends after the spring step" % strand_id)
		assert_eq(_chain_length(strand_id), Season.LAST_STEP, "%s: seven beats on the top line" % strand_id)
		assert_eq(String(Content.character(id)["strand_id"]), strand_id,
			"%s's persona card points at %s" % [id, strand_id])

func test_this_lanes_step_trees_play_through_the_real_read_model() -> void:
	# Never trust a name, assert against the read-model (docs/06 §8.5 trap 1): `_place_basket` truncates
	# the authored basket to the reducer's caps and drops anything the shop has not unlocked, and
	# `Talk._apply` leaves a token it cannot match ALONE — so a cut row does not fail, it PRINTS.
	# Open every step in its own season, walk the top line out, and assert nothing in braces is shown.
	var any := RegEx.create_from_string("\\{([^}]*)\\}")
	for character_id in LANE:
		var id := String(character_id)
		for step in range(Season.FIRST_STEP + 1, Season.LAST_STEP + 1):
			var tree_id := Content.arc_tree_id(id, step)
			var day := Season.first_day_of(Season.index_of(Season.of_step(step)), 28)
			var s := _at_the_counter(id, step, day)
			assert_eq(String(s["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + tree_id,
				"%s opens on day %d, the first night of the %s" % [tree_id, day, Season.of_step(step)])
			var walked := 0
			while Talk.is_open(s) and walked < 40:
				walked += 1
				var talk: Dictionary = Rules.view(s)["talk"]
				var shown: Array = (talk["lines"] as Array).duplicate()
				for choice in (talk["choices"] as Array):
					shown.append(String((choice as Dictionary)["label"]))
				for text in shown:
					for m in any.search_all(String(text)):
						fail("%s/%s: %s reached the box unsubstituted — %s"
							% [tree_id, String(s["talk"]["node"]), m.get_string(0), String(text)])
				var advanced := Rules.apply(s, {"type": "talk_advance"})
				s = advanced if not is_same(advanced, s) else Rules.apply(s, {"type": "talk_choose", "choice": 0})
			assert_false(Talk.is_open(s), "%s closed in %d steps" % [tree_id, walked])
			# The talk ending is the SALE starting (docs/06 §4): a guest whose basket is on the counter
			# stays standing for the register, so "closed" must not be read as "left".
			assert_false((s["active"] as Dictionary).is_empty(),
				"%s stays at the counter with their basket — the register is the serve" % id)
			assert_eq(int(_progress(s, id)["step"]), mini(step + 1, Season.LAST_STEP),
				"%s played, so the ledger moved on one step" % tree_id)

# ───────────────── 8. the SCHULZ / ACHIM lane — two arcs written all the way to the spring ─────────
## Frau Schulz (S5) and Achim (S7) are the first two guests whose seven steps are ALL written: seven
## strand beats each, and a dialogue tree for every one of steps 2-7 beside the step-1 tree that
## shipped with docs/09 §4. What is asserted here is the three things a content lane can get wrong in
## a way nothing else catches:
##   · a tree whose id is not `<char>_<letter><step>` is silently unreachable — so every step is
##     resolved through the REAL selector and opened through the REAL reducer, never looked up;
##   · a flag nobody reads is a lie in the save file, and a beat gated on a flag nothing on the
##     choice-0 path sets FREEZES the arc where it stands (`eligible_beats` skips a strand for ever
##     once its `requires_flag` cannot be met) — so the whole chain is walked with the flags a
##     top-line player would actually be holding;
##   · a token whose basket row was truncated does not fail, it PRINTS — so every one of the twelve
##     trees is walked end to end through `Rules.view`, not through the authored table.
const SA_LANE := ["schulz", "achim"]

## The first night of the season that OWNS a step, in the shipped 28-night year — where that step is
## meant to be played, and (for the trees) a plausible night to be caught up on it.
func _sa_day_for_step(step: int) -> int:
	return Season.first_day_of(Season.index_of(Season.of_step(step)), 28)

## Every flag any choice of one dialogue tree writes.
func _sa_tree_flags(tree_id: String) -> Dictionary:
	var out: Dictionary = {}
	for node_id in (Content.DIALOGUES[tree_id]["nodes"] as Dictionary):
		for choice in (Content.DIALOGUES[tree_id]["nodes"][node_id]["choices"] as Array):
			for key in ["effects", "effects_success", "effects_fail"]:
				for f in ((choice as Dictionary).get(key, {}) as Dictionary).get("flags", []):
					out[String(f)] = node_id
	return out

## Every `requires_flag` gate on one strand's beats — the READ side of that guest's own arc.
func _sa_strand_gates(strand_id: String) -> Dictionary:
	var out: Dictionary = {}
	for beat_id in (Content.strand(strand_id)["beats"] as Dictionary):
		var f := String((Content.strand(strand_id)["beats"][beat_id] as Dictionary).get("requires_flag", ""))
		if f != "":
			out[f] = beat_id
	return out

## Reader kind 1 across ALL content (another strand or a vignette may be the one that gates a flag).
func _sa_all_gates() -> Dictionary:
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

func test_schulz_and_achim_have_a_tree_for_every_step_the_selector_can_ask_for() -> void:
	var s := _fresh()
	for id in SA_LANE:
		for step in range(Season.FIRST_STEP, Season.LAST_STEP + 1):
			var tree := Content.arc_tree_id(id, step)
			if step == Season.FIRST_STEP:
				# Step 1 is the plain tree of docs/09 §4 — deliberately NOT `<char>_s1`.
				assert_false(Content.DIALOGUES.has(tree), "%s stays step 1's tree, not %s" % [id, tree])
				continue
			assert_true(Content.DIALOGUES.has(tree), "%s step %d is written as %s" % [id, step, tree])
			_progress(s, id)["step"] = step
			assert_eq(Content.dialogue_id_for(id, s), tree,
				"%s on step %d resolves through tier 1, not the fallback" % [id, step])
			# The card and the content agree about what this step is called.
			assert_true(Content.arc_title_for_step(id, step).length() > 3,
				"%s step %d is a beat id on the persona card" % [id, step])

func test_the_reducer_opens_every_schulz_and_achim_step_at_the_counter() -> void:
	# The selector is worth nothing if `talk_next` does not use it, and an id that is one character
	# out (`schulz_p7` vs `schulz_s7`) fails HERE and nowhere else.
	for id in SA_LANE:
		var seen: Dictionary = {}
		for step in range(Season.FIRST_STEP + 1, Season.LAST_STEP + 1):
			var s := _at_the_counter(id, step, _sa_day_for_step(step))
			var opened := String(s["talk"]["dialogue_id"])
			assert_eq(opened, Talk.DIALOGUE_PREFIX + Content.arc_tree_id(id, step),
				"%s step %d opens its own tree" % [id, step])
			var first := String((Talk.view(s)["lines"] as Array)[0])
			assert_false(seen.has(first), "%s step %d says something step %s did not"
				% [id, step, seen.get(first, "")])
			seen[first] = step

func test_the_schulz_and_achim_trees_keep_the_authoring_budget() -> void:
	# docs/09 §4, per tree: 5-8 nodes · >= 1 d20 check that is a coin · >= 1 gate LOCKED at day-one
	# stats · a face change per node, drawn only from the six this character has ON DISK · choice 0
	# never gated · the order woven into the first node.
	var defaults: Dictionary = _fresh()["player"]["stats"]
	for id in SA_LANE:
		var drawn: Array = Content.character(id)["expressions"]
		var basket: Dictionary = {}
		for row in Content.basket_for(id):
			basket[String((row as Dictionary)["sku"])] = true
		for step in range(Season.FIRST_STEP + 1, Season.LAST_STEP + 1):
			var tree_id := Content.arc_tree_id(id, step)
			var tree: Dictionary = Content.DIALOGUES[tree_id]
			var nodes: Dictionary = tree["nodes"]
			assert_true(nodes.size() >= 5 and nodes.size() <= 8,
				"%s is 5-8 nodes (got %d)" % [tree_id, nodes.size()])
			var checks := 0
			var gates := 0
			var faces: Dictionary = {}
			for node_id in nodes:
				var node: Dictionary = nodes[node_id]
				assert_eq(String(node["speaker"]), id,
					"%s/%s names its speaker, so the basket tokens resolve" % [tree_id, node_id])
				var face := String(node["expression"])
				assert_true(drawn.has(face), "%s/%s wears a face %s has on disk (%s)" % [tree_id, node_id, id, face])
				faces[face] = true
				var choices: Array = node["choices"]
				assert_false((choices[0] as Dictionary).has("requires"),
					"%s/%s: choice 0 is never gated" % [tree_id, node_id])
				for choice in choices:
					var c: Dictionary = choice
					for key in ["next", "next_fail"]:
						var target := String(c.get(key, ""))
						if target != "":
							assert_true(nodes.has(target), "%s/%s -> %s exists" % [tree_id, node_id, target])
					var check: Dictionary = c.get("check", {})
					if not check.is_empty():
						checks += 1
						var dc := int(check["dc"])
						assert_true(dc >= 11 and dc <= 15, "%s/%s: DC %d is in 11..15" % [tree_id, node_id, dc])
						var chance := Talk.success_chance(dc, Rules.modifier(int(defaults[String(check["stat"])])))
						assert_true(chance >= 0.4 and chance <= 0.7,
							"%s/%s: %d%% is a coin" % [tree_id, node_id, int(round(chance * 100.0))])
						assert_true(String(c["label"]).begins_with("["), "%s/%s wears its tag" % [tree_id, node_id])
					var requires: Dictionary = c.get("requires", {})
					if not requires.is_empty():
						gates += 1
						assert_true(int(requires["min"]) > int(defaults[String(requires["stat"])]),
							"%s/%s's gate is LOCKED on night one" % [tree_id, node_id])
						assert_true(String(c["label"]).begins_with("["), "%s/%s wears its gate tag" % [tree_id, node_id])
			assert_true(checks >= 1, "%s rolls at least one d20 (got %d)" % [tree_id, checks])
			assert_true(gates >= 1, "%s locks at least one door (got %d)" % [tree_id, gates])
			assert_true(faces.size() >= 3, "%s changes its face (got %s)" % [tree_id, str(faces.keys())])
			# The order is in the FIRST node, in tokens, off this guest's own basket.
			var opening := ""
			for line in (nodes[String(tree["start"])]["lines"] as Array):
				opening += String(line) + " "
			var spoke := false
			for sku_id in basket:
				if opening.contains("{qty." + String(sku_id) + "}") or opening.contains("{brand." + String(sku_id) + "}"):
					spoke = true
			assert_true(spoke, "%s's opening node orders off %s's basket in tokens" % [tree_id, id])

func test_every_flag_schulz_and_achim_set_has_a_reader() -> void:
	# The WRITE side of both arcs, checked the way test_flags.gd checks the whole game — but here the
	# reader has to exist for a flag set ANYWHERE in twelve trees and fourteen beats, and each tree of
	# steps 2-6 must additionally set a flag a LATER BEAT OF THE SAME GUEST gates on. That last clause
	# is what makes the arc branch on the player rather than merely accumulate nouns.
	var gated := _sa_all_gates()
	for id in SA_LANE:
		var strand_id := _strand_of(id)
		var own_gates := _sa_strand_gates(strand_id)
		assert_true(own_gates.size() >= 6, "%s's arc reads a flag at every step past the first (%d)"
			% [id, own_gates.size()])
		var trees: Array = [id]
		for step in range(Season.FIRST_STEP + 1, Season.LAST_STEP + 1):
			trees.append(Content.arc_tree_id(id, step))
		for tree_id in trees:
			var flags := _sa_tree_flags(String(tree_id))
			assert_true(flags.size() >= 1, "%s leaves a mark" % tree_id)
			for f in flags:
				var flag := String(f)
				assert_true(gated.has(flag) or Economy.FLAG_LABEL.has(flag) or Content.FLAG_READERS.has(flag),
					"%s/%s sets '%s', which a gate, a FLAG_LABEL or a declared reader consumes"
					% [tree_id, flags[f], flag])
				assert_true(flag.begins_with(id + "_") or Economy.FLAG_LABEL.has(flag) or flag.begins_with("main_"),
					"%s: '%s' is namespaced to its owner" % [tree_id, flag])
			if String(tree_id) == id or String(tree_id).ends_with("p7"):
				continue  # step 1 predates the arc; step 7 has no later beat to feed
			var feeds := ""
			for f in flags:
				if own_gates.has(String(f)):
					feeds = String(f)
			assert_ne(feeds, "", "%s sets a flag one of %s's later beats gates on (set %s)"
				% [tree_id, id, str(flags.keys())])
	# And the two declarations that a real gate took over have gone: `schulz_listen` / `achim_listen`
	# are now the `requires_flag` on each guest's SPRING beat, so a stale FLAG_READERS row for them
	# would be a second, wrong answer to "who reads this?" (test_flags.gd::test_no_declared_reader_is_dead).
	for flag in ["schulz_listen", "achim_listen"]:
		assert_true(gated.has(flag), "'%s' is a real gate now (%s)" % [flag, gated.get(flag, "")])
		assert_false(Content.FLAG_READERS.has(flag), "'%s' no longer needs a declared reader" % flag)

func test_the_schulz_and_achim_beat_chains_never_strand_a_top_line_player() -> void:
	# `eligible_beats` drops a strand whose `requires_flag` is unmet AND a strand whose `cur` has run
	# out — so a gate the choice-0 path cannot satisfy does not produce a smaller arc, it produces a
	# guest who never walks in again. Walk the chain the way the headless policy does and prove every
	# gate is already in hand when it is reached.
	for id in SA_LANE:
		var strand_id := _strand_of(id)
		var strand := Content.strand(strand_id)
		var held: Dictionary = {}
		var seen: Dictionary = {}
		var cur := String(strand["start"])
		var step := Season.FIRST_STEP
		var earlier := ""
		while cur != "":
			assert_false(seen.has(cur), "%s/%s is reached once, so the chain is a line not a loop" % [strand_id, cur])
			seen[cur] = true
			var beat := Content.beat(strand_id, cur)
			assert_false(beat.is_empty(), "%s/%s is written" % [strand_id, cur])
			var gate := String(beat.get("requires_flag", ""))
			if step == Season.FIRST_STEP:
				assert_eq(gate, "", "%s's first beat is ungated — nothing has happened yet" % strand_id)
			else:
				assert_ne(gate, "", "%s/%s (step %d) reads a flag" % [strand_id, cur, step])
				assert_true(held.has(gate),
					"%s/%s needs '%s', which %s already set" % [strand_id, cur, gate, held.get(gate, "nothing")])
			# The step's season may never run ahead of the step number it is written for.
			assert_true(Season.step_is_due(step, Season.of_step(step)), "step %d is due in its own season" % step)
			var choice: Dictionary = (beat["choices"] as Array)[0]
			for f in choice.get("flags", []):
				held[String(f)] = "%s/%s" % [strand_id, cur]
			earlier = cur
			cur = String(choice.get("next", ""))
			step += 1
		assert_eq(step - 1, Season.LAST_STEP,
			"%s is seven beats long, one per Truby step (ended on %s at %d)" % [strand_id, earlier, step - 1])
		# Two outcomes, so the tapestry has something to print in all four endings.
		var outcomes: Dictionary = {}
		for beat_id in (strand["beats"] as Dictionary):
			for choice in ((strand["beats"][beat_id] as Dictionary)["choices"] as Array):
				if String((choice as Dictionary).get("outcome", "")) != "":
					outcomes[String((choice as Dictionary)["outcome"])] = true
		assert_true(outcomes.size() >= 2, "%s still branches to two outcomes (%s)" % [strand_id, str(outcomes.keys())])

func test_every_schulz_and_achim_step_plays_end_to_end_through_the_read_model() -> void:
	# NEVER TRUST A NAME, ASSERT AGAINST THE READ-MODEL. `_place_basket` truncates to the reducer's
	# caps and drops any SKU the shop has not unlocked — Frau Schulz's milk is `unlocked_by
	# grocery_section` and is NOT on the counter on night one — and `Talk._apply` leaves a token it
	# cannot match ALONE, so a `{qty.milk}` would print onto the counter rather than fail.
	var any := RegEx.create_from_string("\\{([^}]*)\\}")
	for id in SA_LANE:
		for step in range(Season.FIRST_STEP + 1, Season.LAST_STEP + 1):
			var tree_id := Content.arc_tree_id(id, step)
			var s := _at_the_counter(id, step, _sa_day_for_step(step))
			assert_eq(String(s["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + tree_id, "%s opened" % tree_id)
			var steps := 0
			while Talk.is_open(s) and steps < 40:
				steps += 1
				var talk: Dictionary = Rules.view(s)["talk"]
				var shown: Array = (talk["lines"] as Array).duplicate()
				for choice in (talk["choices"] as Array):
					shown.append(String((choice as Dictionary)["label"]))
				for text in shown:
					for m in any.search_all(String(text)):
						fail("%s/%s: %s reached the box unsubstituted — %s"
							% [tree_id, String(s["talk"]["node"]), m.get_string(0), String(text)])
				var advanced := Rules.apply(s, {"type": "talk_advance"})
				s = advanced if not is_same(advanced, s) else Rules.apply(s, {"type": "talk_choose", "choice": 0})
			assert_false(Talk.is_open(s), "%s closes on the top line in %d steps" % [tree_id, steps])
			var p: Dictionary = _progress(s, id)
			assert_eq(int(p["step"]), mini(step + 1, Season.LAST_STEP),
				"%s played, so the arc moved on" % tree_id)

func test_schulz_and_achim_reach_the_spring_in_a_headless_year() -> void:
	# The lane's own end-to-end: both arcs are seven beats and twelve trees, so by the spring both
	# guests must be ON step 7 with an outcome recorded and their name in the tapestry. This is the
	# assertion the full-season run makes generically; it is repeated here because these two are the
	# first arcs written all the way through, and a regression in either would otherwise only show up
	# as a number in a loop over eleven names.
	var final := _the_year()
	for id in SA_LANE:
		var strand_id := _strand_of(id)
		var p: Dictionary = final["story"]["strands"][strand_id]
		assert_eq(int(p["step"]), Season.LAST_STEP, "%s's seven beats carried the arc to step 7" % id)
		assert_eq(String(p["cur"]), "", "%s's chain is played out, not stalled on a gate" % id)
		assert_true(String(p["outcome"]).length() > 0, "%s ends the year with an outcome" % id)
		assert_true((final["story"]["met"] as Array).has(String(Content.strand(strand_id)["character"])),
			"%s is in the tapestry" % id)
		assert_true(SEASONS.has(String(p["season_seen"])), "%s's ledger says when they were last seen" % id)
	# The top line takes the listening branch at step 1, which is the gate on both spring beats.
	for flag in ["schulz_listen", "achim_listen"]:
		assert_true((final["story"]["flags"] as Array).has(flag), "'%s' was earned on the way" % flag)

# ───────── 10. the content lane: Karim · Nadia · Robin, steps 2-7 (docs/09 §2.6/§2.7/§2.9) ─────────
## Appended by the cast lane that wrote `karim_s2`..`karim_p7`, `nadia_s2`..`nadia_p7` and
## `robin_s2`..`robin_p7`, plus the beats that schedule them. The sections above prove the MACHINERY;
## these prove the CONTENT hung on it — every step reachable, every step tree inside the docs/09 §4
## budget, every flag read by somebody, and — the one that is new — that no gated step can silently
## delete a guest from the game.

const KNR := ["karim", "nadia", "robin"]
## docs/09 §4: 5-8 nodes · >= 1 d20 check · >= 1 gate LOCKED at day-one stats · a face change per node.
const KNR_MIN_NODES := 5
const KNR_MAX_NODES := 8
const KNR_MIN_FACES := 3
const KNR_MIN_FLAGS := 2
const KNR_MAX_FLAGS := 8

func _knr_steps() -> Array:
	var out: Array = []
	for id in KNR:
		for step in range(Season.FIRST_STEP + 1, Season.LAST_STEP + 1):
			out.append({"id": String(id), "step": step, "tree": Content.arc_tree_id(String(id), step)})
	return out

## Every flag any choice of a graph writes, whichever of the three effect maps carries it.
func _knr_tree_flags(tree_id: String) -> Dictionary:
	var out: Dictionary = {}
	for node_id in (Content.DIALOGUES[tree_id]["nodes"] as Dictionary):
		for choice in (Content.DIALOGUES[tree_id]["nodes"][node_id]["choices"] as Array):
			for key in ["effects", "effects_success", "effects_fail"]:
				for f in ((choice as Dictionary).get(key, {}) as Dictionary).get("flags", []):
					out[String(f)] = "%s/%s" % [tree_id, node_id]
	return out

## A flag is read when a beat/vignette gates on it (kind 1), the Manage panel prints it (kind 2), or
## `Content.FLAG_READERS` names the step that will consume it (kind 3) — docs/09 §4.10.
func _knr_flag_is_read(flag: String) -> bool:
	if Economy.FLAG_LABEL.has(flag) or Content.FLAG_READERS.has(flag):
		return true
	for strand in Content.STRANDS:
		for beat_id in (strand["beats"] as Dictionary):
			if String((strand["beats"][beat_id] as Dictionary).get("requires_flag", "")) == flag:
				return true
	return false

func test_karim_nadia_robin_have_a_tree_for_all_six_remaining_steps() -> void:
	# Step 1 is the plain tree that shipped with the cast; steps 2-7 are this lane's, and the ONLY
	# thing that makes one live is the id. A tree named `karim_a3x` is silently unreachable.
	var s := _fresh()
	for row in _knr_steps():
		var id := String(row["id"])
		var tree := String(row["tree"])
		assert_true(Content.DIALOGUES.has(tree), "%s step %d is written as %s" % [id, row["step"], tree])
		_progress(s, id)["step"] = int(row["step"])
		assert_eq(Content.dialogue_id_for(id, s), tree,
			"the selector opens %s on step %d" % [tree, row["step"]])
	for id in KNR:
		_progress(s, String(id))["step"] = Season.FIRST_STEP
		assert_eq(Content.dialogue_id_for(String(id), s), String(id),
			"%s's step 1 is still their plain tree" % id)

func test_the_reducer_opens_every_karim_nadia_robin_step_at_the_counter() -> void:
	# Reachability the only way that proves anything: put them on the step, take them at the counter,
	# and read back what `talk_next` actually opened.
	for row in _knr_steps():
		var id := String(row["id"])
		var s := _at_the_counter(id, int(row["step"]), 5)
		assert_true(Talk.is_open(s), "%s opens a conversation on step %d" % [id, row["step"]])
		assert_eq(String(s["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + String(row["tree"]),
			"%s step %d opens %s" % [id, row["step"], row["tree"]])

func test_the_karim_nadia_robin_trees_keep_the_authoring_budget() -> void:
	var defaults: Dictionary = _fresh()["player"]["stats"]
	for row in _knr_steps():
		var id := String(row["id"])
		var tree := String(row["tree"])
		var graph: Dictionary = Content.DIALOGUES[tree]
		var nodes: Dictionary = graph["nodes"]
		assert_true(nodes.size() >= KNR_MIN_NODES and nodes.size() <= KNR_MAX_NODES,
			"%s is %d-%d nodes (got %d)" % [tree, KNR_MIN_NODES, KNR_MAX_NODES, nodes.size()])
		assert_true(nodes.has(String(graph["start"])), "%s starts on a written node" % tree)
		# ONLY THE FACES THAT ARE ON DISK. `portrait_asset` falls back to `_neutral` for an expression
		# the character never drew, so naming one is silent: the bust simply never reacts.
		var drawn: Array = Content.character(id)["expressions"]
		var faces: Dictionary = {}
		var checks := 0
		var gates := 0
		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			assert_eq(String(node["speaker"]), id, "%s/%s is spoken by %s" % [tree, node_id, id])
			var face := String(node["expression"])
			assert_true(drawn.has(face), "%s/%s wears a face %s actually has (%s)" % [tree, node_id, id, face])
			faces[face] = true
			var choices: Array = node["choices"]
			assert_true(choices.size() >= 1, "%s/%s has a choice" % [tree, node_id])
			assert_false((choices[0] as Dictionary).has("requires"),
				"%s/%s: choice 0 is never gated" % [tree, node_id])
			for choice in choices:
				var c: Dictionary = choice
				for key in ["next", "next_fail"]:
					var target := String(c.get(key, ""))
					if target != "":
						assert_true(nodes.has(target), "%s/%s -> %s exists" % [tree, node_id, target])
				var check: Dictionary = c.get("check", {})
				if not check.is_empty():
					checks += 1
					var chance := Talk.success_chance(int(check["dc"]), Rules.modifier(int(defaults[String(check["stat"])])))
					assert_true(chance >= 0.4 and chance <= 0.7,
						"%s/%s: %d%% is a coin, not a tax" % [tree, node_id, int(round(chance * 100.0))])
				var requires: Dictionary = c.get("requires", {})
				if not requires.is_empty():
					gates += 1
					assert_true(int(requires["min"]) > int(defaults[String(requires["stat"])]),
						"%s/%s: %s %d is LOCKED on night one" % [tree, node_id, requires["stat"], int(requires["min"])])
		assert_true(checks >= 1, "%s rolls at least one d20 (got %d)" % [tree, checks])
		assert_true(gates >= 1, "%s locks at least one door (got %d)" % [tree, gates])
		assert_true(faces.size() >= KNR_MIN_FACES,
			"%s changes face at least %d times (got %s)" % [tree, KNR_MIN_FACES, str(faces.keys())])

func test_every_karim_nadia_robin_step_speaks_the_order_first() -> void:
	# docs/09 §4: the basket landing on the counter has to be the answer to something they said. Nadia
	# is the guest with no tobacco line and a `coffee` SKU that is `unlocked_by`, so hers is written in
	# plain nouns on purpose — a `{qty.coffee}` in a shop with no machine would print, not fail.
	for row in _knr_steps():
		var id := String(row["id"])
		var graph: Dictionary = Content.DIALOGUES[String(row["tree"])]
		var opening := ""
		for line in (graph["nodes"][String(graph["start"])]["lines"] as Array):
			opening += String(line) + " "
		var names_something := false
		for entry in Content.basket_for(id):
			var sku_id := String((entry as Dictionary)["sku"])
			var sku_name := String(Content.sku(sku_id).get("name", ""))
			if opening.contains("{qty." + sku_id + "}") or opening.contains("{brand." + sku_id + "}") \
					or opening.contains("{logo." + sku_id + "}") or opening.to_lower().contains(sku_name.to_lower()):
				names_something = true
		assert_true(names_something, "%s says what they came in for" % row["tree"])

func test_no_token_in_a_karim_nadia_robin_step_survives_to_the_screen() -> void:
	# The soft-lock rule on the REAL read-model. `_place_basket` truncates to the reducer's caps before
	# `Talk.subs_for` is built, and `_apply` leaves a token it cannot match ALONE — so a `{brand.*}`
	# whose row was cut does not fail, it prints onto the counter at 03:00.
	var any := RegEx.create_from_string("\\{([^}]*)\\}")
	for row in _knr_steps():
		var id := String(row["id"])
		var s := _at_the_counter(id, int(row["step"]), 5)
		var steps := 0
		while Talk.is_open(s) and steps < 40:
			steps += 1
			var talk: Dictionary = Rules.view(s)["talk"]
			var shown: Array = (talk["lines"] as Array).duplicate()
			for choice in (talk["choices"] as Array):
				shown.append(String((choice as Dictionary)["label"]))
			for text in shown:
				for m in any.search_all(String(text)):
					fail("%s/%s: %s reached the box unsubstituted — %s"
						% [row["tree"], String(s["talk"]["node"]), m.get_string(0), String(text)])
			var advanced := Rules.apply(s, {"type": "talk_advance"})
			s = advanced if not is_same(advanced, s) else Rules.apply(s, {"type": "talk_choose", "choice": 0})
		assert_false(Talk.is_open(s), "%s closed in %d steps" % [row["tree"], steps])
		assert_eq(int(_progress(s, id)["step"]), mini(int(row["step"]) + 1, Season.LAST_STEP),
			"%s played, so the arc moved on" % row["tree"])

func test_every_flag_karim_nadia_robin_set_is_read_by_somebody() -> void:
	# A flag nobody reads is a lie in the save file. A dialogue tree cannot gate on a flag, so a step
	# tree's flags are always kind 3 (a declared reader) — and the DECLARATION is data, so "who reads
	# this?" is answerable from `Content.FLAG_READERS` instead of from memory.
	for row in _knr_steps():
		var flags := _knr_tree_flags(String(row["tree"]))
		assert_true(flags.size() >= KNR_MIN_FLAGS and flags.size() <= KNR_MAX_FLAGS,
			"%s spends %d-%d flags (got %d: %s)" % [row["tree"], KNR_MIN_FLAGS, KNR_MAX_FLAGS, flags.size(), str(flags.keys())])
		for f in flags:
			var flag := String(f)
			assert_true(_knr_flag_is_read(flag), "%s (set at %s) has a reader" % [flag, flags[flag]])
			assert_true(flag.begins_with(String(row["id"]) + "_") or flag.begins_with("main_"),
				"%s is namespaced to its owner" % flag)
	# …and the beats' own flags, which are the half the gates read back.
	for id in KNR:
		var strand := Content.strand(_strand_of(String(id)))
		for beat_id in (strand["beats"] as Dictionary):
			for choice in ((strand["beats"][beat_id] as Dictionary).get("choices", []) as Array):
				for f in (choice as Dictionary).get("flags", []):
					assert_true(_knr_flag_is_read(String(f)),
						"%s/%s sets %s, which somebody reads" % [strand["id"], beat_id, f])

func test_every_karim_nadia_robin_step_reads_an_earlier_flag() -> void:
	# THE POINT OF THE WHOLE PASS. A step that reads nothing is a scene that happens to be numbered.
	# Step 1 is the introduction and gates on nothing; every beat after it carries a `requires_flag`,
	# and that flag is written by a choice further up its own chain.
	for id in KNR:
		var strand := Content.strand(_strand_of(String(id)))
		var beats: Dictionary = strand["beats"]
		var written: Dictionary = {}
		for beat_id in beats:
			for choice in ((beats[beat_id] as Dictionary).get("choices", []) as Array):
				for f in (choice as Dictionary).get("flags", []):
					written[String(f)] = beat_id
		assert_eq(String((beats[String(strand["start"])] as Dictionary).get("requires_flag", "")), "",
			"%s's first step gates on nothing — there is nothing earlier" % id)
		var gated := 0
		for beat_id in beats:
			if String(beat_id) == String(strand["start"]):
				continue
			var flag := String((beats[beat_id] as Dictionary).get("requires_flag", ""))
			assert_ne(flag, "", "%s/%s reads a flag an earlier step set" % [strand["id"], beat_id])
			assert_true(written.has(flag),
				"%s/%s gates on %s, which a choice in this strand writes" % [strand["id"], beat_id, flag])
			gated += 1
		assert_true(gated >= 6, "%s's arc reads back on all six later steps (got %d)" % [id, gated])

func test_no_karim_nadia_robin_gate_can_freeze_its_arc() -> void:
	# THE INVARIANT THAT MAKES A MID-CHAIN GATE SAFE, and the reason this lane's forks exist: a strand
	# whose `cur` points at a beat the player can never satisfy is not a branch, it is a guest who
	# silently stops existing — `eligible_beats` skips them for the rest of the run and nothing at
	# runtime can show you that. So: EVERY CHOICE THAT ROUTES TO A BEAT SETS THAT BEAT'S FLAG.
	for id in KNR:
		var strand := Content.strand(_strand_of(String(id)))
		var beats: Dictionary = strand["beats"]
		for beat_id in beats:
			var flag := String((beats[beat_id] as Dictionary).get("requires_flag", ""))
			if flag == "":
				continue
			var routes := 0
			for from_id in beats:
				for choice in ((beats[from_id] as Dictionary).get("choices", []) as Array):
					var c: Dictionary = choice
					if String(c.get("next", "")) != String(beat_id):
						continue
					routes += 1
					assert_true((c.get("flags", []) as Array).has(flag),
						"%s/%s -> %s sets %s, so that gate can never strand them"
						% [strand["id"], from_id, beat_id, flag])
			assert_true(routes >= 1, "%s/%s is routed to by some choice" % [strand["id"], beat_id])

func test_each_karim_nadia_robin_arc_is_seven_beats_deep() -> void:
	# `eligible_beats` skips a strand whose `cur` has run out, so a two-beat chain freezes the arc on
	# step 3 however long the year is. Seven beats on the top-line path is what lets the ledger run to
	# the spring, which is exactly what the headless full-season test measures.
	for id in KNR:
		var strand_id := _strand_of(String(id))
		assert_true(_chain_length(strand_id) >= Season.LAST_STEP,
			"%s's beat chain carries all seven steps (got %d)" % [id, _chain_length(strand_id)])
		# Every beat is reachable from the start, so nothing written is dead content.
		var strand := Content.strand(strand_id)
		var seen: Dictionary = {String(strand["start"]): true}
		var frontier: Array = [String(strand["start"])]
		while not frontier.is_empty():
			var cur: String = frontier.pop_back()
			for choice in ((strand["beats"][cur] as Dictionary).get("choices", []) as Array):
				var next := String((choice as Dictionary).get("next", ""))
				if next != "" and not seen.has(next):
					seen[next] = true
					frontier.append(next)
		for beat_id in (strand["beats"] as Dictionary):
			assert_true(seen.has(String(beat_id)), "%s/%s is reachable from the first beat" % [strand_id, beat_id])

# ───── 11. the content lane: Lena · Jürgen · Mehmet, steps 2-7 (docs/09 §2.1/§2.2/§2.3) ─────
## The three oldest faces in the game — the credit thread, the Pfand dignity, and the parallel fight
## with the same landlord. Their plain trees ARE step 1, `lena_s2` shipped with the contract, and this
## section is the acceptance criteria for the other seventeen: every step written, reachable through
## the REAL selector, inside the authoring budget, speaking a basket it actually carries, leaving a
## flag somebody reads, and — the one that is specific to this lane — a beat chain whose seven
## `requires_flag` gates can never freeze the arc, because every choice of the beat before sets them.

const LJM := ["lena", "juergen", "mehmet"]

## docs/09 §4: 5-8 nodes · >= 1 d20 check · >= 1 gate LOCKED at day-one stats · a face change per node.
const LJM_MIN_NODES := 5
const LJM_MAX_NODES := 8
const LJM_MIN_FLAGS := 2
const LJM_MAX_FLAGS := 8

## Every (guest, step, tree id) this lane owes — steps 2..7, `lena_s2` included because it is the
## template the other sixteen copy and it has to keep passing the same bar.
func _ljm_steps() -> Array:
	var out: Array = []
	for id in LJM:
		for step in range(Season.FIRST_STEP + 1, Season.LAST_STEP + 1):
			out.append({"id": String(id), "step": step, "tree": Content.arc_tree_id(String(id), step)})
	return out

func _ljm_tree_flags(tree_id: String) -> Dictionary:
	var out: Dictionary = {}
	for node_id in (Content.DIALOGUES[tree_id]["nodes"] as Dictionary):
		for choice in ((Content.DIALOGUES[tree_id]["nodes"][node_id] as Dictionary)["choices"] as Array):
			for key in ["effects", "effects_success", "effects_fail"]:
				for f in (((choice as Dictionary).get(key, {}) as Dictionary).get("flags", []) as Array):
					out[String(f)] = node_id
	return out

## A flag is READ when a beat/vignette gates on it, the Manage screen prints it, or `FLAG_READERS`
## names the step that will consume it (docs/09 §4.10 — the three reader kinds, in that order).
func _ljm_flag_is_read(flag: String) -> bool:
	if Economy.FLAG_LABEL.has(flag) or Content.FLAG_READERS.has(flag):
		return true
	for strand in Content.STRANDS:
		for beat_id in (strand["beats"] as Dictionary):
			if String((strand["beats"][beat_id] as Dictionary).get("requires_flag", "")) == flag:
				return true
	for v in Content.VIGNETTES:
		if String(v.get("requires_flag", "")) == flag:
			return true
	return false

## The beat chain in top-line order, which is the order the ledger walks it in.
func _ljm_chain(strand_id: String) -> Array:
	var strand := Content.strand(strand_id)
	var out: Array = []
	var seen: Dictionary = {}
	var cur := String(strand.get("start", ""))
	while cur != "" and not seen.has(cur):
		seen[cur] = true
		out.append(cur)
		var beat := Content.beat(strand_id, cur)
		if beat.is_empty():
			break
		cur = String(((beat["choices"] as Array)[0] as Dictionary).get("next", ""))
	return out

func test_lena_juergen_mehmet_have_a_tree_for_every_remaining_step() -> void:
	# Ship steps IN ORDER (docs/06 §8.5 trap 2): a hole between `lena_s2` and `lena_a4` is not a gap
	# in the arc, it is a silent fallback to her step-1 tree, and the player hears her repeat herself.
	var s := _fresh()
	for row in _ljm_steps():
		var tree := String(row["tree"])
		assert_true(Content.DIALOGUES.has(tree), "%s step %d is written (%s)" % [row["id"], row["step"], tree])
		# And the SELECTOR is what has to find it — not the table. Tier 1, through the real call.
		_progress(s, String(row["id"]))["step"] = int(row["step"])
		assert_eq(Content.dialogue_id_for(String(row["id"]), s), tree,
			"%s on step %d resolves to %s" % [row["id"], row["step"], tree])
		assert_true(Content.arc_title_for_step(String(row["id"]), int(row["step"])).length() > 3,
			"%s step %d is named on the persona card" % [row["id"], row["step"]])

func test_the_reducer_opens_every_lena_juergen_mehmet_step_at_the_counter() -> void:
	# The selector is worth nothing if `talk_next` does not use it, so every one of the eighteen is
	# opened by the reducer with the guest actually standing there and a basket on the laminate.
	for row in _ljm_steps():
		var s := _at_the_counter(String(row["id"]), int(row["step"]), 3)
		assert_eq(String(s["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + String(row["tree"]),
			"talk_next opened %s" % row["tree"])
		assert_false((s["active"]["basket"] as Array).is_empty(),
			"%s has their order on the counter for %s" % [row["id"], row["tree"]])

func test_the_lena_juergen_mehmet_trees_keep_the_authoring_budget() -> void:
	var defaults: Dictionary = SpatiState.new_game({"seed": 1})["player"]["stats"]
	for row in _ljm_steps():
		var tree := String(row["tree"])
		var nodes: Dictionary = Content.DIALOGUES[tree]["nodes"]
		assert_true(nodes.size() >= LJM_MIN_NODES and nodes.size() <= LJM_MAX_NODES,
			"%s is %d-%d nodes (got %d)" % [tree, LJM_MIN_NODES, LJM_MAX_NODES, nodes.size()])
		# THE FACES HAVE TO BE ON DISK. `Content.portrait_asset` falls back to `_neutral`, so a node
		# that names a bust the art lane never drew does not fail — the bust simply never changes, and
		# nothing at runtime can show you that. `expressions` is the honest list (docs/09 §3), and for
		# this lane it is short: lena has three, mehmet three, juergen TWO.
		var on_disk: Array = Content.character(String(row["id"]))["expressions"]
		var faces: Dictionary = {}
		var checks := 0
		var locked_gates := 0
		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			assert_eq(String(node["speaker"]), String(row["id"]),
				"%s/%s is spoken by %s, so their basket answers for it" % [tree, node_id, row["id"]])
			var face := String(node["expression"])
			assert_true(on_disk.has(face), "%s/%s wears %s, which is on disk for %s" % [tree, node_id, face, row["id"]])
			faces[face] = true
			var choices: Array = node["choices"]
			assert_false((choices[0] as Dictionary).has("requires"),
				"%s/%s: choice 0 is never gated" % [tree, node_id])
			for choice in choices:
				var c: Dictionary = choice
				var check: Dictionary = c.get("check", {})
				if not check.is_empty():
					checks += 1
					var dc := int(check["dc"])
					var chance := Talk.success_chance(dc, Rules.modifier(int(defaults[String(check["stat"])])))
					assert_true(chance >= 0.4 and chance <= 0.7,
						"%s/%s: %d%% is a coin, not a tax" % [tree, node_id, int(round(chance * 100.0))])
				var requires: Dictionary = c.get("requires", {})
				if not requires.is_empty():
					var minimum := int(requires["min"])
					assert_true(minimum > int(defaults[String(requires["stat"])]),
						"%s/%s: %s %d is LOCKED on night one" % [tree, node_id, requires["stat"], minimum])
					assert_true(minimum >= 11 and minimum <= 15, "%s/%s: a min of %d is in 11..15" % [tree, node_id, minimum])
					locked_gates += 1
		assert_true(checks >= 1, "%s rolls at least one d20 (got %d)" % [tree, checks])
		assert_true(locked_gates >= 1, "%s locks at least one door (got %d)" % [tree, locked_gates])
		assert_true(faces.size() >= mini(3, on_disk.size()),
			"%s wears every face %s has (got %s of %s)" % [tree, row["id"], str(faces.keys()), str(on_disk)])
		var spent := _ljm_tree_flags(tree).size()
		assert_true(spent >= LJM_MIN_FLAGS and spent <= LJM_MAX_FLAGS,
			"%s leaves %d-%d marks (got %d)" % [tree, LJM_MIN_FLAGS, LJM_MAX_FLAGS, spent])

func test_every_lena_juergen_mehmet_step_speaks_the_order_first() -> void:
	# docs/09 §4: the order is woven into the FIRST node, so the basket landing on the counter is the
	# answer to something the guest actually said — and it is said with the TOKENS, never a brand name
	# typed into a line, or a rename in brands.gd rewrites the fiction instead of the table.
	for row in _ljm_steps():
		var graph: Dictionary = Content.DIALOGUES[String(row["tree"])]
		var opening := ""
		for line in ((graph["nodes"][String(graph["start"])] as Dictionary)["lines"] as Array):
			opening += String(line) + " "
		var spoke := false
		for entry in Content.basket_for(String(row["id"])):
			var sku_id := String((entry as Dictionary)["sku"])
			for token in ["{qty.%s}", "{brand.%s}", "{logo.%s}"]:
				if opening.contains(token % sku_id):
					spoke = true
		assert_true(spoke, "%s opens on the order, in tokens" % row["tree"])

func test_no_token_in_a_lena_juergen_mehmet_step_survives_to_the_screen() -> void:
	# Never trust a name, assert against the read-model (docs/06 §8.5 trap 1). `_place_basket` cuts to
	# four lines, and a `{brand.*}` whose row was cut does not fail — it PRINTS, at 03:00, on a counter.
	# Lena's card carries five rows, so her trees may only speak rows 1-4: mate, schrippe, tobacco, papers.
	var any := RegEx.create_from_string("\\{([^}]*)\\}")
	for row in _ljm_steps():
		var s := _at_the_counter(String(row["id"]), int(row["step"]), 3)
		var steps := 0
		while Talk.is_open(s) and steps < 40:
			steps += 1
			var talk: Dictionary = Rules.view(s)["talk"]
			var shown: Array = (talk["lines"] as Array).duplicate()
			for choice in (talk["choices"] as Array):
				shown.append(String((choice as Dictionary)["label"]))
			for text in shown:
				for m in any.search_all(String(text)):
					fail("%s/%s: %s reached the box unsubstituted — %s"
						% [row["tree"], String(s["talk"]["node"]), m.get_string(0), String(text)])
			var advanced := Rules.apply(s, {"type": "talk_advance"})
			s = advanced if not is_same(advanced, s) else Rules.apply(s, {"type": "talk_choose", "choice": 0})
		assert_false(Talk.is_open(s), "%s closes on the top line in %d steps" % [row["tree"], steps])
		# And the encounter moved the ledger, which is the whole point of writing the step.
		assert_eq(int(_progress(s, String(row["id"]))["step"]), mini(int(row["step"]) + 1, Season.LAST_STEP),
			"%s played, so the arc is on the next step" % row["tree"])

func test_every_flag_lena_juergen_mehmet_set_is_read_by_somebody() -> void:
	# "A flag nobody reads is a lie in the save file." Eighteen trees is a lot of branch, and a branch
	# nothing consumes is a branch that never happens — invisible at runtime, and invisible here too
	# unless it is asserted.
	for row in _ljm_steps():
		var flags := _ljm_tree_flags(String(row["tree"]))
		for f in flags:
			assert_true(_ljm_flag_is_read(String(f)),
				"%s sets %s (at %s) and somebody reads it" % [row["tree"], f, flags[f]])

func test_every_lena_juergen_mehmet_step_reads_an_earlier_flag() -> void:
	# THE LANE'S OWN RULE: a step has to branch on what the player did, not merely happen after it.
	# A dialogue tree cannot gate on a flag (choices carry `check`/`requires` only), so the read lives
	# where the engine already has one — the BEAT that schedules the step. Every beat from step 2 on
	# carries a `requires_flag`, and the flag it names is set by a beat EARLIER in the same chain.
	for id in LJM:
		var strand_id := _strand_of(String(id))
		var chain := _ljm_chain(strand_id)
		assert_true(chain.size() >= Season.LAST_STEP, "%s has a beat per step (got %d)" % [id, chain.size()])
		var set_so_far: Dictionary = {}
		for i in chain.size():
			var beat := Content.beat(strand_id, String(chain[i]))
			var gate := String(beat.get("requires_flag", ""))
			if i == 0:
				assert_eq(gate, "", "%s/%s is step 1 and gates on nothing" % [strand_id, chain[i]])
			else:
				assert_ne(gate, "", "%s/%s (step %d) reads a flag" % [strand_id, chain[i], i + 1])
				assert_true(set_so_far.has(gate),
					"%s/%s reads %s, which %s sets" % [strand_id, chain[i], gate, set_so_far.get(gate, "nobody")])
			for choice in (beat["choices"] as Array):
				for f in ((choice as Dictionary).get("flags", []) as Array):
					if not set_so_far.has(String(f)):
						set_so_far[String(f)] = String(chain[i])

func test_no_lena_juergen_mehmet_gate_can_freeze_its_arc() -> void:
	# The failure this exists to prevent: `eligible_beats` SKIPS a strand whose current beat wants a
	# flag the player never set, and nothing else can move `cur` — so the guest is never scheduled
	# again and their arc dies silently in the autumn. The rule that makes the gates safe is that
	# EVERY choice of the beat before sets the flag, not just the top line the AutoPlayer takes.
	for id in LJM:
		var strand_id := _strand_of(String(id))
		var chain := _ljm_chain(strand_id)
		for i in range(1, chain.size()):
			var gate := String(Content.beat(strand_id, String(chain[i])).get("requires_flag", ""))
			if gate == "":
				continue
			var guaranteed := false
			for j in range(0, i):
				var choices: Array = Content.beat(strand_id, String(chain[j]))["choices"]
				var all_set := not choices.is_empty()
				for choice in choices:
					if not ((choice as Dictionary).get("flags", []) as Array).has(gate):
						all_set = false
				if all_set:
					guaranteed = true
			assert_true(guaranteed,
				"%s/%s gates on %s, which an EARLIER beat sets on every branch" % [strand_id, chain[i], gate])
		# A gate flag is a kind-1 reader, so declaring it in FLAG_READERS as well would be a second,
		# stale answer to "who reads this?" — `test_flags.gd::test_no_declared_reader_is_dead` fails
		# the build for it, and this says the same thing where the lane can see it.
		for beat_id in (Content.strand(strand_id)["beats"] as Dictionary):
			var f := String((Content.strand(strand_id)["beats"][beat_id] as Dictionary).get("requires_flag", ""))
			if f != "":
				assert_false(Content.FLAG_READERS.has(f), "%s is gated, so it has no FLAG_READERS row" % f)

func test_each_lena_juergen_mehmet_arc_is_seven_beats_deep() -> void:
	# The hard blocker the contract named: ten of eleven strands shipped with two or three beats, and
	# a strand whose `cur` runs out freezes on step 3 however long the year is. Seven beats on the
	# top-line path is what carries the ledger to the spring — and every beat has to be reachable, or
	# it is content nobody will ever see.
	for id in LJM:
		var strand_id := _strand_of(String(id))
		assert_true(_chain_length(strand_id) >= Season.LAST_STEP,
			"%s's chain carries all seven steps (got %d)" % [id, _chain_length(strand_id)])
		var strand := Content.strand(strand_id)
		var seen: Dictionary = {String(strand["start"]): true}
		var frontier: Array = [String(strand["start"])]
		while not frontier.is_empty():
			var cur: String = frontier.pop_back()
			for choice in ((strand["beats"][cur] as Dictionary).get("choices", []) as Array):
				var next := String((choice as Dictionary).get("next", ""))
				if next != "" and not seen.has(next):
					seen[next] = true
					frontier.append(next)
		for beat_id in (strand["beats"] as Dictionary):
			assert_true(seen.has(String(beat_id)), "%s/%s is reachable from the first beat" % [strand_id, beat_id])

func test_lena_juergen_and_mehmet_reach_the_spring_in_a_headless_year() -> void:
	# The end-to-end proof, on the same harness the contract ships: a full year played on the top line
	# puts all three on step 7, with the ledger recording a real season for each of them. This is what
	# "make them play" means — not that the trees exist, but that the calendar reaches them.
	var final := _the_year()
	for id in LJM:
		var p := _progress(final, String(id))
		assert_eq(int(p["step"]), Season.LAST_STEP,
			"%s's seven beats carried the arc to step 7 (got %d)" % [id, int(p["step"])])
		assert_true(SEASONS.has(String(p["season_seen"])), "%s's ledger says which season last saw them" % id)
		assert_ne(String(p["outcome"]), "", "%s's arc recorded an outcome for the epilogue" % id)

# ══════════ 12. THE INTEGRATOR'S SWEEP — the whole cast, every step, one year ══════════
## Four content lanes wrote sixty-six step trees into one `dialogues.gd` and seven-beat chains into one
## `story.gd`, each with acceptance tests over its OWN three guests. All of those pass. This section
## asserts the same properties over the CAST AS A WHOLE, because that is the only place a cross-lane
## failure can surface: a tree id one letter out (the selector drops silently to the parade), a face
## the art lane never drew for THAT guest, a beat gated on a flag a neighbouring lane renamed, or two
## story guests in one night now that fourteen strands compete for a single slot.
##
## Everything here is DERIVED FROM THE REGISTRY — `GUESTS` × `Season.STEPS`, `Content.STRANDS` — never
## from a list of what some lane happened to write. A twelfth persona card joins this sweep the day its
## card lands, with no edit here; a lane that deletes a tree fails here rather than only in its own section.

## docs/09 §4, applied to all seventy-seven rather than to one lane's eighteen.
const SWEEP_MIN_NODES := 5
const SWEEP_MAX_NODES := 8
## A tree should change the face it speaks with — but Jürgen was drawn with two expressions and a tree
## of his can wear no more than two, so the bar is min(3, what that guest HAS), never a flat three.
const SWEEP_FACES := 3

## The seventy-seven rows the cast can be in: every guest on every one of their seven steps, paired
## with the tree the SELECTOR actually hands them. Resolved through `Content.dialogue_id_for` against a
## real state rather than rebuilt from the convention — this has to measure what the reducer will do,
## not what the id says it should.
func _cast_steps() -> Array:
	var s := _fresh()
	var out: Array = []
	for id in GUESTS:
		for step in range(Season.FIRST_STEP, Season.LAST_STEP + 1):
			_progress(s, String(id))["step"] = step
			out.append({"id": String(id), "step": step, "tree": Content.dialogue_id_for(String(id), s)})
	return out

func test_every_guest_has_a_tree_on_every_step_and_none_is_the_parade() -> void:
	# The failure here is SILENT by construction: `dialogue_id_for` falls back rather than throwing, so
	# `karim_a4` misspelt as `karim_a5` does not crash — Karim simply opens his summer tree in the
	# autumn and repeats himself, and the lane's own test (which asks for `karim_a5`) still passes.
	var rows := _cast_steps()
	assert_eq(rows.size(), GUESTS.size() * Season.LAST_STEP, "eleven guests x seven steps")
	var trees: Dictionary = {}
	for row in rows:
		var tree := String(row["tree"])
		var where := "%s step %d" % [row["id"], int(row["step"])]
		assert_ne(tree, Content.DIALOGUE_FALLBACK, "%s does not fall through to the parade" % where)
		assert_ne(tree, Content.DIALOGUE_MINOR, "%s is not the minor's one-off either" % where)
		assert_true(Content.DIALOGUES.has(tree), "%s opens a written tree (%s)" % [where, tree])
		assert_false(trees.has(tree), "%s: %s is one step's tree, not two — %s opens it too"
			% [where, tree, trees.get(tree, "")])
		trees[tree] = where
		# The convention, checked against the SELECTOR's answer rather than against itself: step 1 is
		# the plain tree (tier 2, which IS step 1), every later step its own (tier 1).
		if int(row["step"]) == Season.FIRST_STEP:
			assert_eq(tree, String(row["id"]), "%s is the plain tree — step 1 IS it" % where)
		else:
			assert_eq(tree, Content.arc_tree_id(String(row["id"]), int(row["step"])),
				"%s wears the id convention" % where)
	assert_eq(trees.size(), GUESTS.size() * Season.LAST_STEP, "seventy-seven distinct trees, one a step")
	# …and nothing ORPHANED. A tree whose id no (guest, step) can name is content nobody will ever
	# reach: `achim_t`, `lena_a2` (an autumn letter on a summer step), `robin_p8`.
	for id in Content.DIALOGUES:
		var tree := String(id)
		if tree == Content.DIALOGUE_FALLBACK or tree == Content.DIALOGUE_MINOR:
			continue
		assert_true(trees.has(tree), "%s is reachable — some guest's step opens it" % tree)

func test_every_tree_the_cast_can_open_keeps_the_authoring_budget() -> void:
	var defaults: Dictionary = _fresh()["player"]["stats"]
	for row in _cast_steps():
		var id := String(row["id"])
		var tree := String(row["tree"])
		var nodes: Dictionary = Content.DIALOGUES[tree]["nodes"]
		assert_true(nodes.size() >= SWEEP_MIN_NODES and nodes.size() <= SWEEP_MAX_NODES,
			"%s is %d-%d nodes (got %d)" % [tree, SWEEP_MIN_NODES, SWEEP_MAX_NODES, nodes.size()])
		var checks := 0
		var locked := 0
		var faces: Dictionary = {}
		var wearable: Array = Content.character(id)["expressions"]
		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			var expression := String(node.get("expression", "neutral"))
			faces[expression] = true
			# THE QUIET ONE, and the reason this sweep exists. `Content.portrait_asset` falls back to
			# `_neutral` for a face the guest does not have, so a node naming `juergen_tired` does not
			# fail — the bust simply never changes and the performance the lane wrote is invisible.
			# test_content.gd's vocabulary check cannot see it: `tired` IS one of the frozen six. It is
			# just not one of HIS. (This already shipped once, in the contract's own `lena_s2`.)
			assert_true(wearable.has(expression),
				"%s/%s: %s is a face %s actually has (%s)" % [tree, node_id, expression, id, str(wearable)])
			assert_true(Assets.is_real(Content.portrait_asset(id, "", expression)),
				"%s/%s: %s is on disk, not a placeholder" % [tree, node_id, expression])
			for choice in (node["choices"] as Array):
				if not (choice as Dictionary).get("check", {}).is_empty():
					checks += 1
				var requires: Dictionary = (choice as Dictionary).get("requires", {})
				if not requires.is_empty() and int(requires["min"]) > int(defaults[String(requires["stat"])]):
					locked += 1
		# The DC band and the coin test are global already (test_content.gd); what is NOT global is that
		# every step has a roll and a door at all — a lane can ship a tree of pure prose and pass.
		assert_true(checks >= 1, "%s rolls at least one d20 (got %d)" % [tree, checks])
		assert_true(locked >= 1, "%s locks at least one door at day-one stats (got %d)" % [tree, locked])
		assert_true(faces.size() >= mini(SWEEP_FACES, wearable.size()),
			"%s wears %d of %s's %d faces" % [tree, faces.size(), id, wearable.size()])

func test_every_step_opens_by_saying_what_the_guest_came_in_for() -> void:
	# docs/09 §4: the order is spoken in the FIRST node, so the basket landing on the counter is the
	# answer to something the guest actually said. Global, because the register seeds `active.basket`
	# from the persona card whatever step they are on — a step-5 tree that opens on plot leaves a guest
	# standing over an order nobody placed.
	for row in _cast_steps():
		var id := String(row["id"])
		var graph: Dictionary = Content.DIALOGUES[String(row["tree"])]
		var opening := ""
		for line in (graph["nodes"][String(graph["start"])]["lines"] as Array):
			opening += String(line) + " "
		var named := ""
		for entry in Content.basket_for(id):
			var sku_id := String((entry as Dictionary)["sku"])
			var sku_name := String(Content.sku(sku_id).get("name", ""))
			# A token OR the plain noun: Nadia's rows are deliberately token-free (her coffee is
			# upgrade-locked and her tobacco line is cut by the basket cap, so a `{qty.*}` on either
			# would print onto the counter at 03:00 rather than fail), and she still names her order.
			if opening.contains("{qty.%s}" % sku_id) or opening.contains("{brand.%s}" % sku_id) \
					or opening.contains("{logo.%s}" % sku_id) \
					or (sku_name != "" and opening.to_lower().contains(sku_name.to_lower())):
				named = sku_id
		assert_ne(named, "", "%s opens by naming something off %s's basket" % [row["tree"], id])

func test_every_step_of_every_arc_plays_end_to_end_at_the_counter() -> void:
	# "Make them play", as a test. Not that the tree exists (§12.1) and not that it is well-shaped
	# (§12.2), but that the REDUCER opens it, the REAL read-model renders it with every token
	# substituted, the top line reaches the door, and the ledger moves when it closes. All seventy-seven.
	var any := RegEx.create_from_string("\\{([^}]*)\\}")
	for row in _cast_steps():
		var id := String(row["id"])
		var step := int(row["step"])
		var s := _at_the_counter(id, step, 5)
		assert_eq(String(s["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + String(row["tree"]),
			"the reducer OPENED %s, not merely the selector naming it" % row["tree"])
		var walked := 0
		while Talk.is_open(s) and walked < 60:
			walked += 1
			var talk: Dictionary = Rules.view(s)["talk"]
			var shown: Array = (talk["lines"] as Array).duplicate()
			for choice in (talk["choices"] as Array):
				shown.append(String((choice as Dictionary)["label"]))
			for text in shown:
				for m in any.search_all(String(text)):
					fail("%s/%s: %s reached the box unsubstituted — %s"
						% [row["tree"], String(s["talk"]["node"]), m.get_string(0), String(text)])
			var advanced := Rules.apply(s, {"type": "talk_advance"})
			s = advanced if not is_same(advanced, s) else Rules.apply(s, {"type": "talk_choose", "choice": 0})
		assert_false(Talk.is_open(s), "%s reaches the door on the top line (%d steps)" % [row["tree"], walked])
		assert_eq(int(_progress(s, id)["step"]), mini(step + 1, Season.LAST_STEP),
			"%s played, so %s's ledger moved on" % [row["tree"], id])

func test_no_gate_anywhere_can_freeze_a_strand() -> void:
	# `eligible_beats` DROPS a strand whose current beat wants a flag the player never set, and nothing
	# else can move `cur` — so a gate reachable down a branch that never sets it is not a shorter arc,
	# it is a guest who silently stops existing for the rest of the run. Ten of these gates landed in one
	# pass, written by four lanes who could not see each other's flags, so the property is asserted
	# EXHAUSTIVELY rather than by inspection: walk every path through every strand, carrying the flags
	# that path actually set, and assert that each beat's `requires_flag` is already held on arrival.
	#
	# That is deliberately weaker than "the beat before it sets the flag". Herr Bley's step 5 gates on
	# `bley_talks`, which his step 2 wrote on both its branches — a step reading three steps back is
	# better writing, not a bug, and only the walk can tell the two apart. It is also strictly stronger
	# than walking the top line, which is the next test: this one walks the branches nobody playtests.
	#
	# Only a TERMINAL beat may be left unreachable. That is the spring, where an arc is allowed to fork
	# on whether you ever listened (`bley/b_patron` on `bley_tip`, `schulz/sc_corner`, `achim/a_elder`),
	# and it is not a freeze: step 6 has already recorded an outcome and the step-7 TREE still plays.
	for strand in Content.STRANDS:
		var strand_id := String(strand["id"])
		var beats: Dictionary = strand["beats"]
		# Only the flags this strand GATES on are worth carrying, which is what keeps the path space
		# walkable: at most 2^gates x beats states instead of one per combination of branches.
		var watched: Array = []
		for beat_id in beats:
			var f := String((beats[beat_id] as Dictionary).get("requires_flag", ""))
			if f != "" and not watched.has(f):
				watched.append(f)
		var frontier: Array = [{"beat": String(strand["start"]), "held": [] as Array}]
		var seen: Dictionary = {String(strand["start"]) + "|": true}
		var guard := 0
		while not frontier.is_empty() and guard < 20000:
			guard += 1
			var node: Dictionary = frontier.pop_back()
			var cur := String(node["beat"])
			var held: Array = node["held"]
			var beat: Dictionary = beats[cur]
			var terminal := true
			for choice in (beat["choices"] as Array):
				if String((choice as Dictionary).get("next", "")) != "" 						or String((choice as Dictionary).get("next_fail", "")) != "":
					terminal = false
			var gate := String(beat.get("requires_flag", ""))
			if gate != "" and not held.has(gate):
				# The strand stops dead here. Legal only at the spring fork; anywhere else it is a guest
				# who will never be scheduled again, with no symptom the player or a log could show.
				assert_true(terminal,
					"%s/%s wants %s and this path arrives without it — the strand freezes mid-arc (held: %s)"
					% [strand_id, cur, gate, str(held)])
				continue
			for choice in (beat["choices"] as Array):
				var c: Dictionary = choice
				var next_held: Array = held.duplicate()
				for f in (c.get("flags", []) as Array):
					if watched.has(String(f)) and not next_held.has(String(f)):
						next_held.append(String(f))
				next_held.sort()
				for key in ["next", "next_fail"]:
					var next := String(c.get(key, ""))
					if next == "":
						continue
					assert_true(beats.has(next), "%s/%s -> %s is a written beat" % [strand_id, cur, next])
					var sig := next + "|" + "/".join(next_held)
					if seen.has(sig):
						continue
					seen[sig] = true
					frontier.append({"beat": next, "held": next_held})
		assert_true(guard < 20000, "%s's beat graph is walkable, not a cycle" % strand_id)

func test_the_top_line_carries_every_strand_to_its_end() -> void:
	# The headless AutoPlayer and the "just take the first option" player are the same player, and the
	# only one every strand MUST serve. Walk the top line carrying the flags it actually sets and
	# assert no gate along the way is unmet — the same drop `eligible_beats` would make in silence.
	for strand in Content.STRANDS:
		var strand_id := String(strand["id"])
		var beats: Dictionary = strand["beats"]
		var flags: Dictionary = {}
		var cur := String(strand["start"])
		var seen: Dictionary = {}
		while cur != "" and not seen.has(cur):
			seen[cur] = true
			var beat: Dictionary = beats[cur]
			var flag := String(beat.get("requires_flag", ""))
			assert_true(flag == "" or flags.has(flag),
				"%s/%s wants %s, which the top line has not set by the time it arrives" % [strand_id, cur, flag])
			var choice: Dictionary = (beat["choices"] as Array)[0]
			for f in (choice.get("flags", []) as Array):
				flags[String(f)] = true
			cur = String(choice.get("next", ""))
		assert_true(seen.size() >= 1, "%s has a chain at all" % strand_id)

func test_every_cast_strand_is_seven_beats_deep_with_nothing_orphaned() -> void:
	# The contract's hard blocker, closed and kept closed: ten of the eleven strands shipped with two
	# or three beats, and a strand whose `cur` runs out freezes on step 3 however long the year is.
	for id in GUESTS:
		var strand_id := _strand_of(String(id))
		var strand := Content.strand(strand_id)
		assert_true(_chain_length(strand_id) >= Season.LAST_STEP,
			"%s's top line runs all seven steps (got %d)" % [id, _chain_length(strand_id)])
		var seen: Dictionary = {String(strand["start"]): true}
		var frontier: Array = [String(strand["start"])]
		while not frontier.is_empty():
			var cur: String = frontier.pop_back()
			for choice in ((strand["beats"][cur] as Dictionary).get("choices", []) as Array):
				for key in ["next", "next_fail"]:
					var next := String((choice as Dictionary).get(key, ""))
					if next != "" and not seen.has(next):
						seen[next] = true
						frontier.append(next)
		for beat_id in (strand["beats"] as Dictionary):
			assert_true(seen.has(String(beat_id)), "%s/%s is reachable from the first beat" % [strand_id, beat_id])

func test_a_headless_four_season_year_reaches_every_guests_spring() -> void:
	# THE ACCEPTANCE TEST FOR THE WHOLE PASS. Not "the trees exist" (§12.1) and not "the chains are
	# seven long" (§12.7) but: played headless on the top line, does the CALENDAR actually reach all
	# eleven arcs, one guest a night, without the save drifting? Every night of the year is asserted
	# inside `_play_story_season` — one story arrival scheduled, one named face at the counter, no face
	# twice, at most one step per strand, no step more than a season early, and a byte-stable save.
	var final := _the_year()
	assert_eq(String(final["phase"]), "end", "the year ran to the end of the calendar")
	assert_eq(Season.of_state(final), "spring", "and ended in the spring")
	assert_true(int(final["day"]) > FULL_SEASON_DAYS, "all four seasons were played, not just the summer")
	for id in GUESTS:
		var p := _progress(final, String(id))
		var person := String(Content.character(String(id))["name"])
		assert_eq(int(p["step"]), Season.LAST_STEP,
			"%s played all seven steps (got %d)" % [person, int(p["step"])])
		assert_ne(String(p["outcome"]), "", "%s's arc recorded an outcome for the tapestry" % person)
		assert_true(SEASONS.has(String(p["season_seen"])),
			"%s's ledger names the season that last saw them (%s)" % [person, p["season_seen"]])
		assert_true((final["story"]["met"] as Array).has(String(Content.strand(_strand_of(String(id)))["character"])),
			"%s is in `met`, so the Finale can compose them" % person)
	assert_eq(SpatiState.to_json(SpatiState.from_json(SpatiState.to_json(final))), SpatiState.to_json(final),
		"and the finished year round-trips byte for byte")
