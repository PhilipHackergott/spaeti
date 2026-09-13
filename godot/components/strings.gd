class_name Strings
extends RefCounted
## THE string table. Every user-facing word the UI writes lives here and nowhere else — a scene or a
## component that needs text asks `Strings`, never a literal (`tests/unit/test_strings.gd` greps the
## pool and the screens for stray quoted words).
##
## LANGUAGE (game-design-document.md, confirmed by the orchestrator): the base is **English** for the
## chrome and every UI verb; German stays for the flavour nouns the Kiez actually says —
## Späti · Pfand · Kiez · Kiez-Trust · Sterni · Mate · Kippen · Schoki · Feierabend — and for the
## weekday names (`Rules.WEEKDAY_NAMES`, which the engine owns). PRODUCT names are the engine's
## (`engine/content/skus.gd`) and are never restated here.
##
## `%s` / `%d` slots are filled by the caller with `%` — the format strings live here so a translator
## sees the whole sentence, never half of it.

# ── title / shell ────────────────────────────────────────────────────────────────────────────
const WORDMARK := "SPÄTI"
const SUBTITLE := "one night in the Kiez"      # was "eine Nacht im Kiez" (orchestrator's review)
const NEW_GAME := "New game"
const CONTINUE := "Continue"
const SETTINGS := "Settings"
const QUIT := "Quit"
const VERSION := "vertical slice"

# ── pause + settings ─────────────────────────────────────────────────────────────────────────
const PAUSED := "Paused"
const RESUME := "Resume"
const BACK_TO_TITLE := "Back to title"
const REDUCE_MOTION := "Reduce motion"
const SETTINGS_NOTE := "Audio lands with the sound pass."

# ── the night ────────────────────────────────────────────────────────────────────────────────
const SERVE := "Serve"                          # the toggle that opens the shelf
const CLOSE := "Close"                          # ...the same plate, while the shelf is open
const SERVE_PANEL := "SERVE"
const NOBODY_WAITING := "no one waiting"
const WANT_LINE := "%s: %s"                     # who is waiting: what they asked for
const ORDER_LINE := "%s, please."               # the plain order when no beat is pending
const SOMEONE := "Someone"                      # a customer with neither a name nor an archetype
const CHOICE_NUMBER := "%d. %s"                 # how a dialogue choice is numbered
const STOCK_COUNT := "x%d"                      # how many of a SKU are on the shelf
const RESTRICTED := "18"                        # the age gate badge on a restricted SKU

# ── the register: the queue, the six stats, the checks (docs/06-dialogue-and-stats.md) ───
const NEXT_GUEST := "Next guest"                # take the first guest in line (talk_next)
const TALK_TO_GUEST := "Talk to them"           # the same intent with somebody already at the counter
const QUEUE_MORE := "+%d"                       # the overflow chip when the line is longer than the strip
const NUMBER := "%d"                            # a bare stat value
const MODIFIER := "%+d"                         # D&D 5e: floor((stat - 10) / 2), signed even at zero

## The six stats. The full names are what the player reads (docs/06 §1); the ids are the engine's
## (`state.player.stats`), and the order is the one every character sheet uses. The engine names them
## too (`Rules.STAT_NAMES`, for the reason it writes into a locked choice) — `test_scenes.gd::
## test_the_two_stat_tables_agree` is what stops the two from drifting apart.
const STAT_ORDER := ["str", "dex", "con", "int", "wis", "cha"]
## Späti-flavoured stat names (user decision, 2026-09-12): the ids stay D&D (str/dex/con/int/wis/cha), the
## words are the Kiez's — Muscle hauls crates, Hands work the till, Stamina is the 3-am shift, Brains reads
## the rent letter, Kiez Sense notices people, Schnauze (the Berliner Schnauze) talks them round.
const STAT_STRENGTH := "Muscle"
const STAT_DEXTERITY := "Hands"
const STAT_CONSTITUTION := "Stamina"
const STAT_INTELLIGENCE := "Brains"
const STAT_WISDOM := "Kiez Sense"
const STAT_CHARISMA := "Schnauze"
const STAT_NAMES := {
	"str": STAT_STRENGTH, "dex": STAT_DEXTERITY, "con": STAT_CONSTITUTION,
	"int": STAT_INTELLIGENCE, "wis": STAT_WISDOM, "cha": STAT_CHARISMA,
}

