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

## The six stats (docs/06 §1). 8..18; a later character-creation screen may replace them, and the
## engine reads them only through Rules.stat_score / Rules.modifier, never from a literal.
const DEFAULT_STATS := {"str": 10, "dex": 11, "con": 12, "int": 13, "wis": 12, "cha": 14}

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
		"player": new_player(),
		"talk": {},
		# The register (docs/08 §3.1). Everything that dies with the customer lives under `active`;
		# these three stay TOP LEVEL on purpose — which way your body is facing, the uid counter and the
		# record of the last ring-up all have to survive a customer leaving while you are at the wall.
		"view_mode": "counter",
		"next_item_uid": 1,
		"last_verdict": {},
		"rng_state": int(cfg["seed"]) & 0xFFFFFFFF,
		"log": [],
	}

## The shopkeeper themself: the only thing in state that a conversation rolls against (docs/06 §1).
static func new_player() -> Dictionary:
	return {"stats": DEFAULT_STATS.duplicate(true)}

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
		character_id: String = "", beat_id: String = "", vignette_id: String = "",
		bottles: int = 0) -> Dictionary:
	return {
		"id": id,
		"archetype_id": archetype_id,
		"want": want,
		"patience_left_ms": patience_ms,
		"character_id": character_id,
		"beat_id": beat_id,
		"vignette_id": vignette_id,
		"expression": "neutral",
		# Empties THEY carried in — the Pfand you can pay out for them. Not `pfand_held`, which is the
		# shop's own crate waiting on wholesaler credit.
		"bottles": bottles,
		# The register, nested under the person it belongs to (docs/08 §3.1): `_next_customer` clears
		# `active` wholesale, so counter/register desync is structurally impossible rather than a thing
		# somebody has to remember to clear. Empty until `place_basket` fires at the counter.
		"basket": [],
		"counter": [],
		"register": new_register(),
		"hand": [],
	}

## The claim, as opposed to the counter's physical truth (docs/08 §3.1). `flagged` holds the line
## indices the rejected ring-up marked; `correction` is what she said about it.
static func new_register() -> Dictionary:
	return {
		"lines": [],
		"pfand_bottles": 0,
		"id_checked": false,
		"corrections": 0,
		"flagged": [],
		"correction": "",
		## The bucket behind that sentence, so the box can pick the words out of `Strings` instead of
		## printing the reducer's own English (docs/08 §3.4).
		"correction_kind": "",
	}

static func clone(s: Dictionary) -> Dictionary:
	return s.duplicate(true)

static func to_json(s: Dictionary) -> String:
	return JSON.stringify(s)

## The keys `_normalise` INDEXES (as opposed to reading with a default). A half-written file, or a
## save from a build before a key existed, parses as a Dictionary but is not a state — and indexing
## it threw a script error out of the reducer while the title's Continue swallowed the click.
## `player` and `talk` stay forgiving: they post-date the autosave and keep their `.get()` defaults.
const SAVE_SHAPE := {
	"": ["config", "phase", "day", "weekday", "clock_ms", "pfand_held", "next_arrival",
		"next_customer_id", "rng_state", "cash", "ordnungsamt_heat", "inventory", "arrivals",
		"queue", "active", "tally", "summaries", "story", "log"],
	"config": ["seed", "night_len_ms", "season_days", "start_cash", "rent_per_day"],
	"tally": ["sales", "lost"],
	"story": ["strands"],
}

