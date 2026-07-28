extends Node

const MapLayer = preload("res://src/MapLayer.gd")

const MiniTextMessage = preload("res://Scenes/GameEditor/Effects/mini_text_message.gd")

const EditIntermissionAssignments = preload("res://Scenes/Intermission/edit_intermission_assignments.gd")
const IntermissionEvents = EditIntermissionAssignments.Events

signal level_size_changed
signal map_cleared

var map_layer_template: = preload("res://Scenes/MapLayer.tscn")

var layers: Array = []
var map_metadata: = {}

var blocking_tiles: = []
var tiles_with_sprite_modifiers: = []

var is_empty_blocking: = true

var tile_width: int = 32

var tile_defs: = {}
@onready var loaded_tile_defs: = tile_defs

var tile_index_map: = {}

var is_tile_preview_mode: = false

var tileset: TileSet = null
var preview_tileset: TileSet = null

var im_ready: = false

var _positioned_props_set: Array[String] = []
var _tile_ids_of_positioned_props: Dictionary[String, Array] = {}

var _check_moving_away: = false

func setup() -> void:
    fix_string_keys()
    if not TextureManager.im_ready:
        await TextureManager.textures_loaded
    create_tileset()
    find_blocking()
    find_tiles_with_sprite_modifiers()
    
    im_ready = true

func refresh_definition():
    fix_string_keys()
    create_tileset()
    find_blocking()
    find_tiles_with_sprite_modifiers()
    update_should_check_moving_away()
    update_index_map()

func update_should_check_moving_away() -> void:
    _check_moving_away = false
    for tile_id in tile_defs.keys():
        var tile_properties: Dictionary = tile_defs[tile_id].get("properties", {})
        if tile_properties.has("move_away_from"):
            _check_moving_away = true
            break

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
        if "preview_variant" in tile_defs[intk]:
            if "texture" in tile_defs[intk]["preview_variant"]:
                tile_defs[intk]["preview_variant"]["texture"] = int(tile_defs[intk]["preview_variant"]["texture"])
            if "tex_index" in tile_defs[intk]["preview_variant"]:
                tile_defs[intk]["preview_variant"]["tex_index"] = int(tile_defs[intk]["preview_variant"]["tex_index"])

func clear():
    clear_layers()
    map_metadata = {}
    map_cleared.emit()

func clear_layers():
    for l in layers:
        if is_instance_valid(l):
            l.queue_free()
    layers = []

func create_random_layer():
    create_plain_layer()
    layers[0].random_init()

func create_plain_layer():
    clear_layers()
    var map_layer = create_empty_layer()
    if tile_defs.size() > 0:
        var floor_tile_index = _get_tile_id_from_partial_name_insensitive("floor")
        if floor_tile_index == -1:
            floor_tile_index = tile_defs.keys()[0]
        map_layer.single_init(floor_tile_index)
    
    level_size_changed.emit()

func _get_tile_id_from_partial_name_insensitive(partial_name: String) -> int:
    partial_name = partial_name.to_lower()
    for tile_id in tile_defs.keys():
        if tile_defs[tile_id]["name"].to_lower().contains(partial_name):
            return tile_id
    return -1

func _get_museum_tile_ids() -> Array[int]:
    var tile_ids: Array[int] = []
    for tile_id in tile_defs.keys():
        if tile_defs[tile_id].get("no-museum", false):
            continue
        tile_ids.append(tile_id)
    return tile_ids

func create_museum_layer(player_pos: Vector2i, tile_start: Vector2i, tile_spacing: Vector2i, other_floor_rects: Array[Rect2i]):
    clear_layers()
    create_empty_layer()
    if tile_defs.size() < 0:
        return
    var floor_id: = _get_tile_id_from_partial_name_insensitive("floor")
    if floor_id == -1:
        floor_id = tile_defs.keys()[0]
    var outer_walk_space: int = 3
    
    _fill_expanded_rect(floor_id, Rect2i(player_pos, Vector2i.ONE), outer_walk_space)
    for other_rect in other_floor_rects:
        if other_rect.size != Vector2i.ZERO:
            _fill_expanded_rect(floor_id, other_rect, outer_walk_space)
    
    var full_tile_museum_rect: = _place_tile_museum(tile_start, tile_spacing, floor_id, outer_walk_space)
    var reversed_pos: = Vector2i(-tile_start.x, tile_start.y - (4 * signi(tile_spacing.y)))
    var reversed_rect: = Rect2i(reversed_pos, full_tile_museum_rect.size)
    if tile_spacing.x > 0:
        reversed_rect.size.x *= -1
    if tile_spacing.y > 0:
        reversed_rect.size.y *= -1
    _place_tile_museum(reversed_rect.end + tile_spacing.sign(), tile_spacing, floor_id, outer_walk_space)
    
    level_size_changed.emit()

func _place_tile_museum(museum_start: Vector2i, museum_spacing: Vector2i, floor_id: int, outer_walk_space: int) -> Rect2i:
    if museum_spacing.x == 0: museum_spacing.x = 1
    if museum_spacing.y == 0: museum_spacing.y = 1

    var rows: int = 4
    var default_row_width: int = 5
    
    var tile_ids: = _get_museum_tile_ids()
    var num_tiles: int = tile_ids.size()
    rows = mini(rows, ceili(num_tiles / float(default_row_width)))
    var per_row: int = ceili(num_tiles / float(rows))
    
    var museum_size: = museum_spacing.sign() + Vector2i(per_row - 1, rows - 1) * museum_spacing
    var full_museum_rect: = Utility.rect2i_pos_inclusive_abs(Rect2i(museum_start, museum_size))
    _fill_expanded_rect(floor_id, full_museum_rect, outer_walk_space)
    
    var label_offset: = Vector2.UP * tile_width * 0.25

    for i in num_tiles:
        var tile_id = tile_ids[i]
        var row_col: = Vector2i(i % per_row, floori(i / float(per_row)))
        var at_tile_pos: = museum_start + row_col * museum_spacing
        layers[0].set_cell_s(at_tile_pos, tile_id)
        # Labels
        var tile_name: = get_tile_name(tile_id)
        create_persistant_text_effect(tile_name, at_tile_pos + Vector2i.DOWN, label_offset, -2)
    return full_museum_rect

func _fill_expanded_rect(tile_id: int, rect: Rect2i, expanded_by: int):
    _fill_rect(tile_id, rect.grow(expanded_by))

func _fill_rect(tile_id: int, rect: Rect2i):
    for pos in Utility.rect2i_iter(rect):
        layers[0].set_cell_s(pos, tile_id)

func current_tileset() -> TileSet:
    return preview_tileset if is_tile_preview_mode else tileset

func create_empty_layer():
    var map_layer = map_layer_template.instantiate() as MapLayer
    var ents = Utility.get_world().get_node("Entities")

    var is_y_sort_tiles: bool = GameManager.get_game_setting("y_sort_tiles", false)
    map_layer.y_sort_enabled = is_y_sort_tiles

    ents.add_sibling.bind(map_layer, true).call_deferred()
    map_layer.tile_set = current_tileset()
    layers.append(map_layer)
    return map_layer

