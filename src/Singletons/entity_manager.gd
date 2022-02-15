extends Node

signal entity_list_updated

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
var entity_instance_map = {}

var entity_list = []
var bond_groups = []

var im_ready = false

var instance_counter = 0

var frame_counter = 0

func _physics_process(_delta):
	frame_counter += 1

func _ready():
	if not TextureManager.im_ready:
		yield(TextureManager, "textures_loaded")
	create_index_map()
	preload_controller_templates()
	
	im_ready = true

func create_signal(signal_name) -> void:
	add_user_signal(signal_name)


func do_emit_signal(signal_name, owning_entity=null, args=null) -> void:
	if not has_user_signal(signal_name):
		add_user_signal(signal_name)
	if not args:
		args = []
	emit_signal(signal_name, owning_entity, args)

func refresh_definition():
	fix_string_keys()
	create_index_map()

func clear():
	bond_groups = []

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

func entity_order(a, b) -> bool:
	if a.entity_index == b.entity_index:
		return a.instance_id < b.instance_id
	return a.entity_index < b.entity_index

func refresh_entity_list():
	entity_instance_map = {}
	entity_list = get_tree().get_nodes_in_group("_entity_")
	entity_list.sort_custom(self, "entity_order")
	for e in entity_list:
		entity_instance_map[e.instance_id] = e
	
	emit_signal("entity_list_updated")

func clear_entity_list():
	for entity in entity_list:
		if not entity:
			continue
		entity.remove_from_group("_entity_")
		entity.set_active(false)
		entity.queue_free()
	entity_list = []
	entity_instance_map = {}

func get_instance(instance_id):
	if not instance_id in entity_instance_map:
		return null
	return entity_instance_map[instance_id]

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
	#create_default_box()
	
func create_randoms() -> void:
	create_default_player()
	create_random_entity("green_box")
	create_random_entity("swap_box")
	create_random_entity("bouncer")

func create_default_player() -> void:
	create_entity(get_entity_index("player"), Vector2(2, 2))
func create_default_box() -> void:
	create_entity(get_entity_index("green_box"), Vector2(2, 1))

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

func add_entity_to_world(entity):
	var destination = Utility.get_world().get_node("Entities")
	for c in destination.get_children():
		if c.entity_index > entity.entity_index:
			destination.add_child_below_node(c, entity)
			return
	destination.add_child(entity)

func create_entity(entity_index, tile_position, facing=0, activate=true) -> Node2D:
	var entity_info = entity_defs[entity_index]
	
	var entity = entity_template.instance()
	if "intended_move_speed" in entity_info:
		entity.set_intended_move_speed(entity_info['intended_move_speed'])
	if "controller" in entity_info:
		if entity_info["controller"] in controller_templates:
			var controller = get_new_controller(entity_info["controller"])
			entity.controller_name = entity_info['controller']
			entity.add_child(controller)
			entity.set_controller(controller)
			if "controller_options" in entity_info:
				controller.set_options(entity_info["controller_options"])
	entity.entity_index = entity_index
	entity.position = Vector2(MapManager.tile_width * tile_position.x, MapManager.tile_width * tile_position.y)
	add_entity_to_world(entity)
	entity.initialize()
	setup_entity_texture(entity)
	
	entity.set_facing(facing)
	if entity.visual_turn_on_move:
		entity.set_visual_facing(facing)
	
	if "groups" in entity_info:
		for g in entity_info["groups"]:
			entity.add_to_group(g)
	
	entity.instance_id = instance_counter
	instance_counter += 1
	
	var auto_bond = get_entity_property(entity, "auto_bond")
	if auto_bond:
		var need_to_bond = false
		if auto_bond.is_conditional():
			if auto_bond.resolve(self, null, entity.tile_position):
				need_to_bond = true
		elif auto_bond.get_value():
			need_to_bond = true
		
		if need_to_bond:
			var bonded = false
			for abg in bond_groups:
				# This is possible to break if you first add an auto bonding entity to another bonding group I think
				# Pretty sure it's actually kind of hard to break
				if get_instance(abg[0]).entity_index == entity_index:
					bond_entity(entity, abg)
					bonded = true
					break
			if not bonded:
				create_bond_group([entity])
	
	if activate:
		entity.set_active(true)
	refresh_entity_list()
	
	return entity

