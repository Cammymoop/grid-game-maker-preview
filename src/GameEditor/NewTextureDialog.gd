extends ConfirmationDialog

signal hidden

signal make_new_texture(texture_definition)

func _ready():
	visibility_changed.connect(_on_vis_changed)

func _on_NewTextureDialog_confirmed():
	var t_width = find_child("TileWidth").value
	var h_tiles = find_child("TexWidth").value
	var h_border = find_child("HBorder").value
	var h_sep = find_child("HSep").value
	var t_height = find_child("TileHeight").value
	var v_tiles = find_child("TexHeight").value
	var v_border = find_child("VBorder").value
	var v_sep = find_child("VSep").value
	
	var width = (t_width * h_tiles) + ((h_tiles - 1) * h_sep) + (h_border * 2)
	var height = (t_height * v_tiles) + ((v_tiles - 1) * v_sep) + (v_border * 2)
	
	var texture_meta = {
		size = Vector2(width, height),
		tile_size = Vector2(t_width, t_height),
		size_in_tiles = Vector2(h_tiles, v_tiles),
		border = Vector2(h_border, v_border),
		separation = Vector2(h_sep, v_sep),
	}
	
	emit_signal("make_new_texture", texture_meta)

func _on_vis_changed():
	if not visible:
		hidden.emit()