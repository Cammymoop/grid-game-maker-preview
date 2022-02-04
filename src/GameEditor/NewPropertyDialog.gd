extends ConfirmationDialog

func _ready():
	yield(get_tree(), "idle_frame")
	find_node("SetName").grab_focus()
	
	var all_events = ConditionalFunctions.get_all_events()
	var popup_list = find_node("SelectEvent").get_popup()
	
	for event in all_events:
		popup_list.add_item(event)
	
	popup_list.connect("index_pressed", self, "selected_event")

func selected_event(index):
	var popup_list = find_node("SelectEvent").get_popup()
	var text = popup_list.get_item_text(index)
	find_node("SetName").text = text

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ENTER:
		get_ok().emit_signal("pressed")
		get_tree().set_input_as_handled()
