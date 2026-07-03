extends Control

signal value_changed(new_value: Variant)
signal value_type_changed(new_native_type: int)
signal input_focus_out()
signal input_focus_in()
signal conditional_editor_requested()

const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")
const AdaptableMultiLineEdit = preload("res://Scenes/GameEditor/adaptable_multi_line_edit.gd")

@export var show_type_picker: bool = true
@export var type_picker: OptionButton

@export var text_input: AdaptableMultiLineEdit
@export var bool_input: Control
@export var number_input: ScalarValueInput
@export var edit_conditional_button: Button

@export var lowest_step_size: float = 0.00001
@export var allow_negative: bool = true
@export var max_number_value: float = 10000000.0

@export_flags("Txt", "T/F", "Num", "?") var enabled_types: int = 1 | 2 | 4

const type_picker_items: Dictionary = {
    1: {"short_name": "Txt", "description": "Text"},
    2: {"short_name": "T/F", "description": "True or False"},
    4: {"short_name": "Num", "description": "Number"},
    8: {"short_name": "?", "description": "Conditional"},
}

const NATIVE_TYPES: Dictionary[int, int] = {
    1: TYPE_STRING,
    2: TYPE_BOOL,
    4: TYPE_INT,
    8: TYPE_DICTIONARY,
}

var current_type_id: int = 0
var current_value: Variant = null

var _last_conditional_value: Variant = {}

func _ready() -> void:
    if not show_type_picker:
        change_type_picker_visibility(false)
    else:
        refresh_type_picker_focus_neighbors()
    number_input.set_step_and_arrow_step(lowest_step_size, 1)
    _setup_type_picker(enabled_types)
    if type_picker.item_count < 1:
        push_error("No types enabled for multi-type input")
        EngineDebugger.debug()
        return
    on_type_selected(0, false)
    type_picker.item_selected.connect(on_type_selected)
    
    type_picker.pressed.connect(input_focus_in.emit)
    
    number_input.max_value = max_number_value
    number_input.min_value = -max_number_value if allow_negative else 0.0
    number_input.update_input_settings()
    number_input.focus_out.connect(on_number_input_focus_out)
    number_input.focus_entered.connect(input_focus_in.emit)
    
    text_input.multi_line_text_changed.connect(on_value_edited)
    bool_input.value_changed.connect(on_value_edited)
    number_input.value_changed.connect(on_value_edited)
    
    text_input.multi_line_editing_toggled.connect(on_text_editing_toggled)
    text_input.focus_entered.connect(input_focus_in.emit)
    
    edit_conditional_button.pressed.connect(conditional_editor_requested.emit)
    var conditional_enabled: bool = enabled_types & 8 != 0
    edit_conditional_button.disabled = not conditional_enabled
    

func change_type_picker_visibility(new_visible: bool) -> void:
    type_picker.visible = new_visible
    refresh_type_picker_focus_neighbors()

func set_enable_conditional(new_enable: bool) -> void:
    if new_enable:
        enabled_types |= 8
    else:
        enabled_types &= ~8
    edit_conditional_button.disabled = not new_enable
    _setup_type_picker(enabled_types)
    Utility.opbtn_select_id(type_picker, current_type_id)

func on_value_edited(new_value: Variant) -> void:
    current_value = new_value
    value_changed.emit(new_value)

func _setup_type_picker(with_enabled_types: int) -> void:
    type_picker.clear()
    var index: int = 0
    for type_id in type_picker_items:
        if with_enabled_types & type_id:
            type_picker.add_item(type_picker_items[type_id]["short_name"], type_id)
            type_picker.set_item_tooltip(index, type_picker_items[type_id]["description"])
            index += 1

func set_value(new_value: Variant) -> void:
    var new_type_id: int = 1
    if not is_node_ready():
        push_error("Setting multi-type input value before ready")
        return
    if typeof(new_value) in [TYPE_ARRAY, TYPE_DICTIONARY]:
        current_value = new_value.duplicate_deep()
        _last_conditional_value = new_value.duplicate_deep()
        new_type_id = 8
    elif typeof(new_value) == TYPE_BOOL:
        current_value = new_value
        new_type_id = 2
    elif typeof(new_value) in [TYPE_INT, TYPE_FLOAT]:
        current_value = new_value
        new_type_id = 4
    else:
        current_value = str(new_value)
        new_type_id = 1
    if current_type_id != new_type_id:
        pick_type_id(new_type_id)
    set_input_value_from_current_value()
    show_input_for_current_type()

