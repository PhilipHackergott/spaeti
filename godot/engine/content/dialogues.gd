extends RefCounted
## Branching conversation graphs (docs/06-dialogue-and-stats.md §3) — DATA ONLY, no logic.
##
## A guest walks up, you take them with `talk_next`, and this is what the two of you say. ELEVEN
## regulars have their own tree (docs/09 §4: 5-8 nodes, at least two stat checks/gates, at least one
## gate that is LOCKED at day-one stats, an expression change per node, and the order woven into the
## first node); everyone else gets `oneoff`, whose single node substitutes `{want}` with the SKU they
## came in for.
##
## TREES ARE KEYED BY CHARACTER ID — AND, FROM THE SEASONS ON, BY ARC STEP.
## `Content.dialogue_id_for(character_id, state)` resolves three tiers, first hit wins:
##   1. `<char>_<season letter><step>`  the tree written for the step this guest is ON — `lena_s2`,
##      `achim_a3`, `bley_w5`, `karim_p7`. Letters: summer `s` · autumn `a` · winter `w` · SPRING `p`
##      (summer already owns `s`). The letter comes from the STEP's season, never from the calendar,
##      so a guest catching up on a summer step in February still opens the tree written for it.
##   2. `<char>`                        their plain tree — which IS step 1 for the eight new guests.
##   3. `oneoff`                        the nameless parade's.
## A tree named `achim_t` is still silently unreachable: the id has to be one of those three shapes.
## The selector reads `Content.DIALOGUES` for existence, so a lane ships `karim_a3` and it is live on
## the next night with no engine edit — there is no list of who has what anywhere in the reducer.
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
					{"label": "[Schnauze 15] \"Put it on the tab and go home, Lena.\"", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 1.5, "flags": ["lena_credit"]}, "next": "notice"},
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
	# ── Lena, SUMMER STEP 2 — "The Honest Piece" (docs/09 §2.1). THE WORKED EXAMPLE the content
	# lanes copy. Id convention: `<character>_<season letter><step>`, the letter taken from the STEP's
	# season (Season.of_step), never from the calendar — so `lena_s2` is her summer step 2 whether she
	# plays it in July or, catching up, in February. Five nodes · one d20 coin · one gate that is
	# LOCKED at day-one stats · a face change per node · the order woven into the first line · choice 0
	# never gated · four flags autumn's step 3 ("The Gallerist") reads back.
	"lena_s2": {
		"start": "tab",
		"nodes": {
			"tab": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["\"Mate, ein Schrippe, und {brand.tobacco} mit {brand.papers}.\" The portfolio is under her arm, and tonight she does not put it down on the floor.", "\"Tuesday. I know. I have Tuesday written down, ähm, somewhere.\""],
				"choices": [
					{"label": "\"The fridge door says Tuesday. The fridge is patient.\"", "effects": {"kiez": 0.5}, "next": "portfolio"},
					{"label": "[Kiez Sense 12] She is holding that folder like a shield.", "check": {"stat": "wis", "dc": 12}, "next": "portfolio", "next_fail": "deflect"},
					{"label": "\"Tuesday, Lena. I mean it this week.\"", "effects": {"kiez": -0.5}, "next": "deflect"},
				],
			},
			"portfolio": {
				"speaker": "lena", "expression": "upset",
				"lines": ["She opens it flat on the laminate, between the till and the Pfand crate, and turns it so it faces you. Not the clean ones.", "A kitchen at four in the morning, painted from the inside. It is very good and it is not sellable, and she knows both."],
				"choices": [
					{"label": "Look at it properly. Say nothing yet.", "effects": {"kiez": 1.5, "flags": ["lena_honest_piece"]}, "next": "hang"},
					{"label": "\"That one. Not the pretty ones. That one.\"", "effects": {"kiez": 2.0, "flags": ["lena_honest_piece", "lena_named_it"]}, "next": "hang"},
				],
			},
			"deflect": {
				"speaker": "lena", "expression": "upset",
				"lines": ["\"Ähm. Nothing. Studio stuff.\" The folder goes back under her arm corner-first, like a door being shut with a shoulder."],
				"choices": [
					{"label": "Let it go. Bag the Schrippe.", "next": "off"},
					{"label": "\"Bring it Tuesday. With the fifty cents.\"", "effects": {"kiez": 1.0}, "next": "off"},
				],
			},
			"hang": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["\"You can't hang that in a shop. It's a kitchen at four in the morning.\"", "She says it like an argument she is hoping to lose."],
				"choices": [
					{"label": "\"So is this. Bring it and I'll find a nail.\"", "effects": {"kiez": 1.0, "flags": ["lena_wall_offer"]}, "next": "off"},
					{"label": "[Hands 12] Tack it square on the glass, now.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.5, "flags": ["lena_wall_offer", "lena_hung_it"]}, "next": "off"},
					{"label": "\"Then keep it. I've seen it. That counts.\"", "effects": {"kiez": 0.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "lena", "expression": "warm",
				"lines": ["\"Okay. Okay.\" She takes the bag, leaves the Pfand on the counter the way she always does, and calls it forgetfulness so neither of you has to call it a tip."],
				"choices": [
					{"label": "\"Bis morgen, Lena.\"", "next": ""},
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
					{"label": "[Brains 14] Write his Widerspruch in lawyer German.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 1.5, "flags": ["mehmet_evidence"]}, "next": "rally"},
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
	# ── Frau Schulz, SUMMER STEP 2 — "Prices In Her Hand" (docs/09 §2.4). She brings her own pen.
	#    The carry flag `schulz_cards` is on EVERY choice of the opening node and on every choice of
	#    the `sc_prices` beat, and it is what `schulz/sc_verwaltung` gates on — so the autumn cannot
	#    arrive before the price cards do, and no branch of either can strand the arc.
	"schulz_s2": {
		"start": "pen",
		"nodes": {
			"pen": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["\"{qty.schrippe} Schrippen, the milk, the chocolate. And {qty.cigarettes}× {brand.cigarettes}, without filter, while the wall still has them.\"", "Out of the net bag comes a pen with a cap on it. She puts it down on the laminate between you and does not explain why."],
				"choices": [
					{"label": "\"Say them and I'll write them.\"", "effects": {"kiez": 1.0, "flags": ["schulz_cards"]}, "next": "dictate"},
					{"label": "[Kiez Sense 12] The pen came out before the purse.", "check": {"stat": "wis", "dc": 12}, "effects": {"flags": ["schulz_cards"]}, "next": "pfennig", "next_fail": "dictate"},
					{"label": "\"The strips come printed with the shelf.\"", "effects": {"kiez": -0.5, "flags": ["schulz_cards"]}, "next": "printed"},
				],
			},
			"pfennig": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["She has priced this shop in her head since before the sign changed, and tonight she wants one of those numbers said out loud by somebody else.", "\"Schrippe, five Pfennig. Milk, sixty-eight. You will laugh at that, Junge, and then you will do the sums.\""],
				"choices": [
					{"label": "\"Nobody's laughing. Say the next one.\"", "effects": {"kiez": 1.5}, "next": "dictate"},
					{"label": "\"Sixty-eight. And now two twenty-nine.\"", "effects": {"kiez": 1.0}, "next": "dictate"},
				],
			},
			"dictate": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["\"Big. Square. Number first, then the word — never the other way round. A person reads the number from the door.\"", "It is a dispatcher's instruction. She has given it ten thousand times, to men who wrote it down wrong."],
				"choices": [
					{"label": "Write them her way. Slowly.", "effects": {"kiez": 1.0}, "next": "eyes"},
					{"label": "[Hands 12] Letter the whole rack in her hand.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.5, "flags": ["schulz_own_hand"]}, "next": "eyes"},
					{"label": "\"Number first. Fine.\" Do three and stop.", "effects": {"kiez": 0.5}, "next": "eyes"},
				],
			},
			"printed": {
				"speaker": "schulz", "expression": "tired",
				"lines": ["She holds the printed strip at arm's length, then closer, then gives up on it and puts it back on the shelf face down.", "\"Your uncle wrote mine. That is all. I am not asking for the moon, I am asking for a card.\""],
				"choices": [
					{"label": "Take the pen. Start with the milk.", "effects": {"kiez": 1.5}, "next": "dictate"},
					{"label": "\"Friday. I'll have them done by Friday.\"", "effects": {"kiez": 0.5}, "next": "eyes"},
				],
			},
			"eyes": {
				"speaker": "schulz", "expression": "surprised",
				"lines": ["She walks to the door and reads the milk card from there, out loud, the way you read a departure board.", "\"Zwei neunundzwanzig.\" A pause. \"I have not read a price in this shop from this distance since the spring.\""],
				"choices": [
					{"label": "\"Then they all get done that size.\"", "effects": {"kiez": 2.0}, "next": "off"},
					{"label": "Say nothing. Write the next one bigger.", "effects": {"kiez": 1.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "schulz", "expression": "warm",
				"lines": ["The pen goes back in the net bag, capped. The chocolate goes in last, on top, where it will not get squashed.", "\"Do the tobacco strip as well. While there is still tobacco on it.\""],
				"choices": [
					{"label": "\"Bis Freitag, Frau Schulz.\"", "next": ""},
				],
			},
		},
	},
	# ── Frau Schulz, AUTUMN STEP 3 — "A Man From The Verwaltung Came". Brandt's soft approach, at her
	#    door, in a good coat. The Brains gate is the Umlage cap, written wrong in their favour.
	"schulz_a3": {
		"start": "coat",
		"nodes": {
			"coat": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["\"{qty.schrippe} Schrippen. The milk. {qty.cigarettes}× {brand.cigarettes}.\" Then, in exactly the same voice: \"A man from the Verwaltung came to my door.\"", "\"Good coat. He said Modernisierung, and he said it slowly. For the old lady.\""],
				"choices": [
					{"label": "\"What did he leave you?\"", "effects": {"kiez": 1.0, "flags": ["schulz_verwaltung"]}, "next": "folder"},
					{"label": "[Kiez Sense 13] She has read it twice already.", "check": {"stat": "wis", "dc": 13}, "effects": {"flags": ["schulz_verwaltung"]}, "next": "slowly", "next_fail": "folder"},
					{"label": "\"They go door to door. It's nothing yet.\"", "effects": {"kiez": -0.5, "flags": ["schulz_verwaltung"]}, "next": "folder"},
				],
			},
			"slowly": {
				"speaker": "schulz", "expression": "tired",
				"lines": ["The folder has been on her table since Tuesday, in the spot where she can see it from the chair, and she has not moved it and she has not opened it again.", "\"I have been offered a better flat by better-dressed people before. In '92 as well. They were also very kind about it.\""],
				"choices": [
					{"label": "\"Then we read it here, where it's bright.\"", "effects": {"kiez": 1.5}, "next": "folder"},
					{"label": "Put the chocolate on the counter. No charge.", "effects": {"kiez": 1.5, "cash": -1.4}, "next": "folder"},
				],
			},
			"folder": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["It comes out of the net bag, flattened, corner-worn. Modernisierungsankündigung. Twelve pages, and the number that matters sits on page nine in the same size as everything else.", "\"He said it improves the building. He used that word four times. I counted, Junge — it is what I did for a living.\""],
				"choices": [
					{"label": "\"Bring it Friday. I'll read all twelve.\"", "effects": {"kiez": 1.5, "flags": ["schulz_folder"]}, "next": "table"},
					{"label": "[Brains 14] Read the Umlage cap out loud, now.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 2.0, "flags": ["schulz_clause", "schulz_folder"]}, "next": "clause"},
					{"label": "\"Sign nothing. That's the whole of my advice.\"", "effects": {"kiez": 1.0}, "next": "table"},
				],
			},
			"clause": {
				"speaker": "schulz", "expression": "surprised",
				"lines": ["Eleven percent of the works, onto the rent, for ever — and the cap that is supposed to sit under it has been written with the wrong year inside it.", "\"So it is a mistake.\" She looks at you over the top of the page. \"Or it is not a mistake.\""],
				"choices": [
					{"label": "\"It's the same letter Mehmet got.\"", "effects": {"kiez": 2.0}, "next": "table"},
					{"label": "\"It's not a mistake, Frau Schulz.\"", "effects": {"kiez": 1.5}, "next": "table"},
				],
			},
			"table": {
				"speaker": "schulz", "expression": "tired",
				"lines": ["The folder goes back in the bag under the Schrippen, to sit on the table again, in the spot where she can see it from the chair.", "\"Fourth floor, no lift. He did not come up, you know. He rang from downstairs and made me come to the door.\""],
				"choices": [
					{"label": "\"Next time, you don't answer it.\"", "effects": {"kiez": 1.0}, "next": "off"},
					{"label": "\"Next time, ring me. I'll come up.\"", "effects": {"kiez": 2.0}, "next": "off"},
				],
			},
			"off": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["\"Na dann.\" The bell takes her out into the cold. She checks both ways twice, out of habit from a different city."],
				"choices": [
					{"label": "\"Bis morgen, Frau Schulz.\"", "next": ""},
				],
			},
		},
	},
	# ── Frau Schulz, AUTUMN STEP 4 — "Holding Court". She tells it whether you listen or not, and
	#    tonight three people at the beer fridge are the room. The Stamina gate is staying open for it.
	"schulz_a4": {
		"start": "court",
		"nodes": {
			"court": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["\"{qty.schrippe} Schrippen, the milk, {qty.cigarettes}× {brand.cigarettes}\" — and she is already talking past you, at three people standing in front of the beer fridge who did not ask.", "\"The Konsum stood here. Until March '91. Then a video shop, then four years of nothing, then this.\""],
				"choices": [
					{"label": "Turn the radio off and let her run.", "effects": {"kiez": 1.5, "flags": ["schulz_court"]}, "next": "radio"},
					{"label": "[Schnauze 12] \"Tell them what was on the other corner.\"", "check": {"stat": "cha", "dc": 12}, "effects": {"flags": ["schulz_court"]}, "next": "young", "next_fail": "radio"},
					{"label": "\"Frau Schulz. The gentleman is waiting.\"", "effects": {"kiez": -1.0, "flags": ["schulz_court"]}, "next": "queue"},
				],
			},
			"radio": {
				"speaker": "schulz", "expression": "warm",
				"lines": ["The shop goes quiet except for the fridges. She does not thank you and she does not stop.", "\"Bäckerei, then the shoe repair, then the man who sharpened knives on a Thursday. One leg, and a better temper than any of you.\""],
				"choices": [
					{"label": "\"Keep going.\"", "effects": {"kiez": 1.0}, "next": "young"},
					{"label": "Lean on the till and listen properly.", "effects": {"kiez": 1.5}, "next": "young"},
				],
			},
			"queue": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["She stops mid-sentence, which she has had a lifetime of practice at, and hands you the exact coins in the exact order.", "\"Quite right. A shop is a shop. I will tell it to the wall at home. It is a good listener.\""],
				"choices": [
					{"label": "\"That came out wrong. Start again.\"", "effects": {"kiez": 1.0}, "next": "radio"},
					{"label": "Ring it through. Say nothing.", "effects": {"kiez": -0.5}, "next": "late"},
				],
			},
			"young": {
				"speaker": "schulz", "expression": "surprised",
				"lines": ["One of the three has put his beer back on the shelf. He asks her which year the video shop closed, and he means it.", "She answers with the month. Then she looks at you as though you had done something."],
				"choices": [
					{"label": "\"She does this every Friday, by the way.\"", "effects": {"kiez": 2.0, "flags": ["schulz_heard"]}, "next": "late"},
					{"label": "Pull the crate out. Give her somewhere to sit.", "effects": {"kiez": 2.0, "flags": ["schulz_heard"]}, "next": "late"},
				],
			},
			"late": {
				"speaker": "schulz", "expression": "tired",
				"lines": ["It is twenty past, the shutter should be half down, and she is at the year the Wall opened with her coat still on.", "\"I watched it from this corner. At that window. With a Mokka going cold in my hand.\""],
				"choices": [
					{"label": "\"Finish it. The shutter can wait.\"", "effects": {"kiez": 1.5}, "next": "off"},
					{"label": "[Stamina 13] Stay open. Let the whole night run late.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "flags": ["schulz_heard"]}, "next": "off"},
					{"label": "\"Tomorrow. I'll keep the crate out for you.\"", "effects": {"kiez": 0.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "schulz", "expression": "warm",
				"lines": ["The net bag goes over her wrist, and the three at the fridge say goodnight to her, which has not happened on this corner in some years.", "\"Hm,\" she says, to nobody in particular. \"They stood still.\""],
				"choices": [
					{"label": "\"They did. Bis morgen.\"", "next": ""},
				],
			},
		},
	},
	# ── Frau Schulz, WINTER STEP 5 — "They Take The Signal Box Down". The last landmark she worked
	#    in. The Muscle gate is walking down there with her, in February, carrying the bag.
	"schulz_w5": {
		"start": "thursday",
		"nodes": {
			"thursday": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["\"{qty.schrippe} Schrippen. {qty.cigarettes}× {brand.cigarettes}.\" The coins go down. \"They are taking the box down on Thursday.\"", "She says it the way she used to say a departure time: flat, exact, and not open to discussion."],
				"choices": [
					{"label": "\"Which box, Frau Schulz?\"", "effects": {"flags": ["schulz_signal"]}, "next": "ostkreuz"},
					{"label": "[Kiez Sense 13] She has not taken her coat off.", "check": {"stat": "wis", "dc": 13}, "effects": {"flags": ["schulz_signal"]}, "next": "stayed", "next_fail": "ostkreuz"},
					{"label": "\"They'll put a plaque on it. They always do.\"", "effects": {"kiez": -0.5, "flags": ["schulz_signal"]}, "next": "plaque"},
				],
			},
			"ostkreuz": {
				"speaker": "schulz", "expression": "tired",
				"lines": ["\"Ostkreuz. The brick one on the north side, with the iron stair. I sat in it for twenty-nine years and moved trains through this city in the dark.\"", "\"There is no lever left in it. They took those in '97. It is a brick box standing in the way of something.\""],
				"choices": [
					{"label": "\"Then Thursday we go and watch it go.\"", "effects": {"kiez": 2.0}, "next": "bridge"},
					{"label": "[Muscle 11] Carry her bag. Walk her down there now.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.5, "flags": ["schulz_saw_it_go"]}, "next": "bridge"},
					{"label": "\"Twenty-nine years is a long time.\"", "effects": {"kiez": 0.5}, "next": "bridge"},
				],
			},
			"plaque": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["\"A plaque.\" She turns the word over like a coin she suspects. \"They put a plaque on the Vorderhaus as well. Next to the keypad.\"", "\"A plaque is what you give a thing instead of leaving it standing.\""],
				"choices": [
					{"label": "\"Fair. Tell me about the box.\"", "effects": {"kiez": 1.0}, "next": "ostkreuz"},
					{"label": "\"Then we'll remember it properly instead.\"", "effects": {"kiez": 1.5}, "next": "ostkreuz"},
				],
			},
			"stayed": {
				"speaker": "schulz", "expression": "tired",
				"lines": ["The coat is buttoned, the bag is on her wrist, and she is standing the way a person stands who has already decided not to stay for an answer.", "\"I am not stopping. I only wanted it said out loud in a room with the light on.\""],
				"choices": [
					{"label": "\"It's said. Stop anyway.\"", "effects": {"kiez": 2.0}, "next": "ostkreuz"},
					{"label": "\"Say it again. I'm listening properly now.\"", "effects": {"kiez": 1.5}, "next": "ostkreuz"},
				],
			},
			"bridge": {
				"speaker": "schulz", "expression": "surprised",
				"lines": ["From the corner of the bridge you can see the iron stair and the little windows, all lit for the works, brighter than they ever were on a shift.", "\"They have put floodlights on it,\" she says. \"Twenty-nine years I asked for one bulb.\""],
				"choices": [
					{"label": "Laugh. She started it.", "effects": {"kiez": 1.5}, "next": "off"},
					{"label": "\"Tell me what you did in there. Once.\"", "effects": {"kiez": 2.0}, "next": "off"},
				],
			},
			"off": {
				"speaker": "schulz", "expression": "warm",
				"lines": ["\"Na.\" The bag comes off the counter. \"Thursday, then. If the world is still standing on Thursday.\""],
				"choices": [
					{"label": "\"Thursday, Frau Schulz.\"", "next": ""},
				],
			},
		},
	},
	# ── Frau Schulz, WINTER STEP 6 — "They Do Want The Stories". The self-revelation: they were hers
	#    to GIVE, not to hoard. This tree sets `schulz_listen`, which is the gate on her SPRING beat —
	#    so a player who brushed her off in the summer can still earn the Kiezversammlung here.
	"schulz_w6": {
		"start": "recorder",
		"nodes": {
			"recorder": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["\"{qty.schrippe} Schrippen, and {qty.cigarettes}× {brand.cigarettes} while they last.\" Then: \"A student put a telephone on my table and asked me to talk into it.\"", "\"I said no. Quite sharply, actually. She was perfectly polite about it, which made it worse.\""],
				"choices": [
					{"label": "\"Why did you say no?\"", "effects": {"kiez": 1.0, "flags": ["schulz_listen"]}, "next": "hoard"},
					{"label": "[Brains 13] She wants the years, not the feelings.", "check": {"stat": "int", "dc": 13}, "effects": {"flags": ["schulz_listen"]}, "next": "list", "next_fail": "hoard"},
					{"label": "\"Quite right. She only wants a grade out of it.\"", "effects": {"kiez": -0.5, "flags": ["schulz_listen"]}, "next": "refuse"},
				],
			},
			"hoard": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["\"Because if I tell it, it is hers.\" The purse clasp opens and shuts once. \"And while I do not tell it, it is still mine.\"", "\"That is a very small thing to own, Junge. I am aware of that. It is what is left.\""],
				"choices": [
					{"label": "\"It stops being yours when nobody has it.\"", "effects": {"kiez": 2.0}, "next": "list"},
					{"label": "\"Tell it to me, then. I'll hold it badly.\"", "effects": {"kiez": 1.5}, "next": "list"},
				],
			},
			"refuse": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["She does not argue, which is somehow worse than being contradicted, and counts out the coins without looking up from them.", "\"She had her grandmother's name written at the top of the page. Not mine. Her own.\""],
				"choices": [
					{"label": "\"Then she wasn't collecting. She was asking.\"", "effects": {"kiez": 1.5}, "next": "hoard"},
					{"label": "\"…She came back twice, didn't she.\"", "effects": {"kiez": 1.0}, "next": "hoard"},
				],
			},
			"list": {
				"speaker": "schulz", "expression": "surprised",
				"lines": ["She starts, and it is not a memory, it is a schedule. Konsum until March '91. Video shop, '91 to '95. Nothing, '95 to '99. Handyladen. Nothing. Cem.", "\"Four streets, Junge. I can do all four. Nobody has ever asked me for all four.\""],
				"choices": [
					{"label": "\"Do the next street. I'll keep up.\"", "effects": {"kiez": 2.0}, "next": "window"},
					{"label": "[Hands 12] Letter the whole list for the window.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.5, "flags": ["schulz_wall_list"]}, "next": "window"},
					{"label": "\"Give the student the years. Keep the rest.\"", "effects": {"kiez": 1.0}, "next": "window"},
				],
			},
			"window": {
				"speaker": "schulz", "expression": "warm",
				"lines": ["What goes in the glass, under the price cards, is a list of what stood on this corner and when it stopped. People read it. They stand there with a Sterni and read all of it.", "\"They do want them,\" she says, as if catching herself out. \"That is a nuisance. I had got used to the other thing.\""],
				"choices": [
					{"label": "\"Get used to this one. It's Friday work now.\"", "effects": {"kiez": 2.0}, "next": "off"},
					{"label": "\"Bring me the next street on Friday.\"", "effects": {"kiez": 1.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "schulz", "expression": "tired",
				"lines": ["She is at the door before she says it, facing out, which is the only way she can. \"Tell the girl with the telephone that Thursday suits me better than Tuesday.\""],
				"choices": [
					{"label": "\"I'll tell her Thursday.\"", "next": ""},
				],
			},
		},
	},
	# ── Frau Schulz, SPRING STEP 7 — "The Corner's Memory". She narrates the Kiezversammlung and the
	#    room goes quiet. The Schnauze gate is the one docs/09 §0 reserves for the rare occasion:
	#    handing her the room before anybody else can fill it.
	"schulz_p7": {
		"start": "chairs",
		"nodes": {
			"chairs": {
				"speaker": "schulz", "expression": "neutral",
				"lines": ["An hour before the Versammlung: \"{qty.schrippe} Schrippen, the milk, {qty.cigarettes}× {brand.cigarettes}. And do not make a fuss of me at seven o'clock.\"", "\"Will there be chairs? There is no point in a Versammlung where people stand. They leave.\""],
				"choices": [
					{"label": "\"Forty. Achim counted them twice.\"", "effects": {"kiez": 1.0, "flags": ["schulz_corner"]}, "next": "stand"},
					{"label": "[Kiez Sense 12] She has written something on a card.", "check": {"stat": "wis", "dc": 12}, "effects": {"flags": ["schulz_corner"]}, "next": "card", "next_fail": "stand"},
					{"label": "\"You don't have to come, Frau Schulz.\"", "effects": {"kiez": -0.5, "flags": ["schulz_corner"]}, "next": "stand"},
				],
			},
			"card": {
				"speaker": "schulz", "expression": "wary",
				"lines": ["Half out of the net bag: a price card, blank side up, covered in the dispatcher's hand. Not a speech. A list of years, each with a building beside it.", "\"It is so that I do not wander,\" she says, and puts it away. \"I have seen old women wander at those things.\""],
				"choices": [
					{"label": "\"You won't wander. You never have.\"", "effects": {"kiez": 1.5}, "next": "stand"},
					{"label": "\"Read it off the card. Nobody will mind.\"", "effects": {"kiez": 1.0}, "next": "stand"},
				],
			},
			"stand": {
				"speaker": "schulz", "expression": "surprised",
				"lines": ["Forty people on plastic chairs in front of your shutter, and nobody wants to be the one who speaks first. Frau Schulz stands up without being asked.", "The Verwaltung has sent a young man with a lanyard and a laptop. He is still working out which of you is in charge."],
				"choices": [
					{"label": "\"Frau Schulz has the floor.\"", "effects": {"kiez": 2.0}, "next": "quiet"},
					{"label": "[Schnauze 15] Give her the room before anyone else speaks.", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 3.0, "flags": ["schulz_narrated"]}, "next": "quiet"},
					{"label": "Do the agenda first. Let her go third.", "effects": {"kiez": 0.5}, "next": "quiet"},
				],
			},
			"quiet": {
				"speaker": "schulz", "expression": "warm",
				"lines": ["\"I have bought bread on this corner under three signs and two countries,\" she says, \"and I will tell you what stood here. Then you will tell me what you intend to put in its place.\"", "Forty people go quiet. The young man stops typing, which is the loudest thing in the street."],
				"choices": [
					{"label": "Sit down at the back and let it run.", "effects": {"kiez": 3.0, "integrity": 1.0}, "next": "off"},
					{"label": "Chalk the years on the shutter as she says them.", "effects": {"kiez": 2.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "schulz", "expression": "tired",
				"lines": ["Afterwards she is the last to leave, because forty chairs do not stack themselves and she has opinions about how.", "\"Same time Friday. And the milk card has gone crooked, Junge. I can see it from here.\""],
				"choices": [
					{"label": "\"I'll straighten it. Bis Freitag.\"", "next": ""},
				],
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
	# ── Achim, SUMMER STEP 2 — "Can I Put This In Your Window" (docs/09 §2.5). The poster is already
	#    printed; the question was never really a question. The carry flag `achim_window` is on every
	#    choice of the opening node and on every choice of the `a_window` beat, and `achim/a_spaetkauf`
	#    gates on it. `flyers_up` is the corner-status flag Economy.FLAG_LABEL already prints.
	#    Only tobacco/papers/filters are spoken: the Sterni and the lighter carry no brand.
	"achim_s2": {
		"start": "flyer",
		"nodes": {
			"flyer": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["\"{qty.tobacco}× fifty of {brand.tobacco}, {brand.papers}, {brand.filters} — slim, I've told you, I'm not a plumber — Sterni, cheap lighter.\"", "Then the A3 comes out of the jacket, still warm from somebody's work printer. BENEFIZ. SAMSTAG. The typeface is a crime and the cause is not."],
				"choices": [
					{"label": "Tape it up. Centre of the glass.", "effects": {"kiez": 1.5, "flags": ["achim_window", "flyers_up"]}, "next": "tape"},
					{"label": "[Schnauze 12] Half the window, down on Monday.", "check": {"stat": "cha", "dc": 12}, "effects": {"flags": ["achim_window"]}, "next": "deal", "next_fail": "tape"},
					{"label": "\"Inside the door, Achim. That's my glass.\"", "effects": {"kiez": 0.5, "flags": ["achim_window"]}, "next": "inside"},
				],
			},
			"deal": {
				"speaker": "achim", "expression": "warm",
				"lines": ["\"Half. Monday. Done.\" He agrees inside a second and is then visibly delighted to have negotiated something, which he has not done since 2011.", "\"See, that's a deal, that is. Cem never made a deal. Cem just said no and then did it anyway.\""],
				"choices": [
					{"label": "\"Half the window, Achim. Measured.\"", "effects": {"kiez": 1.0}, "next": "benefit"},
					{"label": "\"He said no to you?\" \"Constantly.\"", "effects": {"kiez": 1.5}, "next": "benefit"},
				],
			},
			"tape": {
				"speaker": "achim", "expression": "surprised",
				"lines": ["He watches you do it from the pavement side, through the glass, and corrects the angle twice with a hand, like a man landing a plane.", "\"Left. LEFT. — no. There. That's it. That's the one people read from the bus.\""],
				"choices": [
					{"label": "\"It's a poster, not a PA rig.\"", "effects": {"kiez": 0.5}, "next": "benefit"},
					{"label": "[Hands 12] Square it to the frame. First go.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.0, "flags": ["achim_square"]}, "next": "benefit"},
					{"label": "Let him come round and do it himself.", "effects": {"kiez": 1.0}, "next": "benefit"},
				],
			},
			"inside": {
				"speaker": "achim", "expression": "upset",
				"lines": ["\"Inside the door is a coffin, mate. Inside the door is where flyers go to be pulped in a fortnight by a man with a bin bag.\"", "He tapes it up inside the door anyway, at exactly eye height, because he is not actually going to argue with the man who sells him tobacco."],
				"choices": [
					{"label": "\"Eye height's good. That was smart.\"", "effects": {"kiez": 1.0}, "next": "benefit"},
					{"label": "\"Ask me again for the window on Saturday.\"", "effects": {"kiez": 1.0}, "next": "benefit"},
				],
			},
			"benefit": {
				"speaker": "achim", "expression": "warm",
				"lines": ["The gig is a benefit. Six bands, four of them bad, all of it for one woman's legal costs against a Räumungsklage on the next street.", "\"Forty euro a head at the door would cover it. We'll get nine euro and a bucket of coins and we'll cover it anyway. That's how it works.\""],
				"choices": [
					{"label": "\"Put the bucket on my counter Saturday.\"", "effects": {"kiez": 2.0}, "next": "off"},
					{"label": "\"Who is she?\" \"Nobody you've met. Yet.\"", "effects": {"kiez": 1.0}, "next": "off"},
				],
			},
			"off": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["He leaves the exact money, to the cent, as always, and takes his five things off the laminate in one sweep.", "\"Saturday. Bring the whole Kiez or bring nobody, but bring yourself.\""],
				"choices": [
					{"label": "\"Saturday.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Achim, AUTUMN STEP 3 — "The Spätkauf Opens". He is unbearable about it and completely right.
	#    The Stamina gate is shutting your own till for ten minutes to go and look at theirs.
	"achim_a3": {
		"start": "neon",
		"nodes": {
			"neon": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["\"{brand.tobacco}, {brand.papers}, {brand.filters}, Sterni, lighter — and have you SEEN it? Down the block. The blue sign. You can read it from the S-Bahn.\"", "He has not put his money down yet. That is how you know this is going to take a while."],
				"choices": [
					{"label": "\"I've seen it, Achim.\"", "effects": {"flags": ["achim_chain"]}, "next": "rant"},
					{"label": "[Brains 11] Do their margin on a Sterni out loud.", "check": {"stat": "int", "dc": 11}, "effects": {"flags": ["achim_chain"]}, "next": "maths", "next_fail": "rant"},
					{"label": "\"Competition's competition.\"", "effects": {"kiez": -0.5, "flags": ["achim_chain"]}, "next": "rant"},
				],
			},
			"maths": {
				"speaker": "achim", "expression": "surprised",
				"lines": ["Twenty-two cents a bottle, before the rent on a corner unit that size. They are not making money on beer. They are making it on being there when nothing else is.", "\"…So they're not a Späti. They're a car park that sells Sterni.\" He is thrilled with himself."],
				"choices": [
					{"label": "\"They're a leasehold with a light on.\"", "effects": {"kiez": 1.0}, "next": "rant"},
					{"label": "\"Don't put that on a poster.\" \"Too late.\"", "effects": {"kiez": 1.5}, "next": "rant"},
				],
			},
			"rant": {
				"speaker": "achim", "expression": "upset",
				"lines": ["\"App. QR code where the till should be. A CONCEPT, mate, they've got a concept, it's on a card by the door, I read all of it standing there like a lemon.\"", "\"And they shut at eleven. Eleven! That's not a Späti, that's a chemist with ideas.\""],
				"choices": [
					{"label": "Let him run. Don't fill the gap.", "effects": {"kiez": 0.5}, "next": "bins"},
					{"label": "[Stamina 13] Shut for ten minutes. Go and look.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.0, "flags": ["achim_scouted"]}, "next": "bins"},
					{"label": "\"Eleven o'clock is half my night, Achim.\"", "effects": {"kiez": 1.0}, "next": "bins"},
				],
			},
			"bins": {
				"speaker": "achim", "expression": "upset",
				"lines": ["The thing he saves for last, because it is the one that actually got him: they have put a padlock through the handle of the Pfand bin at the side door.", "\"A padlock. On bottles. Bottles they've already been paid the deposit on. Who is that FOR?\""],
				"choices": [
					{"label": "\"Jürgen's route goes past there twice a night.\"", "effects": {"kiez": 1.5}, "next": "off"},
					{"label": "\"Then our crate stays out. All night.\"", "effects": {"kiez": 2.0}, "next": "off"},
				],
			},
			"off": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["The exact money, to the cent. He gets to the door and turns round with one finger up, which means there is a coda.", "\"They'll have a loyalty scheme by Christmas. Mark it. A loyalty scheme, on a corner, where the whole point is that nobody has to earn anything.\""],
				"choices": [
					{"label": "\"Good night, Achim.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Achim, AUTUMN STEP 4 — "The Folding Table". He starts organising before anybody asks him to.
	#    The Muscle gate is the PA up out of his cellar; the Kiez Sense check is why he is really here.
	"achim_a4": {
		"start": "table",
		"nodes": {
			"table": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["There is a folding table outside your door. On it: a clipboard, a biro on a string, and a Sterni that is not yours.", "\"{brand.tobacco}, {brand.papers}, {brand.filters}. And forty-one signatures, and I told them you'd sign it, so don't make a liar of me at my age.\""],
				"choices": [
					{"label": "\"Where did the table come from?\"", "effects": {"flags": ["achim_table"]}, "next": "clipboard"},
					{"label": "[Kiez Sense 12] He needed somewhere to be tonight.", "check": {"stat": "wis", "dc": 12}, "effects": {"flags": ["achim_table"]}, "next": "lonely", "next_fail": "clipboard"},
					{"label": "\"Off the pavement. I'll get fined for that.\"", "effects": {"kiez": -1.0, "flags": ["achim_table"]}, "next": "fined"},
				],
			},
			"clipboard": {
				"speaker": "achim", "expression": "warm",
				"lines": ["\"Cellar. It's been down there since the Kastanienallee thing. Laminator's down there too, and the small PA, and about nine hundred flyers for a club that shut in 2009.\"", "Forty-one names. Two of them are in the same handwriting and he knows it and has left them in anyway."],
				"choices": [
					{"label": "Sign it. Put the clipboard by the till.", "effects": {"kiez": 2.0, "flags": ["achim_clipboard"]}, "next": "sign"},
					{"label": "[Muscle 11] Bring the PA up out of the cellar too.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.5, "flags": ["achim_carried", "achim_clipboard"]}, "next": "sign"},
					{"label": "\"Two of these are the same hand, Achim.\"", "effects": {"kiez": 0.5}, "next": "sign"},
				],
			},
			"lonely": {
				"speaker": "achim", "expression": "upset",
				"lines": ["It is a Tuesday. There is no gig, no load-in, no crew, and there has not been for eleven weeks. The table went up at six and he has been standing behind it since.", "\"…What. It's a petition. People sign petitions. Don't do the face, it's a table.\""],
				"choices": [
					{"label": "\"Bring it inside. Sign people up in the warm.\"", "effects": {"kiez": 2.0}, "next": "clipboard"},
					{"label": "\"Tuesday's a good night for it. Busy.\"", "effects": {"kiez": 1.5}, "next": "clipboard"},
				],
			},
			"fined": {
				"speaker": "achim", "expression": "upset",
				"lines": ["\"Fined.\" He folds the legs in with two bangs that can be heard from the bus stop. \"Forty years I've put tables on pavements in this city and the only man who ever moved one was a Vopo.\"", "He stands there holding it. He has nowhere else to put it and both of you know it."],
				"choices": [
					{"label": "\"Inside the door, then. By the crate.\"", "effects": {"kiez": 1.5}, "next": "clipboard"},
					{"label": "\"…Half on the pavement. I'll pay the fine.\"", "effects": {"kiez": 2.0, "cash": -25.0}, "next": "clipboard"},
				],
			},
			"sign": {
				"speaker": "achim", "expression": "surprised",
				"lines": ["You sign it. He does not make a thing of it — no speech, no hard consonant — he just squares the sheet up on the clipboard and clips it down.", "\"Right,\" he says, quietly, once. Then, at full volume, to the whole shop: \"HE'S SIGNED IT.\""],
				"choices": [
					{"label": "\"Everyone heard, Achim.\"", "effects": {"kiez": 1.0}, "next": "off"},
					{"label": "Put the clipboard where the Pfand crate is.", "effects": {"kiez": 1.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["The table goes under his arm, folded, with the clipboard inside it, the way it will go under his arm about thirty more times before the spring.", "\"Same time tomorrow. Sixty by Friday or I'll have wasted a laminator.\""],
				"choices": [
					{"label": "\"Sixty by Friday.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Achim, WINTER STEP 5 — "The Squat Becomes Lofts". With a plaque about its history, next to a
	#    keypad. The Brains gate is reading what the plaque actually says; the Schnauze check turns
	#    the grief into a plan, which is the only place he has ever been able to put it.
	"achim_w5": {
		"start": "plaque",
		"nodes": {
			"plaque": {
				"speaker": "achim", "expression": "upset",
				"lines": ["\"{brand.tobacco}. {brand.papers}. {brand.filters}.\" Flat. No filter joke, which from him is a siren.", "\"They've finished the Vorderhaus. Eleven years we held that building. There's a plaque on it now. A PLAQUE. About us. Next to a keypad we couldn't get through.\""],
				"choices": [
					{"label": "\"A plaque about you.\"", "effects": {"flags": ["achim_lofts"]}, "next": "names"},
					{"label": "[Schnauze 13] \"Then be a nuisance about it. Properly.\"", "check": {"stat": "cha", "dc": 13}, "effects": {"flags": ["achim_lofts"]}, "next": "plan", "next_fail": "names"},
					{"label": "\"It's a building, Achim. It was always going.\"", "effects": {"kiez": -0.5, "flags": ["achim_lofts"]}, "next": "names"},
				],
			},
			"names": {
				"speaker": "achim", "expression": "upset",
				"lines": ["He does the names the way other people do a rosary. Sabine, Brandenburg. Tobi, a café in Lisbon, which he says like an accusation. Mecki, who is dead.", "\"And me. Still here. Last one in the postcode, buying papers off a bloke who wasn't born.\""],
				"choices": [
					{"label": "\"You're the one who stayed. That's not nothing.\"", "effects": {"kiez": 1.5}, "next": "cellar"},
					{"label": "\"Tell me about Mecki.\"", "effects": {"kiez": 2.0}, "next": "cellar"},
					{"label": "Slide the Sterni over. Open it for him.", "effects": {"kiez": 1.0, "cash": -1.2}, "next": "cellar"},
				],
			},
			"plan": {
				"speaker": "achim", "expression": "warm",
				"lines": ["He stops mid-clause, which has not happened in four years, and you can watch the grief go somewhere with a handle on it.", "\"…Right. Right. If they want a plaque about the squat, they can have a Versammlung about the Späti. Same street. Same week. I'll do the printing.\""],
				"choices": [
					{"label": "\"Say when.\" \"Thursday. Bring the PA.\"", "effects": {"kiez": 2.5}, "next": "cellar"},
					{"label": "\"Not the same typeface as the benefit.\"", "effects": {"kiez": 1.5}, "next": "cellar"},
				],
			},
			"cellar": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["He has photographed the plaque. It is four sentences long, it uses the word Zwischennutzung, and it does not name a single person who lived there.", "\"Read it. Go on. It's in that German. The German where nobody did anything and it all just happened.\""],
				"choices": [
					{"label": "\"It's four sentences and none of them is you.\"", "effects": {"kiez": 1.0}, "next": "off"},
					{"label": "[Brains 14] Read what the Erhaltungssatzung line is doing there.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 2.0, "flags": ["achim_clause"]}, "next": "off"},
					{"label": "\"Put your names on it. In marker. Tonight.\"", "effects": {"kiez": 1.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "achim", "expression": "warm",
				"lines": ["He softens for about one and a half seconds, at the door, with his back to you, which is the only way he can do it.", "\"Cheers, Chef.\" Then, immediately, at volume: \"YOUR FILTERS ARE IN THE WRONG BOX AGAIN.\""],
				"choices": [
					{"label": "\"Good night, Achim.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Achim, WINTER STEP 6 — "The Fight Is The Scene". Your stand is the scene, reborn, small. The
	#    tree sets `achim_listen`, the gate on his SPRING beat — the second road to it, so a player
	#    who told him it was just a business in the summer can still get him to the Versammlung.
	"achim_w6": {
		"start": "pa",
		"nodes": {
			"pa": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["The small PA is on the bench. There is a bedsheet across your shutter with KIEZVERSAMMLUNG on it in emulsion, and one of the S's is a different size.", "\"{brand.tobacco}, {brand.papers}, {brand.filters}, and don't touch the gain, I've set the gain.\""],
				"choices": [
					{"label": "\"Plug it in, then.\"", "effects": {"kiez": 1.0, "flags": ["achim_listen"]}, "next": "banner"},
					{"label": "[Kiez Sense 12] He has been setting up since six.", "check": {"stat": "wis", "dc": 12}, "effects": {"flags": ["achim_listen"]}, "next": "six", "next_fail": "banner"},
					{"label": "\"Under ninety decibels or the Ordnungsamt come.\"", "effects": {"kiez": 0.5, "flags": ["achim_listen"]}, "next": "banner"},
				],
			},
			"six": {
				"speaker": "achim", "expression": "surprised",
				"lines": ["Six o'clock. Gaffer tape, a spirit level for a bedsheet, cable runs taped flat so nobody trips — a load-in, done properly, by a man who has run three hundred of them for money.", "\"…Well, you don't half-do a room. You do the room or you don't do the room.\""],
				"choices": [
					{"label": "\"Nobody else would have levelled a bedsheet.\"", "effects": {"kiez": 2.0}, "next": "banner"},
					{"label": "\"What do you need? I'll fetch it.\"", "effects": {"kiez": 1.5}, "next": "banner"},
				],
			},
			"banner": {
				"speaker": "achim", "expression": "warm",
				"lines": ["By nine there are forty people in the road with your Sterni in their hands, Mehmet has brought two crates of something, and somebody's kid is asleep on the Pfand crate.", "\"Look at it,\" he says. \"That's a room. That's a proper room, and it's a ROAD.\""],
				"choices": [
					{"label": "\"It's your room. You built it.\"", "effects": {"kiez": 2.0}, "next": "scene"},
					{"label": "[Stamina 13] Shut the till. Work the door until two.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "cash": -30.0, "flags": ["achim_ran_it"]}, "next": "scene"},
					{"label": "Keep serving. Let him run the road.", "effects": {"kiez": 1.5}, "next": "scene"},
				],
			},
			"scene": {
				"speaker": "achim", "expression": "warm",
				"lines": ["Late on, with the PA off and the banner sagging at one corner, he says it in one clause, which is how you know he means it.", "\"It was never the venue.\" A drag. \"Forty years I thought I'd lost the scene. The scene's the fight. It was always the fight.\""],
				"choices": [
					{"label": "\"Then we've still got one.\"", "effects": {"kiez": 2.0}, "next": "off"},
					{"label": "\"Say that on Thursday. Exactly that.\"", "effects": {"kiez": 2.0}, "next": "off"},
				],
			},
			"off": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["He coils the cable over elbow and hand, three hundred load-ins in his wrists, and puts the exact money on the laminate on his way past.", "\"Right. Bins. Somebody's got to do the bins and it's going to be me, isn't it.\""],
				"choices": [
					{"label": "\"I'll do the bins. Go home, Achim.\"", "effects": {"kiez": 1.0}, "next": ""},
				],
			},
		},
	},
	# ── Achim, SPRING STEP 7 — "Elder Agitator". Useful at last, and insufferable about it. Gated on
	#    `achim_listen`: if you never once let him tell you how it was, he is still the loud man with
	#    the flyers and this night does not happen to him.
	"achim_p7": {
		"start": "lanyard",
		"nodes": {
			"lanyard": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["\"{brand.tobacco}, {brand.papers}, {brand.filters}, Sterni.\" He is wearing a lanyard. He has made himself a lanyard. It says ORGA in letters he cut out himself.", "\"Don't. I know. I know exactly what I look like and I have made my peace with it.\""],
				"choices": [
					{"label": "\"Is that a lanyard, Achim.\"", "effects": {"kiez": 1.0, "flags": ["achim_elder"]}, "next": "running"},
					{"label": "[Schnauze 12] Put him in charge of the room, out loud.", "check": {"stat": "cha", "dc": 12}, "effects": {"flags": ["achim_elder"]}, "next": "charge", "next_fail": "running"},
					{"label": "\"Take it off before Mehmet sees it.\"", "effects": {"kiez": -0.5, "flags": ["achim_elder"]}, "next": "running"},
				],
			},
			"charge": {
				"speaker": "achim", "expression": "surprised",
				"lines": ["You say it to the shop, not to him: the Versammlung is Achim's, the chairs are Achim's, and anybody with a question about the room can take it to the man in the lanyard.", "He does not have a clause ready. It is the first time in four years you have seen him have to find one."],
				"choices": [
					{"label": "\"You've done three hundred rooms. Do this one.\"", "effects": {"kiez": 2.5}, "next": "running"},
					{"label": "Go back to the till. Let it sit on him.", "effects": {"kiez": 2.0}, "next": "running"},
				],
			},
			"running": {
				"speaker": "achim", "expression": "warm",
				"lines": ["He runs it like a load-in. Chairs in blocks of eight, a gangway down the middle, the Mieterverein woman miked and the loud ones not, and a hard stop at half nine that he actually keeps.", "\"Forty years I was the bloke shouting at the back,\" he says, in the gap. \"Turns out the trick was being the bloke with the folding table.\""],
				"choices": [
					{"label": "\"You were always going to end up here.\"", "effects": {"kiez": 2.0}, "next": "useful"},
					{"label": "[Muscle 11] Stack the forty chairs with him after.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.5, "flags": ["achim_useful"]}, "next": "useful"},
					{"label": "\"Half nine. You kept a hard stop. Who are you.\"", "effects": {"kiez": 1.5}, "next": "useful"},
				],
			},
			"useful": {
				"speaker": "achim", "expression": "warm",
				"lines": ["Two students ask him what a Räumungsklage is and he explains it for six minutes without swearing once, which you did not know was available to him.", "Afterwards, to you, at the counter, not looking up: \"That's the useful bit. That's the bit I missed. Not the shouting.\""],
				"choices": [
					{"label": "\"Keep the lanyard.\"", "effects": {"kiez": 2.0}, "next": "off"},
					{"label": "\"They'll be back next month. Both of them.\"", "effects": {"kiez": 1.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "achim", "expression": "neutral",
				"lines": ["Exact money, to the cent. The door bangs harder than it needs to, which at this point is punctuation rather than temper.", "\"NEXT ONE'S THE FIRST THURSDAY,\" from the pavement. \"AND YOUR FILTERS ARE STILL IN THE WRONG BOX.\""],
				"choices": [
					{"label": "\"First Thursday, Achim.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
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
	# ── KARIM'S ARC, STEPS 2-7 (docs/09 §2.6). One tree per Truby step, id `karim_<letter><step>`,
	#    the letter taken from the STEP's season: summer `s` 1-2 · autumn `a` 3-4 · winter `w` 5-6 ·
	#    spring `p` 7. His four faces on disk are neutral/warm/wary/surprised — he has no `upset` and
	#    no `tired`, so the guard reads as `wary` and the hurt reads as a straight back. The step's
	#    beat in story.gd is what schedules it; these are what he says while he is standing there.
	"karim_s2": {
		"start": "order",
		"nodes": {
			"order": {
				"speaker": "karim", "expression": "neutral",
				"lines": ["\"Einmal die {brand.cigarettes} — {qty.cigarettes} Stück — und zwar zackig.\" He says it at the wall, at volume, the way you taught him.", "\"Also the water and the Mate. Sorry. Zackig.\" A pause. \"Was that correct? It felt very loud.\""],
				"choices": [
					{"label": "\"Loud is correct. That's the whole word.\"", "effects": {"kiez": 1.0, "flags": ["karim_zackig_joke"]}, "next": "practised"},
					{"label": "[Kiez Sense 12] He rehearsed that on the street.", "check": {"stat": "wis", "dc": 12}, "next": "shelf", "next_fail": "practised"},
					{"label": "\"You said it to a fridge, Karim.\"", "effects": {"kiez": -0.5}, "next": "practised"},
				],
			},
			"practised": {
				"speaker": "karim", "expression": "surprised",
				"lines": ["\"Zackig,\" he says again, to himself, filing it away. \"Quick. Sharp. With — attitude?\"", "\"In Aleppo I was not a man with attitude. Here it appears to be required.\""],
				"choices": [
					{"label": "\"Not required. Just faster.\"", "effects": {"kiez": 0.5}, "next": "shelf"},
					{"label": "[Schnauze 12] Teach him \"Ick hab's eilig.\"", "check": {"stat": "cha", "dc": 12}, "effects_success": {"kiez": 1.0, "flags": ["karim_joke_landed"]}, "next": "rule", "next_fail": "shelf"},
				],
			},
			"shelf": {
				"speaker": "karim", "expression": "wary",
				"lines": ["He builds the next one the way he used to check a level — word, pause, word — and then ruins it on purpose.", "\"And one chocolate. For the girl in the flat below. She is six and a very hard negotiator.\""],
				"choices": [
					{"label": "Ring the chocolate. Laugh on time.", "effects": {"kiez": 1.0, "flags": ["karim_joke_landed"]}, "next": "off"},
					{"label": "[Brains 14] Fix the case ending, once, kindly.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 1.5, "flags": ["karim_sleeve_notes"]}, "next": "rule"},
					{"label": "\"Six is old enough to run a tab.\"", "effects": {"kiez": 0.5}, "next": "off"},
				],
			},
			"rule": {
				"speaker": "karim", "expression": "warm",
				"lines": ["\"Der, die, das,\" he says, like a man reading out a serial number. \"Die Schokolade. Feminine.\"", "\"Of course it is feminine. It is the only one of the three that has never disappointed me.\" It arrives a beat late, and it is very good."],
				"choices": [
					{"label": "\"That one works in any Späti in Berlin.\"", "effects": {"kiez": 1.0, "flags": ["karim_joke_landed"]}, "next": "off"},
					{"label": "\"Write it on the sleeve. You'll lose it.\"", "effects": {"kiez": 1.5, "flags": ["karim_sleeve_notes"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "karim", "expression": "warm",
				"lines": ["\"Gute Nacht.\" At the door he turns and delivers it to the whole shop: \"Und zwar — zackig!\"", "The clubber by the fridge says it back to him. Karim looks like a man who has been let into something."],
				"choices": [{"label": "\"Bis morgen, Karim.\"", "next": ""}],
			},
		},
	},
	"karim_a3": {
		"start": "sleeve",
		"nodes": {
			"sleeve": {
				"speaker": "karim", "expression": "wary",
				"lines": ["\"{brand.cigarettes}, the water, the Mate.\" He puts the money down first, which he does when he is going to ask for something.", "The plastic sleeve comes out. The top envelope has a window, a crest, and a fold across it from four days in a jacket."],
				"choices": [
					{"label": "\"Put it on the counter. I'll look.\"", "effects": {"kiez": 1.0, "flags": ["karim_letter_shown"]}, "next": "date"},
					{"label": "[Kiez Sense 13] Read his face, not the envelope.", "requires": {"stat": "wis", "min": 13}, "effects": {"kiez": 1.5, "flags": ["karim_letter_shown"]}, "next": "date"},
					{"label": "\"Behörde is Behörde. I sell Mate.\"", "effects": {"kiez": -1.0}, "next": "off"},
				],
			},
			"date": {
				"speaker": "karim", "expression": "surprised",
				"lines": ["A deadline, printed small, under a paragraph of nouns welded end to end. It is in eleven days. It was fifteen when the letter arrived.", "\"I know the word Frist,\" he says. \"I did not want to know it on a Tuesday.\""],
				"choices": [
					{"label": "\"Eleven days is a lot of days.\"", "effects": {"kiez": 0.5}, "next": "read"},
					{"label": "[Brains 13] Take the paragraph apart, noun by noun.", "check": {"stat": "int", "dc": 13}, "next": "read", "next_fail": "bring"},
				],
			},
			"read": {
				"speaker": "karim", "expression": "neutral",
				"lines": ["It is not a refusal. It is a request for one document he already has, second from the back of the sleeve, because Karim keeps everything.", "He looks at the counter for a while. \"Six weeks I did not sleep for this paper.\""],
				"choices": [
					{"label": "\"You had it all along. That's a good day.\"", "effects": {"kiez": 1.0, "flags": ["karim_letter_answered"]}, "next": "bring"},
					{"label": "Photocopy it out back. Two copies, on the house.", "effects": {"cash": -0.4, "kiez": 2.0, "flags": ["karim_letter_answered", "karim_copies"]}, "next": "bring"},
				],
			},
			"bring": {
				"speaker": "karim", "expression": "warm",
				"lines": ["\"You will get tired of me,\" he says, sliding the sleeve back into the jacket. \"There is always another one of these.\"", "\"But tonight I have eleven days and one paper. That is nearly a holiday.\""],
				"choices": [
					{"label": "\"Bring the next one on a Wednesday. I'm slower.\"", "effects": {"kiez": 1.0}, "next": "off"},
					{"label": "\"Bring all of them. That's the arrangement.\"", "effects": {"kiez": 1.5, "flags": ["karim_every_letter"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "karim", "expression": "warm",
				"lines": ["He counts the notes twice before he hands them over, which he has done every night for two years and is not going to stop doing.", "\"Gute Nacht. And — thank you. That you wait while I finish. It is not a small thing.\""],
				"choices": [{"label": "\"Gute Nacht, Karim.\"", "next": ""}],
			},
		},
	},
	"karim_a4": {
		"start": "clock",
		"nodes": {
			"clock": {
				"speaker": "karim", "expression": "neutral",
				"lines": ["00:20, to the minute. \"{qty.cigarettes}× {brand.cigarettes}, the water, the Mate.\" Then he puts his phone face-down on the laminate with a timer running.", "\"Ten minutes. Then I go home and you get your shop back.\""],
				"choices": [
					{"label": "\"Start the clock. I'm not going anywhere.\"", "effects": {"kiez": 1.0, "flags": ["karim_ten_nightly"]}, "next": "ten"},
					{"label": "[Kiez Sense 12] He has been doing this for weeks.", "check": {"stat": "wis", "dc": 12}, "next": "articles", "next_fail": "ten"},
					{"label": "\"Put the timer away. We'll manage.\"", "effects": {"kiez": 1.5, "flags": ["karim_ten_nightly"]}, "next": "ten"},
				],
			},
			"ten": {
				"speaker": "karim", "expression": "warm",
				"lines": ["He talks about the kitchen: the head chef's four words of German, the Vietnamese he is picking up faster than either, the delivery man who sings.", "Nine minutes of it. No rehearsal at all, and only two apologies."],
				"choices": [
					{"label": "\"That was nine minutes. No shelf-building.\"", "effects": {"kiez": 1.0, "flags": ["karim_names_it"]}, "next": "articles"},
					{"label": "[Stamina 13] Let the timer run out. Stay open.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.0, "flags": ["karim_names_it", "karim_ten_nightly"]}, "next": "teach"},
				],
			},
			"articles": {
				"speaker": "karim", "expression": "wary",
				"lines": ["\"Der, die, das. Still. Six years of bridges and my enemy is three words that mean the same word.\"", "\"The girl downstairs corrects me now. She is six. She does it very kindly, which is worse.\""],
				"choices": [
					{"label": "\"Nobody on this street gets them right.\"", "effects": {"kiez": 0.5}, "next": "off"},
					{"label": "[Schnauze 13] Tell him what a Berliner does: guess.", "check": {"stat": "cha", "dc": 13}, "effects_success": {"kiez": 1.5, "flags": ["karim_names_it"]}, "next": "teach", "next_fail": "off"},
				],
			},
			"teach": {
				"speaker": "karim", "expression": "surprised",
				"lines": ["Then he turns it round. \"Say it in Arabic: shukran. No — the kh is in the throat. Again.\"", "You are terrible at it. He is delighted, and he does not cover it up, which is new."],
				"choices": [
					{"label": "Keep saying it until he stops laughing.", "effects": {"kiez": 1.5, "flags": ["karim_teaches_back"]}, "next": "off"},
					{"label": "\"Ten minutes each. That's the new deal.\"", "effects": {"kiez": 2.0, "flags": ["karim_teaches_back"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "karim", "expression": "warm",
				"lines": ["The phone goes back in the jacket with the timer still running. He notices at the door and lets it run anyway.", "\"Gute Nacht. Tomorrow I tell you about the delivery man. He is a whole evening on his own.\""],
				"choices": [{"label": "\"Twenty past. I'll be here.\"", "next": ""}],
			},
		},
	},
	"karim_w5": {
		"start": "door",
		"nodes": {
			"door": {
				"speaker": "karim", "expression": "wary",
				"lines": ["He comes in facing the door and stays facing it. The order is the same order and he says it to the window: \"{brand.cigarettes}. Water. Mate.\"", "Outside, two men on the corner are still there, not leaving, having a good night."],
				"choices": [
					{"label": "\"Take your time. I'll ring it slow.\"", "effects": {"kiez": 1.0}, "next": "said"},
					{"label": "[Kiez Sense 12] Something happened out there.", "check": {"stat": "wis", "dc": 12}, "next": "said", "next_fail": "off"},
					{"label": "Ring it fast and let him go.", "next": "off"},
				],
			},
			"said": {
				"speaker": "karim", "expression": "neutral",
				"lines": ["\"He said go home.\" Flat, correct, the whole sentence built and level. \"Then he said it again in English, in case.\"", "\"I said nothing. I have a very good sentence for this and it was not there.\""],
				"choices": [
					{"label": "\"There isn't a good sentence. There's just them.\"", "effects": {"kiez": 1.0, "flags": ["karim_shook"]}, "next": "write"},
					{"label": "[Muscle 11] Put the apron down and go outside.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.0, "flags": ["karim_walked_out"]}, "next": "out"},
					{"label": "\"Ignore it. They'll get bored.\"", "effects": {"kiez": -1.0}, "next": "write"},
				],
			},
			"out": {
				"speaker": "karim", "expression": "surprised",
				"lines": ["You stand in the doorway with the light behind you and say nothing at all. It takes about ninety seconds.", "They go. Karim watches the whole thing from inside, next to the crisps, wearing a face you have not seen on him."],
				"choices": [
					{"label": "\"They come past here every night. So do you.\"", "effects": {"kiez": 2.0, "flags": ["karim_walked_out"]}, "next": "write"},
					{"label": "Come back in. Finish ringing the order.", "effects": {"kiez": 1.0}, "next": "write"},
				],
			},
			"write": {
				"speaker": "karim", "expression": "warm",
				"lines": ["He takes a pen off the counter and writes something on the back of the receipt, slowly, then turns it round for you.", "The sentence he could not find. In German, correct, and unusable — the kind you only think of afterwards."],
				"choices": [
					{"label": "\"Keep it. You'll want it one day.\"", "effects": {"kiez": 1.5, "flags": ["karim_wrote_it_down"]}, "next": "off"},
					{"label": "Pin it behind the till, next to the prices.", "effects": {"kiez": 2.0, "flags": ["karim_wrote_it_down"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "karim", "expression": "wary",
				"lines": ["\"Gute Nacht.\" He says it to you and not to the window this time, which is the whole difference.", "He goes left instead of right, which is four minutes longer, and neither of you mentions it."],
				"choices": [{"label": "\"Bis morgen, Karim.\"", "next": ""}],
			},
		},
	},
	"karim_w6": {
		"start": "list",
		"nodes": {
			"list": {
				"speaker": "karim", "expression": "neutral",
				"lines": ["\"The usual — {qty.cigarettes}× {brand.cigarettes}, water, Mate — and a chocolate, it is Friday.\" Then, with no run-up: \"Have you a pen that is not the till pen?\"", "He writes a list on the back of an envelope. Names, one column, two alphabets."],
				"choices": [
					{"label": "Give him the good pen. Don't ask yet.", "effects": {"kiez": 1.0}, "next": "seven"},
					{"label": "[Kiez Sense 13] He has been counting something.", "requires": {"stat": "wis", "min": 13}, "effects": {"kiez": 1.5, "flags": ["karim_counted_us"]}, "next": "seven"},
					{"label": "\"A shopping list at midnight?\"", "next": "seven"},
				],
			},
			"seven": {
				"speaker": "karim", "expression": "surprised",
				"lines": ["\"People here who know my name. Not the office name. The one my mother uses.\" He turns the envelope round.", "There are seven. The greengrocer is number two. You are number five, under a woman from his stairwell and the man who sings on the deliveries."],
				"choices": [
					{"label": "\"Seven's a lot, Karim. Ask anyone.\"", "effects": {"kiez": 1.5, "flags": ["karim_counted_us"]}, "next": "count"},
					{"label": "[Schnauze 12] \"Number five. I'll take five.\"", "check": {"stat": "cha", "dc": 12}, "effects_success": {"kiez": 2.0, "flags": ["karim_counted_us"]}, "next": "count", "next_fail": "mother"},
				],
			},
			"count": {
				"speaker": "karim", "expression": "warm",
				"lines": ["\"Two years I have been waiting for it to start. And it started somewhere in there and nobody told me.\"", "\"This is already the place. I was saving my life for a later one.\""],
				"choices": [
					{"label": "\"It's not a waiting room. It's a Tuesday.\"", "effects": {"kiez": 1.5}, "next": "mother"},
					{"label": "\"Put the Späti on the list. It's a person.\"", "effects": {"kiez": 2.0, "flags": ["karim_counted_us"]}, "next": "mother"},
				],
			},
			"mother": {
				"speaker": "karim", "expression": "wary",
				"lines": ["\"Tomorrow I call my mother and I do not say 'soon' about coming back. It will be the first time.\"", "He holds the envelope a second too long before it goes in the sleeve — second from the front, where the important ones live."],
				"choices": [
					{"label": "\"Tell her the greengrocer says hello.\"", "effects": {"kiez": 1.5, "flags": ["karim_mother_call"]}, "next": "off"},
					{"label": "\"Call her from here. The signal's better.\"", "effects": {"kiez": 2.0, "flags": ["karim_mother_call", "karim_called_here"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "karim", "expression": "warm",
				"lines": ["\"Gute Nacht.\" A beat, exactly the length it always is. \"…Und zwar zackig.\"", "He gets it right first time now, which is a shame, and he knows it, and he does it anyway."],
				"choices": [{"label": "\"Gute Nacht, Karim.\"", "next": ""}],
			},
		},
	},
	"karim_p7": {
		"start": "tables",
		"nodes": {
			"tables": {
				"speaker": "karim", "expression": "warm",
				"lines": ["He has been here since four in the afternoon and the shop has sold him nothing — no {brand.cigarettes}, no water, nothing.", "\"Tonight I am not a customer. Tonight you are.\" Two trestle tables out front, a gas ring off a small ad, and a pot that has been going six hours."],
				"choices": [
					{"label": "\"Then I'm having whatever's in the pot.\"", "effects": {"kiez": 1.0, "flags": ["karim_cooks"]}, "next": "pot"},
					{"label": "[Muscle 11] Carry the second table out for him.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.0, "flags": ["karim_cooks"]}, "next": "pot"},
					{"label": "\"Water and Mate on the house, then.\"", "effects": {"cash": -2.7, "kiez": 1.5, "flags": ["karim_cooks"]}, "next": "pot"},
				],
			},
			"pot": {
				"speaker": "karim", "expression": "neutral",
				"lines": ["Kibbeh, a vat of it, and a second pot with lemon in it that half the bench is already arguing about in three languages.", "Frau Schulz has a bowl and an opinion. Mehmet has a bowl and a better one."],
				"choices": [
					{"label": "Take a bowl. Let the queue run itself.", "effects": {"kiez": 1.5}, "next": "name"},
					{"label": "[Kiez Sense 11] Watch him watch the street eat.", "check": {"stat": "wis", "dc": 11}, "effects_success": {"kiez": 1.5}, "next": "name", "next_fail": "recipe"},
				],
			},
			"name": {
				"speaker": "karim", "expression": "surprised",
				"lines": ["\"Kib-beh,\" he says, to four people in a row, slowly, until all four have it. Then he does his surname.", "\"Hadid. Not Hah-did. Hadid.\" They get it on the third go. He makes them do a fourth anyway."],
				"choices": [
					{"label": "\"Again. Loud. Und zwar zackig.\"", "effects": {"kiez": 2.0, "flags": ["karim_name_said_right"]}, "next": "recipe"},
					{"label": "Say it properly yourself, into the crowd.", "effects": {"kiez": 2.0, "flags": ["karim_name_said_right"]}, "next": "recipe"},
				],
			},
			"recipe": {
				"speaker": "karim", "expression": "wary",
				"lines": ["Somebody asks for the recipe. He goes very still, the way he used to at the counter, and then says it out loud, all of it, to a stranger.", "\"You will do it wrong,\" he adds. \"That is fine. Everybody's mother does it wrong.\""],
				"choices": [
					{"label": "Write it on a price card and tape it up.", "effects": {"kiez": 2.0, "flags": ["karim_recipe"]}, "next": "off"},
					{"label": "\"Don't give it away for free.\" (He does.)", "effects": {"kiez": 1.0, "flags": ["karim_recipe"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "karim", "expression": "warm",
				"lines": ["At two the tables come in, the gas ring goes in your back room \"for next time\", and the pot goes home empty on the U-Bahn.", "\"Next year we do two pots. And you make something. Anything. I will be kind about it.\""],
				"choices": [{"label": "\"Next year. Gute Nacht, Karim.\"", "next": ""}],
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
	# ── NADIA'S ARC, STEPS 2-7 (docs/09 §2.7). She is the one guest with NO tobacco line, so her
	#    order is spoken in plain nouns — `coffee` is `unlocked_by: coffee_machine` and would be cut
	#    out of the placed basket in a shop that has not bought the machine, and a `{qty.coffee}` on a
	#    cut line does not fail, it PRINTS (docs/06 §8.5). Her six faces are all on disk, so this is
	#    the one arc that can use `upset` and `tired` as well as the other four.
	"nadia_s2": {
		"start": "cold",
		"nodes": {
			"cold": {
				"speaker": "nadia", "expression": "tired",
				"lines": ["03:41. \"Two coffees and two Schrippen — and whatever the porter has, he's been on since six as well.\"", "The machine is cold. Her hand is on the door before you have found the switch. \"It's fine. There's a garage on the Frankfurter.\""],
				"choices": [
					{"label": "\"Sit down. Three minutes and it's hot.\"", "effects": {"kiez": 1.5, "flags": ["nadia_three_minutes"]}, "next": "porter"},
					{"label": "[Kiez Sense 12] That is her third 'it's fine'.", "check": {"stat": "wis", "dc": 12}, "next": "ask", "next_fail": "porter"},
					{"label": "\"Garage coffee it is, then.\"", "effects": {"kiez": -0.5}, "next": "porter"},
				],
			},
			"porter": {
				"speaker": "nadia", "expression": "neutral",
				"lines": ["\"His is the one with four sugars. Don't put four in mine, I've seen what that does to people.\"", "She buys the porter a coffee every night of her life and has never once mentioned it to the porter."],
				"choices": [
					{"label": "\"Four sugars. Noted. Medically.\"", "effects": {"kiez": 1.0}, "next": "ask"},
					{"label": "\"Does he know you pay for it?\" (\"No.\")", "effects": {"kiez": 1.5, "flags": ["nadia_porter_coffee"]}, "next": "ask"},
				],
			},
			"ask": {
				"speaker": "nadia", "expression": "upset",
				"lines": ["\"I don't ask people for things.\" It comes out flatter than she meant it and she hears that herself.", "\"Twelve years on the wards. You learn very fast that the ones who ask get moved to the end of the list.\""],
				"choices": [
					{"label": "\"This isn't a ward. It's a shop with a kettle.\"", "effects": {"kiez": 1.5, "flags": ["nadia_three_minutes"]}, "next": "pour"},
					{"label": "[Stamina 13] \"Then I'll offer nightly till it's boring.\"", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "flags": ["nadia_asked_once"]}, "next": "pour"},
				],
			},
			"pour": {
				"speaker": "nadia", "expression": "warm",
				"lines": ["She takes the first mouthful standing up with her eyes shut. It is the only ten minutes of the day that belongs to her and it lasts about forty seconds.", "\"Right,\" she says. \"That's me repaired. Professionally speaking.\""],
				"choices": [
					{"label": "\"Same time tomorrow. I'll have it hot.\"", "effects": {"kiez": 1.0, "flags": ["nadia_three_minutes"]}, "next": "off"},
					{"label": "\"Forty seconds isn't ten minutes, Nadia.\"", "effects": {"kiez": 1.5, "flags": ["nadia_asked_once"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "nadia", "expression": "neutral",
				"lines": ["The porter's cup goes against her wrist for the warmth on the way out. She does that every night and has never noticed she does it.", "\"Ward starts at four. It's fine.\" That is the fourth meaning, and it is the good one."],
				"choices": [{"label": "\"Go on. Bis morgen.\"", "next": ""}],
			},
		},
	},
	"nadia_a3": {
		"start": "third",
		"nodes": {
			"third": {
				"speaker": "nadia", "expression": "tired",
				"lines": ["\"Two coffees. Two Schrippen. And the Paracetamol — the children's one, if you have it.\" She does not sit down; sitting down is a decision she cannot reverse.", "Third double this week. The coat is over the scrubs and the scrubs are yesterday's."],
				"choices": [
					{"label": "\"Third one this week. I've been counting.\"", "effects": {"kiez": 1.0, "flags": ["nadia_doubles"]}, "next": "rota"},
					{"label": "[Brains 13] Work out what she is actually earning.", "check": {"stat": "int", "dc": 13}, "next": "rota", "next_fail": "sleep"},
					{"label": "Ring it through. Don't make her talk.", "effects": {"kiez": 0.5}, "next": "sleep"},
				],
			},
			"rota": {
				"speaker": "nadia", "expression": "neutral",
				"lines": ["Nights pay a supplement. The supplement is the difference between the rent and the rent; three a week is the difference between the rent and Leo's swimming.", "\"It's fine. It's arithmetic. Arithmetic is fine.\""],
				"choices": [
					{"label": "\"Arithmetic's fine. Sixteen hours isn't.\"", "effects": {"kiez": 1.0, "flags": ["nadia_rota"]}, "next": "sleep"},
					{"label": "[Kiez Sense 13] Ask who is with Leo tonight.", "requires": {"stat": "wis", "min": 13}, "effects": {"kiez": 1.5, "flags": ["nadia_rota"]}, "next": "sleep"},
				],
			},
			"sleep": {
				"speaker": "nadia", "expression": "upset",
				"lines": ["She is asleep. Standing up, one hand on the counter, for about four seconds — and she comes out of it as though nothing happened.", "\"Sorry. Micro-sleep. We get taught to spot those in other people.\""],
				"choices": [
					{"label": "\"Twenty minutes on the crate. I'll wake you.\"", "effects": {"kiez": 2.0, "flags": ["nadia_slept_here"]}, "next": "bench"},
					{"label": "\"You just diagnosed yourself out loud.\"", "effects": {"kiez": 1.0, "flags": ["nadia_doubles"]}, "next": "bench"},
					{"label": "Pretend you didn't see it.", "effects": {"kiez": 0.5}, "next": "off"},
				],
			},
			"bench": {
				"speaker": "nadia", "expression": "warm",
				"lines": ["Twenty-two minutes on the Pfand crate with her coat over her, while the fridges hum and one clubber buys a Mate very quietly because you asked him to.", "She wakes up furious and grateful in the same breath and cannot get either of them out."],
				"choices": [
					{"label": "\"Nothing happened. Your coffee's fresh.\"", "effects": {"kiez": 2.0, "flags": ["nadia_slept_here"]}, "next": "off"},
					{"label": "\"Same crate tomorrow if you need it.\"", "effects": {"kiez": 1.5, "flags": ["nadia_slept_here"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "nadia", "expression": "wary",
				"lines": ["\"If you tell anyone I slept in a Späti I will put you on a waiting list,\" she says, \"and I can do that. I know the system.\"", "It is the closest she gets to a joke, and she delivers it without a smile, like all the good ones."],
				"choices": [{"label": "\"Nobody heard a thing. Go and be brilliant.\"", "next": ""}],
			},
		},
	},
	"nadia_a4": {
		"start": "count",
		"nodes": {
			"count": {
				"speaker": "nadia", "expression": "neutral",
				"lines": ["\"Two coffees, two Schrippen.\" The purse is the flat kind that lives in a coat pocket, and she counts out of it onto the laminate, coin by coin.", "Then, with no change in her face at all, she counts them again."],
				"choices": [
					{"label": "Wait. Don't fill the silence.", "effects": {"kiez": 0.5, "flags": ["nadia_counted_twice"]}, "next": "again"},
					{"label": "[Kiez Sense 12] The second count is the real one.", "check": {"stat": "wis", "dc": 12}, "next": "pride", "next_fail": "again"},
					{"label": "\"Four twenty, whenever you're ready.\"", "next": "again"},
				],
			},
			"again": {
				"speaker": "nadia", "expression": "tired",
				"lines": ["It is four twenty and there is four-oh-five on the counter in ones and twos, and she has known that since the first count.", "\"Take the Schrippen off. I'll get them tomorrow.\" She has already moved them, so it is not a question."],
				"choices": [
					{"label": "\"They're forty cents. Take them.\"", "effects": {"cash": -0.8, "kiez": 1.5, "flags": ["nadia_short"]}, "next": "bag"},
					{"label": "[Hands 12] Palm the fifteen out of the tip jar.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.0, "flags": ["nadia_short"]}, "next": "bag"},
					{"label": "Take the Schrippen off, as asked.", "effects": {"kiez": 0.5, "flags": ["nadia_short"]}, "next": "pride"},
				],
			},
			"pride": {
				"speaker": "nadia", "expression": "upset",
				"lines": ["\"I'm not a case. I've got a job. Two, some weeks. I'm not on anybody's list and I'd like to keep it that way.\"", "The purse goes back in the coat with the flap done up, which takes a moment, and she does it slowly so it does not look like leaving."],
				"choices": [
					{"label": "\"Nobody's on a list. You're on a tab.\"", "effects": {"kiez": 1.5, "flags": ["nadia_no_charity"]}, "next": "bag"},
					{"label": "\"Fine. Pay me Thursday, like Lena does.\"", "effects": {"kiez": 2.0, "flags": ["nadia_no_charity"]}, "next": "bag"},
				],
			},
			"bag": {
				"speaker": "nadia", "expression": "warm",
				"lines": ["Two Schrippen in the bag anyway, and the Paracetamol on top, and she looks at it a second longer than she wants to.", "\"Thursday,\" she says. \"I'll be here Thursday. I'm always here.\""],
				"choices": [
					{"label": "\"Then it isn't charity. It's Thursday.\"", "effects": {"kiez": 1.5, "flags": ["nadia_no_charity"]}, "next": "out"},
					{"label": "\"Write it on the fridge yourself.\"", "effects": {"kiez": 2.0, "flags": ["nadia_counted_twice"]}, "next": "out"},
				],
			},
			"out": {
				"speaker": "nadia", "expression": "surprised",
				"lines": ["At the door she stops. \"The chain up the road does four Schrippen for a euro. I checked.\"", "\"I still come here.\" She says it like a diagnosis she has finally accepted, and goes to work."],
				"choices": [{"label": "\"Four for a euro. Traitor.\"", "next": ""}],
			},
		},
	},
	"nadia_w5": {
		"start": "phone",
		"nodes": {
			"phone": {
				"speaker": "nadia", "expression": "upset",
				"lines": ["Minus nine outside, and the coffee is going cold in her hand because she has not put the phone down since she came in. Two Schrippen, untouched.", "\"My mother's got the flu. Leo's at hers. I'm due on ward in forty minutes and there is nobody else. There is literally nobody else.\""],
				"choices": [
					{"label": "\"Bring him here. I'm open till six anyway.\"", "effects": {"kiez": 2.0, "flags": ["nadia_leo_here"]}, "next": "cold"},
					{"label": "[Schnauze 13] \"Ring the ward. I'll talk to them.\"", "check": {"stat": "cha", "dc": 13}, "effects_success": {"kiez": 1.5, "flags": ["nadia_back_at_seven"]}, "next": "cold", "next_fail": "cold"},
					{"label": "\"That's rough. Hope it works out.\"", "effects": {"kiez": -1.0}, "next": "off"},
				],
			},
			"cold": {
				"speaker": "nadia", "expression": "wary",
				"lines": ["\"You don't want a six-year-old in a Späti at four in the morning. Nobody wants that. It isn't a thing people do.\"", "Minus nine. The bus from her mother's is twenty-five minutes and it is the coldest night of the year."],
				"choices": [
					{"label": "\"It's a thing this corner does. Go and get him.\"", "effects": {"kiez": 2.0, "flags": ["nadia_leo_here", "nadia_coldest"]}, "next": "leo"},
					{"label": "[Stamina 13] \"I'll drive. Mehmet's van, ten minutes.\"", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "flags": ["nadia_leo_here", "nadia_coldest"]}, "next": "leo"},
					{"label": "\"Then take him on the ward. They'll cope.\"", "effects": {"kiez": 0.5}, "next": "off"},
				],
			},
			"leo": {
				"speaker": "nadia", "expression": "surprised",
				"lines": ["He arrives in a coat over pyjamas, entirely unbothered, and asks whether the fridges are always on.", "\"Yes.\" \"Even in the day?\" \"Even in the day.\" He considers this the most important fact he has been told all year."],
				"choices": [
					{"label": "Give him the crate, a Schrippe and the radio.", "effects": {"kiez": 2.0, "flags": ["nadia_leo_here"]}, "next": "keys"},
					{"label": "\"You're in charge of the Pfand. It's serious.\"", "effects": {"kiez": 2.0, "flags": ["nadia_leo_here"]}, "next": "keys"},
				],
			},
			"keys": {
				"speaker": "nadia", "expression": "warm",
				"lines": ["She is at the door with her keys in her fist and has not moved for eleven seconds, which for Nadia is a collapse.", "\"I'll be back at seven. I'll be back at seven.\" Twice, because the first one was for her."],
				"choices": [
					{"label": "\"Seven. He'll be doing sums. Go.\"", "effects": {"kiez": 2.0, "flags": ["nadia_back_at_seven"]}, "next": "off"},
					{"label": "\"Take the porter's coffee. He'll live.\"", "effects": {"kiez": 1.5, "flags": ["nadia_back_at_seven"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "nadia", "expression": "tired",
				"lines": ["07:04, the same coat, twelve hours older. He has fallen asleep on the crate with a price card in his hand.", "She does not say thank you. She stands in the doorway looking at it for a long moment, which is the same thing in her language."],
				"choices": [{"label": "\"He's had a Schrippe. Take him home.\"", "next": ""}],
			},
		},
	},
	"nadia_w6": {
		"start": "door",
		"nodes": {
			"door": {
				"speaker": "nadia", "expression": "wary",
				"lines": ["\"Two coffees, two Schrippen.\" Then she does not go. She stands where Herr Bley stands and turns the cup a quarter turn on the laminate.", "Four minutes. For Nadia that is a speech."],
				"choices": [
					{"label": "Wipe the counter. Let her get there.", "effects": {"kiez": 1.0}, "next": "ask"},
					{"label": "[Kiez Sense 12] She is working up to something.", "check": {"stat": "wis", "dc": 12}, "next": "ask", "next_fail": "rota"},
					{"label": "\"Anything else, Nadia?\"", "next": "ask"},
				],
			},
			"ask": {
				"speaker": "nadia", "expression": "upset",
				"lines": ["\"Thursdays,\" she says, to the cigarette wall. \"Could Leo sit here an hour on Thursdays. While my mother's at the clinic.\"", "\"I'm asking. I am actually asking. Don't make a thing of it or I'll withdraw it.\""],
				"choices": [
					{"label": "\"Thursdays. Crate's his. Done.\"", "effects": {"kiez": 2.5, "flags": ["nadia_said_it"]}, "next": "rota"},
					{"label": "[Brains 14] \"Thursdays and the Tuesday handover.\"", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 3.0, "flags": ["nadia_said_it", "nadia_rota_pinned"]}, "next": "rota"},
					{"label": "\"That's a big ask for a shop.\"", "effects": {"kiez": -1.5}, "next": "off"},
				],
			},
			"rota": {
				"speaker": "nadia", "expression": "neutral",
				"lines": ["Her rota goes on the fridge next to the tab list, in her handwriting, in four colours, because of course it is in four colours.", "Mehmet reads it over your shoulder without being invited and photographs it, also without being invited."],
				"choices": [
					{"label": "\"He'll have opinions. He always has opinions.\"", "effects": {"kiez": 1.0, "flags": ["nadia_rota_pinned"]}, "next": "web"},
					{"label": "\"Leave it up. It's a timetable, not a favour.\"", "effects": {"kiez": 1.5, "flags": ["nadia_rota_pinned"]}, "next": "web"},
				],
			},
			"web": {
				"speaker": "nadia", "expression": "warm",
				"lines": ["By Friday there are four names on it. Mehmet drives her the nights the U-Bahn is out. Schulz has volunteered to teach Leo the old money, which nobody asked for.", "\"This is a web,\" Nadia says, in the voice she uses for a diagnosis. \"I've been telling patients about these for twelve years.\""],
				"choices": [
					{"label": "\"And you never once believed in one.\"", "effects": {"kiez": 2.0, "flags": ["nadia_mehmet_drives"]}, "next": "off"},
					{"label": "\"It's a Kiez. Same thing, worse handwriting.\"", "effects": {"kiez": 2.0, "flags": ["nadia_mehmet_drives"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "nadia", "expression": "warm",
				"lines": ["\"It's fine,\" she says on the way out, and this time it is the one that means fine.", "The porter's coffee goes against her wrist. She is thirty seconds late for the first time in six years, and does not run."],
				"choices": [{"label": "\"Bis Donnerstag, Nadia.\"", "next": ""}],
			},
		},
	},
	"nadia_p7": {
		"start": "thursday",
		"nodes": {
			"thursday": {
				"speaker": "nadia", "expression": "warm",
				"lines": ["Half four on a Thursday: two coffees, two Schrippen, and a six-year-old already climbing onto the Pfand crate like it is his desk, because it is.", "\"Twelve sums and a reading book. I'm back at six.\""],
				"choices": [
					{"label": "\"Twelve sums. We'll be done by five.\"", "effects": {"kiez": 1.5, "flags": ["nadia_thursdays"]}, "next": "sums"},
					{"label": "[Hands 12] Cut him a desk out of a beer crate.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.0, "flags": ["nadia_crate_desk"]}, "next": "sums"},
					{"label": "\"Six. Not quarter past six, Nadia.\"", "effects": {"kiez": 1.0}, "next": "sums"},
				],
			},
			"sums": {
				"speaker": "nadia", "expression": "surprised",
				"lines": ["Question four is change from two euro. He does it in his head, out loud, faster than the till does, then looks up to check whether that was allowed.", "\"Mama does it like that too,\" he says. \"In the shop. With her eyes shut.\""],
				"choices": [
					{"label": "\"Then you've both got the till job. Question five.\"", "effects": {"kiez": 1.5, "flags": ["nadia_leo_reads"]}, "next": "regular"},
					{"label": "[Brains 12] Turn the rest of the sums into the till.", "check": {"stat": "int", "dc": 12}, "effects_success": {"kiez": 2.0, "flags": ["nadia_leo_reads"]}, "next": "regular", "next_fail": "regular"},
				],
			},
			"regular": {
				"speaker": "nadia", "expression": "neutral",
				"lines": ["Achim brings him a laminated price card with his name on it, unasked. Robin teaches him a rude word within a fortnight, also unasked.", "By the fourth Thursday the clubbers keep their voices down without being told, which is the strangest thing this counter has ever done."],
				"choices": [
					{"label": "\"He's a regular. Regulars get the crate.\"", "effects": {"kiez": 1.5, "flags": ["nadia_crate_desk"]}, "next": "chain"},
					{"label": "Put his price card behind the till. Front row.", "effects": {"kiez": 2.0, "flags": ["nadia_crate_desk"]}, "next": "chain"},
				],
			},
			"chain": {
				"speaker": "nadia", "expression": "wary",
				"lines": ["\"The chain shuts at eleven,\" she says, out of nowhere, watching him write. \"I looked it up when the letters started going round.\"", "\"There is no line in anybody's plan where a six-year-old does his sums in a shop at half four. I checked that too.\""],
				"choices": [
					{"label": "\"Then the plan's wrong. Not the shop.\"", "effects": {"kiez": 2.0, "flags": ["nadia_thursdays"]}, "next": "off"},
					{"label": "\"I'll be open at four. That's the whole offer.\"", "effects": {"kiez": 2.0, "flags": ["nadia_thursdays"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "nadia", "expression": "warm",
				"lines": ["Six o'clock on the dot. Twelve sums done, four pages read out loud to a fridge, one Schrippe eaten that was not on the bill.", "\"Say goodbye.\" \"Bis Donnerstag,\" he says, to you, in his mother's flat calm voice. Nadia laughs out loud, once, and is as surprised as you are."],
				"choices": [{"label": "\"Bis Donnerstag, Leo.\"", "next": ""}],
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
	# ── ROBIN'S ARC, STEPS 2-7 (docs/09 §2.9). Their card carries FIVE basket rows against a cap of
	#    five, so every token-bearing line (tobacco · papers · filters) is authored first and the
	#    gummi bears are the row that gives — the draft that ordered them the other way round shipped
	#    a raw `{brand.filters}` onto the counter once already. Four faces on disk: neutral, warm,
	#    wary, surprised. There is no `upset`, which is why the crying scene is written as `wary`.
	"robin_s2": {
		"start": "list",
		"nodes": {
			"list": {
				"speaker": "robin", "expression": "wary",
				"lines": ["\"{brand.tobacco}, {brand.papers}, and {brand.filters}. Slim, not the fat ones. And an energy.\" Then, at the fridge: \"Your tab list. On the door.\"", "\"There's a name on it that isn't mine. That's — yeah. That's a whole thing.\" Flat, fast, eyes anywhere else."],
				"choices": [
					{"label": "\"Which line? I'll cross it out now.\"", "effects": {"kiez": 1.5, "flags": ["robin_fridge_name"]}, "next": "card"},
					{"label": "[Kiez Sense 12] They wrote that line themselves.", "check": {"stat": "wis", "dc": 12}, "next": "pen", "next_fail": "card"},
					{"label": "\"It's a list. It's not a document.\"", "effects": {"kiez": -1.0}, "next": "card"},
				],
			},
			"card": {
				"speaker": "robin", "expression": "neutral",
				"lines": ["\"The card's my mum's old account. She still puts money in it, which is the funniest and the worst thing about her.\"", "\"So the card says one thing and I say another, and everyone gets an opinion about which one's true.\""],
				"choices": [
					{"label": "\"The card's a bank's problem. Not mine.\"", "effects": {"kiez": 1.5, "flags": ["robin_bank_card"]}, "next": "pen"},
					{"label": "\"Cash or the tab, then. Your call.\"", "effects": {"kiez": 1.0, "flags": ["robin_bank_card"]}, "next": "pen"},
				],
			},
			"pen": {
				"speaker": "robin", "expression": "surprised",
				"lines": ["You hand them the pen instead of taking the list down yourself, which they were not expecting and cannot immediately be deadpan about.", "\"…You're just going to let me write on your fridge.\""],
				"choices": [
					{"label": "\"It's a fridge, Robin. Not the Grundbuch.\"", "effects": {"kiez": 2.0, "flags": ["robin_fridge_name"]}, "next": "say"},
					{"label": "[Hands 12] Print it properly. Big. Top line.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.5, "flags": ["robin_fridge_name"]}, "next": "say"},
				],
			},
			"say": {
				"speaker": "robin", "expression": "warm",
				"lines": ["ROBIN, in block capitals, third line down — and then they stand there looking at it a beat too long to be casual.", "\"Say it,\" they say. \"Out loud. Once. Then we never do this again.\""],
				"choices": [
					{"label": "\"Robin. Two-forty for the energy, Robin.\"", "effects": {"kiez": 2.0, "flags": ["robin_said_it_back"]}, "next": "out"},
					{"label": "Use it three more times before they leave.", "effects": {"kiez": 2.5, "flags": ["robin_said_it_back"]}, "next": "out"},
				],
			},
			"out": {
				"speaker": "robin", "expression": "warm",
				"lines": ["\"Cool. Great. Normal.\" They take the bag, and the grin arrives about a second late on the way to the door, which is how you know it is real.", "\"Still depressing in here, by the way.\""],
				"choices": [{"label": "\"Bis morgen, Robin.\"", "next": ""}],
			},
		},
	},
	"robin_a3": {
		"start": "forty",
		"nodes": {
			"forty": {
				"speaker": "robin", "expression": "neutral",
				"lines": ["They order the {brand.tobacco} and the {brand.papers}, then go back outside with the phone before you have rung it, and stand under the sign.", "Forty seconds — you can count it off the till clock. Then they come back in and buy {qty.gummi} bag of gummi bears they did not want."],
				"choices": [
					{"label": "Ring the gummi bears. Say nothing.", "effects": {"kiez": 1.0, "flags": ["robin_forty_seconds"]}, "next": "gummi"},
					{"label": "[Kiez Sense 13] Forty seconds is a Mum call.", "requires": {"stat": "wis", "min": 13}, "effects": {"kiez": 1.5, "flags": ["robin_call_home"]}, "next": "summer"},
					{"label": "\"Everything alright out there?\"", "effects": {"kiez": 0.5}, "next": "gummi"},
				],
			},
			"gummi": {
				"speaker": "robin", "expression": "wary",
				"lines": ["\"I don't even like these.\" They open the bag anyway and eat one, standing at the counter, entirely without expression.", "\"She asked when I'm coming home for the summer. Forty seconds, and that was the whole call.\""],
				"choices": [
					{"label": "\"What did you say?\" (\"I'd let her know.\")", "effects": {"kiez": 1.0, "flags": ["robin_call_home"]}, "next": "summer"},
					{"label": "\"Some calls are forty seconds. That's allowed.\"", "effects": {"kiez": 1.5, "flags": ["robin_call_home"]}, "next": "summer"},
				],
			},
			"summer": {
				"speaker": "robin", "expression": "surprised",
				"lines": ["\"She's not a monster. That's the annoying part. She does my washing when I visit and calls me the wrong thing while she's doing it.\"", "\"Eleven months. I keep thinking there's going to be a conversation, and there's just going to be Christmas.\""],
				"choices": [
					{"label": "\"Then have Christmas here. It's warmer.\"", "effects": {"kiez": 1.5, "flags": ["robin_not_the_summer"]}, "next": "stay"},
					{"label": "[Schnauze 12] \"You don't owe her a summer.\"", "check": {"stat": "cha", "dc": 12}, "effects_success": {"kiez": 2.0, "flags": ["robin_not_the_summer"]}, "next": "stay", "next_fail": "out"},
				],
			},
			"stay": {
				"speaker": "robin", "expression": "warm",
				"lines": ["They roll one on the counter, badly, third attempt, and this time do not tell you not to look.", "\"I'm not going back in the summer,\" they say, to the papers rather than to you. \"That's the first time I've said that out loud in a building.\""],
				"choices": [
					{"label": "\"Said out loud in a building. It counts.\"", "effects": {"kiez": 2.0, "flags": ["robin_not_the_summer"]}, "next": "out"},
					{"label": "\"Then that's this year sorted. Two-forty.\"", "effects": {"kiez": 1.5, "flags": ["robin_not_the_summer"]}, "next": "out"},
				],
			},
			"out": {
				"speaker": "robin", "expression": "wary",
				"lines": ["The phone goes face-down into the jacket pocket, which is where it lives for the next week.", "\"Anyway. Depressing in here.\" It lands about a foot short of deadpan, and they know it, and they are gone before you can say so."],
				"choices": [{"label": "\"Bis morgen.\"", "next": ""}],
			},
		},
	},
	"robin_a4": {
		"start": "glass",
		"nodes": {
			"glass": {
				"speaker": "robin", "expression": "neutral",
				"lines": ["Half twelve, and they have been leaning on your glass for twenty minutes before they come in for the {brand.tobacco}, the {brand.papers} and an energy.", "\"Shift finished at eleven,\" they say, unprompted. \"Bus is whenever. It's fine, I like it out there.\""],
				"choices": [
					{"label": "\"There's a bench. It's free. Use it.\"", "effects": {"kiez": 1.0, "flags": ["robin_pavement"]}, "next": "light"},
					{"label": "[Kiez Sense 12] They wait for the shop to empty.", "check": {"stat": "wis", "dc": 12}, "next": "bench", "next_fail": "light"},
					{"label": "\"You can wait inside, you know.\"", "effects": {"kiez": 0.5}, "next": "light"},
				],
			},
			"light": {
				"speaker": "robin", "expression": "wary",
				"lines": ["\"This is the only bit of pavement round here with a light on it that isn't a bank or a police station.\"", "\"I'm not loitering. I'm orbiting. There's a difference and it's mostly the vibes.\""],
				"choices": [
					{"label": "\"Orbit away. Just don't block the door.\"", "effects": {"kiez": 1.0, "flags": ["robin_pavement"]}, "next": "bench"},
					{"label": "[Muscle 11] Drag the bench round under the light.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.0, "flags": ["robin_bench_shift"]}, "next": "bench"},
				],
			},
			"bench": {
				"speaker": "robin", "expression": "warm",
				"lines": ["Four nights a week after that, and the bench is where the waiting happens: bus, shift, friend, nothing in particular.", "Aylin finds them out there one Sunday morning and the two of them talk for an hour about a club neither of them can afford."],
				"choices": [
					{"label": "\"You've met the Sunday people. Congratulations.\"", "effects": {"kiez": 1.5, "flags": ["robin_pavement"]}, "next": "roll"},
					{"label": "Bring two coffees out. Don't stay.", "effects": {"cash": -0.6, "kiez": 2.0, "flags": ["robin_bench_shift"]}, "next": "roll"},
				],
			},
			"roll": {
				"speaker": "robin", "expression": "surprised",
				"lines": ["They are rolling one on the bench, still badly, and this time they turn it round and hold it out. \"Go on. Show me. Once.\"", "Eleven months of not accepting help with it, and it takes three goes to get the sentence out."],
				"choices": [
					{"label": "Roll one slowly, so they can see the hands.", "effects": {"kiez": 2.0, "flags": ["robin_taught_roll"]}, "next": "out"},
					{"label": "[Hands 11] Roll two. Give them the better one.", "check": {"stat": "dex", "dc": 11}, "effects_success": {"kiez": 2.5, "flags": ["robin_taught_roll"]}, "next": "out", "next_fail": "out"},
				],
			},
			"out": {
				"speaker": "robin", "expression": "warm",
				"lines": ["Theirs is still bad. It is a millimetre less bad, which they notice, and they hold it up to the light to check.", "\"Cool. Great. I'm still not accepting help.\" Said from the bench, in the light, on the way to nowhere."],
				"choices": [{"label": "\"Wouldn't dream of it. Bis morgen.\"", "next": ""}],
			},
		},
	},
	"robin_w5": {
		"start": "two_am",
		"nodes": {
			"two_am": {
				"speaker": "robin", "expression": "wary",
				"lines": ["Two in the morning, and the deadpan has come off like a coat. They buy the {brand.tobacco} and the gummi bears and cannot get the card into the reader.", "\"Don't. I'm fine. I'm doing a thing with my face, it's not — I'm fine.\""],
				"choices": [
					{"label": "Gummi bears on the house. Say nothing.", "effects": {"cash": -1.3, "kiez": 1.5, "flags": ["robin_free_gummi"]}, "next": "six"},
					{"label": "[Kiez Sense 12] That is not a bad-shift face.", "check": {"stat": "wis", "dc": 12}, "next": "six", "next_fail": "phase"},
					{"label": "\"Card machine's slow. Take your time.\"", "effects": {"kiez": 1.0}, "next": "six"},
				],
			},
			"six": {
				"speaker": "robin", "expression": "surprised",
				"lines": ["\"Six weeks. SIX. And she told her mates I was a phase she was having.\" It comes out at volume and surprises both of you.", "The clubber by the fridge suddenly needs to read the back of a Mate bottle very carefully."],
				"choices": [
					{"label": "\"Six weeks is long enough to hurt. It counts.\"", "effects": {"kiez": 2.0, "flags": ["robin_six_weeks"]}, "next": "phase"},
					{"label": "[Schnauze 13] \"She's the phase. Obviously.\"", "check": {"stat": "cha", "dc": 13}, "effects_success": {"kiez": 2.0, "flags": ["robin_six_weeks"]}, "next": "sit", "next_fail": "phase"},
				],
			},
			"phase": {
				"speaker": "robin", "expression": "neutral",
				"lines": ["\"The thing is I knew. I knew in week two. I just wanted to be the kind of person who gets six weeks.\"", "\"That's the bit I'm actually crying about, which is embarrassing, so we're not discussing it.\""],
				"choices": [
					{"label": "\"Not discussing it. Noted.\"", "effects": {"kiez": 1.5, "flags": ["robin_six_weeks"]}, "next": "sit"},
					{"label": "\"Everybody wants to be that person.\"", "effects": {"kiez": 1.5, "flags": ["robin_six_weeks"]}, "next": "sit"},
				],
			},
			"sit": {
				"speaker": "robin", "expression": "warm",
				"lines": ["Two forty. The shop is empty, the till is cashed up, and neither of you has mentioned the time.", "They are on the crate with the gummi bears and the third bad roll of the night, and they have stopped apologising for being here."],
				"choices": [
					{"label": "\"I close at three. Not a minute before.\"", "effects": {"kiez": 1.5, "flags": ["robin_stayed_open"]}, "next": "out"},
					{"label": "[Stamina 13] Stay open until the buses start.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "flags": ["robin_stayed_open"]}, "next": "out"},
				],
			},
			"out": {
				"speaker": "robin", "expression": "warm",
				"lines": ["Ten past five, first bus, and they are asleep against the crisp shelf with an empty gummi bear bag in their lap.", "\"If you tell anyone about this,\" they say from under a hood, \"I'll tell everyone your Mate is warm.\""],
				"choices": [{"label": "\"My Mate is ice cold. Get your bus.\"", "next": ""}],
			},
		},
	},
	"robin_w6": {
		"start": "call",
		"nodes": {
			"call": {
				"speaker": "robin", "expression": "wary",
				"lines": ["\"{brand.tobacco}, {brand.papers}, {brand.filters}. And she did it again.\" No preamble at all. \"Forty minutes this time. Every sentence with the old name in it.\"", "\"Like a correction she's making, forever. Berlin was supposed to be the easy part.\""],
				"choices": [
					{"label": "\"Forty minutes is worse than forty seconds.\"", "effects": {"kiez": 1.0}, "next": "short"},
					{"label": "[Brains 13] Ask what she actually said she wants.", "check": {"stat": "int", "dc": 13}, "next": "five", "next_fail": "short"},
					{"label": "\"She'll come round. Mothers do.\"", "effects": {"kiez": -1.0}, "next": "short"},
				],
			},
			"short": {
				"speaker": "robin", "expression": "neutral",
				"lines": ["They put a folded receipt on the counter and do not let go of it straight away. A list, in biro: people who use the right name without being asked.", "\"It's short,\" they say. \"It's genuinely quite short. You're on it, which is embarrassing for both of us.\""],
				"choices": [
					{"label": "\"Short lists are the real ones.\"", "effects": {"kiez": 2.0, "flags": ["robin_short_list"]}, "next": "five"},
					{"label": "\"Who's number one?\" (\"Girl at the café.\")", "effects": {"kiez": 1.5, "flags": ["robin_short_list"]}, "next": "five"},
				],
			},
			"five": {
				"speaker": "robin", "expression": "surprised",
				"lines": ["Five names: a café supervisor, two people from a Thursday night, Aylin — \"the glitter one, she's unhinged, I love her\" — and you, fourth, written down as *the Späti*.", "\"That's not a family,\" they say, testing it, the way they test everything."],
				"choices": [
					{"label": "\"It's five people who turn up. Same thing.\"", "effects": {"kiez": 2.0, "flags": ["robin_named_us"]}, "next": "here"},
					{"label": "[Schnauze 15] \"It is. And it's already here.\"", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 3.0, "flags": ["robin_named_us"]}, "next": "here"},
				],
			},
			"here": {
				"speaker": "robin", "expression": "warm",
				"lines": ["\"I was going to go back in the summer. Properly go back. I had the train booked for about nine days in October.\"", "\"Then I cancelled it and didn't tell anyone — and now I've told a man in a Späti, so that's the announcement done.\""],
				"choices": [
					{"label": "\"Announcement received. Welcome to Berlin.\"", "effects": {"kiez": 2.0, "flags": ["robin_stayed_berlin"]}, "next": "out"},
					{"label": "\"Put the ticket money on your tab instead.\"", "effects": {"kiez": 1.5, "flags": ["robin_stayed_berlin"]}, "next": "out"},
				],
			},
			"out": {
				"speaker": "robin", "expression": "warm",
				"lines": ["The receipt goes back in the rolling tin, under the papers, folded the same way it came out.", "\"Anyway,\" they say at the door. \"Still depressing in here.\" The grin is a full second late and completely unguarded."],
				"choices": [{"label": "\"Bis morgen, Robin.\"", "next": ""}],
			},
		},
	},
	"robin_p7": {
		"start": "four",
		"nodes": {
			"four": {
				"speaker": "robin", "expression": "warm",
				"lines": ["Four of them come in at once and the shop gets forty per cent louder. \"{brand.tobacco}, {brand.papers}, {brand.filters}, four energies, and the gummi bears.\"", "\"This is the guy,\" Robin tells the other three. \"This is the actual guy. He wrote my name on a fridge.\""],
				"choices": [
					{"label": "\"Four energies and the bears. Bench is outside.\"", "effects": {"kiez": 1.5, "flags": ["robin_crew"]}, "next": "bench"},
					{"label": "[Muscle 11] Carry the crate of Mate out to them.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.0, "flags": ["robin_bench_four"]}, "next": "bench"},
					{"label": "\"Keep it down. People live upstairs.\"", "effects": {"kiez": 0.5}, "next": "bench"},
				],
			},
			"bench": {
				"speaker": "robin", "expression": "neutral",
				"lines": ["Four of them on a bench built for three, in three languages, at one in the morning, for two and a half hours.", "Frau Schulz's window goes up once. She listens for a minute, decides against it, and closes it again."],
				"choices": [
					{"label": "Leave them to it. Prop the door open.", "effects": {"kiez": 1.5, "flags": ["robin_bench_four"]}, "next": "loud"},
					{"label": "[Schnauze 12] Go out and get introduced properly.", "check": {"stat": "cha", "dc": 12}, "effects_success": {"kiez": 2.0, "flags": ["robin_crew"]}, "next": "loud", "next_fail": "loud"},
				],
			},
			"loud": {
				"speaker": "robin", "expression": "wary",
				"lines": ["At half one somebody mentions the notices in the front building, and the bench goes quiet in the particular way a bench does when it is nineteen and paying rent.", "\"If they do this street,\" Robin says, \"where does a bench go? There's no bench in a lobby with a keypad.\""],
				"choices": [
					{"label": "\"Then the bench stays. Put it on the poster.\"", "effects": {"kiez": 2.0, "flags": ["robin_crew"]}, "next": "shift"},
					{"label": "\"Thursday. Kiezversammlung. Bring all four.\"", "effects": {"kiez": 2.5, "flags": ["robin_crew", "robin_bench_four"]}, "next": "shift"},
				],
			},
			"shift": {
				"speaker": "robin", "expression": "surprised",
				"lines": ["Then, at the counter, entirely flat, while the others are still outside: \"Do you ever need anyone on a Saturday. For, like, money.\"", "Eleven months ago they could not say their own name at this counter without checking your face first."],
				"choices": [
					{"label": "\"Saturdays. You'd have to learn the wall.\"", "effects": {"kiez": 2.0, "flags": ["robin_shift"]}, "next": "out"},
					{"label": "\"You already know the wall. Start Saturday.\"", "effects": {"kiez": 2.5, "flags": ["robin_shift"]}, "next": "out"},
				],
			},
			"out": {
				"speaker": "robin", "expression": "warm",
				"lines": ["The bench empties at half three. Four bottles come back in for the Pfand, unasked, and the gummi bear bag is in the bin rather than on the pavement.", "\"Still depressing in here,\" Robin says; one of the others says \"it really is\"; and Robin looks personally offended on your behalf."],
				"choices": [{"label": "\"Out, all of you. Bis Samstag, Robin.\"", "next": ""}],
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
	# ── Lena, AUTUMN STEP 3 — "The Gallerist" (docs/09 §2.1). He will hang her only if she makes it
	#    sellable. It reads the summer back: `lena_honest_piece` is why she opens the folder at all,
	#    and `lena_named_it` is the sentence she quotes at him in the studio.
	"lena_a3": {
		"start": "gallerist",
		"nodes": {
			"gallerist": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["\"Mate, ein Schrippe, {brand.tobacco} und {brand.papers}.\" She says it fast, then stands there with the coins still in her hand.", "\"Ähm. A man came to the studio. A gallery man. He has a room in Mitte and a jacket that costs more than my year.\""],
				"choices": [
					{"label": "\"A room in Mitte. Tell me what he said.\"", "effects": {"kiez": 0.5, "flags": ["lena_gallerist_told"]}, "next": "terms"},
					{"label": "[Kiez Sense 12] She has already said yes to something.", "check": {"stat": "wis", "dc": 12}, "next": "terms", "next_fail": "shrug"},
					{"label": "\"Mitte. Congratulations, I suppose.\"", "effects": {"kiez": -0.5}, "next": "shrug"},
				],
			},
			"terms": {
				"speaker": "lena", "expression": "upset",
				"lines": ["\"He liked the flowers. The pretty ones. The ones I make when I'm too tired to make anything.\" She turns the Mate label-out on the laminate, like she works here.", "\"Eight more of those and the room is mine in March. He did not look at the kitchen once.\""],
				"choices": [
					{"label": "\"And the kitchen at four in the morning?\"", "effects": {"kiez": 1.0, "flags": ["lena_kept_faith"]}, "next": "clause"},
					{"label": "\"Eight of them. That's a job, not a show.\"", "effects": {"kiez": 0.5}, "next": "clause"},
					{"label": "\"Paint the flowers. March is March.\"", "effects": {"kiez": -0.5, "flags": ["lena_made_it_sellable"]}, "next": "clause"},
				],
			},
			"shrug": {
				"speaker": "lena", "expression": "upset",
				"lines": ["\"Nothing. It's fine. It's a good thing, it's — ähm.\" The folder goes under her arm corner-first, like a door shut with a shoulder.", "She counts out the fifty cents she is short in two- and five-cent pieces, and does not look up while she does it."],
				"choices": [
					{"label": "Push the coins back. \"Fridge door. Tuesday.\"", "effects": {"kiez": 1.0, "flags": ["lena_gallerist_told"]}, "next": "clause"},
					{"label": "Take the coins. Let her keep the evening.", "next": "clause"},
				],
			},
			"clause": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["Out of the folder comes one page, folded in four: HÄNGUNGSVEREINBARUNG, a signature line, and a paragraph set in about six point.", "\"He said it's standard. Everything is standard when a man says it in a studio with the door open.\""],
				"choices": [
					{"label": "\"Leave it with me. I'll read it tonight.\"", "effects": {"kiez": 0.5}, "next": "answer"},
					{"label": "[Brains 13] Read the six-point now, at the counter.", "check": {"stat": "int", "dc": 13}, "next": "commission", "next_fail": "answer"},
					{"label": "[Hands 12] Copy both sides under the till lamp.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 1.5, "flags": ["lena_contract_copy"]}, "next": "answer"},
				],
			},
			"commission": {
				"speaker": "lena", "expression": "upset",
				"lines": ["Sixty percent. Framing at her cost, hanging at her cost, and a clause that keeps whatever does not sell in his store room until June.", "\"…Sixty. He said forty. He said forty to my face with the door open.\""],
				"choices": [
					{"label": "\"Then he says forty again, in writing, or nothing.\"", "effects": {"kiez": 1.5, "flags": ["lena_contract_copy"]}, "next": "answer"},
					{"label": "\"Sixty of something beats all of a cold studio.\"", "effects": {"kiez": 0.5, "flags": ["lena_made_it_sellable"]}, "next": "answer"},
				],
			},
			"answer": {
				"speaker": "lena", "expression": "warm",
				"lines": ["\"Okay.\" The page goes back in the sleeve, which is where the things she is serious about live. \"I'll tell him Thursday.\"", "At the door she stops. \"You looked at the real one first. Nobody in Mitte did that.\""],
				"choices": [
					{"label": "\"Bring the real one when it's finished.\"", "effects": {"kiez": 1.0, "flags": ["lena_kept_faith"]}, "next": ""},
					{"label": "\"Bis morgen, Lena.\"", "next": ""},
				],
			},
		},
	},
	# ── Lena, AUTUMN STEP 4 — "Nights In The Studio". She stops eating, the tab grows, the radiator
	#    stays dead. The Schrippe missing from the order IS the beat — read the first line twice.
	"lena_a4": {
		"start": "late",
		"nodes": {
			"late": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["01:40. \"Mate, {brand.tobacco}, {brand.papers}. Kein Schrippe.\" She says the order to the laminate rather than to you.", "There is cadmium orange under her nails, and the jumper is the one she had on the night the gallery man came."],
				"choices": [
					{"label": "Put a Schrippe on the counter anyway. No charge.", "effects": {"kiez": 1.0, "cash": -0.4, "flags": ["lena_fed"]}, "next": "count"},
					{"label": "[Kiez Sense 12] When did she last buy food here?", "check": {"stat": "wis", "dc": 12}, "next": "count", "next_fail": "brush"},
					{"label": "\"Kein Schrippe. Right.\" Ring it and say nothing.", "next": "brush"},
				],
			},
			"count": {
				"speaker": "lena", "expression": "upset",
				"lines": ["Four nights. Four Mate, one Schrippe, and the Schrippe was Sunday. The tab on the fridge door is on its eleventh line and all eleven are in your handwriting.", "\"Don't do the face. I eat at the studio.\" There is no kitchen at the studio."],
				"choices": [
					{"label": "\"Then eat here. It comes off the tab at zero.\"", "effects": {"kiez": 2.0, "cash": -0.4, "flags": ["lena_fed", "lena_tab_deep"]}, "next": "heater"},
					{"label": "\"Eleven lines. I'm not counting. I'm noticing.\"", "effects": {"kiez": 1.0, "flags": ["lena_tab_deep"]}, "next": "heater"},
				],
			},
			"brush": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["She rolls one on the counter with the long papers, badly, because her hands are cold and she is not going to say so.", "\"Eight flowers. Three done. He wants all eight by the sixth.\""],
				"choices": [
					{"label": "\"Three in four nights. You're not sleeping.\"", "effects": {"kiez": 0.5}, "next": "heater"},
					{"label": "\"The sixth is his date, Lena. Not yours.\"", "effects": {"kiez": 1.0}, "next": "heater"},
				],
			},
			"heater": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["\"The radiator did the 1994 thing again. Sascha hit it with a shoe and it made a noise like a tram.\"", "There is a fan heater out the back that Cem used for the two winters the fridge motor leaked. It has been behind the crates since March."],
				"choices": [
					{"label": "\"Come in at four when you can't feel your hands.\"", "effects": {"kiez": 1.0, "flags": ["lena_open_at_four"]}, "next": "off"},
					{"label": "[Muscle 11] Carry the fan heater over to the studio.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.5, "cash": -6.0, "flags": ["lena_radiator"]}, "next": "walk"},
					{"label": "\"1994 was a long time ago. Wear a coat.\"", "effects": {"kiez": -0.5}, "next": "off"},
				],
			},
			"walk": {
				"speaker": "lena", "expression": "warm",
				"lines": ["Four streets with a fan heater under your arm and the shop shut for eleven minutes. The studio smells of turps and cold plaster and there are four bikes in the hall.", "The kitchen at four in the morning is on the wall facing the door, where she has to look at it. The flowers are stacked with their faces to the bricks."],
				"choices": [
					{"label": "\"That's the wrong way round and you know it.\"", "effects": {"kiez": 1.5, "flags": ["lena_radiator"]}, "next": ""},
					{"label": "Plug it in, say nothing, go back and open up.", "effects": {"kiez": 1.0, "flags": ["lena_radiator", "lena_open_at_four"]}, "next": ""},
				],
			},
			"off": {
				"speaker": "lena", "expression": "warm",
				"lines": ["\"Tuesday,\" she says, which is a joke the two of you have now, and leaves the Pfand on the counter and calls it forgetfulness so neither of you has to call it a tip."],
				"choices": [
					{"label": "\"Tuesday.\"", "next": ""},
				],
			},
		},
	},
	# ── Lena, WINTER STEP 5 — "The Show". The honest piece, or the one that sells. She has carried
	#    nine canvases to hang eight, which is the tell; `lena_hung_it` is why the ninth is in the bag.
	"lena_w5": {
		"start": "hang",
		"nodes": {
			"hang": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["\"Mate, {brand.tobacco}, {brand.papers}. And a bag, a proper one.\" There are nine canvases against the fridge door, eight of them face in.", "\"Hanging is Saturday. He wants the eight flowers on the wall by the window.\""],
				"choices": [
					{"label": "\"And the ninth. What's that doing here?\"", "effects": {"kiez": 1.0}, "next": "turned"},
					{"label": "[Kiez Sense 12] She brought nine canvases to hang eight.", "check": {"stat": "wis", "dc": 12}, "next": "turned", "next_fail": "count"},
					{"label": "\"Saturday. I'll shut early and come.\"", "effects": {"kiez": 1.0, "flags": ["lena_came_to_show"]}, "next": "count"},
				],
			},
			"turned": {
				"speaker": "lena", "expression": "upset",
				"lines": ["The kitchen at four in the morning. She has been carrying it round the Kiez in a bin bag for a week and has not hung it anywhere, including the studio.", "\"It doesn't go with the eight. That's what he said. It doesn't GO with them.\""],
				"choices": [
					{"label": "\"That's the point of it. It isn't supposed to go.\"", "effects": {"kiez": 1.5, "flags": ["lena_show_honest"]}, "next": "nail"},
					{"label": "[Schnauze 13] \"Hang nine. Make him take one down.\"", "check": {"stat": "cha", "dc": 13}, "next": "nine", "next_fail": "count"},
					{"label": "\"Eight is the deal. Take the deal.\"", "effects": {"kiez": -0.5, "flags": ["lena_show_flowers"]}, "next": "count"},
				],
			},
			"nine": {
				"speaker": "lena", "expression": "warm",
				"lines": ["She laughs once, the ugly honest one, and writes NEUN on the back of her hand with the pencil she keeps behind her ear.", "\"If he takes it down, I'll know he took it down. That's — ähm. That's information.\""],
				"choices": [
					{"label": "\"That's information. Hang nine.\"", "effects": {"kiez": 2.0, "flags": ["lena_show_honest"]}, "next": "nail"},
				],
			},
			"count": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["She counts the Mate out in coins and is forty cents short, which is closer than she has been since the summer, and she is pleased about it and will not say so.", "\"Sales pay in March. Everything in this city pays in March.\""],
				"choices": [
					{"label": "\"Fridge door. You know where the pen is.\"", "effects": {"kiez": 0.5, "flags": ["lena_credit"]}, "next": "nail"},
					{"label": "Forty cents out of your own pocket. Say nothing.", "effects": {"kiez": 1.0, "cash": -0.4}, "next": "nail"},
				],
			},
			"nail": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["The bin bag has worn through at one corner and the stretcher is showing. It is four streets to the S-Bahn, the S-Bahn is out at Warschauer, and it is December.", "\"I'll manage. I have managed the whole way here.\""],
				"choices": [
					{"label": "\"Take the hand truck. Bring it back Tuesday.\"", "effects": {"kiez": 1.0}, "next": "off"},
					{"label": "[Stamina 13] Shut the shop and carry the nine over.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "cash": -22.0, "flags": ["lena_came_to_show", "lena_show_honest"]}, "next": "off"},
					{"label": "\"Then manage. I've got a night to run.\"", "effects": {"kiez": -0.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "lena", "expression": "warm",
				"lines": ["\"Saturday. Seven. There is wine in plastic cups and everybody will be terrible.\"", "She leaves the Pfand on the counter, as always, and is out of the door before you can call it a tip."],
				"choices": [
					{"label": "\"Saturday.\"", "next": ""},
				],
			},
		},
	},
	# ── Lena, WINTER STEP 6 — "Help Isn't Failing". She asks out loud, which costs her more than the
	#    money ever did — and the piece that sold is the honest one (`lena_honest_piece`, last July).
	"lena_w6": {
		"start": "door",
		"nodes": {
			"door": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["02:10, and she is at the counter with no portfolio, which has not happened once since June. \"Mate. And {brand.tobacco}, if the tab — ähm.\"", "The Schrippe she is looking at is the last one in the basket, and she has been looking at it for a while."],
				"choices": [
					{"label": "Put the Schrippe in front of her. \"It's going stale.\"", "effects": {"kiez": 1.0, "cash": -0.4, "flags": ["lena_fed"]}, "next": "ask"},
					{"label": "[Kiez Sense 13] Wait. Do not fill the silence for her.", "check": {"stat": "wis", "dc": 13}, "next": "ask", "next_fail": "deflect"},
					{"label": "\"The tab's on nineteen lines, Lena.\"", "effects": {"kiez": -0.5}, "next": "deflect"},
				],
			},
			"ask": {
				"speaker": "lena", "expression": "upset",
				"lines": ["\"I need —\" She stops, starts again, and puts both hands flat on the laminate like she is bracing against it.", "\"I need to eat here. For a while. I'm not asking for money, I'm asking for the thing you already do, out loud, which is worse.\""],
				"choices": [
					{"label": "\"Okay. Every night. Come at two, it's quiet.\"", "effects": {"kiez": 2.0, "flags": ["lena_asked_for_help", "lena_fed"]}, "next": "work"},
					{"label": "\"Asking out loud is the whole job. Welcome to it.\"", "effects": {"kiez": 1.5, "flags": ["lena_asked_for_help"]}, "next": "work"},
				],
			},
			"deflect": {
				"speaker": "lena", "expression": "upset",
				"lines": ["\"Nothing. Forget it. The gallery pays in March, everybody knows March.\"", "She rolls one with the long papers, and her hands are not steady enough to do it in one go, so she does it in three, at your counter, in front of you."],
				"choices": [
					{"label": "\"Sit on the crate. I'll put the kettle on.\"", "effects": {"kiez": 1.5, "flags": ["lena_asked_for_help"]}, "next": "work"},
					{"label": "Slide the Schrippe across and go back to the till.", "effects": {"kiez": 1.0, "cash": -0.4, "flags": ["lena_fed"]}, "next": "work"},
				],
			},
			"work": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["\"The kitchen one sold. On Saturday. To a woman who said it made her cry in an aisle in a Kaufland in 1997.\"", "\"Four hundred euro. And I haven't touched it, because the second I touch it it is rent and not a painting.\""],
				"choices": [
					{"label": "\"Then it's rent. The painting already happened.\"", "effects": {"kiez": 1.0, "flags": ["lena_honest_is_work"]}, "next": "tab"},
					{"label": "[Brains 12] Work out what four hundred actually covers.", "check": {"stat": "int", "dc": 12}, "next": "sums", "next_fail": "tab"},
				],
			},
			"sums": {
				"speaker": "lena", "expression": "warm",
				"lines": ["Two months of her half of the flat, the studio's winter share, and eleven euro forty of a tab on a fridge door in a Späti.", "\"…You've had eleven euro forty of my life on a door for six months and you never once said the number.\""],
				"choices": [
					{"label": "\"The number was never the point.\"", "effects": {"kiez": 1.5, "flags": ["lena_honest_is_work"]}, "next": "tab"},
					{"label": "\"Cem had a bigger one on the back of a receipt.\"", "effects": {"kiez": 1.0}, "next": "tab"},
				],
			},
			"tab": {
				"speaker": "lena", "expression": "warm",
				"lines": ["The gallery envelope goes on the counter between the till and the Pfand crate, and she squares it to the edge, which is not a thing she does.", "\"Take the eleven forty. I want the door clean before I ask you for anything else.\""],
				"choices": [
					{"label": "Take it, and write PAID on the fridge in her pencil.", "effects": {"kiez": 1.0, "cash": 11.4, "flags": ["lena_tab_wiped"]}, "next": "off"},
					{"label": "[Hands 12] Tear the list off the door and hand it over.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.5, "flags": ["lena_tab_wiped", "lena_honest_is_work"]}, "next": "off"},
					{"label": "\"Pay me in March. The door is patient.\"", "effects": {"kiez": 1.0}, "next": "off"},
				],
			},
			"off": {
				"speaker": "lena", "expression": "warm",
				"lines": ["\"Okay,\" she says, twice, which is how you know she means it. She eats the Schrippe standing at the counter, in four bites, and does not apologise for it once."],
				"choices": [
					{"label": "\"Bis morgen, Lena.\"", "next": ""},
				],
			},
		},
	},
	# ── Lena, SPRING STEP 7 — "The Wall". She clears the tab in paint and becomes a regular who gives.
	#    `lena_wall_offer` was the nail you offered her in the summer; this is her taking it.
	"lena_p7": {
		"start": "ladder",
		"nodes": {
			"ladder": {
				"speaker": "lena", "expression": "warm",
				"lines": ["April, eight in the evening, like a person with a day. \"{qty.mate}× Mate, {brand.tobacco}, {brand.papers}.\" She has paid, in a note, before you rang it.", "There is a stepladder against the ice-cream chest that does not belong to her and has clearly come four streets."],
				"choices": [
					{"label": "\"Whose ladder is that, Lena.\"", "effects": {"kiez": 1.0}, "next": "pitch"},
					{"label": "[Kiez Sense 12] She has already measured the long wall.", "check": {"stat": "wis", "dc": 12}, "next": "measured", "next_fail": "pitch"},
					{"label": "Ring the Mate. Ignore the ladder.", "next": "pitch"},
				],
			},
			"measured": {
				"speaker": "lena", "expression": "warm",
				"lines": ["There is a folded sheet in her back pocket with your long wall on it to scale, the socket marked, and the crates drawn in pencil where they actually stand.", "\"Three metres forty. I did it on a Tuesday while you were out the back swearing at the fridge.\""],
				"choices": [
					{"label": "\"You measured my wall behind my back.\"", "effects": {"kiez": 1.0, "flags": ["lena_mural"]}, "next": "pitch"},
				],
			},
			"pitch": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["\"The corner at four in the morning. You, the crate, Jürgen's bags, the light off the fridge doing the thing it does to the floor.\"", "\"Not pretty. The other kind. And it comes off nothing, because there's nothing on the door any more — it's just what I want to paint.\""],
				"choices": [
					{"label": "\"Then paint it. I'll move the crates on Sunday.\"", "effects": {"kiez": 1.5, "flags": ["lena_mural"]}, "next": "night"},
					{"label": "[Brains 12] What does a wall like that do to a shop?", "check": {"stat": "int", "dc": 12}, "next": "sign", "next_fail": "night"},
					{"label": "\"A shop isn't a gallery, Lena. Sorry.\"", "effects": {"kiez": -1.0}, "next": "refused"},
				],
			},
			"sign": {
				"speaker": "lena", "expression": "warm",
				"lines": ["A wall like that is a reason to come in, a photograph on somebody's phone, and a thing the Lindner brochure has no word for — for the price of one Sunday and four litres of white.", "\"…You did a sum. You did a sum about my painting.\" She is delighted and refuses to show it."],
				"choices": [
					{"label": "\"I did a sum. It came out your way. Paint it.\"", "effects": {"kiez": 1.5, "flags": ["lena_mural"]}, "next": "night"},
					{"label": "\"I run a shop. The shop says yes.\"", "effects": {"kiez": 1.0, "flags": ["lena_mural"]}, "next": "night"},
				],
			},
			"refused": {
				"speaker": "lena", "expression": "upset",
				"lines": ["\"Ja. Okay. It was a stupid — no. It wasn't stupid.\" She picks the stepladder back up and it is heavier than it was coming in.", "\"I'd have done it for nothing. That was the whole thing about it.\""],
				"choices": [
					{"label": "\"Sunday. Bring the paint. I'll move the crates.\"", "effects": {"kiez": 1.5, "flags": ["lena_mural"]}, "next": "night"},
					{"label": "\"I know. Bis morgen, Lena.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
			"night": {
				"speaker": "lena", "expression": "neutral",
				"lines": ["She paints four nights, from two until it gets light, with the radio low and the door locked and a Mate going warm on top of the fridge.", "On the fourth night the wall is finished except for the bottom right corner, which is empty and about the size of a hand."],
				"choices": [
					{"label": "\"You've left a hole in it.\"", "next": "sign_it"},
					{"label": "[Hands 12] Take the brush when she holds it out.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.5, "flags": ["lena_signed_it"]}, "next": "sign_it"},
					{"label": "\"Leave it. It's finished when you say it is.\"", "effects": {"kiez": 1.0}, "next": "sign_it"},
				],
			},
			"sign_it": {
				"speaker": "lena", "expression": "warm",
				"lines": ["\"That's the tab,\" she says. \"That's the whole tab, in paint. I'm a person who gives things now instead of a person who owes them, and it took a year.\"", "There are four names from the art school in her pocket who will do the Versammlung posters for nothing, and she has already asked all four."],
				"choices": [
					{"label": "\"Bring all four. There's coffee and there's a wall.\"", "effects": {"kiez": 2.0, "flags": ["lena_gives_now"]}, "next": "off"},
					{"label": "\"You never owed me anything, Lena.\"", "effects": {"kiez": 1.0, "flags": ["lena_gives_now"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "lena", "expression": "warm",
				"lines": ["She puts the Pfand in the crate herself on the way out, which she has never once done, and calls it back over her shoulder: \"That one's a tip. Say it out loud.\""],
				"choices": [
					{"label": "\"That one's a tip.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Jürgen, SUMMER STEP 2 — "The Crate Is Yours" (docs/09 §2.2). The crate moves to the step,
	#    which is the only door on this street that opens for him, and he gives you a surname.
	#    NOTE ON FACES: `juergen` has only `neutral` and `warm` on disk (docs/09 §3, wave 2 has not
	#    reached him), so every node here wears one of those two — a tree may not promise a bust the
	#    art lane has not drawn, because `portrait_asset` falls back to `_neutral` and the player
	#    simply sees a face that never changed.
	"juergen_s2": {
		"start": "outside",
		"nodes": {
			"outside": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["22:00, two bags, and he is on the step rather than through the door, the way he has stood there since Cem's time.", "\"{qty.schrippe}× Schrippe, {qty.beer}× Sterni. And {qty.cigarettes}× {brand.cigarettes} if it reaches, Chef. Twenty-nine tonight. The Automat at Ostkreuz is out of order.\""],
				"choices": [
					{"label": "\"Twenty-nine is two ninety. Come in off the step.\"", "effects": {"kiez": 1.0}, "next": "crate"},
					{"label": "[Kiez Sense 12] Twenty-nine, and he stopped early. Why?", "check": {"stat": "wis", "dc": 12}, "next": "early", "next_fail": "crate"},
					{"label": "\"Two ninety. The pack is three sixty, Jürgen.\"", "next": "crate"},
				],
			},
			"early": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["He is finished forty minutes early, and the crate he has used for three years is not with him. There is a bin-bag knot in his left hand instead.", "\"The handle went. It was a crate, Chef, not a marriage.\""],
				"choices": [
					{"label": "\"There's a stack of them out the back. Take one.\"", "effects": {"kiez": 1.5, "flags": ["juergen_crate"]}, "next": "crate"},
					{"label": "\"Three years. You counted every bottle in it.\"", "effects": {"kiez": 1.0}, "next": "crate"},
				],
			},
			"crate": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["There is a Pfand crate inside the door with four bottles in it that customers left, and it has been in there all night where nobody could reach it but you.", "He looks at it the way a man looks at a thing he has decided not to mention."],
				"choices": [
					{"label": "\"That one's out on the step from now on.\"", "effects": {"kiez": 1.5, "flags": ["juergen_crate_out_front"]}, "next": "terms"},
					{"label": "[Muscle 11] Put it out on the step yourself, in front of him.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.0, "flags": ["juergen_crate_out_front", "juergen_crate"]}, "next": "terms"},
					{"label": "Hand him the four bottles over the counter.", "effects": {"kiez": 0.5}, "next": "terms"},
				],
			},
			"terms": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"Then it is a system,\" he says, and you can hear him filing it. \"I empty it, I bring the crate back, I do not take what is not in it.\"", "\"Write it down if you like. I have never once argued with a written thing.\""],
				"choices": [
					{"label": "\"It's not a contract, Jürgen. It's a crate.\"", "effects": {"kiez": 1.0}, "next": "name"},
					{"label": "[Hands 12] Write it on card and tape it to the crate.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.0, "flags": ["juergen_written"]}, "next": "name"},
					{"label": "\"Fine. Your crate, your rules, your route.\"", "effects": {"kiez": 0.5, "flags": ["juergen_crate_out_front"]}, "next": "name"},
				],
			},
			"name": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["\"Massek,\" he says, apropos of nothing, counting the two ninety into your palm in tens. \"Jürgen Massek. In case it goes on the card.\"", "It is the first time he has given you a surname in four months of nightly transactions."],
				"choices": [
					{"label": "\"Massek. It's on the card by tomorrow.\"", "effects": {"kiez": 1.5, "flags": ["juergen_named"]}, "next": "off"},
					{"label": "\"Noted, Herr Massek.\"", "effects": {"kiez": 1.0, "flags": ["juergen_named"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["\"Bis später, Chef.\" The bags go over the shoulder, one each side, balanced, because thirty years at a works teaches a man how to carry.", "Three hours later the crate on the step is empty and stacked square against the wall."],
				"choices": [
					{"label": "\"Bis später.\"", "next": ""},
				],
			},
		},
	},
	# ── Jürgen, AUTUMN STEP 3 — "The Chain Locks Its Bins". Half the route dies in a week, and he
	#    reports it as logistics because that is the only register he has for being frightened.
	"juergen_a3": {
		"start": "short",
		"nodes": {
			"short": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"{qty.schrippe}× Schrippe. Nothing else tonight.\" No Sterni, and no {brand.cigarettes}, which has not happened since the spring.", "\"Eleven bottles. I counted twice. It is eleven.\""],
				"choices": [
					{"label": "\"Eleven. What happened to the arches?\"", "effects": {"kiez": 0.5}, "next": "bins"},
					{"label": "[Kiez Sense 11] Eleven is not a bad night. It is a cut route.", "check": {"stat": "wis", "dc": 11}, "next": "bins", "next_fail": "shrug"},
					{"label": "Ring up the Schrippe. One ten.", "next": "shrug"},
				],
			},
			"bins": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["The chain Spätkauf opened on Monday, and on Tuesday they put a padlock through the hasp on both wheelie bins in the Hof behind it.", "\"It is their Hof. It is their bin. I am not complaining, Chef, I am telling you the route. The arches, the park, the kiosk. That is the route now.\""],
				"choices": [
					{"label": "\"That's half your week behind one padlock.\"", "effects": {"kiez": 1.0, "flags": ["juergen_chain"]}, "next": "list"},
					{"label": "[Brains 12] Work out what eleven bottles a night is.", "check": {"stat": "int", "dc": 12}, "next": "sums", "next_fail": "list"},
				],
			},
			"shrug": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"One ten.\" He counts it out in coppers, which he has not had to do since the summer, and it takes a while, and he does not hurry it.", "\"The weather turns Thursday. Wind from the east. That is not a complaint either.\""],
				"choices": [
					{"label": "\"Sit on the crate a minute. The kettle's on.\"", "effects": {"kiez": 1.0}, "next": "list"},
					{"label": "\"East wind. Noted.\"", "next": "list"},
				],
			},
			"sums": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["Eleven bottles is one euro ten. Forty-one was four ten. Three euro a night is a Schrippe, a coffee, and the difference between two of the three things he buys here.", "\"You did that quickly,\" he says, mildly offended on behalf of arithmetic."],
				"choices": [
					{"label": "\"Thirty years a fitter. You had it first.\"", "effects": {"kiez": 1.0, "flags": ["juergen_chain"]}, "next": "list"},
					{"label": "\"Three euro. Say the number out loud, Jürgen.\"", "effects": {"kiez": 0.5, "flags": ["juergen_chain"]}, "next": "list"},
				],
			},
			"list": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["There are four other doors on this street with a Hof, a bin and a landlord who does not care, and you know every one of them by first name.", "\"I do not knock on doors,\" he says, before you have said anything at all. \"I collect. Knocking is a different profession.\""],
				"choices": [
					{"label": "\"Then I'll knock. You collect.\"", "effects": {"kiez": 1.5, "flags": ["juergen_new_route"]}, "next": "off"},
					{"label": "[Schnauze 12] Talk him into coming to two of them.", "check": {"stat": "cha", "dc": 12}, "next": "along", "next_fail": "off"},
					{"label": "[Stamina 13] Shut for an hour and do all four tonight.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "cash": -14.0, "flags": ["juergen_new_route", "juergen_warm"]}, "next": "along"},
				],
			},
			"along": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["Two doors. At the second one the woman says \"ach, der Flaschenmann\" before you have finished the sentence, and Jürgen stands one step behind you and says absolutely nothing.", "On the way back: \"She knew me. Twelve years on this street and I did not know that she knew me.\""],
				"choices": [
					{"label": "\"Everybody knows you, Jürgen. That's the point.\"", "effects": {"kiez": 1.5, "flags": ["juergen_new_route"]}, "next": "off"},
					{"label": "\"Four bins. That's the road back to forty-one.\"", "effects": {"kiez": 1.0, "flags": ["juergen_new_route"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"Bis später, Chef.\" One bag tonight instead of two, and he balances it anyway, out of habit.", "The padlock on the chain's bin is a good one. You looked, on the way past, and you are not proud of that."],
				"choices": [
					{"label": "\"Bis später.\"", "next": ""},
				],
			},
		},
	},
	# ── Jürgen, AUTUMN STEP 4 — "Not A Winter Jacket". The rhythm gets thinner and the cold does not.
	#    Cem's coat has been on the same hook since March; the only way he can take it is as storage.
	"juergen_a4": {
		"start": "cold",
		"nodes": {
			"cold": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["Minus two and a wind off the water. \"{qty.schrippe}× Schrippe. And {qty.cigarettes}× {brand.cigarettes}. Thirty-eight bottles, Chef — the four doors are working.\"", "The jacket is the same jacket. It was a good jacket in about 1994 and it is a windbreaker now."],
				"choices": [
					{"label": "\"Thirty-eight. The four doors are working.\"", "effects": {"kiez": 0.5}, "next": "hands"},
					{"label": "[Kiez Sense 12] Look at the jacket, not the count.", "check": {"stat": "wis", "dc": 12}, "next": "hands", "next_fail": "weather"},
					{"label": "\"Three eighty. Anything else?\"", "next": "weather"},
				],
			},
			"hands": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["His hands are the wrong colour and he cannot get the coins apart on the laminate. He does it one at a time, with a thumbnail, and does not look up.", "\"It is October. It is supposed to be cold in October.\""],
				"choices": [
					{"label": "Put a coffee in front of him without asking.", "effects": {"kiez": 1.5, "cash": -0.3, "flags": ["juergen_warm"]}, "next": "coat"},
					{"label": "\"Warm them on the machine. That's an order.\"", "effects": {"kiez": 1.0, "flags": ["juergen_warm"]}, "next": "coat"},
				],
			},
			"weather": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"Frost Thursday, then it lifts. The app says Saturday. The app is wrong about this street — there is the arches, and the water, and it comes down the Ringbahn cut.\"", "It is the longest thing he has said in a month and it is entirely about the weather, which is how he says everything else."],
				"choices": [
					{"label": "\"Thursday, then. Come at ten, I'll have the pot on.\"", "effects": {"kiez": 1.0, "flags": ["juergen_warm"]}, "next": "coat"},
					{"label": "\"Noted. Frost Thursday.\"", "effects": {"kiez": 0.5}, "next": "coat"},
				],
			},
			"coat": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["There is a proper winter coat in the back room. It was Cem's, it is too big for you, and it has hung on the same hook since March.", "\"No,\" he says, to a sentence you have not started. \"I have a jacket.\""],
				"choices": [
					{"label": "\"It's Cem's. It's been on a hook for eight months.\"", "effects": {"kiez": 1.0}, "next": "deal"},
					{"label": "[Schnauze 13] Make it a transaction, not a gift.", "check": {"stat": "cha", "dc": 13}, "next": "deal", "next_fail": "refuse"},
					{"label": "Leave it. He said no.", "effects": {"kiez": 0.5, "flags": ["juergen_refused_coat"]}, "next": "off"},
				],
			},
			"deal": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["\"The bins are heavy and the coat is in the way of the crates. Take it off the hook for me and I will call it storage.\" He looks at you for three full seconds.", "\"…Storage,\" he says. \"Ja. Storage I can do.\""],
				"choices": [
					{"label": "\"Storage. Bring it back in April if you like.\"", "effects": {"kiez": 2.0, "flags": ["juergen_jacket"]}, "next": "off"},
					{"label": "[Muscle 11] Get it down off the hook and hold it open.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.5, "flags": ["juergen_jacket", "juergen_warm"]}, "next": "off"},
				],
			},
			"refuse": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"I am not a case, Chef. I am a customer who counts well.\" He says it without any heat at all, which is worse than if there had been some.", "\"The jacket does the job. It has done the job for some years now.\""],
				"choices": [
					{"label": "\"You're a customer. The coffee's still free.\"", "effects": {"kiez": 1.0, "flags": ["juergen_refused_coat"]}, "next": "off"},
					{"label": "\"It's on the hook. It'll be there Thursday.\"", "effects": {"kiez": 0.5, "flags": ["juergen_refused_coat"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["\"Bis später.\" The bell, the wind, and the crate going back square against the wall in the dark.", "He stops at the corner to change hands on the bags, which he never used to have to do."],
				"choices": [
					{"label": "\"Bis später, Jürgen.\"", "next": ""},
				],
			},
		},
	},
	# ── Jürgen, WINTER STEP 5 — "The Night He Doesn't Come". Two nights, a full crate, and then the
	#    bell at 04:20. The Hof behind the chain has a hot-air outlet that goes off when they cash up.
	"juergen_w5": {
		"start": "late",
		"nodes": {
			"late": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["Two nights, no Jürgen, and the crate on the step full to the lip both mornings. At 04:20 on the third the bell goes and he is in the doorway with one bag and no crate.", "\"{qty.schrippe}× Schrippe,\" he says, from the door. \"Nothing else. Six bottles. I did not count them twice.\""],
				"choices": [
					{"label": "\"Come in and shut it. You're letting the night in.\"", "effects": {"kiez": 1.0}, "next": "chest"},
					{"label": "[Kiez Sense 12] He did not count them twice.", "check": {"stat": "wis", "dc": 12}, "next": "chest", "next_fail": "logistics"},
					{"label": "\"Six. That's sixty cents, Jürgen.\"", "next": "logistics"},
				],
			},
			"chest": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["The cough starts at the counter and goes on long enough that he puts a hand flat on the laminate to wait it out. It is coming from somewhere lower than a throat.", "\"It is a cold. Everybody has a cold. It is January.\""],
				"choices": [
					{"label": "\"Sit down. On the crate. Now, please.\"", "effects": {"kiez": 1.5, "flags": ["juergen_slept_in"]}, "next": "hof"},
					{"label": "[Stamina 13] Shut the shop, walk him to the Notdienst.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "cash": -20.0, "flags": ["juergen_doctor", "juergen_warm"]}, "next": "doctor"},
					{"label": "\"That's not a cold. Where are you sleeping?\"", "effects": {"kiez": 0.5}, "next": "hof"},
				],
			},
			"logistics": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"Sixty cents, and the Schrippe is one ten, so it is fifty short and I will bring it Thursday.\" The arithmetic is perfect. The hand holding the bag is not steady.", "\"Two nights is not a thing. The Automat was out. The weather was the weather.\""],
				"choices": [
					{"label": "\"The Schrippe's on the house. Sit down a minute.\"", "effects": {"kiez": 1.5, "cash": -0.4, "flags": ["juergen_slept_in"]}, "next": "hof"},
					{"label": "\"Thursday, then. I'll be counting, Jürgen.\"", "effects": {"kiez": 0.5}, "next": "hof"},
				],
			},
			"hof": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["The Hof behind the chain Spätkauf has a roof over one corner and a hot-air outlet from their fridges that runs until they cash up.", "\"They shut at eleven now,\" he says, to the fridge rather than to you. \"The outlet goes off at eleven. That is all that changed.\""],
				"choices": [
					{"label": "\"There's a bench inside my door. Heat's on till four.\"", "effects": {"kiez": 2.0, "flags": ["juergen_hof"]}, "next": "off"},
					{"label": "[Schnauze 12] Make the bench a job so he can take it.", "check": {"stat": "cha", "dc": 12}, "next": "job", "next_fail": "off"},
					{"label": "\"Eleven. That's five hours of January, Jürgen.\"", "effects": {"kiez": 1.0, "flags": ["juergen_hof"]}, "next": "off"},
				],
			},
			"doctor": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["Forty minutes under a strip light, and he gives the woman at the desk his full name, his date of birth and his address without a flicker, and the address is a Postfach.", "On the walk back: \"You shut the shop. On a Friday. For a cough.\""],
				"choices": [
					{"label": "\"For a chest infection. Antibiotics Monday.\"", "effects": {"kiez": 1.5, "flags": ["juergen_doctor"]}, "next": "off"},
					{"label": "\"The shop shuts when I say. Bench, inside, till four.\"", "effects": {"kiez": 2.0, "flags": ["juergen_doctor", "juergen_hof"]}, "next": "off"},
				],
			},
			"job": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["\"Somebody has to watch the door between two and four while I do the stock,\" you say, which is not true, and he considers it with complete seriousness, which is both worse and better.", "\"I would need a key for the crate,\" he says. \"For the crate only.\""],
				"choices": [
					{"label": "\"For the crate only. Starts tonight.\"", "effects": {"kiez": 2.5, "flags": ["juergen_hof", "juergen_bench"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["He eats half the Schrippe standing up, which he has never done in front of you, and puts the other half in the jacket for later.", "\"Bis später, Chef.\" At the door: \"Frost until Tuesday. The app says Sunday. The app is wrong.\""],
				"choices": [
					{"label": "\"Tuesday, then. Bis später.\"", "next": ""},
				],
			},
		},
	},
	# ── Jürgen, WINTER STEP 6 — "Seen". The bench inside the door is his and nobody asks. The whole
	#    beat is a man trying to finish one sentence at a counter, and whether you let him.
	"juergen_w6": {
		"start": "bench",
		"nodes": {
			"bench": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["He is on the bench inside the door at half past one with the crate at his feet. He has been there forty minutes and nobody has asked him anything.", "\"{qty.schrippe}× Schrippe, {qty.beer}× Sterni, and {qty.cigarettes}× {brand.cigarettes}. Fifty-two bottles. The count reached.\""],
				"choices": [
					{"label": "\"Fifty-two. It reached. The Sterni's cold.\"", "effects": {"kiez": 1.0}, "next": "regulars"},
					{"label": "[Kiez Sense 11] Nobody has looked at him twice all night.", "check": {"stat": "wis", "dc": 11}, "next": "regulars", "next_fail": "ring"},
					{"label": "Ring the three of it up. Five twenty.", "next": "ring"},
				],
			},
			"regulars": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["Four people have come in since he sat down. Two said Abend to him. One asked about the weather and got a forecast with reasons. Nobody asked him to move.", "\"The one with the dog calls me Herr Massek,\" he says. \"I have not corrected her.\""],
				"choices": [
					{"label": "\"Nobody's going to correct her.\"", "effects": {"kiez": 1.5, "flags": ["juergen_seen"]}, "next": "keys"},
					{"label": "\"It's your bench. Has been for a month.\"", "effects": {"kiez": 1.0, "flags": ["juergen_bench"]}, "next": "keys"},
				],
			},
			"ring": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["Five twenty, counted out of the Pfand slip and the coppers, exact, nothing left over, the way it has been every night since the summer.", "He does not go. He turns the Sterni a quarter turn on the laminate and stays where he is."],
				"choices": [
					{"label": "\"Sit down, Jürgen. The bench isn't going anywhere.\"", "effects": {"kiez": 1.5, "flags": ["juergen_bench"]}, "next": "keys"},
					{"label": "Wipe the counter. Let him stay as long as he likes.", "effects": {"kiez": 1.0, "flags": ["juergen_seen"]}, "next": "keys"},
				],
			},
			"keys": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"The crate key,\" he says, and puts it on the counter, and does not let go of it. \"I have had it three weeks. I want to say something about it and I do not have the words in the right order.\"", "This is, by a distance, the most difficult thing he has ever attempted at this counter."],
				"choices": [
					{"label": "Wait. Do not help him. Do not fill it in.", "effects": {"kiez": 1.5, "flags": ["juergen_first_name"]}, "next": "said"},
					{"label": "[Schnauze 13] \"Take your time. There's no queue.\"", "check": {"stat": "cha", "dc": 13}, "next": "said", "next_fail": "logistics"},
					{"label": "\"Keep the key. It's fine. It's only a crate.\"", "effects": {"kiez": 0.5}, "next": "logistics"},
				],
			},
			"said": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["\"At the works there were four hundred of us and I knew every name on my shift. Then there were none of us, and for some years nobody used mine at all.\"", "\"You put a bench inside a door.\" He stops, and starts again, and gets it out: \"Thank you.\" Not Chef. Just that."],
				"choices": [
					{"label": "\"Jürgen.\" Nothing else. Let it stand.", "effects": {"kiez": 2.5, "flags": ["juergen_first_name", "juergen_seen"]}, "next": "off"},
					{"label": "[Hands 12] Write MASSEK on the crate card, in front of him.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.5, "flags": ["juergen_first_name", "juergen_bench"]}, "next": "off"},
				],
			},
			"logistics": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"It is a good crate,\" he says instead. \"The handle is riveted, not moulded. That is the difference between a crate and a thing shaped like one.\"", "He puts the key back in his pocket, and the sentence he was building stays unbuilt on the counter between you."],
				"choices": [
					{"label": "\"Riveted. Noted. Bis später, Jürgen.\"", "effects": {"kiez": 0.5, "flags": ["juergen_bench"]}, "next": "off"},
					{"label": "\"Whatever that was — I heard it anyway.\"", "effects": {"kiez": 1.5, "flags": ["juergen_seen"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["He finishes the Sterni on the bench, puts the empty in his own crate, and carries it out to the step himself.", "\"Bis später. Rain before six. The app has not noticed yet.\""],
				"choices": [
					{"label": "\"Bis später, Herr Massek.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Jürgen, SPRING STEP 7 — "Night-Watch". He tells you the weather before the app does, and the
	#    corner has quietly rearranged itself around the fact that he is on the bench at half twelve.
	"juergen_p7": {
		"start": "forecast",
		"nodes": {
			"forecast": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["April, 21:50, ten minutes early. \"{qty.schrippe}× Schrippe, {qty.beer}× Sterni, {qty.cigarettes}× {brand.cigarettes}. Sixty-one bottles.\"", "\"And it rains at two. Not before. The app says eleven; the app does not know about the cut at the Ringbahn.\""],
				"choices": [
					{"label": "\"Two o'clock. I'll get the crates in at half one.\"", "effects": {"kiez": 1.0, "flags": ["juergen_weather"]}, "next": "watch"},
					{"label": "[Kiez Sense 11] He is early, and he is early to tell you something.", "check": {"stat": "wis", "dc": 11}, "next": "news", "next_fail": "watch"},
					{"label": "\"The app says eleven, Jürgen.\"", "next": "watch"},
				],
			},
			"news": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"Two men in a Kombi at the corner on Tuesday, 03:40. Photographs of the doorways. Not of the shops — of the doorways, and the bins, and the hydrant.\"", "\"Hire car. Brandenburg plates. And a clipboard with your house number on the top sheet.\""],
				"choices": [
					{"label": "\"You read a clipboard across a street in the dark.\"", "effects": {"kiez": 1.5, "flags": ["juergen_watch"]}, "next": "watch"},
					{"label": "[Brains 12] Doorways, bins and hydrants is an access survey.", "check": {"stat": "int", "dc": 12}, "next": "survey", "next_fail": "watch"},
				],
			},
			"survey": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["Doorways, bins and hydrants are what you photograph when you are costing a conversion and need to know where the access has to go.", "\"Then it is not a rumour,\" he says. \"Then it is a date that somebody has already written in a diary.\""],
				"choices": [
					{"label": "\"It is. And you're the only one who saw it.\"", "effects": {"kiez": 2.0, "flags": ["juergen_watch"]}, "next": "watch"},
					{"label": "\"Write down the plate. Write down the time.\"", "effects": {"kiez": 1.5, "flags": ["juergen_watch"]}, "next": "watch"},
				],
			},
			"watch": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["He is on the bench by half past midnight most nights now, between collections, and the street has quietly arranged itself around that.", "\"The girl with the paint left her ladder against the wall on Sunday. I put it inside. The loud one with the flyers dropped a phone in the crate — it is behind your till, in a bag, labelled.\""],
				"choices": [
					{"label": "\"You labelled it.\"", "effects": {"kiez": 1.5, "flags": ["juergen_watch"]}, "next": "wage"},
					{"label": "[Schnauze 12] Offer to pay him for the hours he is here.", "check": {"stat": "cha", "dc": 12}, "next": "wage", "next_fail": "no_wage"},
					{"label": "\"That's the whole street in one crate, Jürgen.\"", "effects": {"kiez": 1.0}, "next": "wage"},
				],
			},
			"no_wage": {
				"speaker": "juergen", "expression": "neutral",
				"lines": ["\"No.\" Flat, immediate, and with no offence in it at all. \"It is not work. If it is work then I have to be good at it, and then I will worry about it.\"", "\"It is a bench, and a crate, and a forecast. Leave it that size, Chef.\""],
				"choices": [
					{"label": "\"That size. Understood.\"", "effects": {"kiez": 1.0, "flags": ["juergen_watch"]}, "next": "off"},
					{"label": "\"Then the coffee isn't a wage. It's the weather service.\"", "effects": {"kiez": 1.5, "flags": ["juergen_wage"]}, "next": "off"},
				],
			},
			"wage": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["\"A Schrippe, a Sterni and the pack,\" he says, \"every night, off the bill, and we do not discuss it again.\" He has clearly rehearsed the sentence somewhere on the route.", "\"That is a wage. I have had four jobs and it is the only one I negotiated myself.\""],
				"choices": [
					{"label": "\"Done. Off the bill. We never discuss it again.\"", "effects": {"kiez": 2.5, "flags": ["juergen_wage"]}, "next": "off"},
					{"label": "[Muscle 11] Shake on it across the crates, like a fitter.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.5, "flags": ["juergen_wage", "juergen_watch"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "juergen", "expression": "warm",
				"lines": ["At 02:00 exactly it rains. He is inside, on the bench, with the crates already in, and he says nothing about it at all, which is how you know he is pleased.", "\"Bis später, Chef.\""],
				"choices": [
					{"label": "\"Bis später, Jürgen.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Mehmet, SUMMER STEP 2 — "Cem Would Have Made A Week Of It" (docs/09 §2.3). He arrives at the
	#    point sideways, through football, and what he is actually telling you is how a corner fights.
	"mehmet_s2": {
		"start": "usual",
		"nodes": {
			"usual": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["\"Das Übliche.\" He does not say what it is, because in thirty-one years he has never had to: {qty.cigarettes}× {brand.cigarettes}, a Mate, a large water.", "\"And if you have to ask me which green, I am going home.\""],
				"choices": [
					{"label": "Ring it from memory. Pack, Mate, water, in that order.", "effects": {"kiez": 1.0, "flags": ["mehmet_usual"]}, "next": "argue"},
					{"label": "[Kiez Sense 11] He is early. He shut the shop early.", "check": {"stat": "wis", "dc": 11}, "next": "early", "next_fail": "argue"},
					{"label": "\"Which green, Mehmet.\"", "effects": {"kiez": -0.5}, "next": "argue"},
				],
			},
			"early": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["Twenty past seven. He shuts at eight, has shut at eight since the year the Wall opened, and the shutter on the fruit shop is already down.", "\"Deniz called. Sunday, and then again tonight, which is not Sunday.\""],
				"choices": [
					{"label": "\"Twice in a week. What did he want?\"", "effects": {"kiez": 1.0, "flags": ["mehmet_deniz_calls"]}, "next": "argue"},
					{"label": "\"You answered on the third ring, I assume.\"", "effects": {"kiez": 0.5, "flags": ["mehmet_deniz_calls"]}, "next": "argue"},
				],
			},
			"argue": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["\"Your uncle and I argued about football for thirty years. Union, Hertha, Union, Hertha. Thirty years, and not one word about anything that mattered.\"", "\"And then he is dead on a Tuesday and I find out at the Bäckerei. From the Bäckerei, my friend.\""],
				"choices": [
					{"label": "\"Nobody knew who to call. I'm sorry.\"", "effects": {"kiez": 1.0}, "next": "week"},
					{"label": "[Schnauze 12] Ask what Cem would have done with a letter like this.", "check": {"stat": "cha", "dc": 12}, "next": "week", "next_fail": "quiet"},
					{"label": "\"He talked about you constantly. Mostly insults.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_cem_story"]}, "next": "week"},
				],
			},
			"week": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["\"A letter like that, Cem would have made a week of it. Monday the Hof, Tuesday the Bäcker, Wednesday he prints something that is not a menu and tells the Verwaltung it is a menu.\"", "\"By Friday there are forty people in a courtyard eating my tomatoes and nobody has signed anything.\""],
				"choices": [
					{"label": "\"Then we've got until Friday.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_cem_story"]}, "next": "crates"},
					{"label": "[Brains 12] Ask what Cem actually WON, not what he did.", "check": {"stat": "int", "dc": 12}, "next": "won", "next_fail": "crates"},
				],
			},
			"won": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["\"Won?\" He thinks about it for longer than you want him to. \"Ninety-six, the rent strike — four flats out of eleven. In 2004, nothing. In 2011 they took the Eckkneipe anyway.\"", "\"He lost, mostly. But nobody on this street signed anything alone, and that is not nothing, and do not let me hear you call it nothing.\""],
				"choices": [
					{"label": "\"Nobody signs alone. That's the whole thing.\"", "effects": {"kiez": 2.0, "flags": ["mehmet_cem_story", "mehmet_not_alone"]}, "next": "crates"},
					{"label": "\"Four out of eleven is four families, Mehmet.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_not_alone"]}, "next": "crates"},
				],
			},
			"quiet": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["\"Quatsch.\" He waves the question away with two fingers and a folded letter. \"You want to make your uncle into an instruction manual. He was not one when he was alive.\"", "He takes the Mate and does not open it, which is what he does when he has not finished talking."],
				"choices": [
					{"label": "\"Fair. Then tell me what YOU would do.\"", "effects": {"kiez": 1.0, "flags": ["mehmet_not_alone"]}, "next": "crates"},
					{"label": "\"Alright, alright. Six ninety, Mehmet.\"", "next": "crates"},
				],
			},
			"crates": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["There are two crates of tomatoes on the step outside that were not there when he came in, and he is already halfway out of the door.", "\"They are going over. They are not a gift, they are going over. Put them by the till and do not put a price on them.\""],
				"choices": [
					{"label": "\"No price. Understood.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_tomatoes"]}, "next": ""},
					{"label": "[Muscle 11] Get both crates in off the step in one trip.", "requires": {"stat": "str", "min": 11}, "effects": {"kiez": 2.0, "flags": ["mehmet_tomatoes"]}, "next": ""},
					{"label": "\"Going over, are they. Every Tuesday.\"", "effects": {"kiez": 1.0, "flags": ["mehmet_tomatoes"]}, "next": ""},
				],
			},
		},
	},
	# ── Mehmet, AUTUMN STEP 3 — "Eleven Percent". The Umlage cap is written wrong, in their favour.
	#    `mehmet_evidence` from the summer is the photographs; this is what they are photographs OF.
	"mehmet_a3": {
		"start": "table",
		"nodes": {
			"table": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["\"{qty.cigarettes}× {brand.cigarettes}, Mate, Wasser.\" The letter is already on the counter, flattened with the side of his hand, and beside it a second envelope from the Mieterverein.", "\"They have written back. Four pages, and page three is a table, and I have read it eleven times.\""],
				"choices": [
					{"label": "Turn the table round and read it with him.", "effects": {"kiez": 1.0}, "next": "cap"},
					{"label": "[Brains 13] Find what the table is actually saying.", "check": {"stat": "int", "dc": 13}, "next": "eleven", "next_fail": "cap"},
					{"label": "\"Six ninety. The lawyer's the one you pay to read it.\"", "effects": {"kiez": -0.5}, "next": "cap"},
				],
			},
			"eleven": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["The Umlage is capped — eight percent of the modernisation cost a year, with a ceiling in euro per square metre on top of it. Their letter applies eleven, and puts the ceiling on the wrong number.", "\"Eleven,\" he says. \"On a letter with a lawyer's name on it. That is not a mistake. Somebody chose eleven.\""],
				"choices": [
					{"label": "\"Somebody chose it. Photograph every page.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_evidence", "mehmet_eleven"]}, "next": "doors"},
					{"label": "[Hands 12] Copy both letters on the shop machine, now.", "requires": {"stat": "dex", "min": 12}, "effects": {"kiez": 2.0, "flags": ["mehmet_evidence", "mehmet_eleven"]}, "next": "doors"},
					{"label": "\"Then they fold the moment somebody says eight.\"", "effects": {"kiez": 1.0, "flags": ["mehmet_eleven"]}, "next": "doors"},
				],
			},
			"cap": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["The paragraphs fold back on themselves. Somewhere around the third §559 you both stop pretending, and he laughs once, without any joy in it at all.", "\"The woman at the Mieterverein has forty minutes on a Thursday. Forty minutes, for a street.\""],
				"choices": [
					{"label": "\"Then we go Thursday and we take both letters.\"", "effects": {"kiez": 1.0, "flags": ["mehmet_lawyer"]}, "next": "doors"},
					{"label": "[Schnauze 13] Get him to ring her tonight, from your counter.", "check": {"stat": "cha", "dc": 13}, "next": "call", "next_fail": "doors"},
				],
			},
			"call": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["He rings from the shop phone with the letter flat under his palm, and his German goes formal and enormous and completely fluent the second somebody official is on the other end.", "\"Sie sagt: elf ist falsch.\" He says it to you with the receiver still at his ear, like a man reading out a scoreline."],
				"choices": [
					{"label": "\"Elf ist falsch. Write it on the envelope.\"", "effects": {"kiez": 2.0, "flags": ["mehmet_lawyer", "mehmet_eleven"]}, "next": "doors"},
					{"label": "\"Your German is fine, Mehmet. It always was.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_lawyer"]}, "next": "doors"},
				],
			},
			"doors": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["\"Half the Haus has the same envelope and the same eleven. The Wagners on four have already paid two months of it, because they are frightened and they are polite.\"", "He looks at the door of your Späti as though it owed him something, which it does."],
				"choices": [
					{"label": "\"Nobody pays another cent before Thursday.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_hausversammlung"]}, "next": "off"},
					{"label": "\"Then we tell them. All of them. This week.\"", "effects": {"kiez": 1.0, "flags": ["mehmet_hausversammlung"]}, "next": "off"},
					{"label": "\"Two months back is a small price for quiet.\"", "effects": {"kiez": -1.0}, "next": "off"},
				],
			},
			"off": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["He folds the letter along its old creases, which are getting soft now, and puts it in the inside pocket where the pack goes.", "\"Thursday. And pack die Kippen unten hin — my wife has eyes like a Zollbeamter.\""],
				"choices": [
					{"label": "\"Bottom of the bag. Bis morgen, Mehmet.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Mehmet, AUTUMN STEP 4 — "Knock On Every Door". Or don't, and be second instead of first.
	#    `mehmet_asked` is the flag the Manage screen already prints; this is where it is earned.
	"mehmet_a4": {
		"start": "list",
		"nodes": {
			"list": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["\"Das Übliche — {qty.cigarettes}× {brand.cigarettes}, Mate, Wasser.\" And a sheet of squared paper with eleven flats on it, four of them ticked.", "\"Four. In nine days. And two of the four are my own family, so really it is two.\""],
				"choices": [
					{"label": "\"Two is two more than last Tuesday.\"", "effects": {"kiez": 0.5}, "next": "first"},
					{"label": "[Kiez Sense 12] He has not knocked on the ground floor at all.", "check": {"stat": "wis", "dc": 12}, "next": "ground", "next_fail": "first"},
					{"label": "\"Eleven doors is a job for the Verwaltung.\"", "effects": {"kiez": -0.5}, "next": "first"},
				],
			},
			"ground": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["Ground floor left is the flat the Verwaltung already emptied. Ground floor right is Frau Krüger, who has told three people on this street that there are too many foreign shops on it.", "\"I am not knocking on that door. I have carried her shopping up a step for six years and I am not knocking on that door.\""],
				"choices": [
					{"label": "\"Then I knock. She gets the same letter you do.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_first"]}, "next": "first"},
					{"label": "[Schnauze 13] \"Eleven percent doesn't care what she thinks.\"", "check": {"stat": "cha", "dc": 13}, "next": "together", "next_fail": "first"},
				],
			},
			"first": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["\"Nobody wants to be first. First is the one whose name is on the letter when the lawyer writes back.\"", "\"And my name is over my door in letters half a metre high, so I am already first whether I knock or not.\""],
				"choices": [
					{"label": "\"Then don't be first. I'll be first — my name on it.\"", "effects": {"kiez": 2.0, "flags": ["mehmet_first"]}, "next": "together"},
					{"label": "\"Both names. Two shops is harder to move than one.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_first", "mehmet_hausversammlung"]}, "next": "together"},
					{"label": "\"Your Haus, your letter. Mine's a shop lease.\"", "effects": {"kiez": -1.0}, "next": "alone"},
				],
			},
			"together": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["You take five doors and he takes six, and at the third one somebody's mother makes you both drink tea standing up in a hallway at half past nine.", "By eleven there are nine ticks on the squared paper, and a Thursday written at the bottom twice, in two different hands."],
				"choices": [
					{"label": "\"Nine. Thursday. In the Hof, seven o'clock.\"", "effects": {"kiez": 2.5, "flags": ["mehmet_asked", "mehmet_hausversammlung"]}, "next": "off"},
					{"label": "[Stamina 13] Do the last two doors after you cash up.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "cash": -16.0, "flags": ["mehmet_asked", "mehmet_hausversammlung"]}, "next": "off"},
				],
			},
			"alone": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["\"Ja. Okay. A lease.\" He puts the squared paper in his pocket unfolded, which ruins it, and he does it on purpose.", "\"Cem had a lease as well, my friend. He never once found it in a drawer when somebody needed him in a courtyard.\""],
				"choices": [
					{"label": "\"That was unfair of me. Give me five doors.\"", "effects": {"kiez": 2.0, "flags": ["mehmet_asked", "mehmet_first"]}, "next": "off"},
					{"label": "\"I'll come Thursday. That's what I can give.\"", "effects": {"kiez": 0.5, "flags": ["mehmet_hausversammlung"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["\"Thursday,\" he says at the door, and then, because he cannot help himself: \"Bring chairs. Nobody ever brings chairs.\"", "The pack goes in the inside pocket, under the letter, at the bottom of the bag."],
				"choices": [
					{"label": "\"Chairs. Bis morgen, Mehmet.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Mehmet, WINTER STEP 5 — "You're Becoming Them". The lease renewal lands the week Deniz visits,
	#    and the conscience of the street tells you, out loud, what he watched you do through a window.
	"mehmet_w5": {
		"start": "price",
		"nodes": {
			"price": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["\"Das Übliche.\" He puts the money down before you have rung it, which he has never done, and looks at the price strip under the {logo.cigarettes} while he does it.", "\"Four sixty. It was four twenty in the summer. That is not a question, it is a number.\""],
				"choices": [
					{"label": "\"The wholesaler went up in October. So did I.\"", "effects": {"kiez": 0.5}, "next": "lease"},
					{"label": "[Kiez Sense 12] He is not asking about cigarettes.", "check": {"stat": "wis", "dc": 12}, "next": "them", "next_fail": "lease"},
					{"label": "\"Four sixty is the price. Everybody's is.\"", "effects": {"kiez": -0.5}, "next": "them"},
				],
			},
			"them": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["\"On Saturday the boy from the front building bought a lighter here and you charged him two euro. Two euro. For a lighter, because he had a card out and he did not look.\"", "\"I watched you do it through my own window, my friend, and I did not know the face you were making.\""],
				"choices": [
					{"label": "\"That's a fair cop. Two euro, and it was wrong.\"", "effects": {"kiez": 1.5, "integrity": 2.0, "flags": ["mehmet_mirror_taken"]}, "next": "lease"},
					{"label": "[Schnauze 13] \"He can afford it and Jürgen can't.\"", "check": {"stat": "cha", "dc": 13}, "next": "sum", "next_fail": "hard"},
					{"label": "\"He didn't look. That's a business, Mehmet.\"", "effects": {"kiez": -1.0, "flags": ["mehmet_priced_them"]}, "next": "hard"},
				],
			},
			"sum": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["He thinks about it properly, which is the thing about him, and he does not hand it to you for free.", "\"Then say it to him out loud. Charge him two euro and TELL him it is two euro because he can. That is a Kiez. What you did is a till.\""],
				"choices": [
					{"label": "\"Out loud. Every time. Agreed.\"", "effects": {"kiez": 2.0, "integrity": 2.0, "flags": ["mehmet_mirror_taken"]}, "next": "lease"},
					{"label": "\"A till that pays the rent that keeps the Kiez.\"", "effects": {"kiez": 0.5}, "next": "lease"},
				],
			},
			"hard": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["\"Quatsch.\" He picks up the water and does not open it. \"Cem fed people who could not pay, and he was not a saint. He was a bad businessman with a good corner.\"", "\"You are a good businessman. I am telling you tonight because in a year I will not bother.\""],
				"choices": [
					{"label": "\"Bother. Keep bothering. That's what you're for.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_mirror_taken"]}, "next": "lease"},
					{"label": "\"Then don't bother. I'll run it my way.\"", "effects": {"kiez": -1.0, "flags": ["mehmet_priced_them"]}, "next": "lease"},
				],
			},
			"lease": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["Out of the inside pocket, under the pack, comes a lease renewal for the fruit shop: five years, a new figure, and a clause about \"Sortimentsabstimmung mit dem Gesamtobjekt\".", "\"They will tell me what I am allowed to sell. And Deniz comes Friday, for four days, and he has a spreadsheet already. I know that he has a spreadsheet.\""],
				"choices": [
					{"label": "\"Bring the spreadsheet here. I'll look at it with him.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_deniz_visit"]}, "next": "off"},
					{"label": "[Brains 14] Read what the Sortiment clause actually does.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 2.0, "flags": ["mehmet_deniz_visit", "mehmet_evidence"]}, "next": "off"},
					{"label": "\"Five years is five years, Mehmet. Sign it.\"", "effects": {"kiez": -0.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["\"Friday,\" he says. \"He will want to take everybody to a restaurant with a concept. Say no for me — I have not got the words in German or in Turkish.\"", "The pack goes at the bottom of the bag. He counts the change back to you out of thirty-one years of habit."],
				"choices": [
					{"label": "\"I'll say no. Bis morgen, Mehmet.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Mehmet, WINTER STEP 6 — "Legacy Is People". The spreadsheet says sell, and the column at the
	#    end is right, and it has nothing in it about Frau Krüger's shopping.
	"mehmet_w6": {
		"start": "shutter",
		"nodes": {
			"shutter": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["\"{qty.cigarettes}× {brand.cigarettes}, Mate, Wasser — and a second Mate.\" The second one is for Deniz, who is outside on the phone to Munich in a coat that is wrong for a Hof.", "\"He has been here four days. He has fixed my till, my lighting and my opening hours, and he has not once come inside this shop.\""],
				"choices": [
					{"label": "\"Send him in. I'll put the second Mate in his hand.\"", "effects": {"kiez": 1.0, "flags": ["mehmet_deniz_in"]}, "next": "spread"},
					{"label": "[Kiez Sense 12] He is proud of the boy and cannot say it.", "check": {"stat": "wis", "dc": 12}, "next": "proud", "next_fail": "spread"},
					{"label": "\"Opening hours and lighting. He isn't wrong.\"", "next": "spread"},
				],
			},
			"proud": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["\"He did the numbers in one evening and he was right about all of them, and I shouted at him about the tomatoes.\" He turns the water bottle a quarter turn on the laminate.", "\"Thirty-nine years I carried crates so that he would never have to carry crates. Now he does not know how, and that is the correct outcome, and it is very lonely.\""],
				"choices": [
					{"label": "\"Tell him that. Tonight. In exactly those words.\"", "effects": {"kiez": 2.0, "flags": ["mehmet_deniz_in"]}, "next": "spread"},
					{"label": "\"That's the job done, Mehmet. That's what it was for.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_legacy_people"]}, "next": "spread"},
				],
			},
			"spread": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["The spreadsheet says sell: hand the lease back, take the Abfindung, and put it into something in Munich where the boy can keep an eye on it.", "\"And the column at the end is right,\" he says. \"That is the thing about a column. It is right, and it has nothing in it about Frau Krüger's shopping.\""],
				"choices": [
					{"label": "\"Then the column's missing a row. Put the row in.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_legacy_people"]}, "next": "ask"},
					{"label": "[Brains 12] Cost what the street actually does for him.", "check": {"stat": "int", "dc": 12}, "next": "rows", "next_fail": "ask"},
					{"label": "\"It's a good offer, Mehmet. Take it.\"", "effects": {"kiez": -1.0}, "next": "ask"},
				],
			},
			"rows": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["Nine deliveries a year you take in for him. The Tuesday crates that go over. Two shops, one skip, one alarm code, and eleven flats who buy fruit because it is forty steps away.", "\"You have put my life in a table,\" he says. \"It is a worse table than his and it is the true one.\""],
				"choices": [
					{"label": "\"Show it to him. Let him argue with it.\"", "effects": {"kiez": 2.0, "flags": ["mehmet_legacy_people"]}, "next": "ask"},
					{"label": "\"Legacy isn't a lease. It's who's still here.\"", "effects": {"kiez": 2.0, "flags": ["mehmet_legacy_people"]}, "next": "ask"},
				],
			},
			"ask": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["\"So. I am going to ask you, and I will only ask once, and then we never discuss it again.\"", "\"If I stand up in that courtyard on the fourteenth and say we are not paying the eleven percent — are you standing up with me, or are you behind your counter?\""],
				"choices": [
					{"label": "\"I'm standing up. Shop shut, sign on the door.\"", "effects": {"kiez": 2.5, "integrity": 2.0, "flags": ["mehmet_keys"]}, "next": "off"},
					{"label": "[Stamina 13] \"Both shops shut. Nobody's open on the fourteenth.\"", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 3.0, "cash": -40.0, "flags": ["mehmet_keys", "mehmet_legacy_people"]}, "next": "off"},
					{"label": "\"Behind the counter. Somebody has to be open.\"", "effects": {"kiez": -0.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["Outside, Deniz has come off the phone and is standing in the doorway holding the second Mate, which somebody has evidently put into his hand.", "\"Fourteenth,\" says Mehmet, to both of you, and goes out past his son without slowing down, which is a father's way of saying come on then."],
				"choices": [
					{"label": "\"Fourteenth.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Mehmet, SPRING STEP 7 — "Deniz Comes For The Versammlung" — or doesn't, and Mehmet stands up
	#    anyway. Four sentences in a courtyard, and his hands shaking afterwards.
	"mehmet_p7": {
		"start": "chairs",
		"nodes": {
			"chairs": {
				"speaker": "mehmet", "expression": "neutral",
				"lines": ["Half past six, an hour before the Versammlung, and he cannot open your door because he is carrying four chairs. \"{qty.cigarettes}× {brand.cigarettes}. Nothing else. My hands are full of chairs.\"", "\"He is not coming. Munich. A thing on Thursday that could not be moved.\""],
				"choices": [
					{"label": "Take two chairs off him. \"Then we're twelve, not thirteen.\"", "effects": {"kiez": 1.0}, "next": "hof"},
					{"label": "[Kiez Sense 12] He has checked the phone twice since the door.", "check": {"stat": "wis", "dc": 12}, "next": "phone", "next_fail": "hof"},
					{"label": "\"Munich. Right. Of course.\"", "effects": {"kiez": -0.5}, "next": "hof"},
				],
			},
			"phone": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["Three times, and each time he turns it face down on the counter afterwards, as though it had been rude to him.", "\"On Tuesday he asked me what time it starts. And then Thursday could not be moved. Both of those are true and I am allowed to be tired about it.\""],
				"choices": [
					{"label": "\"You're allowed. Chairs now, tired later.\"", "effects": {"kiez": 1.5}, "next": "hof"},
					{"label": "[Schnauze 12] Get him to ring the boy back, once, now.", "check": {"stat": "cha", "dc": 12}, "next": "ring", "next_fail": "hof"},
				],
			},
			"ring": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["He rings from your counter, formally, as though to an office. Forty seconds. Then he puts the phone face down again and looks at the price strip for a while.", "\"He is on the 18:04,\" he says, to the strip. \"He booked it on Tuesday. He was going to walk in and not tell me, the little Quatschkopf.\""],
				"choices": [
					{"label": "\"Then we need a fifth chair.\"", "effects": {"kiez": 2.0, "flags": ["mehmet_deniz_came"]}, "next": "hof"},
					{"label": "\"He learned that from you. You know he did.\"", "effects": {"kiez": 2.0, "flags": ["mehmet_deniz_came"]}, "next": "hof"},
				],
			},
			"hof": {
				"speaker": "mehmet", "expression": "wary",
				"lines": ["Forty-one people in a courtyard, on chairs, on crates and on a wall, with a folding table at the front and a PA in a cupboard that somebody has found a cable for.", "\"I have not spoken in front of forty people since a wedding in 1991,\" he says. \"And at the wedding I was allowed to be drunk.\""],
				"choices": [
					{"label": "\"Say the number. Eleven. Then sit down.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_stood"]}, "next": "speech"},
					{"label": "[Schnauze 15] Take the table first, and hand it to him warm.", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.5, "flags": ["mehmet_stood"]}, "next": "speech"},
					{"label": "\"You'll be fine. I'll be at the back.\"", "effects": {"kiez": 0.5}, "next": "speech"},
				],
			},
			"speech": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["He says four sentences: his name, the number of years, the number eleven, and that nobody in this courtyard signs anything on their own.", "Then he sits down, and his hands are shaking, and the courtyard does what a courtyard does, which is get loud all at once."],
				"choices": [
					{"label": "\"Four sentences. Cem would have taken an hour.\"", "effects": {"kiez": 2.0, "flags": ["mehmet_stood"]}, "next": "after"},
					{"label": "Say nothing. Put a Mate into his hand.", "effects": {"kiez": 2.5, "integrity": 1.0, "flags": ["mehmet_stood"]}, "next": "after"},
					{"label": "Slip out at the back; the shop's been shut an hour.", "effects": {"kiez": -1.0}, "next": "after"},
				],
			},
			"after": {
				"speaker": "mehmet", "expression": "warm",
				"lines": ["Afterwards there are two crates of tomatoes going round the courtyard that are, as always, going over, and a list with thirty-one names on it that started with two.", "\"Your uncle,\" says Mehmet, \"would have made a week of this.\" He is already shutting his eyes against what you are going to say."],
				"choices": [
					{"label": "\"Then we've got the rest of the week.\"", "effects": {"kiez": 1.5, "flags": ["mehmet_legacy_people"]}, "next": ""},
					{"label": "\"He'd have made a month. Get the chairs in.\"", "effects": {"kiez": 1.0}, "next": ""},
				],
			},
		},
	},
	# ── Everyone else: the nameless parade. One node, {want} filled from what they came in for ──
	# ── Tobias, SUMMER STEP 2 — "You Should Make This A Destination" (docs/09 §2.8). The fake ally,
	# still entirely harmless: the pitch is a gift, and the gift is a rebrand. Reads back `tobias_tipped`
	# through `tobias/t_destination`; leaves the sign, the wine night and the empty second stool for
	# autumn's fund to pick up.
	"tobias_s2": {
		"start": "thursday",
		"nodes": {
			"thursday": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["\"{qty.beer} Sternis, the chips, and one {brand.cigarettes}. {logo.cigarettes} — that pack is genuinely beautiful, by the way.\"", "Card out before the second bottle is on the counter. \"Okay. I've been thinking about this place all week. Properly thinking.\""],
				"choices": [
					{"label": "\"It's Thursday. Think out loud.\"", "effects": {"kiez": 0.5}, "next": "pitch"},
					{"label": "[Kiez Sense 12] He rehearsed this in the lift.", "check": {"stat": "wis", "dc": 12}, "next": "rehearsed", "next_fail": "pitch"},
					{"label": "\"Four Sternis and a packet, Tobias.\"", "effects": {"kiez": -0.5}, "next": "pitch"},
				],
			},
			"rehearsed": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["He has notes. Actual notes, in an app, under a heading. He shuts the phone too fast, which is the tell.", "\"…Is it weird that I wrote it down. It's weird. Sorry. I do this.\""],
				"choices": [
					{"label": "\"Read me the heading.\"", "effects": {"kiez": 1.0, "flags": ["tobias_notes"]}, "next": "pitch"},
					{"label": "\"It's not weird. It's Thursday.\"", "effects": {"kiez": 0.5, "flags": ["tobias_notes"]}, "next": "pitch"},
				],
			},
			"pitch": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["\"Natural wine night. Once a month, tasting flight, twelve euro. I know three importers who'd do it at cost.\"", "\"And a sign that isn't — sorry — isn't three fonts. This corner could be a destination.\""],
				"choices": [
					{"label": "\"It's already somewhere. To the people on it.\"", "effects": {"kiez": 1.0, "flags": ["tobias_kept_the_sign"]}, "next": "sign"},
					{"label": "[Brains 13] A twelve-euro flight prices out the street.", "check": {"stat": "int", "dc": 13}, "next": "maths", "next_fail": "sign"},
					{"label": "\"Wine night. Alright. One.\"", "effects": {"profit": 1.0, "flags": ["tobias_wine_night"]}, "next": "sign"},
				],
			},
			"maths": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["You do it out loud. Twelve euro is Jürgen's whole night, four of Lena's lunches, and Nadia's coffee eleven times over.", "\"…Yeah. Yeah, okay. I was doing margin, not people.\" He puts the phone face down."],
				"choices": [
					{"label": "\"Margin's fine. Just do it after the people.\"", "effects": {"kiez": 1.5, "flags": ["tobias_kept_the_sign", "tobias_notes"]}, "next": "sign"},
					{"label": "\"You're not wrong about the sign, mind.\"", "effects": {"kiez": 1.0, "flags": ["tobias_notes"]}, "next": "sign"},
				],
			},
			"sign": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["Cem painted the sign in 1998, with a roller, on a Sunday. He got the second K wrong and left it there for twenty-six years.", "Tobias looks at it the way you look at a thing you have walked past four hundred times."],
				"choices": [
					{"label": "\"The wrong K is the point.\"", "effects": {"kiez": 0.5}, "next": "alone"},
					{"label": "[Brains 14] What a destination does to a rent index.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 1.5, "flags": ["tobias_rent_index"]}, "next": "alone"},
					{"label": "\"You could repaint it. You won't.\"", "next": "alone"},
				],
			},
			"alone": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["Four nights a week since August, and the second stool has never had anybody on it.", "\"My team's in Munich. Which is fine, it's a distributed thing, it's fine.\" He counts the bottles again, slower."],
				"choices": [
					{"label": "\"Come Thursday. I'm here. That's the invitation.\"", "effects": {"kiez": 1.0, "flags": ["tobias_alone_named"]}, "next": "off"},
					{"label": "\"Bring one of them. Just one.\"", "effects": {"kiez": 0.5, "flags": ["tobias_alone_named"]}, "next": "off"},
					{"label": "Say nothing. Put the chips on top of the bag.", "effects": {"kiez": 0.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["\"Schönen Abend!\" — practised, and better than yours. He holds the door for a woman with a pushchair and looks pleased with himself for a full second."],
				"choices": [
					{"label": "\"Schönen Abend, Tobias.\"", "next": ""},
				],
			},
		},
	},
	# ── Tobias, AUTUMN STEP 3 — "The Kiez Fund" (docs/09 §2.8). The help, with strings he cannot see;
	# `tobias/t_six` gates on `tobias_fund_offered`, which this step's beat sets on every branch. Clause
	# four is the muzzle, and the flags say whether you read it, took it, or made him read it aloud.
	"tobias_a3": {
		"start": "fund",
		"nodes": {
			"fund": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["\"{qty.beer} Sternis, chips, one {brand.cigarettes}. And — real thing, actual thing — the Kiez fund's approved.\"", "\"Twelve grand a year, local businesses, small grants. I put your name at the top of the list. Top.\""],
				"choices": [
					{"label": "\"That's kind. Now say the rest of it.\"", "effects": {"kiez": 0.5}, "next": "strings"},
					{"label": "[Kiez Sense 12] He said approved, not we approved.", "check": {"stat": "wis", "dc": 12}, "next": "lanyard", "next_fail": "strings"},
					{"label": "\"Twelve grand. Whose twelve grand?\"", "effects": {"kiez": 0.5, "flags": ["tobias_asked_whose"]}, "next": "strings"},
				],
			},
			"lanyard": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["The building pass is out and on the laminate before he hears the question. Fourth floor of the block on the corner: new glass, old address.", "\"Community budget. It sits under the same entity as the office lease, but that's an accounting thing.\""],
				"choices": [
					{"label": "\"Say entity again. Slower.\"", "effects": {"kiez": 1.0, "flags": ["tobias_asked_whose"]}, "next": "strings"},
					{"label": "Write it on a Pfand receipt while he talks.", "effects": {"kiez": 1.5, "flags": ["tobias_asked_whose", "tobias_wrote_it_down"]}, "next": "strings"},
				],
			},
			"strings": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["\"There's a light reporting obligation. Photos, a quote, Proud Partner of the Kiez Fund in the window.\"", "\"It's nothing. It's literally a sticker.\""],
				"choices": [
					{"label": "\"A sticker in the shop they're buying.\"", "effects": {"kiez": 1.0, "flags": ["tobias_fund_refused"]}, "next": "terms"},
					{"label": "[Brains 13] Read the terms he is holding.", "check": {"stat": "int", "dc": 13}, "effects_success": {"flags": ["tobias_fund_strings"]}, "next": "terms", "next_fail": "answer"},
					{"label": "\"I'll take it. My rent went up in August.\"", "effects": {"cash": 60.0, "integrity": -3.0, "flags": ["took_fund"]}, "next": "answer"},
				],
			},
			"terms": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["Clause four: the grant lapses if the recipient takes part in organised action against the fund's partners.", "\"That's boilerplate. That is genuinely boilerplate, they put it in everything.\" He reads it again and goes quiet."],
				"choices": [
					{"label": "\"Boilerplate muzzle. Still a muzzle.\"", "effects": {"kiez": 1.5, "flags": ["tobias_fund_strings"]}, "next": "answer"},
					{"label": "[Schnauze 15] Make him read clause four out loud.", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.0, "flags": ["tobias_fund_strings", "tobias_read_aloud"]}, "next": "answer"},
				],
			},
			"answer": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["He puts the card away and pays cash, badly, counting twice, which is what he does when he is embarrassed.", "\"I wanted to do one good thing with my job. One. That was the whole idea.\""],
				"choices": [
					{"label": "\"Do it with your Thursday instead. Cheaper.\"", "effects": {"kiez": 1.0}, "next": "off"},
					{"label": "\"Then find out who wrote clause four.\"", "effects": {"kiez": 1.0, "flags": ["tobias_digging", "main_lever_hint"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["\"Same time next week?\" — and he waits for the answer, which he has never once done."],
				"choices": [
					{"label": "\"Same time.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Tobias, AUTUMN STEP 4 — "He Brings Six Colleagues" (docs/09 §2.8). The corner changes for a
	# night: his best intention and the loudest the bench has been all year. Whether you held the prices
	# is what winter's ultimatum reads back off `tobias_six_fair` / `tobias_six_priced`.
	"tobias_a4": {
		"start": "six",
		"nodes": {
			"six": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["Seven of them at once. \"{qty.beer} Sternis — no, sorry, times seven — the chips, and one {brand.cigarettes}. My round. All of it's my round.\"", "The corner goes loud in a way it has not been since the summer. Somebody is standing on the Pfand crate."],
				"choices": [
					{"label": "Ring it through. Seven rounds is seven rounds.", "effects": {"cash": 24.0, "profit": 1.0}, "next": "orders"},
					{"label": "[Kiez Sense 12] He is watching you, not them.", "check": {"stat": "wis", "dc": 12}, "next": "watching", "next_fail": "orders"},
					{"label": "[Stamina 13] Stay open an hour past close for it.", "requires": {"stat": "con", "min": 13}, "effects": {"cash": 40.0, "kiez": -0.5, "profit": 1.0, "flags": ["tobias_six_late"]}, "next": "orders"},
				],
			},
			"watching": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["He is not with them. He is standing slightly to the side of them, checking your face, the way a man checks whether a present landed.", "\"Is this okay? It's okay, right? I told them it's the best corner in Berlin.\""],
				"choices": [
					{"label": "\"It's okay. The bench is for sitting on.\"", "effects": {"kiez": 1.0, "flags": ["tobias_six_stayed"]}, "next": "orders"},
					{"label": "\"You brought people. You've never brought people.\"", "effects": {"kiez": 1.5, "flags": ["tobias_six_stayed"]}, "next": "orders"},
				],
			},
			"orders": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["One of them asks if you take card for two euro. One asks whether the Mate is the authentic one. One says the word Kiez four times in a single sentence.", "Frau Schulz comes to the door, looks in, and does not come in."],
				"choices": [
					{"label": "Serve them like anyone else. Hold the prices.", "effects": {"kiez": 1.0, "flags": ["tobias_six_fair"]}, "next": "bench"},
					{"label": "[Schnauze 13] Put the tourist price on the round.", "check": {"stat": "cha", "dc": 13}, "effects_success": {"cash": 12.0, "integrity": -2.0, "flags": ["tobias_six_priced"]}, "effects_fail": {"kiez": -1.0}, "next": "bench", "next_fail": "bench"},
					{"label": "\"Outside with it. The old lady wants her milk.\"", "effects": {"kiez": 1.5, "flags": ["tobias_six_fair"]}, "next": "bench"},
				],
			},
			"bench": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["By half one the bench is six coats and nobody off this street. Aylin's end of it. Jürgen's crate is being used as a table.", "Tobias sees it four minutes after you do, which is four minutes late and still faster than any of them."],
				"choices": [
					{"label": "\"That crate is somebody's work, Tobias.\"", "effects": {"kiez": 1.0, "flags": ["tobias_crate_moved"]}, "next": "after"},
					{"label": "Say nothing. Move the crate yourself.", "effects": {"kiez": 0.5}, "next": "after"},
				],
			},
			"after": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["He gets them into a taxi at two and comes back alone for a bottle of water he does not want.", "\"That was — I think that was good? Was that good?\""],
				"choices": [
					{"label": "\"It was loud. It was good and it was loud.\"", "effects": {"kiez": 1.0, "flags": ["tobias_six_stayed"]}, "next": "off"},
					{"label": "\"It was a Thursday with six strangers in it.\"", "effects": {"kiez": 0.5}, "next": "off"},
					{"label": "[Brains 14] Tell him exactly what the street saw.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 2.0, "flags": ["tobias_told_plainly"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["\"I'll do it again,\" he says, \"but smaller. Two of them. The two that aren't awful.\" He leaves the change and, for once, does not say so."],
				"choices": [
					{"label": "\"Two's a good number.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Tobias, WINTER STEP 5 — "His Company Or The Corner" (docs/09 §2.8). The break clause, said out
	# loud by the man it pays: one of the three independent routes to `main_lever_hint` (docs/09 §4.10),
	# and the night the fake ally finds out which side of the page he is printed on.
	"tobias_w5": {
		"start": "march",
		"nodes": {
			"march": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["\"{qty.beer} Sternis. Actually — one. One Sterni, and one {brand.cigarettes}. I'm not drinking the other three, I just order them.\"", "Snow on his shoulders. He was outside for a while before he came in."],
				"choices": [
					{"label": "\"Sit down. There's a crate by the door.\"", "effects": {"kiez": 0.5}, "next": "clause"},
					{"label": "[Kiez Sense 12] He has known for a week and came anyway.", "check": {"stat": "wis", "dc": 12}, "next": "knew", "next_fail": "clause"},
					{"label": "\"One Sterni it is.\"", "next": "clause"},
				],
			},
			"knew": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["Eight days. He found it in a data room he has access to and should not have opened, and he has slept about nine hours since.", "\"I keep thinking there's a version where I misread it.\""],
				"choices": [
					{"label": "\"Read it to me. We'll misread it together.\"", "effects": {"kiez": 1.5, "flags": ["tobias_read_aloud"]}, "next": "clause"},
					{"label": "\"You didn't misread it.\"", "effects": {"kiez": 1.0}, "next": "clause"},
				],
			},
			"clause": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["The office lease has a break clause. If the block's residential conversion completes by March, the rent halves for six years.", "\"Six years. In my job that's the whole company. That's everyone's job, not only mine.\""],
				"choices": [
					{"label": "\"March. Say that date again, slowly.\"", "effects": {"kiez": 1.0, "flags": ["tobias_break_clause", "main_lever_hint"]}, "next": "ask"},
					{"label": "[Brains 13] What has to be empty for it to complete?", "check": {"stat": "int", "dc": 13}, "next": "vacant", "next_fail": "ask"},
					{"label": "\"So your rent halves when my flat empties.\"", "effects": {"kiez": 0.5, "flags": ["tobias_break_clause"]}, "next": "ask"},
				],
			},
			"vacant": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["Vacant possession. The corner unit with the wrong K on the sign, and every flat above it.", "\"…I'm the tenant. I'm not the landlord, I'm the tenant.\" He hears it as he says it."],
				"choices": [
					{"label": "\"You're the reason it pays. Same thing, better manners.\"", "effects": {"kiez": 1.0, "flags": ["tobias_break_clause", "main_lever_hint", "tobias_digging"]}, "next": "ask"},
					{"label": "\"Then be an expensive tenant. Stay put.\"", "effects": {"kiez": 1.5, "flags": ["tobias_break_clause", "main_lever_hint"]}, "next": "ask"},
				],
			},
			"ask": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["\"They want a letter. Landlord relations. Two paragraphs saying the conversion is supported by the commercial tenants.\"", "\"I am the commercial tenants.\""],
				"choices": [
					{"label": "\"Don't sign it.\"", "effects": {"kiez": 1.0, "flags": ["tobias_asked_not_to_sign"]}, "next": "off"},
					{"label": "[Schnauze 15] Give him the sentence to say to his board.", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.5, "flags": ["tobias_asked_not_to_sign", "tobias_has_the_words"]}, "next": "off"},
					{"label": "\"Sign it. It's your job. I'll still serve you.\"", "effects": {"integrity": -1.0, "flags": ["tobias_signed_anyway"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["He takes the one Sterni and leaves the other three on the counter, paid for, which is the most Tobias sentence there has ever been.", "\"I'll tell you either way. Before you hear it from her.\""],
				"choices": [
					{"label": "\"Before I hear it from her.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Tobias, WINTER STEP 6 — "Belonging Is Paid In Care" (docs/09 §2.8). Nothing is asked for and
	# nothing is announced: the crates, the pavement, a name said correctly at a door. What it costs him
	# at work is the price, and `tobias_belongs` is what the spring signature is written on.
	"tobias_w6": {
		"start": "night",
		"nodes": {
			"night": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["\"{qty.beer} Sternis, chips, one {brand.cigarettes}.\" He puts the card away before you can look at it and finds coins instead, which takes a while.", "\"I've been practising cash. It's harder than it looks.\""],
				"choices": [
					{"label": "\"Nobody's timing you.\"", "effects": {"kiez": 0.5}, "next": "shovel"},
					{"label": "[Kiez Sense 12] He came in the back way, past the bins.", "check": {"stat": "wis", "dc": 12}, "next": "bins", "next_fail": "shovel"},
					{"label": "\"Card's fine, Tobias.\"", "next": "shovel"},
				],
			},
			"bins": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["He has been putting the crates out. For three weeks. At half eleven, on his way home, without telling you, badly.", "\"They were in the rain. I didn't know where they go. They still don't go in the right place, do they.\""],
				"choices": [
					{"label": "\"Under the shutter. I'll show you once.\"", "effects": {"kiez": 2.0, "flags": ["tobias_care_shift"]}, "next": "shovel"},
					{"label": "\"Three weeks?\"", "effects": {"kiez": 1.5, "flags": ["tobias_care_shift"]}, "next": "shovel"},
				],
			},
			"shovel": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["It snowed at eight and the pavement outside your door is the only clear stretch on the block.", "Mehmet's is clear too. Nobody else's is."],
				"choices": [
					{"label": "\"Did you do the pavement?\"", "effects": {"kiez": 1.0, "flags": ["tobias_care_shift"]}, "next": "names"},
					{"label": "[Stamina 13] Do Frau Schulz's stretch with him now.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "flags": ["tobias_care_shift", "tobias_did_the_round"]}, "next": "round"},
					{"label": "Don't mention it. Let it be his.", "effects": {"kiez": 1.0}, "next": "names"},
				],
			},
			"round": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["Forty minutes, two shovels, one of them a dustpan. He asks her name twice, gets it right the second time, and says it again at the door so it sticks.", "\"Christa,\" he says on the way back. \"Not Frau. She said Christa.\""],
				"choices": [
					{"label": "\"She says that once. Don't waste it.\"", "effects": {"kiez": 1.5, "flags": ["tobias_learned_a_name"]}, "next": "names"},
					{"label": "\"Took you five months.\"", "effects": {"kiez": 1.0, "flags": ["tobias_learned_a_name"]}, "next": "names"},
				],
			},
			"names": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["\"I sent the letter back unsigned. They've moved my desk to the floor with no window, which is honestly very funny.\"", "\"Nobody at work has said one word to me since Tuesday.\""],
				"choices": [
					{"label": "\"Then this is where you are on Thursdays.\"", "effects": {"kiez": 1.5, "flags": ["tobias_belongs"]}, "next": "off"},
					{"label": "[Brains 14] Tell him what they can and cannot do to him.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 2.0, "flags": ["tobias_belongs", "tobias_has_the_words"]}, "next": "off"},
					{"label": "\"That's what it costs. You knew that.\"", "effects": {"kiez": 0.5, "flags": ["tobias_belongs"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["He puts the empties in the crate himself on his way out, under the shutter, in the right place."],
				"choices": [
					{"label": "\"Bis Donnerstag.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Tobias, SPRING STEP 7 — "Throws In" (docs/09 §2.8). The fork the persona card names: he signs
	# the tenants' letter and loses something at work, or he moves to the next authentic postcode and
	# the epilogue is a postcard from Leipzig. The strand beat `tobias/t_throws` records which.
	"tobias_p7": {
		"start": "letter",
		"nodes": {
			"letter": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["\"{qty.beer} Sternis and one {brand.cigarettes}, and — is the letter still on the counter? The tenants' one.\"", "He has asked about it four Thursdays running and has not once picked it up."],
				"choices": [
					{"label": "Slide it across. Don't say anything.", "effects": {"kiez": 0.5}, "next": "sign"},
					{"label": "[Kiez Sense 12] He already has a pen out.", "check": {"stat": "wis", "dc": 12}, "next": "pen", "next_fail": "sign"},
					{"label": "\"It's for people on the lease, Tobias.\"", "next": "sign"},
				],
			},
			"pen": {
				"speaker": "tobias", "expression": "surprised",
				"lines": ["His own pen, out of his own jacket, carried around all week by a man who has decided something and is waiting to be asked."],
				"choices": [
					{"label": "\"You've already signed it in your head.\"", "effects": {"kiez": 1.0, "flags": ["tobias_pen"]}, "next": "sign"},
					{"label": "\"Go on, then.\"", "effects": {"kiez": 0.5, "flags": ["tobias_pen"]}, "next": "sign"},
				],
			},
			"sign": {
				"speaker": "tobias", "expression": "neutral",
				"lines": ["Forty-one names. Mehmet's, Christa Schulz's twice because she forgot, Lena's in paint, Karim's in careful capitals, Jürgen's with the year after it.", "\"If I sign this my company is on the other side of it. In writing. With my name on.\""],
				"choices": [
					{"label": "\"Then don't. Nobody here is counting.\"", "effects": {"kiez": 1.0}, "next": "choice"},
					{"label": "[Schnauze 15] \"Belonging is paid in care. This is the bill.\"", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.0, "flags": ["tobias_told_plainly"]}, "next": "choice"},
					{"label": "\"Forty-one people already did.\"", "effects": {"kiez": 0.5}, "next": "choice"},
				],
			},
			"choice": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["He looks at the list for a long time. The fridges hum. Outside, somebody is arguing with a bicycle."],
				"choices": [
					{"label": "Wait. Let it be his.", "effects": {"kiez": 0.5}, "next": "signed"},
					{"label": "[Brains 14] Show him the clause that keeps him safe.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 1.5, "flags": ["tobias_has_the_words"]}, "next": "signed"},
					{"label": "\"Leipzig's nice, they say. Cheaper.\"", "effects": {"kiez": -1.0}, "next": "leipzig"},
				],
			},
			"signed": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["Forty-two. He writes his surname first, then goes back and squeezes Tobias in front of it, which is somehow the whole man.", "\"Right,\" he says. \"Well. That's my week ruined.\" He is delighted."],
				"choices": [
					{"label": "\"Welcome to the street.\"", "effects": {"kiez": 2.5, "integrity": 1.0, "flags": ["tobias_signed_letter"]}, "next": "off"},
					{"label": "\"Sterni's on me.\"", "effects": {"cash": -1.2, "kiez": 2.0, "flags": ["tobias_signed_letter"]}, "next": "off"},
				],
			},
			"leipzig": {
				"speaker": "tobias", "expression": "upset",
				"lines": ["He does not sign it. He buys the Sternis and the chips and one {brand.cigarettes} and he tips, and neither of you says the thing.", "\"They've offered me Leipzig, actually. Bigger role. Really interesting market.\""],
				"choices": [
					{"label": "\"A really interesting market.\"", "effects": {"flags": ["tobias_leipzig"]}, "next": "off"},
					{"label": "\"Send a postcard. I mean that.\"", "effects": {"kiez": 0.5, "flags": ["tobias_leipzig"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "tobias", "expression": "warm",
				"lines": ["\"Schönen Abend,\" he says, and this time he waits at the door until you say it back."],
				"choices": [
					{"label": "\"Schönen Abend, Tobias.\"", "next": ""},
				],
			},
		},
	},
	# ── Aylin, SUMMER STEP 2 — "The Van And The Bar" (docs/09 §2.10). The plans, stated like a contract,
	# and the first crack in them costed on the back of a Pfand receipt. `aylinjonas/aj_onebag` reads
	# `aylin_plans` off this step's beat; the autumn reads the van and the bar back as things she said.
	"aylin_s2": {
		"start": "seven_forty",
		"nodes": {
			"seven_forty": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"{qty.mate} Mate, ein Wasser, {qty.cigarettes}× {brand.cigarettes} — {logo.cigarettes} — und ein Feuerzeug. Yes. Again. Don't.\"", "07:41. Glitter on the eyelid, glitter on your laminate, and she is talking before the door has finished shutting."],
				"choices": [
					{"label": "Put the lighter down first. Say nothing.", "effects": {"kiez": 0.5}, "next": "van"},
					{"label": "[Kiez Sense 12] She has been awake twenty-six hours.", "check": {"stat": "wis", "dc": 12}, "next": "hours", "next_fail": "van"},
					{"label": "\"Fifth one this month.\"", "effects": {"kiez": 0.5, "flags": ["aylin_lighter_count"]}, "next": "van"},
				],
			},
			"hours": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["Load-in at four yesterday afternoon, doors at eleven, off the desk at six. She has not sat down since Friday and is describing a kick drum with both hands.", "\"I'm fine. I'm so fine. I'll sleep on the Ringbahn like a normal person.\""],
				"choices": [
					{"label": "\"Sit on the bench. I'll bring it out.\"", "effects": {"kiez": 1.5, "flags": ["aylin_bench_service"]}, "next": "van"},
					{"label": "\"Twenty-six hours, Aylin.\"", "effects": {"kiez": 1.0}, "next": "van"},
				],
			},
			"van": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"So — the van. We've found the van. It's a Sprinter, it has a bed in it, an actual bed, and it's four and a half.\"", "\"Four and a half thousand. Which we have. Well. Which we will have. By spring.\""],
				"choices": [
					{"label": "\"By spring.\" Write it on the fridge list.", "effects": {"kiez": 1.0, "flags": ["aylin_van"]}, "next": "bar"},
					{"label": "[Brains 13] Four and a half by spring, on two freelancers.", "check": {"stat": "int", "dc": 13}, "next": "costed", "next_fail": "bar"},
					{"label": "\"Every Sunday there's a van.\"", "effects": {"kiez": -0.5}, "next": "bar"},
				],
			},
			"costed": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["You do it on the back of a Pfand receipt. It works if nothing breaks, nobody gets ill, and one of them gives up a rehearsal room.", "\"…You've done Jonas's rent wrong. He's not in Neukölln any more.\" She hears herself say it."],
				"choices": [
					{"label": "\"Where is he, then?\"", "effects": {"kiez": 1.0, "flags": ["aylin_van", "aylin_rent_slip"]}, "next": "bar"},
					{"label": "Let it go past. Redo the number.", "effects": {"kiez": 0.5, "flags": ["aylin_van"]}, "next": "bar"},
				],
			},
			"bar": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["\"And then the bar. Portugal. Small room, one good system. We've got the name already — did you know we've got the name?\"", "She says next summer the way other people say contract."],
				"choices": [
					{"label": "\"Tell me the name.\"", "effects": {"kiez": 1.0, "flags": ["aylin_portugal"]}, "next": "bench"},
					{"label": "[Schnauze 15] Ask which of the two plans is the real one.", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 1.5, "flags": ["aylin_portugal", "aylin_bar_real"]}, "next": "bench"},
					{"label": "\"Portugal's full of Berliners with a system.\"", "effects": {"kiez": -0.5, "flags": ["aylin_portugal"]}, "next": "bench"},
				],
			},
			"bench": {
				"speaker": "aylin", "expression": "tired",
				"lines": ["It lands at twenty past eight, mid-sentence, on the bench with the Mate between her knees.", "\"…The bar's for if the Sundays stop,\" she says, to the street rather than to you. \"That's what it's for.\""],
				"choices": [
					{"label": "\"The Sundays haven't stopped.\"", "effects": {"kiez": 1.5, "flags": ["aylin_sundays_named"]}, "next": "off"},
					{"label": "Say nothing. Let the street get light.", "effects": {"kiez": 1.0, "flags": ["aylin_sundays_named"]}, "next": "off"},
					{"label": "[Stamina 13] Shut the till and sit out there with her.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "cash": -6.0, "flags": ["aylin_sundays_named", "aylin_sat_with_her"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["She is upright again by half eight, because she always is. \"Next Sunday. Bench. Both of us.\" The lighter is already lost."],
				"choices": [
					{"label": "\"Next Sunday.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Aylin, AUTUMN STEP 3 — "Jonas Isn't With Her" (docs/09 §2.10). One bag. The whole staging
	# decision in one prop: Jonas is offstage and his absence IS the arc. `aylin_jonas_two` is now a real
	# gate on `aylinjonas/aj_sundays`, so this is the night the rest of the strand hangs off.
	"aylin_a3": {
		"start": "one_bag",
		"nodes": {
			"one_bag": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["\"{qty.mate} Mate — no. One Mate. Ein Wasser, {qty.cigarettes}× {brand.cigarettes}, und ein Feuerzeug.\"", "One bag on her shoulder. Seven years of Sundays and it has always, always been two."],
				"choices": [
					{"label": "Ring one Mate. Don't look at the door.", "effects": {"kiez": 0.5}, "next": "two"},
					{"label": "[Kiez Sense 12] She ordered two and corrected herself.", "check": {"stat": "wis", "dc": 12}, "next": "corrected", "next_fail": "two"},
					{"label": "\"Two Mate. Have the second one.\"", "effects": {"cash": -1.8, "kiez": 1.0}, "next": "two"},
				],
			},
			"corrected": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["She hears it half a second after you do and puts her hand flat on the counter, which is what she does instead of stopping talking.", "\"Habit. Seven years is a habit.\""],
				"choices": [
					{"label": "\"Habits are allowed.\"", "effects": {"kiez": 1.0, "flags": ["aylin_second_bag"]}, "next": "two"},
					{"label": "\"Since when?\"", "effects": {"kiez": 1.5, "flags": ["aylin_second_bag", "aylin_asked_after_him"]}, "next": "two"},
				],
			},
			"two": {
				"speaker": "aylin", "expression": "tired",
				"lines": ["\"He goes home at two now. Not with me at two — at two, on his own, from wherever we are.\"", "\"Since March. I counted it up on the U8 and then I wished I hadn't counted it up.\""],
				"choices": [
					{"label": "\"And you stay till seven.\"", "effects": {"kiez": 1.5, "flags": ["aylin_asked_after_him"]}, "next": "bench"},
					{"label": "[Brains 13] Ask what changed in March.", "check": {"stat": "int", "dc": 13}, "next": "march", "next_fail": "bench"},
					{"label": "Ring it up. It's Sunday and you're not her mum.", "effects": {"kiez": -0.5}, "next": "bench"},
				],
			},
			"march": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["A permanent contract. Sound job at a theatre, Tuesday to Saturday, with a pension in it and a rota that ends at eleven.", "\"He didn't tell me for five weeks. He was worried about it. About telling me he got a good job.\""],
				"choices": [
					{"label": "\"He was worried you'd hear it as leaving.\"", "effects": {"kiez": 1.5, "flags": ["aylin_march_contract"]}, "next": "bench"},
					{"label": "\"That's a good job, Aylin.\"", "effects": {"kiez": 1.0, "flags": ["aylin_march_contract"]}, "next": "bench"},
				],
			},
			"bench": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["Out front the bench has one coat on it instead of two, and she keeps putting the water down on the empty half."],
				"choices": [
					{"label": "\"Bench is still yours. Both ends of it.\"", "effects": {"kiez": 1.0, "flags": ["aylin_bench_both_ends"]}, "next": "lighter"},
					{"label": "[Stamina 13] Bring the crate out and make it a three.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.0, "flags": ["aylin_bench_both_ends", "aylin_sat_with_her"]}, "next": "lighter"},
					{"label": "Wipe the counter. Let her sit.", "effects": {"kiez": 0.5}, "next": "lighter"},
				],
			},
			"lighter": {
				"speaker": "aylin", "expression": "tired",
				"lines": ["She buys the lighter anyway. She has not opened the {brand.cigarettes} since she came in; the pack is sitting on the bench beside her.", "\"He always had the lighter. That was his one job on a Sunday. The lighter and the second bag.\""],
				"choices": [
					{"label": "\"I'll keep one behind the till with your name on.\"", "effects": {"kiez": 2.0, "flags": ["aylin_lighter_jar"]}, "next": "off"},
					{"label": "\"Call him. Not now. Tuesday.\"", "effects": {"kiez": 1.5, "flags": ["aylin_call_tuesday"]}, "next": "off"},
					{"label": "[Schnauze 15] Say the thing she won't let herself say.", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.5, "flags": ["aylin_named_it", "aylin_call_tuesday"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"Anyway!\" — back at one and a half speed, because the crash is at nine and she has plans until then. \"Next Sunday. I'll drag him.\""],
				"choices": [
					{"label": "\"Bring him. Two Mate.\"", "effects": {"kiez": 0.5, "flags": ["aylin_bring_jonas"]}, "next": ""},
				],
			},
		},
	},
	# ── Aylin, AUTUMN STEP 4 — "One More Season Of Sundays" (docs/09 §2.10). She keeps every component
	# of a Sunday that has one piece missing from it — the jacket, the 07:40, the second Mate. The room
	# she has mixed since 2019 gets sold in the middle of it, which is the corner's story in miniature.
	"aylin_a4": {
		"start": "october",
		"nodes": {
			"october": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"{qty.mate} Mate, ein Wasser, {qty.cigarettes}× {brand.cigarettes}, Feuerzeug. Both Mate are for me. It's a system.\"", "It is October and she is in the summer jacket, because the summer jacket is the Sunday jacket."],
				"choices": [
					{"label": "Ring the two Mate without comment.", "effects": {"kiez": 0.5}, "next": "season"},
					{"label": "[Kiez Sense 12] Nobody dresses for a season that's over.", "check": {"stat": "wis", "dc": 12}, "next": "jacket", "next_fail": "season"},
					{"label": "\"It's nine degrees, Aylin.\"", "effects": {"kiez": 0.5}, "next": "season"},
				],
			},
			"jacket": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["The jacket, the bench, the 07:40, the lighter. She is running every channel of a Sunday that has one input dead.", "\"It's not superstition. It's — okay, it's slightly superstition.\""],
				"choices": [
					{"label": "\"You're running the whole rig for one channel.\"", "effects": {"kiez": 1.5, "flags": ["aylin_running_the_rig"]}, "next": "season"},
					{"label": "Turn the heater round to face the door.", "effects": {"kiez": 1.5, "cash": -2.0, "flags": ["aylin_bench_heater"]}, "next": "season"},
				],
			},
			"season": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["\"One more season. That's all I want. One more winter of Sundays and then we'll see where we are.\"", "\"That's not a plan. Before you say it — I know it's not a plan.\""],
				"choices": [
					{"label": "\"It's a wish with a date on it. Those count.\"", "effects": {"kiez": 1.0, "flags": ["aylin_season_promise"]}, "next": "club"},
					{"label": "[Brains 13] Ask what a winter does to the van money.", "check": {"stat": "int", "dc": 13}, "next": "money", "next_fail": "club"},
					{"label": "\"It's not a plan.\"", "effects": {"kiez": -0.5}, "next": "club"},
				],
			},
			"money": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["The van fund has not moved since August. It has gone down twice, both times for a booking that fell through.", "\"…I'm not saving for a van. I'm saving for a reason to still be doing this in two years.\""],
				"choices": [
					{"label": "\"That's a better thing to be saving for.\"", "effects": {"kiez": 1.5, "flags": ["aylin_van_stalled"]}, "next": "club"},
					{"label": "\"Say that to him. Exactly that.\"", "effects": {"kiez": 1.5, "flags": ["aylin_van_stalled", "aylin_call_tuesday"]}, "next": "club"},
				],
			},
			"club": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["The room she has mixed since 2019 has been sold. Same building, new operator, and the new operator has a house engineer.", "\"They sent a PDF. There was a PDF, and my name was not in the PDF.\""],
				"choices": [
					{"label": "\"Then the Sundays stop being about the club.\"", "effects": {"kiez": 1.5, "flags": ["aylin_club_sold"]}, "next": "off"},
					{"label": "[Schnauze 15] \"Who gets the bookings when the room shuts?\"", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.0, "flags": ["aylin_club_sold", "aylin_asked_the_room"]}, "next": "off"},
					{"label": "\"There's other rooms.\"", "effects": {"kiez": 0.5, "flags": ["aylin_club_sold"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "aylin", "expression": "tired",
				"lines": ["She takes the second Mate out to the bench and sits at the end of it that is not hers, for the first time in seven years."],
				"choices": [
					{"label": "\"Bench is open till eight.\"", "effects": {"kiez": 1.0, "flags": ["aylin_one_more_named"]}, "next": ""},
					{"label": "\"Sunday after next, then.\"", "effects": {"kiez": 0.5, "flags": ["aylin_one_more_named"]}, "next": ""},
				],
			},
		},
	},
	# ── Aylin, WINTER STEP 5 — "The Job In Leipzig" (docs/09 §2.10). One of them has to choose, and the
	# persona card's twist is that it is HER offer too. The fence notice comes off the door in the same
	# conversation: Aylin is the third independent route to `main_lever_hint` (docs/09 §4.10).
	"aylin_w5": {
		"start": "leipzig",
		"nodes": {
			"leipzig": {
				"speaker": "aylin", "expression": "tired",
				"lines": ["\"{qty.mate} Mate. Ein Wasser. {qty.cigarettes}× {brand.cigarettes} und ein Feuerzeug.\" No glitter. 07:38, and she has come from a flat, not from a room.", "\"He's been offered Leipzig. Head of sound. Actual title, actual contract, three years.\""],
				"choices": [
					{"label": "\"That's enormous. For him.\"", "effects": {"kiez": 0.5}, "next": "three"},
					{"label": "[Kiez Sense 12] She is not asking you about Jonas.", "check": {"stat": "wis", "dc": 12}, "next": "herself", "next_fail": "three"},
					{"label": "Ring it up. Give her the room.", "next": "three"},
				],
			},
			"herself": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["She has been offered it too. Second engineer, same house, same three years, and the email has been in her phone since Thursday.", "\"Don't do the face. I know what the face is.\""],
				"choices": [
					{"label": "\"What does the email say?\"", "effects": {"kiez": 1.5, "flags": ["aylin_leipzig_offer"]}, "next": "three"},
					{"label": "\"You've read it more than once.\"", "effects": {"kiez": 1.0, "flags": ["aylin_leipzig_offer"]}, "next": "three"},
				],
			},
			"three": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["Three years. An hour and twenty on the train. A flat with a room in it you could put a desk in.", "\"There's no Sunday in it. That's the whole thing. There is no 07:40 anywhere in three years of that.\""],
				"choices": [
					{"label": "\"There's a 07:40 wherever you decide there is.\"", "effects": {"kiez": 1.0, "flags": ["aylin_told_her_go"]}, "next": "fence"},
					{"label": "[Brains 13] Cost a Sunday from Leipzig, properly.", "check": {"stat": "int", "dc": 13}, "next": "cost", "next_fail": "fence"},
					{"label": "\"Then don't go.\"", "effects": {"kiez": -0.5, "flags": ["aylin_told_her_stay"]}, "next": "fence"},
				],
			},
			"cost": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["Twenty-nine euro on the early train, one night out of a weekend, twice a month. Less than the van. Considerably less than a bar in Portugal.", "\"…You've just costed my relationship on a Pfand receipt.\" She laughs and it comes out wrong and she lets it."],
				"choices": [
					{"label": "\"I cost everything on a Pfand receipt.\"", "effects": {"kiez": 1.5, "flags": ["aylin_told_her_go", "aylin_costed_it"]}, "next": "fence"},
					{"label": "\"Twice a month is still a Sunday.\"", "effects": {"kiez": 1.5, "flags": ["aylin_told_her_go"]}, "next": "fence"},
				],
			},
			"fence": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["On her way in she took the paper off the door and brought it with her. Contractor's notice: hoarding, pavement licence, the bench side of the corner, from the fourteenth.", "\"So the bench is going anyway. Did you know the bench is going.\""],
				"choices": [
					{"label": "\"…No. Leave it with me.\"", "effects": {"kiez": 1.0, "flags": ["aylin_fence", "main_lever_hint"]}, "next": "off"},
					{"label": "[Schnauze 15] \"Then we object. You've a Sunday free.\"", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.5, "flags": ["aylin_fence", "main_lever_hint", "aylin_objects"]}, "next": "off"},
					{"label": "\"It's a pavement licence. They expire.\"", "effects": {"flags": ["aylin_fence"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["\"I'll tell you which way before I tell him,\" she says at the door, \"which is probably a thing a therapist would have an opinion about.\""],
				"choices": [
					{"label": "\"Sunday, either way.\"", "effects": {"kiez": 1.0, "flags": ["aylin_tells_you_first"]}, "next": ""},
				],
			},
		},
	},
	# ── Aylin, WINTER STEP 6 — "The Magic Was Each Other" (docs/09 §2.10). Two bags again, and the
	# discovery that neither of them ever loved the club. The lighter finally gets explained: it was
	# never fire, it was a small object to hand somebody every Sunday for seven years.
	"aylin_w6": {
		"start": "two_bags",
		"nodes": {
			"two_bags": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["Two bags. He is out on the bench with both of them and has not come in, because coming in was never his job.", "\"{qty.mate} Mate — two, properly two — ein Wasser, {qty.cigarettes}× {brand.cigarettes}, und ein Feuerzeug.\""],
				"choices": [
					{"label": "Two Mate on the counter. And the lighter.", "effects": {"kiez": 1.0}, "next": "talk"},
					{"label": "[Kiez Sense 12] She buys a lighter and he carries one.", "check": {"stat": "wis", "dc": 12}, "next": "lighter", "next_fail": "talk"},
					{"label": "\"Tell him the coffee's on if he comes in.\"", "effects": {"kiez": 1.0, "flags": ["aylin_jonas_came"]}, "next": "talk"},
				],
			},
			"lighter": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["Seven years of Sundays and the lighter was never about fire. It was a small object bought so there would be something to hand him.", "\"…Okay, that's horrible. Say something else.\""],
				"choices": [
					{"label": "Give her two lighters. Don't explain.", "effects": {"cash": -0.3, "kiez": 2.0, "flags": ["aylin_two_lighters"]}, "next": "talk"},
					{"label": "\"You've never once smoked before nine.\"", "effects": {"kiez": 1.0, "flags": ["aylin_two_lighters"]}, "next": "talk"},
				],
			},
			"talk": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["\"We did the thing. Four hours, on the floor, with the map out, like a load-in.\"", "\"And it turns out neither of us wants Leipzig. We want the bit where the other one is there when it finishes.\""],
				"choices": [
					{"label": "\"That's what the room was, then.\"", "effects": {"kiez": 1.5, "flags": ["aylin_magic_named"]}, "next": "offer"},
					{"label": "[Brains 13] Ask which of them said it first.", "check": {"stat": "int", "dc": 13}, "next": "first", "next_fail": "offer"},
					{"label": "\"So nobody goes.\"", "effects": {"kiez": 0.5}, "next": "offer"},
				],
			},
			"first": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["He did. At about half two, holding the kettle, having not said a full sentence for eleven minutes.", "\"He said: I don't miss the club. And I went — oh. Oh no. Me neither.\""],
				"choices": [
					{"label": "\"Seven years to find that out is quite fast.\"", "effects": {"kiez": 1.5, "flags": ["aylin_magic_named", "aylin_jonas_said_it"]}, "next": "offer"},
					{"label": "\"Then the Sundays were never the club.\"", "effects": {"kiez": 1.5, "flags": ["aylin_magic_named"]}, "next": "offer"},
				],
			},
			"offer": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["\"He's taking it. Second engineer, not head — they swapped it, he asked them to swap it, which is insane.\"", "\"And I'm here. Tuesday to Saturday at the new place on the big street, and Sundays are Sundays.\""],
				"choices": [
					{"label": "\"Then the bench stays where it is.\"", "effects": {"kiez": 1.5, "flags": ["aylin_bench_stays"]}, "next": "off"},
					{"label": "[Stamina 13] Open at seven on Sundays. Say it out loud.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "flags": ["aylin_bench_stays", "aylin_seven_am"]}, "next": "off"},
					{"label": "\"An hour twenty each way. Every week.\"", "effects": {"kiez": 0.5}, "next": "off"},
				],
			},
			"off": {
				"speaker": "aylin", "expression": "tired",
				"lines": ["She takes the second Mate out to him and sits down, and the two of them say nothing for about four minutes, which is the loudest thing that has happened on that bench in a year."],
				"choices": [
					{"label": "\"Bis Sonntag.\"", "effects": {"kiez": 1.0, "flags": ["aylin_jonas_came"]}, "next": ""},
				],
			},
		},
	},
	# ── Aylin, SPRING STEP 7 — "They Come At Eight In The Evening Now" (docs/09 §2.10). The Sunday
	# survives by moving twelve hours. The bench survived because forty-one people wrote to a Bezirksamt
	# about a bench, and she still buys a lighter, every single time, without exception.
	"aylin_p7": {
		"start": "evening",
		"nodes": {
			"evening": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["Twenty past eight. In the EVENING. \"{qty.mate} Mate, ein Wasser, {qty.cigarettes}× {brand.cigarettes} — und ein Feuerzeug.\"", "\"Don't say anything about the Feuerzeug.\""],
				"choices": [
					{"label": "Put the lighter down first, like always.", "effects": {"kiez": 1.0}, "next": "bench"},
					{"label": "[Kiez Sense 12] Something is different besides the hour.", "check": {"stat": "wis", "dc": 12}, "next": "ring", "next_fail": "bench"},
					{"label": "\"Evening, Aylin.\"", "effects": {"kiez": 0.5}, "next": "bench"},
				],
			},
			"ring": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["A ring, on the wrong hand, which she says is deliberate and is not deliberate.", "\"It's a thing we did at the registry office on a Tuesday with two witnesses off the street. It's not a wedding, it's an admin decision.\""],
				"choices": [
					{"label": "\"Congratulations on your admin decision.\"", "effects": {"kiez": 2.0, "flags": ["aylin_ring"]}, "next": "bench"},
					{"label": "\"Which two off the street?\" (Mehmet. And Jürgen.)", "effects": {"kiez": 2.0, "flags": ["aylin_ring", "aylin_witnesses"]}, "next": "bench"},
				],
			},
			"bench": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["The bench is still there. The hoarding went up eleven metres further down and stopped, because forty-one people wrote to a Bezirksamt about a bench.", "\"I read the objection. Somebody put in the bit about seven years of Sundays. Was that you.\""],
				"choices": [
					{"label": "\"It was Herr Bley's lawyer, actually.\"", "effects": {"kiez": 1.0, "flags": ["aylin_bench_saved"]}, "next": "jar"},
					{"label": "\"Everybody put in a bit.\"", "effects": {"kiez": 1.5, "flags": ["aylin_bench_saved"]}, "next": "jar"},
					{"label": "[Schnauze 15] \"It was you. You said it here first.\"", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.0, "flags": ["aylin_bench_saved", "aylin_objects"]}, "next": "jar"},
				],
			},
			"jar": {
				"speaker": "aylin", "expression": "warm",
				"lines": ["The jar behind the till has nine lighters in it. Three are hers, two are Jonas's, one is Robin's, and nobody knows about the other three."],
				"choices": [
					{"label": "Take one out of the jar. Charge her anyway.", "effects": {"cash": 1.2, "kiez": 1.5, "flags": ["aylin_jar_kept"]}, "next": "sundays"},
					{"label": "\"House lighter. You've paid nine times.\"", "effects": {"kiez": 2.0, "flags": ["aylin_jar_kept"]}, "next": "sundays"},
				],
			},
			"sundays": {
				"speaker": "aylin", "expression": "neutral",
				"lines": ["\"Eight in the evening is a completely different corner. There are children. There's a man who sits there with a dog and says nothing.\"", "\"I've been coming here since I was twenty-two and I've never once seen it in daylight.\""],
				"choices": [
					{"label": "\"Same corner. You were asleep for it.\"", "effects": {"kiez": 1.0, "flags": ["aylin_evening_sundays"]}, "next": "off"},
					{"label": "[Brains 13] Tell her what an evening Sunday pays for.", "check": {"stat": "int", "dc": 13}, "next": "pays", "next_fail": "off"},
					{"label": "\"Sunday evening's the best shift there is.\"", "effects": {"kiez": 1.0, "flags": ["aylin_evening_sundays"]}, "next": "off"},
				],
			},
			"pays": {
				"speaker": "aylin", "expression": "surprised",
				"lines": ["An evening Sunday takes four times what a 07:40 Sunday takes, and the difference is exactly what keeps the door open at 03:40 for a nurse.", "\"So I'm subsidising a nurse. Yeah, alright. I'll take that.\""],
				"choices": [
					{"label": "\"You're subsidising a nurse.\"", "effects": {"kiez": 1.5, "flags": ["aylin_evening_sundays", "aylin_subsidy"]}, "next": "off"},
					{"label": "\"You always were. You just did it at dawn.\"", "effects": {"kiez": 1.5, "flags": ["aylin_evening_sundays"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "aylin", "expression": "tired",
				"lines": ["They stay till eleven, which is late for people who now get up, and leave the Pfand stacked in the crate the way Jürgen likes it."],
				"choices": [
					{"label": "\"Bis Sonntag. Both of you.\"", "effects": {"kiez": 1.0, "flags": ["aylin_still_a_lighter"]}, "next": ""},
				],
			},
		},
	},
	# ── Herr Bley, SUMMER STEP 2 — "\"Young Man\"" (docs/09 §2.11). The armour, worn politely: a form of
	# address that keeps the transaction a transaction. `bley_talks` is now a REAL gate on
	# `bley/b_armour`, so the night he gives you his first name is the night the winter becomes possible.
	# His frozen face set has no `warm` and no `upset` on disk — neutral · wary · surprised · tired only.
	"bley_s2": {
		"start": "three_ten",
		"nodes": {
			"three_ten": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["\"Water. Still. A chocolate. And {qty.cigarettes}× {brand.cigarettes}.\" Word for word as it was said last night, and the night before that.", "\"Young man,\" he adds, which is not your name, and is the ninth night running."],
				"choices": [
					{"label": "\"Coming up.\" Ring it at his speed.", "next": "nine"},
					{"label": "[Kiez Sense 12] Young man is doing work for him.", "check": {"stat": "wis", "dc": 12}, "next": "armour", "next_fail": "nine"},
					{"label": "\"I have got a name, you know.\"", "effects": {"kiez": 0.5, "flags": ["bley_name_offered"]}, "next": "nine"},
				],
			},
			"armour": {
				"speaker": "bley", "expression": "wary",
				"lines": ["It is not condescension. It is a wall with a polite face on it: an address that keeps the transaction a transaction and everything else outside on the pavement.", "He turns the water bottle a quarter turn on the laminate. Twice."],
				"choices": [
					{"label": "Let him have it. Say nothing.", "effects": {"kiez": 1.0, "flags": ["bley_armour_seen"]}, "next": "nine"},
					{"label": "\"Fair enough. Young man's fine.\"", "effects": {"kiez": 1.0, "flags": ["bley_armour_seen"]}, "next": "nine"},
				],
			},
			"nine": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["Nine minutes over four euro forty. The chocolate sits on the laminate getting a great deal of attention and is not picked up."],
				"choices": [
					{"label": "Put the chocolate in the bag. Don't charge.", "effects": {"cash": -0.55, "kiez": 1.0, "flags": ["bley_chocolate_gift"]}, "next": "grunewald"},
					{"label": "[Brains 13] He buys a chocolate he never eats.", "check": {"stat": "int", "dc": 13}, "next": "chocolate", "next_fail": "grunewald"},
					{"label": "\"Four forty, bitte.\"", "next": "grunewald"},
				],
			},
			"chocolate": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["Every night. Bought, paid for, left on the counter — and by the third week you had started putting it back out for whoever came next.", "\"…My wife used to. On a Friday.\" Two seconds. \"The water is the important item.\""],
				"choices": [
					{"label": "\"The water's the important item.\"", "effects": {"kiez": 1.5, "flags": ["bley_friday_chocolate"]}, "next": "grunewald"},
					{"label": "\"Used to.\"", "effects": {"kiez": 1.0, "flags": ["bley_friday_chocolate", "bley_used_to"]}, "next": "grunewald"},
				],
			},
			"grunewald": {
				"speaker": "bley", "expression": "wary",
				"lines": ["\"In Grunewald there is nothing open at three. Not one thing. Not even the people.\"", "\"I leave at midnight. I drive. It is, I am aware, an absurd way to conduct a life.\""],
				"choices": [
					{"label": "\"You're the third one tonight. It's a trade.\"", "effects": {"kiez": 1.0}, "next": "name"},
					{"label": "[Schnauze 15] Ask him something that isn't a price.", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.0, "flags": ["bley_talks", "bley_asked_something"]}, "next": "name"},
					{"label": "\"Forty minutes each way. For a water.\"", "effects": {"kiez": 0.5}, "next": "name"},
				],
			},
			"name": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["\"Rüdiger,\" he says on his way to the door, without turning round, as though correcting an invoice. \"Bley.\"", "\"Since we appear to be doing this.\""],
				"choices": [
					{"label": "\"Noted. Chocolate's one forty.\"", "effects": {"kiez": 1.5, "flags": ["bley_talks"]}, "next": "off"},
					{"label": "\"Then you'll have to learn mine.\"", "effects": {"kiez": 2.0, "flags": ["bley_talks", "bley_name_offered"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "bley", "expression": "tired",
				"lines": ["\"Same time tomorrow, presumably.\" It is not a question. He leaves the chocolate."],
				"choices": [
					{"label": "\"Same time.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Herr Bley, AUTUMN STEP 3 — "He Stays Eleven Minutes" (docs/09 §2.11). Eleven minutes over a
	# four-euro transaction, and one question about you, which is the unguarded clause of the night. The
	# crate by the door is Jürgen's; offering it is the first physical thing anyone has offered him.
	"bley_a3": {
		"start": "eleven",
		"nodes": {
			"eleven": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["\"Water — still — a chocolate, and {qty.cigarettes}× {brand.cigarettes}. {logo.cigarettes}. Thank you.\"", "Eleven minutes tonight. You have started timing it, which you are aware is a strange thing to have started doing."],
				"choices": [
					{"label": "Wipe the fridge doors. Stay in earshot.", "effects": {"kiez": 0.5}, "next": "weather"},
					{"label": "[Kiez Sense 12] He is waiting for the shop to empty.", "check": {"stat": "wis", "dc": 12}, "next": "empty", "next_fail": "weather"},
					{"label": "\"Anything else, Herr Bley?\"", "next": "weather"},
				],
			},
			"empty": {
				"speaker": "bley", "expression": "wary",
				"lines": ["He came in at 03:10, saw two people at the fridges, bought nothing, walked to the end of the block and came back at 03:19.", "\"It was a pleasant evening for it.\" It is November."],
				"choices": [
					{"label": "Lock nothing. Just stop moving about.", "effects": {"kiez": 1.0, "flags": ["bley_waits_for_empty"]}, "next": "weather"},
					{"label": "\"You walked round the block.\"", "effects": {"kiez": 1.5, "flags": ["bley_waits_for_empty"]}, "next": "weather"},
				],
			},
			"weather": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["He talks about the weather for four minutes, correctly and in detail, the way a man talks when the talking is the point and the subject is not.", "Then: \"You are here every night. Do you find that you mind it.\""],
				"choices": [
					{"label": "\"Some nights. Not tonight.\"", "effects": {"kiez": 1.0, "flags": ["bley_asked_something"]}, "next": "house"},
					{"label": "[Brains 13] He has asked you a question about you.", "check": {"stat": "int", "dc": 13}, "next": "asked", "next_fail": "house"},
					{"label": "\"It's a shop. It opens.\"", "next": "house"},
				],
			},
			"asked": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["Thirty-one years in corporate finance, and nobody at three in the morning has asked him a question that was not about a price. He has just asked you one.", "He appears mildly appalled at himself."],
				"choices": [
					{"label": "Answer it properly. Take your time.", "effects": {"kiez": 2.0, "flags": ["bley_asked_something", "bley_answered_properly"]}, "next": "house"},
					{"label": "\"Yes. And then somebody comes in.\"", "effects": {"kiez": 1.5, "flags": ["bley_asked_something"]}, "next": "house"},
				],
			},
			"house": {
				"speaker": "bley", "expression": "wary",
				"lines": ["\"There is a house in Grunewald with four bedrooms and, at present, one person in it. That person is not me, and at three in the morning it is not her either.\"", "An ordinary sentence follows immediately, about what hotels charge for water."],
				"choices": [
					{"label": "Let the ordinary sentence cover it. Nod.", "effects": {"kiez": 1.0, "flags": ["bley_house"]}, "next": "crate"},
					{"label": "[Schnauze 15] Don't let the ordinary sentence cover it.", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.0, "flags": ["bley_house", "bley_uncovered"]}, "next": "crate"},
					{"label": "\"Hotels rob you. It's the business model.\"", "effects": {"kiez": 0.5}, "next": "crate"},
				],
			},
			"crate": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["There is a crate by the door that Jürgen sits on. It is clean, and there is a folded coat on it that is not Jürgen's."],
				"choices": [
					{"label": "\"Crate's free. It's been sat on by worse.\"", "effects": {"kiez": 1.5, "flags": ["bley_crate_offered"]}, "next": "off"},
					{"label": "[Stamina 13] Stay open past four and let him have it.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "cash": -9.0, "flags": ["bley_crate_offered", "bley_stayed_late"]}, "next": "off"},
					{"label": "Say nothing about the crate.", "next": "off"},
				],
			},
			"off": {
				"speaker": "bley", "expression": "tired",
				"lines": ["Eleven minutes becomes nineteen. He takes the water, leaves the chocolate, and squares the coins to the edge of the till before he goes."],
				"choices": [
					{"label": "\"Gute Nacht, Herr Bley.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Herr Bley, AUTUMN STEP 4 — "What He Read On A Tuesday" (docs/09 §2.11). Page eleven, mentioned
	# as small talk by a man who did not look at the street name. He is the lever: the first route to
	# `main_lever_hint`, months before Brandt hands you hers, through a customer relationship.
	"bley_a4": {
		"start": "tuesday",
		"nodes": {
			"tuesday": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["\"Water, still. A chocolate. {qty.cigarettes}× {brand.cigarettes}.\" A pause of exactly the wrong length. \"This street, by the way.\"", "\"Somebody put a paper in front of me on a Tuesday. Block acquisition, mixed use. A very tidy structure.\""],
				"choices": [
					{"label": "\"Tidy for who?\"", "effects": {"kiez": 0.5, "flags": ["bley_page_eleven"]}, "next": "page"},
					{"label": "[Kiez Sense 12] He has worked out where he is standing.", "check": {"stat": "wis", "dc": 12}, "next": "knows", "next_fail": "page"},
					{"label": "Ring up the water. Let him keep talking.", "next": "page"},
				],
			},
			"knows": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["He knows. He worked it out four nights ago off a delivery note behind the till, and he has come back every night since.", "\"One does not look at the street name. That is not an excuse. It is a description.\""],
				"choices": [
					{"label": "\"You're standing in page eleven.\"", "effects": {"kiez": 1.0, "flags": ["bley_page_eleven", "bley_told_him"]}, "next": "page"},
					{"label": "Say nothing. Let him say it.", "effects": {"kiez": 1.5, "flags": ["bley_page_eleven", "bley_told_him"]}, "next": "page"},
				],
			},
			"page": {
				"speaker": "bley", "expression": "wary",
				"lines": ["\"I signed off the financing. Page eleven of a document with nineteen pages in it. Then I went to lunch.\"", "\"That is the entire extent of my involvement, and it is also, I am aware, the whole thing.\""],
				"choices": [
					{"label": "\"What does page eleven give them, exactly?\"", "effects": {"kiez": 1.0, "flags": ["bley_page_eleven"]}, "next": "clause"},
					{"label": "[Brains 14] Read the structure back to him.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 1.5, "flags": ["bley_page_eleven", "bley_read_it_back"]}, "next": "clause"},
					{"label": "\"Then unsign it.\"", "effects": {"kiez": 0.5, "integrity": 1.0, "flags": ["bley_page_eleven"]}, "next": "clause"},
				],
			},
			"clause": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["The facility is conditional. Vacant possession by a fixed date, or the tranche reprices — so every week a tenant stays is a number on somebody's spreadsheet going the wrong way.", "\"…You understood that faster than my analyst.\" He looks at the hand-written prices on the fridge."],
				"choices": [
					{"label": "\"I won't say where I heard it. What's the date?\"", "effects": {"kiez": 1.5, "flags": ["bley_tip", "main_lever_hint"]}, "next": "date"},
					{"label": "[Schnauze 13] Ask him to write it, with no name on it.", "check": {"stat": "cha", "dc": 13}, "effects_success": {"kiez": 2.0, "flags": ["bley_tip", "main_lever_hint", "bley_wrote_it"]}, "effects_fail": {"kiez": 0.5}, "next": "date", "next_fail": "date"},
					{"label": "\"You financed it. You can unfinance it.\"", "effects": {"kiez": 0.5, "integrity": 1.0, "flags": ["bley_tip"]}, "next": "date"},
				],
			},
			"date": {
				"speaker": "bley", "expression": "wary",
				"lines": ["He takes a Pfand receipt off the counter, writes six characters on it, and puts it face down under the chocolate.", "\"I would not repeat where that came from. Not to the greengrocer. Not to the loud one with the flyers.\""],
				"choices": [
					{"label": "\"Nobody hears it from me.\"", "effects": {"kiez": 1.5, "flags": ["bley_kept_quiet"]}, "next": "off"},
					{"label": "\"Mehmet will ask me how I know.\"", "effects": {"kiez": 1.0, "flags": ["bley_kept_quiet"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "bley", "expression": "tired",
				"lines": ["He does not stay tonight. Four minutes exactly, and the water is still full when he reaches the door."],
				"choices": [
					{"label": "\"Gute Nacht, Rüdiger.\"", "effects": {"kiez": 0.5}, "next": ""},
				],
			},
		},
	},
	# ── Herr Bley, WINTER STEP 5 — "The Armour Comes Off" (docs/09 §2.11). A divorce, a collapse, 3am,
	# and a man in a coat that cost more than the fridge sitting on a Flaschensammler's crate. The beat
	# `bley/b_armour` gates on `bley_talks`, which is the summer step's first name.
	"bley_w5": {
		"start": "coat",
		"nodes": {
			"coat": {
				"speaker": "bley", "expression": "tired",
				"lines": ["\"Water.\" A long pause. \"Still. And the chocolate. {qty.cigarettes}× {brand.cigarettes}.\" The order comes out in three pieces instead of one.", "Same coat. Everything under it has come apart."],
				"choices": [
					{"label": "Ring it slowly. Give him the time.", "effects": {"kiez": 0.5}, "next": "letters"},
					{"label": "[Kiez Sense 12] He has been in the car since two.", "check": {"stat": "wis", "dc": 12}, "next": "car", "next_fail": "letters"},
					{"label": "\"Rough one?\"", "effects": {"kiez": 0.5}, "next": "letters"},
				],
			},
			"car": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["The car is across the road with the engine off and the interior light on. He has been in it for an hour and eleven minutes.", "\"I did not wish to arrive before you were quiet.\""],
				"choices": [
					{"label": "\"We're quiet. Come in properly.\"", "effects": {"kiez": 1.5, "flags": ["bley_car"]}, "next": "letters"},
					{"label": "Put the coffee on without asking.", "effects": {"cash": -0.3, "kiez": 2.0, "flags": ["bley_car", "bley_coffee"]}, "next": "letters"},
				],
			},
			"letters": {
				"speaker": "bley", "expression": "wary",
				"lines": ["A house in Grunewald with one person in it, and as of the fourteenth the one person is not him. A daughter in Hamburg who forwards his post unopened.", "\"I am not —\" He stops. \"I would like the water. That is all I would like.\""],
				"choices": [
					{"label": "Put the water in front of him. Stay put.", "effects": {"kiez": 1.5, "flags": ["bley_armour_off"]}, "next": "crate"},
					{"label": "[Schnauze 15] \"Sit down, Rüdiger. The crate's clean.\"", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.5, "flags": ["bley_armour_off", "bley_sat_down"]}, "next": "crate"},
					{"label": "\"Four forty.\" It's 3am and he's a customer.", "effects": {"kiez": -1.0, "flags": ["bley_armour_off"]}, "next": "coins"},
				],
			},
			"crate": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["He sits on Jürgen's crate, in a coat that cost more than the fridge, with a bottle of still water, under a strip light, at twenty past three.", "\"I have not sat down in a shop since I was a student. I am not certain I ever have.\""],
				"choices": [
					{"label": "\"First time for everything.\"", "effects": {"kiez": 1.0, "flags": ["bley_sat_down"]}, "next": "thirty"},
					{"label": "[Stamina 13] Stay open until it gets light.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "cash": -14.0, "flags": ["bley_sat_down", "bley_stayed_late"]}, "next": "thirty"},
					{"label": "\"Don't tell Jürgen. That's his crate.\"", "effects": {"kiez": 1.5, "flags": ["bley_sat_down"]}, "next": "thirty"},
				],
			},
			"thirty": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["\"Thirty-one years,\" he says, to the fridge rather than to you, \"and the person who has asked me the most questions this year works nights in a Spätkauf.\"", "\"That is not a compliment to you. It is an audit of me.\""],
				"choices": [
					{"label": "\"I'll take it either way.\"", "effects": {"kiez": 1.5, "flags": ["bley_audit"]}, "next": "coins"},
					{"label": "[Brains 13] Tell him what an audit is actually for.", "check": {"stat": "int", "dc": 13}, "next": "audit", "next_fail": "coins"},
					{"label": "\"It's a Späti. Nobody's got anywhere to be.\"", "effects": {"kiez": 1.0}, "next": "coins"},
				],
			},
			"audit": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["An audit is not a verdict. It is a list of what is actually there, made once, honestly, so the next decision is taken on the real numbers.", "He does not answer that for a while. \"…Yes. Well. Quite.\""],
				"choices": [
					{"label": "\"So do the list. You've got until it's light.\"", "effects": {"kiez": 2.0, "flags": ["bley_audit", "bley_did_the_list"]}, "next": "coins"},
					{"label": "\"You can start with page eleven.\"", "effects": {"kiez": 1.5, "flags": ["bley_audit"]}, "next": "coins"},
				],
			},
			"coins": {
				"speaker": "bley", "expression": "tired",
				"lines": ["He pays cash, exact, and does not want a bag. The chocolate stays on the counter. Tonight you do not put it back out."],
				"choices": [
					{"label": "\"Tomorrow. Ten past three.\"", "effects": {"kiez": 1.0, "flags": ["bley_tomorrow"]}, "next": ""},
				],
			},
		},
	},
	# ── Herr Bley, WINTER STEP 6 — "Somebody Saw Him" (docs/09 §2.11). Eleven nights away and the
	# greengrocer asked after him, which has not happened to him in thirty-one years. The corner did what
	# his world didn't, and he tries to make the gratitude into a transaction, because that he can do.
	"bley_w6": {
		"start": "back",
		"nodes": {
			"back": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["\"Water, still. Chocolate. {qty.cigarettes}× {brand.cigarettes}.\" The order comes out in one piece again, which is its own kind of news.", "He has been away eleven nights."],
				"choices": [
					{"label": "\"Eleven nights. The chocolate's been piling up.\"", "effects": {"kiez": 1.0}, "next": "gap"},
					{"label": "[Kiez Sense 12] He came back at the exact same minute.", "check": {"stat": "wis", "dc": 12}, "next": "minute", "next_fail": "gap"},
					{"label": "Ring it. Don't count the nights out loud.", "next": "gap"},
				],
			},
			"minute": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["03:10. To the minute, after eleven nights away — which means he drove around until it was 03:10."],
				"choices": [
					{"label": "\"You waited in the car for it, didn't you.\"", "effects": {"kiez": 1.5, "flags": ["bley_kept_the_time"]}, "next": "gap"},
					{"label": "Say nothing. Have the water out before he asks.", "effects": {"kiez": 1.5, "flags": ["bley_kept_the_time"]}, "next": "gap"},
				],
			},
			"gap": {
				"speaker": "bley", "expression": "wary",
				"lines": ["\"I was in Frankfurt. Then I was not in Frankfurt and I did not come here, which I am aware you will have noticed.\"", "\"The greengrocer asked after me. In a shop. To my face. I did not know what to do with that.\""],
				"choices": [
					{"label": "\"He asks after everyone. It's a condition.\"", "effects": {"kiez": 1.0, "flags": ["bley_asked_after"]}, "next": "seen"},
					{"label": "[Brains 13] Tell him what being asked after means here.", "check": {"stat": "int", "dc": 13}, "next": "means", "next_fail": "seen"},
					{"label": "\"Mehmet's been keeping your chocolate.\"", "effects": {"kiez": 1.5, "flags": ["bley_asked_after"]}, "next": "seen"},
				],
			},
			"means": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["It means somebody noticed a gap. That is the entire mechanism of a street: eleven people who notice a gap, and one of them says it out loud in a greengrocer's.", "\"In thirty-one years nobody has noticed a gap.\" A beat. \"The water is the important item.\""],
				"choices": [
					{"label": "\"The water's the important item.\"", "effects": {"kiez": 2.0, "flags": ["bley_seen", "bley_asked_after"]}, "next": "seen"},
					{"label": "\"Somebody noticed, Rüdiger.\"", "effects": {"kiez": 2.0, "flags": ["bley_seen"]}, "next": "seen"},
				],
			},
			"seen": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["He is still here at four. At half four he is still here. Nadia comes in at 03:40 and says good morning to him by name, and he says it back, correctly, with hers."],
				"choices": [
					{"label": "Let them talk. Do the fridges.", "effects": {"kiez": 1.5, "flags": ["bley_seen"]}, "next": "ask"},
					{"label": "[Stamina 13] Make three coffees and stay out of it.", "requires": {"stat": "con", "min": 13}, "effects": {"cash": -0.9, "kiez": 2.5, "flags": ["bley_seen", "bley_three_coffees"]}, "next": "ask"},
					{"label": "\"Herr Bley — Nadia. Nadia — Herr Bley.\"", "effects": {"kiez": 2.0, "flags": ["bley_seen"]}, "next": "ask"},
				],
			},
			"ask": {
				"speaker": "bley", "expression": "wary",
				"lines": ["\"I have a question, and I would like it to be a transaction, because I do not know how to ask it otherwise.\"", "\"What would it cost. To keep this open. The flats above as well. A number.\""],
				"choices": [
					{"label": "\"I'll get you a number.\"", "effects": {"kiez": 1.5, "flags": ["bley_asked_the_number"]}, "next": "off"},
					{"label": "[Schnauze 15] \"It isn't a number and you know it.\"", "requires": {"stat": "cha", "min": 15}, "effects": {"kiez": 2.5, "flags": ["bley_asked_the_number", "bley_not_a_number"]}, "next": "off"},
					{"label": "\"You can't buy your way out of page eleven.\"", "effects": {"kiez": 0.5, "flags": ["bley_asked_the_number"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "bley", "expression": "tired",
				"lines": ["He takes the chocolate with him for the first time since the summer, puts it in his coat pocket, and does not mention it."],
				"choices": [
					{"label": "\"Tomorrow. Ten past three.\"", "effects": {"kiez": 1.0}, "next": ""},
				],
			},
		},
	},
	# ── Herr Bley, SPRING STEP 7 — "A Quiet Patron" (docs/09 §2.11). The envelope, squared to the edge:
	# a year of the Mieterverein retainer with no name on the transfer, and an instruction never to
	# mention it. The strand beat `bley/b_patron` gates on `bley_tip` — the clause he let slip in autumn.
	"bley_p7": {
		"start": "envelope",
		"nodes": {
			"envelope": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["\"Water. Still. A chocolate. {qty.cigarettes}× {brand.cigarettes}.\" And an envelope, squared to the edge of the counter, exactly parallel.", "\"That is not for me to explain and it is not for you to open now.\""],
				"choices": [
					{"label": "Leave it face down. Ring the water.", "effects": {"kiez": 0.5}, "next": "retainer"},
					{"label": "[Kiez Sense 12] He has carried that for a fortnight.", "check": {"stat": "wis", "dc": 12}, "next": "fortnight", "next_fail": "retainer"},
					{"label": "\"What is it, Rüdiger.\"", "effects": {"kiez": 0.5}, "next": "retainer"},
				],
			},
			"fortnight": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["The corner of the envelope is soft. It has been in and out of a coat pocket about thirty times, and twice it has been somewhere with rain in it."],
				"choices": [
					{"label": "\"You've nearly not done this a lot of times.\"", "effects": {"kiez": 1.5, "flags": ["bley_nearly_didnt"]}, "next": "retainer"},
					{"label": "Take it without looking at it.", "effects": {"kiez": 1.0, "flags": ["bley_nearly_didnt"]}, "next": "retainer"},
				],
			},
			"retainer": {
				"speaker": "bley", "expression": "wary",
				"lines": ["A year of the Mieterverein retainer, paid, with no name on the transfer. Enough lawyer to read every rent letter on this street twice.", "\"You will not mention this. Not to the greengrocer, not to the loud one with the flyers, not to the nurse.\""],
				"choices": [
					{"label": "\"Nobody hears it from me.\"", "effects": {"kiez": 2.0, "flags": ["bley_patron"]}, "next": "why"},
					{"label": "[Brains 14] Ask what this does to him if it's traced.", "requires": {"stat": "int", "min": 14}, "effects": {"kiez": 1.5, "flags": ["bley_patron", "bley_exposure"]}, "next": "why"},
					{"label": "\"Keep your money. Just keep coming at three.\"", "effects": {"kiez": 1.5, "flags": ["bley_keeps_coming"]}, "next": "why"},
				],
			},
			"why": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["\"I am not repenting. I want that understood. The structure was tidy and it was legal and I would sign it again on the numbers I was given.\"", "\"I was not given the numbers that are standing in front of me at three in the morning. That is a different deficiency.\""],
				"choices": [
					{"label": "\"That's the audit, then.\"", "effects": {"kiez": 1.5, "flags": ["bley_did_the_list"]}, "next": "three"},
					{"label": "[Schnauze 13] \"Say why. Once. Then never again.\"", "check": {"stat": "cha", "dc": 13}, "effects_success": {"kiez": 2.5, "flags": ["bley_said_why"]}, "effects_fail": {"kiez": 0.5}, "next": "three", "next_fail": "three"},
					{"label": "\"Nobody asked you to repent.\"", "effects": {"kiez": 1.0}, "next": "three"},
				],
			},
			"three": {
				"speaker": "bley", "expression": "surprised",
				"lines": ["\"Because it is the only place I go where nobody wants anything from me,\" he says, at speed, in one piece, \"and it turns out that is because you people simply do not do that.\"", "He looks briefly appalled at himself. \"The water is the important item.\""],
				"choices": [
					{"label": "\"The water's the important item.\"", "effects": {"kiez": 2.0, "flags": ["bley_said_why"]}, "next": "chair"},
					{"label": "\"You people. Say you. It's four of us.\"", "effects": {"kiez": 1.5, "flags": ["bley_said_why", "bley_said_you"]}, "next": "chair"},
				],
			},
			"chair": {
				"speaker": "bley", "expression": "neutral",
				"lines": ["Jürgen's crate has a cushion on it now. Nobody has admitted to the cushion. It is not a good cushion and it is very clearly a deliberate one."],
				"choices": [
					{"label": "\"That's yours. Don't argue about it.\"", "effects": {"kiez": 2.0, "flags": ["bley_has_a_chair"]}, "next": "off"},
					{"label": "[Stamina 13] Open at three. Tomorrow and after.", "requires": {"stat": "con", "min": 13}, "effects": {"kiez": 2.5, "flags": ["bley_has_a_chair", "bley_night_watch"]}, "next": "off"},
					{"label": "\"Jürgen put it there. He'll deny it.\"", "effects": {"kiez": 1.5, "flags": ["bley_has_a_chair"]}, "next": "off"},
				],
			},
			"off": {
				"speaker": "bley", "expression": "tired",
				"lines": ["He pays cash, exact, does not want a bag, and leaves the chocolate on the counter — where, at 03:40, somebody else will find it."],
				"choices": [
					{"label": "\"Same time tomorrow, Rüdiger.\"", "effects": {"kiez": 1.0}, "next": ""},
				],
			},
		},
	},
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
