class_name OrderCard
extends Control
## What she asked for, in her own words (docs/08-register-and-tobacco.md section 1, section 4.1): one
## `RequestChip` per basket line on `Palette.ORDER_RECT`, ticked when the reducer says that line is
## satisfied. Tab swaps it for the `StatsStrip`, which is why the two share the left gutter.
##
## **The chip prints the swatch and the CATEGORY, never the brand name** — unless the engine says the
## customer used it (`name_shown`, from `archetype.speech` / `config.brand_hint`, docs/08 section 2).
## That is the whole difference between reading a list and running a shop, and it lives in the
## read-model: a component may not decide how much a customer gave away.
##
## `satisfied` is the reducer's opinion (docs/08 section 3.3), so a tick can never be a screen's guess.
##
## While you are turned around it re-docks to `Palette.ORDER_RECT_WALL` and goes COMPACT: the marks
## and the counts in one row, because the wall has no room for her sentences and the mark is the only
## part of them you are about to act on.

## `view.order` (display only) and who is saying it.
var _order: Array = []
var _speaker: String = ""
var _on_wall: bool = false
## What is drawn right now, so the per-frame render only rebuilds when the order actually moved.
var _sig: String = ""

const CHIP_H := 18
const CHIP_COMPACT_W := 26
const QTY_W := 22
const MARK_PX := 16
const TICK := 6

## Has `_boot` run? See `_boot`.
var _booted: bool = false

func _ready() -> void:
	_boot()

## docs/04 rule 2 (tree-optional): the work `_ready` does is done on FIRST USE instead of waiting for
## a tree that a capture, a test or a driver may never give this instance. Idempotent.
func _boot() -> void:
	if _booted:
		return
	_booted = true
	Palette.prepare()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := get_node_or_null("%Plate") as PanelContainer
	if plate != null:
		plate.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL_INK, Palette.EDGE, 3, 2))
	set_docked(false)
	render([], "")

## `order` is `view.order`; `speaker` is the name the DialogueBox would print, so the card and the box
## never call the same person two different things.
func render(order: Array, speaker: String) -> void:
	_order = order
	_speaker = speaker
	_collapse(order.size())   # height follows the row count even when the chips host is not resolvable yet
	var head := get_node_or_null("%Who") as Label
	if head != null:
		head.text = speaker if speaker != "" else Strings.SOMEONE
		head.add_theme_color_override("font_color", Palette.AMBER_SOFT)
	var host := _chips()
	if host == null:
		return
	var sig := JSON.stringify(order) + speaker + str(_on_wall)
	if sig == _sig:
		return
	_sig = sig
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
	var empty := get_node_or_null("%Empty") as Label
	if empty != null:
		empty.text = Strings.ORDER_EMPTY
		empty.visible = order.is_empty()
	# The SCENE owns whether the card is on screen at all (docs/08 4.3: the left gutter is the card or
	# the stats sheet, never both) — an empty order still has a head and a "nothing yet" line.
	for i in order.size():
		host.add_child(_chip(order[i], i))

## The card is exactly as tall as it has rows (2026-09-13, the judge: opaque panels out-weigh the guest,
## "collapse the order card around its rows"). The dock rect is the MAXIMUM; an empty order keeps one row
## for the "nothing yet" line. Width and position never move, so every reachability rect is unchanged.
func _collapse(rows: int) -> void:
	var r := Palette.ORDER_RECT_WALL if _on_wall else Palette.ORDER_RECT
	var head_h := 18
	var body := (CHIP_H if _on_wall else CHIP_H * maxi(1, rows)) + 3
	var h := mini(r.size.y, head_h + body)
	# custom_minimum_size FIRST: a Control never shrinks below the minimum it is already carrying, so
	# assigning `size` while the dock's full height is still the minimum silently clamps it back.
	var want := Vector2(float(r.size.x), float(h))
	custom_minimum_size = want
	size = want
	var plate := get_node_or_null("%Plate") as Control
	if plate != null:
		plate.custom_minimum_size = want
		plate.size = want
	var host := _chips()
	if host != null:
		host.size = Vector2(float(r.size.x - 4), float(h - head_h))

## Which chip stands for this basket line — the reachability test reads the card rather than counting
## children, because the order is the engine's list and its indices are the engine's too.
func chip_for(index: int) -> Control:
	var host := _chips()
	if host == null or index < 0 or index >= host.get_child_count():
		return null
	return host.get_child(index) as Control

## Counter dock (a column of sentences) or wall dock (a row of marks). One card, two shapes.
func set_docked(on_wall: bool) -> void:
	_boot()
	_on_wall = on_wall
	var r := Palette.ORDER_RECT_WALL if on_wall else Palette.ORDER_RECT
	position = Vector2(r.position)
	size = Vector2(r.size)
	custom_minimum_size = Vector2(r.size)
	var plate := get_node_or_null("%Plate") as Control
	if plate != null:
		plate.size = Vector2(r.size)
	var host := _chips()
	if host != null:
		host.size = Vector2(float(r.size.x - 4), float(r.size.y - 18))
	_sig = ""   # the dock decides the chips' shape, so they are rebuilt on every re-dock
	render(_order, _speaker)


