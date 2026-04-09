extends Node

var move_mode = "facing"

@onready var parent = get_parent()

func get_options() -> Dictionary:
	return {}

func get_max_move_intentions() -> int:
	return 1

func get_move(_attempt_num: int):
	if not EntityManager.controller_frame:
		return -1
	
	if parent.can_i_move_relative("forward"):
		return parent.move_facing
	else:
		return Utility.facing_opposite(parent.move_facing)
