extends PanelContainer

@export var close_texture_button: TextureRect

@export var keyboard_controls: Control
@export var controller_controls: Control

func _ready() -> void:
    var show_help: bool = GameManager.player_profile.get_profile_setting("showing_controls_help", true)
    if not GameManager.is_in_level_edit_mode or not show_help:
        hide()
    visibility_changed.connect(on_visibility_changed)
    close_texture_button.gui_input.connect(on_close_texture_button_gui_input)
    show_keyboard_controls()

func on_close_texture_button_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        close_help()

func close_help() -> void:
    hide()


func show_keyboard_controls() -> void:
    keyboard_controls.show()
    controller_controls.hide()

func show_controller_controls() -> void:
    keyboard_controls.hide()
    controller_controls.show()

func on_visibility_changed() -> void:
    if GameManager.is_in_level_edit_mode:
        GameManager.player_profile.set_profile_setting("showing_controls_help", visible)