extends Node2D

@export var emitter: GPUParticles2D


var default_color: Color = Color.WHITE
var _got_default_color: bool = false

func _save_default_color() -> void:
    if not _got_default_color:
        default_color = _get_cloud_color()
        _got_default_color = true

func set_default_color() -> void:
    _save_default_color()
    _set_cloud_color(default_color)

func set_particles_color(new_color: Color) -> void:
    _save_default_color()
    _set_cloud_color(new_color)

func _get_cloud_color() -> Color:
    var cloud_particles_mat: = emitter.process_material as ParticleProcessMaterial
    var color_ramp: = cloud_particles_mat.color_ramp as GradientTexture1D
    if not color_ramp:
        return Color.WHITE
    return color_ramp.gradient.get_color(0)

func _set_cloud_color(new_color: Color) -> void:
    var cloud_particles_mat: = emitter.process_material as ParticleProcessMaterial
    var color_ramp: = cloud_particles_mat.color_ramp as GradientTexture1D
    var color_ramp_gradient: = color_ramp.gradient
    
    color_ramp_gradient.set_color(0, new_color)
    var desaturated: = Color.from_ok_hsl(new_color.ok_hsl_h, new_color.ok_hsl_s * 0.35, new_color.ok_hsl_l)
    desaturated.a = new_color.a * 0.5
    color_ramp_gradient.set_color(1, desaturated)
    


func get_linger_time() -> float:
    return emitter.lifetime / emitter.speed_scale

func stop_emitting() -> void:
    emitter.emitting = false

func continue_emitting() -> void:
    emitter.emitting = true