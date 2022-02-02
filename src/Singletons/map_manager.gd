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

func create_default_layer():
	var map_layer = map_layer_template.instance()
	Utility.get_world().add_child(map_layer)
	map_layer.random_init()

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

func get_tile_index(tile_name) -> int:
	return tile_index_map[tile_name]

func get_tile_name(tile_index) -> String:
	return tile_defs[tile_index]['name']

func find_blocking() -> void:
	blocking_tiles = []
	
	for ti in tile_defs:
		var td = tile_defs[ti]
		if "blocks" in td["properties"]:
			blocking_tiles.append(ti)


func auto_setup_layers():
	layers = get_tree().get_nodes_in_group("MapLayer")
	for l in layers:
		l.tile_set = tileset

func can_move_to(entity, tile_position) -> bool:
	if not EntityManager.can_move_to(entity, tile_position):
		return false
	
	for layer in layers:
		var tile_here = layer.get_cellv(tile_position)
		if tile_here in blocking_tiles:
			return false
	return true

func is_blocked(tile_position) -> bool:
	for layer in layers:
		var tile_here = layer.get_cellv(tile_position)
		if tile_here in blocking_tiles:
			return true
	return false

func world_to_tile_position(world_position):
	return Vector2(floor(world_position.x / tile_width), floor(world_position.y / tile_width))
