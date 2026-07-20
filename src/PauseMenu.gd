extends Control

const BGStyleEditor = preload("res://Scenes/GameEditor/bg_style_editor.gd")

const Vector2fInput = preload("res://src/GameEditor/ConditionalEditor/vector2f_input.gd")

signal gameplay_paused
signal pause_menu_closed
signal level_metadata_changed

var save_dialog = preload("res://Scenes/SaveLevelDialog.tscn")
var load_dialog = preload("res://Scenes/LoadLevelDialog.tscn")

var active = false

@export var resume_button: Button
@export var restart_level_button: Button
@export var reload_checkpoint_button: Button

@export var regen_museum_button: Button

@export var credits_button: Button
@export var level_title_edit: LineEdit
@export var level_subtitle_edit: LineEdit

@export var non_editor_stuff: Control
@export var editor_stuff: Control
@export var level_select_button: Button

@export var level_editor_controls_help_toggle: CheckButton

@export var play_mode_button: ButtonContainer
@export var go_to_edit_game_button: ButtonContainer
@export var level_edit_mode_button: Button

@export var web_export_level_button: Button

@export var background_editor_container: Control
@export var background_editor: BGStyleEditor
@export var darkener: ColorRect

@export var level_size_label: Label

@onready var main_panel: PanelContainer = find_child("MainPausePanel")
@onready var level_settings_panel: PanelContainer = find_child("LevelSettingsPausePanel")

@export var user_settings_panel: PanelContainer

@export var start_level_paused_toggle: CheckButton

@export var override_cam_limit_select: OptionButton

@export var level_notes_text_edit: TextEdit

@export var level_list_picker: OptionButton

@export var override_view_size_input: Vector2fInput

@export var copy_to_clipboard_button: Button
@export var paste_from_clipboard_button: Button

@export var save_button: Button
@export var save_as_button: Button

@export var level_info_panel: Control

@export var goto_user_settings_button: Button

@onready var level_notes_min_height: int = level_notes_text_edit.custom_minimum_size.y

func _ready():
	user_settings_panel.request_back.connect(switch_panel.bind("main"))
	
	regen_museum_button.pressed.connect(_on_museum_button_pressed)
	
	level_editor_controls_help_toggle.gui_input.connect(on_level_editor_controls_help_toggle_gui_input)
	level_editor_controls_help_toggle.toggled.connect(on_level_editor_controls_help_toggle_pressed)
	
	level_notes_text_edit.text_changed.connect(on_level_notes_text_edited)
	level_notes_text_edit.gui_input.connect(on_level_notes_text_edit_gui_input)
	level_notes_text_edit.focus_entered.connect(on_level_notes_text_edit_focus_entered)
	
	goto_user_settings_button.pressed.connect(switch_panel.bind("user_settings"))

	copy_to_clipboard_button.pressed.connect(on_copy_to_clipboard_button_pressed)
	paste_from_clipboard_button.pressed.connect(on_paste_from_clipboard_button_pressed)

	web_export_level_button.visible = OS.has_feature("web")
	web_export_level_button.pressed.connect(on_web_export_level_button_pressed)
	
	save_as_button.pressed.connect(on_save_as_button_pressed)

	background_editor_container.hide()
	play_mode_button.pressed.connect(switch_to_non_level_edit_mode)
	level_edit_mode_button.pressed.connect(switch_to_level_edit_mode)
	go_to_edit_game_button.pressed.connect(switch_to_edit_game)

	switch_panel("main")
	visible = false
	
	GameManager.level_state_loaded.connect(refresh_level_settings)
	level_title_edit.text_changed.connect(on_level_title_edited)
	
	level_subtitle_edit.text_changed.connect(on_level_subtitle_edited)
	
	start_level_paused_toggle.toggled.connect(on_start_level_paused_toggle_toggled)
	if GameManager.is_in_level_edit_mode:
		start_level_paused_toggle.set_pressed_no_signal(MapManager.is_level_start_paused())
	

	if MapManager.has_metadata_value("override_enable_camera_limits"):
		var is_limit: bool = MapManager.get_metadata_value("override_enable_camera_limits", false)
		override_cam_limit_select.selected = 1 if is_limit else 2
	else:
		override_cam_limit_select.selected = 0
	override_cam_limit_select.item_selected.connect(on_override_cam_limit_select_item_selected)
	
	override_view_size_input.set_value(Vector2.ZERO)
	override_view_size_input.value_changed.connect(on_override_view_size_input_value_changed)
	
	level_list_picker.item_selected.connect(level_list_picked)

