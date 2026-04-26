extends Control

signal request_remove(item: Control)
signal request_duplicate(item: Control)
signal request_move_relative(item: Control, amt: int)
signal request_move_to_top(item: Control)
signal request_move_to_bottom(item: Control)
signal request_delete_others(item: Control)
signal changed()
signal height_changed()

const Vec2IInput: = preload("res://src/GameEditor/ConditionalEditor/vector2i_input.gd")
const BetterTextureDialog: = preload("res://src/GameEditor/BetterTextureDialog.gd")
const ScalarValueInput: = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

static var texture_picker_scene: = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")

const MODE_NORMAL: = "normal"
const MODE_DIGITS: = "digits"
const MODE_EMPTY: = "empty"

const LayerModeOptions: Dictionary[String, String] = {
    MODE_NORMAL: "normal",
    MODE_DIGITS: "digits",
    MODE_EMPTY: "empty",
}

const OFFSET_OFFSET: = "Offset"
const OFFSET_PIVOT: = "Pivot"
const OFFSET_BOTH: = "Both"

const ROTATES_ROTATES: = 0
const ROTATES_FIXED: = 1
const ROTATES_SPINS: = 2
const RotatesModeNames: Dictionary[int, String] = {
    ROTATES_ROTATES: "rotates",
    ROTATES_FIXED: "fixed",
    ROTATES_SPINS: "spins",
}
static var rotates_modes: Dictionary[String, int] = {}
const DEF_ROTATES_TEXT: = "rotates"

const DIGITS_SOURCE_NUMBER: = 0
const DIGITS_SOURCE_PROPERTY: = 1
const DigitsSourceTexts: Dictionary[int, String] = {
    DIGITS_SOURCE_NUMBER: "Number:",
    DIGITS_SOURCE_PROPERTY: "Property:",
}

@export var empty_layer_button_icon: Texture2D

@export var remove_button: ButtonContainer
@export var layer_image_button: ButtonContainer
@export var offset_type_selector: OptionButton
@export var offset_input: Vec2IInput
@export var mode_selector: OptionButton
@export var reorder_buttons: Control
@export var rotates_option: Control
@export var rotates_mode_select: OptionButton
@export var spin_speed_input: ScalarValueInput
@export var offset_degrees_input: ScalarValueInput

@export var digits_settings: Control
@export var digits_max_digits_input: ScalarValueInput
@export var digits_color_picker: ColorPickerButton
@export var digits_pad_zeros_toggle: CheckButton
@export var digits_source_selector: OptionButton
@export var digits_number_input: ScalarValueInput
@export var digits_property_input: LineEdit

@export var visibility_property_input: FuzzyAutocompleteInput
@export var mod_color_input: ColorPickerButton

@export var show_reorder_buttons: bool = true
@export var enable_context_menu: bool = true


@export var subsection_container: Control
@export var subsection_nav_forward: ButtonContainer
@export var subsection_nav_back: ButtonContainer

var cur_offs_type: String = OFFSET_OFFSET

var layer_info: Dictionary = {}

var last_spinning_value: float = 2

const CONTEXT_MENU_MOVE_UP = 10
const CONTEXT_MENU_MOVE_DOWN = 11
const CONTEXT_MENU_MOVE_TOP = 12
const CONTEXT_MENU_MOVE_BOTTOM = 13

const CONTEXT_MENU_DUPLICATE = 20
const CONTEXT_MENU_DELETE = 22
const CONTEXT_MENU_DELETE_OTHERS = 23

static func _static_init() -> void:
    for rotate_mode_id in RotatesModeNames:
        rotates_modes[RotatesModeNames[rotate_mode_id]] = rotate_mode_id

