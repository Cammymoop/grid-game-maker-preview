extends PanelContainer

func _ready():
	var game_title_label: Label = find_child("GameTitleLabel")
	if GameManager.cur_game_name:
		game_title_label.text = GameManager.cur_game_name
	else:
		game_title_label.visible = false
		

func _on_PlayButton_pressed():
	GameManager.change_scene("Play")

func _on_EditButton_pressed():
	GameManager.change_scene("GameEditor")
