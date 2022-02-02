extends Node

func _ready():
	randomize()

func facing_vector(what_facing) -> Vector2:
	match what_facing:
		0:
			return Vector2(0, -1)
		1:
			return Vector2(1, 0)
		2:
			return Vector2(0, 1)
		3:
			return Vector2(-1, 0)
	print_debug("bad facing")
	return Vector2(0, 0)

func direction_to_facing(direction: String) -> int:
	match direction:
		"up":
			return 0
		"right":
			return 1
		"down":
			return 2
		"left":
			return 3
		"none":
			return -1
	print_debug("bad direction: " + str(direction))
	print_stack()
	return -1

func resolve_relative_direction(relative_direction, facing) -> String:
	match relative_direction:
		"forward":
			pass
		"turn_right":
			facing += 1
			if facing > 3:
				facing = 0
		"turn_left":
			facing -= 1
			if facing < 0:
				facing = 3
		"reverse":
			facing += 2
			if facing > 3:
				facing -= 4
	return facing
	

func random_int_range(start: int, end_exclusive: int):
	return start + floor(randf() * (end_exclusive - start))

func random_list_element(list):
	var index = random_int_range(0, len(list))
	return list[index]

func get_world() -> Node2D:
	var f = get_tree().get_nodes_in_group("World")
	if f:
		return f[0]
	print_debug("Error could not find world")
	return null
