@tool
extends SubViewport

func _process(_delta: float) -> void:
    recenter()

func recenter() -> void:
    var my_size: = size_2d_override
    if my_size.x == 0 or my_size.y == 0:
        my_size = size
    
    if canvas_transform.origin != my_size/2.0:
        canvas_transform.origin = my_size/2.0