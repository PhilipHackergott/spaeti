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
	# The season's end — the finale card (Finale.resolve_finale).
	"ending",
	# The ring-up (docs/08-register-and-tobacco.md section 3.3): the basket on the counter, the wall
	# behind you, and the wrong pack already flagged before you press Ring up.
	"register_counter", "register_wall", "register_error",
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
		"ending":
			# The season is over: `legal_actions` is empty and `view.ending` is the whole screen. Two
			# epilogues so the tapestry's list branch is exercised by every capture and test.
			v["phase"] = "end"
			_set_clock(v, "04:00", 1.0)
			v["cash"] = 212.4
			v["ending"] = {
				"main": "held",
				"title": "Held the Line",
				"line": "Scarred and a little broke, but the doors are open and the Kiez is intact. You stayed.",
				"epilogues": [
					{"character": "lena", "line": "She still comes in on Sundays. The sketch of your corner is taped behind the till."},
					{"character": "juergen", "line": "Jürgen keeps the crate by the door, and nobody moves it."},
				],
			}
		"register_counter":
			# 22:41. Nadia's basket has landed on the laminate: the crate in slot 0, the Mate already
			# scanned, two Adler and a booklet fetched off the wall and still waiting for the glass.
			_set_clock(v, "22:41", 0.34)
			v["active"] = _nadia("neutral", 0.68)
			v["counter"] = _counter(false)
			v["register"] = _register(false)
			v["order"] = _order(false)
		"register_wall":
			# Turned around. The night keeps ticking, the card rides along and so does the money.
			_set_clock(v, "22:42", 0.35)
			v["active"] = _nadia("neutral", 0.61)
			v["counter"] = _counter(false)
			v["register"] = _register(false)
			v["order"] = _order(false)
			v["view_mode"] = "wall"
			v["wall"] = _wall()
		"register_error":
			# The navy pack against her red chip: the line is flagged, the first ring-up was refused,
			# and she is wary. The register is still open — that is the one free correction.
			_set_clock(v, "22:43", 0.36)
			v["active"] = _nadia("wary", 0.47)
			v["counter"] = _counter(true)
			v["register"] = _register(true)
			v["order"] = _order(true)
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
		# The year (docs/05 §11). Day 3 of the default 28-day season is the third day of summer —
		# derived from the engine's own calendar so a capture can never quote a season the reducer
		# would not agree with.
		"season": Season.of_day(3, SpatiState.DEFAULT_CONFIG["season_days"]),
		"day_in_season": Season.day_in_season(3, SpatiState.DEFAULT_CONFIG["season_days"]),
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
		# The ring-up (docs/08 section 3.3). Empty on every pre-register preset on purpose: those are
		# the serve screen's reference shots, and a tray drawn into them would change nine captures.
		# `view_mode` is TOP LEVEL because which way your body is facing must survive a customer
		# leaving while you are at the wall.
		"counter": [],
		"register": {},
		"order": [],
		"view_mode": "counter",
		"wall": {},
		# `status` is the standing roll-up (Economy.corner_status). Empty on purpose: the manage capture
		# is a fresh corner, so the "your corner" panel stands down and the shot is unchanged.
		"manage": {"restock_options": _restock(), "modules": _modules(),
			"status": {"kiez_per_night": 0.0, "traffic_mult": 1.0, "systems": [], "flags": [],
				"illegal": false, "has_security": false, "heat": 0.0},
			"open_sunday": false},
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

## The shape Economy.module_options hands the board: the module's own words under `def`.
static func _modules() -> Array:
	return [
		{"def": {"id": "fridge_2", "name": "Second fridge", "cost": 120.0, "note": "+6 cold slots, fewer warm-beer balks"}, "owned": false, "available": true, "affordable": false, "reason": ""},
		{"def": {"id": "coffee_pot", "name": "Filter coffee pot", "cost": 80.0, "note": "Unlocks Kaffee after midnight"}, "owned": true, "available": false, "affordable": true, "reason": ""},
		{"def": {"id": "awning", "name": "Awning + bench", "cost": 150.0, "note": "Patience +15% when it rains"}, "owned": false, "available": true, "affordable": false, "reason": ""},
		# A LOCKED one, so the capture presets actually render the row type the board grew in 2026-09-13.
		# The wording mirrors `Economy.unlock_reason`: the mock may only say what the engine could.
		{"def": {"id": "mate_tap", "name": "Mate on tap", "cost": 280.0, "note": "Pulls the late crowd"}, "owned": false, "available": false, "affordable": false, "reason": "unlocks on day 10"},
	]


# --- the ring-up (docs/08-register-and-tobacco.md section 3.3) -------------------------------

