class_name Rules
extends RefCounted
## The reducer: `apply(state, action) -> new state`. PURE — it clones first and never touches the
## dictionary it was handed; an illegal action returns the SAME state object back, so callers can test
## legality with `Rules.apply(s, a) == s` (and Session.dispatch reports false).
## Port of app/src/engine/rules.ts + legal.ts, with the counter-fired story of engine-api §4.

const PFAND_PER_BOTTLE := 0.15
## The most empties one guest can carry in. `pfand_held` is the SHOP's crate awaiting wholesaler
## credit — it is not what the person at the counter is holding, and paying out against it let one
## guest double the crate on every serve (0 -> 1 -> 2 -> 4 -> 8 …). What they brought is their own.
const PFAND_MAX_RETURN := 6

# ───────────────────────── the register (docs/08 §3) ─────────────────────────
## Turning your body costs night, not just an animation: the wall is a trip, and a trip is the only
## thing in the slice that spends the clock without a customer moving.
const TURN_MS := 1200
## What you can carry back from the wall in one trip. Four facings, two hands.
const HAND_MAX := 4
## The one free correction (docs/08 §3.4): the first bad ring-up is refused and costs patience.
const CORRECTION_MS := 8000
## Patience runs faster while your back is turned — 1.15, not 1.35: this is Coffee Talk pace.
const BACK_PATIENCE_MULT := 1.15
## …and any basket with tobacco in it is granted the trip up front, so the wall is a rhythm, not a panic.
const TOBACCO_PATIENCE_BONUS_MS := 4000

## Reducer caps, not UI caps (docs/08 §3.1): ≤ 4 distinct goods lines, ≤ 6 units, ≤ 3 of them physically
## placed on the counter. The tray therefore cannot overflow its 7 slots (3 placed + 3 fetched + 1
## crate) and a content mistake cannot break the frame.
const BASKET_MAX_LINES := 4
const BASKET_MAX_UNITS := 6
const BASKET_MAX_PLACED := 3
## A register line is 1..9 of one thing; past that it is a wholesale order, not a Späti.
const REGISTER_QTY_MAX := 9
## The crate is a request like any other, so forgetting the deposit scores as `missing` (docs/08 §3.5).
## It is deliberately NOT a SKU: nothing can charge for it and nothing can take it off a shelf.
const PFAND_SKU := Economy.PFAND_KEY

## What she says when the first ring-up is wrong (docs/08 §3.4) — one line, in character enough to
## read as a person and short enough to fit the one-line box. The reducer also carries the BUCKET ID
## (`view.register.correction_kind`), and `Strings.CORRECTION_BY_KIND` holds the same four sentences,
## so the box takes the words from the string table and this stays the fallback for anyone reading
## the reducer alone. `test_scenes.gd` pins the two tables together the way it pins the stat names.
const CORRECTION_LINES := {
	"wrong_brand": "That's not the one, love. Look at the mark.",
	"extra": "I didn't take that one.",
	"missing": "There's something missing there.",
	"wrong_count": "Not that many — count them again.",
}
const CORRECTION_FALLBACK := "That's not quite my order."

## How a customer asks for a line of her basket (docs/08 §2). MIRROR of `Strings.ASK_*` — the reducer
## is pure and may not import a component, exactly as `STAT_NAMES` mirrors `Strings.STAT_NAMES`;
## `test_scenes.gd::test_the_two_ask_tables_agree` fails the build if the two ever drift.
## NOTE THE LOWERCASE x, the same one `QTY` uses: Jersey 10 has no × glyph and a missing glyph
## prints as a HOLE, not as a multiplication sign. `said` is a player-visible sentence, so it obeys
## the same rule the rest of the pool does.
const ASK_CIGS := "%dx %s — cigarettes."
const ASK_POUCH := "%dx %s — rolling tobacco."
const ASK_ITEM := "%dx %s."
const ASK_PFAND := "%dx Pfand."
const ASK_MARK_PHRASE := "the ones with the %s"
const ASK_POINT := "the %s"

## Night length maps linearly onto a 20:00 → 06:00 night for the clock label.
const NIGHT_START_MIN := 20 * 60
const NIGHT_MINUTES := 10 * 60

## The six stats, in the order the strip prints them (docs/06 §1). Names are what a player reads.
const STAT_IDS := ["str", "dex", "con", "int", "wis", "cha"]
## Späti-flavoured names for the six D&D-style stats (user decision): the ids stay str/dex/con/int/wis/cha so the
## mechanics read as 5e; the words are the Kiez's. "Schnauze" = Berliner Schnauze, the gift of the gab (CHA).
const STAT_NAMES := {
	"str": "Muscle", "dex": "Hands", "con": "Stamina",
	"int": "Brains", "wis": "Kiez Sense", "cha": "Schnauze",
}
## Every check is one d20 against a DC, the 5e way (docs/06 §2).
const DIE_FACES := 20

## The UI is German throughout, so the weekday the HUD and the summary print is German too.
const WEEKDAY_NAMES := ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

# ───────────────────────────────── the reducer ─────────────────────────────────

static func apply(s: Dictionary, action: Dictionary) -> Dictionary:
	var type: String = action.get("type", "")
	var n := SpatiState.clone(s)
	match type:
		"open_night":
			if s["phase"] != "manage":
				return s
			var rng := Rng.from_state(int(n["rng_state"]))
			n["arrivals"] = _build_arrivals(n, rng)
			StoryFlow.schedule_beats(n, rng)  # cast arrivals ride tonight's schedule (§4)
			n["rng_state"] = rng.state()
			n["phase"] = "night"
			n["clock_ms"] = 0
			n["next_arrival"] = 0
			n["queue"] = []
			n["active"] = {}
			n["talk"] = {}
			n["tally"] = SpatiState.new_tally()
			_log(n, "open", "Night %d opens — %d customers expected." % [int(n["day"]), (n["arrivals"] as Array).size()])
			return n
		"tick":
			if s["phase"] != "night":
				return s
			_tick(n, int(action.get("dt_ms", 0)))
			return n
		"serve_active":
			if s["phase"] != "night" or (s["active"] as Dictionary).is_empty() or _dialogue_pending(s):
				return s
			_serve(n, action.get("give", []), int(action.get("pfand_bottles", 0)))
			return n
		"skip_active":
			if (s["active"] as Dictionary).is_empty() or _dialogue_pending(s):
				return s
			n["reputation"]["kiez"] = Economy.clamp_meter(float(n["reputation"]["kiez"]) - 0.1)
			_next_customer(n)
			return n
		# ───────────────── the register (docs/08 §3.2) ─────────────────
		# Drag is a SKIN over `scan{uid}`: pointer, click and key all land here, so a headless test
		# plays the same gesture the hand does.
		"scan":
			if not _register_open(s) or String(s.get("view_mode", "counter")) != "counter":
				return s
			return n if _scan(n, int(action.get("uid", -1))) else s
		"register_remove":
			if not _register_open(s):
				return s
			return n if _register_remove(n, int(action.get("line", -1))) else s
		"register_set_qty":
			if not _register_open(s):
				return s
			return n if _register_set_qty(n, int(action.get("line", -1)), int(action.get("qty", 0))) else s
		"turn_around":
			if s["phase"] != "night" or _dialogue_pending(s):
				return s
			return n if _turn_around(n, bool(action.get("on", false))) else s
		"take_from_wall":
			if not _register_open(s) or String(s.get("view_mode", "counter")) != "wall":
				return s
			return n if _take_from_wall(n, String(action.get("sku", "")), String(action.get("brand", ""))) else s
		"put_back":
			if not _register_open(s) or String(s.get("view_mode", "counter")) != "wall":
				return s
			return n if _put_back(n, int(action.get("uid", -1))) else s
		"set_pfand":
			if not _register_open(s):
				return s
			return n if _set_pfand(n, int(action.get("bottles", 0))) else s
		"check_id":
			# A real Späti verb, free in the reducer — and the only thing that turns a restricted line
			# into a `refused` one instead of an Integrity hit (docs/08 §3.4).
			if not _register_open(s) or bool(s["active"]["register"]["id_checked"]):
				return s
			n["active"]["register"]["id_checked"] = true
			return n
		"ring_up":
			if not _register_open(s) or String(s.get("view_mode", "counter")) != "counter":
				return s
			var register: Dictionary = s["active"]["register"]
			if (register["lines"] as Array).is_empty() and int(register["pfand_bottles"]) <= 0:
				return s
			_ring_up(n)
			return n
		# The four board intents are MANAGE-only: the wholesaler comes before opening, not at 03:00.
		# `legal_actions` has always said so; without these guards the reducer disagreed with it.
		"set_price":
			if s["phase"] != "manage":
				return s
			var sku_id: String = action.get("sku", "")
			if not (n["inventory"] as Dictionary).has(sku_id):
				return s
			n["inventory"][sku_id]["price"] = maxf(0.0, Economy.round2(float(action.get("price", 0.0))))
			return n
		"restock":
			if s["phase"] != "manage":
				return s
			return n if _restock(n, action.get("sku", ""), int(action.get("qty", 0))) else s
		"buy_upgrade":
			if s["phase"] != "manage":
				return s
			return n if _buy_upgrade(n, action.get("id", "")) else s
		"set_sunday_open":
			if s["phase"] != "manage":
				return s
			n["open_sunday"] = bool(action.get("open", false))
			return n
		"talk_next":
			# Take the head of the queue (FIFO) and open the conversation (docs/06 §4).
			if s["phase"] != "night" or Talk.is_open(s):
				return s
			if (n["active"] as Dictionary).is_empty():
				if (n["queue"] as Array).is_empty():
					return s
				_take_next(n)  # may itself open a beat talk — then that IS tonight's conversation
				if Talk.is_open(n):
					return n
			return n if _open_talk(n) else s
		"talk_advance":
			if not Talk.is_open(s):
				return s
			return n if _talk_advance(n) else s
		"talk_choose":
			if not Talk.is_open(s):
				return s
			return n if _talk_choose(n, int(action.get("choice", 0))) else s
		"resolve_beat":
			# The legacy name for `talk_choose` on a beat — the shipped DialogueBox still speaks it.
			if Talk.is_open(s):
				return n if _talk_choose(n, int(action.get("choice", 0))) else s
			if (s["story"]["pending"] as Dictionary).is_empty():
				return s
			_log_choice(n, "beat", int(action.get("choice", 0)))
			StoryFlow.apply_beat_choice(n, int(action.get("choice", 0)))
			return n
		"resolve_vignette":
			if Talk.is_open(s):
				return n if _talk_choose(n, int(action.get("choice", 0))) else s
			if s["story"]["pending_vignette"] == "":
				return s
			_log_choice(n, "vignette", int(action.get("choice", 0)))
			StoryFlow.apply_vignette_choice(n, int(action.get("choice", 0)))
			return n
		"close_night":
			if s["phase"] != "night":
				return s
			_close_night(n)
			return n
		"advance_day":
			if s["phase"] != "summary":
				return s
			_advance_day(n)
			return n
	return s

