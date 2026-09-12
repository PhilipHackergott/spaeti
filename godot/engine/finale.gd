class_name Finale
extends RefCounted
## The ending + the tapestry (narrative-design §6b): the main ending is the frame, and every character
## you actually met and resolved gets the epilogue line written for that frame × their local outcome.
## Port of app/src/engine/finale.ts.

const ENDING_TEXT := {
	"institution": {
		"title": "An Institution",
		"line": "Solvent and beloved — the Späti is the heart of the Kiez, and you belong here. Cem would be proud.",
	},
	"held": {
		"title": "Held the Line",
		"line": "Scarred and a little broke, but the doors are open and the Kiez is intact. You stayed.",
	},
	"soldout": {
		"title": "Sold Out",
		"line": "You made the money. Cem's corner is someone else's show-flat now, and the nights are quiet wherever you are.",
	},
	"pushedout": {
		"title": "Pushed Out",
		"line": "The till ran dry and the lights went off.",
	},
}

## Which of the four frames this season earned. Resolves purely from {cash, integrity, kiez, outcome}.
static func main_ending(s: Dictionary) -> String:
	if float(s["cash"]) < 0.0:
		return "pushedout"
	var story: Dictionary = s["story"]
	var kiez := float(s["reputation"]["kiez"])
	if story["main_outcome"] == "sell" or float(s["reputation"]["integrity"]) < 40.0:
		return "soldout"
	if kiez >= 65.0 and (story["main_outcome"] == "stand" or kiez >= 78.0):
		return "institution"
	return "held"

static func resolve_finale(s: Dictionary) -> Dictionary:
	var ending := main_ending(s)
	var text: Dictionary = ENDING_TEXT[ending]
	var epilogues: Array = []
	for strand in Content.STRANDS:
		if strand["id"] == "main":
			continue  # the main arc IS the frame; it has no epilogue of its own
		var progress: Dictionary = s["story"]["strands"].get(strand["id"], {})
		if progress.is_empty() or progress["outcome"] == "":
			continue
		if not (s["story"]["met"] as Array).has(strand["character"]):
			continue
		var line: String = (strand["epilogue"] as Dictionary).get(ending, {}).get(progress["outcome"], "")
		if line != "":
			epilogues.append({"character": strand["character"], "line": line})
	return {
		"main": ending,
		"title": text["title"],
		"line": text["line"],
		"epilogues": epilogues,
	}
