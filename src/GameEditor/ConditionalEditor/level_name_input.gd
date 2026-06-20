extends FuzzyAutocompleteInput

const ComplexAutocompleteInput = preload("res://Scenes/GameEditor/ConditionalEditor/complex_autocomplete_input.gd")

@export var filter_by_level_list: bool = true

var _level_list_filter: String = ""

var level_titles: Dictionary[String, String] = {}

func _ready() -> void:
	set_fetch_values_func(fetch_level_autocomplete)
	super._ready()
	
	fetch_level_titles()
	
	text_changed.connect(update_tooltip)
	
	await get_tree().process_frame
	
	var found_level_list_sibling: = false
	for sibling in get_parent().get_parent().get_children():
		if sibling is ComplexAutocompleteInput and sibling.name == "ComplexLevelListInput":
			found_level_list_sibling = true
			sibling.plain_or_slot_value_changed.connect(on_level_list_name_input_text_changed)
			break
	if not found_level_list_sibling:
		filter_by_level_list = false

func fetch_level_titles() -> void:
	level_titles.clear()
	for level_name in FilesManager.get_level_list(GameManager.cur_game_name):
		level_titles[level_name] = FilesManager.get_level_title(GameManager.cur_game_name, level_name)

func update_tooltip(new_text: String) -> void:
	if new_text in level_titles:
		tooltip_text = level_titles[new_text]
	else:
		tooltip_text = ""

func fetch_level_autocomplete() -> Array[String]:
	var all_level_names: Array[String] = []
	all_level_names.assign(FilesManager.get_level_list(GameManager.cur_game_name))
	if not filter_by_level_list or not has_level_list_filter():
		return all_level_names

	var levels_in_list: Array[String] = []
	for level_name in GameManager._get_level_list(_level_list_filter)["level_names"]:
		if level_name in all_level_names:
			levels_in_list.append(level_name)
	return levels_in_list

func on_level_list_name_input_text_changed(new_text: String) -> void:
	update_level_list_filter(new_text)
	fetch_now()

func update_level_list_filter(new_text: String) -> void:
	_level_list_filter = new_text

func has_level_list_filter() -> bool:
	var all_level_lists: Array[String] = GameManager.get_list_of_level_lists()
	if _level_list_filter and _level_list_filter in all_level_lists:
		return true
	return false