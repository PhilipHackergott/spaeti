class_name StoryFlow
extends RefCounted
## Story delivery — ported from app/src/engine/storyflow.ts with THE ONE DESIGN CHANGE of
## docs/05-engine-api.md §4: a beat no longer appears as morning text. It walks in.
##
## open_night → schedule_beats() injects an arrival for the character whose beat is due (≤ 2 story
## arrivals a night, main arc first, ≤ 1 beat per strand per day). When that customer becomes active,
## on_customer_active() makes the beat pending; while pending the UI may only resolve it; resolving
## applies the choice and leaves the customer standing there, so the ordinary serve still follows.
## All mutations here are in-place on an already-cloned state (Rules.apply owns the cloning).

const MASK: int = 0xFFFFFFFF
## % of quiet (no cast beat) nights that surface a one-off vignette.
const VIGNETTE_CHANCE: int = 60
## Cap on story arrivals per night — the loop stays a shop, not a visual novel.
const MAX_STORY_ARRIVALS: int = 2

## Deterministic 32-bit hash: vignette selection is keyed on seed+day only, so it never disturbs the
## rng stream that places customers (the prototype's trick — keep it).
static func _hash2(a: int, b: int) -> int:
	var h := (a ^ 0x9e3779b9) & MASK
	h = Rng.imul(h ^ ((b + 0x6d2b79f5) & MASK), 2654435761) & MASK
	h ^= h >> 15
	return h & MASK

## The strand beats that may fire tonight, highest priority first (main arc = 100).
static func eligible_beats(s: Dictionary) -> Array:
	var story: Dictionary = s["story"]
	var out: Array = []
	for strand in Content.STRANDS:
		var progress: Dictionary = story["strands"].get(strand["id"], {})
		if progress.is_empty():
			continue
		var cur: String = progress["cur"]
		if cur == "" or int(progress["last_day"]) == int(s["day"]):
			continue
		var beat: Dictionary = (strand["beats"] as Dictionary).get(cur, {})
		if beat.is_empty():
			continue
		if int(s["day"]) < int(beat.get("after_day", 0)):
			continue
		if float(s["reputation"]["kiez"]) < float(beat.get("min_kiez", 0.0)):
			continue
		var flag: String = beat.get("requires_flag", "")
		if flag != "" and not (story["flags"] as Array).has(flag):
			continue
		out.append({"strand": strand, "beat": beat})
	out.sort_custom(func(a, b): return int(a["strand"].get("priority", 0)) > int(b["strand"].get("priority", 0)))
	return out

## Called by open_night AFTER the ordinary arrivals are built: injects tonight's cast arrivals, or —
## on a quiet night — pins one unseen vignette onto an ordinary customer. Keeps `arrivals` time-sorted.
static func schedule_beats(s: Dictionary, rng: Rng) -> void:
	var arrivals: Array = s["arrivals"]
	var available: Array = (s["inventory"] as Dictionary).keys()
	var scheduled := 0
	for entry in eligible_beats(s):
		if scheduled >= MAX_STORY_ARRIVALS:
			break
		var strand: Dictionary = entry["strand"]
		var beat: Dictionary = entry["beat"]
		# A beat may be spoken by someone other than the strand's owner (Mehmet brings the news
		# about Frau Schmidt) — the beat's own ids win.
		var character_id: String = beat.get("character_id", strand.get("character_id", ""))
		var archetype_id: String = beat.get("archetype_id", strand.get("archetype_id", "regular"))
		var character := Content.character(character_id)
		if not character.is_empty():
			archetype_id = beat.get("archetype_id", character.get("archetype_id", archetype_id))
		var arch := Content.archetype(archetype_id)
		if arch.is_empty():
			continue
		var wants: Dictionary = character.get("wants", arch["wants"]) if not character.is_empty() else arch["wants"]
		arrivals.append({
			"time_ms": _arrival_time(rng, arch, int(s["config"]["night_len_ms"])),
			"archetype_id": archetype_id,
			"want": _pick_want(rng, wants, arch["wants"], available),
			"character_id": character_id,
			"beat_id": beat["id"],
			"vignette_id": "",
		})
		scheduled += 1
	if scheduled == 0:
		_schedule_vignette(s, rng)
	arrivals.sort_custom(func(a, b): return int(a["time_ms"]) < int(b["time_ms"]))