func create_tileset():
    var new_tileset: = TileSet.new()
    var new_preview_tileset: = TileSet.new()
    new_tileset.tile_size = Vector2i.ONE * tile_width
    new_preview_tileset.tile_size = Vector2i.ONE * tile_width
    tile_index_map = {}
    
    for tile_index in tile_defs:
        var tile_info = tile_defs[tile_index]
        var tile_preview_info: Dictionary = tile_info.get("preview_variant", {})
        if not tile_preview_info:
            tile_preview_info = tile_info
        var atlas_source: = TileSetAtlasSource.new()
        var preview_atlas_source: = TileSetAtlasSource.new()
        atlas_source.texture = TextureManager.get_texture(tile_info['texture'])
        preview_atlas_source.texture = TextureManager.get_texture(tile_preview_info['texture'])
        new_tileset.add_source(atlas_source, tile_index)
        new_preview_tileset.add_source(preview_atlas_source, tile_index)
        
        if tile_info['name'] in tile_index_map:
            print_debug("WARNING: tile name already in use: " + tile_info['name'])
        tile_index_map[tile_info['name']] = tile_index
        
        var tile_native_size = TextureManager.get_texture_tile_size(tile_info['texture'])
        var preview_tile_native_size = TextureManager.get_texture_tile_size(tile_preview_info['texture'])
        atlas_source.texture_region_size = tile_native_size
        preview_atlas_source.texture_region_size = preview_tile_native_size
        var atlas_coords: = TextureManager.get_index_atlas_coords(tile_info['texture'], tile_info['tex_index'])
        var preview_atlas_coords: = TextureManager.get_index_atlas_coords(tile_preview_info['texture'], tile_preview_info['tex_index'])
        atlas_source.create_tile(atlas_coords)
        preview_atlas_source.create_tile(preview_atlas_coords)
        
        if "z-index" in tile_info['properties']:
            var tile_z_index = int(tile_info['properties']['z-index'])
            var tile_data: = atlas_source.get_tile_data(atlas_coords, 0)
            tile_data.z_index = tile_z_index
            var preview_tile_data: = preview_atlas_source.get_tile_data(preview_atlas_coords, 0)
            preview_tile_data.z_index = tile_z_index
            
    tileset = new_tileset
    preview_tileset = new_preview_tileset

func update_index_map() -> void:
    tile_index_map = {}
    for tile_index in tile_defs:
        var tname = tile_defs[tile_index]['name']
        if tname in tile_index_map:
            push_warning("WARNING: tile name already in use: " + tname)
        tile_index_map[tname] = tile_index

func get_tile_texture(tile_index, preview: bool = false) -> Texture2D:
    var tex_from: Dictionary = tile_defs[tile_index]
    if preview and tex_from.get("preview_variant", {}):
        tex_from = tex_from["preview_variant"]
    return TextureManager.get_texture(tex_from['texture'])
func get_tile_texture_rect(tile_index, preview: bool = false) -> Rect2:
    var tex_from: Dictionary = tile_defs[tile_index]
    if preview and tex_from.get("preview_variant", {}):
        tex_from = tex_from["preview_variant"]
    return TextureManager.get_index_rect(tex_from['texture'], tex_from['tex_index'])

func get_tile_atlas_coords(tile_index, preview: bool = false) -> Vector2i:
    var tex_from: Dictionary = tile_defs[tile_index]
    if preview and tex_from.get("preview_variant", {}):
        tex_from = tex_from["preview_variant"]
    return TextureManager.get_index_atlas_coords(tex_from['texture'], tex_from['tex_index'])

func create_persistant_text_effect(effect_text: String, at_tile_pos: Vector2i, pos_offset: Vector2 = Vector2.ZERO, z_offset: int = 0) -> int:
    return _create_persistant_effect_info({
        "effect_type": "text",
        "tile_pos": Utility.get_arr_from_vector2i(at_tile_pos),
        "text": effect_text,
        "pos_offset": Utility.get_arr_from_vector2(pos_offset),
        "z_offset": z_offset,
    })

func create_persistant_text_effect_from_info(at_tile_pos: Vector2i, effect_info: Dictionary) -> int:
    var outline_color: Color = effect_info.get("outline_color", Color.BLACK)
    var translated_effect_info: Dictionary = {
        "effect_type": "text",
        "text": effect_info.get("text", ""),
        "size": effect_info.get("font_size", 9.0),
        "tile_pos": Utility.get_arr_from_vector2i(at_tile_pos),
        "z_offset": effect_info.get("z_offset", 0),
        "color": effect_info.get("fill_color", Color.WHITE),
        "h_align": effect_info.get("h_align", HORIZONTAL_ALIGNMENT_CENTER),
        "pos_offset": Utility.get_arr_from_vector2(effect_info.get("pos_offset", Vector2.ZERO)),
        "outline_color": Utility.color_string(outline_color),
        "outline_enabled": outline_color.a > 0.0,
    }
    return _create_persistant_effect_info(translated_effect_info)

func edit_persistant_text_size(effect_id: int, new_size: int) -> void:
    var effect_info: = _find_persistant_effect_by_id(effect_id)
    if not effect_info:
        push_error("Could not find effect with id: " + str(effect_id))
        return
    effect_info["size"] = new_size
    var effect_node: = EffectsHelper.get_effect_node_by_id(effect_id) as MiniTextMessage
    if effect_node:
        effect_node.set_font_size(new_size)

func edit_persistant_text_colors(effect_id: int, new_color: Color, change_outline: bool = false, outline_enabled: bool = true, outline_color: Color = Color.BLACK) -> void:
    var effect_info: = _find_persistant_effect_by_id(effect_id)
    if not effect_info:
        push_error("Could not find effect with id: " + str(effect_id))
        return
    effect_info["color"] = Utility.color_string(new_color)
    if change_outline:
        effect_info["outline_enabled"] = outline_enabled
        effect_info["outline_color"] = Utility.color_string(outline_color)
    var effect_node: = EffectsHelper.get_effect_node_by_id(effect_id) as MiniTextMessage
    if not effect_node:
        push_error("Could not find effect node with id: " + str(effect_id))
        return

    effect_node.set_color(new_color)
    if change_outline:
        effect_node.set_outline_color(outline_color)
        effect_node.set_outline_enabled(outline_enabled)

func edit_persistant_text_layout_mode(effect_id: int, new_horizontal_alignment: HorizontalAlignment) -> void:
    var effect_info: = _find_persistant_effect_by_id(effect_id)
    if not effect_info:
        push_error("Could not find effect with id: " + str(effect_id))
        return
    effect_info["h_align"] = new_horizontal_alignment
    var effect_node: = EffectsHelper.get_effect_node_by_id(effect_id) as MiniTextMessage
    if effect_node:
        effect_node.set_layout_mode(new_horizontal_alignment)

func _find_persistant_effect_by_id(effect_id: int) -> Dictionary:
    for k in map_metadata.get("persistant_effects", {}).keys():
        for effect_info in map_metadata["persistant_effects"][k]:
            if effect_info.get("effect_id", -1) == effect_id:
                return effect_info
    return {}

func _create_persistant_effect_info(effect_info: Dictionary) -> int:
    var effect_type: String = effect_info.get("effect_type", "")
    if not effect_type:
        push_error("Can't create effect with no type")
        return -1

    var effect_id: int = -1
    if effect_type == "text":
        effect_id = _create_persistant_text_effect(effect_info)
    else:
        push_error("Unknown effect type: " + effect_type)
    
    if effect_id < 0:
        return -1
    _register_persistant_effect(effect_info)
    return effect_id

func _create_persistant_text_effect(effect_info: Dictionary) -> int:
    var effect_id: int = effect_info.get("effect_id", -1)
    var tile_pos: Vector2i = Utility.get_vector2i_from_arr(effect_info["tile_pos"])
    var pos_offset: Vector2 = Utility.get_vector2_from_arr(effect_info["pos_offset"])
    var effect_world_pos: Vector2 = tile_to_world_position_centered(tile_pos) + pos_offset
    var z: = int(effect_info.get("z_offset", 0))
    effect_info["effect_id"] = EffectsHelper.spawn_mini_text_at(effect_info["text"], effect_world_pos, 0, z, effect_id)

    var effect_node: = EffectsHelper.get_effect_node_by_id(effect_info["effect_id"]) as MiniTextMessage
    if effect_info.has("h_align"):
        effect_node.set_layout_mode(effect_info["h_align"])
    if effect_info.has("size"):
        effect_node.set_font_size(effect_info["size"])
    if effect_info.has("color"):
        effect_node.set_color(Utility.get_dict_color(effect_info, "color", Color.WHITE))
    if effect_info.has("outline_enabled"):
        effect_node.set_outline_enabled(effect_info["outline_enabled"])
    if effect_info.has("outline_color"):
        effect_node.set_outline_color(Utility.get_dict_color(effect_info, "outline_color", Color.BLACK))

    return effect_info["effect_id"]

