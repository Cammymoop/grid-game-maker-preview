extends Node

const MapLayer = preload("res://src/MapLayer.gd")

signal level_size_changed

var map_layer_template = preload("res://Scenes/MapLayer.tscn")

var layers: Array = []
var map_metadata = {}

var blocking_tiles = []

var tile_width = 32

var tile_defs = {
    0: {
        "name": "floor",
        "texture": 0,
        "tex_index": 18,
        "properties": {
            "f1": true,
        },
    },
    1: {
        "name": "wall",
        "texture": 0,
        "tex_index": 19,
        "properties": {
            "blocks": true,
        },
    },
    2: {
        "name": "floor2",
        "texture": 0,
        "tex_index": 22,
        "properties": {
            "f2": true,
        },
    },
    3: {
        "name": "water",
        "texture": 0,
        "tex_index": 15,
        "properties": {
            "finish_move_onto_tile": {
                "condition": "has_no_property floats",
                "actions": ["kill"],
            },
            "wet": true,
        },
    },
    4: {
        "name": "greenery",
        "texture": 0,
        "tex_index": 27,
        "properties": {
            "blocks": {"condition": "has_no_property treads"},
            "finish_move_onto_tile": {
                "conditions": ["has_property treads"],
                "actions": ["replace_tile was_greenery"]
            }
        },
    },
    5: {
        "name": "was_greenery",
        "texture": 0,
        "tex_index": 28,
        "properties": {},
    },
}
@onready var loaded_tile_defs = tile_defs

var tile_index_map = {}

var tileset = null

var im_ready = false

func setup() -> void:
    fix_string_keys()
    if not TextureManager.im_ready:
        await TextureManager.textures_loaded
    create_tileset()
    find_blocking()
    
    im_ready = true

func refresh_definition():
    fix_string_keys()
    create_tileset()
    find_blocking()

func fix_string_keys():
    var old_definition = tile_defs
    tile_defs = {}
    for key in old_definition:
        var intk = int(key)
        tile_defs[intk] = old_definition[key]
        if "texture" in tile_defs[intk]:
            tile_defs[intk]["texture"] = int(tile_defs[intk]["texture"])
        if "tex_index" in tile_defs[intk]:
            tile_defs[intk]["tex_index"] = int(tile_defs[intk]["tex_index"])

func clear_layers():
    for l in layers:
        if is_instance_valid(l):
            l.queue_free()
    layers = []

func auto_setup_layers():
    layers = get_tree().get_nodes_in_group("MapLayer")
    for l in layers:
        l.tile_set = tileset

func create_random_layer():
    create_plain_layer()
    layers[0].random_init()

func create_plain_layer():
    clear_layers()
    var map_layer = create_empty_layer()
    if tile_defs.size() > 0:
        var floor_tile_index = 0 if not tile_name_exists("floor") else get_tile_index("floor")
        map_layer.single_init(floor_tile_index)
    
    emit_signal("level_size_changed")

func create_empty_layer():
    var map_layer = map_layer_template.instantiate()
    var ents = Utility.get_world().get_node("Entities")
    ents.add_sibling(map_layer, true)
    map_layer.tile_set = tileset
    layers.append(map_layer)
    return map_layer

func create_tileset():
    var new_tileset: = TileSet.new()
    new_tileset.tile_size = Vector2i.ONE * tile_width
    tile_index_map = {}
    
    for tile_index in tile_defs:
        var tile_info = tile_defs[tile_index]
        var atlas_source: = TileSetAtlasSource.new()
        atlas_source.texture = TextureManager.get_texture(tile_info['texture'])
        new_tileset.add_source(atlas_source)
        
        if tile_info['name'] in tile_index_map:
            print_debug("WARNING: tile name already in use: " + tile_info['name'])
        tile_index_map[tile_info['name']] = tile_index
        
        var tile_native_size = TextureManager.get_texture_tile_size(tile_info['texture'])
        atlas_source.texture_region_size = tile_native_size
        var atlas_coords: = TextureManager.get_index_atlas_coords(tile_info['texture'], tile_info['tex_index'])
        atlas_source.create_tile(atlas_coords)
        
        if "z-index" in tile_info['properties']:
            var tile_data: = atlas_source.get_tile_data(atlas_coords, 0)
            tile_data.z_index = int(tile_info['properties']['z-index'])
            
    tileset = new_tileset

