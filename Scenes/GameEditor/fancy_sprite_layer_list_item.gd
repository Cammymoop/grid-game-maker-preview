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
const OrderComparisonInput: = preload("res://src/GameEditor/ConditionalEditor/order_comparison_input.gd")

static var texture_picker_scene: = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")

const MODE_NORMAL: = "normal"
const MODE_FOUR_WAY: = "4-way"
const MODE_DIGITS: = "digits"
const MODE_PARTICLES: = "particles"
const MODE_EMPTY: = "empty"

const LayerModeOptions: Dictionary[String, String] = {
    MODE_NORMAL: "normal",
    MODE_FOUR_WAY: "4-way",
    MODE_DIGITS: "digits",
    MODE_PARTICLES: "particles",
    MODE_EMPTY: "empty",
}

const OFFSET_OFFSET: = "Offset"
const OFFSET_PIVOT: = "Pivot"
const OFFSET_BOTH: = "Both"

const ROTATES_ROTATES: = 0
const ROTATES_FIXED: = 1
const ROTATES_SPINS: = 2
const ROTATES_TO_HEAD: = 3
const RotatesModeNames: Dictionary[int, String] = {
    ROTATES_ROTATES: "rotates",
    ROTATES_FIXED: "fixed",
    ROTATES_SPINS: "spins",
    ROTATES_TO_HEAD: "faces head",
}
static var rotates_modes: Dictionary[String, int] = {}
const DEF_ROTATES_TEXT: = "rotates"

const DIGITS_SOURCE_NUMBER: = 0
const DIGITS_SOURCE_PROPERTY: = 1
const DigitsSourceTexts: Dictionary[int, String] = {
    DIGITS_SOURCE_NUMBER: "Number:",
    DIGITS_SOURCE_PROPERTY: "Property:",
}

const VIS_PROP_TYPE_TRUTHY: = 0
const VIS_PROP_TYPE_FALSEY: = 1
const VIS_PROP_TYPE_NUMBER_COMPARE: = 2
const VisPropTypeTexts: Dictionary[int, String] = {
    VIS_PROP_TYPE_TRUTHY: "True or non-zero",
    VIS_PROP_TYPE_FALSEY: "False or zero",
    VIS_PROP_TYPE_NUMBER_COMPARE: "Compare",
}

const CAM_FOCUS_IGNORE: = "ignore"
const CAM_FOCUS_SHOW: = "show"
const CAM_FOCUS_HIDE: = "hide"
const CamFocusOptions: Array[String] = [CAM_FOCUS_IGNORE, CAM_FOCUS_SHOW, CAM_FOCUS_HIDE]

@export var empty_layer_button_icon: Texture2D

@export var remove_button: ButtonContainer
@export var offset_type_selector: OptionButton
@export var offset_input: Vec2IInput
@export var mode_selector: OptionButton
@export var reorder_buttons: Control
@export var rotates_option: Control
@export var rotates_mode_select: OptionButton
@export var spin_speed_input: ScalarValueInput
@export var angle_offset_four_way_select: OptionButton
@export var offset_degrees_input: ScalarValueInput

@export var layer_image_button: ButtonContainer
@export var four_way_image_pickers: Control
@export var four_way_picker_up: ButtonContainer
@export var four_way_picker_down: ButtonContainer
@export var four_way_picker_left: ButtonContainer
@export var four_way_picker_right: ButtonContainer

@export var z_offset_input: ScalarValueInput

@export var digits_settings: Control
@export var digits_max_digits_input: ScalarValueInput
@export var digits_color_picker: ColorPickerButton
@export var digits_pad_zeros_toggle: CheckButton
@export var digits_source_selector: OptionButton
@export var digits_number_input: ScalarValueInput
@export var digits_property_input: LineEdit

@export var particle_settings: Control
@export var particle_type_selector: OptionButton
@export var particle_color_enable_toggle: CheckButton
@export var particle_color_picker: ColorPickerButton

@export var visibility_property_input: FuzzyAutocompleteInput
@export var vis_prop_comparison_selector: OrderComparisonInput
@export var vis_prop_compare_number_input: ScalarValueInput
@export var vis_prop_type_selector: OptionButton

