extends Control

@export var main_min_size: Vector2 = Vector2(32, 32)
@export var main_max_size: Vector2 = Vector2(96, 96)
@export var small_size_ratio: float = 0.4

@export var main_tex_rect: TextureRect
@export var small_tex_container: Control
@export var small_tex_rect: TextureRect

func fetch_textures(item_id: int, for_item_definition: Dictionary, tile_entity_mode: String) -> void:
    var has_preview_variant: bool = not for_item_definition.get("preview_variant", {}).is_empty()
    small_tex_container.visible = has_preview_variant
    var has_fancy_sprite: bool = tile_entity_mode == "entity" and EntityManager.entity_sprite_snapshots.has(item_id)
    if not has_preview_variant:
        _set_main_texture(item_id, for_item_definition, has_fancy_sprite)
    else:
        _set_small_texture(item_id, for_item_definition, has_fancy_sprite)
        var preview_variant: Dictionary = for_item_definition["preview_variant"]
        _set_tex_by_indices(main_tex_rect, preview_variant["texture"], preview_variant["tex_index"])

func _get_crop_area(snapshot_size: Vector2, snapshot_scale: float) -> Rect2:
    var scaled_tile_size: = (Vector2.ONE * MapManager.tile_width) / snapshot_scale
    var snapshot_center: Vector2 = snapshot_size / 2
    return Rect2(snapshot_center - scaled_tile_size / 2, scaled_tile_size)

func _set_main_texture(item_id: int, basic_sprite_info: Dictionary, has_fancy_sprite: bool) -> void:
    _set_tex(item_id, main_tex_rect, basic_sprite_info, has_fancy_sprite)

func _set_small_texture(item_id: int, basic_sprite_info: Dictionary, has_fancy_sprite: bool) -> void:
    _set_tex(item_id, small_tex_rect, basic_sprite_info, has_fancy_sprite)

func _set_tex(item_id: int, tex_rect: TextureRect, basic_sprite_info: Dictionary, has_fancy_sprite: bool) -> void:
    if not has_fancy_sprite:
        _set_tex_by_indices(tex_rect, basic_sprite_info["texture"], basic_sprite_info["tex_index"])
    else:
        var snapshot: ImageTexture = EntityManager.get_entity_sprite_snapshot(item_id)
        var snap_scale: float = EntityManager.get_entity_sprite_snapshot_scale(item_id, false, false)
        var snapshot_crop: AtlasTexture = AtlasTexture.new()
        snapshot_crop.atlas = snapshot
        snapshot_crop.region = _get_crop_area(snapshot.get_size(), snap_scale)
        tex_rect.texture = snapshot_crop

func _set_tex_by_indices(tex_rect: TextureRect, texture_index: int, tex_sub_index: int) -> void:
    tex_rect.texture = Utility.atlas_texture_from_texture_index(texture_index, tex_sub_index)