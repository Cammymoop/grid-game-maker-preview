extends Window

# warning-ignore:unused_signal
signal save_conditional

@onready var cond_list = find_child("ConditionsList")
@onready var true_actions_list = find_child("TrueActionsList")
@onready var false_actions_list = find_child("FalseActionsList")
@onready var always_actions_list = find_child("AlwaysActionsList")

@onready var add_condition_dialog = find_child("AddConditionDialog")
@onready var add_action_dialog = find_child("AddActionDialog")

@onready var action_tabs = find_child("ActionsTabs")

var command_list_item: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/CommandListItem.tscn")

const ConditionalsV3 = preload("res://src/Singletons/conditionals_v3.gd")
var use_conditionalv3 = true

func _ready():
	add_condition_dialog.connect("command_selected", Callable(self, "add_command").bind("conditions"))
	add_action_dialog.connect("command_selected", Callable(self, "add_command").bind("actions"))
	
	popup()

func add_command(command_code: int, slot_id: int, destination: String, option_values: Array = []) -> void:
		var new_list_item = command_list_item.instantiate()
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
	if _is_raw_data_v3(from_data):
		load_v3_conditional_data(from_data)
		return
	for sublist in from_data:
		if not sublist in ["conditions", "true_actions", "false_actions", "always_actions"]:
			continue
		for command in from_data[sublist]:
			var opts = command.options if command.has("options") else []
			add_command(command.code, command.slot, sublist, opts)

func load_v3_conditional_data(from_data: Dictionary) -> void:
	var sublists = ["conditions", "when true", "when false", "when always"]
	var old_sublists = ["conditions", "true_actions", "false_actions", "always_actions"]
	for sublist in from_data:
		if not sublist in sublists:
			continue
		var old_sublist = old_sublists[sublists.find(sublist)]
		for command in from_data[sublist]:
			var split_cmd = command.split(":")
			var code = ConditionalsV3.V3_CMD_MAP.find_key(split_cmd[0].trim_prefix("basic_default."))
			if not code:
				push_error("Unknown command: %s" % split_cmd[0])
			elif len(split_cmd) < 2:
				add_command(code, Commands.Slot.RED, old_sublist, [])
			else:
				var split_args = split_cmd[1].split(",", true)
				var slot_id: int = int(split_args[0].split("|")[0])
				var options = [] if len(split_args) < 2 else split_args.slice(1)
				add_command(code, slot_id, old_sublist, options)

func _is_raw_data_v3(the_data: Dictionary) -> bool:
	return the_data.get("v", "") == "3"

func get_full_conditional_data() -> Dictionary:
	if use_conditionalv3:
		return get_v3_full_conditional_data()

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

func get_v3_full_conditional_data() -> Dictionary:
	var data = {
		"v": "3",
		"conditions": [],
		"when true": [],
		"when false": [],
		"when always": [],
	}
	
	for command_node in cond_list.get_children():
		data.conditions.append(make_v3_command_data(command_node))
	for command_node in true_actions_list.get_children():
		data["when true"].append(make_v3_command_data(command_node))
	for command_node in false_actions_list.get_children():
		data["when false"].append(make_v3_command_data(command_node))
	for command_node in always_actions_list.get_children():
		data["when always"].append(make_v3_command_data(command_node))
	
	return data

func make_v3_command_data(command_input_node) -> String:
	var data = command_input_node.get_command_data()
	var args: Array[String] = [str(data.slot)]
	for opt in data.options:
		args.append(str(opt))
	return "basic_default.%s:%s" % [ConditionalsV3.V3_CMD_MAP[data.code], ",".join(args)]

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
