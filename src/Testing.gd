extends TileMapLayer

func _ready():
	randomize()
	var width = 12
	var height = 12
	
	for i in range(width):
		for j in range(height):
			set_cell(Vector2i(i, j), 0, Vector2i(random_int_range(0, 2), 0))

func random_int_range(start: int, end_exclusive: int):
	return start + floor(randf() * (end_exclusive - start))