## Convenience wrapper — the render loop's only self-sent action.
static func tick(s: Dictionary, dt_ms: int) -> Dictionary:
	return apply(s, {"type": "tick", "dt_ms": dt_ms})

# ───────────────────────────────── night mechanics ─────────────────────────────────

static func _build_arrivals(s: Dictionary, rng: Rng) -> Array:
	var count := Economy.night_traffic(s)
	var night_len := int(s["config"]["night_len_ms"])
	var available: Array = (s["inventory"] as Dictionary).keys()
	var arch_weights: Array = []
	for arch in Content.ARCHETYPES:
		var curve: Array = arch["curve"]
		arch_weights.append(float(curve[0]) + float(curve[1]) + float(curve[2]))
	var out: Array = []
	for i in count:
		var arch: Dictionary = Content.ARCHETYPES[rng.weighted_index(arch_weights)]
		var third := rng.weighted_index(arch["curve"])
		var time_ms := int(rng.range(float(third) / 3.0 * float(night_len), float(third + 1) / 3.0 * float(night_len)))
		out.append({
			"time_ms": time_ms,
			"archetype_id": arch["id"],
			"want": StoryFlow.pick_want(rng, arch["wants"], arch["wants"], available),
			"character_id": "",
			"beat_id": "",
			"vignette_id": "",
			# What this one is carrying back. One more draw off the same seeded rng, so a night still
			# replays exactly from {config, seed, actions}.
			"bottles": rng.randi_below(PFAND_MAX_RETURN + 1),
		})
	out.sort_custom(func(a, b): return int(a["time_ms"]) < int(b["time_ms"]))
	return out

static func _tick(n: Dictionary, dt_ms: int) -> void:
	n["clock_ms"] = int(n["clock_ms"]) + dt_ms
	var arrivals: Array = n["arrivals"]
	while int(n["next_arrival"]) < arrivals.size() and int(arrivals[int(n["next_arrival"])]["time_ms"]) <= int(n["clock_ms"]):
		var a: Dictionary = arrivals[int(n["next_arrival"])]
		n["next_arrival"] = int(n["next_arrival"]) + 1
		var arch := Content.archetype(a["archetype_id"])
		(n["queue"] as Array).append(SpatiState.new_customer(
			int(n["next_customer_id"]), a["archetype_id"], a["want"], int(arch["patience_ms"]),
			a.get("character_id", ""), a.get("beat_id", ""), a.get("vignette_id", ""),
			int(a.get("bottles", 0))))
		n["next_customer_id"] = int(n["next_customer_id"]) + 1
	var active: Dictionary = n["active"]
	if not active.is_empty() and not _dialogue_pending(n):
		# Patience only runs while you are free to serve: a pending beat is a conversation, not a queue
		# (Coffee Talk, not a timer) — otherwise the story customer could balk mid-sentence.
		# Your back being turned is the one thing that makes it run FASTER (docs/08 §1) — the wall costs
		# something, or the trip is free and the tobacco game is a menu.
		var wall_mult := BACK_PATIENCE_MULT if String(n.get("view_mode", "counter")) == "wall" else 1.0
		active["patience_left_ms"] = int(active["patience_left_ms"]) - int(roundf(float(dt_ms) * wall_mult))
		if int(active["patience_left_ms"]) <= 0:
			var arch := Content.archetype(active["archetype_id"])
			n["tally"]["lost"] = int(n["tally"]["lost"]) + 1
			n["reputation"]["kiez"] = Economy.clamp_meter(float(n["reputation"]["kiez"]) + Economy.kiez_delta(arch, "fair", true))
			_log(n, "balk", "%s got tired of waiting and left." % arch["name"])
			n["active"] = {}
	# The LINE is the slice (docs/06 §5): guests wait at the register until you take the next one (`talk_next`),
	# and while they wait their patience runs — ignore the line and it thins out. `config.auto_take_next`
	# restores the old behaviour (the head of the queue steps up by itself) for the serve-loop sims and tests.
	if _auto_take_next(n):
		if (n["active"] as Dictionary).is_empty() and not (n["queue"] as Array).is_empty():
			_take_next(n)
	else:
		_age_queue(n, dt_ms)

static func _auto_take_next(n: Dictionary) -> bool:
	return bool((n["config"] as Dictionary).get("auto_take_next", false))

## Waiting guests lose patience too (story guests wait forever — their beat is tonight's conversation).
static func _age_queue(n: Dictionary, dt_ms: int) -> void:
	var queue: Array = n["queue"]
	var i := 0
	while i < queue.size():
		var c: Dictionary = queue[i]
		if String(c.get("character_id", "")) != "" or String(c.get("beat_id", "")) != "" or String(c.get("vignette_id", "")) != "":
			i += 1
			continue
		c["patience_left_ms"] = int(c["patience_left_ms"]) - dt_ms
		if int(c["patience_left_ms"]) <= 0:
			var arch := Content.archetype(c["archetype_id"])
			n["tally"]["lost"] = int(n["tally"]["lost"]) + 1
			n["reputation"]["kiez"] = Economy.clamp_meter(float(n["reputation"]["kiez"]) + Economy.kiez_delta(arch, "fair", true) * 0.5)
			_log(n, "balk", "%s gave up on the line and left." % arch["name"])
			queue.remove_at(i)
		else:
			i += 1

## Move the head of the queue to the counter and let the story notice (§4).
static func _take_next(n: Dictionary) -> void:
	n["active"] = (n["queue"] as Array).pop_front()
	var arch := Content.archetype(n["active"]["archetype_id"])
	_log(n, "arrive", "%s steps up to the counter." % arch.get("name", "Someone"))
	_place_basket(n)  # their order becomes objects in front of you (docs/08 §1)
	StoryFlow.on_customer_active(n)
	_open_story_talk(n)  # a beat/vignette IS a conversation now (docs/06 §4) — one box, one source

## Clear the counter. With `auto_take_next` the next person steps up by themselves; otherwise the line waits
## for `talk_next` (the slice's "one guest at a time").
static func _next_customer(n: Dictionary) -> void:
	n["active"] = {}
	if _auto_take_next(n) and not (n["queue"] as Array).is_empty():
		_take_next(n)

## The ONE money path. `accuracy` < 0 means "the legacy single-want serve": the score is then the old
## `got_wanted` bool, 1.0 or 0.0, which `Economy.satisfaction` maps to exactly the endpoints it always
## had. `ring_up` lowers to this with the register's real accuracy (docs/08 §3.6), so there is one
## serve log entry, one tip, one `_next_customer` — and one place stock and cash move.
static func _serve(n: Dictionary, give: Array, pfand_bottles: int, accuracy: float = -1.0) -> void:
	var active: Dictionary = n["active"]
	# You can only take back what they brought. The clamp lives HERE, not in the till: a component may
	# not invent a quantity that moves cash, and this makes over-claiming impossible from any caller.
	pfand_bottles = clampi(pfand_bottles, 0, int(active.get("bottles", 0)))
	var arch := Content.archetype(active["archetype_id"])
	var want: String = active["want"]
	var total := 0.0
	var got_wanted := false
	var want_inv: Dictionary = (n["inventory"] as Dictionary).get(want, {})
	var worst_tier := Economy.price_tier(Content.sku(want), float(want_inv.get("price", 0.0)))
	# −8 Integrity is charged ONCE PER LINE, not once per unit (docs/08 §3.4): two packs to the same
	# kid is one decision. The single-want path gives one unit at a time, so this changes nothing there.
	var penalised: Dictionary = {}
	for id in give:
		var inv: Dictionary = (n["inventory"] as Dictionary).get(id, {})
		var def := Content.sku(id)
		if inv.is_empty() or def.is_empty() or int(inv["stock"]) <= 0:
			continue  # can't give what you don't have
		inv["stock"] = int(inv["stock"]) - 1
		var price := float(inv["price"])
		total += price
		n["tally"]["revenue"] = float(n["tally"]["revenue"]) + price
		n["tally"]["cogs"] = float(n["tally"]["cogs"]) + float(def["cost"])
		n["cash"] = float(n["cash"]) + price
		if id == want:
			got_wanted = true
		var tier := Economy.price_tier(def, price)
		if int(Economy.TIER_RANK[tier]) > int(Economy.TIER_RANK[worst_tier]):
			worst_tier = tier
		if def.get("restricted", false) and arch.get("underage", false) and not penalised.has(id):
			penalised[id] = true
			n["reputation"]["integrity"] = maxf(0.0, float(n["reputation"]["integrity"]) - 8.0)
			_log(n, "ethics", "Sold %s to a minor — Integrity hit." % def["name"])
	if pfand_bottles > 0:
		var payout := Economy.round2(float(pfand_bottles) * PFAND_PER_BOTTLE)
		n["cash"] = float(n["cash"]) - payout
		n["tally"]["pfand_paid"] = float(n["tally"]["pfand_paid"]) + payout
		n["pfand_held"] = int(n["pfand_held"]) + pfand_bottles
		_log(n, "pfand", "Paid out €%.2f Pfand for %d bottles." % [payout, pfand_bottles])
	var promptness := float(active["patience_left_ms"]) / maxf(1.0, float(arch["patience_ms"]))
	var over_budget := total > float(arch["budget"])
	# One score, one path: the register's accuracy when it rang the order, the old bool otherwise.
	var acc := accuracy if accuracy >= 0.0 else (1.0 if got_wanted else 0.0)
	var sat := 0.2 if over_budget else Economy.satisfaction(acc, worst_tier, promptness)
	var tip := Economy.tip_for(arch, total, sat)
	n["cash"] = float(n["cash"]) + tip
	n["tally"]["tips"] = float(n["tally"]["tips"]) + tip
	# The generalised miss penalty (docs/08 §3.4): 0.3 × sensitivity × (1 − accuracy) is the old
	# all-or-nothing rule at the endpoints and a proportional one everywhere in between.
	var miss_penalty := 0.3 * float(arch["kiez_sensitivity"]) * (1.0 - clampf(acc, 0.0, 1.0))
	n["reputation"]["kiez"] = Economy.clamp_meter(float(n["reputation"]["kiez"]) + Economy.kiez_delta(arch, worst_tier, false) - miss_penalty)
	n["reputation"]["profit"] = Economy.clamp_meter(float(n["reputation"]["profit"]) + (0.2 if total > 0.0 else 0.0))
	n["tally"]["sales"] = int(n["tally"]["sales"]) + 1
	n["cash"] = Economy.round2(float(n["cash"]))
	_log(n, "serve", "%s served — €%.2f." % [arch["name"], total])
	if tip > 0.0:
		_log(n, "tip", "Tip: €%.2f." % tip)
	_next_customer(n)

