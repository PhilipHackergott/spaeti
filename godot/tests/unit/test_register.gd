extends "res://tests/TestCase.gd"
## The register: scan to ring, the tobacco wall, and the verdict (docs/08 §3, §6).
##
## Every assertion here is made against the REAL read-model or the REAL reducer — never against a
## button, a node name or a mock. That is the standing rule of this project: the soft-lock that
## shipped did so because a driver pressed a control by name and nobody checked the state moved.

const HAPPY_BASKET := [
	{"sku": "mate", "brand": "", "qty": 1},
	{"sku": "cigarettes", "brand": "adler", "qty": 2},
	{"sku": "papers", "brand": "pap_feder_lang", "qty": 1},
]

# ───────────────────────────── fixtures ─────────────────────────────

## A night with one guest already at the counter and nobody mid-sentence. `auto_take_next` is how the
## head of the queue steps up on a tick, which is the same `_take_next` the player's `talk_next` runs —
## so `place_basket` fires through the real path, not a test back door.
func _counter(archetype_id: String = "regular", want: String = "mate", bottles: int = 0) -> Dictionary:
	var s := SpatiState.new_game({"seed": 7, "auto_take_next": true})
	s["phase"] = "night"
	s["queue"] = [SpatiState.new_customer(1, archetype_id, want, 10000, "", "", "", bottles)]
	return Rules.tick(s, 1)

## Stage a multi-line basket in the documented shape (docs/08 §3.1). The cast lane has not written the
## eleven `characters.gd` baskets yet, so the fixture speaks the contract directly — and the moment
## those rows land, `place_basket` produces exactly this and the fixtures stay true.
func _with_basket(s0: Dictionary, rows: Array) -> Dictionary:
	var s := SpatiState.clone(s0)
	var active: Dictionary = s["active"]
	var basket: Array = []
	var counter: Array = []
	var uid := int(s["next_item_uid"])
	for entry in rows:
		var row: Dictionary = entry
		var sku_id := String(row["sku"])
		var brand := String(row.get("brand", ""))
		var qty := int(row.get("qty", 1))
		var placed := String(Content.sku(sku_id).get("category", "")) != "tobacco"
		basket.append({"sku": sku_id, "brand": brand, "qty": qty, "said": "", "placed": placed})
		if not placed:
			continue
		for i in qty:
			counter.append({"uid": uid, "sku": sku_id, "brand": brand, "kind": "item", "count": 1,
				"scanned": false, "origin": "customer"})
			uid += 1
	var bottles := int(active.get("bottles", 0))
	if bottles > 0:
		counter.append({"uid": uid, "sku": "pfand", "brand": "", "kind": "crate", "count": bottles,
			"scanned": false, "origin": "customer"})
		uid += 1
		basket.append({"sku": "pfand", "brand": "", "qty": bottles, "said": "", "placed": true})
	s["next_item_uid"] = uid
	active["basket"] = basket
	active["counter"] = counter
	active["register"] = SpatiState.new_register()
	active["want"] = String((basket[0] as Dictionary)["sku"])
	return s

## Walk to the wall, take the facings the basket names, walk back. The real four actions.
func _fetch_the_tobacco(s0: Dictionary) -> Dictionary:
	var s := s0
	var shopping: Array = []
	for entry in (s["active"]["basket"] as Array):
		var row: Dictionary = entry
		if bool(row["placed"]):
			continue
		var brand := String(row["brand"])
		if brand == "":
			brand = String((Content.brands_for(String(row["sku"]))[0] as Dictionary)["id"])
		for i in int(row["qty"]):
			shopping.append({"sku": String(row["sku"]), "brand": brand})
	if shopping.is_empty():
		return s
	s = Rules.apply(s, {"type": "turn_around", "on": true})
	for item in shopping:
		s = Rules.apply(s, {"type": "take_from_wall", "sku": String((item as Dictionary)["sku"]),
			"brand": String((item as Dictionary)["brand"])})
	return Rules.apply(s, {"type": "turn_around", "on": false})

func _scan_all(s0: Dictionary) -> Dictionary:
	var s := s0
	for entry in (s["active"]["counter"] as Array).duplicate(true):
		var item: Dictionary = entry
		if String(item["kind"]) == "crate" or bool(item["scanned"]):
			continue
		s = Rules.apply(s, {"type": "scan", "uid": int(item["uid"])})
	return s

func _first_uid(s: Dictionary, sku_id: String) -> int:
	for entry in (s["active"]["counter"] as Array):
		if String((entry as Dictionary)["sku"]) == sku_id:
			return int((entry as Dictionary)["uid"])
	return -1

func _types(actions: Array) -> Array:
	var out: Array = []
	for a in actions:
		out.append(String((a as Dictionary)["type"]))
	return out

func _line_of(s: Dictionary, sku_id: String, brand: String) -> int:
	var lines: Array = s["active"]["register"]["lines"]
	for i in lines.size():
		if String((lines[i] as Dictionary)["sku"]) == sku_id and String((lines[i] as Dictionary)["brand"]) == brand:
			return i
	return -1

# ───────────────────────────── place_basket ─────────────────────────────

func test_the_order_becomes_objects_on_the_counter() -> void:
	var s := _counter("regular", "mate", 3)
	var active: Dictionary = s["active"]
	assert_false((active["basket"] as Array).is_empty(), "reaching the counter places a basket")
	assert_eq(String((active["basket"][0] as Dictionary)["sku"]), String(active["want"]),
		"active.want stays basket[0].sku, so {want} and the auto-serve are untouched")
	# One sprite per unit, plus ONE crate with a x3 badge — never three loose bottles (docs/08 §3.5).
	var crates := 0
	var items := 0
	for entry in (active["counter"] as Array):
		if String((entry as Dictionary)["kind"]) == "crate":
			crates += 1
			assert_eq(int((entry as Dictionary)["count"]), 3, "the crate carries the count")
		else:
			items += 1
	assert_eq(crates, 1, "one crate")
	assert_eq(items, 1, "one Mate")
	# The deposit is a request like any other, so forgetting it scores as `missing`.
	var pfand_row := {}
	for entry in (active["basket"] as Array):
		if String((entry as Dictionary)["sku"]) == "pfand":
			pfand_row = entry
	assert_false(pfand_row.is_empty(), "her empties are a ticket line")
	assert_eq(int(pfand_row["qty"]), 3, "for exactly what she carried in")

func test_tobacco_is_words_not_objects_and_buys_patience() -> void:
	var smoker := _counter("regular", "cigarettes", 0)
	assert_true((smoker["active"]["counter"] as Array).is_empty(),
		"she cannot reach the wall, so the pack exists only as a word")
	assert_eq(int(smoker["active"]["patience_left_ms"]), 10000 + Rules.TOBACCO_PATIENCE_BONUS_MS,
		"a basket with tobacco in it is granted the trip up front")
	var drinker := _counter("regular", "mate", 0)
	assert_eq(int(drinker["active"]["patience_left_ms"]), 10000, "nothing free for a bottle of Mate")

