extends ConfirmationDialog

signal command_selected(command_id: int, slot_id: int)
signal hidden

@export var filter_input: LineEdit
@export var item_list: ItemList

@export var category_filter_menu_button: MenuButton

@export var enable_condition_action_filter: bool = false

const CLEAR_ALL_CATEGORY_FILTER_ID: int = 9999

var excluded_feature_categories: Array[String] = []

var ids_to_names: Dictionary[String, String] = {}
var names_to_ids: Dictionary[String, String] = {}

var ids_to_slot_categories: Dictionary[String, Array] = {}
var ids_to_feature_categories: Dictionary[String, Array] = {}
var ids_condition_exclude: Dictionary[String, bool] = {}
var ids_action_exclude: Dictionary[String, bool] = {}
var ids_to_tooltips: Dictionary[String, String] = {}
var ids_to_search_keywords: Dictionary[String, Array] = {}

var condion_mode_includes_actions: bool = true

var is_condition_mode: bool = true
var is_generic_mode: bool = false

func _ready():
	visibility_changed.connect(_on_vis_changed)
	close_requested.connect(close_dialog)
	size_changed.connect(on_resized)
	category_filter_menu_button.about_to_popup.connect(create_category_filter_menu)
	var popup_menu: PopupMenu = category_filter_menu_button.get_popup()
	popup_menu.id_pressed.connect(on_category_filter_menu_id_pressed)
	
	excluded_feature_categories.assign(GameManager.get_feature_category_filter())

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
	ids_to_slot_categories = {}
	ids_to_feature_categories = {}
	ids_condition_exclude = {}
	ids_action_exclude = {}
	ids_to_tooltips = {}
	ids_to_search_keywords = {}
	
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

		var slot_category_hint = ConditionalsV3.get_command_slot_type_hint(qualified_cmd)
		ids_to_slot_categories[qualified_cmd] = slot_category_hint
		ids_to_tooltips[qualified_cmd] = cmd_info["tooltip"]
		if cmd_info.get("non_condition", false):
			ids_condition_exclude[qualified_cmd] = true
		if cmd_info.get("non_action", false):
			ids_action_exclude[qualified_cmd] = true
		
		var feature_categories: Array[String] = []
		feature_categories.assign(cmd_info.get("feature_tags", []))
		ids_to_feature_categories[qualified_cmd] = feature_categories
		
		var search_keywords: Array[String] = []
		search_keywords.assign(cmd_info.get("extra_keywords", []))
		ids_to_search_keywords[qualified_cmd] = search_keywords
	
	set_cur_items(ids_to_names.keys())

func set_condition_mode(new_is_condition_mode: bool) -> void:
	is_generic_mode = false
	is_condition_mode = new_is_condition_mode
	if visible:
		reapply_filters()

func set_is_generic_mode(new_is_generic_mode: bool) -> void:
	is_generic_mode = new_is_generic_mode
	if visible:
		reapply_filters()

func set_cur_items(new_cmd_ids: Array) -> void:
	var list = find_child("AllCommands") as ItemList
	list.clear()
	
	for cmd_id in new_cmd_ids:
		if not typeof(cmd_id) == TYPE_STRING:
			continue
		if not cmd_id in ids_to_names:
			push_error("Command ID not found in ids_to_names: %s" % [cmd_id])
			prints("id not in known ids: %s" % [cmd_id])
			continue
		var idx: = list.add_item(ids_to_names[cmd_id])
		list.set_item_metadata(idx, cmd_id)
		list.set_item_tooltip(idx, ids_to_tooltips[cmd_id])

func done() -> void:
	var list = find_child("AllCommands") as ItemList
	if len(list.get_selected_items()) < 1:
		return
	var selected_id: String = Utility.itemlist_get_single_selected_metadata(list)
	
	var slot: int = find_child("SlotSelectorButton").current_slot_id
	command_selected.emit(selected_id, slot)
	close_dialog()


func _on_AddConditionDialog_confirmed():
	done()


func get_current_slot_id() -> int:
	var slot_selector = find_child("SlotSelectorButton")
	return slot_selector.current_slot_id

func get_slot_filtered_list(slot_id: int) -> Array[String]:
	if slot_id < 0:
		var typed_list: Array[String] = []
		typed_list.assign(ids_to_names.keys())
		return typed_list
	var cur_slot_category: String = Commands.SLOT_CATEGORIES[slot_id]
	var filtered_ids: Array[String] = []
	for qualified_cmd in ids_to_slot_categories.keys():
		var categories: Array = ids_to_slot_categories[qualified_cmd]
		if not categories or "all" in categories or cur_slot_category in categories:
			filtered_ids.append(qualified_cmd)
	return filtered_ids

