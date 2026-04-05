extends Window

signal hidden

func _ready():
	visibility_changed.connect(_on_vis_changed)
	find_child("LevelNameInput").text = GameManager.loaded_level_name
	close_requested.connect(close_dialog)

func _on_SaveFileButton_pressed():
	var level_name: String = find_child("LevelNameInput").text.strip_edges()
	var level_data: = {}
	level_data["name"] = level_name
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