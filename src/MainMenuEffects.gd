extends Node2D

const VelocitySprite = preload("res://src/VelocitySprite.gd")

var tile_indexes: = []
var tile_defs: = {}
var entity_indexes: = []
var entity_defs: = {}

@export_range(0, 500, 1) var fall_speed: = 90.0
@export var max_objects_cap: int = 1000
@export_range(0.1, 20, 0.1) var density: = 6.0
@export var size_factor: = 1.0
@export_range(0, 50, 0.1) var spinniness: = 1

@export_range(0, 2, 0.05) var max_brightness: = 1.0
@export_exp_easing var color_ease_param: float = 1

@export var changeable_direction: = true

@export var proportional_tile_bias: = true
@export_range(0, 1, 0.05) var tile_bias: = 0.5

@export_enum("up", "down", "left", "right") var fall_direction: = "down"
var gravity_vector: Vector2 = Vector2.DOWN

@export var background_color_rect: NodePath
var bg_color:Color

@export_range(0, 1000, 1) var mouse_push_min_distance: float = 80
@export_range(0, 48, 0.1) var mouse_push_factor: float = 6
@export_range(0, 20, 0.1) var mouse_spin_factor: float = 1
@export_exp_easing var mouse_push_ease_param: float = 0.2
const ROTATION_ADJUST = 1/20.0

var dropping_allowed: = true

func _ready() -> void:
	TextureManager.textures_loaded.connect(on_textures_loaded)
	set_fall_direction(fall_direction)
	set_process_input(changeable_direction)
	tile_indexes = MapManager.get_all_tile_indexes()
	tile_defs = MapManager.tile_defs.duplicate_deep()
	entity_indexes = EntityManager.get_all_entity_indexes()
	entity_defs = EntityManager.entity_defs.duplicate_deep()
	
	bg_color = get_node(background_color_rect).color
	
	size_changed()
	get_viewport().connect("size_changed", Callable(self, "size_changed"))
	
	# Start with stuff already on the screen
	start_fill()

func restart() -> void:
	for child in get_children():
		if child is VelocitySprite:
			child.queue_free()
	reload_definitions()
	dropping_allowed = true
	start_fill()

func pause_drops() -> void:
	dropping_allowed = false

func reload_definitions() -> void:
	tile_indexes = MapManager.get_all_tile_indexes()
	tile_defs = MapManager.tile_defs.duplicate_deep()
	entity_indexes = EntityManager.get_all_entity_indexes()
	entity_defs = EntityManager.entity_defs.duplicate_deep()

func start_fill() -> void:
	var vp_height = get_viewport_rect().size.y
	var simulate_time = vp_height / fall_speed
	var amount_to_spawn = (1/$NewObjTimer.wait_time) * simulate_time
	
	for i in amount_to_spawn:
		spawn_random_obj(i/amount_to_spawn)

func size_changed() -> void:
	$NewObjTimer.wait_time = 1.0 / (get_viewport_rect().size.x / (density * 20))
	$NewObjTimer.start()

func spawn_random_obj(fall_delta: float = 0) -> void:
	if not dropping_allowed:
		return
	if get_child_count() >= max_objects_cap or not visible:
		return
	var num_entities = entity_indexes.size()
	var num_tiles = tile_indexes.size()
	if num_entities + num_tiles == 0:
		return
	
	var tile_chance = tile_bias
	if proportional_tile_bias:
		tile_chance *= num_tiles / float(num_entities + num_tiles)
	if num_entities == 0 or randf() < tile_chance:
		spawn_random_tile(fall_delta)
	else:
		spawn_random_entity(fall_delta)

func spawn_random_entity(fall_delta: float) -> void:
	if entity_indexes.size() == 0:
		return
	var spr: = VelocitySprite.new()
	spr.centered = true
	var entity_index: int = Utility.random_list_element(entity_indexes)
	spr.texture = EntityManager.get_entity_sprite_snapshot(entity_index, true)
	spr.scale *= EntityManager.get_entity_sprite_snapshot_scale(entity_index, true, false)
	spawn_common(spr, fall_delta)

func spawn_random_tile(fall_delta: float) -> void:
	if tile_indexes.size() == 0:
		return
	var spr: = VelocitySprite.new()
	spr.centered = true
	var tile_index = Utility.random_list_element(tile_indexes)
	spr.texture = Utility.atlas_texture_from_texture_index(tile_defs[tile_index]['texture'], tile_defs[tile_index]['tex_index'])
	spawn_common(spr, fall_delta)
	
