extends Node

const BGParticleParallaxHelper: = preload("res://Scenes/bg_particle_parallax_helper.gd")
const BGTileHolder: = preload("res://Scenes/bg_tile_holder.gd")
const ParticleEmitterParallax: = preload("res://Scenes/particle_emitter_parallax.gd")

@export var game_view: Node = null

@export var effect_subviewport: SubViewport
@export var effect_fixed_in_viewport: Node2D

@export var bg_color_rect: ColorRect
@export var dusty_particles: GPUParticles2D
@export var pointy_particles: GPUParticles2D
@export var bg_gradient: TextureRect

@export var dusty_particles_parallax_helper: BGParticleParallaxHelper
@export var pointy_particles_parallax_helper: BGParticleParallaxHelper

@export var bg_tile_holder: BGTileHolder
@export var bg_tile_layer: CanvasLayer

@export var lines: Sprite2D
@export var lines_solid: Sprite2D
@export var lines_layer: CanvasLayer

@export var gradient_texture: GradientTexture2D
@export var gradient_layer: CanvasLayer

var default_bg_color: Color = Color.BLACK
var default_bg_gradient_color: Color = Color.BLACK

var default_particles_color: Color = Color.GRAY
var default_pointy_particles_color: Color = Color.WHITE

var dusty_particles_density: float = 1.0
var dusty_particles_base_speed: float = 1

var pointy_particles_rainbow_hue_var: float = 0
var pointy_particles_base_speed: float = 1
var pointy_particles_density: float = 1.0

var pointy_particles_dark_mode: bool = false


var lines_color: Color = Color.WHITE
var lines_solid_color: Color = Color.WHITE
var lines_scroll_speed: float = 0.05
var lines_scroll_angle: float = 0.4
var lines_warp_strength: float = 1.0
var lines_warp_scroll_speed: float = 0.05
var lines_warp_scroll_angle: float = 0.4

var lines_camera_scroll_factor: float = 0.0
var lines_solid_camera_scroll_factor: float = 0.0

var shader_time_loop_factor: float = 60.0

func _ready() -> void:
    if game_view:
        game_view.camera_displacement_changed.connect(on_camera_displacement_changed)
        game_view.camera_zoom_changed.connect(on_camera_zoom_changed)
        
        if bg_tile_holder:
            bg_tile_holder.camera_zoom_changed(game_view.get_current_pixel_scale())
    
    shader_time_loop_factor = ProjectSettings.get_setting("rendering/limits/time/time_rollover_secs", 60.0)
    
    bg_gradient.texture = gradient_texture

    GameManager.bg_style_changed.connect(on_bg_style_changed)
    default_bg_color = bg_color_rect.color
    default_bg_gradient_color = bg_gradient.modulate

    default_particles_color = dusty_particles.modulate
    dusty_particles_base_speed = dusty_particles.speed_scale
    
    dusty_particles_density = dusty_particles.density

    pointy_particles_base_speed = pointy_particles.speed_scale
    pointy_particles_density = pointy_particles.density
    var pointy_mat: ParticleProcessMaterial = pointy_particles.process_material
    pointy_particles_rainbow_hue_var = pointy_mat.hue_variation_max
    default_pointy_particles_color = pointy_mat.color
    default_pointy_particles_color.a = pointy_particles.modulate.a
    
    var pointy_canvas_mat: CanvasItemMaterial = pointy_particles.material
    pointy_particles_dark_mode = pointy_canvas_mat.blend_mode == CanvasItemMaterial.BLEND_MODE_SUB
    
    var lines_shader: ShaderMaterial = lines.material
    lines_scroll_speed = lines_shader.get_shader_parameter("scroll_speed")
    lines_scroll_angle = lines_shader.get_shader_parameter("scroll_angle")
    lines_warp_strength = lines_shader.get_shader_parameter("displacement_strength")
    lines_warp_scroll_speed = lines_shader.get_shader_parameter("displacement_scroll_speed")
    lines_warp_scroll_angle = lines_shader.get_shader_parameter("displacement_scroll_angle")
    
    lines_color = lines.modulate
    lines_solid_color = lines_solid.modulate
    refresh_bg_style()

func on_bg_style_changed() -> void:
    refresh_bg_style()

