extends Node2D
class_name BaseEntity

signal started_move
signal finished_move
signal blocked

var facing: = 0
var visual_facing: = 0

var visual_turn_on_move: = true

var moving: = false
var just_moved: = false
var steps_remaining: int = 0

var sprite: MaskLayerSprite

# tiles per second
var current_move_speed: float = 0
var steps_per_tile: int = 0
var self_steps_per_tile: int = 0

var controller: Node = null
var controller_name: String = ""

var tile_position = Vector2(0, 0)
var next_tile_pos = Vector2(0, 0)

var entity_index: int = 0
var entity_name: String = ""

var bond_group: Array = []
var tailing: Node = null

var has_idle_update_conditional: = false
var idle_update_cache: Property = null
var idle_update_sleep: int = 1

var active: = false

var local_properties: = {}

var instance_id: int = 0

func _ready() -> void:
	pre_init()
	setup_initial_position()

func _make_sprite() -> void:
	if sprite:
		return
	sprite = MaskLayerSprite.new()
	add_child(sprite, true)

func pre_init() -> void:
	entity_name = EntityManager.get_entity_name(entity_index)
	_make_sprite()
	offset_center()

func setup_initial_position() -> void:
	tile_position = MapManager.world_to_tile_position(global_position)
	next_tile_pos = tile_position
	

func initialize() -> void:
	check_for_idle_update_conditional()
	check_visual_turn_on_move()
	EntityManager.setup_entity_controller(self)
	
	connect_to_signals()
	
	update_z()

func update_z():
	var z = EntityManager.get_entity_property(self, "z-index")
	if z:
		if z.is_conditional():
			z_index = int(z.resolve(self, null, tile_position))
		else:
			z_index = int(z.get_value())
	else:
		z_index = 0

func offset_center() -> void:
	sprite.position = get_center_offset()

func get_center_offset() -> Vector2:
	return Vector2(floor(MapManager.tile_width/2.0), floor(MapManager.tile_width/2.0))

func connect_to_signals() -> void:
	var all_props = EntityManager.get_entity_property_list(self)

	for prop_name in all_props:
		if prop_name.begins_with("when_signal_"):
			var signal_name = prop_name.trim_prefix("when_signal_")
			EntityManager.connect_custom_signal(signal_name, entity_manager_signal.bind(signal_name))

	
func check_for_idle_update_conditional() -> void:
	var update_prop: Property = EntityManager.get_entity_property(self, "idle_update")
	if update_prop and update_prop.is_conditional():
		has_idle_update_conditional = true
	
func check_visual_turn_on_move() -> void:
	var move_turn = EntityManager.get_entity_property(self, "move_turns")
	if move_turn:
		if move_turn.is_conditional():
			visual_turn_on_move = move_turn.resolve(self, null, tile_position)
		else:
			visual_turn_on_move = bool(move_turn.get_value())

func serialize() -> Dictionary:
	var important_stuff = {"entity_index": entity_index, "active": active, "moving": moving, "facing": facing}
	important_stuff['instance_id'] = instance_id
	important_stuff['visual_facing'] = visual_facing
	important_stuff['tile_position'] = [tile_position.x, tile_position.y]
	important_stuff['next_tile_pos'] = [next_tile_pos.x, next_tile_pos.y]
	important_stuff['local_properties'] = local_properties.duplicate()
	important_stuff['steps_per_tile'] = steps_per_tile
	important_stuff['self_steps_per_tile'] = self_steps_per_tile
	important_stuff['position'] = [position.x, position.y]
	if moving:
		important_stuff['steps_remaining'] = steps_remaining
	
	if tailing and is_instance_valid(tailing):
		important_stuff['tailing'] = tailing.instance_id
	
	important_stuff['entity_class'] = "BaseEntity"
	
	return important_stuff

func deserialize(data: Dictionary) -> void:
	data = data.duplicate_deep()
	active = data['active']
	set_self_speed(data['self_steps_per_tile'])
	set_current_steps_per_tile(data['steps_per_tile'])
	entity_index = int(data['entity_index'])
	instance_id = int(data['instance_id'])
	entity_name = EntityManager.get_entity_name(entity_index)
	local_properties = data['local_properties']
	
	bond_group = EntityManager.find_bond_group_of_entity(self)
	
	set_facing(int(data['facing']))
	set_visual_facing(int(data['visual_facing']))
	moving = data['moving']
	position = Vector2(data['position'][0], data['position'][1])
	tile_position = Vector2(data['tile_position'][0], data['tile_position'][1])
	next_tile_pos = Vector2(data['next_tile_pos'][0], data['next_tile_pos'][1])
	if "steps_remaining" in data:
		steps_remaining = int(data["steps_remaining"])
	
	await EntityManager.post_deserialize

