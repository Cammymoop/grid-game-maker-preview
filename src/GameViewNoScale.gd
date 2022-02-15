extends Viewport

func _ready():
	get_parent().texture = get_texture()

func set_resolution(new_resolution: Vector2) -> void:
	size = new_resolution
	
	var tex_rect = get_parent()
	tex_rect.get_viewport().set_resolution(new_resolution * 4)
	
	# Let the texture rect know it needs to scale the texture again
	tex_rect.expand = false
	tex_rect.expand = true

func get_resolution():
	return size

func get_scaled_mouse_position():
	return get_mouse_position()
