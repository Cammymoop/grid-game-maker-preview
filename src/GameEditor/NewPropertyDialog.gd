extends ConfirmationDialog

signal hidden

func _ready():
	visibility_changed.connect(Callable(self, "_on_vis_changed"))
	await get_tree().process_frame
	find_child("SetName").grab_focus()
	
	var all_events = ConditionalsV2.get_all_events()
	var popup_list = find_child("SelectEvent").get_popup()
	
	for event in all_events:
		popup_list.add_item(event)
	
	popup_list.connect("index_pressed", Callable(self, "selected_event"))

func selected_event(index):
	var popup_list = find_child("SelectEvent").get_popup()
	var text = popup_list.get_item_text(index)
	find_child("SetName").text = text

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		get_ok_button().emit_signal("pressed")
		get_viewport().set_input_as_handled()

func _on_vis_changed():
	if not visible:
		hidden.emit()