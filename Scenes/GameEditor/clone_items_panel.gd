extends PanelContainer

const GameSelector: = preload("res://Scenes/game_selector.gd")

signal request_back()
signal clone_items_picked(items: Dictionary, from_game_name: String)

var cloning_from_game_name: String = ""
var cloning_from_game_definition: Dictionary = {}

var int_keyed_entity_defs: Dictionary = {}
var int_keyed_tile_defs: Dictionary = {}

var item_textures: Dictionary = {
	"entities": {},
	"tiles": {},
}

var item_names: Dictionary = {
	"entities": {},
	"tiles": {},
}

@export var game_selector: GameSelector

@export var entity_list_container: Control
@export var entity_list: ItemList
@export var tile_list_container: Control
@export var tile_list: ItemList

@export var select_all_entities_button: Button
@export var select_all_tiles_button: Button

@export var clone_button: Button
@export var cancel_button: Button

func _ready() -> void:
	clone_button.pressed.connect(on_clone_button_pressed)
	cancel_button.pressed.connect(on_cancel_button_pressed)
	
	select_all_entities_button.pressed.connect(on_select_all_entities_button_pressed)
	select_all_tiles_button.pressed.connect(on_select_all_tiles_button_pressed)
	
	entity_list.clear()
	tile_list.clear()
	
	game_selector.changed_game.connect(on_chose_game)

func show_and_refresh() -> void:
	show()
	if not cloning_from_game_name:
		cloning_from_game_name = GameManager.get_identified_game_name()
		game_selector.change_game(1)
	else:
		reload_items()

func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if Utility.event_is_menu_back_just_pressed(event):
		on_cancel_button_pressed()
		accept_event()


func get_cloned_items_info() -> Dictionary:
	var cloned_items: Dictionary = {
		"entities": {},
		"tiles": {},
	}
	var selected_entity_items: = entity_list.get_selected_items()
	for entity_item_index in selected_entity_items:
		var entity_id: = entity_list.get_item_metadata(entity_item_index) as int
		cloned_items["entities"][entity_id] = int_keyed_entity_defs[entity_id]
	var selected_tile_items: = tile_list.get_selected_items()
	for tile_item_index in selected_tile_items:
		var tile_id: = tile_list.get_item_metadata(tile_item_index) as int
		cloned_items["tiles"][tile_id] = int_keyed_tile_defs[tile_id]
	return cloned_items
	

func reload_items() -> void:
	load_basic_textures_for_game(cloning_from_game_name)
	refresh_entity_list()
	refresh_tile_list()

func refresh_entity_list() -> void:
	entity_list.clear()
	for entity_id in item_names["entities"].keys():
		var texture: = item_textures["entities"][entity_id] as Texture2D
		if texture:
			var idx: = entity_list.add_item(item_names["entities"][entity_id], texture)
			entity_list.set_item_metadata(idx, entity_id)

func refresh_tile_list() -> void:
	tile_list.clear()
	for tile_id in item_names["tiles"].keys():
		var texture: = item_textures["tiles"][tile_id] as Texture2D
		if texture:
			var idx: = tile_list.add_item(item_names["tiles"][tile_id], texture)
			tile_list.set_item_metadata(idx, tile_id)

func load_basic_textures_for_game(game_name: String) -> void:
	var game_definition: Dictionary = FilesManager.get_game_definition(game_name)
	var entity_defs_raw: Dictionary = game_definition.get("entity_definitions", {})
	int_keyed_entity_defs.clear()
	for entity_id_str in entity_defs_raw.keys():
		int_keyed_entity_defs[int(entity_id_str)] = entity_defs_raw[entity_id_str]

	var tile_defs_raw: Dictionary = game_definition.get("tile_definitions", {})
	int_keyed_tile_defs.clear()
	for tile_id_str in tile_defs_raw.keys():
		int_keyed_tile_defs[int(tile_id_str)] = tile_defs_raw[tile_id_str]

	item_names["entities"] = {}
	for entity_id in int_keyed_entity_defs.keys():
		item_names["entities"][entity_id] = int_keyed_entity_defs[entity_id].get("name", "")
	item_names["tiles"] = {}
	for tile_id in int_keyed_tile_defs.keys():
		item_names["tiles"][tile_id] = int_keyed_tile_defs[tile_id].get("name", "")

	item_textures["entities"] = EntityManager.get_basic_atlas_textures_for_foreign_game(game_definition, game_name)
	item_textures["tiles"] = MapManager.get_basic_atlas_textures_for_foreign_game(game_definition, game_name)

func start_rendering_sprite_snapshots() -> void:
	var callback: = done_rendering_sprite_snapshots.bind(cloning_from_game_name)
	EntityManager.build_foreign_sprite_previews(cloning_from_game_definition, cloning_from_game_name, callback)

func done_rendering_sprite_snapshots(snapshots: Dictionary, for_game_name: String) -> void:
	if for_game_name != cloning_from_game_name or not snapshots:
		return
	for entity_id in snapshots.keys():
		item_textures["entities"][entity_id] = snapshots[entity_id]
	refresh_entity_list()

func on_chose_game(game_name: String) -> void:
	cloning_from_game_name = game_name
	cloning_from_game_definition = FilesManager.get_game_definition(game_name)
	reload_items()


func on_clone_button_pressed() -> void:
	var cloned_items: = get_cloned_items_info()
	if cloned_items["entities"].size() + cloned_items["tiles"].size() > 0:
		clone_items_picked.emit(get_cloned_items_info(), cloning_from_game_name)
	request_back.emit()

func on_cancel_button_pressed() -> void:
	request_back.emit()


func on_select_all_entities_button_pressed() -> void:
	var selected_items: = entity_list.get_selected_items()
	if selected_items.size() >= entity_list.item_count:
		entity_list.deselect_all()
	else:
		entity_list.select_all()

func on_select_all_tiles_button_pressed() -> void:
	var selected_items: = tile_list.get_selected_items()
	if selected_items.size() >= tile_list.item_count:
		tile_list.deselect_all()
	else:
		tile_list.select_all()