func test_the_caps_hold() -> void:
	# The reducer's caps, not the tray's (docs/08 §3.1): ≤ 4 goods lines, ≤ 6 units, ≤ 3 placed.
	var s := _with_basket(_counter("regular", "mate", 0), [
		{"sku": "mate", "qty": 4}, {"sku": "cola", "qty": 4}, {"sku": "chips", "qty": 2},
		{"sku": "gummi", "qty": 2}, {"sku": "water", "qty": 2},
	])
	# The fixture is deliberately over the caps; the reducer's own path is what has to hold, so run it.
	var real := SpatiState.new_game({"seed": 3, "auto_take_next": true})
	real["phase"] = "night"
	real["queue"] = [SpatiState.new_customer(1, "party", "beer", 9000, "", "", "", 6)]
	real = Rules.tick(real, 1)
	var basket: Array = real["active"]["basket"]
	var lines := 0
	var units := 0
	var placed := 0
	for entry in basket:
		var row: Dictionary = entry
		if String(row["sku"]) == "pfand":
			continue  # the crate is the tray's 7th slot, not one of the four goods lines
		lines += 1
		units += int(row["qty"])
		if bool(row["placed"]):
			placed += int(row["qty"])
	assert_true(lines <= Rules.BASKET_MAX_LINES, "≤ 4 distinct lines (%d)" % lines)
	assert_true(units <= Rules.BASKET_MAX_UNITS, "≤ 6 units (%d)" % units)
	assert_true(placed <= Rules.BASKET_MAX_PLACED, "≤ 3 placed units (%d)" % placed)
	assert_true((real["active"]["counter"] as Array).size() <= 7, "and the tray cannot overflow its 7 slots")
	assert_true((s["active"]["basket"] as Array).size() > 0, "the staged fixture is still a basket")

# ───────────────────────────── scan ─────────────────────────────

func test_scan_is_the_one_gesture_and_only_once() -> void:
	var s := _with_basket(_counter(), HAPPY_BASKET)
	var uid := _first_uid(s, "mate")
	var scanned := Rules.apply(s, {"type": "scan", "uid": uid})
	assert_false(is_same(scanned, s), "the Mate scans")
	assert_true(is_same(Rules.apply(scanned, {"type": "scan", "uid": uid}), scanned),
		"and a second scan of the same uid returns the state ITSELF, not a copy")
	assert_true(is_same(Rules.apply(s, {"type": "scan", "uid": 9999}), s), "an unknown uid is nothing")
	var v := Rules.view(scanned)
	assert_eq((v["register"]["lines"] as Array).size(), 1, "one line slid into the register")
	assert_eq(int(v["register"]["lines"][0]["qty"]), 1, "with one on it")
	assert_almost(float(v["register"]["total"]), float(v["register"]["lines"][0]["line_total"]), 0.001,
		"and the total is the claim")
	for entry in (v["counter"] as Array):
		if int((entry as Dictionary)["uid"]) == uid:
			assert_true(bool((entry as Dictionary)["scanned"]), "the tray sprite is marked scanned")

func test_scan_stands_down_at_the_wall_and_mid_sentence() -> void:
	var s := _with_basket(_counter(), HAPPY_BASKET)
	var uid := _first_uid(s, "mate")
	var wall := Rules.apply(s, {"type": "turn_around", "on": true})
	assert_eq(String(wall["view_mode"]), "wall", "turned around")
	assert_true(is_same(Rules.apply(wall, {"type": "scan", "uid": uid}), wall),
		"you cannot scan what is behind you")
	assert_true(is_same(Rules.apply(wall, {"type": "ring_up"}), wall), "nor ring up facing the wall")
	var talking := Rules.apply(s, {"type": "talk_next"})
	assert_true(Talk.is_open(talking), "the parade has a graph")
	assert_true(is_same(Rules.apply(talking, {"type": "scan", "uid": uid}), talking),
		"and nothing register-shaped happens mid-sentence")
	assert_true(is_same(Rules.apply(talking, {"type": "turn_around", "on": true}), talking),
		"including turning your back on somebody who is talking")

func test_a_second_pack_bumps_the_line_instead_of_adding_one() -> void:
	var s := _fetch_the_tobacco(_with_basket(_counter(), HAPPY_BASKET))
	s = _scan_all(s)
	var line := _line_of(s, "cigarettes", "adler")
	assert_true(line >= 0, "the two Adler are one line")
	assert_eq(int(s["active"]["register"]["lines"][line]["qty"]), 2, "bumped to 2")
	assert_eq((s["active"]["register"]["lines"] as Array).size(), 3, "three lines for three things")

# ───────────────────────────── the register's own edits ─────────────────────────────

func test_register_remove_returns_every_uid_to_the_counter() -> void:
	var s := _scan_all(_fetch_the_tobacco(_with_basket(_counter(), HAPPY_BASKET)))
	var line := _line_of(s, "cigarettes", "adler")
	var uids: Array = (s["active"]["register"]["lines"][line] as Dictionary)["uids"]
	var after := Rules.apply(s, {"type": "register_remove", "line": line})
	assert_eq((after["active"]["register"]["lines"] as Array).size(), 2, "the line is gone")
	for uid in uids:
		var item := Rules._counter_item(after, int(uid))
		assert_false(bool(item["scanned"]), "uid %d is back on the counter, unscanned" % int(uid))
	assert_true(is_same(Rules.apply(s, {"type": "register_remove", "line": 99}), s),
		"an index out of range changes nothing")
	assert_true(is_same(Rules.apply(s, {"type": "register_remove", "line": -1}), s), "and neither does -1")

func test_register_set_qty_clamps_and_unscans_the_surplus() -> void:
	var s := _scan_all(_fetch_the_tobacco(_with_basket(_counter(), HAPPY_BASKET)))
	var line := _line_of(s, "cigarettes", "adler")
	var lowered := Rules.apply(s, {"type": "register_set_qty", "line": line, "qty": 1})
	assert_eq(int(lowered["active"]["register"]["lines"][line]["qty"]), 1, "down to one")
	assert_eq(((lowered["active"]["register"]["lines"][line] as Dictionary)["uids"] as Array).size(), 1,
		"and the surplus pack let go of the line")
	var freed := 0
	for entry in (lowered["active"]["counter"] as Array):
		if String((entry as Dictionary)["sku"]) == "cigarettes" and not bool((entry as Dictionary)["scanned"]):
			freed += 1
	assert_eq(freed, 1, "…and is sitting on the counter again, rescannable")
	var high := Rules.apply(s, {"type": "register_set_qty", "line": line, "qty": 99})
	var stock := int(s["inventory"]["cigarettes"]["stock"])
	assert_eq(int(high["active"]["register"]["lines"][line]["qty"]), mini(Rules.REGISTER_QTY_MAX, stock),
		"clamped to 9 and to stock")
	var zero := Rules.apply(s, {"type": "register_set_qty", "line": line, "qty": 0})
	assert_eq(int(zero["active"]["register"]["lines"][line]["qty"]), 1, "never below one — that is `×`")
	assert_true(is_same(Rules.apply(s, {"type": "register_set_qty", "line": 42, "qty": 2}), s),
		"an index out of range changes nothing")

