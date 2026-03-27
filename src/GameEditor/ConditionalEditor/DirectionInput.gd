extends HBoxContainer

const RELATIVE_BIT = 4
const RELATIVE_MODE_BIT = 8
const SLOT_SHIFT = 4

const DIRECTION_ONLY = 3

var absolute = true

var arg_name: String = ""

func _ready():
	$AbsoluteModeSelect.set_items(["Absolute", "Relative to"])
	$AbsoluteModeSelect.connect("changed", Callable(self, "absolute_changed"))
	$EntityRelativeMode.set_items(["Moving", "Facing"])
	
	$SlotSelectorButton.set_valid_slot_categories(["entity", "pos"])
	$SlotSelectorButton.slot_changed.connect(slot_changed)

func set_arg_name(new_arg_name: String) -> void:
	arg_name = new_arg_name

func get_arg_name() -> String:
	return arg_name

# Return all the info about the selected direction and relativeness as a single int value
func get_value():
	var value: int = $DirectionSelectorButton.current_direction
	var slot_id: int = $SlotSelectorButton.current_slot_id
	var is_tile_pos: bool = Commands.slot_is_positions(slot_id)
	if not absolute:
		value = value | RELATIVE_BIT
		if not is_tile_pos and $EntityRelativeMode.selected_value == "Facing":
			value = value | RELATIVE_MODE_BIT
		value = value | (slot_id << SLOT_SHIFT)
	return value

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
		absolute = true
		$DirectionSelectorButton.show_absolute()
	else:
		$SlotSelectorButton.visible = true
		$EntityRelativeMode.visible = true
		absolute = false
		$DirectionSelectorButton.show_relative()

func slot_changed(_new_slot_id: int) -> void:
	update_relative_selector()

func update_relative_selector() -> void:
	if Commands.slot_is_positions($SlotSelectorButton.current_slot_id):
		$EntityRelativeMode.select_index(1)
		$EntityRelativeMode.disabled = true
	else:
		$EntityRelativeMode.disabled = false