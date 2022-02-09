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

func facing_rotation(what_facing) -> float:
	return (what_facing * PI) / 2.0

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

func is_absolute_direction(direction: String) -> bool:
	return direction == "up" or direction == "down" or direction == "left" or direction == "right"

func resolve_relative_direction(relative_direction, facing: int) -> int:
	if is_absolute_direction(relative_direction):
		return direction_to_facing(relative_direction)
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

func ucfirst(string:String) -> String:
	return string[0].to_upper() + string.substr(1)

func random_int_range(start: int, end_exclusive: int) -> int:
	return start + int(floor(randf() * (end_exclusive - start)))

func random_sign() -> int:
	return int(floor(randf() * 2)) * 2 - 1

func random_list_element(list):
	var index = random_int_range(0, len(list))
	return list[index]

func get_world() -> Node2D:
	var f = get_tree().get_nodes_in_group("World")
	if f:
		return f[0]
	print_debug("Error could not find world")
	return null

func atlas_texture_from_texture_index(texture_index, sub_index):
	var atlas_tex: = AtlasTexture.new()
	
	atlas_tex.atlas = TextureManager.get_texture(texture_index)
	atlas_tex.region = TextureManager.get_index_rect(texture_index, sub_index)
	return atlas_tex

func atlas_texture_from_tile_index(tile_index):
	var atlas_tex: = AtlasTexture.new()
	
	atlas_tex.atlas = MapManager.get_tile_texture(tile_index)
	atlas_tex.region = MapManager.get_tile_texture_rect(tile_index)
	return atlas_tex

func atlas_texture_from_entity_index(entity_index):
	var atlas_tex: = AtlasTexture.new()
	
	atlas_tex.atlas = EntityManager.get_entity_texture(entity_index)
	atlas_tex.region = EntityManager.get_entity_texture_rect(entity_index)
	return atlas_tex
