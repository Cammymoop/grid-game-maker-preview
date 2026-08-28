extends VBoxContainer

signal request_bg_style()
signal disable_custom_bg()
signal edited_bg_style(bg_style: Dictionary)

const IconButton = preload("res://Scenes/UI/icon_button.gd")
const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")
const BGTileHolder = preload("res://Scenes/bg_tile_holder.gd")
const Vector2fInput = preload("res://src/GameEditor/ConditionalEditor/vector2f_input.gd")

const TexturePickerDialog = preload("res://src/GameEditor/BetterTextureDialog.gd")
var texture_picker_dialog_scn: = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")

@export var manual_source: = false

@export var reset_button: Button
@export var remove_override_button: Button

@export var bg_color_picker: ColorPickerButton

@export var bg_gradient_enable: CheckButton
@export var bg_gradient_suboptions: Control
@export var bg_gradient_color_picker: ColorPickerButton
@export var bg_gradient_sort_option: OptionButton
@export var bg_gradient_rotation_input: ScalarValueInput
@export var bg_gradient_cover_amount_input: ScalarValueInput

@export var dusty_particles_enable: CheckButton
@export var dusty_particles_suboptions: Control
@export var dusty_particles_color_picker: ColorPickerButton
@export var dusty_particles_speed_input: ScalarValueInput
@export var dusty_particles_amount_input: ScalarValueInput
@export var dusty_particles_camera_scroll_factor_input: ScalarValueInput

@export var pointy_particles_enable: CheckButton
@export var pointy_particles_suboptions: Control
@export var pointy_particles_color_picker: ColorPickerButton
@export var pointy_particles_rainbow_enable: CheckButton
@export var pointy_particles_dark_mode_enable: CheckButton
@export var pointy_particles_speed_input: ScalarValueInput
@export var pointy_particles_amount_input: ScalarValueInput
@export var pointy_particles_camera_scroll_factor_input: ScalarValueInput

@export var lines_enable: CheckButton
@export var solids_enable: CheckButton
@export var lines_suboptions: Control
@export var lines_sort_option: OptionButton
@export var lines_color_picker: ColorPickerButton
@export var solids_color_picker: ColorPickerButton
@export var ln_scroll_speed_input: ScalarValueInput
@export var ln_scroll_angle_input: ScalarValueInput
@export var ln_warp_strength_input: ScalarValueInput
@export var ln_warp_scroll_speed_input: ScalarValueInput
@export var ln_warp_scroll_angle_input: ScalarValueInput

@export var tile_enable: CheckButton
@export var tile_suboptions: Control
@export var tile_texture_picker_button: IconButton
@export var tile_color_picker: ColorPickerButton
@export var tile_sort_option: OptionButton
@export var tile_below_gradient_toggle: CheckButton
@export var tile_base_offset_input: Vector2fInput

@export var tile_angle_input: ScalarValueInput
@export var tile_scale_input: ScalarValueInput
@export var tile_smooth_scale_toggle: CheckButton
@export var tile_scale_with_camera_toggle: CheckButton
@export var tile_spacing_input: Vector2fInput
@export var tile_camera_scroll_factor_input: ScalarValueInput

@export var tile_auto_scroll_enable: CheckButton
@export var tile_auto_scroll_suboptions: Control
@export var tile_auto_scroll_speed_input: ScalarValueInput
@export var tile_auto_scroll_angle_input: ScalarValueInput

@export var ln_cam_scroll_factor_input: ScalarValueInput
@export var ln_solid_cam_scroll_factor_input: ScalarValueInput

const ANGLE_KEYS: = ["lines_scroll_angle", "lines_warp_scroll_angle", "bg_gradient_rotation", "bg_tile_angle", "bg_tile_auto_scroll_angle"]

var current_tile_texture_id: int = -1
var current_tile_texture_index: int = 0

var manual_info: Dictionary = {}

func _ready() -> void:
    reset_button.pressed.connect(reset_bg_style)
    remove_override_button.pressed.connect(remove_override_bg_style)
    remove_override_button.visible = GameManager.cur_scene == "Play"
    bg_gradient_enable.toggled.connect(refresh_suboptions.unbind(1))
    dusty_particles_enable.toggled.connect(refresh_suboptions.unbind(1))
    pointy_particles_enable.toggled.connect(refresh_suboptions.unbind(1))
    lines_enable.toggled.connect(refresh_suboptions.unbind(1))
    solids_enable.toggled.connect(refresh_suboptions.unbind(1))
    tile_enable.toggled.connect(refresh_suboptions.unbind(1))

    tile_auto_scroll_enable.toggled.connect(refresh_suboptions.unbind(1))
    
    tile_texture_picker_button.pressed.connect(open_tile_texture_picker)
    
    
    if not manual_source:
        GameManager.bg_style_changed.connect(bg_style_changed)
        if not GameManager.current_has_bg_info():
            remove_override_button.disabled = true
    else:
        remove_override_button.visible = true
        remove_override_button.disabled = false
    
    setup_value_change_signals()
    load_bg_style()

