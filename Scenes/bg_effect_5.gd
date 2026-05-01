extends Node

@export var bg_color_rect: ColorRect
@export var dusty_particles: GPUParticles2D
@export var pointy_particles: GPUParticles2D
@export var bg_gradient: TextureRect

@export var lines: Sprite2D
@export var lines_solid: Sprite2D

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

func _ready() -> void:
    GameManager.bg_style_changed.connect(on_bg_style_changed)
    default_bg_color = bg_color_rect.color
    default_bg_gradient_color = bg_gradient.modulate

    default_particles_color = dusty_particles.modulate
    dusty_particles_base_speed = dusty_particles.speed_scale
    
    dusty_particles_density = dusty_particles.density

    default_pointy_particles_color = pointy_particles.modulate
    pointy_particles_base_speed = pointy_particles.speed_scale
    pointy_particles_density = pointy_particles.density
    var pointy_mat: ParticleProcessMaterial = pointy_particles.process_material
    pointy_particles_rainbow_hue_var = pointy_mat.hue_variation_max
    
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
    var level_bg_info: Dictionary = GameManager.get_level_bg_info()
    var background_color: Color = Utility.get_dict_color(level_bg_info, "background_color", default_bg_color)
    var dusty_particles_color: Color = Utility.get_dict_color(level_bg_info, "dusty_particles_color", default_particles_color)
    
    dusty_particles.density = dusty_particles_density * level_bg_info.get("dusty_particles_amount", 1.0)
    dusty_particles.real_update()
    
    bg_color_rect.color = background_color
    dusty_particles.modulate = dusty_particles_color
    dusty_particles.speed_scale = dusty_particles_base_speed * level_bg_info.get("dusty_particles_speed", 1.0)
    dusty_particles.visible = level_bg_info.get("dusty_particles_on", true)
    
    var pointy_mat: ParticleProcessMaterial = pointy_particles.process_material
    pointy_mat.hue_variation_max = pointy_particles_rainbow_hue_var * int(level_bg_info.get("pointy_particles_rainbow_on", false))
    pointy_mat.hue_variation_min = -pointy_mat.hue_variation_max

    pointy_particles.density = pointy_particles_density * level_bg_info.get("pointy_particles_amount", 1.0)
    pointy_particles.real_update()
    pointy_particles.speed_scale = pointy_particles_base_speed * level_bg_info.get("pointy_particles_speed", 1.0)
    pointy_particles.modulate = Utility.get_dict_color(level_bg_info, "pointy_particles_color", default_pointy_particles_color)
    pointy_particles.visible = level_bg_info.get("pointy_particles_on", false)
    if level_bg_info.get("pointy_particles_dark_mode", pointy_particles_dark_mode):
        pointy_particles.material.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
    else:
        pointy_particles.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    
    bg_gradient.visible = level_bg_info.get("bg_gradient_on", true)
    bg_gradient.modulate = Utility.get_dict_color(level_bg_info, "bg_gradient_color", default_bg_gradient_color)
    
    var bg_gradient_above: String = level_bg_info.get("bg_gradient_above", "below")
    if bg_gradient_above == "below":
        bg_gradient.z_index = -6
    elif bg_gradient_above == "between":
        bg_gradient.z_index = 0
    elif bg_gradient_above == "above":
        bg_gradient.z_index = 6
    
    refresh_lines_style()


func refresh_lines_style() -> void:
    var level_bg_info: Dictionary = GameManager.get_level_bg_info()
    lines.visible = level_bg_info.get("lines_on", false)
    lines_solid.visible = level_bg_info.get("lines_solid_on", false)
    if not lines.visible and not lines_solid.visible:
        return
    lines.modulate = Utility.get_dict_color(level_bg_info, "lines_color", lines_color)
    lines_solid.modulate = Utility.get_dict_color(level_bg_info, "lines_solid_color", lines_solid_color)
    var lines_shader: ShaderMaterial = lines.material
    var lines_solid_shader: ShaderMaterial = lines_solid.material
    
    var scroll_speed: float = level_bg_info.get("lines_scroll_speed", lines_scroll_speed)
    var scroll_angle: float = level_bg_info.get("lines_scroll_angle", lines_scroll_angle)
    lines_shader.set_shader_parameter("scroll_speed", scroll_speed)
    lines_solid_shader.set_shader_parameter("scroll_speed", scroll_speed)
    lines_shader.set_shader_parameter("scroll_angle", scroll_angle)
    lines_solid_shader.set_shader_parameter("scroll_angle", scroll_angle)

    var warp_strength: float = level_bg_info.get("lines_warp_strength", lines_warp_strength)
    lines_shader.set_shader_parameter("displacement_strength", warp_strength)
    lines_solid_shader.set_shader_parameter("displacement_strength", warp_strength)
    
    var warp_scroll_speed: float = level_bg_info.get("lines_warp_scroll_speed", lines_warp_scroll_speed)
    var warp_scroll_angle: float = level_bg_info.get("lines_warp_scroll_angle", lines_warp_scroll_angle)
    lines_shader.set_shader_parameter("displacement_scroll_speed", warp_scroll_speed)
    lines_solid_shader.set_shader_parameter("displacement_scroll_speed", warp_scroll_speed)
    lines_shader.set_shader_parameter("displacement_scroll_angle", warp_scroll_angle)
    lines_solid_shader.set_shader_parameter("displacement_scroll_angle", warp_scroll_angle)
    
    var lines_above: String = level_bg_info.get("lines_above", "below")
    lines.z_index = 3 if lines_above.begins_with("above") else -1
    lines_solid.z_index = 3 if lines_above.begins_with("above") else -1 
    if lines_above.contains("solid"):
        lines_solid.z_index += 1
    
    if lines_above.begins_with("above") and level_bg_info.get("bg_gradient_above", "below") == "between":
        bg_gradient.z_index = 2
    