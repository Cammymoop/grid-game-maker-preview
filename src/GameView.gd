extends SubViewport

var scale_factor = 4
var resolution = Vector2(384, 384)
var intended_resolution = Vector2(384, 384)

var parent_vp

var update_aspect: = true

var cached_pixel_scale = null
var cached_tl_offset = null

func _ready():
	size_2d_override = resolution
	set_size_2d_override_stretch(true)
	
	var parent: = get_parent() as TextureRect
	parent.texture = get_texture()
	parent.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

	parent_vp = parent.get_viewport()
	parent_vp.connect("size_changed", Callable(self, "rescale"))
	
func set_update_aspect(new_val) -> void:
	update_aspect = new_val
	if update_aspect:
		# When we are updating our own aspect ratio, scale the short side to fit the texture
		# This is important because we are rounding up to the nearest pixel for the side that 
		# we are extending so it's often going to be longer than the window when scaled up
		get_parent().stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		get_parent().stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func rescale() -> void:
	cached_pixel_scale = null
	cached_tl_offset = null
	
	if update_aspect:
		set_resolution(intended_resolution)

func set_resolution(new_resolution: Vector2) -> void:
	intended_resolution = new_resolution
	resolution = new_resolution
	if update_aspect:
		resolution = fit_resolution_into_aspect()
		#var window_size = Vector2(get_window().size)
		#prints("fitting", new_resolution, "into aspect", window_size.x/window_size.y, "result:", resolution)
	size = resolution * scale_factor
	size_2d_override = resolution
	
	# Let the texture rect know it needs to scale the texture again
	var tex_rect: = get_parent() as TextureRect
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func fit_resolution_into_aspect() -> Vector2:
	var window_size: Vector2 = Vector2(get_window().size)
	var intended_aspect = intended_resolution.x/intended_resolution.y
	var window_aspect = window_size.x/window_size.y
	
	var out_res = intended_resolution
	if intended_aspect == window_aspect:
		return out_res
	
	# window is relatively wider than intended resolution
	if intended_aspect < window_aspect:
		out_res.x = ceil(intended_resolution.y * window_aspect)
	# window is relatively taller than intended resolution
	else:
		out_res.y = ceil(intended_resolution.x / window_aspect)
	return out_res

func get_resolution() -> Vector2:
	return resolution

func get_current_pixel_scale() -> float:
	if cached_pixel_scale:
		return cached_pixel_scale
	var window_size = get_window().size
	var intended_aspect = intended_resolution.x/intended_resolution.y
	var window_aspect = window_size.x/window_size.y
	
	# Return window size in the short side (relative to our intended aspect)
	# divided by our resolution in that axis
	if intended_aspect <= window_aspect:
		cached_pixel_scale = window_size.y / intended_resolution.y
	else:
		cached_pixel_scale = window_size.x / intended_resolution.x
	return cached_pixel_scale

func get_viewport_tl_offset() -> Vector2:
	if cached_tl_offset:
		return cached_tl_offset
	var window_size = get_window().size
	
	var pixel_scale = get_current_pixel_scale()
	var x_off = (window_size.x - (resolution.x*pixel_scale))/2
	var y_off = (window_size.y - (resolution.y*pixel_scale))/2
	cached_tl_offset = Vector2(x_off, y_off)
	return cached_tl_offset
	

func get_scaled_mouse_position():
	var mouse_pos = parent_vp.get_mouse_position()
	mouse_pos -= get_viewport_tl_offset()
	return mouse_pos / get_current_pixel_scale()
