extends ConfirmationDialog

signal command_selected(command_id: int, slot_id: int)
signal hidden

@export var filter_input: LineEdit
@export var item_list: ItemList

@export var enable_condition_action_filter: bool = false

var ids_to_names: Dictionary[String, String] = {}
var names_to_ids: Dictionary[String, String] = {}
var ids_to_categories: Dictionary = {}
var ids_condition_exclude: Dictionary[String, bool] = {}
var ids_action_exclude: Dictionary[String, bool] = {}

var condion_mode_includes_actions: bool = true

var is_condition_mode: bool = true
var is_generic_mode: bool = false

func _ready():
	visibility_changed.connect(_on_vis_changed)
	close_requested.connect(close_dialog)
	size_changed.connect(on_resized)
	build_v3_list()

func on_resized() -> void:
	var col_size: = item_list.custom_minimum_size.x
	item_list.max_columns = maxi(1, floori((item_list.size.x + (col_size * .5)) / col_size))

func make_generic() -> void:
	set_list_name("")
	set_is_generic_mode(true)

func set_list_and_mode(new_list_name: String, new_is_condition: bool, new_is_generic: bool = false) -> void:
	is_generic_mode = new_is_generic
	if not is_generic_mode:
		is_condition_mode = new_is_condition
	set_list_name(new_list_name)
	if visible:
		reapply_filters()

func set_list_name(new_list_name: String) -> void:
	if new_list_name == "":
		title = "Add Command"
	else:
		title = "Add Command to %s" % [new_list_name]

func build_v3_list() -> void:
	var list: = find_child("AllCommands") as ItemList
	list.clear()
	
	names_to_ids = {}
	ids_to_names = {}
	ids_to_categories = {}
	ids_condition_exclude = {}
	ids_action_exclude = {}
	var tooltips: = {}
	
	for qualified_cmd in ConditionalsV3.all_commands:
		var cmd_info = ConditionalsV3.get_command_info(qualified_cmd)
		if cmd_info.get("is_deprecated", false):
			continue
		var base_display_name: String = cmd_info["display_name"]
		var display_name: = base_display_name
		for i in 1000:
			if not names_to_ids.has(display_name):
				break
			display_name = base_display_name + " (%s)" % (i + 2)
	
		ids_to_names[qualified_cmd] = display_name
		names_to_ids[display_name] = qualified_cmd

		var category_hint = ConditionalsV3.get_command_slot_type_hint(qualified_cmd)
		ids_to_categories[qualified_cmd] = category_hint
		tooltips[qualified_cmd] = cmd_info["tooltip"]
		if cmd_info.get("non_condition", false):
			ids_condition_exclude[qualified_cmd] = true
		if cmd_info.get("non_action", false):
			ids_action_exclude[qualified_cmd] = true
	
	var i: = 0
	for display_name in names_to_ids:
		list.add_item(display_name)
		list.set_item_tooltip(i, tooltips[names_to_ids[display_name]])
		i += 1

func set_condition_mode(new_is_condition_mode: bool) -> void:
	is_generic_mode = false
	is_condition_mode = new_is_condition_mode
	if visible:
		reapply_filters()

func set_is_generic_mode(new_is_generic_mode: bool) -> void:
	is_generic_mode = new_is_generic_mode
	if visible:
		reapply_filters()

func set_cur_items(new_list) -> void:
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
	if slot_id < 0:
		return names_to_ids.keys()
	var cur_slot_category: String = Commands.SLOT_CATEGORIES[slot_id]
	var filtered_names = []
	for qualified_cmd in ids_to_categories.keys():
		var categories: Array = ids_to_categories[qualified_cmd]
		if not categories or "all" in categories or cur_slot_category in categories:
			filtered_names.append(ids_to_names[qualified_cmd])
	return filtered_names

func filter_list_condition_action(list: Array) -> Array:
	if is_condition_mode and not condion_mode_includes_actions:
		return list
	var cond_action_filtered: = []
	for cmd_name in list:
		var cmd_id = names_to_ids[cmd_name]
		if is_condition_mode and ids_condition_exclude.has(cmd_id):
			continue
		elif not is_condition_mode and ids_action_exclude.has(cmd_id):
			continue
		cond_action_filtered.append(cmd_name)
	return cond_action_filtered

func get_current_slot_filtered_list() -> Array:
	return get_slot_filtered_list(get_current_slot_id())


func reapply_filters() -> void:
	var filtered_list: = get_current_slot_filtered_list()
	if not is_generic_mode:
		filtered_list = filter_list_condition_action(filtered_list)
	set_cur_items(apply_text_filter(filtered_list, filter_input.text))

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
	else:
		on_shown()

func on_shown() -> void:
	filter_input.grab_focus.call_deferred()