func set_active(new_active: bool) -> void:
	active = new_active

func _physics_process(_delta) -> void:
	if EntityManager.movements_enabled:
		entity_process()

func entity_process() -> void:
	if not active:
		return
	
	
	if not moving:
		if has_idle_update_conditional:
			if not idle_update_cache:
				idle_update_cache = EntityManager.get_entity_property(self, "idle_update")
				var idle_update_sleep_prop = EntityManager.get_entity_property(self, "idle_update_sleep")
				if idle_update_sleep_prop:
					if idle_update_sleep_prop.is_conditional():
						pass
						# I might make idle_update_sleep conditional run only on start, 
						# and also whenever it gets set as a local property
					else:
						idle_update_sleep = int(idle_update_sleep_prop.get_value())
			if idle_update_sleep == 1 or EntityManager.frame_counter % idle_update_sleep == 0:
				idle_update_cache.resolve(self, null, tile_position)
				if not active:
					# we died or were deactivated in idle update
					return
		
		var max_intentions: int = get_max_move_intentions()
		var start_v_facing: = visual_facing
		var start_move_facing: = facing
		var first_attempt_v_facing: = -1
		var first_attempt_move_facing: = -1
		for attempt in max_intentions:
			# if a previous attempt failed, reset the visual facing and move facing
			if attempt > 0:
				set_visual_facing(start_v_facing)
				set_facing(start_move_facing)
			var intended_move_facing = get_intended_move(attempt)
			if intended_move_facing > -1:
				set_current_steps_per_tile(self_steps_per_tile)
				var was_allowed = start_move(intended_move_facing)
				if first_attempt_v_facing == -1:
					first_attempt_v_facing = visual_facing
					first_attempt_move_facing = facing
				if was_allowed:
					break
		
		if not moving and first_attempt_v_facing > -1:
			set_visual_facing(first_attempt_v_facing)
			set_facing(first_attempt_move_facing)
	if moving:
		
		just_moved = false
		position += Utility.facing_vector(facing) * current_move_speed
		steps_remaining -= 1
		if steps_remaining < 1:
			finish_move()
			return # temporarily disabled
#			var intended = get_intended_move()
#			if intended > -1:
#				set_current_steps_per_tile(self_steps_per_tile)
#				start_move(intended)

func has_local_property(property_name) -> bool:
	return property_name in local_properties

func get_local_property(property_name):
	return local_properties[property_name]

func set_local_property(property_name, value) -> void:
	local_properties[property_name] = value
	if property_name == "idle_update":
		check_for_idle_update_conditional()

func remove_local_property(property_name) -> void:
	local_properties.erase(property_name)

func get_intended_move(attempt_num: int = 0):
	if not controller:
		return -1
	
	if controller.move_mode == "direction":
		return Utility.direction_to_facing(controller.get_move(attempt_num))
	else:
		return controller.get_move(attempt_num)

func get_max_move_intentions() -> int:
	if not controller:
		return 0
	
	if not controller.has_method("get_max_move_intentions"):
		return 1
	else:
		return controller.get_max_move_intentions()

func finish_move() -> void:
	position = position.round()
	#tile_position = next_tile_pos
	tile_position = MapManager.world_to_tile_position(global_position)
	emit_signal("finished_move")
	if tile_position != next_tile_pos:
		push_warning("entity moved to another tile position than expected: current " + str(tile_position) + " != " + str(next_tile_pos))
	moving = false
	MapManager.finish_move(self, [tile_position])

