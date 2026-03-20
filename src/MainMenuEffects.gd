extends Node2D

var vel_sprite = preload("res://src/VelocitySprite.gd")

var tile_indexes = []
var entity_indexes = []

@export var fall_speed: = 90.0
@export var max_objects: = 1000
@export var density: = 6.0
@export var size_factor: = 1.0
@export var max_brightness: = 1.0

@export var fall_direction: = "y"

@export var background_color_rect: NodePath
var bg_color:Color

var mouse_push_min = 80
var mouse_push_factor = 6
const ROTATION_FACTOR = 20

func _ready() -> void:
	tile_indexes = MapManager.get_all_tile_indexes()
	entity_indexes = EntityManager.get_all_entity_indexes()
	
	bg_color = get_node(background_color_rect).color
	
	size_changed()
	get_viewport().connect("size_changed", Callable(self, "size_changed"))
	
	# Start with stuff already on the screen
	start_fill()

func start_fill():
	var vp_height = get_viewport_rect().size.y
	var simulate_time = vp_height / fall_speed
	var amount_to_spawn = (1/$NewObjTimer.wait_time) * simulate_time
	
	for i in amount_to_spawn:
		spawn_random_obj(i/amount_to_spawn)

func size_changed():
	$NewObjTimer.wait_time = 1.0 / (get_screen_width() / (density * 20))
	$NewObjTimer.start()

func get_screen_width():
	return get_viewport_rect().size.x
func get_screen_height():
	return get_viewport_rect().size.y

func spawn_random_obj(delta = 0) -> void:
	if get_child_count() > max_objects or not visible:
		return
	
	if Utility.random_int_range(0, 6) == 0:
		spawn_random_tile(delta)
	else:
		spawn_random_entity(delta)

func spawn_random_entity(delta) -> void:
	var spr = vel_sprite.new()
	spr.centered = true
	var entity_index = Utility.random_list_element(entity_indexes)
	spr.texture = Utility.atlas_texture_from_entity_index(entity_index)
	spawn_common(spr, delta)

func spawn_random_tile(delta) -> void:
	var spr = vel_sprite.new()
	spr.centered = true
	var tile_index = Utility.random_list_element(tile_indexes)
	spr.texture = Utility.atlas_texture_from_tile_index(tile_index)
	spawn_common(spr, delta)
	
func spawn_common(spr: Sprite2D, delta) -> void:
	spr.rotation = randf_range(0, PI * 2)
	
	var scale_factor = randf_range(0, 1)
	spr.scale = Vector2.ONE * (1 + (scale_factor * 1.4)) * size_factor
	
	spr.modulate = Color.WHITE.lerp(bg_color, 1 - (scale_factor*max_brightness))
	
	spr.z_index = scale_factor * 100
	
	if "y" in fall_direction:
		spr.position.x = randf_range(0, get_screen_width())
		spr.position.y = -(MapManager.tile_width*1.5*spr.scale.x)
		if delta:
			spr.position.y += (get_screen_height() * delta) * spr.scale.x
		
		if fall_direction == "-y":
			spr.position.y = get_screen_height() - spr.position.y
	else:
		spr.position.y = randf_range(0, get_screen_height())
		spr.position.x = -(MapManager.tile_width*1.5*spr.scale.x)
		if delta:
			spr.position.x += (get_screen_width() * delta) * spr.scale.x
		
		if fall_direction == "-x":
			spr.position.x = get_screen_width() - spr.position.x
	
	spr.x_velocity = 0.0
	spr.y_velocity = 0.0
	if "y" in fall_direction:
		spr.y_velocity = fall_speed * spr.scale.x
		if fall_direction == "-y":
			spr.y_velocity = -spr.y_velocity
	else:
		spr.x_velocity = fall_speed * spr.scale.x
		if fall_direction == "-x":
			spr.x_velocity = -spr.x_velocity
		
	spr.angular_velocity = 0.0
	
	if Utility.random_int_range(0, 2) == 0:
		spr.angular_velocity = Utility.random_sign() * randf_range(0, PI)
	add_child(spr)
	
	

func _process(delta):
	var mouse = get_viewport().get_mouse_position()
	
	var despawn_border = MapManager.tile_width * 2.4 * 2
	
	var fall_y = "y" in fall_direction
	var fall_sign = -1 if "-" in fall_direction else 1
	var fall_v = fall_speed * fall_sign
	
	for spr in get_children():
		if not spr is Sprite2D:
			continue
		
		# Lerp proper axis to proper fall speed
		var spr_fall_v = fall_v * spr.scale.x
		if fall_y:
			if abs(spr.y_velocity - spr_fall_v) > 0.01:
				spr.y_velocity = lerpf(spr.y_velocity, spr_fall_v, 0.7*delta)
		else:
			if abs(spr.x_velocity - spr_fall_v) > 0.01:
				spr.x_velocity = lerpf(spr.x_velocity, spr_fall_v, 0.7*delta)
		
		var mouse_diff = (mouse - spr.position).length()
		
		var other_delta = 0
		if fall_y:
			other_delta = lerpf(spr.x_velocity, 0, 1.5 * delta) - spr.x_velocity
		else:
			other_delta = lerpf(spr.y_velocity, 0, 1.5 * delta) - spr.y_velocity
		spr.angular_velocity = lerpf(spr.angular_velocity, 0, 0.1 * delta)
		if mouse_diff < mouse_push_min:
			var dir = sign(spr.position.x - mouse.x)
			
			var closeness = (mouse_push_min - max(mouse_diff, 0.5))/mouse_push_min
			var squared = (1 + closeness) * (1 + closeness)
			
			other_delta += dir * squared * mouse_push_factor
			
			spr.angular_velocity += dir * (squared/ROTATION_FACTOR)
		
		if fall_y:
			spr.x_velocity += other_delta
		else:
			spr.y_velocity += other_delta
		
		spr.position.y += spr.y_velocity * delta
		spr.position.x += spr.x_velocity * delta
		spr.rotation += spr.angular_velocity * delta
		
		if spr.position.y - despawn_border > get_screen_height():
			spr.queue_free()
		elif spr.position.x - despawn_border > get_screen_width():
			spr.queue_free()
		elif min(spr.position.y + despawn_border, spr.position.x + despawn_border) < 0:
			spr.queue_free()

func _input(e):
	var mouse_click_event = e as InputEventMouseButton
	if not mouse_click_event or not mouse_click_event.is_pressed():
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	if mouse_pos.y < 45:
		fall_direction = "-y"
	elif get_screen_height() - mouse_pos.y < 45:
		fall_direction = "y"
	elif mouse_pos.x < 45:
		fall_direction = "-x"
	elif get_screen_width() - mouse_pos.x < 45:
		fall_direction = "x"

func _on_NewObjTimer_timeout():
	spawn_random_obj()
