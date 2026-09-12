extends SceneTree
## Row profile of a sprite: for every row, the number of opaque pixels and the first/last opaque
## column — the tool that finds a bust's counter line (the last wide row before the key takes over).
##   godot --headless --path . --script res://tools/rows.gd -- --in=path.png [--step=4]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var inp := ""
	var step := 4
	for a in args:
		if a.begins_with("--in="):
			inp = a.substr(5)
		elif a.begins_with("--step="):
			step = int(a.substr(7))
	if inp == "":
		printerr("need --in=")
		quit(2)
		return
	var img := Image.load_from_file(inp)
	if img == null:
		printerr("cannot load ", inp)
		quit(1)
		return
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	print("ROWS %dx%d" % [w, h])
	var last_wide := -1
	for y in range(0, h, step):
		var n := 0
		var first := -1
		var last := -1
		for x in w:
			if img.get_pixel(x, y).a > 0.5:
				n += 1
				if first < 0:
					first = x
				last = x
		if n > 0:
			print("y=%3d opaque=%3d x=%d..%d" % [y, n, first, last])
			if n > w / 2:
				last_wide = y
	print("LAST_WIDE_ROW %d" % last_wide)
	quit(0)
