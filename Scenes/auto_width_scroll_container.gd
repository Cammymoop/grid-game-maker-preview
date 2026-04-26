extends ScrollContainer

@export var custom_margin: float = 0

var _has_width_child: bool = false

func _ready() -> void:
    _find_width_child()

func _find_width_child() -> void:
    if _has_width_child:
        return

    var width_child: Control
    for child in get_children():
        if child is Control:
            width_child = child
            break
    if not width_child:
        return
    
    _has_width_child = true
    width_child.minimum_size_changed.connect(on_child_min_size_updated.bind(width_child))
    width_child.tree_exited.connect(on_width_child_left.bind(width_child))
    get_min_width_from(width_child)

func on_child_min_size_updated(width_child: Control) -> void:
    get_min_width_from(width_child)

func get_min_width_from(from_control: Control) -> void:
    custom_minimum_size.x = from_control.get_combined_minimum_size().x + custom_margin

func on_width_child_left(width_child: Control) -> void:
    if _has_width_child:
        _has_width_child = false
    if width_child.minimum_size_changed.is_connected(on_child_min_size_updated):
        width_child.minimum_size_changed.disconnect(on_child_min_size_updated)
    if width_child.tree_exited.is_connected(on_width_child_left):
        width_child.tree_exited.disconnect(on_width_child_left)