extends BaseEntity
class_name LargeEntity

#var shape: Rect2 = Rect2(0, 0, 2, 2)
var entity_size: Vector2 = Vector2(2, 2)
var use_mask: bool = false
var shape_mask: Dictionary[Vector2i, bool] = {}

func _ready() -> void:
	super._ready()
	#var grid_size = Vector2(MapManager.tile_width, MapManager.tile_width)

func set_default_mask() -> void:
	shape_mask.clear()
	for y in int(entity_size.y):
		for x in int(entity_size.x):
			shape_mask[Vector2i(x, y)] = true

func get_half_size() -> Vector2:
	return (entity_size * MapManager.tile_width) * 0.5

func update_sprite_pos_scale() -> void:
	sprite.position = Vector2(MapManager.tile_width * entity_size.x, MapManager.tile_width * entity_size.y) / 2
	if EntityManager.get_entity_prop_with_default(self, "auto-scale", true):
		sprite.scale = entity_size
	else:
		sprite.scale = Vector2.ONE

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

func serialize() -> Dictionary:
	var serialized = super.serialize()
	serialized["can_be_large"] = true
	serialized["entity_size"] = Utility.get_arr_from_vector2(entity_size)
	serialized["use_mask"] = use_mask
	serialized["shape_mask"] = _serialize_shape_mask()
	return serialized

func shrink_in_direction(in_facing_dir: int, is_relative: bool, amount: int) -> void:
	set_size_in_direction(in_facing_dir, is_relative, -amount)

func grow_in_direction(in_facing_dir: int, is_relative: bool, amount: int) -> void:
	set_size_in_direction(in_facing_dir, is_relative, amount)

func set_size_in_direction(in_facing_dir: int, is_relative: bool, amount: int) -> void:
	var size_axis: = 1 if in_facing_dir == 0 or in_facing_dir == 2 else 0
	var old_size: = int(entity_size[size_axis])
	var new_size: = amount
	if is_relative:
		new_size = old_size + amount
	new_size = maxi(new_size, 1)

	if new_size == old_size or in_facing_dir < 0:
		return
	
	var current_rect: = get_pos_rect_at(get_moving_position())
	var new_rect: = current_rect.grow_side(Utility.facing_to_rect_side(in_facing_dir), new_size - old_size)
	update_position_and_size(new_rect.position, new_rect.size)

func update_size(new_size: Vector2i) -> void:
	_update_size(new_size)

func _update_size(new_size: Vector2i) -> void:
	entity_size = new_size
	# TODO preserve mask more
	use_mask = false
	set_default_mask()
	if sprite:
		update_sprite_pos_scale()
	
func update_size_by_corners(corner_a: Vector2i, corner_b: Vector2i) -> void:
	var new_size_rect: = Utility.rect2i_from_corners_inclusive(corner_a, corner_b)
	#prints("updating size by corners, old size rect:", Rect2i(tile_position, entity_size), "new size rect:", new_size_rect)
	update_position_and_size(new_size_rect.position, new_size_rect.size)

func update_position_and_size(new_position: Vector2i, new_size: Vector2i) -> void:
	var delta_pos: = new_position - get_moving_position()
	if delta_pos == Vector2i.ZERO:
		update_size(new_size)
		return
	if moving:
		next_tile_pos += delta_pos
	else:
		tile_position += delta_pos
		next_tile_pos = tile_position
		position = MapManager.tile_to_world_position(tile_position)
	_update_size(new_size)



func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	entity_size = Utility.get_vector2_from_arr(data.get("entity_size", [2, 2]))
	use_mask = data.get("use_mask", false)
	if use_mask:
		shape_mask = _deserialize_shape_mask(data.get("shape_mask", {}))
	else:
		set_default_mask()
	if sprite:
		update_sprite_pos_scale()

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

func check_mask(check_offset: Vector2i) -> bool:
	return shape_mask.get(mask_offset_rotated_by(check_offset, facing), false)

func mask_offset_rotated_by(offset: Vector2i, by_facing: int) -> Vector2i:
	if by_facing == 0 or entity_size == Vector2.ONE:
		return offset
	var mask_pivot: = entity_size / 2 - Vector2(.5, .5)
	var radians: = Utility.facing_rotation(by_facing)
	return Vector2i((Vector2(offset) - mask_pivot).rotated(radians) + mask_pivot)

