extends VBoxContainer

const TileEntityButton = preload("res://src/GameEditor/TileEntityButton.gd")
var tile_entity_button = preload("res://Scenes/GameEditor/TileEntityDisplay.tscn")

const CloneItemsPanel = preload("res://Scenes/GameEditor/clone_items_panel.gd")

var ui_root

@export var tile_grid: GridContainer
@export var entity_grid: GridContainer

@export var clone_items_layer: CanvasLayer
@export var clone_items_panel: CloneItemsPanel

@export var open_clone_panel_button: Button

@export var clone_with_bundled_disclaimer_dialog: Window

var im_ready = false

var grid_item_width: float = 60

var disclaimer_confirmed_continue: Callable = Callable()

const CONTEXT_MENU_DELETE = 0
const CONTEXT_MENU_DUPLICATE = 1

const CTX_COPY_START = 8
const CONTEXT_MENU_COPY_ITEM = 8
const CONTEXT_MENU_COPY_ALL_ENTITIES = 9
const CONTEXT_MENU_COPY_ALL_TILES = 10
const CONTEXT_MENU_COPY_ALL_ITEMS = 11
const CONTEXT_MENU_COPY_ITEM_PROPERTIES = 12
const CONTEXT_MENU_COPY_ENTITY_SPRITE = 13
const CTX_COPY_END = 12

const CTX_PASTE_START = 18
const CONTEXT_MENU_PASTE_ITEM = 18
const CONTEXT_MENU_PASTE_ITEM_PROPERTIES = 19
const CONTEXT_MENU_PASTE_ITEM_PROP_NO_OVERRIDE = 20
const CONTEXT_MENU_PASTE_ENTITY_SPRITE = 21
const CTX_PASTE_END = 20

const CTX_REORDER_START = 51
const CONTEXT_MENU_REORDER_BACK = 51
const CONTEXT_MENU_REORDER_FORWARD = 52
const CONTEXT_MENU_REORDER_TO_TOP = 53
const CONTEXT_MENU_REORDER_TO_BOTTOM = 54
const CTX_REORDER_END = 54

func _ready():
	assert(tile_grid and entity_grid, "TilesEntitiesEditor must have tile_grid and entity_grid")
	visibility_changed.connect(_on_vis_changed)
	ui_root = find_parent("UIRoot")
	
	open_clone_panel_button.pressed.connect(on_open_clone_panel_button_pressed)
	
	clone_items_panel.clone_items_picked.connect(on_clone_items_picked)
	clone_items_panel.request_back.connect(on_clone_items_panel_request_back)
	
	clone_with_bundled_disclaimer_dialog.confirmed.connect(on_clone_with_bundled_disclaimer_confirmed)

	var editor_window: Window = ui_root.find_child("TileEntityEditorWindow")
	editor_window.hidden.connect(update_all_grids)
	
	var temp_grid_item = tile_entity_button.instantiate()
	grid_item_width = temp_grid_item.get_combined_minimum_size().x
	temp_grid_item.queue_free()
	
	EntityManager.entity_snapshots_updated.connect(update_the_grid.bind(false))
	
	im_ready = true
	await get_tree().process_frame
	update_all_grids()

func set_grid_columns(the_grid: GridContainer) -> void:
	var scroll_container: = the_grid.get_parent() as ScrollContainer
	var grid_width = scroll_container.size.x
	if grid_width < grid_item_width + 1:
		the_grid.columns = 1
		return
	var hsep: = the_grid.get_theme_constant("h_separation")
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
		var instance = tile_entity_button.instantiate()
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
	
	var default_texture = TextureManager.get_all_indexes()[0]
	var all_tile_ids: = MapManager.get_all_tile_indexes()
	all_tile_ids.reverse()
	for tile_id in all_tile_ids:
		var tile_def: Dictionary = MapManager.get_tile_definition(tile_id)
		if tile_def.get("texture", -1) >= 0:
			default_texture = tile_def["texture"]
			break
	var definition = {"name": try_name, "texture": default_texture, "tex_index": 0, "properties": {}}
	var _new_index = MapManager.make_new_tile(definition)
	update_the_grid(true)


