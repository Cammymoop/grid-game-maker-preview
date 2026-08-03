extends Node2D

@export var show_flames: bool = false
@export var show_smoke: bool = true

@export var smoke_particles: GPUParticles2D
@export var flames_particles: GPUParticles2D

var smoke_default_color: Color = Color.WHITE
var flames_default_color: Color = Color.WHITE

var _got_default_colors: bool = false

func _ready() -> void:
    flames_particles.visible = show_flames 
    flames_particles.emitting = show_flames
    smoke_particles.visible = show_smoke
    smoke_particles.emitting = show_smoke

func _save_default_colors() -> void:
    if not _got_default_colors:
        smoke_default_color = smoke_particles.modulate
        flames_default_color = flames_particles.modulate
        _got_default_colors = true

func set_z_offset(z_offset: int) -> void:
    flames_particles.z_index = z_offset
    smoke_particles.z_index = z_offset

func set_flames_z_offset(z_offset: int) -> void:
    flames_particles.z_index = z_offset

func set_smoke_z_offset(z_offset: int) -> void:
    smoke_particles.z_index = z_offset

func set_particles_color(color: Color) -> void:
    _save_default_colors()
    if show_flames:
        flames_particles.modulate = color
    if show_smoke:
        smoke_particles.modulate = color

func set_default_color() -> void:
    if not _got_default_colors:
        return
    flames_particles.modulate = flames_default_color
    smoke_particles.modulate = smoke_default_color


func get_linger_time() -> float:
    var linger_time: float = 0
    if show_flames:
        linger_time = flames_particles.lifetime / flames_particles.speed_scale
    if show_smoke:
        linger_time = maxf(linger_time, smoke_particles.lifetime / smoke_particles.speed_scale)
    return linger_time

func stop_emitting() -> void:
    flames_particles.emitting = false
    smoke_particles.emitting = false

func continue_emitting() -> void:
    if show_flames:
        flames_particles.emitting = true
    if show_smoke:
        smoke_particles.emitting = true