class_name RepeatDelayTimer
extends Timer

signal activated
signal released

@export var initial_delay: float = -1
@export var repeat_delay: float = 0.05
@export var auto_check_hold: bool = true
var _check_hold_callable: Callable = Callable()

var _is_held: = false

func _init() -> void:
    one_shot = false
    wait_time = get_initial_delay()
    timeout.connect(on_timeout)
    _update_processing()

func on_timeout() -> void:
    activated.emit()
    if wait_time != repeat_delay:
        start(repeat_delay)

func get_initial_delay() -> float:
    if initial_delay > 0:
        return initial_delay
    return repeat_delay

func start_hold() -> void:
    _is_held = true
    start(get_initial_delay())
    activated.emit()

func hold() -> void:
    if not _is_held:
        start_hold()

func change_process_callback_type(new_process_callback: int) -> void:
    if new_process_callback == TIMER_PROCESS_IDLE:
        process_callback = TIMER_PROCESS_IDLE
    else:
        process_callback = TIMER_PROCESS_PHYSICS
    _update_processing()

func set_check_hold_callable(check_hold_callable: Callable) -> void:
    _check_hold_callable = check_hold_callable
    _update_processing()

func _update_processing() -> void:
    if auto_check_hold and _check_hold_callable.is_valid():
        if process_callback == TIMER_PROCESS_IDLE:
            set_process(true)
        else:
            set_physics_process(true)
    else:
        set_process(false)
        set_physics_process(false)

func recheck_holding() -> void:
    if _check_hold_callable.is_valid():
        if _check_hold_callable.call():
            hold()
        else:
            release()

func release() -> void:
    _is_held = false
    stop()
    released.emit()

func is_held() -> bool:
    return _is_held

func _process(_delta: float) -> void:
    recheck_holding()
func _physics_process(_delta: float) -> void:
    recheck_holding()