func _on_NewEntityButton_pressed():
	var try_name = "entity"
	var num = 0
	while EntityManager.entity_name_exists(try_name):
		num += 1
		try_name = "entity" + str(num)
	
	var default_texture = TextureManager.get_all_indexes()[0]
	var all_entity_ids: = EntityManager.get_all_entity_indexes()
	all_entity_ids.reverse()
	for entity_id in all_entity_ids:
		var entity_def: Dictionary = EntityManager.get_entity_definition(entity_id)
		if entity_def.get("texture", -1) >= 0:
			default_texture = entity_def["texture"]
			break
	var definition = {"name": try_name, "texture": default_texture, "tex_index": 0, "properties": {}}
	var _new_index = EntityManager.new_entity(definition)
	update_the_grid(false)

func _on_vis_changed():
	if not is_visible_in_tree():
		return
	await get_tree().process_frame
	update_all_grids()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		do_background_context_menu()
		accept_event()

func do_background_context_menu() -> void:
	var context_menu = Utility.get_empty_context_menu()
	context_menu.add_item("Copy All Entities", CONTEXT_MENU_COPY_ALL_ENTITIES)
	context_menu.add_item("Copy All Tiles", CONTEXT_MENU_COPY_ALL_TILES)
	context_menu.add_item("Copy All Items", CONTEXT_MENU_COPY_ALL_ITEMS)
	if CurrentClipboard.has_items():
		context_menu.add_separator("Paste")
		context_menu.add_item("Paste Entity/Tile(s)", CONTEXT_MENU_PASTE_ITEM)
	context_menu.id_pressed.connect(on_context_menu_id_pressed.bind(false))
	Utility.popup_context_menu_at_mouse(context_menu)

func do_context_menu_for_item(the_item: TileEntityButton) -> void:
	var is_entity = the_item.tile_entity_mode == "entity"
	var item_text: = "Entity" if is_entity else "Tile"
	var item_plural: = "Entities" if is_entity else "Tiles"
	var context_menu = Utility.get_empty_context_menu()
	context_menu.add_item("Duplicate", CONTEXT_MENU_DUPLICATE)
	context_menu.add_item("Copy %s" % [item_text], CONTEXT_MENU_COPY_ITEM)
	context_menu.add_item("Copy %s Properties" % [item_text], CONTEXT_MENU_COPY_ITEM_PROPERTIES)
	context_menu.add_item("Copy All %s" % [item_plural], CONTEXT_MENU_COPY_ALL_ENTITIES if is_entity else CONTEXT_MENU_COPY_ALL_TILES)
	context_menu.add_item("Copy All Items", CONTEXT_MENU_COPY_ALL_ITEMS)
	if is_entity:
		var entity_def: Dictionary = get_existing_item_definition(true, the_item.the_index)
		if entity_def.get("sprite_config", {}):
			context_menu.add_item("Copy Entity Sprite", CONTEXT_MENU_COPY_ENTITY_SPRITE)

	if CurrentClipboard.has_items() or CurrentClipboard.has_properties() or CurrentClipboard.has_sprite_config():
		context_menu.add_separator("Paste")
		if CurrentClipboard.has_items():
			context_menu.add_item("Paste Entity/Tile(s)", CONTEXT_MENU_PASTE_ITEM)
		if CurrentClipboard.has_sprite_config():
			context_menu.add_item("Paste Entity Sprite", CONTEXT_MENU_PASTE_ENTITY_SPRITE)
		if CurrentClipboard.has_properties():
			context_menu.add_item("Paste Entity/Tile Properties (Overwrite existing)", CONTEXT_MENU_PASTE_ITEM_PROPERTIES)
			context_menu.add_item("Paste Entity/Tile Properties (Only unset properties)", CONTEXT_MENU_PASTE_ITEM_PROP_NO_OVERRIDE)
	
	context_menu.add_separator("Reorder " + item_text)
	context_menu.add_item("Move Back", CONTEXT_MENU_REORDER_BACK)
	context_menu.add_item("Move Forward", CONTEXT_MENU_REORDER_FORWARD)
	context_menu.add_item("Move to Top", CONTEXT_MENU_REORDER_TO_TOP)
	context_menu.add_item("Move to Bottom", CONTEXT_MENU_REORDER_TO_BOTTOM)

	context_menu.add_separator("Delete")
	context_menu.add_item("Delete", CONTEXT_MENU_DELETE)
	context_menu.id_pressed.connect(on_context_menu_id_pressed.bind(true, is_entity, the_item.the_index))
	Utility.popup_context_menu_at_mouse(context_menu)

