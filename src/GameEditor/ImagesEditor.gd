extends VBoxContainer

var tile_compositor_scn = preload("res://Scenes/GameEditor/TileCompositor.tscn")
var metadata_dialog = preload("res://Scenes/GameEditor/TextureMetaDialog.tscn")

@onready var ui_root = find_parent("UIRoot")

func _ready():
	var list = find_child("ListContainer")
	list.init(self)
	
	refresh_list()

func refresh_list():
	var all_builtin_textures: Dictionary = TextureManager.get_all_builtin_textures()
	var all_user_textures: Dictionary = TextureManager.get_all_user_textures()
	
	var list = find_child("ListContainer")
	list.clear_all()
	for tex in all_builtin_textures:
		var enabled = TextureManager.is_builtin_loaded(tex)
		list.add_texture(tex, all_builtin_textures[tex], true, enabled)
	for tex in all_user_textures:
		var enabled = TextureManager.is_local_file_loaded(tex)
		list.add_texture(tex, all_user_textures[tex], false, enabled)

func images_updated() -> void:
	refresh_list()
	TextureManager.reload_spec()

func enable_edit_button() -> void:
	find_child("EditTexButton").disabled = false

func disable_edit_button() -> void:
	find_child("EditTexTexButton").disabled = true


func _on_EditTexButton_pressed() -> void:
	var selected_item = find_child("ListContainer").get_selected()
	if not selected_item or selected_item.texture_name == "":
		return
	
	var meta
	if selected_item.built_in:
		meta = TextureManager.builtin_meta[selected_item.texture_name]
	else:
		meta = TextureManager.fix_texture_meta(FilesManager.get_local_image_metadata(selected_item.texture_name))
	
	if not meta:
		var dialog = metadata_dialog.instantiate()
		find_parent("UIRoot").add_popup_layer_node(dialog)
		dialog.popup_centered()
		
		dialog.connect("meta_confirmed", Callable(self, "edit_tex_continue").bind(selected_item))
	else:
		edit_tex_continue(meta, selected_item)

	
func edit_tex_continue(meta, selected_item) -> void:
	var tex_edit = tile_compositor_scn.instantiate()
	tex_edit.set_texture(selected_item.get_texture())
	tex_edit.set_metadata(meta)
	if not selected_item.built_in:
		tex_edit.set_save_path(selected_item.texture_name)
	ui_root.add_popup_layer_node(tex_edit)
	tex_edit.popup_centered()
	
	tex_edit.hidden.connect(Callable(self, "images_updated"))

func edit_new_texture(texture_meta: Dictionary) -> void:
	var tex_edit = tile_compositor_scn.instantiate()
	tex_edit.set_new_texture_size(texture_meta['size'])
	tex_edit.set_metadata(texture_meta)
	ui_root.add_popup_layer_node(tex_edit)
	tex_edit.popup_centered()
	
	tex_edit.hidden.connect(Callable(self, "images_updated"))

func _on_NewTexButton_pressed() -> void:
	var dialog = metadata_dialog.instantiate()
	find_parent("UIRoot").add_popup_layer_node(dialog)
	dialog.popup_centered()
	
	dialog.connect("meta_confirmed", Callable(self, "edit_new_texture"))
