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
		active["patience_left_ms"] = int(active["patience_left_ms"]) - dt_ms
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
	StoryFlow.on_customer_active(n)
	_open_story_talk(n)  # a beat/vignette IS a conversation now (docs/06 §4) — one box, one source

## Clear the counter. With `auto_take_next` the next person steps up by themselves; otherwise the line waits
## for `talk_next` (the slice's "one guest at a time").
static func _next_customer(n: Dictionary) -> void:
	n["active"] = {}
	if _auto_take_next(n) and not (n["queue"] as Array).is_empty():
		_take_next(n)

static func _serve(n: Dictionary, give: Array, pfand_bottles: int) -> void:
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
		if def.get("restricted", false) and arch.get("underage", false):
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
	var sat := 0.2 if over_budget else Economy.satisfaction(got_wanted, worst_tier, promptness)
	var tip := Economy.tip_for(arch, total, sat)
	n["cash"] = float(n["cash"]) + tip
	n["tally"]["tips"] = float(n["tally"]["tips"]) + tip
	var miss_penalty := 0.0 if got_wanted else 0.3 * float(arch["kiez_sensitivity"])
	n["reputation"]["kiez"] = Economy.clamp_meter(float(n["reputation"]["kiez"]) + Economy.kiez_delta(arch, worst_tier, false) - miss_penalty)
	n["reputation"]["profit"] = Economy.clamp_meter(float(n["reputation"]["profit"]) + (0.2 if total > 0.0 else 0.0))
	n["tally"]["sales"] = int(n["tally"]["sales"]) + 1
	n["cash"] = Economy.round2(float(n["cash"]))
	_log(n, "serve", "%s served — €%.2f." % [arch["name"], total])
	if tip > 0.0:
		_log(n, "tip", "Tip: €%.2f." % tip)
	_next_customer(n)

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
			else:
				# Take the next guest: the head of the queue (the tick promotes nobody unless
				# config.auto_take_next), or open the conversation with whoever is already at the counter.
				if not (s["active"] as Dictionary).is_empty() or not (s["queue"] as Array).is_empty():
					out.append({"type": "talk_next"})
				if not (s["active"] as Dictionary).is_empty():
					out.append({"type": "serve_active", "give": [s["active"]["want"]], "pfand_bottles": 0})
					out.append({"type": "skip_active"})
			out.append({"type": "close_night"})
		"summary":
			out.append({"type": "advance_day"})
	return out

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
		"customer": active.duplicate(),
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
