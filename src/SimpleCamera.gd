extends Camera2D

signal camera_target_changed(entity: BaseEntity)
signal no_more_targets()

var active: = false
var target_entity: BaseEntity = null
var respect_level_bounds: = true
var extend_level_bounds: = 0

var ent_center_offset: = Vector2.ZERO

var was_target_active: = false
var explicitly_following: = false

var delaying: = false
var delay_pos: = Vector2.ZERO

var override_target_interp_style: = true
var smoothing_enabled: = true
var smoothing_amount: = 32

var teleport_override_interp: = false

var is_shaking: = false
var shake_intensity: float = 0.0
var shake_timer: float = 0.0

func _ready():
	EntityManager.entity_list_updated.connect(on_entity_list_updated)
	EntityManager.entity_became_active.connect(on_entity_became_active)
	
	respect_level_bounds = Utility.get_camera_setting("enable_limits", false)
	MapManager.level_size_changed.connect(update_bounds)
	
	var ext = Utility.get_camera_setting("extend_limits", 0)
	if ext:
		extend_level_bounds = int(ext)
	
	GameManager.any_state_loaded.connect(on_state_loaded)

func update_bounds() -> void:
	if not respect_level_bounds:
		return
	var level_bounds = MapManager.get_level_bounds().grow(extend_level_bounds)
	limit_left = level_bounds.position.x
	limit_top = level_bounds.position.y
	limit_right = level_bounds.end.x
	limit_bottom = level_bounds.end.y
	
	var vp_size = get_viewport().get_resolution()
	if limit_right - limit_left < vp_size.x:
		var center_x = level_bounds.position.x + level_bounds.size.x/2
		limit_left = center_x - vp_size.x/2
		limit_right = center_x + vp_size.x/2
	if limit_bottom - limit_top < vp_size.y:
		var center_y = level_bounds.position.y + level_bounds.size.y/2
		limit_top = center_y - vp_size.y/2
		limit_bottom = center_y + vp_size.y/2

func activate():
	active = true
	print_stack()
	make_current()
	if explicitly_following and target_entity and is_instance_valid(target_entity):
		follow_entity(target_entity)
	else:
		find_entity_to_follow()

func deactivate():
	active = false
	if not explicitly_following:
		target_entity = null

func _process(delta):
	if not active:
		offset = Vector2.ZERO
		return
	
	if Input.is_action_just_pressed("camera_next_target"):
		follow_next(1)
	elif Input.is_action_just_pressed("camera_prev_target"):
		follow_next(-1)
	
	var pos_target: = position
	if target_entity and is_instance_valid(target_entity):
		var find_new_target: = false
		if was_target_active != is_target_active():
			if was_target_active:
				find_new_target = true
			was_target_active = is_target_active()

		if find_new_target:
			find_entity_to_follow()
		else:
			pos_target = get_target_iterpolated_pos()
	
	if smoothing_enabled:
		position = position.lerp(pos_target, smoothing_amount * delta)
	else:
		position = pos_target
	
	if is_shaking and shake_timer > 0:
		shake_timer -= delta
		if shake_timer <= 0:
			shake_timer = 0
			is_shaking = false
		offset = Vector2(randf() * 2 - 1, randf() * 2 - 1) * shake_intensity
	else:
		offset = Vector2.ZERO

func get_targeted_position() -> Vector2:
	var potential_target: BaseEntity = null
	if target_entity and is_instance_valid(target_entity) and is_current():
		potential_target = target_entity
	elif target_entity and is_instance_valid(target_entity) and explicitly_following:
		potential_target = target_entity
	else:
		potential_target = _find_entity_to_follow()
	
	if not potential_target:
		return position
	return get_entity_interp_pos(potential_target)

func is_target_active() -> bool:
	if target_entity and is_instance_valid(target_entity):
		if target_entity.dying:
			return true
		else:
			return target_entity.active
	else:
		return false

func on_entity_list_updated() -> void:
	if not target_entity or not is_instance_valid(target_entity):
		find_entity_to_follow()
	elif not explicitly_following and not is_target_active():
		find_entity_to_follow()

func on_entity_became_active(entity: BaseEntity) -> void:
	if not explicitly_following and not is_target_active():
		if should_follow_entity(entity):
			follow_entity(entity)

