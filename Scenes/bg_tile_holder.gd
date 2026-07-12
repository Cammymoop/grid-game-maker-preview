extends Node2D

const DEFAULT_TILE_COLOR: Color = Color(0.28, 0.22, 0.48)

@export var parallax_amount: float = 1.0

@export var scrolling_piece: Node2D
@export var tiling_sprite: Sprite2D

@export var texture_maker_subviewport: SubViewport
@export var texture_maker_sprite: Sprite2D

const TILING_EXTENTS: int = 4096

const NEAREST_UPSCALE: int = 4
const NEAREST_UPSCALE_LARGE: int = 2

var parent_vp: Viewport

var repeat_vector: Vector2 = Vector2.ONE * 128

func _ready() -> void:
    parent_vp = get_viewport()

func update_bg_tile_info(bg_info: Dictionary, between_z_index: int) -> void:
    var is_enabled: bool = bg_info.get("bg_tile_on", false)
    visible = is_enabled
    if not is_enabled:
        return
    
    parallax_amount = bg_info.get("bg_tile_camera_scroll_factor", 0.5)
    
    var tile_angle: float = bg_info.get("bg_tile_angle", 0.0)
    var angle_radians: = tile_angle * TAU
    rotation = angle_radians

    var texture_id: = int(bg_info.get("bg_tile_texture_id", -1))
    var texture_index: = int(bg_info.get("bg_tile_texture_index", 0))
    if texture_id < 0 or not TextureManager.has_texture_id(texture_id):
        texture_id = TextureManager.get_fallback_texture_id()
    
    var tile_scale: float = bg_info.get("bg_tile_scale", 1.0)
    var is_smooth_scale: bool = bg_info.get("bg_tile_smooth_scale", false)
    
    var tile_spacing: Vector2 = Utility.get_vector2_from_arr(bg_info.get("bg_tile_spacing", [0, 0]))
    
    var mod_color: Color = Utility.get_dict_color(bg_info, "bg_tile_color", DEFAULT_TILE_COLOR)
    tiling_sprite.modulate = mod_color
    
    var bg_tile_above: String = bg_info.get("bg_tile_above", "below")
    if bg_tile_above == "between":
        z_index = between_z_index
    elif bg_tile_above == "above":
        z_index = 6
    else:
        z_index = -6
    
    var parent: Node = get_parent()
    var is_below_gradient: bool = bg_info.get("bg_tile_below_gradient", true)
    if is_below_gradient:
        parent.move_child(self, 0)
    else:
        parent.move_child(self, parent.get_child_count() - 1)

    var atlas_texture: = Utility.atlas_texture_from_texture_index(texture_id, texture_index)
    atlas_texture.filter_clip = true
    
    var spacing_vec: Vector2 = atlas_texture.region.size * tile_spacing
    var total_size: Vector2 = atlas_texture.region.size + spacing_vec
    
    var largest_dimension: float = maxf(total_size.x, total_size.y)
    
    var upscale_factor: float = 1
    if not is_smooth_scale and largest_dimension < 1024:
        upscale_factor = NEAREST_UPSCALE_LARGE
        if largest_dimension < 512:
            upscale_factor = NEAREST_UPSCALE
        tile_scale /= upscale_factor

    if is_smooth_scale:
        texture_maker_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    else:
        texture_maker_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    
    texture_maker_sprite.texture = atlas_texture
    texture_maker_sprite.position = total_size * 0.5 * upscale_factor
    texture_maker_sprite.scale = Vector2.ONE * upscale_factor
    var vp_texture_size: = total_size * upscale_factor
    texture_maker_subviewport.size = vp_texture_size
    texture_maker_subviewport.render_target_update_mode = SubViewport.UPDATE_ONCE
    
    tiling_sprite.scale = Vector2.ONE * tile_scale
    
    var extent_scale: float = 1
    if tile_scale < 1:
        extent_scale = 1 / tile_scale
    var extent_size: Vector2 = ((Vector2.ONE * TILING_EXTENTS * extent_scale) / vp_texture_size).ceil()
    extent_size *= vp_texture_size
    tiling_sprite.region_rect.size = extent_size
    
    repeat_vector = vp_texture_size * tile_scale
    scroll_updated()

func scroll_updated() -> void:
    var scroll_offset: Vector2 = -parent_vp.canvas_transform.origin
    
    position = scroll_offset * (1 - parallax_amount)
    
    var screen_center: Vector2 = scroll_offset + parent_vp.size * 0.5
    var center_local: = to_local(screen_center)
    
    var closest_snap: = center_local.snapped(repeat_vector)
    scrolling_piece.position = closest_snap