func restore_entity(serialized_entity, refresh=true) -> void:
	var entity = entity_template.instance()
	
	add_entity_to_world(entity)
	entity.deserialize(serialized_entity)
	entity.initialize() # initialize after deserializing
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
	
	return {"entity_list": serialized_entities, "bond_groups": bond_groups}

func deserialize(data: Dictionary) -> void:
	clear_entity_list()
	for entity_data in data["entity_list"]:
		restore_entity(entity_data)
	bond_groups = data["bond_groups"]
	refresh_entity_list()
	instance_counter = 0
	for e in entity_list:
		instance_counter = max(instance_counter, e.instance_id + 1)

func create_bond_group(entities: Array) -> void:
	var group = []
	bond_groups.append(group)
	for e in entities:
		group.append(e.instance_id)
		e.bond_group = group

func remove_entities_bond_group(entity) -> void:
	if not entity.bond_group:
		return
	for e in entity.bond_group:
		unbond_entity(e, false)
	bond_group_update()

func bond_entity(entity, bond_group) -> void:
	entity.bond_group = bond_group
	bond_group.append(entity.instance_id)

func unbond_entity(entity, cull_empty=true) -> void:
	if entity.bond_group:
		var bg = entity.bond_group
		bg.remove(bg.find(entity.instance_id))
		entity.bond_group = null
		if cull_empty:
			bond_group_update()

func bond_group_update() -> void:
	var to_remove = []
	for bg_index in range(len(bond_groups)):
		if len(bond_groups[bg_index]) < 1:
			to_remove.append(bg_index)
	
	# Reverse so we delete starting from the end and the indexes still hold after each delete
	to_remove.invert()
	for index in to_remove:
		bond_groups.remove(index)

func get_bond_group(entity):
	for bg in bond_groups:
		if bg.has(entity.instance_id):
			return bg
	return null

func bond_group_start_move(bond_group, steps_per_tile, move_facing) -> bool:
	var instances = []
	for entity_instance_id in bond_group:
		instances.append(get_instance(entity_instance_id))
	
	for entity in instances:
		if entity.moving:
			# Short circuit so we dont break by reverting a move on a currently moving entity
			return false
	
	var move_allowed = true
	for entity in instances:
		# set change visual facing to false for group moves for now
		# good default but should be configurable somehow
		entity.set_current_speed(steps_per_tile)
		if not entity.start_move(move_facing, false, true):
			move_allowed = false
	
	# At least one of the entities in the bond group were blocked
	# Stop them all from moving
	if not move_allowed:
		for entity in instances:
			entity.revert_move_start()
	else:
		for entity in instances:
			post_move_actions(entity, entity.tile_position, entity.next_tile_pos)
			entity.actually_started_move()
	return move_allowed

func get_entities_at(tile_position, exclude_entity=null, exclude_bond_group=null, include_moving_away=false) -> Array:
	var entities_here = []
	for e in entity_list:
		if e == exclude_entity:
			continue
		if exclude_bond_group and e.instance_id in exclude_bond_group:
			continue
		if e.moving:
			if e.next_tile_pos == tile_position or (include_moving_away and e.tile_position == tile_position):
				entities_here.append(e)
		elif e.tile_position == tile_position:
			entities_here.append(e)
	return entities_here

func find_entity_by_index(entity_index, first=true):
	var found = null
	if first:
		for e in entity_list:
			if e.entity_index == entity_index:
				if first:
					return e
				else:
					found = e
	return found

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


