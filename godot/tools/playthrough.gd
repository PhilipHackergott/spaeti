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
## Since docs/06 the demo path is the REGISTER: wait for guests, take the first one ("Next guest" /
## `talk_next`), walk their lines, answer a choice - a stat check when the node offers one - and let
## the conversation end, then the next guest, all night. The old serve steps (Serve -> pick -> Ring
## up -> Wave off) are still here as an OPTIONAL branch: they run when the engine has no `talk_next`
## yet, and `--serve=1` forces them even when it has, so the till never rots untested.
##
## Run it through the wrapper (it owns the lock + the watchdog), never the Godot binary directly:
##   node tools/godot/play.mjs [--out shots] [--timeout 240] [--serve]
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
## …and the register runs SLOWER than real time. Her patience is a game-clock budget (9-13 s, minus
## whatever she spent in the line), while every step here costs real frames — a shot alone settles 28
## of them. At IDLE_SCALE the first guest balked between the capture and the first scan, which is a
## fact about the DRIVER, not about the game. Below 1.0 the driver gets the seconds a human has.
const REGISTER_SCALE := 0.35

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
## The register set pieces, each captured the first time the night offers it.
var _seen_talk: bool = false
var _seen_choice: bool = false
var _seen_check: bool = false
## --serve=1 keeps the old till branch running even on an engine that can talk.
var _force_serve: bool = false
## How many guests the register loop took before the night ran out.
var _guests: int = 0
## What the Night screen dispatched during the step being asserted (its `acted` signal).
var _dispatched: Array = []
## Who the register looked clean FOR, and what it looked like — a guest can leave mid-sequence.
var _clean_for: int = -1
var _clean_order: Array = []
var _clean_lines: Array = []
## Consecutive "Next guest" presses that opened no conversation - the loop steps back after a few.
var _mute: int = 0

func _ready() -> void:
	var args := _parse_args()
	_out_dir = String(args.get("out", "shots")).rstrip("/")
	_force_serve = String(args.get("serve", "")) not in ["", "0", "false"]
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

	# 6 ── wait at the register until somebody is actually there to talk to. On an engine with the
	#      queue this is the LINE forming; on the older one it is the first customer at the counter.
	if not await _wait_for(func() -> bool: return not _active().is_empty() or not _queue().is_empty(), 40.0, "the first guest"):
		return
	await _resolve_any_beat("arrival")
	await _shot("first-guest")

	# 7-9 ── the register: take a guest, talk them through, choose. The till branch runs instead when
	#        the engine cannot talk yet (and as well, with --serve).
	if _can_talk():
		if not await _take_a_guest():
			return
	if _force_serve or not _can_talk():
		if not await _serve_somebody():
			return

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
	# Long enough for the screen to have FINISHED moving: the Summary's tally counts its rows up over
	# ~0.9 s and a 6-frame settle caught it mid-count, so the capture showed "-36,73" for a profit that
	# is actually -47,14 and "47,80" for a rent that is 48,00. A half-animated number in a proof shot is
	# indistinguishable from an arithmetic bug — ask any reader of the last one.
	await _settle(28)
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
		"queue": _queue().size(),
		"talking": String((_talk() as Dictionary).get("speaker", "")),
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
	# On an engine that talks, every beat opens as a one-node conversation (docs/05 section 8) and the
	# register loop is what answers it - this older path would press the same buttons twice.
	if _can_talk():
		return
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
		# The register loop: a conversation to carry, or a line to take the next guest from.
		if _can_talk():
			if not _talk().is_empty():
				Engine.time_scale = IDLE_SCALE
				if not await _carry_the_conversation():
					return false
				if not await _ring_the_register():
					return false
				Engine.time_scale = NIGHT_SCALE
				continue
			# A guest left standing at an open register (her talk ended on an earlier pass, or the
			# wave-off branch below skipped her): ring her up before taking the next one, or the
			# counter never clears and every later guest waits behind a finished conversation.
			if _ringing() and not _active().is_empty():
				Engine.time_scale = IDLE_SCALE
				if not await _ring_the_register():
					return false
				Engine.time_scale = NIGHT_SCALE
				continue
			if not _active().is_empty() or not _queue().is_empty():
				Engine.time_scale = IDLE_SCALE
				await _settle(4)
				if _soft_press(_button("NextGuest")):
					await _settle(6)
					if _talk().is_empty():
						# Nobody the graphs can talk to (or the reducer refused): let the clock run
						# instead of pressing the same button forever.
						_mute += 1
						if _mute > 3:
							_mute = 0
							Engine.time_scale = NIGHT_SCALE
							await _settle(60)
							continue
					else:
						_guests += 1
						_mute = 0
				Engine.time_scale = NIGHT_SCALE
				continue
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
		if not _seen_wave and not _active().is_empty() and not _ringing():
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

