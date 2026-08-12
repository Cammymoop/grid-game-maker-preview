extends VBoxContainer

signal selected_item_changed(item: SelectableTexture)
signal request_refresh_list()

const SelectableTexture = preload("res://src/GameEditor/SelectableTexture.gd")
const ImagesTab = preload("res://src/GameEditor/ImagesEditor.gd")

var item_scene: = preload("res://Scenes/GameEditor/SelectableTexItem.tscn")

var all_textures: Array = []
var enabled_textures: Array = []

var images_editor: ImagesTab

const CTX_EXPORT_IMAGE_FILE = 1

const CTX_REMOVE_USAGE = 5
const CTX_REMAP_TO_ANOTHER = 6

const CTX_EDIT_METADATA = 10

const CTX_MAKE_BUNDLED = 15
const CTX_DUPLICATE_AS_SHARED = 16
const CTX_DUPLICATE_AS_BUNDLED = 17

const CTX_DELETE_IMAGE_FILE = 40


func init(editor: ImagesTab) -> void:
	images_editor = editor

func clear_all() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	enabled_textures = []
	all_textures = []

func add_texture(texture_name: String, texture: Texture, builtin: bool, enabled: bool, is_shared: bool = true, with_metadata: Dictionary = {}) -> void:
	all_textures.append(texture_name)
	if enabled:
		enabled_textures.append(texture_name)
	
	var list_item: = item_scene.instantiate() as SelectableTexture
	list_item.set_texture(texture_name, texture, builtin, is_shared)
	list_item.set_texture_metadata(with_metadata)
	list_item.set_enabled(enabled)
	list_item.selected.connect(on_item_selected)
	list_item.enable_toggled.connect(on_texture_item_enabled_toggled)
	list_item.double_clicked.connect(on_item_double_clicked)
	list_item.request_context_menu.connect(on_item_request_context_menu)
	
	add_child(list_item)

func on_texture_item_enabled_toggled(item: SelectableTexture, new_is_enabled: bool) -> void:
	if not new_is_enabled:
		if not remove_used_item(item, false):
			item.set_enabled(true)
	else:
		images_editor.set_texture_item_enabled(item, true)

func remove_used_item(item: SelectableTexture, skip_remap: bool = false) -> bool:
	var loaded_texture_id: = _get_loaded_texture_id_from_item(item)
	if loaded_texture_id == -1 or not TextureManager.has_texture_id(loaded_texture_id):
		images_editor.disable_texture_item(item)
		return true

	if not skip_remap and TextureManager.is_texture_id_in_use(loaded_texture_id):
		images_editor.prompt_for_remap_used_item(item)
		return false
	
	images_editor.disable_texture_item(item)
	return true


func _get_loaded_texture_id_from_item(item: SelectableTexture) -> int:
	return TextureManager.get_loaded_texture_id(item.get_texture_name(), item.get_is_builtin(), item.get_is_shared())

func on_item_double_clicked(item: SelectableTexture) -> void:
	images_editor.edit_texture_from_selectable_texture(item)

func texture_item_count() -> int:
	var count: int = 0
	for child in get_children():
		if child is SelectableTexture:
			count += 1
	return count

func select_first_item() -> void:
	if texture_item_count() > 0:
		var first_item: = get_child(0) as SelectableTexture
		if first_item:
			deselect_other_items(first_item)
			first_item.select()

func get_selected() -> SelectableTexture:
	for c in get_children():
		if c is SelectableTexture and c.is_selected:
			return c
	return null

func deselect_other_items(item: SelectableTexture) -> void:
	for c in get_children():
		if item == c or not c is SelectableTexture:
			continue
		c.deselect()

func on_item_selected(item: SelectableTexture) -> void:
	deselect_other_items(item)
	selected_item_changed.emit(item)
	images_editor.enable_edit_button()

func sort_items() -> void:
	var items: Array[SelectableTexture] = []
	for child_item in get_children():
		if child_item is SelectableTexture:
			items.append(child_item)
		remove_child(child_item)
	items.sort_custom(texture_item_order)
	var previous_enabled: bool = true
	for sorted_item in items:
		if not sorted_item.is_enabled() and previous_enabled:
			previous_enabled = false
			if items.find(sorted_item) > 0:
				var h_sep: = HSeparator.new()
				add_child(h_sep)
		add_child(sorted_item)

func texture_item_order(item_a: SelectableTexture, item_b: SelectableTexture) -> bool:
	var name_a: = item_a.get_texture_name()
	var name_b: = item_b.get_texture_name()
	
	var score_a: int = 100 * int(item_a.is_enabled())
	var score_b: int = 100 * int(item_b.is_enabled())
	
	score_a += int(item_a.get_is_builtin())
	score_b += int(item_b.get_is_builtin())
	
	if score_a != score_b:
		return score_a > score_b
	return name_a.nocasecmp_to(name_b) < 0

