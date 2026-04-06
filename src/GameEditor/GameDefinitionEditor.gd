extends VBoxContainer

const PropOrEntityNameInput = preload("res://src/GameEditor/ConditionalEditor/prop_or_entity_name_input.gd")

var generic_confirm = preload("res://Scenes/GameEditor/GenericConfirm.tscn")
var load_dialog = preload("res://Scenes/GameEditor/LoadGameDialog.tscn")

var game_settings = {}

var invalid_field_color = Color(0.7, 0.4, 0.4)

@export var show_level_title_option_picker: OptionButton

func _ready():
	var name_box = find_child("NameInput")
	var game_name = GameManager.get_game_name()
	name_box.text = game_name
	find_child("SetWindowWidth").value = GameManager.game_view.x
	find_child("SetWindowHeight").value = GameManager.game_view.y
	init_movement_modes()
	
	game_settings = GameManager.game_definition["game_settings"]
	
	var title_input: LineEdit = find_child("TitleInput")
	title_input.text = GameManager.get_game_setting("title", "")
	title_input.placeholder_text = game_name
	
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
	follow_by_button.changed.connect(change_follow_by)
	
	if "follow_entity" in cam_settings:
		find_child("FollowEntity").set_value(cam_settings["follow_entity"])
	if "follow_entity_by" in cam_settings:
		follow_by_button.text = cam_settings["follow_entity_by"]
	if "enable_limits" in cam_settings:
		find_child("EnableLimitsToggle").button_pressed = cam_settings["enable_limits"]
	
	var show_lvl_title_opt: String = GameManager.get_game_setting("show_level_title", "At Level Start").to_lower()
	show_level_title_option_picker.select(0)
	for index in show_level_title_option_picker.item_count:
		var item_text: = show_level_title_option_picker.get_item_text(index)
		if item_text.to_lower() == show_lvl_title_opt:
			show_level_title_option_picker.select(index)
			break
	show_level_title_option_picker.item_selected.connect(on_show_level_title_option_picked)

func init_movement_modes() -> void:
	var popup_menu: PopupMenu = find_child("MovementModeMenuButton").get_popup()
	
	for mode in GameManager.MovementMode.values():
		popup_menu.add_item(GameManager.describe_movement_mode(mode), mode)
	
	popup_menu.id_pressed.connect(movement_mode_picked)

func change_follow_by(val: String) -> void:
	set_camera_settings("follow_entity_by", val)
	
	var prop_entity_name_input: PropOrEntityNameInput = find_child("FollowEntity") as PropOrEntityNameInput
	if prop_entity_name_input:
		var mode: String = PropOrEntityNameInput.PROP_NAME
		if val == "name":
			mode = PropOrEntityNameInput.ENTITY_NAME
		elif val == "name or property":
			mode = PropOrEntityNameInput.BOTH
		prop_entity_name_input.set_hint_mode(mode)

func movement_mode_picked(mode_id: int) -> void:
	var popup_menu: PopupMenu = find_child("MovementModeMenuButton").get_popup()
	var index = popup_menu.get_item_index(mode_id)
	find_child("MovementModeMenuButton").text = popup_menu.get_item_text(index)
	
	game_settings["movement_mode"] = mode_id

func _on_SaveButton_pressed():
	var is_resave: = GameManager.loaded_from_game_name == GameManager.get_game_name()
	if is_resave or not FilesManager.game_exists(GameManager.get_game_name()):
		_real_save()
	else:
		var popup = generic_confirm.instantiate()
		var title = "Do you want to override"
		var text = "A game with this name already exists, do you want to override it?"
		add_child(popup)
		popup.confirm_with_callbacks(title, text, _real_save)

func _real_save():
	var def_data: = GameManager.get_serialized_game_definition()
	FilesManager.save_game_info(def_data)
	GameManager.loaded_from_game_name = GameManager.get_game_name()
	
	GlobalToaster.show_toast_message("Saved Game Definition")


func _on_NameInput_text_changed(new_name: String) -> void:
	GameManager.set_game_name(new_name)

	var title_input: LineEdit = find_child("TitleInput")
	title_input.placeholder_text = new_name

func load_game_file(dialog) -> void:
	var game_name = dialog.get_selected_game()
	GameManager.load_game_definition_from_file(game_name)
	#show_settings(GameManager.game_definition)

func _on_LoadButton_pressed():
	var dialog = load_dialog.instantiate()
	
	add_child(dialog)
	dialog.connect("confirmed", Callable(self, "load_game_file").bind(dialog))
	dialog.popup_centered()


func _on_SetDefault_pressed():
	FilesManager.save_default_game(GameManager.cur_game_name)
	GlobalToaster.show_toast_message("Default Game Set")


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

func _on_FollowEntity_text_changed(new_text):
	set_camera_settings("follow_entity", new_text)
func _on_EnableLimitsToggle_toggled(button_pressed):
	set_camera_settings("enable_limits", button_pressed)
func _on_ExtendCamLimits_value_changed(value):
	set_camera_settings("extend_limits", value)


func _on_PixelScaleInput_value_changed(value):
	game_settings["pixel_scale"] = value

func _on_AutoAspect_toggled(button_pressed):
	game_settings["auto_aspect"] = button_pressed

func _on_title_input_text_changed(new_text: String) -> void:
	game_settings["title"] = new_text
	
func on_show_level_title_option_picked(index: int) -> void:
	var item_text: = show_level_title_option_picker.get_item_text(index)
	GameManager.set_game_setting("show_level_title", item_text)