# ───────────────────────────────── the register (docs/08 section 6) ─────────────────────────────

## THE ANTI-SOFT-LOCK RULE, and the reason this section exists at all: today's soft-lock shipped
## because the driver pressed buttons BY NODE NAME, so a control that had quietly stopped offering
## its action still "worked" in the run. Nothing below names a node. Every step (1) reads
## `Rules.legal_actions`, (2) asks the SCREEN which on-screen control offers that action
## (`Night.controls_for`), (3) synthesises a real move-press-release at that control's own rect
## centre, and (4) asserts the state actually moved. A control that stops offering its action fails
## the run instead of being pressed anyway.
##
## One whole customer, the way docs/08 section 1 narrates it: her basket is on the counter, you turn
## around for the tobacco she asked for, come back, scan every item, fix a quantity, and ring up.
func _ring_the_register() -> bool:
	var was := Engine.time_scale
	Engine.time_scale = REGISTER_SCALE
	var ok := await _ring_it()
	Engine.time_scale = was
	return ok

func _ring_it() -> bool:
	await _wait_for(func() -> bool: return _ringing() or _active().is_empty(), 8.0, "the register", false)
	if not _at_the_register():
		return true  # she left, or this guest has no basket (the nameless parade)
	if not _has_shot("register-counter"):
		await _shot("register-counter")
	if not await _walk_to_the_wall():
		return false
	if not await _scan_the_counter():
		return false
	if not await _fix_a_quantity():
		return false
	return await _ring_up()

## Is there still somebody to ring up? A guest whose patience runs out LEAVES — that is the game
## working, not the driver failing, so every step below stops quietly instead of dying when she goes.
func _at_the_register() -> bool:
	return _ringing() and not _active().is_empty() and _talk().is_empty()

## The wall trip. What she asked for MINUS what is already on the laminate is the shopping list —
## derived from `view.order` and `view.counter`, never from a name typed in here.
func _walk_to_the_wall() -> bool:
	var missing := _missing_facings()
	if missing.is_empty() or not _at_the_register():
		return true
	if not await _act({"type": "turn_around", "on": true}, "turn around"):
		return false
	if not await _wait_for(func() -> bool: return _on_wall(), 4.0, "the wall", false):
		_die("Turn around did not reach the wall (view_mode %s)" % String(_view().get("view_mode", "")))
		return false
	if not _has_shot("wall"):
		await _shot("wall")
	for key in missing:
		var parts := String(key).split("|")
		for _i in int(missing[key]):
			var take := {"type": "take_from_wall", "sku": parts[0], "brand": parts[1]}
			if not _is_legal(take):
				break  # out of stock, or the hand is full — she gets rung short, which is a real outcome
			if not await _act(take, "take " + String(key)):
				return false
	if not await _act({"type": "turn_around", "on": false}, "back to the counter"):
		return false
	if not await _wait_for(func() -> bool: return not _on_wall(), 4.0, "the counter", false):
		_die("Back did not leave the wall")
		return false
	return true

## Scan every item BY CLICKING THE ITEM. `controls_for({"scan", uid})` hands back the tray slot that
## holds that uid, and the click goes to the slot — never to a node called "Scan".
func _scan_the_counter() -> bool:
	var guard := 0
	while guard < 16:
		guard += 1
		if not _at_the_register():
			return true  # she gave up and left while you were scanning; the night goes on
		var pending := _unscanned()
		if pending.is_empty():
			break
		var before := _register_lines().duplicate(true)
		if not await _act({"type": "scan", "uid": pending[0]}, "scan uid %d" % int(pending[0])):
			return false
		if not _line_grew(before):
			_die("scanning uid %d put nothing on the register — dispatched %s, lines before %s, after %s, counter %s"
				% [int(pending[0]), JSON.stringify(_dispatched), JSON.stringify(before),
					JSON.stringify(_register_lines()), JSON.stringify(_view().get("counter", []))])
			return false
	if _at_the_register() and not _unscanned().is_empty():
		_die("%d item(s) never reached the glass" % _unscanned().size())
		return false
	return true

