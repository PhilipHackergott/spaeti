extends "res://tests/TestCase.gd"
## The night loop: open → tick → serve/skip → close, and the P&L identity on the closed night.

func _fresh() -> Dictionary:
	return SpatiState.new_game({"seed": 7, "auto_take_next": true})  # counter-loop tests: the head steps up on tick

func test_new_game_shape() -> void:
	var s := _fresh()
	assert_eq(s["phase"], "manage", "starts in manage")
	assert_eq(s["day"], 1, "day 1")
	assert_almost(float(s["cash"]), 420.0, 0.001, "normal start cash")
	assert_almost(float(s["config"]["rent_per_day"]), 48.0, 0.001, "normal rent")
	assert_eq(int(s["config"]["night_len_ms"]), 300000, "5-minute night")
	assert_true((s["inventory"] as Dictionary).has("beer"), "beer on the shelf")
	assert_false((s["inventory"] as Dictionary).has("coffee"), "coffee is upgrade-gated")

func test_open_night_schedules_arrivals() -> void:
	var s := Rules.apply(_fresh(), {"type": "open_night"})
	assert_eq(s["phase"], "night", "night opened")
	assert_true((s["arrivals"] as Array).size() > 40, "a busy Späti: %d arrivals" % (s["arrivals"] as Array).size())
	var last := -1
	for a in s["arrivals"]:
		assert_true(int(a["time_ms"]) >= last, "arrivals sorted by time")
		last = int(a["time_ms"])

func test_illegal_actions_return_the_same_state() -> void:
	var s := _fresh()
	assert_true(is_same(Rules.apply(s, {"type": "close_night"}), s), "cannot close what is not open")
	assert_true(is_same(Rules.apply(s, {"type": "advance_day"}), s), "cannot advance from manage")
	assert_true(is_same(Rules.apply(s, {"type": "serve_active"}), s), "nobody to serve")
	assert_true(is_same(Rules.apply(s, {"type": "restock", "sku": "beer", "qty": 99999}), s), "cannot afford")
	assert_true(is_same(Rules.apply(s, {"type": "buy_upgrade", "id": "espresso_bar"}), s), "gated upgrade")
	assert_true(is_same(Rules.apply(s, {"type": "nonsense"}), s), "unknown action")

func test_serve_moves_money_and_stock() -> void:
	var s := Rules.apply(_fresh(), {"type": "open_night"})
	var guard := 0
	while (s["active"] as Dictionary).is_empty() and guard < 500:
		s = Rules.tick(s, 1000)
		guard += 1
	assert_false((s["active"] as Dictionary).is_empty(), "someone reached the counter")
	var want: String = s["active"]["want"]
	var stock_before := int(s["inventory"][want]["stock"])
	var cash_before := float(s["cash"])
	s = Rules.apply(s, {"type": "serve_active", "give": [want], "pfand_bottles": 0})
	assert_eq(int(s["inventory"][want]["stock"]), stock_before - 1, "one unit left the shelf")
	assert_true(float(s["cash"]) > cash_before, "the till went up")
	assert_eq(int(s["tally"]["sales"]), 1, "one sale tallied")

func test_pfand_payout_and_credit() -> void:
	var s := Rules.apply(_fresh(), {"type": "open_night"})
	var guard := 0
	while (s["active"] as Dictionary).is_empty() and guard < 500:
		s = Rules.tick(s, 1000)
		guard += 1
	var cash_before := float(s["cash"])
	# They carried a crate in tonight. `serve_active` can only pay out what is on the counter, so the
	# arithmetic is staged rather than left to the seeded draw (`test_pfand_cannot_pay_out_more_than_
	# the_guest_brought` is the one that exercises the clamp).
	s["active"]["bottles"] = 10
	s = Rules.apply(s, {"type": "serve_active", "give": [], "pfand_bottles": 10})
	assert_eq(int(s["pfand_held"]), 10, "bottles in the crate")
	assert_almost(float(s["cash"]), cash_before - 1.5, 0.001, "paid out 10 x 0.15")
	# The crate becomes wholesaler credit on the NEXT order — i.e. the next manage phase (ordering is a
	# manage-only intent, so the night has to be closed out first). 10 bottles = EUR 1.50 off.
	s = Rules.apply(Rules.apply(s, {"type": "close_night"}), {"type": "advance_day"})
	assert_eq(s["phase"], "manage", "back behind the counter before opening")
	assert_eq(int(s["pfand_held"]), 10, "the crate survives the night")
	var before_order := float(s["cash"])
	s = Rules.apply(s, {"type": "restock", "sku": "water", "qty": 10})  # 10 x 0.20 = 2.00, minus 1.50
	assert_almost(float(s["cash"]), before_order - 0.5, 0.001, "credit applied to the order")
	assert_eq(int(s["pfand_held"]), 0, "crate emptied by the credit")

