extends HBoxContainer

@export var is_reference_position: bool = false

var is_absolute_mode: = true
# in rotation mode, always show the relative icons and dont use the entity relative selector ui, is always complex mode
var is_rotation_mode: = false

var arg_name: String = ""

func _ready():
	$AbsoluteModeSelect.set_items(["Absolute", "Relative to"])
	$AbsoluteModeSelect.changed.connect(absolute_changed)
	$EntityRelativeMode.set_items(["Moving", "Facing"])
	
	$SlotSelectorButton.set_valid_slot_categories(["entity", "pos"])
	$SlotSelectorButton.slot_changed.connect(slot_changed)

	$DirectionSelectorButton.set_slots_enabled(is_reference_position)

func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name

func get_arg_name() -> String:
	return arg_name

func set_input_args(new_args: Array) -> void:
	if not new_args:
		return
	is_reference_position = false
	is_rotation_mode = false
	if new_args[0].is_valid_float() and float(new_args[0]) >= 2:
		is_rotation_mode = true
	if new_args[0].strip_edges().length() > 0:
		is_reference_position = true

	$DirectionSelectorButton.set_slots_enabled(is_reference_position)
	update_relative_selector()

# Return all the info about the selected direction and relativeness as a single int value if not in complex mode
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
		return {"type": "plain", "direction": _relativify(value)}
	else:
		var relative_info: int = 0 if is_rotation_mode else _relativify(0)
		return {"type": "slot_reference", "slot_id": slot_id, "direction": relative_info}

func _relativify(plain_value: int) -> int:
	var slot_id: int = $SlotSelectorButton.current_slot_id
	var is_tile_pos: bool = Commands.slot_is_positions(slot_id)
	var modified_value: int = plain_value
	if not is_absolute_mode:
		modified_value = modified_value | Utility.DIR_RELATIVE_BIT
		if not is_tile_pos and $EntityRelativeMode.selected_value == "Facing":
			modified_value = modified_value | Utility.DIR_RELATIVE_MODE_BIT
		modified_value = modified_value | (slot_id << Utility.DIR_SLOT_SHIFT)
	return modified_value


func set_value(new_val) -> void:
	var facing_dir: int = -1

	var set_direction_button_to_facing: bool = true
	if typeof(new_val) == TYPE_DICTIONARY:
		facing_dir = new_val["direction"]
		if new_val["type"] == "slot_reference":
			set_direction_button_to_facing = false
			$DirectionSelectorButton.set_slot_id(new_val["slot_id"])
	else:
		facing_dir = int(new_val)

	var is_relative = facing_dir & Utility.DIR_RELATIVE_BIT > 0
	var rel_mode = facing_dir & Utility.DIR_RELATIVE_MODE_BIT > 0
	var rel_slot = (facing_dir >> Utility.DIR_SLOT_SHIFT)

	if set_direction_button_to_facing:
		$DirectionSelectorButton.set_direction(facing_dir & Utility.DIR_MASK)

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
		if is_rotation_mode:
			$DirectionSelectorButton.show_relative()
		else:
			$DirectionSelectorButton.show_absolute()
	else:
		$SlotSelectorButton.visible = true
		$EntityRelativeMode.visible = true
		is_absolute_mode = false
		$DirectionSelectorButton.show_relative()

func slot_changed(_new_slot_id: int) -> void:
	update_relative_selector()

func update_relative_selector() -> void:
	$EntityRelativeMode.visible = not is_rotation_mode
	if is_rotation_mode:
		return
	if Commands.slot_is_positions($SlotSelectorButton.current_slot_id):
		$EntityRelativeMode.select_index(1)
		$EntityRelativeMode.disabled = true
	else:
		$EntityRelativeMode.disabled = false