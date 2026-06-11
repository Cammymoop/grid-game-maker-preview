extends Node2D
class_name BaseEntity

signal started_move
signal finished_move
signal blocked
signal local_prop_changed

const PosInterpStyle = Utility.PosInterpStyle

const DEF_DYING_EFFECT_DURATION: float = 0.5

var move_interp_style: = PosInterpStyle.CONTINUOUS_LINEAR
var is_move_interp_override: = false
var override_move_interp_style: = PosInterpStyle.NONE
var teleport_interp_style: = PosInterpStyle.MID_DISCRETE

var jump_interp_amount: float = 0.5
var interp_out_ease_param: float = 0.36

var move_facing: = 0
var facing: = 0

var visual_turn_on_move: = true

var moving: = false
var _pending_half_move: = false
var _this_move_steps: int = 0
var steps_remaining: int = 0

var _this_move_is_teleport: = false

var idle_ticks_elapsed: int = 0

var sprite: MaskLayerSprite

# tiles per second
var DEPRECATED_steps_per_tile: int = 0

# speed in tiles per second, set by config as speed, but steps per tile is used internally
var current_move_speed: float = 0

var _cached_definition_spt: int = 0
var _cached_tele_steps: int = 0
var is_spt_override: bool = false
var override_steps_per_tile: int = 0

var controller: Node = null
var controller_name: String = ""

var tile_position: = Vector2i(0, 0)
var next_tile_pos: = Vector2i(0, 0)
var _from_tile_pos: = Vector2i(0, 0)

var entity_index: int = 0
var entity_name: String = ""

var bond_group: Array = []
var tailing: Node = null

var subordinate_entities: Array[int] = []

var friend_instance_id: int = -1

var has_idle_update_conditional: = false
var idle_update_cache: Property = null
var idle_update_sleep: int = 1

var active: = false
var dying: = false

# Properties set on an entity instance overriding their default for the entity type or removing them entirely
var local_properties: = {}
var removed_properties: Array[String] = []

var terrain_sprite_modifiers: Array[int] = []

var deferred_signals: Array[Dictionary] = []

var instance_id: int = 0

var _pre_init_called: = false

var _currently_starting_move: bool = false
var _current_starting_move_facing: int = -1

func _ready() -> void:
	pre_init()

func _make_sprite() -> void:
	if sprite:
		return
	sprite = MaskLayerSprite.new()
	add_child(sprite, true)
	sprite.dying_animation_finished.connect(on_dying_animation_finished)

func on_dying_animation_finished() -> void:
	dying = false
	EntityManager.remove_entity(self)

func pre_init() -> void:
	if _pre_init_called:
		return
	_pre_init_called = true
	entity_name = EntityManager.get_entity_name(entity_index)
	_make_sprite()
	sprite.set_sprite_size(Vector2(MapManager.tile_width, MapManager.tile_width))
	

func initialize() -> void:
	check_for_idle_update_conditional()
	check_visual_turn_on_move()
	EntityManager.setup_entity_controller(self)
	
	connect_to_signals()
	
	update_cached_special_props()
	
func update_cached_special_props() -> void:
	update_z()
	update_cached_spt()
	update_cached_tele_steps()

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
	var move_turn = EntityManager.get_entity_property(self, "move-turns")
	if move_turn:
		if move_turn.is_conditional():
			visual_turn_on_move = move_turn.resolve(self, null, tile_position)
		else:
			visual_turn_on_move = bool(move_turn.get_value())

func add_depends_on_entity(on_entity: BaseEntity) -> void:
	if on_entity and on_entity.instance_id != instance_id:
		on_entity.add_dependant_entity(self)

func add_dependant_entity(dependant_entity: BaseEntity) -> void:
	if not dependant_entity.instance_id in subordinate_entities:
		subordinate_entities.append(dependant_entity.instance_id)

func remove_dependant_entity(dependant_entity: BaseEntity) -> void:
	subordinate_entities.erase(dependant_entity.instance_id)

func stop_depending_on_entity(on_entity: BaseEntity) -> void:
	if on_entity and instance_id in on_entity.subordinate_entities:
		on_entity.remove_dependant_entity(self)

