extends Node

var move_mode = "direction"

# Options
var stop_repeat_after_bonk = true
var lock_for_idle_delay_after_bonk = true
var allow_wait = true

var is_repeat = false

var is_delay_locked: = false

var up_held: = false
var down_held: = false
var left_held: = false
var right_held: = false

var cancelled: = false

var most_recent_is_horizontal: = false

var parent_entity: BaseEntity = null

var available_options = {
	"stop_repeat_after_bonk": {"display_name": "Stop repeating movement after being blocked", "type": "bool"},
	"lock_for_idle_delay_after_bonk": {"display_name": "Prevent movement briefly after being blocked", "type": "bool"},
	"allow_wait": {"display_name": "Press a key to wait a turn", "type": "bool"},
}

func _ready():
	parent_entity = get_parent() as BaseEntity
	if not parent_entity:
		push_error("InputController parent is not a BaseEntity")
		return
	parent_entity.blocked.connect(got_blocked)
	parent_entity.started_move.connect(on_start_move)

func get_max_move_intentions() -> int:
	if is_delay_locked and parent_entity.idle_ticks_elapsed + 1 < EntityManager.idle_delay_frames:
		return 0
	return 1

func set_options(options: Dictionary) -> void:
	if "stop_repeat_after_bonk" in options:
		stop_repeat_after_bonk = options["stop_repeat_after_bonk"]
	if "lock_for_idle_delay_after_bonk" in options:
		lock_for_idle_delay_after_bonk = options["lock_for_idle_delay_after_bonk"]
	if "allow_wait" in options:
		allow_wait = options["allow_wait"]

func get_options() -> Dictionary:
	return available_options

func _physics_process(_delta):
	var is_pressed = false
	
	up_held = true
	if Input.is_action_just_pressed("move_up"):
		is_pressed = true
		most_recent_is_horizontal = false
	elif not Input.is_action_pressed("move_up"):
		up_held = false
	
	down_held = true
	if Input.is_action_just_pressed("move_down"):
		is_pressed = true
		most_recent_is_horizontal = false
	elif not Input.is_action_pressed("move_down"):
		down_held = false
	
	left_held = true
	if Input.is_action_just_pressed("move_left"):
		is_pressed = true
		most_recent_is_horizontal = true
	elif not Input.is_action_pressed("move_left"):
		left_held = false
	
	
	right_held = true
	if Input.is_action_just_pressed("move_right"):
		is_pressed = true
		most_recent_is_horizontal = true
	elif not Input.is_action_pressed("move_right"):
		right_held = false
	
	is_repeat = not is_pressed
	
	if not EntityManager.movements_enabled:
		if up_held or down_held or left_held or right_held:
			EntityManager.request_move(get_parent())
		elif allow_wait and Input.is_action_just_pressed("wait_turn"):
			if not get_parent().moving:
				EntityManager.request_move(get_parent())

func get_move(attempt_num: int = 0):
	if attempt_num > 0:
		return "none"
	if not EntityManager.controller_frame:
		return "none"
	var input_dir = "none"
	var h_input_dir = "none"
	
	if not is_repeat:
		cancelled = false
	
	if up_held and not down_held and not cancelled:
		input_dir = "up"
	elif down_held and not up_held and not cancelled:
		input_dir = "down"
	
	if left_held and not right_held and not cancelled:
		h_input_dir = "left"
	elif right_held and not left_held and not cancelled:
		h_input_dir = "right"
	
	if input_dir == "none":
		input_dir = h_input_dir
	elif h_input_dir != "none":
		if most_recent_is_horizontal:
			input_dir = h_input_dir
	
	if input_dir == "none":
		is_repeat = false
	return input_dir

func got_blocked(_facing_dir) -> void:
	if stop_repeat_after_bonk:
		cancelled = true
	if lock_for_idle_delay_after_bonk:
		is_delay_locked = true

func on_start_move(_facing_dir) -> void:
	cancelled = false
	is_delay_locked = false