func _register_persistant_effect_at(at_tile_pos: Vector2i, effect_info: Dictionary) -> void:
    effect_info["tile_pos"] = Utility.get_arr_from_vector2i(at_tile_pos)
    _register_persistant_effect(effect_info)

func _register_persistant_effect(effect_info: Dictionary) -> void:
    if not effect_info.has("tile_pos"):
        push_error("Can't register persistant effect with no tile position")
        return
    var key: = Utility.vec2i_key(Utility.get_vector2i_from_arr(effect_info["tile_pos"]))
    if not map_metadata.has("persistant_effects"):
        map_metadata["persistant_effects"] = {}
    if not map_metadata["persistant_effects"].has(key):
        map_metadata["persistant_effects"][key] = []
    map_metadata["persistant_effects"][key].append(effect_info.duplicate_deep())

func _remove_effects_at(at_tile_pos: Vector2i, _is_editor: bool = false) -> void:
    var key: = Utility.vec2i_key(at_tile_pos)
    if not map_metadata.get("persistant_effects", {}).has(key):
        return
    for effect_info in map_metadata["persistant_effects"][key]:
        if effect_info.has("effect_id"):
            EffectsHelper.remove_effect_by_id(effect_info["effect_id"])
    map_metadata["persistant_effects"].erase(key)

func serialize() -> Dictionary:
    var serialized_layers = []
    for l in layers:
        serialized_layers.append(l.serialize())

    var serialized_stuff = {"layers": serialized_layers, "metadata": map_metadata.duplicate(true)}
    return serialized_stuff

func deserialize(data: Dictionary) -> void:
    clear()
    
    for layer_data in data["layers"]:
        var new_layer = create_empty_layer()
        new_layer.deserialize(layer_data)
    
    map_metadata = data.get("metadata", {}).duplicate(true)
    
    recreate_persistant_effects()
    _rebuild_position_prop_cache()
    
    level_size_changed.emit()

func recreate_persistant_effects() -> void:
    if not map_metadata.has("persistant_effects"):
        return
    var old_effects: Dictionary = map_metadata["persistant_effects"].duplicate_deep()
    map_metadata["persistant_effects"] = {}
    for effect_pos_key in old_effects.keys():
        for i in old_effects[effect_pos_key].size():
            _create_persistant_effect_info(old_effects[effect_pos_key][i])

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
    _cache_added_positioned_prop(property_name, for_tile_index)
    pos_prop["local_properties"][property_name] = value

func get_positioned_prop_value(at_pos: Vector2i, for_tile_index: int, property_name: String) -> Variant:
    var pos_prop: = get_positioned_property_at(at_pos, for_tile_index)
    if not pos_prop or not pos_prop["local_properties"].has(property_name):
        return null
    return pos_prop["local_properties"][property_name]

func remove_positioned_prop_value(at_pos: Vector2i, for_tile_index: int, property_name: String, and_revalidate: bool = false) -> void:
    var pos_prop: = get_positioned_property_at(at_pos, for_tile_index)
    if not pos_prop or not pos_prop["local_properties"].has(property_name):
        return
    pos_prop["local_properties"].erase(property_name)
    if and_revalidate:
        _revalidate_cached_positioned_prop(property_name)

func _cache_added_positioned_prop(property_name: String, for_tile_index: int) -> void:
    if not property_name in _positioned_props_set:
        _positioned_props_set.append(property_name)
        _tile_ids_of_positioned_props[property_name] = [for_tile_index]
    else:
        Utility.arr_add_if_not_included(_tile_ids_of_positioned_props[property_name], for_tile_index)

func _revalidate_cached_positioned_prop(property_name: String) -> void:
    var is_set_for: Array[int] = []
    var pos_props: Dictionary = map_metadata.get("positioned_properties", {})
    for positioned_prop_pos in pos_props.keys():
        var local_prop_layers: Dictionary = pos_props[positioned_prop_pos]["layers"]
        for layer_idx in local_prop_layers.keys():
            if property_name in local_prop_layers[layer_idx]["local_properties"]:
                Utility.arr_add_if_not_included(is_set_for, local_prop_layers[layer_idx]["tile_index"])

    # No longer set locally anywhere
    if is_set_for.size() == 0:
        _positioned_props_set.erase(property_name)
        _tile_ids_of_positioned_props.erase(property_name)
        return
    
    # Add to new ids, remove from old
    if not property_name in _positioned_props_set:
        _positioned_props_set.append(property_name)
        _tile_ids_of_positioned_props[property_name] = []
        _tile_ids_of_positioned_props[property_name].append_array(is_set_for)
    else:
        for for_ti in is_set_for:
            Utility.arr_add_if_not_included(_tile_ids_of_positioned_props[property_name], for_ti)

func _revalidate_all_positioned_props(include_prop_names: Array[String] = []) -> void:
    include_prop_names = Utility.arr_set_union(_positioned_props_set, include_prop_names)
    for prop_name in include_prop_names:
        _revalidate_cached_positioned_prop(prop_name)

func _rebuild_position_prop_cache() -> void:
    _positioned_props_set = []
    _tile_ids_of_positioned_props = {}
    var pos_props: Dictionary = map_metadata.get("positioned_properties", {})
    for at_pos in pos_props.keys():
        for layer_local_props in pos_props[at_pos]["layers"].values():
            if layer_local_props["local_properties"].size() == 0:
                continue
            var ti: int = layer_local_props["tile_index"]
            for prop_name in layer_local_props["local_properties"].keys():
                if not prop_name in _positioned_props_set:
                    _positioned_props_set.append(prop_name)
                    _tile_ids_of_positioned_props[prop_name] = [ti]
                else:
                    Utility.arr_add_if_not_included(_tile_ids_of_positioned_props[prop_name], ti)

func is_prop_static(prop_name: String, only_for_tile_id: int = -1) -> bool:
    if len(_positioned_props_set) == 0:
        return true
    if prop_name not in _positioned_props_set:
        return true
    elif only_for_tile_id < 0:
        return false
    return only_for_tile_id not in _tile_ids_of_positioned_props[prop_name]
        

func has_next_level() -> bool:
    var next_level_name: = map_metadata.get("next_level", "") as String
    return next_level_name != "" and FilesManager.level_exists(GameManager.get_identified_game_name(), next_level_name)

func get_level_title() -> String:
    var title: = map_metadata.get("title", "") as String
    if not title:
        return GameManager.loaded_level_name
    return title

func has_level_subtitle() -> bool:
    return map_metadata.get("subtitle", "") != ""

func get_level_subtitle() -> String:
    if not has_level_subtitle():
        return ""
    return map_metadata.get("subtitle", "")

func set_level_subtitle(subtitle: String, update_edited_metadata: bool = true) -> void:
    map_metadata["subtitle"] = subtitle
    if update_edited_metadata:
        GameManager.update_edited_level_metadata_value("subtitle", subtitle)

func set_metadata_value(key: String, value: Variant, update_edited_metadata: bool = true) -> void:
    map_metadata[key] = value
    if update_edited_metadata:
        GameManager.update_edited_level_metadata_value(key, value)

func erase_metadata_value(key: String, update_edited_metadata: bool = true) -> void:
    map_metadata.erase(key)
    if update_edited_metadata:
        GameManager.erase_edited_level_metadata_value(key)

func has_metadata_value(key: String) -> bool:
    return map_metadata.has(key)
func get_metadata_value(key: String, default_value: Variant = null) -> Variant:
    return map_metadata.get(key, default_value)

