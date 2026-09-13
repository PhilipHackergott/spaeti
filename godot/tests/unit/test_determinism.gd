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

## A night driven through the REGISTER — wall trips, a rejected ring-up and a Pfand row — replays
## exactly and survives the save seam (docs/08 §6). The uid counter, `view_mode` and `last_verdict`
## are top-level state now, so a run that handled objects has to come back as the same bytes.
func test_a_register_night_replays_and_round_trips() -> void:
	var a := _play_register_night(4)
	var b := _play_register_night(4)
	assert_eq(SpatiState.to_json(a), SpatiState.to_json(b), "the same register night, twice, identical")
	assert_true(int(a["next_item_uid"]) > 1, "…and it really did handle objects (%d uids)" % int(a["next_item_uid"]))
	assert_false((a["last_verdict"] as Dictionary).is_empty(), "with a verdict on the last ring-up")
	var text := SpatiState.to_json(a)
	assert_eq(SpatiState.to_json(SpatiState.from_json(text)), text, "and it survives JSON byte for byte")
	assert_ne(SpatiState.to_json(_play_register_night(5)), text, "another seed is another night")

## Scan everything on the counter, fetch whatever the basket wants off the wall, take the deposit,
## ring up (twice when the first one is refused) — the register's real actions, no shortcuts.
func _play_register_night(seed_value: int) -> Dictionary:
	var s := AutoPlayer.manage(SpatiState.new_game({"seed": seed_value, "auto_take_next": true}))
	s = Rules.apply(s, {"type": "open_night"})
	var served := 0
	var guard := 0
	while served < 6 and guard < 3000:
		guard += 1
		s = Rules.tick(s, 500)
		if Talk.is_open(s):
			s = AutoPlayer.play_talk(s)
			continue
		if (s["active"] as Dictionary).is_empty() or not (s["story"]["pending"] as Dictionary).is_empty() \
			or String(s["story"]["pending_vignette"]) != "":
			continue
		for entry in (s["active"]["basket"] as Array).duplicate(true):
			var row: Dictionary = entry
			if bool(row["placed"]) or Content.brands_for(String(row["sku"])).is_empty():
				continue
			s = Rules.apply(s, {"type": "turn_around", "on": true})
			for i in int(row["qty"]):
				s = Rules.apply(s, {"type": "take_from_wall", "sku": String(row["sku"]),
					"brand": String((Content.brands_for(String(row["sku"]))[0] as Dictionary)["id"])})
			s = Rules.apply(s, {"type": "turn_around", "on": false})
		for entry in (s["active"]["counter"] as Array).duplicate(true):
			s = Rules.apply(s, {"type": "scan", "uid": int((entry as Dictionary)["uid"])})
		s = Rules.apply(s, {"type": "set_pfand", "bottles": int(s["active"]["bottles"])})
		var before := s
		s = Rules.apply(s, {"type": "ring_up"})
		if not (s["active"] as Dictionary).is_empty():
			s = Rules.apply(s, {"type": "ring_up"})
		if is_same(s, before):
			s = Rules.apply(s, {"type": "skip_active"})
			continue
		served += 1
	return s

func test_apply_never_mutates_the_state_it_was_given() -> void:
	var s := Rules.apply(_fresh(3), {"type": "open_night"})
	var before := SpatiState.to_json(s)
	Rules.tick(s, 5000)
	Rules.apply(s, {"type": "set_price", "sku": "beer", "price": 9.0})
	Rules.apply(s, {"type": "close_night"})
	assert_eq(SpatiState.to_json(s), before, "the reducer is pure")

## 2026-09-13: `Session.has_save()` was `FileAccess.file_exists` alone, so a truncated write (a
## watchdog kill mid-save) or a save from a build before a key existed lit "Continue" on the title —
## and pressing it threw `Invalid access to property or key 'config'` out of `_normalise` and
## swallowed the click. A shape the reducer cannot walk is not a save.
func test_from_json_rejects_a_save_it_cannot_normalise() -> void:
	assert_true(SpatiState.from_json('{"active":{},"arrivals":[{"archetype').is_empty(), "a truncated write is not a save")
	assert_true(SpatiState.from_json('{"day":3,"phase":"manage"}').is_empty(), "an older key set is not a save")
	assert_true(SpatiState.from_json("[1,2,3]").is_empty(), "a JSON array is not a save")
	assert_true(SpatiState.from_json("").is_empty(), "an empty file is not a save")
	var real := SpatiState.to_json(SpatiState.new_game({}))
	assert_false(SpatiState.from_json(real).is_empty(), "a real save still loads")
	# ...and one mid-season, with a night's worth of state in it.
	var s := Rules.apply(SpatiState.new_game({"seed": 5}), {"type": "open_night"})
	s = Rules.tick(s, 60000)
	assert_false(SpatiState.from_json(SpatiState.to_json(s)).is_empty(), "so does a save taken mid-night")

## 2026-09-13: nine Berlin drinks joined the catalogue and this seam broke — Godot's JSON sorts keys, so a
## reloaded save iterated its shelf alphabetically while the live one iterated it in catalogue order, and
## the AutoPlayer's restock (which spends until the cash runs out) then bought different SKUs. The fix is
## in `_normalise`; this is the test that keeps it fixed without playing a whole night to find out.
func test_a_reloaded_shelf_keeps_the_catalogue_order() -> void:
	var s := SpatiState.new_game({})
	var reloaded := SpatiState.from_json(SpatiState.to_json(s))
	var live: Array = (s["inventory"] as Dictionary).keys()
	var back: Array = (reloaded["inventory"] as Dictionary).keys()
	assert_eq(back, live, "the reloaded shelf iterates in the same order as the live one")
	var catalogue: Array = []
	for sku in Content.SKUS:
		if (reloaded["inventory"] as Dictionary).has(String(sku["id"])):
			catalogue.append(String(sku["id"]))
	assert_eq(back, catalogue, "and that order is the catalogue's")
