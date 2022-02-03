extends TextureRect

var index_of_texture
var tiles_per_row

var selected_sub_index = 0

var NO_DARKEN = Color(1, 1, 1)
var DARKEN = Color(.5, .5, .5)

func _gui_input(event):
	if event is InputEventMouseMotion:
		var x_tile = floor(event.position.x / MapManager.tile_width)
		var y_tile = floor(event.position.y / MapManager.tile_width)
		
		var index = int(x_tile + (y_tile * tiles_per_row))
		highlight_index(index)
	elif event is InputEventMouseButton:
		var x_tile = floor(event.position.x / MapManager.tile_width)
		var y_tile = floor(event.position.y / MapManager.tile_width)
		
		var index = int(x_tile + (y_tile * tiles_per_row))
		set_selected_index(index)

func set_texture(texture_index):
	index_of_texture = texture_index
	tiles_per_row = TextureManager.get_tiles_per_row(texture_index)
	var tex = TextureManager.get_texture(texture_index)
	texture = tex
	
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, 32, 32)
	$HighlightedTile.texture = atlas
	
	if selected_sub_index > TextureManager.get_last_sub_index(texture_index):
		selected_sub_index = 0
	set_selected_index(selected_sub_index)

func set_selected_index(index):
	selected_sub_index = index
	
	var offset = TextureManager.get_index_offset(index_of_texture, index)
	$Cursor.margin_left = offset.x
	$Cursor.margin_right = offset.x + MapManager.tile_width
	$Cursor.margin_top = offset.y
	$Cursor.margin_bottom = offset.y + MapManager.tile_width

func highlight_index(hovered_index):
	var offset = TextureManager.get_index_offset(index_of_texture, hovered_index)
	$HighlightedTile.margin_left = offset.x
	$HighlightedTile.margin_top = offset.y
	
	$HighlightedTile.texture.region.position = offset
	


func _on_TilePicker_mouse_entered():
	self_modulate = DARKEN

func _on_TilePicker_mouse_exited():
	self_modulate = NO_DARKEN
