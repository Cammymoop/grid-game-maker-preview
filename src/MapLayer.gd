extends TileMap

func single_init(tile_index):
	var width = 12
	var height = 12
	for i in range(width):
		for j in range(height):
			set_cell(i, j, tile_index)

func random_init():
	var width = 12
	var height = 12
	
	var random_tiles = ['floor', 'floor2', 'floor2', 'greenery', 'water', 'wall']
	var random_ti = []
	for tile in random_tiles:
		random_ti.append(MapManager.get_tile_index(tile))
	
	for i in range(width):
		for j in range(height):
			set_cell(i, j, Utility.random_list_element(random_ti))
