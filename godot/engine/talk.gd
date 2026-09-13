class_name Talk
extends RefCounted
## The conversation at the register (docs/06-dialogue-and-stats.md §3–§4): resolving `state.talk` to
## the node being spoken, and projecting it into `view.talk`. PURE — nothing here mutates state; the
## reducer in `Rules` owns every write.
##
## ONE SOURCE FOR THE BOX. Three kinds of content flow through the same node shape, so `view.dialogue`
## and `view.talk` can never disagree (docs/06 §4):
##   kind "talk"      → a graph in `content/dialogues.gd`, walked node by node; ending it dismisses
##                      the guest (their want is auto-served, docs/06 §4 `talk_end`).
##   kind "beat"      → one strand beat from `content/story.gd`, as a ONE-NODE dialogue. Ending it
##                      leaves the customer standing there for the ordinary serve (docs/05 §4).
##   kind "vignette"  → one one-off from `content/vignettes.gd`, likewise one node.
## `dialogue_id` carries the kind's prefix so a saved talk re-resolves from data alone.

const DIALOGUE_PREFIX := "dlg:"
const BEAT_PREFIX := "beat:"
const VIGNETTE_PREFIX := "vignette:"

const KIND_TALK := "talk"
const KIND_BEAT := "beat"
const KIND_VIGNETTE := "vignette"

## A fresh `state.talk` (docs/06 §4). `history` is the node trail — the only record of the path taken.
static func open(customer_id: int, dialogue_id: String, node_id: String, kind: String) -> Dictionary:
	return {
		"customer_id": customer_id,
		"dialogue_id": dialogue_id,
		"node": node_id,
		"line": 0,
		"last_check": {},
		"history": [node_id],
		"kind": kind,
	}

static func kind_of(s: Dictionary) -> String:
	return String((s.get("talk", {}) as Dictionary).get("kind", KIND_TALK))

static func is_open(s: Dictionary) -> bool:
	return not (s.get("talk", {}) as Dictionary).is_empty()

## The node currently being spoken, normalised to { speaker, expression, lines, choices, kind } with
## `{want}` already substituted. `{}` when the talk points at content that no longer exists.
static func node_of(s: Dictionary) -> Dictionary:
	var talk: Dictionary = s.get("talk", {})
	if talk.is_empty():
		return {}
	var kind := String(talk.get("kind", KIND_TALK))
	var node_id := String(talk.get("node", ""))
	var raw: Dictionary = {}
	match kind:
		KIND_BEAT:
			raw = Content.beat(String(talk.get("dialogue_id", "")).trim_prefix(BEAT_PREFIX), node_id)
		KIND_VIGNETTE:
			raw = Content.vignette(node_id)
		_:
			raw = Content.dialogue_node(String(talk.get("dialogue_id", "")).trim_prefix(DIALOGUE_PREFIX), node_id)
	if raw.is_empty():
		return {}
	var subs := subs_for(s)
	var lines: Array = []
	for line in raw.get("lines", []):
		lines.append(_apply(String(line), subs))
	var choices: Array = []
	for choice in raw.get("choices", []):
		var copy: Dictionary = (choice as Dictionary).duplicate(true)  # the DATA consts are read-only
		copy["label"] = _apply(String(copy.get("label", "")), subs)
		choices.append(copy)
	var active: Dictionary = s.get("active", {})
	return {
		"speaker": _speaker_name(s, raw, kind),
		"expression": String(raw.get("expression", active.get("expression", "neutral"))),
		"lines": lines,
		"choices": choices,
		"kind": kind,
	}

## Every token a line or a label may carry, built ONCE per node (docs/09 §0). Substitution is PER
## BASKET LINE, not per character: Achim orders three different tobacco products in one breath, and a
## single `habits.brand` field cannot serve that sentence.
##   {want}          the SKU the guest came in for — unchanged, and still what a plain order says
##   {qty.<sku>}     how many of that line she asked for
##   {brand.<sku>}   the noun phrase she SAYS ("long Feder papers") — Content.brand_spoken
##   {logo.<sku>}    the facing's ASSET id, i.e. an inline mark glyph, never spoken text — brand_logo
## An unbranded line resolves `{brand.*}` / `{logo.*}` to "", so a basket without tobacco says nothing
## rather than saying "null".
static func subs_for(s: Dictionary) -> Dictionary:
	var out := {"{want}": want_name_of(s)}
	for entry in ((s.get("active", {}) as Dictionary).get("basket", []) as Array):
		var row: Dictionary = entry
		var sku_id := String(row.get("sku", ""))
		if sku_id == "":
			continue
		var brand := String(row.get("brand", ""))
		out["{qty." + sku_id + "}"] = str(int(row.get("qty", 1)))
		out["{brand." + sku_id + "}"] = Content.brand_spoken(brand)
		out["{logo." + sku_id + "}"] = Content.brand_logo(brand)
	return out

