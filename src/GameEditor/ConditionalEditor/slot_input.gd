extends Control

const SlotSelectorButton = preload("res://src/GameEditor/SlotSelectorButton.gd")

@export var slot_button: SlotSelectorButton = null
var arg_name: String = ""

func _ready():
	var slot_id: int = slot_button.get_first_valid_slot_id()
	if slot_id != -1:
		slot_button.set_current_slot(slot_id)

func set_input_args(new_args: Array) -> void:
	if not new_args:
		return
	if new_args.size() > 1 and "none" in new_args:
		slot_button.show_none_option = true
		new_args.erase("none")
	slot_button.set_valid_slot_categories(new_args)

func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name

func get_arg_name() -> String:
	return arg_name

func get_value() -> int:
	return slot_button.get_current_slot()

func set_value(new_val) -> void:
	slot_button.set_current_slot(new_val)
