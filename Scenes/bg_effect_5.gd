extends Node

@export var bg_color_rect: ColorRect
@export var dusty_particles: GPUParticles2D

var default_particles_color: Color = Color.GRAY

func _ready() -> void:
    default_particles_color = dusty_particles.self_modulate
    refresh_game_definition()

func refresh_game_definition() -> void:
    var background_color: Color = GameManager.get_game_setting("level_background_color", Color.BLACK)
    var dusty_particles_color: Color = GameManager.get_game_setting("level_dusty_particles_color", default_particles_color)
    
    bg_color_rect.color = background_color
    dusty_particles.self_modulate = dusty_particles_color
    dusty_particles.visible = GameManager.get_game_setting("level_dusty_particles_on", true)