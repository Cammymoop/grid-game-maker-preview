extends Window

signal closing
signal sprite_config_changed(sprite_config: Dictionary)

const SpritePreviewer: = preload("res://Scenes/GameEditor/sprite_previewer.gd")
const FancySpriteLayerList: = preload("res://Scenes/GameEditor/fancy_sprite_layer_list.gd")

@export var sprite_previewer: SpritePreviewer
@export var layer_list_scroll: ScrollContainer
@export var layer_list: FancySpriteLayerList

var _sprite_config_backup: Dictionary = {}

var entity_def: = {}
var sprite_config: = {}

var snapshot_tex: ViewportTexture = null

func _ready() -> void:
    close_requested.connect(close_sprite_editor)
    if layer_list:
        layer_list.layers_changed.connect(on_layers_changed)
    await get_tree().process_frame
    update_scroll_container_size()

func _shortcut_input(event: InputEvent) -> void:
    if Utility.fixed_just_pressed_by_event("escape", event):
        close_sprite_editor()

func setup(new_entity_def: Dictionary) -> void:
    entity_def = new_entity_def.duplicate_deep()
    sprite_config = new_entity_def.get("sprite_config", {})
    refresh()
    get_layers_info_from_list()
    # save backup after refresh, since the list creates the default setup for starting with an empty sprite config
    _sprite_config_backup = sprite_config.duplicate_deep()

func restore_sprite_config() -> void:
    sprite_config = _sprite_config_backup.duplicate_deep()
    refresh()

func get_sprite_config() -> Dictionary:
    return sprite_config.duplicate_deep()

func on_layers_changed() -> void:
    update_scroll_container_size()
    get_layers_info_from_list()
    sprite_config_changed.emit(sprite_config)
    refresh_previewer()

func get_layers_info_from_list() -> void:
    if not layer_list:
        return
    var layers_info: = layer_list.get_layers_info()
    sprite_config["layers"] = layers_info.duplicate_deep()
    entity_def["sprite_config"] = sprite_config

func refresh() -> void:
    refresh_previewer()
    if layer_list:
        layer_list.set_layers_or_default(sprite_config.get("layers", []), entity_def)
        update_scroll_container_size()

func update_scroll_container_size() -> void:
    var list_size: = layer_list.get_combined_minimum_size()
    layer_list_scroll.custom_minimum_size.x = list_size.x

    var scroll_parent: = layer_list_scroll.get_parent() as VBoxContainer
    var v_spacing: float = scroll_parent.get_theme_constant("separation");
    var vertical_space: float = scroll_parent.size.y
    for scroll_sibling in scroll_parent.get_children():
        if scroll_sibling == layer_list_scroll:
            continue
        vertical_space -= scroll_sibling.size.y + v_spacing

    if list_size.y > vertical_space * 0.9:
        layer_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        layer_list_scroll.custom_minimum_size.y = 180
    else:
        layer_list_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        layer_list_scroll.custom_minimum_size.y = list_size.y

func refresh_previewer() -> void:
    if sprite_previewer:
        sprite_previewer.update_sprite_config(entity_def)

func get_snapshot() -> ViewportTexture:
    if not sprite_previewer:
        prints("No sprite previewer, returning null")
        return null
    sprite_previewer.reset_sprite(entity_def)
    sprite_previewer.find_child("PreviewBG").hide()
    await RenderingServer.frame_post_draw
    return sprite_previewer.preview_subviewport.get_texture()

func close_sprite_editor() -> void:
    snapshot_tex = await get_snapshot()
    closing.emit()
    queue_free()