func _ready() -> void:
    if reorder_buttons:
        reorder_buttons.visible = show_reorder_buttons
        reorder_buttons.get_node("UpButton").pressed.connect(move_up_button_pressed)
        reorder_buttons.get_node("DownButton").pressed.connect(move_down_button_pressed)
    remove_button.pressed.connect(_req_remove)
    
    mode_selector.clear()
    for mode_name in LayerModeOptions:
        mode_selector.add_item(LayerModeOptions[mode_name])
    mode_selector.item_selected.connect(on_mode_selected)
    
    offset_type_selector.clear()
    for offs_type_name in [OFFSET_OFFSET, OFFSET_PIVOT, OFFSET_BOTH]:
        offset_type_selector.add_item(offs_type_name)
    offset_type_selector.selected = 0
    _set_cur_offset_type()
    offset_type_selector.item_selected.connect(on_offset_type_changed)
    offset_input.value_changed.connect(on_offset_changed)
    
    #rotates_toggle.toggled.connect(on_rotates_toggled)
    #rotates_toggle.set_pressed_no_signal(layer_info.get("rotates", true))
    
    rotates_mode_select.clear()
    for rotate_mode_id in [ROTATES_ROTATES, ROTATES_FIXED, ROTATES_SPINS]:
        rotates_mode_select.add_item(RotatesModeNames[rotate_mode_id], rotate_mode_id)
    Utility.opbtn_select_id(rotates_mode_select, ROTATES_ROTATES)
    rotates_mode_select.item_selected.connect(on_rotates_mode_selected)
    
    offset_degrees_input.value_changed.connect(on_offset_degrees_changed)
    
    digits_source_selector.clear()
    for source_id in DigitsSourceTexts:
        digits_source_selector.add_item(DigitsSourceTexts[source_id], source_id)
    Utility.opbtn_select_id(digits_source_selector, DIGITS_SOURCE_NUMBER)
    digits_source_selector.item_selected.connect(on_digits_source_selected)

    spin_speed_input.value_changed.connect(on_spin_speed_changed)
    spin_speed_input.set_value(last_spinning_value)
    
    digits_pad_zeros_toggle.toggled.connect(on_digits_pad_zeros_toggled)
    digits_max_digits_input.value_changed.connect(on_digits_max_digits_changed)
    digits_property_input.text_changed.connect(on_digits_property_changed)
    
    digits_color_picker.color_changed.connect(on_digits_color_changed)
    
    layer_image_button.pressed.connect(on_layer_image_button_pressed)
    
    visibility_property_input.text_changed.connect(on_visibility_prop_changed)
    mod_color_input.color_changed.connect(on_mod_color_changed)
    
    subsection_nav_forward.pressed.connect(on_navigate_subsection.bind(1))
    subsection_nav_back.pressed.connect(on_navigate_subsection.bind(-1))
    if subsection_container.get_child_count() > 0:
        _set_current_subsection_index(0)

    if layer_info and layer_info.has("mode"):
        refresh_ui()

func _current_rotates_mode() -> int:
    if layer_info.get("mode", MODE_EMPTY) == MODE_EMPTY:
        return ROTATES_ROTATES
    if not layer_info.get("rotates", true):
        return ROTATES_FIXED
    elif layer_info.has("spinning"):
        return ROTATES_SPINS
    return ROTATES_ROTATES

func _req_remove() -> void:
    request_remove.emit(self)

func on_rotates_toggled(button_pressed: bool) -> void:
    layer_info['rotates'] = button_pressed
    changed.emit()

func set_layer_info(new_layer_info: Dictionary) -> void:
    layer_info = new_layer_info.duplicate_deep()
    if is_inside_tree():
        refresh_ui()

func get_layer_info() -> Dictionary:
    return layer_info.duplicate_deep()

func get_mode_value() -> String:
    var selected_text: = mode_selector.get_item_text(mode_selector.selected)
    if not selected_text in LayerModeOptions:
        return MODE_NORMAL
    return selected_text