func _unhandled_input(event: InputEvent) -> void:
	if Utility.fixed_just_pressed_by_event("pause_game", event):
		toggle()
		accept_event()

	if active:
		if Utility.event_is_menu_back_just_pressed(event):
			if not main_panel.visible:
				switch_panel("main")
			else:
				toggle()
			accept_event()
		else:
			check_should_focus_event(event)

func check_should_focus_event(event: InputEvent) -> void:
	var current_focus_owner: = get_viewport().gui_get_focus_owner()
	if current_focus_owner and is_ancestor_of(current_focus_owner):
		return
	var do_grab_focus: = false
	for focus_dir_action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		if Utility.fixed_just_pressed_by_event(focus_dir_action, event):
			do_grab_focus = true
	if do_grab_focus:
		var first_visible_button: = _get_first_visible_button()
		if first_visible_button:
			first_visible_button.grab_focus.call_deferred()

func _get_first_visible_button() -> Control:
	if main_panel.visible:
		return main_panel.find_child("ResumeButton")
	else:
		return level_settings_panel.find_child("BackButton")


func switch_panel(to_panel: String) -> void:
	var is_main_panel: = to_panel == "main"
	main_panel.visible = is_main_panel
	var is_level_settings_panel: = to_panel == "level_settings"
	level_settings_panel.visible = is_level_settings_panel
	if is_level_settings_panel:
		level_info_panel.force_show_level_info()
		show_background_editor()
		refresh_level_settings()
	else:
		level_info_panel.refresh_ui()
		hide_background_editor()
	
	var is_user_settings_panel: = to_panel == "user_settings"
	user_settings_panel.visible = is_user_settings_panel
	if is_user_settings_panel:
		user_settings_panel.refresh_ui()

func toggle():
	active = not active
	GameManager.set_pause("pause_menu", active)
	if active:
		switch_panel("main")
		gameplay_paused.emit()
		visible = true
		on_show()
	else:
		visible = false
		pause_menu_closed.emit()