func refresh_bg_style() -> void:
    var level_bg_info: Dictionary = GameManager.get_current_bg_info()
    var background_color: Color = Utility.get_dict_color(level_bg_info, "background_color", default_bg_color)
    var dusty_particles_color: Color = Utility.get_dict_color(level_bg_info, "dusty_particles_color", default_particles_color)
    
    dusty_particles.density = dusty_particles_density * level_bg_info.get("dusty_particles_amount", 1.0)
    dusty_particles.real_update(true)
    
    bg_color_rect.color = background_color
    dusty_particles.modulate = dusty_particles_color
    dusty_particles.speed_scale = dusty_particles_base_speed * level_bg_info.get("dusty_particles_speed", 1.0)
    dusty_particles.visible = level_bg_info.get("dusty_particles_on", true)
    
    var pointy_mat: ParticleProcessMaterial = pointy_particles.process_material
    pointy_mat.hue_variation_max = pointy_particles_rainbow_hue_var * int(level_bg_info.get("pointy_particles_rainbow_on", false))
    pointy_mat.hue_variation_min = -pointy_mat.hue_variation_max

    pointy_particles.density = pointy_particles_density * level_bg_info.get("pointy_particles_amount", 1.0)
    pointy_particles.real_update(true)
    pointy_particles.speed_scale = pointy_particles_base_speed * level_bg_info.get("pointy_particles_speed", 1.0)
    pointy_particles.visible = level_bg_info.get("pointy_particles_on", false)
    if level_bg_info.get("pointy_particles_dark_mode", pointy_particles_dark_mode):
        pointy_particles.material.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
    else:
        pointy_particles.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

    var pointy_color: Color = Utility.get_dict_color(level_bg_info, "pointy_particles_color", default_pointy_particles_color)
    pointy_particles.modulate = Color(1, 1, 1, pointy_color.a)
    pointy_color.a = 1.0
    pointy_mat.color = pointy_color

    var dusty_particles_parallax_amount: float = level_bg_info.get("dusty_particles_camera_scroll_factor", 0.5)
    if dusty_particles_parallax_helper:
        dusty_particles_parallax_helper.set_parallax_amount(dusty_particles_parallax_amount)
    
    var pointy_particles_parallax_amount: float = level_bg_info.get("pointy_particles_camera_scroll_factor", 0.0)
    if pointy_particles_parallax_helper:
        pointy_particles_parallax_helper.set_parallax_amount(pointy_particles_parallax_amount)
    
    bg_gradient.visible = level_bg_info.get("bg_gradient_on", true)
    bg_gradient.modulate = Utility.get_dict_color(level_bg_info, "bg_gradient_color", default_bg_gradient_color)
    
    var gradient_cover_amount: float = level_bg_info.get("bg_gradient_cover_amount", 0.8)

    rotate_gradient(level_bg_info.get("bg_gradient_rotation", 0.5), gradient_cover_amount)
    
    refresh_lines_style()
    var between_layer_index: int = 0
    if lines_layer.layer >= 5:
        between_layer_index = 4
    
    var bg_gradient_above: String = level_bg_info.get("bg_gradient_above", "below")
    if bg_gradient_above == "below":
        gradient_layer.layer = -8
    elif bg_gradient_above == "between":
        gradient_layer.layer = between_layer_index
    elif bg_gradient_above == "above":
        gradient_layer.layer = 8
    
    if bg_tile_holder:
        bg_tile_holder.update_bg_tile_info(level_bg_info)

        var bg_tile_above: String = level_bg_info.get("bg_tile_above", "below")

        if bg_tile_above == "between":
            bg_tile_layer.layer = between_layer_index + 1
        elif bg_tile_above == "above":
            bg_tile_layer.layer = 9
        else:
            bg_tile_layer.layer = -7
        var is_below_gradient: bool = level_bg_info.get("bg_tile_below_gradient", true)
        if is_below_gradient:
            bg_tile_layer.layer -= 2


func snap_scroll_vector_for_shader_time_loop(scroll_vector: Vector2) -> Vector2:
    var snapped_vector: Vector2 = (scroll_vector * shader_time_loop_factor).snapped(Vector2.ONE)
    if snapped_vector == Vector2.ZERO:
        return Vector2(signf(scroll_vector.x), signf(scroll_vector.y))
    return snapped_vector / shader_time_loop_factor


