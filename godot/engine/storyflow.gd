class_name StoryFlow
extends RefCounted
## Story delivery — ported from app/src/engine/storyflow.ts with THE ONE DESIGN CHANGE of
## docs/05-engine-api.md §4: a beat no longer appears as morning text. It walks in.
##
## open_night → schedule_beats() injects an arrival for the character whose beat is due (ONE story
## arrival a night, main arc first, then the guest unseen longest, ≤ 1 beat per strand per day, and
## never the same face twice in one night). When that customer becomes active,
## on_customer_active() makes the beat pending; while pending the UI may only resolve it; resolving
## applies the choice and leaves the customer standing there, so the ordinary serve still follows.
## All mutations here are in-place on an already-cloned state (Rules.apply owns the cloning).

const MASK: int = 0xFFFFFFFF
## % of quiet (no cast beat) nights that surface a one-off vignette.
const VIGNETTE_CHANCE: int = 60
## Cap on story arrivals per night — ONE STORY GUEST AT A TIME (docs/06 §8). The loop stays a shop,
## not a visual novel: a night carries one cast encounter and the rest of the queue is the parade.
## It was 2 until the arcs landed; with seven steps per guest the pacing is the ROTATION in
## `_sorts_before`, not the number of beats crammed into one night.
const MAX_STORY_ARRIVALS: int = 1

## Deterministic 32-bit hash: vignette selection is keyed on seed+day only, so it never disturbs the
## rng stream that places customers (the prototype's trick — keep it).
static func _hash2(a: int, b: int) -> int:
	var h := (a ^ 0x9e3779b9) & MASK
	h = Rng.imul(h ^ ((b + 0x6d2b79f5) & MASK), 2654435761) & MASK
	h ^= h >> 15
	return h & MASK

## The strand beats that may fire tonight, in the order `schedule_beats` should spend the night's one
## slot on them. A STRAND'S CURRENT BEAT IS ITS CURRENT ARC STEP (docs/06 §8), so the gates are the
## four it always had — `after_day`, `min_kiez`, `requires_flag`, one beat per strand per day — plus
## the SEASON.
static func eligible_beats(s: Dictionary) -> Array:
	var story: Dictionary = s["story"]
	var season := Season.of_state(s)
	var out: Array = []
	var order := 0
	for strand in Content.STRANDS:
		order += 1
		var progress: Dictionary = story["strands"].get(strand["id"], {})
		if progress.is_empty():
			continue
		var cur: String = progress["cur"]
		# `last_day` is the "seen tonight" guard, and EVERY encounter stamps it now — a resolved beat
		# or a closed tree, both through `advance_step`. That is what makes "at most one arc step a
		# night" and "never the same guest twice in a night" the same single rule.
		if cur == "" or int(progress["last_day"]) == int(s["day"]):
			continue
		# THE SEASON GATE. A step is due from its own season onward and never before: step 5 cannot
		# play in the summer. A step whose season passed unplayed is STILL due — which is how an arc
		# catches up ONE STEP PER ENCOUNTER instead of skipping ahead to whatever the date says.
		if not Season.step_is_due(int(progress.get("step", Season.FIRST_STEP)), season):
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
		out.append({"strand": strand, "beat": beat, "last_day": int(progress["last_day"]), "order": order})
	out.sort_custom(func(a, b): return _sorts_before(a, b))
	return out

## THE MAIN ARC OUTRANKS THE CAST OUTRIGHT; INSIDE THE CAST, FAIRNESS OUTRANKS PRIORITY.
##   1. the main arc (priority >= MAIN_ARC_PRIORITY) — its beats are pinned to day milestones and may
##      not be made to wait behind a regular,
##   2. whoever has been UNSEEN LONGEST (`last_day` ascending),
##   3. their `priority`, which is now a tiebreak between two guests last seen on the same night,
##   4. registry order.
## Key 2 is what turns a one-a-night cap into a ROTATION. Sorting on `priority` first (which is what
## this did when a night held two arrivals) starves the bottom of the table completely: measured over
## a 28-night season, Herr Bley — priority 4, the lowest — never walked in once. Every key is a pure
## function of state, so the schedule still replays byte-for-byte from {config, seed, actions}.
const MAIN_ARC_PRIORITY: int = 100

static func _sorts_before(a: Dictionary, b: Dictionary) -> bool:
	var pa := int((a["strand"] as Dictionary).get("priority", 0))
	var pb := int((b["strand"] as Dictionary).get("priority", 0))
	var main_a := pa >= MAIN_ARC_PRIORITY
	var main_b := pb >= MAIN_ARC_PRIORITY
	if main_a != main_b:
		return main_a
	if int(a["last_day"]) != int(b["last_day"]):
		return int(a["last_day"]) < int(b["last_day"])
	if pa != pb:
		return pa > pb
	return int(a["order"]) < int(b["order"])

