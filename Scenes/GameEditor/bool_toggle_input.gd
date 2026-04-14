extends Control

signal value_changed(new_value: bool)

@export var true_button: Button
@export var false_button: Button

var button_group: ButtonGroup
var my_value: bool = true

func _ready() -> void:
    button_group = true_button.button_group
    if not button_group:
        button_group = ButtonGroup.new()
        true_button.button_group = button_group
        false_button.button_group = button_group
    button_group.allow_unpress = false
    button_group.pressed.connect(on_button_pressed)

func on_button_pressed(_button: BaseButton) -> void:
    my_value = button_group.get_pressed_button() == true_button
    value_changed.emit(my_value)

func set_value(new_value: bool) -> void:
    my_value = new_value
    if my_value:
        true_button.button_pressed = true
    else:
        false_button.button_pressed = true

func get_value() -> bool:
    return my_value