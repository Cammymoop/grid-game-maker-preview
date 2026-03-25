extends Node

var move_mode = "direction"

# Options
var stop_repeat_after_bonk = true
var allow_wait = true

var is_repeat = false

var up_held: = false
var down_held: = false
var left_held: = false
var right_held: = false

var cancelled: = false

var most_recent_is_horizontal: = false

var available_options = {
	"stop_repeat_after_bonk": {"display_name": "Stop repeating movement after being blocked", "type": "bool"},
	"allow_wait": {"display_name": "Press a key to wait a turn", "type": "bool"},
}

func _ready():
	get_parent().connect("blocked", Callable(self, "got_blocked"))
	get_parent().connect("started_move", Callable(self, "on_start_move"))

func set_options(options: Dictionary) -> void:
	if "stop_repeat_after_bonk" in options:
		stop_repeat_after_bonk = options["stop_repeat_after_bonk"]
	if "allow_wait" in options:
		allow_wait = options["allow_wait"]

func get_options() -> Dictionary:
	return available_options

func _process(_delta):
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
		if allow_wait and Input.is_action_just_pressed("wait"):
			if not get_parent().moving:
				EntityManager.request_move(get_parent())

func get_move(secondary: bool = false):
	if secondary:
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

func on_start_move(_facing_dir) -> void:
	cancelled = false
