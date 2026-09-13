class_name DragItem
extends Control
## One carried sprite (docs/08-register-and-tobacco.md section 4.1): the thing under your finger while
## a drag is in flight. It lifts `Palette.DRAG_LIFT` px off the laminate and casts a 1-px
## `Palette.SHADOW` line where it used to stand, so the eye can still tell where it will land.
##
## It has NO state and knows no rules: `DragLayer` moves it, `CounterTray` decides what started it and
## the reducer decides what it meant. Drag is a skin over `scan{uid}` (docs/08 section 4.2) — nothing
## here may ever be the only way to reach an action.

## What it is carrying, for a driver that wants to read it back: the same dictionary the tray handed
## over ({uid, sku_id, brand, icon, ...}). Display only.
var row: Dictionary = {}

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
	visible = false

## `art` is a read-model row: a brand facing when it carries `mark`/`colour`, otherwise a plain SKU
## sprite from its `icon`. Both go through `Assets`/`BrandMark`, so art lands with no code change.
func show_item(art: Dictionary) -> void:
	_boot()
	row = art
	var well := _well()
	if well == null:
		return
	for c in well.get_children():
		well.remove_child(c)
		c.queue_free()
	var node := _art_node(art)
	var sz := Vector2i(16, 16)
	if node != null:
		well.add_child(node)
		sz = Vector2i(node.size)
	custom_minimum_size = Vector2(sz)
	size = Vector2(sz)
	var shadow := _shadow()
	if shadow != null:
		# A 1-px line on the pixel grid IS the ellipse at this scale: an anti-aliased oval would be the
		# first thing on the screen not drawn on whole pixels (docs/01 "Pixel discipline").
		shadow.color = Palette.SHADOW
		shadow.size = Vector2(float(maxi(4, sz.x - 2)), 1.0)
		shadow.position = Vector2(1.0, float(sz.y) + float(Palette.DRAG_LIFT))
	visible = true

func clear() -> void:
	row = {}
	visible = false
	var well := _well()
	if well == null:
		return
	for c in well.get_children():
		well.remove_child(c)
		c.queue_free()

## The carried art: a brand facing, or the SKU sprite the counter row named.
func _art_node(art: Dictionary) -> Control:
	if String(art.get("mark", "")) != "" or String(art.get("brand", "")) != "":
		var mark := BrandMark.new()
		mark.name = "Facing"
		mark.set_facing(BrandMark.merge(art))
		# Lifted off the laminate — the whole tell that it is in the air and not on the counter.
		mark.position = Vector2(0, float(-Palette.DRAG_LIFT))
		return mark
	var icon := String(art.get("icon", ""))
	if icon == "":
		return null
	var tex := TextureRect.new()
	tex.name = "Sprite"
	tex.texture = Assets.texture(icon)
	tex.size = Vector2(Assets.size_of(icon))
	tex.position = Vector2(0, float(-Palette.DRAG_LIFT))
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tex

func _well() -> Control:
	return get_node_or_null("%Well") as Control

func _shadow() -> ColorRect:
	return get_node_or_null("%Shadow") as ColorRect
