extends Control

var active = false

func _ready():
	visible = false

func toggle():
	active = not active
	if active:
		visible = true
		GameManager.set_pause("pause_menu", true)
	else:
		visible = false
		GameManager.set_pause("pause_menu", false)


func _on_QuitToMenu_pressed():
	GameManager.change_scene("Menu")
