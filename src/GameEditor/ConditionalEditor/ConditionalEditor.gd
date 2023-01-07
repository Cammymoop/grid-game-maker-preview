extends Popup

# warning-ignore:unused_signal
signal save_conditional

onready var cond_list = find_node("ConditionsList")
onready var true_actions_list = find_node("TrueActionsList")
onready var false_actions_list = find_node("FalseActionsList")
onready var always_actions_list = find_node("AlwaysActionsList")

onready var add_condition_dialog = find_node("AddConditionDialog")
onready var add_action_dialog = find_node("AddActionDialog")

onready var action_tabs = find_node("ActionsTabs")

var command_list_item: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/CommandListItem.tscn")

func _ready():
	add_condition_dialog.connect("command_selected", self, "add_command", ["conditions"])
	add_action_dialog.connect("command_selected", self, "add_command", ["actions"])
	
	popup()

func add_command(command_code: int, slot_id: int, destination: String, option_values: Array = []) -> void:
		var new_list_item = command_list_item.instance()
		new_list_item.set_slot(slot_id)
		new_list_item.set_ui_data(command_code, Commands.Friendly[command_code])

		var to_list = cond_list
		match destination:
			"actions":
				to_list = action_tabs.get_current_list()
			"conditions":
				to_list = cond_list
			"true_actions":
				to_list = true_actions_list
			"false_actions":
				to_list = false_actions_list
			"always_actions":
				to_list = always_actions_list
			_:
				print_debug("unkown command list: %s" % destination)
		
		to_list.add_child(new_list_item)
		
		if option_values:
			new_list_item.generate_ui()
			new_list_item.set_option_values(option_values)

func load_conditional_data(from_data: Dictionary) -> void:
	for sublist in from_data:
		if not sublist in ["conditions", "true_actions", "false_actions", "always_actions"]:
			continue
		for command in from_data[sublist]:
			var opts = command.options if command.has("options") else []
			add_command(command.code, command.slot, sublist, opts)

func get_full_conditional_data() -> Dictionary:
	var data = {
		"conditions": [],
		"true_actions": [],
		"false_actions": [],
		"always_actions": [],
	}
	
	for command_node in cond_list.get_children():
		data.conditions.append(make_command_data(command_node))
	for command_node in true_actions_list.get_children():
		data.true_actions.append(make_command_data(command_node))
	for command_node in false_actions_list.get_children():
		data.false_actions.append(make_command_data(command_node))
	for command_node in always_actions_list.get_children():
		data.always_actions.append(make_command_data(command_node))
	
	return data

func make_command_data(command_input_node) -> Dictionary:
	return command_input_node.get_command_data()

func _on_NewConditionButton_pressed():
	add_condition_dialog.popup_centered()
	
	print(get_full_conditional_data())


func _on_NewActionButton_pressed():
	add_action_dialog.popup_centered()

func _on_SaveButton_pressed():
	emit_signal("save_conditional", get_full_conditional_data())
	queue_free()

func _on_CancelButton_pressed():
	queue_free()
