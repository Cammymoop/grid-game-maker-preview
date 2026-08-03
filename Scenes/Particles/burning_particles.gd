extends Node2D

@export var show_flames: bool = false
@export var show_smoke: bool = true

@export var smoke_particles: GPUParticles2D
@export var flames_particles: GPUParticles2D

func _ready() -> void:
    flames_particles.visible = show_flames 
    flames_particles.emitting = show_flames
    smoke_particles.visible = show_smoke
    smoke_particles.emitting = show_smoke

func set_z_offset(z_offset: int) -> void:
    flames_particles.z_index = z_offset
    smoke_particles.z_index = z_offset

func set_flames_z_offset(z_offset: int) -> void:
    flames_particles.z_index = z_offset

func set_smoke_z_offset(z_offset: int) -> void:
    smoke_particles.z_index = z_offset


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