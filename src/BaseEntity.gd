extends Node2D
class_name BaseEntity

signal started_move
signal finished_move
signal blocked
signal local_prop_changed

enum MoveInterpStyle {
	NONE,
	CONTINUOUS_LINEAR,
	EASE_OUT,
	JUMP_LINEAR,
	JUMP_EASE_OUT,
}

static var move_interp_style_strings: Dictionary[MoveInterpStyle, String] = {
	MoveInterpStyle.NONE: "none",
	MoveInterpStyle.CONTINUOUS_LINEAR: "smooth",
	MoveInterpStyle.EASE_OUT: "stepped",
	MoveInterpStyle.JUMP_LINEAR: "jerky",
	MoveInterpStyle.JUMP_EASE_OUT: "jerky-stepped",
}

var move_interp_style: MoveInterpStyle = MoveInterpStyle.EASE_OUT
var is_move_interp_override: = false
var override_move_interp_style: MoveInterpStyle = MoveInterpStyle.NONE
var teleport_interp_style: MoveInterpStyle = MoveInterpStyle.NONE

var jump_interp_amount: float = 0.5
var interp_out_ease_param: float = 0.3

var move_facing: = 0
var facing: = 0

var visual_turn_on_move: = true

var moving: = false
var _pending_half_move: = false
var _this_move_steps: int = 0
var steps_remaining: int = 0

var _revert_position: Vector2 = Vector2(0, 0)

var idle_ticks_elapsed: int = 0

var sprite: MaskLayerSprite

# tiles per second
var DEPRECATED_steps_per_tile: int = 0

# speed in tiles per second, set by config as speed, but steps per tile is used internally
var current_move_speed: float = 0

var _cached_definition_spt: int = 0
var is_spt_override: bool = false
var override_steps_per_tile: int = 0

var controller: Node = null
var controller_name: String = ""

var tile_position: = Vector2i(0, 0)
var next_tile_pos: = Vector2i(0, 0)

var entity_index: int = 0
var entity_name: String = ""

var bond_group: Array = []
var tailing: Node = null

var has_idle_update_conditional: = false
var idle_update_cache: Property = null
var idle_update_sleep: int = 1

var active: = false

# Properties set on an entity instance overriding their default for the entity type or removing them entirely
var local_properties: = {}
var removed_properties: Array[String] = []

var terrain_sprite_modifiers: Array[int] = []

var deferred_signals: Array[Dictionary] = []

var instance_id: int = 0

var _pre_init_called: = false

func _ready() -> void:
	pre_init()

func _make_sprite() -> void:
	if sprite:
		return
	sprite = MaskLayerSprite.new()
	add_child(sprite, true)

func pre_init() -> void:
	if _pre_init_called:
		return
	_pre_init_called = true
	entity_name = EntityManager.get_entity_name(entity_index)
	_make_sprite()
	sprite.position = get_center_offset()
	

func initialize() -> void:
	check_for_idle_update_conditional()
	check_visual_turn_on_move()
	EntityManager.setup_entity_controller(self)
	
	connect_to_signals()
	
	update_z()

func update_z():
	var z = EntityManager.get_entity_property(self, "z-index")
	if z:
		z_index = z.get_or_resolve(self, null, tile_position)

func get_center_offset() -> Vector2:
	return Vector2(floor(MapManager.tile_width/2.0), floor(MapManager.tile_width/2.0))

func get_center_position() -> Vector2:
	return position + get_center_offset()