## A time on this archetype's own curve (the raver shows up late, the tourist early).
static func _arrival_time(rng: Rng, arch: Dictionary, night_len_ms: int) -> int:
	var third := rng.weighted_index(arch["curve"])
	var len_f := float(night_len_ms)
	return int(rng.range(float(third) / 3.0 * len_f, float(third + 1) / 3.0 * len_f))

## Weighted want from `wants`, restricted to what is actually on the shelf; falls back to the
## archetype's wants, then to anything at all (never an empty want — the serve needs a target).
static func _pick_want(rng: Rng, wants: Dictionary, fallback_wants: Dictionary, available: Array) -> String:
	var ids: Array = []
	var weights: Array = []
	for id in wants:
		if available.has(id):
			ids.append(id)
			weights.append(float(wants[id]))
	if ids.is_empty():
		for id in fallback_wants:
			if available.has(id):
				ids.append(id)
				weights.append(float(fallback_wants[id]))
	if ids.is_empty():
		return rng.pick(available) if not available.is_empty() else "water"
	return ids[rng.weighted_index(weights)]

## On a quiet night, pin a deterministically chosen unseen vignette onto a random ordinary arrival.
static func _schedule_vignette(s: Dictionary, rng: Rng) -> void:
	var story: Dictionary = s["story"]
	if not (story["pending"] as Dictionary).is_empty() or story["pending_vignette"] != "":
		return
	var arrivals: Array = s["arrivals"]
	if arrivals.is_empty():
		return
	if _hash2(int(s["config"]["seed"]), int(s["day"])) % 100 >= VIGNETTE_CHANCE:
		return
	var eligible: Array = []
	for v in Content.VIGNETTES:
		if (story["seen_vignettes"] as Array).has(v["id"]):
			continue
		if int(s["day"]) < int(v.get("after_day", 0)):
			continue
		if float(s["reputation"]["kiez"]) < float(v.get("min_kiez", 0.0)):
			continue
		var flag: String = v.get("requires_flag", "")
		if flag != "" and not (story["flags"] as Array).has(flag):
			continue
		if v.has("weekday") and int(s["weekday"]) != int(v["weekday"]):
			continue
		eligible.append(v)
	if eligible.is_empty():
		return
	var pick: Dictionary = eligible[_hash2(int(s["config"]["seed"]) ^ 0x85ebca6b, int(s["day"])) % eligible.size()]
	arrivals[rng.randi_below(arrivals.size())]["vignette_id"] = pick["id"]

## Called from tick the moment a customer reaches the counter: their beat (or vignette) becomes pending.
static func on_customer_active(s: Dictionary) -> void:
	var active: Dictionary = s["active"]
	if active.is_empty():
		return
	var story: Dictionary = s["story"]
	if not (story["pending"] as Dictionary).is_empty() or story["pending_vignette"] != "":
		return
	var beat_id: String = active.get("beat_id", "")
	if beat_id != "":
		var strand_id: String = Content.BEAT_STRAND.get(beat_id, "")
		var progress: Dictionary = story["strands"].get(strand_id, {})
		# The strand may have moved on since this arrival was scheduled — then they are just a customer.
		if not progress.is_empty() and progress["cur"] == beat_id:
			story["pending"] = {"strand": strand_id, "beat": beat_id}
			return
		active["beat_id"] = ""
	var vignette_id: String = active.get("vignette_id", "")
	if vignette_id != "" and not (story["seen_vignettes"] as Array).has(vignette_id):
		story["pending_vignette"] = vignette_id

## The dialogue the UI should be showing right now (engine-api §5 `view().dialogue`), or {}.
static func current_dialogue(s: Dictionary) -> Dictionary:
	var story: Dictionary = s["story"]
	var active: Dictionary = s["active"]
	var character_id: String = active.get("character_id", "")
	var archetype_id: String = active.get("archetype_id", "")
	var expression: String = active.get("expression", "neutral")
	var pending: Dictionary = story["pending"]
	if not pending.is_empty():
		var beat := Content.beat(pending["strand"], pending["beat"])
		if beat.is_empty():
			return {}
		return {
			"speaker": beat["speaker"],
			"portrait": Content.portrait_for(character_id, archetype_id),
			"expression": expression,
			"lines": beat["lines"],
			"choices": _choice_labels(beat["choices"]),
			"kind": "beat",
		}
	if story["pending_vignette"] != "":
		var v := Content.vignette(story["pending_vignette"])
		if v.is_empty():
			return {}
		return {
			"speaker": v["speaker"],
			"portrait": Content.portrait_for(character_id, archetype_id),
			"expression": expression,
			"lines": v["lines"],
			"choices": _choice_labels(v["choices"]),
			"kind": "vignette",
		}
	return {}

