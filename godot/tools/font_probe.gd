extends Control
## The font probe. A pixel face is crisp ONLY at the sizes its own grid divides evenly, and which
## those are is not printed on the tin — so this renders the same sample in every face at every
## candidate size and an operator LOOKS at the result before choosing a size (docs/01 "Pixel
## discipline"). Not game code.
##   node tools/godot/shot.mjs --scene res://tools/FontProbe.tscn --out shots/fontprobe.png
## Findings so far: Jersey 10 is clean at 12/16/20/25/50 and broken at 10 ("KIEZ"->"HIEZ") and 14;
## at 12 the letters are right but the NUMBERS are not ("22:41"->"ZZ41"); Jersey 20 loses the middle
## of an 8 at 20; Jersey 25 is a caps-only display face and is perfect at 50.

const FACES := {
	"J10": "res://assets/fonts/Jersey10-Regular.ttf",
	"J20": "res://assets/fonts/Jersey20-Regular.ttf",
	"J25": "res://assets/fonts/Jersey25-Regular.ttf",
}
const SAMPLE := "KIEZ Mate 1,80 8B MODULES is it? Wasser"

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
