extends Node

var move_mode = "facing"

@onready var parent = get_parent()

var options: Dictionary = {
	"direction_priority": {"display_name": "Direction priority", "type": "reorderable_list", "list_items": ["forward", "left", "right", "backward"]},
	"num_directions": {"display_name": "Number of directions to try", "type": "int", "min_value": 1, "max_value": 4},
}

var direction_priority: Array = ["forward", "left", "right", "backward"]
var num_directions: int = 4
var _facing_priority: Array = []

func _ready():
	update_facing_priority()

func get_options() -> Dictionary:
	return options

func get_default_options() -> Dictionary:
	return {
		"direction_priority": direction_priority,
		"num_directions": num_directions,
	}

func set_options(new_options: Dictionary) -> void:
	if "direction_priority" in new_options:
		direction_priority = new_options["direction_priority"]
	if "num_directions" in new_options:
		num_directions = new_options["num_directions"]
	update_facing_priority()

func get_option_values() -> Dictionary:
	return {
		"direction_priority": direction_priority,
		"num_directions": num_directions,
	}

func update_facing_priority() -> void:
	_facing_priority = []
	for direction in direction_priority:
		_facing_priority.append(Utility.direction_to_facing(direction))

func get_max_move_intentions() -> int:
	return num_directions

func get_move(attempt_num: int):
	if not EntityManager.controller_frame:
		return -1
	
	return posmod(parent.facing + _facing_priority[attempt_num], 4)