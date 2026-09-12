extends SceneTree
## Headless image ops (no rendering needed) — tools/codex/art.mjs uses this to snap generated art to the pixel grid.
##   godot --headless --path godot --script res://tools/img.gd -- --in=C:/abs/raw.png --out=C:/abs/out.png --w=160 --h=200
##        [--mode=fit|exact|cover] [--filter=lanczos|bilinear|cubic|nearest] [--crop=16:9] [--alpha-threshold=0.5] [--trim=1]
## mode fit   = scale to fit inside w×h keeping aspect (sprites)   mode cover = fill w×h and crop the overflow (scene layers)
## mode exact = force w×h.   --crop=W:H first centre-crops the source to that aspect.   --trim=1 trims transparent margins.
## --alpha-threshold binarises alpha (hard pixel edges): a < t → 0 else 1.   Prints an "IMG ..." line; exit 0 on success.

func _init() -> void:
	var a := _args()
	var src: String = a.get("in", "")
	var dst: String = a.get("out", "")
	if src == "" or dst == "":
		printerr("img: need --in and --out")
		quit(2)
		return
	var img := Image.new()
	var err := img.load(src)
	if err != OK:
		printerr("img: cannot load %s (%d)" % [src, err])
		quit(3)
		return
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var sw := img.get_width()
	var sh := img.get_height()
	if a.has("crop"):
		var parts: PackedStringArray = String(a["crop"]).split(":")
		if parts.size() == 2:
			var ar := float(parts[0]) / float(parts[1])
			var cw := sw
			var ch := int(round(sw / ar))
			if ch > sh:
				ch = sh
				cw = int(round(sh * ar))
			img = img.get_region(Rect2i((sw - cw) / 2, (sh - ch) / 2, cw, ch))
			sw = cw
			sh = ch
	if int(a.get("trim", "0")) == 1:
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			img = img.get_region(used)
			sw = img.get_width()
			sh = img.get_height()
	var tw := int(a.get("w", str(sw)))
	var th := int(a.get("h", str(sh)))
	var mode: String = a.get("mode", "fit")
	var interp := Image.INTERPOLATE_LANCZOS
	match String(a.get("filter", "lanczos")):
		"nearest":
			interp = Image.INTERPOLATE_NEAREST
		"bilinear":
			interp = Image.INTERPOLATE_BILINEAR
		"cubic":
			interp = Image.INTERPOLATE_CUBIC
	if mode == "fit":
		var s := minf(float(tw) / sw, float(th) / sh)
		img.resize(maxi(1, int(round(sw * s))), maxi(1, int(round(sh * s))), interp)
	elif mode == "cover":
		var s := maxf(float(tw) / sw, float(th) / sh)
		var rw := maxi(1, int(round(sw * s)))
		var rh := maxi(1, int(round(sh * s)))
		img.resize(rw, rh, interp)
		img = img.get_region(Rect2i((rw - tw) / 2, (rh - th) / 2, tw, th))
	else:
		img.resize(tw, th, interp)
	if a.has("alpha-threshold"):
		var t := float(a["alpha-threshold"])
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				c.a = 0.0 if c.a < t else 1.0
				img.set_pixel(x, y, c)
	err = img.save_png(dst)
	print("IMG err=%d in=%dx%d out=%dx%d mode=%s file=%s" % [err, sw, sh, img.get_width(), img.get_height(), mode, dst])
	quit(0 if err == OK else 5)

func _args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var body := a.trim_prefix("--")
			var eq := body.find("=")
			if eq >= 0:
				d[body.substr(0, eq)] = body.substr(eq + 1)
			else:
				d[body] = "1"
	return d
