extends HBoxContainer

@export var name_label: Label
@export var image_texture_rect: TextureRect

func set_name_and_image(name: String, image: Texture2D) -> void:
    name_label.text = name
    image_texture_rect.texture = image