## The quantity that was wrong and is put right — docs/08 section 1's "+"/"−" on a register line, and
## the proof that `matches` is the REDUCER's opinion and not the screen's: one step up and the line
## stops matching her order, one step down and it matches again. Both presses are real clicks.
func _fix_a_quantity() -> bool:
	if _has_shot("qty-fixed") or not _at_the_register():
		return true
	var lines := _register_lines()
	for i in lines.size():
		var line: Dictionary = lines[i]
		if not bool(line.get("matches", false)):
			continue
		var was := int(line["qty"])
		if not _is_legal({"type": "register_set_qty", "line": i, "qty": was + 1}):
			continue
		if not await _act({"type": "register_set_qty", "line": i, "qty": was + 1}, "one too many on line %d" % i):
			return false
		if bool((_register_lines()[i] as Dictionary).get("matches", true)):
			_die("the register still claims line %d matches after over-ringing it" % i)
			return false
		await _shot("qty-wrong")
		if not await _act({"type": "register_set_qty", "line": i, "qty": was}, "put line %d right" % i):
			return false
		if not bool((_register_lines()[i] as Dictionary).get("matches", false)):
			_die("line %d did not go back to matching" % i)
			return false
		await _shot("qty-fixed")
		return true
	return true

## Ring up, and let the ONE FREE CORRECTION happen if the wall could not supply what she asked for:
## the first bad ring is refused by the reducer, the second commits (docs/08 section 3.4).
func _ring_up() -> bool:
	if not _at_the_register():
		return true
	var sold_before := _sales()
	# THE SHOPKEEPER CHECKS ID. docs/08 §3.4: with the check, a restricted line for a minor is REFUSED
	# — dropped from both sides of the verdict, never charged, Integrity +1 — instead of being sold for
	# −8 Integrity. Without this the scripted night sold a Sterni to the Kassenkind every single time,
	# which is not the baseline the Integrity meter is calibrated against.
	if bool(_active().get("underage", false)) and _has_restricted_line() and _is_legal({"type": "check_id"}):
		if not await _act({"type": "check_id"}, "check ID"):
			return false
	# Her empties, one press of `+` at a time: the row steps by one and `legal_actions` now says so,
	# so a single jump to the full count is an action no chip offers (docs/08 §3.5).
	var bottles := int(_active().get("bottles", 0))
	for _step_i in bottles:
		var staged := int(_register().get("pfand_bottles", 0))
		if staged >= bottles or not _is_legal({"type": "set_pfand", "bottles": staged + 1}):
			break
		if not await _act({"type": "set_pfand", "bottles": staged + 1}, "take a Pfand bottle back"):
			break
	if _register_lines().is_empty() and int(_register().get("pfand_bottles", 0)) == 0:
		# Nothing to ring: the wall could not supply a single thing she asked for (the shelf is out).
		# A shopkeeper waves her off — which is a real control, a real action, and a real outcome, and
		# leaves the counter clear for the next guest instead of stalling the night on an empty till.
		if _is_legal({"type": "skip_active"}):
			if not await _act({"type": "skip_active"}, "wave off an order we cannot fill"):
				return false
			if not _has_shot("waved-off"):
				_seen_wave = true
				await _shot("waved-off")
		return true
	var clean_at_ring := false
	var rang_for := -1
	for attempt in 2:
		if not _is_legal({"type": "ring_up"}):
			break
		# The proof frame is the register LOADED and about to ring clean — every line matching, every
		# chip ticked, the total standing. Captured AFTER the ring it showed an empty counter with the
		# next guest already stepping up, which proves nothing about the sale that just happened.
		if not _has_shot("register-ok") and _rings_clean():
			await _shot("register-ok")
			_clean_for = _who()
		# Re-read AFTER the shot and immediately before dispatching: a shot settles 28 frames, and a
		# guest whose patience runs out in that window LEAVES. The verdict below may only be asserted
		# against the state as it was at the instant we actually rang.
		clean_at_ring = _rings_clean()
		rang_for = _who()
		if not await _act({"type": "ring_up"}, "ring up (%d)" % (attempt + 1)):
			return false
		if _active().is_empty():
			break
		if not _has_shot("correction") and String(_register().get("correction", "")) != "":
			await _shot("correction")
	if _sales() <= sold_before:
		# Nothing was sold. She walked off mid-ring — a real outcome, and the tally is honest about it —
		# but then the `register-ok` frame we may have just taken is of a sale that never happened, and
		# `last_verdict` still belongs to somebody else entirely. Drop the frame; a later guest earns it.
		if not _at_the_register():
			if _clean_for == rang_for and rang_for != -1:
				_undo_shot("register-ok")
			return true
		_die("Ring up sold nothing (sales stayed at %d)" % sold_before)
		return false
	# …and when we DID ring a clean register, the reducer's verdict has to agree with the frame.
	if clean_at_ring and rang_for == _clean_for and not bool(_verdict().get("ok", false)):
		_die("the register looked clean for customer %d but the verdict was %s"
			% [rang_for, JSON.stringify(_verdict())])
		return false
	return true

