extends Viewport

func _ready():
	
	get_texture().flags = Texture.FLAG_FILTER
	get_parent().texture = get_texture()


func set_resolution(new_resolution: Vector2) -> void:
	size = new_resolution
	
	# Let the texture rect know it needs to scale the texture again
	var tex_rect = get_parent()
	tex_rect.expand = false
	tex_rect.expand = true
