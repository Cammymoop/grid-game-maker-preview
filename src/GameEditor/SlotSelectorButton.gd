extends CenterContainer

signal slot_changed(new_slot_id)

onready var picker = find_node("PopupPicker")
onready var cur_display = find_node("CurrentSlotDisplay")

var slot_textures: = {
	Commands.Slot.RED:    preload("res://assets/img/button_icons/slot_icons/red_diamond.png"),
	Commands.Slot.BLUE:   preload("res://assets/img/button_icons/slot_icons/blue_square.png"), 
	Commands.Slot.WHITE:  preload("res://assets/img/button_icons/slot_icons/white_triangle.png"),
	Commands.Slot.PINK:   preload("res://assets/img/button_icons/slot_icons/pink_heart.png"), 
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

func _ready():
	picker.visible = false

func show_picker() -> void:
	picker_open = true
	picker.popup()
	picker.set_as_minsize()
	
	var center_pos = $ButtonContainer.rect_global_position + ($ButtonContainer.rect_size / 2)
	picker.rect_global_position = center_pos - (picker.rect_size/2)

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
		print('picker is open')
		var panel = picker.get_node("PopupPanel")
		var local_click = panel.make_input_local(click_event)
		var bounds = Rect2(Vector2.ZERO, panel.rect_size)
		if not bounds.has_point(local_click.position):
			print('picker is getting hid')
			hide_picker()


func _on_SlotSelected(slot_name: String):
	print("im selected " + slot_name)
	hide_picker()
	set_current_slot(slot_ids[slot_name])

func update_texture() -> void:
	cur_display.texture = slot_textures[current_slot_id]
