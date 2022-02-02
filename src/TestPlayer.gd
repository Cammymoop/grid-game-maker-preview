extends Node2D

var facing: = 0

var moving: = false

onready var sprite: = $Sprite

var physics_step: = 0

# tiles per second
var intended_move_speed: = 6
var actual_move_speed = 0

var tile_width: = 32

func _ready() -> void:
	var fps = ProjectSettings.get("physics/common/physics_fps")
	physics_step = 1 / fps
	
	var steps_per_tile = ceil(fps / intended_move_speed)
	actual_move_speed = tile_width / steps_per_tile
	
	print_debug("My effective move speed is " + str((actual_move_speed * fps)/tile_width) + " tiles per second")

func _physics_process(_delta) -> void:
	var iup = Input.is_action_pressed("move_up")
	var idown = Input.is_action_pressed("move_down")
	var ileft = Input.is_action_pressed("move_left")
	var iright = Input.is_action_pressed("move_right")
	
	var intended_move = "up"
	var move_input = false
	
	if iup and not idown:
		intended_move = "up"
		move_input = true
	elif idown and not iup:
		intended_move = "down"
		move_input = true
	elif ileft and not iright:
		intended_move = "left"
		move_input = true
	elif iright and not ileft:
		intended_move = "right"
		move_input = true
	
	if not moving and move_input:
		set_facing(Utility.direction_to_facing(intended_move))
		moving = true
	if moving:
		position += Utility.facing_vector(facing) * actual_move_speed
		var int_pos = Vector2(round(position.x), round(position.y))
		if int(int_pos.x) % tile_width == 0 and int(int_pos.y) % tile_width == 0:
			if move_input:
				set_facing(Utility.direction_to_facing(intended_move))
			else:
				moving = false

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