## A choice that ROLLS: "[Charisma 12]" beside the line, in the accent colour.
const CHECK_TAG := "[%s %d]"
## A choice that is GATED, not rolled: shown, greyed, and told why (docs/06 §2). Two forms, because
## the reason can come from either side of the contract — `LOCKED_NEEDS` is the sentence the UI
## composes when the view hands it the gate itself (`requires: {stat, min}`), and `LOCKED` frames
## `choice.reason` when the engine composed the words ("Strength 12 needed"). Either way the word
## "locked" is written HERE, so a greyed choice always opens the same way.
const LOCKED_NEEDS := "locked: needs %s %d"
const LOCKED := "locked: %s"
const CHECK_SUCCESS := "success"
const CHECK_FAILED := "failed"
## The d20 pop beside the dialogue box: "d20 14 + 2 = 16" over "vs 12 — success".
const DICE_PLUS := "d20 %d + %d = %d"
const DICE_MINUS := "d20 %d - %d = %d"
const DICE_VS := "vs %d — %s"

# ── the till ─────────────────────────────────────────────────────────────────────────────────
const TILL := "Till"
const TILL_EMPTY := "nothing picked yet"
const TILL_MORE := "+%d more"
const TILL_PFAND_ROW := "Pfand %d × %s"         # bottles × the rate the reducer pays
const TOTAL := "Total"
const RING_UP := "Ring up"
const PFAND := "Pfand"
## The head of the line, when their job fits beside their name ("Lena · painting student").
const QUEUE_WHO := "%s · %s"

static func queue_who(who: String, job: String) -> String:
	return QUEUE_WHO % [who, job]
const WAVE_OFF := "Wave off"

# ── the ring-up: the counter tray, the register, the tobacco wall (docs/08 §4) ───────────────
## The register is the till grown up: the same three verbs (Ring up · Pfand · Wave off, above) plus
## the two the counter adds — turning around to the wall, and asking for an ID before you sell.
const REGISTER := "Register"
const REGISTER_EMPTY := "nothing scanned yet"
const SUBTOTAL := "Subtotal"
const TURN_AROUND := "Turn around"
const WALL_BACK := "Back"
const CHECK_ID := "Check ID"
const ID_CHECKED := "ID checked"
const TRAY_EMPTY := "counter's clear"
const ORDER_EMPTY := "they haven't asked yet"
const IN_HAND := "In hand"
## A quantity, the way the whole pool already writes one (`STOCK_COUNT`): a lowercase x, because
## Jersey 10 has no × glyph and a missing glyph prints as a hole, not as a multiplication sign.
const QTY := "%dx"
## The row controls: a stepper pair and a delete. Symbols, not words — a 130-px register line has
## room for a name or for the word "Remove", never both.
const STEP_UP := "+"
const STEP_DOWN := "-"
const REMOVE := "x"
## The one free correction, when the reducer rejects a bad ring-up and does not say why itself.
const CORRECTION := "Check that again."
## …and what she actually says, by the bucket the reducer flagged (`view.register.correction_kind`,
## docs/08 §3.4). The REDUCER decides which bucket; the words are the table's, which is the rule for
## every other player-visible sentence in the game. One line each — the box is 264 px on the register
## screen and a second line covers the tray until it is dismissed.
const CORRECTION_BY_KIND := {
	"wrong_brand": "That's not the one, love. Look at the mark.",
	"extra": "I didn't take that one.",
	"missing": "There's something missing there.",
	"wrong_count": "Not that many — count them again.",
}

## How a customer asks for what she came in for (docs/08 §2, "How a customer phrases it"). The ENGINE
## composes these into `order[i].said` so the OrderCard, the talk graph and any test read one string
## and can never disagree; `Rules.ASK_*` mirrors the table because a pure reducer may not import a
## component, exactly as `Rules.STAT_NAMES` mirrors `STAT_NAMES`. `test_scenes.gd` pins the two.
## NOTE THE LOWERCASE x, the same one `QTY` uses: Jersey 10 has no × glyph and a missing glyph
## prints as a HOLE, not as a multiplication sign. `said` is a player-visible sentence, so it obeys
## the same rule the rest of the pool does.
const ASK_CIGS := "%dx %s — cigarettes."
const ASK_POUCH := "%dx %s — rolling tobacco."
## Everything that is not a pack or a pouch — papers, filters, and every non-tobacco line. The noun
## is the brand's own `spoken` phrase, which already carries the length and the gauge ("long Feder
## papers", "slim filters"). A template that re-split that into (length, kind) would have to re-derive
## words the catalogue already says, and would print "long long Feder papers" — docs/09 §1 rule 2.
const ASK_ITEM := "%dx %s."
const ASK_PFAND := "%dx Pfand."
## The `mark` speech tier: she points instead of naming. `%s` is `Content.brand_phrase` — the
## article-free logo phrase ("eagle", "fox"), because this template already carries the article.
const ASK_MARK_PHRASE := "the ones with the %s"
## …and how she points at a booklet or a box of filters, which carry no emblem to point at: the
## object itself is the answer ("the cream booklet", "the slim ones"), docs/09 §1 rule 1.
const ASK_POINT := "the %s"
const ASK_TAIL := "That's it."