func get_positions_at(at_tile_position: Vector2i) -> Array[Vector2i]:
	var base_positions: = Utility.get_width_height_position_list(entity_size.x, entity_size.y)
	var offset_positions: Array[Vector2i] = []
	for base_pos in base_positions:
		if not use_mask or check_mask(base_pos):
			offset_positions.append(at_tile_position + base_pos)
	return offset_positions

func get_pos_rect_at(at_tile_position: Vector2i) -> Rect2i:
	return Rect2i(at_tile_position, Vector2i(entity_size))

func get_auto_frontier(is_teleport: bool, from_tile_pos: Vector2i, to_tile_pos: Vector2i, in_facing_dir: int) -> Dictionary[String, Array]:
	if is_teleport:
		return get_teleport_frontier(from_tile_pos, to_tile_pos)
	else:
		return get_frontier(in_facing_dir)

func get_frontier(in_facing_dir: int) -> Dictionary[String, Array]:
	return _get_frontier(tile_position, tile_position + Utility.facing_vector_i(in_facing_dir))

func get_teleport_frontier(from_tile_pos: Vector2i, to_tile_pos: Vector2i) -> Dictionary[String, Array]:
	return _get_frontier(from_tile_pos, to_tile_pos)

func get_current_move_frontier() -> Dictionary[String, Array]:
	if not moving:
		return {}
	return _get_frontier(tile_position, next_tile_pos)

func _get_frontier(from_tile_pos: Vector2i, to_tile_pos: Vector2i) -> Dictionary[String, Array]:
	var from_positions: = get_positions_at(from_tile_pos)
	var to_positions: = get_positions_at(to_tile_pos)
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

	if override_facing == -2:
		override_facing = facing
	var set_facing_to: = implicit_facing if override_facing == -1 else override_facing
	if set_facing_to != facing:
		var do_turn_interp: = sprite.interpolate_facing_enabled
		if not Utility.is_interp_style_smooth(get_teleport_interp_style(_is_diagonal_adj(from_pos, to_pos))):
			do_turn_interp = false
		set_facing(set_facing_to, not do_turn_interp)
	
	if override_steps > 0:
		set_steps_per_tile_override(override_steps)
	
	if not group_move and bond_group:
		return EntityManager.bond_group_start_teleport(bond_group, get_teleport_steps(), move_facing)
	
	# where to set tile_position to
	var base_to_pos: = to_pos - from_delta
	
	return _start_move_common(base_to_pos, group_move, true, is_revertable)
	
func _start_move_common(to_pos: Vector2i, is_group_move: bool, is_teleport: bool, is_revertable: bool) -> bool:
	var related_move_node: = EntityManager.track_move_starting(self, is_group_move, is_revertable)
	_currently_starting_move = true
	_current_starting_move_facing = move_facing
	
	var frontier: Dictionary[String, Array] = get_auto_frontier(is_teleport, tile_position, to_pos, move_facing)
	var result: = MapManager.attempt_move(self, frontier.from, frontier.to, is_group_move)
	
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
			EntityManager.post_move_multi_pos(self, frontier.from, frontier.to, bond_group)
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

func can_i_teleport_to(from_pos: Vector2i, to_pos: Vector2i, with_facing: int = -1, with_move_facing: int = -1) -> bool:
	var old_facing = facing
	var old_move_facing = move_facing
	if with_facing != -1:
		facing = with_facing
	elif with_facing != -2:
		facing = _get_teleport_implicit_facing(from_pos, to_pos)
	if with_move_facing != -1:
		set_move_facing(with_move_facing)
	elif with_move_facing != -2:
		set_move_facing(_get_teleport_implicit_facing(from_pos, to_pos))
	
	var to_base_pos: = to_pos - (from_pos - tile_position)
	var frontier: = get_teleport_frontier(tile_position, to_base_pos)

	var result: = MapManager.can_move_to_multiple(self, frontier.to)
	facing = old_facing
	set_move_facing(old_move_facing)
	return result

func process_finish_move() -> void:
	var frontier = _get_frontier(_from_tile_pos, next_tile_pos)
	MapManager.finish_move(self, frontier.to)

func is_large() -> bool:
	return entity_size.x > 1 or entity_size.y > 1