func get_override_view_size() -> Vector2:
    var override_view_size_raw: Variant = get_metadata_value("override_view_size", [0., 0.])
    if typeof(override_view_size_raw) != TYPE_ARRAY:
        return Vector2.ZERO
    return Utility.get_vector2_from_arr(override_view_size_raw)
func set_override_view_size(override_view_size: Vector2, update_edited_metadata: bool = true) -> void:
    if override_view_size == Vector2.ZERO:
        erase_metadata_value("override_view_size")
    else:
        var converted: Array = Utility.get_arr_from_vector2(override_view_size)
        set_metadata_value("override_view_size", converted, update_edited_metadata)

func get_view_size_with_override() -> Vector2:
    var override_view_size: Vector2 = get_override_view_size()
    if override_view_size == Vector2.ZERO:
        return GameManager.get_window_size_setting()
    return override_view_size

func get_enable_camera_limits_with_override() -> bool:
    if has_metadata_value("override_enable_camera_limits"):
        return get_metadata_value("override_enable_camera_limits", false)
    return Utility.get_camera_setting("enable_limits", false)

func get_all_tile_indexes() -> Array:
    var keys = tile_defs.keys()
    #keys.sort()
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

func get_map_size() -> Rect2i:
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
    is_empty_blocking = GameManager.get_game_setting("empty_tiles_block", true)
    if tile_defs.size() < 1:
        is_empty_blocking = false
    blocking_tiles = []
    
    for ti in tile_defs:
        var blocks: = get_tile_index_property(ti, "blocks")
        if blocks and not blocks.is_conditional() and blocks.get_value():
            blocking_tiles.append(ti)

func find_tiles_with_sprite_modifiers() -> void:
    tiles_with_sprite_modifiers = []
    for ti in tile_defs:
        var spr_mod_prop: = get_tile_index_property(ti, "tile_sprite_modifier")
        if spr_mod_prop:
            if spr_mod_prop.is_conditional() or spr_mod_prop.get_value():
                tiles_with_sprite_modifiers.append(ti)

func clear_all_at(tile_position, _is_editor: bool = false) -> void:
    for l in layers:
        l.set_cell_s(tile_position, -1)

func erase_tiles_at_multiple(position_list: Array, _is_editor: bool = false) -> void:
    for pos in position_list:
        for l in layers:
            l.set_cell_s(pos, -1)

func replace_tiles_in_rect(rect: Rect2, new_tile, checker_tile=false):
    for x in range(rect.position.x, rect.end.x):
        for y in range(rect.position.y, rect.end.y):
            var ti = new_tile
            if checker_tile and (x + y) % 2 == 1:
                ti = checker_tile
            replace_tiles_at(Vector2(x, y), ti)

func replace_tiles_at_multiple(position_list: Array, new_tile: int, preserve_facing: bool = false, is_editor: bool = false):
    var facing_val: int = -1 if preserve_facing else 0
    for pos in position_list:
        replace_tiles_at(pos, new_tile, facing_val, is_editor)

func is_pos_out_of_bounds(tile_position, bounds: Rect2i = Rect2i()) -> bool:
    if bounds == Rect2i():
        bounds = get_map_size()
    return Utility.position_in_rect_inclusive(tile_position, bounds)

# facing -1 => preserve replaced tile's facing
func replace_tiles_at(tile_position: Vector2i, new_tile: int, facing: int = 0, is_editor_place: bool = false) -> void:
    var old_bounds = get_map_size()

    if facing == -1:
        facing = get_tile_facing_at(tile_position)
    clear_all_at(tile_position, is_editor_place)

    var size_changed: = false
    if new_tile != -1:
        size_changed = is_pos_out_of_bounds(tile_position, old_bounds)
        layers[0].set_cell_s(tile_position, new_tile, facing)
    else:
        size_changed = get_map_size() != old_bounds
    
    if size_changed:
        level_size_changed.emit()
    
    if is_editor_place:
        post_editor_placing_tile(tile_position, new_tile)
    else:
        post_non_editor_placing_tile(tile_position, new_tile)

func post_editor_placing_tile(tile_position: Vector2i, new_tile: int) -> void:
    if new_tile == -1:
        return
    resolve_tile_individual_events([tile_position], "editor_placing", null, new_tile)

func post_non_editor_placing_tile(tile_position: Vector2i, new_tile: int) -> void:
    if new_tile == -1:
        return
    resolve_tile_individual_events([tile_position], "placing_tile", null, new_tile)

func erase_tiles_and_effects_at(tile_position: Vector2i, is_editor: bool = false) -> void:
    clear_all_at(tile_position, is_editor)
    _remove_effects_at(tile_position, is_editor)

func erase_tiles_and_effects_at_multiple(position_list: Array, is_editor: bool = false) -> void:
    erase_tiles_at_multiple(position_list, is_editor)
    for pos in position_list:
        _remove_effects_at(pos, is_editor)

func erase_effects_at_multiple(position_list: Array, _is_editor: bool = false) -> void:
    for pos in position_list:
        _remove_effects_at(pos, _is_editor)

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

func update_tile_definition(tile_id: int, definition: Dictionary) -> void:
    if not tile_id in tile_defs:
        push_error("ERROR tried to update non-existing tile: " + str(tile_id))
        return
    tile_defs[tile_id] = definition.duplicate_deep()
    refresh_definition()

func update_tile_def_properties(tile_id: int, properties: Dictionary) -> void:
    if not tile_id in tile_defs:
        push_error("ERROR tried to update properties of non-existing tile: " + str(tile_id))
        return
    tile_defs[tile_id]["properties"] = properties.duplicate_deep()
    refresh_definition()

func make_new_tile(new_tile_definition: Dictionary) -> int:
    new_tile_definition = clean_for_existing_assets(new_tile_definition)
    var new_id: = max_tile_index() + 1
    tile_defs[new_id] = new_tile_definition
    refresh_definition()
    return new_id

func _clean_dict_texture_id_for_existing_assets(incoming_dict: Dictionary) -> void:
    if not incoming_dict.has("texture"):
        return
    var texture_id: = int(incoming_dict["texture"])
    if not TextureManager.has_loaded_texture_id(texture_id):
        incoming_dict["texture"] = TextureManager.get_fallback_texture_id()
        incoming_dict["tex_index"] = 0
    else:
        var max_index: = TextureManager.get_max_texture_index(texture_id)
        incoming_dict["tex_index"] = mini(max_index, int(incoming_dict.get("tex_index", 0)))

func clean_for_existing_assets(incoming_definition: Dictionary) -> Dictionary:
    _clean_dict_texture_id_for_existing_assets(incoming_definition)
    if incoming_definition.has("preview_variant"):
        _clean_dict_texture_id_for_existing_assets(incoming_definition["preview_variant"])
    return incoming_definition

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

func get_tile_prop_text_value_at(tile_positions: Array, property_name: String, default_value: String = "") -> String:
    var prop_info: Dictionary = get_first_located_tile_property(tile_positions, property_name)
    if not prop_info:
        return default_value
    var prop_value: Variant = prop_info["prop"].get_or_resolve(null, null, prop_info["pos"])
    return Utility.property_value_nonempty_string(prop_value, default_value)

func get_tile_prop_scalar_value_at(tile_positions: Array, property_name: String, default_value: float = 0.0) -> float:
    var prop_info: Dictionary = get_first_located_tile_property(tile_positions, property_name)
    if not prop_info:
        return default_value
    var prop_value: Variant = prop_info["prop"].get_or_resolve(null, null, prop_info["pos"])
    return Utility.property_value_scalar(prop_value, default_value)

func get_first_located_tile_property(tile_positions: Array, property_name: String) -> Dictionary:
    for pos in tile_positions:
        var prop: Property = get_tile_property_at(pos, property_name)
        if prop:
            return {"pos": pos, "prop": prop}
    return {}

