@tool
extends Node

enum PosInterpStyle {
	NONE,
	CONTINUOUS_LINEAR,
	EASE_OUT,
	JUMP_LINEAR,
	JUMP_EASE_OUT,
	DOUBLE_EASE_OUT,
	DOUBLE_NONE,
	MID_DISCRETE,
	LATE_DISCRETE,
}

const NON_SMOOTH_INTERP: Array[PosInterpStyle] = [
	PosInterpStyle.NONE, PosInterpStyle.LATE_DISCRETE
]

const POS_INTERP_STRINGS: Dictionary[PosInterpStyle, String] = {
	PosInterpStyle.NONE: "none",
	PosInterpStyle.DOUBLE_NONE: "2-frames",
	PosInterpStyle.CONTINUOUS_LINEAR: "smooth",
	PosInterpStyle.EASE_OUT: "stepped",
	PosInterpStyle.DOUBLE_EASE_OUT: "stepped-twice",
	PosInterpStyle.JUMP_LINEAR: "jerky",
	PosInterpStyle.JUMP_EASE_OUT: "jerky-stepped",
	PosInterpStyle.MID_DISCRETE: "none-middle",
	PosInterpStyle.LATE_DISCRETE: "none-late",
}

const CreditsUI = preload("res://Scenes/credits_ui.gd")

const JUMP_INTERP_AMOUNT = 0.5
const DEF_INTERP_EASE = 0.36

const DIR_RELATIVE_BIT = 4
const DIR_RELATIVE_MODE_BIT = 8
const DIR_SLOT_SHIFT = 4

const DIR_MASK = 3

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
	
func truthy(value: Variant) -> bool:
	return true if value else false

func non_nullable_obj(obj: Object, default_obj: Object) -> Object:
	if not obj:
		return default_obj
	return obj

func non_nullable(value: Variant, default_value: Variant) -> Variant:
	if typeof(value) == TYPE_NIL or (typeof(value) == TYPE_OBJECT and not value):
		return default_value
	return value

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


func dict_map(dict: Dictionary, callback: Callable) -> Dictionary:
	var new_dict: = Dictionary({}, 
		dict.get_typed_key_builtin(), dict.get_typed_key_class_name(), dict.get_typed_key_script(),
		dict.get_typed_value_builtin(), dict.get_typed_value_class_name(), dict.get_typed_value_script())

	for k in dict:
		var kv: Array = callback.call(k, dict[k])
		new_dict[kv[0]] = kv[1]
	return new_dict

func dict_keymap(dict: Dictionary, callback: Callable) -> Dictionary:
	var new_dict: = Dictionary({}, 
		dict.get_typed_key_builtin(), dict.get_typed_key_class_name(), dict.get_typed_key_script(),
		dict.get_typed_value_builtin(), dict.get_typed_value_class_name(), dict.get_typed_value_script())
	
	if callback.get_argument_count() == 1:
		for old_key in dict:
			new_dict[callback.call(old_key)] = dict[old_key]
	else:
		for old_key in dict:
			new_dict[callback.call(old_key, dict[old_key])] = dict[old_key]

	return new_dict

func dict_inplace_map(dict: Dictionary, map_func: Callable) -> void:
	var keys: = dict.keys()
	var vals: = dict.values()
	dict.clear()
	for i in keys.size():
		var kv: Array = map_func.call(keys[i], vals[i])
		dict[kv[0]] = kv[1]

func dict_inplace_keymap(dict: Dictionary, map_func: Callable) -> void:
	var keys: = dict.keys()
	var vals: = dict.values()
	dict.clear()
	if map_func.get_argument_count() == 1:
		for i in keys.size():
			dict[map_func.call(keys[i])] = vals[i]
	else:
		for i in keys.size():
			dict[map_func.call(keys[i], vals[i])] = vals[i]

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