# ── the HUD (one compact line per corner) ────────────────────────────────────────────────────
const HUD_NIGHT := "Night %d"
const HUD_QUEUE := "%d waiting"
const HUD_SEP := "·"

# ── manage (the hour before opening) ─────────────────────────────────────────────────────────
const MANAGE_TITLE := "Späti — night %d, %s"    # the weekday stays German
const MANAGE_SECTION := "RESTOCK · PRICES"
const MANAGE_MODULES := "MODULES"
const MANAGE_OWNED := "owned"
const MANAGE_STANDING := "YOUR CORNER"           # the standing panel: what the modules and the conversations made
const OPEN_UP := "Open up"
## The Ladenschluss gamble (GDD §4.9): a standing decision, so the plate says which way it is set.
## It is offered every manage hour because `legal_actions` is — the roll only happens on a Sonntag.
const SUNDAY_CLOSED := "Sonntag: shut"
const SUNDAY_OPEN := "Sonntag: open"
const MANAGE_HEAT := "Ordnungsamt attention %d"   # what the gamble has cost so far
const CASH := "Cash %s"
const WHOLESALE := "buy %s"                     # the wholesale price of one unit

# ── summary (the nightly P&L) ────────────────────────────────────────────────────────────────
const SUMMARY_TITLE := "Night %d settled"
const SUMMARY_SUB := "%s %s %d sold %s %d missed %s Kiez %+d"
const TALLY_REVENUE := "Revenue"
const TALLY_TIPS := "Tips"
const TALLY_PURCHASES := "Purchases"
const TALLY_BILLS := "Rent + power"
const TALLY_PFAND := "Pfand paid out"
const TALLY_PROFIT := "Profit"
const NEXT_DAY := "Next day"

# ── the season's end ─────────────────────────────────────────────────────────────────────────
const ENDING_TITLE := "The season is over"

## "Night 3 · 2 waiting" — the whole top-left HUD line, built in one place so the separators cannot
## drift between corners. The WEEKDAY is deliberately not here: at one text size (16) the corner
## cannot hold clock + cash + Pfand + weekday and still leave the right corner to the two meters.
## It is on the Manage modal's title and the Summary sub-line, which is where a day is planned anyway.
static func hud_line(day: int, queue: int) -> String:
	var out := HUD_NIGHT % day
	if queue > 0:
		out += " %s %s" % [HUD_SEP, HUD_QUEUE % queue]
	return out

## The summary's sub-line, with the separators kept out of the format string's way.
static func summary_sub(weekday: String, sold: int, missed: int, kiez_delta: int) -> String:
	return SUMMARY_SUB % [weekday, HUD_SEP, sold, HUD_SEP, missed, HUD_SEP, kiez_delta]

## The name the player reads for a stat id. An id the table does not know prints itself rather than
## an empty cell — a missing stat is a content bug you want to SEE, not one that silently vanishes.
static func stat_name(stat_id: String) -> String:
	return String(STAT_NAMES.get(stat_id, stat_id))

## "[Charisma 12]" — the tag a rolled choice carries in its own colour.
static func check_tag(stat_id: String, dc: int) -> String:
	return CHECK_TAG % [stat_name(stat_id), dc]

## "locked: needs Strength 12" — why a gated choice is greyed out, composed from the gate itself.
static func locked_reason(stat_id: String, min_value: int) -> String:
	return LOCKED_NEEDS % [stat_name(stat_id), min_value]

## "locked: Strength 12 needed" — the same sentence when the engine wrote the second half of it
## (`view.talk.choices[].reason`, docs/06 §4).
static func locked(reason: String) -> String:
	return LOCKED % reason

## "d20 14 + 2 = 16". The modifier is signed in the SENTENCE, not by a %+d slot, so a negative reads
## "d20 9 - 1 = 8" instead of the "9 + -1" a format slot would print.
static func dice_line(roll: int, mod: int, total: int) -> String:
	return (DICE_PLUS if mod >= 0 else DICE_MINUS) % [roll, absi(mod), total]

## "vs 12 — success".
static func dice_verdict(dc: int, success: bool) -> String:
	return DICE_VS % [dc, CHECK_SUCCESS if success else CHECK_FAILED]
