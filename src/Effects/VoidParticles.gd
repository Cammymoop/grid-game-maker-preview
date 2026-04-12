extends GPUParticles2D

var density: float
@export var MAX_AMOUNT = 2000
@export var DENSITY_UPDATES: bool = true
@export var smooth_amount_reset: float = 0
var smooth_timer: float = 0

var fading = false
var fade: float = 1

enum ProcessType {
	ParticlesMat, ShaderMat
}

@export var TYPE: ProcessType = ProcessType.ParticlesMat

func _ready():
	set_process(false)
	
	var extents
	if TYPE == ProcessType.ParticlesMat:
		extents = process_material.emission_box_extents
	else:
		extents = process_material.get_shader_parameter("emission_box_extents")
	density = amount / (extents.x * extents.y)
	update_size(true)
	get_viewport().size_changed.connect(update_size)

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
	position.y = vp.size.x / 2
	
	if no_smooth or smooth_amount_reset == 0:
		real_update()
	else:
		fading = true
		smooth_timer = smooth_amount_reset
		set_process(true)

func real_update() -> void:
	var vp = get_viewport()
	if TYPE == ProcessType.ParticlesMat:
		process_material.emission_box_extents = Vector3((vp.size.x/2) * 1.2, vp.size.y * 1.5, 1)
	else:
		process_material.set_shader_parameter("emission_box_extents", Vector3((vp.size.x/2) * 1.2, vp.size.y * 1.5, 1))
	if DENSITY_UPDATES:
		amount = min(MAX_AMOUNT, density * (vp.size.x * vp.size.y))
	