static func _choice_labels(choices: Array) -> Array:
	var out: Array = []
	for c in choices:
		out.append({"label": c["label"]})
	return out

## Apply the chosen option of the pending beat, then hand the customer back to the serve loop.
static func apply_beat_choice(s: Dictionary, choice_index: int) -> void:
	var story: Dictionary = s["story"]
	var pending: Dictionary = story["pending"]
	if pending.is_empty():
		return
	var strand_id: String = pending["strand"]
	var strand := Content.strand(strand_id)
	var progress: Dictionary = story["strands"].get(strand_id, {})
	if strand.is_empty() or progress.is_empty() or progress["cur"] == "":
		story["pending"] = {}
		return
	var beat := Content.beat(strand_id, progress["cur"])
	if beat.is_empty():
		story["pending"] = {}
		return
	var choices: Array = beat["choices"]
	var choice: Dictionary = choices[choice_index] if choice_index >= 0 and choice_index < choices.size() else choices[0]
	_apply_effects(s, choice)
	if choice.get("outcome", "") != "":
		progress["outcome"] = choice["outcome"]
		if strand_id == "main":
			story["main_outcome"] = choice["outcome"]
	# `met` holds the strand's display name — Finale composes the tapestry from exactly these.
	if not (story["met"] as Array).has(strand["character"]):
		(story["met"] as Array).append(strand["character"])
	progress["last_day"] = int(s["day"])
	progress["cur"] = choice.get("next", "")
	story["pending"] = {}
	_set_expression(s, choice)

## Apply the chosen option of the pending one-off vignette (never repeats: it joins seen_vignettes).
static func apply_vignette_choice(s: Dictionary, choice_index: int) -> void:
	var story: Dictionary = s["story"]
	var id: String = story["pending_vignette"]
	if id == "":
		return
	var v := Content.vignette(id)
	if not v.is_empty():
		var choices: Array = v["choices"]
		var choice: Dictionary = choices[choice_index] if choice_index >= 0 and choice_index < choices.size() else choices[0]
		_apply_effects(s, choice)
		_set_expression(s, choice)
	if not (story["seen_vignettes"] as Array).has(id):
		(story["seen_vignettes"] as Array).append(id)
	story["pending_vignette"] = ""

static func _apply_effects(s: Dictionary, choice: Dictionary) -> void:
	var cash := float(choice.get("cash", 0.0))
	if cash != 0.0:
		s["cash"] = Economy.round2(float(s["cash"]) + cash)
	var rep: Dictionary = s["reputation"]
	var kiez := float(choice.get("kiez", 0.0))
	if kiez != 0.0:
		rep["kiez"] = Economy.clamp_meter(float(rep["kiez"]) + kiez)
	var profit := float(choice.get("profit", 0.0))
	if profit != 0.0:
		rep["profit"] = Economy.clamp_meter(float(rep["profit"]) + profit)
	var integrity := float(choice.get("integrity", 0.0))
	if integrity != 0.0:
		rep["integrity"] = Economy.clamp_meter(float(rep["integrity"]) + integrity)
	for f in choice.get("flags", []):
		if not (s["story"]["flags"] as Array).has(f):
			(s["story"]["flags"] as Array).append(f)

## How the person at the counter looks after what you just said (engine-api §4).
static func _set_expression(s: Dictionary, choice: Dictionary) -> void:
	var active: Dictionary = s["active"]
	if active.is_empty():
		return
	var kiez := float(choice.get("kiez", 0.0))
	var integrity := float(choice.get("integrity", 0.0))
	if kiez < 0.0:
		active["expression"] = "upset"
	elif integrity >= 0.0:
		active["expression"] = "warm"
	else:
		active["expression"] = "neutral"
