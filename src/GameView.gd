extends SubViewport

# render to an oversized subviewport and scale the resulting texture to the actual screen res for good looking but still soft interpolation
var overscale_factor: int = 2

var resolution = Vector2(384, 384)
var intended_resolution = Vector2(384, 384)

var parent_vp

var aspect_expand: = true

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
	parent_vp.size_changed.connect(rescale)
	
func set_update_aspect(new_val) -> void:
	aspect_expand = new_val
	get_parent().stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func rescale() -> void:
	cached_pixel_scale = null
	cached_tl_offset = null
	
	set_resolution(intended_resolution)

func set_resolution(new_resolution: Vector2) -> void:
	#get_window().min_size = Vector2i(new_resolution / 2)
	intended_resolution = new_resolution
	resolution = fit_resolution_into_aspect(aspect_expand)
	if maxf(resolution.x, resolution.y) > 1024:
		size = resolution
		size_2d_override = resolution
	else:
		size = resolution * overscale_factor
		size_2d_override = resolution
	
	# Let the texture rect know it needs to scale the texture again
	var tex_rect: = get_parent() as TextureRect
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func fit_resolution_into_aspect(is_expand: bool) -> Vector2:
	var window_size: Vector2 = Vector2(get_window().size)
	var intended_aspect = intended_resolution.x/intended_resolution.y
	var window_aspect = window_size.x/window_size.y
	
	var out_res = intended_resolution
	if intended_aspect == window_aspect:
		return out_res
	
	# window is relatively wider than intended resolution
	if intended_aspect < window_aspect == is_expand:
		out_res.x = ceil(intended_resolution.y * window_aspect)
	# window is relatively taller than intended resolution
	else:
		out_res.y = ceil(intended_resolution.x / window_aspect)
	return out_res

func get_resolution() -> Vector2:
	return resolution

func get_current_pixel_scale() -> float:
	#if cached_pixel_scale:
		#return cached_pixel_scale
	#var window: = get_window()
	#var window_size = window.size
	return get_window().size.y / resolution.y

func get_viewport_tl_offset() -> Vector2:
	#if cached_tl_offset:
		#return cached_tl_offset
	var window_size = get_window().size / get_window().content_scale_factor
	
	var pixel_scale = get_current_pixel_scale()
	var x_off = (window_size.x - (resolution.x*pixel_scale))/2
	var y_off = (window_size.y - (resolution.y*pixel_scale))/2
	cached_tl_offset = Vector2(x_off, y_off)
	return cached_tl_offset
	

func get_scaled_mouse_position():
	var mouse_pos = parent_vp.get_mouse_position() * get_window().content_scale_factor
	#return mouse_pos

	#mouse_pos -= get_viewport_tl_offset()
	#var stretch_transform = get_window().get_stretch_transform()
	#prints("stretch transform pos:", stretch_transform.origin, "scale:", stretch_transform.x.length(), " -- ", stretch_transform)
	return mouse_pos / get_current_pixel_scale()
