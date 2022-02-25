extends ConfirmationDialog

signal meta_confirmed(texture_definition)
signal done

func _ready():
	connect("popup_hide", self, "queue_free")
#
#func closed() -> void:
#	emit_signal("done")
#	queue_free()

func load_meta(metadata) -> void:
	find_node("TileWidth").value = metadata.tile_size.x
	find_node("TexWidth").value = metadata.size_in_tiles.x
	find_node("HBorder").value = metadata.border.x
	find_node("HSep").value = metadata.separation.x
	find_node("TileHeight").value = metadata.tile_size.y
	find_node("TexHeight").value = metadata.size_in_tiles.y
	find_node("VBorder").value = metadata.border.y
	find_node("VSep").value = metadata.separation.y

func _on_TextureMetaDialog_confirmed():
	var t_width = find_node("TileWidth").value
	var h_tiles = find_node("TexWidth").value
	var h_border = find_node("HBorder").value
	var h_sep = find_node("HSep").value
	var t_height = find_node("TileHeight").value
	var v_tiles = find_node("TexHeight").value
	var v_border = find_node("VBorder").value
	var v_sep = find_node("VSep").value
	
	var width = (t_width * h_tiles) + ((h_tiles - 1) * h_sep) + (h_border * 2)
	var height = (t_height * v_tiles) + ((v_tiles - 1) * v_sep) + (v_border * 2)
	
	var texture_meta = {
		size = Vector2(width, height),
		tile_size = Vector2(t_width, t_height),
		size_in_tiles = Vector2(h_tiles, v_tiles),
		border = Vector2(h_border, v_border),
		separation = Vector2(h_sep, v_sep),
	}
	
	emit_signal("done", texture_meta)
	emit_signal("meta_confirmed", texture_meta)
