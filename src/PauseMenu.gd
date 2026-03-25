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


func _on_QuitToMenu_pressed():
	GameManager.change_scene("Menu")


func _on_SaveLevelButton_pressed():
	var popup = save_dialog.instantiate()
	add_child(popup)
	popup.popup_centered()


func _on_LoadLevelButton_pressed():
	var popup = load_dialog.instantiate()
	add_child(popup)
	popup.popup_centered()


func _on_RestartLevel_pressed():
	GameManager.load_edited()
	toggle()
