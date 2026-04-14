extends Control

signal value_changed(new_value: Variant)

const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

@export var type_picker: OptionButton

@export var text_input: LineEdit
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

var current_type_id: int = 0
var current_value: Variant = null

var _last_conditional_value: Variant = {}

func _ready() -> void:
    number_input.set_step_and_arrow_step(lowest_step_size, 1)
    _setup_type_picker(enabled_types)
    if type_picker.item_count < 1:
        push_error("No types enabled for multi-type input")
        EngineDebugger.debug()
        return
    on_type_selected(0, false)
    type_picker.item_selected.connect(on_type_selected)
    
    number_input.max_value = max_number_value
    number_input.min_value = -max_number_value if allow_negative else 0.0
    number_input.update_input_settings()
    
    text_input.text_changed.connect(on_value_edited)
    bool_input.value_changed.connect(on_value_edited)
    number_input.value_changed.connect(on_value_edited)

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
    if not is_node_ready():
        push_error("Setting multi-type input value before ready")
        return
    if typeof(new_value) in [TYPE_ARRAY, TYPE_DICTIONARY]:
        current_value = new_value.duplicate_deep()
        _last_conditional_value = new_value.duplicate_deep()
        current_type_id = 8
    elif typeof(new_value) == TYPE_BOOL:
        current_value = new_value
        current_type_id = 2
    elif typeof(new_value) in [TYPE_INT, TYPE_FLOAT]:
        current_value = new_value
        current_type_id = 4
    else:
        current_value = str(new_value)
        current_type_id = 1
    pick_type_id(current_type_id)
    set_input_value_from_current_value()
    show_input_for_current_type()

func get_value() -> Variant:
    return current_value

# temporarily adds the type as a disabled item if we ended up with a type that is dissalowed
func pick_type_id(type_id: int) -> void:
    _setup_type_picker(enabled_types | type_id)
    for i in type_picker.item_count:
        if type_picker.get_item_id(i) == type_id:
            type_picker.select(i)
            if enabled_types & type_id == 0:
                type_picker.set_item_disabled(i, true)

func on_type_selected(index: int, allow_grabbing_focus: bool = true) -> void:
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
        value_changed.emit(current_value)

func try_grab_focus() -> void:
    if current_type_id == 1:
        text_input.grab_focus.call_deferred()
    elif current_type_id == 4:
        number_input.value_input.grab_focus.call_deferred()

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
            text_input.text = current_value as String
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
                number_input.set_step_and_arrow_step(lowest_step_size, 1)
            number_input.set_value(current_value)

func show_input_for_current_type() -> void:
    text_input.visible = current_type_id == 1
    bool_input.visible = current_type_id == 2
    number_input.visible = current_type_id == 4
    edit_conditional_button.visible = current_type_id == 8