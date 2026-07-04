extends HBoxContainer

const DirectionInput = preload("res://src/GameEditor/ConditionalEditor/DirectionInput.gd")

@export var selector_for_is_default: OptionButton
@export var direction_input: DirectionInput

var arg_name: String = ""
var default_as_default: bool = true

func _ready() -> void:
    selector_for_is_default.item_selected.connect(def_changed)
    if default_as_default:
        selector_for_is_default.selected = 0
    else:
        selector_for_is_default.selected = 1
    refresh_ui()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func set_input_args(new_args: Array) -> void:
    if not new_args:
        return
    
    for arg in new_args:
        if arg.contains("default="):
            var default_value: String = (arg.split("=", true, 1)[1]).strip_edges().to_lower()
            if default_value != "false" and not (default_value.is_valid_float() and float(default_value) == 0):
                default_as_default = true
            else:
                default_as_default = false


func get_value() -> Dictionary:
    return {
        "is_default": is_default_direction(),
        "direction": direction_input.get_value(),
    }

func is_default_direction() -> bool:
    return selector_for_is_default.selected == 0

func set_value(new_val: Dictionary) -> void:
    if new_val.get("is_default", false):
        selector_for_is_default.selected = 0
    else:
        selector_for_is_default.selected = 1
        direction_input.set_value(new_val.get("direction", {}))
    refresh_ui()

func refresh_ui() -> void:
    direction_input.visible = not is_default_direction()

func def_changed(_index: int) -> void:
    refresh_ui()