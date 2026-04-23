extends HBoxContainer

const DirectionInput = preload("res://src/GameEditor/ConditionalEditor/DirectionInput.gd")

@export var dir_input: DirectionInput
@export var exclude_mode_select: OptionButton


func _ready() -> void:
    exclude_mode_select.item_selected.connect(on_exclude_mode_selected)

func on_exclude_mode_selected(index: int) -> void:
    dir_input.visible = index != 0

func set_arg_name(new_arg_name: String) -> void:
    dir_input.set_arg_name(new_arg_name)

func get_arg_name() -> String:
    return dir_input.get_arg_name()

func get_value() -> Dictionary:
    if exclude_mode_select.selected == 0:
        return {"type": "ignore"}

    var dir_input_value: Dictionary = dir_input.get_value()
    dir_input_value["is_exclude"] = exclude_mode_select.selected == 1
    return dir_input_value

func set_value(new_value: Dictionary) -> void:
    if new_value.get("type", "") == "ignore":
        exclude_mode_select.selected = 0
        dir_input.visible = false
    else:
        dir_input.visible = true
        exclude_mode_select.selected = 1 if new_value.get("is_exclude", true) else 2
        new_value = new_value.duplicate()
        new_value.erase("is_exclude")
        dir_input.set_value(new_value)