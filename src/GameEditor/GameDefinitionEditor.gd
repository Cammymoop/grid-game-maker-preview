extends VBoxContainer

var generic_confirm = preload("res://Scenes/GameEditor/GenericConfirm.tscn")
var load_dialog = preload("res://Scenes/GameEditor/LoadGameDialog.tscn")

var game_settings = {}

var invalid_field_color = Color(0.7, 0.4, 0.4)

func _ready():
	var name_box = find_node("NameInput")
	name_box.text = GameManager.get_game_name()
	find_node("SetWindowWidth").value = GameManager.game_view.x
	find_node("SetWindowHeight").value = GameManager.game_view.y
	
	game_settings = GameManager.game_definition["game_settings"]
	
	var cam_settings = {}
	if "camera_settings" in game_settings:
		cam_settings = game_settings["camera_settings"]
	
	if "follow_entity" in cam_settings:
		find_node("FollowEntity").text = cam_settings["follow_entity"]
		follow_entity_validate()
	if "enable_limits" in cam_settings:
		find_node("EnableLimitsToggle").pressed = cam_settings["enable_limits"]

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
	game_data["game_settings"] = game_settings
	
	FilesManager.save_game_info(game_data)
	
	find_parent("UIRoot").show_message("Saved")


func _on_NameInput_text_changed(new_text):
	GameManager.set_game_name(new_text)

func load_game_file(dialog) -> void:
	var game_name = dialog.get_selected_game()
	GameManager.load_game_definition_from_file(game_name)
	#show_settings(GameManager.game_definition)

# TODO with this I dont have to reload this scene on game change
#func show_settings(new_game_defintion) -> void:
#   #show settings here and on other tabs
#	pass

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

func set_camera_settings(setting: String, value) -> void:
	if not "camera_settings" in game_settings:
		game_settings["camera_settings"] = {}
	game_settings["camera_settings"][setting] = value

func follow_entity_validate() -> void:
	var entity_list = EntityManager.get_all_entity_names()
	var input = find_node("FollowEntity")
	if not input.text in entity_list:
		input.add_color_override("font_color", invalid_field_color)
	else:
		input.add_color_override("font_color", Color.white)

func _on_FollowEntity_text_changed(new_text):
	set_camera_settings("follow_entity", new_text)
	follow_entity_validate()
func _on_EnableLimitsToggle_toggled(button_pressed):
	set_camera_settings("enable_limits", button_pressed)
func _on_ExtendCamLimits_value_changed(value):
	set_camera_settings("extend_limits", value)
