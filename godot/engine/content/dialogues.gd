extends RefCounted
## Branching conversation graphs (docs/06-dialogue-and-stats.md §3) — DATA ONLY, no logic.
##
## A guest walks up, you take them with `talk_next`, and this is what the two of you say. ELEVEN
## regulars have their own tree (docs/09 §4: 5-8 nodes, at least two stat checks/gates, at least one
## gate that is LOCKED at day-one stats, an expression change per node, and the order woven into the
## first node); everyone else gets `oneoff`, whose single node substitutes `{want}` with the SKU they
## came in for.
##
## TREES ARE KEYED BY CHARACTER ID. `Content.dialogue_id_for(id)` returns the character id only when
## `DIALOGUES.has(id)`, so a tree named `achim_t` would be silently unreachable — plain ids auto-wire.
## When the seasonal swaps land (`<char>_a2`, `<char>_w3`), the season-aware selector ships in the
## same commit as the rename, never after it.
##
## BASKET TOKENS. `{want}` is substituted by `Talk.node_of`; `{qty.<sku>}`, `{brand.<sku>}` and
## `{logo.<sku>}` are the register's, substituted per BASKET LINE from the speaker's `characters.gd`
## row (docs/09 §0 — `Talk.subs_for`, still owed by the engine lane). `test_tokens.gd` fails the build
## if a token ever names a SKU the speaker's basket does not carry: never trust a name, assert against
## the read-model. `{logo.<sku>}` resolves to a FACING ASSET ID, so it is an inline mark glyph in a
## line, never spoken text.
##
## NODE   { speaker:String  (a character id, or "" = derive from whoever is at the counter),
##          expression:String ("neutral"|"warm"|"wary"|"upset" — drives the Portrait),
##          lines:Array[String], choices:Array[CHOICE] }
## CHOICE { label:String            — the stat tag is written INTO the label ("[Schnauze 12] …"),
##                                    so the box needs no formatting rules of its own,
##          check:{stat,dc}         — a d20 + modifier roll on the state's seeded Rng (§2),
##          requires:{stat,min}     — a GATE: shown, but locked below `min`; no roll,
##          effects:{cash,kiez,profit,integrity,flags}  — the reducer's existing paths,
##          effects_success / effects_fail              — extra effects for a check's two branches,
##          next:String             — "" ends the conversation (the guest leaves),
##          next_fail:String        — where a failed check lands (defaults to `next`),
##          serve:bool              — false = they leave WITHOUT the auto-serve (you turned them away),
##          sell_restricted:bool    — this line knowingly sells a restricted SKU to a minor: it goes
##                                    through the ordinary serve, Integrity hit and `ethics` log and all }
##
## Authoring rule the tests enforce: choice 0 of every node is never gated, so the headless
## AutoPlayer (and any "just take the top line" player) can always get through a night.
## English base, with the Kiez's own nouns left in German — Späti, Pfand, Mate, Schrippe, Flaschen.

