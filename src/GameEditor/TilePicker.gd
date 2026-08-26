extends TextureRect

signal confirmed
signal size_changed

@export var confirm_on_dbl_click: = true
@export var max_tile_upscale_enabled: = false
@export var max_tile_upscale_scales_below_one: = false
@export var max_tile_upscale: Vector2 = Vector2(64, 64)

@export var sel_cursor: Control
@export var hover_cursor: Control
@export var transparency_cursor: Control

var transparency_cursor_enabled: bool = true

var cur_texture_id: int
var tile_size: Vector2
var origin: Vector2
var separation: Vector2
var is_multiple_tiles: bool
# tiles per row
var rows: int
var tpr: int

var view_scale: float = 1.0

var raw_mode = false

var selected_sub_index = 0

var NO_DARKEN = Color(1, 1, 1)
var DARKEN = Color(.7, .7, .7)

var has_target_size: bool = false
var target_size: Vector2 = Vector2.ZERO

var has_loaded: bool = false

func _ready() -> void:
	transparency_cursor.visible = transparency_cursor_enabled
	if not transparency_cursor_enabled:
		transparency_cursor.process_mode = Control.PROCESS_MODE_DISABLED


func _gui_input(event):
	if event is InputEventMouseMotion:
		var index = get_tile_index_from_scaled_pos(event.position)
		if is_index_in_bounds(index):
			hovered_over_index(index)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			var index = get_tile_index_from_scaled_pos(event.position)
			if is_index_in_bounds(index):
				set_selected_index(index)
				hovered_over_index(index)
				if event.double_click and confirm_on_dbl_click:
					confirmed.emit()

func get_tile_index_from_texture_pos(pos: Vector2) -> int:
	return Utility.pixel_to_tile_index(pos, tile_size, origin, separation, tpr)

func get_tile_index_from_scaled_pos(pos: Vector2) -> int:
	return Utility.pixel_to_tile_index(pos / view_scale, tile_size, origin, separation, tpr)

func is_limit_upscale_by_tile_size() -> bool:
	if not max_tile_upscale_enabled:
		return false
	return is_multiple_tiles

func set_view_scale(new_scale) -> void:
	view_scale = new_scale
	update_transparency_cursor_size()
	refresh_highlighted_tile()
	make_atlas_tex()
	set_minsize()

func set_target_size(new_size: Vector2) -> void:
	if new_size == Vector2.ZERO:
		has_target_size = false
		return
	target_size = new_size
	has_target_size = true
	update_target_size()

func _scaled_tile_size(by_scale: float) -> Vector2:
	return tile_size * by_scale

func update_target_size() -> void:
	if has_target_size and has_loaded and texture and texture.get_size().length() > 2:
		var texture_size: = texture.get_size()
		var calculated_scale: float = float(Utility.max_integer_scale_in(texture_size, target_size))
		if calculated_scale == 0:
			calculated_scale = float(Utility.max_integer_scale_in(texture_size, target_size * 4) / 4.0)
			calculated_scale = maxf(0.25, calculated_scale)

		if is_limit_upscale_by_tile_size():
			var first_calculated: = calculated_scale
			var upscaled_tile_size: = _scaled_tile_size(calculated_scale)
			while upscaled_tile_size.x > max_tile_upscale.x or upscaled_tile_size.y > max_tile_upscale.y:
				if calculated_scale >= 2:
					calculated_scale -= 1
				elif not max_tile_upscale_scales_below_one and first_calculated >= 1:
					calculated_scale = 1
					break
				else:
					calculated_scale -= 0.25
				upscaled_tile_size = _scaled_tile_size(calculated_scale)

				if calculated_scale == 0:
					calculated_scale = 0.125
					break
		set_view_scale(calculated_scale)

func set_minsize() -> void:
	custom_minimum_size = texture.get_size() * view_scale
	update_minimum_size()
	size_changed.emit()

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
	is_multiple_tiles = metadata.get("is_multiple_tiles", true)
	var grid_cells: = Utility.get_tile_atlas_coords_size(tex.get_size(), tile_size, origin, separation)
	if not is_multiple_tiles:
		grid_cells = Vector2i.ONE
		var single_tile_rect: = Utility.get_rect_in_single_tile_texture_with_border(tex.get_size(), origin)
		tile_size = single_tile_rect.size
	tpr = grid_cells.x
	rows = grid_cells.y
	texture = tex

	raw_mode = true
	has_loaded = true

	make_atlas_tex()
	update_transparency_cursor_size()
	custom_minimum_size = tex.get_size() * view_scale
	if has_target_size:
		update_target_size()
	else:
		set_minsize()

