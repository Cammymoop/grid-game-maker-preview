extends Window

signal hidden

func _ready():
	visibility_changed.connect(_on_vis_changed)
	var level_title_label: Label = find_child("LevelTitleLabel")
	level_title_label.text = MapManager.get_level_title()
	
	find_child("LevelNameInput").text_changed.connect(name_input_text_changed)

	update_save_level_to_input()
	grab_and_select_all.call_deferred()
	
	close_requested.connect(close_dialog)

func _shortcut_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed_by_event(&"escape", event):
		close_dialog()

func grab_and_select_all() -> void:
	var level_name_input: LineEdit = find_child("LevelNameInput")
	level_name_input.grab_focus()
	level_name_input.select_all()

func name_input_text_changed(new_level_name: String) -> void:
	if not MapManager.get_metadata_value("title"):
		var level_title_label: Label = find_child("LevelTitleLabel")
		level_title_label.text = FilesManager.sanitize_level_filename(new_level_name)

func update_save_level_to_input() -> void:
	find_child("LevelNameInput").text = FilesManager.sanitize_level_filename(GameManager.loaded_level_name)

func _on_SaveFileButton_pressed():
	var level_name: String = find_child("LevelNameInput").text.strip_edges()
	var level_data: = {}
	level_data["name"] = FilesManager.sanitize_level_filename(level_name)
	level_data["state"] = GameManager.editor_save
	
	var saved_successfully: = FilesManager.save_level(GameManager.cur_game_name, level_data)
	if saved_successfully:
		GlobalToaster.show_toast_message("Level Saved")
	else:
		GlobalToaster.show_toast_message("Failed to save level")
		return
	
	GameManager.loaded_level_name = level_name
	GameManager.checkpoint_save = GameManager.editor_save
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