func stop_depending_on_all() -> void:
	for on_entity in EntityManager.entity_list:
		if instance_id in on_entity.subordinate_entities:
			on_entity.remove_dependant_entity(self)

func _handle_removed_entities() -> void:
	if subordinate_entities.size() > 0:
		var new_subordinate_entities: Array[int] = []
		for on_inst_id in subordinate_entities:
			if EntityManager.has_instance(on_inst_id):
				new_subordinate_entities.append(on_inst_id)
		subordinate_entities = new_subordinate_entities
	if tailing:
		if tailing.is_queued_for_deletion() or not EntityManager.has_instance(tailing.instance_id):
			untail()
	if friend_instance_id > -1 and not EntityManager.has_instance(friend_instance_id):
		friend_instance_id = -1

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
		important_stuff['_this_move_is_teleport'] = _this_move_is_teleport
		important_stuff['_from_tile_pos'] = Utility.get_arr_from_vector2(_from_tile_pos)
	
	if tailing and is_instance_valid(tailing):
		important_stuff['tailing'] = tailing.instance_id
	
	if is_move_interp_override:
		important_stuff['is_move_interp_override'] = true
		important_stuff['override_move_interp_style'] = get_move_interp_style_string(override_move_interp_style)
	
	important_stuff['friend_instance_id'] = friend_instance_id
	
	important_stuff['entity_class'] = "BaseEntity"
	
	important_stuff['deferred_signals'] = JSON.from_native(deferred_signals)
	
	if subordinate_entities.size() > 0:
		important_stuff['subordinate_entities'] = subordinate_entities
	
	var serialized_sprite: Dictionary = sprite.get_serialized_info()
	if serialized_sprite:
		important_stuff['serialized_sprite'] = serialized_sprite
	
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
		set_facing(int(data['visual_facing']), true)
	else:
		set_move_facing(int(data['move_facing']))
		set_facing(int(data['facing']), true)
	moving = data['moving']
	_pending_half_move = data.get('_pending_half_move', false)
	position = Utility.get_vector2_from_arr(data['position'])
	tile_position = Utility.get_vector2i_from_arr(data['tile_position'])
	next_tile_pos = Utility.get_vector2i_from_arr(data['next_tile_pos'])
	if "steps_remaining" in data:
		steps_remaining = int(data["steps_remaining"])
	if "_this_move_steps" in data:
		_this_move_steps = int(data["_this_move_steps"])
	if "_this_move_is_teleport" in data:
		_this_move_is_teleport = data['_this_move_is_teleport']
	if "_from_tile_pos" in data:
		_from_tile_pos = Utility.get_vector2i_from_arr(data['_from_tile_pos'])
	
	if 'friend_instance_id' in data:
		friend_instance_id = int(data['friend_instance_id'])
	
	if 'subordinate_entities' in data:
		subordinate_entities.assign(data['subordinate_entities'])
	
	if data.get('is_move_interp_override', false):
		is_move_interp_override = true
		set_move_interp_override(read_move_interp_style_string(data['override_move_interp_style']))
	
	if "deferred_signals" in data:
		deferred_signals = JSON.to_native(data['deferred_signals'])
	
	if data.has('tailing'):
		await EntityManager.post_deserialize

	if data.get('tailing', -1) > -1:
		set_tailing(EntityManager.get_instance(data['tailing']))

func deserialize_sprite(data: Dictionary) -> void:
	if "serialized_sprite" in data:
		sprite.deserialize_sprite_info(data['serialized_sprite'].duplicate_deep())

func set_active(new_active: bool) -> void:
	EntityManager.set_entity_active(self, new_active)

func sprite_process(delta_time: float) -> void:
	sprite.sprite_process(delta_time)

func entity_process_starting_actions() -> void:
	if not moving:
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
					if is_square_aspect():
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
						if tailing:
							untail()
						break
			
			if not moving and first_attempt_v_facing > -1:
				if is_square_aspect():
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
	if steps_remaining > _this_move_steps:
		breakpoint
	return 1 - (steps_remaining / float(_this_move_steps))

func interpolate_pos() -> void:
	var move_progress: float = get_move_progress()
	var prev_pos: = MapManager.tile_to_world_position(tile_position)
	var next_pos: = MapManager.tile_to_world_position(next_tile_pos)
	var interp: = get_move_interp_style()
	position = Utility.apply_vec2_interpolation(interp, prev_pos, next_pos, move_progress, interp_out_ease_param)

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

