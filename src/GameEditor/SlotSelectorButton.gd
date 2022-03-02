extends CenterContainer

signal slot_changed(new_slot_id)

onready var picker = find_node("PopupPicker")
onready var cur_display = find_node("CurrentSlotDisplay")

var slot_textures: = {
	Commands.Slot.RED:    preload("res://assets/img/button_icons/slot_icons/red_diamond.png"),
	Commands.Slot.BLUE:   preload("res://assets/img/button_icons/slot_icons/blue_square.png"), 
	Commands.Slot.WHITE:  preload("res://assets/img/button_icons/slot_icons/white_triangle.png"),
	Commands.Slot.PINK:   preload("res://assets/img/button_icons/slot_icons/pink_heart.png"), 
	
	Commands.Slot.GREY:    preload("res://assets/img/button_icons/slot_icons/grey_pentagon.png"),
	Commands.Slot.BLACK:   preload("res://assets/img/button_icons/slot_icons/black_hexagon.png"),
	
	Commands.Slot.A:  preload("res://assets/img/button_icons/slot_icons/A.png"),
	Commands.Slot.B:   preload("res://assets/img/button_icons/slot_icons/B.png"), 
	Commands.Slot.C:   preload("res://assets/img/button_icons/slot_icons/C.png"), 
	
	Commands.Slot.X:  preload("res://assets/img/button_icons/slot_icons/X.png"),
	Commands.Slot.Y:   preload("res://assets/img/button_icons/slot_icons/Y.png"), 
	Commands.Slot.Z:   preload("res://assets/img/button_icons/slot_icons/Z.png"), 
	
	Commands.Slot.I:  preload("res://assets/img/button_icons/slot_icons/I.png"),
	Commands.Slot.II:   preload("res://assets/img/button_icons/slot_icons/II.png"), 
	Commands.Slot.III:   preload("res://assets/img/button_icons/slot_icons/III.png"), 
	
	Commands.Slot.DARK_RED:    preload("res://assets/img/button_icons/slot_icons/dark_red_blob.png"),
	Commands.Slot.DARK_BLUE:   preload("res://assets/img/button_icons/slot_icons/dark_blue_blob.png"), 
	Commands.Slot.DARK_GREEN:  preload("res://assets/img/button_icons/slot_icons/dark_green_blob.png"),
	Commands.Slot.DARK_ORANGE:   preload("res://assets/img/button_icons/slot_icons/dark_orange_blob.png"), 
}

var slot_ids: = {
	red=   Commands.Slot.RED,
	blue=  Commands.Slot.BLUE,
	white= Commands.Slot.WHITE,
	pink=  Commands.Slot.PINK,
	
	grey=  Commands.Slot.GREY,
	black= Commands.Slot.BLACK,
	
	a= Commands.Slot.A,
	b= Commands.Slot.B,
	c= Commands.Slot.C,
	
	x= Commands.Slot.X,
	y= Commands.Slot.Y,
	z= Commands.Slot.Z,
	
	i= Commands.Slot.I,
	ii= Commands.Slot.II,
	iii= Commands.Slot.III,
	
	dark_red= Commands.Slot.DARK_RED,
	dark_blue= Commands.Slot.DARK_BLUE,
	dark_green= Commands.Slot.DARK_GREEN,
	dark_orange= Commands.Slot.DARK_ORANGE,
}

var current_slot_id: int = Commands.Slot.RED

var picker_open: = false

var PICKER_SCREEN_MARGIN_H = 10
var PICKER_SCREEN_MARGIN_V = 10

func _ready():
	picker.visible = false

func show_picker() -> void:
	picker_open = true
	picker.popup()
	picker.set_as_minsize()
	
	var center_pos = $ButtonContainer.rect_global_position + ($ButtonContainer.rect_size / 2)
	picker.rect_global_position = center_pos - (picker.rect_size/2)
	
	var picker_size = picker.rect_size
	var viewport_size = get_viewport().size
	if picker.rect_global_position.x < PICKER_SCREEN_MARGIN_H:
		picker.rect_global_position.x = PICKER_SCREEN_MARGIN_H
	elif picker.rect_global_position.x + picker_size.x > viewport_size.x - PICKER_SCREEN_MARGIN_H:
		picker.rect_global_position.x = (viewport_size.x - PICKER_SCREEN_MARGIN_H) - picker_size.x
	if picker.rect_global_position.y < PICKER_SCREEN_MARGIN_V:
		picker.rect_global_position.y = PICKER_SCREEN_MARGIN_V
	elif picker.rect_global_position.y + picker_size.y > viewport_size.y - PICKER_SCREEN_MARGIN_V:
		picker.rect_global_position.y = (viewport_size.y - PICKER_SCREEN_MARGIN_V) - picker_size.y

func hide_picker() -> void:
	picker_open = false
	picker.hide()

func get_current_slot() -> int:
	return current_slot_id

func set_current_slot(slot_id: int) -> void:
	current_slot_id = slot_id
	update_texture()
	emit_signal("slot_changed", current_slot_id)

func _on_ButtonContainer_pressed():
	if not picker_open:
		show_picker()

func _input(e):
	var click_event = e as InputEventMouseButton
	if not click_event or not click_event.is_pressed():
		return
	
	if picker_open:
		var panel = picker.get_node("PopupPanel")
		var local_click = panel.make_input_local(click_event)
		var bounds = Rect2(Vector2.ZERO, panel.rect_size)
		if not bounds.has_point(local_click.position):
			hide_picker()


func _on_SlotSelected(slot_name: String):
	hide_picker()
	set_current_slot(slot_ids[slot_name])

func update_texture() -> void:
	cur_display.texture = slot_textures[current_slot_id]
