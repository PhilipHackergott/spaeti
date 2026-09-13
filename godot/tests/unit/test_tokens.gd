extends "res://tests/TestCase.gd"
## docs/09 §6 item 6 — the soft-lock rule applied to content: NEVER TRUST A NAME, ASSERT AGAINST THE
## READ-MODEL. A basket token is a promise that the speaker's order actually contains that SKU, and
## `Talk._apply` leaves an unmatched token alone — so a typo does not crash, it PRINTS. A line reading
## "Two of the {brand.cigarettes}, bitte." on a counter at 03:00 is exactly the class of failure the
## register's soft-lock was: silent, shipped, and invisible to every other test.
##
## The three families (docs/09 §0, substituted per BASKET LINE by `Talk.subs_for`):
##   {qty.<sku>}    the quantity on that basket line
##   {brand.<sku>}  `Content.brand_spoken` — the noun phrase a customer SAYS ("long Feder papers")
##   {logo.<sku>}   `Content.brand_logo`   — the facing's ASSET ID, an inline mark glyph, never words
## `{want}` is the older, per-customer substitution and belongs to `Talk.want_name_of`, not here.

## Families whose value comes out of the BRAND table rather than the basket row itself.
const BRANDED := ["brand", "logo"]

func _token_re() -> RegEx:
	return RegEx.create_from_string("\\{(qty|brand|logo)\\.([a-z_]+)\\}")

## Every `{...}` of any shape, so a misspelt family ("{brnd.cigarettes}") cannot hide by not matching.
func _any_token_re() -> RegEx:
	return RegEx.create_from_string("\\{([^}]*)\\}")

## The character whose basket answers for this node. A graph node names its speaker; when it does not
## (the nameless parade), the graph is keyed by character id, so the tree id is the fallback.
func _speaker_of(dialogue_id: String, node: Dictionary) -> String:
	var speaker := String(node.get("speaker", ""))
	return speaker if speaker != "" else dialogue_id

## Every authored string a player can be SHOWN, with where it came from and who is speaking.
func _authored_text() -> Array:
	var out: Array = []
	for id in Content.DIALOGUES:
		var nodes: Dictionary = Content.DIALOGUES[id]["nodes"]
		for node_id in nodes:
			var node: Dictionary = nodes[node_id]
			var who := _speaker_of(String(id), node)
			for line in (node["lines"] as Array):
				out.append({"where": "%s/%s line" % [id, node_id], "who": who, "text": String(line)})
			for choice in (node["choices"] as Array):
				out.append({"where": "%s/%s label" % [id, node_id], "who": who,
					"text": String((choice as Dictionary).get("label", ""))})
	# The persona card's authored order line is the same promise from the other direction (docs/09 §5
	# rule 2): it must speak the same basket the tree's first node speaks.
	for ch in Content.CHARACTERS:
		var order_line := String(ch.get("order_line", ""))
		if order_line != "":
			out.append({"where": "%s/order_line" % ch["id"], "who": String(ch["id"]), "text": order_line})
	return out

## sku id -> the basket row, for whoever is speaking. {} for a face with no persona card.
func _basket_index(character_id: String) -> Dictionary:
	var out: Dictionary = {}
	for row in Content.basket_for(character_id):
		out[String((row as Dictionary).get("sku", ""))] = row
	return out

func test_every_basket_token_names_a_sku_the_speaker_actually_carries() -> void:
	var re := _token_re()
	var checked := 0
	for row in _authored_text():
		var who := String(row["who"])
		var basket := _basket_index(who)
		for m in re.search_all(String(row["text"])):
			checked += 1
			var family := m.get_string(1)
			var sku_id := m.get_string(2)
			assert_false(Content.sku(sku_id).is_empty(),
				"%s: {%s.%s} names a real SKU" % [row["where"], family, sku_id])
			assert_true(basket.has(sku_id),
				"%s: %s's basket carries %s (it says {%s.%s})" % [row["where"], who, sku_id, family, sku_id])
	assert_true(checked >= 20, "the trees really do speak the basket (%d tokens)" % checked)

func test_every_branded_token_resolves_through_the_brand_table() -> void:
	# A `{brand.*}` on a basket line with no `brand` id substitutes to "" — the sentence loses its noun
	# and reads as a missing word, not as an error. Same for `{logo.*}` and the facing asset id.
	var re := _token_re()
	for row in _authored_text():
		var basket := _basket_index(String(row["who"]))
		for m in re.search_all(String(row["text"])):
			var family := m.get_string(1)
			if not BRANDED.has(family):
				continue
			var sku_id := m.get_string(2)
			if not basket.has(sku_id):
				continue  # already reported by the test above
			var brand_id := String((basket[sku_id] as Dictionary).get("brand", ""))
			assert_ne(brand_id, "", "%s: the %s line names a brand" % [row["where"], sku_id])
			assert_false(Content.brand(brand_id).is_empty(),
				"%s: %s is a row in brands.gd" % [row["where"], brand_id])
			if family == "brand":
				assert_true(Content.brand_spoken(brand_id).length() > 0,
					"%s: %s has something a customer can say" % [row["where"], brand_id])
			else:
				assert_true(Content.brand_logo(brand_id).begins_with("tob/"),
					"%s: %s resolves to a facing asset id" % [row["where"], brand_id])

