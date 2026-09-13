class_name Economy
extends RefCounted
## The money/reputation maths, kept legible (03-mvp-spec.md "Resolution rules").
## Port of app/src/engine/economy.ts. Pure: every function reads state, none writes it.

## Rounding helpers shared by the whole engine. They reproduce JS `Math.round(v*100)/100` exactly
## (floor(x+0.5), i.e. half-up toward +inf) so a ported number never drifts a cent from the prototype.
static func round2(v: float) -> float:
	return floorf(v * 100.0 + 0.5) / 100.0

static func round1(v: float) -> float:
	return floorf(v * 10.0 + 0.5) / 10.0

## Reputation meters live in 0..100 at one decimal.
static func clamp_meter(v: float) -> float:
	return maxf(0.0, minf(100.0, round1(v)))

static func price_tier(sku_def: Dictionary, price: float) -> String:
	if sku_def.is_empty():
		return "fair"
	if price < float(sku_def["fair_lo"]):
		return "steal"
	if price <= float(sku_def["fair_hi"]):
		return "fair"
	if price <= float(sku_def["fair_hi"]) * 1.25:
		return "high"
	return "gouge"

const TIER_RANK := {"steal": 0, "fair": 1, "high": 2, "gouge": 3}
const TIER_SATISFACTION := {"steal": 0.25, "fair": 0.15, "high": -0.05, "gouge": -0.35}
const TIER_KIEZ := {"steal": 0.4, "fair": 0.2, "high": -0.2, "gouge": -0.8}

## `promptness` is 0..1 patience remaining at serve time. `accuracy` is 0..1 — how much of the order
## the register actually got right (docs/08 §3.4). The widening is exact: the legacy call sites pass a
## bool `got_wanted`, which GDScript converts to 1.0 / 0.0, and `0.25 + 0.45 × accuracy` reproduces the
## old endpoints (false → 0.25, true → 0.70) to the cent — which is why test_economy.gd stays green.
static func satisfaction(accuracy: float, tier: String, promptness: float) -> float:
	var s := 0.25 + 0.45 * clampf(accuracy, 0.0, 1.0)
	s += float(TIER_SATISFACTION.get(tier, 0.0))
	s += 0.15 * clampf(promptness, 0.0, 1.0)
	return clampf(s, 0.0, 1.0)

# ─────────────────────── the register's verdict (docs/08 §3.4) ───────────────────────

## The Pfand crate rides the same multiset as everything else: her empties are a request like any
## other, so FORGETTING the deposit scores as `missing`. It is not a SKU — `Content.sku("pfand")` is
## `{}` — which is exactly why nothing charges for it and nothing tries to take it off a shelf.
const PFAND_KEY := "pfand"

