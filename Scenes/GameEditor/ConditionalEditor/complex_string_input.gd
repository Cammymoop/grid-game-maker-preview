extends HBoxContainer

signal plain_value_changed(value: String)

const SlotSelectorButton = preload("res://src/GameEditor/SlotSelectorButton.gd")

@export var slot_selector: SlotSelectorButton
@export var plain_value_input: LineEdit

var arg_name: String = ""
var current_slot_id: int = SlotSelectorButton.TEXT_VALUE


func _ready():
    slot_selector.set_valid_slot_categories(["string"])
    slot_selector.set_current_slot(current_slot_id)
    slot_selector.slot_changed.connect(on_slot_changed)
    
    plain_value_input.text_changed.connect(on_plain_value_changed)
    refresh_ui()

func set_arg_name(new_arg_name: String) -> void:
    arg_name = new_arg_name

func get_arg_name() -> String:
    return arg_name

func get_value() -> Dictionary:
    if current_slot_id == SlotSelectorButton.TEXT_VALUE:
        return {"type": "plain", "value": plain_value_input.text}
    elif current_slot_id >= 0:
        return {"type": "slot_value", "slot_id": current_slot_id}
    else:
        push_error("Invalid complex string slot id: %s" % [current_slot_id])
        return {"type": "plain", "value": ""}

func set_value(new_val: Variant) -> void:
    if not typeof(new_val) == TYPE_DICTIONARY:
        push_error("Invalid complex string value type: %s" % [typeof(new_val)])

    if new_val["type"] == "plain":
        set_plain_value(new_val["value"])
    elif new_val["type"] == "slot_value":
        current_slot_id = new_val["slot_id"]
        refresh_ui()
    else:
        push_error("Invalid complex string value type: %s" % [new_val["type"]])
        set_plain_value("")

func set_plain_value(new_value: String) -> void:
    current_slot_id = SlotSelectorButton.TEXT_VALUE
    slot_selector.set_current_slot(current_slot_id)
    plain_value_input.text = new_value
    refresh_ui()

func on_slot_changed(new_slot_id: int) -> void:
    current_slot_id = new_slot_id
    refresh_ui()

func on_plain_value_changed(new_value: String) -> void:
    plain_value_changed.emit(new_value)

func refresh_ui() -> void:
    plain_value_input.visible = current_slot_id == SlotSelectorButton.TEXT_VALUE