func open_tile_texture_picker() -> void:
    var use_texture_id: int = current_tile_texture_id
    if use_texture_id < 0 or not TextureManager.has_texture_id(use_texture_id):
        use_texture_id = TextureManager.get_fallback_texture_id()
    var texture_picker_dialog: TexturePickerDialog = texture_picker_dialog_scn.instantiate()
    add_child(texture_picker_dialog)
    texture_picker_dialog.setup(use_texture_id, current_tile_texture_index)
    texture_picker_dialog.picked_texture.connect(on_tile_texture_picked)
    texture_picker_dialog.popup_centered()

func reset_bg_style() -> void:
    if manual_source:
        manual_info = {}
        edited_bg_style.emit({})
        return

    if GameManager.cur_scene != "Play":
        GameManager.set_game_setting("bg_style", {})
    else:
        GameManager.copy_game_bg_to_current()
    GameManager.bg_style_changed.emit()
    load_bg_style()

func remove_override_bg_style() -> void:
    if manual_source:
        disable_custom_bg.emit()
        return

    if GameManager.cur_scene != "Play":
        return
    GameManager.remove_current_bg_override()
    remove_override_button.disabled = true
    load_bg_style()

func manual_copy_game_bg_style() -> void:
    manual_info = GameManager.get_current_bg_info()
    load_bg_style(true)

func load_manual_bg_style(new_info: Dictionary) -> void:
    manual_info = new_info
    load_bg_style(true)

func load_bg_style(manual_fetched: bool = false) -> void:
    if manual_source and not manual_fetched:
        request_bg_style.emit()
        return

    var bg_style: Dictionary = manual_info if manual_source else GameManager.get_current_bg_info()
    
    bg_color_picker.color = Utility.get_dict_color(bg_style, "background_color", Color.BLACK)
    
    bg_gradient_enable.set_pressed_no_signal(bg_style.get("bg_gradient_on", true))
    bg_gradient_color_picker.color = Utility.get_dict_color(bg_style, "bg_gradient_color", Color.BLACK)
    Utility.opbtn_select_text(bg_gradient_sort_option, bg_style.get("bg_gradient_above", "below"))
    bg_gradient_rotation_input.set_value(_turn_to_deg(bg_style.get("bg_gradient_rotation", 0.5)))
    bg_gradient_cover_amount_input.set_value(bg_style.get("bg_gradient_cover_amount", 0.8))

    dusty_particles_enable.set_pressed_no_signal(bg_style.get("dusty_particles_on", true))
    dusty_particles_color_picker.color = Utility.get_dict_color(bg_style, "dusty_particles_color", Color.GRAY)
    dusty_particles_speed_input.set_value(bg_style.get("dusty_particles_speed", 1.0))
    dusty_particles_amount_input.set_value(bg_style.get("dusty_particles_amount", 1.0))
    dusty_particles_camera_scroll_factor_input.set_value(bg_style.get("dusty_particles_camera_scroll_factor", 0.5))
    
    pointy_particles_enable.set_pressed_no_signal(bg_style.get("pointy_particles_on", true))
    pointy_particles_color_picker.color = Utility.get_dict_color(bg_style, "pointy_particles_color", Color.WHITE)
    pointy_particles_rainbow_enable.set_pressed_no_signal(bg_style.get("pointy_particles_rainbow_on", false))
    pointy_particles_dark_mode_enable.set_pressed_no_signal(bg_style.get("pointy_particles_dark_mode", false))
    pointy_particles_speed_input.set_value(bg_style.get("pointy_particles_speed", 1.0))
    pointy_particles_amount_input.set_value(bg_style.get("pointy_particles_amount", 1.0))
    pointy_particles_camera_scroll_factor_input.set_value(bg_style.get("pointy_particles_camera_scroll_factor", 0.0))
    
    lines_enable.set_pressed_no_signal(bg_style.get("lines_on", false))
    solids_enable.set_pressed_no_signal(bg_style.get("lines_solid_on", false))
    lines_color_picker.color = Utility.get_dict_color(bg_style, "lines_color", Color.WHITE)
    solids_color_picker.color = Utility.get_dict_color(bg_style, "lines_solid_color", Color.WHITE)
    ln_scroll_speed_input.set_value(bg_style.get("lines_scroll_speed", 0.05))
    ln_scroll_angle_input.set_value(_deg_to_turn(bg_style.get("lines_scroll_angle", 0.4)))
    ln_warp_strength_input.set_value(bg_style.get("lines_warp_strength", 1.0))
    ln_warp_scroll_speed_input.set_value(bg_style.get("lines_warp_scroll_speed", 0.05))
    ln_warp_scroll_angle_input.set_value(_turn_to_deg(bg_style.get("lines_warp_scroll_angle", 0.4)))
    
    ln_cam_scroll_factor_input.set_value(bg_style.get("lines_camera_scroll_factor", 1.0))
    ln_solid_cam_scroll_factor_input.set_value(bg_style.get("lines_solid_camera_scroll_factor", 1.0))
    
    tile_enable.set_pressed_no_signal(bg_style.get("bg_tile_on", false))
    tile_color_picker.color = Utility.get_dict_color(bg_style, "bg_tile_color", BGTileHolder.DEFAULT_TILE_COLOR)
    Utility.opbtn_select_text(tile_sort_option, bg_style.get("bg_tile_above", "below"))
    tile_below_gradient_toggle.set_pressed_no_signal(bg_style.get("bg_tile_below_gradient", true))
    tile_angle_input.set_value(_turn_to_deg(bg_style.get("bg_tile_angle", 0.0)))
    tile_scale_input.set_value(bg_style.get("bg_tile_scale", 1.0))
    tile_smooth_scale_toggle.set_pressed_no_signal(bg_style.get("bg_tile_smooth_scale", false))
    tile_scale_with_camera_toggle.set_pressed_no_signal(bg_style.get("bg_tile_scale_with_camera", true))
    tile_camera_scroll_factor_input.set_value(bg_style.get("bg_tile_camera_scroll_factor", 0.5))

    tile_spacing_input.set_value(Utility.get_vector2_from_arr(bg_style.get("bg_tile_spacing", [0.0, 0.0])), true)
    tile_base_offset_input.set_value(Utility.get_vector2_from_arr(bg_style.get("bg_tile_base_offset", [0.0, 0.0])), true)
    
    tile_auto_scroll_enable.set_pressed_no_signal(bg_style.get("bg_tile_auto_scroll_on", false))
    tile_auto_scroll_speed_input.set_value(bg_style.get("bg_tile_auto_scroll_speed", 0.5))
    tile_auto_scroll_angle_input.set_value(_turn_to_deg(bg_style.get("bg_tile_auto_scroll_angle", 0.0)))
    
    current_tile_texture_id = bg_style.get("bg_tile_texture_id", -1)
    current_tile_texture_index = bg_style.get("bg_tile_texture_index", 0)
    set_tile_texture_button_icon(current_tile_texture_id, current_tile_texture_index)

    refresh_suboptions()

