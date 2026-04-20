extends PanelContainer

var quick_msg = preload("res://Scenes/GameEditor/QuickMessage.tscn")

@onready var popup_layer = get_node("PopupLayerLayer/PopupLayer")
@onready var message_layer = get_node("MessageLayer")

#func _ready():
#	if GameManager.loaded:
#		GameManager.loaded = false
#		show_message("Loaded " + GameManager.cur_game_name)

#func show_message(message_text) -> void:
#	var qm = quick_msg.instantiate()
#	qm.display(message_text)
#	message_layer.add_child(qm)

func add_popup_layer_node(node: Node) -> void:
	popup_layer.add_something(node)

func _on_BackButton_pressed():
	GameManager.change_scene("Menu")

func _on_test_play_button_pressed() -> void:
	GameManager.change_scene("Play")


func _on_OpenGameDir_pressed():
	if false:#GameManager.cur_game_name:
		var game_base_dir: = FilesManager.get_game_base_dir(GameManager.cur_game_name)
		OS.shell_open(ProjectSettings.globalize_path(game_base_dir))
	else:
		OS.shell_open(ProjectSettings.globalize_path(FilesManager.get_games_dir()))

func _on_OpenImagesFolder_pressed():
	var shared_images_dir: = FilesManager.get_shared_images_dir()
	OS.shell_open(ProjectSettings.globalize_path(shared_images_dir))