# ───────────────────────── the register (docs/08 §3) ─────────────────────────

## Is the till live? Night, somebody at the counter, and nobody mid-sentence — the same three
## conditions the serve has always had, named once so every register verb agrees with the others.
## The fourth is a shape check: a customer minted before the register existed (or by a tool writing a
## raw dictionary) has no till to open, and every verb below indexes `active.register` unguarded.
static func _register_open(s: Dictionary) -> bool:
	if s["phase"] != "night" or _dialogue_pending(s):
		return false
	var active: Dictionary = s["active"]
	return not active.is_empty() and (active.get("register", {}) as Dictionary).has("lines")

## `place_basket`, engine-internal (docs/08 §3.2): the moment they reach the counter their order
## becomes objects in front of you. The cast's own `basket` rows win; anyone else's want is a
## one-line basket, which is exactly what the nameless parade has always been.
static func _place_basket(n: Dictionary) -> void:
	var active: Dictionary = n["active"]
	if active.is_empty() or not (active.get("basket", []) as Array).is_empty():
		return
	var basket: Array = []
	var units := 0
	var placed := 0
	var tobacco := false
	for entry in _basket_rows(active):
		var row: Dictionary = entry
		if basket.size() >= BASKET_MAX_LINES or units >= BASKET_MAX_UNITS:
			break
		var sku_id := String(row.get("sku", ""))
		var def := Content.sku(sku_id)
		if def.is_empty() or not (n["inventory"] as Dictionary).has(sku_id):
			continue
		# Behind the counter is behind the counter: tobacco is a trip to the wall, everything else is
		# a thing she can put down in front of you. A tobacco SKU with NO facings (the vape stand) has
		# no cell to fetch from, so it lands on the counter — or its line could never be rung at all.
		var on_counter := String(def.get("category", "")) != "tobacco" or Content.brands_for(sku_id).is_empty()
		var qty := mini(maxi(1, int(row.get("qty", 1))), BASKET_MAX_UNITS - units)
		if on_counter:
			qty = mini(qty, BASKET_MAX_PLACED - placed)
		if qty <= 0:
			continue
		var brand := String(row.get("brand", ""))
		if brand != "" and String(Content.brand(brand).get("sku", "")) != sku_id:
			brand = ""  # a stale id never prints as a mark this shelf cannot sell
		basket.append({"sku": sku_id, "brand": brand, "qty": qty, "said": String(row.get("said", "")),
			"placed": on_counter})
		units += qty
		if on_counter:
			placed += qty
		else:
			tobacco = true
	if basket.is_empty():
		# Their want is always in the inventory (`pick_want` picks from the shelf), so this is the
		# parade's basket, not an error path.
		basket.append({"sku": String(active.get("want", "")), "brand": "", "qty": 1, "said": "", "placed": true})
	# `active.want` stays `basket[0].sku` — which keeps `{want}`, the WantBubble and the docs/06 §7
	# auto-serve working untouched (docs/08 §3.1).
	active["want"] = String((basket[0] as Dictionary)["sku"])
	var counter: Array = []
	for entry in basket:
		var row: Dictionary = entry
		if not bool(row["placed"]):
			continue
		for i in int(row["qty"]):
			counter.append({"uid": _next_uid(n), "sku": String(row["sku"]), "brand": String(row["brand"]),
				"kind": "item", "count": 1, "scanned": false, "origin": "customer"})
	var bottles := int(active.get("bottles", 0))
	if bottles > 0:
		# ONE crate with a ×N badge, not N loose bottles — three empties would eat the tray (docs/08 §3.5).
		counter.append({"uid": _next_uid(n), "sku": PFAND_SKU, "brand": "", "kind": "crate",
			"count": bottles, "scanned": false, "origin": "customer"})
		# …and it is a ticket line too, so FORGETTING the deposit scores as `missing`. Appended last, so
		# `basket[0]` is always a real SKU.
		basket.append({"sku": PFAND_SKU, "brand": "", "qty": bottles, "said": "", "placed": true})
	active["basket"] = basket
	active["counter"] = counter
	if tobacco:
		# The wall trip is paid for in advance (docs/08 §1), so turning around is a rhythm, not a panic.
		active["patience_left_ms"] = int(active["patience_left_ms"]) + TOBACCO_PATIENCE_BONUS_MS

## The rows `place_basket` works from: the persona card's basket (docs/09 §5) if the cast lane has
## written one, else the single want the archetype spawned with.
static func _basket_rows(active: Dictionary) -> Array:
	var character := Content.character(String(active.get("character_id", "")))
	var rows: Array = character.get("basket", [])
	if not rows.is_empty():
		return rows
	return [{"sku": String(active.get("want", "")), "qty": 1}]

## Item ids are unique for the whole run and live TOP LEVEL: a pack you carried back from the wall
## keeps its identity even if the customer it was for walks out while you are still turned around.
static func _next_uid(n: Dictionary) -> int:
	var uid := int(n.get("next_item_uid", 1))
	n["next_item_uid"] = uid + 1
	return uid

## The counter item with this uid, BY REFERENCE (the caller writes `scanned` through it), or {}.
static func _counter_item(s: Dictionary, uid: int) -> Dictionary:
	for item in ((s["active"] as Dictionary).get("counter", []) as Array):
		if int((item as Dictionary)["uid"]) == uid:
			return item
	return {}

## `scan{uid}` — the whole gesture, whether it arrived as a drag, a click or the space bar.
static func _scan(n: Dictionary, uid: int) -> bool:
	var item := _counter_item(n, uid)
	if item.is_empty() or String(item["kind"]) == "crate" or bool(item["scanned"]):
		return false  # the crate is a deposit, not a sale — it goes through `set_pfand`
	item["scanned"] = true
	_register_add(n, item)
	return true

## A second Adler does not add a line: it bumps the existing one (docs/08 §1). Lines are keyed
## `(sku, brand)`, which is the same key the verdict scores on.
static func _register_add(n: Dictionary, item: Dictionary) -> void:
	var lines: Array = n["active"]["register"]["lines"]
	for entry in lines:
		var line: Dictionary = entry
		if String(line["sku"]) == String(item["sku"]) and String(line["brand"]) == String(item["brand"]):
			line["qty"] = int(line["qty"]) + 1
			(line["uids"] as Array).append(int(item["uid"]))
			return
	lines.append({"sku": String(item["sku"]), "brand": String(item["brand"]), "qty": 1,
		"uids": [int(item["uid"])]})

## `register_remove{line}` — every uid on it goes back to `scanned:false`, so the pack is on the
## counter again and can be rescanned or put back.
static func _register_remove(n: Dictionary, index: int) -> bool:
	var register: Dictionary = n["active"]["register"]
	var lines: Array = register["lines"]
	if index < 0 or index >= lines.size():
		return false
	for uid in ((lines[index] as Dictionary)["uids"] as Array):
		_unscan(n, int(uid))
	lines.remove_at(index)
	register["flagged"] = _reindex_flags(register["flagged"] as Array, index)
	return true

## `register_set_qty{line, qty}` — clamped 1..9 and to stock; lowering below the number of scanned
## units un-scans the surplus, because the counter is the physical truth and the register is a claim.
static func _register_set_qty(n: Dictionary, index: int, qty: int) -> bool:
	var lines: Array = n["active"]["register"]["lines"]
	if index < 0 or index >= lines.size():
		return false
	var line: Dictionary = lines[index]
	var stock := int(((n["inventory"] as Dictionary).get(String(line["sku"]), {}) as Dictionary).get("stock", 0))
	var capped := clampi(qty, 1, clampi(stock, 1, REGISTER_QTY_MAX))
	if capped == int(line["qty"]):
		return false
	line["qty"] = capped
	var uids: Array = line["uids"]
	while uids.size() > capped:
		_unscan(n, int(uids.pop_back()))
	return true

static func _unscan(n: Dictionary, uid: int) -> void:
	var item := _counter_item(n, uid)
	if not item.is_empty():
		item["scanned"] = false

## Line indices shift when a line leaves; the amber flags have to shift with them or they point at
## somebody else's mistake.
static func _reindex_flags(flagged: Array, removed: int) -> Array:
	var out: Array = []
	for f in flagged:
		var i := int(f)
		if i == removed:
			continue
		out.append(i - 1 if i > removed else i)
	return out

## `turn_around{on}` — a pivot, and it costs `TURN_MS` of night.
static func _turn_around(n: Dictionary, on: bool) -> bool:
	var at_wall := String(n.get("view_mode", "counter")) == "wall"
	if on == at_wall:
		return false
	# Turning TO the wall needs somebody to fetch for. Turning BACK is ALWAYS legal — a guest who
	# balks while your back is turned must never leave you in a room with no door (the soft-lock rule).
	if on and (n["active"] as Dictionary).is_empty():
		return false
	n["view_mode"] = "wall" if on else "counter"
	if not on:
		_land_hand(n)
	# The clock is charged AFTER the pivot, so the walk to the wall runs at the wall's patience rate
	# and the walk home runs at the counter's.
	_tick(n, TURN_MS)
	return true

## Back at the counter, what you carried lands on the tray where there was space.
static func _land_hand(n: Dictionary) -> void:
	var active: Dictionary = n["active"]
	if active.is_empty() or not active.has("hand"):
		return
	var counter: Array = active["counter"]
	for held in (active["hand"] as Array):
		counter.append({"uid": int((held as Dictionary)["uid"]), "sku": String((held as Dictionary)["sku"]),
			"brand": String((held as Dictionary)["brand"]), "kind": "item", "count": 1,
			"scanned": false, "origin": "wall"})
	active["hand"] = []

## `take_from_wall{sku, brand}` — nothing stops you taking the wrong pack: the wall does not know what
## she wants. Stock does not move here; it moves when the line survives the ring-up.
static func _take_from_wall(n: Dictionary, sku_id: String, brand: String) -> bool:
	var active: Dictionary = n["active"]
	var inv: Dictionary = (n["inventory"] as Dictionary).get(sku_id, {})
	if inv.is_empty() or int(inv["stock"]) <= 0:
		return false
	if (active["hand"] as Array).size() >= HAND_MAX:
		return false
	if String(Content.brand(brand).get("sku", "")) != sku_id:
		return false  # that facing is not on this SKU's rail
	(active["hand"] as Array).append({"uid": _next_uid(n), "sku": sku_id, "brand": brand})
	return true