func set_mode_picker_value(new_mode_value: String) -> void:
    if not new_mode_value in LayerModeOptions.keys():
        mode_selector.selected = _layer_mode_index(MODE_NORMAL)
    else:
        mode_selector.selected = _layer_mode_index(new_mode_value)

func on_mode_selected(_index: int) -> void:
    layer_info['mode'] = get_mode_value()
    if layer_info['mode'] == MODE_NORMAL:
        _set_default_texture_and_index()

    if layer_info['mode'] == MODE_DIGITS:
        layer_info['pad_zeros'] = digits_pad_zeros_toggle.button_pressed
        layer_info['max_digits'] = int(digits_max_digits_input.get_value())
        layer_info['property'] = digits_property_input.text
    else:
        layer_info.erase('pad_zeros')
        layer_info.erase('max_digits')
        layer_info.erase('property')

    refresh_ui()
    changed.emit()

func _set_default_texture_and_index() -> void:
    if not 'texture' in layer_info:
        layer_info['texture'] = 0
    if not 'tex_index' in layer_info:
        layer_info['tex_index'] = 0

func on_offset_type_changed(_index: int) -> void:
    _set_cur_offset_type()

func _set_cur_offset_type() -> void:
    cur_offs_type = offset_type_selector.get_item_text(offset_type_selector.selected)
    update_offset_vec_input()

func _get_cur_offset() -> Vector2i:
    var offset_key: = "offset" if cur_offs_type != OFFSET_PIVOT else "pivot"
    return Utility.get_vector2i_from_arr(layer_info.get(offset_key, [0,0]))

func update_offset_vec_input() -> void:
    var offset_value: Vector2i = _get_cur_offset()
    offset_input.set_value(offset_value)

func on_offset_changed(new_offset: Vector2i) -> void:
    var offset_key: = "offset" if cur_offs_type != OFFSET_PIVOT else "pivot"
    if new_offset == Vector2i.ZERO:
        layer_info.erase(offset_key)
        if cur_offs_type == OFFSET_BOTH:
            layer_info.erase("pivot")
    else:
        layer_info[offset_key] = Utility.get_arr_from_vector2i(new_offset)
        if cur_offs_type == OFFSET_BOTH:
            layer_info["pivot"] = Utility.get_arr_from_vector2i(new_offset)
    changed.emit()


func refresh_ui() -> void:
    update_offset_vec_input()
    visibility_property_input.set_value(layer_info.get("when_property", ""))

    set_mode_picker_value(layer_info['mode'])
    if layer_info['mode'] == MODE_EMPTY:
        layer_image_button.disabled = true
    elif layer_info['mode'] == MODE_DIGITS:
        digits_pad_zeros_toggle.set_pressed_no_signal(layer_info.get("pad_zeros", true))
        digits_max_digits_input.set_value(layer_info.get("max_digits", 1))
        
        var digits_source: = DIGITS_SOURCE_NUMBER
        if layer_info.has("property"):
            digits_source = DIGITS_SOURCE_PROPERTY
        Utility.opbtn_select_id(digits_source_selector, digits_source)

        if digits_source == DIGITS_SOURCE_NUMBER:
            digits_number_input.set_value(layer_info.get("digits_number", 1))
        elif digits_source == DIGITS_SOURCE_PROPERTY:
            digits_property_input.set_value(layer_info.get("property", ""))
        digits_color_picker.color = Utility.get_dict_color(layer_info, "mod_color", Color.WHITE)
    
    mod_color_input.color = Utility.get_dict_color(layer_info, "mod_color", Color.WHITE)

    rotates_mode_select.visible = layer_info['mode'] != MODE_EMPTY
    if layer_info['mode'] != MODE_EMPTY:
        var cur_rotates_mode: = _current_rotates_mode()
        Utility.opbtn_select_id(rotates_mode_select, cur_rotates_mode)
        refresh_spin_speed_input()
    
    offset_degrees_input.set_value(layer_info.get("offset_degrees", 0))
    
    digits_settings.visible = layer_info['mode'] == MODE_DIGITS
    layer_image_button.visible = layer_info['mode'] != MODE_DIGITS
    update_image_button_texture()