func spawn_common(spr: VelocitySprite, fall_delta: float) -> void:
	spr.rotation = randf_range(0, PI * 2)
	
	var depth_factor: = randf_range(0, 1)
	var base_scale: float = 0.5 + (depth_factor * 1.5) * size_factor
	spr.set_meta("base_scale", base_scale)

	var sprite_scale: = base_scale
	var cur_size: Vector2 = spr.texture.get_size() * base_scale
	var max_axis_size: float = maxf(cur_size.x, cur_size.y)
	if max_axis_size > MapManager.tile_width * 3:
		sprite_scale *= MapManager.tile_width * 3 / max_axis_size
	spr.scale *= sprite_scale
	
	spr.modulate = Utility.lerp_ok_hsl_color(bg_color, Color.WHITE, depth_factor) * max_brightness
	
	spr.z_index = int(depth_factor * 1000)
	
	var screen_size: = get_viewport_rect().size
	if gravity_vector.y != 0:
		spr.position.x = randf_range(0, screen_size.x)
		spr.position.y = -(MapManager.tile_width * 1.5 * base_scale)
		if fall_delta:
			spr.position.y += (screen_size.y * fall_delta) * spr.scale.x
		
		if gravity_vector.y < 0:
			spr.position.y = screen_size.y - spr.position.y
	else:
		spr.position.y = randf_range(0, screen_size.y)
		spr.position.x = -(MapManager.tile_width * 1.5 * base_scale)
		if fall_delta:
			spr.position.x += (screen_size.x * fall_delta) * spr.scale.x
		
		if gravity_vector.x < 0:
			spr.position.x = screen_size.x - spr.position.x
	
	spr.x_velocity = gravity_vector.x * fall_speed * base_scale
	spr.y_velocity = gravity_vector.y * fall_speed * base_scale
		
	spr.angular_velocity = 0.0
	if randf() < 0.5:
		spr.angular_velocity = Utility.random_sign() * randf() * PI * spinniness
	add_child(spr)
	
	

func _process(delta: float) -> void:
	var mouse: = get_viewport().get_mouse_position()
	
	var perpendicular: = gravity_vector.rotated(TAU/4)

	var despawn_border = MapManager.tile_width * size_factor * 4
	var despawn_bounds: = Rect2(Vector2.ZERO, get_viewport_rect().size).grow(despawn_border)
	
	for spr in get_children():
		if not spr is VelocitySprite:
			continue
		
		var fall_veocity_target = gravity_vector * spr.get_meta("base_scale") * fall_speed
		spr.set_spr_velocity(spr.get_spr_velocity().lerp(fall_veocity_target, 0.7 * delta))
		
		spr.angular_velocity = lerpf(spr.angular_velocity, 0, 0.1 * delta)
		var mouse_diff = (mouse - spr.position).length()
		
		if mouse_diff < mouse_push_min_distance:
			var dir: = signf(perpendicular.dot(spr.position - mouse))
			
			var closeness: float = (mouse_push_min_distance - maxf(mouse_diff, 0.5))/mouse_push_min_distance
			var pushness: float = 1 + ease(closeness, mouse_push_ease_param)
			spr.add_spr_velocity(perpendicular * dir * pushness * mouse_push_factor)
			spr.angular_velocity -= dir * pushness * mouse_spin_factor * ROTATION_ADJUST
		
		spr.step(delta)
		
		if not despawn_bounds.has_point(spr.position):
			spr.queue_free()

# input process is disabled if changeable_direction is false
func _input(e: InputEvent) -> void:
	var mouse_click_event: = e as InputEventMouseButton
	if not mouse_click_event or not mouse_click_event.is_pressed():
		return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size: = get_viewport_rect().size
	if minf(mouse_pos.y, screen_size.y - mouse_pos.y) < 45:
		set_gravity_vector(Vector2.DOWN * signf(mouse_pos.y - screen_size.y / 2))
	elif minf(mouse_pos.x, screen_size.x - mouse_pos.x) < 45:
		set_gravity_vector(Vector2.RIGHT * signf(mouse_pos.x - screen_size.x / 2))

func set_gravity_vector(new_gravity_vector: Vector2) -> void:
	gravity_vector = new_gravity_vector

func set_fall_direction(new_direction: String) -> void:
	fall_direction = new_direction
	gravity_vector = Utility.facing_vector(Utility.direction_to_facing(new_direction))

func _on_NewObjTimer_timeout() -> void:
	spawn_random_obj()

func on_textures_loaded() -> void:
	reload_definitions()