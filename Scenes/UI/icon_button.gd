@tool
extends ButtonContainer

@export var tex_rect: TextureRect
@export var icon: Texture2D:
    get:
        if not tex_rect:
            return null
        return tex_rect.texture
    set(new_tex):
        if tex_rect:
            tex_rect.texture = new_tex
            if _scale != 1.0:
                _update_min_size()

var _scale: float = 1.0

func set_icon(new_icon: Texture2D) -> void:
    icon = new_icon

func reset_icon_scale() -> void:
    _scale = 1.0
    tex_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
    tex_rect.custom_minimum_size = Vector2.ZERO

func set_icon_scale(new_scale: float) -> void:
    _scale = new_scale
    if _scale == 1.0:
        reset_icon_scale()
    else:
        _update_min_size()

func _update_min_size() -> void:
    tex_rect.custom_minimum_size = icon.get_size() * _scale