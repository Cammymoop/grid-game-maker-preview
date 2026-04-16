extends ConfirmationDialog

signal hidden

func _ready():
	visibility_changed.connect(Callable(self, "_on_vis_changed"))
	await get_tree().process_frame
	var name_input: LineEdit = find_child("SetName")
	name_input.grab_focus.call_deferred()
	name_input.text_submitted.connect(on_name_submitted)
	
func on_name_submitted(_text: String) -> void:
	get_ok_button().pressed.emit()

func _on_vis_changed():
	if not visible:
		hidden.emit()