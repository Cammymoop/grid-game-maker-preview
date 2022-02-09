extends Node2D

var vel_sprite = preload("res://src/VelocitySprite.gd")

var tile_indexes = []
var entity_indexes = []

export var fall_speed: = 90.0
export var max_objects: = 1000
export var density: = 6.0
export var size_factor: = 1.0
export var max_brightness: = 1.0

export var background_color_rect: NodePath
var bg_color:Color

var mouse_push_min = 80
var mouse_push_factor = 6
const ROTATION_FACTOR = 20

func _ready() -> void:
	tile_indexes = MapManager.get_all_tile_indexes()
	entity_indexes = EntityManager.get_all_entity_indexes()
	
	bg_color = get_node(background_color_rect).color
	
	size_changed()
	get_viewport().connect("size_changed", self, "size_changed")

func size_changed():
	$NewObjTimer.wait_time = 1.0 / (get_screen_width() / (density * 20))

func get_screen_width():
	return get_viewport_rect().size.x
func get_screen_height():
	return get_viewport_rect().size.y

func spawn_random_obj() -> void:
	if get_child_count() > max_objects or not visible:
		return
	
	if Utility.random_int_range(0, 6) == 0:
		spawn_random_tile()
	else:
		spawn_random_entity()

func spawn_random_entity() -> void:
	var spr = vel_sprite.new()
	spr.centered = true
	var entity_index = Utility.random_list_element(entity_indexes)
	spr.texture = Utility.atlas_texture_from_entity_index(entity_index)
	spawn_common(spr)

func spawn_random_tile() -> void:
	var spr = vel_sprite.new()
	spr.centered = true
	var tile_index = Utility.random_list_element(tile_indexes)
	spr.texture = Utility.atlas_texture_from_tile_index(tile_index)
	spawn_common(spr)
	
func spawn_common(spr: Sprite) -> void:
	spr.rotation = rand_range(0, PI * 2)
	
	var scale_factor = rand_range(0, 1)
	spr.scale = Vector2.ONE * (1 + (scale_factor * 1.4)) * size_factor
	
	spr.modulate = Color.white.linear_interpolate(bg_color, 1 - (scale_factor*max_brightness))
	
	spr.z_index = scale_factor * 100
	
	spr.position.y = -(MapManager.tile_width*1.5*spr.scale.x)
	spr.position.x = rand_range(0, get_screen_width())
	
	spr.x_velocity = 0.0
	spr.angular_velocity = 0.0
	
	if Utility.random_int_range(0, 2) == 0:
		spr.angular_velocity = Utility.random_sign() * rand_range(0, PI)
	add_child(spr)
	
	

func _process(delta):
	var mouse = get_viewport().get_mouse_position()
	for spr in get_children():
		if not spr is Sprite:
			continue
		spr.position.y += fall_speed * delta * spr.scale.x
		
		var mouse_diff = (mouse - spr.position).length()
		
		spr.x_velocity = lerp(spr.x_velocity, 0, 1.5 * delta)
		spr.angular_velocity = lerp(spr.angular_velocity, 0, 0.1 * delta)
		if mouse_diff < mouse_push_min:
			var dir = sign(spr.position.x - mouse.x)
			
			var closeness = (mouse_push_min - max(mouse_diff, 0.5))/mouse_push_min
			var squared = (1 + closeness) * (1 + closeness)
			#spr.set("horizontal_velocity", dir * squared * mouse_push_factor)
			spr.x_velocity += dir * squared * mouse_push_factor
			
			#spr.set("angular_velocity", dir * squared/100)
			spr.angular_velocity += dir * (squared/ROTATION_FACTOR)
		
		spr.position.x += spr.x_velocity * delta
		spr.rotation += spr.angular_velocity * delta
		
		if spr.position.y - (MapManager.tile_width * spr.scale.x * 1.5) > get_screen_height():
			spr.queue_free()


func _on_NewObjTimer_timeout():
	spawn_random_obj()