func vector_to_facing_from_facing(vector: Vector2, from_facing: int) -> int:
	var v2f: = vector_to_facing(vector)
	if v2f != -1:
		return v2f
	var delta_angle: = vector.angle_to(facing_vector(from_facing))
	vector = vector.rotated(signf(delta_angle) * 0.1)
	return vector_to_facing(vector)

func facing_vector(what_facing: int) -> Vector2:
	if FACING_TO_VECTOR.has(what_facing):
		return FACING_TO_VECTOR[what_facing]
	print_debug("bad facing: %s" % str(what_facing))
	print_stack()
	return Vector2.ZERO

func facing_vector_i(what_facing: int) -> Vector2i:
	return Vector2i(facing_vector(what_facing))

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

func random_list_element(list: Array) -> Variant:
	var index = random_int_range(0, len(list))
	return list[index]

func get_world() -> Node:
	var f = get_tree().get_nodes_in_group("World")
	if f:
		return f[0]
	print_debug("Error could not find world")
	return null

func get_credits_ui() -> CreditsUI:
	var creditses: Array[Node] = get_tree().get_nodes_in_group("Credits")
	for credits in creditses:
		if not credits is CreditsUI:
			continue
		return credits
	return null

func get_level_select_root() -> Control:
	var level_select_roots: Array[Node] = get_tree().get_nodes_in_group("LevelSelectRoot")
	for level_select_root in level_select_roots:
		return level_select_root
	return null

func get_map_editor() -> Node:
	var world: = get_world()
	if world:
		return world.find_child("MapEditor")
	else:
		return null

func get_map_editor_overlay() -> Node:
	var f = get_tree().get_nodes_in_group("MapEditorOverlay")
	if f:
		return f[0]
	print_debug("Error could not find map editor overlay")
	return null

func get_pause_menu() -> Node:
	var f = get_tree().get_nodes_in_group("PauseMenu")
	if f:
		return f[0]
	print_debug("Error could not find pause menu")
	return null


func atlas_texture_from_texture_index(texture_index, sub_index) -> AtlasTexture:
	var atlas_tex: = AtlasTexture.new()
	
	atlas_tex.atlas = TextureManager.get_texture(texture_index)
	atlas_tex.region = TextureManager.get_index_rect(texture_index, sub_index)
	return atlas_tex

func atlas_texture_from_tile_index(tile_index: int, preview: bool = false) -> AtlasTexture:
	var atlas_tex: = AtlasTexture.new()
	
	atlas_tex.atlas = MapManager.get_tile_texture(tile_index, preview)
	atlas_tex.region = MapManager.get_tile_texture_rect(tile_index, preview)
	return atlas_tex

func atlas_texture_from_entity_index(entity_index: int, preview: bool = false) -> AtlasTexture:
	var atlas_tex: = AtlasTexture.new()
	
	atlas_tex.atlas = EntityManager.get_entity_texture(entity_index, preview)
	atlas_tex.region = EntityManager.get_entity_texture_rect(entity_index, preview)
	return atlas_tex

func get_camera_setting(setting: String, default_value: Variant = null) -> Variant:
	return GameManager.get_game_setting("camera_settings", {}).get(setting, default_value)

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

func get_adjacent_positions(pos: Vector2i) -> Array[Vector2i]:
	return [pos + Vector2i.LEFT, pos + Vector2i.RIGHT, pos + Vector2i.UP, pos + Vector2i.DOWN]

func is_pos_adjacent(from_pos: Vector2i, to_pos: Vector2i, include_diagonal: bool = false) -> bool:
	if from_pos == to_pos:
		return false
	var delta: = to_pos - from_pos
	if include_diagonal:
		return delta.length() < 2
	return delta.length_squared() == 1
	

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

func any_to_float(value: Variant) -> float:
	if typeof(value) in [TYPE_FLOAT, TYPE_INT]:
		return float(value)
	
	var str_val: = str(value)
	if str_val.is_valid_hex_number(true) or str_val.is_valid_hex_number():
		return str_val.hex_to_int()
	elif str_val.is_valid_float():
		return float(str_val)
	return 0.0

