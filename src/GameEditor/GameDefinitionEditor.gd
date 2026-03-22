extends VBoxContainer

var generic_confirm = preload("res://Scenes/GameEditor/GenericConfirm.tscn")
var load_dialog = preload("res://Scenes/GameEditor/LoadGameDialog.tscn")

var game_settings = {}

var invalid_field_color = Color(0.7, 0.4, 0.4)

func _ready():
	var name_box = find_child("NameInput")
	name_box.text = GameManager.get_game_name()
	find_child("SetWindowWidth").value = GameManager.game_view.x
	find_child("SetWindowHeight").value = GameManager.game_view.y
	init_movement_modes()
	
	game_settings = GameManager.game_definition["game_settings"]
	
	if "pixel_scale" in game_settings:
		find_child("PixelScaleInput").value = game_settings["pixel_scale"]
	if "auto_aspect" in game_settings:
		find_child("AutoAspect").button_pressed = game_settings["auto_aspect"]
	if "movement_mode" in game_settings:
		find_child("MovementModeMenuButton").text = GameManager.describe_movement_mode(game_settings["movement_mode"])
	
	var cam_settings = {}
	if "camera_settings" in game_settings:
		cam_settings = game_settings["camera_settings"]
	
	var follow_by_button = find_child("FollowBy")
	follow_by_button.connect("changed", Callable(self, "change_follow_by"))
	
	if "follow_entity" in cam_settings:
		find_child("FollowEntity").text = cam_settings["follow_entity"]
		follow_entity_validate()
	if "follow_entity_by" in cam_settings:
		follow_by_button.text = cam_settings["follow_entity_by"]
	if "enable_limits" in cam_settings:
		find_child("EnableLimitsToggle").button_pressed = cam_settings["enable_limits"]

func init_movement_modes() -> void:
	var popup_menu: PopupMenu = find_child("MovementModeMenuButton").get_popup()
	
	for mode in GameManager.MovementMode.values():
		popup_menu.add_item(GameManager.describe_movement_mode(mode), mode)
	
	popup_menu.connect("index_pressed", Callable(self, "movement_mode_picked"))

func change_follow_by(val: String) -> void:
	set_camera_settings("follow_entity_by", val)

func movement_mode_picked(index) -> void:
	var popup_menu: PopupMenu = find_child("MovementModeMenuButton").get_popup()
	find_child("MovementModeMenuButton").text = popup_menu.get_item_text(index)
	var mode = popup_menu.get_item_id(index)
	
	game_settings["movement_mode"] = mode

func _on_SaveButton_pressed():
	if FilesManager.game_definition_exists(GameManager.get_game_name()):
		var popup = generic_confirm.instantiate()
		var title = "Do you want to override"
		var text = "A game with this name already exists, do you want to override it?"
		add_child(popup)
		popup.confirm_with_callbacks(title, text, _real_save)
	else:
		_real_save()

func _real_save():
	var game_data = {"game_name": GameManager.get_game_name()}
	game_data['textures'] = TextureManager.get_texture_spec()
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
	var dialog = load_dialog.instantiate()
	
	add_child(dialog)
	dialog.connect("confirmed", Callable(self, "load_game_file").bind(dialog))
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
	var follow_by = Utility.get_camera_setting("follow_entity_by")
	var input = find_child("FollowEntity")
	if follow_by and follow_by != "name":
		input.add_theme_color_override("font_color", Color.WHITE)
		return
	var entity_list = EntityManager.get_all_entity_names()
	if not input.text in entity_list:
		input.add_theme_color_override("font_color", invalid_field_color)
	else:
		input.add_theme_color_override("font_color", Color.WHITE)

func _on_FollowEntity_text_changed(new_text):
	set_camera_settings("follow_entity", new_text)
	follow_entity_validate()
func _on_EnableLimitsToggle_toggled(button_pressed):
	set_camera_settings("enable_limits", button_pressed)
func _on_ExtendCamLimits_value_changed(value):
	set_camera_settings("extend_limits", value)


func _on_PixelScaleInput_value_changed(value):
	game_settings["pixel_scale"] = value

func _on_AutoAspect_toggled(button_pressed):
	game_settings["auto_aspect"] = button_pressed
