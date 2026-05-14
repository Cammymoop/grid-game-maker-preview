extends PanelContainer

@export var close_texture_button: TextureRect

@export var keyboard_controls: Control
@export var controller_controls: Control

func _ready() -> void:
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