func any_to_int(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return value
	elif typeof(value) == TYPE_FLOAT:
		return roundi(value)
	
	var str_val: = str(value)
	if str_val.is_valid_hex_number(true):
		return str_val.hex_to_int()
	elif str_val.is_valid_float():
		return roundi(float(str_val))
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

func get_transform2d_from_arr(arr: Array) -> Transform2D:
	return Transform2D(get_vector2_from_arr(arr[0]), get_vector2_from_arr(arr[1]), get_vector2_from_arr(arr[2]))

func get_arr_from_transform2d(transform: Transform2D) -> Array:
	return [get_arr_from_vector2(transform.origin), get_arr_from_vector2(transform.x), get_arr_from_vector2(transform.y)]

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

func get_dict_item(from_dict: Dictionary, key: String, default_value: Variant) -> Variant:
	return from_dict.get(key, default_value)

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

func property_value_from_string(str_value: String) -> Variant:
	if str_value.is_valid_float():
		var float_value: = float(str_value)
		if is_float_integer(float_value):
			return int(float_value)
		return float_value
	elif str_value.to_lower() in ["true", "false"]:
		return true if str_value.to_lower() == "true" else false
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

func input_vector_by_prefix(prefix: String) -> Vector2:
	prefix = prefix.trim_suffix("_")
	return Input.get_vector(prefix + "_left", prefix + "_right", prefix + "_up", prefix + "_down")

func input_event_is_dir_action(event: InputEvent, dir_actions_prefix: String) -> bool:
	if event.is_action(dir_actions_prefix + "_left"):
		return true
	elif event.is_action(dir_actions_prefix + "_right"):
		return true
	elif event.is_action(dir_actions_prefix + "_up"):
		return true
	elif event.is_action(dir_actions_prefix + "_down"):
		return true
	return false

func create_auto_repeat_delay_timer(parent_node: Node = null, delay: float = -1, repeat: float = -1, check_callable: Callable = Callable(), bind_callback: Callable = Callable()) -> RepeatDelayTimer:
	var timer: = RepeatDelayTimer.new()
	if delay > 0:
		timer.initial_delay = delay
	if repeat > 0:
		timer.repeat_delay = repeat
	if check_callable.is_valid():
		timer.set_check_hold_callable(check_callable)
	if bind_callback.is_valid():
		timer.activated.connect(bind_callback)
	if parent_node:
		parent_node.add_child(timer)
	return timer

func clamp_point_in_rect2i(point: Vector2i, rect: Rect2i) -> Vector2i:
	return point.clamp(rect.position, rect.end - Vector2i.ONE)

func clamp_point_in_rect2(point: Vector2, rect: Rect2) -> Vector2:
	return point.clamp(rect.position, rect.end)

func clamp_rect2i_in_rect2i(inner_rect: Rect2i, within_rect: Rect2i) -> Rect2i:
	var clamped_pos: = (within_rect.end - inner_rect.size).max(within_rect.position)
	var clamped_rect: = Rect2i(inner_rect.position.clamp(within_rect.position, clamped_pos), Vector2i.ONE)
	var clamped_end: = (within_rect.position + inner_rect.size).min(within_rect.end)
	clamped_rect.end = inner_rect.end.clamp(clamped_end, within_rect.end)
	return clamped_rect

func grow_rect2_by_ratio(rect: Rect2, ratio: float) -> Rect2:
	if ratio <= 0:
		return Rect2()
	var delta_size: = (rect.size * ratio - rect.size) / 2.0
	return rect.grow_individual(delta_size.x, delta_size.y, delta_size.x, delta_size.y)

func get_line_and_column_of_char_index(multi_line_text: String, character_index: int) -> Vector2i:
	if character_index < 0 or character_index > multi_line_text.length() + 1:
		push_error("Character index out of bounds: %d" % character_index)
		return Vector2i(-1, -1)
	var lines: = multi_line_text.split("\n", true)
	var cur_index: int = 0
	for line_index in lines.size():
		var line_length: int = lines[line_index].length() + 1
		if character_index < cur_index + line_length:
			return Vector2i(character_index - cur_index, line_index)
		cur_index += line_length
	return Vector2i(-1, -1)

func get_line_and_column_of_char_index_in_text_edit(text_edit: TextEdit, character_index: int) -> Vector2i:
	if character_index < 0:
		push_error("Character index out of bounds: %d" % character_index)
		return Vector2i(-1, -1)
	var cur_index: int = 0
	for line_index in text_edit.get_line_count():
		var line_length: int = text_edit.get_line(line_index).length() + 1
		if character_index < cur_index + line_length:
			return Vector2i(character_index - cur_index, line_index)
		cur_index += line_length
	push_error("Character index out of bounds: %d" % character_index)
	return Vector2i(-1, -1)

func clamp_window_within_window(clamped_window: Window, parent_window: Window) -> void:
	if not parent_window.gui_embed_subwindows:
		return
	
	var clamped_window_rect: = Rect2i(clamped_window.get_position_with_decorations(), clamped_window.get_size_with_decorations())
	var parent_window_inner: = Rect2i(Vector2i.ZERO, parent_window.size)
	set_window_rect_including_decorations(clamped_window, clamp_rect2i_in_rect2i(clamped_window_rect, parent_window_inner))

func set_window_rect_including_decorations(the_window: Window, rect: Rect2i) -> void:
	var outer_size: = the_window.get_size_with_decorations()
	var decorations_size: = (outer_size - the_window.size).min(Vector2i.ZERO)
	var outer_pos: = the_window.get_position_with_decorations()
	var decorations_offset: = outer_pos - the_window.position
	
	the_window.size = rect.size - decorations_size
	the_window.position = rect.position + decorations_offset

func is_multiline(text: String) -> bool:
	return text.contains("\n")
	
func first_line(text: String) -> String:
	return text.split("\n", true, 1)[0].replace("\r", "")

func split_lines(text: String) -> PackedStringArray:
	return text.replace("\r", "").split("\n", true)

func random_direction() -> int:
	return randi() % 4

func lerp_ok_hsl_color(from_color: Color, to_color: Color, factor: float) -> Color:
	var a: = Vector4(from_color.ok_hsl_h, from_color.ok_hsl_s, from_color.ok_hsl_l, from_color.a)
	var b: = Vector4(to_color.ok_hsl_h, to_color.ok_hsl_s, to_color.ok_hsl_l, to_color.a)
	var interpolated: = a.lerp(b, factor)
	return Color.from_ok_hsl(interpolated.x, interpolated.y, interpolated.z, interpolated.w)

func rect2i_iter(rect: Rect2i) -> Array[Vector2i]:
	rect = rect2i_pos_inclusive_abs(rect)
	var positions: Array[Vector2i] = []
	for y in rect.size.y:
		for x in rect.size.x:
			positions.append(Vector2i(x, y) + rect.position)
	return positions

## If treating a rect2i as inclusive of pos and exclusive of the last row/column, this makes the equivalent abs-sized rect.
func rect2i_pos_inclusive_abs(rect: Rect2i) -> Rect2i:
	var new_rect: = rect
	if rect.size.x < 0:
		new_rect.position.x = rect.end.x + 1
	if rect.size.y < 0:
		new_rect.position.y = rect.end.y + 1
	new_rect.size = rect.size.abs()
	return new_rect

func rect2i_from_corners_inclusive(corner_a: Vector2i, corner_b: Vector2i) -> Rect2i:
	var rect_exclusive: = Rect2i(corner_a, corner_b - corner_a).abs()
	return Rect2i(rect_exclusive.position, rect_exclusive.size + Vector2i.ONE)

func vec2i_key(vec: Vector2i) -> String:
	return "%d|%d" % [vec.x, vec.y]

func key_to_vec2i(key: String) -> Vector2i:
	if not key.contains("|"):
		push_error("Invalid vector2i key: %s" % key)
	var sp: = key.split("|", true, 1)
	return Vector2i(int(sp[0]), int(sp[1]))

func arr_add_if_not_included(arr: Array, item: Variant) -> void:
	if not item in arr:
		arr.append(item)

func arr_set_union(arr: Array, other_arr: Array) -> Array:
	var union: Array = arr.duplicate_deep()
	for item in other_arr:
		if not item in arr:
			union.append(item)
	return union

func opbtn_get_text_from_id(opbtn: OptionButton, id: int, default_value: String = "") -> String:
	for i in opbtn.get_item_count():
		if opbtn.get_item_id(i) == id:
			return opbtn.get_item_text(i)
	return default_value

func opbtn_get_index_from_id(opbtn: OptionButton, id: int) -> int:
	for i in opbtn.get_item_count():
		if opbtn.get_item_id(i) == id:
			return i
	return -1

func opbtn_get_id_from_text(opbtn: OptionButton, text: String, default_value: int = -1) -> int:
	for i in opbtn.get_item_count():
		if opbtn.get_item_text(i) == text:
			return opbtn.get_item_id(i)
	return default_value

func opbtn_get_selected_id(opbtn: OptionButton) -> int:
	return opbtn.get_item_id(opbtn.selected)

func opbtn_get_selected_text(opbtn: OptionButton) -> String:
	return opbtn.get_item_text(opbtn.selected)

func opbtn_get_index_from_text(opbtn: OptionButton, text: String) -> int:
	for i in opbtn.get_item_count():
		if opbtn.get_item_text(i) == text:
			return i
	return -1

func opbtn_has_id(opbtn: OptionButton, id: int) -> bool:
	for i in opbtn.get_item_count():
		if opbtn.get_item_id(i) == id:
			return true
	return false

func opbtn_has_text(opbtn: OptionButton, text: String) -> bool:
	for i in opbtn.get_item_count():
		if opbtn.get_item_text(i) == text:
			return true
	return false

func opbtn_set_text_for_id(opbtn: OptionButton, id: int, new_text: String) -> void:
	var index: int = opbtn_get_index_from_id(opbtn, id)
	if index >= 0:
		opbtn.set_item_text(index, new_text)

func opbtn_set_enabled_for_id(opbtn: OptionButton, id: int, is_enabled: bool) -> void:
	var index: int = opbtn_get_index_from_id(opbtn, id)
	if index >= 0:
		opbtn.set_item_disabled(index, not is_enabled)

func opbtn_select_id(opbtn: OptionButton, id: int) -> void:
	opbtn.selected = opbtn_get_index_from_id(opbtn, id)

func opbtn_select_text(opbtn: OptionButton, text: String) -> void:
	opbtn.selected = opbtn_get_index_from_text(opbtn, text)

func opbtn_enumerate_non_separator_idx(opbtn: OptionButton) -> Array[int]:
	var indices: Array[int] = []
	for i in opbtn.get_item_count():
		if not opbtn.is_item_separator(i):
			indices.append(i)
	return indices

func popupmenu_get_index_from_id(popupmenu: PopupMenu, id: int) -> int:
	for i in popupmenu.get_item_count():
		if popupmenu.get_item_id(i) == id:
			return i
	return -1

func popupmenu_set_enabled_for_id(popupmenu: PopupMenu, id: int, is_enabled: bool) -> void:
	var index: int = popupmenu_get_index_from_id(popupmenu, id)
	if index >= 0:
		popupmenu.set_item_disabled(index, not is_enabled)

func normalize_angle(angle_radians: float) -> float:
	return fposmod(angle_radians, TAU)

func valid_direction_or(direction: int, default_val: int = -1) -> int:
	if direction >= 0 and direction < 4:
		return direction
	return default_val

func double_ease_out(progress: float, ease_param: float) -> float:
	return ease(fmod(progress, 0.5) * 2, ease_param) + roundf(progress) * 0.5

func apply_vec2_interpolation(interp_style: PosInterpStyle, from: Vector2, to: Vector2, progress: float, ease_param: float = DEF_INTERP_EASE) -> Vector2:
	progress = clampf(progress, 0, 1)
	if interp_style == PosInterpStyle.CONTINUOUS_LINEAR:
		return from.lerp(to, progress)
	elif interp_style == PosInterpStyle.NONE:
		return to
	elif interp_style == PosInterpStyle.LATE_DISCRETE:
		return from if progress < 0.5 else to
	elif interp_style == PosInterpStyle.LATE_DISCRETE:
		return from if progress < 1 else to
	elif interp_style == PosInterpStyle.DOUBLE_NONE:
		return from.lerp(to, ceilf(progress * 2) * .5)
	elif interp_style == PosInterpStyle.EASE_OUT:
		return from.lerp(to, ease(progress, ease_param))
	elif interp_style == PosInterpStyle.DOUBLE_EASE_OUT:
		return from.lerp(to, double_ease_out(progress, ease_param))
	elif interp_style in [PosInterpStyle.JUMP_LINEAR, PosInterpStyle.JUMP_EASE_OUT]:
		progress = remap(progress, 0, 1, JUMP_INTERP_AMOUNT, 1)
		if interp_style == PosInterpStyle.JUMP_LINEAR:
			return from.lerp(to, progress)
		else: # interp_style == PosInterpStyle.JUMP_EASE_OUT:
			return from.lerp(to, ease(progress, ease_param))
	else:
		push_error("Unknown move interpolation style: %s" % interp_style)
		return to

func is_interp_style_smooth(interp_style: PosInterpStyle) -> bool:
	return interp_style not in NON_SMOOTH_INTERP

func vec2i_reading_order_cmp(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		return a.x < b.x
	return a.y < b.y

func get_reading_order_sorted_positions(positions: Array) -> Array[Vector2i]:
	var sorted_positions: Array[Vector2i] = []
	sorted_positions.assign(positions)
	sorted_positions.sort_custom(vec2i_reading_order_cmp)
	return sorted_positions

func next_prev_pos_reading_order(positions: Array, reference_pos: Vector2i, previous: bool = false) -> Vector2i:
	if not positions:
		return Vector2i.ZERO
	elif positions.size() == 1:
		return positions[0]
	var sorted_positions: = get_reading_order_sorted_positions(positions)
	var ref_index: int = sorted_positions.find(reference_pos)
	if ref_index == -1:
		return sorted_positions[-1 if previous else 0]
	else:
		var delta: = -1 if previous else 1
		return sorted_positions[posmod(ref_index + delta, sorted_positions.size())]

func is_vec2i_adjacent(a: Vector2i, b: Vector2i, with_diagonal: bool = false) -> bool:
	if a == b:
		return false
	var abs_delta: = (b - a).abs()
	if with_diagonal:
		return abs_delta.x <= 1 and abs_delta.y <= 1
	else:
		return abs_delta.x + abs_delta.y == 1

func check_string_start_end_contains(text: String, start_end: String, filter_text: String) -> bool:
	if not text:
		return false
	if start_end == "start":
		return text.begins_with(filter_text)
	elif start_end == "end":
		return text.ends_with(filter_text)
	else:
		return text.contains(filter_text)

func get_float_step_from_float(float_val: float, min_step: float = 0.00001) -> float:
	var snapped_val: float = snappedf(float_val, min_step)
	if is_float_integer(snapped_val) or min_step >= 1:
		return 1
	var decimals_in_step: int = -1 if min_step == 0 else step_decimals(min_step)
	var val_string: String = String.num(snapped_val, decimals_in_step)
	if not val_string.contains("."):
		return 1
	return pow(10, -len(val_string.split(".", true, 1)[1]))

func count_trailing_digits_with_zeros(float_string: String) -> int:
	float_string = float_string.strip_edges()
	if not float_string.is_valid_float() or not float_string.contains("."):
		return 0
	
	var trailing: String = float_string.split(".", true, 1)[1]
	if not trailing or not trailing.ends_with("0"):
		return 0
	return trailing.length()

func force_rerender_subviewport(subviewport: SubViewport) -> void:
	var scene_tree: = get_tree()
	var root_viewport_rid: = scene_tree.root.get_viewport_rid()
	# breaks if I disable the main viewport rendering, maybe because the subviewport container fucks with the size
	#RenderingServer.viewport_set_active(root_viewport_rid, false)
	
	if subviewport.render_target_update_mode != SubViewport.UPDATE_ALWAYS:
		RenderingServer.viewport_set_update_mode(subviewport.get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ONCE)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	
	#RenderingServer.viewport_set_active(root_viewport_rid, true)

func event_is_menu_back_just_pressed(event: InputEvent) -> bool:
	if fixed_just_pressed_by_event("escape", event):
		return true
	if fixed_just_pressed_by_event("controller_menu_back", event):
		return true
	return false

func get_wav_stream_total_samples(wav_stream: AudioStreamWAV) -> int:
	return roundi(wav_stream.get_length() * wav_stream.sample_rate)

func int_with_commas(value: int) -> String:
	var chars: = str(value)
	var result: String = ""
	while chars.length() > 3:
		result = "," + chars.right(3) + result
		chars = chars.substr(0, chars.length() - 3)
	return chars + result

func get_rect2i_border_in_facing_direction(rect: Rect2i, direction: int) -> Rect2i:
	if direction == 0:
		return Rect2i(rect.position, Vector2i(rect.size.x, 1))
	elif direction == 3:
		return Rect2i(rect.position, Vector2i(1, rect.size.y))
	elif direction == 1:
		return Rect2i(rect.end.x - 1, rect.position.y, 1, rect.size.y)
	elif direction == 2:
		return Rect2i(rect.position.x, rect.end.y - 1, rect.size.x, 1)
	return Rect2i()

func filter_positions_in_rect(positions: Array[Vector2i], rect: Rect2i) -> Array[Vector2i]:
	rect = rect.abs()
	var filtered_positions: Array[Vector2i] = []
	for pos in positions:
		if rect.has_point(pos):
			filtered_positions.append(pos)
	return filtered_positions

func filter_positions_furthest_in_direction(positions: Array[Vector2i], direction: int) -> Array[Vector2i]:
	if not positions:
		return []
	var check_axis: int = 1 if direction == 0 or direction == 2 else 0
	var check_sign: int = 1 if direction == 1 or direction == 2 else -1
	var max_coord: int = positions[0][check_axis] * check_sign
	for pos in positions:
		var coord: int = pos[check_axis] * check_sign
		max_coord = maxi(max_coord, coord)
	var filtered_positions: Array[Vector2i] = []
	for pos in positions:
		if pos[check_axis] * check_sign == max_coord:
			filtered_positions.append(pos)
	return filtered_positions

func facing_to_rect_side(facing: int) -> int:
	if facing == 0:
		return SIDE_TOP
	elif facing == 1:
		return SIDE_RIGHT
	elif facing == 2:
		return SIDE_BOTTOM
	elif facing == 3:
		return SIDE_LEFT
	return -1

func rect2i_opposite_inner_corner(rect: Rect2i, corner: Vector2i) -> Vector2i:
	var clamped_corner: = clamp_point_in_rect2i(corner, rect)
	var inner_end: = rect.end - Vector2i.ONE
	var opposite_corner: = rect.position
	if clamped_corner.x != inner_end.x:
		opposite_corner.x = inner_end.x
	if clamped_corner.y != inner_end.y:
		opposite_corner.y = inner_end.y
	return opposite_corner


