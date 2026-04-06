extends CenterContainer

@onready var picker: PopupPanel = find_child("PopupPicker")
@onready var cur_display = find_child("CurrentDirectionDisplay")

@onready var slot_separator: VSeparator = picker.find_child("SlotSeparator")
@onready var slots_list: VBoxContainer = picker.find_child("SlotsList")

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

var slot_textures: = {
	Commands.Slot.A: preload("res://assets/img/button_icons/slot_icons/A.png"),
	Commands.Slot.B: preload("res://assets/img/button_icons/slot_icons/B.png"),
	Commands.Slot.C: preload("res://assets/img/button_icons/slot_icons/C.png"),
}

var include_slots: bool = true

var absolute_directions: = {up= 0, right= 1, down= 2, left= 3}

var current_direction: int = 0
var current_slot_id: int = -1

var picker_open: = false
var showing_relative: = false

func _ready():
	slot_separator.visible = include_slots
	slots_list.visible = include_slots
	picker.popup_hide.connect(on_picker_hidden)
	picker.get_node("PopupPickerPanel").reset_size()
	picker.window_input.connect(picker_input)

func show_picker() -> void:
	picker_open = true
	#picker.visible = true
	picker.popup_centered()
	var center = $ButtonContainer.get_screen_position() + ($ButtonContainer.size/2)
	picker.size = picker.get_node("PopupPickerPanel").size
	await get_tree().process_frame
	picker.position = center - Vector2(picker.size)/2.

func picker_input(event: InputEvent) -> void:
	if not picker_open:
		return
	
	for dir_input in ["move_up", "move_right", "move_down", "move_left"]:
		if Input.is_action_just_pressed_by_event(dir_input, event):
			var new_dir: String = dir_input.trim_prefix("move_")
			_on_DirectionSelected(new_dir)
			break

func on_picker_hidden() -> void:
	picker_open = false

func hide_picker() -> void:
	picker.hide()

func get_direction() -> int:
	return current_direction

func get_slot_id() -> int:
	return current_slot_id

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
	if direction_name in absolute_directions:
		current_direction = absolute_directions[direction_name]
		current_slot_id = -1
	else:
		current_direction = -1
		current_slot_id = get_slot_id_from_button_name(direction_name)
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
	if current_slot_id >= 0:
		cur_display.texture = slot_textures[current_slot_id]
	else:
		if showing_relative:
			cur_display.texture = relative_direction_textures[current_direction]
		else:
			cur_display.texture = direction_textures[current_direction]

func get_slot_id_from_button_name(button_name: String) -> int:
	var slot_name: = button_name.trim_prefix("Pick").to_upper()
	if not slot_name in Commands.Slot:
		return -1
	
	return Commands.Slot[slot_name]