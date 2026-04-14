extends Control

signal value_changed(value: float)

@export var value_input: SpinBox
@export var is_int_type: bool = false

@export var min_value: float = 0.0
@export var max_value: float = 100.0

@export var custom_step: bool = false
@export var custom_step_value: float = 1.0

@export var is_expand_to_text: bool = true

var arg_name: String = ""

func _ready() -> void:
    value_input.value_changed.connect(on_value_changed)
    update_input_settings()

func update_input_settings() -> void:
    value_input.min_value = min_value
    value_input.max_value = max_value

    if is_int_type:
        value_input.step = 1
        value_input.rounded = true
    else:
        value_input.step = 0.1
        value_input.rounded = false

    if custom_step:
        value_input.step = custom_step_value
    
    value_input.get_line_edit().expand_to_text_length = is_expand_to_text

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func get_value() -> Variant:
    if is_int_type:
        return int(value_input.value)
    else:
        return value_input.value

func set_value(new_val) -> void:
    value_input.value = float(new_val)

func on_value_changed(new_value: float) -> void:
    value_changed.emit(new_value)

func set_expand_to_text(expand_to_text: bool) -> void:
    value_input.get_line_edit().expand_to_text_length = expand_to_text

func set_step_and_arrow_step(new_step: float, new_arrow_step: float) -> void:
    custom_step = true
    custom_step_value = new_step
    value_input.step = custom_step_value
    value_input.custom_arrow_step = new_arrow_step
    value_input.custom_arrow_round = false
    is_expand_to_text = true
    set_expand_to_text(true)
    #value_input.step = 1.0
    #value_input.rounded = false