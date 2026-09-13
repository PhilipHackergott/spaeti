class_name Content
extends RefCounted
## The content registry: every data table plus its id→row index, built once at class load.
## Content is READ-ONLY (the DATA consts are frozen by GDScript); the reducer copies values out of it
## and never writes into it. Registries are default-off in the sense that an empty table still ticks —
## a Späti with no strands and no vignettes is a bare shop, not a crash.

const SkuData := preload("res://engine/content/skus.gd")
const BrandData := preload("res://engine/content/brands.gd")
const CustomerData := preload("res://engine/content/customers.gd")
const UpgradeData := preload("res://engine/content/upgrades.gd")
const StoryData := preload("res://engine/content/story.gd")
const VignetteData := preload("res://engine/content/vignettes.gd")
const CharacterData := preload("res://engine/content/characters.gd")
const DialogueData := preload("res://engine/content/dialogues.gd")

static var SKUS: Array = SkuData.DATA
## Tobacco brands (docs/08 §2). A brand is a VARIANT of a SKU — identity only, never its own stock
## line or its own price; `inventory[brand.sku]` stays the one number the wholesaler sees.
static var BRANDS: Array = BrandData.DATA
static var ARCHETYPES: Array = CustomerData.DATA
static var UPGRADES: Array = UpgradeData.DATA
static var STRANDS: Array = StoryData.DATA
static var VIGNETTES: Array = VignetteData.DATA
static var CHARACTERS: Array = CharacterData.DATA
## The frozen six-id expression vocabulary (docs/09 §3). A tree may only name a face from this list,
## and a character may only LIST one it actually has on disk — test_content.gd guards both, because
## expression-id drift is the failure that ships silently (the portrait quietly falls back and nobody
## sees that the face never changed).
static var EXPRESSIONS: Array = CharacterData.EXPRESSIONS
## flag id -> the reader that consumes it (docs/09 §4.10). The declared half of the flag economy: a
## flag with no `requires_flag` gate and no Economy.FLAG_LABEL entry must name its future reader
## or test_flags.gd fails the build. A flag nobody reads is a lie in the save file.
static var FLAG_READERS: Dictionary = StoryData.FLAG_READERS
## id -> conversation graph (docs/06 §3). Keyed by CHARACTER id, plus the generic DIALOGUE_FALLBACK.
static var DIALOGUES: Dictionary = DialogueData.DATA

static var SKU_BY_ID: Dictionary = {}
static var BRAND_BY_ID: Dictionary = {}
## sku id -> Array of brand rows, in registry order, so the tobacco wall never reshuffles.
static var BRANDS_BY_SKU: Dictionary = {}
## facing asset id -> brand row. `{logo.<sku>}` substitutes a brand's FACING ASSET ID into a spoken
## line (docs/09 §1 rule 3), and the DialogueBox has to turn that id back into a mark to draw it —
## without guessing from the string's shape. This is the lookup that makes the glyph data-driven.
static var BRAND_BY_ICON: Dictionary = {}
static var ARCHETYPE_BY_ID: Dictionary = {}
static var UPGRADE_BY_ID: Dictionary = {}
static var STRAND_BY_ID: Dictionary = {}
static var VIGNETTE_BY_ID: Dictionary = {}
static var CHARACTER_BY_ID: Dictionary = {}
## beat_id → strand_id. A customer at the counter carries only `beat_id`, so the reducer needs this to
## find the strand the beat belongs to (beat ids are unique registry-wide — test_content asserts it).
static var BEAT_STRAND: Dictionary = {}
## The graph every guest with no tree of their own falls back to (its lines substitute `{want}`).
const DIALOGUE_FALLBACK := "oneoff"
## The same parade, but a minor asking for a restricted SKU: the ID check IS the conversation, so the
## Integrity decision is on the table instead of being swallowed by the counter's blanket refusal.
const DIALOGUE_MINOR := "oneoff_minor"

static func _static_init() -> void:
	_index(SKUS, SKU_BY_ID)
	_index(BRANDS, BRAND_BY_ID)
	for row in BRANDS:
		var sku_id: String = row["sku"]
		if not BRANDS_BY_SKU.has(sku_id):
			BRANDS_BY_SKU[sku_id] = []
		(BRANDS_BY_SKU[sku_id] as Array).append(row)
		BRAND_BY_ICON[String(row["icon"])] = row
	_index(ARCHETYPES, ARCHETYPE_BY_ID)
	_index(UPGRADES, UPGRADE_BY_ID)
	_index(STRANDS, STRAND_BY_ID)
	_index(VIGNETTES, VIGNETTE_BY_ID)
	_index(CHARACTERS, CHARACTER_BY_ID)
	for strand in STRANDS:
		for beat_id in (strand["beats"] as Dictionary).keys():
			BEAT_STRAND[beat_id] = strand["id"]

