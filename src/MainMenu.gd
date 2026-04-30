extends PanelContainer

func _ready():
	var game_title_label: Label = find_child("GameTitleLabel")
	if GameManager.cur_game_name:
		game_title_label.text = GameManager.get_game_title()
	else:
		game_title_label.visible = false
		

func _on_PlayButton_pressed():
	if GameManager.is_in_level_edit_mode:
		GameManager.is_in_level_edit_mode = false
	GameManager.start_playing()

func _on_EditButton_pressed():
	GameManager.change_scene("GameEditor")