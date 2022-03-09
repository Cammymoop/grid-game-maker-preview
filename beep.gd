extends Control

onready var cond_list = find_node("ConditionsList")
onready var true_actions_list = find_node("TrueActionsList")
onready var false_actions_list = find_node("FalseActionsList")
onready var always_actions_list = find_node("AlwaysActionsList")

onready var add_condition_dialog = find_node("AddConditionDialog")
onready var add_action_dialog = find_node("AddActionDialog")

onready var action_tabs = find_node("ActionsTabs")

var command_list_item: PackedScene = preload("res://Scenes/GameEditor/CommandListItem.tscn")

func _ready():
	add_condition_dialog.connect("command_selected", self, "add_command", ["condition"])
	add_action_dialog.connect("command_selected", self, "add_command", ["action"])

func add_command(command_code: int, slot_id: int, destination: String) -> void:
		var new_list_item = command_list_item.instance()
		new_list_item.set_slot(slot_id)
		new_list_item.set_ui_data(command_code, Commands.Friendly[command_code])
		
		var to_list
		if destination == "condition":
			to_list = cond_list
		else:
			to_list = action_tabs.get_current_list()
		
		to_list.add_child(new_list_item)

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
	var data: = {}
	data["code"] = command_input_node.get_command_code()
	data["slot"] = command_input_node.get_slot_id()
	data["options"] = command_input_node.get_option_values()
	return data

func _on_NewConditionButton_pressed():
	add_condition_dialog.popup_centered()
	
	print(get_full_conditional_data())


func _on_NewActionButton_pressed():
	add_action_dialog.popup_centered()