## `put_back{uid}` — out of the hand, or off the tray if it came off the wall and has not been rung.
## Her own shopping is not yours to reshelve.
static func _put_back(n: Dictionary, uid: int) -> bool:
	var active: Dictionary = n["active"]
	var hand: Array = active["hand"]
	for i in hand.size():
		if int((hand[i] as Dictionary)["uid"]) == uid:
			hand.remove_at(i)
			return true
	var counter: Array = active["counter"]
	for i in counter.size():
		var item: Dictionary = counter[i]
		if int(item["uid"]) != uid:
			continue
		if String(item.get("origin", "")) != "wall" or bool(item["scanned"]):
			return false
		counter.remove_at(i)
		return true
	return false

## `set_pfand{bottles}` — one clamp, in the reducer, so neither the crate's drag nor the row's
## `−`/`+` can invent a quantity that moves cash.
static func _set_pfand(n: Dictionary, bottles: int) -> bool:
	var active: Dictionary = n["active"]
	var register: Dictionary = active["register"]
	var capped := clampi(bottles, 0, int(active.get("bottles", 0)))
	if capped == int(register["pfand_bottles"]):
		return false
	register["pfand_bottles"] = capped
	return true

## `ring_up` — the verdict, the one free correction, and then the ordinary serve (docs/08 §3.4/§3.6).
static func _ring_up(n: Dictionary) -> void:
	var active: Dictionary = n["active"]
	var register: Dictionary = active["register"]
	var arch := Content.archetype(String(active["archetype_id"]))
	var verdict := Economy.order_accuracy(active["basket"], _scored_lines(register), arch,
		bool(register["id_checked"]))
	n["last_verdict"] = verdict
	var accuracy := float(verdict["accuracy"])
	var lines: Array = register["lines"]
	if accuracy < 1.0 and int(register["corrections"]) == 0:
		# Forgiving once, consequential twice: the drawer does not open, the offending lines are
		# already flagged, the register stays open and she says so in one line.
		register["corrections"] = 1
		register["flagged"] = _flagged_lines(verdict, lines.size())
		register["correction"] = _correction_line(verdict)
		register["correction_kind"] = _correction_kind(verdict)
		active["expression"] = "wary"
		active["patience_left_ms"] = int(active["patience_left_ms"]) - CORRECTION_MS
		_log(n, "misring", "%s: %s" % [Talk.guest_name(active), String(register["correction"])],
			_verdict_data(verdict))
		return
	# Voided: a key she never asked for earns nothing and moves no stock, and an ID'd restricted line
	# is dropped before it can be charged.
	var voided: Dictionary = {}
	for entry in (verdict["extra"] as Array):
		voided[int((entry as Dictionary)["line"])] = true
	for entry in (verdict["refused"] as Array):
		voided[int((entry as Dictionary)["line"])] = true
	var give: Array = []
	for i in lines.size():
		if voided.has(i):
			continue
		var line: Dictionary = lines[i]
		for k in int(line["qty"]):
			give.append(String(line["sku"]))
	if not (verdict["refused"] as Array).is_empty():
		# Integrity +1 and the Kiez is annoyed — that is the price of the spine (docs/08 §3.4).
		var refused_names := ""
		for entry in (verdict["refused"] as Array):
			var sku_name := String(Content.sku(String((entry as Dictionary)["sku"])).get("name", "it"))
			refused_names = sku_name if refused_names == "" else refused_names + ", " + sku_name
		n["reputation"]["integrity"] = Economy.clamp_meter(float(n["reputation"]["integrity"]) + 1.0)
		n["reputation"]["kiez"] = Economy.clamp_meter(float(n["reputation"]["kiez"])
			- 0.2 * float(arch.get("kiez_sensitivity", 1.0)))
		_log(n, "ethics", "ID checked — refused %s." % refused_names,
			{"refused": (verdict["refused"] as Array).size()})
	if accuracy < 1.0:
		# The diff rides in `data`: it is what the box reads to pick her reaction.
		_log(n, "misring", "%s took it as rung." % Talk.guest_name(active), _verdict_data(verdict))
	_serve(n, give, int(register["pfand_bottles"]), accuracy)

## The lines the verdict scores: the register's own, plus the Pfand as one more request. Its index is
## past the real lines, so voiding it can never void a real one.
static func _scored_lines(register: Dictionary) -> Array:
	var out: Array = (register["lines"] as Array).duplicate(true)
	if int(register["pfand_bottles"]) > 0:
		out.append({"sku": PFAND_SKU, "brand": "", "qty": int(register["pfand_bottles"]), "uids": []})
	return out

## Which lines wear the amber edge — everything the verdict can point at, real lines only.
static func _flagged_lines(verdict: Dictionary, line_count: int) -> Array:
	var out: Array = []
	for bucket in ["wrong_brand", "wrong_count", "extra"]:
		for entry in (verdict[bucket] as Array):
			var i := int((entry as Dictionary).get("line", -1))
			if i >= 0 and i < line_count and not out.has(i):
				out.append(i)
	out.sort()
	return out

## One line, in character, naming the worst thing first.
static func _correction_line(verdict: Dictionary) -> String:
	return String(CORRECTION_LINES.get(_correction_kind(verdict), CORRECTION_FALLBACK))

## WHICH bucket she is complaining about — the worst thing first, and the only half of this the
## reducer really owns. The words come from `Strings.CORRECTION_BY_KIND` on the way to the box.
static func _correction_kind(verdict: Dictionary) -> String:
	for bucket in ["wrong_brand", "extra", "missing", "wrong_count"]:
		if not (verdict[bucket] as Array).is_empty():
			return bucket
	return ""

## The log payload. Whole numbers only: `data` goes through `_normalise_data`, which re-integers
## integral floats — an `accuracy` of 1.0 would come back as `1` and break the byte-stable round-trip.
static func _verdict_data(verdict: Dictionary) -> Dictionary:
	return {
		"accuracy_pct": int(floorf(float(verdict["accuracy"]) * 100.0 + 0.5)),
		"missing": (verdict["missing"] as Array).size(),
		"extra": (verdict["extra"] as Array).size(),
		"wrong_brand": (verdict["wrong_brand"] as Array).size(),
		"wrong_count": (verdict["wrong_count"] as Array).size(),
		"refused": (verdict["refused"] as Array).size(),
	}

