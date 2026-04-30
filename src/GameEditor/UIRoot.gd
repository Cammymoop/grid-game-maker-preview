# Game Editor UI panel root
extends PanelContainer

var quick_msg = preload("res://Scenes/GameEditor/QuickMessage.tscn")

var save_as_dialog_scn: = preload("res://Scenes/GameEditor/save_game_as_dialog.tscn")

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
	GameManager.start_playing(true)


func _on_OpenGameDir_pressed():
	if false:#GameManager.cur_game_name:
		var game_base_dir: = FilesManager.get_game_base_dir(GameManager.cur_game_name)
		OS.shell_open(ProjectSettings.globalize_path(game_base_dir))
	else:
		OS.shell_open(ProjectSettings.globalize_path(FilesManager.get_games_dir()))

func _on_OpenImagesFolder_pressed():
	var shared_images_dir: = FilesManager.get_shared_images_dir()
	OS.shell_open(ProjectSettings.globalize_path(shared_images_dir))

func _shortcut_input(event: InputEvent) -> void:
	if Utility.fixed_just_pressed_by_event("save_file_shortcut", event):
		if not GameManager.is_save_current_overwriting():
			GameManager.save_current_game_definition()
			GlobalToaster.show_toast_message("Saved %s Game Definition" % [GameManager.get_game_name()])
		else:
			_open_save_as_dialog(FilesManager.get_unique_game_name(GameManager.get_game_name()))
	elif Utility.fixed_just_pressed_by_event("save_file_as_shortcut", event):
		_open_save_as_dialog()

func _open_save_as_dialog(with_name: String = "") -> void:
	var save_as_dialog: = save_as_dialog_scn.instantiate()
	save_as_dialog.use_game_name = with_name
	add_popup_layer_node(save_as_dialog)
	save_as_dialog.move_to_center()