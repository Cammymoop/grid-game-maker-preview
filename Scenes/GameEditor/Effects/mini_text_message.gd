extends Node2D

@export var label_node: Label
@export var lifetime: float = 1.0
@export var mini_message: String = ""

@export var use_show_anim: bool = true
@export var use_hide_anim: bool = true
@export var animator: AnimationPlayer = null

@export var show_anim_duration: float = 0.1
@export var hide_anim_duration: float = 0.4

var timer: Timer = null

func _ready() -> void:
    label_node.text = mini_message
    timer = Timer.new()
    timer.timeout.connect(on_timer_timeout)
    add_child(timer)
    if lifetime > 0:
        timer.start(lifetime)
    if animator and use_show_anim:
        animator.speed_scale = 1.0 / show_anim_duration
        animator.play("show")

func on_timer_timeout() -> void:
    if not animator or not use_hide_anim:
        queue_free()
    else:
        animator.stop(true)
        animator.speed_scale = 1.0 / hide_anim_duration
        animator.animation_finished.connect(queue_free.unbind(1))
        animator.play("hide")
