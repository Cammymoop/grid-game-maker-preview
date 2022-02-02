extends TileMap

func _ready():
	randomize()
	var width = 12
	var height = 12
	
	for i in range(width):
		for j in range(height):
			set_cell(i, j, random_int_range(0, 2))

func random_int_range(start: int, end_exclusive: int):
	return start + floor(randf() * (end_exclusive - start))
