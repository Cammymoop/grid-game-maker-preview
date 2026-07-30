extends HBoxContainer

const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")
const BetterTextureDialog = preload("res://src/GameEditor/BetterTextureDialog.gd")
const texture_picker_scn: PackedScene = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")

signal changed
signal type_changed
signal request_remove

signal request_move_relative(direction: int)
signal request_move_top_bottom(direction: int)

@export var type_picker: OptionButton
@export var input_1: LineEdit
@export var input_2: LineEdit

@export var image_options: Control

@export var texture_picker_button: ButtonContainer
@export var relative_scale_input: ScalarValueInput
@export var with_dark_bg_toggle: CheckButton
@export var smooth_scale_toggle: CheckButton

@export var up_down_buttons: Control
@export var up_button: ButtonContainer
@export var down_button: ButtonContainer

const TYPE_ROLE_NAME: String = "role_name"
const TYPE_JUST_NAME: String = "just_name"
const TYPE_SECTION: String = "section"
const TYPE_LINK: String = "link"
const TYPE_IMAGE: String = "image"

const TYPE_STRINGS: Dictionary[String, String] = {
    TYPE_ROLE_NAME: "Role & Name",
    TYPE_JUST_NAME: "Just Name",
    TYPE_SECTION: "Section",
    TYPE_LINK: "Link",
    TYPE_IMAGE: "Image",
}

const MAX_ICON_SIZE: int = 32

var entry: Dictionary = {}

func _ready() -> void:
    setup_type_picker()
    type_picker.item_selected.connect(on_type_selected)
    var remove_button = find_child("RemoveCreditItemButton")
    remove_button.pressed.connect(remove_this_credit)
    refresh_ui()
    
    relative_scale_input.value_changed.connect(on_relative_scale_changed)
    with_dark_bg_toggle.toggled.connect(on_with_dark_bg_toggled)
    smooth_scale_toggle.toggled.connect(on_smooth_scale_toggled)
    
    texture_picker_button.pressed.connect(on_texture_picker_button_pressed)
    
    input_1.text_changed.connect(on_text_changed)
    input_2.text_changed.connect(on_text_changed)
    
    up_button.pressed.connect(on_order_button_pressed.bind(-1))
    down_button.pressed.connect(on_order_button_pressed.bind(1))

func on_text_changed(_new_text: String) -> void:
    changed.emit()

func cur_selected_type_str() -> String:
    var type_int_id: int = cur_selected_type_int_id()
    if type_int_id == -1:
        return ""
    return TYPE_STRINGS.keys()[type_int_id]

func cur_selected_type_int_id() -> int:
    return Utility.opbtn_get_selected_id(type_picker)

func get_entry() -> Dictionary:
    var type_str: String = cur_selected_type_str()
    if type_str == "":
        type_str = TYPE_ROLE_NAME

    var ret_entry: Dictionary = { "type": type_str }
    if type_str == TYPE_ROLE_NAME:
        ret_entry["role"] = input_1.text.strip_edges()
        ret_entry["name"] = input_2.text.strip_edges()
    elif type_str == TYPE_JUST_NAME:
        ret_entry["name"] = input_1.text.strip_edges()
    elif type_str == TYPE_SECTION:
        ret_entry["text"] = input_1.text.strip_edges()
    elif type_str == TYPE_IMAGE:
        ret_entry["texture_id"] = float(entry.get("texture_id", -1))
        ret_entry["texture_sub_index"] = float(entry.get("texture_sub_index", 0))
        ret_entry["relative_scale"] = entry.get("relative_scale", 1.0)
        ret_entry["with_dark_bg"] = entry.get("with_dark_bg", false)
        ret_entry["sharp_scale"] = entry.get("sharp_scale", false)
    elif type_str == TYPE_LINK:
        ret_entry["url"] = input_1.text.strip_edges()
    return ret_entry

func set_entry(entry_data: Dictionary) -> void:
    entry = entry_data.duplicate_deep()
    var type_int_id: int = TYPE_STRINGS.keys().find(entry.get("type", TYPE_ROLE_NAME))
    if type_int_id == -1:
        type_int_id = 0
    Utility.opbtn_select_id(type_picker, type_int_id)
    refresh_ui()