func on_item_request_context_menu(item: SelectableTexture) -> void:
	show_context_menu(item)

func show_context_menu(for_item: SelectableTexture) -> void:
	if not for_item:
		return
	var context_menu = Utility.get_empty_context_menu()
	if OS.has_feature("web"):
		context_menu.add_item("Export Image", CTX_EXPORT_IMAGE_FILE)
		context_menu.add_separator()
	
	var texture_id: = _get_loaded_texture_id_from_item(for_item)
	if texture_id != -1:
		if TextureManager.is_texture_id_in_use(texture_id):
			context_menu.add_item("Set Unused (will reset all entity/tile usage)", CTX_REMOVE_USAGE)
			context_menu.add_item("Redirect entity/tile usage to another image", CTX_REMAP_TO_ANOTHER)
		else:
			context_menu.add_item("Set Unused (no entities/tiles will be affected)", CTX_REMOVE_USAGE)
		context_menu.add_separator()


	if for_item.get_is_builtin() or for_item.get_is_shared():
		context_menu.add_item("Change to Bundled Image", CTX_MAKE_BUNDLED)
	context_menu.add_item("Duplicate (Bundled copy)", CTX_DUPLICATE_AS_BUNDLED)
	context_menu.add_item("Duplicate (Shared copy)", CTX_DUPLICATE_AS_SHARED)
	if not for_item.get_is_builtin():
		if texture_id == -1:
			context_menu.add_separator()
			context_menu.add_item("Delete Image", CTX_DELETE_IMAGE_FILE)
		context_menu.add_separator()
		context_menu.add_item("Edit Size/Border/Spacing", CTX_EDIT_METADATA)
	context_menu.id_pressed.connect(on_context_menu_id_pressed.bind(for_item))
	Utility.popup_context_menu_at_mouse(context_menu)

func on_context_menu_id_pressed(id: int, img_item: SelectableTexture) -> void:
	if not img_item or not is_ancestor_of(img_item):
		return
	var for_game_name: = "" if img_item.get_is_shared() else GameManager.get_identified_game_name()
	if not img_item.get_is_builtin() and not img_item.get_is_shared() and not for_game_name:
		push_error("context menu for bundled image but no game name available")
		return
	
	if id == CTX_EXPORT_IMAGE_FILE:
		export_image_on_web(img_item)
	elif id == CTX_DELETE_IMAGE_FILE:
		if img_item.get_is_builtin():
			return
		FilesManager.delete_local_image(img_item.get_texture_name(), for_game_name)
		request_refresh_list.emit()
	elif id == CTX_EDIT_METADATA:
		images_editor.edit_texture_metadata_for_item(img_item)
	elif id == CTX_REMOVE_USAGE:
		remove_used_item(img_item, true)
		request_refresh_list.emit()
	elif id == CTX_REMAP_TO_ANOTHER:
		images_editor.prompt_for_remap_used_item(img_item)
	elif id in [CTX_MAKE_BUNDLED, CTX_DUPLICATE_AS_BUNDLED, CTX_DUPLICATE_AS_SHARED]:
		handle_ctx_copy(id, img_item)

func handle_ctx_copy(id: int, img_item: SelectableTexture) -> void:
	if id == CTX_MAKE_BUNDLED:
		if img_item.get_is_builtin():
			TextureManager.make_builtin_image_bundled(img_item.get_texture_name())
		else:
			TextureManager.make_shared_image_bundled(img_item.get_texture_name())
		request_refresh_list.emit()
	elif id in [CTX_DUPLICATE_AS_BUNDLED, CTX_DUPLICATE_AS_SHARED]:
		var is_bundled_copy: = id == CTX_DUPLICATE_AS_BUNDLED
		prints("making bundled copy of %s" % [img_item.get_texture_name()])
		TextureManager.make_duplicate_of_image(not is_bundled_copy, img_item.get_texture_name(), img_item.get_is_builtin(), img_item.get_is_shared())
		request_refresh_list.emit()



func export_image_on_web(img_item: SelectableTexture) -> void:
	if not OS.has_feature("web"):
		return
	var is_builtin: = img_item.get_is_builtin()
	var save_to_name: = img_item.get_texture_name()
	var image_data_buffer: PackedByteArray
	if is_builtin:
		image_data_buffer = FilesManager.get_image_data_as_bytes(TextureManager.get_builtin_texture_as_image(save_to_name))
	else:
		var for_game_name: = "" if img_item.get_is_shared() else GameManager.get_identified_game_name()
		var img_file_path: String = FilesManager.get_local_image_path(save_to_name, for_game_name)
		if not img_file_path or not FilesManager.smarter_file_exists(img_file_path):
			push_error("Image file not found at path: %s" % [img_file_path])
			return
		image_data_buffer = FileAccess.get_file_as_bytes(img_file_path)
	JavaScriptBridge.download_buffer(image_data_buffer, save_to_name.trim_suffix(".png") + ".png", "image/png")