func get_tile_property_for_index_at(tile_position: Vector2i, property_name: String, for_index: int, local_only: bool = false) -> Property:
    var pos_prop: = get_positioned_property_at(tile_position, for_index)
    if pos_prop and pos_prop["local_properties"].has(property_name):
        var prop: Property = Property.new()
        prop.set_value(pos_prop["local_properties"][property_name])
        prop.set_name(property_name)
        return prop
    elif local_only:
        return null
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
    _revalidate_cached_positioned_prop(property_name)

func remove_tile_property_for_all_tiles_at(at_pos: Vector2i, property_name: String, for_index: int = -1) -> void:
    for layer in layers:
        var ti = layer.get_cell_s(at_pos)
        if ti != -1 and (for_index == -1 or ti == for_index):
            remove_positioned_prop_value(at_pos, ti, property_name)
    _revalidate_cached_positioned_prop(property_name)

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

func is_empty_blocking_at(tile_position: Vector2i) -> bool:
    if not is_empty_blocking:
        return false
    for l in layers:
        if l.get_cell_s(tile_position) != -1:
            return false
    return true

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
    
    return check_blocks_allow_move(entity, [tile_position])

func can_move_to_multiple(entity: BaseEntity, tile_positions: Array[Vector2i], change_facing_to: int = -1) -> bool:
    if not EntityManager.can_move_to_multiple(entity, tile_positions, change_facing_to):
        return false
    
    return check_blocks_allow_move(entity, tile_positions, change_facing_to)
    
func check_blocks_allow_move(entity: BaseEntity, tile_positions: Array[Vector2i], change_facing_to: int = -1) -> bool:
    var tile_ids_here: Array[int] = []
    for layer in layers:
        for pos in tile_positions:
            Utility.arr_add_if_not_included(tile_ids_here, layer.get_cell_s(pos))
    
    var old_facing: int = entity.facing
    if change_facing_to >= 0:
        entity.set_facing_only(change_facing_to)
    
    # For now we run all conditionals even if blocked already, no shortcuts, should be configurable later
    var result: = true
    for tile_id in tile_ids_here:
        if (tile_id == -1 and is_empty_blocking) or (tile_id in blocking_tiles):
            result = false
            continue
        # Run conditional on all pos where tile id exists, any true result is a block
        if conditional_tile_event(tile_positions, "blocks", entity, false, tile_id):
            result = false
    entity.set_facing_only(old_facing)
    return result

func get_tile_facing_at(tile_position: Vector2i) -> int:
    for l in layers:
        if l.get_cell_s(tile_position) != -1:
            return l.get_cell_facing(tile_position)
    return 0

func set_tile_facing_at(tile_position: Vector2i, facing: int) -> void:
    for l in layers:
        if l.get_cell_s(tile_position) != -1:
            l.set_cell_facing(tile_position, facing)

func finish_move(moving_entity: BaseEntity, onto_positions: Array) -> void:
    EntityManager.finish_move(moving_entity, onto_positions)
    
    if not moving_entity.active:
        return
    
    var ifmot: = EntityManager.get_entity_property(moving_entity, "i_finish_move_onto_tile")
    if ifmot and ifmot.is_conditional():
        ifmot.resolve(moving_entity, null, onto_positions)

    if not moving_entity.active:
        return
    
    resolve_tile_individual_events(onto_positions, "finish_move_onto_tile", moving_entity)

    if not moving_entity.active:
        return
    
    var adjacent_positions: Array[Vector2i] = []
    for pos in onto_positions:
        for adj_pos in Utility.get_adjacent_positions(pos):
            if adj_pos not in onto_positions and adj_pos not in adjacent_positions:
                adjacent_positions.append(adj_pos)
    
    var ifmntt: = EntityManager.get_entity_property(moving_entity, "i_finish_move_next_to_tile")
    if ifmntt and ifmntt.is_conditional():
        for pos in adjacent_positions:
            ifmntt.resolve(moving_entity, null, [pos])
    if not moving_entity.active:
        return
    
    resolve_tile_individual_events(adjacent_positions, "finish_move_next_to", moving_entity)
    
    if not moving_entity.active:
        return
    
    check_and_apply_terrain_sprite_modifier(moving_entity, onto_positions)


func check_and_apply_terrain_sprite_modifier(entity: BaseEntity, tile_positions: Array) -> void:
    if not entity.active or entity.is_large():
        return
    var tile_indices_to_check: = tiles_with_sprite_modifiers.duplicate()
    for ti in entity.terrain_sprite_modifiers:
        tile_indices_to_check.erase(ti)
    if not tile_indices_to_check:
        return
    _check_add_terrain_spr_modifier(entity, tile_positions, tile_indices_to_check)

func _check_add_terrain_spr_modifier(entity: BaseEntity, tile_positions: Array, tile_indices_to_check: Array) -> void:
    for l in layers:
        for pos in tile_positions:
            var ti = l.get_cell_s(pos)
            if ti == -1 or not ti in tile_indices_to_check:
                continue
            tile_indices_to_check.erase(ti)
            if conditional_tile_event([pos], "tile_sprite_modifier", entity, true, ti):
                var sprite_modifier_info: Dictionary = tile_defs[ti].get("terrain_sprite_modifier", {})
                if sprite_modifier_info:
                    entity.add_sprite_modifier(sprite_modifier_info)
                # redundant safety check
                if not entity.terrain_sprite_modifiers.has(ti):
                    entity.terrain_sprite_modifiers.append(ti)

# Resolve some event with an optional context entity at multiple tile positions
# for base prop conditionals, evaluates once per tile id with all positions as the grey slot
# if any locally set override excludes a tile or replaces the event with another conditional, thos local overrides are each evaluated once at their position and excluded from the grey slot in the base case
func resolve_tiles_events(at_tile_positions: Array, tile_event_name: String, context_entity: BaseEntity, only_index: int = -1, extra_debug: bool = false) -> void:
    var indices_here: Array[int] = []
    for l in layers:
        for pos in at_tile_positions:
            var ti = l.get_cell_s(pos)
            if only_index != -1 and ti != only_index:
                continue
            if ti != -1 and ti not in indices_here:
                indices_here.append(ti)

    for ti in indices_here:
        # if there are any locally set event conditionals, resolve each at each location set
        var non_overriden_positions: Array[Vector2i] = []
        for pos in at_tile_positions:
            var local_event_prop: = get_tile_property_for_index_at(pos, tile_event_name, ti, true)
            if local_event_prop:
                local_event_prop.get_or_resolve(null, context_entity, [pos], [], extra_debug)
            else:
                non_overriden_positions.append(pos)

        # evaluate only once with all non-overriden positions in the grey slot
        if non_overriden_positions:
            var base_tile_prop: = get_tile_index_property(ti, tile_event_name)
            if base_tile_prop and base_tile_prop.is_conditional():
                base_tile_prop.resolve(null, context_entity, non_overriden_positions, [], extra_debug)

# Resolve tile event for every tile id that exists at all locations provided
# (Only once per id-position pair even if multiple layers at that position have that tile id)
func resolve_tile_individual_events(at_tile_positions: Array, tile_event_name: String, context_entity: BaseEntity, only_index: int = -1, extra_debug: bool = false) -> void:
    for at_pos in at_tile_positions:
        var resolved_indices: Array[int] = []
        for l in layers:
            var ti = l.get_cell_s(at_pos)
            if only_index != -1 and ti != only_index:
                continue
            elif ti == -1 or ti in resolved_indices:
                continue
            resolved_indices.append(ti)
            var event_property: = get_tile_property_for_index_at(at_pos, tile_event_name, ti)
            if event_property and event_property.is_conditional():
                event_property.resolve(null, context_entity, [at_pos], [], extra_debug)

