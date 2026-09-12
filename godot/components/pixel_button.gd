class_name PixelButton
extends Button
## The one button. Chrome comes from Theme.tres (normal/hover/pressed/disabled + a focus ring, so the
## keyboard works); the only thing a caller sets is the label, an optional icon id and the engine
## action it stands for. Scenes listen to `activated` and hand the dictionary straight to `dispatch`.

signal activated(action: Dictionary)

## An asset id (e.g. "ui/icon_pfand"). Resolved through Assets, so it shows a placeholder until art lands.
@export var icon_id: String = "":
	set(v):
		icon_id = v
		_refresh_icon()

## The engine action this button means, e.g. {"type": "serve_active", "give": ["beer"]} (docs/05 section 3).
@export var action: Dictionary = {}

func _ready() -> void:
	Palette.prepare()
	focus_mode = Control.FOCUS_ALL
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_refresh_icon()

func _on_pressed() -> void:
	activated.emit(action)

func _refresh_icon() -> void:
	if icon_id == "":
		icon = null
		return
	icon = Assets.texture(icon_id)
	expand_icon = false
