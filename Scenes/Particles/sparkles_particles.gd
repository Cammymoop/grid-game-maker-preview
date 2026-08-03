extends Node2D

@export var emitter: GPUParticles2D


var default_color: Color = Color.WHITE
var _got_default_color: bool = false

func _save_default_color() -> void:
    if not _got_default_color:
        default_color = emitter.modulate
        _got_default_color = true

func set_default_color() -> void:
    emitter.modulate = default_color

func set_particles_color(new_color: Color) -> void:
    _save_default_color()
    emitter.modulate = new_color


func get_linger_time() -> float:
    return emitter.lifetime / emitter.speed_scale

func stop_emitting() -> void:
    emitter.emitting = false

func continue_emitting() -> void:
    emitter.emitting = true