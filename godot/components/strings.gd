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
const SERVE_PANEL := "SERVE"
const NOBODY_WAITING := "no one waiting"
const WANT_LINE := "%s: %s"                     # who is waiting: what they asked for
const ORDER_LINE := "%s, please."               # the plain order when no beat is pending
const SOMEONE := "Someone"                      # a customer with neither a name nor an archetype

# ── the till ─────────────────────────────────────────────────────────────────────────────────
const TILL := "Till"
const TILL_EMPTY := "nothing picked yet"
const TILL_MORE := "+%d more"
const TILL_PFAND_ROW := "Pfand %d × %s"         # bottles × the rate the reducer pays
const TOTAL := "Total"
const RING_UP := "Ring up"
const PFAND := "Pfand"
const WAVE_OFF := "Wave off"

# ── the HUD (one compact line per corner) ────────────────────────────────────────────────────
const HUD_NIGHT := "Night %d"
const HUD_QUEUE := "%d waiting"
const HUD_SEP := "·"

# ── manage (the hour before opening) ─────────────────────────────────────────────────────────
const MANAGE_TITLE := "Späti — night %d, %s"    # the weekday stays German
const MANAGE_SECTION := "RESTOCK · PRICES"
const MANAGE_MODULES := "MODULES"
const MANAGE_OWNED := "owned"
const OPEN_UP := "Open up"
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
