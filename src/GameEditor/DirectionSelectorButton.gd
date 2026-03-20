extends CenterContainer

@onready var picker = find_child("PopupPicker")
@onready var cur_display = find_child("CurrentDirectionDisplay")

var direction_textures: = {
	0: preload("res://assets/img/button_icons/direction_icons/up.png"),
	3: preload("res://assets/img/button_icons/direction_icons/left.png"), 
	1: preload("res://assets/img/button_icons/direction_icons/right.png"),
	2: preload("res://assets/img/button_icons/direction_icons/down.png"), 
}

var relative_direction_textures: = {
	0: preload("res://assets/img/button_icons/direction_icons/rel_up.png"),
	3: preload("res://assets/img/button_icons/direction_icons/rel_left.png"), 
	1: preload("res://assets/img/button_icons/direction_icons/rel_right.png"),
	2: preload("res://assets/img/button_icons/direction_icons/rel_down.png"), 
}

var absolute_directions: = {up= 0, right= 1, down= 2, left= 3}

var current_direction: int = 0

var picker_open: = false
var showing_relative: = false

func _ready():
	pass#picker.visible = false

func show_picker() -> void:
	picker_open = true
	#picker.visible = true
	picker.popup()
	var center = $ButtonContainer.get_global_rect().get_center()
	picker.size = picker.get_node("PopupPickerPanel").size
	picker.global_position = center - (picker.size/2)

func hide_picker() -> void:
	picker_open = false
	#picker.visible = false
	picker.hide()

func get_direction() -> int:
	return current_direction

func show_relative() -> void:
	showing_relative = true
	update_icon()
	update_picker()

func show_absolute() -> void:
	showing_relative = false
	update_icon()
	update_picker()

func _on_ButtonContainer_pressed():
	show_picker()

#func _input(e):
#	var click_event = e as InputEventMouseButton
#	if not click_event:
#		return
#
#	if picker_open:
#		var local_click = picker.make_input_local(click_event)
#		var bounds = Rect2(Vector2.ZERO, picker.size)
#		if not bounds.has_point(local_click.position):
#			hide_picker()


func _on_DirectionSelected(direction_name: String):
	hide_picker()
	print(direction_name)
	current_direction = absolute_directions[direction_name]
	update_icon()

func set_direction(direction_val: int) -> void:
	current_direction = direction_val
	update_icon()

func update_picker() -> void:
	var textures = relative_direction_textures if showing_relative else direction_textures
	picker.find_child("PickUp").find_child("Icon").texture = textures[0]
	picker.find_child("PickLeft").find_child("Icon").texture = textures[3]
	picker.find_child("PickRight").find_child("Icon").texture = textures[1]
	picker.find_child("PickDown").find_child("Icon").texture = textures[2]

func update_icon() -> void:
	if showing_relative:
		cur_display.texture = relative_direction_textures[current_direction]
	else:
		cur_display.texture = direction_textures[current_direction]