func on_show() -> void:
	if GameManager.is_in_level_edit_mode:
		resume_button.text = "Resume Editor"
	else:
		resume_button.text = "Resume"

	restart_level_button.visible = not GameManager.is_in_level_edit_mode
	reload_checkpoint_button.visible = not GameManager.is_in_level_edit_mode
	
	regen_museum_button.visible = GameManager.current_level_is_museum
	
	#var has_saved_levels: bool = FilesManager.get_level_list(GameManager.get_identified_game_name()).size() > 0
	
	#level_select_button.visible = not GameManager.is_in_level_edit_mode
	
	play_mode_button.visible = GameManager.is_in_level_edit_mode
	level_edit_mode_button.visible = not GameManager.is_in_level_edit_mode
	
	var live_edit_mode_toggle: CheckButton = find_child("LiveEditModeToggle")
	live_edit_mode_toggle.disabled = GameManager.current_level_is_museum
	if GameManager.current_level_is_museum:
		live_edit_mode_toggle.tooltip_text = "Live edit mode is always active in the museum"
	else:
		live_edit_mode_toggle.tooltip_text = ""
	live_edit_mode_toggle.set_pressed_no_signal(GameManager.is_live_edit())
	
	#live_edit_mode_toggle.visible = GameManager.is_in_level_edit_mode
	editor_stuff.visible = GameManager.is_in_level_edit_mode
	non_editor_stuff.visible = not GameManager.is_in_level_edit_mode
	
	if GameManager.is_in_level_edit_mode:
		save_button.disabled = false
		if GameManager.current_game_is_release_locked:
			if GameManager.loaded_level_name in GameManager.get_list_of_all_bundled_levels():
				if not GameManager.is_live_edit():
					GameManager.set_live_edit_mode_enabled(true)
					live_edit_mode_toggle.set_pressed_no_signal(true)
				live_edit_mode_toggle.disabled = true
				live_edit_mode_toggle.tooltip_text = "Live edit only for bundled levels in released version"
				live_edit_mode_toggle.tooltip_text += "\nGo to Game Edit to unlock editing"
				
				save_button.disabled = true

		var current_level_list: String = GameManager.current_level_list
		if not current_level_list:
			current_level_list = GameManager.get_list_containing_level(GameManager.loaded_level_name)
		refresh_level_list_picker(current_level_list)
		
		var cur_level_base64: = GameManager.clipboardify_level_data(GameManager.get_edited_as_level_data())
		copy_to_clipboard_button.disabled = cur_level_base64.length() > GameManager.MAX_LEVEL_TEXT_SIZE
		var char_size_text: = Utility.int_with_commas(cur_level_base64.length())

		level_size_label.text = "Level Size (text):\n"
		if cur_level_base64.length() > GameManager.MAX_LEVEL_TEXT_SIZE:
			level_size_label.text += "%s (TOO BIG)" % [char_size_text]
		else:
			var level_size_percentage: = (cur_level_base64.length() / float(GameManager.MAX_LEVEL_TEXT_SIZE)) * 100.0
			level_size_percentage = clampf(level_size_percentage, 0.1, 99.9)
			if cur_level_base64.length() == GameManager.MAX_LEVEL_TEXT_SIZE:
				level_size_percentage = 100.0
			level_size_label.text += "%.1f%% (%s)" % [level_size_percentage, char_size_text]
		
		var has_clipboard_level: = false
		if DisplayServer.clipboard_has(): 
			var clipboard_data: = DisplayServer.clipboard_get()
			if clipboard_data and clipboard_data.substr(0, 20).contains(":") and clipboard_data[0].is_valid_int():
				has_clipboard_level = true
		paste_from_clipboard_button.disabled = not has_clipboard_level
		
		start_level_paused_toggle.set_pressed_no_signal(MapManager.is_level_start_paused())
		
		if MapManager.has_metadata_value("override_enable_camera_limits"):
			var is_limit: bool = MapManager.get_metadata_value("override_enable_camera_limits", false)
			override_cam_limit_select.selected = 1 if is_limit else 2
		else:
			override_cam_limit_select.selected = 0
			
		var override_view_size: Vector2 = MapManager.get_override_view_size()
		override_view_size_input.set_value(override_view_size)

		var game_view_size: Vector2 = GameManager.get_window_size_setting()
		override_view_size_input.set_tooltip("Default view size: (%s, %s)" % [snappedf(game_view_size.x, 0.01), snappedf(game_view_size.y, 0.01)])
		
		var map_editor_overlay: Node = Utility.get_map_editor_overlay()
		if map_editor_overlay:
			level_editor_controls_help_toggle.set_pressed_no_signal(map_editor_overlay.is_showing_controls_help())
		
		var level_notes: String = MapManager.get_metadata_value("level_notes", "")
		level_notes_text_edit.text = level_notes
		adjust_level_notes_edit_height()
	else:
		var is_intermission: = GameManager.is_intermission_mode
		
		reload_checkpoint_button.disabled = is_intermission
		restart_level_button.disabled = is_intermission
		regen_museum_button.disabled = is_intermission
		level_edit_mode_button.disabled = is_intermission
		credits_button.disabled = is_intermission
		level_select_button.disabled = is_intermission
		
	
	refresh_level_settings()

