class_name AutoPlayer
extends RefCounted
## Headless "competent shopkeeper" policy — drives the engine tests and any balance sweep.
## NOT shipped in the game. Port of app/src/sim/autoPlayer.ts, plus the one thing the prototype never
## had to do: a beat now happens AT THE COUNTER, so the policy has to answer it before it can serve.

const DEFAULT_MARKUP := 2.5
const DEFAULT_PAR := 22
const DEFAULT_DT_MS := 1000
const TICK_GUARD := 100000
## A conversation is 5-8 nodes; this only catches a cycle in badly authored data.
const TALK_GUARD := 128

static func _round2(v: float) -> float:
	return Economy.round2(v)

## Price a SKU at cost×markup, clamped into its fair band — the honest shopkeeper's rule of thumb.
static func clamp_to_fair(sku_id: String, price: float) -> float:
	var def := Content.sku(sku_id)
	if def.is_empty():
		return price
	return _round2(clampf(price, float(def["fair_lo"]), float(def["fair_hi"])))

## Manage phase: set every price, then restock everything up to `par`.
static func manage(s0: Dictionary, markup: float = DEFAULT_MARKUP, par: int = DEFAULT_PAR) -> Dictionary:
	var s := s0
	for sku_id in (s["inventory"] as Dictionary).keys():
		var def := Content.sku(sku_id)
		if def.is_empty():
			continue
		s = Rules.apply(s, {"type": "set_price", "sku": sku_id, "price": clamp_to_fair(sku_id, float(def["cost"]) * markup)})
		var need := par - int(s["inventory"][sku_id]["stock"])
		if need > 0:
			s = Rules.apply(s, {"type": "restock", "sku": sku_id, "qty": need})
	return s

## Answer whatever is being said at the counter — always the first authored option, so a run is
## reproducible. That reads as the kind/honest line in almost every beat; the one place it does not is
## the main climax, where option 0 is "sell and walk away" (which is why the baseline season ends
## 'soldout'). A sweep that wants the other branch passes its own choices, not a smarter policy.
## A GATED choice cannot be taken (docs/06 §2), so the policy is "the first choice that is legal" —
## with the authoring rule that choice 0 is never gated, that is choice 0 in every written node.
static func resolve_dialogue(s: Dictionary) -> Dictionary:
	if Talk.is_open(s):
		return play_talk(s)
	if not (s["story"]["pending"] as Dictionary).is_empty():
		return Rules.apply(s, {"type": "resolve_beat", "choice": 0})
	if s["story"]["pending_vignette"] != "":
		return Rules.apply(s, {"type": "resolve_vignette", "choice": 0})
	return s

## Read every line of the open conversation, then take the first choice that is not locked; repeat
## until the talk closes. Conversations cost no game time, so this never starves the night clock.
static func play_talk(s0: Dictionary, guard_limit: int = TALK_GUARD) -> Dictionary:
	var s := s0
	var guard := 0
	while Talk.is_open(s) and guard < guard_limit:
		guard += 1
		var stepped := Rules.apply(s, {"type": "talk_advance"})
		if not is_same(stepped, s):
			s = stepped
			continue
		var chose := s
		var node := Talk.node_of(s)
		for i in (node.get("choices", []) as Array).size():
			chose = Rules.apply(s, {"type": "talk_choose", "choice": i})
			if not is_same(chose, s):
				break
		if is_same(chose, s):
			break  # every choice locked — test_dialogue forbids the data that would do this
		s = chose
	return s

## One guest, one turn: pull them up with `talk_next`, play the conversation out, and let the
## engine's own `talk_end` ring up what they came in for (docs/06 §4).
static func talk_turn(s0: Dictionary) -> Dictionary:
	var s := s0
	if Talk.is_open(s):
		return play_talk(s)
	# The line waits for the shopkeeper (docs/06 §5 — nobody steps up on their own unless
	# `config.auto_take_next`), so the policy takes the head of the queue itself.
	if (s["active"] as Dictionary).is_empty() and (s["queue"] as Array).is_empty():
		return s
	var opened := Rules.apply(s, {"type": "talk_next"})
	if is_same(opened, s):
		return s  # nothing to take, or no graph for this guest — the caller falls back to the plain serve
	if Talk.is_open(opened):
		return play_talk(opened)
	return opened  # a guest stepped up without a conversation — the caller serves their want

