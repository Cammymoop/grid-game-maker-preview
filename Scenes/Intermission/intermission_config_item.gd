extends Control

signal request_move_relative(direction: int)
signal request_move_top_bottom(direction: int)
signal request_remove()
signal request_context_menu()

signal item_updated()

const ImageConfigSection = preload("res://Scenes/Intermission/intermission_config_image_section.gd")
const AdaptiveMultiLineEdit = preload("res://Scenes/GameEditor/adaptable_multi_line_edit.gd")
const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")


@export var type_picker: OptionButton

@export var top_separator: HSeparator

@export var text_config_section: Control
@export var image_config_section: ImageConfigSection

@export var text_input: AdaptiveMultiLineEdit
@export var font_size_input: ScalarValueInput

@export var text_outline_enabled_toggle: CheckButton
@export var text_color_picker: ColorPickerButton
@export var text_outline_color_picker: ColorPickerButton

@export var move_up_button: ButtonContainer
@export var move_down_button: ButtonContainer

@export var remove_button: ButtonContainer

const TEXT_IDX: int = 0
const IMAGE_IDX: int = 1

const TYPES: Array[String] = ["text", "image"]

var default_font_size: float = 24


func _ready() -> void:
    image_config_section.image_changed.connect(on_image_changed)
    image_config_section.other_changed.connect(item_updated.emit)
    
    remove_button.pressed.connect(on_remove_button_pressed)
    move_up_button.pressed.connect(on_move_up_button_pressed)
    move_down_button.pressed.connect(on_move_down_button_pressed)
    
    text_input.multi_line_text_changed.connect(item_updated.emit.unbind(1))
    text_color_picker.color_changed.connect(item_updated.emit.unbind(1))
    text_outline_color_picker.color_changed.connect(item_updated.emit.unbind(1))
    text_outline_enabled_toggle.toggled.connect(item_updated.emit.unbind(1))
    font_size_input.value_changed.connect(item_updated.emit.unbind(1))

    type_picker.item_selected.connect(on_type_selected)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.is_pressed():
        request_context_menu.emit()

func refresh_order_buttons(max_index: int) -> void:
    var my_index: int = get_index()
    top_separator.visible = my_index != 0
    move_up_button.disabled = my_index == 0
    move_down_button.disabled = my_index == max_index

func setup_type_picker() -> void:
    type_picker.clear()
    for type_id in TYPES.size():
        type_picker.add_item(TYPES[type_id].capitalize(), type_id)

func on_type_selected(type_index: int) -> void:
    var type_id: = type_picker.get_item_id(type_index)
    
    image_config_section.visible = type_id == IMAGE_IDX
    text_config_section.visible = type_id == TEXT_IDX
    item_updated.emit()


func load_item_info(item_info: Dictionary) -> void:
    setup_type_picker()
    var is_text: bool = item_info["type"].to_lower() == TYPES[TEXT_IDX]
    if is_text:
        type_picker.selected = TEXT_IDX
    else:
        type_picker.selected = IMAGE_IDX
    
    text_config_section.visible = is_text
    image_config_section.visible = not is_text
    
    if not is_text:
        image_config_section.set_image_info(item_info)
    else:
        text_input.set_text_contents(item_info.get("text", ""))
        font_size_input.set_value(item_info.get("font_size", default_font_size))
        text_color_picker.color = Utility.get_dict_color(item_info, "text_color", Color.WHITE)
        text_outline_enabled_toggle.button_pressed = item_info.get("text_outline_enabled", true)
        text_outline_color_picker.color = Utility.get_dict_color(item_info, "text_outline_color", Color.BLACK)

func get_item_info() -> Dictionary:
    var info: = {
        "type": Utility.opbtn_get_selected_text(type_picker).to_lower(),
    }
    var is_text: bool = info["type"].to_lower() == "text"
    
    if is_text:
        info["text"] = text_input.multi_line_contents
        info["font_size"] = font_size_input.get_value()
        info["text_color"] = Utility.color_string(text_color_picker.color)
        info["text_outline_enabled"] = text_outline_enabled_toggle.button_pressed
        if text_outline_enabled_toggle.button_pressed:
            info["text_outline_color"] = Utility.color_string(text_outline_color_picker.color)
    else:
        info.merge(image_config_section.get_image_info())

    return info


func on_image_changed(_texture_id: int, _texture_sub_index: int) -> void:
    item_updated.emit()

func on_remove_button_pressed() -> void:
    request_remove.emit()

func on_move_up_button_pressed() -> void:
    _move_pressed(-1)

func on_move_down_button_pressed() -> void:
    _move_pressed(1)

func _move_pressed(direction: int) -> void:
    if Input.is_action_pressed("editor_alt_mode_hold"):
        request_move_top_bottom.emit(direction)
    else:
        request_move_relative.emit(direction)