extends ConfirmationDialog

const Vector2iInput = preload("res://src/GameEditor/ConditionalEditor/vector2i_input.gd")

signal hidden
signal meta_confirmed(texture_definition)

@export var is_new_mode: bool = true
@export var texture_name: String = ""

@export var is_multiple_tiles_toggle: CheckButton

@export var grid_size_input: Vector2iInput
@export var image_size_in_tiles_input: Vector2iInput
@export var border_width_input: Vector2iInput
@export var separation_input: Vector2iInput

@export var image_size_label: Control
@export var image_size_node_2: Control

var edit_shared_meta_warning: bool = false

func _ready():
	if not is_new_mode:
		title = "Update Grid Settings for " + texture_name
		ok_button_text = "Update Grid"
	else:
		title = "New Image"
		ok_button_text = "Create Image"
	
	find_child("SharedImageWarning").visible = edit_shared_meta_warning

	image_size_label.visible = is_new_mode
	image_size_node_2.visible = is_new_mode

	visibility_changed.connect(_on_vis_changed)
	hidden.connect(queue_free)

func load_meta(metadata: Dictionary) -> void:
	if metadata.has("tile_size"):
		prints("setting grid size input to", metadata["tile_size"])
		grid_size_input.set_value(metadata["tile_size"])
	if metadata.has("border"):
		border_width_input.set_value(metadata["border"])
	if metadata.has("separation"):
		separation_input.set_value(metadata["separation"])
	if metadata.get("is_multiple_tiles", true):
		is_multiple_tiles_toggle.set_pressed_no_signal(true)
	refresh_ui()

func refresh_ui() -> void:
	find_child("SharedImageWarning").visible = edit_shared_meta_warning
	var is_multiple: = is_multiple_tiles_toggle.button_pressed
	grid_size_input.disabled = not is_multiple
	image_size_in_tiles_input.disabled = not is_multiple
	#border_width_input.disabled = not is_multiple
	separation_input.disabled = not is_multiple


func _on_TextureMetaDialog_confirmed():
	var edited_meta: = {
		is_multiple_tiles = is_multiple_tiles_toggle.button_pressed,
		tile_size = Vector2(grid_size_input.get_value()),
		border = Vector2(border_width_input.get_value()),
		separation = Vector2(separation_input.get_value()),
	}

	if is_new_mode:
		edited_meta["size_in_tiles"] = Vector2(image_size_in_tiles_input.get_value()).max(Vector2.ONE)
		var total_size: Vector2 = edited_meta["tile_size"] * edited_meta["size_in_tiles"]
		total_size += edited_meta["separation"] * (edited_meta["size_in_tiles"] - Vector2.ONE)
		total_size += edited_meta["border"] * 2
		edited_meta["size"] = total_size
	
	meta_confirmed.emit(edited_meta)

func _on_vis_changed():
	if not visible:
		hidden.emit()