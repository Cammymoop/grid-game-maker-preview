extends Viewport

var scale_factor = 4
var resolution = Vector2(384, 384)

func _ready():
	set_size_override(true, Vector2(384, 384))
	set_size_override_stretch(true)
	
	get_texture().flags = Texture.FLAG_FILTER
	get_parent().texture = get_texture()

func set_resolution(new_resolution: Vector2) -> void:
	size = new_resolution * scale_factor
	set_size_override(true, new_resolution)
	
	# Let the texture rect know it needs to scale the texture again
	var tex_rect = get_parent()
	tex_rect.expand = false
	tex_rect.expand = true

func get_resolution() -> Vector2:
	return resolution

func get_scaled_mouse_position():
	# Why do I divide by 2??
	return get_mouse_position() * scale_factor/2
