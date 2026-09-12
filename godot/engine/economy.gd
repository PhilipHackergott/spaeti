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

## `promptness` is 0..1 patience remaining at serve time.
static func satisfaction(got_wanted: bool, tier: String, promptness: float) -> float:
	var s := 0.7 if got_wanted else 0.25
	s += float(TIER_SATISFACTION.get(tier, 0.0))
	s += 0.15 * clampf(promptness, 0.0, 1.0)
	return clampf(s, 0.0, 1.0)

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
# Vignette/strand flags that visibly change the corner → a friendly label.
const FLAG_LABEL := {
	"flyers_up": "Gig flyers in the window",
	"busker": "Live music out front",
	"lena_credit": "Lena's tab",
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
		if FLAG_LABEL.has(f):
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