func test_a_lowered_qty_stops_at_the_shelf() -> void:
	var s := _with_basket(_counter(), [{"sku": "mate", "qty": 1}])
	s["inventory"]["mate"]["stock"] = 2
	s = _scan_all(s)
	var raised := Rules.apply(s, {"type": "register_set_qty", "line": 0, "qty": 9})
	assert_eq(int(raised["active"]["register"]["lines"][0]["qty"]), 2, "you cannot ring more than you have")

# ───────────────────────────── the wall ─────────────────────────────

func test_the_wall_respects_stock_and_the_hand() -> void:
	var s := Rules.apply(_with_basket(_counter(), HAPPY_BASKET), {"type": "turn_around", "on": true})
	for i in Rules.HAND_MAX:
		s = Rules.apply(s, {"type": "take_from_wall", "sku": "cigarettes", "brand": "adler"})
	assert_eq((s["active"]["hand"] as Array).size(), Rules.HAND_MAX, "two hands, four facings")
	assert_true(is_same(Rules.apply(s, {"type": "take_from_wall", "sku": "cigarettes", "brand": "adler"}), s),
		"and the fifth is refused")
	var empty := Rules.apply(_with_basket(_counter(), HAPPY_BASKET), {"type": "turn_around", "on": true})
	empty["inventory"]["cigarettes"]["stock"] = 0
	assert_true(is_same(Rules.apply(empty, {"type": "take_from_wall", "sku": "cigarettes", "brand": "adler"}), empty),
		"an empty rail hands you nothing")
	assert_true(is_same(Rules.apply(empty, {"type": "take_from_wall", "sku": "papers", "brand": "adler"}), empty),
		"and a facing that is not on that rail is not a facing")
	# Stock moves at the RING, not at the reach — the pack is in your hand, not sold.
	var one := Rules.apply(empty, {"type": "take_from_wall", "sku": "papers", "brand": "pap_feder_lang"})
	assert_eq(int(one["inventory"]["papers"]["stock"]), int(empty["inventory"]["papers"]["stock"]),
		"nothing left the shelf")

func test_take_from_wall_then_put_back_round_trips() -> void:
	var s := Rules.apply(_with_basket(_counter(), HAPPY_BASKET), {"type": "turn_around", "on": true})
	var before := SpatiState.to_json(s)
	var took := Rules.apply(s, {"type": "take_from_wall", "sku": "cigarettes", "brand": "nordstern"})
	var uid := int((took["active"]["hand"][0] as Dictionary)["uid"])
	var back := Rules.apply(took, {"type": "put_back", "uid": uid})
	assert_true((back["active"]["hand"] as Array).is_empty(), "the hand is empty again")
	# Everything is as it was but the uid counter, which only ever goes forward.
	var restored := SpatiState.clone(back)
	restored["next_item_uid"] = int(s["next_item_uid"])
	assert_eq(SpatiState.to_json(restored), before, "stock, lines and state are untouched")
	assert_true(int(back["next_item_uid"]) > int(s["next_item_uid"]), "and the uid counter never rewinds")

func test_what_you_carried_back_lands_on_the_tray() -> void:
	var s := _fetch_the_tobacco(_with_basket(_counter(), HAPPY_BASKET))
	assert_eq(String(s["view_mode"]), "counter", "home again")
	assert_true((s["active"]["hand"] as Array).is_empty(), "hands empty")
	var fetched := 0
	for entry in (s["active"]["counter"] as Array):
		if String((entry as Dictionary)["origin"]) == "wall":
			fetched += 1
	assert_eq(fetched, 3, "two packs and a booklet are on the counter")
	# Her own shopping is not yours to reshelve, and a scanned pack is a line.
	var wall := Rules.apply(s, {"type": "turn_around", "on": true})
	assert_true(is_same(Rules.apply(wall, {"type": "put_back", "uid": _first_uid(s, "mate")}), wall),
		"the Mate she brought stays on the counter")
	var scanned := Rules.apply(_scan_all(s), {"type": "turn_around", "on": true})
	var pack_uid := -1
	for entry in (scanned["active"]["counter"] as Array):
		if String((entry as Dictionary)["origin"]) == "wall":
			pack_uid = int((entry as Dictionary)["uid"])
			break
	assert_true(is_same(Rules.apply(scanned, {"type": "put_back", "uid": pack_uid}), scanned),
		"and a rung pack is a line, not a loose pack")

func test_turning_around_costs_night_and_patience() -> void:
	var s := _with_basket(_counter(), HAPPY_BASKET)
	var clock := int(s["clock_ms"])
	var patience := int(s["active"]["patience_left_ms"])
	var wall := Rules.apply(s, {"type": "turn_around", "on": true})
	assert_eq(int(wall["clock_ms"]), clock + Rules.TURN_MS, "the trip spends night clock")
	# Charged at the WALL's rate, because the pivot happens first: the wall costs something.
	assert_eq(int(wall["active"]["patience_left_ms"]),
		patience - int(round(float(Rules.TURN_MS) * Rules.BACK_PATIENCE_MULT)), "and her patience runs faster")
	assert_true(is_same(Rules.apply(wall, {"type": "turn_around", "on": true}), wall),
		"you cannot turn around twice in the same direction")
	var home := Rules.apply(wall, {"type": "turn_around", "on": false})
	assert_eq(int(home["clock_ms"]), clock + 2 * Rules.TURN_MS, "and the walk home costs the same clock")
	assert_eq(int(home["active"]["patience_left_ms"]),
		int(wall["active"]["patience_left_ms"]) - Rules.TURN_MS, "…at the counter's patience rate")