## Replace what we know and LEAVE THE REST ALONE: a tree is never broken by a basket that lacks the
## SKU it names (docs/09 §0). `test_tokens.gd` is what fails the build when that happens — the same
## rule as the soft-lock: never trust a name, assert against the read-model.
static func _apply(text: String, subs: Dictionary) -> String:
	var out := text
	for token in subs:
		out = out.replace(String(token), String(subs[token]))
	return out

## The SKU name `{want}` stands for — what the person at the counter actually came in for.
static func want_name_of(s: Dictionary) -> String:
	var active: Dictionary = s.get("active", {})
	if active.is_empty():
		return ""
	var def := Content.sku(String(active.get("want", "")))
	return String(def.get("name", active.get("want", "")))

## A beat/vignette writes its own display name; a graph node names a character id (or "" = whoever
## is standing there — which is how one `oneoff` graph speaks for the whole nameless parade).
static func _speaker_name(s: Dictionary, raw: Dictionary, kind: String) -> String:
	if kind == KIND_BEAT or kind == KIND_VIGNETTE:
		return String(raw.get("speaker", ""))
	var speaker := String(raw.get("speaker", ""))
	if speaker != "":
		var named := Content.character(speaker)
		return String(named.get("name", speaker))
	return guest_name(s.get("active", {}))

## Who the queue and the box call this person: their own name if we know it, else their archetype's.
static func guest_name(customer: Dictionary) -> String:
	if customer.is_empty():
		return ""
	var named := Content.character(String(customer.get("character_id", "")))
	if not named.is_empty():
		return String(named["name"])
	return String(Content.archetype(String(customer.get("archetype_id", ""))).get("name", "Someone"))

## `view.talk.choices` (docs/06 §4): the label, the roll it would make, and whether a gate locks it.
static func choice_views(s: Dictionary, node: Dictionary) -> Array:
	var out: Array = []
	for choice in node.get("choices", []):
		var entry := {"label": String((choice as Dictionary).get("label", "")), "check": {}, "locked": false, "reason": ""}
		var requires: Dictionary = (choice as Dictionary).get("requires", {})
		if not requires.is_empty():
			var gate_stat := String(requires.get("stat", "str"))
			var minimum := int(requires.get("min", 0))
			if Rules.stat_score(s, gate_stat) < minimum:
				entry["locked"] = true
				entry["reason"] = "%s %d needed" % [Rules.stat_name(gate_stat), minimum]
		var check: Dictionary = (choice as Dictionary).get("check", {})
		if not check.is_empty():
			var stat := String(check.get("stat", "cha"))
			var dc := int(check.get("dc", 10))
			var mod := Rules.stat_mod(s, stat)
			entry["check"] = {"stat": stat, "dc": dc, "mod": mod, "chance": success_chance(dc, mod)}
		out.append(entry)
	return out

## P(d20 + mod >= dc): the faces that clear it, out of twenty. The box prints this next to the tag.
static func success_chance(dc: int, mod: int) -> float:
	return clampf(float(21 - dc + mod) / 20.0, 0.0, 1.0)

## `view.talk` (docs/06 §4), or {} when nobody is talking.
static func view(s: Dictionary) -> Dictionary:
	var talk: Dictionary = s.get("talk", {})
	if talk.is_empty():
		return {}
	var node := node_of(s)
	if node.is_empty():
		return {}
	var active: Dictionary = s.get("active", {})
	var lines: Array = node["lines"]
	return {
		"speaker": String(node["speaker"]),
		"portrait": Content.portrait_for(String(active.get("character_id", "")), String(active.get("archetype_id", ""))),
		"expression": String(node["expression"]),
		"lines": lines,
		"line": clampi(int(talk.get("line", 0)), 0, maxi(0, lines.size() - 1)),
		"choices": choice_views(s, node),
		"last_check": (talk.get("last_check", {}) as Dictionary).duplicate(true),
	}

## `view.dialogue` — the same node, reduced to what the shipped DialogueBox reads (docs/05 §5). It is
## a projection of `view.talk`, never a second lookup, which is the whole point of docs/06 §4.
static func dialogue_view(s: Dictionary) -> Dictionary:
	var talk_view := view(s)
	if talk_view.is_empty():
		return {}
	var labels: Array = []
	for choice in talk_view["choices"]:
		labels.append({"label": String((choice as Dictionary)["label"])})
	return {
		"speaker": talk_view["speaker"],
		"portrait": talk_view["portrait"],
		"expression": talk_view["expression"],
		"lines": talk_view["lines"],
		"choices": labels,
		"kind": kind_of(s),
	}