## Forget a capture that turned out not to prove what it was taken to prove — the row AND the file, so
## `_has_shot` is false again and the next guest retakes it. A proof frame nobody earned is worse than
## no proof frame: the run REQUIRES `register-ok`, and it has to mean a register that actually rang.
func _undo_shot(step_name: String) -> void:
	for i in range(_rows.size() - 1, -1, -1):
		if String((_rows[i] as Dictionary).get("name", "")) != step_name:
			continue
		var path := "%s/play-%02d-%s.png" % [_out_dir, int((_rows[i] as Dictionary)["step"]), step_name]
		DirAccess.remove_absolute(path)
		_rows.remove_at(i)
		return

## Would this ring be exact? Every line she asked for is on the register, matching, and nothing is
## flagged — the reducer's own opinion (`satisfied` / `matches`), never the driver's arithmetic.
## Is anything on the register age-restricted? The REDUCER says so per line, never the driver.
func _has_restricted_line() -> bool:
	for entry in _register_lines():
		if bool((entry as Dictionary).get("restricted", false)):
			return true
	return false

## The customer at the counter right now, by id. `-1` when nobody is.
func _who() -> int:
	return int((_active().get("customer", {}) as Dictionary).get("id", -1))

func _rings_clean() -> bool:
	var order: Array = _view().get("order", [])
	if order.is_empty():
		return false
	for entry in order:
		if not bool((entry as Dictionary).get("satisfied", false)):
			return false
	for entry in _register_lines():
		if not bool((entry as Dictionary).get("matches", false)):
			return false
	return not _register_lines().is_empty()

# ── the register, read off the real read-model ────────────────────────────────────────────────

func _ringing() -> bool:
	return not (_view().get("register", {}) as Dictionary).is_empty()

func _on_wall() -> bool:
	return String(_view().get("view_mode", "counter")) == "wall"

func _register() -> Dictionary:
	return _view().get("register", {})

func _register_lines() -> Array:
	return (_register().get("lines", []) as Array)

func _verdict() -> Dictionary:
	var s := _session()
	if s == null:
		return {}
	return ((s.get("state") as Dictionary).get("last_verdict", {}) as Dictionary)

## The uids still waiting for the glass, in the order the tray holds them.
func _unscanned() -> Array:
	var out: Array = []
	for entry in (_view().get("counter", []) as Array):
		var item: Dictionary = entry
		if String(item.get("kind", "")) != "crate" and not bool(item.get("scanned", false)):
			out.append(int(item["uid"]))
	return out

