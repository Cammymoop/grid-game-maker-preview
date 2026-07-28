extends Window

signal saved_level(level_name: String)
signal hidden

const LevelListNameInput = preload("res://Scenes/GameEditor/ConditionalEditor/level_list_name_input.gd")

@export var level_name_input: LineEdit
@export var save_level_button: Button

@export var level_list_name_input: LevelListNameInput

func _ready():
	visibility_changed.connect(_on_vis_changed)
	var level_title_label: Label = find_child("LevelTitleLabel")
	level_title_label.text = MapManager.get_level_title()
	
	level_name_input.text_changed.connect(name_input_text_changed)

	update_save_level_to_input()
	grab_and_select_all.call_deferred()
	
	var bundled_lists_locked: bool = GameManager.current_game_is_release_locked

	var current_list: String = current_list_of_saving_level()
	if bundled_lists_locked and GameManager.is_level_list_bundled(current_list):
		current_list = ""
	level_list_name_input.set_value({"type": "plain", "value": current_list})
	
	close_requested.connect(close_dialog)

func current_list_of_saving_level() -> String:
	if not GameManager.loaded_level_name:
		return GameManager.current_level_list

	var current_list: String = GameManager.current_level_list
	if not GameManager.is_level_in_list(GameManager.loaded_level_name, current_list):
		current_list = GameManager.get_list_containing_level(GameManager.loaded_level_name)

	return current_list
	

func _shortcut_input(event: InputEvent) -> void:
	if Utility.event_is_menu_back_just_pressed(event):
		close_dialog()
		set_input_as_handled()

func grab_and_select_all() -> void:
	level_name_input.grab_focus()
	level_name_input.select_all()

func is_overwriting_bundled_level() -> bool:
	var sanitized_intended: String = FilesManager.sanitize_level_filename(level_name_input.text.strip_edges())
	for bundled_level_name in GameManager.get_list_of_all_bundled_levels():
		var sanitized_name = FilesManager.sanitize_level_filename(bundled_level_name)
		if sanitized_name == sanitized_intended:
			return true
	return false

func name_input_text_changed(new_level_name: String) -> void:
	if not MapManager.get_metadata_value("title"):
		var level_title_label: Label = find_child("LevelTitleLabel")
		level_title_label.text = FilesManager.sanitize_level_filename(new_level_name)
	check_if_illegal_overwrite()

func check_if_illegal_overwrite() -> void:
	level_name_input.remove_theme_color_override("font_color")
	save_level_button.disabled = false
	if GameManager.current_game_is_release_locked:
		if is_overwriting_bundled_level():
			level_name_input.add_theme_color_override("font_color", Color.RED)
			save_level_button.disabled = true

func update_save_level_to_input() -> void:
	var cur_level_name: String = GameManager.loaded_level_name
	if not cur_level_name:
		cur_level_name = Utility.random_animal()

	cur_level_name = FilesManager.sanitize_level_filename(cur_level_name)
	level_name_input.text = cur_level_name
	check_if_illegal_overwrite()

func _on_SaveFileButton_pressed():
	var map_editor: = Utility.get_map_editor()
	if map_editor and map_editor.edit_mode:
		GameManager.save_edited()
	var level_name: String = level_name_input.text.strip_edges()
	if GameManager.current_game_is_release_locked:
		if is_overwriting_bundled_level():
			GlobalToaster.show_toast_message("Cannot overwrite bundled level, locked in released version")
			close_dialog()
			return
		if GameManager.current_level_list and GameManager.current_level_list in GameManager.get_list_of_level_lists(true):
			GameManager.current_level_list = ""
	GameManager.save_edited_level_as(level_name)
	saved_level.emit(level_name)
	close_dialog()

func _on_cancel_button_pressed() -> void:
	close_dialog()

func close_dialog() -> void:
	if visible:
		hide()
	queue_free()

func _on_vis_changed():
	if not visible:
		hidden.emit()