extends ColorPickerButton

const GPFriendlyColorPicker = preload("res://Scenes/UI/gamepad_friendly_color_picker.gd")

static var clr_mode: = ColorPicker.MODE_OKHSL
static var clr_pick_shape: = ColorPicker.SHAPE_HSV_RECTANGLE

static var saved_colors: PackedColorArray = []
#static var recent_colors: PackedColorArray = []


func _ready() -> void:
    pressed.connect(load_color_stuff)
    popup_closed.connect(save_color_stuff)
    picker_created.connect(on_picker_created)

func on_picker_created() -> void:
    var picker: = get_picker()
    picker.set_script(GPFriendlyColorPicker)
    picker.set_process(true)
    picker.set_process_input(true)
    picker.cancelled.connect(on_picker_cancelled)

func on_picker_cancelled() -> void:
    get_popup().hide()

func load_color_stuff() -> void:
    var color_picker: = get_picker()
    if not color_picker:
        return
    color_picker.color_mode = clr_mode
    color_picker.picker_shape = clr_pick_shape
    
    _clear_presets(color_picker)
    for c in saved_colors:
        color_picker.add_preset(c)

func _clear_presets(color_picker: ColorPicker) -> void:
    for c in color_picker.get_presets():
        color_picker.erase_preset(c)


func save_color_stuff() -> void:
    var color_picker: = get_picker()
    clr_mode = color_picker.color_mode
    clr_pick_shape = color_picker.picker_shape
    
    saved_colors = color_picker.get_presets()