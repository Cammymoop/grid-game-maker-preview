extends VBoxContainer

var TileEntityButton = preload("res://Scenes/GameEditor/TileEntityDisplay.tscn")

var ui_root

@export var tile_grid: GridContainer
@export var entity_grid: GridContainer

var im_ready = false

var grid_item_width: float = 60

func _ready():
	assert(tile_grid and entity_grid, "TilesEntitiesEditor must have tile_grid and entity_grid")
	visibility_changed.connect(_on_vis_changed)
	ui_root = find_parent("UIRoot")

	var editor_window: Window = ui_root.find_child("TileEntityEditorWindow")
	editor_window.hidden.connect(update_all_grids)
	
	var temp_grid_item = TileEntityButton.instantiate()
	prints("temp grid item min size:", temp_grid_item.get_combined_minimum_size(), "min size vec:", temp_grid_item.custom_minimum_size)
	grid_item_width = temp_grid_item.get_combined_minimum_size().x
	temp_grid_item.queue_free()
	
	im_ready = true
	_on_vis_changed()

func set_grid_columns(the_grid: GridContainer) -> void:
	var scroll_container: = the_grid.get_parent() as ScrollContainer
	var grid_width = scroll_container.size.x
	if grid_width < grid_item_width + 1:
		the_grid.columns = 1
		return
	var hsep: = the_grid.get_theme_constant("h_separation")
	prints("width in terms of columns:", (grid_width + hsep - 1) / (grid_item_width + hsep), "grid_width:", grid_width, "column width:", grid_item_width + hsep)
	the_grid.columns = floor((grid_width + hsep - 1) / (grid_item_width + hsep))

func update_all_grids() -> void:
	update_the_grid(true)
	update_the_grid(false)

func update_the_grid(is_tile_update: bool) -> void:
	var the_grid: = tile_grid if is_tile_update else entity_grid
	set_grid_columns(the_grid)
	for c in the_grid.get_children():
		the_grid.remove_child(c)
	
	var objects = []
	if is_tile_update:
		objects = MapManager.get_all_tile_indexes()
	else:
		objects = EntityManager.get_all_entity_indexes()
	
	for obj_index in objects:
		var instance = TileEntityButton.instantiate()
		instance.parent_editor = self
		instance.tile_entity_mode = "tile" if is_tile_update else "entity"
		instance.the_index = obj_index
		
		the_grid.add_child(instance)

func edit_tile(tile_index: int):
	var editor_window: Window = ui_root.find_child("TileEntityEditorWindow")
	editor_window.load_tile_info(tile_index)
	
	edit_common(editor_window)

func edit_entity(entity_index: int):
	var editor_window: Window = ui_root.find_child("TileEntityEditorWindow")
	editor_window.load_entity_info(entity_index)
	
	edit_common(editor_window)
	
func edit_common(editor_window):
	editor_window.popup_centered()
	editor_window.fix_size()
	#editor_window.center_self()


func _on_Tiles_resized():
	if not im_ready:
		return
	set_grid_columns(tile_grid)
	set_grid_columns(entity_grid)


func _on_NewTileButton_pressed():
	var try_name = "tile"
	var num = 0
	while MapManager.tile_name_exists(try_name):
		num += 1
		try_name = "tile" + str(num)
	
	var definition = {"name": try_name, "texture": TextureManager.get_all_indexes()[0], "tex_index": 0, "properties": {}}
	var _new_index = MapManager.make_new_tile(definition)
	update_the_grid(true)


func _on_NewEntityButton_pressed():
	var try_name = "entity"
	var num = 0
	while EntityManager.entity_name_exists(try_name):
		num += 1
		try_name = "entity" + str(num)
	
	var definition = {"name": try_name, "texture": TextureManager.get_all_indexes()[0], "tex_index": 0, "properties": {}}
	var _new_index = EntityManager.new_entity(definition)
	update_the_grid(false)

func _on_vis_changed():
	if not is_visible_in_tree():
		return
	await get_tree().process_frame
	update_all_grids()