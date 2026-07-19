extends VBoxContainer

signal image_changed(texture_id: int, texture_sub_index: int)
signal other_changed()

const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

const BetterTextureDialog = preload("res://src/GameEditor/BetterTextureDialog.gd")
var texture_picker_scn: PackedScene = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")

const MAX_ICON_SIZE: float = 100.0

var current_texture_id: int = -1
var current_texture_sub_index: int = 0

@export var no_image_texture: Texture2D

@export var image_picker_button: ButtonContainer

@export var scale_input: ScalarValueInput
@export var scale_smooth_toggle: CheckButton

@export var background_selector: OptionButton

@export var mod_color_picker: ColorPickerButton

func _ready() -> void:
    image_picker_button.pressed.connect(on_image_picker_button_pressed)

    scale_input.value_changed.connect(other_changed.emit.unbind(1))
    scale_smooth_toggle.toggled.connect(other_changed.emit.unbind(1))
    mod_color_picker.color_changed.connect(other_changed.emit.unbind(1))
    background_selector.item_selected.connect(other_changed.emit.unbind(1))

func set_image(texture_id: int, texture_sub_index: int) -> void:
    current_texture_id = texture_id
    current_texture_sub_index = texture_sub_index
    refresh_picker_button()

func on_image_picker_button_pressed() -> void:
    if not current_texture_id >= 0 or not TextureManager.has_texture_id(current_texture_id):
        current_texture_id = TextureManager.get_fallback_texture_id()
    show_texture_picker(current_texture_id, current_texture_sub_index)

func show_texture_picker(for_texture_id: int, for_texture_sub_index: int) -> void:
    var picker: = texture_picker_scn.instantiate() as BetterTextureDialog
    picker.setup(for_texture_id, for_texture_sub_index)
    picker.picked_texture.connect(on_texture_picked)
    add_child(picker)
    picker.popup_centered()

func on_texture_picked(texture_id: int, texture_sub_index: int) -> void:
    current_texture_id = texture_id
    current_texture_sub_index = texture_sub_index
    refresh_picker_button()
    image_changed.emit(current_texture_id, current_texture_sub_index)



func refresh_picker_button() -> void:
    if not current_texture_id >= 0 or not TextureManager.has_texture_id(current_texture_id):
        current_texture_id = TextureManager.get_fallback_texture_id()

    var atlas_tex: Texture2D = Utility.atlas_texture_from_texture_index(current_texture_id, current_texture_sub_index)
    var max_edge: int = maxi(atlas_tex.get_width(), atlas_tex.get_height())
    image_picker_button.icon = atlas_tex
    var icon_scale: float = minf(1, MAX_ICON_SIZE / maxf(1, max_edge))
    image_picker_button.set_icon_scale(icon_scale)

func set_image_info(item_info: Dictionary) -> void:
    set_image(int(item_info.get("texture_id", -1)), int(item_info.get("texture_sub_index", 0)))
    scale_input.set_value(item_info.get("scale", 1.0))
    scale_smooth_toggle.set_pressed_no_signal(item_info.get("scale_smooth", false))
    mod_color_picker.color = Utility.get_dict_color(item_info, "mod_color", Color.WHITE)
    
    var light_background: bool = item_info.get("light_background", false)
    var dark_background: bool = item_info.get("dark_background", false)
    if light_background:
        background_selector.selected = 1
    elif dark_background:
        background_selector.selected = 2
    else:
        background_selector.selected = 0

func get_image_info() -> Dictionary:
    var ret: =  {
        "texture_id": current_texture_id,
        "texture_sub_index": current_texture_sub_index,
        "scale": scale_input.get_value(),
        "scale_smooth": scale_smooth_toggle.button_pressed,
        "mod_color": Utility.color_string(mod_color_picker.color),
        "light_background": background_selector.selected == 1,
        "dark_background": background_selector.selected == 2,
    }
    return ret