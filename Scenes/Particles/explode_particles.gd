extends Node2D

signal particles_finished

@export var remove_on_finish: bool = false

@export var smoke_particles: GPUParticles2D
@export var flash_particles: GPUParticles2D

func _ready() -> void:
    smoke_particles.emitting = true
    flash_particles.emitting = true
    
    smoke_particles.finished.connect(on_smoke_done)

func on_smoke_done() -> void:
    particles_finished.emit()
    if remove_on_finish:
        queue_free()