## Nadia Ferreira, the night-shift nurse of docs/08 section 1 and docs/09 section 2.7: three empties,
## a Mate, and the one tobacco line she does NOT take.
static func _nadia(expression: String, patience: float) -> Dictionary:
	return {
		"customer": {"id": 31, "archetype_id": "nurse", "want": "mate", "character_id": "nadia"},
		"archetype": {"id": "nurse", "name": "Nachtschwester"},
		"want": {"sku_id": "mate", "name": "Mate", "price": 1.8, "stock": 18, "icon": "sku/mate"},
		"portrait": "char/nadia",
		"expression": expression,
		"patience": patience,
		"is_story": false,
		"bottles": 3,
	}

## One `view.counter` row. The brand's identity is READ OUT OF THE CATALOGUE, never re-typed here: a
## mock that invents a mark or a colour teaches a lie in every capture and in every test.
static func _item(uid: int, sku_id: String, brand_id: String, slot: int, scanned: bool,
		origin: String = "customer") -> Dictionary:
	var b := Content.brand(brand_id)
	var s := Content.sku(sku_id)
	return {
		"uid": uid,
		"sku_id": sku_id,
		"name": String(b.get("name", s.get("name", sku_id))),
		"brand": brand_id,
		"mark": String(b.get("mark", "")),
		"colour": String(b.get("colour", "")),
		"icon": String(b.get("icon", s.get("icon", ""))),
		"kind": "item",
		"count": 1,
		"scanned": scanned,
		# Where it came from: she put it down, or you walked to the wall for it (docs/08 §3.3).
		"origin": origin,
		"slot": slot,
	}

## The crate: ONE sprite with a count badge in slot 0, not three loose bottles, which would eat the
## tray (docs/08 section 3.5). It is a deposit, so it carries no sku and never reaches the scanner.
static func _crate(uid: int, bottles: int) -> Dictionary:
	return {
		# `name` is "" exactly as the reducer emits it for the crate — the deposit is one of the few
		# things on screen the STRING TABLE names, not the catalogue (rules.gd's counter view).
		"uid": uid, "sku_id": "pfand", "name": "", "brand": "", "mark": "", "colour": "",
		"icon": "prop/pfand_crate", "kind": "crate", "count": bottles, "scanned": false,
		"origin": "customer", "slot": 0,
	}

## What is standing on the laminate. `wrong` is the Nordstern case: you reached for the navy pack.
static func _counter(wrong: bool) -> Array:
	return [
		_crate(1, 3),
		_item(2, "mate", "", 1, true),
		_item(3, "cigarettes", "nordstern" if wrong else "adler", 2, wrong, "wall"),
		_item(4, "cigarettes", "adler", 3, false, "wall"),
		_item(5, "papers", "pap_feder_lang", 4, false, "wall"),
	]

## `view.register`. `matches` is the REDUCER's verdict — the mock states it, it never derives it.
static func _register(wrong: bool) -> Dictionary:
	var lines: Array = [
		{"sku_id": "mate", "name": "Mate", "brand": "", "mark": "", "colour": "",
			"qty": 1, "unit_price": 1.8, "line_total": 1.8, "restricted": false, "matches": true},
	]
	if wrong:
		var n := Content.brand("nordstern")
		lines.append({"sku_id": "cigarettes", "name": String(n.get("name", "")), "brand": "nordstern",
			"mark": String(n.get("mark", "")), "colour": String(n.get("colour", "")),
			"qty": 1, "unit_price": 8.5, "line_total": 8.5, "restricted": true, "matches": false})
	var subtotal := 0.0
	for line in lines:
		subtotal += float((line as Dictionary)["line_total"])
	var pfand_line := 3.0 * Rules.PFAND_PER_BOTTLE
	return {
		"lines": lines,
		"pfand_bottles": 3,
		"pfand_line": pfand_line,
		"subtotal": subtotal,
		"total": subtotal - pfand_line,
		"can_ring": true,
		"id_checked": false,
		# One free correction per customer, spoken in character (docs/08 section 3.4). The reducer
		# writes the sentence; the panel only frames it.
		"correction": String(Rules.CORRECTION_LINES["wrong_brand"]) if wrong else "",
		"corrections": 1 if wrong else 0,
		# The bucket behind the sentence; the box takes its words from `Strings.CORRECTION_BY_KIND`.
		"correction_kind": "wrong_brand" if wrong else "",
		"flagged": [1] if wrong else [],
	}

