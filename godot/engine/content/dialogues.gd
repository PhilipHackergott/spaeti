extends RefCounted
## Branching conversation graphs (docs/06-dialogue-and-stats.md §3) — DATA ONLY, no logic.
##
## A guest walks up, you take them with `talk_next`, and this is what the two of you say. Three
## regulars have their own tree (5-8 nodes, two stat checks/gates each — that is the whole story
## budget for the slice); everyone else gets `oneoff`, whose single node substitutes `{want}` with
## the SKU they came in for.
##
## NODE   { speaker:String  (a character id, or "" = derive from whoever is at the counter),
##          expression:String ("neutral"|"warm"|"wary"|"upset" — drives the Portrait),
##          lines:Array[String], choices:Array[CHOICE] }
## CHOICE { label:String            — the stat tag is written INTO the label ("[Charisma 12] …"),
##                                    so the box needs no formatting rules of its own,
##          check:{stat,dc}         — a d20 + modifier roll on the state's seeded Rng (§2),
##          requires:{stat,min}     — a GATE: shown, but locked below `min`; no roll,
##          effects:{cash,kiez,profit,integrity,flags}  — the reducer's existing paths,
##          effects_success / effects_fail              — extra effects for a check's two branches,
##          next:String             — "" ends the conversation (the guest leaves),
##          next_fail:String        — where a failed check lands (defaults to `next`),
##          serve:bool              — false = they leave WITHOUT the auto-serve (you turned them away) }
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
				"lines": ["Mate, bitte. …And, ähm. I'm fifty cents short. Again."],
				"choices": [
					{"label": "\"On the house. Pay me Tuesday.\"", "effects": {"kiez": 1.0, "cash": -1.8}, "next": "thanks"},
					{"label": "[Charisma 12] \"Pay me in a sketch instead.\"", "check": {"stat": "cha", "dc": 12}, "next": "sketch", "next_fail": "no_sketch"},
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
					{"label": "[Wisdom 12] Actually look at her.", "check": {"stat": "wis", "dc": 12}, "next": "notice", "next_fail": "smalltalk"},
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
				"lines": ["A crate of Flaschen lands on the laminate, clinking like a small church.", "\"Automat has eaten them again. Forty-one bottles. I counted twice, Chef.\""],
				"choices": [
					{"label": "Count them out with him, one by one.", "effects": {"kiez": 1.0}, "next": "counted"},
					{"label": "[Strength 12] Carry the crate out back yourself.", "requires": {"stat": "str", "min": 12}, "effects": {"kiez": 1.5, "flags": ["juergen_crate"]}, "next": "lifted"},
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
					{"label": "[Wisdom 13] Notice how he said 'then home'.", "check": {"stat": "wis", "dc": 13}, "next": "cold_read", "next_fail": "feierabend"},
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
				"lines": ["Mehmet flattens a letter on the counter with the side of his hand, the way you flatten a receipt.", "\"Read this for me? My German is fine. Lawyer German is another language.\""],
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
					{"label": "[Intelligence 13] Work out what the numbers actually do.", "check": {"stat": "int", "dc": 13}, "next": "parsed", "next_fail": "lost"},
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
					{"label": "[Charisma 13] Talk him into knocking on every door tonight.", "check": {"stat": "cha", "dc": 13}, "next": "rally", "next_fail": "quiet"},
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
}