func conditional_tile_event(at_tile_positions: Array, tile_event_name: String, context_entity: BaseEntity, is_all: bool = false, only_index: int = -1, extra_debug: bool = false) -> bool:
    var is_static: = is_prop_static(tile_event_name, only_index)
    for at_pos in at_tile_positions:
        for l in layers:
            var ti = l.get_cell_s(at_pos)
            if ti == -1 or (only_index != -1 and ti != only_index):
                continue
            var result: = false
            if is_static:
                if not get_tile_index_property(ti, tile_event_name):
                    continue
                result = _resolve_single_pos_static_prop_truthy(at_pos, ti, tile_event_name, context_entity, false, extra_debug)
            else:
                var event_property: = get_tile_property_for_index_at(at_pos, tile_event_name, ti)
                if not event_property:
                    continue
                result = Utility.truthy(event_property.get_or_resolve(null, context_entity, [at_pos], [], extra_debug))
            if not is_all and result:
                return true
            if is_all and not result:
                return false
    # If all, then yes all passed, if any, then no, none passed
    return is_all

func _resolve_single_pos_static_prop_truthy(at_pos: Vector2i, tile_id: int, event_name: String, context_entity: BaseEntity, default_result: bool = false, extra_debug: bool = false) -> bool:
    var static_prop: = get_tile_index_property(tile_id, event_name)
    if not static_prop:
        return default_result
    return Utility.truthy(static_prop.get_or_resolve(null, context_entity, [at_pos], [], extra_debug))

func _get_or_resolve_single_pos_static_prop(at_pos: Vector2i, tile_id: int, event_name: String, context_entity: BaseEntity, default_value: Variant = null, extra_debug: bool = false) -> Variant:
    var static_prop: = get_tile_index_property(tile_id, event_name)
    if not static_prop:
        return default_value
    return static_prop.get_or_resolve(null, context_entity, [at_pos], [], extra_debug)

func _resolve_truthy_single_pos_prop_if_exists(is_static: bool, at_pos: Vector2i, tile_id: int, prop_name: String, context_entity: BaseEntity, default_result: bool = false, extra_debug: bool = false) -> bool:
    if is_static:
        return _resolve_single_pos_static_prop_truthy(at_pos, tile_id, prop_name, context_entity, default_result, extra_debug)
    else:
        var prop: = get_tile_property_for_index_at(at_pos, prop_name, tile_id)
        if not prop:
            return default_result
        return Utility.truthy(prop.get_or_resolve(null, context_entity, [at_pos], [], extra_debug))

func tracked_conditional_tile_event(at_tile_positions: Array, event_name: String, ctx_entity: BaseEntity, is_all: bool = false, only_index: int = -1, extra_debug: bool = false) -> Dictionary:
    var result_info: Dictionary = {}
    var default_result: = true if is_all else false
    var overall_result: = default_result
    for at_pos in at_tile_positions:
        var resolved_here: Array[int] = []
        for l in layers:
            var ti: int = l.get_cell_s(at_pos)
            if ti == -1 or (only_index != -1 and ti != only_index) or ti in resolved_here:
                continue
            resolved_here.append(ti)
            var is_static: = is_prop_static(event_name, only_index)
            var result: = _resolve_truthy_single_pos_prop_if_exists(is_static, at_pos, ti, event_name, ctx_entity, default_result, extra_debug)
            if not result_info.has(ti):
                result_info[ti] = {"true": [], "false": [], "overall": default_result}
            result_info[ti][str(result)].append(at_pos)
            if is_all:
                overall_result = result and overall_result
                result_info[ti]["overall"] = result and result_info[ti]["overall"]
            else:
                overall_result = result or overall_result
                result_info[ti]["overall"] = result or result_info[ti]["overall"]
    result_info["overall"] = overall_result
    return result_info


func attempt_move(moving_entity: BaseEntity, leaving_ps: Array[Vector2i], entering_ps: Array[Vector2i], new_pos: Vector2i, is_group_move: bool = false, change_facing_to: int = -1, force_immediate_turn: bool = false) -> bool:
    #var result: = conditional_tile_event(leaving_ps, "move_off_of", moving_entity, true)
    var tracked_result: = tracked_conditional_tile_event(leaving_ps, "move_off_of", moving_entity, true)
    var result: bool = tracked_result["overall"]
    #prints("tracked result: %s" % [tracked_result])

    var skip_collection: Array[int] = []
    if not EntityManager.attempt_move_leave(moving_entity, leaving_ps, skip_collection, is_group_move):
        result = false
    if _check_moving_away:
        var moving_away_from_ps: = get_positions_moving_away_from(leaving_ps, moving_entity.facing)
        for pos in moving_away_from_ps:
            var tracked_away: = tracked_conditional_tile_event([pos], "move_away_from", moving_entity, false)
            if not tracked_away["overall"]:
                result = false
    if not result:
        return false
    
    # Move-dependent facing: Change facing dir in between leaving and entering
    var old_facing: int = moving_entity.facing
    if change_facing_to >= 0:
        moving_entity.facing = change_facing_to
    
    result = check_blocks_allow_move(moving_entity, entering_ps)
    if result:
        var tracked_onto: = tracked_conditional_tile_event(entering_ps, "move_onto", moving_entity, true)
        if not tracked_onto["overall"]:
            result = false
    if not EntityManager.attempt_move_enter(moving_entity, result, entering_ps, skip_collection):
        result = false
    
    if change_facing_to >= 0:
        if result:
            moving_entity.apply_teleport_facing_change(new_pos, change_facing_to, force_immediate_turn)
        else:
            # Restore facing if move dependent facing change exists and move failed
            moving_entity.facing = old_facing
    
    return result

func get_positions_moving_away_from(tile_positions: Array[Vector2i], move_direction: int) -> Array[Vector2i]:
    var adjacent_positions: Array[Vector2i] = []
    var facing_vectors: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
    
    for pos in tile_positions:
        for dir in facing_vectors.size():
            if dir == move_direction:
                continue
            #if dir >= 4 and Vector2(facing_vectors[dir]).dot(Vector2(facing_vectors[move_direction])) > 0:
                #continue
            var adjacent_pos: = pos + facing_vectors[dir]
            if adjacent_pos in adjacent_positions or adjacent_pos in tile_positions:
                continue
            adjacent_positions.append(adjacent_pos)
    return adjacent_positions
    

func is_blocked(tile_position, empty_blocks: bool = true) -> bool:
    if empty_blocks and not tile_exists_at(tile_position):
        return false
    for layer in layers:
        if layer.get_cell_s(tile_position) in blocking_tiles:
            return true
    return false

func world_to_tile_position(world_position: Vector2) -> Vector2i:
    return Vector2i(Vector2(world_position.floor() / tile_width).floor())

func tile_to_world_position(tile_position: Vector2i) -> Vector2:
    return Vector2(tile_position.x * tile_width, tile_position.y * tile_width)
func tile_to_world_position_centered(tile_position: Vector2i) -> Vector2:
    return (Vector2(tile_position) + Vector2(0.5, 0.5)) * tile_width

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

func check_terrain_spr_mod_for_created(created_entity: BaseEntity) -> void:
    _check_add_terrain_spr_modifier(created_entity, [created_entity.get_stationary_position()], tiles_with_sprite_modifiers.duplicate())
    
    # If the entity is created moving, check and remove the terrain sprite mod from their previous pos if it's no longer active during the move
    if created_entity.moving:
        _check_and_remove_terrain_spr_mod_for_moving(created_entity, created_entity.get_moving_position())

func half_moved_leaving_at(at_position: Vector2i, leaving_entities: Array) -> void:
    var tile_indices_here: Array[int] = []
    for l in layers:
        var ti = l.get_cell_s(at_position)
        if ti != -1 and ti not in tile_indices_here:
            tile_indices_here.append(ti)
    
    if not tile_indices_here:
        return

    for entity: BaseEntity in leaving_entities:
        EntityManager.resolve_entity_interaction_old("half_moved_off_of_tile", entity, null, at_position)
    for entity: BaseEntity in leaving_entities:
        resolve_tiles_events([at_position], "half_moved_off_of", entity)
    
