@tool
extends Node

const TILE_TANSFORM_MASK: int = TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V | TileSetAtlasSource.TRANSFORM_TRANSPOSE

const FACING_TO_TILE_TRANSFORMS: Dictionary = {
	0: 0,
	1: TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_TRANSPOSE,
	2: TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V,
	3: TileSetAtlasSource.TRANSFORM_FLIP_V | TileSetAtlasSource.TRANSFORM_TRANSPOSE,
}

const TILE_TRANSFORM_TO_FACING: Dictionary = {
	0: 0,
	TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_TRANSPOSE: 1,
	TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V: 2,
	TileSetAtlasSource.TRANSFORM_FLIP_V | TileSetAtlasSource.TRANSFORM_TRANSPOSE: 3,
}

const FACING_TO_VECTOR: Dictionary = {
	0: Vector2.UP,
	1: Vector2.RIGHT,
	2: Vector2.DOWN,
	3: Vector2.LEFT,
}

func _ready():
	randomize()

func set_keys(dict : Dictionary, keys: Array) -> void:
	for k in keys:
		dict[k] = true

func exclusive_randf() -> float:
	var r: = randf()
	return 0.0 if r == 1.0 else r

func random_int_range(start: int, end_exclusive: int) -> int:
	return randi_range(start, end_exclusive - 1)

func vector_to_facing(vector: Vector2) -> int:
	if abs(vector.x) == abs(vector.y):
		return -1
	elif abs(vector.x) > abs(vector.y):
		return 1 if vector.x > 0 else 3
	else:
		return 2 if vector.y > 0 else 0

func biased_vector_to_facing(vector: Vector2, bias_vertical: bool) -> int:
	if vector == Vector2.ZERO:
		return -1
	if abs(vector.x) == abs(vector.y):
		if bias_vertical:
			vector.x = 0
		else:
			vector.y = 0
	return vector_to_facing(vector)

func vector_to_facing_alternate(vector: Vector2, with_bias: bool = false, bias_vertical: bool = true) -> int:
	if vector == Vector2.ZERO:
		return -1
	if abs(vector.x) == abs(vector.y):
		if with_bias:
			var axis_index: int = 1 if bias_vertical else 0
			vector[axis_index] = 0
			return vector_to_facing(vector)
		else:
			return -1
	
	vector[vector.abs().max_axis_index()] = 0
	if vector == Vector2.ZERO:
		return -1
	return vector_to_facing(vector)

func facing_vector(what_facing: int) -> Vector2:
	if FACING_TO_VECTOR.has(what_facing):
		return FACING_TO_VECTOR[what_facing]
	print_debug("bad facing: %s" % str(what_facing))
	print_stack()
	return Vector2.ZERO

func facing_rotated(what_facing: int, what_rotation: int) -> int:
	return posmod(what_facing + what_rotation, 4)

func facing_opposite(what_facing: int) -> int:
	return posmod(what_facing + 2, 4)

func facing_rotation(what_facing: int) -> float:
	return (what_facing * PI) / 2.0

func direction_to_facing(direction: String) -> int:
	if direction == "up" or direction == "forward":
		return 0
	elif direction == "right":
		return 1
	elif direction == "down" or direction == "backward":
		return 2
	elif direction == "left":
		return 3
	elif direction == "none":
		return -1
	print_debug("bad direction: " + str(direction))
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
	
	var facing: int

	var relative_to_slot_id: = get_full_direction_slot(full_direction)
	if Commands.slot_is_entity(relative_to_slot_id):
		var entity = slots[relative_to_slot_id]
		if not entity:
			push_warning("Slot for relative direction (entity) is empty")
			return get_full_direction_absolute(full_direction)
		
		if is_full_dir_relative_to_visual_facing(full_direction):
			facing = entity.facing
		else:
			facing = entity.move_facing
	elif Commands.slot_is_positions(relative_to_slot_id):
		var positions: Array = slots[relative_to_slot_id]
		if not positions:
			push_warning("Slot for relative direction (tile positions) is empty")
			facing = 0
		else:
			facing = MapManager.get_tile_facing_at(positions[0])
	
	return facing_rotated(facing, get_full_direction_absolute(full_direction))


