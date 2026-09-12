class_name Transition
extends ColorRect
## The dusk-to-night wipe between screens. `cover_then(cb)` fades to black, runs the callable while
## nothing is visible, then fades back — so a scene swap never flashes.

signal covered()
signal revealed()

@export var duration: float = 0.22

func _ready() -> void:
	Palette.prepare()
	color = Palette.INK_DEEP
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false

func cover() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if Palette.reduce_motion or not is_inside_tree():
		modulate.a = 1.0
		covered.emit()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, duration)
	tw.tween_callback(func() -> void: covered.emit())

func reveal() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Palette.reduce_motion or not is_inside_tree():
		modulate.a = 0.0
		visible = false
		revealed.emit()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(func() -> void:
		visible = false
		revealed.emit())

## Fade out, run `cb`, fade back in.
func cover_then(cb: Callable) -> void:
	if Palette.reduce_motion or not is_inside_tree():
		cb.call()
		return
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, duration)
	tw.tween_callback(cb)
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_callback(func() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		revealed.emit())