func add_item_as_definition(is_entity: bool, item_definition: Dictionary) -> int:
	item_definition = item_definition.duplicate_deep()
	item_definition["name"] = get_renumbered_name(is_entity, item_definition["name"])
	if is_entity:
		return EntityManager.new_entity(item_definition)
	else:
		return MapManager.make_new_tile(item_definition)

func get_existing_item_definition(is_entity: bool, item_id: int) -> Dictionary:
	if is_entity:
		return EntityManager.get_entity_definition(item_id)
	else:
		return MapManager.get_tile_definition(item_id)

func update_definition_properties(is_entity: bool, item_id: int, new_definition_props: Dictionary, overwrite: bool) -> void:
	var new_props: Dictionary = get_existing_item_definition(is_entity, item_id).get("properties", {})
	new_props.merge(new_definition_props, overwrite)
	if is_entity:
		EntityManager.update_entity_def_properties(item_id, new_props)
	else:
		MapManager.update_tile_def_properties(item_id, new_props)

func on_context_menu_id_pressed(context_menu_id: int, is_clicked_item: bool, is_entity: bool = true, item_id: int = -1) -> void:
	if context_menu_id == CONTEXT_MENU_DELETE:
		if is_clicked_item:
			if is_entity:
				EntityManager.remove_entity_definition(item_id)
			else:
				MapManager.remove_tile_definition(item_id)
			update_all_grids()
	elif context_menu_id == CONTEXT_MENU_DUPLICATE:
		if is_clicked_item:
			add_item_as_definition(is_entity, get_existing_item_definition(is_entity, item_id))
			update_all_grids()
	elif context_menu_id >= CTX_COPY_START and context_menu_id <= CTX_COPY_END:
		handle_ctx_copy(context_menu_id, is_clicked_item, is_entity, item_id)
	elif context_menu_id >= CTX_PASTE_START and context_menu_id <= CTX_PASTE_END:
		handle_ctx_paste(context_menu_id, is_clicked_item, is_entity, item_id)
	elif context_menu_id >= CTX_REORDER_START and context_menu_id <= CTX_REORDER_END:
		handle_ctx_reorder(context_menu_id, is_clicked_item, is_entity, item_id)

func get_renumbered_name(is_entity: bool, old_name: String) -> String:
	var check_name: Callable = EntityManager.entity_name_exists if is_entity else MapManager.tile_name_exists
	var name_number = Utility.get_number_suffix(old_name)
	old_name = old_name.trim_suffix(str(name_number))
	name_number += 1
	while check_name.call(old_name + str(name_number)):
		name_number += 1
	return old_name + str(name_number)

func handle_ctx_paste(context_menu_id: int, is_clicked_item: bool, clicked_is_entity: bool, clicked_item_id: int) -> void:
	if context_menu_id == CONTEXT_MENU_PASTE_ITEM_PROPERTIES or context_menu_id == CONTEXT_MENU_PASTE_ITEM_PROP_NO_OVERRIDE:
		if not is_clicked_item:
			return
		var do_overwrite: = context_menu_id == CONTEXT_MENU_PASTE_ITEM_PROPERTIES
		update_definition_properties(clicked_is_entity, clicked_item_id, CurrentClipboard.get_properties(), do_overwrite)
		update_all_grids()
	elif context_menu_id == CONTEXT_MENU_PASTE_ITEM:
		var items: Dictionary = CurrentClipboard.get_items()
		for pasted_entity_def in items.get("entities", []):
			add_item_as_definition(true, pasted_entity_def)
		for pasted_tile_def in items.get("tiles", []):
			add_item_as_definition(false, pasted_tile_def)
		update_all_grids()
	elif context_menu_id == CONTEXT_MENU_PASTE_ENTITY_SPRITE:
		if not is_clicked_item or not clicked_is_entity:
			return
		var sprite_config: Dictionary = CurrentClipboard.get_sprite_config()
		var entity_def: Dictionary = get_existing_item_definition(true, clicked_item_id)
		entity_def["sprite_config"] = sprite_config
		EntityManager.update_entity_definition(clicked_item_id, entity_def)
		update_all_grids()
			