## The wall must never become a room with no door. A guest who balks while your back is turned takes
## `active` with them — and `turn_around{on:false}` has to survive that, in the reducer AND on the list.
func test_the_wall_always_has_a_way_home() -> void:
	var s := Rules.apply(_with_basket(_counter(), HAPPY_BASKET), {"type": "turn_around", "on": true})
	s["active"] = {}
	assert_true(_types(Rules.legal_actions(s)).has("turn_around"), "the way back is still offered")
	var home := Rules.apply(s, {"type": "turn_around", "on": false})
	assert_eq(String(home["view_mode"]), "counter", "and it works with nobody at the counter")
	# …and the shutters put you back at the counter whatever you were doing at 05:59.
	var closed := Rules.apply(Rules.apply(_with_basket(_counter(), HAPPY_BASKET), {"type": "turn_around", "on": true}),
		{"type": "close_night"})
	assert_eq(String(closed["view_mode"]), "counter", "the night ends facing the room")
	# …but you do not turn your back on an empty counter in the first place.
	var idle := _counter()
	idle["active"] = {}
	assert_true(is_same(Rules.apply(idle, {"type": "turn_around", "on": true}), idle),
		"nothing to fetch, no trip")
	assert_true((Rules.legal_actions(s) as Array).size() > 0, "and the night is never actionless")

# ───────────────────────────── the verdict ─────────────────────────────

func test_the_happy_path_rings_exactly() -> void:
	var s := _scan_all(_fetch_the_tobacco(_with_basket(_counter(), HAPPY_BASKET)))
	var v := Rules.view(s)
	for entry in (v["order"] as Array):
		assert_true(bool((entry as Dictionary)["satisfied"]), "%s ticked" % String((entry as Dictionary)["sku_id"]))
	for entry in (v["register"]["lines"] as Array):
		assert_true(bool((entry as Dictionary)["matches"]), "every line matches the order")
	assert_true(bool(v["register"]["can_ring"]), "and the drawer is ready")
	var cash := float(s["cash"])
	var packs := int(s["inventory"]["cigarettes"]["stock"])
	var sales := int(s["tally"]["sales"])
	var rung := Rules.apply(s, {"type": "ring_up"})
	assert_true(bool(rung["last_verdict"]["ok"]), "no errors")
	assert_almost(float(rung["last_verdict"]["accuracy"]), 1.0, 0.001, "accuracy 1.0")
	assert_eq(int(rung["inventory"]["cigarettes"]["stock"]), packs - 2, "two packs left the shelf")
	assert_true(float(rung["cash"]) > cash, "the till went up")
	assert_eq(int(rung["tally"]["sales"]), sales + 1, "one sale, one serve log, one _next_customer")
	assert_true((rung["active"] as Dictionary).is_empty(), "and the counter is clear")

func test_missing_scores_missing() -> void:
	var s := _with_basket(_counter(), [{"sku": "mate", "qty": 2}])
	var uid := _first_uid(s, "mate")
	s = Rules.apply(s, {"type": "scan", "uid": uid})
	var rung := _commit(s)
	var verdict: Dictionary = rung["last_verdict"]
	assert_eq((verdict["missing"] as Array).size(), 0, "half a line is not a missing line…")
	assert_eq((verdict["wrong_count"] as Array).size(), 1, "…it is the wrong number of them")
	assert_almost(float(verdict["accuracy"]), 0.5, 0.001, "1 error over 2 wanted units")
	var forgotten := _commit(_with_basket(_counter(), [{"sku": "mate", "qty": 1}, {"sku": "chips", "qty": 1}]))
	assert_almost(float(forgotten["last_verdict"]["accuracy"]), 0.0, 0.001, "ringing nothing is nothing right")
	assert_eq((forgotten["last_verdict"]["missing"] as Array).size(), 2, "both lines missing")

func test_extra_is_voided_not_quietly_profitable() -> void:
	var s := _with_basket(_counter(), [{"sku": "mate", "qty": 1}])
	s = _scan_all(s)
	# Ring something she never asked for: a pack off the wall.
	s = Rules.apply(s, {"type": "turn_around", "on": true})
	s = Rules.apply(s, {"type": "take_from_wall", "sku": "cigarettes", "brand": "adler"})
	s = Rules.apply(s, {"type": "turn_around", "on": false})
	s = _scan_all(s)
	var packs := int(s["inventory"]["cigarettes"]["stock"])
	var mates := int(s["inventory"]["mate"]["stock"])
	var cash := float(s["cash"])
	var mate_price := float(s["inventory"]["mate"]["price"])
	var rung := _commit(s)
	var verdict: Dictionary = rung["last_verdict"]
	assert_eq((verdict["extra"] as Array).size(), 1, "the pack is extra")
	assert_eq(int(rung["inventory"]["cigarettes"]["stock"]), packs, "no stock moved for it")
	assert_eq(int(rung["inventory"]["mate"]["stock"]), mates - 1, "…and the Mate still sold")
	assert_almost(float(rung["cash"]), Economy.round2(cash + mate_price), 0.001,
		"the shop never quietly profits from your mistake")

func test_the_wrong_pack_is_half_the_sin_and_still_sells() -> void:
	var s := _with_basket(_counter(), [{"sku": "cigarettes", "brand": "adler", "qty": 2}])
	s = Rules.apply(s, {"type": "turn_around", "on": true})
	s = Rules.apply(s, {"type": "take_from_wall", "sku": "cigarettes", "brand": "nordstern"})
	s = Rules.apply(s, {"type": "take_from_wall", "sku": "cigarettes", "brand": "nordstern"})
	s = _scan_all(Rules.apply(s, {"type": "turn_around", "on": false}))
	var v := Rules.view(s)
	assert_false(bool((v["register"]["lines"][0] as Dictionary)["matches"]),
		"the navy mark against her red chip: the line does not match")
	assert_false(bool((v["order"][0] as Dictionary)["satisfied"]), "and the chip does not tick")
	var packs := int(s["inventory"]["cigarettes"]["stock"])
	var rung := _commit(s)
	var verdict: Dictionary = rung["last_verdict"]
	assert_eq((verdict["wrong_brand"] as Array).size(), 1, "its own bucket")
	assert_eq(int((verdict["wrong_brand"][0] as Dictionary)["qty"]), 2, "two units of it")
	assert_almost(float(verdict["errors"]), 1.0, 0.001, "weighted HALF of extra: 2 × 0.5")
	assert_almost(float(verdict["accuracy"]), 0.5, 0.001, "1 error over 2 wanted units")
	assert_eq(int(rung["inventory"]["cigarettes"]["stock"]), packs - 2, "and they still sold — money follows the register")

func test_wrong_count_counts_the_delta() -> void:
	var s := _scan_all(_with_basket(_counter(), [{"sku": "mate", "qty": 1}]))
	s = Rules.apply(s, {"type": "register_set_qty", "line": 0, "qty": 3})
	var rung := _commit(s)
	var verdict: Dictionary = rung["last_verdict"]
	assert_eq((verdict["wrong_count"] as Array).size(), 1, "right key, wrong quantity")
	assert_eq(int((verdict["wrong_count"][0] as Dictionary)["qty"]), 2, "the delta counts")
	assert_almost(float(verdict["accuracy"]), 0.0, 0.001, "2 errors over 1 wanted unit, clamped")