func update_index_map() -> void:
    tile_index_map = {}
    for tile_index in tile_defs:
        var tname = tile_defs[tile_index]['name']
        if tname in tile_index_map:
            push_warning("WARNING: tile name already in use: " + tname)
        tile_index_map[tname] = tile_index

func get_tile_texture(tile_index) -> Texture2D:
    return TextureManager.get_texture(tile_defs[tile_index]['texture'])
func get_tile_texture_rect(tile_index) -> Rect2:
    return TextureManager.get_index_rect(tile_defs[tile_index]['texture'], tile_defs[tile_index]['tex_index'])

func serialize() -> Dictionary:
    var serialized_layers = []
    for l in layers:
        serialized_layers.append(l.serialize())

    var serialized_stuff = {"layers": serialized_layers, "metadata": map_metadata.duplicate(true)}
    return serialized_stuff

func deserialize(data: Dictionary) -> void:
    clear_layers()
    
    for layer_data in data["layers"]:
        var new_layer = create_empty_layer()
        new_layer.deserialize(layer_data)
    
    map_metadata = data.get("metadata", {}).duplicate(true)
    
    emit_signal("level_size_changed")

func create_positioned_property(at_pos: Vector2i, for_tile_index: int) -> Dictionary:
    if not map_metadata.has("positioned_properties"):
        map_metadata["positioned_properties"] = {}
    var on_layer_index: int = -1
    for i in layers.size():
        var layer: = layers[i] as MapLayer
        var index_here: = layer.get_cell_s(at_pos)
        if index_here != for_tile_index:
            continue
        on_layer_index = i
        break
    
    if on_layer_index == -1:
        #push_warning("Tile index %s not found at position %s to create positioned property for" % [for_tile_index, at_pos])
        return {}
    
    var pos_props: Dictionary = map_metadata["positioned_properties"]
    if not has_positioned_property_at(at_pos):
        pos_props[at_pos] = { "layers": {} }
    var new_pos_prop: Dictionary = {
        "tile_index": for_tile_index,
        "local_properties": {},
    }
    pos_props[at_pos]["layers"][on_layer_index] = new_pos_prop
    return new_pos_prop

func has_positioned_property_at(at_pos: Vector2i, for_tile_index: int = -1) -> bool:
    if not map_metadata.has("positioned_properties"):
        return false
    var pos_props: Dictionary = map_metadata["positioned_properties"]
    if for_tile_index >= 0:
        var pos_prop: = pos_props.get(at_pos, {}) as Dictionary
        for layer_pos_prop: Dictionary in pos_prop["layers"].values():
            if layer_pos_prop["tile_index"] == for_tile_index:
                return true
        return false
    return pos_props.has(at_pos)

func get_positioned_property_at(at_pos: Vector2i, for_tile_index: int) -> Dictionary:
    if not has_positioned_property_at(at_pos):
        return {}
    var pos_prop: = map_metadata["positioned_properties"].get(at_pos, {}) as Dictionary
    for layer_pos_prop: Dictionary in pos_prop["layers"].values():
        if layer_pos_prop["tile_index"] == for_tile_index:
            return layer_pos_prop
    return {}

func get_or_create_positioned_property_at(at_pos: Vector2i, for_tile_index: int) -> Dictionary:
    var existing: = get_positioned_property_at(at_pos, for_tile_index)
    if existing:
        return existing
    return create_positioned_property(at_pos, for_tile_index)

func set_positioned_prop_value(at_pos: Vector2i, for_tile_index: int, property_name: String, value: Variant) -> void:
    var pos_prop: = get_or_create_positioned_property_at(at_pos, for_tile_index)
    if not pos_prop:
        # tile index is not at this position
        return
    pos_prop["local_properties"][property_name] = value

func get_positioned_prop_value(at_pos: Vector2i, for_tile_index: int, property_name: String) -> Variant:
    var pos_prop: = get_positioned_property_at(at_pos, for_tile_index)
    if not pos_prop or not pos_prop["local_properties"].has(property_name):
        return null
    return pos_prop["local_properties"][property_name]

func remove_positioned_prop_value(at_pos: Vector2i, for_tile_index: int, property_name: String) -> void:
    var pos_prop: = get_positioned_property_at(at_pos, for_tile_index)
    if not pos_prop or not pos_prop["local_properties"].has(property_name):
        return
    pos_prop["local_properties"].erase(property_name)

