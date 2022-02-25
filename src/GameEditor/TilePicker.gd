extends TextureRect

var index_of_texture
var tile_size: Vector2
var origin: Vector2
var separation: Vector2
# tiles per row
var rows: int
var tpr: int

var scale: = 1

var raw_mode = false

var selected_sub_index = 0

var NO_DARKEN = Color(1, 1, 1)
var DARKEN = Color(.7, .7, .7)

func _gui_input(event):
	if event is InputEventMouseMotion:
		var index = tile_pos_to_index(local_pos_to_tile_pos(event.position))
		highlight_index(index)
	elif event is InputEventMouseButton:
		var index = tile_pos_to_index(local_pos_to_tile_pos(event.position))
		set_selected_index(index)

func set_scale(new_scale) -> void:
	scale = new_scale
	make_atlas_tex()
	rect_min_size = texture.get_size() * new_scale
	minimum_size_changed()

func local_pos_to_tile_pos(pos: Vector2) -> Vector2:
	pos /= scale
	pos -= origin
	pos -= (separation/2).floor()
	var combined_tile_size = tile_size + separation
	#print(combined_tile_size)
	return (pos / combined_tile_size).floor()
	

func tile_pos_to_index(pos: Vector2) -> int:
	return int(pos.x) + (int(pos.y) * tpr)

func set_raw_texture(tex: Texture, meta: Dictionary) -> void:
	index_of_texture = -1
	tpr = meta['size_in_tiles'].x
	rows = meta['size_in_tiles'].y
	tile_size = meta['tile_size']
	origin = meta['border']
	separation = meta['separation']
	texture = tex.duplicate()
	texture.flags = 0
	
	raw_mode = true
	
	make_atlas_tex()
	rect_min_size = tex.get_size() * scale
	minimum_size_changed()

func set_texture(texture_index) -> void:
	index_of_texture = texture_index
	
	var tex = TextureManager.get_texture(texture_index)
	var meta = TextureManager.get_texture_metadata(texture_index)
	tpr = meta['size_in_tiles'].x
	rows = meta['size_in_tiles'].y
	tile_size = meta['tile_size']
	origin = meta['border']
	separation = meta['separation']
	texture = tex
	
	make_atlas_tex()
	rect_min_size = tex.get_size() * scale
	minimum_size_changed()
	
func make_atlas_tex() -> void:
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2.ZERO, tile_size)
	$HighlightedTile.texture = atlas
	$HighlightedTile.rect_size = tile_size * scale
	
	var last_sub_index = (tpr * rows) - 1
	if selected_sub_index > last_sub_index:
		selected_sub_index = 0
	set_selected_index(selected_sub_index)
	highlight_index(selected_sub_index)

func set_selected_index(index):
	selected_sub_index = index
	
	var offset = Utility.get_texture_index_offset(index, tile_size, origin, separation, tpr) * scale
	$Cursor.margin_left = offset.x
	$Cursor.margin_right = offset.x + (tile_size.x * scale)
	$Cursor.margin_top = offset.y
	$Cursor.margin_bottom = offset.y + (tile_size.y * scale)

func get_picked_offset() -> Vector2:
	return Utility.get_texture_index_offset(selected_sub_index, tile_size, origin, separation, tpr)

func get_picked_region() -> Rect2:
	return Utility.get_texture_index_rect(selected_sub_index, tile_size, origin, separation, tpr)

func highlight_index(hovered_index):
	var base_offset = Utility.get_texture_index_offset(hovered_index, tile_size, origin, separation, tpr)
	var offset = base_offset * scale
	$HighlightedTile.margin_left = offset.x
	$HighlightedTile.margin_top = offset.y
	$HighlightedTile.margin_right = offset.x + (tile_size.x * scale)
	$HighlightedTile.margin_bottom = offset.y + (tile_size.y * scale)
	
	$HighlightedTile.texture.region.position = base_offset
	


func _on_TilePicker_mouse_entered():
	self_modulate = DARKEN

func _on_TilePicker_mouse_exited():
	self_modulate = NO_DARKEN
