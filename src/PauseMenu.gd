extends Control

signal gameplay_paused

var save_dialog = preload("res://Scenes/SaveLevelDialog.tscn")
var load_dialog = preload("res://Scenes/LoadLevelDialog.tscn")

var active = false

@export var next_level_list: OptionButton
@export var level_title_edit: LineEdit

@onready var main_panel: PanelContainer = find_child("MainPausePanel")
@onready var level_settings_panel: PanelContainer = find_child("LevelSettingsPausePanel")

func _ready():
	switch_panel("main")
	visible = false
	if next_level_list:
		next_level_list.item_selected.connect(next_level_picked)
	
	GameManager.level_state_loaded.connect(refresh_level_settings)
	if level_title_edit:
		level_title_edit.text_changed.connect(on_level_title_edited)

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

func on_show() -> void:
	var restart_button = find_child("RestartLevel")
	restart_button.visible = GameManager.loaded_level_name != ""
	
	var has_saved_levels: bool = FilesManager.get_level_list(GameManager.cur_game_name).size() > 0
	
	var load_button: BaseButton = find_child("LoadLevelButton")
	load_button.disabled = not has_saved_levels
	
	var live_edit_mode_toggle: CheckButton = find_child("LiveEditModeToggle")
	live_edit_mode_toggle.set_pressed_no_signal(GameManager.editor_live_edit_mode)
	
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
	GameManager.level_start()
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
	GameManager.editor_live_edit_mode = toggled_on

func next_level_picked(index: int) -> void:
	var level_name = next_level_list.get_item_text(index)
	if level_name == "[None]":
		level_name = ""
	MapManager.set_metadata_value("next_level", level_name)

func on_level_title_edited(new_title: String) -> void:
	if new_title == "":
		MapManager.map_metadata.erase("title")
	else:
		MapManager.map_metadata["title"] = new_title

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
		next_level_list.add_item(level)

	if MapManager.has_next_level():
		var index = level_list.find(MapManager.get_metadata_value("next_level"))
		next_level_list.selected = index
	else:
		next_level_list.selected = 0