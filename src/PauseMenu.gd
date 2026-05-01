extends Control

signal gameplay_paused
signal pause_menu_closed

var save_dialog = preload("res://Scenes/SaveLevelDialog.tscn")
var load_dialog = preload("res://Scenes/LoadLevelDialog.tscn")

var active = false

@export var next_level_list: OptionButton
@export var level_title_edit: LineEdit

@export var editor_stuff: Control

@export var play_mode_button: Button
@export var level_edit_mode_button: Button

@onready var main_panel: PanelContainer = find_child("MainPausePanel")
@onready var level_settings_panel: PanelContainer = find_child("LevelSettingsPausePanel")

func _ready():
	play_mode_button.pressed.connect(switch_to_non_level_edit_mode)
	level_edit_mode_button.pressed.connect(switch_to_level_edit_mode)

	switch_panel("main")
	visible = false
	if next_level_list:
		next_level_list.item_selected.connect(next_level_picked)
	
	GameManager.level_state_loaded.connect(refresh_level_settings)
	if level_title_edit:
		level_title_edit.text_changed.connect(on_level_title_edited)

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
	prints("check_should_focus_event: ", event)
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
	level_settings_panel.visible = not is_main_panel
	if level_settings_panel.visible:
		refresh_level_settings()

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
	var restart_button = find_child("RestartLevel")
	restart_button.visible = GameManager.loaded_level_name != ""
	
	var has_saved_levels: bool = FilesManager.get_level_list(GameManager.cur_game_name).size() > 0
	
	var load_button: BaseButton = find_child("LoadLevelButton")
	load_button.disabled = not has_saved_levels
	
	play_mode_button.visible = GameManager.is_in_level_edit_mode
	level_edit_mode_button.visible = not GameManager.is_in_level_edit_mode
	
	var live_edit_mode_toggle: CheckButton = find_child("LiveEditModeToggle")
	live_edit_mode_toggle.disabled = GameManager.current_level_is_museum
	if GameManager.current_level_is_museum:
		live_edit_mode_toggle.tooltip_text = "Live edit mode is always active in the museum"
	else:
		live_edit_mode_toggle.tooltip_text = ""
	live_edit_mode_toggle.set_pressed_no_signal(GameManager.is_live_edit())
	
	live_edit_mode_toggle.visible = GameManager.is_in_level_edit_mode
	editor_stuff.visible = GameManager.is_in_level_edit_mode
	
	refresh_level_settings()

func close_pause_menu() -> void:
	if active:
		toggle()

func _on_QuitToMenu_pressed():
	GameManager.change_scene("Menu")

func _on_SaveLevelButton_pressed():
	var popup: Window = save_dialog.instantiate()
	add_child(popup)
	popup.popup_centered()
	popup.hidden.connect(refresh_level_settings)

func _on_new_level_button_pressed() -> void:
	GameManager.new_empty_level()
	close_pause_menu()

func _on_LoadLevelButton_pressed():
	var popup: Window = load_dialog.instantiate()
	add_child(popup)
	popup.popup_centered()

func _on_RestartLevel_pressed():
	GameManager.load_edited()
	close_pause_menu()

func _on_resume_button_pressed() -> void:
	close_pause_menu()

func _on_live_edit_mode_toggle_toggled(toggled_on: bool) -> void:
	GameManager.set_live_edit_mode_enabled(toggled_on)

func next_level_picked(index: int) -> void:
	var level_name = next_level_list.get_item_text(index)
	if level_name == "[None]":
		level_name = ""
	MapManager.set_metadata_value("next_level", level_name)

func on_level_title_edited(new_title: String) -> void:
	if new_title == "":
		MapManager.erase_metadata_value("title")
	else:
		MapManager.set_metadata_value("title", new_title)

func _on_edit_level_settings_button_pressed() -> void:
	switch_panel("level_settings")

func refresh_level_settings() -> void:
	refresh_next_level_list()
	level_title_edit.text = MapManager.map_metadata.get("title", "")
	level_title_edit.placeholder_text = GameManager.loaded_level_name

func refresh_next_level_list() -> void:
	if not next_level_list:
		return
	
	next_level_list.clear()

	var level_list: = FilesManager.get_level_list(GameManager.cur_game_name)
	level_list.push_front("[None]")

	for level in level_list:
		if level == "editor_autosave" or level == "editor autosave":
			continue
		next_level_list.add_item(level)

	if MapManager.has_next_level():
		Utility.opbtn_select_text(next_level_list, MapManager.get_metadata_value("next_level"))
	else:
		next_level_list.selected = 0

func _on_back_button_pressed() -> void:
	switch_panel("main")


func _on_museum_button_pressed() -> void:
	GameManager.new_museum_level()
	close_pause_menu()


func _on_credits_button_pressed() -> void:
	GameManager.show_credits()
	toggle()

func go_to_level_select() -> void:
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
	GameManager.set_live_edit_mode_enabled(false)
	var map_editor = Utility.get_map_editor()
	if map_editor:
		map_editor.switch_edit_mode(true)

func switch_to_non_level_edit_mode() -> void:
	if not GameManager.is_in_level_edit_mode:
		return
	if active:
		toggle()
	var map_editor = Utility.get_map_editor()
	if map_editor:
		map_editor.switch_to_non_level_edit_mode()