func half_moved_entering_at(at_position: Vector2i, entering_entities: Array) -> void:
    var tile_indices_here: Array[int] = []
    for l in layers:
        var ti = l.get_cell_s(at_position)
        if ti != -1 and ti not in tile_indices_here:
            tile_indices_here.append(ti)
    
    if not tile_indices_here:
        return

    for entity: BaseEntity in entering_entities:
        EntityManager.resolve_entity_interaction_old("half_moved_onto_tile", entity, null, at_position)
    for entity: BaseEntity in entering_entities:
        resolve_tiles_events([at_position], "half_moved_onto", entity)
    
    # TODO handle covered tracking here

func post_move_actions(moving_entity: BaseEntity, _from_position: Vector2i, to_position: Vector2i) -> void:
    _check_and_remove_terrain_spr_mod_for_moving(moving_entity, to_position)

func entity_idle_actions(entity: BaseEntity) -> void:
    resolve_tiles_events([entity.get_stationary_position()], "idle_on", entity)

func _check_and_remove_terrain_spr_mod_for_moving(moving_entity: BaseEntity, to_position: Vector2i) -> void:
    if not moving_entity.terrain_sprite_modifiers:
        return
    elif moving_entity.is_large():
        for terrain_mod_tile_id in moving_entity.terrain_sprite_modifiers:
            var terrain_mod: Dictionary = tile_defs[terrain_mod_tile_id].get("terrain_sprite_modifier", {})
            if terrain_mod:
                moving_entity.remove_sprite_modifier(terrain_mod)
    
    var cur_terrain_mods: = moving_entity.terrain_sprite_modifiers.duplicate()
    
    var overlapping_tile_indices: Array[int] = []
    for l in layers:
        var ti = l.get_cell_s(to_position)
        overlapping_tile_indices.append(ti)
    
    for mod_tile_index in cur_terrain_mods:
        if not mod_tile_index in overlapping_tile_indices:
            var mod_info: Dictionary = tile_defs[mod_tile_index].get("terrain_sprite_modifier", {})
            moving_entity.remove_sprite_modifier(mod_info)
            moving_entity.terrain_sprite_modifiers.erase(mod_tile_index)
    

func switch_tiles_preview_mode(enable_preview: bool) -> void:
    if enable_preview == is_tile_preview_mode:
        return
    is_tile_preview_mode = enable_preview
    
    for tilemap_layer in layers:
        tilemap_layer.tile_set = current_tileset()
        
    # Cell data is stored in TileMapLayers as source IDs and atlas coords, so in order for the tilemap to work
    # we need to change the atlas coords even though each source only has a single tile defined anyway
    for tile_index in tile_defs:
        if not tile_defs[tile_index].get("preview_variant", {}):
            continue

        var cur_atlas_coords: = get_tile_atlas_coords(tile_index, is_tile_preview_mode)
        for tilemap_layer: TileMapLayer in layers:
            var tile_index_positions: = tilemap_layer.get_used_cells_by_id(tile_index)
            for at_pos in tile_index_positions:
                var alt_id: = tilemap_layer.get_cell_alternative_tile(at_pos)
                tilemap_layer.set_cell(at_pos, tile_index, cur_atlas_coords, alt_id)

func get_world_pos_above(tile_position: Vector2i) -> Vector2:
    return tile_to_world_position_centered(tile_position) + (Vector2.UP * (tile_width * 0.75))

func idle_actions() -> void:
    var activate_id: Array[int] = []
    var activate_at: Array = []
    for t_id in tile_defs:
        var tile_props: Dictionary = tile_defs[t_id].get("properties", {})
        if not tile_props.has("idle_update"):
            continue
        var idle_update_prop: = get_tile_index_property(t_id, "idle_update")
        if not idle_update_prop.is_conditional():
            continue
        activate_id.append(t_id)
        activate_at.append(get_all_positions_of_tile(t_id))
    for idx in activate_id.size():
        resolve_tile_individual_events(activate_at[idx], "idle_update", null, activate_id[idx], false)

func every_tick_actions() -> void:
    var activate_id: Array[int] = []
    var activate_at: Array = []
    for t_id in tile_defs:
        var tile_props: Dictionary = tile_defs[t_id].get("properties", {})
        if not tile_props.has("every_tick"):
            continue
        var every_tick_prop: = get_tile_index_property(t_id, "every_tick")
        if not every_tick_prop.is_conditional():
            continue
        activate_id.append(t_id)
        activate_at.append(get_all_positions_of_tile(t_id))
    for idx in activate_id.size():
        resolve_tile_individual_events(activate_at[idx], "every_tick", null, activate_id[idx], false)

func removing_texture_id(_texture_id: int) -> void:
    var fallback_tex: int = TextureManager.get_fallback_texture_id()
    for tile_id in tile_defs.keys():
        _remap_texture_id_in_tile(tile_id, _texture_id, fallback_tex, 0)

func remapping_texture_id(from_texture_id: int, into_texture_id: int) -> void:
    for tile_id in tile_defs.keys():
        _remap_texture_id_in_tile(tile_id, from_texture_id, into_texture_id)

func _remap_texture_id_in_tile(tile_id: int, from_texture_id: int, into_texture_id: int, overwrite_index_with: int = -1) -> void:
    _remap_texture_id_in_dict(tile_defs[tile_id], from_texture_id, into_texture_id, overwrite_index_with)
    if "preview_variant" in tile_defs[tile_id]:
        _remap_texture_id_in_dict(tile_defs[tile_id]["preview_variant"], from_texture_id, into_texture_id, overwrite_index_with)
    if "terrain_sprite_modifier" in tile_defs[tile_id]:
        for mod_layer in tile_defs[tile_id]["terrain_sprite_modifier"].get("layers", []):
            _remap_texture_id_in_dict(mod_layer, from_texture_id, into_texture_id, overwrite_index_with)

func _remap_texture_id_in_dict(dict: Dictionary, from_texture_id: int, into_texture_id: int, overwrite_index_with: int = -1) -> void:
    if "texture" in dict and int(dict["texture"]) == from_texture_id:
        dict["texture"] = into_texture_id
        if overwrite_index_with >= 0 and "tex_index" in dict:
                dict["tex_index"] = overwrite_index_with
    if "mask_texture" in dict and int(dict["mask_texture"]) == from_texture_id:
        dict["mask_texture"] = into_texture_id
        if overwrite_index_with >= 0 and "mask_tex_index" in dict:
            dict["mask_tex_index"] = overwrite_index_with

func accumulate_used_texture_ids_from_dict(dict: Dictionary, texture_ids: Array[int]) -> void:
    if "preview_variant" in dict:
        accumulate_used_texture_ids_from_dict(dict["preview_variant"], texture_ids)
    if "terrain_sprite_modifier" in dict:
        for mod_layer in dict["terrain_sprite_modifier"].get("layers", []):
            accumulate_used_texture_ids_from_dict(mod_layer, texture_ids)
    if "mask_texture" in dict:
        if typeof(dict["mask_texture"]) in [TYPE_INT, TYPE_FLOAT] and int(dict["mask_texture"]) >= 0:
            var texture_id: int = int(dict["mask_texture"])
            if not texture_id in texture_ids:
                texture_ids.append(texture_id)
    if "texture" in dict:
        if typeof(dict["texture"]) not in [TYPE_INT, TYPE_FLOAT]:
            return
        var texture_id: int = int(dict["texture"])
        if texture_id < 0:
            return
        if not texture_id in texture_ids:
            texture_ids.append(texture_id)

func get_used_texture_ids_from_defs(some_tile_defintions: Dictionary) -> Array[int]:
    var used_texture_ids: Array[int] = []
    for tile_def in some_tile_defintions.values():
        accumulate_used_texture_ids_from_dict(tile_def, used_texture_ids)
    return used_texture_ids