func refresh_cached_prop(prop_name: String) -> void:
	if prop_name in GameManager.SPECIAL_PROPS:
		update_cached_special_props()

func _set_local_property(property_name: String, value: Variant) -> void:
	if property_name in removed_properties:
		removed_properties.erase(property_name)
	local_properties[property_name] = value
	if property_name == "idle_update":
		check_for_idle_update_conditional()
	refresh_cached_prop(property_name)

func remove_local_property(property_name: String) -> void:
	_remove_local_property(property_name)
	_local_prop_changed()

func _remove_local_property(property_name: String) -> void:
	local_properties.erase(property_name)
	if EntityManager.entity_has_property(self, property_name):
		removed_properties.append(property_name)
	refresh_cached_prop(property_name)

func reset_local_property(property_name: String) -> void:
	_reset_local_property(property_name)
	_local_prop_changed()

func _reset_local_property(property_name: String) -> void:
	local_properties.erase(property_name)
	removed_properties.erase(property_name)
	refresh_cached_prop(property_name)

func reset_all_local_properties() -> void:
	for property_name in local_properties:
		_reset_local_property(property_name)
	for deleted_name in removed_properties:
		_reset_local_property(deleted_name)
	_local_prop_changed()

func _local_prop_changed() -> void:
	local_prop_changed.emit(self)

func has_any_local_properties() -> bool:
	return local_properties.size() > 0 or removed_properties.size() > 0

func get_local_properties_dict() -> Dictionary:
	return {
		"local_set": local_properties.duplicate_deep(),
		"local_removed": removed_properties.duplicate_deep(),
	}

func set_local_properties_dict(properties_dict: Dictionary) -> void:
	local_properties.assign(properties_dict["local_set"].duplicate_deep())
	removed_properties.assign(properties_dict["local_removed"].duplicate_deep())
	update_cached_special_props()
	_local_prop_changed()

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
	if not controller or EntityManager.get_entity_prop_is_truthy(self, "controller-disabled"):
		return 0
	if tailing and EntityManager.has_instance(tailing.instance_id):
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

func start_move(in_facing_dir: int, change_visual_facing: bool = true, group_move: bool = false, is_revertable: bool = false) -> bool:
	if moving or get_steps_per_tile() <= 0:
		return false
	if change_visual_facing and visual_turn_on_move:
		set_facing(in_facing_dir)
	set_move_facing(in_facing_dir)

	if not group_move and bond_group:
		return EntityManager.bond_group_start_move(bond_group, get_steps_per_tile(), in_facing_dir, is_revertable)
	
	var to_pos: = tile_position + Utility.facing_vector_i(in_facing_dir)
	return _start_move_common(to_pos, group_move, false, is_revertable)

func start_teleport_to(from_pos: Vector2i, to_pos: Vector2i, override_move_facing: int = -1, override_facing: int = -1, group_move: bool = false, override_steps: int = -1, is_revertable: bool = false) -> bool:
	if moving:
		return false

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
	
	return _start_move_common(to_pos, group_move, true, is_revertable)

