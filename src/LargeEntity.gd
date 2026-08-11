extends BaseEntity
class_name LargeEntity

#var shape: Rect2 = Rect2(0, 0, 2, 2)
var entity_size: Vector2 = Vector2(2, 2)
var use_mask: bool = false
var shape_mask: Dictionary[Vector2i, bool] = {}

var _move_was_facing: int = -1

func _ready() -> void:
	super._ready()
	#var grid_size = Vector2(MapManager.tile_width, MapManager.tile_width)

func set_default_mask() -> void:
	shape_mask.clear()
	for y in int(entity_size.y):
		for x in int(entity_size.x):
			shape_mask[Vector2i(x, y)] = true

func get_oriented_size() -> Vector2i:
	if facing % 2 == 0:
		return Vector2i(entity_size)
	else:
		return Vector2i(entity_size.y, entity_size.x)

func get_oriented_half_size() -> Vector2:
	return (get_oriented_size() * MapManager.tile_width) * 0.5

func get_half_size() -> Vector2:
	return (entity_size * MapManager.tile_width) * 0.5

func get_default_size() -> Vector2:
	return EntityManager.get_default_size_for_entity(entity_index)

func is_default_size() -> bool:
	return entity_size == get_default_size()

func update_sprite_pos_scale(immediate: bool = true, tile_pos_delta: Vector2i = Vector2i.ZERO) -> void:
	var is_auto_scale: bool = EntityManager.get_entity_prop_with_default(self, "auto-scale", true)
	if not immediate and is_auto_scale and sprite.interpolate_size_change_enabled:
		sprite.set_large_size_with_position_and_interpolation(entity_size, tile_pos_delta)
		return
	prints("immediate param:", immediate, "sprite interp enabled:", sprite.interpolate_size_change_enabled)
	prints("updating sprite pos scale (immediate), size:", entity_size, "is auto scale:", is_auto_scale)

	sprite.set_large_auto_scale(is_auto_scale, entity_size)
	sprite.set_sprite_size(entity_size * MapManager.tile_width)

func _serialize_shape_mask() -> Dictionary:
	var serialized_shape_mask: Dictionary = {}
	for offset in shape_mask.keys():
		var offset_key: = "%d:%d" % [offset.x, offset.y]
		serialized_shape_mask[offset_key] = shape_mask[offset]
	return serialized_shape_mask

func _deserialize_shape_mask(serialized_shape_mask: Dictionary) -> Dictionary[Vector2i, bool]:
	var deserialized_shape_mask: Dictionary[Vector2i, bool] = {}
	for offset_key in serialized_shape_mask.keys():
		var offset: Vector2i = Vector2i(offset_key.split(":")[0], offset_key.split(":")[1])
		deserialized_shape_mask[offset] = serialized_shape_mask[offset_key]
	return deserialized_shape_mask

func serialize(static_mode: bool = false) -> Dictionary:
	var serialized = super.serialize(static_mode)
	serialized["can_be_large"] = true
	serialized["entity_size"] = Utility.get_arr_from_vector2(entity_size)
	serialized["use_mask"] = use_mask
	serialized["shape_mask"] = _serialize_shape_mask()
	serialized["move_was_facing"] = _move_was_facing
	return serialized

func shrink_in_direction(in_facing_dir: int, is_relative: bool, amount: int, immediate: bool = false) -> void:
	set_size_in_direction(in_facing_dir, is_relative, -amount, immediate)

func grow_in_direction(in_facing_dir: int, is_relative: bool, amount: int, immediate: bool = false) -> void:
	set_size_in_direction(in_facing_dir, is_relative, amount, immediate)

func set_size_in_direction(in_facing_dir: int, is_relative: bool, amount: int, immediate: bool = false) -> void:
	var size_axis: = 1 if in_facing_dir == 0 or in_facing_dir == 2 else 0
	var oriented_size: = get_oriented_size()
	var old_size: = int(oriented_size[size_axis])
	var new_size: = amount
	if is_relative:
		new_size = old_size + amount
	new_size = maxi(new_size, 1)

	if new_size == old_size or in_facing_dir < 0:
		return
	
	var current_rect: = get_pos_rect_at(get_moving_position())
	var new_rect: = current_rect.grow_side(Utility.facing_to_rect_side(in_facing_dir), new_size - old_size)
	update_position_and_size(new_rect.position, new_rect.size, immediate)

func update_size(new_size: Vector2i, is_oriented: bool = true, immediate: bool = true, tile_pos_delta: Vector2i = Vector2i.ZERO) -> void:
	if is_oriented:
		_update_oriented_size(new_size, immediate, tile_pos_delta)
	else:
		_update_size(new_size, immediate, tile_pos_delta)

