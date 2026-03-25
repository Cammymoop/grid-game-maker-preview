extends Node

func _ready():
	randomize()

func set_keys(dict : Dictionary, keys: Array) -> void:
	for k in keys:
		dict[k] = true

func exclusive_randf() -> float:
	var r: = randf()
	return 0.0 if r == 1.0 else r

func random_int_range(start: int, end_exclusive: int) -> int:
	return start + int(floor(exclusive_randf() * (end_exclusive - start)))

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
	print_debug("bad facing: %s" % str(what_facing))
	print_stack()
	return Vector2(0, 0)

func facing_rotated(what_facing: int, what_rotation: int) -> int:
	return posmod(what_facing + what_rotation, 4)

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

func string_to_string_float(the_string: String) -> String:
	if the_string == "":
		return ""
	if the_string == ".":
		return "."
	
	var new_str: = str(float(the_string))
	if len(new_str) < 1:
		return ""
	
	if new_str[0] == "0" and the_string[0] != "0":
		new_str = new_str.substr(1)
	new_str = new_str.trim_suffix(".0")
	return new_str

func random_sign() -> int:
	return int(floor(randf() * 2)) * 2 - 1

func random_list_element(list):
	var index = random_int_range(0, len(list))
	return list[index]

func get_world() -> Node:
	var f = get_tree().get_nodes_in_group("World")
	if f:
		return f[0]
	print_debug("Error could not find world")
	return null

func get_pause_menu() -> Node:
	var f = get_tree().get_nodes_in_group("PauseMenu")
	if f:
		return f[0]
	print_debug("Error could not find pause menu")
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

func get_camera_setting(setting):
	var game_settings = GameManager.game_definition["game_settings"]
	if "camera_settings" in game_settings:
		if setting in game_settings["camera_settings"]:
			return game_settings["camera_settings"][setting]
	return null

var animal_file = "res://src/animals.txt"
var animals = []
func _fetch_animals() -> void:
	var f = FileAccess.open(animal_file, FileAccess.READ)
	if f:
		var text = f.get_as_text()
		animals = text.split("\n", false)
	
func random_animal() -> String:
	if len(animals) < 1:
		_fetch_animals()
	return animals[random_int_range(0, len(animals))]

func vector_to_list(vec: Vector2) -> Array:
	return [vec.x, vec.y]

func array_vectors_to_lists(arr: Array) -> Array:
	var new_arr = []
	for val in arr:
		if typeof(val) == TYPE_VECTOR2:
			new_arr.append(vector_to_list(val))
		elif typeof(val) == TYPE_ARRAY:
			new_arr.append(array_vectors_to_lists(val))
		elif typeof(val) == TYPE_DICTIONARY:
			new_arr.append(dict_vectors_to_lists(val))
		else:
			new_arr.append(val)
	return new_arr

func facing_from_adjacent_positions(from_pos, to_pos) -> int:
	if to_pos.x > from_pos.x:
		return 1
	elif to_pos.x < from_pos.x:
		return 3
	elif to_pos.y < from_pos.y:
		return 0
	elif to_pos.y > from_pos.y:
		return 2
	else:
		return -1
	

func dict_vectors_to_lists(dict: Dictionary) -> Dictionary:
	var new_dict = {}
	for key in dict:
		var val = dict[key]
		if typeof(val) == TYPE_ARRAY:
			new_dict[key] = array_vectors_to_lists(val)
		elif typeof(val) == TYPE_DICTIONARY:
			new_dict[key] = dict_vectors_to_lists(val)
		elif typeof(val) == TYPE_VECTOR2:
			new_dict[key] = vector_to_list(val)
		else:
			new_dict[key] = val
	return new_dict

func array_iter(arr, reversed: bool = false) -> Array:
	if reversed:
		return reversed_array_iter(arr)
	return range(len(arr))

func reversed_array_iter(arr) -> Array:
	return range(len(arr) - 1, -1, -1)

func max_integer_scale_in(base: Vector2, max_size: Vector2) -> int:
	var max_x = int(floor(max_size.x / base.x))
	var max_y = int(floor(max_size.y / base.y))
	return max_x if max_x <= max_y else max_y

# Normally rect.has_point is exclusive on the bottom and right edge
func position_in_rect_inclusive(position: Vector2, rect: Rect2) -> bool:
	var new_rect = Rect2(rect.position, rect.size + Vector2(1, 1))
	return new_rect.has_point(position)

func get_2d_coords_from_index(index : int, tpr : int) -> Vector2:
	return Vector2(index % tpr, floor(float(index)/tpr))

func get_texture_index_offset(texture_sub_index, tile_size, border, separation, tpr) -> Vector2:
	var coord = get_2d_coords_from_index(texture_sub_index, tpr)
	var combined_tile_size = tile_size + separation
	return border + (coord * combined_tile_size)
	#return Vector2(texture_sub_index % tpr * MapManager.tile_width, floor(texture_sub_index/tpr) * MapManager.tile_width)

func get_texture_index_rect(texture_sub_index, tile_size, border, separation, tpr) -> Rect2:
	var t_offset = get_texture_index_offset(texture_sub_index, tile_size, border, separation, tpr)
	return Rect2(t_offset, tile_size)


const FULL_DIR_RELATIVE_BIT = 4
const FULL_DIR_RELATIVE_MODE_BIT = 8
const FULL_DIR_SLOT_SHIFT = 4

func full_direction_is_absolute(full_dir: int) -> bool:
	return not bool(FULL_DIR_RELATIVE_BIT & full_dir)

func get_full_direction_slot(full_dir: int) -> int:
	return full_dir >> FULL_DIR_SLOT_SHIFT

func get_full_direction_absolute(full_dir: int) -> int:
	return full_dir & 3 # Just the first 2 bits

func is_full_dir_relative_to_visual_facing(full_dir: int) -> bool:
	return bool(FULL_DIR_RELATIVE_MODE_BIT & full_dir)

func resolve_full_direction_to_facing(full_direction: int, slots: Dictionary) -> int:
	if full_direction_is_absolute(full_direction):
		return get_full_direction_absolute(full_direction)
	
	# TODO needs to know if the slot is a tile_pos and resolve direction relative to the tiles facing
	var entity = slots[get_full_direction_slot(full_direction)]
	if not entity:
		print_debug("Slot for relative direction is empty")
		return get_full_direction_absolute(full_direction)
	
	var facing: int
	if is_full_dir_relative_to_visual_facing(full_direction):
		facing = entity.visual_facing
	else:
		facing = entity.facing
	
	return facing_rotated(facing, get_full_direction_absolute(full_direction))


func parse_json(text: String):
	var parser: = JSON.new()
	if parser.parse(text) != OK:
		print_debug("JSON parse error at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return null
	return parser.data
