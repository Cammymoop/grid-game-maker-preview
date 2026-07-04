extends HBoxContainer

signal info_updated()

@export var icon_texrect: TextureRect
@export var text_label: Label
@export var separator_label: Label
@export var value_label: Label

@export var relative_icon_scale: float = 1

var item_id: int = -1

var has_icon: bool = false

var hide_empty_value: bool = true
var hide_zero_value: bool = false

var show_icon: bool = true
var show_text: bool = true
var show_value: bool = true

var enabled: bool = true

func _ready() -> void:
    set_icon_texture(TextureManager.get_fallback_texture_id(), 0)
    refresh_ui()

func updated() -> void:
    refresh_ui()
    info_updated.emit()

func set_enabled(new_enabled: bool) -> void:
    enabled = new_enabled
    updated()

func set_icon_texture(texture_id: int, tex_index: int) -> void:
    has_icon = true
    var atlas_texture: = Utility.atlas_texture_from_texture_index(texture_id, tex_index)
    var ui_scale: = GameManager.get_default_pixel_scale() * relative_icon_scale
    _set_icon_tex(atlas_texture, ui_scale)
    if enabled:
        updated()

func set_icon_as_entity(entity_id: int) -> void:
    has_icon = true
    var entity_snapshot: = EntityManager.get_entity_sprite_snapshot(entity_id)
    var ui_scale: = EntityManager.get_entity_sprite_snapshot_scale(entity_id) * relative_icon_scale
    _set_icon_tex(entity_snapshot, ui_scale)
    if enabled:
        updated()

func _set_icon_tex(texture: Texture2D, ui_scale: float) -> void:
    icon_texrect.texture = texture
    icon_texrect.custom_minimum_size = texture.get_size() * ui_scale

func unset_icon() -> void:
    has_icon = false
    if enabled:
        updated()


func set_item_text(text: String) -> void:
    text_label.text = text
    if enabled:
        updated()

func set_item_separator_string(separator: String) -> void:
    separator_label.text = separator

func set_item_number(value: float, non_negative: bool) -> void:
    if non_negative and value < 0.0:
        value = 0.0
    if Utility.is_float_integer(value):
        value_label.text = str(int(value))
    else:
        value_label.text = str(value)
    if enabled:
        updated()

func get_item_number() -> float:
    if not value_label.text.is_valid_float():
        return 0.0
    return float(value_label.text)

func set_item_value_string(value: String) -> void:
    value_label.text = value
    if enabled:
        updated()


func set_show_parts(new_show_icon: bool, new_show_text: bool, new_show_value: bool) -> void:
    show_icon = new_show_icon
    show_text = new_show_text
    show_value = new_show_value
    if enabled:
        updated()

func refresh_ui() -> void:
    if not enabled:
        hide()
        return
    var has_text: bool = show_text and text_label.text.length() > 0
    var has_value: bool = show_value and value_label.text.length() > 0
    if hide_empty_value and not has_value:
        hide()
        return
    if hide_zero_value and value_label.text.is_valid_float() and float(value_label.text) == 0.0:
        hide()
        return
    if not show_icon and not has_text and not has_value:
        hide()
        return
    show()

    icon_texrect.visible = show_icon and has_icon
    text_label.visible = has_text
    value_label.visible = has_value
    separator_label.visible = has_text and has_value