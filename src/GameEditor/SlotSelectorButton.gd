extends CenterContainer

signal slot_changed(new_slot_id)

@export var show_none_option: bool = false
@export var show_any_option: bool = false
@export var show_number_option: bool = false
@export var show_text_option: bool = false
@export var show_bool_option: bool = false
@export var args_enabled: bool = false
@export var default_slot_id: int = Commands.Slot.RED

@export var show_categories: Array[String] = ["all"]

@onready var picker = find_child("PopupPicker")
@onready var cur_display = find_child("CurrentSlotDisplay")

const ANY_SLOT: int = -2
const NUMBER_VALUE: int = -3
const TEXT_VALUE: int = -4
const BOOL_VALUE: int = -5
const NONE_SLOTS: int = -6

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
    
    ANY_SLOT: preload("res://assets/img/button_icons/slot_icons/any.png"),
    NUMBER_VALUE: preload("res://assets/img/button_icons/slot_icons/num.png"),
    TEXT_VALUE: preload("res://assets/img/button_icons/slot_icons/text.png"),
    BOOL_VALUE: preload("res://assets/img/button_icons/slot_icons/true_false.png"),
    NONE_SLOTS: preload("res://assets/img/button_icons/slot_icons/none.png"),
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
    
    any= ANY_SLOT,
    num= NUMBER_VALUE,
    text= TEXT_VALUE,
    tf= BOOL_VALUE,
    none= NONE_SLOTS,
}

var disabled_slots: Array = []

var current_slot_id: int = Commands.Slot.RED

var picker_open: = false

var PICKER_SCREEN_MARGIN_H = 10
var PICKER_SCREEN_MARGIN_V = 10

func _ready():
    picker.visible = false
    if default_slot_id != current_slot_id and default_slot_id in slot_textures.keys():
        current_slot_id = default_slot_id
        update_texture()
    set_valid_slot_categories(show_categories)
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

func any_special_enabled() -> bool:
    return (show_any_option or show_number_option or show_text_option or show_none_option or show_bool_option)

func set_valid_slot_categories(categories: Array) -> void:
    show_categories.assign(categories)
    
    var has_special_column: bool = any_special_enabled()
    var special_column: Node = find_child("SpecialColumn")
    
    special_column.visible = has_special_column
    find_child("SpecialSeparator").visible = has_special_column

    special_column.find_child("PickNone").visible = show_none_option
    special_column.find_child("PickAny").visible = show_any_option
    special_column.find_child("PickNumber").visible = show_number_option
    special_column.find_child("PickText").visible = show_text_option
    special_column.find_child("PickTrueFalse").visible = show_bool_option

    if len(show_categories) == 0:
        $ButtonContainer.set_disabled(true)
        $ButtonContainer/CenterContainer.visible = false
        return
    else:
        $ButtonContainer.set_disabled(false)
        $ButtonContainer/CenterContainer.visible = true
    
    
    var all = "all" in show_categories
    var cat_visible: Dictionary = {
        "Entity": all,
        "TilePos": all,
        "Int": all,
        "Float": all,
        "String": all,
        "Arg": all and args_enabled,
    }
    
    if "entity" in show_categories:
        cat_visible["Entity"] = true
    if "pos" in show_categories:
        cat_visible["TilePos"] = true

    if "string" in show_categories:
        cat_visible["String"] = true
        if args_enabled:
            cat_visible["Arg"] = true

    if "float" in show_categories:
        cat_visible["Float"] = true
    if "int" in show_categories:
        cat_visible["Int"] = true

    var or_in_show: = func(acc: bool, cat: String) -> bool: return acc or cat in show_categories
    var numerical: bool = ["float", "int", "number"].reduce(or_in_show, false)

    if numerical:
        cat_visible["Float"] = true
        cat_visible["Int"] = true
        if args_enabled:
            cat_visible["Arg"] = true
    if "argument" in show_categories and args_enabled:
        cat_visible["Arg"] = true
    
    var last_category: String = ""
    for category in cat_visible.keys():
        if cat_visible[category]:
            last_category = category

    for category in cat_visible.keys():
        if category != "Arg":
            find_child(category + "Separator").visible = false if category == last_category else cat_visible[category] 
        find_child(category + "Slots").visible = cat_visible[category]
    

func get_first_valid_slot_id() -> int:
    if show_any_option:
        return ANY_SLOT
    elif show_number_option:
        return NUMBER_VALUE
    elif show_text_option:
        return TEXT_VALUE
    elif show_categories.size() == 0:
        return -1

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
    
    var picker_size = picker.get_child(0).size
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
    if show_categories.size() == 0:
        if not (show_any_option or show_number_option or show_text_option):
            return -1
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
        var panel = picker.find_child("PopupPanel")
        var local_click = panel.make_input_local(click_event)
        var bounds = Rect2(Vector2.ZERO, panel.size)
        if not bounds.has_point(local_click.position):
            hide_picker()


func _on_SlotSelected(slot_name: String):
    hide_picker()
    set_current_slot(slot_ids[slot_name])

func update_texture() -> void:
    cur_display.texture = slot_textures[current_slot_id]