@export var mod_color_input: ColorPickerButton
@export var cam_focus_visibility_select: OptionButton
@export var moving_visibility_select: OptionButton

@export var show_reorder_buttons: bool = true
@export var enable_context_menu: bool = true


@export var subsection_container: Control
@export var subsection_nav_forward: ButtonContainer
@export var subsection_nav_back: ButtonContainer

@export var scale_input: ScalarValueInput

@export var large_scale_mode_select: OptionButton
@export var nine_patch_corner_size_input: Vec2IInput

@export var nine_patch_edge_repeat_select: OptionButton
@export var nine_patch_center_repeat_select: OptionButton

@export var nine_patch_corner_option: Control
@export var nine_patch_repeats_option: Control

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
    
    setup_particle_selector()
    particle_type_selector.item_selected.connect(on_particle_type_selected)
    
    particle_color_enable_toggle.toggled.connect(on_particle_toggle_color)
    particle_color_picker.color_changed.connect(on_particle_color_changed)
    
    z_offset_input.value_changed.connect(on_z_offset_changed)
    
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
    for rotate_mode_id in [ROTATES_ROTATES, ROTATES_FIXED, ROTATES_SPINS, ROTATES_TO_HEAD]:
        rotates_mode_select.add_item(RotatesModeNames[rotate_mode_id], rotate_mode_id)
    Utility.opbtn_select_id(rotates_mode_select, ROTATES_ROTATES)
    rotates_mode_select.item_selected.connect(on_rotates_mode_selected)
    
    angle_offset_four_way_select.item_selected.connect(on_angle_offset_four_way_selected)

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
    
    var dir_picker_buttons: Array[ButtonContainer] = [four_way_picker_up, four_way_picker_right, four_way_picker_down, four_way_picker_left]
    for i in 4:
        var dir_picker_button: ButtonContainer = dir_picker_buttons[i]
        dir_picker_button.pressed.connect(on_four_way_picker_pressed.bind(i))
    
    visibility_property_input.text_changed.connect(on_visibility_prop_changed)
    mod_color_input.color_changed.connect(on_mod_color_changed)
    
    vis_prop_type_selector.item_selected.connect(on_vis_prop_type_selected)
    vis_prop_type_selector.clear()
    for vis_prop_type_id in VisPropTypeTexts:
        vis_prop_type_selector.add_item(VisPropTypeTexts[vis_prop_type_id], vis_prop_type_id)
    Utility.opbtn_select_id(vis_prop_type_selector, VIS_PROP_TYPE_TRUTHY)
    
    vis_prop_comparison_selector.item_selected.connect(on_vis_prop_comparison_selected)
    vis_prop_compare_number_input.value_changed.connect(on_vis_prop_compare_number_changed)
    
    cam_focus_visibility_select.clear()
    for cam_focus_option in CamFocusOptions:
        cam_focus_visibility_select.add_item(cam_focus_option)
    cam_focus_visibility_select.selected = 0
    cam_focus_visibility_select.item_selected.connect(on_cam_focus_visibility_selected)
    
    moving_visibility_select.clear()
    for cam_focus_option in CamFocusOptions:
        moving_visibility_select.add_item(cam_focus_option)
    moving_visibility_select.selected = 0
    moving_visibility_select.item_selected.connect(on_moving_visibility_selected)
    
    scale_input.value_changed.connect(on_scale_changed)
    
    large_scale_mode_select.item_selected.connect(on_large_scale_mode_selected)
    
    nine_patch_corner_size_input.value_changed.connect(on_nine_patch_corner_size_changed)
    
    nine_patch_edge_repeat_select.item_selected.connect(on_nine_patch_edge_repeat_selected)
    nine_patch_center_repeat_select.item_selected.connect(on_nine_patch_center_repeat_selected)
    
    subsection_nav_forward.pressed.connect(on_navigate_subsection.bind(1))
    subsection_nav_back.pressed.connect(on_navigate_subsection.bind(-1))
    if subsection_container.get_child_count() > 0:
        _set_current_subsection_index(0)

    if layer_info and layer_info.has("mode"):
        refresh_ui()

