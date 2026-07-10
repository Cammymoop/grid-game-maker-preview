extends VBoxContainer

const PropOrEntityNameInput = preload("res://src/GameEditor/ConditionalEditor/prop_or_entity_name_input.gd")
const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

var save_as_dialog_scn: = preload("res://Scenes/GameEditor/save_game_as_dialog.tscn")

var generic_confirm = preload("res://Scenes/GameEditor/GenericConfirm.tscn")
var load_dialog = preload("res://Scenes/GameEditor/LoadGameDialog.tscn")

var game_settings = {}

var invalid_field_color = Color(0.7, 0.4, 0.4)

@export var show_level_title_option_picker: OptionButton

@export var game_identifier_label: Label
@export var game_identifier_panel: Control

@export var game_identifier_input: LineEdit
@export var game_identifier_input_panel: Control
@export var game_identifier_set_button: Button
@export var game_identifier_cancel_button: Button

@export var name_input: LineEdit
@export var edit_game_dir_button: Button

@export var move_interp_option_picker: OptionButton
@export var tele_interp_option_picker: OptionButton
@export var action_signal_sent_to_option_picker: OptionButton
@export var turn_animation_option_picker: OptionButton

@export var def_dying_eff_picker: OptionButton
@export var def_spawn_eff_picker: OptionButton

@export var use_spawn_effect_at_level_start_toggle: CheckButton
@export var level_start_anim_duration_option: Control
@export var level_start_animation_duration_input: ScalarValueInput

@export var default_move_speed_input: ScalarValueInput
@export var default_teleport_duration_input: ScalarValueInput

@export var auto_reload_checkpoint_for_no_cam_focus_toggle: CheckButton

@export var follow_by_controller_picker: OptionButton

@export var auto_undo_option: Control
@export var auto_undo_toggle: CheckButton

@export var action_1_is_undo_toggle: CheckButton

@export var start_paused_option: Control
@export var start_level_paused_toggle: CheckButton

@export var section_container: Control

var _save_as_dialog_open: bool = false

static var expanded_sections: Array[String] = []

