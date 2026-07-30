extends Control

signal value_changed(value: float)
signal focus_out()

@export var value_input: SpinBox
@export var is_int_type: bool = false

@export var default_value: float = 0.0

@export var min_value: float = 0.0
@export var max_value: float = 100.0

@export var custom_step: bool = false
@export var custom_step_value: float = 1.0

@export var auto_double_focus: bool = true

@export var is_expand_to_text: bool = true

@export var update_precision_on_text_input: bool = true

var smallest_step: float = 0.00001

var arg_name: String = ""
var _value_set: bool = false

var _double_focus: bool = false

var _ignore_value_changed: bool = false

func _ready() -> void:
    if not _value_set:
        value_input.set_value_no_signal(default_value)
    value_input.value_changed.connect(on_value_changed)
    update_input_settings()
    value_input.get_line_edit().gui_input.connect(on_line_edit_gui_input)
    
    value_input.get_line_edit().editing_toggled.connect(on_input_text_editing_change)
    
    value_input.tooltip_text = tooltip_text
    
    value_input.focus_exited.connect(on_value_input_focus_out)

func set_tooltip(new_tooltip: String) -> void:
    value_input.tooltip_text = new_tooltip

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

func line_edit_grab_focus(double_focus: bool = true) -> void:
    value_input.get_line_edit().grab_focus()
    if double_focus and value_input.get_line_edit().has_focus():
        enable_double_focus()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func get_value() -> Variant:
    if is_int_type:
        return int(value_input.value)
    else:
        return value_input.value

func set_value(new_val: Variant) -> void:
    _value_set = true
    value_input.set_value_no_signal(float(new_val))

func on_value_changed(new_value: float) -> void:
    if _ignore_value_changed:
        return
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

func enable_double_focus() -> void:
    _double_focus = true

func disable_double_focus() -> void:
    _double_focus = false

func is_double_focus() -> bool:
    if not value_input.get_line_edit().has_focus():
        return false
    if auto_double_focus and value_input.get_line_edit().is_editing():
        return true
    return _double_focus

func on_line_edit_gui_input(event: InputEvent) -> void:
    if Utility.fixed_just_pressed_by_event("ui_accept", event):
        if _double_focus:
            disable_double_focus()
        else:
            enable_double_focus()
        return
    
    # Because movement keys include wasd, make sure we dont capture shortcuts like ctrl+s to save
    if Utility.fixed_just_pressed_by_event("save_file_shortcut", event):
        return
    if Utility.fixed_just_pressed_by_event("save_file_as_shortcut", event):
        return

    var up_down: int = 0
    if event.is_action_pressed("value_increase"):
        up_down = 1
    elif event.is_action_pressed("value_decrease"):
        up_down = -1
    if is_double_focus():
        if event.is_action_pressed("move_up"):
            up_down = 1
        elif event.is_action_pressed("move_down"):
            up_down = -1

    if up_down != 0:
        accept_event()
        var step_amt: float = value_input.step if value_input.custom_arrow_step == 0 else value_input.custom_arrow_step
        if step_amt == 0:
            step_amt = 1
        value_input.set_value_no_signal(value_input.value + up_down * step_amt)
        value_input.get_line_edit().text = str(value_input.value)
        value_changed.emit(value_input.value)
    elif Utility.event_is_menu_back_just_pressed(event):
        disable_double_focus()
        accept_event()
        if value_input.get_line_edit().is_editing():
            value_input.get_line_edit().unedit()
        focus_out.emit()

func on_value_input_focus_out() -> void:
    disable_double_focus()


func on_input_text_editing_change(is_editing: bool) -> void:
    if not is_editing:
        on_input_text_done_editing()

func on_input_text_done_editing() -> void:
    if not update_precision_on_text_input:
        return
    var text_val: String = value_input.get_line_edit().text.strip_edges()
    if text_val.is_valid_float() and not text_val.contains("e"):
        if _set_input_precision_from_trailing_zeros(text_val):
            return
        _set_input_precision_from_float(float(text_val))
        return
    _ignore_value_changed = true
    # Allow the SPinBox code to process the expression with the smallest possible step and update the value
    # then choose an appropriate step based on the result
    change_precision(smallest_step)
    value_input.apply()
    _ignore_value_changed = false
    _set_input_precision_from_float(value_input.value)

func _set_input_precision_from_float(float_val: float) -> void:
    var inferred_step: float = Utility.get_float_step_from_float(float_val, smallest_step)
    change_precision(inferred_step)

func _set_input_precision_from_trailing_zeros(text_val: String) -> bool:
    var trailing_zeros: int = Utility.count_trailing_digits_with_zeros(text_val)
    if trailing_zeros == 0:
        return false
    change_precision(maxf(pow(10, -trailing_zeros), smallest_step))
    return true

func change_precision(new_step: float, base_step: float = 0) -> void:
    if not base_step:
        base_step = new_step
    set_step_and_arrow_step(base_step, new_step)