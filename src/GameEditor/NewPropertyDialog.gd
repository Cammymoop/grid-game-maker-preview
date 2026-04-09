extends ConfirmationDialog

signal hidden

func _ready():
	visibility_changed.connect(Callable(self, "_on_vis_changed"))
	await get_tree().process_frame
	find_child("SetName").grab_focus.call_deferred()
	
func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		get_ok_button().emit_signal("pressed")
		get_viewport().set_input_as_handled()

func _on_vis_changed():
	if not visible:
		hidden.emit()