## Open → tick the whole night, talking to whoever talks and serving the want if stocked → close.
static func play_night(s0: Dictionary, dt_ms: int = DEFAULT_DT_MS) -> Dictionary:
	var s := Rules.apply(s0, {"type": "open_night"})
	var guard := 0
	while s["phase"] == "night" and guard < TICK_GUARD:
		guard += 1
		s = Rules.apply(s, {"type": "tick", "dt_ms": dt_ms})
		var before_talk := s
		s = talk_turn(s)  # talk_next -> advance -> choose; the talk ends and leaves them AT the register
		# docs/08 §1: her talk ending is not the sale any more, it is the sale STARTING. A guest whose
		# basket is on the counter has to be fetched for, scanned and rung up, or the competent
		# shopkeeper simply stands there while the patience clock runs out.
		s = serve_register(s)
		if is_same(s, before_talk):
			# Nobody could be talked to (no graph for them) — fall back to the plain counter policy.
			var active: Dictionary = s["active"]
			if not active.is_empty():
				var want: String = active["want"]
				var in_stock := int((s["inventory"] as Dictionary).get(want, {}).get("stock", 0)) > 0
				# A competent, honest shopkeeper serves the want if stocked — but refuses an underage
				# restricted sale (the Integrity beat). The dark path drives Integrity down elsewhere.
				var illegal_sale := bool(Content.archetype(active["archetype_id"]).get("underage", false)) \
					and bool(Content.sku(want).get("restricted", false))
				if in_stock and not illegal_sale:
					s = Rules.apply(s, {"type": "serve_active", "give": [want], "pfand_bottles": 0})
				else:
					s = Rules.apply(s, {"type": "skip_active"})
		if int(s["clock_ms"]) >= int(s["config"]["night_len_ms"]) \
			and not Talk.is_open(s) \
			and (s["active"] as Dictionary).is_empty() \
			and (s["queue"] as Array).is_empty() \
			and int(s["next_arrival"]) >= (s["arrivals"] as Array).size():
			break
	return Rules.apply(s, {"type": "close_night"})

## The whole register loop as a policy (docs/08 §1), driven ENTIRELY off the read-model: what she
## asked for minus what is already on the counter is the wall trip, and nothing here is typed by hand.
##   order -> what is missing -> turn around -> take those facings -> turn back -> scan -> pfand -> ring
## `{}` in, `{}` out when there is nobody to serve, so the caller can always run it.
static func serve_register(s0: Dictionary) -> Dictionary:
	var s := s0
	if Talk.is_open(s) or (s["active"] as Dictionary).is_empty():
		return s
	if (((s["active"] as Dictionary).get("basket", []) as Array)).is_empty():
		return s  # the parade: no basket, the caller's plain `serve_active` still answers for them
	var trips := 0
	while trips < 4:
		trips += 1
		var missing := _missing_facings(s)
		if missing.is_empty():
			break
		s = Rules.apply(s, {"type": "turn_around", "on": true})
		if String(s.get("view_mode", "counter")) != "wall":
			break  # the wall refused the trip (no active guest any more) — do not spin
		var hand := int(((s["active"] as Dictionary).get("hand", []) as Array).size())
		for key in missing:
			var parts := String(key).split("|")
			for i in int(missing[key]):
				if hand >= Rules.HAND_MAX:
					break
				var before := s
				s = Rules.apply(s, {"type": "take_from_wall", "sku": parts[0], "brand": parts[1]})
				if is_same(s, before):
					break  # out of stock: ring it short rather than loop
				hand += 1
		s = Rules.apply(s, {"type": "turn_around", "on": false})
	# Scan everything that is not the crate — one `scan` per uid, exactly what the tray offers.
	var guard := 0
	while guard < 32:
		guard += 1
		var uid := -1
		for entry in ((s["active"] as Dictionary).get("counter", []) as Array):
			var item: Dictionary = entry
			if String(item["kind"]) != "crate" and not bool(item["scanned"]):
				uid = int(item["uid"])
				break
		if uid < 0:
			break
		var before := s
		s = Rules.apply(s, {"type": "scan", "uid": uid})
		if is_same(s, before):
			break
	# The competent shopkeeper is also the HONEST one (the same rule `play_night`'s fallback already
	# applied to the single-want path): a minor at the counter gets their ID checked, which REFUSES the
	# restricted line rather than selling it for −8 Integrity (docs/08 §3.4). The dark path drives
	# Integrity down elsewhere, deliberately, and not by accident in the baseline.
	# `.get` all the way down: by here the guest may have run out of patience and left, and `active` is
	# then `{}` — a hard index would take the whole season down with it (it did: test_determinism).
	var guest: Dictionary = s.get("active", {})
	if bool(Content.archetype(String(guest.get("archetype_id", ""))).get("underage", false)):
		for entry in ((guest.get("register", {}) as Dictionary).get("lines", []) as Array):
			if bool(Content.sku(String((entry as Dictionary)["sku"])).get("restricted", false)):
				s = Rules.apply(s, {"type": "check_id"})
				break
	var bottles := int((s["active"] as Dictionary).get("bottles", 0))
	if bottles > 0:
		s = Rules.apply(s, {"type": "set_pfand", "bottles": bottles})
	# Ring it. The first ring may be REJECTED by the one free correction (docs/08 §3.4) when the wall
	# could not supply what she asked for; the second commits as rung, which is the shopkeeper
	# accepting the short order rather than leaving her standing there.
	for attempt in 2:
		if (s["active"] as Dictionary).is_empty():
			break
		var before := s
		s = Rules.apply(s, {"type": "ring_up"})
		if is_same(s, before):
			break
		if (s["active"] as Dictionary).is_empty():
			break
	return s