## You can only take back what the guest carried in. Paying out against `pfand_held` (the SHOP's crate)
## meant one press doubled it on every serve — 0 -> 1 -> 2 -> 4 -> 8 — and pumped cash out of the till.
func test_pfand_cannot_pay_out_more_than_the_guest_brought() -> void:
	var s := Rules.apply(_fresh(), {"type": "open_night"})
	var guard := 0
	while (s["active"] as Dictionary).is_empty() and guard < 500:
		s = Rules.tick(s, 1000)
		guard += 1
	assert_false((s["active"] as Dictionary).is_empty(), "someone reached the counter")
	var brought := int(Rules.view(s)["active"]["bottles"])
	assert_true(brought >= 0 and brought <= Rules.PFAND_MAX_RETURN, "and they carried a sane number (%d)" % brought)
	var cash_before := float(s["cash"])
	var held_before := int(s["pfand_held"])
	s = Rules.apply(s, {"type": "serve_active", "give": [], "pfand_bottles": 999})
	assert_eq(int(s["pfand_held"]) - held_before, brought, "the crate grew by exactly what they handed over")
	assert_almost(float(s["cash"]), cash_before - float(brought) * Rules.PFAND_PER_BOTTLE, 0.001,
		"and the till paid for exactly those")

## The tray reads the guest's own count out of the read-model, so it can never stage the shop's crate.
func test_the_active_view_says_what_they_are_carrying() -> void:
	var s := Rules.apply(_fresh(), {"type": "open_night"})
	var guard := 0
	while (s["active"] as Dictionary).is_empty() and guard < 500:
		s = Rules.tick(s, 1000)
		guard += 1
	var active: Dictionary = Rules.view(s)["active"]
	assert_true(active.has("bottles"), "the read-model carries the guest's empties")
	assert_eq(typeof(active["bottles"]), TYPE_INT, "as a whole number of bottles")
	# ...and it survives the save seam like everything else.
	var back := SpatiState.from_json(SpatiState.to_json(s))
	assert_eq(int(Rules.view(back)["active"]["bottles"]), int(active["bottles"]), "and the autosave keeps it")

func test_balk_when_nobody_serves() -> void:
	var s := Rules.apply(_fresh(), {"type": "open_night"})
	for i in 60:
		s = Rules.tick(s, 1000)
	assert_true(int(s["tally"]["lost"]) > 0, "unserved customers walk (%d lost)" % int(s["tally"]["lost"]))
	assert_true(float(s["reputation"]["kiez"]) < 50.0, "balking costs Kiez-Trust")

func test_close_night_pnl_identity() -> void:
	var s := AutoPlayer.play_night(AutoPlayer.manage(_fresh()))
	assert_eq(s["phase"], "summary", "night closed into the summary")
	var sum: Dictionary = (s["summaries"] as Array).back()
	var expected := Economy.round2(float(sum["revenue"]) + float(sum["tips"]) - float(sum["cogs"])
		- float(sum["bills_due"]) - float(sum["pfand_paid"]))
	assert_almost(float(sum["profit"]), expected, 0.005, "profit = revenue + tips - cogs - bills(incl. fines) - pfand")
	assert_true(int(sum["sales"]) > 10, "the night actually traded (%d sales)" % int(sum["sales"]))

