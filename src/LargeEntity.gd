extends BaseEntity
class_name LargeEntity

#var shape: Rect2 = Rect2(0, 0, 2, 2)
var entity_size: Vector2 = Vector2(2, 2)

# At least for now in 3.0 parent class _ready is auto called before this
func _ready() -> void:
	#var grid_size = Vector2(MapManager.tile_width, MapManager.tile_width)
	$Sprite2D.position = Vector2(MapManager.tile_width * entity_size.x, MapManager.tile_width * entity_size.y) / 2
	$Sprite2D.scale = entity_size

func serialize() -> Dictionary:
	var serialized = super.serialize()
	serialized["entity_class"] = "LargeEntity"
	return serialized

func is_at(check_position: Vector2) -> bool:
	var at_pos = tile_position
	if moving:
		at_pos = next_tile_pos
	
	if check_position.x >= at_pos.x and check_position.x < at_pos.x + entity_size.x:
		if check_position.y >= at_pos.y and check_position.y < at_pos.y + entity_size.y:
			return true
	return false

func get_frontier(in_facing: int) -> Dictionary:
	var frontier = []
	var fromtier = []
	if in_facing == 1 or in_facing == 3:
		var x = -1 if in_facing == 3 else int(entity_size.x)
		var x2 = int(entity_size.x - 1) if in_facing == 3 else 0
		for y in range(0, entity_size.y):
			frontier.append(tile_position + Vector2(x, y))
			fromtier.append(tile_position + Vector2(x2, y))
	elif in_facing == 0 or in_facing == 2:
		var y = -1 if in_facing == 0 else int(entity_size.y)
		var y2 = int(entity_size.y - 1) if in_facing == 0 else 0
		for x in range(0, entity_size.x):
			frontier.append(tile_position + Vector2(x, y))
			fromtier.append(tile_position + Vector2(x, y2))
	return {to = frontier, from = fromtier}

# Override start_move because I'm too thicc
func start_move(move_facing, change_visual_facing=true, group_move=false) -> bool:
	if moving:
		print_debug("Tried to start move when already moving")
		return false
	if change_visual_facing and visual_turn_on_move:
		set_visual_facing(move_facing)
	set_facing(move_facing)
	
	if current_move_speed > 0:
		if not group_move and bond_group:
			# TODO entity managers bond group move checking doesnt take large entities into account yet
			return EntityManager.bond_group_start_move(bond_group, steps_per_tile, move_facing)
		
		next_tile_pos = tile_position + Utility.facing_vector(facing)
		var not_stopped = true
		
		var frontier = get_frontier(move_facing)
		for moving_to in frontier.to:
			not_stopped = not_stopped and MapManager.attempt_move(self, moving_to, group_move)
		
		if not_stopped:
			moving = true
			steps_remaining = steps_per_tile
			if not bond_group:
				# during a bonded move, entity manager handles calling post_move_actions and actually_started_move
				# they wont get called unless the move succeeds
				for i in range(len(frontier.to)):
					EntityManager.post_move_actions(self, frontier.from[i], frontier.to[i])
				actually_started_move()
			else:
				emit_signal("started_move")
			return true
		else:
			next_tile_pos = tile_position
			emit_signal("blocked")
			return false
	return false

func finish_move() -> void:
	position = Vector2(int(round(position.x)), int(round(position.y)))
	#tile_position = next_tile_pos
	var frontier = get_frontier(facing)
	tile_position = MapManager.world_to_tile_position(global_position)
	emit_signal("finished_move")
	if tile_position != next_tile_pos:
		print_debug("???")
	moving = false
	
	for moved_to in frontier.to:
		MapManager.finish_move(self, moved_to)
