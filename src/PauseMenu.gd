extends Control

signal gameplay_paused

var save_dialog = preload("res://Scenes/SaveLevelDialog.tscn")
var load_dialog = preload("res://Scenes/LoadLevelDialog.tscn")

var active = false

func _ready():
	visible = false

func toggle():
	active = not active
	if active:
		emit_signal("gameplay_paused")
		visible = true
		GameManager.set_pause("pause_menu", true)
		on_show()
	else:
		visible = false
		GameManager.set_pause("pause_menu", false)

func on_show() -> void:
	var restart_button = find_child("RestartLevel")
	restart_button.visible = GameManager.loaded_level_name != ""
	
	var has_saved_levels: bool = FilesManager.get_level_list(GameManager.cur_game_name).size() > 0
	
	var load_button: BaseButton = find_child("LoadLevelButton")
	load_button.disabled = not has_saved_levels
	
	var live_edit_mode_toggle: CheckButton = find_child("LiveEditModeToggle")
	live_edit_mode_toggle.set_pressed_no_signal(GameManager.editor_live_edit_mode)

func close_pause_menu() -> void:
	if active:
		toggle()

func _on_QuitToMenu_pressed():
	GameManager.change_scene("Menu")

func _on_SaveLevelButton_pressed():
	var popup = save_dialog.instantiate()
	add_child(popup)
	popup.popup_centered()

func _on_new_level_button_pressed() -> void:
	GameManager.level_start()
	close_pause_menu()

func _on_LoadLevelButton_pressed():
	var popup = load_dialog.instantiate()
	add_child(popup)
	popup.popup_centered()

func _on_RestartLevel_pressed():
	GameManager.load_edited()
	close_pause_menu()

func _on_resume_button_pressed() -> void:
	close_pause_menu()

func _on_live_edit_mode_toggle_toggled(toggled_on: bool) -> void:
	GameManager.editor_live_edit_mode = toggled_on
