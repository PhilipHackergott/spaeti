extends "res://tests/TestCase.gd"
## docs/06 §6 — the slice's core: guests queue, you take them one at a time, and the conversation is
## a D&D-shaped tree whose choices roll or gate against the six stats. Everything here must be pure
## and seeded: a night replays from {config, seed, actions}, every d20 included.

const REGULARS := ["lena", "juergen", "mehmet"]

func _fresh(seed_value: int = 5) -> Dictionary:
	return SpatiState.new_game({"seed": seed_value})

## A night with one named guest already at the counter and the conversation open.
func _talking(character_id: String, seed_value: int = 5, want: String = "mate") -> Dictionary:
	var s := _fresh(seed_value)
	s["phase"] = "night"
	var archetype_id := String(Content.character(character_id).get("archetype_id", "regular"))
	s["active"] = SpatiState.new_customer(1, archetype_id, want, 10000, character_id)
	return Rules.apply(s, {"type": "talk_next"})

func _types(actions: Array) -> Array:
	var out: Array = []
	for a in actions:
		out.append(a["type"])
	return out

# ───────────────────────────── §1 the six stats ─────────────────────────────

func test_a_new_game_rolls_up_the_shopkeeper() -> void:
	var stats: Dictionary = _fresh()["player"]["stats"]
	assert_eq(stats.size(), 6, "six stats")
	for stat in Rules.STAT_IDS:
		assert_true(stats.has(stat), "stats carry " + str(stat))
		assert_true(int(stats[stat]) >= 8 and int(stats[stat]) <= 18, "%s is in 8..18" % stat)
	assert_eq(int(stats["str"]), 10, "STR default")
	assert_eq(int(stats["cha"]), 14, "CHA default")
	assert_eq(String(Rules.stat_name("cha")), "Schnauze", "the strip prints the Späti name")

func test_the_modifier_is_the_5e_one() -> void:
	# floor, not truncation: a 9 is -1, not 0. That is the bug integer division would hand you.
	assert_eq(Rules.modifier(8), -1, "8 -> -1")
	assert_eq(Rules.modifier(9), -1, "9 -> -1")
	assert_eq(Rules.modifier(10), 0, "10 -> 0")
	assert_eq(Rules.modifier(11), 0, "11 -> 0")
	assert_eq(Rules.modifier(14), 2, "14 -> +2")
	assert_eq(Rules.modifier(18), 4, "18 -> +4")
	var s := _fresh()
	assert_eq(Rules.stat_mod(s, "cha"), 2, "CHA 14 is +2")
	assert_eq(Rules.stat_mod(s, "str"), 0, "STR 10 is +0")

func test_the_player_view_carries_scores_and_mods() -> void:
	var v: Dictionary = Rules.view(_fresh())["player"]
	assert_eq((v["stats"] as Dictionary).size(), 6, "six scores")
	for stat in Rules.STAT_IDS:
		assert_eq(int(v["mods"][stat]), Rules.modifier(int(v["stats"][stat])), "%s mod matches its score" % stat)

# ───────────────────────────── §2 checks ─────────────────────────────

func test_a_check_is_deterministic_and_logged() -> void:
	var a := Rules.apply(_talking("lena", 17), {"type": "talk_choose", "choice": 1})  # the CHA 12 line
	var b := Rules.apply(_talking("lena", 17), {"type": "talk_choose", "choice": 1})
	var check_a: Dictionary = a["talk"]["last_check"] if not (a["talk"] as Dictionary).is_empty() else {}
	assert_false(check_a.is_empty(), "the roll is on the talk for the UI to pop")
	assert_eq(JSON.stringify(check_a), JSON.stringify(b["talk"]["last_check"]), "same seed, same d20")
	assert_eq(String(check_a["stat"]), "cha", "the check names its stat")
	assert_eq(int(check_a["dc"]), 12, "and its DC")
	assert_eq(int(check_a["mod"]), Rules.stat_mod(a, "cha"), "the modifier is the player's")
	assert_true(int(check_a["roll"]) >= 1 and int(check_a["roll"]) <= 20, "a d20 is a d20 (%d)" % int(check_a["roll"]))
	assert_eq(bool(check_a["success"]), int(check_a["roll"]) + int(check_a["mod"]) >= int(check_a["dc"]), "success is roll+mod vs DC")
	var logged := {}
	for entry in a["log"]:
		if entry["kind"] == "check":
			logged = entry["data"]
	assert_eq(JSON.stringify(logged), JSON.stringify(check_a), "the check entry is in the log stream (§2)")
	assert_ne(int(a["rng_state"]), int(_talking("lena", 17)["rng_state"]), "the roll consumed rng state")

