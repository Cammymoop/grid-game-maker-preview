extends Window

func _ready():
	find_child("LevelNameInput").text = GameManager.loaded_level_name
	close_requested.connect(queue_free)

func _on_SaveFileButton_pressed():
	var level_name = find_child("LevelNameInput").text
	var level_data = {}
	level_data["name"] = level_name
	level_data["state"] = GameManager.editor_save
	
	FilesManager.save_level(GameManager.cur_game_name, level_data)
	
	GameManager.loaded_level_name = level_name
	GameManager.checkpoint_save = GameManager.editor_save
	queue_free()

func _on_cancel_button_pressed() -> void:
	queue_free()
