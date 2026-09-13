extends "res://tests/TestCase.gd"
## The one design change (engine-api §4): beats walk up to the counter. They must be scheduled as
## arrivals, gate correctly, block the serve while pending, apply their choice, and compose a finale.

func _fresh(seed_value: int = 3) -> Dictionary:
	return SpatiState.new_game({"seed": seed_value, "auto_take_next": true})  # beat tests: the cast steps up on tick

## Tick until someone is mid-conversation (or the night ends).
func _tick_to_dialogue(s0: Dictionary, dt_ms: int = 500) -> Dictionary:
	var s := s0
	var guard := 0
	while s["phase"] == "night" and guard < 2000:
		guard += 1
		if not (s["story"]["pending"] as Dictionary).is_empty() or s["story"]["pending_vignette"] != "":
			return s
		s = Rules.tick(s, dt_ms)
		var active: Dictionary = s["active"]
		if not active.is_empty() and active.get("beat_id", "") == "" and active.get("vignette_id", "") == "":
			s = Rules.apply(s, {"type": "skip_active"})  # clear the counter so the cast can reach it
	return s

func test_day_one_schedules_the_main_intro() -> void:
	var s := Rules.apply(_fresh(), {"type": "open_night"})
	var story_arrivals := 0
	var intro := false
	for a in s["arrivals"]:
		if a["beat_id"] != "":
			story_arrivals += 1
			if a["beat_id"] == "intro":
				intro = true
	assert_eq(story_arrivals, 1, "only the main intro is eligible on day 1")
	assert_true(intro, "the intro beat is on tonight's schedule")

func test_story_arrivals_are_capped() -> void:
	var s := _fresh()
	s["day"] = 20
	s["weekday"] = 5
	s["reputation"]["kiez"] = 70.0
	s = Rules.apply(s, {"type": "open_night"})
	var story_arrivals := 0
	for a in s["arrivals"]:
		if a["beat_id"] != "":
			story_arrivals += 1
	# 2026-09-14: the cap is config (`story_slots`, testbuild default 2)  the night must fill it
	# when enough beats are eligible, and never exceed it.
	assert_eq(story_arrivals, StoryFlow.story_slots(s), "the night fills the configured story slots (docs/06 section 8)")

func test_gating_holds_beats_back() -> void:
	var s := _fresh()
	var eligible := StoryFlow.eligible_beats(s)
	assert_eq(eligible.size(), 1, "day 1: only the intro")
	# Walk the main strand to the offer beat; it must still wait for day 6.
	s["story"]["strands"]["main"]["cur"] = "offer"
	s["day"] = 5
	for e in StoryFlow.eligible_beats(s):
		assert_ne(e["beat"]["id"], "offer", "day 5 is too early for the offer")
	s["day"] = 7
	var day7: Array = []
	for e in StoryFlow.eligible_beats(s):
		day7.append(e["beat"]["id"])
	assert_true(day7.has("offer"), "Frau Brandt's offer unlocks on day 6")
	assert_false(day7.has("climax"), "the climax waits for day 22")
	assert_eq(StoryFlow.eligible_beats(s)[0]["strand"]["id"], "main", "main arc sorts first (priority 100)")

func test_beat_fires_at_the_counter_and_blocks_the_serve() -> void:
	var s := _tick_to_dialogue(Rules.apply(_fresh(), {"type": "open_night"}))
	assert_false((s["story"]["pending"] as Dictionary).is_empty(), "a beat became pending at the counter")
	assert_eq(s["story"]["pending"]["beat"], "intro", "it is the intro beat")
	assert_false((s["active"] as Dictionary).is_empty(), "the speaker is the active customer")
	assert_eq(s["active"]["beat_id"], "intro", "the active customer carries the beat")
	var dialogue: Dictionary = Rules.view(s)["dialogue"]
	assert_eq(dialogue["kind"], "beat", "view exposes the dialogue")
	assert_true((dialogue["lines"] as Array).size() >= 1, "with lines")
	assert_eq(dialogue["portrait"], "char/you", "and a portrait id")
	# While pending, the counter is blocked.
	assert_true(is_same(Rules.apply(s, {"type": "serve_active", "give": []}), s), "no serving mid-beat")
	assert_true(is_same(Rules.apply(s, {"type": "skip_active"}), s), "no waving them off mid-beat")
	var types: Array = []
	for a in Rules.legal_actions(s):
		types.append(a["type"])
	assert_true(types.has("resolve_beat"), "only resolve_beat is offered")
	assert_false(types.has("serve_active"), "serve is not offered while pending")

