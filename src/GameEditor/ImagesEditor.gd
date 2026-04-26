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

func _ready():
	texture_item_list.init(self)
	texture_item_list.selected_item_changed.connect(on_selected_item_changed)
	
	edit_texture_button.pressed.connect(on_edit_texture_button_pressed)
	refresh_list()

func refresh_list():
	var all_builtin_textures: Dictionary = TextureManager.get_all_builtin_textures()
	var all_user_textures: Dictionary = TextureManager.get_all_user_textures()
	
	texture_item_list.clear_all()
	disable_edit_button()
	for tex in all_builtin_textures:
		var enabled = TextureManager.is_builtin_loaded(tex)
		texture_item_list.add_texture(tex, all_builtin_textures[tex], true, enabled)
	for tex in all_user_textures:
		var enabled = TextureManager.is_local_file_loaded(tex)
		texture_item_list.add_texture(tex, all_user_textures[tex], false, enabled)
	
	texture_item_list.sort_items()

	texture_item_list.select_first_item()
	if texture_item_list.get_selected():
		enable_edit_button()

func images_updated() -> void:
	refresh_list()
	TextureManager.reload_spec()

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
		var dialog: = metadata_dialog.instantiate() as TextureMetaDialog
		add_child(dialog)
		dialog.popup_centered()
		dialog.meta_confirmed.connect(edit_tex_continue.bind(sel_tex))
	else:
		var meta: Dictionary = TextureManager.get_unloaded_texture_meta(texture_name, is_builtin, is_shared)
		edit_tex_continue(meta, sel_tex)


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