func test_a_check_branches_to_its_own_node() -> void:
	# Whatever the die says, the talk lands on a written node — never nowhere.
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8]:
		var s := Rules.apply(_talking("lena", seed_value), {"type": "talk_choose", "choice": 1})
		var landed := String((s["talk"] as Dictionary).get("node", ""))
		var succeeded := bool(s["talk"]["last_check"]["success"])
		assert_eq(landed, "sketch" if succeeded else "no_sketch", "seed %d lands on its branch" % seed_value)

func test_the_chance_the_box_prints_is_the_real_one() -> void:
	assert_almost(Talk.success_chance(12, 2), 0.55, 0.0001, "DC 12 at +2 clears on 10+ = 11/20")
	assert_almost(Talk.success_chance(1, 0), 1.0, 0.0001, "DC 1 never fails")
	assert_almost(Talk.success_chance(30, 0), 0.0, 0.0001, "DC 30 never lands")

# ───────────────────────────── §2 gates ─────────────────────────────

func test_a_gate_locks_below_its_minimum() -> void:
	var s := _talking("juergen", 5, "beer")  # "crate": choice 1 needs STR 12, the default is 10
	var choices: Array = Rules.view(s)["talk"]["choices"]
	assert_true(bool(choices[1]["locked"]), "the STR line is locked at STR 10")
	assert_true(String(choices[1]["reason"]).contains("Muscle"), "and says why: " + String(choices[1]["reason"]))
	assert_false(bool(choices[0]["locked"]), "choice 0 is never gated (the authoring rule)")
	assert_true(is_same(Rules.apply(s, {"type": "talk_choose", "choice": 1}), s), "a locked choice is illegal")
	assert_false(_types(Rules.legal_actions(s)).has("talk_choose") and _legal_choices(s).has(1), "and is not offered")
	# Raise the stat and the same line opens, with no roll.
	s["player"]["stats"]["str"] = 12
	assert_false(bool((Rules.view(s)["talk"]["choices"] as Array)[1]["locked"]), "STR 12 unlocks it")
	var lifted := Rules.apply(s, {"type": "talk_choose", "choice": 1})
	assert_eq(String(lifted["talk"]["node"]), "lifted", "a gate has no die — it just opens")
	assert_true((lifted["talk"]["last_check"] as Dictionary).is_empty(), "and rolls nothing")
	assert_true((lifted["story"]["flags"] as Array).has("juergen_crate"), "its effects still apply")

func _legal_choices(s: Dictionary) -> Array:
	var out: Array = []
	for a in Rules.legal_actions(s):
		if a["type"] == "talk_choose":
			out.append(int(a["choice"]))
	return out

# ───────────────────────────── §3/§4 the graph ─────────────────────────────

func test_effects_apply_through_the_reducers_own_paths() -> void:
	var s := _talking("lena")
	var cash_before := float(s["cash"])
	var kiez_before := float(s["reputation"]["kiez"])
	s = Rules.apply(s, {"type": "talk_choose", "choice": 0})  # "On the house": kiez +1, cash -1.80
	assert_almost(float(s["cash"]), cash_before - 1.8, 0.001, "the Mate came out of the till")
	assert_almost(float(s["reputation"]["kiez"]), kiez_before + 1.0, 0.001, "and bought trust")
	assert_eq(String(s["talk"]["node"]), "thanks", "and walked to the named node")
	assert_eq(int(s["talk"]["line"]), 0, "a new node starts on its first line")
	assert_eq(String(s["active"]["expression"]), "warm", "the face follows the node")
	assert_true((s["talk"]["history"] as Array).has("thanks"), "history is the trail taken")

