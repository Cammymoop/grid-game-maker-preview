extends VBoxContainer

const PropOrEntityNameInput = preload("res://src/GameEditor/ConditionalEditor/prop_or_entity_name_input.gd")
const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

var save_as_dialog_scn: = preload("res://Scenes/GameEditor/save_game_as_dialog.tscn")

var generic_confirm = preload("res://Scenes/GameEditor/GenericConfirm.tscn")
var load_dialog = preload("res://Scenes/GameEditor/LoadGameDialog.tscn")

var game_settings = {}

var invalid_field_color = Color(0.7, 0.4, 0.4)

@export var show_level_title_option_picker: OptionButton

@export var name_input: LineEdit
@export var edit_game_dir_button: Button

@export var move_interp_option_picker: OptionButton
@export var action_signal_sent_to_option_picker: OptionButton
@export var turn_animation_option_picker: OptionButton

@export var def_dying_eff_picker: OptionButton

@export var default_move_speed_input: ScalarValueInput

@export var auto_reload_checkpoint_for_no_cam_focus_toggle: CheckButton

var _save_as_dialog_open: bool = false

func _ready():
	if OS.has_feature("web"):
		find_child("OpenGameDir").disabled = true
	GameManager.game_dir_name_changed.connect(on_game_dir_name_changed)
	var game_name = GameManager.get_game_name()
	name_input.text = game_name
	init_movement_modes()
	
	game_settings = GameManager.game_definition["game_settings"]
	
	var title_input: LineEdit = find_child("TitleInput")
	title_input.text = GameManager.get_game_setting("title", "")
	title_input.placeholder_text = game_name
	
	if "pixel_scale" in game_settings:
		find_child("PixelScaleInput").value = game_settings["pixel_scale"]
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
	
	move_interp_option_picker.clear()
	for intertp_id in Utility.POS_INTERP_STRINGS.keys():
		move_interp_option_picker.add_item(Utility.POS_INTERP_STRINGS[intertp_id], intertp_id)

	move_interp_option_picker.item_selected.connect(on_move_interp_option_picked)
	var cur_interp: = GameManager.get_game_setting("default_move_interp", "") as String
	var interp_id: int = Utility.PosInterpStyle.CONTINUOUS_LINEAR
	if cur_interp:
		interp_id = BaseEntity.read_move_interp_style_string(cur_interp)
	Utility.opbtn_select_id(move_interp_option_picker, interp_id)
	
	turn_animation_option_picker.item_selected.connect(on_turn_animation_option_picked)
	Utility.opbtn_select_text(turn_animation_option_picker, GameManager.get_game_setting("default_turn_animation", "quick"))
	
	default_move_speed_input.set_value(GameManager.get_game_setting("entity_move_speed", EntityManager.DEFAULT_MOVE_SPEED))
	default_move_speed_input.value_changed.connect(on_default_move_speed_changed)
	
	action_signal_sent_to_option_picker.item_selected.connect(on_action_signal_sent_to_option_picked)
	var cur_action_signal_sent_to: = GameManager.get_game_setting("action_signal_sent_to", "all_entities") as String
	action_signal_sent_to_option_picker.selected = -1
	for i in action_signal_sent_to_option_picker.item_count:
		if action_signal_sent_to_option_picker.get_item_text(i) == cur_action_signal_sent_to:
			action_signal_sent_to_option_picker.select(i)
			break
	
	def_dying_eff_picker.item_selected.connect(on_default_dying_eff_option_picked)
	var cur_dying_eff: String = GameManager.get_game_setting("default_dying_effect", "")
	def_dying_eff_picker.clear()
	def_dying_eff_picker.add_item("None")
	for effect_name in SpriteEffects.DYING_EFFECTS:
		def_dying_eff_picker.add_item(effect_name)
	
	var auto_reload_no_cam_focus: bool = GameManager.get_game_setting("auto_reload_checkpoint_for_no_cam_focus", false)
	auto_reload_checkpoint_for_no_cam_focus_toggle.set_pressed_no_signal(auto_reload_no_cam_focus)
	auto_reload_checkpoint_for_no_cam_focus_toggle.toggled.connect(on_auto_reload_checkpoint_for_no_cam_focus_toggled)

	if cur_dying_eff:
		Utility.opbtn_select_text(def_dying_eff_picker, cur_dying_eff)
	else:
		def_dying_eff_picker.selected = 0

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