func _current_rotates_mode() -> int:
    if layer_info.get("mode", MODE_EMPTY) == MODE_EMPTY:
        return ROTATES_ROTATES
    if layer_info.get("rotates_to_head", false):
        return ROTATES_TO_HEAD
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
    
    if layer_info['mode'] == MODE_PARTICLES:
        if particle_type_selector.item_count > 0:
            if particle_type_selector.selected < 0:
                particle_type_selector.selected = 0
            layer_info['particles_type'] = particle_type_selector.get_item_metadata(particle_type_selector.selected)
    else:
        layer_info.erase('particles_type')
    
    if layer_info['mode'] == MODE_FOUR_WAY:
        if not layer_info.has("four_way_texture_ids"):
            var cur_texture_id: int = TextureManager.get_fallback_texture_id()
            var cur_sub_index: int = 0
            if layer_info.has("texture") and layer_info.has("tex_index"):
                cur_texture_id = int(layer_info['texture'])
                cur_sub_index = int(layer_info['tex_index'])
            layer_info["four_way_texture_ids"] = []
            layer_info["four_way_texture_ids"].resize(4)
            layer_info["four_way_texture_ids"].fill(cur_texture_id)
            layer_info["four_way_sub_indices"] = []
            layer_info["four_way_sub_indices"].resize(4)
            layer_info["four_way_sub_indices"].fill(cur_sub_index)
        
        if not layer_info.has("four_way_angle_offsets"):
            layer_info["four_way_angle_offsets"] = []
            for i in 4:
                layer_info["four_way_angle_offsets"].append(Utility.normalize_angle_degrees(i * -90))
    else:
        layer_info.erase("four_way_texture_ids")
        layer_info.erase("four_way_sub_indices")
        layer_info.erase("four_way_angle_offsets")

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

    if layer_info.has("when_camera_focus"):
        Utility.opbtn_select_text(cam_focus_visibility_select, layer_info["when_camera_focus"])
    else:
        cam_focus_visibility_select.selected = 0
    if layer_info.has("when_moving"):
        Utility.opbtn_select_text(moving_visibility_select, layer_info["when_moving"])
    else:
        moving_visibility_select.selected = 0

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
        
        digits_number_input.visible = digits_source == DIGITS_SOURCE_NUMBER
        digits_property_input.visible = digits_source == DIGITS_SOURCE_PROPERTY
    elif layer_info['mode'] == MODE_PARTICLES:
        if not particle_type_selector.item_count > 0:
            setup_particle_selector()
        var type_capitalized: String = layer_info['particles_type'].capitalize()
        Utility.opbtn_select_text(particle_type_selector, type_capitalized)
        
        if layer_info.has("particles_color"):
            var particles_color: Color = Utility.get_dict_color(layer_info, "particles_color", Color.WHITE)
            particle_color_picker.color = particles_color
        
        particle_color_enable_toggle.set_pressed_no_signal(layer_info.get("particles_have_color", false))
        particle_color_picker.visible = particle_color_enable_toggle.button_pressed
    
    z_offset_input.set_value(layer_info.get("z_offset", 0))
    
    mod_color_input.color = Utility.get_dict_color(layer_info, "mod_color", Color.WHITE)

    rotates_mode_select.visible = layer_info['mode'] != MODE_EMPTY
    if layer_info['mode'] != MODE_EMPTY:
        var cur_rotates_mode: = _current_rotates_mode()
        Utility.opbtn_select_id(rotates_mode_select, cur_rotates_mode)
        refresh_spin_speed_input()
    
    var scale_vec: = Utility.get_vector2_from_arr(layer_info.get("scale", [1,1]))
    var scale_value: float = scale_vec[scale_vec.max_axis_index()]
    scale_input.set_value(scale_value)
    
    large_scale_mode_select.visible = layer_info['mode'] == MODE_NORMAL
    var is_nine_patch: bool = layer_info.get("scale_as_9_patch", false)
    
    large_scale_mode_select.selected = 1 if is_nine_patch else 0
    
    var corner_size_ratio: Vector2 = Utility.get_vector2_from_arr(layer_info.get("9_patch_corner_size", [0.375, 0.375]))
    var texture_tile_size: Vector2 = Vector2.ONE * MapManager.tile_width
    if layer_info.has("texture") and TextureManager.has_texture_id(layer_info['texture']):
        texture_tile_size = TextureManager.get_texture_metadata(layer_info['texture']).get('tile_size', texture_tile_size)
    nine_patch_corner_size_input.set_value((corner_size_ratio * texture_tile_size).round())
    
    nine_patch_edge_repeat_select.selected = 1 if layer_info.get("9_patch_edge_repeat", false) else 0
    nine_patch_center_repeat_select.selected = 1 if layer_info.get("9_patch_center_repeat", false) else 0

    nine_patch_corner_option.visible = is_nine_patch and layer_info['mode'] == MODE_NORMAL
    nine_patch_repeats_option.visible = is_nine_patch and layer_info['mode'] == MODE_NORMAL
    
    if layer_info['mode'] == MODE_FOUR_WAY:
        if not layer_info.has("four_way_angle_offsets"):
            offset_degrees_input.set_value(0)
        else:
            var cur_four_way_angle_dir: int = angle_offset_four_way_select.selected
            offset_degrees_input.set_value(layer_info.get("four_way_angle_offsets")[cur_four_way_angle_dir])
    else:
        offset_degrees_input.set_value(layer_info.get("offset_degrees", 0))
    
    _update_vis_prop_inputs_from_layer_info()
    
    four_way_image_pickers.visible = layer_info['mode'] == MODE_FOUR_WAY
    angle_offset_four_way_select.visible = layer_info['mode'] == MODE_FOUR_WAY
    digits_settings.visible = layer_info['mode'] == MODE_DIGITS
    particle_settings.visible = layer_info['mode'] == MODE_PARTICLES
    layer_image_button.visible = layer_info['mode'] in [MODE_NORMAL, MODE_EMPTY]
    update_image_button_texture()

