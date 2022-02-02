extends Node

var move_mode = "direction"
var multi_try = false

func get_move():
	var input_dir = "none"
	
	var iup = Input.is_action_pressed("move_up")
	var idown = Input.is_action_pressed("move_down")
	var ileft = Input.is_action_pressed("move_left")
	var iright = Input.is_action_pressed("move_right")
	
	if iup and not idown:
		input_dir = "up"
	elif idown and not iup:
		input_dir = "down"
	elif ileft and not iright:
		input_dir = "left"
	elif iright and not ileft:
		input_dir = "right"
	
	return input_dir