func _ready():
	refresh_expanded_sections()
	if OS.has_feature("web"):
		find_child("OpenGameDir").disabled = true
	GameManager.game_dir_name_changed.connect(on_game_dir_name_changed)
	name_input.text = GameManager.get_game_name()
	init_movement_modes()
	
	update_identifier_label()
	
	game_settings = GameManager.game_definition["game_settings"]
	
	var title_input: LineEdit = find_child("TitleInput")
	title_input.text = GameManager.get_game_setting("title", "")
	title_input.placeholder_text = GameManager.get_game_implicit_title()
	
	game_identifier_panel.gui_input.connect(on_game_identifier_panel_gui_input)
	game_identifier_input.text_submitted.connect(on_game_identifier_input_text_submitted)
	game_identifier_input.editing_toggled.connect(on_game_identifier_input_editing_toggled)
	game_identifier_input_panel.hide()
	
	game_identifier_set_button.pressed.connect(on_game_identifier_set_button_pressed)
	game_identifier_cancel_button.pressed.connect(on_game_identifier_cancel_button_pressed)
	
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
	else:
		follow_by_button.text = "controller"
	if "enable_limits" in cam_settings:
		find_child("EnableLimitsToggle").button_pressed = cam_settings["enable_limits"]
	
	follow_by_controller_picker.clear()
	for controller_type in EntityManager.controller_templates.keys():
		follow_by_controller_picker.add_item(controller_type)
	var selected_controller_type: String = "InputController"
	if cam_settings.get("follow_entity_by", "controller") == "controller":
		selected_controller_type = cam_settings.get("follow_entity", "InputController")
		if selected_controller_type not in EntityManager.controller_templates.keys():
			prints("changing follow setting to InputController")
			selected_controller_type = "InputController"
			game_settings["camera_settings"]["follow_entity"] = "InputController"
	Utility.opbtn_select_text(follow_by_controller_picker, selected_controller_type)
	follow_by_controller_picker.item_selected.connect(on_follow_by_controller_option_picked)

	follow_by_controller_picker.visible = cam_settings.get("follow_entity_by", "controller") == "controller"
	find_child("FollowEntity").visible = cam_settings.get("follow_entity_by", "controller") != "controller"
	
	var is_continuous: bool = is_continuous_movement_mode()
	auto_undo_option.visible = not is_continuous
	
	auto_undo_toggle.set_pressed_no_signal(game_settings.get("auto_undo", true) if not is_continuous else true)
	auto_undo_toggle.toggled.connect(on_auto_undo_toggled)
	
	action_1_is_undo_toggle.set_pressed_no_signal(game_settings.get("action_1_does_undo", true))
	action_1_is_undo_toggle.toggled.connect(on_action_1_is_undo_toggled)
	
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
	
	tele_interp_option_picker.clear()
	for intertp_id in Utility.POS_INTERP_STRINGS.keys():
		tele_interp_option_picker.add_item(Utility.POS_INTERP_STRINGS[intertp_id], intertp_id)

	move_interp_option_picker.item_selected.connect(on_move_interp_option_picked)
	var cur_interp: = GameManager.get_game_setting("default_move_interp", "") as String
	var interp_id: int = Utility.PosInterpStyle.CONTINUOUS_LINEAR
	if cur_interp:
		interp_id = BaseEntity.read_move_interp_style_string(cur_interp)
	Utility.opbtn_select_id(move_interp_option_picker, interp_id)
	
	tele_interp_option_picker.item_selected.connect(on_tele_interp_option_picked)
	var cur_tele_interp: = GameManager.get_game_setting("default_teleport_interp", "") as String
	var tele_interp_id: int = Utility.PosInterpStyle.CONTINUOUS_LINEAR
	if cur_tele_interp:
		tele_interp_id = BaseEntity.read_move_interp_style_string(cur_tele_interp)
	Utility.opbtn_select_id(tele_interp_option_picker, tele_interp_id)
	
	turn_animation_option_picker.item_selected.connect(on_turn_animation_option_picked)
	Utility.opbtn_select_text(turn_animation_option_picker, GameManager.get_game_setting("default_turn_animation", "quick"))
	
	default_move_speed_input.set_value(GameManager.get_game_setting("entity_move_speed", EntityManager.DEFAULT_MOVE_SPEED))
	default_move_speed_input.value_changed.connect(on_default_move_speed_changed)
	
	var def_raw: = EntityManager.DEFAULT_TELEPORT_DURATION
	var tps: = GameManager.get_full_tick_rate()
	var def_tele_rounded: float = floorf((ceilf(def_raw * tps) / tps) * 100) / 100
	default_teleport_duration_input.set_value(GameManager.get_game_setting("default_teleport_duration", def_tele_rounded))
	default_teleport_duration_input.value_changed.connect(on_default_teleport_duration_changed)
	refresh_teleport_duration_tooltip()
	
	action_signal_sent_to_option_picker.item_selected.connect(on_action_signal_sent_to_option_picked)
	var cur_action_signal_sent_to: = GameManager.get_game_setting("action_signal_sent_to", "all_entities") as String
	action_signal_sent_to_option_picker.selected = -1
	for i in action_signal_sent_to_option_picker.item_count:
		if action_signal_sent_to_option_picker.get_item_text(i) == cur_action_signal_sent_to:
			action_signal_sent_to_option_picker.select(i)
			break
	
	start_paused_option.visible = is_continuous
	start_level_paused_toggle.set_pressed_no_signal(GameManager.get_game_setting("start_level_paused", false))
	start_level_paused_toggle.toggled.connect(on_start_level_paused_toggle_toggled)
	
	def_dying_eff_picker.item_selected.connect(on_default_dying_eff_option_picked)
	var cur_dying_eff: String = GameManager.get_game_setting("default_dying_effect", "")
	def_dying_eff_picker.clear()
	def_dying_eff_picker.add_item("None")
	for effect_name in SpriteEffects.DYING_EFFECTS:
		def_dying_eff_picker.add_item(effect_name)

	if cur_dying_eff:
		Utility.opbtn_select_text(def_dying_eff_picker, cur_dying_eff)
	else:
		def_dying_eff_picker.selected = 0
	
	def_spawn_eff_picker.item_selected.connect(on_default_spawn_eff_option_picked)
	var cur_spawn_eff: String = GameManager.get_game_setting("default_spawn_effect", "")
	def_spawn_eff_picker.clear()
	def_spawn_eff_picker.add_item("None")
	for effect_name in SpriteEffects.SPAWN_EFFECTS:
		def_spawn_eff_picker.add_item(effect_name)
	
	if cur_spawn_eff:
		Utility.opbtn_select_text(def_spawn_eff_picker, cur_spawn_eff)
	else:
		def_spawn_eff_picker.selected = 0
	
	var is_level_start_anim: bool = GameManager.get_game_setting("level_start_entity_spawn_effect_enabled", false)
	use_spawn_effect_at_level_start_toggle.set_pressed_no_signal(is_level_start_anim)
	use_spawn_effect_at_level_start_toggle.toggled.connect(on_use_spawn_effect_at_level_start_toggled)
	
	level_start_anim_duration_option.visible = is_level_start_anim
	
	var level_start_anim_duration: float = GameManager.get_game_setting("level_start_entity_spawn_effect_duration", 0.5)
	level_start_animation_duration_input.set_value(level_start_anim_duration)
	level_start_animation_duration_input.value_changed.connect(on_level_start_animation_duration_changed)
	
	var auto_reload_no_cam_focus: bool = GameManager.get_game_setting("auto_reload_checkpoint_for_no_cam_focus", false)
	auto_reload_checkpoint_for_no_cam_focus_toggle.set_pressed_no_signal(auto_reload_no_cam_focus)
	auto_reload_checkpoint_for_no_cam_focus_toggle.toggled.connect(on_auto_reload_checkpoint_for_no_cam_focus_toggled)