func handle_ctx_copy(context_menu_id: int, is_clicked_item: bool, clicked_is_entity: bool, clicked_item_id: int) -> void:
	if context_menu_id in [CONTEXT_MENU_COPY_ALL_ENTITIES, CONTEXT_MENU_COPY_ALL_TILES, CONTEXT_MENU_COPY_ALL_ITEMS]:
		var include_entities: = context_menu_id != CONTEXT_MENU_COPY_ALL_TILES
		var include_tiles: = context_menu_id != CONTEXT_MENU_COPY_ALL_ENTITIES
		var items: Dictionary = {}
		if include_entities:
			items["entities"] = []
			for entity_id in EntityManager.get_all_entity_indexes():
				items["entities"].append(EntityManager.get_entity_definition(entity_id))
		if include_tiles:
			items["tiles"] = []
			for tile_id in MapManager.get_all_tile_indexes():
				items["tiles"].append(MapManager.get_tile_definition(tile_id))
		CurrentClipboard.copy_items(items)
	elif context_menu_id == CONTEXT_MENU_COPY_ITEM:
		if not is_clicked_item:
			return
		var item_definition: = get_existing_item_definition(clicked_is_entity, clicked_item_id)
		if clicked_is_entity:
			CurrentClipboard.copy_entity_type(item_definition)
		else:
			CurrentClipboard.copy_tile_type(item_definition)
	elif context_menu_id == CONTEXT_MENU_COPY_ITEM_PROPERTIES:
		if not is_clicked_item:
			return
		var item_definition: = get_existing_item_definition(clicked_is_entity, clicked_item_id)
		CurrentClipboard.copy_properties(item_definition.get("properties", {}))
	elif context_menu_id == CONTEXT_MENU_COPY_ENTITY_SPRITE:
		if not is_clicked_item or not clicked_is_entity:
			return
		var entity_def: Dictionary = get_existing_item_definition(true, clicked_item_id)
		CurrentClipboard.copy_sprite_config(entity_def.get("sprite_config", {}))

func handle_ctx_reorder(context_menu_id: int, is_clicked_item: bool, clicked_is_entity: bool, clicked_item_id: int) -> void:
	if not is_clicked_item:
		return
	if context_menu_id == CONTEXT_MENU_REORDER_BACK:
		reorder_item_relative(clicked_is_entity, clicked_item_id, -1)
	elif context_menu_id == CONTEXT_MENU_REORDER_FORWARD:
		reorder_item_relative(clicked_is_entity, clicked_item_id, 1)
	elif context_menu_id == CONTEXT_MENU_REORDER_TO_TOP:
		reorder_item(clicked_is_entity, clicked_item_id, 0)
	elif context_menu_id == CONTEXT_MENU_REORDER_TO_BOTTOM:
		reorder_item(clicked_is_entity, clicked_item_id, 10000000)


func reorder_item(is_entity: bool, item_id: int, to_order_index: int) -> void:
	var old_definitions: Dictionary = {}
	if is_entity:
		old_definitions = EntityManager.entity_defs
	else:
		old_definitions = MapManager.tile_defs
	to_order_index = clampi(to_order_index, 0, old_definitions.size() - 1)
	
	var new_ids: = old_definitions.keys()
	new_ids.erase(item_id)
	new_ids.insert(to_order_index, item_id)
	
	var new_definitions: Dictionary = {}
	for new_key in new_ids:
		new_definitions[new_key] = old_definitions[new_key]
	
	if is_entity:
		EntityManager.entity_defs = new_definitions
		EntityManager.refresh_definition()
	else:
		MapManager.tile_defs = new_definitions
		MapManager.refresh_definition()
	update_all_grids()