func refresh_ui() -> void:
    if not is_inside_tree():
        return
    var type_int_id: int = cur_selected_type_int_id()
    if type_int_id == -1:
        type_int_id = 0
    Utility.opbtn_select_id(type_picker, type_int_id)
    
    image_options.hide()

    var cur_type: String = cur_selected_type_str()
    if cur_type == TYPE_SECTION:
        input_1.text = entry.get("text", "")
        input_1.placeholder_text = "Section Title"
        input_2.visible = false
        
        input_1.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
        input_1.custom_minimum_size.x = 200
    elif cur_type in [TYPE_ROLE_NAME, TYPE_JUST_NAME, TYPE_LINK]:
        input_1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        input_1.custom_minimum_size.x = 0
        if cur_type == TYPE_ROLE_NAME:
            input_1.text = entry.get("role", "")
            input_1.placeholder_text = "Role"
            input_2.text = entry.get("name", "")
            input_2.visible = true
        elif cur_type == TYPE_JUST_NAME:
            input_1.text = entry.get("name", "")
            input_1.placeholder_text = "Name"
            input_2.visible = false
        elif cur_type == TYPE_LINK:
            input_1.text = entry.get("url", "")
            input_1.placeholder_text = "Link URL (https://...)"
            input_2.visible = false
    elif cur_type == TYPE_IMAGE:
        input_1.hide()
        input_2.hide()
        image_options.show()
        refresh_texture_picker_icon()
        relative_scale_input.set_value(entry.get("relative_scale", 1.0))
        with_dark_bg_toggle.set_pressed(entry.get("with_dark_bg", false))
        smooth_scale_toggle.set_pressed_no_signal(not entry.get("sharp_scale", false))

func refresh_texture_picker_icon() -> void:
    var cur_texture_id: int = int(entry.get("texture_id", -1))
    if not cur_texture_id >= 0 or not TextureManager.has_texture_id(cur_texture_id):
        cur_texture_id = TextureManager.get_fallback_texture_id()
    var cur_texture_sub_index: int = int(entry.get("texture_sub_index", 0))
    var atlas_tex: Texture2D = Utility.atlas_texture_from_texture_index(cur_texture_id, cur_texture_sub_index)
    var max_edge: int = maxi(atlas_tex.get_width(), atlas_tex.get_height())
    texture_picker_button.icon = atlas_tex
    var icon_scale: float = minf(1, MAX_ICON_SIZE / maxf(1, max_edge))
    texture_picker_button.set_icon_scale(icon_scale)


func remove_this_credit() -> void:
    request_remove.emit()

func clear() -> void:
    input_1.text = ""
    input_2.text = ""

func setup_type_picker() -> void:
    type_picker.clear()
    for index in TYPE_STRINGS.size():
        var type_str: String = TYPE_STRINGS.keys()[index]
        type_picker.add_item(TYPE_STRINGS[type_str], index)
    type_picker.selected = 0

func on_type_selected(index: int) -> void:
    var type_str: String = TYPE_STRINGS.keys()[type_picker.get_item_id(index)]
    entry["type"] = type_str
    refresh_ui()
    type_changed.emit()


func on_texture_picker_button_pressed() -> void:
    var type_str: String = cur_selected_type_str()
    if type_str == TYPE_IMAGE:
        var cur_texture_id: int = int(entry.get("texture_id", -1))
        if not cur_texture_id >= 0 or not TextureManager.has_texture_id(cur_texture_id):
            cur_texture_id = TextureManager.get_fallback_texture_id()
        var cur_texture_sub_index: int = int(entry.get("texture_sub_index", 0))
        show_texture_picker(cur_texture_id, cur_texture_sub_index)


func show_texture_picker(for_texture_id: int, for_texture_sub_index: int) -> void:
    var picker: = texture_picker_scn.instantiate() as BetterTextureDialog
    picker.setup(for_texture_id, for_texture_sub_index)
    picker.picked_texture.connect(on_texture_picked)
    add_child(picker)
    picker.popup_centered()

func on_texture_picked(texture_id: int, texture_sub_index: int) -> void:
    entry["texture_id"] = float(texture_id)
    entry["texture_sub_index"] = float(texture_sub_index)
    changed.emit()
    refresh_ui()

func on_relative_scale_changed(new_value: float) -> void:
    var type_str: String = cur_selected_type_str()
    if type_str == TYPE_IMAGE:
        entry["relative_scale"] = new_value
        changed.emit()

func on_with_dark_bg_toggled(new_pressed: bool) -> void:
    var type_str: String = cur_selected_type_str()
    if type_str == TYPE_IMAGE:
        entry["with_dark_bg"] = new_pressed
        changed.emit()

func on_smooth_scale_toggled(new_pressed: bool) -> void:
    var type_str: String = cur_selected_type_str()
    if type_str == TYPE_IMAGE:
        entry["sharp_scale"] = not new_pressed
        changed.emit()

func on_order_button_pressed(direction: int) -> void:
    if Utility.is_holding_alt_mode():
        request_move_top_bottom.emit(direction)
    else:
        request_move_relative.emit(direction)

func update_up_down_buttons(max_index: int) -> void:
    var my_index: = get_index()
    up_button.disabled = my_index == 0
    down_button.disabled = my_index == max_index
