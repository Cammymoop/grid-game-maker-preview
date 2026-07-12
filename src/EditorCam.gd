extends Camera2D

@export var edge_limit_tile_count: int = 9
var extend_limits = 0
@onready var vp = get_viewport()

@export var game_view: Node = null

var _cached_center_limits: Rect2 = Rect2()

var _enable_limits: = true

func _ready():
	MapManager.connect("level_size_changed", Callable(self, "update_bounds"))
	
	update_bounds()

func _process(_delta: float) -> void:
	if is_current():
		game_view.update_screen_space_camera_displacement(get_screen_center_position())

func set_position_immediate(pos: Vector2) -> void:
	position_smoothing_enabled = false
	outsize_bounds()
	position = pos
	force_update_scroll()
	
	# wait for a frame so the camera is positioned properly before we re-enable smoothing and the level bounds
	await get_tree().process_frame
	position_smoothing_enabled = true
	update_bounds()

func set_enable_limits(new_enabled: bool) -> void:
	_enable_limits = new_enabled
	update_bounds()

func get_limits() -> Rect2:
	return Rect2(limit_left, limit_top, limit_right - limit_left, limit_bottom - limit_top)

func set_limits_rect(rect: Rect2) -> void:
	limit_left = rect.position.x
	limit_top = rect.position.y
	limit_right = rect.end.x
	limit_bottom = rect.end.y

func get_center_limits() -> Rect2:
	if _cached_center_limits:
		return _cached_center_limits
	var game_render_size: Vector2 = vp.get_resolution()
	var limits: = get_limits()
	limits.position += game_render_size/2
	limits.size = Vector2(max(0, limits.size.x - game_render_size.x), max(0, limits.size.y - game_render_size.y))
	_cached_center_limits = limits
	return limits

func _clamped_by_limits(pos: Vector2) -> Vector2:
	var center_lim = get_center_limits()
	return pos.clamp(center_lim.position, center_lim.end)

func do_scroll(scroll_vec: Vector2) -> void:
	var pos = _clamped_by_limits(position)
	position = pos + scroll_vec

func move_to_pos(pos: Vector2) -> void:
	position = _clamped_by_limits(pos)

func get_tl_position() -> Vector2:
	return get_screen_center_position() - (vp.get_resolution()/2)

func outsize_bounds() -> void:
	set_limits_rect(Rect2().grow(10000000))
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000
	_cached_center_limits = Rect2()

func update_bounds() -> void:
	if not _enable_limits:
		outsize_bounds()
		return
	extend_limits = MapManager.tile_width * edge_limit_tile_count

	var game_render_size: Vector2 = vp.get_resolution()
	var level_bounds = MapManager.get_level_bounds().grow(extend_limits)
	var bound_center: Vector2 = level_bounds.get_center()

	if level_bounds.size.x < game_render_size.x:
		level_bounds.position.x = bound_center.x - game_render_size.x/2
		level_bounds.size.x = game_render_size.x
	if level_bounds.size.y < game_render_size.y:
		level_bounds.position.y = bound_center.y - game_render_size.y/2
		level_bounds.size.y = game_render_size.y
	set_limits_rect(level_bounds)
	_cached_center_limits = Rect2()

func reset_zoom() -> void:
	GameManager.update_game_viewport()
	update_bounds()

func zoom_in() -> float:
	return zoom_in_out(-1)

func zoom_out() -> float:
	return zoom_in_out(1)

func zoom_in_out(dir: float) -> float:
	var base_vp_size: Vector2 = GameManager.get_base_window_size()
	var current_vp_size: Vector2 = vp.intended_resolution

	var cur_multiplier: float = current_vp_size.x / base_vp_size.x
	var new_multiplier: float = cur_multiplier + (dir * .25)
	return _set_zoom_to(new_multiplier)

func set_zoom_to(multiplier: float) -> float:
	return _set_zoom_to(multiplier)

func _set_zoom_to(multiplier: float) -> float:
	var base_vp_size: Vector2 = GameManager.get_base_window_size()
	
	var long_side_lenght: float = max(base_vp_size.x, base_vp_size.y)
	var max_vp_target_size: float = 4096
	var max_factor: float = floorf((max_vp_target_size / long_side_lenght) * 4) * 0.25
	multiplier = clamp(multiplier, .25, max_factor)
	
	vp.set_resolution(base_vp_size * multiplier)
	update_bounds()
	return multiplier