## Called by open_night AFTER the ordinary arrivals are built: injects tonight's cast arrivals, or —
## on a quiet night — pins one unseen vignette onto an ordinary customer. Keeps `arrivals` time-sorted.
static func schedule_beats(s: Dictionary, rng: Rng) -> void:
	var arrivals: Array = s["arrivals"]
	var available: Array = (s["inventory"] as Dictionary).keys()
	var scheduled := 0
	# NEVER THE SAME GUEST TWICE IN A NIGHT. A beat may be spoken by someone else's face (the main
	# arc's `squeeze` is Mehmet's), so two eligible beats can name one person — and two Mehmets in one
	# queue is a bug the player can see. Deliberately independent of MAX_STORY_ARRIVALS: raising the
	# cap later must not quietly reintroduce the double.
	var tonight: Dictionary = {}
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
		if character_id != "" and tonight.has(character_id):
			continue
		var arch := Content.archetype(archetype_id)
		if arch.is_empty():
			continue
		var wants: Dictionary = character.get("wants", arch["wants"]) if not character.is_empty() else arch["wants"]
		arrivals.append({
			"time_ms": _arrival_time(rng, arch, int(s["config"]["night_len_ms"])),
			"archetype_id": archetype_id,
			"want": pick_want(rng, wants, arch["wants"], available),
			"character_id": character_id,
			"beat_id": beat["id"],
			"vignette_id": "",
			# The cast carry empties like anyone else (Jürgen especially) — same draw, same seeded rng,
			# and the arrival shape stays identical to the parade's so `from_json` cannot re-shape it.
			"bottles": rng.randi_below(Rules.PFAND_MAX_RETURN + 1),
		})
		if character_id != "":
			tonight[character_id] = true
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
static func pick_want(rng: Rng, wants: Dictionary, fallback_wants: Dictionary, available: Array) -> String:
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
		return str(rng.pick(available)) if not available.is_empty() else "water"
	return str(ids[rng.weighted_index(weights)])

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
	advance_step(s, strand_id)  # the beat resolved: the arc moves on one step, and `last_day` is stamped
	progress["cur"] = choice.get("next", "")
	story["pending"] = {}
	_set_expression(s, choice)

## THE ARC LEDGER (docs/06 §8). `step` is the Truby step this guest plays NEXT; `season_seen` is the
## season the last one actually happened in. Three rules, all of them here:
##   · a step advances when an ENCOUNTER resolves — a beat answered, or the guest's own tree closed;
##   · AT MOST ONE STEP PER NIGHT PER GUEST: `last_day` is the guard, and stamping it unconditionally
##     is also what stops the same guest being scheduled again tonight (`eligible_beats` reads it);
##   · NEVER A SKIP: it is +1, never "jump to whatever the season says", so an arc whose season passed
##     unplayed catches up one step per encounter. `Season.step_is_due` is the other half of that.
## It saturates at `Season.LAST_STEP` — once step 7 has played, that tree stays the guest's voice.
static func advance_step(s: Dictionary, strand_id: String) -> bool:
	if strand_id == "":
		return false
	var progress: Dictionary = (s["story"]["strands"] as Dictionary).get(strand_id, {})
	if progress.is_empty():
		return false
	var day := int(s["day"])
	var first_tonight := int(progress.get("last_day", -1)) != day
	progress["last_day"] = day
	if not first_tonight:
		return false
	progress["season_seen"] = Season.of_state(s)
	progress["step"] = mini(int(progress.get("step", Season.FIRST_STEP)) + 1, Season.LAST_STEP)
	return true

## The same ledger addressed by the FACE at the counter rather than by the strand — what
## `Rules._end_talk` calls when a guest's own conversation closes. A face with no persona card (the
## whole nameless parade) has no strand_id and therefore moves nothing.
static func advance_step_for(s: Dictionary, character_id: String) -> bool:
	if character_id == "":
		return false
	return advance_step(s, String(Content.character(character_id).get("strand_id", "")))

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

## A beat/vignette choice carries its effects as flat keys; a dialogues.gd choice nests them under
## `effects` (docs/06 §3). Both end up here, so there is exactly one place cash/kiez/flags are moved.
static func _apply_effects(s: Dictionary, choice: Dictionary) -> void:
	apply_effect_map(s, choice.get("effects", choice))

static func apply_effect_map(s: Dictionary, choice: Dictionary) -> void:
	if choice.is_empty():
		return
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