func get_half_size() -> Vector2:
	return Vector2.ONE * (MapManager.tile_width * 0.5)

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
	var important_stuff = {}
	important_stuff['entity_index'] = entity_index
	important_stuff['active'] = active
	important_stuff['instance_id'] = instance_id
	important_stuff['facing'] = facing
	important_stuff['position'] = Utility.get_arr_from_vector2(position)
	important_stuff['moving'] = moving
	important_stuff['_pending_half_move'] = _pending_half_move
	important_stuff['move_facing'] = move_facing
	important_stuff['tile_position'] = Utility.get_arr_from_vector2(tile_position)
	important_stuff['next_tile_pos'] = Utility.get_arr_from_vector2(next_tile_pos)
	important_stuff['local_properties'] = local_properties.duplicate()
	important_stuff['removed_properties'] = removed_properties.duplicate()
	important_stuff['is_spt_override'] = is_spt_override
	important_stuff['override_steps_per_tile'] = override_steps_per_tile
	important_stuff['idle_ticks_elapsed'] = idle_ticks_elapsed
	if moving:
		important_stuff['steps_remaining'] = steps_remaining
		important_stuff['_this_move_steps'] = _this_move_steps
	
	if tailing and is_instance_valid(tailing):
		important_stuff['tailing'] = tailing.instance_id
	
	if is_move_interp_override:
		important_stuff['is_move_interp_override'] = true
		important_stuff['override_move_interp_style'] = get_move_interp_style_string(override_move_interp_style)
	
	important_stuff['entity_class'] = "BaseEntity"
	
	important_stuff['deferred_signals'] = JSON.from_native(deferred_signals)
	
	return important_stuff

func deserialize(data: Dictionary) -> void:
	data = data.duplicate_deep()
	entity_index = int(data['entity_index'])
	entity_name = EntityManager.get_entity_name(entity_index)
	instance_id = int(data['instance_id'])

	active = data['active']
	if "idle_ticks_elapsed" in data:
		idle_ticks_elapsed = int(data['idle_ticks_elapsed'])
	if "override_steps_per_tile" in data:
		override_steps_per_tile = data['override_steps_per_tile']
	if "is_spt_override" in data:
		is_spt_override = data['is_spt_override']
	update_cached_spt()
	local_properties = data['local_properties']
	removed_properties.assign(data.get('removed_properties', []))
	
	bond_group = EntityManager.find_bond_group_of_entity(self)
	
	# handle old format of 'visual_facing'
	if data.has('visual_facing'):
		set_move_facing(int(data['facing']))
		set_facing(int(data['visual_facing']))
	else:
		set_move_facing(int(data['move_facing']))
		set_facing(int(data['facing']))
	moving = data['moving']
	_pending_half_move = data.get('_pending_half_move', false)
	position = Utility.get_vector2_from_arr(data['position'])
	tile_position = Utility.get_vector2_from_arr(data['tile_position'])
	next_tile_pos = Utility.get_vector2_from_arr(data['next_tile_pos'])
	if "steps_remaining" in data:
		steps_remaining = int(data["steps_remaining"])
	if "_this_move_steps" in data:
		_this_move_steps = int(data["_this_move_steps"])
	
	if data.get('is_move_interp_override', false):
		is_move_interp_override = true
		set_move_interp_override(read_move_interp_style_string(data['override_move_interp_style']))
	
	if "deferred_signals" in data:
		deferred_signals = JSON.to_native(data['deferred_signals'])
	
	if data.has('tailing'):
		await EntityManager.post_deserialize
		set_tailing(EntityManager.get_instance(data['tailing']))

func set_active(new_active: bool) -> void:
	EntityManager.set_entity_active(self, new_active)

func sprite_process() -> void:
	sprite.sprite_process()