func _is_dict_using_texture_id(dict: Dictionary, texture_id: int) -> bool:
    if int(dict.get("texture", -1)) == texture_id or int(dict.get("mask_texture", -1)) == texture_id:
        return true
    return false

func _is_tile_using_texture_id(tile_id: int, texture_id: int) -> bool:
    if _is_dict_using_texture_id(tile_defs[tile_id], texture_id):
        return true
    if "preview_variant" in tile_defs[tile_id]:
        return _is_dict_using_texture_id(tile_defs[tile_id]["preview_variant"], texture_id)
    if "terrain_sprite_modifier" in tile_defs[tile_id]:
        for mod_layer in tile_defs[tile_id]["terrain_sprite_modifier"].get("layers", []):
            if _is_dict_using_texture_id(mod_layer, texture_id):
                return true
    return false

func is_texture_id_in_use(texture_id: int) -> bool:
    for tile_id in tile_defs.keys():
        if _is_tile_using_texture_id(tile_id, texture_id):
            return true
    return false

func get_max_z_at(at_tile_pos: Vector2i) -> int:
    var max_z: int = 0
    for l in layers:
        var ti = l.get_cell_s(at_tile_pos)
        if ti != -1:
            var tile_def_props: Dictionary = tile_defs[ti]["properties"]
            if not tile_def_props.has("z-index") or typeof(tile_def_props["z-index"]) in [TYPE_DICTIONARY, TYPE_ARRAY]:
                continue
            max_z = maxi(max_z, Utility.property_value_scalar(tile_def_props["z-index"], max_z))
    return max_z

func set_save_persist_on_completion(save_key: String, value: Variant, allow_in_level_edit: bool = false) -> void:
    if not allow_in_level_edit and GameManager.is_in_level_edit_mode:
        return
    if not map_metadata.has("save_persist_on_completion"):
        map_metadata["save_persist_on_completion"] = {}
    map_metadata["save_persist_on_completion"][save_key] = value

func add_save_persist_on_completion(save_key: String, to_add: float, default_start: float = 0, allow_in_level_edit: bool = false) -> void:
    if not allow_in_level_edit and GameManager.is_in_level_edit_mode:
        return
    if not map_metadata.has("save_increment_on_completion"):
        map_metadata["save_increment_on_completion"] = {}
    if not map_metadata["save_increment_on_completion"].has(save_key):
        map_metadata["save_increment_on_completion"][save_key] = default_start
    map_metadata["save_increment_on_completion"][save_key] += to_add

func clear_save_adds_for(save_key: String) -> void:
    if not map_metadata.get("save_increment_on_completion", {}).has(save_key):
        return
    map_metadata["save_increment_on_completion"].erase(save_key)

func get_save_adds_for(save_key: String) -> float:
    if not map_metadata.get("save_increment_on_completion", {}).has(save_key):
        return 0
    return map_metadata["save_increment_on_completion"][save_key]

func clear_save_persist_on_completion() -> void:
    map_metadata.erase("save_persist_on_completion")
    map_metadata.erase("save_increment_on_completion")

func flush_save_persist_on_completion() -> void:
    if GameManager.is_in_level_edit_mode:
        return
    for save_key in map_metadata.get("save_persist_on_completion", {}).keys():
        var val: Variant = map_metadata["save_persist_on_completion"][save_key]
        GameManager.set_game_save_data(save_key, val)
    for save_key in map_metadata.get("save_increment_on_completion", {}).keys():
        var to_add: float = map_metadata["save_increment_on_completion"][save_key]
        var exisiting_val: Variant = GameManager.get_game_save_data(save_key, 0)
        if not Utility.is_variant_valid_scalar(exisiting_val):
            GameManager.set_game_save_data(save_key, to_add)
        else:
            var existing_scalar: float = float(exisiting_val)
            GameManager.set_game_save_data(save_key, existing_scalar + to_add)
    clear_save_persist_on_completion()

func is_level_start_paused() -> bool:
    if not map_metadata.has("start_level_paused"):
        return GameManager.get_game_setting("start_level_paused", false)
    else:
        return map_metadata["start_level_paused"]

func set_level_start_paused(paused: bool) -> void:
    var def: bool = GameManager.get_game_setting("start_level_paused", false)
    if def != paused:
        set_metadata_value("start_level_paused", paused, GameManager.is_in_level_edit_mode)
    else:
        erase_metadata_value("start_level_paused", GameManager.is_in_level_edit_mode)

func get_basic_atlas_textures_for_foreign_game(foreign_game_def: Dictionary, game_name: String) -> Dictionary[int, AtlasTexture]:
    var foreign_texture_spec: Array = foreign_game_def.get("textures", [])
    var foreign_texture_lookup: Dictionary = TextureManager.make_foreign_texture_lookup(foreign_texture_spec, game_name)
    if foreign_texture_lookup["errors"].size() > 0:
        push_warning("Some foreign textures were not able to be loaded: %s" % [foreign_texture_lookup["errors"]])
    
    var fallback_atlas_tex: AtlasTexture = AtlasTexture.new()
    fallback_atlas_tex.atlas = TextureManager.placeholder
    fallback_atlas_tex.region = Rect2(0, 0, 32, 32)

    var basic_atlas_textures: Dictionary[int, AtlasTexture] = {}
    var foreign_tile_defs: Dictionary = foreign_game_def.get("tile_definitions", {})
    for tile_id_str in foreign_tile_defs.keys():
        var tile_id: int = int(tile_id_str)
        var texture_id: int = foreign_tile_defs[tile_id_str].get("texture", -1)
        if texture_id < 0 or not texture_id in foreign_texture_lookup:
            basic_atlas_textures[tile_id] = fallback_atlas_tex
            continue

        var sub_index: int = foreign_tile_defs[tile_id_str].get("tex_index", 0)
        basic_atlas_textures[tile_id] = Utility.atlas_texture_from_id_using_lookup(texture_id, sub_index, foreign_texture_lookup)
    
    return basic_atlas_textures


func import_new_definition_with_texture_remaps(new_definition: Dictionary, texture_remaps: Dictionary[int, int]) -> int:
    var new_tile_id: int = max_tile_index() + 1
    tile_defs[new_tile_id] = new_definition
    
    for remap_from_id in texture_remaps:
        _remap_texture_id_in_tile(new_tile_id, remap_from_id, texture_remaps[remap_from_id])

    return new_tile_id

func import_new_tiles_with_texture_remaps(new_tiles: Array, texture_remaps: Dictionary[int, int]) -> void:
    for new_tile_definition in new_tiles:
        if typeof(new_tile_definition) != TYPE_DICTIONARY:
            continue
        import_new_definition_with_texture_remaps(new_tile_definition, texture_remaps)

func state_load_actions() -> void:
    if GameManager._state_load_is_start_of_level:
        starting_event("level_start")
    starting_event("level_refresh")

func starting_event(event_name: String) -> void:
    for t_id in tile_defs:
        var tile_props: Dictionary = tile_defs[t_id].get("properties", {})
        if not tile_props.has(event_name):
            continue
        var event_prop: = get_tile_index_property(t_id, event_name)
        if not event_prop.is_conditional():
            continue
        var positions_of_tile: = get_all_positions_of_tile(t_id)
        resolve_tile_individual_events(positions_of_tile, event_name, null, t_id, false)

func get_custom_fail_state_intermission_id() -> String:
    var custom_fail_assignments: Array = get_intermission_assignements_for_event(IntermissionEvents.CUSTOM_FAIL_STATE)
    return GameManager.get_first_viewable_intermission_from_list(custom_fail_assignments)


func get_intermission_assignements_for_event(event: IntermissionEvents) -> Array:
    var event_key: String = EditIntermissionAssignments.get_event_key(event)
    if not event_key:
        return []

    var intermissions: Array[String] = []
    var intermission_assignments: Dictionary = map_metadata.get("intermission_assignments", {})
    intermissions.append_array(intermission_assignments.get(event_key, []))

    return intermissions