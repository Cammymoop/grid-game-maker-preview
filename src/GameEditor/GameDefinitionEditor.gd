extends VBoxContainer

var load_dialog = preload("res://Scenes/GameEditor/LoadGameDialog.tscn")

func _ready():
	var name_box = find_node("NameInput")
	name_box.text = GameManager.get_game_name()

func _on_SaveButton_pressed():
	var game_data = {"game_name": GameManager.get_game_name()}
	game_data['tile_definitions'] = MapManager.tile_defs
	game_data['entity_definitions'] = EntityManager.entity_defs
	
	FilesManager.save_game_info(game_data)


func _on_NameInput_text_changed(new_text):
	GameManager.set_game_name(new_text)

func load_game_file(dialog) -> void:
	var game_name = dialog.get_selected_game()
	
	var definition = FilesManager.get_game_definition(game_name)
	GameManager.set_game_name(definition['game_name'])
	MapManager.tile_defs = definition['tile_definitions']
	MapManager.refresh_definition()
	EntityManager.entity_defs = definition['entity_definitions']
	EntityManager.refresh_definition()
	
	GameManager.change_scene("Menu")

func _on_LoadButton_pressed():
	var dialog = load_dialog.instance()
	
	add_child(dialog)
	dialog.connect("confirmed", self, "load_game_file", [dialog])
	dialog.popup_centered()
