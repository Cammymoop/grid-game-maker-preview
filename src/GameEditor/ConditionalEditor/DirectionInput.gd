extends HBoxContainer

const RELATIVE_BIT = 4
const RELATIVE_MODE_BIT = 8
const SLOT_SHIFT = 4

var absolute = true

func _ready():
	$AbsoluteModeSelect.set_items(["Absolute", "Relative to"])
	$AbsoluteModeSelect.connect("changed", self, "absolute_changed")
	$EntityRelativeMode.set_items(["Facing", "Moving"])

# Return all the info about the selected direction and relativeness as a single int value
func get_value():
	var value: int = $DirectionSelectorButton.current_direction
	if absolute:
		value = value | RELATIVE_BIT
		if $EntityRelativeMode.selected_value == "Facing":
			value = value | RELATIVE_MODE_BIT
		value = value | ($SlotSelectorButton.current_slot_id >> SLOT_SHIFT)
	return value

func absolute_changed(new_value: String) -> void:
	if new_value == "Absolute":
		$SlotSelectorButton.visible = false
		$EntityRelativeMode.visible = false
		absolute = true
		$DirectionSelectorButton.show_absolute()
	else:
		$SlotSelectorButton.visible = true
		$EntityRelativeMode.visible = true
		$DirectionSelectorButton.show_relative()