func start_move(move_facing, change_visual_facing=true, group_move=false) -> bool:
	if moving:
		return false
	if current_move_speed <= 0:
		return false
	if change_visual_facing and visual_turn_on_move:
		set_visual_facing(move_facing)
	set_facing(move_facing)
	
	if not group_move and bond_group:
		return EntityManager.bond_group_start_move(bond_group, steps_per_tile, move_facing)
	
	next_tile_pos = tile_position + Utility.facing_vector(facing)
	var not_stopped = MapManager.attempt_move(self, next_tile_pos, group_move)
	if not_stopped:
		moving = true
		steps_remaining = steps_per_tile
		if not bond_group:
			# during a bonded move, entity manager handles calling post_move_actions and actually_started_move
			# they wont get called unless the move succeeds
			EntityManager.post_move_actions(self, tile_position, next_tile_pos)
			actually_started_move()
		else:
			emit_signal("started_move", move_facing)
		return true
	else:
		next_tile_pos = tile_position
		if not group_move:
			emit_signal("blocked", move_facing)
		return false

# Only called right after start move to abort the actual move
# Used by bond groups to stop members moving when one member can't
func revert_move_start() -> void:
	moving = false
	steps_remaining = 0
	next_tile_pos = tile_position
	emit_signal("blocked", facing)

# I started moving
func actually_started_move() -> void:
	emit_signal("started_move", facing)
	var post_move = EntityManager.get_entity_property(self, "post_move")
	if post_move and post_move.is_conditional():
		print("post move conditional")
		post_move.resolve(self, null, next_tile_pos)

func is_settled() -> bool:
	return not moving

func set_controller(new_controller) -> void:
	controller = new_controller
	
	var definition = EntityManager.get_entity_definition(entity_index)
	if "controller_optiops" in definition:
		controller.set_options(definition["controller_options"])

func set_visual_facing(new_facing):
	visual_facing = new_facing
	var no_rotate = EntityManager.get_entity_property(self, "no_rotation")
	if no_rotate != null and no_rotate.get_value():
		return
	sprite.set_sprite_rotation(Utility.facing_rotation(visual_facing))

func set_facing(new_facing):
	facing = new_facing

func turn_to_facing(new_facing):
	set_facing(new_facing)
	set_visual_facing(new_facing)

func set_intended_move_speed(intended: float) -> void:
	var ticks_per_second: int = ProjectSettings.get("physics/common/physics_ticks_per_second")
	
	if intended > 0:
		var spt: = maxi(1, round(ticks_per_second / intended))
		set_self_speed(spt)
	else:
		set_self_speed(0)

func set_self_speed(new_steps_per_tile: int) -> void:
	self_steps_per_tile = new_steps_per_tile
	set_current_steps_per_tile(new_steps_per_tile)

func set_current_steps_per_tile(new_spt) -> void:
	steps_per_tile = new_spt
	if steps_per_tile == 0:
		current_move_speed = 0
	else:
		current_move_speed = MapManager.tile_width / float(steps_per_tile)
		

func can_i_move(at_facing) -> bool:
	var my_pos = tile_position if not moving else next_tile_pos
	var target_pos = my_pos + Utility.facing_vector(at_facing)
	
	# temporarily face the movement direction, so that blocking conditionals can read it
	var old_facing = facing
	set_facing(at_facing)
	var result = MapManager.can_move_to(self, target_pos)
	set_facing(old_facing)
	
	return result

func die() -> void:
	var dying = EntityManager.get_entity_property(self, "dying")
	if dying and dying.is_conditional():
		dying.resolve(self, null, tile_position)
	EntityManager.remove_entity(self)

func set_tailing(entity_to_tail) -> void:
	tailing = entity_to_tail
	tailing.started_move.connect(tail_follow)

func untail() -> void:
	if tailing and is_instance_valid(tailing):
		if tailing.started_move.is_connected(tail_follow):
			tailing.started_move.disconnect(tail_follow)
	tailing = null

func tail_follow(_move_facing) -> void:
	if not tailing:
		return
	if steps_per_tile != tailing.steps_per_tile:
		set_current_steps_per_tile(tailing.steps_per_tile)
	
	var target_tile = tailing.tile_position
	if (target_tile - tile_position).length() > 1:
		print_debug('tail detached')
		untail()
	
	var new_facing = Utility.facing_from_adjacent_positions(tile_position, target_tile)
	var moved = start_move(new_facing)
	if not moved:
		print_debug('tail failed to move')
		untail()

func can_i_move_relative(relative_direction) -> bool:
	return can_i_move(Utility.resolve_relative_direction(relative_direction, facing))

func entity_manager_signal(signaling_entity, args, signal_name) -> void:
	var handler = EntityManager.get_entity_property(self, "when_signal_" + signal_name)
	if handler and handler.is_conditional():
		handler.resolve(self, signaling_entity, tile_position, args)