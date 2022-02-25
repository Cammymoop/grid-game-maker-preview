extends Node

var move_mode = "facing"

onready var parent = get_parent()

func get_options() -> Dictionary:
	return {}

func get_move():
	if not EntityManager.controller_frame:
		return -1
	
	if parent.can_i_move_relative("forward"):
		return parent.facing
	
	if parent.can_i_move_relative("reverse"):
		return Utility.resolve_relative_direction("reverse", parent.facing)
	
	return -1
