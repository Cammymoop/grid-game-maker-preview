extends Node2D

const DEFAULT_TILE_COLOR: Color = Color(0.28, 0.22, 0.48)

@export var bg_scroll_multiplier: float = 240.0

@export var parallax_amount: float = 0.5

@export var scrolling_piece: Node2D
@export var tiling_sprite: Sprite2D

@export var texture_maker_subviewport: SubViewport
@export var texture_maker_sprite: Sprite2D

@export var crossfade_time: float = 0.5

const TILING_EXTENTS: int = 4096

const MAX_REGION_FACTOR: float = 500

const NEAREST_UPSCALE: int = 4
const NEAREST_UPSCALE_LARGE: int = 2

var scale_with_camera: bool = false

var base_offset: Vector2 = Vector2.ZERO

var auto_scrolling_vector: Vector2 = Vector2.ZERO
var accumulated_auto_scroll: Vector2 = Vector2.ZERO

var camera_zoom_factor: float = 2.0

var camera_scroll_pos: Vector2 = Vector2.ZERO

var parent_vp: Viewport

var base_scale: Vector2 = Vector2.ONE

var tile_size: Vector2 = Vector2.ONE * 128
var repeat_vector: Vector2 = Vector2.ONE * 128

var old_texture: String = ""

func _ready() -> void:
    parent_vp = get_viewport()

func camera_zoom_changed(new_camera_zoom_factor: float) -> void:
    camera_zoom_factor = new_camera_zoom_factor
    if scale_with_camera:
        update_scale()

func update_bg_tile_info(bg_info: Dictionary) -> void:
    var is_enabled: bool = bg_info.get("bg_tile_on", false)
    visible = is_enabled
    if not is_enabled:
        return
    
    var do_reset_auto_scroll: bool = auto_scrolling_vector == Vector2.ZERO
    
    parallax_amount = bg_info.get("bg_tile_camera_scroll_factor", 0.5)
    
    var tile_angle: float = bg_info.get("bg_tile_angle", 0.0)
    var angle_radians: = tile_angle * TAU
    rotation = angle_radians

    var texture_id: = int(bg_info.get("bg_tile_texture_id", -1))
    var texture_index: = int(bg_info.get("bg_tile_texture_index", 0))
    if texture_id < 0 or not TextureManager.has_texture_id(texture_id):
        texture_id = TextureManager.get_fallback_texture_id()
    
    var texture_key: String = str(texture_id) + "::" + str(texture_index)
    if texture_key != old_texture:
        do_reset_auto_scroll = true
    old_texture = texture_key
    
    var is_enable_auto_scroll: bool = bg_info.get("bg_tile_auto_scroll_on", false)
    if is_enable_auto_scroll:
        auto_scrolling_vector = Vector2.UP * bg_info.get("bg_tile_auto_scroll_speed", 0.5) * bg_scroll_multiplier
        var auto_scroll_angle_radians: float = bg_info.get("bg_tile_auto_scroll_angle", 0.0) * TAU
        auto_scrolling_vector = auto_scrolling_vector.rotated(auto_scroll_angle_radians)
    else:
        auto_scrolling_vector = Vector2.ZERO
    
    var tile_scale: float = bg_info.get("bg_tile_scale", 1.0)
    var is_smooth_scale: bool = bg_info.get("bg_tile_smooth_scale", false)
    
    scale_with_camera = bg_info.get("bg_tile_scale_with_camera", true)
    
    var tile_spacing: Vector2 = Utility.get_vector2_from_arr(bg_info.get("bg_tile_spacing", [0, 0]))
    
    var mod_color: Color = Utility.get_dict_color(bg_info, "bg_tile_color", DEFAULT_TILE_COLOR)
    tiling_sprite.modulate = mod_color
    
    var parent: Node = get_parent()
    var is_below_gradient: bool = bg_info.get("bg_tile_below_gradient", true)
    if is_below_gradient:
        parent.move_child(self, 0)
    else:
        parent.move_child(self, parent.get_child_count() - 1)

    var atlas_texture: = Utility.atlas_texture_from_texture_index(texture_id, texture_index)
    atlas_texture.filter_clip = true
    
    
    var old_base_offset: Vector2 = base_offset
    tile_size = atlas_texture.region.size
    base_offset = Utility.get_vector2_from_arr(bg_info.get("bg_tile_base_offset", [0.0, 0.0])) * tile_size

    if old_base_offset != base_offset:
        do_reset_auto_scroll = true
    
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
    
    base_scale = Vector2.ONE * tile_scale;
    if tiling_sprite.scale != base_scale:
        do_reset_auto_scroll = true
    tiling_sprite.scale = base_scale
    if scale_with_camera:
        tiling_sprite.scale *= camera_zoom_factor
    
    var extent_scale: float = 1
    if tile_scale < 1:
        extent_scale = 1 / tile_scale
    var extent_size: Vector2 = ((Vector2.ONE * TILING_EXTENTS * extent_scale) / vp_texture_size).ceil()
    extent_size *= vp_texture_size
    extent_size = extent_size.min(Vector2.ONE * TILING_EXTENTS * MAX_REGION_FACTOR)
    tiling_sprite.region_rect.size = extent_size
    tiling_sprite.region_rect.position = (-extent_size * 0.5) + (vp_texture_size * 0.5)
    
    if do_reset_auto_scroll:
        accumulated_auto_scroll = Vector2.ZERO
    
    repeat_vector = vp_texture_size * tiling_sprite.scale
    scroll_updated()

func update_scale() -> void:
    var camera_adjusted_scale: Vector2 = base_scale * (camera_zoom_factor if scale_with_camera else 1.0)
    tiling_sprite.scale = camera_adjusted_scale
    repeat_vector = Vector2(texture_maker_subviewport.size) * camera_adjusted_scale
    update_position_and_snap()

func scroll_updated() -> void:
    camera_scroll_pos = -parent_vp.canvas_transform.origin
    update_position_and_snap()

func update_position_and_snap() -> void:
    var half_vp_size: Vector2 = parent_vp.size * 0.5

    position = half_vp_size + (camera_scroll_pos * parallax_amount) + accumulated_auto_scroll

    var scaled_base_offset: Vector2 = base_offset
    if scale_with_camera:
        scaled_base_offset *= camera_zoom_factor
    
    var screen_center: Vector2 = camera_scroll_pos + half_vp_size
    var center_local: = to_local(screen_center)
    
    var closest_snap: = center_local.snapped(repeat_vector)
    scrolling_piece.position = closest_snap + scaled_base_offset

func _process(delta: float) -> void:
    if not visible:
        return
    
    if auto_scrolling_vector != Vector2.ZERO:
        accumulated_auto_scroll += auto_scrolling_vector * delta
        update_position_and_snap()