func has_next_level() -> bool:
    var next_level_name = map_metadata.get("next_level", "") as String
    return next_level_name != "" and FilesManager.level_exists(GameManager.cur_game_name, next_level_name)

func set_next_level_name(next_level_name: String) -> void:
    map_metadata["next_level"] = next_level_name

func get_next_level_name() -> String:
    return map_metadata.get("next_level", "") as String

func get_all_tile_indexes() -> Array:
    var keys = tile_defs.keys()
    keys.sort()
    return keys
 

func get_all_positions_of_tile(tile_index: int, position_filter: Array = []) -> Array:
    var positions = []
    for l in layers:
        for pos in l.get_used_cells_by_id(tile_index):
            if is_pos_in_filter(pos, position_filter):
                positions.append(pos)
    return positions

func is_pos_in_filter(tile_position: Vector2i, position_filter: Array) -> bool:
    if not position_filter:
        return true
    if typeof(position_filter[0]) == TYPE_STRING and position_filter[0] == "rectangle":
        var rect = Rect2(position_filter[1], position_filter[2] + Vector2(1, 1))
        return rect.has_point(tile_position)
    else:
        return tile_position in position_filter

func get_map_size() -> Rect2:
    if len(layers) > 0:
        return layers[0].get_used_rect()
    return Rect2(0, 0, 0, 0)

func get_level_bounds() -> Rect2:
    var map_bounds: = get_map_size()
    var level_bounds: = Rect2(map_bounds.position * tile_width, map_bounds.size * tile_width)
    return level_bounds

func get_tile_index(tile_name) -> int:
    return tile_index_map[tile_name]

func tile_name_exists(tile_name) -> bool:
    return tile_name in tile_index_map

func get_tile_name(tile_index) -> String:
    return tile_defs[tile_index]['name']

func find_blocking() -> void:
    blocking_tiles = []
    
    for ti in tile_defs:
        var blocks: = get_tile_index_property(ti, "blocks")
        if blocks and not blocks.is_conditional() and blocks.get_value():
            blocking_tiles.append(ti)

func clear_all_at(tile_position) -> void:
    for l in layers:
        l.set_cell_s(tile_position, -1)

func replace_tiles_in_rect(rect: Rect2, new_tile, checker_tile=false):
    for x in range(rect.position.x, rect.end.x):
        for y in range(rect.position.y, rect.end.y):
            var ti = new_tile
            if checker_tile and (x + y) % 2 == 1:
                ti = checker_tile
            replace_tiles_at(Vector2(x, y), ti)

func replace_tiles_at_array(position_list, new_tile):
    for pos in position_list:
        replace_tiles_at(pos, new_tile)

func is_pos_out_of_bounds(tile_position) -> bool:
    return Utility.position_in_rect_inclusive(tile_position, get_map_size())

func replace_tiles_at(tile_position, new_tile, facing: int = 0) -> void:
    var old_bounds = get_map_size()
    clear_all_at(tile_position)
    if new_tile != -1:
        layers[0].set_cell_s(tile_position, new_tile, facing)
    
    if new_tile == -1:
        if get_map_size() != old_bounds:
            emit_signal("level_size_changed")
    elif is_pos_out_of_bounds(tile_position):
        emit_signal("level_size_changed")

func get_tile_definition(tile_index):
    return tile_defs[tile_index].duplicate(true)

func is_tile_at(tile_index, tile_position) -> bool:
    var found = false
    for l in layers:
        if l.get_cell_s(tile_position) == tile_index:
            found = true
    return found

func tile_exists_at(tile_position) -> bool:
    for l in layers:
        if l.get_cell_s(tile_position) != -1:
            return true
    return false

func update_tile_definition(tile_index, definition) -> void:
    if not tile_index in tile_defs:
        print("ERROR tried to update non-existing tile: " + str(tile_index))
        return
    tile_defs[tile_index] = definition
    update_index_map()

func make_new_tile(definition) -> int:
    var new_index = max_tile_index() + 1
    tile_defs[new_index] = definition
    update_index_map()
    return new_index

func max_tile_index() -> int:
    var max_index = 0
    for t in tile_defs.keys():
        max_index = maxi(max_index, t)
    return max_index

func add_new_tile_definition(definition) -> int:
    var index = 0
    while index in tile_defs:
        index += 1
    tile_defs[index] = definition
    return index