func test_advance_walks_the_lines_then_opens_the_choices() -> void:
	var s := Rules.apply(_talking("lena"), {"type": "talk_choose", "choice": 0})  # "thanks" has 2 lines
	var v: Dictionary = Rules.view(s)["talk"]
	assert_eq((v["lines"] as Array).size(), 2, "two lines")
	assert_eq(int(v["line"]), 0, "on the first")
	assert_true(_types(Rules.legal_actions(s)).has("talk_advance"), "so advance is offered")
	s = Rules.apply(s, {"type": "talk_advance"})
	assert_eq(int(Rules.view(s)["talk"]["line"]), 1, "advance moves to the last line")
	assert_false(_types(Rules.legal_actions(s)).has("talk_advance"), "there is nothing after the last line")
	assert_true(is_same(Rules.apply(s, {"type": "talk_advance"}), s), "advancing past the end is illegal")
	assert_true(_legal_choices(s).size() >= 1, "the choices are up")

func test_the_end_of_the_talk_lets_the_guest_go_and_rings_them_up() -> void:
	var s := _talking("", 5, "water")  # a nameless guest -> the `oneoff` graph
	assert_eq(String(s["talk"]["dialogue_id"]), Talk.DIALOGUE_PREFIX + "oneoff", "the parade shares one graph")
	var stock_before := int(s["inventory"]["water"]["stock"])
	var cash_before := float(s["cash"])
	s = Rules.apply(s, {"type": "talk_choose", "choice": 0})  # "Here you go." -> next:""
	assert_true((s["talk"] as Dictionary).is_empty(), "next:\"\" ends the conversation")
	assert_true((s["active"] as Dictionary).is_empty(), "the guest leaves")
	assert_eq(int(s["inventory"]["water"]["stock"]), stock_before - 1, "their want came off the shelf")
	assert_true(float(s["cash"]) > cash_before, "so cash still moves (docs/06 §4)")
	assert_eq(int(s["tally"]["sales"]), 1, "one sale tallied")

func test_turning_them_away_ends_the_talk_without_a_sale() -> void:
	var s := _talking("", 5, "water")
	var stock_before := int(s["inventory"]["water"]["stock"])
	s = Rules.apply(s, {"type": "talk_choose", "choice": 1})  # "We are out, sorry." -> serve:false
	assert_true((s["talk"] as Dictionary).is_empty(), "the talk closed")
	assert_eq(int(s["inventory"]["water"]["stock"]), stock_before, "nothing left the shelf")
	assert_eq(int(s["tally"]["sales"]), 0, "and nothing was rung up")
	assert_true(float(s["reputation"]["kiez"]) < 50.0, "sending someone away costs a little trust")

func test_the_want_is_substituted_into_the_one_off() -> void:
	var s := _talking("", 5, "beer")
	var v: Dictionary = Rules.view(s)["talk"]
	assert_true(String(v["lines"][0]).contains("Sterni"), "{want} became the SKU's name: " + String(v["lines"][0]))
	assert_false(String(v["lines"][0]).contains("{want}"), "no placeholder survives to the screen")
	assert_eq(String(v["speaker"]), Content.archetype(String(s["active"]["archetype_id"]))["name"],
		"a nameless guest speaks as their archetype")

# ───────────────────────────── §4 the queue and the actions ─────────────────────────────

func test_talk_next_is_illegal_with_an_empty_queue() -> void:
	var s := Rules.apply(_fresh(), {"type": "open_night"})
	assert_true((s["queue"] as Array).is_empty(), "nobody has arrived yet")
	assert_true(is_same(Rules.apply(s, {"type": "talk_next"}), s), "there is nobody to take")
	assert_false(_types(Rules.legal_actions(s)).has("talk_next"), "and the button is not offered")
	var manage_phase := _fresh()
	assert_true(is_same(Rules.apply(manage_phase, {"type": "talk_next"}), manage_phase), "nor outside the night")