func refresh_spin_speed_input() -> void:
    spin_speed_input.visible = _current_rotates_mode() == ROTATES_SPINS
    if layer_info.has("spinning"):
        spin_speed_input.set_value(layer_info["spinning"])

func update_image_button_texture() -> void:
    var button_texture: Texture2D = null
    var is_empty: bool = layer_info['mode'] == MODE_EMPTY
    if is_empty and empty_layer_button_icon:
        button_texture = empty_layer_button_icon
    elif layer_info['mode'] == MODE_NORMAL:
        button_texture = Utility.atlas_texture_from_texture_index(layer_info['texture'], layer_info['tex_index'])

    if layer_info['mode'] != MODE_FOUR_WAY:
        var layer_image_button_tex: TextureRect = layer_image_button.find_child("TextureRect")
        if layer_image_button_tex:
            layer_image_button_tex.texture = button_texture
            if is_empty:
                layer_image_button_tex.self_modulate = Color.WHITE
            else:
                layer_image_button_tex.self_modulate = Utility.get_dict_color(layer_info, "mod_color", Color.WHITE)
    else:
        var dir_picker_buttons: Array[ButtonContainer] = [four_way_picker_up, four_way_picker_right, four_way_picker_down, four_way_picker_left]
        for i in 4:
            var picker_button: ButtonContainer = dir_picker_buttons[i]
            var tex_rect: TextureRect = picker_button.find_child("TextureRect")
            
            var tex_id: int = layer_info["four_way_texture_ids"][i]
            var sub_index: int = layer_info["four_way_sub_indices"][i]
            var offset_angle: float = 0
            if layer_info.get("four_way_angle_offsets", []).size() == 4:
                offset_angle = deg_to_rad(layer_info["four_way_angle_offsets"][i])
            offset_angle += i * (TAU / 4)
            
            tex_rect.texture = Utility.atlas_texture_from_texture_index(tex_id, sub_index)
            tex_rect.rotation = offset_angle
            tex_rect.self_modulate = Utility.get_dict_color(layer_info, "mod_color", Color.WHITE)


func move_up_button_pressed() -> void:
    request_move_relative.emit(self, -1)

func move_down_button_pressed() -> void:
    request_move_relative.emit(self, 1)


