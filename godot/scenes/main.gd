extends Control
## The shell: it owns which screen is on, and the fade between them. It holds no game state — the
## Session autoload does, once the engine lane lands; until then every screen runs on MockView.

const SCREENS := {
	"title": preload("res://scenes/Title.tscn"),
	"night": preload("res://scenes/Night.tscn"),
	"manage": preload("res://scenes/Manage.tscn"),
	"summary": preload("res://scenes/Summary.tscn"),
}

## Which screen a capture preset belongs to, so `shot.mjs` can also be pointed at Main.
const PRESET_SCREEN := {
	"title": "title",
	"empty_counter": "night",
	"customer_at_counter": "night",
	"dialogue_choice": "night",
	"serving": "night",
	"pfand": "night",
	"late_night": "night",
	"manage": "manage",
	"summary": "summary",
}

var current_screen: String = ""

func _ready() -> void:
	Palette.prepare()
	show_screen("title", true)

func show_screen(screen_name: String, instant: bool = false) -> void:
	if not SCREENS.has(screen_name):
		push_warning("Main: unknown screen " + screen_name)
		return
	var transition := get_node_or_null("%Transition") as Transition
	if instant or transition == null:
		_swap(screen_name)
	else:
		transition.cover_then(func() -> void: _swap(screen_name))

func apply_capture_preset(preset_name: String) -> void:
	var target: String = PRESET_SCREEN.get(preset_name, "night")
	_swap(target)
	var screen := _screen()
	if screen != null and screen.has_method("apply_capture_preset"):
		screen.apply_capture_preset(preset_name)

func _swap(screen_name: String) -> void:
	var host := get_node_or_null("%Screens") as Control
	if host == null:
		return
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
	var inst := SCREENS[screen_name].instantiate()
	host.add_child(inst)
	current_screen = screen_name
	if inst.has_signal("request_screen"):
		inst.connect("request_screen", _on_request_screen)

func _on_request_screen(screen_name: String) -> void:
	show_screen(screen_name)

func _screen() -> Node:
	var host := get_node_or_null("%Screens") as Control
	if host == null or host.get_child_count() == 0:
		return null
	return host.get_child(0)
