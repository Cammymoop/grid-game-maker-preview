extends ConfirmationDialog

signal hidden
signal picked_texture(texture_id: int, texture_index: int)
signal picked_raw_texture(texture: Texture2D, texture_rect: Rect2, picked_index: int, texture_info: Dictionary)

const TilePicker = preload("res://src/GameEditor/TilePicker.gd")

@export var tile_picker: TilePicker

var select_menu: PopupMenu

var selected_texture: int
var raw_mode: bool = false

var raw_texture_info: Dictionary

var HEIGHT_ADD = 110

func _ready() -> void:
	select_menu = find_child("TextureSelector").get_popup()
	confirmed.connect(emit_picked_texture)
	hidden.connect(queue_free)

func setup(texture_id, sub_index):
	raw_mode = false
	visibility_changed.connect(Callable(self, "_on_vis_changed"))
	var tex_ids: = TextureManager.get_current_texture_ids()
	var tex_list = TextureManager.get_current_texture_names()
	
	var tex_menu: PopupMenu = find_child("TextureSelector").get_popup()
	tex_menu.clear()
	for i in tex_ids.size():
		tex_menu.add_item(tex_list[i], tex_ids[i])
	
	tex_menu.id_pressed.connect(set_texture)

	if not is_inside_tree():
		await ready
	set_texture(texture_id)
	tile_picker.set_selected_index(sub_index)

func setup_raw(texture_name: String = "", is_builtin: bool = true, is_shared: bool = false, current_index: int = 0):
	raw_mode = true
	var tex_selector = find_child("TextureSelector")
	if not select_menu:
		select_menu = tex_selector.get_popup()

	if not texture_name:
		var all_textures_info: = TextureManager.get_all_possible_textures_info()
		if all_textures_info.size() == 0:
			push_error("No textures found")
			return
		texture_name = all_textures_info[0]["texture_name"]
		is_builtin = all_textures_info[0]["is_builtin"]
		is_shared = all_textures_info[0]["is_shared"]
		current_index = 0
	
	raw_texture_info = { "texture_name": texture_name, "is_builtin": is_builtin, "is_shared": is_shared }

	var tex: = TextureManager.get_texture_by_name(texture_name, is_builtin, is_shared)
	var metadata: = TextureManager.get_texture_metadata_by_name(texture_name, is_builtin, is_shared)
	tile_picker.set_raw_texture(tex, metadata)
	tile_picker.set_selected_index(current_index)
	
	setup_raw_list()
	tex_selector.text = texture_name
	if not is_builtin:
		tex_selector.text += (" (bundled)" if not is_shared else " (shared)")


func setup_raw_list():
	select_menu.clear()
	var all_textures_info: = TextureManager.get_all_possible_textures_info()
	
	var has_builtin_separator: bool = false
	var has_bundled_separator: bool = false
	var has_shared_separator: bool = false
	for texture_info in all_textures_info:
		if texture_info["is_builtin"]:
			if not has_builtin_separator:
				select_menu.add_separator("Builtin")
				has_builtin_separator = true
		elif not texture_info["is_shared"]:
			if not has_bundled_separator:
				select_menu.add_separator("Bundled")
				has_bundled_separator = true
		elif not has_shared_separator:
			select_menu.add_separator("Shared")
			has_shared_separator = true

		select_menu.add_item(texture_info["texture_name"])
		var idx: = select_menu.item_count - 1
		select_menu.set_item_metadata(idx, texture_info)
	
	select_menu.index_pressed.connect(on_raw_texture_selected)

	

func set_texture(texture_id: int):
	if raw_mode:
		return
	selected_texture = texture_id
	
	tile_picker.set_picking_texture(texture_id)
	var tex_selector = find_child("TextureSelector")
	var idx: int = tex_selector.get_popup().get_item_index(texture_id)
	tex_selector.text = tex_selector.get_popup().get_item_text(idx)
	
	reshrink()

func reshrink() -> void:
	await get_tree().process_frame
	size = get_child(0).size


func on_raw_texture_selected(index: int) -> void:
	var texture_info: Dictionary = select_menu.get_item_metadata(index)
	raw_texture_info = texture_info.duplicate()
	
	var texture_name: = raw_texture_info["texture_name"] as String
	var is_builtin: = raw_texture_info["is_builtin"] as bool
	var is_shared: = raw_texture_info["is_shared"] as bool
	
	var tex: = TextureManager.get_texture_by_name(texture_name, is_builtin, is_shared)
	var metadata: = TextureManager.get_texture_metadata_by_name(texture_name, is_builtin, is_shared)
	tile_picker.set_raw_texture(tex, metadata)
	
	var tex_selector = find_child("TextureSelector")
	var display_name: String = texture_name
	if not is_builtin:
		display_name += (" (bundled)" if not is_shared else " (shared)")
	tex_selector.text = display_name
	

func get_selected_texture() -> int:
	return selected_texture

func get_selected_sub_index() -> int:
	return tile_picker.selected_sub_index

func get_picked_raw_texture() -> Texture2D:
	if not raw_mode:
		return null
	return tile_picker.get_raw_texture()

func _on_TilePicker_resized():
	size.y = HEIGHT_ADD + tile_picker.size.y

func _on_vis_changed():
	if not visible:
		hidden.emit()

func emit_picked_texture() -> void:
	if raw_mode:
		var picked_index: = get_selected_sub_index()
		var texture_name: = raw_texture_info["texture_name"] as String
		var is_builtin: = raw_texture_info["is_builtin"] as bool
		var is_shared: = raw_texture_info["is_shared"] as bool

		var rect_for_index: = Utility.get_raw_indexed_atlas_rect(texture_name, is_builtin, is_shared, picked_index)
		var tex: = get_picked_raw_texture()
		picked_raw_texture.emit(tex, rect_for_index, picked_index, raw_texture_info)
	else:
		picked_texture.emit(get_selected_texture(), get_selected_sub_index())

func _on_tile_picker_confirmed() -> void:
	confirmed.emit()
	hide()