func test_talk_next_takes_the_head_of_the_queue() -> void:
	var s := Rules.apply(_fresh(3), {"type": "open_night"})
	var guard := 0
	while (s["queue"] as Array).size() < 2 and guard < 900:
		s = Rules.tick(s, 500)
		guard += 1
	# The tick pulls the first person up by itself; clear the counter so the queue is what is waiting.
	s["active"] = {}
	var head := int((s["queue"] as Array)[0]["id"])
	assert_true(_types(Rules.legal_actions(s)).has("talk_next"), "a queue means there is someone to take")
	s = Rules.apply(s, {"type": "talk_next"})
	assert_eq(int(s["active"]["id"]), head, "FIFO: the head of the queue steps up")
	assert_eq(int(s["talk"]["customer_id"]), head, "and it is them the talk is about")

func test_the_queue_view_is_fifo_and_carries_portraits() -> void:
	var s := Rules.apply(_fresh(3), {"type": "open_night"})
	var guard := 0
	while (s["queue"] as Array).size() < 3 and guard < 900:
		s = Rules.tick(s, 500)
		guard += 1
	var v: Dictionary = Rules.view(s)
	var queue: Array = v["queue"]
	assert_eq(queue.size(), (s["queue"] as Array).size(), "everyone waiting is in the view")
	assert_eq(int(v["queue_len"]), queue.size(), "queue_len agrees with the list")
	for i in queue.size():
		var entry: Dictionary = queue[i]
		assert_eq(int(entry["customer_id"]), int((s["queue"] as Array)[i]["id"]), "entry %d keeps its place (FIFO)" % i)
		assert_true(String(entry["portrait"]).begins_with("char/"), "everyone has a portrait id")
		assert_true(String(entry["name"]).length() > 0, "and a name to print")
		assert_true(Assets.SIZES.has(String(entry["portrait"]) + "_neutral"), "which the art pipeline knows")
	# A cast member borrows their own bust; the nameless borrow their archetype's.
	var lena: Dictionary = SpatiState.new_customer(99, "student", "mate", 9000, "lena")
	assert_eq(Talk.guest_name(lena), "Lena", "a named guest is named")
	assert_eq(Content.portrait_for("lena", "student"), "char/lena", "and wears their own face")
	assert_eq(Content.portrait_for("", "tourist"), "char/oneoff_tourist", "a stranger wears the archetype's")

func test_while_talking_only_talk_actions_are_offered() -> void:
	var s := _talking("lena")
	var types := _types(Rules.legal_actions(s))
	assert_true(types.has("talk_choose"), "you can say something")
	assert_false(types.has("serve_active"), "but not ring them up mid-sentence")
	assert_false(types.has("skip_active"), "nor wave them off")
	assert_false(types.has("talk_next"), "nor start a second conversation")
	assert_true(is_same(Rules.apply(s, {"type": "serve_active", "give": ["mate"]}), s), "and the reducer agrees")
	assert_true(is_same(Rules.apply(s, {"type": "skip_active"}), s), "for both")

func test_the_night_and_the_day_close_the_conversation() -> void:
	var s := _talking("lena")
	assert_true((Rules.apply(s, {"type": "close_night"})["talk"] as Dictionary).is_empty(),
		"06:00 sends whoever is mid-sentence home")

# ───────────────────────────── §4 one box, one source ─────────────────────────────

func test_the_dialogue_view_is_a_projection_of_the_talk() -> void:
	var s := _talking("mehmet", 5, "cigarettes")
	var v := Rules.view(s)
	var talk: Dictionary = v["talk"]
	var dialogue: Dictionary = v["dialogue"]
	assert_false(dialogue.is_empty(), "the box has something to show")
	assert_eq(String(dialogue["speaker"]), String(talk["speaker"]), "same speaker")
	assert_eq(String(dialogue["portrait"]), String(talk["portrait"]), "same portrait")
	assert_eq(String(dialogue["expression"]), String(talk["expression"]), "same face")
	assert_eq(JSON.stringify(dialogue["lines"]), JSON.stringify(talk["lines"]), "same lines")
	assert_eq((dialogue["choices"] as Array).size(), (talk["choices"] as Array).size(), "same number of choices")
	assert_eq(String(dialogue["choices"][0]["label"]), String(talk["choices"][0]["label"]), "same labels")
	assert_eq(String(dialogue["kind"]), "talk", "and it says which kind of content it is")