func _turn_to_deg(turns: float) -> float:
    return roundf(rad_to_deg(turns * TAU))

func _deg_to_turn(deg: float) -> float:
    return deg_to_rad(deg) / TAU

func refresh_suboptions() -> void:
    bg_gradient_suboptions.visible = bg_gradient_enable.button_pressed
    dusty_particles_suboptions.visible = dusty_particles_enable.button_pressed
    pointy_particles_suboptions.visible = pointy_particles_enable.button_pressed
    lines_suboptions.visible = lines_enable.button_pressed or solids_enable.button_pressed
    tile_suboptions.visible = tile_enable.button_pressed
    tile_auto_scroll_suboptions.visible = tile_auto_scroll_enable.button_pressed

func _set_info_value(key: String, value: Variant) -> void:
    if manual_source:
        manual_source_set_info(key, value)
    else:
        GameManager.set_auto_bg_info_value(key, value)

func manual_source_set_info(key: String, value: Variant) -> void:
    manual_info[key] = value
    edited_bg_style.emit(manual_info)
    

func update_color_option(new_color: Color, color_key: String, no_alpha: bool = false) -> void:
    var color_func: = Utility.color_string_no_alpha if no_alpha else Utility.color_string
    _set_info_value(color_key, color_func.call(new_color))

func update_scalar_option(new_value: float, scalar_key: String) -> void:
    if scalar_key in ANGLE_KEYS:
        new_value = _deg_to_turn(new_value)
    _set_info_value(scalar_key, new_value)

func update_opbtn_option(new_index: int, opbtn: OptionButton, value_key: String) -> void:
    _set_info_value(value_key, opbtn.get_item_text(new_index))

func update_toggle_option(new_is_pressed: bool, toggle_key: String) -> void:
    _set_info_value(toggle_key, new_is_pressed)

func update_vector2f_option(new_value: Vector2, vector2f_key: String) -> void:
    _set_info_value(vector2f_key, Utility.get_arr_from_vector2(new_value))

func on_tile_texture_picked(texture_id: int, texture_index: int) -> void:
    current_tile_texture_id = texture_id
    current_tile_texture_index = texture_index
    set_tile_texture_button_icon(current_tile_texture_id, current_tile_texture_index)
    update_scalar_option(current_tile_texture_id, "bg_tile_texture_id")
    update_scalar_option(current_tile_texture_index, "bg_tile_texture_index")

