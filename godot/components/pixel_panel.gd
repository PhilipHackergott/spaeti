class_name PixelPanel
extends PanelContainer
## The one dark translucent Coffee-Talk box. Anything that needs a surface instances this instead of
## styling its own PanelContainer. Use `variation` to switch between the pool's surfaces
## (&"" = panel, &"DialoguePanel", &"BubblePanel", &"SlotPanel", &"FlatPanel"); all of them live in Theme.tres.

@export var title: String = "":
    set(v):
        title = v
        _refresh()

@export var variation: StringName = &"":
    set(v):
        variation = v
        theme_type_variation = v

func _ready() -> void:
    Palette.prepare()
    _refresh()

func _refresh() -> void:
    var t := get_node_or_null("%Title") as Label
    if t == null:
        return
    t.text = title
    t.visible = title != ""

## The node new children go into (so the panel keeps its own padding + title).
func content() -> Control:
    return get_node_or_null("%Content") as Control

func add_content(n: Node) -> void:
    var c := content()
    if c != null:
        c.add_child(n)

func clear_content() -> void:
    var c := content()
    if c == null:
        return
    for ch in c.get_children():
        c.remove_child(ch)
        ch.queue_free()
