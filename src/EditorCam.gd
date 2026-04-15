extends Camera2D

@export var edge_limit_tile_count: int = 4
var extend_limits = 0
@onready var vp = get_viewport()

func _ready():
	MapManager.connect("level_size_changed", Callable(self, "update_bounds"))
	
	update_bounds()

func set_position_immediate(pos: Vector2) -> void:
	position_smoothing_enabled = false
	outsize_bounds()
	position = pos
	force_update_scroll()
	
	# wait for a frame so the camera is positioned properly before we re-enable smoothing and the level bounds
	await get_tree().process_frame
	position_smoothing_enabled = true
	update_bounds()

func get_limits() -> Rect2:
	return Rect2(limit_left, limit_top, limit_right - limit_left, limit_bottom - limit_top)

var cached_center_limits = null

func get_center_limits() -> Rect2:
	if cached_center_limits:
		return cached_center_limits
	var screen = vp.get_resolution()
	var limits = get_limits()
	limits.position += screen/2
	limits.size = Vector2(max(0, limits.size.x - screen.x), max(0, limits.size.y - screen.y))
	cached_center_limits = limits
	return limits

func _clamped_by_limits(pos: Vector2) -> Vector2:
	var center_lim = get_center_limits()
	if pos.x < center_lim.position.x:
		pos.x = center_lim.position.x
	if pos.y < center_lim.position.y:
		pos.y = center_lim.position.y
	if pos.x > center_lim.end.x:
		pos.x = center_lim.end.x
	if pos.y > center_lim.end.y:
		pos.y = center_lim.end.y
	return pos

func do_scroll(scroll_vec: Vector2) -> void:
	var pos = _clamped_by_limits(position)
	position = pos + scroll_vec

func move_to_pos(pos: Vector2) -> void:
	position = _clamped_by_limits(pos)

func get_tl_position() -> Vector2:
	return get_screen_center_position() - (vp.get_resolution()/2)

func outsize_bounds() -> void:
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000
	cached_center_limits = null

func update_bounds() -> void:
	extend_limits = MapManager.tile_width * edge_limit_tile_count

	var level_bounds = MapManager.get_level_bounds()
	limit_left = level_bounds.position.x - extend_limits
	limit_top = level_bounds.position.y - extend_limits
	limit_right = level_bounds.end.x + extend_limits
	limit_bottom = level_bounds.end.y + extend_limits
	
	var vp_size = vp.get_resolution()
	if limit_right - limit_left < vp_size.x:
		var center_x = level_bounds.position.x + level_bounds.size.x/2
		limit_left = center_x - vp_size.x/2
		limit_right = center_x + vp_size.x/2
	if limit_bottom - limit_top < vp_size.y:
		var center_y = level_bounds.position.y + level_bounds.size.y/2
		limit_top = center_y - vp_size.y/2
		limit_bottom = center_y + vp_size.y/2
	cached_center_limits = null
