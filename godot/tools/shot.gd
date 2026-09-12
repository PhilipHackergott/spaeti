extends Node
## Screenshot tool — renders any scene at the project base grid (480x270) into a SubViewport and saves it
## integer-upscaled (nearest) to 1920x1080, exactly what the player sees on a 1080p screen.
## Run WINDOWED (never --headless: headless cannot render and this script would hang):
##   godot --path godot --resolution 320x180 res://tools/Shot.tscn -- --scene=res://scenes/Night.tscn --out=C:/abs/out.png [--preset=name] [--frames=12] [--timeout=20]
## Prefer the wrapper: node tools/godot/shot.mjs --scene res://scenes/Night.tscn --out shots/night.png --preset customer_at_counter
## If the scene root defines `apply_capture_preset(name: String)`, it is called before capture so a screenshot
## shows a deterministic moment (a customer at the counter, dialogue open, the summary tally, ...).

const OUT_W := 1920
const OUT_H := 1080

func _ready() -> void:
	var args := _parse_args()
	var scene_path: String = args.get("scene", "")
	var out: String = args.get("out", "")
	var preset: String = args.get("preset", "")
	var frames: int = int(args.get("frames", "12"))
	var timeout_s: float = float(args.get("timeout", "20"))
	if scene_path == "" or out == "":
		push_error("Shot: need --scene=<res path> and --out=<abs path>")
		get_tree().quit(2)
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Shot: cannot load scene " + scene_path)
		get_tree().quit(3)
		return
	var timer := get_tree().create_timer(timeout_s)
	timer.timeout.connect(_on_timeout)
	var base_w: int = ProjectSettings.get_setting("display/window/size/viewport_width", 480)
	var base_h: int = ProjectSettings.get_setting("display/window/size/viewport_height", 270)
	var vp := SubViewport.new()
	vp.size = Vector2i(base_w, base_h)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	var inst := packed.instantiate()
	vp.add_child(inst)
	if preset != "" and inst.has_method("apply_capture_preset"):
		inst.call("apply_capture_preset", preset)
	for i in frames:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if img.get_width() != OUT_W or img.get_height() != OUT_H:
		img.resize(OUT_W, OUT_H, Image.INTERPOLATE_NEAREST)
	var err := img.save_png(out)
	print("SHOT err=%d size=%dx%d base=%dx%d out=%s scene=%s preset=%s" % [err, img.get_width(), img.get_height(), base_w, base_h, out, scene_path, preset])
	get_tree().quit(0 if err == OK else 5)

func _on_timeout() -> void:
	push_error("Shot: timeout — scene never finished rendering")
	get_tree().quit(4)

func _parse_args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.trim_prefix("--").split("=", true, 1)
			d[kv[0]] = kv[1]
	return d