func test_an_unnamed_mark_takes_any_facing() -> void:
	# The nameless parade asks for "cigarettes", not for Adler — any pack answers that (docs/08 §2).
	var s := _with_basket(_counter("regular", "cigarettes"), [{"sku": "cigarettes", "qty": 1}])
	s = Rules.apply(s, {"type": "turn_around", "on": true})
	s = Rules.apply(s, {"type": "take_from_wall", "sku": "cigarettes", "brand": "bergmann"})
	s = _scan_all(Rules.apply(s, {"type": "turn_around", "on": false}))
	assert_true(bool((Rules.view(s)["register"]["lines"][0] as Dictionary)["matches"]), "the line matches")
	var rung := Rules.apply(s, {"type": "ring_up"})
	assert_true(bool(rung["last_verdict"]["ok"]), "and it rings first time")

func test_the_id_check_refuses_instead_of_costing_integrity() -> void:
	var s := _with_basket(_counter("kid", "beer"), [{"sku": "beer", "qty": 1}])
	s = _scan_all(s)
	var integrity := float(s["reputation"]["integrity"])
	var bottles := int(s["inventory"]["beer"]["stock"])
	var cash := float(s["cash"])
	# Without the ID check this is today's path, unchanged: −8 Integrity, once.
	var sold := _commit(s)
	assert_almost(float(sold["reputation"]["integrity"]), integrity - 8.0, 0.001, "−8 Integrity")
	assert_eq(int(sold["inventory"]["beer"]["stock"]), bottles - 1, "the bottle left the shelf")
	# With it, the line is dropped at the ring: never charged, and NOT scored as missing.
	var checked := Rules.apply(s, {"type": "check_id"})
	assert_true(bool(Rules.view(checked)["register"]["id_checked"]), "the read-model says you asked")
	assert_true(is_same(Rules.apply(checked, {"type": "check_id"}), checked), "and you only ask once")
	var refused := Rules.apply(checked, {"type": "ring_up"})
	var verdict: Dictionary = refused["last_verdict"]
	assert_eq((verdict["refused"] as Array).size(), 1, "the line is refused")
	assert_true(bool(verdict["ok"]), "doing the right thing is not an error")
	assert_almost(float(verdict["accuracy"]), 1.0, 0.001, "…and is never scored as missing")
	assert_eq(int(refused["inventory"]["beer"]["stock"]), bottles, "nothing left the shelf")
	assert_almost(float(refused["reputation"]["integrity"]), integrity + 1.0, 0.001, "Integrity +1")
	assert_almost(float(refused["cash"]), cash, 0.001, "and it was never charged")
	# …and they are annoyed: the same kid, served something they were allowed to have, leaves the
	# corner more trusted than the one you turned down. That gap is the price of the spine.
	var allowed := _commit(_scan_all(_with_basket(_counter("kid", "energy"), [{"sku": "energy", "qty": 1}])))
	assert_true(float(refused["reputation"]["kiez"]) < float(allowed["reputation"]["kiez"]),
		"refusing costs Kiez-Trust that serving does not")

func test_two_restricted_units_cost_integrity_once_per_line() -> void:
	var s := _with_basket(_counter("kid", "beer"), [{"sku": "beer", "qty": 2}])
	s = _scan_all(s)
	var integrity := float(s["reputation"]["integrity"])
	var sold := _commit(s)
	assert_almost(float(sold["reputation"]["integrity"]), integrity - 8.0, 0.001,
		"two bottles to the same kid is ONE decision, not two")

# ───────────────────────────── the one free correction ─────────────────────────────

func test_the_first_bad_ring_up_is_rejected_and_the_second_commits() -> void:
	var s := _with_basket(_counter(), [{"sku": "cigarettes", "brand": "adler", "qty": 1}])
	s = Rules.apply(s, {"type": "turn_around", "on": true})
	s = Rules.apply(s, {"type": "take_from_wall", "sku": "cigarettes", "brand": "nordstern"})
	s = _scan_all(Rules.apply(s, {"type": "turn_around", "on": false}))
	var cash := float(s["cash"])
	var patience := int(s["active"]["patience_left_ms"])
	var rejected := Rules.apply(s, {"type": "ring_up"})
	assert_false(is_same(rejected, s), "the ring-up is a real action even when it is refused")
	assert_false((rejected["active"] as Dictionary).is_empty(), "she is still standing there")
	assert_eq(int(rejected["active"]["register"]["corrections"]), 1, "one correction spent")
	assert_eq(String(rejected["active"]["expression"]), "wary", "and her face says so")
	assert_eq(int(rejected["active"]["patience_left_ms"]), patience - Rules.CORRECTION_MS,
		"patience docks CORRECTION_MS")
	assert_almost(float(rejected["cash"]), cash, 0.001, "the drawer did not open")
	assert_eq(int(rejected["tally"]["sales"]), int(s["tally"]["sales"]), "and nothing was rung")
	var v := Rules.view(rejected)
	assert_ne(String(v["register"]["correction"]), "", "she says one line about it")
	assert_true((v["register"]["flagged"] as Array).has(0), "with the offending line already flagged")
	assert_true(bool(v["register"]["can_ring"]), "the register stays open")
	# Fix it the way the screen would: × the line, fetch the right pack, ring again.
	var fixed := Rules.apply(rejected, {"type": "register_remove", "line": 0})
	assert_true((fixed["active"]["register"]["flagged"] as Array).is_empty(), "the flag leaves with the line")
	fixed = Rules.apply(fixed, {"type": "turn_around", "on": true})
	fixed = Rules.apply(fixed, {"type": "take_from_wall", "sku": "cigarettes", "brand": "adler"})
	fixed = _scan_all(Rules.apply(fixed, {"type": "turn_around", "on": false}))
	var done := Rules.apply(fixed, {"type": "ring_up"})
	assert_true((done["active"] as Dictionary).is_empty(), "the second ring-up commits")
	assert_true(bool(done["last_verdict"]["ok"]), "…and it was right that time")

func test_the_correction_is_free_exactly_once() -> void:
	var s := _scan_all(_with_basket(_counter(), [{"sku": "mate", "qty": 2}]))
	s = Rules.apply(s, {"type": "register_set_qty", "line": 0, "qty": 1})
	var rejected := Rules.apply(s, {"type": "ring_up"})
	assert_false((rejected["active"] as Dictionary).is_empty(), "refused once")
	var committed := Rules.apply(rejected, {"type": "ring_up"})
	assert_true((committed["active"] as Dictionary).is_empty(), "and committed as rung the second time")
	assert_eq(int(committed["tally"]["sales"]), int(s["tally"]["sales"]) + 1, "money and all")
	# The miss penalty is proportional now (0.3 × sensitivity × (1 − accuracy)), so half an order
	# builds visibly less trust than the whole one — same guest, same night, same prices.
	var exact := Rules.apply(_scan_all(_with_basket(_counter(), [{"sku": "mate", "qty": 2}])), {"type": "ring_up"})
	assert_true((exact["active"] as Dictionary).is_empty(), "an exact order rings first time")
	assert_true(float(committed["reputation"]["kiez"]) < float(exact["reputation"]["kiez"]),
		"and it earns more trust than the half-rung one")

