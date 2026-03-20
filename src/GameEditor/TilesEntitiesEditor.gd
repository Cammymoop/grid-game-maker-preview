extends VBoxContainer

var TileEntityButton = preload("res://Scenes/GameEditor/TileEntityDisplay.tscn")

@export var tile_entity_mode = "tile"
var ui_root

@export var the_grid_path: NodePath
var the_grid: GridContainer
var grid_scroll_container: ScrollContainer

var im_ready = false

func _ready():
	visibility_changed.connect(_on_vis_changed)
	ui_root = find_parent("UIRoot")
	the_grid = get_node(the_grid_path)
	grid_scroll_container = the_grid.get_parent()
	
	im_ready = true

func set_grid_columns() -> void:
	var grid_width = grid_scroll_container.size.x
	if grid_width < 61:
		the_grid.columns = 1
		return
	var hsep: = the_grid.get_theme_constant("h_separation")
	the_grid.columns = floor((grid_width + hsep - 1) / (60.0 + hsep))

func update_the_grid() -> void:
	set_grid_columns()
	for c in the_grid.get_children():
		the_grid.remove_child(c)
	
	var objects = []
	if tile_entity_mode == "tile":
		objects = MapManager.get_all_tile_indexes()
	else:
		objects = EntityManager.get_all_entity_indexes()
	
	for ti in objects:
		var instance = TileEntityButton.instantiate()
		instance.parent_editor = self
		instance.tile_entity_mode = tile_entity_mode
		instance.the_index = ti
		
		the_grid.add_child(instance)

func edit_tile(ti):
	var editor_window: Window = ui_root.find_child("TileEntityEditorWindow")
	editor_window.load_tile_info(ti)
	
	edit_common(editor_window)

func edit_entity(index):
	var editor_window: Window = ui_root.find_child("TileEntityEditorWindow")
	editor_window.load_entity_info(index)
	
	edit_common(editor_window)
	
func edit_common(editor_window):
	editor_window.popup_centered()
	editor_window.fix_size()
	#editor_window.center_self()
	
	editor_window.hidden.connect(Callable(self, "update_the_grid"), CONNECT_ONE_SHOT)


func _on_Tiles_resized():
	if not im_ready:
		return
	set_grid_columns()


func _on_NewTileButton_pressed():
	var try_name = "tile"
	var num = 0
	while MapManager.tile_name_exists(try_name):
		num += 1
		try_name = "tile" + str(num)
	
	var definition = {"name": try_name, "texture": TextureManager.get_all_indexes()[0], "tex_index": 0, "properties": {}}
	var _new_index = MapManager.make_new_tile(definition)
	update_the_grid()


func _on_NewEntityButton_pressed():
	var try_name = "entity"
	var num = 0
	while EntityManager.entity_name_exists(try_name):
		num += 1
		try_name = "entity" + str(num)
	
	var definition = {"name": try_name, "texture": TextureManager.get_all_indexes()[0], "tex_index": 0, "properties": {}}
	var _new_index = EntityManager.new_entity(definition)
	update_the_grid()

func _on_vis_changed():
	if not is_visible_in_tree():
		return
	prints("vis changed", visible)
	await get_tree().process_frame
	update_the_grid()