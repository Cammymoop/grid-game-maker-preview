extends Camera2D

var active = false
var target_entity = null
var respect_level_bounds
var extend_level_bounds: = 0

var ent_center_offset = Vector2.ZERO

func _ready():
	EntityManager.connect("entity_list_updated", self, "find_entity_to_follow")
	
	respect_level_bounds = Utility.get_camera_setting("enable_limits")
	MapManager.connect("level_size_changed", self, "update_bounds")
	
	var ext = Utility.get_camera_setting("extend_limits")
	if ext:
		extend_level_bounds = ext

func update_bounds() -> void:
	if not respect_level_bounds:
		return
	var level_bounds = MapManager.get_level_bounds()
	limit_left = level_bounds.position.x - extend_level_bounds
	limit_top = level_bounds.position.y - extend_level_bounds
	limit_right = level_bounds.end.x + extend_level_bounds
	limit_bottom = level_bounds.end.y + extend_level_bounds
	
	var vp_size = get_viewport().get_resolution()
	if limit_right - limit_left < vp_size.x:
		var center_x = level_bounds.position.x + level_bounds.size.x/2
		limit_left = center_x - vp_size.x/2
		limit_right = center_x + vp_size.x/2
	if limit_bottom - limit_top < vp_size.y:
		var center_y = level_bounds.position.y + level_bounds.size.y/2
		limit_top = center_y - vp_size.y/2
		limit_bottom = center_y + vp_size.y/2
	print([limit_left, limit_right])

func activate():
	active = true
	current = true
	find_entity_to_follow()

func deactivate():
	active = false
	target_entity = false

var c = 0

func _process(_delta):
	if not active:
		return
	
	if target_entity and is_instance_valid(target_entity):
		position = target_entity.global_position + ent_center_offset

func find_entity_to_follow() -> void:
	if not active:
		return
	
	var follow_this = Utility.get_camera_setting("follow_entity")
	var by_mode = Utility.get_camera_setting("follow_entity_by")
	
	if follow_this:
		if not by_mode or by_mode == "name":
			#print_debug("finding name " + follow_this)
			var ent_index = EntityManager.get_entity_index(follow_this)
			target_entity = EntityManager.find_entity_by_index(ent_index, false)
			if target_entity:
				ent_center_offset = target_entity.get_center_offset()
			else:
				print_debug("not found name " + follow_this + " " + str(ent_index))
		else:
			target_entity = EntityManager.find_entity_with_property(follow_this, false)
			if target_entity:
				ent_center_offset = target_entity.get_center_offset()
		