func _update_size(new_size: Vector2i, immediate: bool, tile_pos_delta: Vector2i) -> void:
	entity_size = new_size
	# TODO preserve mask more
	use_mask = false
	set_default_mask()
	if sprite:
		update_sprite_pos_scale(immediate, tile_pos_delta)

func _update_oriented_size(new_size: Vector2i, immediate: bool, tile_pos_delta: Vector2i) -> void:
	if facing % 2 == 0:
		entity_size = Vector2(new_size)
	else:
		entity_size = Vector2(new_size.y, new_size.x)
	prints("updated oriented size:", entity_size)
	# TODO preserve mask more
	use_mask = false
	set_default_mask()
	if sprite:
		update_sprite_pos_scale(immediate, tile_pos_delta)
	
func update_size_by_corners(corner_a: Vector2i, corner_b: Vector2i, immediate: bool = true) -> void:
	var new_size_rect: = Utility.rect2i_from_corners_inclusive(corner_a, corner_b)
	#prints("updating size by corners, old size rect:", Rect2i(tile_position, entity_size), "new size rect:", new_size_rect)
	update_position_and_size(new_size_rect.position, new_size_rect.size, immediate)

func update_position_and_size(new_position: Vector2i, new_size: Vector2i, immediate: bool = true) -> void:
	prints("updating position and size, new position:", new_position, "new size:", new_size)
	var delta_pos: = new_position - get_moving_position()
	if delta_pos == Vector2i.ZERO:
		update_size(new_size, true, immediate)
		return
	if moving:
		immediate = true
		next_tile_pos += delta_pos
		interpolate_pos()
	else:
		tile_position += delta_pos
		next_tile_pos = tile_position
		position = MapManager.tile_to_world_position(tile_position)
	update_size(new_size, true, immediate, delta_pos)



func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	entity_size = Utility.get_vector2_from_arr(data.get("entity_size", [1, 1]))
	use_mask = data.get("use_mask", false)
	if use_mask:
		shape_mask = _deserialize_shape_mask(data.get("shape_mask", {}))
	else:
		set_default_mask()
	if sprite:
		update_sprite_pos_scale()
	if "move_was_facing" in data:
		_move_was_facing = int(data["move_was_facing"])

func is_at_multiple(check_positions: Array[Vector2i], include_moving_away: bool = false) -> bool:
	var my_positions: = get_positions_at(tile_position)
	var moving_pos_offset: = next_tile_pos - tile_position
	for check_pos in check_positions:
		if check_pos in my_positions:
			return true
		if include_moving_away and check_pos - moving_pos_offset in my_positions:
			return true
	return false

func is_at(check_position: Vector2i, include_moving_away: bool = false) -> bool:
	if moving:
		if is_at_relative(check_position - next_tile_pos):
			return true
		elif not include_moving_away:
			return false
	
	return is_at_relative(check_position - tile_position)

func is_half_at(check_position: Vector2i) -> bool:
	if not moving or _pending_half_move:
		return is_at_relative(check_position - tile_position)
	return is_at_relative(check_position - next_tile_pos)

func is_at_relative(check_relative: Vector2i) -> bool:
	if use_mask:
		return check_mask(check_relative)
	else:
		return check_relative.x >= 0 and check_relative.x < entity_size.x and check_relative.y >= 0 and check_relative.y < entity_size.y

func check_mask(check_offset: Vector2i, with_facing: int = -1) -> bool:
	if with_facing < 0:
		with_facing = facing
	return shape_mask.get(mask_offset_rotated_by(check_offset, with_facing), false)

func mask_offset_rotated_by(offset: Vector2i, by_facing: int) -> Vector2i:
	if by_facing == 0 or entity_size == Vector2.ONE:
		return offset
	if by_facing == 2 or by_facing == 3:
		var symmetric_pivot: = (entity_size / 2) - Vector2(.5, .5)
		offset = Vector2i((Vector2(offset) - symmetric_pivot).rotated(TAU/2) + symmetric_pivot)

	if by_facing == 2:
		return offset
	else:
		var max_square: = maxf(entity_size.x, entity_size.y)
		var odd_pivot: = (Vector2.ONE * max_square / 2) - Vector2(.5, .5)
		return Vector2i((Vector2(offset) - odd_pivot).rotated(TAU/4) + odd_pivot)

func _oriented_size_for_facing(with_facing: int) -> Vector2i:
	return Utility.get_transposed_v2(entity_size) if with_facing % 2 == 1 else entity_size