func refresh_expanded_sections() -> void:
	var all_sections: Array[FoldableContainer] = []
	for section_child in section_container.get_children():
		if section_child is FoldableContainer:
			all_sections.append(section_child)
	if expanded_sections.size() == 0:
		for section in all_sections:
			if not section.folded:
				expanded_sections.append(section.name)
	else:
		for section in all_sections:
			section.folded = section.name not in expanded_sections

	for section in all_sections:
		section.folding_changed.connect(on_section_folding_changed.bind(section))

func on_section_folding_changed(is_folded: bool, section: FoldableContainer) -> void:
	if not is_folded:
		if section.name not in expanded_sections:
			expanded_sections.append(section.name)
	else:
		expanded_sections.erase(section.name)


func is_continuous_movement_mode() -> bool:
	return GameManager.get_game_setting("movement_mode", GameManager.MovementMode.MOVEMENT_CONTINUOUS) == GameManager.MovementMode.MOVEMENT_CONTINUOUS

func init_movement_modes() -> void:
	var popup_menu: PopupMenu = find_child("MovementModeMenuButton").get_popup()
	
	for mode in GameManager.MovementMode.values():
		popup_menu.add_item(GameManager.describe_movement_mode(mode), mode)
	
	popup_menu.id_pressed.connect(movement_mode_picked)

func change_follow_by(val: String) -> void:
	var old_val: String = GameManager.get_cam_setting("follow_entity_by", "controller")
	if old_val == val:
		return
	if old_val == "controller":
		set_camera_settings("follow_entity", "")
	set_camera_settings("follow_entity_by", val)
	
	var prop_entity_name_input: PropOrEntityNameInput = find_child("FollowEntity") as PropOrEntityNameInput
	if prop_entity_name_input:
		if val == "controller":
			prop_entity_name_input.hide()
		else:
			prop_entity_name_input.show()
			var mode: String = PropOrEntityNameInput.PROP_NAME
			if val == "name":
				mode = PropOrEntityNameInput.ENTITY_NAME
			elif val == "name or property":
				mode = PropOrEntityNameInput.BOTH
			prop_entity_name_input.set_hint_mode(mode)
	
	follow_by_controller_picker.visible = val == "controller"
	if val == "controller" and GameManager.get_cam_setting("follow_entity", "InputController") not in EntityManager.controller_templates:
		GameManager.set_cam_setting("follow_entity", "InputController")
		Utility.opbtn_select_text(follow_by_controller_picker, "InputController")

func movement_mode_picked(mode_id: int) -> void:
	var popup_menu: PopupMenu = find_child("MovementModeMenuButton").get_popup()
	var index = popup_menu.get_item_index(mode_id)
	find_child("MovementModeMenuButton").text = popup_menu.get_item_text(index)
	
	GameManager.set_game_setting("movement_mode", mode_id)
	
	var is_continuous: bool = is_continuous_movement_mode()
	auto_undo_option.visible = not is_continuous
	start_paused_option.visible = is_continuous

