extends ConfirmationDialog

func _ready():
	yield(get_tree(), "idle_frame")
	find_node("SetName").grab_focus()

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		get_ok().emit_signal("pressed")
		get_tree().set_input_as_handled()
