class_name DragLayer
extends Control
## The manual drag (docs/08-register-and-tobacco.md section 4.2). Godot's own
## `_get_drag_data` / `_can_drop_data` / `_drop_data` was evaluated and REJECTED, and the four reasons
## are written down there so nobody tries it again: a fractional preview position at x4, a preview
## reparented outside the screen's tree (so unthemed), drag data that must stay a plain Dictionary
## because the night rebuilds the tray under the drag, and — the one that decides it — no keyboard
## path and no headless driver, while this project's entire test culture is synthesised input.
##
## So: `Palette.snap()` every frame, the theme kept, a plain payload, a `Palette.DRAG_GRAB_PX` grab
## threshold, and `move_to` / `release_at` so a driver can play a drag with no viewport at all.
##
## **Drag is a skin over `scan{uid}`.** Under the threshold it is a click, and a click on a tray item
## scans it — which is the primary path. Nothing here is ever the only way to reach an action.

## A real drop on a target that took it. The scene turns the pair into an engine action.
signal dropped(payload: Dictionary, target: Control)
## The drag ended on nothing: the item springs home and the state never moved.
signal missed(payload: Dictionary)
## Which target the carried item's CENTRE is over right now (null for none). The scanner's glass arms
## off this, so it lights the moment the item is actually over the hot zone and not a pixel before.
signal hovering(target: Control)

var _payload: Dictionary = {}
var _from: Vector2 = Vector2.ZERO
var _dragging: bool = false

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
	# The layer is a lens, never a lid: it covers the whole frame and must not eat a single click.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	var item := _item()
	if item != null:
		item.clear()

## `payload` is what the drop MEANS ({kind:"item", uid:3} / {kind:"crate", uid:1, count:3}); `art` is
## the read-model row it is drawn from. Two dictionaries, because the thing you can see and the thing
## the reducer will be told are not the same object — and only the second may ever reach `dispatch`.
func begin(payload: Dictionary, art: Dictionary, from: Vector2) -> void:
	_boot()
	_payload = payload.duplicate(true)
	_from = Palette.snap(from)
	_dragging = true
	var item := _item()
	if item != null:
		item.show_item(art)
		item.position = _from
	set_process(is_inside_tree())

func is_dragging() -> bool:
	return _dragging

func payload() -> Dictionary:
	return _payload.duplicate(true)

## Where the carried item is right now, in this layer's coordinates. Snapped, always.
func at() -> Vector2:
	var item := _item()
	return item.position if item != null else Vector2.ZERO

## Drive the drag by hand — what a keyboard carry and the headless driver both use, and what
## `_process` calls with the real cursor.
func move_to(p: Vector2) -> void:
	if not _dragging:
		return
	var item := _item()
	if item == null:
		return
	item.position = Palette.snap(p - item.size * 0.5)
	hovering.emit(target_at(item.position + item.size * 0.5))

## The release. Hit-tests the `drop_targets` group at `p`; the topmost target that ACCEPTS the payload
## wins, and a miss springs the item home over `Palette.DRAG_SPRING_MS` instead of vanishing.
func release_at(p: Vector2) -> void:
	if not _dragging:
		return
	var target := target_at(p)
	_dragging = false
	set_process(false)
	if target != null:
		var item := _item()
		if item != null:
			item.clear()
		var taken := _payload
		_payload = {}
		dropped.emit(taken, target)
		return
	var missed_payload := _payload
	_payload = {}
	_spring_home()
	missed.emit(missed_payload)

## The topmost drop target under `p` that would take this payload. Public because the reachability
## test asks the same question the release does, on the same rects, at 480x270.
func target_at(p: Vector2) -> Control:
	var best: Control = null
	for node in _targets():
		var c := node as Control
		if c == null or not _visible_up(c):
			continue
		if not c.has_method("hot_zone") or not c.has_method("accepts"):
			continue
		var zone: Rect2 = c.call("hot_zone")
		if not zone.has_point(p):
			continue
		if not bool(c.call("accepts", _payload)):
			continue
		# Later in the tree is drawn later, so it is the one the finger is actually over.
		if best == null or c.is_greater_than(best):
			best = c
	return best

## The `drop_targets` group when there is a tree to ask, and a walk of the screen when there is not —
## docs/04 rule 2 again: the headless driver plays a whole drag on a Night that never entered one.
func _targets() -> Array:
	if is_inside_tree():
		return get_tree().get_nodes_in_group(Palette.DROP_TARGETS)
	var out: Array = []
	var root: Node = get_parent() if get_parent() != null else self
	_collect(root, out)
	return out

func _collect(node: Node, out: Array) -> void:
	if node.is_in_group(Palette.DROP_TARGETS):
		out.append(node)
	for c in node.get_children():
		_collect(c, out)

## `is_visible_in_tree()` needs a tree; this asks the parent chain the same question.
func _visible_up(c: Control) -> bool:
	var n: Node = c
	while n != null:
		var as_control := n as Control
		if as_control != null and not as_control.visible:
			return false
		n = n.get_parent()
	return true

## THE RELEASE THAT ENDS A POINTER DRAG, and the reason this layer listens to `_input` at all.
##
## The press that started the drag was taken by the tray slot, so Godot keeps the mouse grab on that
## slot for the whole gesture: the drop target under the cursor never sees a button event, and the
## scanner's own `_gui_input` fires on a PRESS, which during a drag has already happened somewhere
## else. Nothing, therefore, ended a real drag — the item hung on the cursor, `is_dragging()` stayed
## true for the rest of the night, the glass stayed armed, and `Turn around` (which stands down mid-
## drag, docs/08 §3.2) was dead from then on. A drag you cannot let go of is the soft-lock class this
## component exists inside, and it shipped because every test so far called `release_at()` by hand.
##
## `_input`, not `_gui_input`: the layer is `MOUSE_FILTER_IGNORE` on purpose — a lens, never a lid.
## The event is deliberately NOT consumed, so the slot still gets its own button-up and resets its
## pressed state; the tray's `_dragged_slot` guard is what stops the release reading as a click too.
func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	release_at(get_global_mouse_position() if is_inside_tree() else _carried_centre())

## Where the carried item's CENTRE is - the point `move_to` hit-tests the hover with, so a release
## outside a tree (the headless tests) lands exactly where the glass said it had armed.
func _carried_centre() -> Vector2:
	var item := _item()
	return item.position + item.size * 0.5 if item != null else Vector2.ZERO

func cancel() -> void:
	if not _dragging:
		return
	_dragging = false
	set_process(false)
	var lost := _payload
	_payload = {}
	_spring_home()
	missed.emit(lost)

## The layer is a full-frame child of the screen, so its local space IS the 480x270 base grid and the
## drop targets' global rects can be hit-tested against a cursor without a single transform.
func _process(_delta: float) -> void:
	if not _dragging or not is_inside_tree():
		return
	move_to(get_global_mouse_position())

## Back where it came from, on the grid the whole way. Instant under reduce_motion, and instant
## outside the tree — a tween with no tree is how a headless test hangs on a drag that never ends.
func _spring_home() -> void:
	var item := _item()
	if item == null:
		return
	if not is_inside_tree() or Palette.reduce_motion:
		item.clear()
		return
	var tw := create_tween()
	tw.tween_property(item, "position", _from, float(Palette.DRAG_SPRING_MS) / 1000.0)
	tw.tween_callback(item.clear)

func _item() -> DragItem:
	return get_node_or_null("%DragItem") as DragItem
