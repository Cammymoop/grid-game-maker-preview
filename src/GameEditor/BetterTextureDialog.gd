extends ConfirmationDialog

var selected_texture

var HEIGHT_ADD = 110

func setup(texture_index, sub_index):
	var tex_list = TextureManager.get_texture_name_list()
	
	var tex_menu:PopupMenu = find_node("TextureSelector").get_popup()
	tex_menu.clear()
	for i in range(len(tex_list)):
		tex_menu.add_item(tex_list[i])
	
	tex_menu.connect("index_pressed", self, "set_texture")
	
	set_texture(texture_index)
	find_node("TilePicker").set_selected_index(sub_index)

func set_texture(texture_index):
	selected_texture = texture_index
	
	find_node("TilePicker").set_texture(texture_index)
	var tex_selector = find_node("TextureSelector")
	tex_selector.text = tex_selector.get_popup().get_item_text(texture_index)

func get_selected_texture() -> int:
	return selected_texture

func get_selected_sub_index() -> int:
	return find_node("TilePicker").selected_sub_index


func _on_TilePicker_resized():
	rect_size.y = HEIGHT_ADD + find_node("TilePicker").rect_size.y