func get_positions_at(at_tile_position: Vector2i, with_facing: int = -1) -> Array[Vector2i]:
	if with_facing < 0:
		with_facing = facing
	var check_size: = _oriented_size_for_facing(with_facing)
	var base_positions: = Utility.get_width_height_position_list(check_size.x, check_size.y)
	var offset_positions: Array[Vector2i] = []
	for base_pos in base_positions:
		if not use_mask or check_mask(base_pos, with_facing):
			offset_positions.append(at_tile_position + base_pos)
	return offset_positions

func get_pos_rect_at(at_tile_position: Vector2i) -> Rect2i:
	return Rect2i(at_tile_position, Vector2i(entity_size))

func get_auto_frontier(is_teleport: bool, from_tile_pos: Vector2i, to_tile_pos: Vector2i, in_facing_dir: int) -> Dictionary[String, Array]:
	if is_teleport:
		return get_teleport_frontier(from_tile_pos, to_tile_pos, in_facing_dir)
	else:
		return get_frontier(in_facing_dir)

func get_frontier(in_facing_dir: int) -> Dictionary[String, Array]:
	return _get_frontier(tile_position, tile_position + Utility.facing_vector_i(in_facing_dir))

func get_teleport_frontier(from_tile_pos: Vector2i, to_tile_pos: Vector2i, to_facing: int = -1) -> Dictionary[String, Array]:
	return _get_frontier(from_tile_pos, to_tile_pos, facing, to_facing)

func get_current_move_frontier() -> Dictionary[String, Array]:
	if not moving:
		return {}
	return _get_frontier(tile_position, next_tile_pos, _move_was_facing)

func _get_frontier(from_tile_pos: Vector2i, to_tile_pos: Vector2i, from_facing: int = -1, to_facing: int = -1) -> Dictionary[String, Array]:
	if to_facing < 0:
		to_facing = facing
	if from_facing < 0:
		if moving:
			from_facing = _move_was_facing
		else:
			from_facing = facing
	var from_positions: = get_positions_at(from_tile_pos, from_facing)
	var to_positions: = get_positions_at(to_tile_pos, to_facing)
	var a_v2i: Array[Vector2i] = []
	var frontier: Dictionary[String, Array] = {"from": a_v2i.duplicate(), "to": a_v2i}
	for from_pos in from_positions:
		if from_pos not in to_positions:
			frontier.from.append(from_pos)
	for to_pos in to_positions:
		if to_pos not in from_positions:
			frontier.to.append(to_pos)
	return frontier

func is_square_aspect() -> bool:
	return entity_size.x == entity_size.y

# Override start_move because I'm too thicc
func start_move(in_facing_dir: int, change_visual_facing: bool = true, group_move: bool = false, is_revertable: bool = false) -> bool:
	if moving or get_steps_per_tile() <= 0:
		return false
	if change_visual_facing and visual_turn_on_move and is_square_aspect():
		set_facing(in_facing_dir)
	set_move_facing(in_facing_dir)
	
	if not group_move and bond_group:
		# TODO entity managers bond group move checking doesnt take large entities into account yet
		return EntityManager.bond_group_start_move(bond_group, get_steps_per_tile(), in_facing_dir, is_revertable)
	
	var to_pos: = tile_position + Utility.facing_vector_i(in_facing_dir)
	return _start_move_common(to_pos, group_move, false, is_revertable)

func start_teleport_to(from_pos: Vector2i, to_pos: Vector2i, override_move_facing: int = -1, override_facing: int = -1, group_move: bool = false, override_steps: int = -1, is_revertable: bool = false) -> bool:
	if moving:
		return false
	
	var from_delta: = from_pos - tile_position

	var implicit_facing: = _get_teleport_implicit_facing(from_pos, to_pos)
	if override_move_facing == -2:
		override_move_facing = move_facing
	set_move_facing(implicit_facing if override_move_facing == -1 else override_move_facing)

	var teleport_dependant_facing: int = -1
	if override_facing >= 0:
		teleport_dependant_facing = override_facing
	elif override_facing == -1:
		teleport_dependant_facing = implicit_facing

	if teleport_dependant_facing == facing:
		teleport_dependant_facing = -1
	
	if override_steps > 0:
		set_steps_per_tile_override(override_steps)
	
	if not group_move and bond_group:
		return EntityManager.bond_group_start_teleport(bond_group, get_teleport_steps(), move_facing)
	
	# where to set tile_position to
	var base_to_pos: = to_pos - from_delta
	
	return _start_move_common(base_to_pos, group_move, true, is_revertable, teleport_dependant_facing)
	
