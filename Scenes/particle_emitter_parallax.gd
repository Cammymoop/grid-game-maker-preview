extends Parallax2D

var parent_vp: SubViewport = null

var camera_scroll_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
    parent_vp = get_viewport()

func scroll_updated() -> void:
    camera_scroll_pos = -parent_vp.canvas_transform.origin
    screen_offset = camera_scroll_pos
    
    for child in get_children():
        if child is Node2D:
            pass#child.position = camera_scroll_pos * scroll_scale