extends Node

signal textures_loaded

var texture_names = [
	"assets/img/tiles.png",
	"assets/img/entityTiles.png",
]
var textures = []
var tiles_per_row = []

var im_ready = false

func _ready() -> void:
	for tn in texture_names:
		var img = load("res://" + tn)
		textures.append(img)
		tiles_per_row.append(int(img.get_width() / MapManager.tile_width))
	
	emit_signal("textures_loaded")
	im_ready = true

func get_texture(texture_index) -> Texture:
	return textures[texture_index]

func get_index_offset(texture_index, tile_index) -> Vector2:
		var tpr = tiles_per_row[texture_index]
		return Vector2(tile_index % tpr * MapManager.tile_width, floor(tile_index/tpr) * MapManager.tile_width)

func get_index_rect(texture_index, tile_index) -> Rect2:
	return Rect2(get_index_offset(texture_index, tile_index), Vector2(MapManager.tile_width, MapManager.tile_width))
