extends Control

@export var controls_help: Control

func _ready() -> void:
    controls_help.hide()


func set_show_controls_help(is_showing: bool) -> void:
    controls_help.visible = is_showing

func is_showing_controls_help() -> bool:
    return controls_help.visible
