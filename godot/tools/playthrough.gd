extends Node
## THE PROOF THAT THE LOOP IS PLAYABLE. It boots the real `res://scenes/Main.tscn` into the same
## 480x270 SubViewport `shot.gd` captures from, and then plays it the way a person would: it presses
## the screens' OWN buttons, picks off the real Shelf, rings up on the real Till, answers a story beat
## on the real DialogueBox, and lets the real Session tick the night to 06:00. Nothing here fakes a
## read-model — `MockView` is never touched; every number in the log comes from `Session.view()`.
##
## After every step it saves shots/play-NN-<step>.png (1920x1080, nearest) and appends one row to
## shots/play-log.json, so a failure is a picture, not a stack trace.
##
## Run it through the wrapper (it owns the lock + the watchdog), never the Godot binary directly:
##   node tools/godot/play.mjs [--out shots] [--timeout 240]
##
## Time: a night is `night_len_ms` = 5 real minutes. `Engine.time_scale` (and NOTHING in the game) is
## what makes that fit in a test run — Session still ticks itself, arrivals still arrive on their own
## curve, patience still runs, and `night.gd` still closes the night by itself.

const OUT_W := 1920
const OUT_H := 1080
const MAIN := "res://scenes/Main.tscn"
## How fast the clock runs between interactions. Kept modest so a press lands on the frame we think.
const IDLE_SCALE := 4.0
## The night is 5 real minutes; the driver loop plays it out at this speed, which is ~40 s of wall
## clock. Fast enough for a test run, slow enough that patience and arrivals still behave.
const NIGHT_SCALE := 8.0

var _vp: SubViewport = null
var _main: Node = null
var _out_dir: String = "shots"
var _rows: Array = []
var _step: int = 0
var _failed: String = ""
var _deadline_ms: int = 0
## Each of these is captured the first time the night offers it, then never again.
var _seen_beat: bool = false
var _seen_wave: bool = false

func _ready() -> void:
	var args := _parse_args()
	_out_dir = String(args.get("out", "shots")).rstrip("/")
	# Wall clock, not a SceneTreeTimer: those run on SCALED time, so at time_scale 4 a 225-second
	# watchdog fires after 56 real seconds (it did, on the first run).
	_deadline_ms = Time.get_ticks_msec() + int(float(args.get("timeout", "240")) * 1000.0)
	var packed := load(MAIN) as PackedScene
	if packed == null:
		_die("cannot load " + MAIN)
		return
	var base_w: int = ProjectSettings.get_setting("display/window/size/viewport_width", 480)
	var base_h: int = ProjectSettings.get_setting("display/window/size/viewport_height", 270)
	_vp = SubViewport.new()
	_vp.size = Vector2i(base_w, base_h)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_vp)
	_main = packed.instantiate()
	_vp.add_child(_main)
	await _settle(4)
	await _play()

# ───────────────────────────────── the playthrough ─────────────────────────────────

