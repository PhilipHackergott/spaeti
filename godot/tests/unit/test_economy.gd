extends "res://tests/TestCase.gd"
## Price tiers, satisfaction/tips, Kiez deltas, traffic and the module shop — the numbers the whole
## economy hangs on (03-mvp-spec.md "Resolution rules").

func _beer() -> Dictionary:
	return Content.sku("beer")  # fair band 1.00 .. 1.90, cost 0.45

func test_price_tiers() -> void:
	assert_eq(Economy.price_tier(_beer(), 0.90), "steal", "under the band is a steal")
	assert_eq(Economy.price_tier(_beer(), 1.00), "fair", "the low edge is fair")
	assert_eq(Economy.price_tier(_beer(), 1.90), "fair", "the high edge is fair")
	assert_eq(Economy.price_tier(_beer(), 2.20), "high", "up to +25% is merely high")
	assert_eq(Economy.price_tier(_beer(), 2.50), "gouge", "beyond that is gouging")

func test_satisfaction_rewards_the_right_item_fast_and_fair() -> void:
	var good := Economy.satisfaction(true, "fair", 1.0)
	var wrong := Economy.satisfaction(false, "fair", 1.0)
	var gouged := Economy.satisfaction(true, "gouge", 1.0)
	var slow := Economy.satisfaction(true, "fair", 0.0)
	assert_almost(good, 1.0, 0.001, "right item, fair price, quick = capped happy")
	assert_true(wrong < good, "the wrong item disappoints")
	assert_true(gouged < good, "gouging disappoints")
	assert_true(slow < good, "dawdling disappoints")
	assert_true(Economy.satisfaction(false, "gouge", 0.0) >= 0.0, "never negative")

func test_tips_need_a_happy_customer() -> void:
	var tourist := Content.archetype("tourist")
	assert_almost(Economy.tip_for(tourist, 10.0, 0.4), 0.0, 0.001, "unhappy customers do not tip")
	assert_almost(Economy.tip_for(tourist, 10.0, 1.0), 6.0, 0.001, "tip_base 0.6 x total x satisfaction")
	assert_true(Economy.tip_for(Content.archetype("student"), 10.0, 1.0)
		< Economy.tip_for(tourist, 10.0, 1.0), "the broke student tips less than the tourist")

func test_kiez_delta_scales_with_sensitivity() -> void:
	var regular := Content.archetype("regular")   # sensitivity 1.4
	var tourist := Content.archetype("tourist")   # sensitivity 0.4
	assert_true(Economy.kiez_delta(regular, "gouge", false) < Economy.kiez_delta(tourist, "gouge", false),
		"gouging a regular hurts more than gouging a tourist")
	assert_true(Economy.kiez_delta(regular, "fair", false) > 0.0, "a fair sale builds trust")
	assert_almost(Economy.kiez_delta(regular, "fair", true), -1.4, 0.001, "a balk costs the full sensitivity")

func test_night_traffic_responds_to_trust_upgrades_and_sunday() -> void:
	var s := SpatiState.new_game()
	var base := Economy.night_traffic(s)
	assert_true(base > 40, "a busy Späti (%d)" % base)
	s["reputation"]["kiez"] = 90.0
	assert_true(Economy.night_traffic(s) > base, "trust brings footfall")
	s["reputation"]["kiez"] = 50.0
	(s["upgrades"] as Array).append("signage")
	assert_true(Economy.night_traffic(s) > base, "neon brings footfall")
	s["upgrades"] = []
	s["weekday"] = 6
	s["open_sunday"] = true
	assert_true(Economy.night_traffic(s) > base * 1.5, "Sunday is a spike — everyone else is shut")

func test_module_options_explain_the_lock() -> void:
	var s := SpatiState.new_game()
	var by_id := {}
	for option in Economy.module_options(s):
		by_id[option["def"]["id"]] = option
	assert_true(by_id["posters"]["available"], "posters are open from day 1")
	assert_true(by_id["posters"]["affordable"], "and cheap")
	assert_eq(by_id["espresso_bar"]["reason"], "needs Coffee machine", "prerequisite named")
	assert_eq(by_id["ice_cream_freezer"]["reason"], "unlocks on day 4", "day gate named")
	assert_true(by_id["bigger_fridge"]["affordable"], "a 200 fridge is within the 420 start cash")
	assert_false(by_id["espresso_bar"]["affordable"], "a 450 espresso bar is not")
	assert_eq(by_id["berlin_mural"]["reason"], "unlocks on day 11", "day gate wins over the trust gate")

func test_buying_an_upgrade_unlocks_its_skus() -> void:
	var s := SpatiState.new_game()
	s["day"] = 3
	s["cash"] = 1000.0
	s = Rules.apply(s, {"type": "buy_upgrade", "id": "coffee_machine"})
	assert_true((s["upgrades"] as Array).has("coffee_machine"), "owned")
	assert_true((s["inventory"] as Dictionary).has("coffee"), "coffee appears on the shelf")
	assert_eq(int(s["inventory"]["coffee"]["stock"]), 0, "with nothing in it yet")
	assert_almost(float(s["cash"]), 700.0, 0.001, "and it cost 300")

func test_corner_status_rolls_up_what_the_place_became() -> void:
	var s := SpatiState.new_game()
	s["upgrades"] = ["bench", "extra_menu", "security"]
	s["story"]["flags"] = ["busker"]
	var status := Economy.corner_status(s)
	assert_almost(float(status["kiez_per_night"]), 1.0, 0.001, "the bench earns trust nightly")
	assert_true(status["illegal"], "the extra menu is running")
	assert_true(status["has_security"], "the cam is up")
	assert_true((status["systems"] as Array).has("The bench draws a crowd"), "systems are labelled")
	assert_true((status["flags"] as Array).has("Live music out front"), "flags are labelled")