func test_resolving_keeps_the_customer_for_the_serve() -> void:
	var s := _tick_to_dialogue(Rules.apply(_fresh(), {"type": "open_night"}))
	var customer_id := int(s["active"]["id"])
	s = Rules.apply(s, {"type": "resolve_beat", "choice": 0})
	assert_true((s["story"]["pending"] as Dictionary).is_empty(), "pending cleared")
	assert_eq(int(s["active"]["id"]), customer_id, "the same person is still at the counter")
	assert_eq(s["story"]["strands"]["main"]["cur"], "offer", "the strand advanced to the next beat")
	assert_eq(int(s["story"]["strands"]["main"]["last_day"]), 1, "one beat per strand per day")
	assert_true((s["story"]["met"] as Array).has("Onkel Cem"), "met records the strand's character")
	s = Rules.apply(s, {"type": "serve_active", "give": []})
	assert_eq(int(s["tally"]["sales"]), 1, "the ordinary serve follows the beat")

func test_choice_effects_apply() -> void:
	var s := _fresh()
	s["story"]["pending"] = {"strand": "lena", "beat": "l_credit"}
	s["story"]["strands"]["lena"]["cur"] = "l_credit"
	s["active"] = SpatiState.new_customer(1, "student", "mate", 10000, "lena", "l_credit")
	var cash_before := float(s["cash"])
	var kiez_before := float(s["reputation"]["kiez"])
	s = Rules.apply(s, {"type": "resolve_beat", "choice": 0})  # "Pay me when you can" — cash -3, kiez +1
	assert_almost(float(s["cash"]), cash_before - 3.0, 0.001, "the tab costs cash")
	assert_almost(float(s["reputation"]["kiez"]), kiez_before + 1.0, 0.001, "and buys trust")
	assert_true((s["story"]["flags"] as Array).has("lena_credit"), "the flag is set")
	assert_eq(s["story"]["strands"]["lena"]["cur"], "l_show", "branches to the named next beat")
	assert_eq(s["active"]["expression"], "warm", "a kind answer warms the face")

func test_vignette_rides_a_quiet_night() -> void:
	var s := _fresh(11)
	# Day 3 with every strand parked: no cast beat is due, so the night may carry a one-off.
	s["day"] = 3
	s["weekday"] = 2
	for id in (s["story"]["strands"] as Dictionary).keys():
		s["story"]["strands"][id]["cur"] = ""
	s = Rules.apply(s, {"type": "open_night"})
	var vignettes := 0
	for a in s["arrivals"]:
		if a["vignette_id"] != "":
			vignettes += 1
	assert_eq(vignettes, 1, "exactly one vignette rides an ordinary arrival")
	s = _tick_to_dialogue(s)
	assert_ne(s["story"]["pending_vignette"], "", "it becomes pending at the counter")
	var id: String = s["story"]["pending_vignette"]
	assert_eq(Rules.view(s)["dialogue"]["kind"], "vignette", "view says vignette")
	s = Rules.apply(s, {"type": "resolve_vignette", "choice": 0})
	assert_eq(s["story"]["pending_vignette"], "", "resolved")
	assert_true((s["story"]["seen_vignettes"] as Array).has(id), "and never repeats")

func test_finale_composes_the_tapestry() -> void:
	var s := _fresh()
	s["reputation"]["kiez"] = 80.0
	s["reputation"]["integrity"] = 70.0
	s["story"]["main_outcome"] = "stand"
	s["story"]["met"] = ["Lena", "Mehmet"]
	s["story"]["strands"]["lena"]["outcome"] = "found_voice"
	s["story"]["strands"]["mehmet"]["outcome"] = "reconciled"
	s["story"]["strands"]["nadia"]["outcome"] = "held"  # never met — must not appear
	var finale := Finale.resolve_finale(s)
	assert_eq(finale["main"], "institution", "kiez 80 + stood = An Institution")
	assert_eq((finale["epilogues"] as Array).size(), 2, "one epilogue per met, resolved character")
	assert_eq(finale["epilogues"][0]["character"], "Lena", "in registry order")
	assert_true(str(finale["epilogues"][0]["line"]).length() > 10, "with a written line")

func test_endings_resolve_from_the_meters() -> void:
	var s := _fresh()
	s["cash"] = -10.0
	assert_eq(Finale.main_ending(s), "pushedout", "broke = pushed out")
	s["cash"] = 500.0
	s["reputation"]["integrity"] = 20.0
	assert_eq(Finale.main_ending(s), "soldout", "low integrity = sold out")
	s["reputation"]["integrity"] = 80.0
	s["reputation"]["kiez"] = 50.0
	assert_eq(Finale.main_ending(s), "held", "middling = held the line")
	s["story"]["main_outcome"] = "sell"
	assert_eq(Finale.main_ending(s), "soldout", "selling up = sold out")