func test_a_story_beat_is_a_one_node_dialogue_on_the_same_rails() -> void:
	# This test is about the beat rails, not the line: let the head of the queue step up on tick as before.
	var s := Rules.apply(SpatiState.new_game({"seed": 3, "auto_take_next": true}), {"type": "open_night"})
	var guard := 0
	while s["phase"] == "night" and guard < 2000:
		guard += 1
		if Talk.is_open(s) and Talk.kind_of(s) == Talk.KIND_BEAT:
			break
		s = Rules.tick(s, 500)
		if Talk.is_open(s):
			continue
		if not (s["active"] as Dictionary).is_empty():
			s = Rules.apply(s, {"type": "skip_active"})  # clear the counter so the cast can reach it
	assert_eq(Talk.kind_of(s), Talk.KIND_BEAT, "a beat opened as a talk")
	var v := Rules.view(s)
	assert_eq(String(v["dialogue"]["kind"]), "beat", "the box still calls it a beat (docs/05 §4)")
	assert_eq(JSON.stringify(v["dialogue"]["lines"]), JSON.stringify(v["talk"]["lines"]), "one source, two names")
	assert_true(_types(Rules.legal_actions(s)).has("resolve_beat"), "the legacy action is still offered")
	var customer_id := int(s["active"]["id"])
	var resolved := Rules.apply(s, {"type": "resolve_beat", "choice": 0})
	assert_true((resolved["talk"] as Dictionary).is_empty(), "resolving closes the box")
	assert_eq(int(resolved["active"]["id"]), customer_id, "but a beat does NOT dismiss the guest (docs/05 §4)")
	assert_eq(JSON.stringify(resolved), JSON.stringify(Rules.apply(s, {"type": "talk_choose", "choice": 0})),
		"resolve_beat and talk_choose are the same path")

# ───────────────────────────── §6 the whole night, and the data ─────────────────────────────

func test_the_auto_player_talks_its_way_through_a_night() -> void:
	var s := AutoPlayer.play_night(AutoPlayer.manage(_fresh(4)))
	assert_eq(s["phase"], "summary", "the night closed")
	assert_true((s["talk"] as Dictionary).is_empty(), "with nobody left mid-sentence")
	var sum: Dictionary = (s["summaries"] as Array).back()
	assert_true(int(sum["sales"]) > 10, "talking still trades (%d sales)" % int(sum["sales"]))
	var expected := Economy.round2(float(sum["revenue"]) + float(sum["tips"]) - float(sum["cogs"])
		- float(sum["bills_due"]) - float(sum["pfand_paid"]))
	assert_almost(float(sum["profit"]), expected, 0.005, "and the books still balance")
	var talked := 0
	for entry in s["log"]:
		if entry["kind"] == "beat":
			talked += 1
	assert_true(talked > 10, "a line was said to nearly everyone (%d)" % talked)

func test_a_talked_night_replays_exactly() -> void:
	# The d20s are drawn from the state's own rng, so the whole night is in {config, seed, actions}.
	var a := AutoPlayer.play_nights(_fresh(6), 2)
	var b := AutoPlayer.play_nights(_fresh(6), 2)
	assert_eq(SpatiState.to_json(a), SpatiState.to_json(b), "two identical runs, every roll included")
	var text := SpatiState.to_json(a)
	assert_eq(SpatiState.to_json(SpatiState.from_json(text)), text, "and it survives a save/load")

