extends PanelContainer

var quick_msg = preload("res://Scenes/GameEditor/QuickMessage.tscn")

func _ready():
	if GameManager.loaded:
		GameManager.loaded = false
		show_message("Loaded " + GameManager.cur_game_name)

func show_message(message_text) -> void:
	var qm = quick_msg.instance()
	qm.display(message_text)
	add_child(qm)


func _on_BackButton_pressed():
	GameManager.change_scene("Menu")


func _on_OpenGameDir_pressed():
	OS.shell_open(ProjectSettings.globalize_path("user://Games"))
