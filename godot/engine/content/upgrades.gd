extends RefCounted
## Build & Customize (GDD §4c) — an ONGOING loop: modules + décor unlock GRADUALLY (gated by day /
## Kiez-Trust / a prerequisite), several are TIERED, and a parallel décor track lets you make the place
## yours. `kind: "module"` = functional offering; `kind: "decor"` = customization (cosmetic + small effect).
## Port of app/src/engine/content/upgrades.ts. Optional keys are read with .get(k, default).

const DATA: Array[Dictionary] = [
	# ── modules: capacity / offering / draw (trickle out across the season) ──
	{"id": "bigger_fridge", "name": "Bigger fridge", "cost": 200.0, "kind": "module", "tier": 1, "effects": {"stock_cap": 12}, "note": "More cold stock + shelf space."},
	{"id": "bigger_fridge_2", "name": "Walk-in fridge", "cost": 350.0, "kind": "module", "tier": 2, "requires": "bigger_fridge", "available_day": 9, "effects": {"stock_cap": 24}, "note": "Serious cold capacity."},
	{"id": "signage", "name": "Neon signage", "cost": 180.0, "kind": "module", "tier": 1, "effects": {"traffic_mult": 1.2}, "note": "More foot traffic."},
	{"id": "signage_2", "name": "Big neon sign", "cost": 320.0, "kind": "module", "tier": 2, "requires": "signage", "available_day": 11, "effects": {"traffic_mult": 1.15}, "note": "Seen from down the block."},
	{"id": "coffee_machine", "name": "Coffee machine", "cost": 300.0, "kind": "module", "tier": 1, "available_day": 3, "effects": {"unlocks_sku": ["coffee", "currywurst"]}, "note": "Hot drinks + currywurst."},
	{"id": "espresso_bar", "name": "Espresso bar", "cost": 450.0, "kind": "module", "tier": 2, "requires": "coffee_machine", "available_day": 13, "effects": {"traffic_mult": 1.2, "kiez_per_night": 1.0}, "note": "A reason to linger."},
	{"id": "ice_cream_freezer", "name": "Ice-cream freezer", "cost": 250.0, "kind": "module", "available_day": 4, "effects": {"unlocks_sku": ["icecream"]}, "note": "Summer revenue."},
	{"id": "grocery_section", "name": "Grocery section", "cost": 220.0, "kind": "module", "available_day": 6, "effects": {"unlocks_sku": ["milk", "eggs"], "traffic_mult": 1.1}, "note": "Daytime + Sunday demand."},
	{"id": "vape_stand", "name": "Vape stand", "cost": 150.0, "kind": "module", "available_day": 7, "effects": {"unlocks_sku": ["vape"]}, "note": "High margin; minors = Integrity/legal beat."},
	{"id": "security", "name": "Security cam", "cost": 220.0, "kind": "module", "available_day": 5, "effects": {"fewer_risk_events": true}, "note": "Fewer risk events."},
	{"id": "pfandautomat", "name": "Pfandautomat", "cost": 350.0, "kind": "module", "available_day": 9, "effects": {}, "note": "Reverse-vending; automates Pfand."},
	{"id": "bench", "name": "Bench out front", "cost": 120.0, "kind": "module", "effects": {"kiez_per_night": 1.0, "unlocks_system": "dwell"}, "note": "The Kiez gathers."},
	# ── the illegal dark path ──
	{"id": "extra_menu", "name": "'Extra menu' (illegal)", "cost": 100.0, "kind": "module", "available_day": 5, "effects": {"illegal": true, "traffic_mult": 1.4}, "note": "Fat margins; nightly Integrity bleed + rare brutal raid; gates dark branches."},
	# ── décor / customization (parallel track — make it yours) ──
	{"id": "posters", "name": "Posters & stickers", "cost": 40.0, "kind": "decor", "effects": {"kiez_per_night": 0.5}, "note": "Techno flyers, football scarves — character."},
	{"id": "plants", "name": "Plants", "cost": 60.0, "kind": "decor", "available_day": 2, "effects": {"kiez_per_night": 0.5}, "note": "A little life."},
	{"id": "fairy_lights", "name": "Fairy lights", "cost": 50.0, "kind": "decor", "available_day": 3, "effects": {"kiez_per_night": 0.5}, "note": "Cozy glow."},
	{"id": "rug", "name": "Old rug", "cost": 70.0, "kind": "decor", "available_day": 4, "effects": {"kiez_per_night": 0.5}, "note": "It really ties the Späti together."},
	{"id": "jukebox", "name": "Retro jukebox", "cost": 180.0, "kind": "decor", "available_day": 8, "effects": {"traffic_mult": 1.1, "kiez_per_night": 0.5}, "note": "People stay for the tunes."},
	{"id": "outdoor_seating", "name": "Outdoor seating", "cost": 140.0, "kind": "decor", "requires": "bench", "available_day": 6, "effects": {"kiez_per_night": 1.0, "traffic_mult": 1.05}, "note": "Sit, drink, talk."},
	{"id": "berlin_mural", "name": "Berlin mural", "cost": 220.0, "kind": "decor", "available_day": 11, "available_kiez": 60.0, "effects": {"kiez_per_night": 1.5}, "note": "A local artist (Lena?) paints the wall — a landmark."},
	# ── community systems (GDD §4b) ──
	{"id": "foodsharing_fridge", "name": "Foodsharing fridge", "cost": 80.0, "kind": "module", "available_day": 5, "effects": {"kiez_per_night": 2.0, "unlocks_system": "community"}, "note": "No margin; pure Kiez-Trust."},
	{"id": "open_mic", "name": "Open-mic corner", "cost": 200.0, "kind": "module", "available_day": 13, "effects": {"kiez_per_night": 1.0, "unlocks_system": "events"}, "note": "Host events; the busker arc."},
	{"id": "noticeboard", "name": "Community noticeboard", "cost": 60.0, "kind": "module", "available_day": 4, "effects": {"kiez_per_night": 1.0, "unlocks_system": "board"}, "note": "Flatshares, lost cats, gigs — the Kiez talks."},
	{"id": "mate_tap", "name": "Mate on tap", "cost": 280.0, "kind": "module", "available_day": 10, "effects": {"traffic_mult": 1.15}, "note": "A Berlin pilgrimage; pulls the late crowd."},
	# ── more décor / customization ──
	{"id": "photo_booth", "name": "Photo booth", "cost": 240.0, "kind": "decor", "available_day": 8, "effects": {"traffic_mult": 1.1, "kiez_per_night": 0.5}, "note": "Analog strips; people linger and return."},
	{"id": "vinyl_corner", "name": "Vinyl crate corner", "cost": 160.0, "kind": "decor", "available_day": 9, "effects": {"kiez_per_night": 1.0}, "note": "Crates to dig through; the music nerds adopt you."},
]
