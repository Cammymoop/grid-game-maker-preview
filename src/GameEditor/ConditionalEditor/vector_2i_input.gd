extends Control

@export var starting_value: Vector2i = Vector2i(0, 0)

@export var x_input: Range
@export var y_input: Range

var arg_name: String = ""

func _ready():
    set_value(starting_value)

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func set_input_args(new_args: Array) -> void:
    prints("set vec input args: ", new_args)
    if new_args.size() < 1:
        return
    if typeof(new_args[0]) in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I]:
        starting_value = Vector2i(new_args[0].x, new_args[0].y)
        if is_inside_tree():
            set_value(starting_value)
        return

    var x_val: int = Utility.any_to_int(new_args[0])
    prints("x_val:", x_val)
    starting_value.x = x_val
    if new_args.size() < 2:
        prints("using x for y value")
        starting_value.y = x_val
    else:
        prints("y_val:", new_args[1])
        starting_value.y = Utility.any_to_int(new_args[1])
    if is_inside_tree():
        set_value(starting_value)
    

func get_arg_name() -> String:
    return arg_name

func get_value() -> Vector2i:
    return Vector2i(x_input.value, y_input.value)

func set_value(new_val: Vector2i) -> void:
    x_input.value = new_val.x
    y_input.value = new_val.y