func test_advance_day_rolls_the_calendar() -> void:
	var s := AutoPlayer.play_night(AutoPlayer.manage(_fresh()))
	var perishable_before := int(s["inventory"]["schrippe"]["stock"])
	s = Rules.apply(s, {"type": "advance_day"})
	assert_eq(s["phase"], "manage", "back to the shop")
	assert_eq(int(s["day"]), 2, "day 2")
	assert_eq(int(s["weekday"]), 1, "Tuesday")
	assert_eq(int(s["inventory"]["schrippe"]["stock"]), int(floor(perishable_before * 0.5)), "Schrippen go stale")

func test_view_shape_and_clock() -> void:
	var s := Rules.apply(_fresh(), {"type": "open_night"})
	var v := Rules.view(s)
	assert_eq(v["time_label"], "20:00", "the night starts at 20:00")
	s = Rules.tick(s, int(s["config"]["night_len_ms"] / 2))
	assert_eq(Rules.view(s)["time_label"], "01:00", "half a night is 01:00")
	s = Rules.tick(s, int(s["config"]["night_len_ms"]))
	assert_eq(Rules.view(s)["time_label"], "06:00", "dawn")
	assert_eq((Rules.view(s)["shelf"] as Array).size(), (s["inventory"] as Dictionary).size(), "shelf shows every stocked SKU")
	assert_true(Rules.view(s)["hud"]["kiez_label"].begins_with("Kiez-Trust"), "hud labels")

func test_legal_actions_track_the_phase() -> void:
	var s := _fresh()
	assert_true(_has_type(Rules.legal_actions(s), "open_night"), "manage offers open_night")
	assert_false(_has_type(Rules.legal_actions(s), "close_night"), "manage does not offer close_night")
	s = Rules.apply(s, {"type": "open_night"})
	assert_true(_has_type(Rules.legal_actions(s), "tick"), "night ticks")
	# ...and the reducer agrees with the list: the four board intents are refused outside manage, or the
	# UI's legality and the engine's drift apart again (docs/05 §3).
	var night := Rules.apply(_fresh(), {"type": "open_night"})
	assert_true(is_same(Rules.apply(night, {"type": "restock", "sku": "beer", "qty": 1}), night),
		"no wholesaler run at 03:00")
	assert_true(is_same(Rules.apply(night, {"type": "set_price", "sku": "beer", "price": 99.0}), night),
		"and no re-pricing the shelf mid-night")
	assert_true(is_same(Rules.apply(night, {"type": "set_sunday_open", "open": true}), night),
		"Sunday is decided before opening")
	s = Rules.apply(AutoPlayer.play_night(s), {"type": "advance_day"})
	assert_eq(s["phase"], "manage", "and round again")

func test_session_dispatches_and_streams_events() -> void:
	# The autoload is a Node, but nothing in it needs the tree — instantiate it bare and drive it.
	var session: Node = load("res://state/session.gd").new()
	session.new_game({"seed": 7, "auto_take_next": true})
	var seen: Array = []
	session.event.connect(func(entry: Dictionary): seen.append(entry["kind"]))
	assert_true(session.dispatch({"type": "open_night"}), "legal action dispatches")
	assert_false(session.dispatch({"type": "open_night"}), "an illegal one reports false")
	assert_true(seen.has("open"), "log entries reach the event stream")
	assert_eq(session.view()["phase"], "night", "view follows the state")
	assert_true(is_same(session.view(), session.view()), "view is memoised per state")
	session.dispatch({"type": "tick", "dt_ms": 1000})
	assert_eq(int(session.view()["clock_ms"]), 1000, "and re-renders after a dispatch")
	assert_true((session.legal_actions() as Array).size() > 0, "legal actions pass through")
	session.free()

func _has_type(actions: Array, type: String) -> bool:
	for a in actions:
		if a["type"] == type:
			return true
	return false