func refresh_spin_speed_input() -> void:
    spin_speed_input.visible = _current_rotates_mode() == ROTATES_SPINS
    if layer_info.has("spinning"):
        spin_speed_input.set_value(layer_info["spinning"])

func update_image_button_texture() -> void:
    var button_texture: Texture2D = null
    if layer_info['mode'] == MODE_EMPTY and empty_layer_button_icon:
        button_texture = empty_layer_button_icon
    elif layer_info['mode'] == MODE_NORMAL:
        button_texture = Utility.atlas_texture_from_texture_index(layer_info['texture'], layer_info['tex_index'])
    layer_image_button.find_child("TextureRect").texture = button_texture


func move_up_button_pressed() -> void:
    request_move_relative.emit(self, -1)

func move_down_button_pressed() -> void:
    request_move_relative.emit(self, 1)


func on_layer_image_button_pressed() -> void:
    open_texture_picker()

func open_texture_picker() -> void:
    var tex_picker: = texture_picker_scene.instantiate()
    add_child(tex_picker)
    tex_picker.setup(layer_info['texture'], layer_info['tex_index'])
    tex_picker.confirmed.connect(_on_tex_picker_confirmed.bind(tex_picker))
    tex_picker.popup_centered()

func _on_tex_picker_confirmed(tex_picker: BetterTextureDialog) -> void:
    layer_info['texture'] = tex_picker.get_selected_texture()
    layer_info['tex_index'] = tex_picker.get_selected_sub_index()
    tex_picker.queue_free()
    update_image_button_texture()
    changed.emit()

func _gui_input(event: InputEvent) -> void:
    if enable_context_menu and event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and not event.is_pressed():
            do_context_menu()

func do_context_menu() -> void:
    var context_menu = Utility.get_empty_context_menu()
    context_menu.add_item("Duplicate", CONTEXT_MENU_DUPLICATE)
    context_menu.add_separator()
    context_menu.add_item("Delete", CONTEXT_MENU_DELETE)
    context_menu.add_item("Delete all other layers", CONTEXT_MENU_DELETE_OTHERS)
    context_menu.add_separator()
    context_menu.add_item("Move to top", CONTEXT_MENU_MOVE_TOP)
    context_menu.add_item("Move to bottom", CONTEXT_MENU_MOVE_BOTTOM)
    context_menu.id_pressed.connect(on_context_menu_id_pressed)
    get_window().add_child(context_menu)
    Utility.popup_context_menu_at_mouse(context_menu)

func on_context_menu_id_pressed(context_menu_id: int) -> void:
    match context_menu_id:
        CONTEXT_MENU_MOVE_UP:
            request_move_relative.emit(self, -1)
        CONTEXT_MENU_MOVE_DOWN:
            request_move_relative.emit(self, 1)
        CONTEXT_MENU_MOVE_TOP:
            request_move_to_top.emit(self)
        CONTEXT_MENU_MOVE_BOTTOM:
            request_move_to_bottom.emit(self)
        CONTEXT_MENU_DUPLICATE:
            request_duplicate.emit(self)
        CONTEXT_MENU_DELETE:
            request_remove.emit(self)
        CONTEXT_MENU_DELETE_OTHERS:
            request_delete_others.emit(self)

func _layer_mode_index(layer_mode: String) -> int:
    var mode_text: = LayerModeOptions[layer_mode]
    for i in mode_selector.get_item_count():
        if mode_selector.get_item_text(i) == mode_text:
            return i
    return -1


func on_digits_pad_zeros_toggled(is_pad_zeros: bool) -> void:
    if not layer_info["mode"] == MODE_DIGITS:
        return
    layer_info['pad_zeros'] = is_pad_zeros
    changed.emit()

