extends Node

var entity_template = preload("res://Scenes/BaseEntity.tscn")
var controller_templates = {}

var entity_defs = {
	0: {
		"name": "player",
		"texture": 1,
		"tex_index": 0,
		"intended_move_speed": 6,
		"controller": "InputController",
		"properties": {
			"pusher": true,
			"treads": true,
		},
		"groups": ["Player"],
	},
	1: {
		"name": "green_box",
		"texture": 1,
		"tex_index": 1,
		"properties": {
			"blocks": {"condition": "has_no_property pusher"},
			"move_onto": {"condition": "be_pushed forward"},
			"i_finish_move_onto_tile": {
				"condition": "tile_has_property wet",
				"actions": ["replace_tile greenery", "die"]
			}
		},
	},
	2: {
		"name": "bouncer",
		"texture": 1,
		"tex_index": 6,
		"intended_move_speed": 4,
		"controller": "BounceController",
		"properties": {
			"kills": true,
		},
	},
	3: {
		"name": "swap_box",
		"texture": 1,
		"tex_index": 8,
		"properties": {
			"blocks": {"condition": "has_no_property pusher"},
			"move_onto": {"condition": "be_pushed reverse"},
		},
	},
	4: {
		"name": "rotate_box",
		"texture": 1,
		"tex_index": 13,
		"properties": {
			"pusher": true,
			"no_rotation": true,
			"blocks": {"condition": "has_no_property pusher"},
			"move_onto": {"condition": "be_pushed turn_right"},
		},
	},
}
onready var loaded_entity_defs = entity_defs

var entity_index_map = {}

var entity_list = []

var im_ready = false

func _ready():
	if not TextureManager.im_ready:
		yield(TextureManager, "textures_loaded")
	create_index_map()
	preload_controller_templates()
	
	im_ready = true

func refresh_definition():
	fix_string_keys()
	create_index_map()

func fix_string_keys():
	var old_definition = entity_defs
	entity_defs = {}
	for key in old_definition:
		var intk = int(key)
		entity_defs[intk] = old_definition[key]
		if "texture" in entity_defs[intk]:
			entity_defs[intk]["texture"] = int(entity_defs[intk]["texture"])
		if "tex_index" in entity_defs[intk]:
			entity_defs[intk]["tex_index"] = int(entity_defs[intk]["tex_index"])

func refresh_entity_list():
	entity_list = get_tree().get_nodes_in_group("_entity_")

func clear_entity_list():
	for entity in entity_list:
		if not entity:
			continue
		entity.remove_from_group("_entity_")
		entity.set_active(false)
		entity.queue_free()
	entity_list = []

func update_entity_definition(entity_index, entity_definition):
	if not entity_index in entity_defs:
		print("ERROR tried to update non-existing entity: " + str(entity_index))
		return
	entity_defs[entity_index] = entity_definition
	refresh_definition()

func get_all_controllers() -> Array:
	return controller_templates.keys()

func new_entity(definition) -> int:
	var try_index = 0
	while try_index in entity_defs:
		try_index += 1
	entity_defs[try_index] = definition
	refresh_definition()
	return try_index

func create_defaults() -> void:
	create_default_player()
	create_default_box()
	
func create_randoms() -> void:
	create_default_player()
	create_random_entity("green_box")
	create_random_entity("swap_box")
	create_random_entity("bouncer")

func create_default_player() -> void:
	create_entity(get_entity_index("player"), Vector2(3, 3))
func create_default_box() -> void:
	create_entity(get_entity_index("green_box"), Vector2(4, 3))

func create_random_entity(entity_name) -> void:
	var tries = 20
	
	while tries > 0:
		tries -= 1
		var entity_pos = Vector2(Utility.random_int_range(1, 11), Utility.random_int_range(1, 11))
		if MapManager.is_blocked(entity_pos):
			continue
		create_entity(get_entity_index(entity_name), entity_pos)
		break

func get_entity_texture(entity_index):
	return TextureManager.get_texture(entity_defs[entity_index]['texture'])

func get_entity_texture_rect(entity_index):
	return TextureManager.get_index_rect(entity_defs[entity_index]['texture'], entity_defs[entity_index]['tex_index'])

func get_new_controller(controller_name):
	return controller_templates[controller_name].instance()

func create_entity(entity_index, tile_position, facing=0, activate=true) -> void:
	var entity_info = entity_defs[entity_index]
	
	var entity = entity_template.instance()
	if "intended_move_speed" in entity_info:
		entity.set_intended_move_speed(entity_info['intended_move_speed'])
	if "controller" in entity_info:
		if entity_info["controller"] in controller_templates:
			var controller = controller_templates[entity_info["controller"]].instance()
			entity.controller_name = entity_info['controller']
			entity.add_child(controller)
			entity.set_controller(controller)
	entity.entity_index = entity_index
	entity.position = Vector2(MapManager.tile_width * tile_position.x, MapManager.tile_width * tile_position.y)
	Utility.get_world().add_child(entity)
	setup_entity_texture(entity)
	
	entity.set_facing(facing)
	
	if "groups" in entity_info:
		for g in entity_info["groups"]:
			entity.add_to_group(g)
	
	if activate:
		entity.set_active(true)
	refresh_entity_list()