## Two multisets keyed `(sku, brand)` — what she asked for, and what you actually rang — reduced to
## five buckets and one score (docs/08 §3.4). PURE: it reads the basket and the register lines and
## writes nothing. `lines` are `active.register.lines` (plus the Pfand pseudo-line the reducer
## appends), so every entry carries the `line` index the UI flags and the reducer voids.
##
##   missing      — an ordered key that was never rung at all.
##   extra        — a rung key that was never ordered; the units are VOIDED (no revenue, no stock).
##   wrong_brand  — right `sku`, wrong `brand`; weighted HALF of `extra` (reaching for the navy pack
##                  is a different sin from inventing a sale), and still sold.
##   wrong_count  — right key, wrong quantity; the delta counts.
##   refused      — a restricted line for an underage guest you actually ID'd: dropped from BOTH
##                  sides before scoring, so doing the right thing is never scored as `missing`.
static func order_accuracy(basket: Array, lines: Array, arch: Dictionary, id_checked: bool = false) -> Dictionary:
	var refuse := bool(arch.get("underage", false)) and id_checked
	var missing: Array = []
	var extra: Array = []
	var wrong_brand: Array = []
	var wrong_count: Array = []
	var refused: Array = []
	# Ordered key lists, so the buckets come out in basket order / register order and a replay of the
	# same night produces the same verdict dictionary byte for byte.
	var want_keys: Array = []
	var want: Dictionary = {}
	var want_row: Dictionary = {}
	var wanted_units := 0
	for entry in basket:
		var row: Dictionary = entry
		var sku_id := String(row.get("sku", ""))
		var qty := int(row.get("qty", 0))
		if sku_id == "" or qty <= 0:
			continue
		if refuse and is_restricted(sku_id):
			continue  # off both sides before scoring
		var key := _order_key(sku_id, String(row.get("brand", "")))
		if not want.has(key):
			want_keys.append(key)
			want[key] = 0
			want_row[key] = {"sku": sku_id, "brand": String(row.get("brand", ""))}
		want[key] = int(want[key]) + qty
		wanted_units += qty
	var got_keys: Array = []
	var got: Dictionary = {}
	var got_row: Dictionary = {}
	for i in lines.size():
		var line: Dictionary = lines[i]
		var sku_id := String(line.get("sku", ""))
		var qty := int(line.get("qty", 0))
		if sku_id == "" or qty <= 0:
			continue
		var brand := String(line.get("brand", ""))
		if refuse and is_restricted(sku_id):
			refused.append({"line": i, "sku": sku_id, "brand": brand, "qty": qty})
			continue
		var key := _order_key(sku_id, brand)
		if not got.has(key):
			got_keys.append(key)
			got[key] = 0
			got_row[key] = {"sku": sku_id, "brand": brand, "line": i}
		got[key] = int(got[key]) + qty
	# 1. Exact key matches: the same thing, possibly the wrong number of them.
	var want_left: Dictionary = want.duplicate()
	var got_left: Dictionary = got.duplicate()
	for key in want_keys:
		if not got.has(key):
			continue
		var delta := int(got[key]) - int(want[key])
		if delta != 0:
			wrong_count.append({"line": int(got_row[key]["line"]), "sku": String(want_row[key]["sku"]),
				"brand": String(want_row[key]["brand"]), "want": int(want[key]), "got": int(got[key]),
				"qty": absi(delta)})
		want_left.erase(key)
		got_left.erase(key)
	# 2. What is left of the order looks for the same SKU under another mark — that is the half-sin.
	#    UNLESS she never named a mark: an unbranded line is "whatever you've got", so any facing of
	#    that SKU satisfies it. That is the whole nameless parade, which asks for "cigarettes".
	for key in want_keys:
		if not want_left.has(key):
			continue
		var need := int(want_left[key])
		var sku_id := String(want_row[key]["sku"])
		var any_mark := String(want_row[key]["brand"]) == ""
		for gkey in got_keys:
			if need <= 0:
				break
			if not got_left.has(gkey) or String(got_row[gkey]["sku"]) != sku_id:
				continue
			var paired := mini(need, int(got_left[gkey]))
			if not any_mark:
				wrong_brand.append({"line": int(got_row[gkey]["line"]), "sku": sku_id,
					"brand": String(got_row[gkey]["brand"]), "wanted_brand": String(want_row[key]["brand"]),
					"qty": paired})
			need -= paired
			if int(got_left[gkey]) - paired <= 0:
				got_left.erase(gkey)
			else:
				got_left[gkey] = int(got_left[gkey]) - paired
		if need > 0:
			missing.append({"sku": sku_id, "brand": String(want_row[key]["brand"]), "qty": need})
		want_left.erase(key)
	# 3. Whatever is still on the register was never ordered at all.
	for gkey in got_keys:
		if not got_left.has(gkey):
			continue
		extra.append({"line": int(got_row[gkey]["line"]), "sku": String(got_row[gkey]["sku"]),
			"brand": String(got_row[gkey]["brand"]), "qty": int(got_left[gkey])})
	var errors := float(_units(missing)) + float(_units(extra)) + 0.5 * float(_units(wrong_brand)) + float(_units(wrong_count))
	var accuracy := round2(clampf(1.0 - errors / maxf(1.0, float(wanted_units)), 0.0, 1.0))
	return {
		"ok": errors == 0.0,
		"accuracy": accuracy,
		"errors": errors,
		"wanted_units": wanted_units,
		"missing": missing,
		"extra": extra,
		"wrong_brand": wrong_brand,
		"wrong_count": wrong_count,
		"refused": refused,
	}

## A basket line and a register line are the same thing when the SKU *and* the mark agree — which is
## the whole tobacco wall in one string.
static func _order_key(sku_id: String, brand: String) -> String:
	return sku_id + "|" + brand

static func _units(bucket: Array) -> int:
	var n := 0
	for entry in bucket:
		n += int((entry as Dictionary).get("qty", 0))
	return n

## Age-restricted? Asked of the SKU table, never of a hard-coded list, so a new restricted SKU is
## restricted everywhere the moment it is written.
static func is_restricted(sku_id: String) -> bool:
	return bool(Content.sku(sku_id).get("restricted", false))

static func tip_for(arch: Dictionary, total: float, sat: float) -> float:
	if sat < 0.5 or arch.is_empty():
		return 0.0
	return round2(float(arch["tip_base"]) * total * sat)

static func kiez_delta(arch: Dictionary, tier: String, balked: bool) -> float:
	if arch.is_empty():
		return 0.0
	var sensitivity := float(arch["kiez_sensitivity"])
	var v := -1.0 * sensitivity if balked else float(TIER_KIEZ.get(tier, 0.0)) * sensitivity
	return round1(v)

