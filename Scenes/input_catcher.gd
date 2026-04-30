extends TextureRect

@export var forward_to: Node

func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    if mouse_filter == Control.MOUSE_FILTER_IGNORE:
        mouse_filter = Control.MOUSE_FILTER_PASS
    if forward_to:
        process_mode = Node.PROCESS_MODE_ALWAYS
        if forward_to.has_signal("request_grab_gui_focus"):
            forward_to.request_grab_gui_focus.connect(try_grab_focus)

func _gui_input(event: InputEvent) -> void:
    if forward_to:
        forward_to.forwarded_gui_input(event)

func _shortcut_input(event: InputEvent) -> void:
    if forward_to:
        forward_to.forwarded_shortcut_input(event)

func _process(_delta: float) -> void:
    if get_tree().paused:
        return
    var focus_owner = get_viewport().gui_get_focus_owner()
    if not focus_owner or focus_owner != self:
        grab_focus()

func try_grab_focus() -> void:
    var focus_owner = get_viewport().gui_get_focus_owner()
    if focus_owner != self:
        grab_focus()