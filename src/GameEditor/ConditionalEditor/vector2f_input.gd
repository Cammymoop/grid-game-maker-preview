extends Control

signal value_changed(value: Vector2)

var smallest_step: float = 0.00001

@export var label_is_w_h: bool = false
@export var starting_value: Vector2 = Vector2(0, 0)
@export var starting_step: Vector2 = Vector2(0.1, 0.1)

@export var x_label: Label
@export var x_input: SpinBox
@export var y_label: Label
@export var y_input: SpinBox

@export var text_with_trailing_zeros_sets_precision: bool = true

var arg_name: String = ""

var _ignore_value_changed: bool = false

func _ready():
    if label_is_w_h:
        x_label.text = "W"
        y_label.text = "H"
    set_value(starting_value)
    x_input.value_changed.connect(on_input_changed.unbind(1))
    y_input.value_changed.connect(on_input_changed.unbind(1))
    
    var x_line_edit: LineEdit = x_input.get_line_edit()
    x_line_edit.editing_toggled.connect(on_input_text_editing_change.bind(x_input))
    #x_line_edit.expand_to_text_length = true
    var y_line_edit: LineEdit = y_input.get_line_edit()
    y_line_edit.editing_toggled.connect(on_input_text_editing_change.bind(y_input))
    #y_line_edit.expand_to_text_length = true

func _apply_starting() -> void:
    set_value(starting_value)
    change_precision_of_input(x_input, starting_step.x)
    change_precision_of_input(y_input, starting_step.y)

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func set_input_args(new_args: Array) -> void:
    if new_args.size() < 1:
        return
    if typeof(new_args[0]) in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I]:
        set_args_starting_value(Vector2(new_args[0].x, new_args[0].y))
    else:
        var new_starting_val: = Vector2.ZERO
        var x_val: float = Utility.any_to_float(new_args[0])
        new_starting_val.x = x_val
        if new_args.size() < 2:
            new_starting_val.y = x_val
        else:
            new_starting_val.y = Utility.any_to_float(new_args[1])
        set_args_starting_value(new_starting_val)

    if is_inside_tree():
        set_value(starting_value)

func set_args_starting_value(new_starting_val: Vector2) -> void:
    starting_value = new_starting_val
    var input_arg_inferred_step: = Vector2.ZERO
    input_arg_inferred_step.x = Utility.get_float_step_from_float(starting_value.x, starting_step.x)
    input_arg_inferred_step.y = Utility.get_float_step_from_float(starting_value.y, starting_step.y)
    starting_step = starting_step.min(input_arg_inferred_step)
    

func get_arg_name() -> String:
    return arg_name

func get_value() -> Vector2:
    return Vector2(x_input.value, y_input.value)

func set_value(new_val: Vector2) -> void:
    change_precision_of_input(x_input, smallest_step)
    change_precision_of_input(y_input, smallest_step)
    x_input.set_value_no_signal(new_val.x)
    y_input.set_value_no_signal(new_val.y)
    _set_input_precision_from_float(x_input, new_val.x)
    _set_input_precision_from_float(y_input, new_val.y)

func on_input_changed() -> void:
    if _ignore_value_changed:
        return
    value_changed.emit(get_value())


func on_input_text_editing_change(is_editing: bool, the_input: SpinBox) -> void:
    if not is_editing:
        on_input_text_done_editing(the_input)
    else:
        # When editing the text use the smallest step to keep the SpinBox from messing with it much
        #prints("setting small precision for %s because editing text" % [the_input.name])
        pass#change_precision_of_input(the_input, smallest_step)

func on_input_text_done_editing(the_input: SpinBox) -> void:
    var text_val: String = the_input.get_line_edit().text.strip_edges()
    if text_val.is_valid_float() and not text_val.contains("e"):
        if text_with_trailing_zeros_sets_precision:
            if _set_input_precision_from_trailing_zeros(the_input, text_val):
                return
        _set_input_precision_from_float(the_input, float(text_val))
        return
    _ignore_value_changed = true
    # Allow the SPinBox code to process the expression with the smallest possible step and update the value
    # then choose an appropriate step based on the result
    change_precision_of_input(the_input, smallest_step)
    the_input.apply()
    _ignore_value_changed = false
    _set_input_precision_from_float(the_input, the_input.value)

func _set_input_precision_from_float(the_input: SpinBox, float_val: float) -> void:
    var inferred_step: float = Utility.get_float_step_from_float(float_val, smallest_step)
    change_precision_of_input(the_input, inferred_step)

func _set_input_precision_from_trailing_zeros(the_input: SpinBox, text_val: String) -> bool:
    var trailing_zeros: int = Utility.count_trailing_digits_with_zeros(text_val)
    if trailing_zeros == 0:
        return false
    change_precision_of_input(the_input, maxf(pow(10, -trailing_zeros), smallest_step))
    return true

func change_precision_of_input(the_input: SpinBox, new_step: float) -> void:
    the_input.rounded = new_step == 1
    the_input.step = new_step
    the_input.custom_arrow_step = new_step