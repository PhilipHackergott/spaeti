extends RefCounted
## The named cast (engine-api §6). `portrait` + "_" + expression = the asset id under godot/assets/
## (ids match docs/asset-spec.json); a missing expression falls back to `_neutral`, and a story character
## with no entry here falls back to their archetype's one-off portrait (see Content.portrait_for).
## `wants` are this person's own weighted SKU wants — a story arrival buys what *they* would buy.
## `archetype_id` supplies the patience/budget/tip behaviour they use while they stand at the counter.

const DATA: Array[Dictionary] = [
	{"id": "you", "name": "You", "portrait": "char/you", "expressions": ["neutral"], "archetype_id": "regular", "colour": "#f0e0c0",
		"wants": {"coffee": 2, "water": 1}},
	{"id": "lena", "name": "Lena", "portrait": "char/lena", "expressions": ["neutral", "warm", "upset"], "archetype_id": "student", "colour": "#e8a1b8",
		"wants": {"mate": 3, "beer": 1, "gummi": 1, "schrippe": 1}},
	{"id": "juergen", "name": "'Bottle' Jürgen", "portrait": "char/juergen", "expressions": ["neutral", "warm"], "archetype_id": "regular", "colour": "#9fb7a3",
		"wants": {"beer": 2, "schrippe": 2, "coffee": 1}},
	{"id": "mehmet", "name": "Mehmet", "portrait": "char/mehmet", "expressions": ["neutral", "warm", "wary"], "archetype_id": "regular", "colour": "#d8a05a",
		"wants": {"cigarettes": 2, "mate": 2, "water": 1}},
	{"id": "brandt", "name": "Frau Brandt", "portrait": "char/brandt", "expressions": ["neutral", "wary"], "archetype_id": "tourist", "colour": "#8fa8c8",
		"wants": {"water": 3, "coffee": 1}},
	{"id": "tobias", "name": "Tobias", "portrait": "char/tobias", "expressions": ["neutral", "warm", "upset"], "archetype_id": "tourist", "colour": "#c9b07a",
		"wants": {"beer": 2, "mate": 2, "chips": 1}},
	{"id": "schulz", "name": "Frau Schulz", "portrait": "char/schulz", "expressions": ["neutral", "wary"], "archetype_id": "regular", "colour": "#b8a9c0",
		"wants": {"schrippe": 3, "chocolate": 1, "milk": 1}},
	{"id": "nadia", "name": "Nadia", "portrait": "char/nadia", "expressions": ["neutral", "warm", "upset"], "archetype_id": "nurse", "colour": "#7fbfb0",
		"wants": {"coffee": 3, "schrippe": 2, "painkillers": 1}},
	# One-off portraits: the nameless parade. Archetypes point at these (customers.gd `portrait`).
	{"id": "oneoff_clubber", "name": "Clubber", "portrait": "char/oneoff_clubber", "expressions": ["neutral"], "archetype_id": "raver", "colour": "#a98fd0",
		"wants": {"mate": 3, "energy": 2, "water": 2}},
	{"id": "oneoff_tourist", "name": "Tourist", "portrait": "char/oneoff_tourist", "expressions": ["neutral"], "archetype_id": "tourist", "colour": "#e0c090",
		"wants": {"water": 3, "beer": 2, "chips": 1}},
]