func get_slot_and_feature_filtered_list(slot_id: int, excluded_features: Array[String] = []) -> Array[String]:
	var slot_filtered_list: Array[String] = get_slot_filtered_list(slot_id)
	var feature_filtered_list: Array[String] = []
	for cmd_id in slot_filtered_list:
		var cmd_feature_categories: Array = ids_to_feature_categories[cmd_id]
		
		var is_excluded: bool = false
		for feature_category in cmd_feature_categories:
			if feature_category in excluded_features:
				is_excluded = true
				break
		if not is_excluded:
			feature_filtered_list.append(cmd_id)
	return feature_filtered_list


func filter_list_condition_action(list: Array) -> Array[String]:
	if is_condition_mode and not condion_mode_includes_actions:
		return list
	var cond_action_filtered: Array[String] = []
	for cmd_id in list:
		if not typeof(cmd_id) == TYPE_STRING:
			continue
		if is_condition_mode and ids_condition_exclude.has(cmd_id):
			continue
		elif not is_condition_mode and ids_action_exclude.has(cmd_id):
			continue
		cond_action_filtered.append(cmd_id)
	return cond_action_filtered

func get_current_slot_and_feature_filtered_list() -> Array[String]:
	return get_slot_and_feature_filtered_list(get_current_slot_id(), excluded_feature_categories)


func reapply_filters() -> void:
	var filtered_list: = get_current_slot_and_feature_filtered_list()
	if not is_generic_mode:
		filtered_list = filter_list_condition_action(filtered_list)
	set_cur_items(apply_text_filter(filtered_list, filter_input.text))

func _on_Filter_text_changed(_new_text):
	reapply_filters()

func apply_text_filter(list: Array, filter_str: String) -> Array[String]:
	if len(filter_str) < 1:
		var typed_list: Array[String] = []
		typed_list.assign(list)
		return typed_list
	filter_str = filter_str.to_lower()
	var sortable: Array[Dictionary] = []
	
	for cmd_id in list:
		if not typeof(cmd_id) == TYPE_STRING:
			continue
		if not cmd_id in ids_to_names:
			push_error("Command ID not found in ids_to_names: %s" % [cmd_id])
			prints("id not in known ids: %s" % [cmd_id])
			continue
		var filters_left = filter_str
		var s: String = ids_to_names[cmd_id]
		var lower = s.to_lower()
		var sortable_item: = {}
		for i in range(len(lower)):
			if filters_left[0] == lower[i]:
				if len(filters_left) <= 1:
					#new_list.append(s)
					sortable_item["cmd_id"] = cmd_id
					sortable_item["sort_str"] = s
					break
				filters_left = filters_left.substr(1)
		if sortable_item:
			var base_score: int = 0
			for i in range(len(filter_str)-1, -1, -1):
				if lower.contains(filter_str.substr(0, i+1)):
					base_score = i + 1
					if lower.begins_with(filter_str.substr(0, i+1)):
						base_score += 50
					break
			var kw_score: int = 0
			for kw in ids_to_search_keywords[cmd_id]:
				var kw_lower: String = kw.to_lower()
				var this_kw_score: int = 0
				for i in range(len(filter_str)-1, -1, -1):
					if kw_lower.contains(filter_str.substr(0, i+1)):
						this_kw_score = i + 1
						if kw_lower.begins_with(filter_str.substr(0, i+1)):
							this_kw_score += 50
						break
				kw_score = maxi(kw_score, this_kw_score)

			base_score = maxi(base_score, kw_score)
			base_score *= 100
			if base_score > kw_score:
				base_score += 40

			sortable_item["score"] = base_score
			sortable.append(sortable_item)
	if sortable.size() == 0:
		return []
	
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] == b["score"]:
			return a["sort_str"].nocasecmp_to(b["sort_str"]) < 0
		return a["score"] > b["score"]
	)
	var typed_sorted_result: Array[String] = []
	typed_sorted_result.assign(sortable.map(Utility.get_dict_item.bind("cmd_id", "")))

	return typed_sorted_result

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


func create_category_filter_menu() -> void:
	var popup_menu: PopupMenu = category_filter_menu_button.get_popup()
	popup_menu.clear()
	popup_menu.add_item("Clear All", CLEAR_ALL_CATEGORY_FILTER_ID)
	popup_menu.add_separator("Excluded Categories")
	for i in ConditionalsV3.all_feature_categories.size():
		var cat: String = ConditionalsV3.all_feature_categories[i]
		popup_menu.add_check_item(cat.capitalize(), i)
		var idx: = popup_menu.item_count - 1
		popup_menu.set_item_checked(idx, cat in excluded_feature_categories)

func on_category_filter_menu_id_pressed(id: int) -> void:
	if id == CLEAR_ALL_CATEGORY_FILTER_ID:
		excluded_feature_categories.clear()
		return
	if id < 0 or id >= ConditionalsV3.all_feature_categories.size():
		push_error("Invalid category filter menu ID: %s" % [id])
		return

	var chosen_category: String = ConditionalsV3.all_feature_categories[id]
	if chosen_category in excluded_feature_categories:
		excluded_feature_categories.erase(chosen_category)
	else:
		excluded_feature_categories.append(chosen_category)
	
	GameManager.update_feature_category_filter(excluded_feature_categories)

	reapply_filters()