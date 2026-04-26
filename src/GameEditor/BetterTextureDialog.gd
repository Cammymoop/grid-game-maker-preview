extends ConfirmationDialog

signal hidden

var selected_texture

var HEIGHT_ADD = 110

func setup(texture_index, sub_index):
	visibility_changed.connect(Callable(self, "_on_vis_changed"))
	var tex_list = TextureManager.get_current_texture_names()
	prints("tex_list", tex_list)
	
	var tex_menu:PopupMenu = find_child("TextureSelector").get_popup()
	tex_menu.clear()
	for i in range(len(tex_list)):
		tex_menu.add_item(tex_list[i])
	
	tex_menu.connect("index_pressed", Callable(self, "set_texture"))
	hidden.connect(queue_free)

	if not is_inside_tree():
		await ready
	set_texture(texture_index)
	find_child("TilePicker").set_selected_index(sub_index)
	

func set_texture(texture_index):
	selected_texture = texture_index
	
	find_child("TilePicker").set_picking_texture(texture_index)
	var tex_selector = find_child("TextureSelector")
	tex_selector.text = tex_selector.get_popup().get_item_text(texture_index)
	
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

func _on_tile_picker_confirmed() -> void:
	confirmed.emit()
	hide()