func entity_process_starting_actions() -> void:
	if not moving:
		#if has_idle_update_conditional:
		#	if not idle_update_cache:
		#		idle_update_cache = EntityManager.get_entity_property(self, "idle_update")
		#		var idle_update_sleep_prop = EntityManager.get_entity_property(self, "idle_update_sleep")
		#		if idle_update_sleep_prop:
		#			if idle_update_sleep_prop.is_conditional():
		#				pass
		#				# I might make idle_update_sleep conditional run only on start, 
		#				# and also whenever it gets set as a local property
		#			else:
		#				idle_update_sleep = int(idle_update_sleep_prop.get_value())
		#	if idle_update_sleep == 1 or EntityManager.frame_counter % idle_update_sleep == 0:
		#		idle_update_cache.resolve(self, null, tile_position)
		#		if not active:
		#			# we died or were deactivated in idle update
		#			return
		
		var max_intentions: int = get_max_move_intentions()
		if max_intentions > 0:
			var pre_fetch_move_list: Array = get_pre_fetch_move_list()
			if pre_fetch_move_list.size() > 0:
				max_intentions = pre_fetch_move_list.size()

			var start_v_facing: = facing
			var start_move_facing: = move_facing
			var first_attempt_v_facing: = -1
			var first_attempt_move_facing: = -1
			for attempt in max_intentions:
				# if a previous attempt failed, reset the visual move_facing and move move_facing
				if attempt > 0:
					set_facing(start_v_facing)
					set_move_facing(start_move_facing)
				var intended_move_facing: int = -1
				if pre_fetch_move_list.size() > 0:
					intended_move_facing = pre_fetch_move_list[attempt]
				else:
					intended_move_facing = get_intended_move(attempt)

				if intended_move_facing > -1:
					set_native_move_speed()
					var was_allowed = start_move(intended_move_facing)
					if first_attempt_v_facing == -1:
						first_attempt_v_facing = facing
						first_attempt_move_facing = move_facing
					if was_allowed:
						break
			
			if not moving and first_attempt_v_facing > -1:
				set_facing(first_attempt_v_facing)
				set_move_facing(first_attempt_move_facing)

func entity_process_idle_actions() -> void:
	if has_idle_update_conditional:
		if not idle_update_cache:
			idle_update_cache = EntityManager.get_entity_property(self, "idle_update")
		idle_update_cache.resolve(self, null, tile_position)
	if controller and controller.has_method("on_idle"):
		controller.on_idle()

func entity_process_moving_actions() -> void:
	if not moving:
		return

	bump_move_step()

	if _pending_half_move and steps_remaining <= floori(_this_move_steps / 2.0):
		EntityManager.queue_half_move_actions_for(self)

	if steps_remaining < 1:
		_movement_steps_finished()

func bump_move_step() -> void:
	steps_remaining -= 1
	interpolate_pos()

func get_move_progress() -> float:
	return 1 - (steps_remaining / float(_this_move_steps))

func interpolate_pos() -> void:
	var move_progress: float = get_move_progress()
	var prev_pos: = MapManager.tile_to_world_position(tile_position)
	var next_pos: = MapManager.tile_to_world_position(next_tile_pos)
	var interp_style: MoveInterpStyle = get_move_interp_style()
	if interp_style == MoveInterpStyle.NONE:
		position = next_pos
	elif interp_style == MoveInterpStyle.CONTINUOUS_LINEAR:
		#var pixel_speed_per_tick: float = MapManager.tile_width * (current_move_speed / GameManager.get_full_tick_rate())
		#position += Utility.facing_vector(move_facing) * pixel_speed_per_tick
		position = prev_pos.lerp(next_pos, move_progress)
	elif interp_style == MoveInterpStyle.EASE_OUT:
		position = prev_pos.lerp(next_pos, ease(move_progress, interp_out_ease_param))
	elif interp_style in [MoveInterpStyle.JUMP_LINEAR, MoveInterpStyle.JUMP_EASE_OUT]:
		move_progress = remap(move_progress, 0, 1, jump_interp_amount, 1)
		if interp_style == MoveInterpStyle.JUMP_LINEAR:
			position = prev_pos.lerp(next_pos, move_progress)
		elif interp_style == MoveInterpStyle.JUMP_EASE_OUT:
			position = prev_pos.lerp(next_pos, ease(move_progress, interp_out_ease_param))
	else:
		push_error("Unknown move interpolation style: " + str(interp_style))
		if is_move_interp_override:
			clear_move_interp_override()
		else:
			move_interp_style = MoveInterpStyle.NONE
		position = next_pos

func has_local_property(property_name: String) -> bool:
	if property_name in removed_properties:
		return false
	return property_name in local_properties

func is_property_removed(property_name: String) -> bool:
	return property_name in removed_properties