func on_digits_max_digits_changed(new_value: float) -> void:
    if not layer_info["mode"] == MODE_DIGITS:
        return
    layer_info['max_digits'] = int(new_value)
    changed.emit()

func on_digits_property_changed(_prop_name: String) -> void:
    if not layer_info["mode"] == MODE_DIGITS:
        return
    _update_digits_source_from_selector()
    changed.emit()

func _update_digits_source_from_selector() -> void:
    var current_digits_source: = _get_digits_source_from_selector()
    if current_digits_source == DIGITS_SOURCE_PROPERTY:
        layer_info['property'] = digits_property_input.text
        layer_info.erase('digits_number')
    elif current_digits_source == DIGITS_SOURCE_NUMBER:
        layer_info['digits_number'] = int(digits_number_input.get_value())
        layer_info.erase('property')

func _get_digits_source_from_selector() -> int:
    return digits_source_selector.get_item_id(digits_source_selector.selected)
    
func on_digits_source_selected(index: int) -> void:
    var new_source_id: = digits_source_selector.get_item_id(index)
    digits_number_input.disabled = new_source_id == DIGITS_SOURCE_PROPERTY
    digits_property_input.disabled = new_source_id == DIGITS_SOURCE_NUMBER
    _update_digits_source_from_selector()

func on_digits_color_changed(new_color: Color) -> void:
    if not layer_info["mode"] == MODE_DIGITS:
        return
    _on_mod_color_picked(new_color)

func on_mod_color_changed(new_color: Color) -> void:
    _on_mod_color_picked(new_color)

func _on_mod_color_picked(new_color: Color) -> void:
    if new_color == Color.WHITE:
        layer_info.erase('mod_color')
    else:
        layer_info['mod_color'] = Utility.color_string(new_color)
    changed.emit()


func on_visibility_prop_changed(prop_name: String) -> void:
    layer_info['when_property'] = prop_name
    changed.emit()

func on_rotates_mode_selected(index: int) -> void:
    var new_rotates_mode: = rotates_mode_select.get_item_id(index)
    if new_rotates_mode == ROTATES_ROTATES:
        layer_info['rotates'] = true
        layer_info.erase('spinning')
    elif new_rotates_mode == ROTATES_FIXED:
        layer_info['rotates'] = false
        layer_info.erase('spinning')
    elif new_rotates_mode == ROTATES_SPINS:
        layer_info['rotates'] = true
        layer_info['spinning'] = last_spinning_value
    refresh_spin_speed_input()
    changed.emit()

func on_spin_speed_changed(new_value: float) -> void:
    last_spinning_value = new_value
    if _current_rotates_mode() != ROTATES_SPINS:
        return
    layer_info['spinning'] = new_value
    changed.emit()

func _get_current_subsection_index() -> int:
    for subsection in subsection_container.get_children():
        if subsection.visible:
            return subsection.get_index()
    return -1

func _set_current_subsection_index(index: int) -> void:
    for i in subsection_container.get_child_count():
        subsection_container.get_child(i).visible = i == index
    subsection_nav_back.disabled = index == 0
    subsection_nav_forward.disabled = index == subsection_container.get_child_count() - 1

func on_navigate_subsection(direction: int) -> void:
    var num_subsections: = subsection_container.get_child_count()
    if num_subsections == 0:
        return
    var new_index: = clampi(_get_current_subsection_index() + direction, 0, num_subsections - 1)
    _set_current_subsection_index(new_index)
    height_changed.emit()

func on_offset_degrees_changed(new_value: float) -> void:
    var wrapped_value: = fposmod(new_value, 360)
    if wrapped_value == 360:
        wrapped_value = 0
    if wrapped_value != new_value:
        offset_degrees_input.set_value(wrapped_value)

    if new_value == 0:
        layer_info.erase('offset_degrees')
    else:
        layer_info['offset_degrees'] = new_value
    changed.emit()