## (sku|brand) -> how many more of that facing her order needs than the counter already holds. The
## same rule the reducer scores by: an UNBRANDED line takes any facing of that SKU.
func _missing_facings() -> Dictionary:
	var have: Dictionary = {}
	var have_by_sku: Dictionary = {}
	for entry in (_view().get("counter", []) as Array):
		var item: Dictionary = entry
		if String(item.get("kind", "")) == "crate":
			continue
		var key := String(item["sku_id"]) + "|" + String(item["brand"])
		have[key] = int(have.get(key, 0)) + 1
		have_by_sku[String(item["sku_id"])] = int(have_by_sku.get(String(item["sku_id"]), 0)) + 1
	var out: Dictionary = {}
	for entry in (_view().get("order", []) as Array):
		var row: Dictionary = entry
		var sku_id := String(row["sku_id"])
		if String(row.get("category", "")) == "pfand":
			continue
		var brand := String(row["brand"])
		var key := sku_id + "|" + brand
		var got := int(have_by_sku.get(sku_id, 0)) if brand == "" else int(have.get(key, 0))
		if int(row["qty"]) - got > 0:
			out[key] = int(row["qty"]) - got
	return out

## Did the register actually move? A new line, or an existing one stepped up.
func _line_grew(before: Array) -> bool:
	var now := _register_lines()
	if now.size() != before.size():
		return true
	for i in now.size():
		if int((now[i] as Dictionary)["qty"]) != int((before[i] as Dictionary)["qty"]):
			return true
	return false

# ── acting on the world, the only way this driver is allowed to ───────────────────────────────

func _legal() -> Array:
	var s := _session()
	return (s.call("legal_actions") as Array) if s != null else []

## Is the engine actually offering THIS action? Compared field by field, so a `scan` of uid 7 never
## passes because some other uid happens to be scannable.
func _is_legal(action: Dictionary) -> bool:
	for entry in _legal():
		var a: Dictionary = entry
		if String(a.get("type", "")) != String(action["type"]):
			continue
		var same := true
		for key in action:
			if key == "type":
				continue
			if not a.has(key) or a[key] != action[key]:
				same = false
				break
		if same:
			return true
	return false

## The four steps, in order: legal -> find the control that OFFERS it -> real click at its own rect
## centre -> assert the state moved. Then the two standing guards docs/08 section 6 asks for.
func _act(action: Dictionary, what: String) -> bool:
	if not _is_legal(action):
		_die("the engine does not offer %s (%s)" % [JSON.stringify(action), what])
		return false
	if _active().is_empty():
		return true
	var night := _screen()
	if night == null or not night.has_method("controls_for"):
		_die("the night screen offers no controls_for() - cannot prove %s is reachable" % what)
		return false
	var controls: Array = night.call("controls_for", action)
	if controls.is_empty():
		_die("NO VISIBLE CONTROL offers %s (%s) - that is the soft-lock" % [JSON.stringify(action), what])
		return false
	if not night.is_connected("acted", _on_acted):
		night.connect("acted", _on_acted)
	_dispatched = []
	var before := _register_fingerprint()
	await _click(controls[0] as Control, what)
	# "The view changed" proves nothing — the clock moves every frame. What must move is the part of
	# the read-model this action acts on, and the screen must say it dispatched something.
	if _register_fingerprint() == before:
		var c := controls[0] as Control
		var here: Variant = night.call("control_at", c.get_global_rect().get_center()) if night.has_method("control_at") else null
		_die("clicking the control for %s (%s) moved nothing — control '%s' rect %s visible=%s, control_at says '%s', dispatched %s"
			% [JSON.stringify(action), what, c.name, str(c.get_global_rect()), str(c.is_visible_in_tree()),
				(here.name if here != null else "<nothing>"), JSON.stringify(_dispatched)])
		return false
	return await _guards(what)

## A click only counts if the control is the thing UNDER THE POINTER. The tobacco wall is a
## full-frame overlay with a 160-ms pivot, and `view_mode` flips back to "counter" the instant the
## reducer says so — a quarter of a second before the overlay has finished sliding off. A click in
## that window lands on the wall and is swallowed in silence, which is precisely the failure this
## driver exists to catch, so it waits for the frame instead of trusting the flag.
func _wait_until_on_top(c: Control, what: String) -> void:
	var night := _screen()
	if night == null or not night.has_method("control_at"):
		return
	var deadline := mini(Time.get_ticks_msec() + 2000, _deadline_ms)
	while Time.get_ticks_msec() < deadline:
		var top: Variant = night.call("control_at", c.get_global_rect().get_center())
		if top != null and (top == c or c.is_ancestor_of(top) or (top as Node).is_ancestor_of(c)):
			return
		await get_tree().process_frame