func remove_tile_definition(tile_index) -> void:
    tile_defs.erase(tile_index)
    refresh_definition()

func check_multiple_pos_for_property_bool(tile_positions: Array, entity_asking: BaseEntity, property_name: String, check_for: bool, is_all: bool = false) -> bool:
    for pos in tile_positions:
        var pass_check: = Property.resolve_truthy(get_tile_property_at(pos, property_name), null, entity_asking, pos) == check_for
        if not is_all and pass_check:
            return true
        if is_all and not pass_check:
            return false
    # If all, then yes all passed, if any, then no, none passed
    return is_all

func compare_multiple_pos_prop_value(tile_positions: Array, entity_asking: BaseEntity, property_name: String, comparison: String, compare_to: float, is_all: bool = false) -> bool:
    for pos in tile_positions:
        var prop: Property = get_tile_property_at(pos, property_name)
        if not prop:
            if is_all:
                return false
            continue
        var compare_result: = Utility.check_comparison(prop.get_or_resolve(null, entity_asking, pos), compare_to, comparison)
        if not is_all and compare_result:
            return true
        if is_all and not compare_result:
            return false
    # If all, then yes all passed, if any, then no, none passed
    return is_all

func get_tile_property_at(tile_position: Vector2i, property_name: String) -> Property:
    var tile_indices: Array[int] = []
    for l in layers:
        var ti = l.get_cell_s(tile_position)
        if ti != -1 and ti not in tile_indices:
            tile_indices.append(ti)

    var check_positioned_props: = has_positioned_property_at(tile_position)
    for ti in tile_indices:
        var tprop: Property
        if check_positioned_props:
            tprop = get_tile_property_for_index_at(tile_position, property_name, ti)
        else:
            tprop = get_tile_index_property(ti, property_name)
        if tprop != null:
            return tprop
    return null

func get_tile_property_for_index_at(tile_position: Vector2i, property_name: String, for_index: int) -> Property:
    var pos_prop: = get_positioned_property_at(tile_position, for_index)
    if pos_prop and pos_prop["local_properties"].has(property_name):
        var prop: Property = Property.new()
        prop.set_value(pos_prop["local_properties"][property_name])
        prop.set_name(property_name)
        return prop
    return get_tile_index_property(for_index, property_name)

func get_tile_index_property(tile_index, property_name) -> Property:
    var props = tile_defs[tile_index]["properties"]
    if not property_name in props:
        return null
    var property = Property.new()
    property.set_value(props[property_name])
    property.set_name(property_name)
    return property


func tile_index_has_property(tile_index: int, property_name: String) -> bool:
    var tile_index_props: Dictionary = tile_defs[tile_index]["properties"]
    return property_name in tile_index_props

func any_pos_has_property(tile_positions: Array, property_name: String) -> bool:
    for pos in tile_positions:
        for layer in layers:
            var ti = layer.get_cell_s(pos)
            if ti == -1:
                continue
            if tile_index_has_property(ti, property_name):
                return true
    for pos in tile_positions:
        for layer in layers:
            var ti = layer.get_cell_s(pos)
            if ti == -1:
                continue
            var pos_prop: = get_positioned_property_at(pos, ti)
            if pos_prop and pos_prop["local_properties"].has(property_name):
                return true
    return false

func remove_tile_property_multiple(tile_positions: Array, property_name: String, for_index: int = -1) -> void:
    for pos in tile_positions:
        remove_tile_property_for_all_tiles_at(pos, property_name, for_index)

func remove_tile_property_for_all_tiles_at(at_pos: Vector2i, property_name: String, for_index: int = -1) -> void:
    for layer in layers:
        var ti = layer.get_cell_s(at_pos)
        if ti != -1 and (for_index == -1 or ti == for_index):
            remove_positioned_prop_value(at_pos, ti, property_name)

func set_tile_property_at_multiple(tile_positions: Array, property_name: String, value: Variant, for_index: int = -1) -> void:
    for pos in tile_positions:
        set_tile_property_for_all_tiles_at(pos, property_name, value, for_index)

func set_tile_property_for_all_tiles_at(at_pos: Vector2i, property_name: String, value: Variant, for_index: int = -1) -> void:
    for layer in layers:
        var ti = layer.get_cell_s(at_pos)
        if ti != -1 and (for_index == -1 or ti == for_index):
            set_positioned_prop_value(at_pos, ti, property_name, value)