func get_value() -> Variant:
    return current_value

# temporarily adds the type as a disabled item if we ended up with a type that is dissalowed
func pick_type_id(type_id: int) -> void:
    if type_id == current_type_id or not type_id in NATIVE_TYPES:
        return
    current_type_id = type_id
    _setup_type_picker(enabled_types | type_id)
    for i in type_picker.item_count:
        if type_picker.get_item_id(i) == type_id:
            type_picker.select(i)
            if enabled_types & type_id == 0:
                type_picker.set_item_disabled(i, true)
    value_type_changed.emit(NATIVE_TYPES[type_id])
    refresh_focus_neighbors_on_type_change()

func set_type_from_gd_type(new_type: int) -> void:
    var my_type: int = 0
    if new_type == TYPE_STRING:
        my_type = 1
    elif new_type == TYPE_BOOL:
        my_type = 2
    elif new_type == TYPE_INT or new_type == TYPE_FLOAT:
        my_type = 4
    elif new_type == TYPE_DICTIONARY or new_type == TYPE_ARRAY:
        my_type = 8
    else:
        my_type = 1
        push_warning("Unhandled native type for multi-type input: %s" % type_string(new_type))
    var type_index: int = Utility.opbtn_get_index_from_id(type_picker, my_type)
    on_type_selected(type_index, false, false)

func on_type_selected(index: int, allow_grabbing_focus: bool = true, do_emit: bool = true) -> void:
    var type_id: int = type_picker.get_item_id(index)
    var emit_changed: bool = false
    if type_id != current_type_id:
        emit_changed = current_type_id != 0
        convert_value(current_type_id, type_id)
    current_type_id = type_id
    set_input_value_from_current_value()
    show_input_for_current_type()
    if allow_grabbing_focus:
        try_grab_focus()

    if emit_changed:
        if do_emit:
            value_type_changed.emit(typeof(current_value))
            value_changed.emit(current_value)
        refresh_focus_neighbors_on_type_change()
    if show_type_picker != type_picker.visible:
        type_picker.visible = show_type_picker

func try_grab_focus() -> void:
    if current_type_id == 1:
        text_input.grab_focus_and_edit.call_deferred()
    elif current_type_id == 2:
        bool_input.button_grab_focus.call_deferred()
    elif current_type_id == 4:
        number_input.line_edit_grab_focus.call_deferred()
    elif current_type_id == 8:
        edit_conditional_button.grab_focus.call_deferred()

func convert_value(from_type_id: int, to_type_id: int) -> void:
    if from_type_id == 0:
        _set_default_value(to_type_id)
        return
    if to_type_id == 8:
        current_value = _last_conditional_value.duplicate_deep()
        return
    if from_type_id == 8:
        _last_conditional_value = current_value.duplicate_deep()
        _set_default_value(to_type_id)
        return
    
    if to_type_id == 1:
        current_value = str(current_value)
        if from_type_id == 4:
            current_value = current_value.trim_suffix(".0")
        return
    if from_type_id == 1:
        if to_type_id == 2:
            if current_value.to_lower() in ["false", "0", "0.0"]:
                current_value = false
            else:
                current_value = true
        elif to_type_id == 4:
            if not current_value.is_valid_float():
                current_value = int(1) if current_value.to_lower() == "true" else int(0)
            else:
                current_value = float(current_value)
                if Utility.is_float_integer(current_value):
                    current_value = int(current_value)
        return
    
    if to_type_id == 2 and from_type_id == 4:
        current_value = true if current_value != 0 else false
    elif to_type_id == 4 and from_type_id == 2:
        current_value = int(1) if current_value else int(0)

func _set_default_value(for_type_id: int) -> void:
    match for_type_id:
        1:
            current_value = ""
        2:
            current_value = true
        4:
            current_value = int(1)
        8:
            current_value = {}

