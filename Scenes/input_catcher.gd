extends TextureRect

@export var forward_to: Node

func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    if mouse_filter == Control.MOUSE_FILTER_IGNORE:
        mouse_filter = Control.MOUSE_FILTER_PASS
    if forward_to:
        process_mode = Node.PROCESS_MODE_ALWAYS

func _gui_input(event: InputEvent) -> void:
    if forward_to:
        forward_to.forwarded_gui_input(event)

func _shortcut_input(event: InputEvent) -> void:
    if forward_to:
        forward_to.forwarded_shortcut_input(event)
