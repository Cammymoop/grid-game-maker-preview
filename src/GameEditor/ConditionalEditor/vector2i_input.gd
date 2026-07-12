extends Control

signal value_changed(value: Vector2i)

@export var starting_value: Vector2i = Vector2i(0, 0)

@export var x_input: Range
@export var y_input: Range

var arg_name: String = ""

var _set_value: = false

func _ready():
    if not _set_value:
        set_value(starting_value)
    x_input.value_changed.connect(on_input_changed.unbind(1))
    y_input.value_changed.connect(on_input_changed.unbind(1))

func set_tooltip(new_tooltip_text: String) -> void:
    tooltip_text = new_tooltip_text
    x_input.tooltip_text = new_tooltip_text
    y_input.tooltip_text = new_tooltip_text

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func set_input_args(new_args: Array) -> void:
    if new_args.size() < 1:
        return
    if typeof(new_args[0]) in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I]:
        starting_value = Vector2i(new_args[0].x, new_args[0].y)
        if is_inside_tree():
            set_value(starting_value)
        return

    var x_val: int = Utility.any_to_int(new_args[0])
    starting_value.x = x_val
    if new_args.size() < 2:
        starting_value.y = x_val
    else:
        starting_value.y = Utility.any_to_int(new_args[1])
    if is_inside_tree():
        set_value(starting_value)
    

func get_arg_name() -> String:
    return arg_name

func get_value() -> Vector2i:
    return Vector2i(x_input.value, y_input.value)

func set_value(new_val: Vector2i) -> void:
    _set_value = true
    x_input.set_value_no_signal(new_val.x)
    y_input.set_value_no_signal(new_val.y)

func on_input_changed() -> void:
    value_changed.emit(get_value())