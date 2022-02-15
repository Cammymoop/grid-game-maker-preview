extends TileMap

func single_init(tile_index):
	var width = GameManager.game_view.x
	var height = GameManager.game_view.y
	for i in range(width):
		for j in range(height):
			set_cell(i, j, tile_index)

func random_init():
	var width = GameManager.game_view.x
	var height = GameManager.game_view.y
	
	var random_tiles = ['floor', 'floor', 'floor', 'floor2', 'greenery', 'water', 'wall']
	var random_ti = []
	for tile in random_tiles:
		random_ti.append(MapManager.get_tile_index(tile))
	
	for i in range(width):
		for j in range(height):
			set_cell(i, j, Utility.random_list_element(random_ti))

func serialize() -> Dictionary:
	var rect = get_used_rect()
	var start_x = rect.position.x
	var start_y = rect.position.y
	var rows = []
	var x_range = range(start_x, rect.end.x)
	for y in range(start_y, rect.end.y):
		var row = []
		for x in x_range:
			row.append(get_cell(x, y))
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
			set_cell(j + sx, i + sy, row[j])
