extends VBoxContainer

const SelectableTexture = preload("res://src/GameEditor/SelectableTexture.gd")
const TextureMetaDialog = preload("res://src/GameEditor/TextureMetaDialog.gd")
const TileCompositor = preload("res://src/GameEditor/TileCompositor.gd")
const SelectableTextureList = preload("res://src/GameEditor/SelectableTextureList.gd")

var tile_compositor_scn = preload("res://Scenes/GameEditor/TileCompositor.tscn")
var metadata_dialog = preload("res://Scenes/GameEditor/TextureMetaDialog.tscn")

@onready var ui_root = find_parent("UIRoot")

@export var texture_item_list: SelectableTextureList
@export var edit_texture_button: Button

@export var convert_to_bundled_button: Button
@export var import_image_button: Button

@export var open_images_folder_button: Button

func _ready():
	if convert_to_bundled_button:
		convert_to_bundled_button.pressed.connect(make_all_used_shared_images_bundled)
	if OS.has_feature("web"):
		open_images_folder_button.disabled = true
		open_images_folder_button.visible = false
	if import_image_button:
		import_image_button.visible = OS.has_feature("web")
		import_image_button.pressed.connect(import_image_from_web)
	texture_item_list.init(self)
	texture_item_list.selected_item_changed.connect(on_selected_item_changed)
	
	edit_texture_button.pressed.connect(on_edit_texture_button_pressed)
	refresh_list()

func refresh_list():
	var all_builtin_textures: Dictionary = TextureManager.get_all_builtin_textures()
	var all_bundled_textures: Dictionary = TextureManager.get_all_bundled_textures()
	var all_shared_textures: Dictionary = TextureManager.get_all_shared_textures()
	
	texture_item_list.clear_all()
	disable_edit_button()
	var any_enabled_shared_images: bool = false
	for tex in all_builtin_textures:
		var is_enabled = TextureManager.is_builtin_loaded(tex)
		texture_item_list.add_texture(tex, all_builtin_textures[tex], true, is_enabled)
	for tex in all_bundled_textures:
		var is_enabled = TextureManager.is_local_file_loaded(tex, false)
		texture_item_list.add_texture(tex, all_bundled_textures[tex], false, is_enabled, false)
	for tex in all_shared_textures:
		var is_enabled = TextureManager.is_local_file_loaded(tex, true)
		if is_enabled:
			any_enabled_shared_images = true
		texture_item_list.add_texture(tex, all_shared_textures[tex], false, is_enabled, true)
	
	texture_item_list.sort_items()

	texture_item_list.select_first_item()
	if texture_item_list.get_selected():
		enable_edit_button()
	if convert_to_bundled_button:
		convert_to_bundled_button.disabled = not any_enabled_shared_images

func images_updated() -> void:
	refresh_list()
	TextureManager.refresh_textures()

func on_selected_item_changed(_item: SelectableTexture) -> void:
	enable_edit_button()

func enable_edit_button() -> void:
	edit_texture_button.disabled = false

func disable_edit_button() -> void:
	edit_texture_button.disabled = true

func on_edit_texture_button_pressed() -> void:
	var selected_item = texture_item_list.get_selected()
	edit_texture_from_selectable_texture(selected_item)

func _on_NewTexButton_pressed() -> void:
	var dialog: = metadata_dialog.instantiate() as TextureMetaDialog
	find_parent("UIRoot").add_popup_layer_node(dialog)
	dialog.popup_centered()
	
	dialog.meta_confirmed.connect(edit_new_texture)


func edit_texture_from_selectable_texture(sel_tex: SelectableTexture) -> void:
	if not sel_tex:
		return
	
	var is_builtin: = sel_tex.get_is_builtin()
	var is_shared: = sel_tex.get_is_shared()
	var texture_name: = sel_tex.get_texture_name()
	if sel_tex.is_enabled():
		var texture_id: int = TextureManager.get_loaded_texture_id(texture_name, is_builtin, is_shared)
		if texture_id != -1:
			edit_tex_continue(TextureManager.get_texture_metadata(texture_id), sel_tex)
		return
	
	if not TextureManager.unloaded_texture_has_metadata(texture_name, is_builtin, is_shared):
		if is_builtin:
			push_error("Builtin texture %s failed to get metadata" % texture_name)
			return
		var default_meta: Dictionary = TextureManager.create_metadata_for_texture(sel_tex.get_texture())
		var dialog: = metadata_dialog.instantiate() as TextureMetaDialog
		dialog.is_new_mode = false
		dialog.load_meta(default_meta)
		add_child(dialog)
		dialog.popup_centered()
		dialog.meta_confirmed.connect(create_texture_meta_and_edit.bind(sel_tex))
	else:
		var meta: Dictionary = TextureManager.get_unloaded_texture_meta(texture_name, is_builtin, is_shared)
		edit_tex_continue(meta, sel_tex)