func should_follow_entity(entity: BaseEntity) -> bool:
	var follow_this: String = Utility.get_camera_setting("follow_entity", "")
	var by_mode: String = Utility.get_camera_setting("follow_entity_by", "property")
	if not follow_this or not by_mode:
		return false
	
	if by_mode == "name":
		return EntityManager.get_entity_name(entity.entity_index) == follow_this
	elif by_mode == "property":
		return EntityManager.get_entity_prop_is_truthy(entity, follow_this)
	else:
		push_warning("Unknown follow entity by mode: " + by_mode)
		return false

func follow_entity(entity: BaseEntity) -> void:
	if not entity or entity == target_entity:
		return
	target_entity = entity
	ent_center_offset = target_entity.get_center_offset()
	was_target_active = is_target_active()
	camera_target_changed.emit(target_entity)

func follow_next(dir: int = 1) -> void:
	if not active:
		return
	if not target_entity or not is_instance_valid(target_entity):
		find_entity_to_follow()
		return
	var new_target: = get_next_prev_follow_target(dir)
	if new_target:
		explicitly_following = true
		follow_entity(new_target)
	
func get_follow_targets() -> Array[BaseEntity]:
	var follow_this = Utility.get_camera_setting("follow_entity", "")
	var by_mode = Utility.get_camera_setting("follow_entity_by", "property")
	if by_mode == "instances":
		var ent_arr: Array[BaseEntity] = []
		ent_arr.assign(EntityManager.get_camera_following_instances())
		return ent_arr
	
	var follow_targets: Array[BaseEntity] = []
	if follow_this:
		if by_mode == "name":
			#print_debug("finding name " + follow_this)
			var ent_index = EntityManager.get_entity_index(follow_this)
			follow_targets = EntityManager.find_all_entities_by_index(ent_index, false)
		elif by_mode == "property":
			follow_targets = EntityManager.find_all_entities_with_truthy_property(follow_this, false)
		else:
			push_warning("Unknown follow entity by mode: " + by_mode)
	return follow_targets

func find_entity_to_follow() -> void:
	if not active:
		return
	explicitly_following = false
	var next_to_follow: = _find_entity_to_follow()
	target_entity = next_to_follow
	if not target_entity:
		no_more_targets.emit()
	else:
		camera_target_changed.emit(target_entity)

func _find_entity_to_follow() -> BaseEntity:
	var follow_targets: = get_follow_targets()
	# Prefer active entities
	for entity in follow_targets:
		if entity.active:
			return entity
	for entity in follow_targets:
		return entity
	return null

func get_next_prev_follow_target(dir: int = 1) -> BaseEntity:
	if not active or dir == 0:
		return null
	dir = signi(dir)
	var follow_targets: = get_follow_targets()
	var cur_index: = follow_targets.find(target_entity)
	if cur_index == -1:
		cur_index = follow_targets.size() - 1 if dir > 0 else 0
	# Prefer active entities
	var next_index: = posmod(cur_index + dir, follow_targets.size())
	while next_index != cur_index:
		if follow_targets[next_index].active:
			return follow_targets[next_index]
		next_index = posmod(next_index + dir, follow_targets.size())

	# now for any regardless of active status
	return follow_targets[posmod(cur_index + dir, follow_targets.size())]

func teleport(pos: Vector2) -> void:
	position = pos

func on_state_loaded() -> void:
	if not active:
		return
	if target_entity and is_instance_valid(target_entity):
		teleport(get_target_iterpolated_pos())
	else:
		find_entity_to_follow()

func get_target_iterpolated_pos() -> Vector2:
	return get_entity_interp_pos(target_entity)

func get_entity_interp_pos(entity: BaseEntity) -> Vector2:
	var use_entity_interp_pos: = not override_target_interp_style or not entity.moving
	if entity.is_teleporting():
		use_entity_interp_pos = not teleport_override_interp
	if use_entity_interp_pos:
		return entity.global_position + ent_center_offset
	
	var target_from_pos: = MapManager.tile_to_world_position(entity.get_stationary_position())
	var target_to_pos: = MapManager.tile_to_world_position(entity.next_tile_pos)
	return target_from_pos.lerp(target_to_pos, entity.get_move_progress()) + ent_center_offset
	
func do_screen_shake(intensity: float, duration: float) -> void:
	if not is_shaking:
		shake_timer = 0
	is_shaking = true
	shake_intensity = intensity
	shake_timer = maxf(shake_timer, duration)

func stop_screen_shake() -> void:
	is_shaking = false
	shake_timer = 0