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
		},
		"groups": ["Player"],
	},
	1: {
		"name": "green_box",
		"texture": 1,
		"tex_index": 1,
		"properties": {
			"blocks": {"condition": "has_no_property pusher"},
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
}

var entity_index_map = {}

var entity_list = []

var im_ready = false

func _ready():
	if not TextureManager.im_ready:
		yield(TextureManager, "textures_loaded")
	create_index_map()
	preload_controller_templates()
	
	im_ready = true

func refresh_entity_list():
	entity_list = get_tree().get_nodes_in_group("_entity_")

func create_default_player() -> void:
	create_entity(get_entity_index("player"), Vector2(3, 3))

func create_default_box() -> void:
	var tries = 20
	
	while tries > 0:
		tries -= 1
		var box_pos = Vector2(Utility.random_int_range(1, 11), Utility.random_int_range(1, 11))
		if MapManager.is_blocked(box_pos):
			continue
		create_entity(get_entity_index("green_box"), box_pos)
		break

func create_default_bouncer() -> void:
	var tries = 20
	
	while tries > 0:
		tries -= 1
		var bouncer_pos = Vector2(Utility.random_int_range(1, 11), Utility.random_int_range(1, 11))
		if MapManager.is_blocked(bouncer_pos):
			continue
		create_entity(get_entity_index("bouncer"), bouncer_pos)
		break

func create_entity(entity_index, tile_position, activate=true) -> void:
	var entity_info = entity_defs[entity_index]
	
	var entity = entity_template.instance()
	if "intended_move_speed" in entity_info:
		entity.set_intended_move_speed(entity_info['intended_move_speed'])
	if "controller" in entity_info:
		if entity_info["controller"] in controller_templates:
			var controller = controller_templates[entity_info["controller"]].instance()
			entity.add_child(controller)
			entity.set_controller(controller)
	entity.entity_index = entity_index
	entity.position = Vector2(MapManager.tile_width * tile_position.x, MapManager.tile_width * tile_position.y)
	Utility.get_world().add_child(entity)
	
	var sprite = entity.get_node("Sprite")
	sprite.texture = TextureManager.get_texture(entity_info['texture'])
	
	sprite.region_rect = TextureManager.get_index_rect(entity_info['texture'], entity_info['tex_index'])
	
	if "groups" in entity_info:
		for g in entity_info["groups"]:
			entity.add_to_group(g)
	
	if activate:
		entity.set_active(true)
	refresh_entity_list()

func get_entities_at(tile_position, exclude_entity=null) -> Array:
	var entities_here = []
	for e in entity_list:
		if e == exclude_entity:
			continue
		if e.tile_position == tile_position or e.next_tile_pos == tile_position:
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
		print_debug("loading " + controllers_path + fname)
		controller_templates[controller_name] = load(controllers_path + fname)

func can_move_to(moving_entity, tile_position) -> bool:
	var entities_here = get_entities_at(tile_position, moving_entity)
	for e in entities_here:
		var blocks = get_entity_property(e, "blocks")
		if blocks:
			if typeof(blocks) == TYPE_DICTIONARY:
				var condition: String = blocks["condition"]
				var split_condition = condition.split(' ')
				match split_condition[0]:
					"has_property":
						if get_entity_property(moving_entity, split_condition[1]) != null:
							return false
					"has_no_property":
						if get_entity_property(moving_entity, split_condition[1]) == null:
							return false
			else:
				return false
	return true

func get_entity_property(entity, property_name):
	var props = entity_defs[entity.entity_index]["properties"]
	if not property_name in props:
		return null
	return props[property_name]

func get_entity_index(entity_name) -> int:
	return entity_index_map[entity_name]

func get_entity_name(entity_index) -> String:
	return entity_defs[entity_index]['name']
