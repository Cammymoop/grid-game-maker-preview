extends Control

const SlotSelectorButton = preload("res://src/GameEditor/SlotSelectorButton.gd")
const MultiTypeInput = preload("res://Scenes/GameEditor/multi_type_input.gd")

@export var slot_selector: SlotSelectorButton
@export var multi_type_input: MultiTypeInput

var arg_name: String = ""

var VALUE_SLOTS: Array[int] = [
    SlotSelectorButton.TEXT_VALUE,
    SlotSelectorButton.BOOL_VALUE,
    SlotSelectorButton.NUMBER_VALUE,
]

func _ready() -> void:
	slot_selector.slot_changed.connect(on_slot_changed)
	refresh_ui()

func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name

func get_arg_name() -> String:
	return arg_name

func get_value() -> Dictionary:
	var current_slot_id: int = slot_selector.get_current_slot()
	if current_slot_id in VALUE_SLOTS:
		return {
			"type": "plain",
			"slot_id": current_slot_id,
			"value": multi_type_input.get_value()
		}
	else:
		return {
			"type": "slot_value",
			"slot_id": current_slot_id
		}

func set_value(new_val_complex: Dictionary) -> void:
	slot_selector.set_current_slot(int(new_val_complex["slot_id"]))
	if new_val_complex["type"] == "plain":
		var plain_val: Variant = new_val_complex["value"]
		if typeof(plain_val) in [TYPE_ARRAY, TYPE_DICTIONARY]:
			plain_val = false
		multi_type_input.set_value(plain_val)
	else:
		multi_type_input.set_value(true)
	refresh_ui()

func on_slot_changed(new_slot_id: int) -> void:
	if new_slot_id in VALUE_SLOTS:
		multi_type_input.set_type_from_gd_type(slot_selector.get_value_gd_type())
	refresh_ui()

func refresh_ui() -> void:
	var current_slot_id: int = slot_selector.get_current_slot()
	multi_type_input.visible = current_slot_id in VALUE_SLOTS

		