func set_input_value_from_current_value() -> void:
    match current_type_id:
        1:
            text_input.set_text_contents(current_value as String)
        2:
            bool_input.set_value(current_value as bool)
        4:
            if typeof(current_value) == TYPE_FLOAT and not Utility.is_float_integer(current_value):
                current_value = snappedf(current_value, lowest_step_size)
                if not "." in str(current_value) or is_nan(current_value):
                    current_value = 0.1
                var num_decimal_places: int = maxi(0, len(str(current_value).split(".")[1]))
                number_input.set_step_and_arrow_step(lowest_step_size, pow(10, -num_decimal_places))
            else:
                number_input.set_step_and_arrow_step(1, 1)
            number_input.set_value(current_value)

func show_input_for_current_type() -> void:
    text_input.visible = current_type_id == 1
    bool_input.visible = current_type_id == 2
    number_input.visible = current_type_id == 4
    edit_conditional_button.visible = current_type_id == 8

func on_text_editing_toggled(is_editing: bool) -> void:
    if not is_editing and current_type_id == 1:
        input_focus_out.emit()

func on_number_input_focus_out() -> void:
    if current_type_id == 4:
        input_focus_out.emit()


func _focusable_controls() -> Array[Control]:
    return [type_picker, text_input, number_input.value_input, edit_conditional_button]

func _get_current_last_focusable_control() -> Control:
    return _get_current_first_focusable_control(true)

func _get_current_first_focusable_control(get_last: bool = false) -> Control:
    if current_type_id == 1:
        return text_input
    elif current_type_id == 2:
        return bool_input.false_button if get_last else bool_input.true_button
    elif current_type_id == 4:
        return number_input.value_input
    elif current_type_id == 8:
        return edit_conditional_button
    return null

func unset_all_up_down_focus_neighbors() -> void:
    for focusable_control in _focusable_controls():
        focusable_control.focus_neighbor_top = ^""
        focusable_control.focus_neighbor_bottom = ^""
    bool_input.unset_all_up_down_focus_neighbors()

func set_focus_up_and_down(up: NodePath, down: NodePath) -> void:
    for focusable_control in _focusable_controls():
        if up:
            focusable_control.set_focus_neighbor(SIDE_TOP, up)
        if down:
            focusable_control.set_focus_neighbor(SIDE_BOTTOM, down)
    bool_input.set_focus_up_and_down(up, down)

func set_focus_left_and_right(left: NodePath, right: NodePath) -> void:
    focus_neighbor_left = left
    focus_neighbor_right = right
    refresh_left_right_focus_neighbors()

    
# Also refreshes all focus neighbors, mainly to ensure type picker becoming visible has the correct next focus
func refresh_type_picker_focus_neighbors() -> void:
    var focus_to: NodePath = ^""
    for focusable_control in _focusable_controls() + [bool_input.true_button]:
        if type_picker.visible:
            focus_to = focusable_control.get_path_to(type_picker)
        focusable_control.set_focus_neighbor(SIDE_LEFT, focus_to)
        focusable_control.focus_previous = focus_to
    refresh_focus_neighbors_on_type_change()

func refresh_focus_neighbors_on_type_change() -> void:
    refresh_left_right_focus_neighbors()
    refresh_focus_from_type_picker()

func refresh_focus_from_type_picker() -> void:
    if not type_picker.visible:
        return
    var first_focusable_control: = _get_current_first_focusable_control()
    if first_focusable_control:
        var focus_to: NodePath = type_picker.get_path_to(first_focusable_control)
        type_picker.set_focus_neighbor(SIDE_RIGHT, focus_to)
        type_picker.focus_next = focus_to

func refresh_left_right_focus_neighbors() -> void:
    var set_prev_focus_on: Control = type_picker
    if not type_picker.visible:
        set_prev_focus_on = _get_current_first_focusable_control()
    if set_prev_focus_on:
        set_prev_focus_on.set_focus_neighbor(SIDE_LEFT, focus_neighbor_left)
        set_prev_focus_on.focus_previous = focus_neighbor_left

    var set_next_focus_on: Control = _get_current_last_focusable_control()
    if set_next_focus_on:
        set_next_focus_on.set_focus_neighbor(SIDE_RIGHT, focus_neighbor_right)
        set_next_focus_on.focus_next = focus_neighbor_right