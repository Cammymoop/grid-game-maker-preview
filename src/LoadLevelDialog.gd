extends Window

signal hidden

@export var select_level_option: OptionButton

var all_levels = []

func _ready():
	visibility_changed.connect(_on_vis_changed)
	all_levels = FilesManager.get_level_list(GameManager.cur_game_name)
	
	var has_editor_autosave: bool = "editor_autosave" in all_levels
	var is_editor_autosave_newer: bool = false

	all_levels.erase("editor_autosave")

	var autosave_level_name: String = ""
	if has_editor_autosave:
		is_editor_autosave_newer = FilesManager.get_editor_autosave_is_newer(GameManager.cur_game_name)
		autosave_level_name = FilesManager.get_editor_autosave_level_name(GameManager.cur_game_name)
	
	select_level_option.clear()
	if not has_editor_autosave and all_levels.size() < 1:
		select_level_option.add_item("(No levels saved)")
		select_level_option.disabled = true
	else:
		if has_editor_autosave:
			var autosave_text: = "[autosave]"
			if not is_editor_autosave_newer:
				autosave_text += " (older)"
			if autosave_level_name:
				autosave_text += " " + autosave_level_name
			select_level_option.add_item(autosave_text, 0)
			select_level_option.add_separator("levels")
		for i in all_levels.size():
			var level_name = all_levels[i]
			select_level_option.add_item(level_name, i + 1)

	close_requested.connect(close_dialog)

func _shortcut_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed_by_event(&"escape", event):
		close_dialog()

func _on_LoadFileButton_pressed():
	var selected_index: = select_level_option.selected
	var selected_level: = select_level_option.get_item_text(selected_index)
	if selected_index == 0:
		GameManager.load_editor_autosave()
		close_dialog()
		return

	var parsed_level = FilesManager.get_level_data(GameManager.cur_game_name, selected_level)
	GameManager.load_level_data(parsed_level)
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