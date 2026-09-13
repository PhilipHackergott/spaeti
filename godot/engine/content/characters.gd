extends RefCounted
## The named cast (engine-api §6, docs/09 "The cast"). `portrait` + "_" + expression = the asset id
## under godot/assets/ (ids match docs/asset-spec.json); a missing expression falls back to `_neutral`,
## and a story character with no entry here falls back to their archetype's one-off portrait (see
## Content.portrait_for). `wants` are this person's own weighted SKU wants — a story arrival buys what
## *they* would buy. `archetype_id` supplies the patience/budget/tip behaviour they use at the counter.
##
## THE PERSONA CARD (docs/09 §5). Every key below `archetype_id` is display and authoring data: it is
## read with `.get(k, default)`, the reducer never touches it, and nothing here enters `state`. The
## mandatory pair is `stake` (what this person loses if the Späti goes) and `arc_link` (their tie to
## the gentrification arc) — test_content.gd fails the build on a card that omits either, because a
## guest with no relationship to the pressure is decoration, not cast.
##
##   age / job / voice / quirk    who they are and how they sound
##   story                        the paragraph the persona-card overlay prints
##   strand_id                    their strand in story.gd (the arc below is that strand's seven steps)
##   signature_prop               the object in EVERY expression of their portrait (docs/09 §3)
##   schedule                     when they come. DEFERRED: nothing reads this yet, and it is far
##                                cheaper to write now than to retrofit into eleven hand-written cards.
##   basket / order_line          what the register serves, and the sentence they say while it lands.
##                                `basket` is the SINGLE SOURCE of the order: the register seeds
##                                `state.active.basket` from it and `Talk.subs_for` builds
##                                {qty.<sku>} / {brand.<sku>} / {logo.<sku>} out of the same rows, so
##                                the want-list and the spoken line cannot drift (docs/09 §5).
##                                `brand` is a BRAND ID from brands.gd — a paper "brand" is the length
##                                variant (`pap_feder_lang`), a filter's is the gauge (`fil_slim`).
##   pays / pfand / tip           how the money lands at the register
##   arc                          Truby's seven steps keyed to the year: Summer 1–2 · Autumn 3–4 ·
##                                Winter 5–6 · Spring 7. Beat ids a later season ships, not "Battle".
##
## `expressions` LISTS ONLY WHAT IS ON DISK. `Content.portrait_asset` falls back to `_neutral`, and a
## stamped placeholder standing beside a finished bust reads as a broken character rather than as an
## unfinished expression — so promotion is one array edit per portrait the art lane delivers.

## The frozen expression vocabulary (docs/09 §3): six ids, identical for the whole cast, so a tree can
## never name a face the art lane was never asked to draw. Expression-id drift is the failure that
## ships silently — test_content.gd checks every tree and every character against this one list.
const EXPRESSIONS: Array[String] = ["neutral", "warm", "wary", "upset", "surprised", "tired"]