## Everything the Night screen dispatched since the last step — its `acted` signal, so a failure can
## say what the click actually did instead of only that nothing happened.
func _on_acted(a: Dictionary) -> void:
	_dispatched.append(a)

## The register as a string: which way you face, what is on the counter, what is scanned, what is
## rung, and what is in your hand. Everything an action in this section can move, and nothing that
## moves on its own.
func _register_fingerprint() -> String:
	var v := _view()
	var scanned: Array = []
	for entry in (v.get("counter", []) as Array):
		var item: Dictionary = entry
		scanned.append([int(item["uid"]), bool(item.get("scanned", false))])
	var active: Dictionary = v.get("active", {})
	return JSON.stringify({
		"mode": String(v.get("view_mode", "")),
		"counter": scanned,
		"lines": _register_lines(),
		"pfand": int(_register().get("pfand_bottles", 0)),
		"corrections": int(_register().get("corrections", 0)),
		"id_checked": bool(_register().get("id_checked", false)),
		"hand": (active.get("hand", []) as Array).size(),
		"who": int((active.get("customer", {}) as Dictionary).get("id", -1)),
	})

## After EVERY step: the night still offers something (or it is over), and no drag is stuck.
func _guards(what: String) -> bool:
	if String(_view().get("phase", "")) == "night" and _legal().is_empty():
		_die("SOFT-LOCK after %s: legal_actions is empty and the night is still running" % what)
		return false
	var layer := _node("DragLayer")
	if layer != null and layer.has_method("is_dragging") and bool(layer.call("is_dragging")):
		await _settle(120)
		if bool(layer.call("is_dragging")):
			_die("a drag is still in flight two seconds after %s" % what)
			return false
	return true

## A genuine press: move the pointer onto the control, press, release. `push_input` on the
## SubViewport is the same door a real mouse comes through, so the control's own `_gui_input`, its
## hover state and its guards all apply - which `pressed.emit()` would have skipped.
func _click(c: Control, what: String) -> void:
	await _wait_until_on_top(c, what)
	var at := c.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_vp.push_input(motion, true)
	await _settle(1)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		_vp.push_input(ev, true)
		await _settle(1)
	await _settle(3)

# ───────────────────────────────── the register (docs/06 section 5) ─────────────────────────────

## True once the engine ships the conversation (docs/06 section 4). Until then `view` carries no
## `talk` key at all and this whole branch is skipped - which is exactly how the two lanes land
## independently: the screen is built against the contract, the driver waits for the reducer.
func _can_talk() -> bool:
	return _view().has("talk")

func _talk() -> Dictionary:
	return _view().get("talk", {})

func _queue() -> Array:
	return _view().get("queue", [])

## One whole guest: take them out of the line, walk their lines, answer the first choice they offer,
## and see the conversation close. Captures the three set pieces once each.
func _take_a_guest() -> bool:
	if not await _wait_for(func() -> bool: return not _queue().is_empty() or not _active().is_empty(), 40.0, "a guest to take"):
		return false
	await _shot("queue")
	# The strip's own button, the way a player presses it - not a dispatch behind the screen's back.
	if not await _wait_for(func() -> bool: return _soft_ready(_button("NextGuest")), 6.0, "the Next guest button"):
		return false
	if not _press(_button("NextGuest"), "Next guest"):
		return false
	if not await _wait_for(func() -> bool: return not _talk().is_empty(), 8.0, "the conversation to open"):
		return false
	if not _serve_is_blocked():
		_die("the engine offered `serve_active` while a conversation was open")
		return false
	await _shot("talk-open")
	_guests += 1
	if not await _carry_the_conversation():
		return false
	# docs/08 §1: her talk ending is the sale STARTING. The basket is on the counter and she is still
	# standing there — so the guest is not finished until the register is.
	return await _ring_the_register()