func _play() -> void:
	Engine.time_scale = IDLE_SCALE

	# 1 ── the title, as the player first sees it.
	if not await _expect_screen("title", 5.0, "boot to the title"):
		return
	await _shot("title")

	# 2 ── New game: the Session starts a season and the shell hands over to the Manage hour.
	if not _press(_button("NewGame"), "New game"):
		return
	if not await _expect_screen("manage", 5.0, "New game opens the Manage hour"):
		return
	await _shot("new-game")

	# 3 ── the opening beat, if the season opens with one. (No-op today; the wiring is the point,
	#      because this same call is what answers every later beat at the counter.)
	await _advance_dialogue()
	await _shot("opening-beat")

	# 4 ── a real restock off the board: the button dispatches and the engine moves the stock.
	var before_stock := _first_restock_stock()
	if not _press(_first_restock_button(), "restock +"):
		return
	await _settle(2)
	if _first_restock_stock() <= before_stock:
		_die("restock did not reach the engine (stock %d -> %d)" % [before_stock, _first_restock_stock()])
		return
	await _shot("restock")

	# 5 ── Open up: phase manage -> night, and the shell swaps in the Night screen.
	if not _press(_button("OpenNight"), "Open up"):
		return
	if not await _expect_screen("night", 6.0, "Open up starts the night"):
		return
	if String(_view().get("phase", "")) != "night":
		_die("the reducer is still in %s after Open up" % String(_view().get("phase", "")))
		return
	await _shot("night-open")

	# 6 ── wait at the counter until somebody actually walks up.
	if not await _wait_for(func() -> bool: return not _active().is_empty(), 40.0, "the first customer"):
		return
	await _resolve_any_beat("arrival")
	await _shot("first-customer")

	# 7 ── open the shelf the way the player does: the Serve toggle.
	if not _press(_button("ServeToggle"), "Serve"):
		return
	await _settle(12)
	if not _serve_open():
		_die("the serve panel did not open")
		return
	await _shot("shelf-open")

	# 8 ── pick what they asked for, off the real ItemSlot.
	var want := String((_active().get("want", {}) as Dictionary).get("sku_id", ""))
	if not _pick(want):
		_die("no shelf slot for the wanted sku '%s'" % want)
		return
	await _settle(2)
	if not _till_has_lines():
		_die("picking '%s' did not reach the till" % want)
		return
	await _shot("picked")

	# 9 ── ring it up: the till becomes `serve_active` and the tally has to move.
	var sold_before := _sales()
	if not _press(_button("RingUp"), "Ring up"):
		return
	await _settle(8)
	if _sales() <= sold_before:
		_die("Ring up did not sell anything (sales stayed at %d)" % sold_before)
		return
	await _shot("rang-up")

	# 10-12 ── play the rest of the night out: answer the beat the story schedules, wave one customer
	#          off, and let `night.gd` close the books itself at 06:00. Everything below happens on the
	#          real screens; the loop only decides WHEN to press, never what the engine may do.
	Engine.time_scale = NIGHT_SCALE
	if not await _play_out_the_night():
		return
	Engine.time_scale = IDLE_SCALE

	# 13 ── the Summary screen, with the night's P&L.
	if not await _expect_screen("summary", 10.0, "the night hands over to the summary"):
		return
	await _shot("summary")

	# 14 ── Continue: advance_day, back to the Manage hour of night 2.
	var day_before := int(_view().get("day", 1))
	if not _press(_button("Continue"), "Next day"):
		return
	if not await _expect_screen("manage", 8.0, "the summary hands back to Manage"):
		return
	if int(_view().get("day", 1)) <= day_before:
		_die("advance_day did not move the calendar (still day %d)" % day_before)
		return
	await _shot("day2-manage")

	# 15 ── and night 2 opens, which is the whole loop closed.
	if not _press(_button("OpenNight"), "Open up (night 2)"):
		return
	if not await _expect_screen("night", 8.0, "night 2 opens"):
		return
	await _shot("night2-open")

	_finish()

# ───────────────────────────────── steps & assertions ─────────────────────────────────

## Renders and saves the frame, then appends the read-model row. Both, always, in this order.
func _shot(step_name: String) -> void:
	_step += 1
	await _settle(6)
	var img := _vp.get_texture().get_image()
	if img.get_width() != OUT_W or img.get_height() != OUT_H:
		img.resize(OUT_W, OUT_H, Image.INTERPOLATE_NEAREST)
	var path := "%s/play-%02d-%s.png" % [_out_dir, _step, step_name]
	var err := img.save_png(path)
	var v := _view()
	_rows.append({
		"step": _step,
		"name": step_name,
		"screen": String(_main.get("current_screen")),
		"phase": String(v.get("phase", "")),
		"day": int(v.get("day", 1)),
		"clock": String(v.get("time_label", "")),
		"cash": snappedf(float(v.get("cash", 0.0)), 0.01),
		"active": _active_name(),
		"pending": _pending(),
	})
	print("PLAY step=%02d %s screen=%s phase=%s day=%d clock=%s cash=%.2f active='%s' pending='%s' png_err=%d" % [
		_step, step_name, String(_main.get("current_screen")), String(v.get("phase", "")),
		int(v.get("day", 1)), String(v.get("time_label", "")), float(v.get("cash", 0.0)),
		_active_name(), _pending(), err])

