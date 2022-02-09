extends ConfirmationDialog

func confirm_with_callbacks(title: String, message: String, parent, callback_ok=false, callback_close=false):
	window_title = title
	dialog_text = message
	
	if callback_ok:
		connect("confirmed", parent, callback_ok)
	if callback_close:
		connect("popup_hide", parent, callback_close)
	connect("popup_hide", self, "queue_free")
	
	parent.add_child(self)
	popup_centered()