func get_local_property(property_name: String) -> Variant:
	return local_properties[property_name]

func set_local_property(property_name: String, value: Variant) -> void:
	_set_local_property(property_name, value)
	_local_prop_changed()

func _set_local_property(property_name: String, value: Variant) -> void:
	if property_name in removed_properties:
		removed_properties.erase(property_name)
	local_properties[property_name] = value
	if property_name == "idle_update":
		check_for_idle_update_conditional()

func remove_local_property(property_name: String) -> void:
	_remove_local_property(property_name)
	_local_prop_changed()

func _remove_local_property(property_name: String) -> void:
	local_properties.erase(property_name)
	if EntityManager.entity_has_property(self, property_name):
		removed_properties.append(property_name)

func reset_local_property(property_name: String) -> void:
	_reset_local_property(property_name)
	_local_prop_changed()

func _reset_local_property(property_name: String) -> void:
	local_properties.erase(property_name)
	removed_properties.erase(property_name)

func _local_prop_changed() -> void:
	local_prop_changed.emit(self)

func get_intended_move(attempt_num: int = 0) -> int:
	if not controller:
		return -1
	
	if controller.move_mode == "direction":
		return Utility.direction_to_facing(controller.get_move(attempt_num))
	elif controller.move_mode == "facing":
		return controller.get_move(attempt_num)
	elif controller.move_mode == "pre_fetch":
		return -1
	else:
		push_error("Unknown controller move mode: " + controller.move_mode)
		return -1

func get_pre_fetch_move_list() -> Array:
	if not controller or not controller.move_mode == "pre_fetch":
		return []
	
	return controller.get_moves()

func get_max_move_intentions() -> int:
	if not controller:
		return 0
	
	if not controller.has_method("get_max_move_intentions"):
		return 1
	else:
		return controller.get_max_move_intentions()

func has_move_intentions() -> bool:
	if not controller:
		return false
	return get_max_move_intentions() > 0

func soft_check_intended_move_facing() -> int:
	var max_intentions: int = get_max_move_intentions()
	if max_intentions == 0:
		return -1
	var move_list: Array = get_pre_fetch_move_list()
	if move_list.size() > 0:
		max_intentions = move_list.size()
	for i in max_intentions:
		var intended_move_facing: int = move_list[i] if move_list else get_intended_move(i)
		if intended_move_facing == -1:
			continue
		if i == max_intentions - 1 or can_i_move(intended_move_facing):
			return intended_move_facing
	return -1

func _movement_steps_finished() -> void:
	position = position.round()
	tile_position = next_tile_pos
	finished_move.emit()
	var positioned_at_tile_position: = MapManager.world_to_tile_position(global_position)
	if tile_position != positioned_at_tile_position:
		push_warning("entity moved above another tile position than expected: over tile: " + str(positioned_at_tile_position) + " != actual pos: " + str(tile_position))
		position = MapManager.tile_to_world_position(tile_position)
	moving = false
	if is_spt_override:
		set_native_move_speed()
	if is_move_interp_override:
		clear_move_interp_override()

func process_finish_move() -> void:
	MapManager.finish_move(self, [tile_position])

func start_move(in_facing_dir: int, change_visual_facing: bool = true, group_move: bool = false) -> bool:
	if moving or get_steps_per_tile() <= 0:
		return false
	if change_visual_facing and visual_turn_on_move:
		set_facing(in_facing_dir)
	set_move_facing(in_facing_dir)
	
	if not group_move and bond_group:
		return EntityManager.bond_group_start_move(bond_group, get_steps_per_tile(), in_facing_dir)
	
	next_tile_pos = tile_position + Utility.facing_vector_i(in_facing_dir)
	var move_has_started = MapManager.attempt_move(self, next_tile_pos, group_move)

	if move_has_started:
		moving = true
		_pending_half_move = true
		steps_remaining = get_steps_per_tile()
		_this_move_steps = steps_remaining
		if not group_move:
			EntityManager.post_move_actions(self, tile_position, next_tile_pos)
			actually_started_move()
		else:
			# save position before a bump to revert to if the group move is reverted
			_revert_position = position
			# during a bonded move, entity manager handles calling post_move_actions and actually_started_move if the group move succeeds
		_move_bump_check()
		return true
	else:
		next_tile_pos = tile_position
		if not group_move:
			blocked.emit(in_facing_dir)
		return false

