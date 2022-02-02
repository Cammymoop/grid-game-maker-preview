extends Node

var move_mode = "facing"
var multi_try = true

func get_move():
	var parent = get_parent()
	if parent.can_i_move_relative("forward"):
		return parent.facing
	
	if parent.can_i_move_relative("reverse"):
		return Utility.resolve_relative_direction("reverse", parent.facing)
	
	return -1