## `view.order` — her words, one chip per basket line. In `mark` mode the chip prints the swatch and
## the CATEGORY and never the brand name; the Mate and the Pfand are named because they are not a
## puzzle. `satisfied` is the reducer's, like `matches`.
## `view.order` — EXACTLY the row `Rules._order_view` emits (docs/08 §3.3), key for key, including the
## ones a component would otherwise have to re-derive. `name` is the SKU's name and `brand_name` is
## the BRAND's, withheld as "" unless the engine says she used it: the chip may not decide how much a
## customer gave away. `said` is composed the way the reducer composes it (`Rules._said_for`), so a
## capture reads the sentence the game would actually print. Nadia is a nurse — the `mark` tier.
static func _order(wrong: bool) -> Array:
	var adler := Content.brand("adler")
	var feder := Content.brand("pap_feder_lang")
	return [
		{"sku_id": "mate", "said": "1x Mate.", "qty": 1, "name": "Mate", "category": "drinks",
			"brand": "", "brand_name": "", "mark": "", "colour": "", "icon": "sku/mate",
			"name_shown": false, "satisfied": true},
		{"sku_id": "cigarettes", "said": "2x the ones with the eagle — cigarettes.", "qty": 2,
			"name": String(Content.sku("cigarettes").get("name", "")), "category": "tobacco",
			"brand": "adler", "brand_name": "", "mark": String(adler.get("mark", "")),
			"colour": String(adler.get("colour", "")), "icon": String(adler.get("icon", "")),
			"name_shown": false, "satisfied": false},
		{"sku_id": "papers", "said": "1x the cream booklet.", "qty": 1,
			"name": String(Content.sku("papers").get("name", "")), "category": "tobacco",
			"brand": "pap_feder_lang", "brand_name": "", "mark": String(feder.get("mark", "")),
			"colour": String(feder.get("colour", "")), "icon": String(feder.get("icon", "")),
			"name_shown": false, "satisfied": false},
		{"sku_id": "pfand", "said": "3x Pfand.", "qty": 3, "name": "", "category": "pfand",
			"brand": "", "brand_name": "", "mark": "", "colour": "", "icon": "prop/pfand_crate",
			"name_shown": false, "satisfied": not wrong},
	]

## `view.wall`: three shelves, a price rail each, and what you are already carrying. The facings come
## straight out of `Content.BRANDS`, in registry order, so the wall never reshuffles between captures
## and a brand added to the catalogue is on the wall the same day.
static func _wall() -> Dictionary:
	return {
		"shelves": [_wall_shelf("cigarettes", 0), _wall_shelf("tobacco", 1), _wall_shelf_bottom()],
		"hand": [{"uid": 8, "sku_id": "cigarettes", "brand": "adler"}],
	}

static func _wall_shelf(sku_id: String, row: int) -> Dictionary:
	var s := Content.sku(sku_id)
	var cells: Array = []
	for b in Content.brands_for(sku_id):
		cells.append(_wall_cell(b, row, cells.size(), _mock_stock(String((b as Dictionary).get("id", "")))))
	return {"label": String(s.get("name", sku_id)), "price": float(s.get("base_price", 0.0)), "cells": cells}

## The bottom shelf carries papers AND filters on one rail — ten facings, one price. The rail quotes
## the papers, which is the deviation docs/08 section 4.3's "one price per rail" costs when two SKUs
## share a shelf; a second rail is the fix if the judge reads it as wrong.
static func _wall_shelf_bottom() -> Dictionary:
	var s := Content.sku("papers")
	var cells: Array = []
	for sku_id in ["papers", "filters"]:
		for b in Content.brands_for(String(sku_id)):
			cells.append(_wall_cell(b, 2, cells.size(), _mock_stock(String((b as Dictionary).get("id", "")))))
	return {"label": String(s.get("name", "papers")), "price": float(s.get("base_price", 0.0)), "cells": cells}

## One facing, in exactly the keys docs/08 section 3.3 documents — `BrandMark.merge` is what fills in
## the facing's icon, band and footprint, which is the path the real read-model will take too.
static func _wall_cell(brand_row: Dictionary, row: int, col: int, stock: int) -> Dictionary:
	return {
		"sku_id": String(brand_row.get("sku", "")),
		"brand": String(brand_row.get("id", "")),
		"name": String(brand_row.get("name", "")),
		"mark": String(brand_row.get("mark", "")),
		"colour": String(brand_row.get("colour", "")),
		# The facing's own asset id, so `BrandMark` never has to go back to the catalogue for it.
		"icon": String(brand_row.get("icon", "")),
		"stock": stock,
		"row": row,
		"col": col,
	}

## Deterministic stock for the capture: Bergmann is out and Luxor is down to its last row (which is a
## Schulz story beat waiting to happen, docs/09 section 2.4), so both greyed states are on screen.
static func _mock_stock(brand_id: String) -> int:
	match brand_id:
		"bergmann":
			return 0
		"luxor":
			return 1
	return 6
