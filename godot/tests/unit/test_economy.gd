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

## `satisfaction` widened from a bool to an accuracy for the register (docs/08 §3.4). The mapping
## `0.25 + 0.45 × accuracy` has to reproduce the old endpoints EXACTLY, or every number in the game
## moves under a change that was supposed to be a refactor.
func test_the_accuracy_mapping_keeps_the_old_endpoints() -> void:
	assert_almost(Economy.satisfaction(1.0, "fair", 1.0), Economy.satisfaction(true, "fair", 1.0), 0.000001,
		"accuracy 1.0 is the old `got_wanted` true")
	assert_almost(Economy.satisfaction(0.0, "fair", 1.0), Economy.satisfaction(false, "fair", 1.0), 0.000001,
		"accuracy 0.0 is the old false")
	assert_almost(Economy.satisfaction(1.0, "fair", 0.0) - Economy.satisfaction(0.0, "fair", 0.0), 0.45, 0.000001,
		"and the whole range between them is 0.45 wide")
	var half := Economy.satisfaction(0.5, "fair", 0.5)
	assert_true(half > Economy.satisfaction(0.0, "fair", 0.5) and half < Economy.satisfaction(1.0, "fair", 0.5),
		"half an order lands between the two — the register grades, it does not judge")

## The five buckets and the one score (docs/08 §3.4), on the function itself rather than through a
## night: `extra` and `missing` weigh a whole unit, the wrong mark weighs half.
func test_order_accuracy_weighs_the_wrong_mark_at_half() -> void:
	var order := [{"sku": "cigarettes", "brand": "adler", "qty": 2}]
	var exact := Economy.order_accuracy(order, [{"sku": "cigarettes", "brand": "adler", "qty": 2}], {})
	assert_true(bool(exact["ok"]), "the right two packs is no errors at all")
	var navy := Economy.order_accuracy(order, [{"sku": "cigarettes", "brand": "nordstern", "qty": 2}], {})
	assert_almost(float(navy["errors"]), 1.0, 0.001, "two wrong marks weigh 2 × 0.5")
	var invented := Economy.order_accuracy(order, [{"sku": "cigarettes", "brand": "adler", "qty": 2},
		{"sku": "chips", "brand": "", "qty": 2}], {})
	assert_almost(float(invented["errors"]), 2.0, 0.001, "…and two invented units weigh 2 × 1")
	assert_true(float(navy["accuracy"]) > float(invented["accuracy"]),
		"reaching for the navy pack is a different sin from inventing a sale")
	var nothing := Economy.order_accuracy(order, [], {})
	assert_almost(float(nothing["accuracy"]), 0.0, 0.001, "and ringing nothing is nothing right")

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
	# A branch chosen in a conversation is on the board too, or the choice was theatre (docs/06 §3).
	s["story"]["flags"] = ["busker", "lena_sketch", "lena_tab", "lena_credit"]
	var talked := Economy.corner_status(s)
	assert_true((talked["flags"] as Array).has("Lena's sketch by the register"), "a dialogue flag is labelled")
	# lena_tab and lena_credit are the same standing; the panel says it once.
	assert_eq((talked["flags"] as Array).count("Lena's tab"), 1, "one tab, one line")
	# ...and the board can only print it because the read-model carries it (rules.gd view()).
	var v: Dictionary = Rules.view(s)["manage"]["status"]
	assert_true((v["flags"] as Array).has("Lena's sketch by the register"), "and the screen is handed it")
