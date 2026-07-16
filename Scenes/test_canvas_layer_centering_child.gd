extends CanvasLayer

const VoidParticles: = preload("res://src/Effects/VoidParticles.gd")

@export var child_node: Node2D = null
@export var void_particles: VoidParticles = null

var old_follow_viewport_scale: float = 0.5

func _ready() -> void:
    if void_particles:
        void_particles.set_canvas_layer_scale(follow_viewport_scale)
    old_follow_viewport_scale = follow_viewport_scale

func _process(_delta: float) -> void:
    if not child_node:
        return
    
    if follow_viewport_scale != old_follow_viewport_scale:
        void_particles.set_canvas_layer_scale(follow_viewport_scale)
        old_follow_viewport_scale = follow_viewport_scale
    
    var vp: Viewport = get_viewport()
    var vp_center: Vector2 = vp.size / 2
    
    var local_center: Vector2 = get_final_transform().affine_inverse() * vp_center
    local_center *= follow_viewport_scale
    
    child_node.position = local_center
    void_particles.position = local_center
