extends PanelContainer

func _on_PlayButton_pressed():
	GameManager.change_scene_to_file("Play")

func _on_EditButton_pressed():
	GameManager.change_scene_to_file("GameEditor")
