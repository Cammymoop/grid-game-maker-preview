extends ConfirmationDialog

signal command_selected(command_id: int, slot_id: int)
signal hidden

@export var exclude_conditions: bool = false
@export var exclude_actions: bool = false

var names_to_ids: Dictionary = {}
var names_to_categories: Dictionary = {}

var use_v3: bool = true

func _ready():
	visibility_changed.connect(_on_vis_changed)
	close_requested.connect(close_dialog)
	if use_v3:
		build_v3_list()
	else:
		build_base_list()

func build_base_list() -> void:
	var list = find_child("AllCommands")
	list.clear()
	
	for comm in Commands.Friendly:
		if exclude_actions and Commands.is_action(comm):
			continue
		if exclude_conditions and Commands.is_condition(comm):
			continue
		var command_name = Commands.Friendly[comm].display_name
		names_to_ids[command_name] = comm
	
	for command_name in names_to_ids:
		list.add_item(command_name)

func build_v3_list() -> void:
	var list: = find_child("AllCommands") as ItemList
	list.clear()
	
	names_to_ids = {}
	names_to_categories = {}
	var tooltips: = {}
	
	for qualified_cmd in ConditionalsV3.all_commands:
		var cmd_info = ConditionalsV3.get_command_info(qualified_cmd)
		if exclude_conditions:
			pass
		if exclude_actions:
			pass
		var display_name = cmd_info["display_name"]
		names_to_ids[display_name] = qualified_cmd
		var category_hint = ConditionalsV3.get_command_slot_type_hint(qualified_cmd)
		names_to_categories[display_name] = category_hint
		tooltips[qualified_cmd] = cmd_info["tooltip"]
	
	var i: = 0
	for display_name in names_to_ids:
		list.add_item(display_name)
		list.set_item_tooltip(i, tooltips[names_to_ids[display_name]])
		i += 1

func set_items(new_list) -> void:
	var list = find_child("AllCommands")
	list.clear()
	
	for command_name in new_list:
		list.add_item(command_name)

func done() -> void:
	var list = find_child("AllCommands")
	if len(list.get_selected_items()) < 1:
		return
	var selected = list.get_item_text(list.get_selected_items()[0])
	
	var selected_id = names_to_ids[selected]
	var slot = find_child("SlotSelectorButton").current_slot_id
	emit_signal("command_selected", selected_id, slot)
	close_dialog()


func _on_AddConditionDialog_confirmed():
	done()


func get_current_slot_id() -> int:
	var slot_selector = find_child("SlotSelectorButton")
	return slot_selector.current_slot_id

func get_slot_filtered_list(slot_id: int) -> Array:
	if not use_v3 or slot_id < 0:
		return names_to_ids.keys()
	var cur_slot_category: String = Commands.SLOT_CATEGORIES[slot_id]
	var filtered_names = []
	for cmd_name in names_to_categories.keys():
		var categories: Array = names_to_categories[cmd_name]
		if not categories or "all" in categories or cur_slot_category in categories:
			filtered_names.append(cmd_name)
	return filtered_names

func get_current_slot_filtered_list() -> Array:
	return get_slot_filtered_list(get_current_slot_id())


func reapply_filters() -> void:
	var filter_text = find_child("FilterInput").text
	var all = get_current_slot_filtered_list()
	set_items(apply_text_filter(all, filter_text))

func _on_Filter_text_changed(_new_text):
	reapply_filters()

func apply_text_filter(list: Array, filter_str: String) -> Array:
	if len(filter_str) < 1:
		return list.duplicate()
	filter_str = filter_str.to_lower()
	var sortable: Array[Dictionary] = []
	
	for s: String in list:
		var filters_left = filter_str
		var lower = s.to_lower()
		var sortable_item: = {}
		for i in range(len(lower)):
			if filters_left[0] == lower[i]:
				if len(filters_left) <= 1:
					#new_list.append(s)
					sortable_item["item"] = s
					break
				filters_left = filters_left.substr(1)
		if sortable_item:
			sortable_item["score"] = 0
			for i in range(len(filter_str)-1, -1, -1):
				if lower.contains(filter_str.substr(0, i+1)):
					sortable_item["score"] = i + 1
					if lower.begins_with(filter_str.substr(0, i+1)):
						sortable_item["score"] += 50
					break
			sortable.append(sortable_item)
	if sortable.size() == 0:
		return []
	
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] == b["score"]:
			return a["item"].nocasecmp_to(b["item"]) < 0
		return a["score"] > b["score"]
	)

	return sortable.map(Utility.get_dict_item.bind("item", ""))

func _on_AllCommands_item_activated(_index):
	done()

func close_dialog():
	hide()

func _on_slot_selector_button_slot_changed(_new_slot_id: Variant) -> void:
	reapply_filters()

func _on_vis_changed():
	if not visible:
		hidden.emit()