class_name MockView
extends RefCounted
## Deterministic read-models shaped EXACTLY like `Rules.view(state)` (docs/05-engine-api.md section 5),
## one per capture preset in docs/02-art-pipeline.md. They let the component pool and every screen run,
## be captured and be judged before the engine lane lands — and they are what `apply_capture_preset`
## feeds a scene, so a screenshot is the same moment every time.
##
## This file is MOCK DATA ONLY. It contains no rules: when Session exists, scenes render its view instead.

const PRESETS := [
	"title", "empty_counter", "customer_at_counter", "dialogue_choice",
	"serving", "pfand", "late_night", "manage", "summary",
	# The register screen (docs/06-dialogue-and-stats.md section 5): the line, the conversation, the roll.
	"queue_waiting", "talk_lines", "talk_choice", "talk_result",
]

static func presets() -> Array:
	return PRESETS.duplicate()

static func view(preset: String) -> Dictionary:
	var v := _base()
	match preset:
		"title":
			v["phase"] = "title"
		"empty_counter":
			_set_clock(v, "20:15", 0.04)
		"customer_at_counter":
			_set_clock(v, "22:40", 0.33)
			v["active"] = _lena("neutral", 0.72)
		"dialogue_choice":
			_set_clock(v, "22:41", 0.34)
			v["active"] = _lena("neutral", 0.66)
			v["active"]["is_story"] = true
			v["dialogue"] = {
				"speaker": "Lena",
				"portrait": "char/lena",
				"expression": "neutral",
				"lines": [
					"They put the rent up again. Third time since I moved in.",
					"I keep telling myself the Kiez is still the Kiez. Is it?",
				],
				"choices": [
					{"label": "It is. We are still here, aren't we?"},
					{"label": "Nothing stays. Take the Mate, it's on me."},
				],
				"kind": "beat",
			}
		"serving":
			_set_clock(v, "23:05", 0.39)
			v["active"] = _clubber(0.51)
		"pfand":
			_set_clock(v, "00:20", 0.54)
			v["active"] = _juergen(0.83)
			v["pfand_held"] = 34
		"late_night":
			_set_clock(v, "02:30", 0.81)
			v["cash"] = 143.7
			v["pfand_held"] = 41
		"manage":
			v["phase"] = "manage"
			_set_clock(v, "19:45", 0.0)
			v["cash"] = 96.4
		"summary":
			v["phase"] = "summary"
			_set_clock(v, "04:00", 1.0)
			v["cash"] = 134.7
			v["summary"] = {
				"day": 3,
				"revenue": 142.8,
				"cogs": 61.2,
				"tips": 8.4,
				"bills_due": 35.0,
				"pfand_paid": 4.8,
				"profit": 50.2,
				"cash_after": 134.7,
				"sales": 23,
				"lost": 3,
				"kiez_delta": 2.0,
			}
		"queue_waiting":
			# Three guests in the line and nobody at the counter: the "Next guest" state, and the one
			# preset where the six stats are on screen without being asked for (docs/06 section 5).
			_set_clock(v, "21:10", 0.18)
			v["queue"] = [_waiting(21, "lena"), _waiting(22, "juergen"), _waiting(23, "mehmet")]
		"talk_lines":
			# Lena is talking and has not reached her choices yet: lines only, the queue still waiting.
			_set_clock(v, "21:24", 0.22)
			v["active"] = _lena("neutral", 0.78)
			v["active"]["is_story"] = true
			v["queue"] = [_waiting(22, "juergen"), _waiting(24, "")]
			v["talk"] = _lena_talk(1, [], {})
		"talk_choice":
			# The decision: a plain line, a Charisma 12 ROLL, and a Strength 12 GATE she cannot pass.
			_set_clock(v, "21:25", 0.23)
			v["active"] = _lena("neutral", 0.74)
			v["active"]["is_story"] = true
			v["queue"] = [_waiting(22, "juergen"), _waiting(24, "")]
			v["talk"] = _lena_talk(2, _lena_choices(), {})
		"talk_result":
			# The roll landed: 14 + 2 = 16 against DC 12. Lena warms up and the pop says why.
			_set_clock(v, "21:26", 0.24)
			v["active"] = _lena("warm", 0.74)
			v["active"]["is_story"] = true
			v["queue"] = [_waiting(22, "juergen"), _waiting(24, "")]
			var talk := _lena_talk(0, [], {"stat": "cha", "roll": 14, "mod": 2, "dc": 12, "success": true})
			talk["expression"] = "warm"
			talk["lines"] = ["Ha. Fine — one sketch, one Mate. Don't tell Jürgen."]
			v["talk"] = talk
		_:
			pass
	# ONE source, exactly as the engine builds it (rules.gd: both fields come off `s["queue"]`), so a
	# capture can never print "2 waiting" over a frame with nobody in the line. The old serve-screen
	# presets keep an EMPTY line on purpose (see _base) and therefore read 0 waiting.
	v["queue_len"] = (v["queue"] as Array).size()
	return v

