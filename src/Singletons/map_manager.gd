extends Node

var map_layer_template = preload("res://Scenes/MapLayer.tscn")

var layers = []

var blocking_tiles = []

var tile_width = 32

var tile_defs = {
	0: {
		"name": "floor",
		"texture": 0,
		"tex_index": 18,
		"properties": {},
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
		"properties": {},
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

var tile_index_map = {}

var tileset = null

var im_ready = false

func _ready() -> void:
	if not TextureManager.im_ready:
		yield(TextureManager, "textures_loaded")
	create_tileset()
	find_blocking()
	
	im_ready = true

func create_random_layer():
	create_empty_layer()
	layers[0].random_init()

func create_empty_layer():
	var map_layer = map_layer_template.instance()
	Utility.get_world().add_child(map_layer)
	auto_setup_layers()
	map_layer.single_init(get_tile_index("floor2"))

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
		
		new_tileset.tile_set_region(tile_index, TextureManager.get_index_rect(tile_info['texture'], tile_info['tex_index']))
	
	tileset = new_tileset

func get_all_tile_indexes() -> Array:
	return tile_defs.keys()

func get_tile_index(tile_name) -> int:
	return tile_index_map[tile_name]

func get_tile_name(tile_index) -> String:
	return tile_defs[tile_index]['name']

func find_blocking() -> void:
	blocking_tiles = []
	
	for ti in tile_defs:
		var td = tile_defs[ti]
		if "blocks" in td["properties"]:
			if typeof(td["properties"]["blocks"]) != TYPE_DICTIONARY and td["properties"]["blocks"]:
				blocking_tiles.append(ti)


func auto_setup_layers():
	layers = get_tree().get_nodes_in_group("MapLayer")
	for l in layers:
		l.tile_set = tileset

func clear_all_at(tile_position) -> void:
	for l in layers:
		l.set_cellv(tile_position, -1)

func replace_tiles_at(tile_position, new_tile) -> void:
	clear_all_at(tile_position)
	layers[0].set_cellv(tile_position, new_tile)

func get_tile_property_at(tile_position, property_name):
	var property_val = null
	for l in layers:
		var ti = l.get_cellv(tile_position)
		if ti != -1:
			var tprop = get_tile_property(ti, property_name)
			if tprop != null:
				property_val = ti
	return property_val

func get_tile_index_at(tile_position):
	var tile_index = -1
	for l in layers:
		var ti = l.get_cellv(tile_position)
		if ti != -1:
			tile_index = ti
	return tile_index

func get_tile_property(tile_index, property_name):
	var props = tile_defs[tile_index]["properties"]
	if not property_name in props:
		return null
	return props[property_name]

func can_move_to(entity, tile_position) -> bool:
	if not EntityManager.can_move_to(entity, tile_position):
		return false
	
	return check_blocks(entity, tile_position)
	
func check_blocks(entity, tile_position) -> bool:
	for layer in layers:
		var tile_here = layer.get_cellv(tile_position)
		if tile_here == -1 or tile_here in blocking_tiles:
			return false
		var blocks_conditional = get_tile_property(tile_here, "blocks")
		if blocks_conditional:
			var result = ConditionalFunctions.resolve_conditional("blocks", blocks_conditional, null, entity, tile_position)
			if result:
				return false
	return true

func finish_move(moving_entity, tile_position) -> void:
	EntityManager.finish_move(moving_entity, tile_position)
	
	var ifmot = EntityManager.get_entity_property(moving_entity, "i_finish_move_onto_tile")
	if typeof(ifmot) == TYPE_DICTIONARY:
		ConditionalFunctions.resolve_conditional("i_finish_move_onto_tile", ifmot, moving_entity, null, tile_position)
	
	for l in layers:
		var ti = l.get_cellv(tile_position)
		if ti == -1:
			continue
		var fmot = get_tile_property(ti, "finish_move_onto_tile")
		if typeof(fmot) == TYPE_DICTIONARY:
			ConditionalFunctions.resolve_conditional("finish_move_onto_tile", fmot, null, moving_entity, tile_position)

func attempt_move(moving_entity, tile_position) -> bool:
	var entity_move_allow = EntityManager.attempt_move(moving_entity, tile_position)
	
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