func _on_SaveButton_pressed() -> void:
	if not GameManager.is_save_current_overwriting():
		_real_save()
	else:
		#_open_save_as_dialog()
		GlobalToaster.show_toast_message("Cannot save game with this ID, please change the Game ID", 2)

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
	FilesManager.save_default_game(GameManager.get_identified_game_name())
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
		FilesManager.save_default_game(GameManager.get_identified_game_name())

func on_move_interp_option_picked(index: int) -> void:
	var interp_style: = move_interp_option_picker.get_item_id(index) as Utility.PosInterpStyle
	GameManager.set_game_setting("default_move_interp", BaseEntity.get_move_interp_style_string(interp_style))
	GameManager.game_settings_changed.emit()

func on_tele_interp_option_picked(index: int) -> void:
	var interp_style: = tele_interp_option_picker.get_item_id(index) as Utility.PosInterpStyle
	GameManager.set_game_setting("default_teleport_interp", BaseEntity.get_move_interp_style_string(interp_style))
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

func on_game_identifier_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not game_identifier_input_panel.visible:
			game_identifier_input_panel.show()
			game_identifier_input.text = GameManager.get_game_identifier()
			game_identifier_input.grab_focus()
			accept_event()

func on_game_identifier_input_text_submitted(_new_text: String) -> void:
	do_update_identifier()

func on_game_identifier_set_button_pressed() -> void:
	prints("on_game_identifier_set_button_pressed")
	do_update_identifier()

func on_game_identifier_cancel_button_pressed() -> void:
	prints("game identifier cancel button pressed")
	game_identifier_input_panel.hide()

func do_update_identifier() -> void:
	if _save_as_dialog_open:
		return
	game_identifier_input_panel.hide()
	renaming_game_dir(true)

func on_game_identifier_input_editing_toggled(toggled_on: bool) -> void:
	if not toggled_on:
		await get_tree().process_frame
		if game_identifier_input_panel.visible:
			game_identifier_input_panel.hide()

func renaming_game_dir(is_changing_identifier: bool = false) -> void:
	_disable_name_input()
	var new_identifier: = GameManager.get_game_identifier()
	var new_game_dir_name: = GameManager.get_game_name()
	if is_changing_identifier:
		new_identifier = game_identifier_input.text
	else:
		new_game_dir_name = name_input.text

	var new_identified_game_name: = new_identifier + "/" + new_game_dir_name
	if is_changing_identifier:
		prints("updating identifier, new identified name: ", new_identified_game_name)
	if new_identified_game_name == GameManager.get_identified_game_name():
		return
	if not GameManager.is_current_game_saved() or FilesManager.is_game_name_equivalent(new_identified_game_name, GameManager.get_identified_game_name()):
		GameManager._set_identified_game_name(new_identified_game_name)
		return
	
	if GameManager.is_name_overwriting(new_identified_game_name):
		GlobalToaster.show_toast_message("Another game with this Game ID already exists", 2)
	else:
		var old_game_name: = GameManager.get_identified_game_name()
		if is_changing_identifier:
			if GameManager.save_current_game_definition_as(new_identified_game_name):
				GlobalToaster.show_toast_message("Created %s as a copy of %s" % [GameManager.get_identified_game_name(), old_game_name])
		else:
			if GameManager.rename_and_save_current_game_definition(new_identified_game_name):
				GlobalToaster.show_toast_message("Moved Game Definition from %s to %s" % [old_game_name, GameManager.get_identified_game_name()])
	update_identifier_label()

func update_identifier_label() -> void:
	var identifier: = GameManager.get_game_identifier()
	if not identifier:
		identifier = "?"
	game_identifier_label.text = identifier + "/"
	
#func _open_save_as_dialog(new_game_dir_name: String = "") -> void:
	#var save_as_dialog: = save_as_dialog_scn.instantiate() as Window
	#save_as_dialog.use_game_name = new_game_dir_name
	#save_as_dialog.hidden.connect(set.bind("_save_as_dialog_open", false))
	#add_child(save_as_dialog)
	#save_as_dialog.move_to_center()
	#_save_as_dialog_open = true
	#prints("opening save as dialog with game name: ", new_game_dir_name)

func _on_edit_game_dir_button_pressed() -> void:
	if _save_as_dialog_open:
		return
	_enable_name_input()
	name_input.grab_focus.call_deferred()


func _on_export_zip_pressed(no_bundle_pls: bool = false, is_release_export: bool = false) -> void:
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
	
	var export_location: String = ""
	if is_release_export:
		export_location = FilesManager.get_game_release_zip_directory(GameManager.get_identified_game_name())

	if OS.has_feature("web"):
		export_web_mode(export_location)
		return
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.title = "Export Game .zip To Folder..."
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.dir_selected.connect(_export_destination_picked.bind(export_location, file_dialog))
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