func on_layer_image_button_pressed() -> void:
    open_texture_picker()

func on_four_way_picker_pressed(dir: int) -> void:
    open_texture_picker(dir)

func open_texture_picker(for_direction: int = -1) -> void:
    var cur_mode: String = layer_info['mode']
    if cur_mode != MODE_NORMAL and cur_mode != MODE_FOUR_WAY:
        return

    var tex_picker: = texture_picker_scene.instantiate()
    add_child(tex_picker)

    var tex_id: int = -1
    var sub_index: int = 0
    if cur_mode == MODE_NORMAL:
        tex_id = layer_info['texture']
        sub_index = layer_info['tex_index']
    elif cur_mode == MODE_FOUR_WAY:
        tex_id = layer_info["four_way_texture_ids"][for_direction]
        sub_index = layer_info["four_way_sub_indices"][for_direction]

    tex_picker.setup(tex_id, sub_index)
    tex_picker.confirmed.connect(_on_tex_picker_confirmed.bind(for_direction, tex_picker))
    tex_picker.popup_centered()

func _on_tex_picker_confirmed(for_direction: int, tex_picker: BetterTextureDialog) -> void:
    var cur_mode: String = layer_info['mode']
    var selected_texture_id: int = tex_picker.get_selected_texture()
    var selected_sub_index: int = tex_picker.get_selected_sub_index()

    if cur_mode == MODE_NORMAL:
        layer_info['texture'] = selected_texture_id
        layer_info['tex_index'] = selected_sub_index
    elif cur_mode == MODE_FOUR_WAY:
        if for_direction == -1:
            for_direction = 0
        layer_info["four_way_texture_ids"][for_direction] = selected_texture_id
        layer_info["four_way_sub_indices"][for_direction] = selected_sub_index
        if for_direction == 0:
            layer_info["texture"] = selected_texture_id
            layer_info["tex_index"] = selected_sub_index

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
    digits_number_input.value_input.visible = new_source_id == DIGITS_SOURCE_NUMBER
    digits_property_input.visible = new_source_id == DIGITS_SOURCE_PROPERTY
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
    update_image_button_texture()
    changed.emit()


func on_visibility_prop_changed(prop_name: String) -> void:
    layer_info['when_property'] = prop_name
    changed.emit()

func on_rotates_mode_selected(index: int) -> void:
    var new_rotates_mode: = rotates_mode_select.get_item_id(index)
    if new_rotates_mode == ROTATES_ROTATES:
        layer_info['rotates'] = true
        layer_info.erase('spinning')
        layer_info.erase('rotates_to_head')
    elif new_rotates_mode == ROTATES_FIXED:
        layer_info['rotates'] = false
        layer_info.erase('spinning')
        layer_info.erase('rotates_to_head')
    elif new_rotates_mode == ROTATES_SPINS:
        layer_info['rotates'] = true
        layer_info['spinning'] = last_spinning_value
        layer_info.erase('rotates_to_head')
    elif new_rotates_mode == ROTATES_TO_HEAD:
        layer_info['rotates'] = true
        layer_info['rotates_to_head'] = true
        layer_info.erase('spinning')

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
    var wrapped_value: = Utility.normalize_angle_degrees(new_value)
    if wrapped_value == 360:
        wrapped_value = 0
    if wrapped_value != new_value:
        offset_degrees_input.set_value(wrapped_value)

    var cur_mode: String = layer_info['mode']
    if cur_mode == MODE_FOUR_WAY:
        var cur_four_way_angle_dir: int = angle_offset_four_way_select.selected
        if not layer_info.has("four_way_angle_offsets"):
            layer_info["four_way_angle_offsets"] = []
            for i in 4:
                layer_info["four_way_angle_offsets"].append(Utility.normalize_angle_degrees(i * -90))
        layer_info["four_way_angle_offsets"][cur_four_way_angle_dir] = wrapped_value
    else:
        if new_value == 0:
            layer_info.erase('offset_degrees')
        else:
            layer_info['offset_degrees'] = wrapped_value
    update_image_button_texture()
    changed.emit()

