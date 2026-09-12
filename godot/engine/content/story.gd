extends RefCounted
## Narrative content (Truby), ported 1:1 from app/src/engine/content/story.ts.
## The MAIN arc is a high-priority strand gated by day milestones; the side strands are recurring
## characters with branching beats → a local outcome → a per-main-ending epilogue (the tapestry,
## narrative-design.md §6b, §8 S1–S15).
##
## THE ONE DESIGN CHANGE vs the prototype (docs/05-engine-api.md §4): a beat no longer fires as morning
## text — it fires AT THE COUNTER. `character_id` + `archetype_id` (on the strand, overridable per beat)
## tell StoryFlow whose arrival to inject and how that person behaves while they stand there.
## `character_id`s that have no entry in characters.gd fall back to the archetype's one-off portrait.
## Optional beat/choice keys are read with .get(k, default): after_day, min_kiez, requires_flag /
## cash, kiez, profit, integrity, flags, outcome, next.

const DATA: Array[Dictionary] = [
	{
		"id": "main", "character": "Onkel Cem", "character_id": "you", "archetype_id": "regular",
		"start": "intro", "priority": 100, "epilogue": {},
		"beats": {
			"intro": {
				"id": "intro", "speaker": "—", "after_day": 1, "character_id": "you",
				"lines": ["You let yourself in with Cem's keys. The fridges hum. The Späti still smells of him.", "He left it to you. You never got to make peace."],
				"choices": [{"label": "Open up.", "next": "offer"}],
			},
			"offer": {
				"id": "offer", "speaker": "Frau Brandt", "after_day": 6, "character_id": "brandt",
				"lines": ["\"Lindner Group. We're acquiring the building.\" She slides a number across the counter.", "\"Generous, no? Think about it. These corners… they don't last.\""],
				"choices": [
					{"label": "\"I'll think about it.\"", "flags": ["heard_offer"], "next": "squeeze"},
					{"label": "\"It's not for sale.\"", "kiez": 2, "flags": ["refused_early"], "next": "squeeze"},
				],
			},
			"squeeze": {
				"id": "squeeze", "speaker": "Mehmet", "after_day": 13, "character_id": "mehmet",
				"lines": ["\"You saw? The chain Spätkauf opened down the block. And the rent letter came.\" Mehmet shakes his head.", "\"Cem never sold. Stubborn old goat. …Best man I knew.\""],
				"choices": [{"label": "Dig in.", "next": "climax"}],
			},
			"climax": {
				"id": "climax", "speaker": "Frau Brandt", "after_day": 22, "character_id": "brandt",
				"lines": ["\"Last chance. The number's even better now.\" Snow on the glass. The sign flickers.", "Cem's keys are warm in your pocket."],
				"choices": [
					{"label": "Sell, and walk away.", "outcome": "sell", "flags": ["sold"]},
					{"label": "Stand with the Kiez.", "outcome": "stand", "kiez": 5, "flags": ["stood"]},
				],
			},
		},
	},
	{
		"id": "lena", "character": "Lena", "character_id": "lena", "archetype_id": "student",
		"start": "l_meet", "priority": 10,
		"beats": {
			"l_meet": {
				"id": "l_meet", "speaker": "Lena", "after_day": 2,
				"lines": ["\"One Mate, bitte. …Ach, I'm fifty cents short. Tomorrow, promise?\""],
				"choices": [
					{"label": "\"On the house.\"", "kiez": 1, "flags": ["lena_kind"], "next": "l_credit"},
					{"label": "\"Sorry — exact change.\"", "next": "l_credit"},
				],
			},
			"l_credit": {
				"id": "l_credit", "speaker": "Lena", "after_day": 8,
				"lines": ["\"Big show coming up. Could I… run a tab? Just till it sells.\" Paint on her knuckles."],
				"choices": [
					{"label": "\"Pay me when you can.\"", "cash": -3, "kiez": 1, "flags": ["lena_credit"], "next": "l_show"},
					{"label": "\"Cash only, Lena.\"", "kiez": -1, "next": "l_show"},
				],
			},
			"l_show": {
				"id": "l_show", "speaker": "Lena", "after_day": 15,
				"lines": ["\"The gallery wants the 'marketable' one. But the true piece…\" She looks at you. \"What would you do?\""],
				"choices": [
					{"label": "\"Hang the one that's true.\"", "kiez": 1, "outcome": "found_voice"},
					{"label": "\"Paint what sells.\"", "outcome": "sold_out_art"},
				],
			},
		},
		"epilogue": {
			"institution": {"found_voice": "Lena's mural goes up inside the Späti — her first real audience.", "sold_out_art": "Lena's pieces sell downtown now; she still comes by for a Mate."},
			"held": {"found_voice": "Lena paints you a new sign for the door, on the house.", "sold_out_art": "Lena's busy with commissions, but she waves through the glass."},
			"soldout": {"found_voice": "Her best work hangs where the Späti used to be. She can't look at it.", "sold_out_art": "Lena cashed in too. You toast once, somewhere far from the Kiez."},
			"pushedout": {"found_voice": "She paints the boarded-up window — a memorial the whole street signs.", "sold_out_art": "Lena moved to Leipzig. Cheaper light, she says."},
		},
	},
	{
		"id": "juergen", "character": "\"Bottle\" Jürgen", "character_id": "juergen", "archetype_id": "regular",
		"start": "j_meet", "priority": 10,
		"beats": {
			"j_meet": {
				"id": "j_meet", "speaker": "\"Bottle\" Jürgen", "after_day": 3,
				"lines": ["An older man hovers at the door, a clinking bag over his shoulder, eyes down. He won't come in unless asked."],
				"choices": [
					{"label": "Wave him in; take his Pfand kindly.", "kiez": 1, "flags": ["j_welcome"], "next": "j_cold"},
					{"label": "Pretend not to see him.", "kiez": -1, "next": "j_cold"},
				],
			},
			"j_cold": {
				"id": "j_cold", "speaker": "—", "after_day": 12,
				"lines": ["The coldest night of the year. Jürgen never showed for his round."],
				"choices": [
					{"label": "Leave the light on and a coffee out.", "kiez": 1, "outcome": "seen"},
					{"label": "Not your problem.", "kiez": -1, "outcome": "vanished"},
				],
			},
		},
		"epilogue": {
			"institution": {"seen": "Jürgen is the Späti's night-watch now — knows every face on the block.", "vanished": "No one's seen Jürgen since the cold snap. The crate by the door stays empty."},
			"held": {"seen": "Jürgen still does his round; you still leave the crate out.", "vanished": "Someone else collects the bottles now. You don't ask who."},
			"soldout": {"seen": "You leave Jürgen the keys to nothing. He nods, understanding.", "vanished": "He was already gone before the sign came down."},
			"pushedout": {"seen": "On the last night Jürgen brings back every bottle — and a thermos, for you.", "vanished": "The corner empties. Jürgen drifts to the next lit door."},
		},
	},
	{
		"id": "mehmet", "character": "Mehmet", "character_id": "mehmet", "archetype_id": "regular",
		"start": "m_meet", "priority": 20,
		"beats": {
			"m_meet": {
				"id": "m_meet", "speaker": "Mehmet", "after_day": 2,
				"lines": ["The döner man from next door studies you over the counter. \"So. Cem's kid. You here to run it — or sell it?\""],
				"choices": [{"label": "\"I want to do right by him.\"", "kiez": 1, "flags": ["m_trust"], "next": "m_word"}],
			},
			"m_word": {
				"id": "m_word", "speaker": "Mehmet", "after_day": 16,
				"lines": ["\"I've watched you these weeks.\" A long pause. \"Cem fed people who couldn't pay. Is that still what this corner is — or just a till?\""],
				"choices": [
					{"label": "\"You're right. I lost the plot.\"", "integrity": 5, "kiez": 2, "outcome": "reconciled"},
					{"label": "\"I do what I have to.\"", "outcome": "estranged"},
				],
			},
		},
		"epilogue": {
			"institution": {"reconciled": "Mehmet caters the street party. \"Cem would've liked you,\" he says.", "estranged": "Mehmet nods at you across the street. Just nods."},
			"held": {"reconciled": "You and Mehmet trade staff and stories; the block holds together.", "estranged": "Mehmet keeps to his shop. The friendship Cem left you went unspent."},
			"soldout": {"reconciled": "Mehmet doesn't say goodbye — just turns his sign off early that night.", "estranged": "Mehmet saw it coming. He always did."},
			"pushedout": {"reconciled": "Mehmet helps you carry the last boxes out. Neither of you speaks.", "estranged": "Mehmet's döner outlasts you by a month. Then it's gone too."},
		},
	},
	{
		"id": "yusuf", "character": "Yusuf", "character_id": "yusuf", "archetype_id": "kid",
		"start": "y_meet", "priority": 10,
		"beats": {
			"y_meet": {
				"id": "y_meet", "speaker": "Yusuf", "after_day": 4,
				"lines": ["A skinny kid, fourteen maybe, freezes with a chocolate bar half up his sleeve. He doesn't run. He just stares at the floor."],
				"choices": [
					{"label": "\"Put it back. Sit down. You hungry?\"", "kiez": 1, "integrity": 1, "flags": ["y_grace"], "next": "y_job"},
					{"label": "\"Pay or get out — and don't come back.\"", "kiez": -1, "next": "y_job"},
				],
			},
			"y_job": {
				"id": "y_job", "speaker": "Yusuf", "after_day": 13,
				"lines": ["He's hovered by the fridges every night since. \"My mum works doubles. I could… stack shelves? For real money?\" He won't meet your eye."],
				"choices": [
					{"label": "Give him evening shifts. Teach him the till.", "kiez": 1, "integrity": 1, "outcome": "mentored"},
					{"label": "\"I can barely pay myself, kid.\"", "kiez": -1, "outcome": "adrift"},
				],
			},
		},
		"epilogue": {
			"institution": {"mentored": "Yusuf runs the late shift now; half the block's teenagers do homework at the bench.", "adrift": "Yusuf found another corner to stand on. Word is he's in with the wrong crew."},
			"held": {"mentored": "Yusuf still works his shifts — first in his family with a payslip.", "adrift": "Yusuf drifts past sometimes, older than he should look. He doesn't come in."},
			"soldout": {"mentored": "You wrote Yusuf a reference before you left. He keeps it folded in his wallet.", "adrift": "You never learned what became of the kid. You tell yourself it wasn't your job."},
			"pushedout": {"mentored": "On the last night Yusuf mops up unasked, then pockets the keys you no longer need.", "adrift": "The corner that might have held him is boarded shut. He doesn't look up as he passes."},
		},
	},
	{
		"id": "schmidt", "character": "Frau Schmidt", "character_id": "schmidt", "archetype_id": "regular",
		"start": "s_meet", "priority": 15,
		"beats": {
			"s_meet": {
				"id": "s_meet", "speaker": "Frau Schmidt", "after_day": 3,
				"lines": ["She buys one bread roll and stays twenty minutes. \"Forty years on this street. My Walter and I had our first coffee where the chain stands now.\" She pats the counter."],
				"choices": [
					{"label": "Pour her a coffee. Let her talk.", "cash": -1, "kiez": 1, "next": "s_fall"},
					{"label": "Smile, ring up the roll, keep moving.", "next": "s_fall"},
				],
			},
			"s_fall": {
				"id": "s_fall", "speaker": "Mehmet", "after_day": 15, "character_id": "mehmet",
				"lines": ["\"Frau Schmidt had a fall. Lay there a whole day — nobody noticed.\" Mehmet lowers his voice. \"She asks after your Späti, you know. It's her one outing.\""],
				"choices": [
					{"label": "Rally the regulars to look in on her; deliver her rolls.", "kiez": 2, "integrity": 1, "outcome": "watched_over"},
					{"label": "\"That's what family is for. Not me.\"", "kiez": -1, "outcome": "forgotten"},
				],
			},
		},
		"epilogue": {
			"institution": {"watched_over": "Frau Schmidt holds court at the bench every afternoon. The Späti is her living room now.", "forgotten": "Frau Schmidt stopped coming. The chain won't make coffee for one roll."},
			"held": {"watched_over": "A rota of regulars checks on Frau Schmidt. She knits you a scarf — badly, with love.", "forgotten": "You heard Frau Schmidt moved to a niece in Spandau. You never asked to be sure."},
			"soldout": {"watched_over": "You left Frau Schmidt the rota's number. She still asks the new owners where you went.", "forgotten": "Frau Schmidt watched the sign come down from her window. One more thing, gone."},
			"pushedout": {"watched_over": "On the last day Frau Schmidt brings you Walter's old thermos. \"He'd have liked you,\" she says.", "forgotten": "The street empties of the old faces. Frau Schmidt's window goes dark not long after yours."},
		},
	},
	{
		"id": "aylinjonas", "character": "Aylin & Jonas", "character_id": "aylinjonas", "archetype_id": "raver",
		"start": "aj_meet", "priority": 5,
		"beats": {
			"aj_meet": {
				"id": "aj_meet", "speaker": "Aylin & Jonas", "after_day": 4,
				"lines": ["Glitter, big coats, Sunday-morning glow. \"Two Mate, two Pilsner — letztes Bier before bed.\" They lean on each other, laughing at nothing."],
				"choices": [
					{"label": "Ring it up; share the joke.", "kiez": 1, "next": "aj_turn"},
					{"label": "\"Long night?\" Keep it brief.", "next": "aj_turn"},
				],
			},
			"aj_turn": {
				"id": "aj_turn", "speaker": "Aylin", "after_day": 17,
				"lines": ["Aylin's alone tonight, no glow. \"Jonas got a job. Munich. He says come, I say the weekends are here…\"", "She turns the Mate in her hands. \"Were we ever really us, or just the Sundays?\""],
				"choices": [
					{"label": "\"The magic was each other. Go find out.\"", "kiez": 1, "integrity": 1, "outcome": "together"},
					{"label": "\"Only you know that, Aylin.\"", "outcome": "drifted"},
				],
			},
		},
		"epilogue": {
			"institution": {"together": "Aylin & Jonas come by at 8pm now, not 8am — and bring the baby to the bench.", "drifted": "Aylin still comes alone on Sundays, lingering by the window where they used to stand."},
			"held": {"together": "They took the flat above the corner. The Sundays turned into a life.", "drifted": "Jonas went to Munich. Aylin sends him photos of the old corner sometimes."},
			"soldout": {"together": "They found their forever somewhere with cheaper rent — and named the corner in the toast.", "drifted": "The Sundays ended when the bench did. Aylin doesn't dance much anymore."},
			"pushedout": {"together": "On the last Sunday they bring a speaker and the whole corner dances the place out.", "drifted": "Aylin heard the Späti closed from three cities away. So did the magic, she thinks."},
		},
	},
	{
		"id": "karim", "character": "Karim", "character_id": "karim", "archetype_id": "regular",
		"start": "k_meet", "priority": 6,
		"beats": {
			"k_meet": {
				"id": "k_meet", "speaker": "Karim", "after_day": 5,
				"lines": ["He rehearses the words before he says them. \"One… telephone card, bitte. And — entschuldigung — this word, is correct?\" He shows a form, a hand not quite steady."],
				"choices": [
					{"label": "Help with the form. Slow German, no rush.", "kiez": 1, "integrity": 1, "flags": ["karim_kind"], "next": "k_battle"},
					{"label": "Sell the card; point him to an office.", "next": "k_battle"},
				],
			},
			"k_battle": {
				"id": "k_battle", "speaker": "Karim", "after_day": 16,
				"lines": ["He's shaking. \"A man outside told me to go back. In front of everyone.\"", "A breath. \"The Behörde letter came also. I think maybe this city does not want me.\""],
				"choices": [
					{"label": "\"This corner wants you. You have people here.\"", "kiez": 2, "integrity": 1, "outcome": "belongs"},
					{"label": "\"It gets easier. Probably.\" Ring him up.", "outcome": "isolated"},
				],
			},
		},
		"epilogue": {
			"institution": {"belongs": "Karim brings his mother's cooking to the street party; half the Kiez asks for the recipe.", "isolated": "Karim got his papers and moved to where he already knew someone. He waves if he's ever back."},
			"held": {"belongs": "Karim's German is sharp now; he translates for the next newcomer at your counter.", "isolated": "Karim kept to himself, then one month stopped coming. You hope he's alright."},
			"soldout": {"belongs": "You wrote Karim a reference for his lease. The corner that anchored him is gone now.", "isolated": "The one place Karim almost belonged sold up. He starts over, again, alone."},
			"pushedout": {"belongs": "Karim helps carry the boxes and won't take money for it. \"You helped me,\" is all he says.", "isolated": "Another door closes in a cold city. Karim doesn't look surprised."},
		},
	},
	{
		"id": "achim", "character": "Achim", "character_id": "achim", "archetype_id": "insomniac",
		"start": "a_meet", "priority": 5,
		"beats": {
			"a_meet": {
				"id": "a_meet", "speaker": "Achim", "after_day": 6,
				"lines": ["Leather vest, grey mohawk, a Sterni at 2pm. \"This whole Kiez sold out. You're next, probably.\" He says it like a test, not an insult."],
				"choices": [
					{"label": "\"Maybe. Tell me how it was, then.\"", "kiez": 1, "flags": ["achim_listen"], "next": "a_battle"},
					{"label": "\"It's a business, Achim.\"", "kiez": -1, "next": "a_battle"},
				],
			},
			"a_battle": {
				"id": "a_battle", "speaker": "Achim", "after_day": 19,
				"lines": ["\"They're turning my old squat into lofts. Lofts.\" He laughs, hollow. \"Forty years I fought this — to watch from a Späti?\""],
				"choices": [
					{"label": "\"Then help me fight for this corner. Last stand.\"", "kiez": 2, "integrity": 1, "outcome": "elder_agitator"},
					{"label": "\"Nothing lasts, Achim. You know that.\"", "outcome": "fossil"},
				],
			},
		},
		"epilogue": {
			"institution": {"elder_agitator": "Achim runs the Kiezversammlung like a gig — the old fire, useful at last.", "fossil": "Achim drinks his Sterni and watches the loft lights. The fight went out of him."},
			"held": {"elder_agitator": "Achim papers the block with your flyers; the chain can't stand him. Good.", "fossil": "Achim comes by less. The city he fought for keeps not existing."},
			"soldout": {"elder_agitator": "Achim never forgave you for selling. He was right to be angry, and you know it.", "fossil": "Achim raises one last bitter toast: \"Told you.\" Then he's gone too."},
			"pushedout": {"elder_agitator": "Achim chains himself to the shutter on the last day. They carry him off grinning.", "fossil": "One more squat, one more Späti. Achim stops counting the losses out loud."},
		},
	},
	{
		"id": "tobias", "character": "Tobias", "character_id": "tobias", "archetype_id": "tourist",
		"start": "t_meet", "priority": 8,
		"beats": {
			"t_meet": {
				"id": "t_meet", "speaker": "Tobias", "after_day": 5,
				"lines": ["Crisp jacket, warm smile, leaves the change. \"Man, I LOVE this place. So authentic. You should do a natural-wine night — I know people. This corner could be a destination.\""],
				"choices": [
					{"label": "\"It's already somewhere. To us.\"", "kiez": 1, "flags": ["tobias_warn"], "next": "t_choice"},
					{"label": "\"Tell me more.\" Take the big tip.", "profit": 1, "next": "t_choice"},
				],
			},
			"t_choice": {
				"id": "t_choice", "speaker": "Tobias", "after_day": 18,
				"lines": ["Quieter tonight. \"My startup's leasing the whole block — with the Lindner people. I didn't connect it to here. To you.\"", "He looks sick about it. \"I could sign. Or I could not.\""],
				"choices": [
					{"label": "\"Belonging isn't bought, Tobias. Choose us.\"", "kiez": 1, "integrity": 1, "outcome": "threw_in"},
					{"label": "\"Do what you came here to do.\"", "kiez": -1, "outcome": "moved_on"},
				],
			},
		},
		"epilogue": {
			"institution": {"threw_in": "Tobias bankrolls the bench and learns to just… sit on it. He earned the corner.", "moved_on": "Tobias found a newer \"authentic\" Kiez to love to death. Somewhere is bracing for him."},
			"held": {"threw_in": "Tobias pulled his startup out of the deal. It cost him. He stayed anyway.", "moved_on": "Tobias still tips big at the chain. He tells people he used to know the real owner."},
			"soldout": {"threw_in": "Tobias begged you not to sell — the one transplant who meant it, and you didn't listen.", "moved_on": "Tobias got his destination. It has your old address and none of your corner."},
			"pushedout": {"threw_in": "Tobias quietly covered a month's rent; it only delayed it. He cried at the end. So did you.", "moved_on": "Tobias posted a fond goodbye to the \"OG spot.\" He'd already signed the lease."},
		},
	},
	{
		"id": "nadia", "character": "Nadia", "character_id": "nadia", "archetype_id": "nurse",
		"start": "n_meet", "priority": 6,
		"beats": {
			"n_meet": {
				"id": "n_meet", "speaker": "Nadia", "after_day": 4,
				"lines": ["Scrubs under her coat, 4am eyes. \"Coffee, strongest you've got, and a Schrippe for the kid's breakfast.\" She's already half out the door."],
				"choices": [
					{"label": "Make it a good one. \"Long shift?\"", "kiez": 1, "next": "n_battle"},
					{"label": "Ring it up fast — she's in a hurry.", "next": "n_battle"},
				],
			},
			"n_battle": {
				"id": "n_battle", "speaker": "Nadia", "after_day": 15,
				"lines": ["On the phone, voice cracking. \"Childcare fell through and I'm due on ward in twenty—\"", "She catches your eye, mortified to be seen needing anything."],
				"choices": [
					{"label": "\"The kid waits here with me. Go. Go!\"", "kiez": 2, "integrity": 1, "outcome": "held"},
					{"label": "\"That's rough. Hope it works out.\"", "outcome": "burned_out"},
				],
			},
		},
		"epilogue": {
			"institution": {"held": "Nadia's kid does homework behind the counter on late shifts. The corner raised another one.", "burned_out": "Nadia transferred to a day clinic with less night. She deserved easier."},
			"held": {"held": "The corner minds Nadia's kid sometimes; she finally believes she can ask.", "burned_out": "Nadia ran on empty until she left the city for family. The web wasn't there yet."},
			"soldout": {"held": "You left Nadia the rota's numbers. The 4am coffee is a vending machine now.", "burned_out": "No one caught Nadia when she fell. She remembers the corner was almost that place."},
			"pushedout": {"held": "Nadia rallies the regulars for a 4am farewell — her whole night shift, clapping.", "burned_out": "The one warm light on her commute went dark. She drinks machine coffee and drives on."},
		},
	},
	{
		"id": "robin", "character": "Robin", "character_id": "robin", "archetype_id": "student",
		"start": "r_meet", "priority": 5,
		"beats": {
			"r_meet": {
				"id": "r_meet", "speaker": "Robin", "after_day": 7,
				"lines": ["Hovers by the magazines, watching the door more than the shelf — buys a single Mate just to have a reason to stand in the warm light a while longer."],
				"choices": [
					{"label": "\"Stay as long as you like. It's cold out.\"", "kiez": 1, "flags": ["robin_safe"], "next": "r_battle"},
					{"label": "Ring up the Mate; leave them be.", "next": "r_battle"},
				],
			},
			"r_battle": {
				"id": "r_battle", "speaker": "Robin", "after_day": 18,
				"lines": ["Eyes red. \"Called home. Mum still uses my old name. Says I can come back when I'm 'normal'.\"", "A shaky laugh. \"Berlin was supposed to be the easy part.\""],
				"choices": [
					{"label": "\"Your people are out there — some of them are right here.\"", "kiez": 2, "integrity": 1, "outcome": "chosen_family"},
					{"label": "\"Family's complicated. You'll figure it out.\"", "outcome": "fled"},
				],
			},
		},
		"epilogue": {
			"institution": {"chosen_family": "Robin brings their whole chosen crew to the Späti; it's the safest light on the street.", "fled": "Robin found their people eventually — somewhere that didn't remind them of the hard nights."},
			"held": {"chosen_family": "Robin works the odd shift and mother-hens every new kid who hovers by the door.", "fled": "Robin moved on before they found their footing here. You hope the next corner was kinder."},
			"soldout": {"chosen_family": "You gave Robin a key to nowhere, in the end — but they got the message, and the love.", "fled": "The one safe light Robin found in Berlin blinked out. They keep moving."},
			"pushedout": {"chosen_family": "Robin and their crew paint the boarded window into something beautiful and defiant.", "fled": "Another door that might have been home, closed. Robin is good at leaving by now."},
		},
	},
	{
		"id": "schulz", "character": "Frau Schulz", "character_id": "schulz", "archetype_id": "regular",
		"start": "sc_meet", "priority": 7,
		"beats": {
			"sc_meet": {
				"id": "sc_meet", "speaker": "Frau Schulz", "after_day": 6,
				"lines": ["Sharp eyes, sharper tongue. \"In the GDR this corner had a different name and better Brötchen. You young ones don't know what stood here.\" She watches to see if you flinch."],
				"choices": [
					{"label": "\"Then tell me. I want to know.\"", "kiez": 1, "flags": ["schulz_listen"], "next": "sc_battle"},
					{"label": "\"Times change, Frau Schulz.\"", "kiez": -1, "next": "sc_battle"},
				],
			},
			"sc_battle": {
				"id": "sc_battle", "speaker": "Frau Schulz", "after_day": 17,
				"lines": ["\"They tore down the old Konsum today. Forty years I bought bread there.\" Her voice doesn't shake; that's worse.", "\"Soon no one will remember it stood at all.\""],
				"choices": [
					{"label": "\"I'll remember. Write your prices in your old hand.\"", "kiez": 2, "integrity": 1, "outcome": "living_history"},
					{"label": "\"Nothing we can do about it.\" Ring her up.", "outcome": "forgotten"},
				],
			},
		},
		"epilogue": {
			"institution": {"living_history": "Frau Schulz's stories run painted along the Späti wall; school groups come to hear her.", "forgotten": "Frau Schulz stopped telling the stories. When she goes, the corner's memory goes with her."},
			"held": {"living_history": "Frau Schulz holds court at the counter; the young ones actually listen now.", "forgotten": "Frau Schulz keeps her stories to herself. The new Kiez never asks."},
			"soldout": {"living_history": "You sold the corner she trusted to remember. She doesn't say it; her eyes do.", "forgotten": "Another piece of her city, gone. Frau Schulz has stopped being surprised."},
			"pushedout": {"living_history": "Frau Schulz notes the closing date in her old GDR hand. \"So that it is remembered.\"", "forgotten": "The last witness to what stood here watches the shutter come down, and says nothing."},
		},
	},
]