## Parse + re-integer: Godot's JSON makes every number a float, so `day` would come back as 1.0 and
## stringify as "1.0" — the round-trip (and every `==` against an int) breaks without this pass.
## A shape `_normalise` cannot walk comes back as `{}`, so a bad save is a dead Continue, never a crash.
static func from_json(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var s := parsed as Dictionary
	for section in SAVE_SHAPE:
		var d: Variant = s if String(section) == "" else s.get(section)
		if typeof(d) != TYPE_DICTIONARY:
			return {}
		for key in SAVE_SHAPE[section]:
			if not (d as Dictionary).has(key):
				return {}
	return _normalise(s)

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
	# The shelf is rebuilt in the CATALOGUE's order, not the order the file happened to carry: Godot's
	# JSON sorts keys alphabetically on the way out, so a reloaded save iterated its inventory in a
	# different order from the live one  and any loop that spends until the cash runs out (the
	# AutoPlayer's restock) then bought different things. Re-integering alone is not enough to make a
	# save/load seam invisible; the ORDER has to be canonical too (2026-09-13).
	var shelf := {}
	for sku in Content.SKUS:
		var sid := String(sku["id"])
		if (s["inventory"] as Dictionary).has(sid):
			shelf[sid] = s["inventory"][sid]
	for sku_id in s["inventory"]:
		if not shelf.has(sku_id):
			shelf[sku_id] = s["inventory"][sku_id]   # a SKU the catalogue no longer lists still loads
	s["inventory"] = shelf
	for sku_id in s["inventory"]:
		var inv: Dictionary = s["inventory"][sku_id]
		inv["stock"] = int(inv["stock"])
		inv["price"] = float(inv["price"])
	for arrival in s["arrivals"]:
		arrival["time_ms"] = int(arrival["time_ms"])
		arrival["bottles"] = int(arrival.get("bottles", 0))
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
	var player: Dictionary = s.get("player", new_player())
	for stat in (player["stats"] as Dictionary):
		player["stats"][stat] = int(player["stats"][stat])
	s["player"] = player
	var talk: Dictionary = s.get("talk", {})
	if not talk.is_empty():
		talk["customer_id"] = int(talk["customer_id"])
		talk["line"] = int(talk["line"])
		_normalise_data(talk["last_check"])
	s["talk"] = talk
	# The register keys post-date the autosave, so they are read with defaults: a save written before
	# docs/08 landed loads into a shop facing the counter with an empty till (docs/08 §3.1).
	s["view_mode"] = String(s.get("view_mode", "counter"))
	s["next_item_uid"] = int(s.get("next_item_uid", 1))
	s["last_verdict"] = _normalise_verdict(s.get("last_verdict", {}))
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
	c["bottles"] = int(c.get("bottles", 0))
	# The register, re-integered (docs/08 §3.1). Every count here is a whole number of things, so a
	# save that came back as 2.0 packs would stringify differently and break the replay guarantee.
	var basket: Array = c.get("basket", [])
	for row in basket:
		(row as Dictionary)["qty"] = int((row as Dictionary).get("qty", 1))
	c["basket"] = basket
	var counter: Array = c.get("counter", [])
	for item in counter:
		(item as Dictionary)["uid"] = int((item as Dictionary).get("uid", 0))
		(item as Dictionary)["count"] = int((item as Dictionary).get("count", 1))
	c["counter"] = counter
	var register: Dictionary = c.get("register", new_register())
	for line in (register.get("lines", []) as Array):
		(line as Dictionary)["qty"] = int((line as Dictionary).get("qty", 1))
		var uids: Array = (line as Dictionary).get("uids", [])
		for i in uids.size():
			uids[i] = int(uids[i])
	register["pfand_bottles"] = int(register.get("pfand_bottles", 0))
	register["corrections"] = int(register.get("corrections", 0))
	# Both halves of the correction get a default, so a register saved before the bucket id existed
	# still round-trips to a byte-identical `to_json` (test_determinism.gd).
	register["correction"] = String(register.get("correction", ""))
	register["correction_kind"] = String(register.get("correction_kind", ""))
	var flagged: Array = register.get("flagged", [])
	for i in flagged.size():
		flagged[i] = int(flagged[i])
	register["flagged"] = flagged
	c["register"] = register
	var hand: Array = c.get("hand", [])
	for held in hand:
		(held as Dictionary)["uid"] = int((held as Dictionary).get("uid", 0))
	c["hand"] = hand

## `last_verdict` mixes whole counts with two real numbers (docs/08 §3.4), so it cannot go through
## `_normalise_data`'s "every integral float is an int" rule — that would turn `accuracy 1.0` into
## `1` and the round-trip would stop being byte-stable. Each field is re-typed by name instead.
const VERDICT_BUCKETS := ["missing", "extra", "wrong_brand", "wrong_count", "refused"]
const VERDICT_COUNTS := ["line", "qty", "want", "got"]

static func _normalise_verdict(verdict: Dictionary) -> Dictionary:
	if verdict.is_empty():
		return {}
	verdict["ok"] = bool(verdict.get("ok", false))
	verdict["accuracy"] = float(verdict.get("accuracy", 0.0))
	verdict["errors"] = float(verdict.get("errors", 0.0))
	verdict["wanted_units"] = int(verdict.get("wanted_units", 0))
	for bucket in VERDICT_BUCKETS:
		for entry in (verdict.get(bucket, []) as Array):
			for key in VERDICT_COUNTS:
				if (entry as Dictionary).has(key):
					(entry as Dictionary)[key] = int((entry as Dictionary)[key])
	return verdict

## Act/season label from the calendar (Summer → Autumn → Winter thirds).
static func act_of(s: Dictionary) -> String:
	var f := float(s["day"]) / float(s["config"]["season_days"])
	if f <= 1.0 / 3.0:
		return "summer"
	return "autumn" if f <= 2.0 / 3.0 else "winter"