func on_z_offset_changed(new_value: float) -> void:
    if new_value == 0:
        layer_info.erase('z_offset')
    else:
        layer_info['z_offset'] = new_value
    changed.emit()

func on_cam_focus_visibility_selected(index: int) -> void:
    var new_cam_focus_visibility: = cam_focus_visibility_select.get_item_text(index)
    if new_cam_focus_visibility == CAM_FOCUS_IGNORE:
        layer_info.erase('when_camera_focus')
    else:
        layer_info['when_camera_focus'] = new_cam_focus_visibility
    changed.emit()

func on_moving_visibility_selected(index: int) -> void:
    var new_moving_visibility: = moving_visibility_select.get_item_text(index)
    if new_moving_visibility == CAM_FOCUS_IGNORE:
        layer_info.erase('when_moving')
    else:
        layer_info['when_moving'] = new_moving_visibility
    changed.emit()


func _set_current_vis_prop_compare_expression() -> void:
    var compare_to_num: = float(vis_prop_compare_number_input.get_value())
    var comparison_op_str: = vis_prop_comparison_selector.get_value()
    if comparison_op_str == "=":
        comparison_op_str = "=="
    var E = GGMExpressionBuilder
    var expr = E.e_op(E.e_var("V"), comparison_op_str, E.e_val(compare_to_num))
    layer_info['when_prop_expression'] = E.e_wrap(expr)

func _get_comparison_op_and_number_from_expression(expr_data: Dictionary) -> Array:
    var default: Array = [">", 1.0]
    if not expr_data or not GGMExpressionBuilder._validate_expr_data(expr_data):
        prints("invalid or empty expression data")
        return default
    var op_expr = expr_data["expression_tree"]
    if op_expr.get("node", "") != "operation":
        prints("expression top level is not an operation")
        return default
    var op: String = op_expr.get("op", "")
    var right_expr = op_expr.get("right", {})
    if not op or not right_expr or right_expr.get("node", "") != "decimal":
        prints("Unable to get operator, or right operand as a float")
        return default
    
    return [op, right_expr.get("value", 1.0)]

func _update_vis_prop_inputs_from_layer_info() -> void:
    var vis_type: = _get_vis_type_from_layer_info()
    Utility.opbtn_select_id(vis_prop_type_selector, vis_type)
    if vis_type == VIS_PROP_TYPE_NUMBER_COMPARE:
        var expr_data: Dictionary = layer_info.get("when_prop_expression", {})
        var op_and_num: = _get_comparison_op_and_number_from_expression(expr_data)
        vis_prop_comparison_selector.set_value(op_and_num[0])
        vis_prop_compare_number_input.set_value(str(op_and_num[1]))

    vis_prop_comparison_selector.visible = vis_type == VIS_PROP_TYPE_NUMBER_COMPARE
    vis_prop_compare_number_input.visible = vis_type == VIS_PROP_TYPE_NUMBER_COMPARE

func _get_vis_type_from_layer_info() -> int:
    if layer_info.get("when_prop_expression", {}):
        return VIS_PROP_TYPE_NUMBER_COMPARE
    if layer_info.get("when_prop_falsey", false):
        return VIS_PROP_TYPE_FALSEY
    return VIS_PROP_TYPE_TRUTHY

func on_vis_prop_type_selected(index: int) -> void:
    var new_vis_prop_type: = vis_prop_type_selector.get_item_id(index)
    
    if new_vis_prop_type == VIS_PROP_TYPE_NUMBER_COMPARE:
        layer_info.erase('when_prop_falsey')
        _set_current_vis_prop_compare_expression()
    elif new_vis_prop_type == VIS_PROP_TYPE_FALSEY:
        layer_info.erase('when_prop_expression')
        layer_info["when_prop_falsey"] = true
    else:
        layer_info.erase('when_prop_expression')
        layer_info.erase('when_prop_falsey')
    changed.emit()
    
    refresh_ui()

func on_vis_prop_comparison_selected(_index: int) -> void:
    _set_current_vis_prop_compare_expression()
    changed.emit()

func on_vis_prop_compare_number_changed(_new_value: float) -> void:
    _set_current_vis_prop_compare_expression()
    changed.emit()


