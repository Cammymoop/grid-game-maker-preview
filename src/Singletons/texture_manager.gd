extends Node

signal textures_loaded

var texture_names = [
	"assets/img/tiles.png",
	"assets/img/entityTiles.png",
]
var textures = []
var tiles_per_row = []
var texture_rows = []

var im_ready = false

func _ready() -> void:
	for tn in texture_names:
		var img = load("res://" + tn)
		textures.append(img)
		tiles_per_row.append(int(img.get_width() / MapManager.tile_width))
		texture_rows.append(int(img.get_height() / MapManager.tile_width))
	
	emit_signal("textures_loaded")
	im_ready = true

func get_texture_name(texture_index):
	var tname = texture_names[texture_index]
	var name_bit = tname.split('/')[-1]
	return name_bit

func get_texture_name_list():
	var tlist = []
	for i in range(len(textures)):
		tlist.append(get_texture_name(i))
	
	return tlist

func get_all_indexes() -> Array:
	return range(len(textures))

func get_texture(texture_index) -> Texture:
	return textures[texture_index]

func get_index_offset(texture_index, tile_index) -> Vector2:
		var tpr = tiles_per_row[texture_index]
		return Vector2(tile_index % tpr * MapManager.tile_width, floor(tile_index/tpr) * MapManager.tile_width)

func get_tiles_per_row(texture_index):
	return tiles_per_row[texture_index]

func get_index_rect(texture_index, tile_index) -> Rect2:
	return Rect2(get_index_offset(texture_index, tile_index), Vector2(MapManager.tile_width, MapManager.tile_width))

func get_last_sub_index(texture_index) -> int:
	var tpr = tiles_per_row[texture_index]
	var rows = texture_rows[texture_index]
	return (rows * tpr) - 1
