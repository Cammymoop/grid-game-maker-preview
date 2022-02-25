extends VSlider

signal mouse_released
signal mouse_pressed


func _on_BrushSlide_gui_input(the_event):
	var event: = the_event as InputEventMouseButton
	if not event:
		return
	if event.button_index == BUTTON_MASK_LEFT:
		if not event.is_pressed():
			emit_signal("mouse_released")
		else:
			emit_signal("mouse_pressed")
