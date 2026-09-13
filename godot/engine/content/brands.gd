extends RefCounted
## Brand catalogue (data only) — the canonical table from docs/08 §2, "The tobacco catalogue".
##
## A brand is a VARIANT OF AN EXISTING SKU, never a new SKU: `inventory["cigarettes"]` keeps one stock
## number and one price for the wholesaler and the ManageBoard, and a row here carries identity only.
## Per-brand stock and per-brand prices are explicitly out of the slice (docs/08 §7).
##
## `spoken` is the noun phrase a customer SAYS ("Adler cigarettes", "long Feder papers") — it is what
## `Content.brand_spoken` substitutes into `{brand.<sku>}` in a talk graph (docs/09 §0), so every one is
## a sayable phrase with no ids, no parentheticals and no unit suffixes.
## `phrase` is the same brand pointed at rather than named — the article-free logo phrase the `mark`
## speech tier speaks through `Strings.ASK_MARK_PHRASE` ("the ones with the %s"). The article is NOT
## stored, because the template already carries it; docs/09 §1's table writes it with one.
## `mark` is the whole shape a 16×16 window has to hold — the shape ALWAYS carries the answer, because
## `speech:"colour"` exists and colour-blind players do not get a worse game (docs/08 §2, §7).
## `size` is the facing's base-pixel footprint; `icon` is the asset id of that facing (docs/08 §5) —
## a missing id renders as a correctly-sized placeholder, so this table ships before the art does.
##
## TWO CONTENT INVARIANTS, both enforced by tests/unit/test_brands.gd:
##   1. marks are unique — no two brands are separable by colour alone;
##   2. the twelve cigarette + rolling-tobacco colours differ by ≥ 40 RGB Euclidean distance (the
##      minimum here is 45.11, kranich/elbe), so the swatch game is winnable.
## The two catch opposite failure modes. Ship both.