func get_raw_texture() -> Texture2D:
	if not raw_mode:
		return null
	return texture

func set_picking_texture(texture_id: int) -> void:
	cur_texture_id = texture_id
	
	var tex = TextureManager.get_texture(texture_id)
	var meta = TextureManager.get_texture_metadata(texture_id).duplicate_deep()
	tile_size = meta['tile_size']
	origin = meta['border']
	separation = meta['separation']
	is_multiple_tiles = meta.get("is_multiple_tiles", true)
	var grid_cells: = Utility.get_tile_atlas_coords_size(tex.get_size(), tile_size, origin, separation)
	if not is_multiple_tiles:
		grid_cells = Vector2i.ONE
		var single_tile_rect: = Utility.get_rect_in_single_tile_texture_with_border(tex.get_size(), origin)
		tile_size = single_tile_rect.size
	tpr = grid_cells.x
	rows = grid_cells.y
	texture = tex

	raw_mode = false
	has_loaded = true
	
	make_atlas_tex()
	update_transparency_cursor_size()
	if has_target_size:
		update_target_size()
	else:
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
	refresh_highlighted_tile()
	set_selected_index(selected_sub_index)

func set_selected_index(new_selected_index):
	new_selected_index = clampi(new_selected_index, 0, (tpr * rows) - 1)
	selected_sub_index = new_selected_index
	
	show_only_selected()

func _update_control_offsets_by_rect(control: Control, rect: Rect2) -> void:
	control.offset_left = rect.position.x
	control.offset_right = rect.end.x
	control.offset_top = rect.position.y
	control.offset_bottom = rect.end.y

func _set_cursor_scaled_rect(the_cursor: Control, rect: Rect2) -> void:
	_update_control_offsets_by_rect(the_cursor, rect)

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

func hovered_over_index(hovered_index: int) -> void:
	self_modulate = DARKEN
	highlight_index(hovered_index)
	show_hovered_cursor_at_index(hovered_index)

func show_hovered_cursor_at_index(at_index: int) -> void:
	if not sel_cursor.visible:
		sel_cursor.show()
		_set_cursor_scaled_rect(sel_cursor, _get_scaled_index_rect(selected_sub_index))
	_set_cursor_scaled_rect(hover_cursor, _get_scaled_index_rect(at_index))
	if transparency_cursor_enabled:
		_set_cursor_scaled_rect(transparency_cursor, _get_scaled_index_rect(at_index))

func show_only_selected() -> void:
	sel_cursor.hide()
	_set_cursor_scaled_rect(hover_cursor, _get_scaled_index_rect(selected_sub_index))
	if transparency_cursor_enabled:
		_set_cursor_scaled_rect(transparency_cursor, _get_scaled_index_rect(selected_sub_index))


func highlight_index(hovered_index):
	var scaled_rect: = _get_scaled_index_rect(hovered_index)
	_update_control_offsets_by_rect($HighlightedTile, scaled_rect)
	$HighlightedTile.texture.region.position = _get_index_offset(hovered_index)

func refresh_highlighted_tile() -> void:
	_update_control_offsets_by_rect($HighlightedTile, _get_scaled_index_rect(selected_sub_index))
	$HighlightedTile.texture.region.position = _get_index_offset(selected_sub_index)


func _on_TilePicker_mouse_entered():
	self_modulate = DARKEN

func _on_TilePicker_mouse_exited():
	unhighlight_all()

func unhighlight_all() -> void:
	self_modulate = NO_DARKEN
	show_only_selected()

func update_transparency_cursor_size() -> void:
	if not transparency_cursor_enabled:
		return
	var atlas_tex = transparency_cursor.texture as AtlasTexture
	if atlas_tex:
		var scaled_size: = tile_size * view_scale
		var tp_center: Vector2 = (atlas_tex.atlas.get_size() / 2).floor()
		atlas_tex.region = Rect2(tp_center - (scaled_size / 2), scaled_size)