const DATA: Array[Dictionary] = [
	{"id": "you", "name": "You", "portrait": "char/you", "expressions": ["neutral"], "archetype_id": "regular", "colour": "#f0e0c0",
		"wants": {"coffee": 2, "water": 1}},

	# ── Lena Voigt — the tab on the fridge door, and the pride that costs money ────────────────
	{"id": "lena", "name": "Lena", "portrait": "char/lena", "expressions": ["neutral", "warm", "upset"],
		"archetype_id": "student", "colour": "#e8a1b8",
		"wants": {"mate": 3, "beer": 1, "gummi": 1, "schrippe": 1},
		"age": 23, "job": "Painting student", "strand_id": "lena",
		"story": "Third year at the art school, a studio shared with four people and one radiator that died in 1994. Came from Cottbus for the school and stayed for the city. She has been fifty cents short at this counter since Cem's time — he kept her tab on the back of a Pfand receipt and never mentioned it once.",
		"stake": "The Späti is her canteen and her clock, and the tab on the fridge door is the only credit anyone has ever extended her.",
		"arc_link": "Her half of the flat is in the building Lindner is buying. A professionalised Spätkauf has no line item for a tab on a fridge door — she is the first person the corner loses.",
		"voice": "Quick, deflecting, jokes ahead of the sentence that would hurt. Short clauses.",
		"quirk": "Says \"ähm\" when she means: I am about to ask you for something.",
		"signature_prop": "a Mate bottle, label out",
		"schedule": {"after_hour": 23, "days": "any"},
		"basket": [
			{"sku": "mate", "qty": 1},
			{"sku": "schrippe", "qty": 1},
			{"sku": "tobacco", "qty": 1, "brand": "dreiringe"},
			{"sku": "papers", "qty": 1, "brand": "pap_feder_lang"},
			{"sku": "filters", "qty": 1, "brand": "fil_reg"},
		],
		"order_line": "Mate, ein Schrippe, und {brand.tobacco} mit {brand.papers}.",
		"pays": "fifty cents short, most weeks", "pfand": "leaves it as a tip she can pretend isn't one", "tip": 0.0,
		"arc": {
			"summer": ["Fifty Cents Short", "The Honest Piece"],
			"autumn": ["The Gallerist", "Nights In The Studio"],
			"winter": ["The Show", "Help Isn't Failing"],
			"spring": ["The Wall"],
		},
	},

	# ── "Bottle" Jürgen Massek — the Pfand round, and a jacket that is not a winter jacket ─────
	{"id": "juergen", "name": "'Bottle' Jürgen", "portrait": "char/juergen", "expressions": ["neutral", "warm"],
		"archetype_id": "regular", "colour": "#9fb7a3",
		"wants": {"beer": 2, "schrippe": 2, "coffee": 1},
		"age": 61, "job": "Flaschensammler", "strand_id": "juergen",
		"story": "Thirty years a fitter at a works that closed in 1996, and he has not said the word \"unemployed\" out loud since. Does the Pfand round between the S-Bahn arches and the park with two carrier bags and a crate he found. Never wrong about a count, and has never once said so.",
		"stake": "The Pfand crate you leave out is the only door on this street that opens for him.",
		"arc_link": "The chain Spätkauf locks its bins. When the chain opens, half his route dies — he is the human cost of the squeeze, standing in front of you.",
		"voice": "Short, formal, exact numbers. Deflects care with logistics.",
		"quirk": "Calls you Chef, because a first name would make it a friendship.",
		"signature_prop": "a crate handle",
		"schedule": {"after_hour": 22, "days": "any"},
		"basket": [
			{"sku": "schrippe", "qty": 1},
			{"sku": "beer", "qty": 1},
			{"sku": "cigarettes", "qty": 1, "brand": "fuchs"},
		],
		"order_line": "Ein Schrippe, ein Sterni. Und einmal die {brand.cigarettes}, if it reaches.",
		"pays": "entirely by offsetting the deposit against the bill", "pfand": "the whole bill IS the Pfand", "tip": 0.0,
		"arc": {
			"summer": ["Forty-One Bottles", "The Crate Is Yours"],
			"autumn": ["The Chain Locks Its Bins", "Not A Winter Jacket"],
			"winter": ["The Night He Doesn't Come", "Seen"],
			"spring": ["Night-Watch"],
		},
	},

	# ── Mehmet Aydın — the conscience, and the same pack for thirty-one years ──────────────────
	{"id": "mehmet", "name": "Mehmet", "portrait": "char/mehmet", "expressions": ["neutral", "warm", "wary"],
		"archetype_id": "regular", "colour": "#d8a05a",
		"wants": {"cigarettes": 2, "mate": 2, "water": 1},
		"age": 58, "job": "Greengrocer two doors down", "strand_id": "mehmet",
		"story": "Came at nineteen to a job his uncle had already quit, stayed for a woman who stayed for him, and has sold fruit on this street since the year the Wall opened. Cem's oldest friend. His son Deniz went to Munich and calls on Sundays; Mehmet answers on the third ring so it does not look eager.",
		"stake": "He is the conscience — the ally who will tell you, out loud, the night you start pricing people instead of serving them.",
		"arc_link": "Same envelope, same lawyer's name, six weeks from Friday. He is your co-defendant, and Brandt has already been in his shop buying two lemons and staying twenty minutes.",
		"voice": "Warm, blunt, arrives at the point sideways. Says \"Quatsch.\"",
		"quirk": "Uses your uncle as a yardstick, and knows exactly what he is doing when he does it.",
		"signature_prop": "a folded letter",
		"schedule": {"after_hour": 20, "days": "any"},
		"basket": [
			{"sku": "cigarettes", "qty": 1, "brand": "kranich"},
			{"sku": "mate", "qty": 1},
			{"sku": "water", "qty": 1},
		],
		"order_line": "Die {brand.cigarettes}, ein Mate, ein Wasser. Das Übliche.",
		"pays": "cash, and counts it back to you", "pfand": "brings the empties in a fruit box", "tip": 0.0,
		"arc": {
			"summer": ["Lawyer German", "Cem Would Have Made A Week Of It"],
			"autumn": ["Eleven Percent", "Knock On Every Door"],
			"winter": ["You're Becoming Them", "Legacy Is People"],
			"spring": ["Deniz Comes For The Versammlung"],
		},
	},

	# ── Frau Brandt — NOT a guest: the developer's agent, pressure on all eleven (docs/09 §2.11) ─
	{"id": "brandt", "name": "Frau Brandt", "portrait": "char/brandt", "expressions": ["neutral", "wary"],
		"archetype_id": "tourist", "colour": "#8fa8c8",
		"wants": {"water": 3, "coffee": 1}},

	# ── Christa Schulz — the corner's memory, and the last filterless row on the wall ──────────
	{"id": "schulz", "name": "Frau Schulz", "portrait": "char/schulz", "expressions": ["neutral", "warm", "wary", "surprised", "tired"],
		"archetype_id": "regular", "colour": "#b8a9c0",
		"wants": {"schrippe": 3, "chocolate": 1, "milk": 1},
		"age": 79, "job": "Retired Reichsbahn dispatcher", "strand_id": "schulz",
		"story": "Born four streets away, put on the trains at nineteen, ran night traffic out of Ostkreuz until 1993, when a man from Hannover explained her job to her and then took it. Watched the Wall open from this corner, at this window, with a Mokka going cold in her hand.",
		"stake": "She has bought bread on this corner under three different signs, and Cem wrote her prices by hand on card because her eyes went.",
		"arc_link": "Brandt's people have already been to her door with a Modernisierungsangebot and a slow, kind voice \"for the old lady\". They expect the easiest tenant in the Haus. She is not.",
		"voice": "Dry, declarative, small cruelties followed by an unexpected tenderness.",
		"quirk": "Prices everything in the old money first. Calls you Junge. Never explains a reference.",
		"signature_prop": "a net shopping bag",
		"schedule": {"after_hour": 18, "days": "any"},
		"basket": [
			{"sku": "schrippe", "qty": 2},
			{"sku": "milk", "qty": 1},
			{"sku": "chocolate", "qty": 1},
			{"sku": "cigarettes", "qty": 1, "brand": "luxor"},
		],
		"order_line": "Two Schrippen, the milk, one chocolate. And {qty.cigarettes}× {brand.cigarettes}. Without filter.",
		"pays": "coins out of a clasp purse, one at a time", "pfand": "returns every bottle, counted", "tip": 0.0,
		"arc": {
			"summer": ["The Konsum Stood Here", "Prices In Her Hand"],
			"autumn": ["A Man From The Verwaltung Came", "Holding Court"],
			"winter": ["They Take The Signal Box Down", "They Do Want The Stories"],
			"spring": ["The Corner's Memory"],
		},
	},

	# ── Achim Kolbe — the deepest register order in the game, and a poster already printed ─────
	{"id": "achim", "name": "Achim", "portrait": "char/achim", "expressions": ["neutral", "warm", "upset", "surprised"],
		"archetype_id": "insomniac", "colour": "#c2564a",
		"wants": {"tobacco": 3, "papers": 2, "beer": 2},
		"age": 57, "job": "Sound engineer, ex-squatter", "strand_id": "achim",
		"story": "Came over in '84 to dodge the draft and stayed for the noise. Squatted the Vorderhaus on the next street for eleven years; the venues he ran the PA in are now a gym, a co-working space and a hole. Two of his crew moved to Brandenburg, one runs a café in Lisbon, one is dead. He is the last of them in the postcode.",
		"stake": "Your window is his noticeboard and your counter is his stage.",
		"arc_link": "When the fight comes he already knows how to run one: folding table, laminator, a PA in a cupboard, no shame. He is your campaign, badly dressed.",
		"voice": "Loud, funny, five clauses where one would do, lands on a hard consonant. Softens once, then covers it.",
		"quirk": "Corrects you on the filter gauge. Every time.",
		"signature_prop": "a fistful of flyers",
		"schedule": {"after_hour": 1, "days": "any"},
		"basket": [
			{"sku": "tobacco", "qty": 1, "brand": "zunder"},
			{"sku": "papers", "qty": 1, "brand": "pap_feder_lang"},
			{"sku": "filters", "qty": 1, "brand": "fil_slim"},
			{"sku": "beer", "qty": 1},
			{"sku": "lighter", "qty": 1},
		],
		"order_line": "Fifty of {brand.tobacco}, {brand.papers}, and {brand.filters}. And a Sterni and the cheap lighter.",
		"pays": "exact coins", "pfand": "never returns it", "tip": 0.0,
		"arc": {
			"summer": ["Everything Good Gets Sold", "Can I Put This In Your Window"],
			"autumn": ["The Spätkauf Opens", "The Folding Table"],
			"winter": ["The Squat Becomes Lofts", "The Fight Is The Scene"],
			"spring": ["Elder Agitator"],
		},
	},

	# ── Karim Hadid — he orders by pointing at the wall, which is how the wall becomes a way in ─
	{"id": "karim", "name": "Karim", "portrait": "char/karim", "expressions": ["neutral", "warm", "wary", "surprised"],
		"archetype_id": "regular", "colour": "#8fae5a",
		"wants": {"cigarettes": 2, "water": 2, "mate": 1, "chocolate": 1},
		"age": 31, "job": "Prep cook, trained civil engineer", "strand_id": "karim",
		"story": "Two years here via Aleppo and four years in Beirut; a degree three offices have politely failed to recognise; prep cook on the late shift at a Vietnamese place on the big street. His German is better than he thinks and deserts him completely at counters. Keeps every letter in a plastic sleeve.",
		"stake": "Your counter is his evening class, and the fact that you wait while he finishes a sentence is not a small thing.",
		"arc_link": "He is what the corner is FOR. A Kiez that can absorb a stranger is worth defending; a lobby with a keypad is not. Brandt's plan has no floor for the person who needs somewhere to be bad at German in public.",
		"voice": "Careful, formal, short. Rehearses before he speaks. Apologises for language that is fine.",
		"quirk": "Builds a sentence like a shelf, checks the level, then ruins it on purpose with a joke.",
		"signature_prop": "a plastic document sleeve",
		"schedule": {"after_hour": 0, "days": "any"},
		"basket": [
			{"sku": "water", "qty": 1},
			{"sku": "mate", "qty": 1},
			{"sku": "cigarettes", "qty": 2, "brand": "fuchs"},
			{"sku": "chocolate", "qty": 1},
		],
		"order_line": "One water — still — one Mate, and {qty.cigarettes}. {logo.cigarettes}.",
		"pays": "notes, counted twice before he hands them over", "pfand": "asks whether he may", "tip": 0.0,
		"arc": {
			"summer": ["A Careful Sentence", "The Berlin Way To Say It"],
			"autumn": ["The Letter In His Jacket", "Ten Minutes Of German, Every Night"],
			"winter": ["Something Gets Said To Him At The Corner", "This Is Already Home"],
			"spring": ["He Cooks For The Street Party"],
		},
	},

	# ── Nadia Ferreira — 03:40, and the tobacco wall still argues with her every night ─────────
	{"id": "nadia", "name": "Nadia", "portrait": "char/nadia", "expressions": ["neutral", "warm", "wary", "upset", "surprised", "tired"],
		"archetype_id": "nurse", "colour": "#7fbfb0",
		"wants": {"coffee": 3, "schrippe": 2, "painkillers": 1},
		"age": 34, "job": "ITU night nurse", "strand_id": "nadia",
		"story": "Twelve years on the wards, the last six at night because nights pay the difference between the rent and the rent. Her son Leo is six and sleeps at her mother's three nights a week. She quit smoking eleven years ago on the day of the scan, and your tobacco wall is the only thing in the Kiez that still argues with her about it.",
		"stake": "The 04:00 coffee is the only ten minutes of the day that belongs to her.",
		"arc_link": "She is why \"open at four\" is not a business decision. The chain shuts at 23:00; there is no line in the development plan where she would appear.",
		"voice": "Quiet, economical, medical precision, gallows humour delivered without a smile.",
		"quirk": "Says \"it's fine\" in four different meanings. Never asks for anything.",
		"signature_prop": "a takeaway coffee cup",
		"schedule": {"after_hour": 3, "days": "any"},
		# NO TOBACCO LINE, on purpose: the night she looks at the nordstern row is a beat, not a sale,
		# and the register needs one basket that proves an absence is servable (docs/09 §6.7).
		"basket": [
			{"sku": "coffee", "qty": 2},
			{"sku": "schrippe", "qty": 2},
			{"sku": "painkillers", "qty": 1},
		],
		"order_line": "Two coffees, two Schrippen, and the Paracetamol. The children's one, if you have it.",
		"pays": "exact, out of a coat pocket", "pfand": "hands the cup back for the machine", "tip": 0.0,
		"arc": {
			"summer": ["03:40, Coffee, Two Schrippen", "She Never Asks"],
			"autumn": ["The Doubles Stack Up", "Counting Coins At The Till"],
			"winter": ["Childcare Falls Through Mid-Shift", "It Takes A Kiez"],
			"spring": ["Leo Does Homework On The Crate"],
		},
	},

	# ── Tobias Lange — your best customer and your worst omen ──────────────────────────────────
	{"id": "tobias", "name": "Tobias", "portrait": "char/tobias", "expressions": ["neutral", "warm", "upset", "surprised"],
		"archetype_id": "tourist", "colour": "#c9b07a",
		"wants": {"beer": 2, "mate": 2, "chips": 1},
		"age": 33, "job": "Product lead, mobility startup", "strand_id": "tobias",
		"story": "Düsseldorf, then Munich, then a two-bedroom in the front building with the good windows for what Mehmet's whole family pays. He genuinely loves this corner, learns names, tips absurdly, calls it \"my Späti\" to colleagues — and nobody has ever come in with him.",
		"stake": "Your best customer and your worst omen.",
		"arc_link": "The fake-ally opponent. His company's Series B was led by a fund with Lindner three layers down, and its office lease carries a break clause tied to the block's residential conversion completing by March.",
		"voice": "Fluent, over-friendly, product vocabulary leaking into human sentences.",
		"quirk": "Card out before you have scanned the first bottle, every time — and he apologises for it.",
		"signature_prop": "a contactless card, already out",
		"schedule": {"after_hour": 21, "days": "thu"},
		"basket": [
			{"sku": "beer", "qty": 4},
			{"sku": "chips", "qty": 1},
			{"sku": "cigarettes", "qty": 1, "brand": "nordstern"},
		],
		"order_line": "Four Sternis, the chips, and one {brand.cigarettes}.",
		"pays": "card, always", "pfand": "leaves the empties for whoever wants them", "tip": 5.0,
		"arc": {
			"summer": ["Big Tip, Big Ideas", "You Should Make This A Destination"],
			"autumn": ["The Kiez Fund", "He Brings Six Colleagues"],
			"winter": ["His Company Or The Corner", "Belonging Is Paid In Care"],
			"spring": ["Throws In"],
		},
	},

	# ── Robin Kessler — the flat opener, which is a test ───────────────────────────────────────
	{"id": "robin", "name": "Robin", "portrait": "char/robin", "expressions": ["neutral", "warm", "wary", "surprised"],
		"archetype_id": "student", "colour": "#c07ad8",
		"wants": {"energy": 2, "gummi": 2, "tobacco": 2, "papers": 1},
		"age": 19, "job": "Café shift", "strand_id": "robin",
		"story": "Left a town near Halberstadt eleven months ago with a rucksack and a chosen name, and has been braced for the flinch ever since. Tests everyone with a flat, slightly rude opener, delivered deadpan, to see what comes back. Their mother thinks they are coming home in the summer.",
		"stake": "The safest-looking light on the street at one in the morning, which is not nothing when you are nineteen.",
		"arc_link": "The corner is the reason they stayed in Berlin instead of going back. A lobby with a keypad is not a place you can stand outside of at 1am without a reason. If the corner goes, they go.",
		"voice": "Flat, deadpan, very fast once the guard drops. The grin arrives a second late.",
		"quirk": "Rolls at the counter, badly, and will not accept help with it.",
		"signature_prop": "a rolling tin",
		"schedule": {"after_hour": 1, "days": "any"},
		# ORDER MATTERS. `Rules._place_basket` truncates at BASKET_MAX_LINES 4 / BASKET_MAX_UNITS 6 /
		# BASKET_MAX_PLACED 3 (rules.gd:30), and a truncated line takes its {brand.*} token with it —
		# `Talk._apply` then leaves the token alone and it PRINTS. The three wall lines lead, so the
		# tokens always resolve; the gummi bears are the line that gives, and they are prose anyway.
		"basket": [
			{"sku": "tobacco", "qty": 1, "brand": "dreiringe"},
			{"sku": "papers", "qty": 1, "brand": "pap_feder_kurz"},
			{"sku": "filters", "qty": 1, "brand": "fil_slim"},
			{"sku": "energy", "qty": 1},
			{"sku": "gummi", "qty": 1},
		],
		"order_line": "{brand.tobacco}, {brand.papers}, and {brand.filters}. Energy and the gummi bears.",
		"pays": "card, and the name on it is not theirs", "pfand": "keeps the bottle to stand outside with", "tip": 0.0,
		"arc": {
			"summer": ["The Flat Opener", "The Name They Use Now"],
			"autumn": ["A Call Home", "Orbiting The Light"],
			"winter": ["First Heartbreak, 2am, Your Counter", "Chosen Family Is Real And It's Here"],
			"spring": ["They Bring The Crew"],
		},
	},

	# ── Aylin Demir — Sunday, 07:40, glitter, and a lighter. Always a lighter. ─────────────────
	{"id": "aylin", "name": "Aylin", "portrait": "char/aylin", "expressions": ["neutral", "warm", "surprised", "tired"],
		"archetype_id": "raver", "colour": "#d6e05e",
		"wants": {"mate": 3, "water": 1, "cigarettes": 1, "lighter": 1},
		"age": 29, "job": "Live-sound engineer", "strand_id": "aylinjonas",
		"story": "She arrives Sunday at 07:40 still glittering, talking at one and a half speed about a set that ended an hour ago, in the specific radiant condition of a person who will crash hard at nine. Plans things constantly: next weekend, next summer, a bar in Portugal, a van. Jonas held the second bag for seven years of Sundays. Lately, sometimes, he doesn't.",
		"stake": "The bench out front is where their Sundays happen; your corner has hosted more of that relationship than either of their flats.",
		"arc_link": "The bench is public, free and unbuyable, which is precisely what the development plan has no line item for — and she is the one who notices the fence notice on the door.",
		"voice": "Fast, warm, radiant, plans stated as facts. Goes very even when something costs her.",
		"quirk": "Buys a lighter every single time, without exception. Fourth one this month.",
		"signature_prop": "a lighter",
		"schedule": {"after_hour": 7, "days": "sun"},
		# The lighter sits above the water on purpose: BASKET_MAX_PLACED 3 drops whichever placed line
		# comes last, and "a lighter, every single time, without exception" is the whole character.
		"basket": [
			{"sku": "mate", "qty": 2},
			{"sku": "cigarettes", "qty": 1, "brand": "perle"},
			{"sku": "lighter", "qty": 1},
			{"sku": "water", "qty": 1},
		],
		"order_line": "Two Mate, a water, {qty.cigarettes}× {brand.cigarettes}, und ein Feuerzeug.",
		"pays": "card, laughing about the lighter", "pfand": "brings back Sunday's, eventually", "tip": 0.5,
		"arc": {
			"summer": ["Sunday, 07:40, Glitter", "The Van And The Bar"],
			"autumn": ["Jonas Isn't With Her", "One More Season Of Sundays"],
			"winter": ["The Job In Leipzig", "The Magic Was Each Other"],
			"spring": ["They Come At Eight In The Evening Now"],
		},
	},

	# ── Rüdiger Bley — 03:10, still water, and a term sheet he read on a Tuesday ───────────────
	{"id": "bley", "name": "Herr Bley", "portrait": "char/bley", "expressions": ["neutral", "wary", "surprised", "tired"],
		"archetype_id": "insomniac", "colour": "#8a949c",
		"wants": {"water": 3, "chocolate": 2, "cigarettes": 1},
		"age": 61, "job": "Corporate real-estate financing", "strand_id": "bley",
		"story": "Arrives at 03:10 in a good coat and orders with the crispness of a man who considers you staff, then stands at the counter nine minutes over a four-euro transaction. A wife in a house in Grunewald that he leaves at midnight to drive around a city he despises on paper. He is not a conspirator: he is a man who read a term sheet on a Tuesday and went to lunch.",
		"stake": "The only place in his life where nobody wants anything from him.",
		"arc_link": "He is the lever. He signed off the Lindner financing on page eleven, and what he lets slip at three in the morning — that the facility is conditional on vacant possession by a fixed date — arrives through a customer relationship, months before Brandt hands you hers.",
		"voice": "Clipped, formal, sentences with the subject fully specified.",
		"quirk": "One unguarded clause per night, immediately covered by an ordinary one.",
		"signature_prop": "a still-water bottle",
		"schedule": {"after_hour": 3, "days": "any"},
		"basket": [
			{"sku": "water", "qty": 1},
			{"sku": "chocolate", "qty": 1},
			{"sku": "cigarettes", "qty": 1, "brand": "nordstern"},
		],
		"order_line": "Water. Still — the other is undrinkable. A chocolate. And {qty.cigarettes}× {brand.cigarettes}.",
		"pays": "cash, exact, and does not want a bag", "pfand": "leaves the bottle on the counter", "tip": 0.0,
		"arc": {
			"summer": ["Still Water, Never Sparkling", "\"Young Man\""],
			"autumn": ["He Stays Eleven Minutes", "What He Read On A Tuesday"],
			"winter": ["The Armour Comes Off", "Somebody Saw Him"],
			"spring": ["A Quiet Patron"],
		},
	},

	# ── One-off portraits: the nameless parade. Archetypes point at these (customers.gd `portrait`).
	#    TWO silhouettes today, and that is the open seam: with eleven named regulars in rotation one
	#    shared clubber visibly doubles a face at the counter, so docs/09 §3 grows the pool to five
	#    (`oneoff_lateworker`, `oneoff_dogwalker`, `oneoff_kassenkind`) and remaps `customers.gd`
	#    `regular`/`nurse` → lateworker · `insomniac` → dogwalker · `kid` → kassenkind ·
	#    `student`/`raver`/`party` → clubber. The remap is one field per archetype and is NOT made
	#    here, because the three ids do not exist in docs/asset-spec.json or Assets.SIZES yet (the
	#    orchestrator owns both) and `test_dialogue.gd::test_the_queue_view_is_fifo_and_carries_
	#    portraits` asserts every queued portrait is an id the art pipeline knows. Rows for the three
	#    are deliberately absent too: a row listing a `neutral` that is not on disk is exactly the
	#    half-drawn character test_content.gd's expression rule exists to catch.
	{"id": "oneoff_clubber", "name": "Clubber", "portrait": "char/oneoff_clubber", "expressions": ["neutral"], "archetype_id": "raver", "colour": "#a98fd0",
		"wants": {"mate": 3, "energy": 2, "water": 2}},
	{"id": "oneoff_tourist", "name": "Tourist", "portrait": "char/oneoff_tourist", "expressions": ["neutral"], "archetype_id": "tourist", "colour": "#e0c090",
		"wants": {"water": 3, "beer": 2, "chips": 1}},
]