func test_no_authored_string_carries_an_unknown_token() -> void:
	# The failure mode this catches is a family typo: `_apply` matches nothing, so "{brnd.cigarettes}"
	# reaches the DialogueBox verbatim and the test above never sees it.
	var known := _token_re()
	var any := _any_token_re()
	for row in _authored_text():
		var text := String(row["text"])
		for m in any.search_all(text):
			var whole := m.get_string(0)
			if whole == "{want}":
				continue
			assert_true(known.search(whole) != null,
				"%s: %s is a token the substitution knows" % [row["where"], whole])

func test_every_persona_basket_is_servable() -> void:
	# `basket` is the single source of the order (docs/09 §5 rule 1): every line has to name a SKU the
	# shop can stock, a positive quantity, and — for tobacco — a brand that is a variant of THAT SKU.
	# A brand on the wrong SKU is how the wall hands you a pouch when she asked for a pack.
	var carded := 0
	for ch in Content.CHARACTERS:
		var basket: Array = ch.get("basket", [])
		if basket.is_empty():
			continue
		carded += 1
		var seen: Dictionary = {}
		for entry in basket:
			var line: Dictionary = entry
			var sku_id := String(line.get("sku", ""))
			var sku := Content.sku(sku_id)
			assert_false(sku.is_empty(), "%s's basket names a real SKU: %s" % [ch["id"], sku_id])
			assert_false(seen.has(sku_id), "%s orders %s on one line, not two" % [ch["id"], sku_id])
			seen[sku_id] = true
			assert_true(int(line.get("qty", 0)) >= 1, "%s: %s has a quantity" % [ch["id"], sku_id])
			var brand_id := String(line.get("brand", ""))
			if brand_id == "":
				assert_ne(String(sku.get("category", "")), "tobacco",
					"%s: a tobacco line off the wall carries a brand (%s)" % [ch["id"], sku_id])
				continue
			var brand := Content.brand(brand_id)
			assert_false(brand.is_empty(), "%s: %s is a row in brands.gd" % [ch["id"], brand_id])
			assert_eq(String(brand.get("sku", "")), sku_id,
				"%s: %s is a variant of %s, not of something else" % [ch["id"], brand_id, sku_id])
			var on_shelf := false
			for facing in Content.brands_for(sku_id):
				if String((facing as Dictionary)["id"]) == brand_id:
					on_shelf = true
			assert_true(on_shelf, "%s: %s is on %s's shelf of the wall" % [ch["id"], brand_id, sku_id])
	assert_eq(carded, 11, "all eleven guests have a basket to serve (got %d)" % carded)

func test_nadias_basket_has_no_tobacco_line_on_purpose() -> void:
	# docs/09 §2.7: she quit eleven years ago and the wall still argues with her every night. The
	# register has to serve an ABSENCE — this is a test case, not an omission, and a well-meaning
	# edit that "completes" her order would delete the beat.
	for entry in Content.basket_for("nadia"):
		assert_ne(String(Content.sku(String((entry as Dictionary)["sku"])).get("category", "")), "tobacco",
			"Nadia buys nothing off the wall: " + String((entry as Dictionary)["sku"]))
	var speaks := false
	for node_id in (Content.DIALOGUES["nadia"]["nodes"] as Dictionary):
		for line in (Content.DIALOGUES["nadia"]["nodes"][node_id]["lines"] as Array):
			if String(line).contains("row"):
				speaks = true
	assert_true(speaks, "and her tree still looks at the wall")

## Every guest with a tree, in registry order — the eleven of docs/09 §2.
const GUESTS := ["lena", "juergen", "mehmet", "schulz", "achim", "karim", "nadia", "tobias",
	"robin", "aylin", "bley"]

func test_no_token_survives_to_the_screen() -> void:
	# THE ONE THAT MATTERS, and the only one that checks the REAL read-model. The tests above read the
	# AUTHORED basket; `Rules._place_basket` then truncates it to the reducer's caps (4 lines / 6 units
	# / 3 placed, rules.gd:30) and drops any SKU the shop has not unlocked. `Talk._apply` leaves what it
	# cannot match alone — so a token whose line was truncated away does not fail, it PRINTS
	# "{brand.filters}" into a sentence on the counter at 03:00. Walk each guest's whole tree through
	# `Rules.view` and assert nothing in curly braces ever reaches the box.
	var any := _any_token_re()
	for id in GUESTS:
		var s := SpatiState.new_game({"seed": 4})
		s["phase"] = "night"
		s["queue"] = [SpatiState.new_customer(1, String(Content.character(id)["archetype_id"]), "mate", 10000, id)]
		s = Rules.apply(s, {"type": "talk_next"})
		assert_false((s["active"] as Dictionary).is_empty(), "%s stepped up" % id)
		var steps := 0
		while Talk.is_open(s) and steps < 40:
			steps += 1
			var view: Dictionary = Rules.view(s)["talk"]
			var shown: Array = (view["lines"] as Array).duplicate()
			for choice in (view["choices"] as Array):
				shown.append(String((choice as Dictionary)["label"]))
			for text in shown:
				for m in any.search_all(String(text)):
					fail("%s/%s: %s reached the box unsubstituted — %s"
						% [id, String(s["talk"]["node"]), m.get_string(0), String(text)])
			var advanced := false
			for a in Rules.legal_actions(s):
				if String(a["type"]) == "talk_advance":
					s = Rules.apply(s, a)
					advanced = true
					break
			if not advanced:
				s = Rules.apply(s, {"type": "talk_choose", "choice": 0})
		assert_false(Talk.is_open(s), "%s's tree closed in %d steps" % [id, steps])
