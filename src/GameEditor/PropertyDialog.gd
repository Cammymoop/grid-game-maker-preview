extends ConfirmationDialog

var conditional_editor_scn = preload("res://Scenes/GameEditor/ConditionalEditor/ConditionalEditor.tscn")

var conditional_val = {}
var conditional_mode: = false

func set_info(prop_name, prop_val) -> void:
	find_child("SetName").text = prop_name
	if typeof(prop_val) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		find_child("CheckButton").set_pressed_no_signal(true)
		_on_toggle(true)
		conditional_val = prop_val
	else:
		find_child("SetValue").text = prop_val


func _on_EditConditional_pressed():
	var editor = conditional_editor_scn.instantiate()
	
	var ui_root = find_parent("UIRoot")
	if not ui_root:
		print_debug("Can't get UI Layer")
		return
	
	ui_root.add_popup_layer_node(editor)
	editor.popup()
	if conditional_val:
		editor.load_conditional_data(conditional_val)
	
	editor.connect("save_conditional", Callable(self, "on_save_conditional"))

func on_save_conditional(new_conditional) -> void:
	conditional_val = new_conditional

func get_value():
	if conditional_mode:
		return conditional_val
	else:
		return find_child("SetValue").text

func _on_toggle(button_pressed):
	conditional_mode = button_pressed
	if button_pressed:
		find_child("SetValue").visible = false
		find_child("EditConditional").visible = true
	else:
		find_child("SetValue").visible = true
		find_child("EditConditional").visible = false

func _on_Button_pressed():
	if not conditional_val:
		return
	var result = OldConditionalConverter.to_new(conditional_val)
	if result:
		print("converted from old data")
		print(str(result))
		conditional_val = result
