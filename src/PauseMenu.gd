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
	else:
		visible = false
		GameManager.set_pause("pause_menu", false)


func _on_QuitToMenu_pressed():
	GameManager.change_scene("Menu")


func _on_SaveLevelButton_pressed():
	var popup = save_dialog.instance()
	add_child(popup)
	popup.popup_centered()


func _on_LoadLevelButton_pressed():
	var popup = load_dialog.instance()
	add_child(popup)
	popup.popup_centered()
