extends Screen
## The nightly P&L: one centred card over the closed shop, the tally counting itself up, and the way
## back to the next day. The arithmetic is the engine's — this only reads `view.summary`.

func _ready() -> void:
	super._ready()
	var cont := get_node_or_null("%Continue") as Button
	if cont != null and not cont.pressed.is_connected(_on_continue):
		cont.pressed.connect(_on_continue)
	var tally := _tally()
	if tally != null and not _capture_mode:
		tally.play()

func render(v: Dictionary) -> void:
	if v.is_empty():
		return
	var layers := get_node_or_null("%SceneLayers") as SceneLayers
	if layers != null:
		layers.set_time(1.0)
	var s: Dictionary = v.get("summary", {})
	var title := get_node_or_null("%Title") as Label
	if title != null:
		title.text = "Nacht %d abgerechnet" % int(s.get("day", v.get("day", 1)))
	var sub := get_node_or_null("%Sub") as Label
	if sub != null:
		sub.text = "%s · %d verkauft · %d verpasst · Kiez %+d" % [
			String(v.get("weekday_name", "")),
			int(s.get("sales", 0)),
			int(s.get("lost", 0)),
			int(s.get("kiez_delta", 0)),
		]
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
		cash.text = "Kasse " + Palette.money(float(s.get("cash_after", v.get("cash", 0.0))))

func _on_continue() -> void:
	dispatch({"type": "advance_day"})
	request_screen.emit("manage")

func _tally() -> SummaryTally:
	return get_node_or_null("%Tally") as SummaryTally