func _is_diagonal_adj(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if (from_pos - to_pos).abs() == Vector2i.ONE:
		return true
	return false

func _start_move_common(to_tile_pos: Vector2i, is_group_move: bool, is_teleport: bool, is_revertable: bool) -> bool:
	var related_move_node: = EntityManager.track_move_starting(self, is_group_move, is_revertable)
	_currently_starting_move = true
	_current_starting_move_facing = move_facing
	
	var result: = MapManager.attempt_move(self, [tile_position], [to_tile_pos], to_tile_pos, is_group_move)

	if result:
		moving = true
		_from_tile_pos = tile_position
		next_tile_pos = to_tile_pos
		invalidate_cached_at_position([tile_position])
		_pending_half_move = true
		steps_remaining = get_teleport_steps() if is_teleport else get_steps_per_tile()
		_this_move_steps = steps_remaining
		_this_move_is_teleport = is_teleport
		if not is_group_move:
			EntityManager.post_move_actions(self, tile_position, next_tile_pos)
			actually_started_move()
		_move_bump_check()
	else:
		if not is_group_move:
			on_move_was_blocked()
	
	EntityManager.just_finished_move_start(related_move_node, result)
	_currently_starting_move = false
	_current_starting_move_facing = -1
	return result

func on_move_was_blocked() -> void:
	EntityManager.resolve_entity_interaction_event("was_blocked", self, null, [tile_position])
	blocked.emit()

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
	steps_remaining = 0
	_this_move_steps = 0
	_this_move_is_teleport = false
	next_tile_pos = tile_position
	invalidate_cached_at_position([next_tile_pos])
	blocked.emit()

# I started moving
func actually_started_move() -> void:
	started_move.emit(move_facing)
	var post_move = EntityManager.get_entity_property(self, "post_move")
	if post_move and post_move.is_conditional():
		post_move.resolve(self, null, get_moving_position())
	
	if entity_name == "player":
		pass#do_named_bump_effect({"name": "Spin"})

func invalidate_cached_at_position(from_positions: Array) -> void:
	var from_positions_v2i: Array[Vector2i] = Array(from_positions, TYPE_VECTOR2I, "", null)
	EntityManager.invalidate_cached_instance_at_pos(self, from_positions_v2i)

func is_settled() -> bool:
	return not moving

func set_controller(new_controller) -> void:
	controller = new_controller
	
	var definition = EntityManager.get_entity_definition(entity_index)
	if "controller_optiops" in definition:
		controller.set_options(definition["controller_options"])

func set_facing(new_facing: int, immediate: bool = false) -> void:
	facing = new_facing
	var no_rotate = EntityManager.get_entity_property(self, "no-rotate")
	if no_rotate != null and no_rotate.get_value():
		return
	sprite.set_sprite_facing(facing, immediate)

func set_facing_only(new_facing: int) -> void:
	facing = new_facing

func set_move_facing(new_facing: int) -> void:
	move_facing = new_facing

func turn_to_facing(new_facing: int, immediate: bool = false) -> void:
	set_move_facing(new_facing)
	set_facing(new_facing, immediate)

static func _speed_to_spt(speed: float) -> int:
	if speed <= 0:
		return 0
	return maxi(1, roundi(GameManager.get_full_tick_rate() / speed))

static func _spt_to_speed(spt: int) -> float:
	if spt <= 0:
		return 0
	return 1 / (float(spt) / GameManager.get_full_tick_rate())

func update_cached_spt() -> void:
	var entity_type_base_speed: Variant = EntityManager.get_static_entity_prop_with_default(self, "move-speed", EntityManager.get_default_move_speed())
	var base_speed_float: float = Utility.property_value_scalar(entity_type_base_speed, EntityManager.get_default_move_speed())
	if typeof(entity_type_base_speed) == TYPE_BOOL:
		base_speed_float = EntityManager.get_default_move_speed()
	elif base_speed_float <= 0:
		base_speed_float = EntityManager.get_default_move_speed()
	_cached_definition_spt = _speed_to_spt(entity_type_base_speed)
	update_move_speed()

func update_cached_tele_steps() -> void:
	if not EntityManager.entity_has_property(self, "teleport-duration"):
		_cached_tele_steps = maxi(1, EntityManager.get_default_tele_steps())
		return
	var tele_duration = EntityManager.get_static_entity_prop_with_default(self, "teleport-duration", EntityManager.default_teleport_duration)
	_cached_tele_steps = maxi(1, ceili(tele_duration * GameManager.get_full_tick_rate()))

func set_steps_per_tile_override(override_spt: int) -> void:
	is_spt_override = true
	override_steps_per_tile = override_spt
	if moving:
		var move_remaining = steps_remaining / float(_this_move_steps)
		steps_remaining = roundi(move_remaining * override_steps_per_tile)
		_this_move_steps = override_steps_per_tile
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

func get_move_duration() -> float:
	return get_steps_per_tile() / float(GameManager.FULL_TICK_RATE)

func get_native_steps_per_tile() -> int:
	return _cached_definition_spt

func get_teleport_steps() -> int:
	if is_spt_override:
		return override_steps_per_tile
	prints("returning cached tele steps:", _cached_tele_steps)
	return _cached_tele_steps

func get_moving_steps_per_tile() -> int:
	if not moving:
		return 0
	if _this_move_is_teleport:
		return get_teleport_steps()
	return get_steps_per_tile()

func update_move_speed() -> void:
	current_move_speed = _spt_to_speed(get_steps_per_tile())

func _get_teleport_implicit_facing(from_pos: Vector2i, to_pos: Vector2i) -> int:
	return Utility.vector_to_facing_from_facing(to_pos - from_pos, facing)

func can_i_move(at_facing: int) -> bool:
	if moving:
		return false
	var target_pos: = tile_position + Utility.facing_vector_i(at_facing)
	
	# temporarily face the movement direction, so that blocking conditionals can read it
	var old_move_facing = move_facing
	set_move_facing(at_facing)
	var result = MapManager.can_move_to(self, target_pos)
	set_move_facing(old_move_facing)
	
	return result

func can_i_teleport_to(from_pos: Vector2i, to_pos: Vector2i, with_move_facing: int = -1, with_facing: int = -1) -> bool:
	var old_facing = facing
	var old_move_facing = move_facing
	if with_facing >= 0:
		facing = with_facing
	elif with_facing == -1:
		facing = _get_teleport_implicit_facing(from_pos, to_pos)
	if with_move_facing >= 0:
		set_move_facing(with_move_facing)
	elif with_move_facing == -1:
		set_move_facing(_get_teleport_implicit_facing(from_pos, to_pos))

	var result: = MapManager.can_move_to(self, to_pos)
	facing = old_facing
	set_move_facing(old_move_facing)
	return result

func die_with_effect(effect_info: Dictionary) -> void:
	var effect_name: String = effect_info.get("name", "")
	if effect_name == "" or not effect_name in SpriteEffects.DYING_EFFECTS:
		push_warning("Unknown dying effect: %s" % effect_name)
		die()
	else:
		var duration: float = -1
		if effect_info.has("duration"):
			duration = effect_info["duration"]
		# todo: extra modifications to effect like direction or color
		die(SpriteEffects.DYING_EFFECTS[effect_name], duration)

func die(with_effect_info: Dictionary = {}, with_duration: float = -1) -> void:
	var dying_conditional = EntityManager.get_entity_property(self, "dying")
	if dying_conditional and dying_conditional.is_conditional():
		dying_conditional.resolve(self, null, tile_position)
	EntityManager.post_die_actions(self)
	if not with_effect_info:
		with_effect_info = EntityManager.get_default_dying_effect_for_entity_id(entity_index)

	if not with_effect_info or with_effect_info.get("none", false):
		EntityManager.remove_entity(self)
	else:
		dying = true
		do_dying_effect(with_effect_info, with_duration)

func do_dying_effect(effect_info: Dictionary, with_duration: float = -1) -> void:
	var effect_name: String = effect_info.get("name", "")
	if not effect_info or not effect_name:
		push_warning("invalid dying effect info: " + str(effect_info))
		EntityManager.remove_entity(self)
		return
	effect_info = effect_info.duplicate_deep()
	set_active(false)
	if with_duration < 0:
		with_duration = effect_info.get("duration", DEF_DYING_EFFECT_DURATION)
	for ll_effect_name in effect_info.get("animated_effects", {}):
		var ll_effect: Dictionary = effect_info["animated_effects"][ll_effect_name]
		var ll_effect_dur_factor: float = ll_effect.get("duration_factor", 1.0)
		ll_effect["base_duration"] = with_duration * ll_effect_dur_factor
		if ll_effect.has("time_offset"):
			ll_effect["time_offset"] *= with_duration
	effect_info["expire_time"] = with_duration
	add_sprite_modifier(effect_info, true)


func do_named_bump_effect(effect_params: Dictionary, with_duration: float = -1) -> void:
	var effect_name: String = effect_params.get("name", "")
	if not effect_name or not effect_name in SpriteEffects.BUMP_EFFECTS:
		push_warning("Unknown bump effect: %s" % effect_name)
		return
	var effect_info: Dictionary = SpriteEffects.BUMP_EFFECTS[effect_name].duplicate_deep()
	SpriteEffects.set_bump_effect_params(effect_name, effect_params, effect_info)
	do_bump_effect(effect_info, with_duration)

func do_bump_effect(effect_info: Dictionary, with_duration: float = -1) -> void:
	if not effect_info:
		return
	effect_info = effect_info.duplicate_deep()
	if with_duration < 0:
		if effect_info.has("duration"):
			with_duration = effect_info["duration"]
		else:
			with_duration = get_move_duration()
	var animated_effects: Dictionary = effect_info.get("animated_effects", {})
	for ll_effect_name in animated_effects:
		var ll_effect: Dictionary = animated_effects[ll_effect_name]
		var ll_effect_dur_factor: float = ll_effect.get("duration_factor", 1.0)
		ll_effect["base_duration"] = with_duration * ll_effect_dur_factor
		if ll_effect.has("time_offset"):
			ll_effect["time_offset"] *= with_duration
	effect_info["expire_time"] = with_duration
	var modifier_name: String = effect_info.get("name", "")
	if modifier_name and sprite.has_applied_modifier(modifier_name):
		remove_sprite_modifier({"name": modifier_name})
	add_sprite_modifier(effect_info)


func set_tailing(entity_to_tail) -> void:
	if tailing and tailing.started_move.is_connected(tail_follow):
		tailing.started_move.disconnect(tail_follow)
	tailing = entity_to_tail
	if tailing:
		tailing.started_move.connect(tail_follow)

func untail() -> void:
	if tailing:
		if tailing.started_move.is_connected(tail_follow):
			tailing.started_move.disconnect(tail_follow)
		add_deferred_event("stopped_tailing", tailing.instance_id)
	tailing = null

func tail_follow(_move_facing) -> void:
	if not tailing:
		return
	if get_steps_per_tile() != tailing.get_moving_steps_per_tile():
		set_steps_per_tile_override(tailing.get_steps_per_tile())
	
	var target_tile = tailing.get_stationary_position()
	if target_tile == tile_position:
		return
	if (target_tile - tile_position).length() > 1:
		if GameManager.get_game_setting("tails_teleport", true):
			var facing_val: = -1 if visual_turn_on_move else -2
			if not start_teleport_to(tile_position, target_tile, -1, facing_val, true):
				untail()
		else:
			untail()
	else:
		var new_facing = Utility.facing_from_adjacent_positions(tile_position, target_tile)
		if not start_move(new_facing, true, false, true):
			untail()
	if moving and not _this_move_is_teleport and not tailing._this_move_is_teleport:
		set_move_interp_override(tailing.get_move_interp_style())

func can_i_move_relative(relative_direction) -> bool:
	return can_i_move(Utility.resolve_relative_direction(relative_direction, move_facing))

func entity_manager_signal(signaling_entity: BaseEntity, args: Array, signal_name: String) -> void:
	if not active:
		return
	if not moving:
		_handle_signal(signaling_entity, args, signal_name)
	else:
		add_deferred_signal(signaling_entity, args, signal_name)

func got_action_signals(action_signals: Array[String]) -> void:
	if not active or EntityManager.get_entity_prop_is_truthy(self, "actions-disabled"):
		return
	for act_sig in action_signals:
		if not moving:
			_handle_action_signal({"is_action_signal": true, "action_signal": act_sig})
		else:
			var already_deferred: = false
			for deferred_sig in deferred_signals:
				if deferred_sig.get("action_signal", "") == act_sig:
					already_deferred = true
					break
			if not already_deferred:
				add_deferred_action_signal(act_sig)

func add_deferred_action_signal(action_signal: String) -> void:
	deferred_signals.append({
		"is_action_signal": true,
		"action_signal": action_signal,
	})

func _handle_signal(signaling_entity: BaseEntity, args: Array, signal_name: String) -> void:
	var handler = EntityManager.get_entity_property(self, "when_signal_" + signal_name)
	if handler and handler.is_conditional():
		handler.resolve(self, signaling_entity, tile_position, args)

func add_sprite_modifier(mod_info: Dictionary, is_dying_effect: bool = false) -> void:
	if not mod_info or not mod_info.get("name", ""):
		return
	sprite.apply_modifier_info(mod_info, is_dying_effect)

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

func is_half_at(check_position: Vector2i) -> bool:
	if not moving or _pending_half_move:
		return check_position == tile_position
	return check_position == next_tile_pos

func add_deferred_signal(signaling_entity: BaseEntity, args: Array, signal_name: String) -> void:
	deferred_signals.append({
		"signaling_entity": signaling_entity.instance_id,
		"args": args,
		"signal_name": signal_name
	})

func add_deferred_event(event_name: String, context_instance_id: int = -1) -> void:
	deferred_signals.append({
		"context_entity": context_instance_id,
		"event_name": event_name,
	})

func process_deferred_signals() -> void:
	for deferred_sig in deferred_signals:
		if deferred_sig.get("is_action_signal", false):
			_handle_action_signal(deferred_sig)
		elif deferred_sig.get("event_name", ""):
			_handle_deferred_event(deferred_sig)
		else:
			var signaling_entity = EntityManager.get_instance(deferred_sig["signaling_entity"])
			_handle_signal(signaling_entity, deferred_sig["args"], deferred_sig["signal_name"])
	deferred_signals.clear()

func _handle_action_signal(deferred_sig: Dictionary) -> void:
	var allowed_actions: Array[String] = ["do_action_1", "do_action_2", "do_action_3"]
	var action_signal = deferred_sig.get("action_signal", "")
	if action_signal not in allowed_actions:
		push_error("Unknown action signal: " + action_signal)
		return
	var action_signal_handler: Property = EntityManager.get_entity_property(self, action_signal)
	if not action_signal_handler or not action_signal_handler.is_conditional():
		return
	action_signal_handler.resolve(self, null, [tile_position], [])

func _handle_deferred_event(deferred_sig: Dictionary) -> void:
	var event_name = deferred_sig.get("event_name", "")
	var context_entity: BaseEntity = null
	if deferred_sig.has("context_entity") and EntityManager.has_instance(deferred_sig["context_entity"]):
		context_entity = EntityManager.get_instance(deferred_sig["context_entity"])
	EntityManager.resolve_entity_interaction_event(event_name, self, context_entity, [tile_position])

func has_local_data() -> bool:
	if local_properties.size() > 0 or removed_properties.size() > 0:
		return true
	return false

static func read_move_interp_style_string(style_str: String, default_style: PosInterpStyle = PosInterpStyle.NONE) -> PosInterpStyle:
	style_str = style_str.to_lower()
	var found_style: Variant = Utility.POS_INTERP_STRINGS.find_key(style_str)
	if found_style:
		return found_style as PosInterpStyle
	return default_style

static func get_move_interp_style_string(style: PosInterpStyle) -> String:
	return Utility.POS_INTERP_STRINGS.get(style, "none")

func set_move_interp_override(style: PosInterpStyle) -> void:
	is_move_interp_override = true
	override_move_interp_style = style

func clear_move_interp_override() -> void:
	is_move_interp_override = false
	override_move_interp_style = PosInterpStyle.NONE

func get_move_interp_style(is_diagonal_adj: bool = false) -> PosInterpStyle:
	if _this_move_is_teleport:
		return get_teleport_interp_style(is_diagonal_adj)
	elif is_move_interp_override:
		return override_move_interp_style
	return move_interp_style

func get_teleport_interp_style(is_diagonal_adj: bool) -> PosInterpStyle:
	if is_move_interp_override:
		return override_move_interp_style
	elif is_diagonal_adj:
		return move_interp_style
	return teleport_interp_style

func is_teleporting() -> bool:
	return moving and _this_move_is_teleport

func is_large() -> bool:
	return false

func is_square_aspect() -> bool:
	return true

func is_visual_moving() -> bool:
	if not moving:
		return false
	if _this_move_steps == 2:
		return steps_remaining == 2
	elif _this_move_steps >= 3:
		if steps_remaining <= ceili(_this_move_steps / 3.0):
			return false
	return true

func pop_controller() -> Node:
	var the_controller = controller
	remove_child(controller)
	controller = null
	return the_controller

func replace_controller(new_controller: Node) -> void:
	if controller and controller.get_parent() == self:
		remove_child(controller)
		controller.queue_free()
	controller = new_controller
	if controller.get_parent() != self:
		add_child(controller)

func apply_teleport_facing_change(_to_pos: Vector2i, new_facing: int, force_immediate_turn: bool) -> void:
	set_facing(new_facing, force_immediate_turn)