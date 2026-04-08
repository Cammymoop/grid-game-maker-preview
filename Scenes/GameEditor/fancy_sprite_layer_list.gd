extends VBoxContainer

signal layers_changed

const FancySpriteLayerListItem: = preload("res://Scenes/GameEditor/fancy_sprite_layer_list_item.gd")
var layer_list_item_scene: = preload("res://Scenes/GameEditor/fancy_sprite_layer_list_item.tscn")

const DEFAULT_LAYER_INFO: Dictionary = {
    "mode": FancySpriteLayerListItem.MODE_NORMAL,
    "texture": 0,
    "tex_index": 0,
}

func clear() -> void:
    clear_layers()
    layers_changed.emit()

func set_layers_or_default(new_layers: Array, entity_def: Dictionary = {}) -> void:
    if not new_layers:
        clear_layers()
        if not entity_def.has("texture") or not entity_def.has("tex_index"):
            _append_default_layer()
        else:
            var layer_info: = DEFAULT_LAYER_INFO.merged({"texture": entity_def["texture"], "tex_index": entity_def["tex_index"]}, true)
            prints("setting up first layer from basic texture indices:", layer_info)
            _append_layer_info(layer_info)
    else:
        set_layers_info(new_layers)

func get_layers_info() -> Array:
    var layers_info: Array = []
    for child in get_children():
        if child is FancySpriteLayerListItem:
            layers_info.push_front(child.get_layer_info())
    return layers_info

func set_layers_info(new_layers_info: Array) -> void:
    clear_layers()
    for new_layer_info in new_layers_info:
        _append_layer_info(new_layer_info)

func append_new_layer_auto() -> void:
    var layer_infos: = get_layers_info()
    layer_infos.reverse()
    var texture_index: int = 0
    var texture_sub_index: int = 0
    for layer_info in layer_infos:
        if layer_info["mode"] == FancySpriteLayerListItem.MODE_EMPTY:
            continue
        texture_index = layer_info["texture"]
        texture_sub_index = layer_info["tex_index"]
        break
    _append_layer_info(DEFAULT_LAYER_INFO.merged({"texture": texture_index, "tex_index": texture_sub_index}, true))
    layers_changed.emit()

func _append_default_layer() -> void:
    _append_layer_info(DEFAULT_LAYER_INFO)

func _append_layer_info(layer_info: Dictionary) -> void:
    var layer_item: = layer_list_item_scene.instantiate()
    layer_item.changed.connect(on_layer_changed)
    layer_item.request_move_relative.connect(move_layer_item_relative)
    layer_item.request_move_to_top.connect(layer_item_to_top)
    layer_item.request_move_to_bottom.connect(layer_item_to_bottom)
    layer_item.request_duplicate.connect(duplicate_layer_item)
    layer_item.request_remove.connect(remove_layer_item)
    layer_item.request_delete_others.connect(delete_other_layers)
    layer_item.set_layer_info(layer_info.duplicate_deep())
    add_child(layer_item)
    move_child(layer_item, 0)

func clear_layers() -> void:
    for child in get_children():
        if child is FancySpriteLayerListItem:
            remove_child(child)
            child.queue_free()

func on_layer_changed() -> void:
    layers_changed.emit()


func remove_layer_item(layer_item: FancySpriteLayerListItem) -> void:
    remove_child(layer_item)
    layer_item.queue_free()
    layers_changed.emit()

func delete_other_layers(except_layer_item: FancySpriteLayerListItem) -> void:
    for child in get_children():
        if child is FancySpriteLayerListItem and child != except_layer_item:
            remove_child(child)
            child.queue_free()
    layers_changed.emit()

func duplicate_layer_item(layer_item: FancySpriteLayerListItem) -> void:
    var layer_info: Dictionary = layer_item.get_layer_info()
    _append_layer_info(layer_info)
    var new_layer_item: = get_child(-1) as FancySpriteLayerListItem
    move_child(new_layer_item, layer_item.get_index() + 1)
    layers_changed.emit()

func move_layer_item_relative(layer_item: FancySpriteLayerListItem, move_amt: int) -> void:
    move_child(layer_item, layer_item.get_index() + move_amt)
    layers_changed.emit()

func layer_item_to_top(layer_item: FancySpriteLayerListItem) -> void:
    move_child(layer_item, 0)
    layers_changed.emit()

func layer_item_to_bottom(layer_item: FancySpriteLayerListItem) -> void:
    move_child(layer_item, get_child_count() - 1)
    layers_changed.emit()