func _get_nine_patch_corner_size_for_save() -> Array:
    if not layer_info.has('texture') or not TextureManager.has_texture_id(layer_info['texture']):
        return [0.375, 0.375]

    var corner_size_pixels: Vector2 = nine_patch_corner_size_input.get_value()
    var texture_meta: Dictionary = TextureManager.get_texture_metadata(layer_info['texture'])
    var texture_tile_size: Vector2 = texture_meta.get('tile_size', Vector2.ONE * MapManager.tile_width)
    
    var corner_size_ratio: Vector2 = (corner_size_pixels / texture_tile_size)
    return Utility.vector_to_list(corner_size_ratio)

func on_large_scale_mode_selected(index: int) -> void:
    var is_nine_patch: bool = index > 0
    
    if is_nine_patch:
        layer_info['scale_as_9_patch'] = true
        layer_info['9_patch_corner_size'] = _get_nine_patch_corner_size_for_save()
        layer_info['9_patch_edge_repeat'] = nine_patch_edge_repeat_select.selected > 0
        layer_info['9_patch_center_repeat'] = nine_patch_center_repeat_select.selected > 0
    else:
        layer_info.erase('scale_as_9_patch')
        layer_info.erase('9_patch_corner_size')
        layer_info.erase('9_patch_edge_repeat')
        layer_info.erase('9_patch_center_repeat')
    changed.emit()
    refresh_ui()

func on_nine_patch_corner_size_changed(_new_value: Vector2) -> void:
    layer_info['9_patch_corner_size'] = _get_nine_patch_corner_size_for_save()
    changed.emit()

func on_nine_patch_edge_repeat_selected(index: int) -> void:
    if not layer_info.get("scale_as_9_patch", false):
        layer_info.erase('9_patch_edge_repeat')
        return
    layer_info['9_patch_edge_repeat'] = true if index > 0 else false
    changed.emit()

func on_nine_patch_center_repeat_selected(index: int) -> void:
    if not layer_info.get("scale_as_9_patch", false):
        layer_info.erase('9_patch_center_repeat')
        return
    layer_info['9_patch_center_repeat'] = true if index > 0 else false
    changed.emit()


func setup_particle_selector() -> void:
    particle_type_selector.clear()
    
    for i in MaskLayerSprite.particle_types.size():
        var particle_type_key: String = MaskLayerSprite.particle_types.keys()[i]
        particle_type_selector.add_item(particle_type_key.capitalize())
        particle_type_selector.set_item_metadata(i, particle_type_key)

func on_particle_type_selected(index: int) -> void:
    if layer_info["mode"] != MODE_PARTICLES:
        return
    var particle_type_key: String = particle_type_selector.get_item_metadata(index)
    layer_info['particles_type'] = particle_type_key
    changed.emit()

func on_particle_toggle_color(is_enabled: bool) -> void:
    if is_enabled:
        layer_info['particles_have_color'] = true
        layer_info['particles_color'] = Utility.color_string(particle_color_picker.color)
    else:
        layer_info.erase('particles_have_color')
        layer_info.erase('particles_color')
    particle_color_picker.visible = is_enabled
    changed.emit()

func on_particle_color_changed(new_color: Color) -> void:
    if particle_color_enable_toggle.button_pressed:
        layer_info['particles_color'] = Utility.color_string(new_color)
        changed.emit()

func on_angle_offset_four_way_selected(index: int) -> void:
    if not layer_info['mode'] == MODE_FOUR_WAY:
        return
    if index == 4:
        layer_info["four_way_angle_offsets"] = []
        for i in 4:
            layer_info["four_way_angle_offsets"].append(Utility.normalize_angle_degrees(i * -90))
        angle_offset_four_way_select.selected = 0
        changed.emit()
    elif index == 5:
        layer_info["four_way_angle_offsets"] = []
        for i in 4:
            layer_info["four_way_angle_offsets"].append(0.0)
        angle_offset_four_way_select.selected = 0
        changed.emit()

    refresh_ui()

func on_scale_changed(new_value: float) -> void:
    layer_info['scale'] = Utility.vector_to_list(Vector2(new_value, new_value))
    changed.emit()