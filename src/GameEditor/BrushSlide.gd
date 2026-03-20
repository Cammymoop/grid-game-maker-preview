extends HSlider

signal mouse_released


func _on_BrushSlide_gui_input(the_event):
	var event: = the_event as InputEventMouseButton
	if not event:
		return
	if event is InputEventMouseButton and not event.is_pressed():
		if event.button_index == MOUSE_BUTTON_MASK_LEFT:
			print("releasing")
			emit_signal("mouse_released")