func reorder_item_relative(is_entity: bool, item_id: int, delta: int) -> void:
	var old_keys: = []
	if is_entity:
		old_keys = EntityManager.entity_defs.keys()
	else:
		old_keys = MapManager.tile_defs.keys()
	
	var old_index: int = old_keys.find(item_id)
	if old_index == -1:
		return
	
	reorder_item(is_entity, item_id, clampi(old_index + delta, 0, old_keys.size() - 1))
	

func on_open_clone_panel_button_pressed() -> void:
	clone_items_layer.show()
	clone_items_panel.show()

func on_clone_items_panel_request_back() -> void:
	clone_items_layer.hide()

func on_clone_items_picked(items: Dictionary, from_game_name: String) -> void:
	var from_game_definition: Dictionary = FilesManager.get_game_definition(from_game_name)
	
	var texture_ids_used: = EntityManager.get_used_texture_ids_from_defs(items["entities"])
	for tile_texture_id in MapManager.get_used_texture_ids_from_defs(items["tiles"]):
		if not tile_texture_id in texture_ids_used:
			texture_ids_used.append(tile_texture_id)

	var from_game_texture_spec: Array = from_game_definition.get("textures", [])
	var texture_lookup: = TextureManager.make_foreign_texture_lookup(from_game_texture_spec, from_game_name)
	
	var used_bundled_ids: Array[int] = []
	for bundled_id in texture_lookup["bundled_images"]:
		if bundled_id in texture_ids_used:
			used_bundled_ids.append(bundled_id)
	
	if used_bundled_ids.size() < 1 or GameManager.is_one_time_message_dismissed(GameManager.OneTimeMessages.CLONE_ITEMS_WITH_BUNDLED_IMAGES):
		_do_clone_items(items, from_game_name, texture_ids_used)
		return
	
	show_clone_with_bundled_disclaimer(items, from_game_name, texture_ids_used, texture_lookup)
	

func _do_clone_items(items: Dictionary, from_game_name: String, texture_ids_used: Array) -> void:
	var from_game_definition: Dictionary = FilesManager.get_game_definition(from_game_name)
	var from_game_texture_spec: Array = from_game_definition.get("textures", [])
	var texture_lookup: = TextureManager.make_foreign_texture_lookup(from_game_texture_spec, from_game_name)

	var remaps: Dictionary[int, int] = TextureManager.load_and_copy_from_foreign_lookup(texture_lookup, from_game_name, texture_ids_used)
	var fallback_id: int = TextureManager.get_fallback_texture_id()
	for from_id in remaps:
		if remaps[from_id] < 0:
			remaps[from_id] = fallback_id
	
	var has_entities: bool = items["entities"].size() > 0
	var has_tiles: bool = items["tiles"].size() > 0
	
	if has_entities:
		EntityManager.import_new_entities_with_texture_remaps(items["entities"].values(), remaps)
	if has_tiles:
		MapManager.import_new_tiles_with_texture_remaps(items["tiles"].values(), remaps)
	
	TextureManager.refresh_textures()
	TextureManager.textures_remapped.emit()
	
	EntityManager.refresh_definition()
	MapManager.refresh_definition()
	
	update_all_grids()


func show_clone_with_bundled_disclaimer(items: Dictionary, from_game_name: String, texture_ids_used: Array, texture_lookup: Dictionary) -> void:
	disclaimer_confirmed_continue = _do_clone_items.bind(items, from_game_name, texture_ids_used)
	var bundled_image_names: Array[String] = []
	var bundled_image_textures: Array[Texture2D] = []
	for bundled_id in texture_lookup["bundled_images"]:
		if bundled_id in texture_ids_used:
			bundled_image_names.append(texture_lookup["bundled_images"][bundled_id])
			bundled_image_textures.append(texture_lookup[bundled_id])
	clone_with_bundled_disclaimer_dialog.set_textures(bundled_image_names, bundled_image_textures)
	clone_with_bundled_disclaimer_dialog.popup_centered()

func on_clone_with_bundled_disclaimer_confirmed() -> void:
	if disclaimer_confirmed_continue.is_valid():
		disclaimer_confirmed_continue.call()
		disclaimer_confirmed_continue = Callable()