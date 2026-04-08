@tool
extends SubViewport

func _process(_delta: float) -> void:
    var my_size: = size_2d_override
    
    if canvas_transform.origin != my_size/2.0:
        canvas_transform.origin = my_size/2.0