func close_pause_menu() -> void:
	if active:
		toggle()

func pause_and_open() -> void:
	if not active:
		toggle()

func _on_QuitToMenu_pressed():
	if GameManager.is_in_level_edit_mode:
		var map_editor: = Utility.get_map_editor()
		if map_editor:
			map_editor.quit_to_main_menu_with_confirm()
	else:
		GameManager.change_scene("Menu")

func _on_SaveLevelButton_pressed():
	do_save_or_save_as()

func do_save_or_save_as_if_edited() -> bool:
	if not GameManager.is_in_level_edit_mode:
		return true
	var map_editor: = Utility.get_map_editor()
	if not map_editor:
		push_warning("No map editor found")
		return true
	if not map_editor.has_edited_something:
		return true
	return do_save_or_save_as()

func do_save_or_save_as() -> bool:
	if not GameManager.is_in_level_edit_mode:
		return true

	if not GameManager.loaded_level_name or not GameManager.loaded_level_is_saved:
		on_save_as_button_pressed()
		return false
	else:
		var map_editor: = Utility.get_map_editor()
		if map_editor and map_editor.edit_mode:
			GameManager.save_edited()
		GameManager.save_edited_level_as(GameManager.loaded_level_name)
		return true

func on_save_as_button_pressed(after_save_as_callable: Callable = Callable()) -> void:
	var popup: Window = save_dialog.instantiate()
	add_child(popup)
	popup.saved_level.connect(level_was_saved.bind(GameManager.loaded_level_name))
	if after_save_as_callable.is_valid():
		popup.saved_level.connect(after_save_as_callable.call_deferred)
	popup.popup_centered()
	popup.hidden.connect(refresh_level_settings)

func level_was_saved(level_name: String, old_level_name: String) -> void:
	# in case it was a new level or it was saved as a new name, set it up to be in the selected list
	if not old_level_name or old_level_name != level_name:
		var current_selected_list: String = Utility.opbtn_get_selected_text(level_list_picker)
		if current_selected_list == "[No List]":
			current_selected_list = ""
		if GameManager.current_game_is_release_locked:
			current_selected_list = ""
		set_current_level_list_to(current_selected_list, false)

func _on_new_level_button_pressed() -> void:
	if not GameManager.is_in_level_edit_mode:
		return
	var map_editor: = Utility.get_map_editor()
	if map_editor:
		map_editor.edit_new_level()

func _on_RestartLevel_pressed():
	GameManager.load_edited(false)
	close_pause_menu()

func _on_ReloadCheckpoint_pressed():
	GameManager.load_checkpoint.call_deferred()
	close_pause_menu()

func _on_resume_button_pressed() -> void:
	close_pause_menu()

func _on_live_edit_mode_toggle_toggled(toggled_on: bool) -> void:
	if GameManager.current_game_is_release_locked:
		if GameManager.loaded_level_name in GameManager.get_list_of_all_bundled_levels():
			return
	GameManager.set_live_edit_mode_enabled(toggled_on)

func on_level_title_edited(new_title: String) -> void:
	if new_title == "":
		MapManager.erase_metadata_value("title")
	else:
		MapManager.set_metadata_value("title", new_title)
	level_metadata_changed.emit()

func on_level_subtitle_edited(new_subtitle: String) -> void:
	if new_subtitle == "":
		MapManager.erase_metadata_value("subtitle")
	else:
		MapManager.set_metadata_value("subtitle", new_subtitle)
	level_metadata_changed.emit()

func _on_edit_level_settings_button_pressed() -> void:
	switch_panel("level_settings")

func refresh_level_settings() -> void:
	#refresh_next_level_list()
	level_title_edit.text = MapManager.map_metadata.get("title", "")
	
	var list_of_current_level: String = ""
	if GameManager.loaded_level_name:
		level_title_edit.placeholder_text = GameManager.loaded_level_name
		if GameManager.current_level_list:
			list_of_current_level = GameManager.current_level_list
		else:
			list_of_current_level = GameManager.get_list_containing_level(GameManager.loaded_level_name)
	else:
		level_title_edit.placeholder_text = ""
	
	level_subtitle_edit.text = MapManager.get_level_subtitle()
	
	refresh_level_list_picker(list_of_current_level)

