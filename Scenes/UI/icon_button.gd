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