const DATA: Array[Dictionary] = [
	# — Cigarettes — sku "cigarettes", 8,00 €, pack 26×34 —
	{"id": "adler", "sku": "cigarettes", "family": "cigarettes", "name": "Adler", "spoken": "Adler cigarettes", "phrase": "eagle",
		"mark": "blunt white chevron wedge, 3 blocks", "colour": "#b2372f", "band": "#efe6d2", "size": [26, 34], "icon": "tob/pack_adler"},
	{"id": "nordstern", "sku": "cigarettes", "family": "cigarettes", "name": "Nordstern", "spoken": "Nordstern cigarettes", "phrase": "star",
		"mark": "8-point star, one core block and 4 arms", "colour": "#1e3a63", "band": "#ffffff", "size": [26, 34], "icon": "tob/pack_nordstern"},
	{"id": "kranich", "sku": "cigarettes", "family": "cigarettes", "name": "Kranich", "spoken": "Kranich cigarettes", "phrase": "crane",
		"mark": "S-hook crane neck, 2 blocks", "colour": "#2f7a5f", "band": "#efe6d2", "size": [26, 34], "icon": "tob/pack_kranich"},
	{"id": "luxor", "sku": "cigarettes", "family": "cigarettes", "name": "Luxor", "spoken": "Luxor cigarettes", "phrase": "pyramid",
		"mark": "stepped pyramid, 3 rows", "colour": "#c9a227", "band": "#3a2a12", "size": [26, 34], "icon": "tob/pack_luxor"},
	{"id": "elbe", "sku": "cigarettes", "family": "cigarettes", "name": "Elbe", "spoken": "Elbe cigarettes", "phrase": "ripples",
		"mark": "two stacked ripples", "colour": "#2e7d8c", "band": "#efe6d2", "size": [26, 34], "icon": "tob/pack_elbe"},
	{"id": "bergmann", "sku": "cigarettes", "family": "cigarettes", "name": "Bergmann", "spoken": "Bergmann cigarettes", "phrase": "peak",
		"mark": "notched triangle peak", "colour": "#5a6b8c", "band": "#d8d2c4", "size": [26, 34], "icon": "tob/pack_bergmann"},
	{"id": "fuchs", "sku": "cigarettes", "family": "cigarettes", "name": "Fuchs", "spoken": "Fuchs cigarettes", "phrase": "fox",
		"mark": "two ear triangles over a muzzle block", "colour": "#d2691e", "band": "#2a1a12", "size": [26, 34], "icon": "tob/pack_fuchs"},
	{"id": "perle", "sku": "cigarettes", "family": "cigarettes", "name": "Perle", "spoken": "Perle cigarettes", "phrase": "pearl",
		"mark": "filled circle with one highlight block", "colour": "#c8c3bb", "band": "#4a4238", "size": [26, 34], "icon": "tob/pack_perle"},

	# — Rolling tobacco — sku "tobacco", 11,00 €, soft pouch 28×26 —
	{"id": "dreiringe", "sku": "tobacco", "family": "tobacco", "name": "Drei Ringe", "spoken": "Drei Ringe tobacco", "phrase": "three rings",
		"mark": "three rings in a row", "colour": "#6b7a3a", "band": "#efe6d2", "size": [28, 26], "icon": "tob/pouch_dreiringe"},
	{"id": "altepost", "sku": "tobacco", "family": "tobacco", "name": "Alte Post", "spoken": "Alte Post tobacco", "phrase": "posthorn",
		"mark": "posthorn spiral", "colour": "#7a4a26", "band": "#e8dcc0", "size": [28, 26], "icon": "tob/pouch_altepost"},
	{"id": "zunder", "sku": "tobacco", "family": "tobacco", "name": "Zunder", "spoken": "Zunder tobacco", "phrase": "spark",
		"mark": "4-block flint spark", "colour": "#2a2a30", "band": "#d8712c", "size": [28, 26], "icon": "tob/pouch_zunder"},
	{"id": "kiezgold", "sku": "tobacco", "family": "tobacco", "name": "Kiez Gold", "spoken": "Kiez Gold tobacco", "phrase": "crown",
		"mark": "3-block crown", "colour": "#5e1b2c", "band": "#d8a83c", "size": [28, 26], "icon": "tob/pouch_kiezgold"},

	# — Papers — sku "papers", 1,00 €. Three kinds × two lengths. THE LENGTH IS THE SILHOUETTE, never a
	#   label (lang 20×30, kurz 20×24), and the kind is a foot-band shape, never the cover colour alone.
	{"id": "pap_feder_lang", "sku": "papers", "family": "papers", "name": "Feder lang", "spoken": "long Feder papers", "phrase": "cream booklet",
		"mark": "tall booklet, single thin foot band", "colour": "#e6dcc2", "band": "#c9b78d", "size": [20, 30], "icon": "tob/paper_feder_lang"},
	{"id": "pap_feder_kurz", "sku": "papers", "family": "papers", "name": "Feder kurz", "spoken": "short Feder papers", "phrase": "cream booklet",
		"mark": "short booklet, single thin foot band", "colour": "#e6dcc2", "band": "#c9b78d", "size": [20, 24], "icon": "tob/paper_feder_kurz"},
	{"id": "pap_braun_lang", "sku": "papers", "family": "papers", "name": "Braun lang", "spoken": "long Braun papers", "phrase": "kraft booklet",
		"mark": "tall booklet, double foot band", "colour": "#a8814f", "band": "#6f4f2c", "size": [20, 30], "icon": "tob/paper_braun_lang"},
	{"id": "pap_braun_kurz", "sku": "papers", "family": "papers", "name": "Braun kurz", "spoken": "short Braun papers", "phrase": "kraft booklet",
		"mark": "short booklet, double foot band", "colour": "#a8814f", "band": "#6f4f2c", "size": [20, 24], "icon": "tob/paper_braun_kurz"},
	{"id": "pap_kohle_lang", "sku": "papers", "family": "papers", "name": "Kohle lang", "spoken": "long Kohle papers", "phrase": "black booklet",
		"mark": "tall booklet, solid foot block", "colour": "#23222a", "band": "#55525e", "size": [20, 30], "icon": "tob/paper_kohle_lang"},
	{"id": "pap_kohle_kurz", "sku": "papers", "family": "papers", "name": "Kohle kurz", "spoken": "short Kohle papers", "phrase": "black booklet",
		"mark": "short booklet, solid foot block", "colour": "#23222a", "band": "#55525e", "size": [20, 24], "icon": "tob/paper_kohle_kurz"},

	# — Filters — sku "filters" (the new SKU, docs/08 §3.6), 1,00 €, box 22×22. Two gauges × two kinds.
	#   The gauge is the box width in the silhouette; charcoal is a cored tip, never the body colour alone.
	{"id": "fil_slim", "sku": "filters", "family": "filters", "name": "Slim", "spoken": "slim filters", "phrase": "slim ones",
		"mark": "narrow box, three plain round tips", "colour": "#cfc7b4", "band": "#efe6d2", "size": [22, 22], "icon": "tob/filter_slim"},
	{"id": "fil_slim_kohle", "sku": "filters", "family": "filters", "name": "Slim Kohle", "spoken": "slim charcoal filters", "phrase": "slim black ones",
		"mark": "narrow box, three cored round tips", "colour": "#3a3740", "band": "#efe6d2", "size": [22, 22], "icon": "tob/filter_slim_kohle"},
	{"id": "fil_reg", "sku": "filters", "family": "filters", "name": "Regular", "spoken": "regular filters", "phrase": "fat ones",
		"mark": "wide box, three plain round tips", "colour": "#b9a982", "band": "#efe6d2", "size": [22, 22], "icon": "tob/filter_reg"},
	{"id": "fil_reg_kohle", "sku": "filters", "family": "filters", "name": "Regular Kohle", "spoken": "regular charcoal filters", "phrase": "fat black ones",
		"mark": "wide box, three cored round tips", "colour": "#2b2930", "band": "#efe6d2", "size": [22, 22], "icon": "tob/filter_reg_kohle"},
]
