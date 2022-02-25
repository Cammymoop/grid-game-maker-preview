extends Control

func _ready():
	visible = false

func _process(_delta):
	if not visible:
		return
	hide_check()

func add_something(node: Node) -> void:
	visible = true
	add_child(node)

func hide_check() -> void:
	if get_child_count() <= 1:
		# Only the color rect is in the popup layer
		visible = false