# --- pieces --------------------------------------------------------------------------------

static func _base() -> Dictionary:
	return {
		"phase": "night",
		"day": 3,
		"weekday_name": "Mittwoch",  # day 3 = Rules.WEEKDAY_NAMES[2]; day 1 is a Montag
		"clock_ms": 9600000,
		"night_progress": 0.33,
		"time_label": "22:40",
		"cash": 84.5,
		"pfand_held": 12,
		# The engine constant, not a copy of it: a mock that quotes a stale deposit lies in every capture.
		"pfand_rate": Rules.PFAND_PER_BOTTLE,
		"reputation": {"kiez": 62.0, "profit": 48.0, "integrity": 71.0},
		# Verbatim the strings Rules.view() formats ("Kiez-Trust %d" / "Profit %d") — a mock that
		# prints shorter text than the engine hides the overflow the real HUD would show.
		"hud": {"kiez_label": "Kiez-Trust 62", "profit_label": "Profit 48"},
		"active": {},
		"queue_len": 0,
		# docs/06 section 4. Empty on the old presets on purpose: they are the SERVE screen's captures
		# and predate the register, so adding a line to them would silently change nine reference shots
		# — and since `view()` derives `queue_len` from this, those presets read "0 waiting" too.
		"queue": [],
		"talk": {},
		"player": _player(),
		"dialogue": {},
		"shelf": _shelf(),
		"summary": {},
		# `status` is the standing roll-up (Economy.corner_status). Empty on purpose: the manage capture
		# is a fresh corner, so the "your corner" panel stands down and the shot is unchanged.
		"manage": {"restock_options": _restock(), "modules": _modules(),
			"status": {"kiez_per_night": 0.0, "traffic_mult": 1.0, "systems": [], "flags": [],
				"illegal": false, "has_security": false, "heat": 0.0}},
		"ending": {},
	}

static func _set_clock(v: Dictionary, label: String, progress: float) -> void:
	v["time_label"] = label
	v["night_progress"] = progress
	v["clock_ms"] = int(progress * 28800000.0)

static func _lena(expression: String, patience: float) -> Dictionary:
	return {
		"customer": {"id": 7, "archetype_id": "student", "want": "mate", "character_id": "lena"},
		"archetype": {"id": "student", "name": "Studentin"},
		"want": {"sku_id": "mate", "name": "Mate", "price": 1.8, "stock": 18, "icon": "sku/mate"},
		"portrait": "char/lena",
		"expression": expression,
		"patience": patience,
		"is_story": false,
		# Empties THEY brought in — `view.active.bottles`, never the shop's `pfand_held` crate.
		"bottles": 0,   # a student carries no crate
	}