func refresh_level_list_picker(list_of_current_level: String) -> void:
	level_list_picker.clear()
	level_list_picker.add_item("[No List]")
	if GameManager.current_game_is_release_locked:
		return
	for list_name in GameManager.get_list_of_level_lists():
		level_list_picker.add_item(list_name)

	if not list_of_current_level:
		level_list_picker.selected = 0
	else:
		Utility.opbtn_select_text(level_list_picker, list_of_current_level)

func _on_back_button_pressed() -> void:
	switch_panel("main")

func _on_museum_button_pressed() -> void:
	if GameManager.is_in_level_edit_mode:
		var map_editor: = Utility.get_map_editor()
		if map_editor:
			map_editor.edit_new_level(true)
		return
	else:
		GameManager.new_museum_level()
		close_pause_menu()


func _on_credits_button_pressed() -> void:
	GameManager.show_credits()
	toggle()

func go_to_level_select() -> void:
	if GameManager.is_in_level_edit_mode:
		if not do_save_or_save_as_if_edited():
			return
	if active:
		toggle()
	var level_select_root = Utility.get_level_select_root()
	level_select_root.open_level_select()

func switch_to_level_edit_mode() -> void:
	if GameManager.is_in_level_edit_mode:
		return
	if active:
		toggle()
	GameManager.is_in_level_edit_mode = true
	GameManager.level_edit_mode_changed.emit()
	GameManager.set_live_edit_mode_enabled(false)
	var map_editor = Utility.get_map_editor()
	if map_editor:
		map_editor.hot_start_edit_mode()

func switch_to_non_level_edit_mode() -> void:
	if not GameManager.is_in_level_edit_mode:
		return
	if active:
		toggle()
	var map_editor = Utility.get_map_editor()
	if map_editor:
		map_editor.switch_to_non_level_edit_mode()

func switch_to_edit_game() -> void:
	if not GameManager.is_in_level_edit_mode:
		return
	if active:
		toggle()
	var map_editor: = Utility.get_map_editor()
	if map_editor:
		map_editor.quit_to_game_edit_with_confirm()

func show_background_editor() -> void:
	if not GameManager.is_in_level_edit_mode:
		return
	background_editor_container.show()
	darkener.hide()
	background_editor.load_bg_style()

func hide_background_editor() -> void:
	darkener.show()
	background_editor_container.hide()

func level_list_picked(index: int) -> void:
	if not GameManager.loaded_level_name:
		# the current level isn't saved, still allow choosing the list which it will be added to once saved
		return
	var list_name = level_list_picker.get_item_text(index)
	if list_name == "[No List]":
		list_name = ""
	
	set_current_level_list_to(list_name, true)

func set_current_level_list_to(list_name: String, show_toast: bool) -> void:
	if GameManager.current_game_is_release_locked:
		return
	if not list_name:
		GameManager._remove_level_from_all_lists(GameManager.loaded_level_name)
		GameManager.current_level_list = ""
	else:
		GameManager.move_level_to_level_list(GameManager.loaded_level_name, list_name)
		GameManager.current_level_list = list_name
	GameManager.save_current_game_definition()
	if show_toast:
		GlobalToaster.show_toast_message("Saved Level List")
	level_metadata_changed.emit()

func on_web_export_level_button_pressed() -> void:
	if not GameManager.is_in_level_edit_mode:
		return
	if not FilesManager.level_exists(GameManager.get_identified_game_name(), GameManager.loaded_level_name):
		GlobalToaster.show_toast_message("Saved level not found")
		return
	GameManager.web_export_level_json(GameManager.loaded_level_name)