# ───────────────────────────── Pfand ─────────────────────────────

func test_pfand_is_a_ticket_line_with_one_clamp() -> void:
	var s := _with_basket(_counter("regular", "mate", 3), [{"sku": "mate", "qty": 1}])
	s = _scan_all(s)
	var forgotten := _commit(s)
	assert_eq((forgotten["last_verdict"]["missing"] as Array).size(), 1, "forgetting the deposit scores as missing")
	var taken := Rules.apply(s, {"type": "set_pfand", "bottles": 3})
	assert_eq(int(taken["active"]["register"]["pfand_bottles"]), 3, "three empties on the ticket")
	var over := Rules.apply(s, {"type": "set_pfand", "bottles": 99})
	assert_eq(int(over["active"]["register"]["pfand_bottles"]), 3, "clamped to what she carried in")
	var v := Rules.view(taken)
	assert_almost(float(v["register"]["pfand_line"]), 3.0 * Rules.PFAND_PER_BOTTLE, 0.001,
		"the deposit is PFAND_PER_BOTTLE × bottles, exactly")
	assert_almost(float(v["register"]["total"]),
		Economy.round2(float(v["register"]["subtotal"]) - float(v["register"]["pfand_line"])), 0.001,
		"and the total carries it as a minus")
	var cash := float(taken["cash"])
	var rung := Rules.apply(taken, {"type": "ring_up"})
	assert_true(bool(rung["last_verdict"]["ok"]), "returning it is part of the order")
	assert_eq(int(rung["pfand_held"]), 3, "the bottles are in the shop's crate")
	assert_almost(float(rung["tally"]["pfand_paid"]) - float(taken["tally"]["pfand_paid"]),
		float(v["register"]["pfand_line"]), 0.001, "the payout is the register's Pfand row, to the cent")
	var tip := float(rung["tally"]["tips"]) - float(taken["tally"]["tips"])
	assert_almost(float(rung["cash"]), Economy.round2(cash + float(v["register"]["total"]) + tip), 0.001,
		"and the till moved by exactly the register's total, plus whatever she left on top")

func test_the_crate_is_not_scannable() -> void:
	var s := _with_basket(_counter("regular", "mate", 2), [{"sku": "mate", "qty": 1}])
	var crate_uid := _first_uid(s, "pfand")
	assert_true(crate_uid > 0, "the crate is on the tray")
	assert_true(is_same(Rules.apply(s, {"type": "scan", "uid": crate_uid}), s),
		"a deposit is not a sale — it goes through set_pfand")
	for a in Rules.legal_actions(s):
		if String((a as Dictionary)["type"]) == "scan":
			assert_ne(int((a as Dictionary)["uid"]), crate_uid, "and it is never offered as a scan")

# ───────────────────────────── legality & the read-model ─────────────────────────────

## `view.register` is `{}` with nobody at the counter - the convention `view.wall` and `view.active`
## already keep, the one docs/08 section 4.1 gives `RegisterPanel` ("an empty dictionary is the
## pre-basket state"), and the one the whole Night chrome is derived from
## (`night.gd::_note_mode`: `_ringing = not register.is_empty()`). A zeroed ROW OF KEYS is not empty,
## so the shipped game sat in register mode all night: the queue never drew its line, the tray, the
## glass and the till column stood over an empty counter, and the want bubble, the plain order line
## and the d20 plate - every one of which stands down during a ring-up - were never seen again.
## Nothing caught it because every capture reads `MockView`, where the key really was `{}`.
## (Pointer probe, 2026-09-13.)
func test_the_register_is_empty_until_a_basket_lands_on_the_counter() -> void:
	var s := SpatiState.new_game({"seed": 11})
	s = Rules.apply(s, {"type": "open_night"})
	var quiet := Rules.view(s)
	assert_true((quiet["active"] as Dictionary).is_empty(), "nobody is at the counter yet")
	assert_true((quiet["register"] as Dictionary).is_empty(), "so there is no register open")
	assert_true((quiet["counter"] as Array).is_empty(), "and nothing on the laminate")
	assert_true((quiet["wall"] as Dictionary).is_empty(), "the same convention the wall keeps")
	assert_false((Rules.view(_with_basket(_counter(), HAPPY_BASKET))["register"] as Dictionary).is_empty(),
		"a basket on the counter is what opens it")

func test_legal_actions_offer_the_register_and_nothing_out_of_range() -> void:
	var s := _scan_all(_fetch_the_tobacco(_with_basket(_counter("regular", "mate", 2), HAPPY_BASKET)))
	var actions := Rules.legal_actions(s)
	var types := _types(actions)
	for want in ["ring_up", "turn_around", "register_remove", "register_set_qty", "set_pfand", "check_id"]:
		assert_true(types.has(want), "the counter offers " + want)
	assert_false(types.has("take_from_wall"), "but not the wall's verbs while you are facing the room")
	var lines := (s["active"]["register"]["lines"] as Array).size()
	for a in actions:
		var action: Dictionary = a
		if String(action["type"]).begins_with("register_"):
			assert_true(int(action["line"]) >= 0 and int(action["line"]) < lines, "never an index out of range")
		# Every offered action actually moves the state — a list that offers no-ops teaches a driver to lie.
		if String(action["type"]) in ["register_remove", "register_set_qty", "set_pfand", "check_id", "scan", "ring_up"]:
			assert_false(is_same(Rules.apply(s, action), s), "%s actually does something" % String(action["type"]))

func test_the_wall_offers_only_the_walls_verbs() -> void:
	var s := Rules.apply(_with_basket(_counter(), HAPPY_BASKET), {"type": "turn_around", "on": true})
	var types := _types(Rules.legal_actions(s))
	assert_true(types.has("take_from_wall"), "facings")
	assert_true(types.has("turn_around"), "and the way home")
	for forbidden in ["scan", "ring_up", "register_remove", "talk_next", "serve_active"]:
		assert_false(types.has(forbidden), "no " + forbidden + " with your back turned")
	# One `take_from_wall` per IN-STOCK facing, and none at all once your hands are full.
	var facings := 0
	for a in Rules.legal_actions(s):
		if String((a as Dictionary)["type"]) == "take_from_wall":
			facings += 1
	var expected := 0
	for def in Content.SKUS:
		if int(((s["inventory"] as Dictionary).get(String(def["id"]), {}) as Dictionary).get("stock", 0)) > 0:
			expected += Content.brands_for(String(def["id"])).size()
	assert_eq(facings, expected, "every in-stock facing, once")
	var full := s
	for i in Rules.HAND_MAX:
		full = Rules.apply(full, {"type": "take_from_wall", "sku": "cigarettes", "brand": "adler"})
	assert_false(_types(Rules.legal_actions(full)).has("take_from_wall"), "hands full, nothing offered")
	assert_true(_types(Rules.legal_actions(full)).has("put_back"), "but everything you hold can go back")

