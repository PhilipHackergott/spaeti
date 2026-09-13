extends "res://tests/TestCase.gd"
## `components/strings.gd` is THE string table: every user-facing word the UI writes lives there.
## This is what keeps that true — it greps the screens and the pool for the words that used to be
## typed straight into a scene, and it checks the table itself against the language decision in
## `game-design-document.md` (English base, German only for the Kiez's own nouns and the weekdays).

## Chrome words that were hard-coded before the table existed. Any of them reappearing in a screen or
## a component means someone wrote a label instead of adding a constant.
const STRAY_WORDS := [
	"Umsatz", "Trinkgeld", "Einkauf", "Gewinn", "Kasse", "Weiter", "Laden", "Kunde",
	"no one waiting", "Nacht %d", "Ring up", "Wave off", "Open up", "New game",
]

## The German that STAYS: the Kiez says these words and translating them would be the wrong move.
const KEPT_GERMAN := ["Späti", "Pfand", "Kiez", "Kiez-Trust"]

## No CODE sets a label to a literal. `.tscn` placeholders are exempt on purpose: docs/01 wants the
## node tree to show reality in the editor, and every one of them is overwritten by `render()`.
func test_no_screen_or_component_writes_a_ui_word() -> void:
	for path in _sources():
		if not path.ends_with(".gd") or path.ends_with("/strings.gd"):
			continue
		for line in _code_lines(path):
			assert_false(line.contains('text = "'), "%s sets a label to a literal: %s" % [path, line])
			for word in STRAY_WORDS:
				assert_false(line.contains('"%s' % word), "%s writes '%s' instead of asking Strings" % [path, word])

## Source lines with the comments (and the doc comments) taken out, so prose about a word is not
## mistaken for the word.
func _code_lines(path: String) -> Array[String]:
	var out: Array[String] = []
	for raw in _read(path).split("
"):
		var line := String(raw).strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var hash_at := line.find("#")
		out.append(line.substr(0, hash_at) if hash_at > 0 else line)
	return out

## Every word a screen asks for has to exist and to say something. (Named one by one on purpose:
## `Strings` is a constants-only RefCounted, so there is no dictionary to iterate — and naming them
## means a constant that is deleted breaks this test instead of silently emptying a button.)
func test_the_table_holds_the_words_the_ui_needs() -> void:
	for value in [Strings.NEW_GAME, Strings.CONTINUE, Strings.SETTINGS, Strings.QUIT, Strings.SERVE, Strings.CLOSE,
			Strings.SERVE_PANEL, Strings.RING_UP, Strings.WAVE_OFF, Strings.PFAND, Strings.TOTAL,
			Strings.TILL_EMPTY, Strings.OPEN_UP, Strings.CASH, Strings.NEXT_DAY, Strings.SUMMARY_TITLE,
			Strings.TALLY_REVENUE, Strings.TALLY_TIPS, Strings.TALLY_PURCHASES, Strings.TALLY_BILLS,
			Strings.TALLY_PFAND, Strings.TALLY_PROFIT, Strings.ORDER_LINE, Strings.NOBODY_WAITING,
			Strings.MANAGE_SECTION, Strings.MANAGE_MODULES, Strings.MANAGE_OWNED, Strings.MANAGE_STANDING,
			Strings.WHOLESALE]:
		assert_true(String(value).strip_edges() != "", "the table has a word here, not an empty string")
	# The format strings must still have their slot, or the caller's `%` silently drops the number.
	assert_true(Strings.CASH.contains("%s"), "CASH takes the amount")
	assert_true(Strings.SUMMARY_TITLE.contains("%d"), "SUMMARY_TITLE takes the night")
	assert_true(Strings.ORDER_LINE.contains("%s"), "ORDER_LINE takes the product")
	assert_true(Strings.MANAGE_TITLE.contains("%d") and Strings.MANAGE_TITLE.contains("%s"), "MANAGE_TITLE takes night + weekday")

## English base, German flavour. "Späti" and "Pfand" stay; the verbs do not.
func test_the_language_decision_holds() -> void:
	assert_eq(Strings.WORDMARK, "SPÄTI", "the wordmark is the German noun")
	assert_true(Strings.PFAND.begins_with("Pfand"), "the deposit keeps its German name")
	assert_eq(Strings.NEW_GAME, "New game", "the menu verbs are English")
	assert_eq(Strings.OPEN_UP, "Open up", "so is the button that starts a night")
	assert_true(Strings.SUBTITLE.contains("Kiez"), "the subtitle keeps the Kiez")

## The two composed lines are built here so the separators cannot drift between corners.
func test_the_composed_lines_read_as_sentences() -> void:
	assert_eq(Strings.hud_line(3, 2), "Night 3 · 2 waiting", "the HUD line")
	assert_eq(Strings.hud_line(1, 0), "Night 1", "an empty queue says nothing")
	assert_eq(Strings.summary_sub("Mittwoch", 23, 3, 2), "Mittwoch · 23 sold · 3 missed · Kiez +2", "the summary sub-line")
	# The weekday in that line is the engine's word, never one this table invents.
	assert_true(Rules.WEEKDAY_NAMES.has("Mittwoch"), "and it is a weekday the engine names")

func _sources() -> Array[String]:
	var out: Array[String] = []
	for folder in ["res://scenes", "res://components"]:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		for file in dir.get_files():
			if file.ends_with(".gd") or file.ends_with(".tscn"):
				out.append(folder + "/" + file)
	return out

func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text()
	f.close()
	return text
