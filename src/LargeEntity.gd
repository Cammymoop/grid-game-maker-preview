extends BaseEntity
class_name LargeEntity

#var shape: Rect2 = Rect2(0, 0, 2, 2)
var entity_size: Vector2 = Vector2(2, 2)
var use_mask: bool = false
var shape_mask: Dictionary[Vector2, bool] = {}

func _ready() -> void:
	super._ready()
	#var grid_size = Vector2(MapManager.tile_width, MapManager.tile_width)

func update_sprite_pos_scale() -> void:
	sprite.position = Vector2(MapManager.tile_width * entity_size.x, MapManager.tile_width * entity_size.y) / 2
	if EntityManager.get_entity_prop_with_default(self, "auto_scale", true):
		sprite.scale = entity_size
	else:
		sprite.scale = Vector2.ONE

func serialize() -> Dictionary:
	var serialized = super.serialize()
	serialized["entity_class"] = "LargeEntity"
	return serialized

func is_at_multiple(check_positions: Array[Vector2i], include_moving_away: bool = false) -> bool:
	var my_positions: = get_positions_at(tile_position)
	var moving_pos_offset: = Vector2i(next_tile_pos - tile_position)
	for check_pos in check_positions:
		if check_pos in my_positions:
			return true
		if include_moving_away and check_pos - moving_pos_offset in my_positions:
			return true
	return false

func is_at(check_position: Vector2i, include_moving_away: bool = false) -> bool:
	if moving:
		if is_at_relative(check_position - Vector2i(next_tile_pos)):
			return true
		elif not include_moving_away:
			return false
	
	return is_at_relative(check_position - Vector2i(tile_position))

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

func get_frontier(in_facing_dir: int) -> Dictionary:
	var from_positions: = get_positions_at(tile_position)
	var to_positions: = get_positions_at(tile_position + Utility.facing_vector(in_facing_dir))
	var fromtier: Array[Vector2i] = []
	var frontier: Array[Vector2i] = []
	for from_pos in from_positions:
		if from_pos not in to_positions:
			fromtier.append(from_pos)
	for to_pos in to_positions:
		if to_pos not in from_positions:
			frontier.append(to_pos)
	return {to = frontier, from = fromtier}

# Override start_move because I'm too thicc
func start_move(in_facing_dir: int, change_visual_facing: bool = true, group_move: bool = false) -> bool:
	if moving:
		push_warning("Tried to start move when already moving")
		return false
	if get_steps_per_tile() <= 0:
		return false

	if change_visual_facing and visual_turn_on_move:
		set_facing(in_facing_dir)
	set_move_facing(in_facing_dir)
	
	if not group_move and bond_group:
		# TODO entity managers bond group move checking doesnt take large entities into account yet
		return EntityManager.bond_group_start_move(bond_group, get_steps_per_tile(), in_facing_dir)
	
	next_tile_pos = tile_position + Utility.facing_vector(in_facing_dir)
	var not_stopped = true
	
	var frontier = get_frontier(in_facing_dir)
	for moving_to in frontier.to:
		not_stopped = not_stopped and MapManager.attempt_move(self, moving_to, group_move)
	
	if not_stopped:
		moving = true
		steps_remaining = get_steps_per_tile()
		if not bond_group:
			# during a bonded move, entity manager handles calling post_move_actions and actually_started_move
			# they wont get called unless the move succeeds
			EntityManager.post_move_multi_pos(self, frontier.from, frontier.to, bond_group)
			actually_started_move()
		else:
			emit_signal("started_move")
		_move_bump_check()
		return true
	else:
		next_tile_pos = tile_position
		emit_signal("blocked")
		return false

func process_finish_move() -> void:
	var frontier = get_frontier(move_facing)
	MapManager.finish_move(self, frontier.to)
