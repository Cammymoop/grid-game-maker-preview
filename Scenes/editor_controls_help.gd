extends PanelContainer

@export var close_texture_button: TextureRect

@export var keyboard_controls: Control
@export var controller_controls: Control

@export var show_gamepad_controls_toggle: CheckButton

func _ready() -> void:
    show_gamepad_controls_toggle.toggled.connect(on_show_gamepad_controls_toggle_toggled)
    show_gamepad_controls_toggle.set_pressed_no_signal(controller_controls.visible)

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

func on_show_gamepad_controls_toggle_toggled(is_toggled: bool) -> void:
    if is_toggled:
        show_controller_controls()
    else:
        show_keyboard_controls()

func show_keyboard_controls() -> void:
    keyboard_controls.show()
    controller_controls.hide()
    show_gamepad_controls_toggle.set_pressed_no_signal(false)

func show_controller_controls() -> void:
    keyboard_controls.hide()
    controller_controls.show()
    show_gamepad_controls_toggle.set_pressed_no_signal(true)

func on_visibility_changed() -> void:
    if GameManager.is_in_level_edit_mode:
        GameManager.player_profile.set_profile_setting("showing_controls_help", visible)