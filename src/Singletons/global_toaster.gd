extends CanvasLayer

var base_control: Control

@onready var toast_message_label: Label = find_child("ToastMessageLabel")
@onready var toast_animator: AnimationPlayer = find_child("ToastAnimator")

@export var message_queue_max_size: = 12 
@export var message_queue_clip_end_time: = 0.3

var message_queue: Array[Dictionary] = []

var default_extra_time: float = 0.7
var _extra_wait_time: float = -1.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func show_toast_message(message: String, with_extra_time: float = -1) -> void:
    if message_queue and message_queue.front()["message"] == message:
        return
    if message_queue.size() >= message_queue_max_size:
        message_queue.pop_back()
    message_queue.append({"message": message, "extra_time": with_extra_time})
    
func do_show_message(message: Dictionary) -> void:
    _extra_wait_time = message["extra_time"]
    if _extra_wait_time < 0:
        _extra_wait_time = default_extra_time

    toast_message_label.text = message["message"]
    toast_animator.play("show")

func start_hide_anim() -> void:
    toast_animator.play("hide")

func is_showing() -> bool:
    if _extra_wait_time >= 0.0:
        return true
    return toast_animator.is_playing() and not toast_animator.current_animation == "RESET"

func cur_anim_time_left() -> float:
    return toast_animator.current_animation_length - toast_animator.current_animation_position

func _process(delta: float) -> void:
    if _extra_wait_time >= 0.0:
        process_extra_wait(delta)
    elif message_queue.size() > 0:
        if is_showing():
            if cur_anim_time_left() < message_queue_clip_end_time:
                toast_animator.play("RESET")
            return
        do_show_message(message_queue.pop_front())

func process_extra_wait(delta: float) -> void:
    _extra_wait_time -= delta
    if _extra_wait_time < 0.0:
        start_hide_anim()