func on_copy_to_clipboard_button_pressed() -> void:
	var cur_level_base64: = GameManager.clipboardify_level_data(GameManager.get_edited_as_level_data())
	DisplayServer.clipboard_set(cur_level_base64)
	GlobalToaster.show_toast_message("Copied Level to Clipboard (as text)")

func on_paste_from_clipboard_button_pressed() -> void:
	if not DisplayServer.clipboard_has():
		return
	var clipboard_data: = DisplayServer.clipboard_get()
	if not clipboard_data.substr(0, 20).contains(":"):
		return
	if not GameManager.load_level_from_clipboard_string(clipboard_data):
		GlobalToaster.show_toast_message("Failed to load level from clipboard text")

func on_level_editor_controls_help_toggle_pressed(toggled_on: bool) -> void:
	var map_editor_overlay: = Utility.get_map_editor_overlay()
	if map_editor_overlay:
		map_editor_overlay.set_show_controls_help(toggled_on)

func on_start_level_paused_toggle_toggled(toggled_on: bool) -> void:
	if GameManager.is_in_level_edit_mode:
		MapManager.set_level_start_paused(toggled_on)
		level_metadata_changed.emit()


func on_override_cam_limit_select_item_selected(index: int) -> void:
	if not GameManager.is_in_level_edit_mode:
		return
	if index == 0:
		MapManager.erase_metadata_value("override_enable_camera_limits")
	elif index == 1:
		MapManager.set_metadata_value("override_enable_camera_limits", true)
	else:
		MapManager.set_metadata_value("override_enable_camera_limits", false)
	level_metadata_changed.emit()
	GameManager.refresh_view_limit()

func on_level_editor_controls_help_toggle_gui_input(event: InputEvent) -> void:
	if not Input.is_action_just_pressed_by_event("ui_accept", event):
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var map_editor_overlay: = Utility.get_map_editor_overlay()
		if map_editor_overlay:
			map_editor_overlay.switch_controls_overlay_to_gamepad()

func on_level_notes_text_edited() -> void:
	if not GameManager.is_in_level_edit_mode:
		return
	MapManager.set_metadata_value("level_notes", level_notes_text_edit.text)
	level_metadata_changed.emit()
	adjust_level_notes_edit_height()

func on_level_notes_text_edit_gui_input(event: InputEvent) -> void:
	if not level_notes_text_edit.has_focus():
		return
	if level_notes_text_edit.editable:
		if Utility.event_is_menu_back_just_pressed(event):
			accept_event()
			level_notes_text_edit.editable = false
	else:
		if Utility.fixed_just_pressed_by_event("ui_accept", event):
			accept_event()
			level_notes_text_edit.editable = true
		else:
			var focus_neighbor: Control = null
			if Utility.fixed_just_pressed_by_event("ui_up", event):
				focus_neighbor = level_notes_text_edit.get_node_or_null(level_notes_text_edit.focus_neighbor_top) as Control
			elif Utility.fixed_just_pressed_by_event("ui_down", event):
				focus_neighbor = level_notes_text_edit.get_node_or_null(level_notes_text_edit.focus_neighbor_bottom) as Control
			if focus_neighbor:
				accept_event()
				focus_neighbor.grab_focus.call_deferred()
				return
	

func on_level_notes_text_edit_focus_entered() -> void:
	pass#level_notes_text_edit

func adjust_level_notes_edit_height() -> void:
	var num_lines: int = level_notes_text_edit.get_line_count()
	if num_lines > 5:
		level_notes_text_edit.custom_minimum_size.y = 24 * 5
		level_notes_text_edit.scroll_fit_content_height = false
	else:
		level_notes_text_edit.custom_minimum_size.y = level_notes_min_height
		level_notes_text_edit.scroll_fit_content_height = true

func on_override_view_size_input_value_changed(value: Vector2) -> void:
	MapManager.set_override_view_size(value)
	level_metadata_changed.emit()
	GameManager.refresh_game_view_size()