static func _index(rows: Array, out: Dictionary) -> void:
	for row in rows:
		out[row["id"]] = row

static func sku(id: String) -> Dictionary:
	return SKU_BY_ID.get(id, {})

## One brand row, or {} — `brand` is "" on every non-tobacco basket line, and that resolves to {}.
static func brand(id: String) -> Dictionary:
	return BRAND_BY_ID.get(id, {})

## Every brand/variant of one SKU, in registry order (the wall's shelf order). [] for a SKU with none.
static func brands_for(sku_id: String) -> Array:
	return BRANDS_BY_SKU.get(sku_id, [])

## The noun phrase a customer SAYS for a brand — what `{brand.<sku>}` substitutes to (docs/09 §0).
## "" for an unbranded line, so a basket without tobacco simply says nothing instead of saying "null".
static func brand_spoken(id: String) -> String:
	return String(brand(id).get("spoken", ""))

## The asset id of a brand's facing — what `BrandMark` crops its 16×16 window out of, and what
## `{logo.<sku>}` resolves to. "" for an unbranded line.
static func brand_logo(id: String) -> String:
	return String(brand(id).get("icon", ""))

## The brand's LOGO PHRASE, article-free — the emblem as a customer names it out loud ("eagle",
## "fox", "cream booklet"). `Strings.ASK_MARK_PHRASE "the ones with the %s"` is what wraps it, which
## is why the article is not stored here: "the ones with the the fox" is how that bug reads.
## This is the `mark` speech tier's only source of words; "" for an unbranded line.
static func brand_phrase(id: String) -> String:
	return String(brand(id).get("phrase", ""))

## The brand whose facing is this asset id, or {} — the inverse of `brand_logo`, so a component that
## meets a bare asset id in a sentence can ask the catalogue instead of parsing the string.
static func brand_by_icon(icon_id: String) -> Dictionary:
	return BRAND_BY_ICON.get(icon_id, {})

static func archetype(id: String) -> Dictionary:
	return ARCHETYPE_BY_ID.get(id, {})

static func upgrade(id: String) -> Dictionary:
	return UPGRADE_BY_ID.get(id, {})

static func strand(id: String) -> Dictionary:
	return STRAND_BY_ID.get(id, {})

static func vignette(id: String) -> Dictionary:
	return VIGNETTE_BY_ID.get(id, {})

static func character(id: String) -> Dictionary:
	return CHARACTER_BY_ID.get(id, {})

## What the register serves this person: the persona card's authored basket rows (docs/09 §5), or []
## for a face with no card. This is the SINGLE SOURCE of an order — the register seeds
## `state.active.basket` from it and `Talk.subs_for` builds {qty.*} / {brand.*} / {logo.*} out of
## the same rows, so the want-list and the spoken line cannot drift apart.
static func basket_for(character_id: String) -> Array:
	return character(character_id).get("basket", [])

## The declared reader of a flag, or "" (docs/09 §4.10) — authoring metadata, never read by the reducer.
static func flag_reader(flag: String) -> String:
	return String(FLAG_READERS.get(flag, ""))

## The conversation graph a guest gets: their own if one is written, else the nameless parade's.
static func dialogue_id_for(character_id: String) -> String:
	return character_id if DIALOGUES.has(character_id) else DIALOGUE_FALLBACK

static func dialogue(id: String) -> Dictionary:
	return DIALOGUES.get(id, {})

## One node of one graph, or {} — the reducer never indexes the tables directly.
static func dialogue_node(dialogue_id: String, node_id: String) -> Dictionary:
	var graph := dialogue(dialogue_id)
	if graph.is_empty():
		return {}
	return (graph["nodes"] as Dictionary).get(node_id, {})

## The beat dictionary for a strand's beat id, or {}.
static func beat(strand_id: String, beat_id: String) -> Dictionary:
	var st := strand(strand_id)
	if st.is_empty():
		return {}
	return (st["beats"] as Dictionary).get(beat_id, {})

## Portrait base id for whoever is at the counter: the named character if we have one, else the
## archetype's one-off portrait (engine-api §6), else the generic clubber.
static func portrait_for(character_id: String, archetype_id: String) -> String:
	var ch := character(character_id)
	if not ch.is_empty():
		return ch["portrait"]
	var arch := archetype(archetype_id)
	if not arch.is_empty():
		return arch.get("portrait", "char/oneoff_clubber")
	return "char/oneoff_clubber"

## Full asset id: "char/lena" + "warm" → "char/lena_warm"; an expression the character does not have
## falls back to "_neutral" so the art pipeline only ever needs the sheets it actually drew.
static func portrait_asset(character_id: String, archetype_id: String, expression: String) -> String:
	var base := portrait_for(character_id, archetype_id)
	var ch := character(character_id)
	var has_expr := not ch.is_empty() and (ch["expressions"] as Array).has(expression)
	return base + "_" + (expression if has_expr else "neutral")