func _on_SaveButton_pressed() -> void:
	if not GameManager.is_save_current_overwriting():
		_real_save()
	else:
		_open_save_as_dialog()

func _real_save() -> void:
	GameManager.save_current_game_definition()
	GlobalToaster.show_toast_message("Saved %s Game Definition" % [GameManager.get_game_name()])


func on_game_dir_name_changed(new_game_name: String) -> void:
	var title_input: LineEdit = find_child("TitleInput")
	title_input.placeholder_text = GameManager.get_game_implicit_title()
	name_input.text = new_game_name

func load_game_file(dialog) -> void:
	var game_name = dialog.get_selected_game()
	if game_name:
		GameManager.load_game_definition_from_file.call_deferred(game_name)
	else:
		dialog.close_dialog()

func _on_LoadButton_pressed():
	var dialog = load_dialog.instantiate()
	
	add_child(dialog)
	dialog.confirmed.connect(load_game_file.bind(dialog))
	dialog.popup_centered()


func _on_SetDefault_pressed():
	FilesManager.save_default_game(GameManager.cur_game_name)
	GlobalToaster.show_toast_message("Default Game Set")

func _on_UpdateWindow_pressed():
	GameManager.rescale_window()

func set_camera_settings(setting: String, value) -> void:
	if not "camera_settings" in game_settings:
		game_settings["camera_settings"] = {}
	game_settings["camera_settings"][setting] = value

func _on_FollowEntity_text_changed(new_text: String) -> void:
	set_camera_settings("follow_entity", new_text)
func _on_EnableLimitsToggle_toggled(button_pressed: bool) -> void:
	set_camera_settings("enable_limits", button_pressed)
func _on_ExtendCamLimits_value_changed(value):
	set_camera_settings("extend_limits", value)


func _on_PixelScaleInput_value_changed(value):
	game_settings["pixel_scale"] = value

func _on_title_input_text_changed(new_text: String) -> void:
	game_settings["title"] = new_text
	
func on_show_level_title_option_picked(index: int) -> void:
	var item_text: = show_level_title_option_picker.get_item_text(index)
	GameManager.set_game_setting("show_level_title", item_text)

func _on_new_empty_pressed() -> void:
	GameManager.new_empty_game_definition()
	GameManager.save_current_game_definition()
	var default_game: = FilesManager.get_default_game()
	if not default_game or not FilesManager.game_exists(default_game):
		FilesManager.save_default_game(GameManager.get_game_name())

func on_move_interp_option_picked(index: int) -> void:
	var interp_style: = move_interp_option_picker.get_item_id(index) as Utility.PosInterpStyle
	GameManager.set_game_setting("default_move_interp", BaseEntity.get_move_interp_style_string(interp_style))
	GameManager.game_settings_changed.emit()

func on_action_signal_sent_to_option_picked(index: int) -> void:
	var item_text: = action_signal_sent_to_option_picker.get_item_text(index)
	GameManager.set_game_setting("action_signal_sent_to", item_text)
	GameManager.game_settings_changed.emit()

func on_turn_animation_option_picked(index: int) -> void:
	var turn_anim: = turn_animation_option_picker.get_item_text(index)
	GameManager.set_game_setting("default_turn_animation", turn_anim)
	GameManager.game_settings_changed.emit()

func _disable_name_input() -> void:
	name_input.editable = false
	edit_game_dir_button.disabled = false

func _enable_name_input() -> void:
	name_input.editable = true
	edit_game_dir_button.disabled = true

func _on_name_input_editing_toggled(toggled_on: bool) -> void:
	if name_input.editable and not toggled_on and not _save_as_dialog_open:
		renaming_game_dir()

func _on_name_input_text_submitted(_new_text: String) -> void:
	if _save_as_dialog_open:
		name_input.text = GameManager.get_game_name()
		_disable_name_input()
		return
	renaming_game_dir()

func renaming_game_dir() -> void:
	var new_game_dir_name: = name_input.text
	if new_game_dir_name == GameManager.get_game_name():
		_disable_name_input()
		return
	if not GameManager.is_current_game_saved() or FilesManager.is_game_name_equivalent(new_game_dir_name, GameManager.get_game_name()):
		GameManager._set_game_name(new_game_dir_name)
		_disable_name_input()
		return
	
	if GameManager.is_name_overwriting(new_game_dir_name):
		_open_save_as_dialog(FilesManager.get_unique_game_name(new_game_dir_name))
	else:
		var old_game_name: = GameManager.get_game_name()
		if GameManager.rename_and_save_current_game_definition(new_game_dir_name):
			GlobalToaster.show_toast_message("Moved %s Game Definition to %s" % [old_game_name, GameManager.get_game_name()])
	_disable_name_input()
	
