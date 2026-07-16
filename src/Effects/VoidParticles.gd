extends GPUParticles2D

var density: float
@export var MAX_AMOUNT = 2000
@export var DENSITY_UPDATES: bool = true
@export var smooth_amount_reset: float = 0
var smooth_timer: float = 0

var fading = false
var fade: float = 1

var inverse_canvas_layer_scale: float = 1.0

var viewport_overscan: float = 1.8

enum ProcessType {
	ParticlesMat, ShaderMat
}

@export var TYPE: ProcessType = ProcessType.ParticlesMat

var base_scale_min: float = 1.0
var base_scale_max: float = 1.0

func _ready():
	set_process(false)
	
	if TYPE == ProcessType.ParticlesMat:
		base_scale_min = (process_material as ParticleProcessMaterial).scale_min
		base_scale_max = (process_material as ParticleProcessMaterial).scale_max
	
	var extents
	if TYPE == ProcessType.ParticlesMat:
		extents = process_material.emission_box_extents
	else:
		extents = process_material.get_shader_parameter("emission_box_extents")
	density = amount / (extents.x * extents.y)
	update_size(true)
	get_viewport().size_changed.connect(update_size)

func set_canvas_layer_scale(new_scale: float) -> void:
	inverse_canvas_layer_scale = 1.0 / new_scale
	if TYPE == ProcessType.ParticlesMat:
		(process_material as ParticleProcessMaterial).scale_min = base_scale_min * inverse_canvas_layer_scale
		(process_material as ParticleProcessMaterial).scale_max = base_scale_max * inverse_canvas_layer_scale

func _process(delta):
	if is_zero_approx(smooth_amount_reset):
		return
	if fading:
		fade -= delta / smooth_amount_reset
		fade = max(0, fade)
	else:
		fade += delta / smooth_amount_reset
		fade = min(1, fade)
		if fade >= 1:
			set_process(false)
	
	self_modulate.a = fade
	
	if fading:
		smooth_timer -= delta
		if smooth_timer <= 0:
			fading = false
			real_update()

func update_size(no_smooth: bool = false):
	var vp = get_viewport()
	position.x = vp.size.x / 2
	position.y = vp.size.y / 2
	
	if no_smooth or smooth_amount_reset == 0:
		real_update()
	else:
		fading = true
		smooth_timer = smooth_amount_reset
		set_process(true)

func real_update() -> void:
	var vp = get_viewport()
	var size2: = Vector2((vp.size.x/2) * 1.2, (vp.size.y/2) * 1.5) * viewport_overscan * inverse_canvas_layer_scale
	if TYPE == ProcessType.ParticlesMat:
		process_material.emission_box_extents = Vector3(size2.x, size2.y, 1)
	else:
		process_material.set_shader_parameter("emission_box_extents", Vector3(size2.x, size2.y, 1))
	if DENSITY_UPDATES:
		amount = mini(MAX_AMOUNT, maxi(10, density * (vp.size.x * vp.size.y)))
	