## Waits for the shell to land on `screen_name`. Screen swaps fade, so this is a poll, not a frame count.
func _expect_screen(screen_name: String, seconds: float, what: String) -> bool:
	var ok := await _wait_for(func() -> bool: return String(_main.get("current_screen")) == screen_name, seconds, what, false)
	if not ok:
		_die("%s: the shell is on '%s', not '%s'" % [what, String(_main.get("current_screen")), screen_name])
	return ok

func _wait_for(cond: Callable, seconds: float, what: String, fatal: bool = true) -> bool:
	var deadline := mini(Time.get_ticks_msec() + int(seconds * 1000.0), _deadline_ms)
	while Time.get_ticks_msec() < deadline:
		if bool(cond.call()):
			return true
		await get_tree().process_frame
	if fatal:
		_die("timed out waiting for %s" % what)
	return false

## Space/click, exactly as `night.gd::_unhandled_input` sends it, until the choices are on screen.
func _advance_dialogue() -> void:
	var box := _node("DialogueBox")
	if box == null or not bool(box.get("visible")):
		return
	for _i in 8:
		box.call("advance")
		await _settle(2)
		if _choice_buttons().size() > 0:
			return

func _choose(index: int) -> bool:
	var buttons := _choice_buttons()
	if index >= buttons.size():
		_die("the beat offered %d choices, not %d" % [buttons.size(), index + 1])
		return false
	return _press(buttons[index], "choice %d" % (index + 1))

## Resolves a beat that fired the moment a customer stepped up, so the serve steps can run.
func _resolve_any_beat(tag: String) -> void:
	if _pending() == "":
		return
	await _advance_dialogue()
	await _shot("beat-" + tag)
	await _choose(0)
	await _settle(6)

## Plays the night from "one customer served" to 06:00. The night ENDS ITSELF — `night.gd` dispatches
## `close_night` once the clock is out and the counter is clear — so this only does what a player at
## the counter does: answer the story when it speaks, wave one person off, and let the rest go by.
## Each of the two set pieces is captured the first time it happens.
func _play_out_the_night() -> bool:
	while not _expired():
		if String(_view().get("phase", "")) != "night":
			return true
		if _pending() != "":
			Engine.time_scale = IDLE_SCALE
			await _advance_dialogue()
			if not _seen_beat:
				_seen_beat = true
				await _shot("beat-choice")
				# docs/05 §4: while a beat is pending the engine offers no serve at all.
				if not _serve_is_blocked():
					_die("the engine offered `serve_active` while a beat was pending")
					return false
			if not await _choose(0):
				return false
			await _settle(6)
			if _seen_beat and _step > 0 and not _has_shot("beat-resolved"):
				await _shot("beat-resolved")
			Engine.time_scale = NIGHT_SCALE
			continue
		if not _seen_wave and not _active().is_empty():
			_seen_wave = true
			Engine.time_scale = IDLE_SCALE
			if not _serve_open():
				_press(_button("ServeToggle"), "Serve")
				await _settle(12)
			if _press(_button("WaveOff"), "Wave off"):
				await _settle(8)
				await _shot("waved-off")
			Engine.time_scale = NIGHT_SCALE
			continue
		await get_tree().process_frame
	_die("the night never reached 06:00 (progress %.2f, phase %s, active '%s', queue %d)" % [
		float(_view().get("night_progress", 0.0)), String(_view().get("phase", "")),
		_active_name(), int(_view().get("queue_len", 0))])
	return false

## Wall-clock budget for the whole run, checked by every wait in here.
func _expired() -> bool:
	return Time.get_ticks_msec() >= _deadline_ms

func _has_shot(step_name: String) -> bool:
	for row in _rows:
		if String((row as Dictionary).get("name", "")) == step_name:
			return true
	return false

func _press(b: Button, what: String) -> bool:
	if b == null:
		_die("no button for '%s'" % what)
		return false
	if b.disabled or not b.is_visible_in_tree():
		_die("'%s' is %s" % [what, "disabled" if b.disabled else "hidden"])
		return false
	b.grab_focus()
	b.pressed.emit()
	return true

