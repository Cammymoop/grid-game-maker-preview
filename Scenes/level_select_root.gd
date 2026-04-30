extends Control

@export var level_select_ui: VBoxContainer

func _ready() -> void:
    GameManager.level_state_loaded.connect(on_level_state_loaded)
    hide()
    level_select_ui.close_level_select.connect(on_level_select_ui_close_level_select)

func on_level_state_loaded() -> void:
    if visible:
        close_level_select()

func on_level_select_ui_close_level_select() -> void:
    close_level_select()

func open_level_select() -> void:
    GameManager.set_pause("level_select", true)
    level_select_ui.load_unlocked_level_lists()
    show()

func close_level_select() -> void:
    GameManager.set_pause("level_select", false)
    hide()
