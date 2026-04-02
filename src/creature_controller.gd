extends Node

var move_mode = "facing"

@onready var parent = get_parent()

var options: Dictionary = {
	"direction_priority": {"display_name": "Direction priority", "type": "reorderable_list", "list_items": ["forward", "left", "right", "backward"]},
}

var direction_priority: Array = ["forward", "left", "right", "backward"]
var _facing_priority: Array = []

func _ready():
	update_facing_priority()

func get_options() -> Dictionary:
	return options

func set_options(new_options: Dictionary) -> void:
	if "direction_priority" in new_options:
		direction_priority = new_options["direction_priority"]
	update_facing_priority()

func update_facing_priority() -> void:
	_facing_priority = []
	for direction in direction_priority:
		_facing_priority.append(Utility.direction_to_facing(direction))

func get_max_move_intentions() -> int:
	return 4

func get_move(attempt_num: int):
	if not EntityManager.controller_frame:
		return -1
	
	return posmod(parent.visual_facing + _facing_priority[attempt_num], 4)
