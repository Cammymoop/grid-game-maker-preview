extends HBoxContainer

const RELATIVE_BIT = 4
const RELATIVE_MODE_BIT = 8
const SLOT_SHIFT = 4

const DIRECTION_ONLY = 3

var absolute = true

func _ready():
	$AbsoluteModeSelect.set_items(["Absolute", "Relative to"])
	$AbsoluteModeSelect.connect("changed", Callable(self, "absolute_changed"))
	$EntityRelativeMode.set_items(["Moving", "Facing"])

# Return all the info about the selected direction and relativeness as a single int value
func get_value():
	var value: int = $DirectionSelectorButton.current_direction
	if not absolute:
		value = value | RELATIVE_BIT
		if $EntityRelativeMode.selected_value == "Facing":
			value = value | RELATIVE_MODE_BIT
		value = value | ($SlotSelectorButton.current_slot_id << SLOT_SHIFT)
	return value

func set_value(new_val) -> void:
	new_val = int(new_val)
	var is_relative = new_val & RELATIVE_BIT > 0
	var rel_mode = new_val & RELATIVE_MODE_BIT > 0
	var rel_slot = (new_val >> SLOT_SHIFT)
	
	$DirectionSelectorButton.set_direction(new_val & DIRECTION_ONLY)
	$AbsoluteModeSelect.index_selected(1 if is_relative else 0)
	if is_relative:
		$EntityRelativeMode.index_selected(1 if rel_mode else 0)
		$SlotSelectorButton.set_current_slot(rel_slot)

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