func test_nothing_register_shaped_is_offered_mid_sentence() -> void:
	var s := Rules.apply(_with_basket(_counter(), HAPPY_BASKET), {"type": "talk_next"})
	assert_true(Talk.is_open(s), "somebody is talking")
	var types := _types(Rules.legal_actions(s))
	for forbidden in ["scan", "ring_up", "register_remove", "register_set_qty", "turn_around", "set_pfand", "check_id"]:
		assert_false(types.has(forbidden), "no " + forbidden + " while a talk is open")

## docs/08 §2: three tiers, and which one you get is the ARCHETYPE's, never the screen's. A regular
## knows the wall by name; a stranger has to be read off it, which is the whole puzzle.
func test_a_regular_names_the_brand_and_a_stranger_points_at_it() -> void:
	var named := Rules.view(_fetch_the_tobacco(_with_basket(_counter("regular", "mate", 2), HAPPY_BASKET)))
	var pointed := Rules.view(_fetch_the_tobacco(_with_basket(_counter("student", "mate", 2), HAPPY_BASKET)))
	var told := 0
	for entry in (named["order"] as Array):
		var row: Dictionary = entry
		if String(row["brand"]) == "":
			continue
		told += 1
		assert_true(bool(row["name_shown"]), "a regular says the name out loud")
		assert_eq(String(row["brand_name"]), String(Content.brand(String(row["brand"]))["name"]),
			"…and the read-model hands it over")
		# A pack and a pouch are said by NAME ("Kranich"); a booklet or a box of filters is said by its
		# whole noun phrase ("long Feder papers"), because the variant is the identity (docs/09 §1
		# rule 1) and "Feder lang" is a catalogue entry, not something a person says out loud.
		var facing := Content.brand(String(row["brand"]))
		var family := String(facing["family"])
		var spoken_as := String(facing["name"]) if family in ["cigarettes", "tobacco"] else String(facing["spoken"])
		assert_true(String(row["said"]).contains(spoken_as), "…in her own words: " + String(row["said"]))
	assert_true(told > 0, "the basket had a brand to name")
	for entry in (pointed["order"] as Array):
		var row: Dictionary = entry
		if String(row["brand"]) == "":
			continue
		assert_false(bool(row["name_shown"]), "a stranger points instead")
		assert_eq(String(row["brand_name"]), "", "…and the read-model WITHHOLDS the name")
		var secret := String(Content.brand(String(row["brand"]))["name"])
		assert_false(String(row["said"]).contains(secret), "…so her words cannot leak it: " + secret)
		assert_true(String(row["said"]) != "", "she still says something")

func test_the_read_model_carries_the_whole_register() -> void:
	# `student` declares no `speech`, so it is the DEFAULT tier — `regular` and `insomniac` are the
	# two archetypes docs/08 §2 puts on the `name` tier, and they get their own assertion below.
	var s := _fetch_the_tobacco(_with_basket(_counter("student", "mate", 2), HAPPY_BASKET))
	var v := Rules.view(s)
	assert_eq(String(v["view_mode"]), "counter", "which way you are facing")
	assert_true((v["wall"] as Dictionary).is_empty(), "…and no wall while you are not at it")
	for entry in (v["counter"] as Array):
		var item: Dictionary = entry
		for key in ["uid", "sku_id", "name", "brand", "mark", "colour", "icon", "kind", "count", "scanned", "slot"]:
			assert_true(item.has(key), "counter row has " + key)
	assert_eq(int((v["counter"][0] as Dictionary)["slot"]), 0, "slots are the tray's own order")
	for key in ["lines", "pfand_bottles", "pfand_line", "subtotal", "total", "can_ring", "id_checked", "correction"]:
		assert_true((v["register"] as Dictionary).has(key), "register view has " + key)
	assert_eq((v["order"] as Array).size(), 4, "three lines and the Pfand chip")
	for entry in (v["order"] as Array):
		var row: Dictionary = entry
		for key in ["said", "qty", "category", "brand", "mark", "colour", "name_shown", "satisfied", "icon"]:
			assert_true(row.has(key), "order chip has " + key)
		# In `mark` mode the chip prints the swatch and the category and NEVER the brand name.
		assert_false(bool(row["name_shown"]), "the default archetype speaks in marks")
		assert_eq(String(row["brand_name"]), "", "so the read-model withholds the name")
	var named := SpatiState.clone(s)
	named["config"]["brand_hint"] = "name"
	assert_eq(String((Rules.view(named)["order"][1] as Dictionary)["brand_name"]), "Adler",
		"config.brand_hint is the mercy setting, and it is the engine that grants it")
	# The wall, seen from the wall.
	var wall := Rules.view(Rules.apply(s, {"type": "turn_around", "on": true}))
	assert_false((wall["wall"] as Dictionary).is_empty(), "turned around, the wall is in the read-model")
	var cells := 0
	for shelf in (wall["wall"]["shelves"] as Array):
		assert_ne(String((shelf as Dictionary)["label"]), "", "every rail is labelled with its SKU")
		assert_true(float((shelf as Dictionary)["price"]) > 0.0, "and carries the parent SKU's one price")
		cells += ((shelf as Dictionary)["cells"] as Array).size()
	assert_eq(cells, Content.BRANDS.size(), "every facing in the catalogue is on a rail")
	assert_eq(String(Rules.view(s)["active"]["customer"]["basket"][0]["sku"]), "mate",
		"and the customer's own basket rides in `active`")

# ───────────────────────────── the basket's tokens (docs/09 §0) ─────────────────────────────