func parse_json(text: String):
	var parser: = JSON.new()
	if parser.parse(text) != OK:
		print_debug("JSON parse error at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return null
	return parser.data

func callv_with_errors(callable: Callable, args: Array) -> Variant:
	return callable.bindv(args).call()

func any_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value
	elif typeof(value) == TYPE_FLOAT:
		return int(value)
	
	var str_val: = str(value)
	if str_val.is_valid_hex_number(true):
		return str_val.hex_to_int()
	elif str_val.is_valid_float():
		return int(float(str_val))
	return 0

func tile_transform_from_facing(facing: int) -> int:
	return FACING_TO_TILE_TRANSFORMS.get(facing, 0)

func facing_from_tile_alt_id(alt_id: int) -> int:
	return TILE_TRANSFORM_TO_FACING.get(alt_id & TILE_TANSFORM_MASK, 0)

func insert_array_at(into_array: Array, insert_at_index: int, inserted_array: Array) -> void:
	if insert_at_index == into_array.size():
		into_array.append_array(inserted_array)
		return
	for i in range(inserted_array.size() - 1, -1, -1):
		into_array.insert(insert_at_index, inserted_array[i])

func get_empty_context_menu() -> PopupMenu:
	var context_menu = PopupMenu.new()
	context_menu.popup_hide.connect(context_menu.queue_free)
	return context_menu

func popup_context_menu_at_mouse(the_context_menu: PopupMenu) -> void:
	var window: = get_window()
	var popup_at_pos: = Vector2i(window.get_mouse_position())
	if not window.gui_embed_subwindows:
		popup_at_pos += window.position
	if not the_context_menu.is_inside_tree():
		window.add_child(the_context_menu)
	the_context_menu.position = popup_at_pos
	the_context_menu.popup()

func get_number_suffix(of_string: String) -> int:
	var regex: = RegEx.new()
	regex.compile("(\\d+)$")
	var got_match = regex.search(of_string)
	if got_match:
		return got_match.get_string(1).to_int()
	return 0

func get_width_height_position_list(width: int, height: int) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for y in height:
		for x in width:
			positions.append(Vector2i(x, y))
	return positions

func check_comparison(value_a: float, value_b: float, comparison: String) -> bool:
	if comparison == ">":
		return value_a > value_b
	elif comparison == "<":
		return value_a < value_b
	elif comparison == "=":
		return value_a == value_b
	elif comparison == "!=":
		return value_a != value_b
	elif comparison == ">=":
		return value_a >= value_b
	elif comparison == "<=":
		return value_a <= value_b
	return false

func sanitize_for_filename(the_str: String, allow_uppercase: bool = false, allow_spaces: bool = false) -> String:
	the_str = the_str.strip_edges()
	if not allow_uppercase:
		the_str = the_str.to_lower()
	if not allow_spaces:
		the_str = the_str.replace(" ", "_")
	the_str = the_str.replace('"', "'")
	the_str = the_str.remove_chars('\\/|*?<>:')
	while the_str.begins_with("."):
		the_str = the_str.substr(1)
	if not the_str:
		return "OOPS"
	return the_str
	
func get_vector2_from_arr(arr: Array) -> Vector2:
	return Vector2(arr[0], arr[1])

func get_vector2i_from_arr(arr: Array) -> Vector2i:
	return Vector2i(int(arr[0]), int(arr[1]))

func get_arr_from_vector2(vec: Vector2) -> Array:
	return [vec.x, vec.y]

func get_arr_from_vector2i(vec: Vector2i) -> Array:
	return [vec.x, vec.y]

func string_list_union(list_a: Array, list_b: Array) -> Array:
	for item in list_b:
		if not item in list_a:
			list_a.append(item)
	return list_a

func long_basis(vec: Vector2) -> Vector2:
	var dir_vec: = vec.sign()
	dir_vec[vec.abs().min_axis_index()] = 0
	return dir_vec

func short_basis(vec: Vector2) -> Vector2:
	var dir_vec: = vec.sign()
	dir_vec[vec.abs().max_axis_index()] = 0
	return dir_vec

func get_dict_color(from_dict: Dictionary, key: String, default_color: Color) -> Color:
	if not key in from_dict:
		return default_color
	var val: String = from_dict.get(key, "")
	if not val.is_valid_html_color():
		return default_color
	return Color.from_string(val, default_color)

func color_string(of_color: Color, force_alpha: bool = true) -> String:
	return '#' + of_color.to_html(force_alpha or (of_color.a < 1))

func color_string_no_alpha(of_color: Color) -> String:
	return '#' + of_color.to_html(false)

func is_float_integer(num: float) -> bool:
	return is_equal_approx(num, roundf(num))

func property_value_or_conditional_to_string(prop_value: Variant) -> String:
	if typeof(prop_value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		return "{CONDITIONAL}"
	return property_value_to_string(prop_value)

func property_value_to_string(prop_value: Variant) -> String:
	if typeof(prop_value) == TYPE_STRING:
		return prop_value
	elif typeof(prop_value) == TYPE_FLOAT:
		if is_float_integer(prop_value):
			return str(roundi(prop_value))
		else:
			return str(prop_value)
	elif typeof(prop_value) in [TYPE_INT, TYPE_BOOL]:
		return str(prop_value)
	else:
		push_error("Tried to convert unexpectedly typed (%s) property value to string defualt str(): %s" % [type_string(typeof(prop_value)), prop_value])
		return ""

func property_value_nonempty_string(prop_value: Variant, default_value: String) -> String:
	var str_value: String = property_value_to_string(prop_value)
	if str_value.strip_edges() == "":
		return default_value
	return str_value

func property_value_scalar(prop_value: Variant, default_value: float) -> float:
	if typeof(prop_value) in [TYPE_INT, TYPE_FLOAT]:
		return float(prop_value)
	elif typeof(prop_value) == TYPE_STRING:
		if not prop_value or not prop_value.is_valid_float():
			return default_value
		return float(prop_value)
	elif typeof(prop_value) == TYPE_BOOL:
		return 1.0 if prop_value else 0.0
	else:
		push_error("Tried to convert unexpectedly typed (%s) property value to scalar: %s" % [type_string(typeof(prop_value)), prop_value])
		return default_value

func _fixed_just_press_released_by_event(action: String, event: InputEvent, exact: bool, as_pressed: bool) -> bool:
	if not InputMap.has_action(action):
		push_error("Action %s not found in InputMap" % action)
		EngineDebugger.debug()
	
	if not event is InputEventMouseButton or event.is_pressed() != as_pressed:
		return Input.is_action_just_pressed_by_event(action, event, exact)
	
	var action_bindings: = InputMap.action_get_events(action)
	for bound_event in action_bindings:
		var mbe: = bound_event as InputEventMouseButton
		if not mbe or mbe.button_index != event.button_index:
			continue
		if not exact:
			return true

		var shift_bound: = mbe.shift_pressed
		# TODO handle cmd remapping for Mac
		var ctr_bound: = mbe.command_or_control_autoremap or mbe.ctrl_pressed
		var meta_bound: = mbe.meta_pressed
		
		if shift_bound != event.shift_pressed or ctr_bound != event.ctrl_pressed or meta_bound != event.meta_pressed:
			return false
		else:
			return true
	return false

func fixed_just_pressed_by_event(action: String, event: InputEvent, exact: bool = false) -> bool:
	return _fixed_just_press_released_by_event(action, event, exact, true)

func fixed_just_released_by_event(action: String, event: InputEvent, exact: bool = false) -> bool:
	return _fixed_just_press_released_by_event(action, event, exact, false)