static func _juergen(patience: float) -> Dictionary:
	return {
		"customer": {"id": 11, "archetype_id": "pfand_sammler", "want": "beer", "character_id": "juergen"},
		"archetype": {"id": "pfand_sammler", "name": "Pfandsammler"},
		"want": {"sku_id": "beer", "name": "Sterni", "price": 1.2, "stock": 24, "icon": "sku/beer"},
		"portrait": "char/juergen",
		"expression": "neutral",
		"patience": patience,
		"is_story": false,
		# Empties THEY brought in — `view.active.bottles`, never the shop's `pfand_held` crate.
		"bottles": 6,   # the Pfandsammler's whole evening, on the counter
	}

static func _clubber(patience: float) -> Dictionary:
	return {
		"customer": {"id": 14, "archetype_id": "clubber", "want": "beer", "character_id": ""},
		"archetype": {"id": "clubber", "name": "Clubber"},
		"want": {"sku_id": "beer", "name": "Sterni", "price": 1.2, "stock": 24, "icon": "sku/beer"},
		"portrait": "char/oneoff_clubber",
		"expression": "warm",
		"patience": patience,
		"is_story": false,
		# Empties THEY brought in — `view.active.bottles`, never the shop's `pfand_held` crate.
		"bottles": 2,   # two empties out of a coat pocket
	}

## docs/06 section 1: 8..18, the defaults SpatiState.new_game seeds, with the 5e modifier alongside.
static func _player() -> Dictionary:
	var stats := {"str": 10, "dex": 11, "con": 12, "int": 13, "wis": 12, "cha": 14}
	var mods := {}
	for id in stats:
		mods[id] = int(floorf((float(stats[id]) - 10.0) / 2.0))
	return {"stats": stats, "mods": mods}

## One row of `view.queue` (docs/06 section 4). An empty `character_id` is the nameless parade: the
## one-off keeps the archetype's portrait and is named for what they are, not who they are.
static func _waiting(id: int, character_id: String) -> Dictionary:
	match character_id:
		"lena":
			return {"customer_id": id, "character_id": "lena", "name": "Lena", "portrait": "char/lena", "expression": "neutral", "is_story": true}
		"juergen":
			return {"customer_id": id, "character_id": "juergen", "name": "'Bottle' Jürgen", "portrait": "char/juergen", "expression": "neutral", "is_story": true}
		"mehmet":
			return {"customer_id": id, "character_id": "mehmet", "name": "Mehmet", "portrait": "char/mehmet", "expression": "neutral", "is_story": true}
		_:
			return {"customer_id": id, "character_id": "", "name": "After-club raver", "portrait": "char/oneoff_clubber", "expression": "neutral", "is_story": false}

## Lena's node, at the line the preset wants. `line` is the engine's index into `lines` — the box shows
## one line at a time and `talk_advance` walks it, so a capture is never half a paragraph ahead.
static func _lena_talk(line: int, choices: Array, last_check: Dictionary) -> Dictionary:
	return {
		"speaker": "Lena",
		"portrait": "char/lena",
		"expression": "neutral",
		"lines": [
			"Mate, bitte.",
			"…I'm fifty cents short again. Third time this week, I know.",
			"You could just say no. People do.",
		],
		"line": line,
		"choices": choices,
		"last_check": last_check,
	}

## Three choices: one plain, one ROLL (shown with its stat tag), one GATE the player cannot pass.
## `reason` comes from the string table so the mock cannot say a word the UI could not produce.
static func _lena_choices() -> Array:
	return [
		{"label": "On the house.", "check": {}, "locked": false, "reason": ""},
		{"label": "[Charisma 12] Pay me in a sketch.", "check": {"stat": "cha", "dc": 12, "mod": 2, "chance": 0.55}, "locked": false, "reason": ""},
		# A GATE, not a roll: Talk.choice_views leaves check empty and writes the reason itself, so the
		# mock does the same - the box's "locked: " frame is what makes the sentence (docs/06 section 2).
		{"label": "[Strength 12] Shift the crate, we're square.", "check": {}, "locked": true, "reason": "%s %d needed" % [Rules.stat_name("str"), 12]},
	]