## `{brand.<sku>}` is what she SAYS, `{logo.<sku>}` is the facing's asset id (a mark glyph, never
## spoken text) and `{qty.<sku>}` is how many. Substitution is per BASKET LINE: Achim orders three
## different tobacco products in one breath, and one `habits.brand` field cannot serve that sentence.
func test_the_basket_builds_the_talk_tokens() -> void:
	var s := _with_basket(_counter(), HAPPY_BASKET)
	var subs := Talk.subs_for(s)
	assert_eq(String(subs["{qty.cigarettes}"]), "2", "two of them")
	assert_eq(String(subs["{brand.cigarettes}"]), Content.brand_spoken("adler"), "said as the table says it")
	assert_eq(String(subs["{logo.cigarettes}"]), Content.brand_logo("adler"), "and shown as the facing")
	assert_eq(String(subs["{brand.papers}"]), "long Feder papers", "the variant IS the id — the length rides in the phrase")
	assert_eq(String(subs["{brand.mate}"]), "", "an unbranded line says nothing rather than saying null")
	assert_eq(String(subs["{want}"]), "Mate", "and {want} is untouched")
	# Both replace sites: the node's lines AND each choice's label (talk.gd `node_of`).
	var talking := Rules.apply(s, {"type": "talk_next"})
	var node := Talk.node_of(talking)
	for line in (node["lines"] as Array):
		assert_false(String(line).contains("{want}"), "no token survives into a spoken line")
	for choice in (node["choices"] as Array):
		assert_false(String((choice as Dictionary)["label"]).contains("{want}"), "nor into a label")
	assert_true(String((node["lines"] as Array)[0]).contains("Mate"), "…because the substitution happened")
	# A token the basket cannot answer is LEFT ALONE, so a tree is never broken by a basket that
	# lacks the SKU it names (test_tokens.gd is what fails the build for that — docs/09 §0).
	assert_eq(Talk._apply("{brand.vape} please", subs), "{brand.vape} please", "an unmatched token stands")

# ───────────────────────────── determinism & the save seam ─────────────────────────────

func test_the_whole_sequence_is_deterministic() -> void:
	var a := _play_a_register_turn(5)
	var b := _play_a_register_turn(5)
	assert_eq(SpatiState.to_json(a), SpatiState.to_json(b), "the same actions on the same seed are the same state")
	var text := SpatiState.to_json(a)
	assert_eq(SpatiState.to_json(SpatiState.from_json(text)), text, "and it round-trips through JSON byte for byte")

## A save from before docs/08 landed has no `view_mode`, no `next_item_uid`, no basket on the customer
## — and it must still load into a shop facing the counter rather than a dead Continue.
func test_an_older_save_normalises_into_the_register() -> void:
	var s := _with_basket(_counter(), HAPPY_BASKET)
	var old: Dictionary = SpatiState.clone(s)
	old.erase("view_mode")
	old.erase("next_item_uid")
	old.erase("last_verdict")
	(old["active"] as Dictionary).erase("basket")
	(old["active"] as Dictionary).erase("counter")
	(old["active"] as Dictionary).erase("register")
	(old["active"] as Dictionary).erase("hand")
	var back := SpatiState.from_json(JSON.stringify(old))
	assert_false(back.is_empty(), "an older save still loads")
	assert_eq(String(back["view_mode"]), "counter", "facing the counter")
	assert_eq(int(back["next_item_uid"]), 1, "with a fresh uid counter")
	assert_true((back["last_verdict"] as Dictionary).is_empty(), "and no verdict yet")
	assert_true((back["active"]["basket"] as Array).is_empty(), "the customer has an empty basket")
	assert_eq(int(back["active"]["register"]["pfand_bottles"]), 0, "and an empty register")
	assert_true(Rules.view(back) is Dictionary, "…and the read-model renders it without a crash")
	# The ints really are ints again, or the round-trip stops being byte-stable.
	var live := SpatiState.from_json(SpatiState.to_json(_play_a_register_turn(3)))
	assert_eq(typeof(live["next_item_uid"]), TYPE_INT, "next_item_uid is an int")
	assert_eq(typeof(live["last_verdict"]["wanted_units"]), TYPE_INT, "wanted_units is an int")
	assert_eq(typeof(live["last_verdict"]["accuracy"]), TYPE_FLOAT, "…and accuracy stays a float")

## The P&L identity still balances after a night of BASKET serves — the register lowers to the same
## `_serve`, so there is one money path and the books close the way they always did (docs/08 §6).
func test_twenty_basket_serves_still_balance() -> void:
	var s := AutoPlayer.manage(SpatiState.new_game({"seed": 11, "auto_take_next": true}))
	s = Rules.apply(s, {"type": "open_night"})
	var served := 0
	var guard := 0
	while served < 20 and guard < 6000:
		guard += 1
		s = Rules.tick(s, 400)
		if Talk.is_open(s):
			s = AutoPlayer.play_talk(s)
			continue
		if (s["active"] as Dictionary).is_empty() or not (s["story"]["pending"] as Dictionary).is_empty() \
			or String(s["story"]["pending_vignette"]) != "":
			continue
		s = _scan_all(_fetch_the_tobacco(s))
		if int(s["active"]["bottles"]) > 0:
			s = Rules.apply(s, {"type": "set_pfand", "bottles": int(s["active"]["bottles"])})
		var before := s
		s = Rules.apply(s, {"type": "ring_up"})
		if not (s["active"] as Dictionary).is_empty():
			s = Rules.apply(s, {"type": "ring_up"})  # the free correction, then commit
		if is_same(s, before):
			s = Rules.apply(s, {"type": "skip_active"})  # nothing rung and nothing to ring: wave off
			continue
		served += 1
	assert_eq(served, 20, "twenty baskets rang up (%d ticks)" % guard)
	s = Rules.apply(s, {"type": "close_night"})
	var sum: Dictionary = (s["summaries"] as Array).back()
	var expected := Economy.round2(float(sum["revenue"]) + float(sum["tips"]) - float(sum["cogs"])
		- float(sum["bills_due"]) - float(sum["pfand_paid"]))
	assert_almost(float(sum["profit"]), expected, 0.005, "profit = revenue + tips − cogs − bills − pfand − fines")
	assert_true(int(sum["sales"]) >= 20, "every basket was a sale (%d)" % int(sum["sales"]))

# ───────────────────────────── helpers that ring ─────────────────────────────

## Ring twice: the first bad ring-up is refused by design, so "commit" is press, press.
func _commit(s0: Dictionary) -> Dictionary:
	var s := Rules.apply(s0, {"type": "ring_up"})
	if not (s["active"] as Dictionary).is_empty():
		s = Rules.apply(s, {"type": "ring_up"})
	return s

## One whole register turn, from the queue to the drawer, driven by the real actions.
func _play_a_register_turn(seed_value: int) -> Dictionary:
	var s := SpatiState.new_game({"seed": seed_value, "auto_take_next": true})
	s["phase"] = "night"
	s["queue"] = [SpatiState.new_customer(1, "regular", "mate", 10000, "", "", "", 2)]
	s = Rules.tick(s, 1)
	s = _with_basket(s, HAPPY_BASKET)
	s = _fetch_the_tobacco(s)
	s = _scan_all(s)
	s = Rules.apply(s, {"type": "set_pfand", "bottles": 2})
	s = Rules.apply(s, {"type": "register_set_qty", "line": 0, "qty": 2})
	s = Rules.apply(s, {"type": "ring_up"})   # refused: the Mate line is now two
	s = Rules.apply(s, {"type": "register_set_qty", "line": 0, "qty": 1})
	return Rules.apply(s, {"type": "ring_up"})
