extends VBoxContainer

var generic_confirm = preload("res://Scenes/GameEditor/GenericConfirm.tscn")
var load_dialog = preload("res://Scenes/GameEditor/LoadGameDialog.tscn")

func _ready():
	var name_box = find_node("NameInput")
	name_box.text = GameManager.get_game_name()
	find_node("SetWindowWidth").value = GameManager.game_view.x
	find_node("SetWindowHeight").value = GameManager.game_view.y

func _on_SaveButton_pressed():
	if FilesManager.game_definition_exists(GameManager.get_game_name()):
		var popup = generic_confirm.instance()
		var title = "Do you want to override"
		var text = "A game with this name already exists, do you want to override it?"
		popup.confirm_with_callbacks(title, text, self, "_real_save")
	else:
		_real_save()

func _real_save():
	var game_data = {"game_name": GameManager.get_game_name()}
	game_data['tile_definitions'] = MapManager.tile_defs
	game_data['entity_definitions'] = EntityManager.entity_defs
	game_data['window_width'] = GameManager.game_view.x
	game_data['window_height'] = GameManager.game_view.y
	
	FilesManager.save_game_info(game_data)
	
	find_parent("UIRoot").show_message("Saved")


func _on_NameInput_text_changed(new_text):
	GameManager.set_game_name(new_text)

func load_game_file(dialog) -> void:
	var game_name = dialog.get_selected_game()
	GameManager.load_game_definition_from_file(game_name)

func _on_LoadButton_pressed():
	var dialog = load_dialog.instance()
	
	add_child(dialog)
	dialog.connect("confirmed", self, "load_game_file", [dialog])
	dialog.popup_centered()


func _on_SetDefault_pressed():
	FilesManager.save_default_game(GameManager.cur_game_name)
	find_parent("UIRoot").show_message("Default Game Set")


func _on_SetWindowWidth_value_changed(value):
	GameManager.set_game_view(value, GameManager.game_view.y)
func _on_SetWindowHeight_value_changed(value):
	GameManager.set_game_view(GameManager.game_view.x, value)

func _on_UpdateWindow_pressed():
	GameManager.rescale_window()
