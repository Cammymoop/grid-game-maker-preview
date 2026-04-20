extends Camera2D

signal camera_target_changed(entity: BaseEntity)

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

func _ready():
	EntityManager.entity_list_updated.connect(on_entity_list_updated)
	EntityManager.entity_became_active.connect(on_entity_became_active)
	
	respect_level_bounds = Utility.get_camera_setting("enable_limits", false)
	MapManager.level_size_changed.connect(update_bounds)
	
	var ext = Utility.get_camera_setting("extend_limits", 0)
	if ext:
		extend_level_bounds = int(ext)
	
	GameManager.level_state_loaded.connect(on_level_state_loaded)

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
		return
	
	if Input.is_action_just_pressed("camera_next_target"):
		follow_next(1)
	elif Input.is_action_just_pressed("camera_prev_target"):
		follow_next(-1)
	
	var pos_target: = position
	if target_entity and is_instance_valid(target_entity):
		var find_new_target: = false
		if was_target_active != target_entity.active:
			if was_target_active:
				find_new_target = true
			was_target_active = target_entity.active

		if find_new_target:
			find_entity_to_follow()
		else:
			pos_target = get_target_iterpolated_pos()
	
	if smoothing_enabled:
		position = position.lerp(pos_target, smoothing_amount * delta)
	else:
		position = pos_target

func is_target_active() -> bool:
	return target_entity and is_instance_valid(target_entity) and target_entity.active

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
	was_target_active = target_entity.active
	camera_target_changed.emit(target_entity)

func follow_next(dir: int = 1) -> void:
	if not active:
		return
	if not target_entity or not is_instance_valid(target_entity):
		find_entity_to_follow()
		return

	var follow_targets: = get_follow_targets()
	if not follow_targets.has(target_entity):
		find_entity_to_follow()
		return
	elif follow_targets.size() < 2:
		return

	var target_instance_ids: Array[int] = []
	for entity in follow_targets:
		target_instance_ids.append(entity.instance_id)
	
	target_instance_ids.sort()
	var cur_index: = target_instance_ids.find(target_entity.instance_id)
	var new_index: = posmod(cur_index + dir, target_instance_ids.size())
	follow_entity(EntityManager.get_instance(target_instance_ids[new_index]))
	explicitly_following = true
	
func get_follow_targets() -> Array[BaseEntity]:
	var follow_this = Utility.get_camera_setting("follow_entity", "")
	var by_mode = Utility.get_camera_setting("follow_entity_by", "property")
	
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
	var follow_targets: = get_follow_targets()
	# Prefer active entities
	for entity in follow_targets:
		if entity.active:
			follow_entity(entity)
			break
	if not target_entity:
		for entity in follow_targets:
			follow_entity(entity)

func teleport(pos: Vector2) -> void:
	position = pos

func on_level_state_loaded() -> void:
	if target_entity and is_instance_valid(target_entity):
		teleport(get_target_iterpolated_pos())

func get_target_iterpolated_pos() -> Vector2:
	if not override_target_interp_style or not target_entity.moving:
		return target_entity.global_position + ent_center_offset
	
	var target_from_pos: = MapManager.tile_to_world_position(target_entity.get_stationary_position())
	var target_to_pos: = MapManager.tile_to_world_position(target_entity.next_tile_pos)
	return target_from_pos.lerp(target_to_pos, target_entity.get_move_progress()) + ent_center_offset
	