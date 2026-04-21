extends HBoxContainer

signal plain_value_changed(value: Variant)

const SlotSelectorButton = preload("res://src/GameEditor/SlotSelectorButton.gd")
const MultiTypeInput = preload("res://Scenes/GameEditor/multi_type_input.gd")

@export var slot_selector: SlotSelectorButton
@export var plain_multi_type_input: MultiTypeInput
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_NIL_IS_VARIANT) var default_value: Variant = true

var plain_value_as_string: bool = false

var arg_name: String = ""
var current_slot_id: int = SlotSelectorButton.TEXT_VALUE

var VALUE_SLOTS: Array = [SlotSelectorButton.TEXT_VALUE, SlotSelectorButton.BOOL_VALUE, SlotSelectorButton.NUMBER_VALUE]

var _value_set: bool = false

func _ready():
    slot_selector.set_valid_slot_categories(["string","number","bool"])
    slot_selector.set_current_slot(current_slot_id)
    slot_selector.slot_changed.connect(on_slot_changed)
    
    plain_multi_type_input.value_type_changed.connect(on_plain_value_type_changed)
    plain_multi_type_input.value_changed.connect(on_plain_value_changed)
    
    if not _value_set:
        set_value({"type": "plain", "value": default_value})
    
    refresh_ui()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func set_input_args(new_args: Array) -> void:
    if not "compat" in new_args:
        plain_value_as_string = false
    else:
        plain_value_as_string = true

func get_value() -> Variant:
    if is_plain_value():
        if plain_value_as_string:
            return Utility.property_value_to_string(plain_multi_type_input.get_value())
        return {"type": "plain", "value": plain_multi_type_input.get_value()}
    else:
        return {"type": "slot_value", "slot_id": current_slot_id}

func set_value(new_val: Variant) -> void:
    _value_set = true
    if typeof(new_val) == TYPE_STRING:
        set_plain_value(Utility.property_value_from_string(new_val))
        return
    if not typeof(new_val) == TYPE_DICTIONARY:
        push_error("Invalid complex prop value type: %s" % [typeof(new_val)])
    
    if new_val["type"] == "plain":
        set_plain_value(new_val["value"])
    elif new_val["type"] == "slot_value":
        _set_slot(new_val["slot_id"])
        refresh_ui()
    else:
        push_error("Unknown complex prop value 'type': %s" % [new_val["type"]])
        set_plain_value(0)

func _set_slot(new_slot_id: int) -> void:
    current_slot_id = new_slot_id
    slot_selector.set_current_slot(current_slot_id)

func set_plain_value(new_value: Variant) -> void:
    _value_set = true
    if typeof(new_value) == TYPE_STRING:
        set_string_value(new_value)
    elif typeof(new_value) == TYPE_BOOL:
        set_bool_value(new_value)
    elif typeof(new_value) in [TYPE_INT, TYPE_FLOAT]:
        set_number_value(new_value)
    else:
        push_warning("Invalid plain value native type: %s" % [type_string(typeof(new_value))])

func set_string_value(new_value: String) -> void:
    _set_slot(SlotSelectorButton.TEXT_VALUE)
    plain_multi_type_input.set_value(new_value)
    refresh_ui()

func set_bool_value(new_value: bool) -> void:
    _set_slot(SlotSelectorButton.BOOL_VALUE)
    plain_multi_type_input.set_value(new_value)
    refresh_ui()

func set_number_value(new_value: float) -> void:
    _set_slot(SlotSelectorButton.NUMBER_VALUE)
    plain_multi_type_input.set_value(new_value)
    refresh_ui()

func on_slot_changed(new_slot_id: int) -> void:
    current_slot_id = new_slot_id
    change_multi_type_input_type()
    refresh_ui()

func change_multi_type_input_type() -> void:
    if current_slot_id == SlotSelectorButton.BOOL_VALUE:
        plain_multi_type_input.set_type_from_gd_type(TYPE_BOOL)
    elif current_slot_id == SlotSelectorButton.TEXT_VALUE:
        plain_multi_type_input.set_type_from_gd_type(TYPE_STRING)
    elif current_slot_id == SlotSelectorButton.NUMBER_VALUE:
        plain_multi_type_input.set_type_from_gd_type(TYPE_INT)

func on_plain_value_changed(new_value: Variant) -> void:
    plain_value_changed.emit(new_value)

func on_plain_value_type_changed(new_type: int) -> void:
    set_slot_based_on_native_type(new_type)

func set_slot_based_on_native_type(new_type: int) -> void:
    if new_type == TYPE_STRING:
        _set_slot(SlotSelectorButton.TEXT_VALUE)
    elif new_type == TYPE_BOOL:
        _set_slot(SlotSelectorButton.BOOL_VALUE)
    elif new_type in [TYPE_INT, TYPE_FLOAT]:
        _set_slot(SlotSelectorButton.NUMBER_VALUE)
    else:
        push_warning("Invalid plain value native type: %s" % [type_string(new_type)])
    refresh_ui()

func is_plain_value() -> bool:
    return current_slot_id in VALUE_SLOTS

func refresh_ui() -> void:
    plain_multi_type_input.visible = is_plain_value()