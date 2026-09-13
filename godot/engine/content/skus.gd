extends RefCounted
## SKU catalogue (data only) — port of app/src/engine/content/skus.ts. Prices in euros.
## `deposit` = Pfand on returnable bottles. `unlocked_by` gates a SKU behind an upgrade module.
## Real-brand stand-ins throughout (see docs/legal: no real trademarks).
## Optional keys (`perishable`, `restricted`, `deposit`, `unlocked_by`) are read with .get(k, default).
## `name` is SPOKEN: it is substituted into `{want}` in the conversation graphs (talk.gd) and into
## `Strings.ORDER_LINE` ("%s, please.") on the plain order — so every name is a sayable noun phrase.
## No parentheticals, no glosses, no unit suffixes; shelf-only detail belongs in the icon or category.

const DATA: Array[Dictionary] = [
	# — Drinks —
	{"id": "beer", "name": "Sterni", "category": "drinks", "cost": 0.45, "base_price": 1.2, "fair_lo": 1.0, "fair_hi": 1.9, "demand": 1.6, "deposit": 0.08, "restricted": true, "icon": "sku/beer"},
	{"id": "mate", "name": "Mate", "category": "drinks", "cost": 0.85, "base_price": 1.8, "fair_lo": 1.5, "fair_hi": 2.8, "demand": 1.4, "deposit": 0.15, "icon": "sku/mate"},
	{"id": "cola", "name": "Cola", "category": "drinks", "cost": 0.5, "base_price": 1.5, "fair_lo": 1.2, "fair_hi": 2.4, "demand": 1.0, "deposit": 0.25, "icon": "sku/cola"},
	{"id": "water", "name": "Water", "category": "drinks", "cost": 0.2, "base_price": 0.9, "fair_lo": 0.7, "fair_hi": 1.6, "demand": 1.1, "deposit": 0.25, "icon": "sku/water"},
	{"id": "energy", "name": "Energy drink", "category": "drinks", "cost": 0.7, "base_price": 1.8, "fair_lo": 1.5, "fair_hi": 2.9, "demand": 0.7, "icon": "sku/energy"},
	# — Snacks —
	{"id": "chips", "name": "Chips", "category": "snacks", "cost": 0.7, "base_price": 1.8, "fair_lo": 1.5, "fair_hi": 2.7, "demand": 0.9, "icon": "sku/chips"},
	{"id": "chocolate", "name": "Chocolate", "category": "snacks", "cost": 0.55, "base_price": 1.4, "fair_lo": 1.1, "fair_hi": 2.2, "demand": 0.8, "icon": "sku/chocolate"},
	{"id": "gummi", "name": "Gummi bears", "category": "snacks", "cost": 0.5, "base_price": 1.3, "fair_lo": 1.0, "fair_hi": 2.0, "demand": 0.7, "icon": "sku/gummi"},
	{"id": "schrippe", "name": "Schrippe", "category": "snacks", "cost": 0.1, "base_price": 0.4, "fair_lo": 0.3, "fair_hi": 0.7, "demand": 0.5, "perishable": true, "icon": "sku/schrippe"},
	# — Tobacco (restricted) —
	{"id": "cigarettes", "name": "Cigarettes", "category": "tobacco", "cost": 6.5, "base_price": 8.0, "fair_lo": 7.5, "fair_hi": 9.0, "demand": 1.0, "restricted": true, "icon": "sku/cigarettes"},
	{"id": "tobacco", "name": "Rolling tobacco", "category": "tobacco", "cost": 9.0, "base_price": 11.0, "fair_lo": 10.5, "fair_hi": 12.5, "demand": 0.5, "restricted": true, "icon": "sku/tobacco"},
	{"id": "papers", "name": "Rolling papers", "category": "tobacco", "cost": 0.4, "base_price": 1.0, "fair_lo": 0.8, "fair_hi": 1.6, "demand": 0.5, "icon": "sku/papers"},
	{"id": "filters", "name": "Filters", "category": "tobacco", "cost": 0.35, "base_price": 1.0, "fair_lo": 0.8, "fair_hi": 1.6, "demand": 0.5, "icon": "sku/filters"},
	# — Essentials —
	{"id": "tp", "name": "Toilet paper", "category": "essentials", "cost": 0.6, "base_price": 1.5, "fair_lo": 1.2, "fair_hi": 2.4, "demand": 0.4, "icon": "sku/tp"},
	{"id": "condoms", "name": "Condoms", "category": "essentials", "cost": 1.5, "base_price": 3.5, "fair_lo": 3.0, "fair_hi": 5.0, "demand": 0.4, "icon": "sku/condoms"},
	{"id": "batteries", "name": "Batteries", "category": "essentials", "cost": 1.0, "base_price": 3.0, "fair_lo": 2.5, "fair_hi": 4.5, "demand": 0.3, "icon": "sku/batteries"},
	{"id": "lighter", "name": "Lighter", "category": "essentials", "cost": 0.3, "base_price": 1.2, "fair_lo": 1.0, "fair_hi": 2.0, "demand": 0.6, "icon": "sku/lighter"},
	{"id": "painkillers", "name": "Painkillers", "category": "essentials", "cost": 1.2, "base_price": 3.0, "fair_lo": 2.5, "fair_hi": 4.5, "demand": 0.4, "icon": "sku/painkillers"},
	# — Upgrade-gated —
	{"id": "coffee", "name": "Coffee", "category": "hot", "cost": 0.3, "base_price": 2.0, "fair_lo": 1.6, "fair_hi": 3.0, "demand": 0.9, "unlocked_by": "coffee_machine", "icon": "sku/coffee"},
	{"id": "currywurst", "name": "Currywurst", "category": "hot", "cost": 1.2, "base_price": 3.5, "fair_lo": 3.0, "fair_hi": 5.0, "demand": 0.7, "unlocked_by": "coffee_machine", "icon": "sku/currywurst"},
	{"id": "icecream", "name": "Ice cream", "category": "snacks", "cost": 0.5, "base_price": 2.0, "fair_lo": 1.6, "fair_hi": 3.2, "demand": 0.6, "perishable": true, "unlocked_by": "ice_cream_freezer", "icon": "sku/icecream"},
	{"id": "milk", "name": "Milk", "category": "essentials", "cost": 0.6, "base_price": 1.5, "fair_lo": 1.2, "fair_hi": 2.2, "demand": 0.5, "perishable": true, "unlocked_by": "grocery_section", "icon": "sku/milk"},
	{"id": "eggs", "name": "Eggs", "category": "essentials", "cost": 1.0, "base_price": 2.5, "fair_lo": 2.0, "fair_hi": 3.5, "demand": 0.4, "perishable": true, "unlocked_by": "grocery_section", "icon": "sku/eggs"},
	{"id": "vape", "name": "Vape", "category": "tobacco", "cost": 4.0, "base_price": 8.0, "fair_lo": 7.0, "fair_hi": 11.0, "demand": 0.5, "restricted": true, "unlocked_by": "vape_stand", "icon": "sku/vape"},
]