func restore_entity(serialized_entity, refresh=true) -> void:
	var entity = entity_template.instance()
	
	Utility.get_world().add_child(entity)
	entity.deserialize(serialized_entity)
	setup_entity_texture(entity)
	
	if refresh:
		refresh_entity_list()

func setup_entity_texture(entity) -> void:
	var texture_index = entity_defs[entity.entity_index]['texture']
	var texture_sub_index = entity_defs[entity.entity_index]['tex_index']
	var sprite = entity.get_node("Sprite")
	sprite.texture = TextureManager.get_texture(texture_index)
	sprite.region_rect = TextureManager.get_index_rect(texture_index, texture_sub_index)

func serialize() -> Dictionary:
	var serialized_entities = []
	for e in entity_list:
		serialized_entities.append(e.serialize())
	
	return {"entity_list": serialized_entities}

func deserialize(data: Dictionary) -> void:
	clear_entity_list()
	for entity_data in data["entity_list"]:
		restore_entity(entity_data)
	refresh_entity_list()

func get_entities_at(tile_position, exclude_entity=null, include_moving_away=false) -> Array:
	var entities_here = []
	for e in entity_list:
		if e == exclude_entity:
			continue
		if e.moving:
			if e.next_tile_pos == tile_position or (include_moving_away and e.tile_position == tile_position):
				entities_here.append(e)
		elif e.tile_position == tile_position:
			entities_here.append(e)
	return entities_here

func create_index_map() -> void:
	entity_index_map = {}
	
	for entity_index in entity_defs:
		var entity_info = entity_defs[entity_index]
		
		if entity_info['name'] in entity_index_map:
			print_debug("WARNING: entity name already in use: " + entity_info['name'])
		entity_index_map[entity_info['name']] = entity_index

func preload_controller_templates() -> void:
	var controller_class_files = []
	var directory_walker:Directory = Directory.new()
	var controllers_path = "res://Scenes/Controllers/"
	if directory_walker.open(controllers_path) == OK:
		directory_walker.list_dir_begin(true)
		
		var file_name = directory_walker.get_next()
		while file_name != "":
			if directory_walker.current_is_dir():
				file_name = directory_walker.get_next()
				continue
			if file_name.ends_with(".tscn"):
				controller_class_files.append(file_name)
			file_name = directory_walker.get_next()
		directory_walker.list_dir_end()
	else:
		print_debug("error opening controller class path")
	
	for fname in controller_class_files:
		var controller_name = fname.split('.')[0]
		controller_templates[controller_name] = load(controllers_path + fname)

func finish_move(moving_entity, tile_position) -> void:
	var entities_here = get_entities_at(tile_position, moving_entity)
	for e in entities_here:
		var ifmot: = get_entity_property(moving_entity, "i_finish_move_onto")
		if ifmot and ifmot.is_conditional():
			ifmot.resolve(moving_entity, e, tile_position)
		var fmot: = get_entity_property(e, "finish_move_onto")
		if fmot and fmot.is_conditional():
			fmot.resolve(e, moving_entity, tile_position)


func attempt_move(moving_entity, tile_position) -> bool:
	var entities_here = get_entities_at(tile_position, moving_entity)
	for e in entities_here:
		var move_onto: = get_entity_property(e, "move_onto")
		
		if move_onto:
			if move_onto.is_conditional():
				if move_onto.resolve(e, moving_entity, tile_position):
					continue
				else:
					return false
			elif not move_onto.get_value():
				return false
		else:
			var blocks: = get_entity_property(e, "blocks")
			if blocks:
				if blocks.is_conditional():
					if not blocks.resolve(e, moving_entity, tile_position):
						continue
					return false
				elif blocks.get_value():
					return false
				else:
					continue
			else:
				continue
		
	return true

func can_move_to(moving_entity, tile_position) -> bool:
	var entities_here = get_entities_at(tile_position, moving_entity)
	for e in entities_here:
		var blocks: = get_entity_property(e, "blocks")
		if blocks:
			if blocks.is_conditional():
				if blocks.resolve(e, moving_entity, tile_position):
					return false
			else:
				if blocks.get_value():
					return false
	return true

func set_entity_property(entity, property_name, property_value) -> void:
	entity.set_local_property(property_name, property_value)

func get_entity_property(entity, property_name) -> Property:
	var value = null
	if not entity.has_local_property(property_name):
		var def_props = entity_defs[entity.entity_index]["properties"]
		if not property_name in def_props:
			return null
		value = def_props[property_name]
	else:
		value = entity.get_local_property(property_name)
	var property = Property.new()
	property.set_value(value)
	property.set_name(property_name)
	return property

func get_entity_definition(entity_index) -> Dictionary:
	return entity_defs[entity_index]

func remove_entity(entity) -> void:
	entity_list.remove(entity_list.find(entity))
	entity.remove_from_group("_entity_")
	entity.set_active(false)
	entity.call_deferred("queue_free")

func get_all_entity_indexes() -> Array:
	var keys = entity_defs.keys()
	keys.sort()
	return keys

func get_entity_index(entity_name) -> int:
	return entity_index_map[entity_name]

func entity_name_exists(entity_name) -> bool:
	return entity_name in entity_index_map

func get_entity_name(entity_index) -> String:
	return entity_defs[entity_index]['name']
