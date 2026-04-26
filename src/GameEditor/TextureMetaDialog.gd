extends ConfirmationDialog

const Vector2iInput = preload("res://src/GameEditor/ConditionalEditor/vector2i_input.gd")

signal hidden
signal meta_confirmed(texture_definition)

@export var is_new_mode: bool = true
@export var texture_name: String = ""

@export var grid_size_input: Vector2iInput
@export var image_size_in_tiles_input: Vector2iInput
@export var border_width_input: Vector2iInput
@export var separation_input: Vector2iInput

func _ready():
	if not is_new_mode:
		title = "Set Grid for " + texture_name
	else:
		title = "New Image"
	image_size_in_tiles_input.visible = is_new_mode

	visibility_changed.connect(_on_vis_changed)
	hidden.connect(queue_free)

func load_meta(metadata: Dictionary) -> void:
	if metadata.has("tile_size"):
		grid_size_input.set_value(metadata["tile_size"])
	if metadata.has("border"):
		border_width_input.set_value(metadata["border"])
	if metadata.has("separation"):
		separation_input.set_value(metadata["separation"])
	#find_child("TileWidth").value = metadata.tile_size.x
	#find_child("TexWidth").value = metadata.size_in_tiles.x
	#find_child("HBorder").value = metadata.border.x
	#find_child("HSep").value = metadata.separation.x
	#find_child("TileHeight").value = metadata.tile_size.y
	#find_child("TexHeight").value = metadata.size_in_tiles.y
	#find_child("VBorder").value = metadata.border.y
	#find_child("VSep").value = metadata.separation.y

func _on_TextureMetaDialog_confirmed():
	#var t_width = find_child("TileWidth").value
	#var h_tiles = find_child("TexWidth").value
	#var h_border = find_child("HBorder").value
	#var h_sep = find_child("HSep").value
	#var t_height = find_child("TileHeight").value
	#var v_tiles = find_child("TexHeight").value
	#var v_border = find_child("VBorder").value
	#var v_sep = find_child("VSep").value
	#
	#var width = (t_width * h_tiles) + ((h_tiles - 1) * h_sep) + (h_border * 2)
	#var height = (t_height * v_tiles) + ((v_tiles - 1) * v_sep) + (v_border * 2)
	
	var edited_meta: = {
		tile_size = Vector2(grid_size_input.get_value()),
		border = Vector2(border_width_input.get_value()),
		separation = Vector2(separation_input.get_value()),
	}

	if is_new_mode:
		var total_size: Vector2 = edited_meta["tile_size"] * edited_meta["size_in_tiles"]
		total_size += edited_meta["separation"] * (edited_meta["size_in_tiles"] - 1)
		total_size += edited_meta["border"] * 2
		edited_meta["size"] = total_size
		edited_meta["size_in_tiles"] = image_size_in_tiles_input.get_value()
	
	meta_confirmed.emit(edited_meta)

func _on_vis_changed():
	if not visible:
		hidden.emit()