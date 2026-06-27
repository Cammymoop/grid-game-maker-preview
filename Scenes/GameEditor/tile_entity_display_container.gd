extends PanelContainer

const ItemDisplay: = preload("res://Scenes/GameEditor/basic_item_display.gd")

@export var item_display: ItemDisplay
@export var center_container: CenterContainer

var is_entity: bool = false
var item_id: int = 0

var is_local_definition: = false
var _local_item_definition: Dictionary = {}

func load_item_from_current_game(item_is_entity: bool, new_item_id: int) -> void:
    is_entity = item_is_entity
    item_id = new_item_id
    is_local_definition = false
    _local_item_definition = {}
    refresh()

func load_local_def(item_is_entity: bool, new_local_def: Dictionary) -> void:
    is_entity = item_is_entity
    item_id = -1
    _local_item_definition = new_local_def
    is_local_definition = true
    refresh()

func get_def_from_game() -> Dictionary:
    if is_entity:
        return EntityManager.entity_defs.get(item_id, {})
    return MapManager.tile_defs.get(item_id, {})

func get_item_def() -> Dictionary:
    if is_local_definition:
        return _local_item_definition
    return get_def_from_game()

func get_item_type_str() -> String:
    return "entity" if is_entity else "tile"

func refresh() -> void:
    item_display.fetch_textures(item_id, get_item_def(), get_item_type_str())