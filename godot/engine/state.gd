class_name SpatiState
extends RefCounted
## The whole game is one plain Dictionary (docs/05-engine-api.md §2) so it round-trips through JSON,
## replays from {config, seed, actions} and runs headless. "None" is "" or {} — never null inside an
## array — because Godot's JSON drops nothing but types everything numeric as float, which is why
## from_json() re-integers the int fields (see _normalise).
## Port of app/src/engine/setup.ts + types.ts.

## Difficulty lives in the FINANCIALS (start cash / rent), not in traffic — see Economy.night_traffic.
const DIFFICULTY_PRESETS := {
	"cozy": {"start_cash": 600.0, "rent_per_day": 35.0},
	"normal": {"start_cash": 420.0, "rent_per_day": 48.0},
	"tight": {"start_cash": 300.0, "rent_per_day": 68.0},
}

const DEFAULT_CONFIG := {
	"difficulty": "normal",
	"seed": 1,
	"night_len_ms": 300000,  # 5 compressed minutes of night; maps onto 20:00 → 06:00 in the view
	"season_days": 28,
	"start_cash": 420.0,
	"rent_per_day": 48.0,
}

const START_STOCK := 8
const START_KIEZ := 50.0
const START_PROFIT := 50.0
const START_INTEGRITY := 75.0

## DEFAULT_CONFIG + the difficulty preset + whatever the caller overrode, in that order.
static func make_config(overrides: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = DEFAULT_CONFIG.duplicate(true)
	var difficulty: String = overrides.get("difficulty", cfg["difficulty"])
	var preset: Dictionary = DIFFICULTY_PRESETS.get(difficulty, {})
	cfg["difficulty"] = difficulty
	for key in preset:
		cfg[key] = preset[key]
	for key in overrides:
		cfg[key] = overrides[key]
	cfg["seed"] = int(cfg["seed"])
	cfg["night_len_ms"] = int(cfg["night_len_ms"])
	cfg["season_days"] = int(cfg["season_days"])
	cfg["start_cash"] = float(cfg["start_cash"])
	cfg["rent_per_day"] = float(cfg["rent_per_day"])
	return cfg

static func new_game(config: Dictionary = {}) -> Dictionary:
	var cfg := make_config(config)
	var inventory := {}
	for sku in Content.SKUS:
		if sku.get("unlocked_by", "") != "":
			continue  # gated SKUs appear on the shelf when their upgrade is bought
		inventory[sku["id"]] = {"stock": START_STOCK, "price": float(sku["base_price"])}
	return {
		"config": cfg,
		"day": 1,
		"weekday": 0,  # day 1 is a Monday
		"phase": "manage",
		"clock_ms": 0,
		"cash": float(cfg["start_cash"]),
		"pfand_held": 0,
		"inventory": inventory,
		"upgrades": [],
		"reputation": {"kiez": START_KIEZ, "profit": START_PROFIT, "integrity": START_INTEGRITY},
		"open_sunday": false,
		"ordnungsamt_heat": 0.0,
		"arrivals": [],
		"next_arrival": 0,
		"queue": [],
		"active": {},
		"next_customer_id": 1,
		"tally": new_tally(),
		"summaries": [],
		"story": new_story(),
		"rng_state": int(cfg["seed"]) & 0xFFFFFFFF,
		"log": [],
	}

static func new_tally() -> Dictionary:
	return {"revenue": 0.0, "cogs": 0.0, "tips": 0.0, "pfand_paid": 0.0, "sales": 0, "lost": 0}

static func new_story() -> Dictionary:
	var strands := {}
	for strand in Content.STRANDS:
		strands[strand["id"]] = {"cur": strand["start"], "outcome": "", "last_day": -1}
	return {
		"flags": [],
		"met": [],
		"strands": strands,
		"main_outcome": "",
		"pending": {},
		"seen_vignettes": [],
		"pending_vignette": "",
	}

## A customer instance at (or heading for) the counter.
static func new_customer(id: int, archetype_id: String, want: String, patience_ms: int,
		character_id: String = "", beat_id: String = "", vignette_id: String = "") -> Dictionary:
	return {
		"id": id,
		"archetype_id": archetype_id,
		"want": want,
		"patience_left_ms": patience_ms,
		"character_id": character_id,
		"beat_id": beat_id,
		"vignette_id": vignette_id,
		"expression": "neutral",
	}

static func clone(s: Dictionary) -> Dictionary:
	return s.duplicate(true)

static func to_json(s: Dictionary) -> String:
	return JSON.stringify(s)

## Parse + re-integer: Godot's JSON makes every number a float, so `day` would come back as 1.0 and
## stringify as "1.0" — the round-trip (and every `==` against an int) breaks without this pass.
static func from_json(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return _normalise(parsed as Dictionary)

static func _normalise(s: Dictionary) -> Dictionary:
	var cfg: Dictionary = s["config"]
	cfg["seed"] = int(cfg["seed"])
	cfg["night_len_ms"] = int(cfg["night_len_ms"])
	cfg["season_days"] = int(cfg["season_days"])
	cfg["start_cash"] = float(cfg["start_cash"])
	cfg["rent_per_day"] = float(cfg["rent_per_day"])
	s["day"] = int(s["day"])
	s["weekday"] = int(s["weekday"])
	s["clock_ms"] = int(s["clock_ms"])
	s["pfand_held"] = int(s["pfand_held"])
	s["next_arrival"] = int(s["next_arrival"])
	s["next_customer_id"] = int(s["next_customer_id"])
	s["rng_state"] = int(s["rng_state"])
	s["cash"] = float(s["cash"])
	s["ordnungsamt_heat"] = float(s["ordnungsamt_heat"])
	for sku_id in s["inventory"]:
		var inv: Dictionary = s["inventory"][sku_id]
		inv["stock"] = int(inv["stock"])
		inv["price"] = float(inv["price"])
	for arrival in s["arrivals"]:
		arrival["time_ms"] = int(arrival["time_ms"])
	for customer in s["queue"]:
		_normalise_customer(customer)
	if not (s["active"] as Dictionary).is_empty():
		_normalise_customer(s["active"])
	s["tally"]["sales"] = int(s["tally"]["sales"])
	s["tally"]["lost"] = int(s["tally"]["lost"])
	for summary in s["summaries"]:
		summary["day"] = int(summary["day"])
		summary["sales"] = int(summary["sales"])
		summary["lost"] = int(summary["lost"])
	for strand_id in s["story"]["strands"]:
		var progress: Dictionary = s["story"]["strands"][strand_id]
		progress["last_day"] = int(progress["last_day"])
	for entry in s["log"]:
		entry["ts"] = int(entry["ts"])
		_normalise_data(entry["data"])
	return s

## Log `data` payloads are free-form (the FX/SFX stream reads them), so the rule is: whole numbers are
## ints, never 2.0 — then re-integering every integral float here restores the state exactly as written.
static func _normalise_data(data: Dictionary) -> void:
	for key in data:
		var v: Variant = data[key]
		if typeof(v) == TYPE_FLOAT and v == floorf(v):
			data[key] = int(v)
		elif typeof(v) == TYPE_DICTIONARY:
			_normalise_data(v)

static func _normalise_customer(c: Dictionary) -> void:
	c["id"] = int(c["id"])
	c["patience_left_ms"] = int(c["patience_left_ms"])

## Act/season label from the calendar (Summer → Autumn → Winter thirds).
static func act_of(s: Dictionary) -> String:
	var f := float(s["day"]) / float(s["config"]["season_days"])
	if f <= 1.0 / 3.0:
		return "summer"
	return "autumn" if f <= 2.0 / 3.0 else "winter"
