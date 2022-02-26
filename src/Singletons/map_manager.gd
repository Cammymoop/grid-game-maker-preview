extends Node

signal level_size_changed

var map_layer_template = preload("res://Scenes/MapLayer.tscn")

var layers = []

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
onready var loaded_tile_defs = tile_defs

var tile_index_map = {}

var tileset = null

var im_ready = false

func setup() -> void:
	fix_string_keys()
	if not TextureManager.im_ready:
		yield(TextureManager, "textures_loaded")
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
	map_layer.single_init(get_tile_index("floor"))
	
	emit_signal("level_size_changed")

func create_empty_layer():
	var map_layer = map_layer_template.instance()
	var ents = Utility.get_world().get_node("Entities")
	Utility.get_world().add_child_below_node(ents, map_layer)
	map_layer.tile_set = tileset
	layers.append(map_layer)
	return map_layer

func create_tileset():
	var new_tileset: = TileSet.new()
	tile_index_map = {}
	
	for tile_index in tile_defs:
		var tile_info = tile_defs[tile_index]
		new_tileset.create_tile(tile_index)
		new_tileset.tile_set_texture(tile_index, TextureManager.get_texture(tile_info['texture']))
		
		if tile_info['name'] in tile_index_map:
			print_debug("WARNING: tile name already in use: " + tile_info['name'])
		tile_index_map[tile_info['name']] = tile_index
		
		var texture_rect = TextureManager.get_index_rect(tile_info['texture'], tile_info['tex_index'])
		new_tileset.tile_set_region(tile_index, texture_rect)
		if texture_rect.size.x != tile_width or texture_rect.size.y != tile_width:
			var offset = ((Vector2(tile_width, tile_width) - texture_rect.size) / 2).floor()
			new_tileset.tile_set_texture_offset(tile_index, offset)
		
		if "z-index" in tile_info['properties']:
			new_tileset.tile_set_z_index(tile_index, tile_info['properties']['z-index'])
			
	
	tileset = new_tileset

func update_index_map() -> void:
	tile_index_map = {}
	for tile_index in tile_defs:
		var tname = tile_defs[tile_index]['name']
		if tname in tile_index_map:
			print_debug("WARNING: tile name already in use: " + tname)
		tile_index_map[tname] = tile_index

func get_tile_texture(tile_index) -> Texture:
	return TextureManager.get_texture(tile_defs[tile_index]['texture'])
func get_tile_texture_rect(tile_index) -> Rect2:
	return TextureManager.get_index_rect(tile_defs[tile_index]['texture'], tile_defs[tile_index]['tex_index'])

func serialize() -> Dictionary:
	var serialized_layers = []
	for l in layers:
		serialized_layers.append(l.serialize())
	
	return {"layers": serialized_layers}

func deserialize(data: Dictionary) -> void:
	clear_layers()
	
	for layer_data in data["layers"]:
		var new_layer = create_empty_layer()
		new_layer.deserialize(layer_data)
	
	emit_signal("level_size_changed")

func get_all_tile_indexes() -> Array:
	var keys = tile_defs.keys()
	keys.sort()
	return keys
 

func get_all_positions_of_tile(tile_index) -> Array:
	var positions = []
	for l in layers:
		for pos in l.get_used_cells_by_id(tile_index):
			positions.append(pos)
	return positions

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
		var blocks: = get_tile_property(ti, "blocks")
		if blocks and not blocks.is_conditional() and blocks.get_value():
			blocking_tiles.append(ti)

func clear_all_at(tile_position) -> void:
	for l in layers:
		l.set_cellv(tile_position, -1)

func replace_tiles_in_rect(rect:Rect2, new_tile, checker_tile=false):
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

func replace_tiles_at(tile_position, new_tile) -> void:
	var old_bounds = get_map_size()
	clear_all_at(tile_position)
	if new_tile != -1:
		layers[0].set_cellv(tile_position, new_tile)
	
	if new_tile == -1:
		if get_map_size() != old_bounds:
			emit_signal("level_size_changed")
	elif is_pos_out_of_bounds(tile_position):
		emit_signal("level_size_changed")

