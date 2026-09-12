extends "res://tests/TestCase.gd"
## The replay guarantee: a season is reconstructable from {config, seed, actions}, survives a JSON
## round-trip byte-for-byte, and a full 7-night AutoPlayer run never throws and always balances.

const SEASON_NIGHTS := 7

func _fresh(seed_value: int = 1) -> Dictionary:
	return SpatiState.new_game({"seed": seed_value})

func test_same_seed_same_actions_same_state() -> void:
	var a := AutoPlayer.play_nights(_fresh(42), 2)
	var b := AutoPlayer.play_nights(_fresh(42), 2)
	assert_eq(SpatiState.to_json(a), SpatiState.to_json(b), "two identical runs are the same state")

func test_a_different_seed_is_a_different_night() -> void:
	var a := Rules.apply(_fresh(1), {"type": "open_night"})
	var b := Rules.apply(_fresh(2), {"type": "open_night"})
	assert_ne(JSON.stringify(a["arrivals"]), JSON.stringify(b["arrivals"]), "seeds diverge")

func test_json_round_trip_is_stable() -> void:
	var s := AutoPlayer.play_nights(_fresh(5), 2)
	var text := SpatiState.to_json(s)
	var back := SpatiState.from_json(text)
	assert_eq(SpatiState.to_json(back), text, "state survives a JSON round trip unchanged")
	# And the re-integered fields really are ints again, not 1.0-shaped floats.
	assert_eq(typeof(back["day"]), TYPE_INT, "day is an int")
	assert_eq(typeof(back["clock_ms"]), TYPE_INT, "clock is an int")
	assert_eq(typeof(back["rng_state"]), TYPE_INT, "rng state is an int")
	assert_eq(typeof(back["config"]["seed"]), TYPE_INT, "seed is an int")
	assert_eq(typeof(back["inventory"]["beer"]["stock"]), TYPE_INT, "stock is an int")

func test_a_reloaded_state_keeps_playing_identically() -> void:
	var s := AutoPlayer.play_nights(_fresh(9), 1)
	var reloaded := SpatiState.from_json(SpatiState.to_json(s))
	var straight := AutoPlayer.play_nights(s, 1)
	var resumed := AutoPlayer.play_nights(reloaded, 1)
	assert_eq(SpatiState.to_json(resumed), SpatiState.to_json(straight), "a save/load seam changes nothing")

func test_full_seven_night_season() -> void:
	var s := _fresh(1)
	for night in SEASON_NIGHTS:
		assert_eq(s["phase"], "manage", "night %d starts in manage" % (night + 1))
		var cash_before := float(s["cash"])
		s = AutoPlayer.manage(s)
		var restock_spend := cash_before - float(s["cash"])
		s = AutoPlayer.play_night(s)
		assert_eq(s["phase"], "summary", "night %d closed" % (night + 1))
		var sum: Dictionary = (s["summaries"] as Array).back()
		# The P&L identity, on every closed night.
		var expected := Economy.round2(float(sum["revenue"]) + float(sum["tips"]) - float(sum["cogs"])
			- float(sum["bills_due"]) - float(sum["pfand_paid"]))
		assert_almost(float(sum["profit"]), expected, 0.005, "night %d P&L balances" % (night + 1))
		assert_almost(float(sum["cash_after"]), float(s["cash"]), 0.005, "the summary reports the real till")
		assert_true(int(sum["sales"]) > 0, "night %d traded (%d sales)" % [night + 1, int(sum["sales"])])
		assert_true(restock_spend >= 0.0, "restocking costs money")
		s = Rules.apply(s, {"type": "advance_day"})
	assert_eq(int(s["day"]), SEASON_NIGHTS + 1, "seven nights advanced the calendar")
	assert_true(float(s["cash"]) > 0.0, "a competent shopkeeper is still solvent (€%.2f)" % float(s["cash"]))
	assert_true((s["story"]["met"] as Array).size() > 0, "the cast turned up at the counter")
	assert_true(int(s["story"]["strands"]["main"]["last_day"]) > 0, "the main arc moved")
	# Every night's log is intact and ordered.
	var last_ts := -1
	for entry in s["log"]:
		assert_true(int(entry["ts"]) >= last_ts, "log entries are ordered")
		last_ts = int(entry["ts"])
	# And the whole season round-trips.
	var text := SpatiState.to_json(s)
	assert_eq(SpatiState.to_json(SpatiState.from_json(text)), text, "the season survives JSON")

func test_season_is_reproducible_end_to_end() -> void:
	var a := AutoPlayer.play_nights(_fresh(1), SEASON_NIGHTS)
	var b := AutoPlayer.play_nights(_fresh(1), SEASON_NIGHTS)
	assert_eq(SpatiState.to_json(a), SpatiState.to_json(b), "seven nights, twice, identical")
	assert_ne(SpatiState.to_json(AutoPlayer.play_nights(_fresh(2), SEASON_NIGHTS)), SpatiState.to_json(a),
		"another seed tells another story")

func test_apply_never_mutates_the_state_it_was_given() -> void:
	var s := Rules.apply(_fresh(3), {"type": "open_night"})
	var before := SpatiState.to_json(s)
	Rules.tick(s, 5000)
	Rules.apply(s, {"type": "set_price", "sku": "beer", "price": 9.0})
	Rules.apply(s, {"type": "close_night"})
	assert_eq(SpatiState.to_json(s), before, "the reducer is pure")
