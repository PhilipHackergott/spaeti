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
			v["queue_len"] = 0
		"customer_at_counter":
			_set_clock(v, "22:40", 0.33)
			v["active"] = _lena("neutral", 0.72)
			v["queue_len"] = 2
		"dialogue_choice":
			_set_clock(v, "22:41", 0.34)
			v["active"] = _lena("neutral", 0.66)
			v["active"]["is_story"] = true
			v["queue_len"] = 2
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
			v["queue_len"] = 3
		"pfand":
			_set_clock(v, "00:20", 0.54)
			v["active"] = _juergen(0.83)
			v["pfand_held"] = 34
			v["queue_len"] = 1
		"late_night":
			_set_clock(v, "02:30", 0.81)
			v["cash"] = 143.7
			v["pfand_held"] = 41
			v["queue_len"] = 0
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
		_:
			pass
	return v

# --- pieces --------------------------------------------------------------------------------

static func _base() -> Dictionary:
	return {
		"phase": "night",
		"day": 3,
		"weekday_name": "Donnerstag",
		"clock_ms": 9600000,
		"night_progress": 0.33,
		"time_label": "22:40",
		"cash": 84.5,
		"pfand_held": 12,
		"reputation": {"kiez": 62.0, "profit": 48.0, "integrity": 71.0},
		"hud": {"kiez_label": "Kiez 62", "profit_label": "Profit 48"},
		"active": {},
		"queue_len": 0,
		"dialogue": {},
		"shelf": _shelf(),
		"summary": {},
		"manage": {"restock_options": _restock(), "modules": _modules()},
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
	}

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
		{"sku_id": "beer", "name": "Sterni", "cost": 0.55, "stock": 24, "price": 1.2, "fair_lo": 1.0, "fair_hi": 1.5},
		{"sku_id": "mate", "name": "Mate", "cost": 0.9, "stock": 18, "price": 1.8, "fair_lo": 1.5, "fair_hi": 2.1},
		{"sku_id": "cola", "name": "Cola", "cost": 0.7, "stock": 12, "price": 1.7, "fair_lo": 1.2, "fair_hi": 1.6},
		{"sku_id": "water", "name": "Wasser", "cost": 0.35, "stock": 20, "price": 1.0, "fair_lo": 0.8, "fair_hi": 1.2},
		{"sku_id": "coffee", "name": "Kaffee", "cost": 0.6, "stock": 8, "price": 1.5, "fair_lo": 1.3, "fair_hi": 1.8},
		{"sku_id": "chips", "name": "Chips", "cost": 0.95, "stock": 9, "price": 1.9, "fair_lo": 1.6, "fair_hi": 2.2},
		{"sku_id": "chocolate", "name": "Schoki", "cost": 0.6, "stock": 14, "price": 1.1, "fair_lo": 1.2, "fair_hi": 1.6},
		{"sku_id": "cigarettes", "name": "Kippen", "cost": 6.4, "stock": 6, "price": 8.5, "fair_lo": 7.0, "fair_hi": 8.0},
	]

static func _modules() -> Array:
	return [
		{"id": "fridge_2", "name": "Second fridge", "cost": 120.0, "desc": "+6 cold slots, fewer warm-beer balks", "owned": false},
		{"id": "coffee_pot", "name": "Filter coffee pot", "cost": 80.0, "desc": "Unlocks Kaffee after midnight", "owned": true},
		{"id": "awning", "name": "Awning + bench", "cost": 150.0, "desc": "Patience +15% when it rains", "owned": false},
	]