## (sku|brand) -> how many more of that facing the order needs than the counter currently holds.
## Pfand is not a facing and never counts; an UNBRANDED line takes any facing of that SKU, which is
## the same rule `Economy.order_accuracy` scores by (economy.gd, step 2 of the pairing).
static func _missing_facings(s: Dictionary) -> Dictionary:
	var active: Dictionary = s["active"]
	var have: Dictionary = {}
	var have_by_sku: Dictionary = {}
	for entry in (active.get("counter", []) as Array):
		var item: Dictionary = entry
		if String(item["kind"]) == "crate":
			continue
		var key := String(item["sku"]) + "|" + String(item["brand"])
		have[key] = int(have.get(key, 0)) + 1
		have_by_sku[String(item["sku"])] = int(have_by_sku.get(String(item["sku"]), 0)) + 1
	for entry in (active.get("hand", []) as Array):
		var item: Dictionary = entry
		var key := String(item["sku"]) + "|" + String(item["brand"])
		have[key] = int(have.get(key, 0)) + 1
		have_by_sku[String(item["sku"])] = int(have_by_sku.get(String(item["sku"]), 0)) + 1
	var out: Dictionary = {}
	for entry in (active.get("basket", []) as Array):
		var row: Dictionary = entry
		var sku_id := String(row["sku"])
		if sku_id == Rules.PFAND_SKU:
			continue
		var brand := String(row["brand"])
		var key := sku_id + "|" + brand
		var got := int(have_by_sku.get(sku_id, 0)) if brand == "" else int(have.get(key, 0))
		var short_by := int(row["qty"]) - got
		if short_by > 0:
			out[key] = short_by
	return out

## Optional strategy knobs — the balance sweeps use them to exercise the risk systems. The default
## (no policy) is the fair-pricing, no-upgrades, weekdays-only baseline the determinism test relies on.
static func play_season(s0: Dictionary, policy: Dictionary = {}) -> Dictionary:
	var markup := float(policy.get("markup", DEFAULT_MARKUP))
	var s := s0
	var total_profit := 0.0
	var guard := 0
	while s["phase"] != "end" and guard < 1000:
		guard += 1
		if s["phase"] == "manage":
			if policy.get("open_sundays", false) and not bool(s["open_sunday"]):
				s = Rules.apply(s, {"type": "set_sunday_open", "open": true})
			if policy.get("buy_security", false):
				s = Rules.apply(s, {"type": "buy_upgrade", "id": "security"})  # no-op until available
			if policy.get("buy_dark_path", false):
				s = Rules.apply(s, {"type": "buy_upgrade", "id": "extra_menu"})
			s = manage(s, markup)
			s = play_night(s)
		if s["phase"] == "summary":
			total_profit += float((s["summaries"] as Array).back()["profit"])
			s = Rules.apply(s, {"type": "advance_day"})
	return {
		"survived": float(s["cash"]) >= 0.0,
		"days": int(s["day"]),
		"end_cash": _round2(float(s["cash"])),
		"kiez": float(s["reputation"]["kiez"]),
		"integrity": float(s["reputation"]["integrity"]),
		"total_profit": _round2(total_profit),
		"final": s,
	}

## Play exactly `nights` nights from a fresh manage phase (the tests' 7-night season).
static func play_nights(s0: Dictionary, nights: int, markup: float = DEFAULT_MARKUP) -> Dictionary:
	var s := s0
	for i in nights:
		if s["phase"] != "manage":
			break
		s = manage(s, markup)
		s = play_night(s)
		if s["phase"] == "summary":
			s = Rules.apply(s, {"type": "advance_day"})
	return s
