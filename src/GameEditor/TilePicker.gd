extends TextureRect

signal confirmed

@export var confirm_on_dbl_click: = true

var cur_texture_id: int
var tile_size: Vector2
var origin: Vector2
var separation: Vector2
# tiles per row
var rows: int
var tpr: int

var view_scale: = 1

var raw_mode = false

var selected_sub_index = 0

var NO_DARKEN = Color(1, 1, 1)
var DARKEN = Color(.7, .7, .7)

func _gui_input(event):
	if event is InputEventMouseMotion:
		var index = get_tile_index_from_scaled_pos(event.position)
		if is_index_in_bounds(index):
			highlight_index(index)
	elif event is InputEventMouseButton:
		if event.is_pressed():
			var index = get_tile_index_from_scaled_pos(event.position)
			if is_index_in_bounds(index):
				set_selected_index(index)
				if event.double_click and confirm_on_dbl_click:
					confirmed.emit()

func get_tile_index_from_texture_pos(pos: Vector2) -> int:
	return Utility.pixel_to_tile_index(pos, tile_size, origin, separation, tpr)

func get_tile_index_from_scaled_pos(pos: Vector2) -> int:
	return Utility.pixel_to_tile_index(pos / view_scale, tile_size, origin, separation, tpr)

func set_view_scale(new_scale) -> void:
	view_scale = new_scale
	make_atlas_tex()
	set_minsize()

func set_minsize() -> void:
	custom_minimum_size = texture.get_size() * view_scale
	update_minimum_size()

func local_pos_to_tile_pos(pos: Vector2) -> Vector2:
	pos /= view_scale
	pos -= origin
	pos -= (separation/2).floor()
	var combined_tile_size = tile_size + separation
	#print(combined_tile_size)
	return (pos / combined_tile_size).floor()
	

func tile_pos_to_index(pos: Vector2) -> int:
	return int(pos.x) + (int(pos.y) * tpr)

func is_index_in_bounds(index: int) -> bool:
	return index >= 0 and index < tpr * rows

func set_raw_texture(tex: Texture2D, metadata: Dictionary) -> void:
	cur_texture_id = -1
	tile_size = metadata['tile_size']
	origin = metadata['border']
	separation = metadata['separation']
	var grid_cells: = Utility.get_tile_atlas_coords_size(tex.get_size(), tile_size, origin, separation)
	tpr = grid_cells.x
	rows = grid_cells.y
	texture = tex.duplicate()

	raw_mode = true
	
	make_atlas_tex()
	custom_minimum_size = tex.get_size() * view_scale
	update_minimum_size()

func set_picking_texture(texture_id: int) -> void:
	cur_texture_id = texture_id
	
	var tex = TextureManager.get_texture(texture_id)
	var meta = TextureManager.get_texture_metadata(texture_id).duplicate_deep()
	tile_size = meta['tile_size']
	origin = meta['border']
	separation = meta['separation']
	var grid_cells: = Utility.get_tile_atlas_coords_size(tex.get_size(), tile_size, origin, separation)
	tpr = grid_cells.x
	rows = grid_cells.y
	texture = tex
	
	make_atlas_tex()
	set_minsize()
	
func make_atlas_tex() -> void:
	var atlas = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(Vector2.ZERO, tile_size)
	$HighlightedTile.texture = atlas
	$HighlightedTile.size = tile_size * view_scale
	
	var last_sub_index = (tpr * rows) - 1
	if selected_sub_index > last_sub_index:
		selected_sub_index = 0
	set_selected_index(selected_sub_index)
	highlight_index(selected_sub_index)

func set_selected_index(index):
	selected_sub_index = index
	
	_set_cursor_scaled_rect(_get_scaled_index_rect(index))

func _update_control_offsets_by_rect(control: Control, rect: Rect2) -> void:
	control.offset_left = rect.position.x
	control.offset_right = rect.end.x
	control.offset_top = rect.position.y
	control.offset_bottom = rect.end.y

func _set_cursor_scaled_rect(rect: Rect2) -> void:
	_update_control_offsets_by_rect($Cursor, rect)

func _get_index_offset(index: int) -> Vector2:
	return Utility.get_indexed_tile_offset_by_per_row(index, tpr, tile_size, origin, separation)

func _get_scaled_index_offset(index: int) -> Vector2:
	return Utility.get_indexed_tile_offset_by_per_row(index, tpr, tile_size, origin, separation) * view_scale

func _get_index_rect(index: int) -> Rect2:
	return Rect2(_get_index_offset(index), tile_size)

func _get_scaled_index_rect(index: int) -> Rect2:
	var offset: = _get_scaled_index_offset(index)
	return Rect2(offset, tile_size * view_scale)

func get_picked_offset() -> Vector2:
	return _get_index_offset(selected_sub_index)

func get_picked_region() -> Rect2:
	return _get_index_rect(selected_sub_index)

func highlight_index(hovered_index):
	var scaled_rect: = _get_scaled_index_rect(hovered_index)
	_update_control_offsets_by_rect($HighlightedTile, scaled_rect)
	$HighlightedTile.texture.region.position = _get_index_offset(hovered_index)


func _on_TilePicker_mouse_entered():
	self_modulate = DARKEN

func _on_TilePicker_mouse_exited():
	self_modulate = NO_DARKEN