static func owns_upgrade(s: Dictionary, id: String) -> bool:
	return (s["upgrades"] as Array).has(id)

## Why a module is still locked — "" when it is buyable now (gradual availability, GDD §4c).
static func unlock_reason(s: Dictionary, def: Dictionary) -> String:
	var requires: String = def.get("requires", "")
	if requires != "" and not owns_upgrade(s, requires):
		var prereq := Content.upgrade(requires)
		return "needs %s" % (prereq["name"] if not prereq.is_empty() else requires)
	var available_day: int = int(def.get("available_day", 0))
	if available_day > 0 and int(s["day"]) < available_day:
		return "unlocks on day %d" % available_day
	var available_kiez := float(def.get("available_kiez", 0.0))
	if available_kiez > 0.0 and float(s["reputation"]["kiez"]) < available_kiez:
		return "needs Kiez-Trust %d" % int(available_kiez)
	return ""

## The Build & Customize shop view: what is owned / available now / still locked, and why.
static func module_options(s: Dictionary) -> Array:
	var out: Array = []
	for def in Content.UPGRADES:
		var owned := owns_upgrade(s, def["id"])
		var reason := "" if owned else unlock_reason(s, def)
		out.append({
			"def": def,
			"owned": owned,
			"available": not owned and reason == "",
			"affordable": float(s["cash"]) >= float(def["cost"]),
			"reason": reason,
		})
	return out

# Community systems a module can switch on (GDD §4b) → a friendly label for the UI.
const SYSTEM_LABEL := {
	"dwell": "The bench draws a crowd",
	"community": "Foodsharing fridge",
	"events": "Open-mic nights",
	"board": "Community noticeboard",
}
# Vignette/strand/conversation flags that visibly change the corner → a friendly label. This is the
# READ side of `story.flags`: a branch the player chose in a conversation has to leave a mark they can
# see, or the choice was theatre. (The regulars' graphs write these — dialogues.gd.)
const FLAG_LABEL := {
	"flyers_up": "Gig flyers in the window",
	"busker": "Live music out front",
	"lena_credit": "Lena's tab",
	"lena_tab": "Lena drinks on trust",
	"lena_sketch": "Lena's sketch by the register",
	"lena_fed": "Lena eats here now",
	"juergen_crate": "You carry Jürgen's crates",
	"juergen_warm": "Jürgen thawed out",
	"juergen_bench": "Jürgen's bench out front",
	"mehmet_evidence": "The rent letter is filed",
	"mehmet_asked": "Mehmet asked the street",
	"kiez_rally": "The Kiez turned out",
}

## A legible roll-up of "what your corner has become" — drives the Manage-screen standing panel.
static func corner_status(s: Dictionary) -> Dictionary:
	var kiez_per_night := 0.0
	var traffic_mult := 1.0
	var illegal := false
	var has_security := false
	var systems: Array = []
	for id in s["upgrades"]:
		var effects: Dictionary = Content.upgrade(id).get("effects", {})
		kiez_per_night += float(effects.get("kiez_per_night", 0.0))
		traffic_mult *= float(effects.get("traffic_mult", 1.0))
		if effects.get("illegal", false):
			illegal = true
		if effects.get("fewer_risk_events", false):
			has_security = true
		var system: String = effects.get("unlocks_system", "")
		if SYSTEM_LABEL.has(system):
			systems.append(SYSTEM_LABEL[system])
	var flags: Array = []
	for f in s["story"]["flags"]:
		# Two flags may share a label (lena_credit and lena_tab are both the tab) — say it once.
		if FLAG_LABEL.has(f) and not flags.has(FLAG_LABEL[f]):
			flags.append(FLAG_LABEL[f])
	return {
		"kiez_per_night": round1(kiez_per_night),
		"traffic_mult": round2(traffic_mult),
		"systems": systems,
		"flags": flags,
		"illegal": illegal,
		"has_security": has_security,
		"heat": float(s["ordnungsamt_heat"]),
	}

## Expected customer count for one night (deterministic; the rng only places them in time).
static func night_traffic(s: Dictionary) -> int:
	# A busy Späti serves dozens a night; difficulty lives in the financials, not the traffic.
	var base := 65.0
	var mult := 1.0
	for id in s["upgrades"]:
		mult *= float(Content.upgrade(id).get("effects", {}).get("traffic_mult", 1.0))
	# Kiez-Trust nudges foot traffic; Sunday is a big spike (everyone else is shut).
	mult *= 1.0 + clampf((float(s["reputation"]["kiez"]) - 50.0) / 200.0, -0.3, 0.4)
	if int(s["weekday"]) == 6 and bool(s["open_sunday"]):
		mult *= 1.6
	return int(floorf(base * mult + 0.5))
