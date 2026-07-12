extends ConfirmationDialog

signal hidden
signal picked_texture(texture_id: int, texture_index: int)

var selected_texture: int

var HEIGHT_ADD = 110

func setup(texture_id, sub_index):
	visibility_changed.connect(Callable(self, "_on_vis_changed"))
	var tex_ids: = TextureManager.get_current_texture_ids()
	var tex_list = TextureManager.get_current_texture_names()
	
	var tex_menu:PopupMenu = find_child("TextureSelector").get_popup()
	tex_menu.clear()
	for i in tex_ids.size():
		tex_menu.add_item(tex_list[i], tex_ids[i])
	
	tex_menu.id_pressed.connect(set_texture)
	hidden.connect(queue_free)

	if not is_inside_tree():
		await ready
	set_texture(texture_id)
	find_child("TilePicker").set_selected_index(sub_index)
	
	confirmed.connect(emit_picked_texture)
	

func set_texture(texture_id: int):
	selected_texture = texture_id
	
	find_child("TilePicker").set_picking_texture(texture_id)
	var tex_selector = find_child("TextureSelector")
	var idx: int = tex_selector.get_popup().get_item_index(texture_id)
	tex_selector.text = tex_selector.get_popup().get_item_text(idx)
	
	reshrink()

func reshrink() -> void:
	await get_tree().process_frame
	size = get_child(0).size
	

func get_selected_texture() -> int:
	return selected_texture

func get_selected_sub_index() -> int:
	return find_child("TilePicker").selected_sub_index


func _on_TilePicker_resized():
	size.y = HEIGHT_ADD + find_child("TilePicker").size.y

func _on_vis_changed():
	if not visible:
		hidden.emit()

func emit_picked_texture() -> void:
	picked_texture.emit(get_selected_texture(), get_selected_sub_index())

func _on_tile_picker_confirmed() -> void:
	confirmed.emit()
	hide()
