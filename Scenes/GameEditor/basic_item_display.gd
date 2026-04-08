extends Control

@export var main_min_size: Vector2 = Vector2(32, 32)
@export var main_max_size: Vector2 = Vector2(96, 96)
@export var small_size_ratio: float = 0.4

@export var main_tex_rect: TextureRect
@export var small_tex_container: Control
@export var small_tex_rect: TextureRect

func fetch_textures(for_item_definition: Dictionary) -> void:
    var has_preview_variant: bool = not for_item_definition.get("preview_variant", {}).is_empty()
    small_tex_container.visible = has_preview_variant
    if not has_preview_variant:
        _set_main_texture_indices(for_item_definition['texture'], for_item_definition['tex_index'])
    else:
        _set_small_texture_indices(for_item_definition["texture"], for_item_definition["tex_index"])
        var preview_variant: Dictionary = for_item_definition["preview_variant"]
        _set_main_texture_indices(preview_variant["texture"], preview_variant["tex_index"])

func _set_main_texture_indices(texture_index: int, tex_sub_index: int) -> void:
    main_tex_rect.texture = Utility.atlas_texture_from_texture_index(texture_index, tex_sub_index)

func _set_small_texture_indices(texture_index: int, tex_sub_index: int) -> void:
    small_tex_rect.texture = Utility.atlas_texture_from_texture_index(texture_index, tex_sub_index)