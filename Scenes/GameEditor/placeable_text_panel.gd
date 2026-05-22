extends PanelContainer

const AdaptiveMultiLineEdit = preload("res://Scenes/GameEditor/adaptable_multi_line_edit.gd")
const ScalarValueInput: = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

signal text_picked(text: String)

@export var enable_style_customization_toggle: CheckButton
@export var customization_options_container: Control

@export var text_color_picker: ColorPickerButton
@export var outline_enabled_toggle: CheckButton
@export var outline_color_picker: ColorPickerButton
@export var font_size_input: ScalarValueInput

@export var align_left_button: Button
@export var align_center_button: Button
@export var align_right_button: Button

@export var text_input: AdaptiveMultiLineEdit

@export var hide_parent: Control

func _ready() -> void:
    close_panel()
    customization_options_container.hide()
    enable_style_customization_toggle.toggled.connect(on_style_customization_toggled)
    text_input.multi_line_text_submitted.connect(on_text_submitted)
    #text_input.multi_line_editing_toggled.connect(on_text_editing_toggled)
    
    outline_enabled_toggle.toggled.connect(on_outline_enabled_toggled)

func set_input_text(text: String) -> void:
    text_input.set_text_contents(text)

func open_panel(with_focus: bool = true) -> void:
    if hide_parent:
        hide_parent.show()
    show()
    if with_focus:
        text_input.grab_focus_and_edit()

func _shortcut_input(event: InputEvent) -> void:
    if not visible:
        return
    if Utility.event_is_menu_back_just_pressed(event):
        close_panel()
        accept_event()

func close_panel() -> void:
    if hide_parent:
        hide_parent.hide()
    hide()

func on_text_submitted(_text: String) -> void:
    accept_text()

func accept_text() -> void:
    prints("accepting text: ", text_input.multi_line_contents)
    text_picked.emit(text_input.multi_line_contents)
    close_panel()

func on_style_customization_toggled(new_is_enabled: bool) -> void:
    customization_options_container.visible = new_is_enabled

func get_style_info() -> Dictionary:
    if not enable_style_customization_toggle.button_pressed:
        return {}
    return {
        "h_align": get_horizontal_alignment(),
        "size": font_size_input.get_value(),
        "color": text_color_picker.color,
        "outline_enabled": outline_enabled_toggle.button_pressed,
        "outline_color": outline_color_picker.color,
    }

func get_horizontal_alignment() -> HorizontalAlignment:
    if align_left_button.button_pressed:
        return HORIZONTAL_ALIGNMENT_LEFT
    elif align_right_button.button_pressed:
        return HORIZONTAL_ALIGNMENT_RIGHT
    else:
        return HORIZONTAL_ALIGNMENT_CENTER

func on_outline_enabled_toggled(new_is_enabled: bool) -> void:
    outline_color_picker.disabled = not new_is_enabled