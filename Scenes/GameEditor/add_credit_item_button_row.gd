extends HBoxContainer

signal add_pressed(before_node: Node)

@export var button: Button

func _ready() -> void:
    button.pressed.connect(on_button_pressed)

func on_button_pressed() -> void:
    add_pressed.emit(self)