## A real click on a real ItemSlot — through the slot's own `_gui_input`, so its stock guard applies.
func _pick(sku_id: String) -> bool:
	var shelf := _node("Shelf")
	if shelf == null:
		return false
	var slot: Node = shelf.call("slot_for", sku_id)
	if slot == null:
		return false
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	slot.call("_gui_input", ev)
	return true

# ───────────────────────────────── reading the world ─────────────────────────────────

func _session() -> Node:
	return get_node_or_null("/root/Session")

func _view() -> Dictionary:
	var s := _session()
	return s.call("view") if s != null else {}

func _active() -> Dictionary:
	return _view().get("active", {})

func _active_name() -> String:
	var a := _active()
	return String((a.get("archetype", {}) as Dictionary).get("name", "")) if not a.is_empty() else ""

func _pending() -> String:
	return String((_view().get("dialogue", {}) as Dictionary).get("kind", ""))

func _tally(key: String) -> int:
	var s := _session()
	if s == null:
		return 0
	return int(((s.get("state") as Dictionary).get("tally", {}) as Dictionary).get(key, 0))

func _sales() -> int:
	return _tally("sales")

## While a beat is pending the engine offers no `serve_active` at all (docs/05 §4) — so the real
## check is `legal_actions`, not whether a button happens to be greyed out.
func _serve_is_blocked() -> bool:
	var s := _session()
	if s == null:
		return true
	for a in (s.call("legal_actions") as Array):
		if String((a as Dictionary).get("type", "")) == "serve_active":
			return false
	return true

func _screen() -> Node:
	var host := _main.get_node_or_null("%Screens") as Control
	if host == null or host.get_child_count() == 0:
		return null
	return host.get_child(0)

## Finds a node by NAME anywhere under the live screen. Deliberately not a `%unique` lookup:
## components are reparented at runtime (the board into the Modal, the bust into the set), and a
## search by name is the one thing that stays true whatever a screen does with its own tree.
func _node(node_name: String) -> Node:
	return _search(_screen(), node_name)

func _button(node_name: String) -> Button:
	return _search(_screen(), node_name) as Button

func _search(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	for c in root.get_children():
		var hit := _search(c, node_name)
		if hit != null:
			return hit
	return null

func _serve_open() -> bool:
	var panel := _node("ServePanel")
	return panel != null and bool(panel.get("is_open"))

func _till_has_lines() -> bool:
	var till := _node("Till")
	return till != null and not (till.get("lines") as Array).is_empty()

func _choice_buttons() -> Array:
	var box := _node("Choices")
	if box == null:
		return []
	var out: Array = []
	for c in box.get_children():
		if c is Button:
			out.append(c)
	return out

func _first_restock_button() -> Button:
	var rows := _node("Rows")
	if rows == null or rows.get_child_count() == 0:
		return null
	for c in (rows.get_child(0) as Node).get_children():
		if c is Button:
			return c as Button
	return null

func _first_restock_stock() -> int:
	var options: Array = (_view().get("manage", {}) as Dictionary).get("restock_options", [])
	return int((options[0] as Dictionary).get("stock", 0)) if not options.is_empty() else -1

# ───────────────────────────────── plumbing ─────────────────────────────────

func _settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _finish() -> void:
	_write_log()
	print("PLAY ok steps=%d" % _step)
	get_tree().quit(0)

func _die(reason: String) -> void:
	if _failed != "":
		return
	_failed = reason
	_write_log()
	print("PLAY FAILED step=%d reason=%s" % [_step, reason])
	get_tree().quit(1)

func _write_log() -> void:
	var f := FileAccess.open(_out_dir + "/play-log.json", FileAccess.WRITE)
	if f == null:
		push_error("PLAY: cannot write " + _out_dir + "/play-log.json")
		return
	f.store_string(JSON.stringify({"ok": _failed == "", "failed": _failed, "steps": _rows}, "\t"))
	f.close()

func _parse_args() -> Dictionary:
	var d := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.trim_prefix("--").split("=", true, 1)
			d[kv[0]] = kv[1]
	return d
