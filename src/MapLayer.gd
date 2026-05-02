extends TileMapLayer

func single_init(tile_index):
	var width = 5
	var height = 5
	for i in range(width):
		for j in range(height):
			set_cell_i_source(i, j, tile_index)

func set_cell_s(at_coord: Vector2i, tile_source: int, facing: int = 0) -> void:
	if tile_source == -1:
		erase_cell(at_coord)
		return
	var transform_val: = Utility.tile_transform_from_facing(facing)
	var atlas_source: = tile_set.get_source(tile_source) as TileSetAtlasSource
	var tile_atlas_coords: = atlas_source.get_tile_id(0)
	set_cell(at_coord, tile_source, tile_atlas_coords, transform_val)

func set_cell_i_source(x: int, y: int, tile_source: int, facing: int = 0):
	set_cell_s(Vector2i(x, y), tile_source, facing)

func set_cell_facing(at_coord: Vector2i, facing: int):
	var transform_val: = Utility.tile_transform_from_facing(facing)
	var old_source: = get_cell_source_id(at_coord)
	var old_atlas_coords: = get_cell_atlas_coords(at_coord)
	# NOTE: Currently doesn't use regular alt IDs, this would be needed if they were ever non-zero
	#var old_alt_id: = get_cell_alternative_tile(at_coord) & ~Utility.TILE_TANSFORM_MASK
	# ... and pass `old_alt_id | transform_val` instead of just `transform_val`
	set_cell(at_coord, old_source, old_atlas_coords, transform_val)

func get_cell_s(at_coord: Vector2i) -> int:
	return get_cell_source_id(at_coord)

func get_cell_i_source(x: int, y: int) -> int:
	return get_cell_source_id(Vector2i(x, y))

func get_cell_facing(at_coord: Vector2i) -> int:
	return Utility.facing_from_tile_alt_id(get_cell_alternative_tile(at_coord))

func random_init():
	var width = 5
	var height = 5
	
	var random_tiles = MapManager.get_all_tile_names()
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
			var coords: = Vector2i(x, y)
			row.append([get_cell_s(coords), get_cell_alternative_tile(coords)])
		rows.append(row)
	
	return {"start_x": start_x, "start_y": start_y, "has_alt_ids": true, "tiles": rows}

func deserialize(data: Dictionary) -> void:
	clear()
	
	var tile_data: = data['tiles'] as Array
	var sx: = int(data['start_x'])
	var sy: = int(data['start_y'])
	
	var has_alt_ids: bool = data.get("has_alt_ids", false)
	
	for y in tile_data.size():
		var row = tile_data[y]
		for x in row.size():
			var coords: = Vector2i(x + sx, y + sy)
			var tile_source_id: int = int(row[x][0]) if has_alt_ids else int(row[x])
			if not tile_set.has_source(tile_source_id):
				continue
			if has_alt_ids:
				set_cell_s(coords, int(row[x][0]), Utility.facing_from_tile_alt_id(int(row[x][1])))
			else:
				set_cell_s(coords, int(row[x]))
