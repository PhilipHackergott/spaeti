class_name AutoPlayer
extends RefCounted
## Headless "competent shopkeeper" policy — drives the engine tests and any balance sweep.
## NOT shipped in the game. Port of app/src/sim/autoPlayer.ts, plus the one thing the prototype never
## had to do: a beat now happens AT THE COUNTER, so the policy has to answer it before it can serve.

const DEFAULT_MARKUP := 2.5
const DEFAULT_PAR := 22
const DEFAULT_DT_MS := 1000
const TICK_GUARD := 100000

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
static func resolve_dialogue(s: Dictionary) -> Dictionary:
	if not (s["story"]["pending"] as Dictionary).is_empty():
		return Rules.apply(s, {"type": "resolve_beat", "choice": 0})
	if s["story"]["pending_vignette"] != "":
		return Rules.apply(s, {"type": "resolve_vignette", "choice": 0})
	return s

## Open → tick the whole night, talking to whoever talks and serving the want if stocked → close.
static func play_night(s0: Dictionary, dt_ms: int = DEFAULT_DT_MS) -> Dictionary:
	var s := Rules.apply(s0, {"type": "open_night"})
	var guard := 0
	while s["phase"] == "night" and guard < TICK_GUARD:
		guard += 1
		s = Rules.apply(s, {"type": "tick", "dt_ms": dt_ms})
		s = resolve_dialogue(s)  # a beat blocks the serve until it is answered
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
			and (s["active"] as Dictionary).is_empty() \
			and (s["queue"] as Array).is_empty() \
			and int(s["next_arrival"]) >= (s["arrivals"] as Array).size():
			break
	return Rules.apply(s, {"type": "close_night"})

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