func edit_texture_metadata_for_item(item: SelectableTexture) -> void:
	if not item or item.get_is_builtin():
		return
	var is_shared: = item.get_is_shared()
	var texture_name: = item.get_texture_name()
	
	var current_meta: Dictionary = TextureManager.get_unloaded_texture_meta(texture_name, false, is_shared)
	if not current_meta:
		current_meta = TextureManager.create_metadata_for_texture(item.get_texture())
	var edit_meta_dialog: = metadata_dialog.instantiate() as TextureMetaDialog
	edit_meta_dialog.is_new_mode = false
	edit_meta_dialog.edit_shared_meta_warning = item.get_is_shared()
	edit_meta_dialog.load_meta(current_meta)
	add_child(edit_meta_dialog)
	edit_meta_dialog.popup_centered()
	edit_meta_dialog.meta_confirmed.connect(on_confirm_meta_edit.bind(item))

func on_confirm_meta_edit(new_meta: Dictionary, for_item: SelectableTexture) -> void:
	TextureManager.set_texture_meta_by_name(for_item.get_texture_name(), false, for_item.get_is_shared(), new_meta)

func create_texture_meta_and_edit(new_meta: Dictionary, selected_item: SelectableTexture) -> void:
	var t_name: = selected_item.get_texture_name()
	var is_shared: = selected_item.get_is_shared()
	TextureManager.set_texture_meta_by_name(t_name, false, is_shared, new_meta)
	edit_tex_continue(new_meta, selected_item)

func edit_tex_continue(meta: Dictionary, selected_item: SelectableTexture) -> void:
	var tile_compositor: = tile_compositor_scn.instantiate() as TileCompositor
	tile_compositor.set_texture(selected_item.get_texture())
	tile_compositor.set_metadata(meta)
	if not selected_item.get_is_builtin():
		if not selected_item.get_is_shared():
			push_error("Texture inside game not implemented yet")
		else:
			tile_compositor.set_filename(selected_item.texture_name)
	ui_root.add_popup_layer_node(tile_compositor)
	tile_compositor.popup_centered()
	
	tile_compositor.hidden.connect(images_updated)

func edit_new_texture(texture_meta: Dictionary) -> void:
	var tile_compositor: = tile_compositor_scn.instantiate() as TileCompositor
	tile_compositor.set_new_texture_size(texture_meta['size'])
	tile_compositor.set_metadata(texture_meta)
	ui_root.add_popup_layer_node(tile_compositor)
	tile_compositor.popup_centered()
	
	tile_compositor.hidden.connect(images_updated)


func set_texture_item_enabled(item: SelectableTexture, new_is_enabled: bool) -> void:
	if new_is_enabled:
		enable_texture_item(item)
	else:
		disable_texture_item(item)
	images_updated()

func disable_texture_item(item: SelectableTexture) -> void:
	TextureManager.remove_loaded_texture_by_name(item.get_texture_name(), item.get_is_builtin(), item.get_is_shared())

func enable_texture_item(item: SelectableTexture) -> void:
	if item.get_is_builtin():
		TextureManager.add_builtin_texture(item.get_texture_name())
	elif item.get_is_shared():
		if not FilesManager.has_local_image_metadata(item.get_texture_name()):
			item.set_enabled(false)
			var meta_dialog: = metadata_dialog.instantiate() as TextureMetaDialog
			add_child(meta_dialog)
			meta_dialog.popup_centered()
			meta_dialog.meta_confirmed.connect(TextureManager.add_local_texture.bind(item.get_texture_name()))
			meta_dialog.meta_confirmed.connect(item.set_enabled.bind(true))
		else:
			TextureManager.add_local_texture(item.get_texture_name())
	else:
		item.set_enabled(false)
		push_error("Texture inside game not implemented yet")


func make_all_used_shared_images_bundled() -> void:
	TextureManager.bundle_all_used_shared_images()

func import_image_from_web() -> void:
	if not OS.has_feature("web"):
		return
	var as_shared: = true
	if Input.is_action_pressed("&editor_alt_mode_hold"):
		as_shared = false
	GameManager.file_access_web = FileAccessWeb.new()
	GameManager.file_access_web.loaded.connect(got_web_import_image.bind(as_shared))
	GameManager.file_access_web.open(".png")

func got_web_import_image(file_name: String, _file_type: String, b64_data: String, as_shared: bool) -> void:
	if GameManager.file_access_web:
		GameManager.file_access_web.queue_free()
		GameManager.file_access_web = null
	var png_data_bytes: PackedByteArray = Marshalls.base64_to_raw(b64_data)
	var image: Image = Image.new()
	file_name = Utility.sanitize_for_filename(file_name, true, true)
	file_name = Utility.sanitize_for_filename(file_name, true, true)

	file_name = TextureManager._unique_image_name(file_name, not as_shared)
	var unable_to_import_msg: = "Something went wrong, did not import %s" % [file_name]
	if not file_name:
		GlobalToaster.show_toast_message(unable_to_import_msg)
		return
	var error: int = image.load_png_from_buffer(png_data_bytes)
	if error != OK:
		push_error("Failed to load png data from image %s from web upload dialog: %s" % [file_name, error_string(error)])
		GlobalToaster.show_toast_message(unable_to_import_msg)
		return

	var to_game_name: = "" if as_shared else GameManager.get_game_name()
	var saved_successfully: = FilesManager.save_local_image(image, file_name, to_game_name)
	if not saved_successfully:
		GlobalToaster.show_toast_message(unable_to_import_msg)
		return
	GlobalToaster.show_toast_message("Imported %s" % [file_name])
	refresh_list()