func attempt_move(moving_entity, tile_position, group_move=false) -> bool:
	var entities_here: = []
	if group_move:
		entities_here = get_entities_at(moving_entity.tile_position, null, moving_entity.bond_group)
	else:
		entities_here = get_entities_at(moving_entity.tile_position, moving_entity)
	for e in entities_here:
		var move_off_of: = get_entity_property(e, "move_off_of")
		if move_off_of:
			if move_off_of.is_conditional():
				if not move_off_of.resolve(e, moving_entity, tile_position):
					return false
			elif not move_off_of.get_value():
				return false
	
	var entities_there: = []
	if group_move:
		entities_there = get_entities_at(tile_position, null, moving_entity.bond_group)
	else:
		entities_there = get_entities_at(tile_position, moving_entity)
	for e in entities_there:
		if e in entities_here:
			continue
		var blocks: = get_entity_property(e, "blocks")
		if blocks:
			if blocks.is_conditional():
				if blocks.resolve(e, moving_entity, tile_position):
					return false
			elif blocks.get_value():
				return false
		
		var move_onto: = get_entity_property(e, "move_onto")
		if move_onto:
			if move_onto.is_conditional():
				if not move_onto.resolve(e, moving_entity, tile_position):
					return false
			elif not move_onto.get_value():
				return false
		
	return true

func post_move_actions(moving_entity, from_position, to_position, exclude_group=null) -> void:
	var entities_start = get_entities_at(from_position, moving_entity, exclude_group)
	for e in entities_start:
		var pmove_off_of: = get_entity_property(e, "post_move_off_of")
		if pmove_off_of and pmove_off_of.is_conditional():
			pmove_off_of.resolve(e, moving_entity, from_position)
	
	var entities_destination = get_entities_at(to_position, moving_entity, exclude_group)
	for e in entities_destination:
		var pmove_onto: = get_entity_property(e, "post_move_onto")
		if pmove_onto and pmove_onto.is_conditional():
			pmove_onto.resolve(e, moving_entity, to_position)

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
		if property_name in def_props:
			value = def_props[property_name]
		elif "inherit_properties" in def_props:
			var inherit_from = get_entity_index(def_props["inherit_properties"])
			var inherit_props = entity_defs[inherit_from]["properties"]
			if not property_name in inherit_props:
				return null
			value = inherit_props[property_name]
		else:
			return null
	else:
		value = entity.get_local_property(property_name)
	var property = Property.new()
	property.set_value(value)
	property.set_name(property_name)
	return property

func get_entity_property_list(entity) -> Array:
	var props: Dictionary = {}
	var definition_props = entity_defs[entity.entity_index]["properties"]
	Utility.set_keys(props, definition_props.keys())
	Utility.set_keys(props, entity.local_properties.keys())
	if "inherit_properties" in definition_props:
		var inherit_from = get_entity_index(definition_props["inherit_properties"])
		Utility.set_keys(props, entity_defs[inherit_from]["properties"].keys())
	
	return props.keys()

func get_entity_definition(entity_index) -> Dictionary:
	return entity_defs[entity_index].duplicate()

func remove_entity(entity) -> void:
	entity_list.remove(entity_list.find(entity))
	if entity.bond_group:
		unbond_entity(entity)
	entity.remove_from_group("_entity_")
	entity.set_active(false)
	entity.call_deferred("queue_free")

func get_all_entity_indexes() -> Array:
	var keys = entity_defs.keys()
	keys.sort()
	return keys

func get_all_entity_names() -> Array:
	var names = []
	for e in entity_defs:
		names.append(entity_defs[e]["name"])
	return names

func get_entity_index(entity_name) -> int:
	return entity_index_map[entity_name]

func entity_name_exists(entity_name) -> bool:
	return entity_name in entity_index_map

func get_entity_name(entity_index) -> String:
	return entity_defs[entity_index]['name']