func test_a_save_taken_mid_conversation_comes_back_whole() -> void:
	# The autosave can land on any frame, including line 2 of Mehmet's letter.
	var s := Rules.apply(_talking("mehmet", 8, "cigarettes"), {"type": "talk_advance"})
	s = Rules.apply(s, {"type": "talk_choose", "choice": 0})   # -> "reading"
	s = Rules.apply(s, {"type": "talk_choose", "choice": 1})   # the INT 13 check
	assert_false((s["talk"] as Dictionary).is_empty(), "still mid-conversation")
	var text := SpatiState.to_json(s)
	var back := SpatiState.from_json(text)
	assert_eq(SpatiState.to_json(back), text, "a mid-talk state survives JSON unchanged")
	assert_eq(typeof(back["talk"]["line"]), TYPE_INT, "the line index is an int again")
	assert_eq(typeof(back["talk"]["customer_id"]), TYPE_INT, "and so is the customer id")
	assert_eq(typeof(back["talk"]["last_check"]["roll"]), TYPE_INT, "the d20 is an int, not 14.0")
	assert_eq(typeof(back["player"]["stats"]["cha"]), TYPE_INT, "the stats are ints")
	assert_eq(JSON.stringify(Rules.view(back)["talk"]), JSON.stringify(Rules.view(s)["talk"]),
		"and the box renders the same thing after the seam")

func test_every_graph_is_playable() -> void:
	for id in Content.DIALOGUES:
		var graph: Dictionary = Content.DIALOGUES[id]
		var nodes: Dictionary = graph["nodes"]
		assert_true(nodes.has(String(graph["start"])), "%s starts on a written node" % id)
		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			assert_true((node["lines"] as Array).size() >= 1, "%s/%s has lines" % [id, node_id])
			var choices: Array = node["choices"]
			assert_true(choices.size() >= 1, "%s/%s has a choice" % [id, node_id])
			assert_false((choices[0] as Dictionary).has("requires"),
				"%s/%s: choice 0 is never gated — the AutoPlayer has to get out" % [id, node_id])
			for choice in choices:
				var c: Dictionary = choice
				assert_true(String(c["label"]).length() > 0, "%s/%s: labelled" % [id, node_id])
				for key in ["next", "next_fail"]:
					var target := String(c.get(key, ""))
					if target != "":
						assert_true(nodes.has(target), "%s/%s -> %s exists" % [id, node_id, target])
				var check: Dictionary = c.get("check", {})
				if not check.is_empty():
					assert_true(Rules.STAT_IDS.has(String(check["stat"])), "%s/%s rolls a real stat" % [id, node_id])
					assert_true(int(check["dc"]) >= 5 and int(check["dc"]) <= 25, "%s/%s DC is sane" % [id, node_id])
					assert_true(String(c["label"]).begins_with("["), "%s/%s wears its stat tag" % [id, node_id])
				var requires: Dictionary = c.get("requires", {})
				if not requires.is_empty():
					assert_true(Rules.STAT_IDS.has(String(requires["stat"])), "%s/%s gates on a real stat" % [id, node_id])
					assert_true(String(c["label"]).begins_with("["), "%s/%s wears its gate tag" % [id, node_id])

func test_the_three_regulars_carry_the_slices_story_budget() -> void:
	for id in REGULARS:
		assert_true(Content.DIALOGUES.has(id), "%s has a tree" % id)
		assert_false(Content.character(id).is_empty(), "%s is in the cast registry" % id)
		var nodes: Dictionary = Content.DIALOGUES[id]["nodes"]
		assert_true(nodes.size() >= 5 and nodes.size() <= 8, "%s is 5-8 nodes (got %d)" % [id, nodes.size()])
		var rolls := 0
		for node_id in nodes:
			for choice in nodes[node_id]["choices"]:
				if not (choice as Dictionary).get("check", {}).is_empty() or not (choice as Dictionary).get("requires", {}).is_empty():
					rolls += 1
		assert_true(rolls >= 2, "%s has at least two checks/gates (got %d)" % [id, rolls])
	assert_true(Content.DIALOGUES.has(Content.DIALOGUE_FALLBACK), "and the parade has its one-off")
	assert_eq(Content.dialogue_id_for("nobody_at_all"), Content.DIALOGUE_FALLBACK, "strangers fall back to it")
	assert_eq(Content.dialogue_id_for("lena"), "lena", "regulars do not")
	var order: Dictionary = Content.DIALOGUES[Content.DIALOGUE_FALLBACK]["nodes"]["order"]
	assert_true(String(order["lines"][0]).contains("{want}"), "the one-off asks for what they came for")
