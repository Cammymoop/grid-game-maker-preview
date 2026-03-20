extends TileMapLayer

func single_init(tile_index):
	var width = 5
	var height = 5
	for i in range(width):
		for j in range(height):
			set_cell_i_source(i, j, tile_index)

func set_cell_s(at_coord: Vector2i, tile_source: int) -> void:
	if tile_source == -1:
		erase_cell(at_coord)
		return
	var atlas_source: = tile_set.get_source(tile_source) as TileSetAtlasSource
	var tile_atlas_coords: = atlas_source.get_tile_id(0)
	set_cell(at_coord, tile_source, tile_atlas_coords)

func set_cell_i_source(x: int, y: int, tile_source: int):
	set_cell_s(Vector2i(x, y), tile_source)

func get_cell_s(at_coord: Vector2i) -> int:
	return get_cell_source_id(at_coord)

func get_cell_i_source(x: int, y: int) -> int:
	return get_cell_source_id(Vector2i(x, y))

func random_init():
	var width = 5
	var height = 5
	
	var random_tiles = ['floor', 'floor', 'floor', 'floor2', 'greenery', 'water', 'wall']
	var random_ti = []
	for tile in random_tiles:
		random_ti.append(MapManager.get_tile_index(tile))
	
	for i in range(width):
		for j in range(height):
			set_cell_i_source(i, j, Utility.random_list_element(random_ti))

func serialize() -> Dictionary:
	var rect = get_used_rect()
	var start_x = rect.position.x
	var start_y = rect.position.y
	var rows = []
	var x_range = range(start_x, rect.end.x)
	for y in range(start_y, rect.end.y):
		var row = []
		for x in x_range:
			row.append(get_cell_i_source(x, y))
		rows.append(row)
	
	return {"start_x": start_x, "start_y": start_y, "tiles": rows}

func deserialize(data: Dictionary) -> void:
	clear()
	
	var tile_data = data['tiles']
	var sx = data['start_x']
	var sy = data['start_y']
	
	var j_range = range(len(tile_data[0]))
	var i_range = range(len(tile_data))
	for i in i_range:
		var row = tile_data[i]
		for j in j_range:
			set_cell_i_source(j + sx, i + sy, row[j])
