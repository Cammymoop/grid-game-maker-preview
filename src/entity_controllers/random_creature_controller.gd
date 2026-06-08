extends Node

var move_mode = "pre_fetch"

@onready var parent = get_parent()

var options: Dictionary = {
	"prefer_forward": {"display_name": "Prefer continuing forward", "type": "bool"},
}

var prefer_forward: bool = false

func get_options() -> Dictionary:
	return options

func get_default_options() -> Dictionary:
	return {
		"prefer_forward": prefer_forward,
	}

func set_options(new_options: Dictionary) -> void:
	if "prefer_forward" in new_options:
		prefer_forward = new_options["prefer_forward"]

func get_option_values() -> Dictionary:
	return {
		"prefer_forward": prefer_forward,
	}

func get_max_move_intentions() -> int:
	return 4

func get_moves() -> Array:
	if not EntityManager.controller_frame:
		return []
    
	var shuffled_directions: Array = [0, 1, 2, 3]
	shuffled_directions.shuffle()
	if prefer_forward:
		shuffled_directions.erase(parent.move_facing)
		shuffled_directions.push_front(parent.move_facing)
	
	return shuffled_directions
	
