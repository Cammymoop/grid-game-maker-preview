extends Control

var tile_brush_size: Vector2 = Vector2(32, 32)
@onready var my_size: Vector2 = size

func set_my_size(new_size: Vector2) -> void:
	my_size = new_size

func set_size_offset(new_size: Vector2, new_offset: Vector2) -> void:
	tile_brush_size = new_size
	
	set_offset(new_offset)

func set_offset(new_offset) -> void:
	update_visual(new_offset)

func update_visual(offset):
	var m_top = offset.y
	var m_bottom = - ((my_size.y - tile_brush_size.y) - offset.y)
	var m_left = offset.x
	var m_right = - ((my_size.x - tile_brush_size.x) - offset.x)
	
	$CrosshairBorder.offset_top = m_top
	$CrosshairCenter.offset_top = m_top
	$CrosshairBorder.offset_bottom = m_bottom
	$CrosshairCenter.offset_bottom = m_bottom
	$CrosshairBorder.offset_left = m_left
	$CrosshairCenter.offset_left = m_left
	$CrosshairBorder.offset_right = m_right
	$CrosshairCenter.offset_right = m_right