func refresh_lines_style() -> void:
    var level_bg_info: Dictionary = GameManager.get_current_bg_info()
    lines.visible = level_bg_info.get("lines_on", false)
    lines_solid.visible = level_bg_info.get("lines_solid_on", false)
    if not lines.visible and not lines_solid.visible:
        return
    lines.modulate = Utility.get_dict_color(level_bg_info, "lines_color", lines_color)
    lines_solid.modulate = Utility.get_dict_color(level_bg_info, "lines_solid_color", lines_solid_color)
    var lines_shader: ShaderMaterial = lines.material
    var lines_solid_shader: ShaderMaterial = lines_solid.material
    
    lines_shader.set_shader_parameter("camera_displacement_scale", level_bg_info.get("lines_camera_scroll_factor", lines_camera_scroll_factor))
    lines_solid_shader.set_shader_parameter("camera_displacement_scale", level_bg_info.get("lines_solid_camera_scroll_factor", lines_solid_camera_scroll_factor))
    
    var scroll_speed: float = level_bg_info.get("lines_scroll_speed", lines_scroll_speed)
    var scroll_angle: float = level_bg_info.get("lines_scroll_angle", lines_scroll_angle)
    var scroll_vec: = Vector2.RIGHT.rotated(scroll_angle * TAU) * scroll_speed
    scroll_vec = snap_scroll_vector_for_shader_time_loop(scroll_vec)
    scroll_speed = scroll_vec.length()
    scroll_angle = scroll_vec.angle() / TAU
    scroll_angle = fposmod(((scroll_vec.angle() + PI) / TAU) - 0.5, 1.0)

    lines_shader.set_shader_parameter("scroll_speed", scroll_speed)
    lines_solid_shader.set_shader_parameter("scroll_speed", scroll_speed)
    lines_shader.set_shader_parameter("scroll_angle", scroll_angle)
    lines_solid_shader.set_shader_parameter("scroll_angle", scroll_angle)

    var warp_strength: float = level_bg_info.get("lines_warp_strength", lines_warp_strength)
    lines_shader.set_shader_parameter("displacement_strength", warp_strength)
    lines_solid_shader.set_shader_parameter("displacement_strength", warp_strength)
    
    var warp_scroll_speed: float = level_bg_info.get("lines_warp_scroll_speed", lines_warp_scroll_speed)
    var warp_scroll_angle: float = level_bg_info.get("lines_warp_scroll_angle", lines_warp_scroll_angle)
    var warp_scroll_vec: = Vector2.RIGHT.rotated(warp_scroll_angle * TAU) * warp_scroll_speed
    warp_scroll_vec = snap_scroll_vector_for_shader_time_loop(warp_scroll_vec)
    warp_scroll_speed = warp_scroll_vec.length()
    warp_scroll_angle = fposmod(((warp_scroll_vec.angle() + PI) / TAU) - 0.5, 1.0)

    lines_shader.set_shader_parameter("displacement_scroll_speed", warp_scroll_speed)
    lines_solid_shader.set_shader_parameter("displacement_scroll_speed", warp_scroll_speed)
    lines_shader.set_shader_parameter("displacement_scroll_angle", warp_scroll_angle)
    lines_solid_shader.set_shader_parameter("displacement_scroll_angle", warp_scroll_angle)
    

    var lines_above: String = level_bg_info.get("lines_above", "below")
    var is_above: bool = lines_above.begins_with("above")
    var is_solid_on_top: bool = lines_above.contains(", solid on top")
    var lines_parent: Node = lines_solid.get_parent()
    lines_parent.move_child(lines_solid, 1 if is_solid_on_top else 0)

    lines_layer.layer = 5 if is_above else -2

func rotate_gradient(rotation_amt_turns: float, gradient_cover_amount: float = 0.8) -> void:
    var base_fill_from: Vector2 = Vector2(0, -0.5)
    var base_fill_to: Vector2 = Vector2(0, gradient_cover_amount - 0.5)
    
    var center_offset: = Vector2.ONE * 0.5
    
    var rotation_amt: float = rotation_amt_turns * TAU
    gradient_texture.fill_from = base_fill_from.rotated(rotation_amt) + center_offset
    gradient_texture.fill_to = base_fill_to.rotated(rotation_amt) + center_offset

func update_cam_scale_and_scroll_manually(camera_zoom_factor: float, camera_scroll_pos: Vector2) -> void:
    on_camera_zoom_changed(camera_zoom_factor)
    on_camera_displacement_changed(camera_scroll_pos)
    
    
func on_camera_displacement_changed(camera_displacement: Vector2) -> void:
    if effect_subviewport:
        effect_subviewport.canvas_transform.origin = -camera_displacement
        if effect_fixed_in_viewport:
            effect_fixed_in_viewport.position = camera_displacement
    if bg_tile_holder.visible:
        bg_tile_holder.scroll_updated()

func on_camera_zoom_changed(camera_zoom_factor: float) -> void:
    if bg_tile_holder.visible:
        bg_tile_holder.camera_zoom_changed(camera_zoom_factor)