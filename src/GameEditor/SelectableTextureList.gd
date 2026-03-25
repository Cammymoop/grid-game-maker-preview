extends VBoxContainer

var item_scene = preload("res://Scenes/GameEditor/SelectableTexItem.tscn")

var enabled_textures = []
var enabled_builtin_tex = []

var images_editor

func init(editor) -> void:
	images_editor = editor

func clear_all() -> void:
	for c in get_children():
		c.queue_free()
	enabled_textures = []
	enabled_builtin_tex = []

func add_texture(texture_name, texture, builtin: bool, enabled: bool):
	if enabled:
		enabled_textures.append(texture_name)
	
	var list_item = item_scene.instantiate()
	list_item.set_texture(texture_name, texture, builtin)
	list_item.set_enabled(enabled)
	list_item.connect("selected", Callable(self, "list_item_selected"))
	list_item.connect("enabled", Callable(self, "list_item_enabled"))
	list_item.connect("double_clicked", Callable(images_editor, "_on_EditTexButton_pressed"))
	
	add_child(list_item)

func get_selected() -> Node:
	for c in get_children():
		if c.is_selected:
			return c
	return null

func list_item_selected(item) -> void:
	for c in get_children():
		if item == c:
			continue
		c.deselect()
	images_editor.enable_edit_button()

func list_item_enabled(on_off: bool, is_builtin: bool, texture_name, checkbox) -> void:
	if on_off:
		if is_builtin:
			TextureManager.add_builtin_texture(texture_name)
		else:
			TextureManager.add_local_texture(texture_name)
#			if not texture_name in enabled_textures:
#				enabled_textures.append(texture_name)
#		elif not texture_name in enabled_builtin_tex:
#				enabled_builtin_tex.append(texture_name)
	else:
		checkbox.set_pressed_no_signal(false)