func get_tile_definition(tile_index):
	return tile_defs[tile_index].duplicate()

func is_tile_at(tile_index, tile_position) -> bool:
	var found = false
	for l in layers:
		if l.get_cellv(tile_position) == tile_index:
			found = true
	return found

func update_tile_definition(tile_index, definition) -> void:
	if not tile_index in tile_defs:
		print("ERROR tried to update non-existing tile: " + str(tile_index))
		return
	tile_defs[tile_index] = definition
	update_index_map()

func new_tile(definition) -> int:
	var try_index = 0
	while try_index in tile_defs:
		try_index += 1
	tile_defs[try_index] = definition
	update_index_map()
	return try_index

func add_new_tile_definition(definition) -> int:
	var index = 0
	while index in tile_defs:
		index += 1
	tile_defs[index] = definition
	return index

func remove_tile_definition(tile_index) -> void:
	tile_defs.erase(tile_index)

func get_tile_property_at(tile_position, property_name) -> Property:
	var return_val = null
	for l in layers:
		var ti = l.get_cellv(tile_position)
		if ti != -1:
			var tprop = get_tile_property(ti, property_name)
			if tprop != null:
				return_val = tprop
	return return_val

func get_tile_index_at(tile_position):
	var tile_index = -1
	for l in layers:
		var ti = l.get_cellv(tile_position)
		if ti != -1:
			tile_index = ti
	return tile_index

func get_tile_property(tile_index, property_name) -> Property:
	var props = tile_defs[tile_index]["properties"]
	if not property_name in props:
		return null
	var property = Property.new()
	property.set_value(props[property_name])
	property.set_name(property_name)
	return property

func can_move_to(entity, tile_position) -> bool:
	if not EntityManager.can_move_to(entity, tile_position):
		return false
	
	return check_blocks(entity, tile_position)
	
func check_blocks(entity, tile_position) -> bool:
	for layer in layers:
		var tile_here = layer.get_cellv(tile_position)
		if tile_here == -1 or tile_here in blocking_tiles:
			return false
		var blocks_conditional: = get_tile_property(tile_here, "blocks")
		if blocks_conditional and blocks_conditional.is_conditional():
			var result = blocks_conditional.resolve(null, entity, tile_position)
			if result:
				return false
	return true

func get_tile_facing_at(_tile_position) -> int:
	return 0 # TODO do this

func finish_move(moving_entity, tile_position) -> void:
	EntityManager.finish_move(moving_entity, tile_position)
	
	var ifmot: = EntityManager.get_entity_property(moving_entity, "i_finish_move_onto_tile")
	if ifmot and ifmot.is_conditional():
		ifmot.resolve(moving_entity, null, tile_position)
	
	for l in layers:
		var ti = l.get_cellv(tile_position)
		if ti == -1:
			continue
		var fmot: = get_tile_property(ti, "finish_move_onto_tile")
		if fmot and fmot.is_conditional():
			fmot.resolve(null, moving_entity, tile_position)

func attempt_move(moving_entity, tile_position, group_move=false) -> bool:
	var entity_move_allow = EntityManager.attempt_move(moving_entity, tile_position, group_move)
	
	var tile_move_allow = check_blocks(moving_entity, tile_position)
	return tile_move_allow and entity_move_allow

func is_blocked(tile_position) -> bool:
	for layer in layers:
		var tile_here = layer.get_cellv(tile_position)
		if tile_here in blocking_tiles:
			return true
	return false

func world_to_tile_position(world_position):
	return Vector2(floor(world_position.x / tile_width), floor(world_position.y / tile_width))

func tile_to_world_position(tile_position):
	return Vector2(tile_position.x * tile_width, tile_position.y * tile_width)
func tile_to_world_position_centered(tile_position):
	return (tile_position + Vector2(0.5, 0.5)) * tile_width
