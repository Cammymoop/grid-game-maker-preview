extends Node2D

var facing: = 0

var moving: = false
var steps_remaining:int = 0

onready var sprite: = $Sprite

# tiles per second
var actual_move_speed = 0
var steps_per_tile:int = 0

var controller = null

var tile_position = Vector2(0, 0)
var next_tile_pos = Vector2(0, 0)

var entity_index = 0

var active = false

func _ready() -> void:
	tile_position = MapManager.world_to_tile_position(global_position)

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

func start_move(move_facing) -> void:
	set_facing(move_facing)
	if actual_move_speed > 0:
		next_tile_pos = tile_position + Utility.facing_vector(move_facing)
		if MapManager.can_move_to(self, next_tile_pos):
			moving = true
			steps_remaining = steps_per_tile
		else:
			next_tile_pos = tile_position

func set_controller(new_controller) -> void:
	controller = new_controller

func set_facing(new_facing):
	facing = new_facing
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
	
	steps_per_tile = max(1, round(fps / intended))
	actual_move_speed = MapManager.tile_width / float(steps_per_tile)

func can_i_move(facing) -> bool:
	var my_pos = tile_position if not moving else next_tile_pos
	var target_pos = my_pos + Utility.facing_vector(facing)
	
	return MapManager.can_move_to(self, target_pos)

func can_i_move_relative(relative_direction) -> bool:
	return can_i_move(Utility.resolve_relative_direction(relative_direction, facing))
