extends Node

var move_mode = "direction"

# Options
var stop_repeat_after_bonk = true
var allow_wait = true

var up_held: = false
var down_held: = false
var left_held: = false
var right_held: = false

var available_options = {
	"stop_repeat_after_bonk": {"display_name": "Stop repeating movement after being blocked", "type": "bool"},
	"allow_wait": {"display_name": "Press a key to wait a turn", "type": "bool"},
}

func _ready():
	get_parent().connect("blocked", self, "got_blocked")

func set_options(options: Dictionary) -> void:
	if "stop_repeat_after_bonk" in options:
		stop_repeat_after_bonk = options["stop_repeat_after_bonk"]
	if "allow_wait" in options:
		allow_wait = options["allow_wait"]

func get_options() -> Dictionary:
	return available_options

func _process(_delta):
	if Input.is_action_just_pressed("move_up"):
		up_held = true
	elif not Input.is_action_pressed("move_up"):
		up_held = false
	
	if Input.is_action_just_pressed("move_down"):
		down_held = true
	elif not Input.is_action_pressed("move_down"):
		down_held = false
		
	if Input.is_action_just_pressed("move_left"):
		left_held = true
	elif not Input.is_action_pressed("move_left"):
		left_held = false
		
	if Input.is_action_just_pressed("move_right"):
		right_held = true
	elif not Input.is_action_pressed("move_right"):
		right_held = false
	
	if not EntityManager.movements_enabled:
		if up_held or down_held or left_held or right_held:
			EntityManager.request_move(get_parent())
		if allow_wait and Input.is_action_just_pressed("wait"):
			if not get_parent().moving:
				EntityManager.request_move(get_parent())

func get_move():
	if not EntityManager.controller_frame:
		return "none"
	var input_dir = "none"
	
	if up_held and not down_held:
		input_dir = "up"
	elif down_held and not up_held:
		input_dir = "down"
	elif left_held and not right_held:
		input_dir = "left"
	elif right_held and not left_held:
		input_dir = "right"
	
	return input_dir

func got_blocked() -> void:
	if stop_repeat_after_bonk:
		up_held = false
		down_held = false
		left_held = false
		right_held = false
