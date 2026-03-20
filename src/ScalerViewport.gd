extends SubViewport

func _ready():
	var vp_display: = get_parent() as TextureRect
	if not vp_display:
		return
	
	vp_display.texture = get_texture()
	vp_display.filter_mode = CanvasItem.TEXTURE_FILTER_LINEAR

func set_resolution(new_resolution: Vector2) -> void:
	size = new_resolution
	
	# Let the texture rect know it needs to scale the texture again
	var tex_rect = get_parent()
	tex_rect.expand = false
	tex_rect.expand = true