func export_web_mode(export_location: String = "") -> void:
	var prefer_skip_date_stamp: bool = export_location != ""
	var zip_path: String = ImporterExporter.export_game_zip(GameManager.get_identified_game_name(), export_location, "export", prefer_skip_date_stamp)
	var zip_byte_array: = FileAccess.get_file_as_bytes(zip_path)
	JavaScriptBridge.download_buffer(zip_byte_array, zip_path.get_file(), "application/zip")

func _export_destination_picked(path: String, export_location: String, file_dialog: FileDialog) -> void:
	file_dialog.queue_free()
	var prefer_skip_date_stamp: bool = export_location != ""
	var zip_path: String = ImporterExporter.export_game_zip(GameManager.get_identified_game_name(), export_location, "export", prefer_skip_date_stamp)
	if zip_path:
		var error: = DirAccess.rename_absolute(zip_path, path.path_join(zip_path.get_file()))
		if error != OK:
			push_error("Failed to rename zip file to %s: %s" % [path, error_string(error)])
			GlobalToaster.show_toast_message("Failed to copy exported Game .zip to destination folder", 2.0)
			return
		else:
			GlobalToaster.show_toast_message("Exported Game .zip to\n%s" % [zip_path], 1.5)
	else:
		GlobalToaster.show_toast_message("Failed to export Game .zip", 2.0)

func on_default_move_speed_changed(value: float) -> void:
	GameManager.set_game_setting("entity_move_speed", value)
	GameManager.game_settings_changed.emit()

func on_default_teleport_duration_changed(value: float) -> void:
	GameManager.set_game_setting("default_teleport_duration", value)
	GameManager.game_settings_changed.emit()
	refresh_teleport_duration_tooltip()

func refresh_teleport_duration_tooltip() -> void:
	var dur: float = default_teleport_duration_input.get_value()
	var frames: int = ceili(dur * GameManager.get_full_tick_rate())
	default_teleport_duration_input.set_tooltip("Teleport duration (seconds) rounded to logical frames at 60 FPS\n= %d frames" % [frames])

func _on_import_levels_btn_pressed() -> void:
	GameManager.start_import_levels()

func on_default_dying_eff_option_picked(index: int) -> void:
	var item_text: = def_dying_eff_picker.get_item_text(index)
	GameManager.set_game_setting("default_dying_effect", item_text)
	GameManager.game_settings_changed.emit()

func on_default_spawn_eff_option_picked(index: int) -> void:
	var item_text: = def_spawn_eff_picker.get_item_text(index)
	GameManager.set_game_setting("default_spawn_effect", item_text)
	GameManager.game_settings_changed.emit()

func on_use_spawn_effect_at_level_start_toggled(button_pressed: bool) -> void:
	prints("on_use_spawn_effect_at_level_start_toggled: ", button_pressed)
	level_start_anim_duration_option.visible = button_pressed
	GameManager.set_game_setting("level_start_entity_spawn_effect_enabled", button_pressed)
	GameManager.game_settings_changed.emit()

func on_auto_reload_checkpoint_for_no_cam_focus_toggled(button_pressed: bool) -> void:
	GameManager.set_game_setting("auto_reload_checkpoint_for_no_cam_focus", button_pressed)
	GameManager.game_settings_changed.emit()

func on_follow_by_controller_option_picked(index: int) -> void:
	set_camera_settings("follow_entity", follow_by_controller_picker.get_item_text(index))

func on_auto_undo_toggled(button_pressed: bool) -> void:
	GameManager.set_game_setting("auto_undo", button_pressed)
	GameManager.game_settings_changed.emit()

func on_action_1_is_undo_toggled(button_pressed: bool) -> void:
	GameManager.set_game_setting("action_1_does_undo", button_pressed)
	GameManager.game_settings_changed.emit()

func on_start_level_paused_toggle_toggled(button_pressed: bool) -> void:
	GameManager.set_game_setting("start_level_paused", button_pressed)
	GameManager.game_settings_changed.emit()

func on_level_start_animation_duration_changed(value: float) -> void:
	GameManager.set_game_setting("level_start_entity_spawn_effect_duration", value)
	GameManager.game_settings_changed.emit()