func _start_move_common(to_pos: Vector2i, is_group_move: bool, is_teleport: bool, is_revertable: bool, change_facing_to: int = -1) -> bool:
	var related_move_node: = EntityManager.track_move_starting(self, is_group_move, is_revertable)
	_currently_starting_move = true
	_current_starting_move_facing = move_facing
	
	var facing_to_check: int = move_facing
	if is_teleport:
		if change_facing_to >= 0:
			facing_to_check = change_facing_to
		else:
			facing_to_check = facing

	var frontier: Dictionary[String, Array] = get_auto_frontier(is_teleport, tile_position, to_pos, facing_to_check)

	var force_immediate_turn: = false
	if change_facing_to >= 0 and sprite.interpolate_facing_enabled:
		if not Utility.is_interp_style_smooth(get_teleport_interp_style(_is_diagonal_adj(tile_position, to_pos))):
			force_immediate_turn = true
	var result: = MapManager.attempt_move(self, frontier.from, frontier.to, to_pos, is_group_move, change_facing_to, force_immediate_turn)
	
	if result:
		moving = true
		_from_tile_pos = tile_position
		next_tile_pos = to_pos
		invalidate_cached_at_position(frontier.from)
		_pending_half_move = true
		steps_remaining = get_teleport_steps() if is_teleport else get_steps_per_tile()
		_this_move_steps = steps_remaining
		_this_move_is_teleport = is_teleport
		if not bond_group:
			EntityManager.post_move_multi_pos(self, frontier.from, frontier.to)
			actually_started_move()
		_move_bump_check()
	else:
		next_tile_pos = tile_position
		emit_signal("blocked")
	
	EntityManager.just_finished_move_start(related_move_node, result)
	_currently_starting_move = false
	_current_starting_move_facing = -1
	return result

func can_i_move(at_facing: int) -> bool:
	if moving:
		return false

	var frontier: = get_frontier(at_facing)
	# temporarily face the movement direction, so that blocking conditionals can read it
	var old_move_facing = move_facing
	set_move_facing(at_facing)
	var result = MapManager.can_move_to_multiple(self, frontier.to)
	set_move_facing(old_move_facing)
	
	return result

func can_i_teleport_to(from_pos: Vector2i, to_pos: Vector2i, with_move_facing: int = -1, with_facing: int = -2) -> bool:
	var old_move_facing = move_facing
	var implicit_facing: = _get_teleport_implicit_facing(from_pos, to_pos)

	var check_facing: int = with_facing
	if with_facing == -1:
		check_facing = implicit_facing
	elif with_facing == -2:
		check_facing = -1

	if with_move_facing >= 0:
		set_move_facing(with_move_facing)
	elif with_move_facing == -1:
		set_move_facing(implicit_facing)
	
	var to_base_pos: = to_pos - (from_pos - tile_position)
	var frontier: = get_teleport_frontier(tile_position, to_base_pos, check_facing)

	var result: = MapManager.can_move_to_multiple(self, frontier.to)
	set_move_facing(old_move_facing)
	return result

func _find_teleport_fixed_point(from_facing: int, to_facing: int, to_pos: Vector2i) -> Vector2:
	if from_facing == to_facing:
		return Vector2.ZERO
	
	var from_size: = _oriented_size_for_facing(from_facing)
	var to_size: = _oriented_size_for_facing(to_facing)
	
	var tile_space_from_center: = Vector2(tile_position) + (Vector2(from_size) / 2)
	var tile_space_to_center: = Vector2(to_pos) + (Vector2(to_size) / 2)
	var tile_space_translation: = tile_space_to_center - tile_space_from_center

	# return fixed point relative to to_pos
	var fp_relative_to_from: = Utility.get_fixed_point_of_orthogonal_translate_rotate(tile_space_translation, from_facing, to_facing)
	return (fp_relative_to_from - tile_space_from_center) - Vector2(to_pos)

func process_finish_move() -> void:
	var frontier = _get_frontier(_from_tile_pos, next_tile_pos)
	MapManager.finish_move(self, frontier.to)

func is_large() -> bool:
	return entity_size.x > 1 or entity_size.y > 1

# WIP
func apply_teleport_facing_change(to_pos: Vector2i, new_facing: int, immediate: bool) -> void:
	if new_facing == facing or is_square_aspect() or not sprite.interpolate_facing_enabled:
		set_facing(new_facing, immediate)
		return
	var no_rotate = EntityManager.get_entity_property(self, "no-rotate")
	if no_rotate != null and no_rotate.get_value():
		return
	
	#var is_smooth_move_interp: = Utility.is_interp_style_smooth(get_teleport_interp_style(_is_diagonal_adj(tile_position, to_pos)))
	
	# fixed point is relative to new position
	var fixed_point: = _find_teleport_fixed_point(facing, new_facing, to_pos) * MapManager.tile_width
	sprite.set_sprite_facing_with_fixed_point(new_facing, fixed_point, immediate)