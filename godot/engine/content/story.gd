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
			# SEVEN BEATS, one per Truby step (docs/09 §2.1): summer 1-2 · autumn 3-4 · winter 5-6 ·
			# spring 7, and a strand's current beat IS its current arc step (docs/06 §8.4). Every beat
			# from step 2 on carries a `requires_flag` naming a flag that EVERY choice of the beat
			# before it sets — so each step literally reads the step before it, and the chain can
			# never stall on a branch the player did not take. Those gate flags are kind-1 readers and
			# therefore have NO `FLAG_READERS` row; the colour flags beside them do.
			"l_meet": {
				"id": "l_meet", "speaker": "Lena", "after_day": 2,
				"lines": ["\"One Mate, bitte. …Ach, I'm fifty cents short. Tomorrow, promise?\""],
				"choices": [
					{"label": "\"On the house.\"", "kiez": 1, "flags": ["lena_kind", "lena_tab_open"], "next": "l_honest"},
					{"label": "\"Sorry — exact change.\"", "flags": ["lena_tab_open"], "next": "l_honest"},
				],
			},
			"l_honest": {
				"id": "l_honest", "speaker": "Lena", "after_day": 5, "requires_flag": "lena_tab_open",
				"lines": ["The portfolio comes out flat on the laminate, turned to face you. Not the clean ones — a kitchen at four in the morning, painted from the inside.", "\"You can't hang that in a shop,\" she says, like an argument she is hoping to lose."],
				"choices": [
					{"label": "\"That one. Not the pretty ones. That one.\"", "kiez": 2, "flags": ["lena_saw_work", "lena_honest_piece"], "next": "l_gallerist"},
					{"label": "Look at it properly. Say nothing yet.", "kiez": 1, "flags": ["lena_saw_work"], "next": "l_gallerist"},
				],
			},
			"l_gallerist": {
				"id": "l_gallerist", "speaker": "Lena", "after_day": 9, "requires_flag": "lena_saw_work",
				"lines": ["\"A man came to the studio. A gallery, in Mitte, a room with a window.\" She says it fast, the way she says the things that matter.", "\"He wants eight of the flowers. The pretty ones. He did not look at the kitchen at all.\""],
				"choices": [
					{"label": "\"Then hang the kitchen too. Nine, not eight.\"", "kiez": 1, "flags": ["lena_gallerist", "lena_kept_faith"], "next": "l_credit"},
					{"label": "\"Eight flowers is a room in Mitte. Paint them.\"", "flags": ["lena_gallerist", "lena_made_it_sellable"], "next": "l_credit"},
				],
			},
			"l_credit": {
				"id": "l_credit", "speaker": "Lena", "after_day": 12, "requires_flag": "lena_gallerist",
				"lines": ["Three nights with no Schrippe, and the tab on the fridge door is on its eleventh line. The studio radiator died in 1994 and nobody has been to look at it since.", "\"Could I… run it until March? Just till the show sells.\" Paint on her knuckles, and nothing eaten since Sunday."],
				"choices": [
					{"label": "\"Until March. And you eat here, at zero.\"", "cash": -3, "kiez": 1, "flags": ["lena_credit", "lena_studio_nights", "lena_fed"], "next": "l_show"},
					{"label": "\"Cash only, Lena.\"", "kiez": -1, "flags": ["lena_studio_nights"], "next": "l_show"},
				],
			},
			"l_show": {
				"id": "l_show", "speaker": "Lena", "after_day": 16, "requires_flag": "lena_studio_nights",
				"lines": ["\"The gallery wants the 'marketable' one. But the true piece…\" She looks at you. \"What would you do?\""],
				"choices": [
					{"label": "\"Hang the one that's true.\"", "kiez": 1, "flags": ["lena_show_done"], "outcome": "found_voice", "next": "l_help"},
					{"label": "\"Paint what sells.\"", "flags": ["lena_show_done"], "outcome": "sold_out_art", "next": "l_help"},
				],
			},
			"l_help": {
				"id": "l_help", "speaker": "Lena", "after_day": 19, "requires_flag": "lena_show_done",
				"lines": ["02:10, no portfolio, both hands flat on the laminate. \"I need to eat here. For a while.\"", "\"I'm not asking for money. I'm asking for the thing you already do, out loud, which is worse.\""],
				"choices": [
					{"label": "\"Every night. Come at two, it's quiet.\"", "kiez": 2, "integrity": 1, "flags": ["lena_let_in", "lena_fed"], "next": "l_wall"},
					{"label": "\"Asking out loud is the whole job.\"", "kiez": 1, "flags": ["lena_let_in"], "next": "l_wall"},
				],
			},
			"l_wall": {
				"id": "l_wall", "speaker": "Lena", "after_day": 23, "requires_flag": "lena_let_in",
				"lines": ["April, a borrowed stepladder, and a sheet of paper with your long wall on it to scale — socket marked, crates drawn in pencil where they actually stand.", "\"Three metres forty. It comes off nothing; there's nothing on the door any more. It's just what I want to paint.\""],
				"choices": [
					{"label": "\"Then paint it. I'll move the crates on Sunday.\"", "kiez": 2, "flags": ["lena_mural"], "outcome": "found_voice"},
					{"label": "\"Put it in the window where it sells things.\"", "flags": ["lena_mural"], "outcome": "sold_out_art"},
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
			# SEVEN BEATS, one per Truby step (docs/09 §2.2). `j_cold` keeps its id, its two outcomes
			# and its title — "The Night He Doesn't Come" — but it now has him walking in at 04:20 on
			# the third night, because a beat is staged AT THE COUNTER (docs/05 §4) and an absence
			# cannot be played by the person who is absent.
			"j_meet": {
				"id": "j_meet", "speaker": "\"Bottle\" Jürgen", "after_day": 3,
				"lines": ["An older man hovers at the door, a clinking bag over his shoulder, eyes down. He won't come in unless asked.", "\"Forty-one bottles, Chef. I counted twice.\""],
				"choices": [
					{"label": "Wave him in; take his Pfand kindly.", "kiez": 1, "flags": ["j_welcome", "juergen_counted"], "next": "j_crate"},
					{"label": "Pretend not to see him.", "kiez": -1, "flags": ["juergen_counted"], "next": "j_crate"},
				],
			},
			"j_crate": {
				"id": "j_crate", "speaker": "\"Bottle\" Jürgen", "after_day": 6, "requires_flag": "juergen_counted",
				"lines": ["The handle went on the crate he has used for three years. \"It was a crate, Chef, not a marriage.\"", "There is a Pfand crate inside your door with four bottles in it, and it has been in there all night where nobody could reach it but you."],
				"choices": [
					{"label": "\"That one lives on the step from now on.\"", "kiez": 2, "flags": ["juergen_crate_out", "juergen_crate"], "next": "j_bins"},
					{"label": "Hand him the four bottles over the counter.", "flags": ["juergen_crate_out"], "next": "j_bins"},
				],
			},
			"j_bins": {
				"id": "j_bins", "speaker": "\"Bottle\" Jürgen", "after_day": 9, "requires_flag": "juergen_crate_out",
				"lines": ["Eleven bottles. He counted twice and it is still eleven. The chain Spätkauf opened on Monday and put a padlock through both wheelie bins on Tuesday.", "\"It is their Hof. I am not complaining, Chef, I am telling you the route.\""],
				"choices": [
					{"label": "\"Four doors on this street have bins. I'll knock.\"", "kiez": 1, "flags": ["juergen_route_cut", "juergen_chain"], "next": "j_jacket"},
					{"label": "\"The arches and the park will have to do it.\"", "flags": ["juergen_route_cut"], "next": "j_jacket"},
				],
			},
			"j_jacket": {
				"id": "j_jacket", "speaker": "\"Bottle\" Jürgen", "after_day": 13, "requires_flag": "juergen_route_cut",
				"lines": ["Minus two and a wind off the water. He cannot get the coins apart on the laminate and does it one at a time with a thumbnail.", "The jacket is the same jacket. It was a good jacket in 1994 and it is a windbreaker now. \"It is October. It is supposed to be cold.\""],
				"choices": [
					{"label": "Cem's coat, off the hook. \"Call it storage.\"", "kiez": 2, "flags": ["juergen_cold_read", "juergen_warm"], "next": "j_cold"},
					{"label": "\"Frost Thursday, then. Noted.\"", "flags": ["juergen_cold_read"], "next": "j_cold"},
				],
			},
			"j_cold": {
				"id": "j_cold", "speaker": "—", "after_day": 16, "requires_flag": "juergen_cold_read",
				"lines": ["The coldest night of the year came and went, and the crate on the step stayed full to the lip. Two nights. No Jürgen.", "At 04:20 on the third the bell goes and he is in the doorway with one bag, no crate, and a cough that is coming from somewhere lower than a throat."],
				"choices": [
					{"label": "Coffee in his hands before he asks. Sit him down.", "kiez": 1, "cash": -1, "flags": ["juergen_came_back", "juergen_warm"], "outcome": "seen", "next": "j_seen"},
					{"label": "\"Six bottles is sixty cents, Jürgen.\"", "kiez": -1, "flags": ["juergen_came_back"], "outcome": "vanished", "next": "j_seen"},
				],
			},
			"j_seen": {
				"id": "j_seen", "speaker": "\"Bottle\" Jürgen", "after_day": 20, "requires_flag": "juergen_came_back",
				"lines": ["He is on the bench inside the door at half past one with the crate at his feet. He has been there forty minutes and nobody has asked him anything.", "\"The one with the dog calls me Herr Massek,\" he says. \"I have not corrected her.\""],
				"choices": [
					{"label": "\"Nobody's going to correct her.\"", "kiez": 2, "flags": ["juergen_bench_his", "juergen_bench"], "outcome": "seen", "next": "j_watch"},
					{"label": "\"Five twenty. Anything else?\"", "flags": ["juergen_bench_his"], "next": "j_watch"},
				],
			},
			"j_watch": {
				"id": "j_watch", "speaker": "\"Bottle\" Jürgen", "after_day": 23, "requires_flag": "juergen_bench_his",
				"lines": ["April, ten minutes early. \"It rains at two. Not before. The app says eleven; the app does not know about the cut at the Ringbahn.\"", "\"And two men in a Kombi photographed the doorways on Tuesday at 03:40. Brandenburg plates. Your house number was on the top sheet of the clipboard.\""],
				"choices": [
					{"label": "\"A Schrippe, a Sterni and the pack. Off the bill.\"", "kiez": 2, "cash": -2, "flags": ["juergen_wage", "juergen_watch"], "outcome": "seen"},
					{"label": "\"Noted. Bis später, Jürgen.\"", "flags": ["juergen_watch"], "outcome": "seen"},
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
			# SEVEN BEATS, one per Truby step (docs/09 §2.3). `m_word` keeps its id, its two outcomes
			# and the reader `m_trust` was always declared against — it is step 6, "Legacy Is People".
			"m_meet": {
				"id": "m_meet", "speaker": "Mehmet", "after_day": 2,
				"lines": ["The greengrocer from two doors down studies you over the counter. \"So. Cem's kid. You here to run it — or sell it?\"", "A letter goes down on the laminate, flattened with the side of his hand. \"And read this for me. My German is fine. Lawyer German is another language.\""],
				"choices": [
					{"label": "\"I want to do right by him.\" Then read the letter.", "kiez": 1, "flags": ["m_trust", "mehmet_letter"], "next": "m_cem"},
					{"label": "\"Take it to the Mieterverein, Mehmet.\"", "flags": ["mehmet_letter"], "next": "m_cem"},
				],
			},
			"m_cem": {
				"id": "m_cem", "speaker": "Mehmet", "after_day": 6, "requires_flag": "mehmet_letter",
				"lines": ["\"Your uncle and I argued about football for thirty years and not one word about anything that mattered. Then he is dead on a Tuesday and I hear it at the Bäckerei.\"", "\"A letter like this, Cem would have made a week of it. By Friday there are forty people in a courtyard eating my tomatoes and nobody has signed anything.\""],
				"choices": [
					{"label": "\"Then we've got until Friday.\"", "kiez": 1, "flags": ["mehmet_cem_week", "mehmet_cem_story"], "next": "m_eleven"},
					{"label": "\"He's not an instruction manual, Mehmet.\"", "flags": ["mehmet_cem_week"], "next": "m_eleven"},
				],
			},
			"m_eleven": {
				"id": "m_eleven", "speaker": "Mehmet", "after_day": 10, "requires_flag": "mehmet_cem_week",
				"lines": ["The Mieterverein has written back. Page three is a table: the Umlage is capped at eight percent a year, with a ceiling per square metre on top.", "\"Their letter says eleven. And it puts the ceiling on the wrong number. Nobody makes that mistake twice on one page.\""],
				"choices": [
					{"label": "\"Photograph every page. Somebody chose eleven.\"", "kiez": 2, "flags": ["mehmet_umlage", "mehmet_evidence"], "next": "m_doors"},
					{"label": "\"Pay nothing until the Mieterverein has it.\"", "kiez": 1, "flags": ["mehmet_umlage"], "next": "m_doors"},
				],
			},
			"m_doors": {
				"id": "m_doors", "speaker": "Mehmet", "after_day": 13, "requires_flag": "mehmet_umlage",
				"lines": ["A sheet of squared paper with eleven flats on it, four of them ticked, and two of the four are his own family.", "\"Nobody wants to be first. First is the name on the letter when the lawyer writes back — and my name is over my door in letters half a metre high.\""],
				"choices": [
					{"label": "\"Then I'll be first. My name goes on it.\"", "kiez": 2, "flags": ["mehmet_doors_done", "mehmet_asked"], "next": "m_becoming"},
					{"label": "\"Your Haus, your letter. Mine's a shop lease.\"", "kiez": -1, "flags": ["mehmet_doors_done"], "next": "m_becoming"},
				],
			},
			"m_becoming": {
				"id": "m_becoming", "speaker": "Mehmet", "after_day": 17, "requires_flag": "mehmet_doors_done",
				"lines": ["\"On Saturday the boy from the front building bought a lighter here and you charged him two euro, because he had a card out and he did not look.\"", "\"I watched you through my own window, my friend, and I did not know the face you were making.\""],
				"choices": [
					{"label": "\"That was wrong. Two euro, and it was wrong.\"", "kiez": 1, "integrity": 3, "flags": ["mehmet_mirror"], "next": "m_word"},
					{"label": "\"He didn't look. That's a business, Mehmet.\"", "kiez": -1, "flags": ["mehmet_mirror", "mehmet_priced_them"], "next": "m_word"},
				],
			},
			"m_word": {
				"id": "m_word", "speaker": "Mehmet", "after_day": 20, "requires_flag": "mehmet_mirror",
				"lines": ["\"I've watched you these weeks.\" A long pause. \"Cem fed people who couldn't pay. Is that still what this corner is — or just a till?\""],
				"choices": [
					{"label": "\"You're right. I lost the plot.\"", "integrity": 5, "kiez": 2, "flags": ["mehmet_legacy"], "outcome": "reconciled", "next": "m_deniz"},
					{"label": "\"I do what I have to.\"", "flags": ["mehmet_legacy"], "outcome": "estranged", "next": "m_deniz"},
				],
			},
			"m_deniz": {
				"id": "m_deniz", "speaker": "Mehmet", "after_day": 24, "requires_flag": "mehmet_legacy",
				"lines": ["Half past six, an hour before the Kiezversammlung, and he is carrying four chairs and cannot open your door with them. \"He is not coming. Munich. A thing on Thursday that could not be moved.\"", "He checks the phone three times while he says it, and turns it face down afterwards as though it had been rude to him."],
				"choices": [
					{"label": "\"Ring him back. Once. From my counter.\"", "kiez": 2, "flags": ["mehmet_deniz_came", "mehmet_stood"], "outcome": "reconciled"},
					{"label": "Take two chairs off him and say nothing about Munich.", "kiez": 1, "flags": ["mehmet_stood"], "outcome": "reconciled"},
					{"label": "\"Munich. Right. Of course.\"", "kiez": -1, "outcome": "estranged"},
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
		"id": "aylinjonas", "character": "Aylin", "character_id": "aylin", "archetype_id": "raver",
		# STAGING (docs/09 §2.10): two people cannot share one 160×193 leaning bust without shrinking
		# both faces or cropping one to a shoulder, so S4 is HER arc and Jonas's absence becomes the arc
		# itself — one bag instead of two. The strand id stays `aylinjonas`, so its beats, outcomes and
		# epilogue keys are untouched; only the face at the counter and the name in `met` changed.
		"start": "aj_meet", "priority": 5,
		# THE SEVEN-STEP ARC (docs/09 §2.10), one beat per Truby step: Sunday, 07:40, Glitter · The Van
		# And The Bar · Jonas Isn't With Her · One More Season Of Sundays · The Job In Leipzig · The Magic
		# Was Each Other · They Come At Eight In The Evening Now. Jonas stays offstage throughout — the
		# arc is the second bag, and the count of bags is the whole plot. Each step from 2 on gates on a
		# flag every branch of an earlier step wrote, so the chain reads back and cannot stall.
		"beats": {
			"aj_meet": {
				"id": "aj_meet", "speaker": "Aylin & Jonas", "after_day": 4,
				"lines": ["Glitter, big coats, Sunday-morning glow. \"Two Mate, two Pilsner — letztes Bier before bed.\" They lean on each other, laughing at nothing."],
				"choices": [
					{"label": "Ring it up; share the joke.", "kiez": 1, "flags": ["aylin_sunday"], "next": "aj_plans"},
					{"label": "\"Long night?\" Keep it brief.", "flags": ["aylin_sunday"], "next": "aj_plans"},
				],
			},
			"aj_plans": {
				"id": "aj_plans", "speaker": "Aylin", "after_day": 7, "requires_flag": "aylin_sunday",
				"lines": ["\"The van. We've found the van. Sprinter, bed in it, four and a half — which we have. Well. Which we will have. By spring.\"", "And then the bar. Portugal, small room, one good system. She says next summer the way other people say contract."],
				"choices": [
					{"label": "\"By spring.\" Write it on the fridge list.", "kiez": 1, "flags": ["aylin_plans", "aylin_van"], "next": "aj_onebag"},
					{"label": "Cost it properly on a Pfand receipt.", "kiez": 1, "flags": ["aylin_plans", "aylin_van", "aylin_rent_slip"], "next": "aj_onebag"},
					{"label": "\"Every Sunday there's a van, Aylin.\"", "kiez": -1, "flags": ["aylin_plans", "aylin_portugal"], "next": "aj_onebag"},
				],
			},
			"aj_onebag": {
				"id": "aj_onebag", "speaker": "Aylin", "after_day": 10, "requires_flag": "aylin_plans",
				"lines": ["One bag. Seven years of Sundays and it has always, always been two.", "\"He goes home at two now. Not with me at two — at two, on his own, from wherever we are. Since March.\""],
				"choices": [
					{"label": "\"And you stay till seven.\"", "kiez": 1, "flags": ["aylin_jonas_two", "aylin_asked_after_him"], "next": "aj_sundays"},
					{"label": "\"Since when?\" Wait for the answer.", "kiez": 2, "flags": ["aylin_jonas_two", "aylin_second_bag", "aylin_named_it"], "next": "aj_sundays"},
					{"label": "Ring it up. Not your business.", "kiez": -1, "flags": ["aylin_jonas_two"], "next": "aj_sundays"},
				],
			},
			"aj_sundays": {
				"id": "aj_sundays", "speaker": "Aylin", "after_day": 13, "requires_flag": "aylin_jonas_two",
				"lines": ["October, and she is in the summer jacket, because the summer jacket is the Sunday jacket.", "\"One more season. One more winter of Sundays and then we'll see. That's not a plan. I know it's not a plan.\""],
				"choices": [
					{"label": "\"It's a wish with a date on it. Those count.\"", "kiez": 1, "flags": ["aylin_one_more", "aylin_season_promise"], "next": "aj_turn"},
					{"label": "Turn the heater round to face the door.", "cash": -2, "kiez": 2, "flags": ["aylin_one_more", "aylin_bench_heater"], "next": "aj_turn"},
					{"label": "\"They sold the room, Aylin. I heard.\"", "kiez": 1, "flags": ["aylin_one_more", "aylin_club_sold"], "next": "aj_turn"},
				],
			},
			"aj_turn": {
				"id": "aj_turn", "speaker": "Aylin", "after_day": 17, "requires_flag": "aylin_one_more",
				"lines": ["Aylin's alone tonight, no glow. \"Jonas got a job. Leipzig. He says come, I say the weekends are here…\"", "She turns the Mate in her hands. \"Were we ever really us, or just the Sundays?\" The offer is hers as well, and she has not said so yet."],
				"choices": [
					{"label": "\"The magic was each other. Go find out.\"", "kiez": 1, "integrity": 1, "outcome": "together", "flags": ["aylin_leipzig", "aylin_told_her_go"], "next": "aj_magic"},
					{"label": "\"Only you know that, Aylin.\"", "outcome": "drifted", "flags": ["aylin_leipzig", "aylin_leipzig_offer"], "next": "aj_magic"},
				],
			},
			"aj_magic": {
				"id": "aj_magic", "speaker": "Aylin", "after_day": 20, "requires_flag": "aylin_leipzig",
				"lines": ["Two bags. He is out on the bench with both of them and has not come in, because coming in was never his job.", "\"Four hours on the floor with the map out, like a load-in. Neither of us wants Leipzig. We want the bit where the other one's there when it finishes.\""],
				"choices": [
					{"label": "\"That's what the room was, then.\"", "kiez": 2, "flags": ["aylin_magic", "aylin_magic_named"], "next": "aj_eight"},
					{"label": "Open at seven on Sundays. Say it out loud.", "kiez": 2, "integrity": 1, "flags": ["aylin_magic", "aylin_bench_stays", "aylin_seven_am"], "next": "aj_eight"},
					{"label": "\"An hour twenty each way. Every week.\"", "flags": ["aylin_magic"], "next": "aj_eight"},
				],
			},
			"aj_eight": {
				"id": "aj_eight", "speaker": "Aylin", "after_day": 24, "requires_flag": "aylin_magic",
				"lines": ["Twenty past eight. In the evening. Two Mate, a water, a pack she will not open, und ein Feuerzeug — every single time, without exception.", "The bench is still there. The hoarding went up eleven metres down the street and stopped, because forty-one people wrote to a Bezirksamt about a bench."],
				"choices": [
					{"label": "\"Bench is yours. Both ends of it.\"", "kiez": 2, "integrity": 1, "outcome": "together", "flags": ["aylin_evening_sundays", "aylin_bench_saved"], "next": ""},
					{"label": "House lighter. She's paid for nine of them.", "kiez": 2, "outcome": "together", "flags": ["aylin_evening_sundays", "aylin_jar_kept"], "next": ""},
					{"label": "\"Sunday mornings were better.\"", "kiez": -1, "outcome": "drifted", "flags": ["aylin_evening_sundays"], "next": ""},
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
		# THE SEVEN STEPS (docs/09 §2.6), one beat per Truby step, keyed to the year — summer 1-2 ·
		# autumn 3-4 · winter 5-6 · spring 7. Every beat past the first carries a `requires_flag` that
		# an EARLIER step set, which is what makes the arc branch on what the player did rather than
		# on the date. THE INVARIANT THAT KEEPS A GATE FROM FREEZING THE ARC: every choice that routes
		# to a beat sets that beat's flag. So a gate can only ever mean "you got here the way this
		# scene was written for", never "this guest silently stopped existing" — and a FORK (here
		# `k_letter`) is two step-4 beats, one per answer, each gated on its own half of the fork.
		"id": "karim", "character": "Karim", "character_id": "karim", "archetype_id": "regular",
		"start": "k_meet", "priority": 6,
		"beats": {
			"k_meet": {
				"id": "k_meet", "speaker": "Karim", "after_day": 5,
				"lines": ["He rehearses the words before he says them. \"One… telephone card, bitte. And — entschuldigung — this word, is correct?\" He shows a form, a hand not quite steady."],
				"choices": [
					{"label": "Help with the form. Slow German, no rush.", "kiez": 1, "integrity": 1, "flags": ["karim_kind", "karim_at_the_counter"], "next": "k_zackig"},
					{"label": "Sell the card; point him to an office.", "flags": ["karim_at_the_counter"], "next": "k_zackig"},
				],
			},
			"k_zackig": {
				"id": "k_zackig", "speaker": "Karim", "after_day": 7, "requires_flag": "karim_at_the_counter",
				"lines": ["\"Einmal die Fuchs — und zwar zackig.\" He lands it at the wall, at volume, and then checks your face for the mark.", "\"I said it four times today. Two understood. One laughed. One was a policeman.\""],
				"choices": [
					{"label": "\"Perfect. Never say it any other way.\"", "kiez": 1, "flags": ["karim_berlin_word"], "next": "k_letter"},
					{"label": "\"Zackig is the speed. Not the order.\"", "flags": ["karim_berlin_word"], "next": "k_letter"},
				],
			},
			"k_letter": {
				# THE FORK. Read it with him and step 4 is the nightly ten minutes at your counter;
				# wave it off and it is the same ten minutes with the sleeve shut in his jacket.
				"id": "k_letter", "speaker": "Karim", "after_day": 9, "requires_flag": "karim_berlin_word",
				"lines": ["The plastic sleeve comes out and stays shut on the laminate. Through the window of the top envelope: a Behörde crest and a date.", "\"Four days. I read who it is from, and then I was very busy for four days.\""],
				"choices": [
					{"label": "\"Open it here. Two of us read faster than one.\"", "kiez": 1, "integrity": 1, "flags": ["karim_letter_read"], "next": "k_tenmin"},
					{"label": "\"That's a Behörde thing, Karim. Not a Späti thing.\"", "kiez": -1, "flags": ["karim_letter_kept"], "next": "k_tenmin_alone"},
				],
			},
			"k_tenmin": {
				"id": "k_tenmin", "speaker": "Karim", "after_day": 12, "requires_flag": "karim_letter_read",
				"lines": ["He comes at twenty past midnight and stays exactly ten minutes, which is how long it takes him to say one true thing without rehearsing it first.", "\"Ten minutes. Every night. This is the deal I made with myself. You are the classroom. Sorry.\""],
				"choices": [
					{"label": "\"Ten minutes. I'll keep the queue off you.\"", "kiez": 2, "flags": ["karim_ten_minutes"], "next": "k_corner"},
					{"label": "\"Twelve, if nobody's waiting.\"", "kiez": 1, "flags": ["karim_ten_minutes"], "next": "k_corner"},
				],
			},
			"k_tenmin_alone": {
				"id": "k_tenmin_alone", "speaker": "Karim", "after_day": 12, "requires_flag": "karim_letter_kept",
				"lines": ["He still comes at twenty past midnight. The sleeve stays in the jacket now, and the sentences have gone back to short, correct and about nothing.", "\"The letter is handled. An office. A number. Four hours of a Tuesday.\" A beat. \"It is normal. It is fine.\""],
				"choices": [
					{"label": "\"Ten minutes of German a night. Starting now.\"", "kiez": 2, "flags": ["karim_ten_minutes"], "next": "k_corner"},
					{"label": "\"Four hours of a Tuesday is not normal.\"", "kiez": 1, "flags": ["karim_ten_minutes"], "next": "k_corner"},
				],
			},
			"k_corner": {
				"id": "k_corner", "speaker": "Karim", "after_day": 15, "requires_flag": "karim_ten_minutes",
				"lines": ["He is not shaking and he is not going to. He is standing very straight, which is worse.", "\"Two men at the corner. One of them said something. Everyone heard it, and everyone looked at their phone.\""],
				"choices": [
					{"label": "\"Out front with me. While they're still there.\"", "kiez": 2, "integrity": 1, "flags": ["karim_corner_night", "karim_stood_up"], "next": "k_battle"},
					{"label": "\"Sit on the crate. Nobody gets past me.\"", "kiez": 1, "flags": ["karim_corner_night"], "next": "k_battle"},
					{"label": "\"Some people are like that. Ignore them.\"", "kiez": -1, "flags": ["karim_corner_night"], "next": "k_battle"},
				],
			},
			"k_battle": {
				"id": "k_battle", "speaker": "Karim", "after_day": 17, "requires_flag": "karim_corner_night",
				"lines": ["\"I made a list,\" he says, and puts it on the counter: names in his handwriting, in two alphabets.", "\"People here who know my name. I thought it would be two. It is seven. Eight, if the greengrocer counts, and he counts.\""],
				"choices": [
					{"label": "\"That's not a list, Karim. That's a Kiez.\"", "kiez": 2, "integrity": 1, "outcome": "belongs", "flags": ["karim_counted_them"], "next": "k_party"},
					{"label": "\"Eight's a good number.\" Ring him up.", "outcome": "isolated", "flags": ["karim_counted_them"], "next": "k_party"},
				],
			},
			"k_party": {
				"id": "k_party", "speaker": "Karim", "after_day": 22, "requires_flag": "karim_counted_them",
				"lines": ["Two trestle tables out front, a gas ring he carried here on the U-Bahn, and a pot that has been going since four in the afternoon.", "\"Kibbeh,\" he tells four Germans in a row, slowly, until all four say it back properly. Then he makes them do his surname."],
				"choices": [
					{"label": "\"Say it again. They'll have it by the third go.\"", "kiez": 2, "integrity": 1, "next": ""},
					{"label": "Take a bowl and stand out of his way.", "kiez": 1, "next": ""},
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
			# S7 — Truby's seven, keyed to the year (docs/09 §2.5): summer 1-2 · autumn 3-4 · winter 5-6 ·
			# spring 7. Every beat past the first GATES ON A FLAG THE STEP BEFORE IT SET, and each of
			# those carry flags is written by EVERY choice of its beat (and again by that step's tree),
			# so no branch can strand the arc half-told. The one gate that is a real fork is the last:
			# `a_elder` needs `achim_listen`, which only exists if you ever let him tell you how it was.
			"a_meet": {
				"id": "a_meet", "speaker": "Achim", "after_day": 6,
				"lines": ["Leather vest, grey mohawk, a Sterni at 2pm. \"This whole Kiez sold out. You're next, probably.\" He says it like a test, not an insult."],
				"choices": [
					{"label": "\"Maybe. Tell me how it was, then.\"", "kiez": 1, "flags": ["achim_listen", "achim_met"], "next": "a_window"},
					{"label": "\"It's a business, Achim.\"", "kiez": -1, "flags": ["achim_met"], "next": "a_window"},
				],
			},
			"a_window": {
				"id": "a_window", "speaker": "Achim", "after_day": 8, "requires_flag": "achim_met",
				"lines": ["An A3 comes out of the jacket, still warm from somebody's work printer. BENEFIZ. SAMSTAG. The typeface is a crime and the cause is not.", "\"Your window. It's the only glass on this street anyone still reads.\""],
				"choices": [
					{"label": "Tape it up. Centre of the glass.", "kiez": 2, "flags": ["achim_window", "flyers_up"], "next": "a_spaetkauf"},
					{"label": "\"Inside the door. The window's my livelihood.\"", "kiez": 1, "flags": ["achim_window"], "next": "a_spaetkauf"},
				],
			},
			"a_spaetkauf": {
				"id": "a_spaetkauf", "speaker": "Achim", "after_day": 11, "requires_flag": "achim_window",
				"lines": ["\"Have you SEEN it? Down the block. Neon, an app, a QR code where the till should be. They've got a CONCEPT.\"", "\"And they shut at eleven, and they've put a padlock on the Pfand bin. On bottles. Who is that FOR?\""],
				"choices": [
					{"label": "\"Then we're the late shift. Same as ever.\"", "kiez": 1, "flags": ["achim_chain"], "next": "a_table"},
					{"label": "\"Let it go, Achim. It's a shop.\"", "kiez": -1, "flags": ["achim_chain"], "next": "a_table"},
				],
			},
			"a_table": {
				"id": "a_table", "speaker": "Achim", "after_day": 13, "requires_flag": "achim_chain",
				"lines": ["A folding table has appeared outside your door, with a clipboard on it and a biro on a string. Nobody asked him to do this.", "\"Forty-one signatures. I told them you'd sign it, so don't make a liar of me at my age.\""],
				"choices": [
					{"label": "Sign it. Put the clipboard by the till.", "kiez": 2, "integrity": 1, "flags": ["achim_table", "achim_clipboard"], "next": "a_battle"},
					{"label": "\"Off the pavement, Achim. I'll get fined.\"", "kiez": -1, "flags": ["achim_table"], "next": "a_battle"},
				],
			},
			"a_battle": {
				"id": "a_battle", "speaker": "Achim", "after_day": 17, "requires_flag": "achim_table",
				"lines": ["\"They're turning my old squat into lofts. Lofts.\" He laughs, hollow. \"Forty years I fought this — to watch from a Späti?\""],
				"choices": [
					{"label": "\"Then help me fight for this corner. Last stand.\"", "kiez": 2, "integrity": 1, "outcome": "elder_agitator", "flags": ["achim_lofts"], "next": "a_scene"},
					{"label": "\"Nothing lasts, Achim. You know that.\"", "outcome": "fossil", "flags": ["achim_lofts"], "next": "a_scene"},
				],
			},
			"a_scene": {
				"id": "a_scene", "speaker": "Achim", "after_day": 19, "requires_flag": "achim_lofts",
				"lines": ["The small PA is on the bench, a bedsheet banner is taped across your shutter, and forty people are standing in the road with your Sterni in their hands.", "\"It was never the venue,\" he says, in one clause, which from him is a confession. \"The scene's the fight.\""],
				"choices": [
					{"label": "\"Then plug it in and say that out loud.\"", "kiez": 3, "integrity": 1, "next": "a_elder"},
					{"label": "Keep serving. Let him run the road.", "kiez": 2, "next": "a_elder"},
				],
			},
			"a_elder": {
				"id": "a_elder", "speaker": "Achim", "after_day": 23, "requires_flag": "achim_listen",
				"lines": ["He has a lanyard. He made himself a lanyard. He is running the Kiezversammlung like a load-in and has already told two people where to stand.", "\"Forty years I was the bloke shouting at the back. Turns out the trick was being the bloke with the folding table.\""],
				"choices": [
					{"label": "\"You're insufferable. Don't stop.\"", "kiez": 3, "integrity": 1, "outcome": "elder_agitator"},
					{"label": "\"Just don't blow the fuses again.\"", "kiez": 1},
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
		# THE SEVEN-STEP ARC (docs/09 §2.8), one beat per Truby step: Big Tip, Big Ideas · You Should
		# Make This A Destination · The Kiez Fund · He Brings Six Colleagues · His Company Or The Corner ·
		# Belonging Is Paid In Care · Throws In. Every step from 2 on GATES on a flag an earlier step
		# wrote (`requires_flag`), and every choice of the gating beat writes it — so the read is real
		# and the chain can never stall on a branch the player took. The seasonal trees `tobias_s2` …
		# `tobias_p7` are what he SAYS on each of these nights.
		"beats": {
			"t_meet": {
				"id": "t_meet", "speaker": "Tobias", "after_day": 5,
				"lines": ["Crisp jacket, warm smile, leaves the change. \"Man, I LOVE this place. So authentic. You should do a natural-wine night — I know people. This corner could be a destination.\""],
				"choices": [
					{"label": "\"It's already somewhere. To us.\"", "kiez": 1, "flags": ["tobias_warn", "tobias_tipped"], "next": "t_destination"},
					{"label": "\"Tell me more.\" Take the big tip.", "profit": 1, "flags": ["tobias_tipped"], "next": "t_destination"},
				],
			},
			"t_destination": {
				"id": "t_destination", "speaker": "Tobias", "after_day": 7, "requires_flag": "tobias_tipped",
				"lines": ["He has notes. In an app, under a heading, which he shuts too fast. \"Tasting flight, twelve euro, once a month. And the sign. Sorry — the sign.\"", "Cem painted that sign with a roller in 1998 and got the second K wrong and left it."],
				"choices": [
					{"label": "\"The wrong K is the point, Tobias.\"", "kiez": 1, "flags": ["tobias_destination", "tobias_kept_the_sign"], "next": "t_fund"},
					{"label": "\"Twelve euro is Jürgen's whole night.\"", "kiez": 1, "integrity": 1, "flags": ["tobias_destination"], "next": "t_fund"},
					{"label": "\"One wine night. One.\"", "profit": 1, "flags": ["tobias_destination", "tobias_wine_night"], "next": "t_fund"},
				],
			},
			"t_fund": {
				"id": "t_fund", "speaker": "Tobias", "after_day": 9, "requires_flag": "tobias_destination",
				"lines": ["\"Real thing. We're standing up a Kiez fund — local businesses, small grants, no strings. I put your name at the top.\"", "The building pass is still round his neck. Fourth floor of the block on the corner: new glass, old address."],
				"choices": [
					{"label": "\"Whose twelve grand is it, Tobias?\"", "kiez": 1, "flags": ["tobias_fund_offered", "tobias_asked_whose"], "next": "t_six"},
					{"label": "\"Clause four is a muzzle. Read it again.\"", "kiez": 1, "integrity": 1, "flags": ["tobias_fund_offered", "tobias_fund_strings"], "next": "t_six"},
					{"label": "Take it. The rent went up in August.", "cash": 60, "integrity": -3, "flags": ["tobias_fund_offered", "took_fund"], "next": "t_six"},
				],
			},
			"t_six": {
				"id": "t_six", "speaker": "Tobias", "after_day": 12, "requires_flag": "tobias_fund_offered",
				"lines": ["Seven of them at once, and his round, all of it. The corner goes loud in a way it has not been since the summer.", "By half one the bench is six coats and nobody off this street, and Jürgen's crate is being used as a table."],
				"choices": [
					{"label": "Hold the prices. Move the crate yourself.", "kiez": 1, "flags": ["tobias_colleagues", "tobias_six_fair"], "next": "t_choice"},
					{"label": "\"That crate is somebody's work.\"", "kiez": 2, "flags": ["tobias_colleagues", "tobias_crate_moved"], "next": "t_choice"},
					{"label": "Tourist price on the round. They won't notice.", "cash": 12, "integrity": -2, "flags": ["tobias_colleagues", "tobias_six_priced"], "next": "t_choice"},
				],
			},
			"t_choice": {
				"id": "t_choice", "speaker": "Tobias", "after_day": 18, "requires_flag": "tobias_colleagues",
				"lines": ["Quieter tonight. \"My startup's leasing the whole block — with the Lindner people. I didn't connect it to here. To you.\"", "He looks sick about it. \"I could sign. Or I could not.\""],
				"choices": [
					{"label": "\"Belonging isn't bought, Tobias. Choose us.\"", "kiez": 1, "integrity": 1, "outcome": "threw_in", "flags": ["tobias_chose", "tobias_asked_not_to_sign", "main_lever_hint"], "next": "t_care"},
					{"label": "\"Do what you came here to do.\"", "kiez": -1, "outcome": "moved_on", "flags": ["tobias_chose", "tobias_signed_anyway"], "next": "t_care"},
				],
			},
			"t_care": {
				"id": "t_care", "speaker": "Tobias", "after_day": 20, "requires_flag": "tobias_chose",
				"lines": ["It snowed at eight and the pavement outside your door is the only clear stretch on the block. Mehmet's is clear too. Nobody else's is.", "He has been putting your crates out at half eleven for three weeks and has not once mentioned it."],
				"choices": [
					{"label": "\"Under the shutter. I'll show you once.\"", "kiez": 2, "flags": ["tobias_cared", "tobias_care_shift"], "next": "t_throws"},
					{"label": "Do Frau Schulz's stretch with him. Forty minutes.", "kiez": 2, "integrity": 1, "flags": ["tobias_cared", "tobias_did_the_round", "tobias_learned_a_name"], "next": "t_throws"},
					{"label": "Don't mention it. Let it be his.", "kiez": 1, "flags": ["tobias_cared", "tobias_belongs"], "next": "t_throws"},
				],
			},
			"t_throws": {
				"id": "t_throws", "speaker": "Tobias", "after_day": 23, "requires_flag": "tobias_cared",
				"lines": ["The tenants' letter has been on your counter four Thursdays and he has asked about it every one of them without picking it up.", "Forty-one names. \"If I sign this, my company is on the other side of it. In writing. With my name on.\""],
				"choices": [
					{"label": "Say nothing. Let it be his.", "kiez": 2, "integrity": 1, "outcome": "threw_in", "flags": ["tobias_signed_letter"], "next": ""},
					{"label": "\"Belonging is paid in care. This is the bill.\"", "kiez": 2, "integrity": 1, "outcome": "threw_in", "flags": ["tobias_signed_letter", "tobias_told_plainly"], "next": ""},
					{"label": "\"Leipzig's nice, they say. Cheaper.\"", "kiez": -1, "outcome": "moved_on", "flags": ["tobias_leipzig"], "next": ""},
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
		# The seven steps of docs/09 §2.7, same contract as `karim`: every beat past the first is gated
		# on a flag an earlier step set, and every choice that routes to a beat sets that beat's flag,
		# so no answer can strand her. The fork is `n_doubles` — let her say what would help and step 4
		# is the count you are allowed to see; keep it a transaction and it is the count she catches
		# you watching. Both halves land on the same winter.
		"id": "nadia", "character": "Nadia", "character_id": "nadia", "archetype_id": "nurse",
		"start": "n_meet", "priority": 6,
		"beats": {
			"n_meet": {
				"id": "n_meet", "speaker": "Nadia", "after_day": 4,
				"lines": ["Scrubs under her coat, 4am eyes. \"Coffee, strongest you've got, and a Schrippe for the kid's breakfast.\" She's already half out the door."],
				"choices": [
					{"label": "Make it a good one. \"Long shift?\"", "kiez": 1, "flags": ["nadia_at_the_counter"], "next": "n_never"},
					{"label": "Ring it up fast — she's in a hurry.", "flags": ["nadia_at_the_counter"], "next": "n_never"},
				],
			},
			"n_never": {
				"id": "n_never", "speaker": "Nadia", "after_day": 6, "requires_flag": "nadia_at_the_counter",
				"lines": ["The machine is cold and it is 03:41. She sees you see it, and her hand is on the door before you have found the switch.", "\"It's fine. There's a garage on the Frankfurter. It's fine.\" That is two of the four meanings of fine and neither is the good one."],
				"choices": [
					{"label": "\"Sit down. Three minutes and it's hot.\"", "kiez": 2, "flags": ["nadia_never_asked"], "next": "n_doubles"},
					{"label": "\"Garage coffee. On a night shift. Nadia.\"", "kiez": 1, "flags": ["nadia_never_asked"], "next": "n_doubles"},
				],
			},
			"n_doubles": {
				"id": "n_doubles", "speaker": "Nadia", "after_day": 9, "requires_flag": "nadia_never_asked",
				"lines": ["Third double this week. She lists it the way she'd list obs — hours, handovers, the two they lost on Tuesday — in one flat voice.", "\"It's the rent, mostly. Nights pay the difference between the rent and the rent.\""],
				"choices": [
					{"label": "\"What would actually help? Say the thing.\"", "kiez": 1, "flags": ["nadia_doubles_seen"], "next": "n_coins"},
					{"label": "\"Two coffees, two Schrippen. Same as always.\"", "flags": ["nadia_doubles_hidden"], "next": "n_coins_proud"},
				],
			},
			"n_coins": {
				"id": "n_coins", "speaker": "Nadia", "after_day": 12, "requires_flag": "nadia_doubles_seen",
				"lines": ["She counts the coins out on the laminate. Then, without a flicker, she counts them again — slower — and it is the second count that tells you.", "\"Take the Schrippen off. I'll get them tomorrow.\" It is not a request; she has already moved them."],
				"choices": [
					{"label": "\"They're forty cents, Nadia. Take them.\"", "cash": -0.8, "kiez": 2, "flags": ["nadia_counted"], "next": "n_battle"},
					{"label": "Ring it as she asked. Bag them anyway.", "kiez": 1, "flags": ["nadia_counted"], "next": "n_battle"},
				],
			},
			"n_coins_proud": {
				"id": "n_coins_proud", "speaker": "Nadia", "after_day": 12, "requires_flag": "nadia_doubles_hidden",
				"lines": ["She counts the coins twice, catches you watching the second count, and stops dead in the middle of it.", "\"Don't.\" A breath. \"I'm not a collection. I'm a nurse with a rota problem.\""],
				"choices": [
					{"label": "\"Understood. Two coffees, two Schrippen.\"", "kiez": 1, "flags": ["nadia_counted"], "next": "n_battle"},
					{"label": "\"Nobody's collecting. I'm just awake too.\"", "kiez": 2, "flags": ["nadia_counted"], "next": "n_battle"},
				],
			},
			"n_battle": {
				"id": "n_battle", "speaker": "Nadia", "after_day": 15, "requires_flag": "nadia_counted",
				"lines": ["On the phone, voice cracking. \"Childcare fell through and I'm due on ward in twenty—\"", "She catches your eye, mortified to be seen needing anything. It is the coldest night of the year."],
				"choices": [
					{"label": "\"The kid waits here with me. Go. Go!\"", "kiez": 2, "integrity": 1, "outcome": "held", "flags": ["nadia_leo_night"], "next": "n_kiez"},
					{"label": "\"That's rough. Hope it works out.\"", "outcome": "burned_out", "flags": ["nadia_leo_night"], "next": "n_kiez"},
				],
			},
			"n_kiez": {
				"id": "n_kiez", "speaker": "Nadia", "after_day": 18, "requires_flag": "nadia_leo_night",
				"lines": ["She stands in the doorway a long time before she says it, and it costs her more than the double did.", "\"Thursdays. Could Leo sit here an hour on Thursdays, while my mother's at the doctor. I'm asking. I'm actually asking.\""],
				"choices": [
					{"label": "\"Thursdays. He gets the crate and a Schrippe.\"", "kiez": 2, "integrity": 1, "flags": ["nadia_asked_out_loud"], "next": "n_leo"},
					{"label": "\"You could have asked in September.\"", "kiez": 1, "flags": ["nadia_asked_out_loud"], "next": "n_leo"},
				],
			},
			"n_leo": {
				"id": "n_leo", "speaker": "Nadia", "after_day": 22, "requires_flag": "nadia_asked_out_loud",
				"lines": ["Thursday, half four, a six-year-old on the Pfand crate with a maths book on his knees and a Schrippe he is not eating.", "\"Mama says you know all the numbers,\" he says, with the flat calm of somebody who has been calm since seven last night. He gets it from somewhere."],
				"choices": [
					{"label": "\"Only the till ones. Show me question four.\"", "kiez": 2, "next": ""},
					{"label": "Put the radio on low and let him work.", "kiez": 1, "next": ""},
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
		# The seven steps of docs/09 §2.9, same contract as `karim` and `nadia`. The fork is `r_call`:
		# stand outside with them after the forty-second phone call and step 4 is somebody orbiting a
		# light they are allowed to be seen in; say nothing and it is the same orbit, done when the
		# shop is empty. Nineteen years old either way, and the winter is the same winter.
		"id": "robin", "character": "Robin", "character_id": "robin", "archetype_id": "student",
		"start": "r_meet", "priority": 5,
		"beats": {
			"r_meet": {
				"id": "r_meet", "speaker": "Robin", "after_day": 7,
				"lines": ["Hovers by the magazines, watching the door more than the shelf — buys a single Mate just to have a reason to stand in the warm light a while longer."],
				"choices": [
					{"label": "\"Stay as long as you like. It's cold out.\"", "kiez": 1, "flags": ["robin_safe", "robin_at_the_counter"], "next": "r_name"},
					{"label": "Ring up the Mate; leave them be.", "flags": ["robin_at_the_counter"], "next": "r_name"},
				],
			},
			"r_name": {
				"id": "r_name", "speaker": "Robin", "after_day": 9, "requires_flag": "robin_at_the_counter",
				"lines": ["\"The tab list. On the fridge.\" They look at the list, not at you. \"It says a name on there that isn't mine. The card's my mum's old account. It's a whole thing.\"", "\"Robin. With an i-n.\" Fast and flat, and their hand is very still on the counter."],
				"choices": [
					{"label": "Cross it out. Write ROBIN. Hand them the pen.", "kiez": 2, "integrity": 1, "flags": ["robin_name_written"], "next": "r_call"},
					{"label": "\"Robin. Got it.\" Use it twice more tonight.", "kiez": 1, "flags": ["robin_name_written"], "next": "r_call"},
				],
			},
			"r_call": {
				"id": "r_call", "speaker": "Robin", "after_day": 11, "requires_flag": "robin_name_written",
				"lines": ["Forty seconds outside with the phone to their ear. Then back in, gummi bears they do not want, and nothing said at all.", "\"She asked when I'm coming home for the summer.\" Flat. \"I said I'd let her know.\""],
				"choices": [
					{"label": "\"Say it out here if you want. Nobody's listening.\"", "kiez": 2, "flags": ["robin_call_heard"], "next": "r_orbit"},
					{"label": "Say nothing. Put the gummi bears in the bag.", "kiez": 1, "flags": ["robin_call_private"], "next": "r_orbit_alone"},
				],
			},
			"r_orbit": {
				"id": "r_orbit", "speaker": "Robin", "after_day": 13, "requires_flag": "robin_call_heard",
				"lines": ["Four nights a week, and they stay outside longer than the transaction — leaning on your glass, in your light, on the phone to nobody.", "\"This is the only bit of pavement round here with a light on it that isn't a bank.\""],
				"choices": [
					{"label": "\"The bench is for standing near. Use it.\"", "kiez": 2, "flags": ["robin_orbiting"], "next": "r_heart"},
					{"label": "\"Come in, then. The heater's my side.\"", "kiez": 1, "flags": ["robin_orbiting"], "next": "r_heart"},
				],
			},
			"r_orbit_alone": {
				"id": "r_orbit_alone", "speaker": "Robin", "after_day": 13, "requires_flag": "robin_call_private",
				"lines": ["Four nights a week, and they do not come in until the shop is empty. If somebody is at the counter they walk the block once and try again.", "\"I'm not weird about it,\" they say, unasked. \"I just like it when it's quiet.\""],
				"choices": [
					{"label": "\"Quiet from one. I'll leave the light on.\"", "kiez": 2, "flags": ["robin_orbiting"], "next": "r_heart"},
					{"label": "\"You're not weird. You're nineteen.\"", "kiez": 1, "flags": ["robin_orbiting"], "next": "r_heart"},
				],
			},
			"r_heart": {
				"id": "r_heart", "speaker": "Robin", "after_day": 16, "requires_flag": "robin_orbiting",
				"lines": ["Two in the morning and the deadpan has come off like a coat. Crying at your counter in front of a fridge full of Mate, and furious about it.", "\"Six weeks. Six. And she told her mates I was a phase she was having.\""],
				"choices": [
					{"label": "Gummi bears on the house. Nothing clever.", "cash": -1.3, "kiez": 2, "flags": ["robin_heartbreak"], "next": "r_battle"},
					{"label": "\"Six weeks is long enough to hurt. Sit down.\"", "kiez": 2, "flags": ["robin_heartbreak"], "next": "r_battle"},
					{"label": "\"You'll laugh about this in a year.\"", "kiez": -1, "flags": ["robin_heartbreak"], "next": "r_battle"},
				],
			},
			"r_battle": {
				"id": "r_battle", "speaker": "Robin", "after_day": 18, "requires_flag": "robin_heartbreak",
				"lines": ["\"Mum still uses the old name. Every call. Like a correction she's making, forever.\" To the counter, not to you. \"Berlin was supposed to be the easy part.\"", "\"So I wrote a list. People who don't. It's short, and you're on it, which is embarrassing for both of us.\""],
				"choices": [
					{"label": "\"Short lists are the real ones. You're on mine.\"", "kiez": 2, "integrity": 1, "outcome": "chosen_family", "flags": ["robin_chosen"], "next": "r_crew"},
					{"label": "\"Family's complicated. You'll figure it out.\"", "outcome": "fled", "flags": ["robin_chosen"], "next": "r_crew"},
				],
			},
			"r_crew": {
				"id": "r_crew", "speaker": "Robin", "after_day": 22, "requires_flag": "robin_chosen",
				"lines": ["Four of them on the bench out front at one in the morning, loud in three languages, and Robin in the middle of it not braced for anything.", "\"This is the guy,\" they tell the bench. \"This is the actual guy. He wrote my name on a fridge.\""],
				"choices": [
					{"label": "\"Four energies and the gummi bears. Go on.\"", "kiez": 2, "next": ""},
					{"label": "\"Keep it down. And keep the bench.\"", "kiez": 1, "next": ""},
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
			# S5 — Truby's seven, keyed to the year (docs/09 §2.4): summer 1-2 · autumn 3-4 · winter 5-6 ·
			# spring 7. Every beat past the first GATES ON A FLAG THE STEP BEFORE IT SET, and each carry
			# flag is written by EVERY choice of its beat (and again by that step's tree), so no branch
			# can strand her arc half-told. The exception is deliberate: `sc_corner` needs
			# `schulz_listen` — if you never once asked her to tell you, she does not stand up in the
			# spring, and `sc_battle`'s outcome is where her story stops. Her step-6 tree sets it too,
			# so a bad summer is recoverable; a whole year of not listening is not.
			"sc_meet": {
				"id": "sc_meet", "speaker": "Frau Schulz", "after_day": 6,
				"lines": ["Sharp eyes, sharper tongue. \"In the GDR this corner had a different name and better Brötchen. You young ones don't know what stood here.\" She watches to see if you flinch."],
				"choices": [
					{"label": "\"Then tell me. I want to know.\"", "kiez": 1, "flags": ["schulz_listen", "schulz_met"], "next": "sc_prices"},
					{"label": "\"Times change, Frau Schulz.\"", "kiez": -1, "flags": ["schulz_met"], "next": "sc_prices"},
				],
			},
			"sc_prices": {
				"id": "sc_prices", "speaker": "Frau Schulz", "after_day": 8, "requires_flag": "schulz_met",
				"lines": ["She holds the printed price strip at arm's length, then closer, then puts it back on the shelf face down.", "\"Your uncle wrote mine on card. Big, square, number first. I could read them from the door.\""],
				"choices": [
					{"label": "\"Say them and I'll write them.\"", "kiez": 1, "flags": ["schulz_cards"], "next": "sc_verwaltung"},
					{"label": "\"They come printed with the shelf.\"", "kiez": -1, "flags": ["schulz_cards"], "next": "sc_verwaltung"},
				],
			},
			"sc_verwaltung": {
				"id": "sc_verwaltung", "speaker": "Frau Schulz", "after_day": 11, "requires_flag": "schulz_cards",
				"lines": ["\"A man from the Verwaltung came to my door. Good coat. He said Modernisierung, and he said it slowly. For the old lady.\"", "\"He left a folder. It is on my table, in the spot where I can see it from the chair.\""],
				"choices": [
					{"label": "\"Bring it here. We'll read all twelve pages.\"", "kiez": 2, "flags": ["schulz_verwaltung", "schulz_folder"], "next": "sc_court"},
					{"label": "\"Sign nothing. That's the whole of my advice.\"", "kiez": 1, "flags": ["schulz_verwaltung"], "next": "sc_court"},
				],
			},
			"sc_court": {
				"id": "sc_court", "speaker": "Frau Schulz", "after_day": 13, "requires_flag": "schulz_verwaltung",
				"lines": ["She is telling the whole corner about the Konsum, the video shop and the four years of nothing, at volume, to three people at the fridge who did not ask.", "One of them has put his beer back down on the shelf. That is more than anyone has given her in a year."],
				"choices": [
					{"label": "Turn the radio off and let her finish.", "kiez": 2, "flags": ["schulz_court"], "next": "sc_signal"},
					{"label": "\"Frau Schulz. The gentleman is waiting.\"", "kiez": -1, "flags": ["schulz_court"], "next": "sc_signal"},
				],
			},
			"sc_signal": {
				"id": "sc_signal", "speaker": "Frau Schulz", "after_day": 16, "requires_flag": "schulz_court",
				"lines": ["\"They are taking the signal box at Ostkreuz down. Thursday.\" She says it like a departure time.", "\"Twenty-nine years I sat in that box and moved trains through this city in the dark. Now it is in the way of something.\""],
				"choices": [
					{"label": "\"Then Thursday we go and watch it go.\"", "kiez": 2, "flags": ["schulz_signal"], "next": "sc_battle"},
					{"label": "\"They'll put a plaque on it, probably.\"", "kiez": -1, "flags": ["schulz_signal"], "next": "sc_battle"},
				],
			},
			"sc_battle": {
				"id": "sc_battle", "speaker": "Frau Schulz", "after_day": 18, "requires_flag": "schulz_signal",
				"lines": ["\"They tore down the old Konsum today. Forty years I bought bread there.\" Her voice doesn't shake; that's worse.", "\"Soon no one will remember it stood at all.\""],
				"choices": [
					{"label": "\"I'll remember. Write your prices in your old hand.\"", "kiez": 2, "integrity": 1, "outcome": "living_history", "next": "sc_corner"},
					{"label": "\"Nothing we can do about it.\" Ring her up.", "outcome": "forgotten", "next": "sc_corner"},
				],
			},
			"sc_corner": {
				"id": "sc_corner", "speaker": "Frau Schulz", "after_day": 22, "requires_flag": "schulz_listen",
				"lines": ["Forty people on plastic chairs in front of your shutter, and nobody wants to speak first. Frau Schulz stands up without being asked.", "\"I have bought bread on this corner under three signs and two countries. I will tell you what stood here, and then you will tell me what you intend to put in its place.\""],
				"choices": [
					{"label": "Give her the room. Sit down at the back.", "kiez": 3, "integrity": 1, "outcome": "living_history"},
					{"label": "\"Five minutes, Frau Schulz. There's a vote.\"", "kiez": -1},
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
	{
		# S13 — the lever. Not a conspirator: a man who read a term sheet on a Tuesday and went to lunch.
		# Seven beats, Truby's seven steps keyed to the year (docs/09 §2.11): Summer 1–2 · Autumn 3–4 ·
		# Winter 5–6 · Spring 7. `b_patron` is gated on `bley_tip` — if you never got the clause out of
		# him he stays a customer in a good coat, and `b_seen`'s outcome is where his story stops.
		"id": "bley", "character": "Herr Bley", "character_id": "bley", "archetype_id": "insomniac",
		"start": "b_water", "priority": 4,
		"beats": {
			"b_water": {
				"id": "b_water", "speaker": "Herr Bley", "after_day": 2,
				"lines": ["03:10. A good coat, a good watch, and an order given with the crispness of a man who considers you staff. \"Water. Still — the other is undrinkable.\"", "Then he does not leave. He stands nine minutes over a four-euro transaction, turning the bottle a quarter turn on the laminate."],
				"choices": [
					{"label": "Let him stand. Wipe the counter down slowly.", "kiez": 1, "flags": ["bley_water"], "next": "b_youngman"},
					{"label": "\"Anything else, or is that us?\"", "flags": ["bley_water"], "next": "b_youngman"},
				],
			},
			"b_youngman": {
				"id": "b_youngman", "speaker": "Herr Bley", "after_day": 5, "requires_flag": "bley_water",
				"lines": ["\"Young man,\" he says, for the ninth night running, and it is armour, worn politely.", "\"In Grunewald there is nothing open at three. Not even the people.\""],
				"choices": [
					{"label": "\"I've got a name. So have you, presumably.\"", "kiez": 1, "flags": ["bley_talks", "bley_youngman"], "next": "b_eleven"},
					{"label": "\"Young man's fine. Four twenty, bitte.\"", "flags": ["bley_talks", "bley_youngman"], "next": "b_eleven"},
				],
			},
			"b_eleven": {
				"id": "b_eleven", "speaker": "Herr Bley", "after_day": 9, "requires_flag": "bley_youngman",
				"lines": ["Eleven minutes tonight. He buys a bar of chocolate and leaves it on the counter, which he does most nights, and you have started putting it out again.", "\"You are open at three. Remarkable.\" He says it the way one remarks on a species."],
				"choices": [
					{"label": "\"Somebody's always awake. I just sell to them.\"", "kiez": 1, "flags": ["bley_eleven"], "next": "b_tuesday"},
					{"label": "Put the chocolate back in his bag without a word.", "kiez": 1, "integrity": 1, "flags": ["bley_eleven"], "next": "b_tuesday"},
				],
			},
			"b_tuesday": {
				"id": "b_tuesday", "speaker": "Herr Bley", "after_day": 12, "requires_flag": "bley_eleven",
				"lines": ["\"This street, by the way. Somebody put a paper in front of me on Tuesday. Block acquisition, mixed use. A very tidy structure.\"", "\"I signed off the financing on page eleven and went to lunch. One does not look at the street name.\" He has no idea he is standing in it."],
				"choices": [
					{"label": "\"What does page eleven give them, exactly?\"", "kiez": 1, "flags": ["bley_lindner", "bley_tip", "main_lever_hint", "bley_page_eleven"], "next": "b_armour"},
					{"label": "\"Tidy for who?\"", "flags": ["bley_lindner", "bley_page_eleven"], "next": "b_armour"},
					{"label": "Say nothing. Ring up the water.", "flags": ["bley_page_eleven"], "next": "b_armour"},
				],
			},
			"b_armour": {
				"id": "b_armour", "speaker": "Herr Bley", "after_day": 16, "requires_flag": "bley_talks",
				"lines": ["He is not crisp tonight. The coat is the same coat and everything under it has come apart: a house in Grunewald with one person in it, a daughter who forwards his letters unopened.", "\"I am not —\" He stops. \"I would like the water. That is all I would like.\""],
				"choices": [
					{"label": "Pour him a coffee he did not order. Say nothing.", "cash": -1, "kiez": 1, "integrity": 1, "next": "b_seen"},
					{"label": "\"Sit down, Rüdiger. The crate's clean.\"", "kiez": 2, "next": "b_seen"},
					{"label": "Ring up the water. It is 3am and he is a customer.", "next": "b_seen"},
				],
			},
			"b_seen": {
				"id": "b_seen", "speaker": "Herr Bley", "after_day": 19, "requires_flag": "bley_page_eleven",
				"lines": ["\"Thirty-one years in corporate finance,\" he says, to the fridge rather than to you, \"and the only person who has asked me a question that was not about a price works nights in a Späti.\"", "The coat is over his arm. He has been here fifty minutes."],
				"choices": [
					{"label": "Stay open. Let him talk until it gets light.", "kiez": 2, "integrity": 1, "outcome": "seen_him", "flags": ["bley_seen"], "next": "b_patron"},
					{"label": "\"Same time tomorrow, Herr Bley.\" Cash up.", "outcome": "back_in_the_coat"},
				],
			},
			"b_patron": {
				"id": "b_patron", "speaker": "Herr Bley", "after_day": 23, "requires_flag": "bley_tip",
				"lines": ["An envelope goes on the counter beside the chocolate, squared to the edge. A year of the Mieterverein retainer, paid, with no name on the transfer.", "\"You will not mention this. Not to the greengrocer, not to the loud one with the flyers. I would like to keep coming at three.\""],
				"choices": [
					{"label": "\"Nobody hears it from me. Same time tomorrow.\"", "kiez": 2, "integrity": 1, "outcome": "quiet_patron"},
					{"label": "\"Keep your money, Rüdiger. Just keep coming.\"", "kiez": 1, "outcome": "seen_him"},
				],
			},
		},
		"epilogue": {
			"institution": {
				"quiet_patron": "Herr Bley's retainer is still paid, still anonymous, and the Mieterverein has not lost a case on this street since.",
				"seen_him": "Herr Bley comes at three, sits on the crate, and tells the room what the numbers are actually doing. Nobody calls him young man.",
				"back_in_the_coat": "A man in a good coat buys still water at three in the morning and never stays. The new staff find him odd.",
			},
			"held": {
				"quiet_patron": "The retainer covers the lawyer who keeps the rent letters honest. He has never once mentioned it.",
				"seen_him": "Herr Bley drives in from Grunewald at three, and for nine minutes a night he is not a man who signs things.",
				"back_in_the_coat": "He kept coming and kept the coat on. Neither of you ever decided that; it just stayed true.",
			},
			"soldout": {
				"quiet_patron": "He paid for a fight you stopped fighting. The envelope went back uncashed, and he understood, and that was worse.",
				"seen_him": "\"You were the only one who asked,\" he says on the last night, and buys still water from you one final time.",
				"back_in_the_coat": "Two men who signed the tidy structure drink at different counters now. His is nicer.",
			},
			"pushedout": {
				"quiet_patron": "Herr Bley pays for the appeal out of his own account, loses, and turns up anyway on the day you carry the fridges out.",
				"seen_him": "He reads the closing notice on the glass for a long time. \"Page eleven,\" he says. \"I am sorry. That is not nothing, is it.\"",
				"back_in_the_coat": "He drove past on the Tuesday it shut, at three in the morning, and did not stop.",
			},
		},
	},
]

## THE FLAG ECONOMY (docs/09 §4.10). A flag nobody reads is a lie in the save file: the branch simply
## never happens, and nothing at runtime can show you that. `test_content.gd` already guards the READ
## side (every `requires_flag` names a flag some choice writes); this table is the WRITE side, and
## `test_flags.gd` fails the build on any flag set by any choice that nothing consumes.
##
## Three reader kinds count, and a flag needs exactly one of them:
##   1. a beat's or vignette's `requires_flag`  — a real gate, checked by StoryFlow.eligible_beats;
##   2. an `Economy.FLAG_LABEL` entry           — the Manage screen's corner-status panel prints it;
##   3. an entry HERE                           — a reader that is written and scheduled but not yet
##      shipped: the seasonal trees and the later arc beats of docs/09 §2. The value names the beat
##      that will consume it, so "who reads this?" is answerable from the data instead of from memory.
##
## Namespace (docs/09 §4.10): `<character_id>_<event>` strand-local · `kiez_*` corner-wide · `main_*`
## anything the 22-step arc reads. Lower snake, set-only, never cleared, stored in `story.flags`.
## Budget: 2–5 flags per guest per season. DELETE the entry when the real reader lands — the day a
## seasonal tree gates on `karim_zackig`, kind 1 takes over and this row becomes a dead declaration,
## which `test_flags.gd` also fails on.
const FLAG_READERS: Dictionary = {
	# — the main arc —
	"heard_offer": "main/climax — the second offer reads whether she has already made the first",
	"refused_early": "main/climax — Brandt's approach hardens if you refused her on day 6",
	"sold": "Finale.main_ending — mirrors story.main_outcome into the epilogue copy",
	"stood": "Finale.main_ending — mirrors story.main_outcome into the epilogue copy",
	"main_lever_hint": "main step 17 — the lever; set by three independent routes (Bley's clause, Tobias's March date, Aylin's fence notice) and read once",

	# — S1 Lena —
	"lena_kind": "lena/l_show — The Show: the tab decides whether she can afford to hang the honest piece",
	# Summer step 2, "The Honest Piece" (`lena_s2`) — the four flags autumn's step 3 reads back.
	"lena_honest_piece": "S1 autumn — The Gallerist: he can only ask her to make it sellable if you have seen the honest one",
	"lena_named_it": "S1 autumn — The Gallerist: she quotes you back at him, and it costs her the hanging",
	"lena_wall_offer": "S1 spring — The Wall: the nail you offered in the summer is the wall she pays the tab off on",
	"lena_hung_it": "S1 winter — The Show: the piece was already up in a Späti, which is either nothing or everything",

	# — S2 Jürgen —
	"j_welcome": "juergen/j_cold — The Night He Doesn't Come",

	# — S3 Mehmet —
	"m_trust": "mehmet/m_word — Legacy Is People",

	# — S11 Yusuf —
	"y_grace": "yusuf/y_job — the shelf-stacking offer only lands if you gave him the grace first",

	# — S5 Frau Schulz —
	"schulz_reserved": "S5 autumn — the luxor row runs out as a story beat, not a stock-out",
	"schulz_hand": "S5 winter — They Do Want The Stories: the price cards in her own hand",
	"schulz_bag": "S5 spring — The Corner's Memory: she narrates the Kiezversammlung",
	"schulz_brandt_visit": "main step 15 — the Brandt pressure beat knows she was approached first",
	# The seven-step arc's own marks. The carry flags (`schulz_met`/`_cards`/`_verwaltung`/`_court`/
	# `_signal`) are NOT here: each is a real `requires_flag` gate on the next beat, which is kind 1.
	"schulz_own_hand": "S5 §6 They Do Want The Stories — the rack is already in her hand, so the list is only the next card",
	"schulz_folder": "main steps 15-17 — the Modernisierungsankündigung she carried in is the tenants' first piece of paper",
	"schulz_clause": "main steps 15-17 — the Umlage cap is written with the wrong year and you read it before the lawyer did",
	"schulz_heard": "S5 §7 The Corner's Memory — the three at the fridge came back, which is why forty chairs is not optimistic",
	"schulz_saw_it_go": "S5 §6 They Do Want The Stories — you stood on the bridge with her, so the list is not secondhand",
	"schulz_wall_list": "S5 §7 The Corner's Memory — what is in the glass is what she reads out at the Versammlung",
	"schulz_corner": "Finale epilogue — the corner's memory survived her, in her own hand, on the window",
	"schulz_narrated": "Finale epilogue — she had the room before anyone else spoke, and the room went quiet",

	# — S6 Karim —
	# The BEAT chain's own flags (`karim_at_the_counter`, `karim_berlin_word`, `karim_letter_read` /
	# `karim_letter_kept`, `karim_ten_minutes`, `karim_corner_night`, `karim_counted_them`) are REAL
	# `requires_flag` gates and therefore have no row here — kind 1 owns them. Everything below is
	# what the seven step TREES write: a dialogue tree cannot gate on a flag, so the step that reads
	# these back is the beat or the epilogue named in the value.
	"karim_kind": "karim/k_battle — This Is Already Home",
	"karim_word": "S6 winter — the Behörde deadline: he says the brand name instead of pointing",
	"karim_zackig": "S6 spring — He Cooks For The Street Party",
	"karim_form": "S6 winter — the Behörde deadline",
	"karim_helped": "S6 winter — the Behörde deadline: the photocopy is the document they wanted",
	# summer step 2, `karim_s2` — The Berlin Way To Say It
	"karim_zackig_joke": "S6 spring — He Cooks For The Street Party: the word is his party piece by then",
	"karim_joke_landed": "S6 winter — This Is Already Home: the first joke he told that nobody translated",
	"karim_sleeve_notes": "S6 autumn — The Letter In His Jacket: the sleeve carries his own notes now",
	# autumn step 3, `karim_a3` — The Letter In His Jacket
	"karim_letter_shown": "S6 autumn — Ten Minutes Of German: he brings the sleeve to the counter unasked",
	"karim_letter_answered": "S6 winter — This Is Already Home: the Frist he beat is on the list",
	"karim_copies": "S6 winter — Something Gets Said To Him: the copy is what he has on him",
	"karim_every_letter": "S6 spring — He Cooks For The Street Party: two years of letters, all answered",
	# autumn step 4, `karim_a4` — Ten Minutes Of German, Every Night
	"karim_ten_nightly": "S6 winter — This Is Already Home: the ten minutes are why the list is seven long",
	"karim_names_it": "S6 winter — This Is Already Home: he stopped calling it practice",
	"karim_teaches_back": "S6 spring — He Cooks For The Street Party: he makes four Germans repeat after him",
	# winter step 5, `karim_w5` — Something Gets Said To Him At The Corner
	"karim_shook": "S6 winter — This Is Already Home: the night he counted who was actually there",
	"karim_walked_out": "main step 19 — the Kiezversammlung: he saw what standing in a doorway does",
	"karim_wrote_it_down": "S6 spring — He Cooks For The Street Party: the sentence he finally gets to use",
	# winter step 6, `karim_w6` — This Is Already Home
	"karim_counted_us": "S6 spring — He Cooks For The Street Party: the list is the guest list",
	"karim_mother_call": "S6 spring — He Cooks For The Street Party: she asks for a photo of the tables",
	"karim_called_here": "S6 spring — He Cooks For The Street Party: she has heard the shop bell now",
	# spring step 7, `karim_p7` — He Cooks For The Street Party
	"karim_cooks": "Finale — the Kiez epilogue: the street party is what the corner was for",
	"karim_name_said_right": "Finale — the Kiez epilogue: four Germans learned to say his name",
	"karim_recipe": "Finale — the Kiez epilogue: the recipe is taped up behind the till",
	# the beat chain's one non-gate flag
	"karim_stood_up": "main step 19 — the Kiezversammlung: you went outside for him once already",

	# — S7 Achim —
	"achim_maths": "S7 autumn — The Folding Table",
	"achim_ally": "main step 19 — the Kiezversammlung: he brings the PA",
	"achim_poster": "main step 19 — the Kiezversammlung: turnout is the window's readership",
	"achim_poster_inside": "main step 19 — the Kiezversammlung: half the turnout",
	"achim_route": "main step 19 — the Kiezversammlung: the sixty-poster route fills the room",
	"achim_cem_story": "S7 winter — The Squat Becomes Lofts: Cem was at the '96 rent strike",
	# The seven-step arc's own marks; the carry flags (`achim_met`/`_window`/`_chain`/`_table`/`_lofts`)
	# are real `requires_flag` gates on the next beat and so are deliberately absent from this table.
	"achim_square": "S7 §4 The Folding Table — he trusts your hands with his print, which is why the clipboard lands here",
	"achim_scouted": "S7 §5 The Squat Becomes Lofts — you shut your own till to look at theirs, and he has not forgotten",
	"achim_clipboard": "main step 19 — the Kiezversammlung: the signature list on the counter IS the turnout",
	"achim_carried": "S7 §6 The Fight Is The Scene — the PA came up out of the cellar early, so the road has sound",
	"achim_clause": "main steps 15-17 — the Erhaltungssatzung line on the plaque is the same instrument as the lever",
	"achim_ran_it": "S7 §7 Elder Agitator — you worked his door once, so he lets you hand him the room",
	"achim_elder": "Finale epilogue — the lanyard, and what he did with it",
	"achim_useful": "Finale epilogue — forty chairs stacked by two men, which is the whole of the ending",

	# — S8 Tobias —
	"tobias_warn": "tobias/t_choice — His Company Or The Corner",
	"tobias_lindner": "main steps 15–17 — you knew whose money was under the fund",
	"tobias_digging": "main step 17 — the lever: he finds the break clause from the inside",
	"tobias_warned": "S8 winter — Belonging Is Paid In Care",
	"tobias_invited": "S8 winter — Belonging Is Paid In Care: he came, and came alone",
	"tobias_gouged": "S8 winter — His Company Or The Corner: you priced him once, and he remembers",
	"took_fund": "main steps 15–17 — the fund's strings close around the corner",

	# — S9 Nadia —
	# Same split as Karim: her beat chain's gates (`nadia_at_the_counter`, `nadia_never_asked`,
	# `nadia_doubles_seen` / `nadia_doubles_hidden`, `nadia_counted`, `nadia_leo_night`,
	# `nadia_asked_out_loud`) are kind 1 and have no rows. These are the step trees' flags.
	"nadia_tab": "S9 winter — Childcare Falls Through Mid-Shift",
	"nadia_seen": "S9 winter — It Takes A Kiez: she can only ask if she has been seen",
	"nadia_held": "S9 winter — It Takes A Kiez: the wall stayed shut",
	"nadia_offered": "S9 winter — It Takes A Kiez: you left the choice with her",
	"nadia_kid": "S9 spring — Leo Does Homework On The Crate",
	"nadia_open_at_four": "S9 spring — Leo Does Homework On The Crate",
	# summer step 2, `nadia_s2` — She Never Asks
	"nadia_three_minutes": "S9 winter — It Takes A Kiez: the offer she refused all summer is the one she takes",
	"nadia_porter_coffee": "S9 spring — Leo Does Homework On The Crate: the porter turns up on the rota",
	"nadia_asked_once": "S9 winter — It Takes A Kiez: somebody offered until it stopped being a favour",
	# autumn step 3, `nadia_a3` — The Doubles Stack Up
	"nadia_doubles": "S9 winter — Childcare Falls Through Mid-Shift: the week that had no slack left in it",
	"nadia_rota": "S9 winter — It Takes A Kiez: the rota goes on the fridge because you asked about it",
	"nadia_slept_here": "S9 winter — It Takes A Kiez: she has already let this counter hold her once",
	# autumn step 4, `nadia_a4` — Counting Coins At The Till
	"nadia_counted_twice": "S9 winter — It Takes A Kiez: you saw the second count and said nothing about it",
	"nadia_short": "S9 spring — Leo Does Homework On The Crate: the tab she never calls a tab",
	"nadia_no_charity": "S9 winter — It Takes A Kiez: asking is only possible because it was never charity",
	# winter step 5, `nadia_w5` — Childcare Falls Through Mid-Shift
	"nadia_leo_here": "S9 spring — Leo Does Homework On The Crate: the crate was his before it was Thursdays",
	"nadia_coldest": "main step 19 — the Kiezversammlung: what 'open at four' is actually for",
	"nadia_back_at_seven": "S9 winter — It Takes A Kiez: she came back at seven and it did not cost her anything",
	# winter step 6, `nadia_w6` — It Takes A Kiez
	"nadia_said_it": "S9 spring — Leo Does Homework On The Crate: she asked out loud and Thursday exists",
	"nadia_rota_pinned": "S9 spring — Leo Does Homework On The Crate: four names on the fridge by Friday",
	"nadia_mehmet_drives": "main step 19 — the Kiezversammlung: the web has other people in it now",
	# spring step 7, `nadia_p7` — Leo Does Homework On The Crate
	"nadia_crate_desk": "Finale — the Kiez epilogue: the corner raised another one",
	"nadia_thursdays": "Finale — the Kiez epilogue: half four on a Thursday, for as long as the corner lasts",
	"nadia_leo_reads": "Finale — the Kiez epilogue: he does change from two euro faster than the till",

	# — S10 Robin —
	# Their beat chain's gates (`robin_at_the_counter`, `robin_name_written`, `robin_call_heard` /
	# `robin_call_private`, `robin_orbiting`, `robin_heartbreak`, `robin_chosen`) are kind 1 and have
	# no rows here. Below are the step trees' flags.
	"robin_safe": "robin/r_battle — Chosen Family Is Real And It's Here",
	"robin_name": "S10 winter — Chosen Family Is Real And It's Here",
	"robin_crate": "S10 autumn — Orbiting The Light",
	"robin_rolled": "S10 autumn — Orbiting The Light",
	"robin_summer": "S10 winter — First Heartbreak, 2am, Your Counter",
	# summer step 2, `robin_s2` — The Name They Use Now
	"robin_fridge_name": "S10 winter — Chosen Family Is Real And It's Here: the fridge was the first list",
	"robin_bank_card": "S10 autumn — A Call Home: whose account the money still comes out of",
	"robin_said_it_back": "S10 winter — Chosen Family: you are on the list because you said it out loud",
	# autumn step 3, `robin_a3` — A Call Home
	"robin_call_home": "S10 winter — Chosen Family Is Real And It's Here: the forty-minute call answers this one",
	"robin_forty_seconds": "S10 winter — First Heartbreak: the gummi bears they buy when it has gone wrong",
	"robin_not_the_summer": "S10 spring — They Bring The Crew: the train ticket that was never booked again",
	# autumn step 4, `robin_a4` — Orbiting The Light
	"robin_pavement": "S10 spring — They Bring The Crew: the bench is the thing a keypad has no line for",
	"robin_bench_shift": "S10 spring — They Bring The Crew: four of them on a bench built for three",
	"robin_taught_roll": "S10 spring — They Bring The Crew: they roll for the whole bench now, badly",
	# winter step 5, `robin_w5` — First Heartbreak, 2am, Your Counter
	"robin_free_gummi": "S10 winter — Chosen Family Is Real And It's Here: nobody made a thing of it",
	"robin_six_weeks": "S10 spring — They Bring The Crew: one of the four is from that Thursday night",
	"robin_stayed_open": "main step 19 — the Kiezversammlung: the night the shop did not close at three",
	# winter step 6, `robin_w6` — Chosen Family Is Real And It's Here
	"robin_short_list": "S10 spring — They Bring The Crew: the list walks in through the door",
	"robin_named_us": "Finale — the Kiez epilogue: the Späti is fourth on a list of five",
	"robin_stayed_berlin": "Finale — the Kiez epilogue: they stayed, and the corner is the reason",
	# spring step 7, `robin_p7` — They Bring The Crew
	"robin_crew": "Finale — the Kiez epilogue: the safest light on the street, with four people under it",
	"robin_bench_four": "Finale — the Kiez epilogue: the bench is public, free and unbuyable",
	"robin_shift": "Finale — the Kiez epilogue: they work the odd Saturday and know the wall",

	# — S4 Aylin —
	"aylin_named_it": "S4 winter — The Magic Was Each Other",
	"aylin_bench": "S4 winter — The Magic Was Each Other",
	"aylin_bench_talk": "S4 winter — The Magic Was Each Other",
	"aylin_bring_jonas": "S4 spring — They Come At Eight In The Evening Now",
	"aylin_lighter_jar": "S4 spring — They Come At Eight In The Evening Now: the jar is still there",
	"aylin_fence": "main step 17 — the lever: the fence notice on the door",

	# — S13 Herr Bley —  (`bley_tip` is a REAL gate: bley/b_patron.requires_flag)
	"bley_lindner": "main step 17 — the lever: you know which desk signed it",
	"bley_seen": "S13 spring — A Quiet Patron",

	# — S8 Tobias, the seven-step arc (`tobias_s2` … `tobias_p7`). `tobias_tipped`, `tobias_destination`,
	#   `tobias_fund_offered`, `tobias_colleagues`, `tobias_chose` and `tobias_cared` are NOT here: each
	#   is a real `requires_flag` on the next step's beat, which is kind 1 and needs no declaration.
	"tobias_notes": "S8 autumn — The Kiez Fund: the man who writes the pitch down also writes the fund down",
	"tobias_kept_the_sign": "S8 winter — Belonging Is Paid In Care: the sign he was told to leave alone",
	"tobias_wine_night": "S8 autumn — He Brings Six Colleagues: the wine night is what the six turn up for",
	"tobias_rent_index": "main step 17 — the lever: he was told what a destination does to a rent index",
	"tobias_alone_named": "S8 winter — Belonging Is Paid In Care: he came alone, because you asked him to",
	"tobias_asked_whose": "main step 17 — the lever: you made him name the money before he could hear it",
	"tobias_wrote_it_down": "S8 winter — His Company Or The Corner: the Pfand receipt with the entity on it",
	"tobias_fund_refused": "S8 spring — Throws In: refusing the grant is what leaves him free to sign",
	"tobias_fund_strings": "S8 winter — His Company Or The Corner: clause four is the break clause in miniature",
	"tobias_read_aloud": "S8 spring — Throws In: a man who has read it out loud once can do it again",
	"tobias_six_late": "S9 winter — Childcare Falls Through Mid-Shift: an hour past close costs the 04:00 coffee",
	"tobias_six_stayed": "S8 spring — Throws In: the night the corner was his and he stayed inside it",
	"tobias_six_fair": "main step 19 — the Kiezversammlung: the street saw you hold the prices",
	"tobias_six_priced": "S8 winter — His Company Or The Corner: you priced him once, and he remembers",
	"tobias_crate_moved": "S2 winter — The Night He Doesn't Come: whose crate that is, and who said so",
	"tobias_told_plainly": "S8 spring — Throws In: he was told plainly once, with nobody else in the shop",
	"tobias_break_clause": "main step 17 — the lever: the March date, from inside the company it pays",
	"tobias_asked_not_to_sign": "S8 spring — Throws In: you asked him not to sign, months before the letter",
	"tobias_has_the_words": "S8 spring — Throws In: the sentence he can say to a board",
	"tobias_signed_anyway": "main steps 15–17 — the landlord-relations letter carries his name",
	"tobias_care_shift": "S8 spring — Throws In: three weeks of crates nobody was supposed to notice",
	"tobias_did_the_round": "S5 spring — The Corner's Memory: Christa saw who cleared her pavement",
	"tobias_learned_a_name": "S5 spring — The Corner's Memory: he says Christa, and he gets it right",
	"tobias_belongs": "S8 spring — Throws In: what the desk with no window bought him",
	"tobias_pen": "S8 spring — Throws In: he brought his own pen and waited to be asked",
	"tobias_signed_letter": "main step 19 — the Kiezversammlung: forty-two names on the tenants' letter",
	"tobias_leipzig": "Finale — the epilogue is a postcard from Leipzig",

	# — S4 Aylin, the seven-step arc (`aylin_s2` … `aylin_p7`). `aylin_sunday`, `aylin_plans`,
	#   `aylin_jonas_two`, `aylin_one_more`, `aylin_leipzig` and `aylin_magic` are real `requires_flag`
	#   gates on the following beat (kind 1), so they are deliberately absent from this table.
	"aylin_lighter_count": "S4 spring — They Come At Eight In The Evening Now: the jar started as a joke about counting",
	"aylin_bench_service": "S4 autumn — One More Season Of Sundays: the bench became table service that morning",
	"aylin_van": "S4 autumn — One More Season Of Sundays: the van fund has not moved since August",
	"aylin_rent_slip": "S4 autumn — Jonas Isn't With Her: the rent she got wrong is the flat he left",
	"aylin_portugal": "S4 winter — The Magic Was Each Other: the bar was always the exit plan",
	"aylin_bar_real": "S4 winter — The Magic Was Each Other: she was asked which plan was the real one",
	"aylin_sundays_named": "S4 winter — The Magic Was Each Other: the bar is for if the Sundays stop",
	"aylin_sat_with_her": "S4 spring — They Come At Eight In The Evening Now: somebody sat out the crash with her",
	"aylin_second_bag": "S4 winter — The Job In Leipzig: the bag she still orders for",
	"aylin_asked_after_him": "S4 winter — The Magic Was Each Other: you asked after Jonas before she could",
	"aylin_march_contract": "S4 winter — The Job In Leipzig: the theatre contract is why two o'clock happened",
	"aylin_bench_both_ends": "S4 spring — They Come At Eight In The Evening Now: both ends of the bench, in writing",
	"aylin_call_tuesday": "S4 winter — The Magic Was Each Other: the four hours on the floor started with a Tuesday",
	"aylin_running_the_rig": "S4 winter — The Magic Was Each Other: every channel up, for one dead input",
	"aylin_bench_heater": "S4 spring — They Come At Eight In The Evening Now: the heater that made it a winter bench",
	"aylin_season_promise": "S4 winter — The Job In Leipzig: one more season, and it had a date on it",
	"aylin_van_stalled": "S4 winter — The Job In Leipzig: what she was actually saving for",
	"aylin_club_sold": "main step 15 — the same operator and the same tidy structure, one street over",
	"aylin_asked_the_room": "S4 winter — The Job In Leipzig: who gets the bookings when a room shuts",
	"aylin_one_more_named": "S4 winter — The Job In Leipzig: the end of the bench that is not hers",
	"aylin_leipzig_offer": "S4 winter — The Magic Was Each Other: the offer was hers as well",
	"aylin_told_her_go": "S4 spring — They Come At Eight In The Evening Now: you costed it and said go",
	"aylin_told_her_stay": "S4 spring — They Come At Eight In The Evening Now: you told her to stay, and she did",
	"aylin_costed_it": "S4 spring — They Come At Eight In The Evening Now: twenty-nine euro on the early train",
	"aylin_objects": "main step 19 — the Kiezversammlung: the bench objection, and who wrote it",
	"aylin_tells_you_first": "S4 winter — The Magic Was Each Other: she said she would tell you first, and did",
	"aylin_two_lighters": "S4 spring — They Come At Eight In The Evening Now: the jar behind the till",
	"aylin_jonas_came": "S4 spring — They Come At Eight In The Evening Now: he comes inside now",
	"aylin_magic_named": "S4 spring — They Come At Eight In The Evening Now: said out loud, on your counter",
	"aylin_jonas_said_it": "S4 spring — They Come At Eight In The Evening Now: he said it first, holding a kettle",
	"aylin_bench_stays": "main step 19 — the Kiezversammlung: a bench is a line item nobody costed",
	"aylin_seven_am": "S9 spring — Leo Does Homework On The Crate: a seven o'clock Sunday opens the door wider",
	"aylin_ring": "Finale — a registry office on a Tuesday, with two witnesses off the street",
	"aylin_witnesses": "S3 spring — Deniz Comes For The Versammlung: Mehmet stood as one of the two",
	"aylin_bench_saved": "main step 19 — the Kiezversammlung: the hoarding stopped eleven metres short",
	"aylin_jar_kept": "Finale — the jar of lighters is what the corner keeps of her",
	"aylin_evening_sundays": "Finale — the epilogue's eight in the evening, not eight in the morning",
	"aylin_subsidy": "S9 spring — Leo Does Homework On The Crate: the evening Sunday pays for the 03:40",
	"aylin_still_a_lighter": "Finale — and they still buy a lighter",

	# — S13 Herr Bley, the seven-step arc (`bley_s2` … `bley_p7`). `bley_water`, `bley_youngman`,
	#   `bley_eleven`, `bley_page_eleven` and `bley_talks` are real `requires_flag` gates on the beats
	#   that follow them (kind 1), as is `bley_tip` on `bley/b_patron`.
	"bley_name_offered": "S13 autumn — He Stays Eleven Minutes: he learns your name the week after you offer it",
	"bley_armour_seen": "S13 winter — The Armour Comes Off: you saw the wall while it was still standing",
	"bley_chocolate_gift": "S13 winter — Somebody Saw Him: the chocolate you never charged him for",
	"bley_friday_chocolate": "S13 winter — The Armour Comes Off: the Friday it used to be bought for",
	"bley_used_to": "S13 winter — The Armour Comes Off: the tense he let slip and covered",
	"bley_asked_something": "S13 winter — Somebody Saw Him: a question that was not about a price",
	"bley_waits_for_empty": "S13 winter — Somebody Saw Him: he waits in the car until the shop is quiet",
	"bley_answered_properly": "S13 spring — A Quiet Patron: you answered him properly, once, at three",
	"bley_house": "S13 winter — The Armour Comes Off: four bedrooms and one person in them",
	"bley_uncovered": "S13 winter — The Armour Comes Off: the ordinary sentence was not allowed to cover it",
	"bley_crate_offered": "S13 spring — A Quiet Patron: the crate first, and eventually the cushion",
	"bley_stayed_late": "S13 spring — A Quiet Patron: the nights you stayed open past four for him",
	"bley_told_him": "main step 17 — the lever: he was told whose street he was standing in",
	"bley_read_it_back": "main step 17 — the lever: the structure read back to the man who signed it",
	"bley_wrote_it": "main step 17 — the lever: six characters on a Pfand receipt with no name on it",
	"bley_kept_quiet": "S13 spring — A Quiet Patron: you never once said where it came from",
	"bley_car": "S13 winter — Somebody Saw Him: an hour and eleven minutes with the engine off",
	"bley_coffee": "S13 spring — A Quiet Patron: a coffee he did not order and did not refuse",
	"bley_armour_off": "S13 winter — Somebody Saw Him: the night it came off, and who was standing there",
	"bley_sat_down": "S13 spring — A Quiet Patron: the first time he sat down in a shop",
	"bley_audit": "S13 spring — A Quiet Patron: an audit is a list of what is actually there",
	"bley_did_the_list": "S13 spring — A Quiet Patron: he made the list before he wrote the cheque",
	"bley_tomorrow": "S13 winter — Somebody Saw Him: eleven nights away, and he came back to the minute",
	"bley_kept_the_time": "S13 spring — A Quiet Patron: 03:10, to the minute, for a year",
	"bley_asked_after": "S13 spring — A Quiet Patron: the greengrocer asked after him, in a shop, to his face",
	"bley_three_coffees": "S9 spring — Leo Does Homework On The Crate: the night the 03:40 and the 03:10 overlapped",
	"bley_asked_the_number": "S13 spring — A Quiet Patron: he needed it to be a transaction to be able to ask",
	"bley_not_a_number": "S13 spring — A Quiet Patron: it was never a number, and he was told so",
	"bley_nearly_didnt": "Finale — the envelope he very nearly did not hand over",
	"bley_patron": "Finale — the retainer: still anonymous, still paid, never mentioned",
	"bley_exposure": "Finale — what it costs him if that transfer is ever traced back",
	"bley_keeps_coming": "Finale — you sent the money back and he kept coming at three anyway",
	"bley_said_why": "Finale — the one unguarded clause of the year, said once, at speed",
	"bley_said_you": "Finale — you people became you, and then became four of us",
	"bley_has_a_chair": "Finale — the cushion on Jürgen's crate that nobody has admitted to",
	"bley_night_watch": "S2 spring — Night-Watch: the corner opens at three because two men needed it to",

	# — S1 Lena, the seven-step arc (`lena_a3` … `lena_p7`). The BEAT chain's own gate flags
	#   (`lena_tab_open`, `lena_saw_work`, `lena_gallerist`, `lena_studio_nights`, `lena_show_done`,
	#   `lena_let_in`) are kind-1 readers — a real `requires_flag` on the next beat — so they are
	#   deliberately absent from this table. Everything below is a colour flag a later STEP reads.
	"lena_gallerist_told": "S1 winter — The Show: she told you about Mitte before she told the studio",
	"lena_kept_faith": "S1 winter — The Show: you asked after the kitchen, so the ninth canvas is in the bag",
	"lena_made_it_sellable": "S1 winter — The Show: you sent her to paint eight flowers and she painted eight",
	"lena_contract_copy": "S1 winter — The Show: sixty percent in writing is what she takes to the hanging",
	"lena_tab_deep": "S1 winter — Help Isn't Failing: eleven lines is the number she has to say out loud",
	"lena_open_at_four": "S1 spring — The Wall: she paints from two until it gets light because the door is open",
	"lena_radiator": "S1 winter — The Show: a studio she can feel her hands in is eight canvases, not three",
	"lena_came_to_show": "S1 winter — Help Isn't Failing: you were in the room when the kitchen sold",
	"lena_show_honest": "S1 spring — The Wall: the honest piece hung, so the wall is the next honest piece",
	"lena_show_flowers": "S1 spring — The Wall: she hung eight flowers, and the wall is what she owes herself",
	"lena_asked_for_help": "S1 spring — The Wall: asking out loud once is what makes the giving possible",
	"lena_honest_is_work": "S1 spring — The Wall: the true one is the one that sold, and she believes it now",
	"lena_tab_wiped": "S1 spring — The Wall: a clean door is why the mural is a gift and not a payment",
	"lena_mural": "Finale — the corner's epilogue: whose wall the last night is photographed against",
	"lena_signed_it": "Finale — the corner's epilogue: your hand is in the bottom right of her wall",
	"lena_gives_now": "main step 19 — the Kiezversammlung: four art-school posters, done for nothing",

	# — S2 Jürgen, the seven-step arc (`juergen_s2` … `juergen_p7`). Gate flags `juergen_counted`,
	#   `juergen_crate_out`, `juergen_route_cut`, `juergen_cold_read`, `juergen_came_back` and
	#   `juergen_bench_his` are kind-1 and are not declared here.
	"juergen_crate_out_front": "S2 autumn — The Chain Locks Its Bins: a crate he can reach is the route's last stop",
	"juergen_written": "S2 winter — Seen: the card on the crate is where MASSEK eventually gets written",
	"juergen_named": "S2 winter — Seen: he gave you the surname first, months before the rest of it",
	"juergen_chain": "S2 autumn — Not A Winter Jacket: three euro a night is the jacket he cannot replace",
	"juergen_new_route": "S2 winter — The Night He Doesn't Come: four doors is why he is still out at all",
	"juergen_jacket": "S2 winter — The Night He Doesn't Come: a coat is two nights of January survived",
	"juergen_refused_coat": "S2 winter — The Night He Doesn't Come: he said no, and the cough is the bill",
	"juergen_hof": "S2 winter — Seen: the bench inside the door replaces an outlet that goes off at eleven",
	"juergen_doctor": "S2 spring — Night-Watch: the chest cleared, which is why there is a spring at all",
	"juergen_slept_in": "S2 winter — Seen: he sat down once, in front of people, and nothing bad happened",
	"juergen_first_name": "S2 spring — Night-Watch: the sentence he finished is why he negotiates a wage",
	"juergen_seen": "S2 spring — Night-Watch: a man nobody looks at does not label a stranger's phone",
	"juergen_watch": "main step 17 — the lever: the Kombi, the plates and the clipboard at 03:40",
	"juergen_weather": "Finale — the corner's epilogue: the forecast the street trusts over the app",
	"juergen_wage": "Finale — the corner's epilogue: the only job he ever negotiated himself",

	# — S3 Mehmet, the seven-step arc (`mehmet_s2` … `mehmet_p7`). Gate flags `mehmet_letter`,
	#   `mehmet_cem_week`, `mehmet_umlage`, `mehmet_doors_done`, `mehmet_mirror` and `mehmet_legacy`
	#   are kind-1 and are not declared here.
	"mehmet_usual": "S3 winter — You're Becoming Them: you knew the order, which is why the price hurts",
	"mehmet_deniz_calls": "S3 winter — Legacy Is People: the Sunday calls stopped being Sunday calls",
	"mehmet_cem_story": "S3 spring — Deniz Comes For The Versammlung: Cem's week is the shape of the night",
	"mehmet_not_alone": "S3 autumn — Knock On Every Door: nobody on this street signs anything alone",
	"mehmet_tomatoes": "S3 spring — Deniz Comes For The Versammlung: two crates going round a courtyard",
	"mehmet_eleven": "S3 autumn — Knock On Every Door: the number he says out loud to forty people",
	"mehmet_lawyer": "S3 winter — Legacy Is People: elf ist falsch, in a lawyer's handwriting this time",
	"mehmet_hausversammlung": "main step 19 — the Kiezversammlung: the Haus turns out because he knocked",
	"mehmet_first": "S3 winter — You're Becoming Them: whose name went on the letter, and who let it",
	"mehmet_mirror_taken": "S3 winter — Legacy Is People: he asks you to stand up because you took the telling",
	"mehmet_priced_them": "S3 winter — Legacy Is People: he asked once, and you had already answered",
	"mehmet_deniz_visit": "S3 winter — Legacy Is People: the spreadsheet arrives because the boy did",
	"mehmet_deniz_in": "S3 spring — Deniz Comes For The Versammlung: he came inside the shop once",
	"mehmet_legacy_people": "Finale — the corner's epilogue: the worse table, and the true one",
	"mehmet_keys": "main step 19 — the Kiezversammlung: both shops shut, sign on both doors",
	"mehmet_deniz_came": "Finale — the corner's epilogue: the 18:04, booked on Tuesday, and the fifth chair",
	"mehmet_stood": "Finale — the corner's epilogue: four sentences, and his hands shaking after",
}