func set_tile_property_for_tile_at(at_pos: Vector2i, for_tile_index: int, property_name: String, value: Variant) -> void:
    if not is_tile_index_at(at_pos, for_tile_index):
        return
    set_positioned_prop_value(at_pos, for_tile_index, property_name, value)
    

func is_tile_index_at(tile_position, tile_index: int) -> bool:
    for l in layers:
        if l.get_cell_s(tile_position) == tile_index:
            return true
    return false

func get_tile_index_at(tile_position) -> int:
    var tile_index = -1
    for l in layers:
        var ti = l.get_cell_s(tile_position)
        if ti != -1:
            tile_index = ti
    return tile_index

#func set_tile_property(tile_index, property_name, value) -> void:
    #var props = tile_defs[tile_index]["properties"]
    #props[property_name] = value

func can_move_to(entity, tile_position) -> bool:
    if not EntityManager.can_move_to(entity, tile_position):
        return false
    
    return check_blocks(entity, tile_position)
    
func check_blocks(entity, tile_position) -> bool:
    for layer in layers:
        var tile_here = layer.get_cell_s(tile_position)
        if tile_here == -1 or tile_here in blocking_tiles:
            return false
        var blocks_conditional: = get_tile_index_property(tile_here, "blocks")
        if blocks_conditional and blocks_conditional.is_conditional():
            var result = blocks_conditional.resolve(null, entity, tile_position)
            if result:
                return false
    return true

func get_tile_facing_at(tile_position: Vector2i) -> int:
    for l in layers:
        if l.get_cell_s(tile_position) != -1:
            return l.get_cell_facing(tile_position)
    return 0

func set_tile_facing_at(tile_position: Vector2i, facing: int) -> void:
    for l in layers:
        if l.get_cell_s(tile_position) != -1:
            l.set_cell_facing(tile_position, facing)

func finish_move(moving_entity, onto_positions: Array) -> void:
    EntityManager.finish_move(moving_entity, onto_positions)
    
    var ifmot: = EntityManager.get_entity_property(moving_entity, "i_finish_move_onto_tile")
    if ifmot and ifmot.is_conditional():
        for onto_position in onto_positions:
            ifmot.resolve(moving_entity, null, onto_position)
    
    resolve_tile_event(onto_positions, "finish_move_onto_tile", moving_entity)

# Resolve tile event for every tile index that exists at all locations provided
# (Only once per index-position pair)
func resolve_tile_event(at_tile_positions: Array, tile_event_name: String, context_entity) -> void:
    for at_pos in at_tile_positions:
        var resolved_indices: Array[int] = []
        for l in layers:
            var ti = l.get_cell_s(at_pos)
            if ti in resolved_indices:
                continue
            resolved_indices.append(ti)
            var event_property: = get_tile_property_for_index_at(at_pos, tile_event_name, ti)
            if event_property and event_property.is_conditional():
                event_property.resolve(null, context_entity, at_pos)

func attempt_move(moving_entity, tile_position, group_move=false) -> bool:
    var entity_move_allow = EntityManager.attempt_move(moving_entity, tile_position, group_move)
    
    var tile_move_allow = check_blocks(moving_entity, tile_position)
    return tile_move_allow and entity_move_allow

func is_blocked(tile_position, empty_blocks: bool = true) -> bool:
    if empty_blocks and not tile_exists_at(tile_position):
        return false
    for layer in layers:
        if layer.get_cell_s(tile_position) in blocking_tiles:
            return true
    return false

func world_to_tile_position(world_position) -> Vector2:
    return Vector2(floor(world_position.x / tile_width), floor(world_position.y / tile_width))

func tile_to_world_position(tile_position) -> Vector2:
    return Vector2(tile_position.x * tile_width, tile_position.y * tile_width)
func tile_to_world_position_centered(tile_position) -> Vector2:
    return (tile_position + Vector2(0.5, 0.5)) * tile_width

func get_used_positions_in_all_layers() -> Array[Vector2i]:
    var used_positions: Array[Vector2i] = []
    for l in layers:
        for pos in l.get_used_cells():
            if not pos in used_positions:
                used_positions.append(pos)
    return used_positions

func get_all_tile_names() -> Array[String]:
    var names: Array[String] = []
    for t in tile_defs.values():
        var t_name: String = t["name"]
        if not t_name in names:
            names.append(t_name)
    return names