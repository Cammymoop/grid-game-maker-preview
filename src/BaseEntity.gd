extends Node2D

var facing: = 0

var moving: = false
var steps_remaining:int = 0

onready var sprite: = $Sprite

# tiles per second
var actual_move_speed = 0
var steps_per_tile:int = 0

var controller = null
var controller_name = null

var tile_position = Vector2(0, 0)
var next_tile_pos = Vector2(0, 0)

var entity_index = 0
var entity_name = null

var active = false

var local_properties = {}

func _ready() -> void:
	tile_position = MapManager.world_to_tile_position(global_position)
	next_tile_pos = tile_position
	entity_name = EntityManager.get_entity_name(entity_index)

func serialize() -> Dictionary:
	var important_stuff = {"entity_index": entity_index, "active": active, "moving": moving, "facing": facing}
	important_stuff['tile_position'] = [tile_position.x, tile_position.y]
	important_stuff['next_tile_pos'] = [next_tile_pos.x, next_tile_pos.y]
	important_stuff['local_properties'] = local_properties.duplicate()
	important_stuff['steps_per_tile'] = steps_per_tile
	important_stuff['position'] = [position.x, position.y]
	if moving:
		important_stuff['steps_remaining'] = steps_remaining
	if controller_name:
		important_stuff['controller_name'] = controller_name
	
	return important_stuff

func deserialize(data: Dictionary) -> void:
	active = data['active']
	set_real_speed(data['steps_per_tile'])
	entity_index = data['entity_index']
	entity_name = EntityManager.get_entity_name(entity_index)
	local_properties = data['local_properties']
	
	set_facing(int(data['facing']))
	moving = data['moving']
	position = Vector2(data['position'][0], data['position'][1])
	tile_position = Vector2(data['tile_position'][0], data['tile_position'][1])
	next_tile_pos = Vector2(data['next_tile_pos'][0], data['next_tile_pos'][1])
	if "steps_remaining" in data:
		steps_remaining = int(data["steps_remaining"])
	
	if "controller_name" in data:
		controller_name = data['controller_name']
		var new_controller = EntityManager.get_new_controller(controller_name)
		add_child(new_controller)
		set_controller(new_controller)

func set_active(new_active) -> void:
	active = new_active

func _physics_process(_delta) -> void:
	if not active:
		return
	
	if not moving:
		var intended = get_intended_move()
		if intended > -1:
			start_move(intended)
	if moving:
		position += Utility.facing_vector(facing) * actual_move_speed
		steps_remaining -= 1
		if steps_remaining < 1:
			finish_move()
			var intended = get_intended_move()
			if intended > -1:
				start_move(intended)

func has_local_property(property_name) -> bool:
	return property_name in local_properties

func get_local_property(property_name):
	return local_properties[property_name]

func set_local_property(property_name, value) -> void:
	local_properties[property_name] = value

func remove_local_property(property_name) -> void:
	local_properties.erase(property_name)

func get_intended_move():
	if not controller:
		return -1
	
	if controller.move_mode == "direction":
		return Utility.direction_to_facing(controller.get_move())
	else:
		return controller.get_move()

func finish_move() -> void:
	position = Vector2(int(round(position.x)), int(round(position.y)))
	#tile_position = next_tile_pos
	tile_position = MapManager.world_to_tile_position(global_position)
	if tile_position != next_tile_pos:
		print("???")
	moving = false
	MapManager.finish_move(self, tile_position)

func start_move(move_facing) -> bool:
	if moving:
		print_debug("Tried to start move when already moving")
		return false
	set_facing(move_facing)
	if actual_move_speed > 0:
		next_tile_pos = tile_position + Utility.facing_vector(move_facing)
		var not_stopped = MapManager.attempt_move(self, next_tile_pos)
		if not_stopped:
			moving = true
			steps_remaining = steps_per_tile
			return true
		else:
			next_tile_pos = tile_position
			return false
	return false

func set_controller(new_controller) -> void:
	controller = new_controller

func set_facing(new_facing):
	facing = new_facing
	var no_rotate = EntityManager.get_entity_property(self, "no_rotation")
	if no_rotate != null and no_rotate.get_value():
		return
	match facing:
		0:
			sprite.rotation = 0
		1:
			sprite.rotation = PI/2.0
		2:
			sprite.rotation = PI
		3:
			sprite.rotation = 3 * PI/2.0

func set_intended_move_speed(intended) -> void:
	var fps = ProjectSettings.get("physics/common/physics_fps")
	
	if intended > 0:
		steps_per_tile = max(1, round(fps / intended))
		actual_move_speed = MapManager.tile_width / float(steps_per_tile)
	else:
		steps_per_tile = 0
		actual_move_speed = 0

func set_real_speed(new_steps_per_tile) -> void:
	steps_per_tile = new_steps_per_tile
	if steps_per_tile == 0:
		actual_move_speed = 0
	else:
		actual_move_speed = MapManager.tile_width / float(steps_per_tile)

func can_i_move(facing) -> bool:
	var my_pos = tile_position if not moving else next_tile_pos
	var target_pos = my_pos + Utility.facing_vector(facing)
	
	return MapManager.can_move_to(self, target_pos)

func die() -> void:
	var dying = EntityManager.get_entity_property(self, "dying")
	if dying and dying.is_conditional():
		dying.resolve(self, null, tile_position)
	EntityManager.remove_entity(self)

func can_i_move_relative(relative_direction) -> bool:
	return can_i_move(Utility.resolve_relative_direction(relative_direction, facing))