## What a basket asked for, keyed the way the verdict keys it — the read-model's `matches` and
## `satisfied` both read this, so a screen cannot have its own opinion about correctness.
static func _want_units(basket: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry in basket:
		var row: Dictionary = entry
		var key := String(row.get("sku", "")) + "|" + String(row.get("brand", ""))
		out[key] = int(out.get(key, 0)) + int(row.get("qty", 0))
	return out

## What a restock ACTUALLY costs after the crate's Pfand credit — the same arithmetic `_restock`
## charges below, so `legal_actions` and the board's "+" gate on exactly what the reducer will accept
## (with a full crate a restock goes through on 0,00 € cash; the old `cost <= cash` denied it).
static func restock_cost(s: Dictionary, sku_id: String, qty: int) -> float:
	var def := Content.sku(sku_id)
	if def.is_empty() or not (s["inventory"] as Dictionary).has(sku_id) or qty <= 0:
		return -1.0
	var credit := float(s["pfand_held"]) * PFAND_PER_BOTTLE
	return Economy.round2(maxf(0.0, float(qty) * float(def["cost"]) - credit))

## Will `apply(s, {restock})` move the stock? The one affordability rule the UI may ask.
static func can_restock(s: Dictionary, sku_id: String, qty: int) -> bool:
	var cost := restock_cost(s, sku_id, qty)
	return cost >= 0.0 and cost <= float(s["cash"])

static func _restock(n: Dictionary, sku_id: String, qty: int) -> bool:
	var def := Content.sku(sku_id)
	var inv: Dictionary = (n["inventory"] as Dictionary).get(sku_id, {})
	if def.is_empty() or inv.is_empty() or qty <= 0:
		return false
	var cost := float(qty) * float(def["cost"])
	# Bottles in the crate become wholesaler credit on the next order (spec: Pfand).
	var credit := float(n["pfand_held"]) * PFAND_PER_BOTTLE
	if credit > 0.0:
		var used := minf(credit, cost)
		cost -= used
		n["pfand_held"] = maxi(0, int(n["pfand_held"]) - int(floorf(used / PFAND_PER_BOTTLE + 0.5)))
	cost = Economy.round2(cost)
	if cost > float(n["cash"]):
		return false
	n["cash"] = Economy.round2(float(n["cash"]) - cost)
	inv["stock"] = int(inv["stock"]) + qty
	return true

static func _buy_upgrade(n: Dictionary, id: String) -> bool:
	var def := Content.upgrade(id)
	if def.is_empty() or (n["upgrades"] as Array).has(id) or float(def["cost"]) > float(n["cash"]):
		return false
	if Economy.unlock_reason(n, def) != "":  # prerequisite / day / Kiez-Trust gating (GDD §4c)
		return false
	n["cash"] = Economy.round2(float(n["cash"]) - float(def["cost"]))
	(n["upgrades"] as Array).append(id)
	for sku_id in def["effects"].get("unlocks_sku", []):
		if not (n["inventory"] as Dictionary).has(sku_id):
			var sku := Content.sku(sku_id)
			n["inventory"][sku_id] = {"stock": 0, "price": float(sku.get("base_price", 1.0))}
	_log(n, "upgrade", "Bought %s." % def["name"])
	return true

static func _close_night(n: Dictionary) -> void:
	var bills_due := float(n["config"]["rent_per_day"])
	n["cash"] = float(n["cash"]) - bills_due
	var fine := 0.0
	# The Sunday (Ladenschluss) gamble: trading brazenly raises the heat, and the roll scales with it.
	if int(n["weekday"]) == 6 and bool(n["open_sunday"]):
		var rng := Rng.from_state(int(n["rng_state"]) ^ 0x9e3779b9)
		if rng.next() < minf(0.6, 0.1 + float(n["ordnungsamt_heat"]) / 100.0):
			fine = 50.0 + floorf(float(n["ordnungsamt_heat"]) + 0.5)
			n["cash"] = float(n["cash"]) - fine
			_log(n, "ordnungsamt", "Ordnungsamt inspection — fined €%d for Sunday trading." % int(fine))
		n["ordnungsamt_heat"] = float(n["ordnungsamt_heat"]) + 10.0
		n["rng_state"] = rng.state()
	# The illegal "extra menu": fat margins by day, but the corner gets dirtier — a nightly Integrity
	# bleed and a real bust risk. The security cam buys down the odds. This is what pushes a greedy run
	# toward the 'soldout' ending.
	if _has_effect(n, "illegal"):
		n["reputation"]["integrity"] = Economy.clamp_meter(float(n["reputation"]["integrity"]) - 1.5)
		var has_security := _has_effect(n, "fewer_risk_events")
		var dark := Rng.from_state((int(n["rng_state"]) ^ 0x2545f491) & 0xFFFFFFFF)
		if dark.next() < (0.04 if has_security else 0.08):
			var raid := 120.0 + floorf(dark.next() * 80.0 + 0.5)
			n["cash"] = float(n["cash"]) - raid
			fine += raid
			n["reputation"]["kiez"] = Economy.clamp_meter(float(n["reputation"]["kiez"]) - 6.0)
			n["reputation"]["integrity"] = Economy.clamp_meter(float(n["reputation"]["integrity"]) - 8.0)
			_log(n, "raid", "Police raid — the \"extra menu\" cost you €%d and the block's trust." % int(raid))
	var kiez_gain := 0.0
	for id in n["upgrades"]:
		kiez_gain += float(Content.upgrade(id).get("effects", {}).get("kiez_per_night", 0.0))
	n["reputation"]["kiez"] = Economy.clamp_meter(float(n["reputation"]["kiez"]) + kiez_gain)
	var tally: Dictionary = n["tally"]
	var profit := Economy.round2(float(tally["revenue"]) + float(tally["tips"]) - float(tally["cogs"]) - bills_due - float(tally["pfand_paid"]) - fine)
	n["cash"] = Economy.round2(float(n["cash"]))
	(n["summaries"] as Array).append({
		"day": int(n["day"]),
		"revenue": Economy.round2(float(tally["revenue"])),
		"cogs": Economy.round2(float(tally["cogs"])),
		"tips": Economy.round2(float(tally["tips"])),
		"bills_due": Economy.round2(bills_due + fine),
		"pfand_paid": Economy.round2(float(tally["pfand_paid"])),
		"profit": profit,
		"cash_after": Economy.round2(float(n["cash"])),
		"sales": int(tally["sales"]),
		"lost": int(tally["lost"]),
		"kiez_delta": Economy.round2(kiez_gain),
	})
	# Whoever was mid-conversation goes home; an unanswered beat simply comes back another night.
	n["story"]["pending"] = {}
	n["story"]["pending_vignette"] = ""
	n["active"] = {}
	n["talk"] = {}
	# You are at the counter when the shutters come down, whatever you were doing at 05:59 — otherwise
	# tomorrow's night opens with your back to the room and nobody at the till.
	n["view_mode"] = "counter"
	n["phase"] = "summary"
	_log(n, "close", "Night %d closed — profit €%.2f, cash €%.2f." % [int(n["day"]), profit, float(n["cash"])])

static func _advance_day(n: Dictionary) -> void:
	for id in (n["inventory"] as Dictionary).keys():
		if Content.sku(id).get("perishable", false):
			n["inventory"][id]["stock"] = int(floorf(float(n["inventory"][id]["stock"]) * 0.5))
	n["day"] = int(n["day"]) + 1
	n["weekday"] = (int(n["weekday"]) + 1) % 7
	n["clock_ms"] = 0
	n["talk"] = {}
	n["story"]["pending_vignette"] = ""
	if int(n["day"]) > int(n["config"]["season_days"]) or float(n["cash"]) < -200.0:
		n["phase"] = "end"
	else:
		n["phase"] = "manage"

# ──────────────────────── the six stats & checks (docs/06 §1-§2) ────────────────────────

## D&D 5e: floor((score - 10) / 2). floorf, not integer division — GDScript truncates toward zero,
## which would turn a 9 (mod -1) into a 0.
static func modifier(score: int) -> int:
	return int(floorf(float(score - 10) / 2.0))

static func stat_score(s: Dictionary, stat: String) -> int:
	return int(((s.get("player", {}) as Dictionary).get("stats", {}) as Dictionary).get(stat, 10))

static func stat_mod(s: Dictionary, stat: String) -> int:
	return modifier(stat_score(s, stat))

## What a player reads for a stat id ("cha" -> "Schnauze"); unknown ids print themselves.
static func stat_name(stat: String) -> String:
	return String(STAT_NAMES.get(stat, stat))

## One d20 + modifier against a DC, rolled on the state's OWN Rng so a night replays exactly
## (docs/06 §2). Mutates `n` (the roll consumes rng state) and logs a `check` entry the box reads.
static func roll_check(n: Dictionary, check: Dictionary) -> Dictionary:
	var stat := String(check.get("stat", "cha"))
	var dc := int(check.get("dc", 10))
	var rng := Rng.from_state(int(n["rng_state"]))
	var roll := rng.randi_below(DIE_FACES) + 1
	n["rng_state"] = rng.state()
	var mod := stat_mod(n, stat)
	var success := roll + mod >= dc
	var result := {"stat": stat, "roll": roll, "mod": mod, "dc": dc, "success": success}
	var signed := ("+" + str(mod)) if mod >= 0 else str(mod)
	_log(n, "check", "%s check: %d%s = %d vs DC %d — %s" % [
		stat_name(stat), roll, signed, roll + mod, dc, ("success" if success else "fail")], result.duplicate())
	return result

# ────────────────────────── the conversation (docs/06 §3-§4) ──────────────────────────

## Open the guest's own graph (or the nameless parade's). False = there is nothing to say.
static func _open_talk(n: Dictionary) -> bool:
	var active: Dictionary = n["active"]
	if active.is_empty():
		return false
	var graph_id := Content.dialogue_id_for(String(active.get("character_id", "")))
	# A minor asking for a restricted SKU gets the ID check instead of the parade's "Here you go." —
	# the counter's blanket refusal used to swallow that answer into a silent Kiez tick (docs/06 §7).
	if graph_id == Content.DIALOGUE_FALLBACK and _is_illegal_want(active):
		graph_id = Content.DIALOGUE_MINOR
	var graph := Content.dialogue(graph_id)
	if graph.is_empty():
		return false
	var start := String(graph.get("start", ""))
	if Content.dialogue_node(graph_id, start).is_empty():
		return false
	n["talk"] = Talk.open(int(active["id"]), Talk.DIALOGUE_PREFIX + graph_id, start, Talk.KIND_TALK)
	return true

## A pending beat/vignette IS a conversation: it opens as a ONE-NODE talk so `view.dialogue` and
## `view.talk` are the same node (docs/06 §4). Ending it does NOT dismiss the guest — the ordinary
## serve still follows (docs/05 §4), which is the one behavioural difference from a graph talk.
static func _open_story_talk(n: Dictionary) -> void:
	if Talk.is_open(n):
		return
	var active: Dictionary = n["active"]
	if active.is_empty():
		return
	var story: Dictionary = n["story"]
	var pending: Dictionary = story["pending"]
	if not pending.is_empty():
		n["talk"] = Talk.open(int(active["id"]), Talk.BEAT_PREFIX + String(pending["strand"]),
			String(pending["beat"]), Talk.KIND_BEAT)
		return
	var vignette_id := String(story["pending_vignette"])
	if vignette_id != "":
		n["talk"] = Talk.open(int(active["id"]), Talk.VIGNETTE_PREFIX + vignette_id, vignette_id, Talk.KIND_VIGNETTE)

## Next line of the node. On the last line there is nothing left to advance to — the choices are up.
static func _talk_advance(n: Dictionary) -> bool:
	var node := Talk.node_of(n)
	if node.is_empty():
		return false
	var last := maxi(0, (node["lines"] as Array).size() - 1)
	var talk: Dictionary = n["talk"]
	if int(talk["line"]) >= last:
		return false
	talk["line"] = int(talk["line"]) + 1
	return true

## Resolve a choice: gate → roll → effects → next node, or the end of the conversation.
static func _talk_choose(n: Dictionary, index: int) -> bool:
	var node := Talk.node_of(n)
	if node.is_empty():
		return false
	var choices: Array = node["choices"]
	if choices.is_empty():
		return false
	var i := clampi(index, 0, choices.size() - 1)
	var choice: Dictionary = choices[i]
	var requires: Dictionary = choice.get("requires", {})
	if not requires.is_empty() and stat_score(n, String(requires.get("stat", "str"))) < int(requires.get("min", 0)):
		return false  # a locked gate is an illegal action, not a failed roll
	_log(n, "beat", "%s — %s" % [String(node["speaker"]), String(choice.get("label", ""))],
		{"kind": String(node["kind"]), "choice": i})
	var kind := String(node["kind"])
	if kind == Talk.KIND_BEAT:
		StoryFlow.apply_beat_choice(n, i)
		_end_talk(n, false, true)
		return true
	if kind == Talk.KIND_VIGNETTE:
		StoryFlow.apply_vignette_choice(n, i)
		_end_talk(n, false, true)
		return true
	var next_id := String(choice.get("next", ""))
	var result: Dictionary = {}
	if not (choice.get("check", {}) as Dictionary).is_empty():
		result = roll_check(n, choice["check"])
		if bool(result["success"]):
			StoryFlow.apply_effect_map(n, choice.get("effects_success", {}))
		else:
			next_id = String(choice.get("next_fail", next_id))
			StoryFlow.apply_effect_map(n, choice.get("effects_fail", {}))
	StoryFlow.apply_effect_map(n, choice.get("effects", {}))
	var talk: Dictionary = n["talk"]
	talk["last_check"] = result
	var graph_id := String(talk["dialogue_id"]).trim_prefix(Talk.DIALOGUE_PREFIX)
	var next_node := Content.dialogue_node(graph_id, next_id) if next_id != "" else {}
	if next_node.is_empty():
		_end_talk(n, true, bool(choice.get("serve", true)), bool(choice.get("sell_restricted", false)))
		return true
	talk["node"] = next_id
	talk["line"] = 0
	(talk["history"] as Array).append(next_id)
	# The face follows the node you just walked into (docs/06 §3) — the Portrait reads it from `active`.
	var active: Dictionary = n["active"]
	active["expression"] = String(next_node.get("expression", active.get("expression", "neutral")))
	return true

## `talk_end` (docs/06 §4, engine-internal). `dismiss` = the guest leaves; `serve_them` = their want
## is rung up on the way out if it is in stock, so a night of pure conversation still moves cash.
## The counter refuses an underage restricted sale on its own UNLESS the line taken was the one that
## knowingly sells it (`sell_restricted`) — that answer routes through the ordinary `_serve`, so it
## costs exactly what `serve_active` costs: -8 Integrity and the `ethics` log entry.
static func _end_talk(n: Dictionary, dismiss: bool, serve_them: bool, allow_restricted: bool = false) -> void:
	n["talk"] = {}
	if not dismiss:
		return
	var active: Dictionary = n["active"]
	if active.is_empty():
		return
	# THE REGISTER IS THE SERVE NOW (docs/08 §1). Her talk graph ends, the box slides away and she is
	# STILL STANDING THERE with her basket on the counter — the player scans it and rings it up. The
	# docs/06 §7 auto-serve was written when a guest had one `want` and ending the sentence was the
	# only way to take their money; leaving it in place meant every authored tree rang itself up and
	# dismissed the guest, so the whole register was unreachable for all eleven of them (probed on the
	# REAL read-model, 2026-09-13: after Aylin's tree closed, `legal_actions` offered only close_night).
	# A guest with NO basket keeps the old path — that is the parade served by `serve_active`, the
	# AutoPlayer's serve-loop sims and `config.auto_take_next`, none of which ever place a basket.
	if serve_them and not (active.get("basket", []) as Array).is_empty():
		# The restricted decision is not skipped, only MOVED: `ring_up` charges the same -8 Integrity
		# once per line, and `check_id` is now the way to refuse (docs/08 §3.4) instead of the
		# counter's blanket refusal below. `allow_restricted` therefore has nothing left to say here.
		return
	var want := String(active["want"])
	var stock := int(((n["inventory"] as Dictionary).get(want, {}) as Dictionary).get("stock", 0))
	var illegal := _is_illegal_want(active)
	if serve_them and stock > 0 and (allow_restricted or not illegal):
		_serve(n, [want], 0)  # the ONE Integrity path — `_serve` logs the `ethics` entry
		return
	if serve_them and illegal:
		# The house rule, not a snub: it costs no Kiez-Trust, but it goes on the record so the player
		# can see that the counter — not their answer — is what turned the kid away.
		_log(n, "ethics", "Refused %s to a minor — no ID, no sale." % String(Content.sku(want).get("name", want)))
		_next_customer(n)
		return
	n["reputation"]["kiez"] = Economy.clamp_meter(float(n["reputation"]["kiez"]) - 0.1)
	_next_customer(n)

## A minor asking for a restricted SKU. Used both to pick the conversation and to gate the auto-serve.
static func _is_illegal_want(active: Dictionary) -> bool:
	return bool(Content.archetype(String(active.get("archetype_id", ""))).get("underage", false)) 		and bool(Content.sku(String(active.get("want", ""))).get("restricted", false))

static func _has_effect(n: Dictionary, key: String) -> bool:
	for id in n["upgrades"]:
		if Content.upgrade(id).get("effects", {}).get(key, false):
			return true
	return false

## "Somebody is mid-sentence" — the serve, the wave-off and the patience clock all stand down for it.
static func _dialogue_pending(s: Dictionary) -> bool:
	if Talk.is_open(s) or not (s["story"]["pending"] as Dictionary).is_empty():
		return true
	return s["story"]["pending_vignette"] != ""

static func _log(n: Dictionary, kind: String, text: String, data: Dictionary = {}) -> void:
	# ts orders entries across the season: day-major, clock-minor.
	(n["log"] as Array).append({
		"ts": int(n["day"]) * 1000000 + int(n["clock_ms"]),
		"kind": kind,
		"text": text,
		"data": data,
	})

static func _log_choice(n: Dictionary, kind: String, index: int) -> void:
	var dialogue := StoryFlow.current_dialogue(n)
	if dialogue.is_empty():
		return
	var choices: Array = dialogue["choices"]
	var label: String = choices[index]["label"] if index >= 0 and index < choices.size() else choices[0]["label"]
	_log(n, "beat", "%s — %s" % [dialogue["speaker"], label], {"kind": kind, "choice": index})

# ───────────────────────────────── legality ─────────────────────────────────

## The action dictionaries the UI may offer right now. `set_price`/`restock` carry a representative
## argument (current price, one unit) — the screen supplies its own quantity from the same shape.
static func legal_actions(s: Dictionary) -> Array:
	var out: Array = []
	match s["phase"]:
		"manage":
			out.append({"type": "open_night"})
			out.append({"type": "set_sunday_open", "open": not bool(s["open_sunday"])})
			for sku_id in (s["inventory"] as Dictionary).keys():
				out.append({"type": "set_price", "sku": sku_id, "price": float(s["inventory"][sku_id]["price"])})
				if can_restock(s, sku_id, 1):
					out.append({"type": "restock", "sku": sku_id, "qty": 1})
			for option in Economy.module_options(s):
				if option["available"] and option["affordable"]:
					out.append({"type": "buy_upgrade", "id": option["def"]["id"]})
		"night":
			out.append({"type": "tick", "dt_ms": 100})
			var story: Dictionary = s["story"]
			if Talk.is_open(s):
				# Mid-sentence, the only intents are "next line" and "say this" (docs/06 §4).
				var node := Talk.node_of(s)
				var lines: Array = node.get("lines", [])
				if int((s["talk"] as Dictionary).get("line", 0)) < maxi(0, lines.size() - 1):
					out.append({"type": "talk_advance"})
				var views := Talk.choice_views(s, node)
				for i in views.size():
					if not bool(views[i]["locked"]):  # a gate is shown by the box, never offered here
						out.append({"type": "talk_choose", "choice": i})
				# Legacy aliases: the shipped DialogueBox dispatches these for a beat/vignette.
				var kind := Talk.kind_of(s)
				if kind == Talk.KIND_BEAT or kind == Talk.KIND_VIGNETTE:
					var legacy := "resolve_vignette" if kind == Talk.KIND_VIGNETTE else "resolve_beat"
					for i in views.size():
						if not bool(views[i]["locked"]):  # same gate rule as talk_choose (docs/05 §8)
							out.append({"type": legacy, "choice": i})
			elif not (story["pending"] as Dictionary).is_empty():
				var beat := Content.beat(story["pending"]["strand"], story["pending"]["beat"])
				for i in (beat.get("choices", []) as Array).size():
					out.append({"type": "resolve_beat", "choice": i})
			elif story["pending_vignette"] != "":
				var v := Content.vignette(story["pending_vignette"])
				for i in (v.get("choices", []) as Array).size():
					out.append({"type": "resolve_vignette", "choice": i})
			elif String(s.get("view_mode", "counter")) == "wall":
				# Turned around, the only verbs are the wall's — and `turn_around{on:false}` is always
				# among them, so the wall can never become a room without a door (docs/08 §3.2).
				out.append({"type": "turn_around", "on": false})
				_wall_actions(s, out)
			else:
				# Take the next guest: the head of the queue (the tick promotes nobody unless
				# config.auto_take_next), or open the conversation with whoever is already at the counter.
				if not (s["active"] as Dictionary).is_empty() or not (s["queue"] as Array).is_empty():
					out.append({"type": "talk_next"})
				if not (s["active"] as Dictionary).is_empty():
					# `serve_active` is NOT offered any more (docs/08 §3.6 demotes ServePanel/Shelf/Till
					# to a `play.mjs --serve` debug affordance). It stays LEGAL as the alias the
					# AutoPlayer's serve-loop sims and docs/06 §7 dispatch by hand, but offering it here
					# would put an action on the board with no visible control to press — which is
					# exactly the soft-lock class `test_the_register_puts_every_action_on_a_control_you
					# _can_hit` exists to catch.
					out.append({"type": "skip_active"})
					_register_actions(s, out)
			out.append({"type": "close_night"})
		"summary":
			out.append({"type": "advance_day"})
	return out

## Everything the till offers with a guest at the counter (docs/08 §3.2): one `scan` per unscanned
## uid, `register_*` per REAL line index — never one out of range — and the ring only when there is
## something to ring.
static func _register_actions(s: Dictionary, out: Array) -> void:
	if not _register_open(s):
		return
	var active: Dictionary = s["active"]
	var register: Dictionary = active["register"]
	for entry in (active["counter"] as Array):
		var item: Dictionary = entry
		if String(item["kind"]) == "crate" or bool(item["scanned"]):
			continue
		out.append({"type": "scan", "uid": int(item["uid"])})
	var lines: Array = register["lines"]
	for i in lines.size():
		var line: Dictionary = lines[i]
		out.append({"type": "register_remove", "line": i})
		# BOTH steps the row offers, not a representative one. The register line has a "−" and a "+"
		# and `RegisterPanel.control_for` already routes each to its own chip, so advertising only one
		# of them left a visible, pressable control whose action the engine never admitted was legal —
		# the mirror image of a soft-lock, and what `play.mjs` hit trying to put a quantity back
		# (2026-09-13). Every entry still MOVES the state when taken, which is the actual rule here.
		var stock := int(((s["inventory"] as Dictionary).get(String(line["sku"]), {}) as Dictionary).get("stock", 0))
		var cap := clampi(stock, 1, REGISTER_QTY_MAX)
		var qty := int(line["qty"])
		for stepped in [qty + 1, qty - 1]:
			if stepped >= 1 and stepped <= cap:
				out.append({"type": "register_set_qty", "line": i, "qty": stepped})
	# THE STEPS THE ROW ACTUALLY TAKES, both of them — the same rule as the register line above. The
	# Pfand row is a `-` and a `+` and each one moves the count by ONE; offering "all of them at once"
	# instead described a control the screen does not have. `controls_for` routed that entry to the
	# `+` chip, pressing it staged ONE bottle, and the ring then came back `wrong_count` on a register
	# the driver had every reason to believe was exact (found by the pointer probe, 2026-09-13 —
	# `set_pfand{6}` was on offer and the control for it dispatched `set_pfand{1}`). Meanwhile `-` was
	# a live, enabled chip whose action the engine never admitted was legal: the mirror image again.
	# `set_pfand{all}` stays LEGAL — it is what the crate's drag dispatches (docs/08 §3.5) and what
	# `AutoPlayer` and the sims send — it is simply not advertised, exactly like `serve_active`.
	var bottles := int(active.get("bottles", 0))
	if bottles > 0:
		var staged := int(register["pfand_bottles"])
		for stepped in [staged + 1, staged - 1]:
			if stepped >= 0 and stepped <= bottles:
				out.append({"type": "set_pfand", "bottles": stepped})
	if not bool(register["id_checked"]):
		out.append({"type": "check_id"})
	out.append({"type": "turn_around", "on": true})
	if not lines.is_empty() or int(register["pfand_bottles"]) > 0:
		out.append({"type": "ring_up"})

## THE WALL IS THREE SHELVES (docs/08 §4.3), not one per SKU: cigarettes, rolling tobacco, and a
## bottom rail carrying the papers AND the filters together — ten facings at pitch 42.
##
## The row index is LAYOUT, and the layout is authored: `Palette.wall_cell_rect` knows exactly three
## rows and folds anything past the second onto the third. Emitting a fourth shelf therefore drew the
## four filter boxes directly on top of the first four paper booklets — both visible, both clickable,
## the later one swallowing the clicks meant for the other. Nothing failed; the wall simply lied.
## (Caught 2026-09-13 by test_scenes.gd::test_every_legal_action_at_a_real_register_has_a_control,
## which is the first test to ask the REAL read-model rather than `MockView` — the mock had always
## built the bottom shelf by hand and so had never disagreed with the grid.)
##
## A tobacco SKU with facings that is not named here still gets a shelf of its own, appended after
## these — and the Palette grid must grow a row in the same commit, or it lands on the bottom one.
static func _wall_rows() -> Array:
	var named := ["cigarettes", "tobacco", "papers", "filters"]
	var rows: Array = [["cigarettes"], ["tobacco"], ["papers", "filters"]]
	for def in Content.SKUS:
		var sku_id := String(def["id"])
		if not named.has(sku_id) and not Content.brands_for(sku_id).is_empty():
			rows.append([sku_id])
	return rows

## The wall's own verbs: one `take_from_wall` per in-stock facing, and a way back for anything you
## picked up by mistake.
static func _wall_actions(s: Dictionary, out: Array) -> void:
	if not _register_open(s):
		return
	var active: Dictionary = s["active"]
	var hand: Array = active["hand"]
	if hand.size() < HAND_MAX:
		for def in Content.SKUS:
			var sku_id := String(def["id"])
			var inv: Dictionary = (s["inventory"] as Dictionary).get(sku_id, {})
			if inv.is_empty() or int(inv["stock"]) <= 0:
				continue
			for facing in Content.brands_for(sku_id):
				out.append({"type": "take_from_wall", "sku": sku_id, "brand": String((facing as Dictionary)["id"])})
	for held in hand:
		out.append({"type": "put_back", "uid": int((held as Dictionary)["uid"])})
	# A facing that already LANDED on the tray stays legal to reshelve (docs/08 §3.2: `origin=="wall"`
	# and `not scanned`), and `_put_back` still honours it — but it is not OFFERED here, for the same
	# reason `serve_active` is not offered at the counter: the wall's only put-back control is the
	# hand strip, and the tray is not on screen while your back is turned, so advertising it put an
	# action on the board with no control to press. Caught 2026-09-13 by the pointer probe, one turn
	# after a pack came home — a state `test_every_legal_action_at_a_real_register_has_a_control`
	# never reached, because it turns around exactly once, from a counter nothing has come back to.
	# What you are carrying goes back; what you already put down is on the counter, like her own.

# ───────────────────────────────── the read-model ─────────────────────────────────

static func view(s: Dictionary) -> Dictionary:
	var night_len := maxi(1, int(s["config"]["night_len_ms"]))
	var progress := clampf(float(s["clock_ms"]) / float(night_len), 0.0, 1.0)
	var rep: Dictionary = s["reputation"]
	return {
		"phase": s["phase"],
		"day": int(s["day"]),
		"weekday_name": WEEKDAY_NAMES[int(s["weekday"]) % 7],
		"clock_ms": int(s["clock_ms"]),
		"night_progress": progress,
		"time_label": time_label(progress),
		"cash": Economy.round2(float(s["cash"])),
		"pfand_held": int(s["pfand_held"]),
		# The deposit the reducer actually pays per returned bottle — the till prints this, never its own rate.
		"pfand_rate": PFAND_PER_BOTTLE,
		"reputation": rep.duplicate(),
		"hud": {
			"kiez_label": "Kiez-Trust %d" % int(floorf(float(rep["kiez"]) + 0.5)),
			"profit_label": "Profit %d" % int(floorf(float(rep["profit"]) + 0.5)),
		},
		"active": _active_view(s),
		# The register (docs/08 §3.3). `matches` and `satisfied` are derived HERE, never in the UI:
		# the ticks and the amber edges are the reducer's opinion, so a screen cannot lie about
		# correctness the way a screen that pressed buttons by name once lied about reachability.
		"counter": _counter_view(s),
		"register": _register_view(s),
		"order": _order_view(s),
		"view_mode": String(s.get("view_mode", "counter")),
		"wall": _wall_view(s),
		"queue_len": (s["queue"] as Array).size(),
		"queue": _queue_view(s),
		"talk": Talk.view(s),
		"player": _player_view(s),
		# ONE source for the box: while anyone is talking this is a projection of `talk` (docs/06 §4);
		# the StoryFlow path survives only as the fallback for a pending beat that never opened.
		"dialogue": _dialogue_view(s),
		"shelf": _shelf_view(s),
		"summary": ((s["summaries"] as Array).back() if not (s["summaries"] as Array).is_empty() else {}),
		# `status` is the standing roll-up: what the corner has become (modules, and the conversation
		# branches that left a mark). Without it in the read-model the flags a graph writes are unread.
		# `open_sunday` rides along because the board's toggle has to read the state it flips — a
		# component may not reach into `s`, and `legal_actions` offers `set_sunday_open` every manage
		# hour (the Sunday spike and the Ordnungsamt roll were unreachable content without it).
		"manage": {"restock_options": _restock_options(s), "modules": Economy.module_options(s),
			"status": Economy.corner_status(s), "open_sunday": bool(s["open_sunday"])},
		"ending": (Finale.resolve_finale(s) if s["phase"] == "end" else {}),
	}

## 20:00 → 06:00 across the night, whatever night_len_ms is.
static func time_label(progress: float) -> String:
	var minutes := NIGHT_START_MIN + int(floorf(progress * float(NIGHT_MINUTES)))
	return "%02d:%02d" % [int(minutes / 60.0) % 24, minutes % 60]

static func _active_view(s: Dictionary) -> Dictionary:
	var active: Dictionary = s["active"]
	if active.is_empty():
		return {}
	var arch := Content.archetype(active["archetype_id"])
	var want_id: String = active["want"]
	var def := Content.sku(want_id)
	var inv: Dictionary = (s["inventory"] as Dictionary).get(want_id, {})
	var patience_ms := maxf(1.0, float(arch.get("patience_ms", 1)))
	return {
		# Deep, because the customer now carries the basket, the counter and the register: a shallow
		# copy would hand a component the reducer's own arrays to write into.
		"customer": active.duplicate(true),
		"archetype": {"id": arch.get("id", ""), "name": arch.get("name", "")},
		"want": {
			"sku_id": want_id,
			"name": def.get("name", want_id),
			"price": float(inv.get("price", 0.0)),
			"stock": int(inv.get("stock", 0)),
			"icon": def.get("icon", "sku/" + want_id),
			"restricted": bool(def.get("restricted", false)),
		},
		"portrait": Content.portrait_for(active.get("character_id", ""), active["archetype_id"]),
		"expression": active.get("expression", "neutral"),
		"patience": clampf(float(active["patience_left_ms"]) / patience_ms, 0.0, 1.0),
		"is_story": active.get("beat_id", "") != "" or active.get("vignette_id", "") != "",
		"underage": bool(arch.get("underage", false)),
		"bottles": int(active.get("bottles", 0)),
	}

## `view.counter` (docs/08 §3.3): what is physically on the laminate, in tray order. The crate is one
## sprite with a ×N badge; everything else is one sprite per unit.
static func _counter_view(s: Dictionary) -> Array:
	var active: Dictionary = s["active"]
	if active.is_empty():
		return []
	var out: Array = []
	for entry in (active.get("counter", []) as Array):
		var item: Dictionary = entry
		var sku_id := String(item["sku"])
		var def := Content.sku(sku_id)
		var facing := Content.brand(String(item["brand"]))
		var is_crate := String(item["kind"]) == "crate"
		out.append({
			"uid": int(item["uid"]),
			"sku_id": sku_id,
			# The crate is not a SKU, so it has no spoken name: the tray labels it from `Strings`.
			"name": "" if is_crate else String(def.get("name", sku_id)),
			"brand": String(item["brand"]),
			"mark": String(facing.get("mark", "")),
			"colour": String(facing.get("colour", "")),
			"icon": "prop/pfand_crate" if is_crate else String(facing.get("icon", def.get("icon", "sku/" + sku_id))),
			"kind": String(item["kind"]),
			"count": int(item["count"]),
			"scanned": bool(item["scanned"]),
			"origin": String(item.get("origin", "customer")),
			"slot": out.size(),
		})
	return out

## `view.register` (docs/08 §3.3): the claim, priced. `total` includes −pfand_line and may go negative.
static func _register_view(s: Dictionary) -> Dictionary:
	var active: Dictionary = s["active"]
	if active.is_empty():
		# EMPTY, like `view.wall` off the wall and `view.active` with nobody there — not a zeroed row
		# of keys. "{} is the pre-basket state" is the contract docs/08 §4.1 gives `RegisterPanel` and
		# the one `MockView` writes, and `night.gd::_note_mode` derives the whole chrome mode from it
		# (`_ringing = not register.is_empty()`). A zeroed dictionary is not empty, so the real game
		# was in register mode ALL NIGHT: the queue never drew its line, the tray, the glass and the
		# till column stood over an empty counter, and the want bubble, the order line and the d20
		# plate — all of which stand down during a ring-up — were never seen again. Nothing caught it
		# because every capture reads `MockView`, where the key really was `{}`.
		return {}
	var register: Dictionary = active["register"]
	var want := _want_units(active.get("basket", []))
	var flagged: Array = register["flagged"]
	var lines: Array = []
	var subtotal := 0.0
	for entry in (register["lines"] as Array):
		var line: Dictionary = entry
		var sku_id := String(line["sku"])
		var def := Content.sku(sku_id)
		var facing := Content.brand(String(line["brand"]))
		var qty := int(line["qty"])
		var unit_price := float(((s["inventory"] as Dictionary).get(sku_id, {}) as Dictionary).get("price", 0.0))
		var line_total := Economy.round2(unit_price * float(qty))
		subtotal += line_total
		var index := lines.size()
		lines.append({
			"sku_id": sku_id,
			"name": String(def.get("name", sku_id)),
			"brand": String(line["brand"]),
			"mark": String(facing.get("mark", "")),
			"colour": String(facing.get("colour", "")),
			"icon": String(facing.get("icon", def.get("icon", "sku/" + sku_id))),
			"qty": qty,
			"unit_price": unit_price,
			"line_total": line_total,
			"restricted": bool(def.get("restricted", false)),
			# She asked for that mark — or for no mark at all, which any facing answers — and not
			# fewer of them than this.
			"matches": _line_matches(want, sku_id, String(line["brand"]), qty),
			"flagged": flagged.has(index),
		})
	var pfand_line := Economy.round2(float(register["pfand_bottles"]) * PFAND_PER_BOTTLE)
	return {
		"lines": lines,
		"pfand_bottles": int(register["pfand_bottles"]),
		"pfand_line": pfand_line,
		"subtotal": Economy.round2(subtotal),
		"total": Economy.round2(subtotal - pfand_line),
		"can_ring": String(s.get("view_mode", "counter")) == "counter" and not _dialogue_pending(s)
			and (not lines.is_empty() or int(register["pfand_bottles"]) > 0),
		"id_checked": bool(register["id_checked"]),
		"corrections": int(register["corrections"]),
		"flagged": flagged.duplicate(),
		"correction": String(register["correction"]),
		# The BUCKET the reducer flagged, so the box can take the words from `Strings` instead of
		# printing the reducer's English (docs/08 §3.4). "" when there is nothing to correct.
		"correction_kind": String(register.get("correction_kind", "")),
	}

## `view.order` (docs/08 §3.3): her words as chips. In `mark` mode the chip prints the swatch and the
## category and NEVER the brand name — so `brand_name` is "" unless the speech mode earns it. That is
## the difference between reading a list and running a shop.
static func _order_view(s: Dictionary) -> Array:
	var active: Dictionary = s["active"]
	if active.is_empty():
		return []
	var register: Dictionary = active["register"]
	var got: Dictionary = {}
	var got_by_sku: Dictionary = {}
	for entry in (register["lines"] as Array):
		var line: Dictionary = entry
		var key := String(line["sku"]) + "|" + String(line["brand"])
		got[key] = int(got.get(key, 0)) + int(line["qty"])
		got_by_sku[String(line["sku"])] = int(got_by_sku.get(String(line["sku"]), 0)) + int(line["qty"])
	if int(register["pfand_bottles"]) > 0:
		got[PFAND_SKU + "|"] = int(register["pfand_bottles"])
		got_by_sku[PFAND_SKU] = int(register["pfand_bottles"])
	var name_shown := _speech_mode(s) == "name" or _speech_mode(s) == "both"
	var out: Array = []
	for entry in (active.get("basket", []) as Array):
		var row: Dictionary = entry
		var sku_id := String(row["sku"])
		var def := Content.sku(sku_id)
		var facing := Content.brand(String(row["brand"]))
		var is_pfand := sku_id == PFAND_SKU
		var key := sku_id + "|" + String(row["brand"])
		out.append({
			"sku_id": sku_id,
			# Content may author her exact words; otherwise the ENGINE composes them once, here, from
			# the ASK_* templates, so the OrderCard never has to invent a sentence (docs/08 §2).
			"said": String(row.get("said", "")) if String(row.get("said", "")) != ""
				else _said_for(row, def, facing, name_shown),
			"qty": int(row["qty"]),
			"name": "" if is_pfand else String(def.get("name", sku_id)),
			"category": "pfand" if is_pfand else String(def.get("category", "")),
			"brand": String(row["brand"]),
			"brand_name": String(facing.get("name", "")) if name_shown else "",
			"mark": String(facing.get("mark", "")),
			"colour": String(facing.get("colour", "")),
			"icon": "prop/pfand_crate" if is_pfand else String(facing.get("icon", def.get("icon", "sku/" + sku_id))),
			"name_shown": name_shown,
			# A named mark has to be the mark; an unnamed one counts every facing of that SKU.
			"satisfied": int(row["qty"]) == (int(got_by_sku.get(sku_id, 0)) if String(row["brand"]) == ""
				else int(got.get(key, 0))),
		})
	return out

## Her words for one basket line (docs/08 §2, "How a customer phrases it"). Three tiers decide only
## HOW THE BRAND IS NAMED — the quantity and the category are always spoken:
##   "name"  (regulars)  "2× Adler — cigarettes."
##   "mark"  (strangers) "2× the ones with the eagle — cigarettes."   ← the default, and the game
##   unbranded           "2× Mate."
## The `colour` tier of docs/08 §2 is NOT implemented: a colour word would have to be invented in the
## reducer from a hex, and docs/08 §7 lists that tier as a planned cut. It degrades to `mark`.
static func _said_for(row: Dictionary, def: Dictionary, facing: Dictionary, name_shown: bool) -> String:
	var qty := int(row["qty"])
	if String(row["sku"]) == PFAND_SKU:
		return ASK_PFAND % qty
	var noun := String(def.get("name", row["sku"]))
	if not facing.is_empty():
		var phrase := String(facing.get("phrase", ""))
		var family := String(facing.get("family", ""))
		if family == "cigarettes" or family == "tobacco":
			# A pack and a pouch wear an EMBLEM, so a stranger points at the emblem. A named brand is
			# said by name; printing "Adler" in `mark` mode would give the whole wall away (docs/08 §2).
			noun = String(facing["name"]) if name_shown else ASK_MARK_PHRASE % phrase
			return (ASK_CIGS if family == "cigarettes" else ASK_POUCH) % [qty, noun]
		# Papers and filters have no emblem — the VARIANT is the identity (docs/09 §1 rule 1), so a
		# stranger points at the object itself ("the cream booklet"), never at a mark on it: "the ones
		# with the slim ones" is what happens when a booklet is asked for like a cigarette pack.
		# `spoken` already carries the length and the gauge, so nothing re-derives them (rule 2).
		noun = String(facing["spoken"]) if name_shown else ASK_POINT % phrase
	return ASK_ITEM % [qty, noun]

## One rule for "is this line what she asked for", used by the register view and nothing else may
## have its own (docs/08 §3.3).
static func _line_matches(want: Dictionary, sku_id: String, brand: String, qty: int) -> bool:
	if want.has(sku_id + "|" + brand) and qty <= int(want[sku_id + "|" + brand]):
		return true
	return brand != "" and want.has(sku_id + "|") and qty <= int(want[sku_id + "|"])

## How this guest asks for a brand (docs/08 §2): `config.brand_hint` is the global override — "both"
## on night 1 as a tutorial, "name" as a mercy setting — and "" lets the archetype decide.
static func _speech_mode(s: Dictionary) -> String:
	var hint := String((s["config"] as Dictionary).get("brand_hint", ""))
	if hint != "":
		return hint
	return String(Content.archetype(String((s["active"] as Dictionary).get("archetype_id", ""))).get("speech", "mark"))

## `view.wall` (docs/08 §3.3) — {} unless your back is actually turned. One shelf per tobacco SKU, in
## registry order, each carrying the parent SKU's one price: per-brand stock and per-brand prices are
## explicitly out of the slice (docs/08 §7), so every facing on a rail reads the same number.
static func _wall_view(s: Dictionary) -> Dictionary:
	if String(s.get("view_mode", "counter")) != "wall":
		return {}
	var shelves: Array = []
	for group in _wall_rows():
		var cells: Array = []
		var lead: String = ""
		for id in (group as Array):
			var sku_id := String(id)
			var facings := Content.brands_for(sku_id)
			var inv: Dictionary = (s["inventory"] as Dictionary).get(sku_id, {})
			if facings.is_empty() or inv.is_empty():
				continue
			if lead == "":
				lead = sku_id
			for entry in facings:
				var facing: Dictionary = entry
				cells.append({
					"sku_id": sku_id,
					"brand": String(facing["id"]),
					"name": String(facing["name"]),
					"mark": String(facing["mark"]),
					"colour": String(facing["colour"]),
					"icon": String(facing["icon"]),
					"stock": int(inv["stock"]),
					"row": shelves.size(),
					# The column runs ACROSS the whole rail, so ten facings from two SKUs sit in ten
					# places and not in two overlapping runs of six and four.
					"col": cells.size(),
				})
		if cells.is_empty():
			continue
		var lead_inv: Dictionary = (s["inventory"] as Dictionary)[lead]
		for cell in cells:
			(cell as Dictionary)["row"] = shelves.size()
		shelves.append({
			"sku_id": lead,
			"label": String(Content.sku(lead)["name"]),
			# One price per rail (docs/08 §4.3). A shared rail quotes the SKU that leads it — the
			# papers, on the bottom shelf — which is what the reference photo does too.
			"price": float(lead_inv["price"]),
			"stock": int(lead_inv["stock"]),
			"row": shelves.size(),
			"cells": cells,
		})
	var hand: Array = []
	for entry in ((s["active"] as Dictionary).get("hand", []) as Array):
		var held: Dictionary = entry
		var facing := Content.brand(String(held["brand"]))
		var def := Content.sku(String(held["sku"]))
		hand.append({
			"uid": int(held["uid"]),
			"sku_id": String(held["sku"]),
			"brand": String(held["brand"]),
			"name": String(facing.get("name", def.get("name", held["sku"]))),
			"mark": String(facing.get("mark", "")),
			"colour": String(facing.get("colour", "")),
			"icon": String(facing.get("icon", def.get("icon", "sku/" + String(held["sku"])))),
		})
	return {"shelves": shelves, "hand": hand, "hand_max": HAND_MAX}

## Everyone waiting, FIFO, each with the portrait the art lane drew for them: their own if they are
## cast, otherwise their archetype's one-off bust (docs/05 §6).
static func _queue_view(s: Dictionary) -> Array:
	var out: Array = []
	for customer in (s["queue"] as Array):
		var c: Dictionary = customer
		out.append({
			"customer_id": int(c["id"]),
			"character_id": String(c.get("character_id", "")),
			"name": Talk.guest_name(c),
			"portrait": Content.portrait_for(String(c.get("character_id", "")), String(c.get("archetype_id", ""))),
			"expression": String(c.get("expression", "neutral")),
			"is_story": String(c.get("beat_id", "")) != "" or String(c.get("vignette_id", "")) != "",
		})
	return out

## The six-stat strip: the scores and the modifiers the checks actually add (docs/06 §1).
static func _player_view(s: Dictionary) -> Dictionary:
	var stats: Dictionary = {}
	var mods: Dictionary = {}
	for stat in STAT_IDS:
		var score := stat_score(s, stat)
		stats[stat] = score
		mods[stat] = modifier(score)
	return {"stats": stats, "mods": mods}

static func _dialogue_view(s: Dictionary) -> Dictionary:
	var projected := Talk.dialogue_view(s)
	return projected if not projected.is_empty() else StoryFlow.current_dialogue(s)

static func _shelf_view(s: Dictionary) -> Array:
	var out: Array = []
	for def in Content.SKUS:  # registry order, so the shelf never reshuffles under the player
		var inv: Dictionary = (s["inventory"] as Dictionary).get(def["id"], {})
		if inv.is_empty():
			continue
		out.append({
			"sku_id": def["id"],
			"name": def["name"],
			"price": float(inv["price"]),
			"stock": int(inv["stock"]),
			"icon": def.get("icon", "sku/" + def["id"]),
			"restricted": bool(def.get("restricted", false)),
			"tier": Economy.price_tier(def, float(inv["price"])),
		})
	return out

static func _restock_options(s: Dictionary) -> Array:
	var out: Array = []
	for def in Content.SKUS:
		var inv: Dictionary = (s["inventory"] as Dictionary).get(def["id"], {})
		if inv.is_empty():
			continue
		out.append({
			"sku_id": def["id"],
			"name": def["name"],
			"cost": float(def["cost"]),
			"stock": int(inv["stock"]),
			"price": float(inv["price"]),
			"fair_lo": float(def["fair_lo"]),
			"fair_hi": float(def["fair_hi"]),
			# The board colours the price from this — the bands live here, never in a component.
			"tier": Economy.price_tier(def, float(inv["price"])),
			# …and greys the "+" from this: a board that re-derived `cost <= cash` would both offer
			# restocks the reducer refuses and hide the ones the Pfand crate pays for.
			"affordable": can_restock(s, String(def["id"]), 1),
		})
	return out