func _move_bump_check() -> void:
	if EntityManager.should_bump_move():
		# Bump 1 step forward so that late move starts during a tick are synchronized
		# but if the next step could trigger actions, bumping would skip them so don't bump
		if not next_step_has_actions():
			prints("BUMP")
			bump_move_step()

func next_step_has_actions() -> bool:
	if not moving:
		var spt: = get_steps_per_tile()
		return spt == 1 or spt == 2
	else:
		var next_steps_remaining: = steps_remaining - 1
		# next step would finish move, or would trigger half-move
		return next_steps_remaining == 0 or next_steps_remaining == floori(_this_move_steps / 2.0)

# Only called right after start move to abort the actual move
# Used by bond groups to stop members moving when one member can't
func revert_move_start() -> void:
	moving = false
	position = _revert_position
	steps_remaining = 0
	_this_move_steps = 0
	next_tile_pos = tile_position
	blocked.emit(move_facing)

# I started moving
func actually_started_move() -> void:
	started_move.emit(move_facing)
	var post_move = EntityManager.get_entity_property(self, "post_move")
	if post_move and post_move.is_conditional():
		post_move.resolve(self, null, next_tile_pos)

func is_settled() -> bool:
	return not moving

func set_controller(new_controller) -> void:
	controller = new_controller
	
	var definition = EntityManager.get_entity_definition(entity_index)
	if "controller_optiops" in definition:
		controller.set_options(definition["controller_options"])

func set_facing(new_facing):
	facing = new_facing
	var no_rotate = EntityManager.get_entity_property(self, "no_rotation")
	if no_rotate != null and no_rotate.get_value():
		return
	sprite.set_sprite_rotation(Utility.facing_rotation(facing))

func set_move_facing(new_facing):
	move_facing = new_facing

func turn_to_facing(new_facing):
	set_move_facing(new_facing)
	set_facing(new_facing)

static func _speed_to_spt(speed: float) -> int:
	if speed <= 0:
		return 0
	return maxi(1, roundi(GameManager.get_full_tick_rate() / speed))

static func _spt_to_speed(spt: int) -> float:
	if spt <= 0:
		return 0
	return 1 / (float(spt) / GameManager.get_full_tick_rate())

func update_cached_spt() -> void:
	var entity_speed = EntityManager.get_entity_definition(entity_index).get("intended_move_speed", EntityManager.default_move_speed)
	_cached_definition_spt = _speed_to_spt(entity_speed)
	update_move_speed()

func set_steps_per_tile_override(override_spt: int) -> void:
	is_spt_override = true
	override_steps_per_tile = override_spt
	update_move_speed()

func set_move_speed_override(speed: float) -> void:
	set_steps_per_tile_override(_speed_to_spt(speed))

func set_native_move_speed() -> void:
	is_spt_override = false
	update_move_speed()

func get_steps_per_tile() -> int:
	if is_spt_override:
		return override_steps_per_tile
	return _cached_definition_spt

func get_native_steps_per_tile() -> int:
	return _cached_definition_spt

func update_move_speed() -> void:
	current_move_speed = _spt_to_speed(get_steps_per_tile())


func can_i_move(at_facing: int) -> bool:
	var my_pos: = tile_position if not moving else next_tile_pos
	var target_pos: = my_pos + Utility.facing_vector_i(at_facing)
	
	# temporarily face the movement direction, so that blocking conditionals can read it
	var old_facing = move_facing
	set_move_facing(at_facing)
	var result = MapManager.can_move_to(self, target_pos)
	set_move_facing(old_facing)
	
	return result

