extends ConfirmationDialog

signal hidden

func confirm_with_callbacks(with_title: String, message: String, ok_callback: Callable = Callable(), close_callback: Callable = Callable()):
	title = with_title
	dialog_text = message
	
	if ok_callback.is_valid():
		confirmed.connect(ok_callback)
	if close_callback.is_valid():
		hidden.connect(close_callback)
	hidden.connect(queue_free)

	popup_centered()

func _on_vis_changed():
	if not visible:
		hidden.emit()
		