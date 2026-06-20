extends HBoxContainer

signal plain_value_changed(value: float)

const SlotSelectorButton = preload("res://src/GameEditor/SlotSelectorButton.gd")
const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

@export var slot_selector: SlotSelectorButton
@export var plain_value_input: ScalarValueInput

@export var is_int_only: bool = false
@export var plain_value_min: float = -100
@export var plain_value_max: float = 100
@export var plain_value_step: float = 1

@export var default_slot_id: int = SlotSelectorButton.NUMBER_VALUE
@export var default_plain_value: float = 0.0

var arg_name: String = ""
var current_slot_id: int = SlotSelectorButton.NUMBER_VALUE

func _ready():
    slot_selector.set_valid_slot_categories(["int", "float"])
    slot_selector.set_current_slot(default_slot_id, false)
    slot_selector.slot_changed.connect(on_slot_changed)
    
    plain_value_input.value_changed.connect(on_plain_value_changed)
    if is_int_only:
        _update_int_only()
    refresh_ui()

func _update_int_only() -> void:
    plain_value_input.is_int_type = true
    plain_value_input.update_input_settings()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func set_input_args(new_args: Array) -> void:
    if not new_args:
        return
    if "int" in new_args:
        is_int_only = true
        _update_int_only()
    for arg in new_args:
        if arg.begins_with("default="):
            set_value({"type": "plain", "value": float(arg.split("=")[1])})
        elif arg.begins_with("step="):
            plain_value_step = float(arg.split("=")[1])
            plain_value_input.custom_step = true
    refresh_ui()

func get_value() -> Dictionary:
    if current_slot_id == SlotSelectorButton.NUMBER_VALUE:
        return {"type": "plain", "value": plain_value_input.get_value()}
    elif current_slot_id >= 0:
        return {"type": "slot_value", "slot_id": current_slot_id}
    else:
        push_error("Invalid complex scalar slot id: %s" % [current_slot_id])
        return {"type": "plain", "value": 0}

func set_value(new_val: Variant) -> void:
    # load old conditionals that used generic string inputs
    if typeof(new_val) == TYPE_STRING and new_val.is_valid_float():
        new_val = {"type": "plain", "value": float(new_val)}

    if new_val["type"] == "plain":
        plain_value_input.set_value(new_val["value"])
    elif new_val["type"] == "slot_value":
        current_slot_id = new_val["slot_id"]
    else:
        push_error("Invalid complex scalar value type: %s" % [new_val["type"]])
        current_slot_id = SlotSelectorButton.NUMBER_VALUE
        plain_value_input.set_value(0)
    refresh_ui()

func on_slot_changed(new_slot_id: int) -> void:
    current_slot_id = new_slot_id
    refresh_ui()

func on_plain_value_changed(new_value: float) -> void:
    plain_value_changed.emit(new_value)

func refresh_ui() -> void:
    plain_value_input.custom_step = true
    plain_value_input.custom_step_value = plain_value_step
    plain_value_input.min_value = plain_value_min
    plain_value_input.max_value = plain_value_max
    plain_value_input.is_int_type = is_int_only
    plain_value_input.update_input_settings()

    if current_slot_id == SlotSelectorButton.NUMBER_VALUE:
        plain_value_input.visible = true
    else:
        plain_value_input.visible = false
    
    slot_selector.set_current_slot(current_slot_id, false)