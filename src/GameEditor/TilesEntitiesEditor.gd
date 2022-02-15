extends VBoxContainer

var TileEntityButton = preload("res://Scenes/GameEditor/TileEntityDisplay.tscn")

export var tile_entity_mode = "tile"
var ui_root

export var the_grid_path:NodePath
var the_grid:GridContainer

var im_ready = false

func _ready():
	ui_root = find_parent("UIRoot")
	the_grid = get_node(the_grid_path)
	set_grid_columns()
	update_the_grid()
	
	im_ready = true

func set_grid_columns() -> void:
	var grid_width = the_grid.rect_size.x
	the_grid.columns = floor(grid_width / (60 + the_grid.get_constant("hseparation")))

func update_the_grid() -> void:
	for c in the_grid.get_children():
		the_grid.remove_child(c)
	
	var objects = []
	if tile_entity_mode == "tile":
		objects = MapManager.get_all_tile_indexes()
	else:
		objects = EntityManager.get_all_entity_indexes()
	
	for ti in objects:
		var instance = TileEntityButton.instance()
		instance.parent_editor = self
		instance.tile_entity_mode = tile_entity_mode
		instance.the_index = ti
		
		the_grid.add_child(instance)

func edit_tile(ti):
	var editor_window:WindowDialog = ui_root.find_node("TileEntityEditorWindow")
	editor_window.load_tile_info(ti)
	
	edit_common(editor_window)

func edit_entity(index):
	var editor_window:WindowDialog = ui_root.find_node("TileEntityEditorWindow")
	editor_window.load_entity_info(index)
	
	edit_common(editor_window)
	
func edit_common(editor_window):
	editor_window.popup_centered()
	editor_window.fix_size()
	#editor_window.center_self()
	
	editor_window.connect("popup_hide", self, "update_the_grid", [], CONNECT_ONESHOT)


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
	var _new_index = MapManager.new_tile(definition)
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
