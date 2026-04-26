extends VBoxContainer

signal selected_item_changed(item: SelectableTexture)

const SelectableTexture = preload("res://src/GameEditor/SelectableTexture.gd")
const ImagesTab = preload("res://src/GameEditor/ImagesEditor.gd")

var item_scene: = preload("res://Scenes/GameEditor/SelectableTexItem.tscn")

var all_textures: Array = []
var enabled_textures: Array = []

var images_editor: ImagesTab

func init(editor: ImagesTab) -> void:
	images_editor = editor

func clear_all() -> void:
	for c in get_children():
		c.queue_free()
	enabled_textures = []
	all_textures = []

func add_texture(texture_name: String, texture: Texture, builtin: bool, enabled: bool, is_shared: bool = true) -> void:
	all_textures.append(texture_name)
	if enabled:
		enabled_textures.append(texture_name)
	
	var list_item: = item_scene.instantiate() as SelectableTexture
	list_item.set_texture(texture_name, texture, builtin, is_shared)
	list_item.set_enabled(enabled)
	list_item.selected.connect(on_item_selected)
	list_item.enable_toggled.connect(images_editor.set_texture_item_enabled)
	list_item.double_clicked.connect(on_item_double_clicked)
	
	add_child(list_item)

func on_item_double_clicked(item: SelectableTexture) -> void:
	images_editor.edit_texture_from_selectable_texture(item)

func select_first_item() -> void:
	if get_child_count() > 0:
		var first_item: = get_child(0) as SelectableTexture
		if first_item:
			deselect_other_items(first_item)
			first_item.select()

func get_selected() -> SelectableTexture:
	for c in get_children():
		if c.is_selected:
			return c
	return null

func deselect_other_items(item: SelectableTexture) -> void:
	for c in get_children():
		if item == c:
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
	for sorted_item in items:
		add_child(sorted_item)

func texture_item_order(item_a: SelectableTexture, item_b: SelectableTexture) -> bool:
	var name_a: = item_a.get_texture_name()
	var name_b: = item_b.get_texture_name()
	if not name_b in all_textures or not name_a in all_textures:
		return true
	
	var score_a: int = 0
	var score_b: int = 0
	
	score_a += 100 * int(item_a.is_enabled())
	score_b += 100 * int(item_b.is_enabled())
	
	score_a += int(item_a.get_is_builtin())
	score_a += int(item_a.get_is_builtin())
	
	if score_a != score_b:
		return score_a > score_b
	return name_a.nocasecmp_to(name_b) < 0