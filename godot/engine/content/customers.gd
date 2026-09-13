extends RefCounted
## Customer archetypes (data only) — port of app/src/engine/content/customers.ts.
## `wants` are weighted SKU picks; `curve` weights spawns across the night's [early, mid, late] thirds.
## `portrait` is the one-off portrait a nameless customer of this archetype wears — and the fallback
## portrait for a story character who has no entry in the CHARACTERS registry yet (engine-api §6).
## `speech` is how this archetype NAMES A BRAND at the register (docs/08 §2), and it is the whole
## difference between reading a list and running a shop:
##   "mark" (default) — a stranger points: "2× the ones with the eagle — cigarettes."
##   "name"           — a regular knows the wall: "2× Adler — cigarettes."
## Only people who are IN the Kiez every week get "name"; everybody else has to be read off the
## shelf, which is the puzzle. `config.brand_hint` overrides both (the night-1 tutorial / mercy
## setting). The `colour` tier of docs/08 §2 is designed but not built — see `Rules._said_for`.

const DATA: Array[Dictionary] = [
	{
		"id": "regular", "speech": "name", "name": "Kiez regular", "portrait": "char/oneoff_clubber",
		"wants": {"beer": 3, "mate": 2, "cigarettes": 2, "water": 1, "schrippe": 1},
		"patience_ms": 9000, "budget": 12.0, "price_tolerance": 1.25, "kiez_sensitivity": 1.4, "tip_base": 0.2, "curve": [1.0, 1.0, 0.8],
	},
	{
		"id": "tourist", "name": "Lost tourist", "portrait": "char/oneoff_tourist",
		"wants": {"water": 3, "beer": 2, "chips": 2, "cola": 1, "chocolate": 1},
		"patience_ms": 7000, "budget": 20.0, "price_tolerance": 1.9, "kiez_sensitivity": 0.4, "tip_base": 0.6, "curve": [1.0, 1.0, 0.4],
	},
	{
		"id": "raver", "name": "After-club raver", "portrait": "char/oneoff_clubber",
		"wants": {"mate": 3, "energy": 2, "water": 2, "gummi": 1, "chips": 1},
		"patience_ms": 6000, "budget": 14.0, "price_tolerance": 1.5, "kiez_sensitivity": 0.8, "tip_base": 0.4, "curve": [0.0, 0.4, 1.8],
	},
	{
		"id": "nurse", "name": "Night-shift nurse", "portrait": "char/oneoff_clubber",
		"wants": {"coffee": 3, "water": 2, "painkillers": 1, "schrippe": 1, "chocolate": 1},
		"patience_ms": 8000, "budget": 10.0, "price_tolerance": 1.1, "kiez_sensitivity": 1.1, "tip_base": 0.3, "curve": [0.5, 1.0, 1.0],
	},
	{
		"id": "student", "name": "Broke student", "portrait": "char/oneoff_clubber",
		"wants": {"mate": 3, "beer": 2, "gummi": 1, "schrippe": 1},
		"patience_ms": 10000, "budget": 6.0, "price_tolerance": 1.0, "kiez_sensitivity": 1.2, "tip_base": 0.05, "curve": [0.8, 1.0, 0.9],
	},
	{
		"id": "insomniac", "speech": "name", "name": "Insomniac", "portrait": "char/oneoff_clubber",
		"wants": {"cigarettes": 2, "cola": 2, "chips": 2, "chocolate": 1, "papers": 1},
		"patience_ms": 11000, "budget": 15.0, "price_tolerance": 1.3, "kiez_sensitivity": 1.0, "tip_base": 0.2, "curve": [0.3, 1.0, 1.2],
	},
	{
		"id": "party", "name": "Party group", "portrait": "char/oneoff_clubber",
		"wants": {"beer": 4, "chips": 2, "energy": 1, "gummi": 1},
		"patience_ms": 6500, "budget": 25.0, "price_tolerance": 1.4, "kiez_sensitivity": 0.9, "tip_base": 0.5, "curve": [0.5, 1.4, 0.7],
	},
	{
		# Kassenkind: tries to buy a restricted item — the ethics beat at the counter.
		"id": "kid", "name": "Kassenkind", "portrait": "char/oneoff_clubber",
		"wants": {"beer": 3, "energy": 1},
		"patience_ms": 7000, "budget": 8.0, "price_tolerance": 1.1, "kiez_sensitivity": 0.6, "tip_base": 0.1, "curve": [1.0, 0.7, 0.2],
		"underage": true,
	},
]
