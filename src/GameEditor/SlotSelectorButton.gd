extends CenterContainer

signal slot_changed(new_slot_id)

@export var show_any_option: bool = false
@export var default_slot_id: int = Commands.Slot.RED

@onready var picker = find_child("PopupPicker")
@onready var cur_display = find_child("CurrentSlotDisplay")

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
    
    -2: preload("res://assets/img/button_icons/slot_icons/any.png"),
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
    
    any= -2,
}

var disabled_slots: Array = []

var current_slot_id: int = Commands.Slot.RED

var picker_open: = false

var show_categories: = ["all"]

var PICKER_SCREEN_MARGIN_H = 10
var PICKER_SCREEN_MARGIN_V = 10

func _ready():
    picker.visible = false
    if default_slot_id != current_slot_id and default_slot_id in slot_textures.keys():
        current_slot_id = default_slot_id
        update_texture()
    update_disabled_slots()

func update_disabled_slots() -> void:
    var category_container: Control = find_child("CategoryContainer")
    for category_child in category_container.get_children():
        if not category_child is Control:
            continue
        for button_child in category_child.get_children():
            if not button_child is ButtonContainer:
                continue
            var button_slot_id: int = get_slot_id_from_button_texture(button_child)
            if button_slot_id != -1:
                set_button_is_disabled(button_child, button_slot_id in disabled_slots)

func set_button_is_disabled(the_button: ButtonContainer, is_disabled: bool) -> void:
    if the_button.disabled == is_disabled:
        return
    the_button.disabled = is_disabled
    var texture_rect: TextureRect = the_button.find_child("TextureRect")
    if texture_rect:
        texture_rect.modulate.a = 0.5 if is_disabled else 1.0

func set_disabled_slots(new_disabled_slots: Array) -> void:
    disabled_slots = new_disabled_slots
    update_disabled_slots()

func get_slot_id_from_button_texture(button_node: ButtonContainer) -> int:
    var texture_rect: TextureRect = button_node.find_child("TextureRect")
    if not texture_rect or not texture_rect.texture in slot_textures.values():
        return -1
    
    return slot_textures.find_key(texture_rect.texture)

func set_valid_slot_categories(categories: Array) -> void:
    show_categories = categories
    
    find_child("AnyColumn").visible = show_any_option
    find_child("AnySeparator").visible = show_any_option
    
    var all = "all" in show_categories
    
    find_child("EntitySlots").visible = all or "entity" in show_categories
    find_child("EntitySeparator").visible = all or "entity" in show_categories

    find_child("TilePosSlots").visible = all or "pos" in show_categories
    find_child("TilePosSeparator").visible = all or "pos" in show_categories
    
    var value = all or "value" in show_categories
    var number = all or "number" in show_categories
    
    var int_category = value or number or "int" in show_categories
    var float_category = value or number or "float" in show_categories
    var string_category = value or "string" in show_categories
    
    find_child("IntSlots").visible = int_category
    find_child("IntSeparator").visible = int_category
    find_child("FloatSlots").visible = float_category
    find_child("FloatSeparator").visible = float_category
    find_child("StringSlots").visible = string_category
    find_child("StringSeparator").visible = string_category
    
    var arg_category = all or value or "argument" in show_categories
    find_child("ArgSlots").visible = all or value or "argument" in show_categories
    
    if not arg_category:
        for category in ["String", "Float", "Int", "TilePos", "Entity", "Any"]:
            var separator = find_child(category + "Separator")
            if separator.visible:
                separator.visible = false
                break
    
    if len(show_categories) == 0:
        $ButtonContainer.set_disabled(true)
        $ButtonContainer/CenterContainer.visible = false
    else:
        $ButtonContainer.set_disabled(false)
        $ButtonContainer/CenterContainer.visible = true

func get_first_valid_slot_id() -> int:
    if show_any_option:
        return -2
    for category_name in ["Entity", "TilePos", "Int", "Float", "String", "Arg"]:
        var slot_list: Node = find_child(category_name + "Slots")
        if not slot_list.visible or slot_list.get_child_count() == 0:
            continue
        for i in range(slot_list.get_child_count()):
            var slot_button: ButtonContainer = slot_list.get_child(i)
            if slot_button.disabled:
                continue
            var slot_id: int = get_slot_id_from_button_texture(slot_button)
            if slot_id != -1:
                return slot_id
    return Commands.Slot.RED

func show_picker() -> void:
    picker_open = true
    picker.popup_centered()
    picker.size = Vector2.ZERO
    var center_pos = $ButtonContainer.get_screen_position() + ($ButtonContainer.size/2)
    
    var picker_size = picker.get_node("PopupPanel").size
    picker.size = picker_size
    var viewport_size = get_viewport().size
    if picker.position.x < PICKER_SCREEN_MARGIN_H:
        picker.position.x = PICKER_SCREEN_MARGIN_H
    elif picker.position.x + picker_size.x > viewport_size.x - PICKER_SCREEN_MARGIN_H:
        picker.position.x = (viewport_size.x - PICKER_SCREEN_MARGIN_H) - picker_size.x
    if picker.position.y < PICKER_SCREEN_MARGIN_V:
        picker.position.y = PICKER_SCREEN_MARGIN_V
    elif picker.position.y + picker_size.y > viewport_size.y - PICKER_SCREEN_MARGIN_V:
        picker.position.y = (viewport_size.y - PICKER_SCREEN_MARGIN_V) - picker_size.y
    picker.position = center_pos - Vector2(picker.size/2)

    await get_tree().process_frame
    picker.position = center_pos - (Vector2(picker.size)/2)

func hide_picker() -> void:
    picker_open = false
    picker.hide()

func get_current_slot() -> int:
    return current_slot_id

func get_value() -> int:
    return get_current_slot()

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
        var bounds = Rect2(Vector2.ZERO, panel.size)
        if not bounds.has_point(local_click.position):
            hide_picker()


func _on_SlotSelected(slot_name: String):
    hide_picker()
    set_current_slot(slot_ids[slot_name])

func update_texture() -> void:
    cur_display.texture = slot_textures[current_slot_id]
