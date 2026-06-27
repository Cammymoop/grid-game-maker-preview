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
			if level_name == GameManager.loaded_level_name and not GameManager.loaded_is_autosave:
				var index: = select_level_option.get_item_index(i + 1)
				select_level_option.selected = index

	close_requested.connect(close_dialog)

func _shortcut_input(event: InputEvent) -> void:
	if Utility.event_is_menu_back_just_pressed(event):
		close_dialog()

func _on_LoadFileButton_pressed():
	if GameManager.queued_level_load:
		GameManager.cancel_queued_level_load()
	var idx: int = select_level_option.selected
	var selected_id: = select_level_option.get_item_id(idx)
	var selected_level: = select_level_option.get_item_text(idx)
	if selected_id == 0:
		GameManager.load_editor_autosave()
		close_dialog()
		return

	if not GameManager.is_in_level_edit_mode:
		push_error("Trying to load a level from load level dialog while not in level edit mode")
	else:
		var map_editor: = Utility.get_map_editor()
		if map_editor:
			var list_of_level: = GameManager.get_list_containing_level(selected_level)
			map_editor.load_level_in_list(selected_level, list_of_level)
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
