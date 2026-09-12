extends Control
## Throwaway: renders the same string in every Jersey face at several sizes so an operator can LOOK at
## which size a face is actually drawn for. Not game code; capture it with tools/godot/shot.mjs.

const FACES := {
	"J25": "res://assets/fonts/Jersey25-Regular.ttf",
}
const SAMPLE := "SPÄTI 8B KIEZ"

func _ready() -> void:
	var y := 2
	for key in FACES:
		var ff := load(FACES[key]) as FontFile
		ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		ff.hinting = TextServer.HINTING_NONE
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		for s in [12, 16, 20, 25, 50]:
			var l := Label.new()
			l.text = "%s@%d %s" % [key, s, SAMPLE]
			l.add_theme_font_override("font", ff)
			l.add_theme_font_size_override("font_size", s)
			l.position = Vector2(2, y)
			add_child(l)
			y += s + 3
			if y > 268:
				return