## One request: how many, the mark, what it is, and whether it is already on the counter.
## One request: how many, the mark, what it is, and whether it is already on the counter. Laid out by
## hand rather than by a Container, for the same reason the register is (docs/04 rule 2): a Container
## sorts its children on a tree notification, and this screen is measured on instances that never
## entered a tree.
func _chip(entry: Dictionary, index: int) -> Control:
	var wide := CHIP_COMPACT_W if _on_wall else Palette.ORDER_RECT.size.x - 6
	var chip := Control.new()
	chip.name = "Chip%d" % index
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.position = Vector2(float(index * CHIP_COMPACT_W) if _on_wall else 0.0,
		0.0 if _on_wall else float(index * CHIP_H))
	chip.size = Vector2(float(wide), float(CHIP_H))
	chip.custom_minimum_size = chip.size
	var qty_w := 10 if _on_wall else QTY_W
	var qty := Label.new()
	qty.name = "Qty"
	qty.theme_type_variation = &"TinyLabel"
	# clip_text FIRST, then the text, then the rect. A Label's minimum width is its text until it is
	# told to clip, and a Control never shrinks below a minimum it has already been given — so setting
	# the size before the clip leaves a 24-px money column 30 px wide, over the chip beside it.
	qty.clip_text = true
	qty.text = Strings.QTY % int(entry.get("qty", 1))
	qty.position = Vector2.ZERO
	qty.size = Vector2(float(qty_w), float(CHIP_H))
	qty.custom_minimum_size = qty.size
	qty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(qty)
	var art := _art(entry)
	art.position = Vector2(float(qty_w + 1), float((CHIP_H - MARK_PX) / 2))
	chip.add_child(art)
	if not _on_wall:
		var what_x := qty_w + 1 + MARK_PX + 2
		var what := Label.new()
		what.name = "What"
		what.theme_type_variation = &"SmallLabel"
		what.clip_text = true
		what.text = _wording(entry)
		what.position = Vector2(float(what_x), 0.0)
		what.size = Vector2(float(wide - what_x - TICK - 2), float(CHIP_H))
		what.custom_minimum_size = what.size
		what.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		what.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(what)
	var tick := ColorRect.new()
	tick.name = "Tick"
	tick.color = Palette.GOOD
	tick.size = Vector2(TICK, TICK)
	tick.custom_minimum_size = tick.size
	tick.position = Vector2(float(wide - TICK), float(1 if _on_wall else (CHIP_H - TICK) / 2))
	tick.visible = bool(entry.get("satisfied", false))
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(tick)
	return chip

## The swatch: a brand mark when she pointed at the wall, the SKU's own sprite when she did not.
func _art(entry: Dictionary) -> Control:
	if String(entry.get("mark", "")) != "":
		var mark := BrandMark.new()
		mark.name = "Mark"
		mark.set_brand(entry, MARK_PX)
		return mark
	var icon := String(entry.get("icon", ""))
	var well := Control.new()
	well.name = "Icon"
	well.custom_minimum_size = Vector2(MARK_PX, MARK_PX)
	well.clip_contents = true
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "":
		var tex := TextureRect.new()
		tex.name = "Sprite"
		tex.texture = Assets.texture(icon)
		var sz := Assets.size_of(icon)
		tex.size = Vector2(sz)
		# A 36-px bottle cannot stretch a chip row, so the well CLIPS it the way `ItemSlot` does.
		tex.position = Palette.snap(Vector2(float(MARK_PX - sz.x) * 0.5, float(MARK_PX - sz.y) * 0.5))
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(tex)
	return well

## What the chip is allowed to say. Two different names arrive in the row and confusing them is the
## whole bug this replaced: `brand_name` is "Adler" and the ENGINE withholds it (sends "") unless the
## customer actually used it, while `name` is the SKU's own word — "Cigarettes", "Mate", "Papers".
## So in `mark` mode the chip says WHAT she wants and never WHICH ONE: the shape and the colour are
## the whole puzzle, and printing "Adler" beside them would give it away (docs/08 §1's card prints
## "Mate" / "Cigarettes" / "Papers, long"; §2 is what forbids the brand).
func _wording(entry: Dictionary) -> String:
	var brand_name := String(entry.get("brand_name", ""))
	if bool(entry.get("name_shown", false)) and brand_name != "":
		return brand_name
	var shown := String(entry.get("name", ""))
	if shown != "":
		return shown
	# The Pfand row has no SKU of its own (`Content.sku("pfand")` is {} on purpose), so the category
	# is what names it — and the deposit keeps its German name from the string table.
	var category := String(entry.get("category", ""))
	if category == "pfand":
		return Strings.PFAND
	return category if category != "" else String(entry.get("said", ""))

func _chips() -> Control:
	return get_node_or_null("%Chips") as Control
