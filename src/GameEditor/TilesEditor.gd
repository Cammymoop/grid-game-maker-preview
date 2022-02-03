extends VBoxContainer

var TileEntityButton = preload("res://Scenes/GameEditor/TileEntityDisplay.tscn")

var ui_root

func _ready():
	ui_root = find_parent("UIRoot")
	set_grid_columns()
	update_tile_grid()

func set_grid_columns() -> void:
	var tile_grid:GridContainer = find_node("EditTilesGrid")
	var grid_width = tile_grid.rect_size.x
	tile_grid.columns = floor(grid_width / (60 + tile_grid.get_constant("hseparation")))

func update_tile_grid() -> void:
	var tile_grid:GridContainer = find_node("EditTilesGrid")
	for c in tile_grid.get_children():
		tile_grid.remove_child(c)
	var all_tiles = MapManager.get_all_tile_indexes()
	
	for ti in all_tiles:
		var instance = TileButton.instance()
		instance.tile_editor = self
		instance.tile_index = ti
		
		tile_grid.add_child(instance)

func edit_tile(ti):
	var editor_window:WindowDialog = ui_root.find_node("TileEntityEditorWindow")
	editor_window.load_tile_info(ti)
	
	editor_window.popup_centered()
	editor_window.fix_size()
	#editor_window.center_self()
	
	editor_window.connect("popup_hide", self, "update_tile_grid", [], CONNECT_ONESHOT)


func _on_Tiles_resized():
	set_grid_columns()
