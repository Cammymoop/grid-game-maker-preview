extends HBoxContainer

const RELATIVE_BIT = 4
const RELATIVE_MODE_BIT = 8
const SLOT_SHIFT = 4

const DIRECTION_ONLY = 3

@export var is_reference_position: bool = false

var is_absolute_mode: = true

var arg_name: String = ""

func _ready():
	$AbsoluteModeSelect.set_items(["Absolute", "Relative to"])
	$AbsoluteModeSelect.changed.connect(absolute_changed)
	$EntityRelativeMode.set_items(["Moving", "Facing"])
	
	$SlotSelectorButton.set_valid_slot_categories(["entity", "pos"])
	$SlotSelectorButton.slot_changed.connect(slot_changed)

func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name

func get_arg_name() -> String:
	return arg_name

func set_input_args(new_args: Array) -> void:
	if not new_args:
		return
	if new_args[0]:
		is_reference_position = true
	else:
		is_reference_position = false

# Return all the info about the selected direction and relativeness as a single int value
func get_value() -> Variant:
	if not is_reference_position:
		return get_int_value()
	else:
		return get_complex_value()

func get_int_value() -> int:
	var value: int = $DirectionSelectorButton.get_direction()
	return _relativify(value)

func get_complex_value() -> Dictionary:
	var value: int = $DirectionSelectorButton.get_direction()
	var slot_id: int = $DirectionSelectorButton.get_slot_id()
	if slot_id == -1:
		return {"type": "plain", "direction": value}
	else:
		return {"type": "slot_reference", "slot_id": slot_id, "direction": _relativify(0)}

func _relativify(plain_value: int) -> int:
	var slot_id: int = $SlotSelectorButton.current_slot_id
	var is_tile_pos: bool = Commands.slot_is_positions(slot_id)
	var modified_value: int = plain_value
	if not is_absolute_mode:
		modified_value = modified_value | RELATIVE_BIT
		if not is_tile_pos and $EntityRelativeMode.selected_value == "Facing":
			modified_value = modified_value | RELATIVE_MODE_BIT
		modified_value = modified_value | (slot_id << SLOT_SHIFT)
	return modified_value


func set_value(new_val) -> void:
	new_val = int(new_val)
	var is_relative = new_val & RELATIVE_BIT > 0
	var rel_mode = new_val & RELATIVE_MODE_BIT > 0
	var rel_slot = (new_val >> SLOT_SHIFT)
	
	$DirectionSelectorButton.set_direction(new_val & DIRECTION_ONLY)
	$AbsoluteModeSelect.select_index(1 if is_relative else 0)
	if is_relative:
		$EntityRelativeMode.select_index(1 if rel_mode else 0)
		$SlotSelectorButton.set_current_slot(rel_slot)
	update_relative_selector()

func absolute_changed(new_value: String) -> void:
	if new_value == "Absolute":
		$SlotSelectorButton.visible = false
		$EntityRelativeMode.visible = false
		is_absolute_mode = true
		$DirectionSelectorButton.show_absolute()
	else:
		$SlotSelectorButton.visible = true
		$EntityRelativeMode.visible = true
		is_absolute_mode = false
		$DirectionSelectorButton.show_relative()

func slot_changed(_new_slot_id: int) -> void:
	update_relative_selector()

func update_relative_selector() -> void:
	if Commands.slot_is_positions($SlotSelectorButton.current_slot_id):
		$EntityRelativeMode.select_index(1)
		$EntityRelativeMode.disabled = true
	else:
		$EntityRelativeMode.disabled = false