func _open_save_as_dialog(new_game_dir_name: String = "") -> void:
	var save_as_dialog: = save_as_dialog_scn.instantiate() as Window
	save_as_dialog.use_game_name = new_game_dir_name
	save_as_dialog.hidden.connect(set.bind("_save_as_dialog_open", false))
	add_child(save_as_dialog)
	save_as_dialog.move_to_center()
	_save_as_dialog_open = true
	prints("opening save as dialog with game name: ", new_game_dir_name)

func _on_edit_game_dir_button_pressed() -> void:
	if _save_as_dialog_open:
		return
	_enable_name_input()
	name_input.grab_focus.call_deferred()


func _on_export_zip_pressed(no_bundle_pls: bool = false) -> void:
	if not no_bundle_pls and Input.is_action_pressed(&"editor_alt_mode_hold"):
		no_bundle_pls = true

	if not no_bundle_pls and TextureManager.has_enabled_shared_images():
		var bundle_shared_images_dialog: = generic_confirm.instantiate() as ConfirmationDialog
		bundle_shared_images_dialog.free_on_close = true
		add_child(bundle_shared_images_dialog)
		bundle_shared_images_dialog.add_button("Export Without Bundling", true, "no_bundle_pls")
		bundle_shared_images_dialog.custom_action.connect(on_bundle_dialog_custom_action)

		var message_text: = "The current game is using some shared (non-bundled) images. The exported copy will not include those images."
		message_text += "\nIt can still be exported, but will require those images to be in the shared images folder when imported in order to work properly."
		message_text += "\n\nYou can bundle a copy of each shared image now so they are all included in the export, or export without bundling shared images."
		bundle_shared_images_dialog.ok_button_text = "Bundle Images and Export"
		bundle_shared_images_dialog.confirm_with_callbacks("Bundle Images Before Export?", message_text, do_bundle_first)
		return
	GameManager.save_current_game_definition()

	if OS.has_feature("web"):
		export_web_mode()
		return
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.title = "Export Game .zip To Folder..."
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.dir_selected.connect(_export_destination_picked.bind(file_dialog))
	file_dialog.close_requested.connect(file_dialog.queue_free)
	file_dialog.canceled.connect(file_dialog.queue_free)
	add_child(file_dialog)
	file_dialog.popup_file_dialog()

func do_bundle_first() -> void:
	if not TextureManager.bundle_all_used_shared_images():
		GlobalToaster.show_toast_message("Oops! Failed to bundle shared images")
	else:
		_on_export_zip_pressed()

func on_bundle_dialog_custom_action(action: String) -> void:
	if action == "no_bundle_pls":
		_on_export_zip_pressed(true)

func export_web_mode() -> void:
	var zip_path: String = ImporterExporter.export_game_zip(GameManager.get_game_name(), "")
	var zip_byte_array: = FileAccess.get_file_as_bytes(zip_path)
	JavaScriptBridge.download_buffer(zip_byte_array, zip_path.get_file(), "application/zip")

func _export_destination_picked(path: String, file_dialog: FileDialog) -> void:
	prints("export destination picked: ", path)
	file_dialog.queue_free()
	var zip_path: String = ImporterExporter.export_game_zip(GameManager.get_game_name(), path)
	if zip_path:
		GlobalToaster.show_toast_message("Exported Game .zip to\n%s" % [zip_path])
	else:
		GlobalToaster.show_toast_message("Failed to export Game .zip")

func on_default_move_speed_changed(value: float) -> void:
	GameManager.set_game_setting("entity_move_speed", value)

func _on_import_levels_btn_pressed() -> void:
	GameManager.start_import_levels()

func on_default_dying_eff_option_picked(index: int) -> void:
	var item_text: = def_dying_eff_picker.get_item_text(index)
	GameManager.set_game_setting("default_dying_effect", item_text)
	GameManager.game_settings_changed.emit()

func on_auto_reload_checkpoint_for_no_cam_focus_toggled(button_pressed: bool) -> void:
	GameManager.set_game_setting("auto_reload_checkpoint_for_no_cam_focus", button_pressed)
	GameManager.game_settings_changed.emit()