static func _shelf() -> Array:
	return [
		{"sku_id": "beer", "name": "Sterni", "price": 1.2, "stock": 24, "icon": "sku/beer", "restricted": false, "tier": "fair"},
		{"sku_id": "mate", "name": "Mate", "price": 1.8, "stock": 18, "icon": "sku/mate", "restricted": false, "tier": "fair"},
		{"sku_id": "cola", "name": "Cola", "price": 1.7, "stock": 12, "icon": "sku/cola", "restricted": false, "tier": "high"},
		{"sku_id": "water", "name": "Wasser", "price": 1.0, "stock": 20, "icon": "sku/water", "restricted": false, "tier": "fair"},
		{"sku_id": "coffee", "name": "Kaffee", "price": 1.5, "stock": 8, "icon": "sku/coffee", "restricted": false, "tier": "fair"},
		{"sku_id": "chips", "name": "Chips", "price": 1.9, "stock": 9, "icon": "sku/chips", "restricted": false, "tier": "fair"},
		{"sku_id": "chocolate", "name": "Schoki", "price": 1.1, "stock": 14, "icon": "sku/chocolate", "restricted": false, "tier": "steal"},
		{"sku_id": "gummi", "name": "Gummi", "price": 1.2, "stock": 11, "icon": "sku/gummi", "restricted": false, "tier": "fair"},
		{"sku_id": "cigarettes", "name": "Kippen", "price": 8.5, "stock": 6, "icon": "sku/cigarettes", "restricted": true, "tier": "gouge"},
		{"sku_id": "lighter", "name": "Feuer", "price": 1.0, "stock": 7, "icon": "sku/lighter", "restricted": false, "tier": "fair"},
	]

static func _restock() -> Array:
	return [
		{"sku_id": "beer", "name": "Sterni", "cost": 0.55, "stock": 24, "price": 1.2, "fair_lo": 1.0, "fair_hi": 1.5, "tier": "fair"},
		{"sku_id": "mate", "name": "Mate", "cost": 0.9, "stock": 18, "price": 1.8, "fair_lo": 1.5, "fair_hi": 2.1, "tier": "fair"},
		{"sku_id": "cola", "name": "Cola", "cost": 0.7, "stock": 12, "price": 1.7, "fair_lo": 1.2, "fair_hi": 1.6, "tier": "high"},
		{"sku_id": "water", "name": "Wasser", "cost": 0.35, "stock": 20, "price": 1.0, "fair_lo": 0.8, "fair_hi": 1.2, "tier": "fair"},
		{"sku_id": "coffee", "name": "Kaffee", "cost": 0.6, "stock": 8, "price": 1.5, "fair_lo": 1.3, "fair_hi": 1.8, "tier": "fair"},
		{"sku_id": "chips", "name": "Chips", "cost": 0.95, "stock": 9, "price": 1.9, "fair_lo": 1.6, "fair_hi": 2.2, "tier": "fair"},
		{"sku_id": "chocolate", "name": "Schoki", "cost": 0.6, "stock": 14, "price": 1.1, "fair_lo": 1.2, "fair_hi": 1.6, "tier": "steal"},
		{"sku_id": "cigarettes", "name": "Kippen", "cost": 6.4, "stock": 6, "price": 8.5, "fair_lo": 7.0, "fair_hi": 8.0, "tier": "high"},
	]

static func _modules() -> Array:
	return [
		{"id": "fridge_2", "name": "Second fridge", "cost": 120.0, "desc": "+6 cold slots, fewer warm-beer balks", "owned": false},
		{"id": "coffee_pot", "name": "Filter coffee pot", "cost": 80.0, "desc": "Unlocks Kaffee after midnight", "owned": true},
		{"id": "awning", "name": "Awning + bench", "cost": 150.0, "desc": "Patience +15% when it rains", "owned": false},
	]
