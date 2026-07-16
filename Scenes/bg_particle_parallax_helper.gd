extends CanvasLayer

const VoidParticles: = preload("res://src/Effects/VoidParticles.gd")

var parent_vp: Viewport

@export var void_particles: VoidParticles = null

var last_parallax_amount: float = 0.0

func _ready() -> void:
    parent_vp = get_viewport()
    if follow_viewport_enabled:
        set_parallax_amount(follow_viewport_scale)
    else:
        set_parallax_amount(0)

func get_particles() -> VoidParticles:
    return void_particles

func set_parallax_amount(parallax_amount: float) -> void:
    parallax_amount = 1 - parallax_amount
    if parallax_amount < 0.05:
        parallax_amount = 0
    if parallax_amount == last_parallax_amount:
        return

    if parallax_amount == 0:
        follow_viewport_enabled = false
        follow_viewport_scale = 1.0
        void_particles.set_overscan_factor(1.0)
        void_particles.set_canvas_layer_scale(1.0)
    else:
        follow_viewport_enabled = true
        follow_viewport_scale = parallax_amount
        void_particles.set_overscan_factor(1 + ((1 - parallax_amount) * 0.5))
        void_particles.set_canvas_layer_scale(follow_viewport_scale)
    last_parallax_amount = parallax_amount
    update_particles_position()

func _process(_delta: float) -> void:
    update_particles_position()

func update_particles_position() -> void:
    var vp_center: Vector2 = parent_vp.size / 2
    if not follow_viewport_enabled:
        void_particles.position = vp_center
        return
    
    var local_center: Vector2 = get_final_transform().affine_inverse() * vp_center
    local_center *= follow_viewport_scale
    
    void_particles.position = local_center