const DATA: Dictionary = {
	# ── Lena: art student, chronically fifty cents short, warmer than she lets on ──────────────
	"lena": {
		"start": "hello",
		"nodes": {
			"hello": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["Mate, ein Schrippe, und {brand.tobacco} mit {brand.papers}. …And, ähm. I'm fifty cents short. Again."],
				"choices": [
					{"label": "\"On the house. Pay me Tuesday.\"", "effects": {"kiez": 1.0, "cash": -1.8}, "next": "thanks"},
					{"label": "[Schnauze 12] \"Pay me in a sketch instead.\"", "check": {"stat": "cha", "dc": 12}, "next": "sketch", "next_fail": "no_sketch"},
					{"label": "\"Cash only, Lena. Even for you.\"", "effects": {"kiez": -1.0}, "next": "", "serve": false},
				],
			},
			"thanks": {
				"speaker": "lena", "expression": "warm",
				"lines": ["\"You're the only Späti on this block that still does that.\"", "She pockets the Mate like it is evidence of something."],
				"choices": [
					{"label": "\"Tuesday. I'm writing it on the fridge.\"", "effects": {"flags": ["lena_tab"]}, "next": "studio"},
					{"label": "\"Go on, before I change my mind.\"", "next": "studio"},
				],
			},
			"sketch": {
				"speaker": "lena", "expression": "warm",
				"lines": ["She laughs, tears a page out of the portfolio and draws the counter in nine quick lines — the till, the Pfand crate, you.", "\"Tape it up. Then the whole Kiez knows I paid.\""],
				"choices": [
					{"label": "Tape it to the cigarette wall.", "effects": {"kiez": 1.5, "flags": ["lena_sketch"]}, "next": "studio"},
					{"label": "\"Deal. The Mate is still one-eighty next time.\"", "effects": {"kiez": 0.5}, "next": "studio"},
				],
			},
			"no_sketch": {
				"speaker": "lena", "expression": "upset",
				"lines": ["\"I'm not a busker. I'm a student.\" The page stays shut in her bag."],
				"choices": [
					{"label": "\"Fair enough. Take the Mate anyway.\"", "effects": {"kiez": 0.5, "cash": -1.8}, "next": "studio"},
					{"label": "\"Then we are still fifty cents apart.\"", "effects": {"kiez": -0.5}, "next": "", "serve": false},
				],
			},
			"studio": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["\"Third night in the studio this week. The radiators in there died in 1994.\"", "She says it lightly, both hands around the cold can as if it were a Kaffee."],
				"choices": [
					{"label": "\"Berlin in November. Wear a coat.\"", "next": "smalltalk"},
					{"label": "[Kiez Sense 12] Actually look at her.", "check": {"stat": "wis", "dc": 12}, "next": "notice", "next_fail": "smalltalk"},
				],
			},
			"notice": {
				"speaker": "lena", "expression": "warm",
				"lines": ["Grey under the eyes. No bag but the portfolio. Nothing eaten since the Schrippe she bought here yesterday.", "\"…What. Don't do the face. Cem used to do the face.\""],
				"choices": [
					{"label": "Put a Schrippe on the counter. No charge.", "effects": {"kiez": 2.0, "cash": -0.4, "flags": ["lena_fed"]}, "next": ""},
					{"label": "\"Go home, Lena. The studio will still be there.\"", "effects": {"kiez": 1.0}, "next": ""},
				],
			},
			"smalltalk": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["\"Ja, ja. Bis morgen.\" The door lets the cold in and takes her out with it."],
				"choices": [
					{"label": "\"Bis morgen.\"", "next": ""},
				],
			},
		},
	},
	# ── 'Bottle' Jürgen: the Pfand round, the bench, the jacket that is not a winter jacket ────
	"juergen": {
		"start": "crate",
		"nodes": {
			"crate": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["A crate of Flaschen lands on the laminate, clinking like a small church.", "\"Automat has eaten them again. Forty-one bottles. I counted twice, Chef.\"", "\"Und einmal die {brand.cigarettes}. Die kleinen. If it reaches.\""],
				"choices": [
					{"label": "Count them out with him, one by one.", "effects": {"kiez": 1.0}, "next": "counted"},
					{"label": "[Muscle 12] Carry the crate out back yourself.", "requires": {"stat": "str", "min": 12}, "effects": {"kiez": 1.5, "flags": ["juergen_crate"]}, "next": "lifted"},
					{"label": "\"The Automat is the Automat, Jürgen. Monday.\"", "effects": {"kiez": -1.0}, "next": ""},
				],
			},
			"counted": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["Forty-one. He is never wrong about the count, and he has never once said so.", "\"Six fifteen. Keep the fifteen for the trouble.\""],
				"choices": [
					{"label": "\"Six fifteen is six fifteen, Jürgen.\"", "effects": {"kiez": 0.5}, "next": "cold"},
					{"label": "Take the fifteen cents. He wants you to.", "effects": {"kiez": 0.5, "cash": 0.15}, "next": "cold"},
				],
			},
			"lifted": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["You take the crate through the back in one go. He watches the door swing shut behind it, a little robbed of his job.", "\"…Danke. That thing has been getting heavier since the summer.\""],
				"choices": [
					{"label": "\"It has been getting heavier for me too.\"", "next": "cold"},
				],
			},
			"cold": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["He rubs his hands down the front of his jacket. It is not a winter jacket.", "\"Nah. Pfand round, bench at the Spätkauf, bench at the kiosk, then home.\""],
				"choices": [
					{"label": "\"Feierabend, Jürgen. Go on.\"", "next": "feierabend"},
					{"label": "[Kiez Sense 13] Notice how he said 'then home'.", "check": {"stat": "wis", "dc": 13}, "next": "cold_read", "next_fail": "feierabend"},
				],
			},
			"cold_read": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["Two carrier bags, not one. The jacket has been slept in. 'Home' has been the Hof behind the Spätkauf for three weeks.", "\"Don't make it a thing. It is a warm Hof.\""],
				"choices": [
					{"label": "Coffee on the house, every night this week.", "effects": {"kiez": 2.0, "cash": -0.3, "flags": ["juergen_warm"]}, "next": ""},
					{"label": "\"The bench inside the door is yours. Nobody asks.\"", "effects": {"kiez": 1.5, "flags": ["juergen_bench"]}, "next": ""},
				],
			},
			"feierabend": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"Bis später, Chef.\" The crate goes back under his arm, empty and rattling."],
				"choices": [
					{"label": "\"Bis später.\"", "next": ""},
				],
			},
		},
	},
	# ── Mehmet: the greengrocer two doors down, and a letter written in lawyer German ──────────
	"mehmet": {
		"start": "letter",
		"nodes": {
			"letter": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["\"Die {brand.cigarettes}, ein Mate, ein Wasser — und pack die Kippen unten hin, my wife has eyes like a Zollbeamter.\"", "Mehmet flattens a letter on the counter with the side of his hand, the way you flatten a receipt.", "\"Read this for me? My German is fine. Lawyer German is another language.\""],
				"choices": [
					{"label": "Take it and read it properly.", "next": "reading"},
					{"label": "\"Take it to the Mieterverein, Mehmet. Tonight.\"", "effects": {"kiez": 0.5}, "next": "advice"},
				],
			},
			"reading": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["Two pages. Modernisierung. Umlage. A date in bold that is six weeks from Friday.", "\"The number at the bottom. That is the new one, ja?\""],
				"choices": [
					{"label": "\"It is a rent increase. That is as far as I can honestly go.\"", "next": "advice"},
					{"label": "[Brains 13] Work out what the numbers actually do.", "check": {"stat": "int", "dc": 13}, "next": "parsed", "next_fail": "lost"},
				],
			},
			"parsed": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["The Umlage is capped, and they have written the cap wrong — by eleven percent, in their own favour.", "\"…Eleven. Eleven percent, on a letter with a lawyer's name on it.\""],
				"choices": [
					{"label": "\"Photograph every page. Then we go to the Mieterverein.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_evidence"]}, "next": "plan"},
					{"label": "\"Pay nothing until somebody official has read it.\"", "effects": {"kiez": 1.0}, "next": "plan"},
				],
			},
			"lost": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["The paragraphs fold back on themselves. You get as far as 'entsprechend §559' and stop pretending.", "\"It is fine. You tried. Cem used to say 'Quatsch' and put it under the till.\""],
				"choices": [
					{"label": "\"Then it goes under the till until somebody who knows reads it.\"", "effects": {"kiez": 0.5}, "next": "plan"},
					{"label": "\"Quatsch. Bring it back Thursday, I will have asked around.\"", "effects": {"kiez": 1.0, "flags": ["mehmet_asked"]}, "next": "plan"},
				],
			},
			"advice": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["\"Mieterverein.\" He says it the way people say the name of a dentist. \"Ja. Ja, okay.\""],
				"choices": [
					{"label": "\"I will come with you. The shop shuts at six anyway.\"", "effects": {"kiez": 1.0}, "next": "plan"},
					{"label": "\"They are free for members, and you joined in 1998.\"", "next": "plan"},
				],
			},
			"plan": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["\"Half the Haus got the same envelope. Nobody wants to be the first one making noise.\"", "He looks at the Späti door as though it owed him something."],
				"choices": [
					{"label": "\"Then don't be first. Be second — I will be first.\"", "effects": {"kiez": 1.0}, "next": "quiet"},
					{"label": "[Schnauze 13] Talk him into knocking on every door tonight.", "check": {"stat": "cha", "dc": 13}, "next": "rally", "next_fail": "quiet"},
				],
			},
			"rally": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["He goes out holding the letter up like a ticket. Through the glass the Hinterhof lights come on, one window at a time.", "\"Fourth floor says they got eleven percent as well!\""],
				"choices": [
					{"label": "Prop the Späti door open and put the coffee on.", "effects": {"kiez": 2.5, "flags": ["kiez_rally"]}, "next": ""},
				],
			},
			"quiet": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["\"Thursday, then.\" He folds the letter along its old creases and puts it away.", "\"Your uncle would have made a whole evening out of this, you know.\""],
				"choices": [
					{"label": "\"He would have made a whole week of it.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Frau Schulz: the price strip, and what stood on this corner before ─────────────────────
	"schulz": {
		"start": "prices",
		"nodes": {
			"prices": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["\"Two Schrippen, the milk, one chocolate. And {qty.cigarettes}× {brand.cigarettes}. Without filter.\"", "A pause exactly long enough to be a test. \"You still have them. Or is that finished too.\""],
				"choices": [
					{"label": "\"Two left on the wall. I'll put one aside for Friday.\"", "effects": {"kiez": 1.0, "flags": ["schulz_reserved"]}, "next": "strip"},
					{"label": "[Kiez Sense 12] She is not asking about cigarettes.", "check": {"stat": "wis", "dc": 12}, "next": "konsum", "next_fail": "strip"},
					{"label": "\"Wholesaler's dropped them. That's the last row.\"", "effects": {"kiez": -0.5}, "next": "strip"},
				],
			},
			"konsum": {
				"speaker": "schulz", "expression": "warm",
				"lines": ["It is not the cigarette. The Konsum stood here until March '91, then a video shop, then four years of nothing, and now a price strip in a font.", "\"I dispatched night trains out of Ostkreuz for twenty-nine years, Junge. I know what a schedule is. This Kiez has no schedule any more.\""],
				"choices": [
					{"label": "\"Tell me what stood on the other corner.\"", "effects": {"kiez": 1.5, "flags": ["schulz_listen"]}, "next": "strip"},
					{"label": "\"March '91. You're sure?\" (She is sure.)", "effects": {"kiez": 0.5, "flags": ["schulz_listen"]}, "next": "strip"},
				],
			},
			"strip": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["\"Your uncle wrote the prices by hand. On card. You could read them from the street.\"", "She counts the coins out of a purse with a clasp older than you are, one at a time, which takes a while and is meant to."],
				"choices": [
					{"label": "\"I'll write the next lot by hand.\"", "effects": {"kiez": 0.5}, "next": "bag"},
					{"label": "[Hands 12] Let her dictate the dispatcher's hand.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.0, "flags": ["schulz_hand"]}, "next": "bag"},
					{"label": "\"The strips came with the shelf.\"", "next": "bag"},
				],
			},
			"bag": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["The net bag goes over her wrist. Milk, two Schrippen, chocolate, {logo.cigarettes} on top. It hangs lower than her hand wants it to.", "\"Fourth floor. No lift. It was a beautiful building in 1968.\""],
				"choices": [
					{"label": "\"Bis morgen, Frau Schulz.\"", "next": "door"},
					{"label": "[Muscle 11] Carry it up the four floors.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.0, "flags": ["schulz_bag"]}, "next": "landing"},
					{"label": "[Schnauze 13] Who knocked on her door last week?", "check": {"stat": "cha", "dc": 13}, "next": "brandt", "next_fail": "door"},
				],
			},
			"landing": {
				"speaker": "schulz", "expression": "surprised",
				"lines": ["Four floors. She talks the whole way up and is not out of breath. You are.", "At the door she takes the bag back and looks at you one second too long. \"Cem carried it too. He never said it was heavy either.\""],
				"choices": [
					{"label": "\"Same time tomorrow.\"", "effects": {"kiez": 1.0, "flags": ["schulz_bag"]}, "next": ""},
				],
			},
			"brandt": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["\"A young woman. Good coat. She said Modernisierung, and she said it slowly. For the old lady.\"", "\"I have been offered a better flat by better-dressed people before, Junge. In '92 as well.\""],
				"choices": [
					{"label": "\"Don't sign anything. Bring it to me first.\"", "effects": {"kiez": 2.0, "flags": ["schulz_brandt_visit"]}, "next": "door"},
					{"label": "\"What did you tell her?\" (\"Nothing.\")", "effects": {"kiez": 1.0, "flags": ["schulz_brandt_visit"]}, "next": "door"},
				],
			},
			"door": {
				"speaker": "schulz", "expression": "tired",
				"lines": ["\"Na dann. Friday, if the world is still standing.\" The bell takes her out into it. She checks both ways twice, out of habit from a different city."],
				"choices": [{"label": "\"Friday, Frau Schulz.\"", "next": ""}],
			},
		},
	},
	# ── Achim: three reaches at the wall, and a poster that is already printed ─────────────────
	"achim": {
		"start": "order",
		"nodes": {
			"order": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["\"Fifty of {brand.tobacco}, {brand.papers}, and {brand.filters} — slim, not the fat ones, I'm not a plumber.\"", "\"And a Sterni and the cheap lighter. Not the branded one. I'm not paying two euro for fire.\" Three separate reaches at the wall. He watches all three like a man marking a load-in."],
				"choices": [
					{"label": "Ring all five through, slims included.", "effects": {"kiez": 0.5}, "next": "chain"},
					{"label": "[Brains 11] The fifty is cheaper than two thirties.", "check": {"stat": "int", "dc": 11}, "next": "maths", "next_fail": "chain"},
					{"label": "[Muscle 11] Reach the top-row box without the stool.", "requires": {"stat": "str", "min": 11}, "next": "reach"},
				],
			},
			"maths": {
				"speaker": "achim", "expression": "warm",
				"lines": ["\"One euro sixty. Over a year that is — hang on — that is a PA cable.\" He is delighted in a way he would deny under questioning.", "\"Cem never did the maths for me. Cem just took the money.\""],
				"choices": [
					{"label": "\"Cem was a businessman. I'm just bored.\"", "effects": {"kiez": 1.0, "flags": ["achim_maths"]}, "next": "chain"},
				],
			},
			"reach": {
				"speaker": "achim", "expression": "surprised",
				"lines": ["You go up on the counter edge and have it down in one. No stool, no wobble.", "\"…Alright. Alright. Your uncle used the stool like a pensioner.\""],
				"choices": [
					{"label": "\"My uncle never dropped a box on a customer.\"", "effects": {"kiez": 1.0}, "next": "chain"},
				],
			},
			"chain": {
				"speaker": "achim", "expression": "upset",
				"lines": ["\"You seen it? Down the block. Neon sign, app, a QR code where the till should be. They've got a CONCEPT.\"", "\"And they've done the Vorderhaus. The one we held for eleven years. Lofts. There's a plaque, mate. A PLAQUE. About us. Next to a keypad we couldn't get through.\""],
				"choices": [
					{"label": "Let him run. Don't fill the gap.", "effects": {"kiez": 0.5}, "next": "poster"},
					{"label": "[Schnauze 13] \"So do it again. Here. This winter.\"", "check": {"stat": "cha", "dc": 13}, "next": "scene", "next_fail": "poster"},
					{"label": "\"It's a shop, Achim. Not the Stasi.\"", "effects": {"kiez": -0.5}, "next": "poster"},
				],
			},
			"scene": {
				"speaker": "achim", "expression": "warm",
				"lines": ["He goes quiet for the first time in four years. Rolls one with the long papers, doesn't light it.", "\"…I've still got the small PA. And I know every printer in this postcode. Say when, Chef.\""],
				"choices": [
					{"label": "\"When. Thursday. Bring the PA.\"", "effects": {"kiez": 2.0, "flags": ["achim_ally"]}, "next": "poster"},
				],
			},
			"poster": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["Out of the jacket comes an A3, still warm from somebody's work printer. KIEZVERSAMMLUNG. DONNERSTAG. The typeface is a crime and the message is not.", "\"Your window. It's the only glass on this street anyone still reads.\""],
				"choices": [
					{"label": "Tape it up, centre of the window.", "effects": {"kiez": 1.5, "flags": ["achim_poster"]}, "next": "off"},
					{"label": "\"Inside the door. The window is my livelihood.\"", "effects": {"kiez": 0.5, "flags": ["achim_poster_inside"]}, "next": "off"},
					{"label": "[Stamina 13] Shut the shop, do the poster route with him.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "cash": -18.0, "flags": ["achim_route", "achim_ally"]}, "next": "four_am"},
				],
			},
			"four_am": {
				"speaker": "achim", "expression": "warm",
				"lines": ["Four in the morning, sixty posters, and one long silence somewhere around Wühlischplatz where he does not rant at all.", "\"Cem did this with us once. Ninety-six. Rent strike. He printed the flyers on the shop's paper and told the Vermieter it was a menu.\""],
				"choices": [
					{"label": "\"He never told me that.\"", "effects": {"kiez": 1.0, "flags": ["achim_cem_story"]}, "next": ""},
					{"label": "\"Then we've done this before. Good.\"", "effects": {"kiez": 1.5, "flags": ["achim_cem_story"]}, "next": ""},
				],
			},
			"off": {
				"speaker": "achim", "expression": "upset",
				"lines": ["\"Thursday. Bring the whole Kiez or bring nobody, but bring yourself.\"", "He takes his five things and leaves the exact money, to the cent, as always. The door bangs harder than it needs to."],
				"choices": [{"label": "\"Thursday.\"", "effects": {"kiez": 0.5}, "next": ""}],
			},
		},
	},
	# ── Karim: he points at the wall, and there is a letter he has not opened ──────────────────
	"karim": {
		"start": "point",
		"nodes": {
			"point": {
				"speaker": "karim", "expression": "neutral",
				"lines": ["\"Good evening. One water — still — one Mate, and… {qty.cigarettes}. The fox. {logo.cigarettes}.\"", "His finger goes over your shoulder, precise, to exactly the right row. He builds the sentence like a shelf, checking the level, and lands it."],
				"choices": [
					{"label": "\"{qty.cigarettes}× {brand.cigarettes}.\" Ring it, no fuss.", "next": "lesson"},
					{"label": "[Kiez Sense 11] He mouthed the word before he pointed.", "check": {"stat": "wis", "dc": 11}, "next": "practice", "next_fail": "lesson"},
					{"label": "[Schnauze 12] Say the brand once, slowly, like it's nothing.", "check": {"stat": "cha", "dc": 12}, "next": "word", "next_fail": "stiff"},
				],
			},
			"word": {
				"speaker": "karim", "expression": "warm",
				"lines": ["\"{brand.cigarettes}.\" He says it back, then again to himself while you bag it. \"{brand.cigarettes}. The fox is a {brand.cigarettes}.\"", "\"Tomorrow I will not point.\""],
				"choices": [
					{"label": "\"Point anyway. I like the pointing.\"", "effects": {"kiez": 1.0, "flags": ["karim_word"]}, "next": "lesson"},
					{"label": "\"Say it the Kiez way: einmal die {brand.cigarettes}, und zwar zackig.\"", "effects": {"kiez": 1.5, "flags": ["karim_word", "karim_zackig"]}, "next": "lesson"},
				],
			},
			"practice": {
				"speaker": "karim", "expression": "surprised",
				"lines": ["He had the whole sentence ready outside, under the sign, and it left him at the counter. It happens every night.", "\"…You saw this. Sorry. It is stupid.\""],
				"choices": [
					{"label": "\"It's not stupid. Try it on me. Nobody's behind you.\"", "effects": {"kiez": 1.5, "flags": ["karim_word"]}, "next": "lesson"},
					{"label": "\"Happens to me in my own language, most nights.\"", "effects": {"kiez": 1.0}, "next": "lesson"},
				],
			},
			"stiff": {
				"speaker": "karim", "expression": "wary",
				"lines": ["He hears the lesson inside the sentence and goes very polite, which is how he goes away.", "\"Yes. Thank you. {qty.cigarettes}. Correct.\""],
				"choices": [
					{"label": "Drop it. Bag the water.", "next": "lesson"},
				],
			},
			"lesson": {
				"speaker": "karim", "expression": "neutral",
				"lines": ["\"In Aleppo I built bridges. Here I am very good at cutting onions.\" He says it lightly, which is how you know it is not light.", "\"Six years of study, and my problem is the articles. Der, die, das. A child knows them.\""],
				"choices": [
					{"label": "\"A child has had six years of practice too.\"", "effects": {"kiez": 1.0}, "next": "sleeve"},
					{"label": "\"Nobody in this Kiez gets them right either.\"", "effects": {"kiez": 0.5}, "next": "sleeve"},
				],
			},
			"sleeve": {
				"speaker": "karim", "expression": "wary",
				"lines": ["A plastic sleeve comes out of the jacket, flattened at the corners from being carried a long time. The top envelope is the window kind, and it is still sealed.", "\"Four days. I read the sender, and then I put it in my jacket, and I have been very busy for four days.\""],
				"choices": [
					{"label": "\"Bring it tomorrow, early. We'll go through it.\"", "effects": {"kiez": 1.0, "flags": ["karim_form"]}, "next": "goodnight"},
					{"label": "[Brains 14] Read the paragraph under the date.", "requires": {"stat": "int", "min": 14}, "next": "read"},
					{"label": "\"That's Behörde business, Karim. I sell Mate.\"", "effects": {"kiez": -1.0}, "next": "goodnight"},
				],
			},
			"read": {
				"speaker": "karim", "expression": "surprised",
				"lines": ["It is not a refusal. It is a request for one document he already has, in the sleeve, second from the back.", "He looks at the counter for a while. \"Six weeks I did not sleep for this paper.\""],
				"choices": [
					{"label": "Photocopy it out back. On the house.", "effects": {"kiez": 2.0, "flags": ["karim_form", "karim_helped"]}, "next": "goodnight"},
				],
			},
			"goodnight": {
				"speaker": "karim", "expression": "warm",
				"lines": ["\"Gute Nacht.\" A beat. \"…Und zwar zackig.\" He gets the rhythm right on the third try and leaves pleased with himself."],
				"choices": [{"label": "\"Gute Nacht, Karim.\"", "next": ""}],
			},
		},
	},
	# ── Nadia: 03:40, and the Paracetamol is not for her ───────────────────────────────────────
	"nadia": {
		"start": "four",
		"nodes": {
			"four": {
				"speaker": "nadia", "expression": "tired",
				"lines": ["\"Two coffees — one's for the porter, he's been on since six as well — two Schrippen, and the Paracetamol. The children's one, if you have it.\"", "03:52. Scrubs under the coat. She is very still, the way people are when moving costs something."],
				"choices": [
					{"label": "Ring the four. Make the porter's the strong one.", "effects": {"kiez": 0.5}, "next": "wall"},
					{"label": "[Kiez Sense 12] The children's one.", "check": {"stat": "wis", "dc": 12}, "next": "leo", "next_fail": "wall"},
					{"label": "\"Long one?\" (Everyone asks her that.)", "effects": {"kiez": -0.5}, "next": "wall"},
				],
			},
			"leo": {
				"speaker": "nadia", "expression": "upset",
				"lines": ["The children's dose. At twenty to four, on her way *in* to a shift, not out of one.", "\"He's six. Thirty-eight nine at ten o'clock. My mother's with him and she'll call if it climbs.\" Her jaw is doing a lot of work."],
				"choices": [
					{"label": "\"Then you should be at home, and you know it.\"", "effects": {"kiez": 0.5}, "next": "wall"},
					{"label": "Turn the box round. Read the weight column out loud.", "effects": {"kiez": 1.0}, "next": "dose"},
					{"label": "\"Take it. Pay me whenever.\"", "effects": {"cash": -3.0, "kiez": 2.0, "flags": ["nadia_tab"]}, "next": "wall"},
				],
			},
			"dose": {
				"speaker": "nadia", "expression": "surprised",
				"lines": ["She lets you get all the way to the end before she says anything.", "\"…I know the table. I'm an ICU nurse.\" A breath. \"I wanted somebody to say it to me. Nobody says anything to me.\""],
				"choices": [
					{"label": "\"Then I'll say it again tomorrow at twenty to four.\"", "effects": {"kiez": 2.0, "flags": ["nadia_seen"]}, "next": "wall"},
					{"label": "Say nothing. Push the coffee across.", "effects": {"kiez": 1.5, "flags": ["nadia_seen"]}, "next": "wall"},
				],
			},
			"wall": {
				"speaker": "nadia", "expression": "wary",
				"lines": ["The star row, second from the top. She has been looking at it for the length of a coffee.", "\"Eleven years. I stopped the day of the scan. And that wall still talks to me every single night.\""],
				"choices": [
					{"label": "\"Nothing off that wall tonight. Coffee's poured.\"", "effects": {"kiez": 1.0, "flags": ["nadia_held"]}, "next": "childcare"},
					{"label": "\"Your call, Nadia. I'll ring it if you say so.\"", "effects": {"flags": ["nadia_offered"]}, "next": "childcare"},
					{"label": "Switch the display light off. \"Wall's shut.\"", "effects": {"kiez": 1.5, "flags": ["nadia_held"]}, "next": "childcare"},
				],
			},
			"childcare": {
				"speaker": "nadia", "expression": "upset",
				"lines": ["Her phone goes on the counter face-up, which it never does. Her mother has the flu. Leo is asleep four streets away and will not be, at seven.", "\"It's fine. I'll sort it. It's fine.\""],
				"choices": [
					{"label": "\"What would actually help? Say the thing.\"", "effects": {"kiez": 1.0}, "next": "bye"},
					{"label": "[Stamina 13] \"I'll open at six. Bring him here.\"", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "flags": ["nadia_kid"]}, "next": "bye"},
					{"label": "\"You always say it's fine.\"", "effects": {"kiez": 0.5, "flags": ["nadia_seen"]}, "next": "bye"},
				],
			},
			"bye": {
				"speaker": "nadia", "expression": "warm",
				"lines": ["She takes the porter's coffee and holds it against her wrist for a second, for the warmth.", "\"This is the only place open that isn't a petrol station. You know that, ja? The chain shuts at eleven.\" A beat. \"You should sleep, by the way. Professionally speaking.\""],
				"choices": [
					{"label": "\"I'll be open at four. That's the whole offer.\"", "effects": {"kiez": 1.0, "flags": ["nadia_open_at_four"]}, "next": ""},
					{"label": "\"Professionally noted.\"", "next": ""},
				],
			},
		},
	},
	# ── Tobias: the big tip, the lanyard, and whose money is under the fund ────────────────────
	"tobias": {
		"start": "order",
		"nodes": {
			"order": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["\"Four Sternis, the chips, and one {brand.cigarettes} — love the pack, honestly, it's such a clean design. I only smoke when I drink, so, you know. Twice a week.\"", "Card out before you've scanned the first bottle. \"Keep the change. No — keep it, I mean it. This place is the reason I moved to this Kiez.\""],
				"choices": [
					{"label": "\"Thanks, Tobias.\" Take the tip, ring it straight.", "effects": {"cash": 5.0, "kiez": 0.5}, "next": "fund"},
					{"label": "[Kiez Sense 12] Read the lanyard he forgot to remove.", "check": {"stat": "wis", "dc": 12}, "next": "lanyard", "next_fail": "fund"},
					{"label": "[Schnauze 13] Ring the pack at tourist price.", "check": {"stat": "cha", "dc": 13}, "effects_success": {"cash": 3.0, "integrity": -2.0, "flags": ["tobias_gouged"]}, "effects_fail": {"kiez": -1.0}, "next": "fund", "next_fail": "fund"},
				],
			},
			"lanyard": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["A building pass. Fourth floor of the block on the corner — the one with the new glass and the old address.", "\"Oh — yeah, we moved in in August. Amazing space. Really respectful refurb, actually.\""],
				"choices": [
					{"label": "\"Respectful to who, Tobias?\"", "effects": {"flags": ["tobias_lindner"]}, "next": "lonely"},
					{"label": "Say nothing. File it.", "effects": {"flags": ["tobias_lindner"]}, "next": "fund"},
				],
			},
			"lonely": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["He comes in four nights a week. He knows your name, Mehmet's name and the dog's name. Nobody has ever come in *with* him.", "\"…You do the thing my dad does. With the face.\" He laughs at it and it doesn't quite take."],
				"choices": [
					{"label": "\"Come Thursday. There's a thing. Bring nobody.\"", "effects": {"kiez": 1.0, "flags": ["tobias_invited"]}, "next": "fund"},
					{"label": "\"Four Sternis and a packet. That's all I'm reading into it.\"", "next": "fund"},
				],
			},
			"fund": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["\"Actually — real thing. We're putting together a little Kiez fund. Local businesses, small grants, no strings. I put your name in.\"", "\"It'd cover, like, a year of your rent increase.\""],
				"choices": [
					{"label": "\"That's kind. I'll think about it.\"", "effects": {"flags": ["tobias_fund_offered"]}, "next": "night"},
					{"label": "[Brains 13] A fund needs a funder.", "check": {"stat": "int", "dc": 13}, "next": "lindner", "next_fail": "night"},
					{"label": "[Schnauze 15] Make him say the investor's name.", "requires": {"stat": "cha", "min": 15}, "effects": {"flags": ["tobias_fund_offered"]}, "next": "lindner"},
				],
			},
			"lindner": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["Three questions in he says it himself and doesn't hear it: the fund sits under the community budget, the Series B was led by a property group's venture arm, and the office lease has a break clause tied to the block's residential conversion completing by March.", "\"…Lindner. Yeah. But that's just capital, they don't *do* anything, they're an LP.\" A pause. \"That's bad, isn't it. That's why you went quiet.\""],
				"choices": [
					{"label": "\"March. Say that date again, slowly.\"", "effects": {"kiez": 1.0, "flags": ["tobias_digging", "main_lever_hint"]}, "next": "ask"},
					{"label": "\"Then I'll take the money and keep our prices.\"", "effects": {"cash": 60.0, "integrity": -3.0, "flags": ["tobias_lindner", "took_fund"]}, "next": "night"},
					{"label": "\"No fund. Just come in and buy beer like a person.\"", "effects": {"kiez": 1.0, "flags": ["tobias_lindner"]}, "next": "ask"},
				],
			},
			"ask": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["He puts the card away and pays cash, badly, counting twice.", "\"I didn't — I chose the office off a floorplan. That's genuinely how it happened.\""],
				"choices": [
					{"label": "\"I know. That's the whole problem, mate.\"", "effects": {"kiez": 1.0, "flags": ["tobias_warned"]}, "next": "night"},
					{"label": "\"Then find out what else you signed off a floorplan.\"", "effects": {"kiez": 1.0, "flags": ["tobias_warned", "tobias_digging"]}, "next": "night"},
				],
			},
			"night": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["\"Schönen Abend!\" — pronounced beautifully, practised — and he holds the door for the next guest, because he is, genuinely, quite nice."],
				"choices": [{"label": "\"Schönen Abend.\"", "next": ""}],
			},
		},
	},
	# ── Robin: the flat opener, which is a test, and the name they use now ─────────────────────
	"robin": {
		"start": "counter",
		"nodes": {
			"counter": {
				"speaker": "robin", "expression": "wary",
				"lines": ["\"{brand.tobacco} — {logo.tobacco} — {brand.papers}, and {brand.filters}. The slim ones, not the fat ones. And an energy and the gummi bears.\"", "\"This place is kind of depressing, by the way.\" Delivered completely flat, eyes on you, waiting."],
				"choices": [
					{"label": "\"It's a Späti at one in the morning. That's the genre.\"", "effects": {"kiez": 0.5}, "next": "roll"},
					{"label": "[Kiez Sense 12] That was a test, not an insult.", "check": {"stat": "wis", "dc": 12}, "next": "test", "next_fail": "roll"},
					{"label": "\"Then buy your gummi bears somewhere cheerful.\"", "effects": {"kiez": -1.5}, "next": "", "serve": false},
				],
			},
			"test": {
				"speaker": "robin", "expression": "surprised",
				"lines": ["They say something rude to everyone on the first go. Eleven months of it. It is cheaper to be thrown out on your own terms than on somebody else's.", "You put the tin down without a word and don't rise to it. Their whole face resets a millimetre."],
				"choices": [
					{"label": "\"Sit on the crate. It's warmer inside the door.\"", "effects": {"kiez": 1.5, "flags": ["robin_crate"]}, "next": "roll"},
					{"label": "\"Depressing is free. The energy drink is two twenty.\"", "effects": {"kiez": 1.0}, "next": "roll"},
				],
			},
			"roll": {
				"speaker": "robin", "expression": "neutral",
				"lines": ["They roll one on the counter, badly — too much in one end, the paper going soft at the seam. Third attempt.", "\"Don't. I know. I'm learning.\""],
				"choices": [
					{"label": "\"You're learning fine.\"", "next": "name"},
					{"label": "[Hands 12] Roll one and slide it over, no comment.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 1.5, "flags": ["robin_rolled"]}, "next": "name"},
					{"label": "\"Buy the ready-mades. Cheaper by the hour.\"", "next": "name"},
				],
			},
			"name": {
				"speaker": "robin", "expression": "wary",
				"lines": ["\"Put it on the tab thing. If you do tabs.\" A pause. \"Robin. With an i-n. Not what my bank card says — the card's my mum's old account, it's a whole thing.\"", "Said fast and flat, and their hand is very still on the counter."],
				"choices": [
					{"label": "Write ROBIN on the fridge list. \"Done.\"", "effects": {"kiez": 2.0, "flags": ["robin_name"]}, "next": "home"},
					{"label": "\"Robin. Got it.\" Use it again later, naturally.", "effects": {"kiez": 2.0, "flags": ["robin_name"]}, "next": "home"},
					{"label": "\"The card has to match the name, sorry.\"", "effects": {"kiez": -2.5, "integrity": -1.0}, "next": "home"},
				],
			},
			"home": {
				"speaker": "robin", "expression": "neutral",
				"lines": ["\"Halberstadt. Well — near it. Nobody's ever heard of the actual place, which was the best thing about leaving.\"", "\"Eleven months. My mum thinks I'm coming back in the summer.\""],
				"choices": [
					{"label": "\"Are you?\"", "effects": {"flags": ["robin_summer"]}, "next": "out"},
					{"label": "\"Berlin's full of people from near somewhere.\"", "effects": {"kiez": 1.0}, "next": "out"},
				],
			},
			"out": {
				"speaker": "robin", "expression": "warm",
				"lines": ["\"Anyway. Still depressing in here.\" The grin arrives about a second late, which is how you know it's real."],
				"choices": [{"label": "\"Bis morgen, Robin.\"", "next": ""}],
			},
		},
	},
	# ── Aylin: Sunday, 07:40, glitter, and a lighter. Always a lighter. ────────────────────────
	"aylin": {
		"start": "dawn",
		"nodes": {
			"dawn": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"Two Mate, a water, {qty.cigarettes}× {brand.cigarettes} — {logo.cigarettes} — und ein Feuerzeug.\"", "\"Don't say it. I know. Fourth one this month. They *leave*, Chef. I don't lose them, they emigrate.\""],
				"choices": [
					{"label": "Put the lighter on the counter without comment.", "next": "set"},
					{"label": "\"I'm starting a jar. Yours live here now.\"", "effects": {"kiez": 1.0, "flags": ["aylin_lighter_jar"]}, "next": "set"},
					{"label": "[Kiez Sense 12] She is holding one bag, not two.", "check": {"stat": "wis", "dc": 12}, "next": "jonas", "next_fail": "set"},
				],
			},
			"jonas": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["One bag. Seven years of Sundays and it has always been two bags, and Jonas holding both of them.", "\"He went home at two. He's been going home at two since March.\" The sentence is very even, which costs her something."],
				"choices": [
					{"label": "\"Two's a reasonable time to go home.\"", "effects": {"kiez": 0.5, "flags": ["aylin_jonas_two"]}, "next": "set"},
					{"label": "\"And you've been staying till seven.\"", "effects": {"kiez": 1.5, "flags": ["aylin_jonas_two", "aylin_named_it"]}, "next": "set"},
					{"label": "Ring it up. Not your business.", "effects": {"kiez": -0.5}, "next": "set"},
				],
			},
			"set": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"Second room, half four, this Italian woman with a modular rig — unbelievable. I nearly cried at a hi-hat.\"", "She is talking at about one and a half speed, which means the crash is due around nine."],
				"choices": [
					{"label": "\"Go home and sleep before it lands.\"", "next": "plans"},
					{"label": "[Stamina 13] Stay on the bench with her until it does.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.0, "flags": ["aylin_bench"]}, "next": "bench"},
				],
			},
			"bench": {
				"speaker": "aylin", "expression": "tired",
				"lines": ["It lands at twenty past eight, mid-sentence, somewhere between the van they're going to buy and the bar they're going to open in Portugal.", "\"…The bar's not real, is it.\" The Mate goes down on the bench between you. \"It was real in 2019.\""],
				"choices": [
					{"label": "\"The bench is real. Sunday's real. Start there.\"", "effects": {"kiez": 2.0, "flags": ["aylin_bench_talk"]}, "next": "plans"},
					{"label": "Say nothing. Let the street get light.", "effects": {"kiez": 1.5, "flags": ["aylin_bench_talk"]}, "next": "plans"},
				],
			},
			"plans": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"Next Sunday. Bench. Both of us, I'll drag him.\" She says *next Sunday* the way other people say *contract*.", "The glitter has got onto your counter and will still be there on Wednesday."],
				"choices": [
					{"label": "\"Bench is yours. It always was.\"", "effects": {"kiez": 1.0}, "next": "door"},
					{"label": "\"Bring him. I'll do two coffees.\"", "effects": {"kiez": 1.0, "flags": ["aylin_bring_jonas"]}, "next": "door"},
				],
			},
			"door": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["Halfway out she turns round. \"They're putting a fence round the bench side. Did you know that? There was a paper taped to the door.\""],
				"choices": [
					{"label": "\"…No. Bring me the paper, Aylin.\"", "effects": {"kiez": 1.0, "flags": ["aylin_fence", "main_lever_hint"]}, "next": ""},
					{"label": "\"I'll look tomorrow.\"", "effects": {"flags": ["aylin_fence"]}, "next": ""},
				],
			},
		},
	},
	# ── Herr Bley: 03:10, still water, and a term sheet he read on a Tuesday ───────────────────
	"bley": {
		"start": "three_am",
		"nodes": {
			"three_am": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["\"Water. Still — the other is undrinkable. A chocolate. And {qty.cigarettes}× {brand.cigarettes}.\"", "Good coat, good watch, and he has been standing at this counter for nine minutes over a four-euro transaction."],
				"choices": [
					{"label": "Ring it up at the speed he seems to want.", "next": "stays"},
					{"label": "\"Long night, or a short one?\"", "effects": {"kiez": 0.5}, "next": "stays"},
					{"label": "[Schnauze 12] Talk to him like a person, not a customer.", "check": {"stat": "cha", "dc": 12}, "next": "armour", "next_fail": "stays"},
				],
			},
			"stays": {
				"speaker": "bley", "expression": "wary",
				"lines": ["He does not leave. He turns the water bottle a quarter turn on the laminate. Twice.", "\"You are open at three. Remarkable. In Grunewald there is nothing open at three. Not even the people.\""],
				"choices": [
					{"label": "\"Somebody's always awake. I just sell to them.\"", "next": "tuesday"},
					{"label": "\"You drive here from Grunewald?\" (He does.)", "effects": {"kiez": 0.5}, "next": "tuesday"},
				],
			},
			"armour": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["\"Young man—\" and then he stops, and starts again without the young man. \"…Rüdiger. Bley. Since we appear to be doing this.\"", "\"Thirty-one years in corporate finance, and nobody at three in the morning has asked me a question that was not about a price.\""],
				"choices": [
					{"label": "\"Then I'll ask you one every night at three.\"", "effects": {"kiez": 1.5, "flags": ["bley_talks"]}, "next": "tuesday"},
					{"label": "\"Rüdiger. Noted. Chocolate's one forty.\"", "effects": {"kiez": 1.0, "flags": ["bley_talks"]}, "next": "tuesday"},
				],
			},
			"tuesday": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["\"This street, by the way. Somebody put a paper in front of me on Tuesday. Block acquisition, mixed use. A very tidy structure.\"", "\"I signed off the financing on page eleven and went to lunch. One does not look at the street name.\""],
				"choices": [
					{"label": "\"It's this street. You're standing in page eleven.\"", "effects": {"flags": ["bley_lindner"]}, "next": "close"},
					{"label": "\"Tidy for who?\"", "effects": {"kiez": 0.5, "flags": ["bley_lindner"]}, "next": "close"},
					{"label": "[Brains 14] What does page eleven actually give them?", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 1.0, "flags": ["bley_lindner"]}, "next": "clause"},
				],
			},
			"clause": {
				"speaker": "bley", "expression": "wary",
				"lines": ["The facility is conditional. Vacant possession on a fixed date, or the tranche is repriced — which means every week a tenant stays is a number on somebody's spreadsheet going the wrong way.", "\"…You understood that faster than my analyst.\" He looks at the shelf, the fridge, the hand-written prices. \"I would not repeat where you heard it.\""],
				"choices": [
					{"label": "\"I won't. What's the date?\"", "effects": {"kiez": 1.5, "flags": ["bley_tip", "main_lever_hint"]}, "next": "close"},
					{"label": "\"Write it down. Nothing with your name on it.\"", "effects": {"kiez": 2.0, "flags": ["bley_tip", "main_lever_hint"]}, "next": "close"},
					{"label": "\"You financed it. You can unfinance it.\"", "effects": {"kiez": 0.5, "integrity": 1.0, "flags": ["bley_tip"]}, "next": "close"},
				],
			},
			"close": {
				"speaker": "bley", "expression": "tired",
				"lines": ["He takes the water and leaves the chocolate. He leaves the chocolate most nights; you have started putting it out again.", "\"Same time tomorrow, then. Presumably you will still be open.\" It is, from him, an enormous sentence."],
				"choices": [
					{"label": "\"I'll be open.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Everyone else: the nameless parade. One node, {want} filled from what they came in for ──
	"oneoff": {
		"start": "order",
		"nodes": {
			"order": {
				"speaker": "", "expression": "neutral",
				"lines": ["\"{want}, please.\""],
				"choices": [
					{"label": "Here you go.", "next": ""},
					{"label": "\"{want}? We are out, sorry.\"", "effects": {"kiez": -0.5}, "next": "", "serve": false},
				],
			},
		},
	},
	# ── The same parade, under age, asking for something restricted. The counter used to refuse this
	#    silently, which turned "Here you go." into an unexplained Kiez tick; now the ID check IS the
	#    conversation and the Integrity decision is the player's. Choice 0 stays the honest one so the
	#    AutoPlayer (and `play.mjs`) never bleeds Integrity by walking the top line (docs/03 build log).
	"oneoff_minor": {
		"start": "order",
		"nodes": {
			"order": {
				"speaker": "", "expression": "neutral",
				"lines": ["\"{want}, please.\" The note is folded twice, and the eyes stay on the counter."],
				"choices": [
					# No `serve: false` on purpose: the counter refuses a restricted SKU to a minor by
					# itself, and marking this a wave-off would charge the player Kiez-Trust for
					# keeping the law. The refusal is free, and `_end_talk` puts it in the night log.
					{"label": "\"Ausweis, bitte.\" No ID, no sale.", "next": ""},
					{"label": "Ring up the {want} anyway.", "sell_restricted": true, "next": ""},
				],
			},
		},
	},
}
