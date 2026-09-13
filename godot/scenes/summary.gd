extends Screen
## The nightly P&L: one centred card over the closed shop, the tally counting itself up, and the way
## back to the next day. The arithmetic is the engine's — this only reads `view.summary`.

func _ready() -> void:
	super._ready()
	# The veil and the two hairlines are Palette tokens, never colours written into the .tscn
	# (docs/04 rule 1) — a palette change has to reach every surface.
	_paint("Dim", Palette.DIM)
	_paint("Card/Box/Rule", Palette.RULE)
	_paint("Card/Box/Rule2", Palette.RULE)
	var cont := get_node_or_null("%Continue") as Button
	if cont != null:
		cont.text = Strings.NEXT_DAY
		if not cont.pressed.is_connected(_on_continue):
			cont.pressed.connect(_on_continue)
	var tally := _tally()
	if tally != null and not _capture_mode:
		tally.play()
	# The same anchor Manage and Title carry: with no focus owner the keyboard ring cannot start.
	# Deferred for the same reason Manage's is — a capture must not inherit a focus ring.
	_seed_focus.call_deferred()

func _seed_focus() -> void:
	if _capture_mode or not is_inside_tree():
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	var cont := get_node_or_null("%Continue") as Button
	if cont != null and cont.is_visible_in_tree() and not cont.disabled:
		cont.grab_focus()

func render(v: Dictionary) -> void:
	if v.is_empty():
		return
	var layers := get_node_or_null("%SceneLayers") as SceneLayers
	if layers != null:
		layers.set_time(1.0)
	var s: Dictionary = v.get("summary", {})
	var title := get_node_or_null("%Title") as Label
	if title != null:
		title.text = Strings.SUMMARY_TITLE % int(s.get("day", v.get("day", 1)))
	var sub := get_node_or_null("%Sub") as Label
	if sub != null:
		sub.text = Strings.summary_sub(
			String(v.get("weekday_name", "")),
			int(s.get("sales", 0)),
			int(s.get("lost", 0)),
			int(s.get("kiez_delta", 0)))
	var tally := _tally()
	if tally != null:
		tally.set_summary(s)
		if _capture_mode:
			# A capture must show the finished numbers, never a half-counted tally.
			pass
		else:
			tally.play()
	var cash := get_node_or_null("%Cash") as Label
	if cash != null:
		cash.text = Strings.CASH % Palette.money(float(s.get("cash_after", v.get("cash", 0.0))))

func _on_continue() -> void:
	# Follow the phase the reducer LANDED in, and only when it took the action: the last night's
	# `advance_day` ends the season, and naming "manage" regardless put the player on a board where
	# every control is live and every action refused.
	if dispatch({"type": "advance_day"}):
		request_screen.emit(Screen.screen_for(String(view().get("phase", "manage"))))

func _paint(path: String, col: Color) -> void:
	var r := get_node_or_null(path) as ColorRect
	if r != null:
		r.color = col

func _tally() -> SummaryTally:
	return get_node_or_null("%Tally") as SummaryTally