func setup_value_change_signals() -> void:
    var color_pickers: Dictionary = {
        "background_color": bg_color_picker,
        "bg_gradient_color": bg_gradient_color_picker,
        "dusty_particles_color": dusty_particles_color_picker,
        "pointy_particles_color": pointy_particles_color_picker,
        "lines_color": lines_color_picker,
        "lines_solid_color": solids_color_picker,
        
        "bg_tile_color": tile_color_picker,
    }
    for key in color_pickers:
        var color_picker: ColorPickerButton = color_pickers[key]
        if key == "background_color":
            color_picker.color_changed.connect(update_color_option.bind(key, true))
        else:
            color_picker.color_changed.connect(update_color_option.bind(key))

    var scalar_inputs: Dictionary = {
        "bg_gradient_rotation": bg_gradient_rotation_input,
        "bg_gradient_cover_amount": bg_gradient_cover_amount_input,
        
        "bg_tile_angle": tile_angle_input,
        "bg_tile_scale": tile_scale_input,
        "bg_tile_camera_scroll_factor": tile_camera_scroll_factor_input,
        "bg_tile_auto_scroll_speed": tile_auto_scroll_speed_input,
        "bg_tile_auto_scroll_angle": tile_auto_scroll_angle_input,

        "dusty_particles_speed": dusty_particles_speed_input,
        "dusty_particles_amount": dusty_particles_amount_input,
        "dusty_particles_camera_scroll_factor": dusty_particles_camera_scroll_factor_input,
        "pointy_particles_speed": pointy_particles_speed_input,
        "pointy_particles_amount": pointy_particles_amount_input,
        "pointy_particles_camera_scroll_factor": pointy_particles_camera_scroll_factor_input,
        "lines_scroll_speed": ln_scroll_speed_input,
        "lines_scroll_angle": ln_scroll_angle_input,
        "lines_warp_strength": ln_warp_strength_input,
        "lines_warp_scroll_speed": ln_warp_scroll_speed_input,
        "lines_warp_scroll_angle": ln_warp_scroll_angle_input,
        
        "lines_camera_scroll_factor": ln_cam_scroll_factor_input,
        "lines_solid_camera_scroll_factor": ln_solid_cam_scroll_factor_input,
    }
    for key in scalar_inputs:
        var scalar_input = scalar_inputs[key]
        scalar_input.value_changed.connect(update_scalar_option.bind(key))

    var opbtn_options: Dictionary = {
        "bg_gradient_above": bg_gradient_sort_option,
        "lines_above": lines_sort_option,
        "bg_tile_above": tile_sort_option,
    }
    for key in opbtn_options:
        var opbtn: OptionButton = opbtn_options[key]
        opbtn.item_selected.connect(update_opbtn_option.bind(opbtn, key))
    
    var toggle_inputs: Dictionary = {
        "bg_gradient_on": bg_gradient_enable,
        "bg_tile_on": tile_enable,
        "bg_tile_below_gradient": tile_below_gradient_toggle,
        "bg_tile_smooth_scale": tile_smooth_scale_toggle,
        "bg_tile_scale_with_camera": tile_scale_with_camera_toggle,
        "bg_tile_auto_scroll_on": tile_auto_scroll_enable,

        "dusty_particles_on": dusty_particles_enable,
        "pointy_particles_on": pointy_particles_enable,
        "lines_on": lines_enable,
        "lines_solid_on": solids_enable,
        "pointy_particles_rainbow_on": pointy_particles_rainbow_enable,
        "pointy_particles_dark_mode": pointy_particles_dark_mode_enable,
    }
    for key in toggle_inputs:
        var toggle_input: CheckButton = toggle_inputs[key]
        toggle_input.toggled.connect(update_toggle_option.bind(key))
    
    var vector2f_inputs: Dictionary = {
        "bg_tile_spacing": tile_spacing_input,
        "bg_tile_base_offset": tile_base_offset_input,
    }
    for key in vector2f_inputs:
        var vector2f_input: Vector2fInput = vector2f_inputs[key]
        vector2f_input.value_changed.connect(update_vector2f_option.bind(key))

func bg_style_changed() -> void:
    if GameManager.cur_scene != "Play":
        return
    remove_override_button.disabled = not GameManager.current_has_bg_info()


func set_tile_texture_button_icon(texture_id: int, texture_index: int) -> void:
    if not TextureManager.has_texture_id(texture_id):
        texture_id = TextureManager.get_fallback_texture_id()
    var atlas_texture: Texture2D = Utility.atlas_texture_from_texture_index(texture_id, texture_index)
    tile_texture_picker_button.icon = atlas_texture