class_name Content
extends RefCounted
## The content registry: every data table plus its id→row index, built once at class load.
## Content is READ-ONLY (the DATA consts are frozen by GDScript); the reducer copies values out of it
## and never writes into it. Registries are default-off in the sense that an empty table still ticks —
## a Späti with no strands and no vignettes is a bare shop, not a crash.

const SkuData := preload("res://engine/content/skus.gd")
const CustomerData := preload("res://engine/content/customers.gd")
const UpgradeData := preload("res://engine/content/upgrades.gd")
const StoryData := preload("res://engine/content/story.gd")
const VignetteData := preload("res://engine/content/vignettes.gd")
const CharacterData := preload("res://engine/content/characters.gd")

static var SKUS: Array = SkuData.DATA
static var ARCHETYPES: Array = CustomerData.DATA
static var UPGRADES: Array = UpgradeData.DATA
static var STRANDS: Array = StoryData.DATA
static var VIGNETTES: Array = VignetteData.DATA
static var CHARACTERS: Array = CharacterData.DATA

static var SKU_BY_ID: Dictionary = {}
static var ARCHETYPE_BY_ID: Dictionary = {}
static var UPGRADE_BY_ID: Dictionary = {}
static var STRAND_BY_ID: Dictionary = {}
static var VIGNETTE_BY_ID: Dictionary = {}
static var CHARACTER_BY_ID: Dictionary = {}
## beat_id → strand_id. A customer at the counter carries only `beat_id`, so the reducer needs this to
## find the strand the beat belongs to (beat ids are unique registry-wide — test_content asserts it).
static var BEAT_STRAND: Dictionary = {}

static func _static_init() -> void:
	_index(SKUS, SKU_BY_ID)
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
