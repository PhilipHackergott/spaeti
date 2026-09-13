class_name Season
extends RefCounted
## The year the arcs are keyed to (docs/05 §11, docs/06 §8, docs/09 §2).
##
## `config.season_days` is split into FOUR equal quarters — summer, autumn, winter, spring — and
## Truby's seven steps are laid across them: **summer 1-2 · autumn 3-4 · winter 5-6 · spring 7**.
## That 2/2/2/1 split is written in exactly one place (`STEPS`) and everything else derives from it.
##
## PURE and dependency-free: every function takes `(day, season_days)` (or a whole state, which is the
## same two numbers) and returns a String or an int. The reducer, the content registry, StoryFlow and
## the tests therefore all read ONE calendar — the failure this file exists to prevent is two of them
## disagreeing about what month it is while both look right on their own.

## Registry order IS chronological order: `index_of` is what "has the calendar reached this yet" asks.
const NAMES: Array[String] = ["summer", "autumn", "winter", "spring"]

## One letter per season, and it is the letter a seasonal tree id wears (`lena_s2`, `achim_a3`).
## `s` is summer's, so SPRING takes **`p`** — the two share an initial and two tree ids may not.
const LETTERS: Dictionary = {"summer": "s", "autumn": "a", "winter": "w", "spring": "p"}

## Which of the seven steps each season owns. THE ONLY PLACE the 2/2/2/1 split is written down.
const STEPS: Dictionary = {"summer": [1, 2], "autumn": [3, 4], "winter": [5, 6], "spring": [7]}

const FIRST_STEP: int = 1
const LAST_STEP: int = 7

static func count() -> int:
	return NAMES.size()

# ───────────────────────────── the calendar ─────────────────────────────

## Which quarter of the season `day` (1-based) falls in. Integer maths on purpose: a four-day season
## is one day per season rather than three days of nothing, and a day PAST the end (the reducer sets
## `phase = "end"` on `day > season_days`, and `Rules.view` still renders that state) clamps to spring
## instead of running off the table.
static func index_of_day(day: int, season_days: int) -> int:
	var span := maxi(1, season_days)
	return clampi((maxi(1, day) - 1) * NAMES.size() / span, 0, NAMES.size() - 1)

static func of_day(day: int, season_days: int) -> String:
	return NAMES[index_of_day(day, season_days)]

## The first calendar day of the i-th season — `ceil(i * season_days / 4) + 1`, which is what makes
## the quarters as even as an odd `season_days` allows.
static func first_day_of(index: int, season_days: int) -> int:
	var span := maxi(1, season_days)
	var i := clampi(index, 0, NAMES.size() - 1)
	return int(ceilf(float(i * span) / float(NAMES.size()))) + 1

## 1-based day WITHIN the current season — "day 3 of autumn", which is what a HUD prints and what a
## beat that wants "the first night of winter" reads.
static func day_in_season(day: int, season_days: int) -> int:
	return maxi(1, maxi(1, day) - first_day_of(index_of_day(day, season_days), season_days) + 1)

## How many days this season lasts, for the same reason `day_in_season` exists.
static func length_of(index: int, season_days: int) -> int:
	var i := clampi(index, 0, NAMES.size() - 1)
	var last := season_days + 1 if i == NAMES.size() - 1 else first_day_of(i + 1, season_days)
	return maxi(1, last - first_day_of(i, season_days))

## -1 for a string that is not a season, so a typo fails a comparison instead of passing one.
static func index_of(season: String) -> int:
	return NAMES.find(season)

static func is_season(season: String) -> bool:
	return index_of(season) >= 0

static func letter_of(season: String) -> String:
	return String(LETTERS.get(season, ""))

# ───────────────────────────── the seven steps ─────────────────────────────

## The season a Truby step belongs to — 1-2 summer, 3-4 autumn, 5-6 winter, 7 spring.
static func of_step(step: int) -> String:
	var n := clampi(step, FIRST_STEP, LAST_STEP)
	for season in NAMES:
		if (STEPS[season] as Array).has(n):
			return String(season)
	return NAMES[0]

## The last step a season owns — what "an arc that has caught up with the calendar" means.
static func last_step_of(season: String) -> int:
	var steps: Array = STEPS.get(season, [])
	return int(steps.back()) if not steps.is_empty() else FIRST_STEP

## THE ARC RULE (docs/06 §8). A step becomes due in its OWN season and stays due for ever after, which
## is exactly what lets an arc whose season passed unplayed catch up **one step per encounter** rather
## than skipping to whatever the date says. It is never due early: step 5 cannot play in summer.
static func step_is_due(step: int, season: String) -> bool:
	var now := index_of(season)
	return now >= 0 and now >= index_of(of_step(step))

# ───────────────────────────── over a whole state ─────────────────────────────

## `{}` and a state missing `config` both answer for the defaults rather than throwing: the registry's
## selector is handed a state by the reducer and an empty one by a content test.
static func season_days_of(s: Dictionary) -> int:
	return int((s.get("config", {}) as Dictionary).get("season_days", 28))

static func of_state(s: Dictionary) -> String:
	return of_day(int(s.get("day", 1)), season_days_of(s))

static func index_of_state(s: Dictionary) -> int:
	return index_of_day(int(s.get("day", 1)), season_days_of(s))

static func day_in_season_of_state(s: Dictionary) -> int:
	return day_in_season(int(s.get("day", 1)), season_days_of(s))
