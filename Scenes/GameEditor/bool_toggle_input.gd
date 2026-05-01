extends Control

signal value_changed(new_value: bool)

@export var true_button: Button
@export var false_button: Button

var button_group: ButtonGroup
var my_value: bool = true

func _ready() -> void:
    true_button.focus_neighbor_right = true_button.get_path_to(false_button)
    true_button.focus_next = true_button.get_path_to(false_button)
    false_button.focus_neighbor_left = false_button.get_path_to(true_button)
    false_button.focus_previous = false_button.get_path_to(true_button)
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
        true_button.set_pressed_no_signal(true)
        false_button.set_pressed_no_signal(false)
    else:
        true_button.set_pressed_no_signal(false)
        false_button.set_pressed_no_signal(true)

func get_value() -> bool:
    return my_value

func unset_all_up_down_focus_neighbors() -> void:
    for button in [true_button, false_button]:
        button.focus_neighbor_top = ^""
        button.focus_neighbor_bottom = ^""

func set_focus_up_and_down(up: NodePath, down: NodePath) -> void:
    if up:
        true_button.focus_neighbor_top = up
        false_button.focus_neighbor_top = up
    if down:
        true_button.focus_neighbor_bottom = down
        false_button.focus_neighbor_bottom = down

func set_focus_left_and_right(left: NodePath, right: NodePath) -> void:
    if left:
        true_button.focus_neighbor_left = left
        true_button.focus_previous = left
    if right:
        false_button.focus_neighbor_right = right
        false_button.focus_next = right
    
func button_grab_focus() -> void:
    if my_value:
        false_button.grab_focus()
    else:
        true_button.grab_focus()