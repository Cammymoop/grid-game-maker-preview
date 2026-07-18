extends PanelContainer

@export var bg_stylebox_dark: StyleBoxFlat

@export var texture_rect: TextureRect

func set_texture(texture: Texture2D, relative_scale: float, with_dark_bg: bool, sharp_scale: bool) -> void:
    texture_rect.texture = texture
    texture_rect.custom_minimum_size = texture.get_size() * relative_scale
    if with_dark_bg:
        add_theme_stylebox_override("panel", bg_stylebox_dark)
    
    if sharp_scale:
        texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func set_mod_color(color: Color) -> void:
    texture_rect.modulate = color