func die() -> void:
	var dying = EntityManager.get_entity_property(self, "dying")
	if dying and dying.is_conditional():
		dying.resolve(self, null, tile_position)
	EntityManager.post_die_actions(self)
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
	if get_steps_per_tile() != tailing.get_steps_per_tile():
		set_steps_per_tile_override(tailing.get_steps_per_tile())
	
	var target_tile = tailing.get_stationary_position()
	if (target_tile - tile_position).length() > 1:
		print_debug('tail detached')
		untail()
	
	var new_facing = Utility.facing_from_adjacent_positions(tile_position, target_tile)
	var moved = start_move(new_facing)
	if not moved:
		print_debug('tail failed to move')
		untail()

func can_i_move_relative(relative_direction) -> bool:
	return can_i_move(Utility.resolve_relative_direction(relative_direction, move_facing))

func entity_manager_signal(signaling_entity: BaseEntity, args: Array, signal_name: String) -> void:
	if not active:
		return
	if not moving:
		_handle_signal(signaling_entity, args, signal_name)
	else:
		add_deferred_signal(signaling_entity, args, signal_name)

func _handle_signal(signaling_entity: BaseEntity, args: Array, signal_name: String) -> void:
	var handler = EntityManager.get_entity_property(self, "when_signal_" + signal_name)
	if handler and handler.is_conditional():
		handler.resolve(self, signaling_entity, tile_position, args)

func add_sprite_modifier(mod_info: Dictionary) -> void:
	if not mod_info or not mod_info.get("name", ""):
		return
	sprite.apply_modifier(mod_info.get("name", ""), mod_info.get("layers", []), mod_info.get("mask_info", {}))

func remove_sprite_modifier(mod_info: Dictionary) -> void:
	if not mod_info or not mod_info.get("name", ""):
		return
	sprite.remove_modifier(mod_info.get("name", ""))

func clear_sprite_modifiers() -> void:
	sprite.clear_modifiers()

func get_stationary_position() -> Vector2i:
	return Vector2i(tile_position)

func get_moving_position() -> Vector2i:
	if not moving:
		return get_stationary_position()
	return Vector2i(next_tile_pos)

func get_half_moved_position() -> Vector2i:
	if moving and not _pending_half_move:
		return get_moving_position()
	return Vector2i(tile_position)

func is_at_multiple(check_positions: Array, include_moving_away: bool = false) -> bool:
	if get_moving_position() in check_positions:
		return true
	elif include_moving_away and get_stationary_position() in check_positions:
		return true
	return false

func add_deferred_signal(signaling_entity: BaseEntity, args: Array, signal_name: String) -> void:
	deferred_signals.append({
		"signaling_entity": signaling_entity.instance_id,
		"args": args,
		"signal_name": signal_name
	})

func process_deferred_signals() -> void:
	for deferred_signal in deferred_signals:
		var signaling_entity = EntityManager.get_instance(deferred_signal["signaling_entity"])
		_handle_signal(signaling_entity, deferred_signal["args"], deferred_signal["signal_name"])
	deferred_signals.clear()

func has_local_data() -> bool:
	if local_properties.size() > 0 or removed_properties.size() > 0:
		return true
	return false

static func read_move_interp_style_string(style_str: String) -> MoveInterpStyle:
	style_str = style_str.to_lower()
	var found_style: Variant = move_interp_style_strings.find_key(style_str)
	if found_style:
		return found_style as MoveInterpStyle
	return MoveInterpStyle.NONE

static func get_move_interp_style_string(style: MoveInterpStyle) -> String:
	return move_interp_style_strings.get(style, "none")

func set_move_interp_override(style: MoveInterpStyle) -> void:
	is_move_interp_override = true
	override_move_interp_style = style

func clear_move_interp_override() -> void:
	is_move_interp_override = false
	override_move_interp_style = MoveInterpStyle.NONE

func get_move_interp_style() -> MoveInterpStyle:
	if is_move_interp_override:
		return override_move_interp_style
	return move_interp_style