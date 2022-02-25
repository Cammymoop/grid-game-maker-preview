extends WindowDialog

func _ready():
	find_node("LevelNameInput").text = GameManager.loaded_level_name

func _on_SaveFileButton_pressed():
	var level_name = find_node("LevelNameInput").text
	var level_data = {}
	level_data["name"] = level_name
	level_data["state"] = GameManager.editor_save
	
	FilesManager.save_level(GameManager.cur_game_name, level_data)
	queue_free()