## Advance until the node offers choices, take one, and let the guest go. Everything is pressed on
## the real DialogueBox; the engine owns `talk.line`, so this only decides WHEN to click.
func _carry_the_conversation() -> bool:
	var guard := 0
	while not _talk().is_empty() and not _expired() and guard < 40:
		guard += 1
		if not _seen_talk and (_talk().get("choices", []) as Array).is_empty():
			_seen_talk = true
			await _shot("talk-lines")
		var choices := _choice_buttons()
		if choices.is_empty():
			# No choices yet: one more line. `advance()` is exactly what a click or Space does.
			var box := _node("DialogueBox")
			if box == null:
				return true
			box.call("advance")
			await _settle(6)
			continue
		if not _seen_choice:
			_seen_choice = true
			await _shot("talk-choice")
		# Prefer a choice that ROLLS, so the d20 pop is exercised; otherwise the first open one.
		if not _choose(_pick_choice()):
			return false
		await _settle(8)
		if not _seen_check and not (_talk().get("last_check", {}) as Dictionary).is_empty():
			_seen_check = true
			await _shot("talk-check")
	if _talk().is_empty() and _guests > 0 and not _has_shot("talk-ended"):
		await _shot("talk-ended")
	return true

## The index of the first choice that carries a check and is not locked; else the first open one.
## A locked gate is never pressed - `legal_actions` does not offer it and the button is disabled.
func _pick_choice() -> int:
	var choices: Array = _talk().get("choices", [])
	var fallback := -1
	for i in choices.size():
		var c: Dictionary = choices[i]
		if bool(c.get("locked", false)):
			continue
		if fallback < 0:
			fallback = i
		if not (c.get("check", {}) as Dictionary).is_empty():
			return i
	return maxi(0, fallback)

## The old till branch, kept whole: Serve -> pick the wanted SKU -> Ring up. It is the demo path on
## an engine without conversations, and an optional extra (--serve) on one with them.
func _serve_somebody() -> bool:
	if not await _wait_for(func() -> bool: return not _active().is_empty(), 40.0, "somebody at the counter"):
		return false
	await _resolve_any_beat("serve")
	if not _press(_button("ServeToggle"), "Serve"):
		return false
	await _settle(12)
	if not _serve_open():
		_die("the serve panel did not open")
		return false
	await _shot("shelf-open")
	var want := String((_active().get("want", {}) as Dictionary).get("sku_id", ""))
	if not _pick(want):
		_die("no shelf slot for the wanted sku '%s'" % want)
		return false
	await _settle(2)
	if not _till_has_lines():
		_die("picking '%s' did not reach the till" % want)
		return false
	await _shot("picked")
	var sold_before := _sales()
	if not _press(_button("RingUp"), "Ring up"):
		return false
	await _settle(8)
	if _sales() <= sold_before:
		_die("Ring up did not sell anything (sales stayed at %d)" % sold_before)
		return false
	await _shot("rang-up")
	return true

## Wall-clock budget for the whole run, checked by every wait in here.
func _expired() -> bool:
	return Time.get_ticks_msec() >= _deadline_ms

func _has_shot(step_name: String) -> bool:
	for row in _rows:
		if String((row as Dictionary).get("name", "")) == step_name:
			return true
	return false

## A press that is allowed to fail: the screen renders a frame behind the reducer, so "the button is
## not there yet" is an ordinary state inside the night loop, not a failed playthrough.
func _soft_ready(b: Button) -> bool:
	return b != null and not b.disabled and b.is_visible_in_tree()

func _soft_press(b: Button) -> bool:
	if not _soft_ready(b):
		return false
	b.grab_focus()
	b.pressed.emit()
	return true

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

## The buttons under `%Choices`, in order. It walks INTO each row: since docs/06 a choice is a row
## (`Choice1`, `Choice2`, …) holding the button plus its stat tag as a sibling label, because a label
## cannot colour half of itself. A direct-children-only scan finds zero and reads as "the beat offered
## no choices" while the choice is plainly on screen — which is exactly what it did.
func _choice_buttons() -> Array:
	var box := _node("Choices")
	if box == null:
		return []
	var out: Array = []
	_collect_buttons(box, out)
	return out

func _collect_buttons(root: Node, out: Array) -> void:
	for c in root.get_children():
		if c is Button:
			out.append(c)
		else:
			_collect_buttons(c, out)

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
	# The run is only a proof if the register set pieces actually happened — a night that never
	# turned around and never rang clean would otherwise pass as "ok" with the loop untested.
	for required in ["register-counter", "wall", "register-ok"]:
		if not _has_shot(required):
			_die("the night never reached `%s` — the register loop was not exercised" % required)
			return
	print("PLAY ok steps=%d guests=%d" % [_step, _guests])
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
