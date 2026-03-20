extends TileMapLayer

func single_init(tile_index):
	var width = 5
	var height = 5
	for i in range(width):
		for j in range(height):
			set_cell_tile_idx(i, j, tile_index)

func get_atlas_size() -> Vector2i:
	return (tile_set.get_source(0) as TileSetAtlasSource).get_atlas_grid_size()

func atlas_coords_to_index(atlas_coords: Vector2i) -> int:
	return atlas_coords.x + (atlas_coords.y * get_atlas_size().x)

func index_to_atlas_coords(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % get_atlas_size().x, index / get_atlas_size().x)

func set_cell_tile_idx(x: int, y: int, tile_index: int):
	set_cell(Vector2i(x, y), 0, index_to_atlas_coords(tile_index))

func get_cell_tile_idx(x: int, y: int) -> int:
	return atlas_coords_to_index(get_cell_atlas_coords(Vector2i(x, y)))

func random_init():
	var width = 5
	var height = 5
	
	var random_tiles = ['floor', 'floor', 'floor', 'floor2', 'greenery', 'water', 'wall']
	var random_ti = []
	for tile in random_tiles:
		random_ti.append(MapManager.get_tile_index(tile))
	
	for i in range(width):
		for j in range(height):
			set_cell_tile_idx(i, j, Utility.random_list_element(random_ti))

func serialize() -> Dictionary:
	var rect = get_used_rect()
	var start_x = rect.position.x
	var start_y = rect.position.y
	var rows = []
	var x_range = range(start_x, rect.end.x)
	for y in range(start_y, rect.end.y):
		var row = []
		for x in x_range:
			row.append(get_cell_tile_idx(x, y))
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
			set_cell_tile_idx(j + sx, i + sy, row[j])
