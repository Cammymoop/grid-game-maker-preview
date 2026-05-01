extends VBoxContainer

const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

@export var reset_button: Button

@export var bg_color_picker: ColorPickerButton

@export var bg_gradient_enable: CheckButton
@export var bg_gradient_suboptions: Control
@export var bg_gradient_color_picker: ColorPickerButton
@export var bg_gradient_sort_option: OptionButton

@export var dusty_particles_enable: CheckButton
@export var dusty_particles_suboptions: Control
@export var dusty_particles_color_picker: ColorPickerButton
@export var dusty_particles_speed_input: ScalarValueInput
@export var dusty_particles_amount_input: ScalarValueInput

@export var pointy_particles_enable: CheckButton
@export var pointy_particles_suboptions: Control
@export var pointy_particles_color_picker: ColorPickerButton
@export var pointy_particles_rainbow_enable: CheckButton
@export var pointy_particles_dark_mode_enable: CheckButton
@export var pointy_particles_speed_input: ScalarValueInput
@export var pointy_particles_amount_input: ScalarValueInput

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

func _ready() -> void:
    reset_button.pressed.connect(reset_bg_style.unbind(1))
    bg_gradient_enable.toggled.connect(refresh_suboptions.unbind(1))
    dusty_particles_enable.toggled.connect(refresh_suboptions.unbind(1))
    pointy_particles_enable.toggled.connect(refresh_suboptions.unbind(1))
    lines_enable.toggled.connect(refresh_suboptions.unbind(1))
    solids_enable.toggled.connect(refresh_suboptions.unbind(1))
    
    setup_value_change_signals()
    load_bg_style()

func reset_bg_style() -> void:
    if GameManager.cur_scene != "Play":
        GameManager.set_game_setting("bg_style", {})
        GameManager.bg_style_changed.emit()
    else:
        GameManager.copy_game_bg_to_level()
    load_bg_style()

func load_bg_style() -> void:
    var bg_style: Dictionary = GameManager.get_level_bg_info()
    
    bg_color_picker.color = Utility.get_dict_color(bg_style, "background_color", Color.BLACK)
    
    bg_gradient_enable.set_pressed_no_signal(bg_style.get("bg_gradient_on", true))
    bg_gradient_color_picker.color = Utility.get_dict_color(bg_style, "bg_gradient_color", Color.BLACK)
    Utility.opbtn_select_text(bg_gradient_sort_option, bg_style.get("bg_gradient_above", "below"))
    
    dusty_particles_enable.set_pressed_no_signal(bg_style.get("dusty_particles_on", true))
    dusty_particles_color_picker.color = Utility.get_dict_color(bg_style, "dusty_particles_color", Color.GRAY)
    dusty_particles_speed_input.set_value(bg_style.get("dusty_particles_speed", 1.0))
    dusty_particles_amount_input.set_value(bg_style.get("dusty_particles_amount", 1.0))
    
    pointy_particles_enable.set_pressed_no_signal(bg_style.get("pointy_particles_on", true))
    pointy_particles_color_picker.color = Utility.get_dict_color(bg_style, "pointy_particles_color", Color.WHITE)
    pointy_particles_rainbow_enable.set_pressed_no_signal(bg_style.get("pointy_particles_rainbow_on", false))
    pointy_particles_dark_mode_enable.set_pressed_no_signal(bg_style.get("pointy_particles_dark_mode", false))
    pointy_particles_speed_input.set_value(bg_style.get("pointy_particles_speed", 1.0))
    pointy_particles_amount_input.set_value(bg_style.get("pointy_particles_amount", 1.0))
    
    lines_enable.set_pressed_no_signal(bg_style.get("lines_on", false))
    solids_enable.set_pressed_no_signal(bg_style.get("lines_solid_on", false))
    lines_color_picker.color = Utility.get_dict_color(bg_style, "lines_color", Color.WHITE)
    solids_color_picker.color = Utility.get_dict_color(bg_style, "lines_solid_color", Color.WHITE)
    ln_scroll_speed_input.set_value(bg_style.get("lines_scroll_speed", 0.05))
    ln_scroll_angle_input.set_value(bg_style.get("lines_scroll_angle", 0.4))
    ln_warp_strength_input.set_value(bg_style.get("lines_warp_strength", 1.0))
    ln_warp_scroll_speed_input.set_value(bg_style.get("lines_warp_scroll_speed", 0.05))
    ln_warp_scroll_angle_input.set_value(bg_style.get("lines_warp_scroll_angle", 0.4))

    refresh_suboptions()

func refresh_suboptions() -> void:
    bg_gradient_suboptions.visible = bg_gradient_enable.button_pressed
    dusty_particles_suboptions.visible = dusty_particles_enable.button_pressed
    pointy_particles_suboptions.visible = pointy_particles_enable.button_pressed
    lines_suboptions.visible = lines_enable.button_pressed or solids_enable.button_pressed

func update_color_option(new_color: Color, color_key: String, no_alpha: bool = false) -> void:
    var color_func: = Utility.color_string_no_alpha if no_alpha else Utility.color_string
    GameManager.set_auto_bg_info_value(color_key, color_func.call(new_color))

func update_scalar_option(new_value: float, scalar_key: String) -> void:
    GameManager.set_auto_bg_info_value(scalar_key, new_value)

func update_opbtn_option(new_index: int, opbtn: OptionButton, value_key: String) -> void:
    GameManager.set_auto_bg_info_value(value_key, opbtn.get_item_text(new_index))

func update_toggle_option(new_is_pressed: bool, toggle_key: String) -> void:
    GameManager.set_auto_bg_info_value(toggle_key, new_is_pressed)

func setup_value_change_signals() -> void:
    var color_pickers: Dictionary = {
        "background_color": bg_color_picker,
        "bg_gradient_color": bg_gradient_color_picker,
        "dusty_particles_color": dusty_particles_color_picker,
        "pointy_particles_color": pointy_particles_color_picker,
        "lines_color": lines_color_picker,
        "lines_solid_color": solids_color_picker,
    }
    for key in color_pickers:
        var color_picker: ColorPickerButton = color_pickers[key]
        if key == "background_color":
            color_picker.color_changed.connect(update_color_option.bind(key, true))
        else:
            color_picker.color_changed.connect(update_color_option.bind(key))

    var scalar_inputs: Dictionary = {
        "dusty_particles_speed": dusty_particles_speed_input,
        "dusty_particles_amount": dusty_particles_amount_input,
        "pointy_particles_speed": pointy_particles_speed_input,
        "pointy_particles_amount": pointy_particles_amount_input,
        "lines_scroll_speed": ln_scroll_speed_input,
        "lines_scroll_angle": ln_scroll_angle_input,
        "lines_warp_strength": ln_warp_strength_input,
        "lines_warp_scroll_speed": ln_warp_scroll_speed_input,
        "lines_warp_scroll_angle": ln_warp_scroll_angle_input,
    }
    for key in scalar_inputs:
        var scalar_input = scalar_inputs[key]
        scalar_input.value_changed.connect(update_scalar_option.bind(key))

    var opbtn_options: Dictionary = {
        "bg_gradient_above": bg_gradient_sort_option,
        "lines_above": lines_sort_option,
    }
    for key in opbtn_options:
        var opbtn: OptionButton = opbtn_options[key]
        opbtn.item_selected.connect(update_opbtn_option.bind(opbtn, key))
    
    var toggle_inputs: Dictionary = {
        "bg_gradient_on": bg_gradient_enable,
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