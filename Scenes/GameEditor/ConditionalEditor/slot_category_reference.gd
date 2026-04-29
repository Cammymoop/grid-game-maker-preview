extends Label

@export var ref_image_node: Control

func _ready() -> void:
    ref_image_node.hide()
    mouse_entered.connect(on_mouse_entered)
    mouse_exited.connect(on_mouse_exited)

func on_mouse_entered() -> void:
    ref_image_node.show()

func on_mouse_exited() -> void:
    ref_image_node.hide()
