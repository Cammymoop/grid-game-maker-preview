extends Node

var clipboard_stuff: Variant
var clipboard_type: String = ""

func get_clipboard_type() -> String:
	return clipboard_type

func set_clipboard_stuff(stuff: Variant, type: String) -> void:
	clipboard_stuff = stuff
	clipboard_type = type


func copy_properties(properties: Dictionary) -> void:
	set_clipboard_stuff(properties.duplicate_deep(), "properties")

func copy_property_value(property_name: String, value: Variant) -> void:
	copy_properties_values({property_name: value})

func copy_properties_values(properties: Dictionary) -> void:
	set_clipboard_stuff(properties.duplicate_deep(), "property_values")

func get_properties() -> Dictionary:
	if clipboard_type in ["properties", "property_values"]:
		return clipboard_stuff.duplicate_deep()
	return {}

func get_property_value() -> Variant:
	if not has_property_value():
		return false
	return clipboard_stuff.values()[0]

func has_property_value() -> bool:
	if not clipboard_type == "property_values":
		return false
	if clipboard_stuff.size() != 1:
		return false
	return true

func has_properties() -> bool:
	return clipboard_type in ["properties", "property_values"]


func copy_entity_type(entity_definition: Dictionary) -> void:
	copy_items({"entities": [entity_definition]})

func copy_entity_types(entity_definitions: Array) -> void:
	copy_items({"entities": entity_definitions})

func copy_tile_type(tile_definition: Dictionary) -> void:
	copy_items({"tiles": [tile_definition]})

func copy_tile_types(tile_definitions: Array) -> void:
	copy_items({"tiles": tile_definitions})

func copy_items(items: Dictionary) -> void:
	set_clipboard_stuff(items.duplicate_deep(), "items")

func get_items() -> Dictionary:
	if clipboard_type == "items":
		return clipboard_stuff.duplicate_deep()
	return {}

func get_entity_types() -> Array:
	return get_items().get("entities", [])

func get_tile_types() -> Array:
	return get_items().get("tiles", [])

func has_items() -> bool:
	return clipboard_type == "items"

func has_entity_types() -> bool:
	return clipboard_type == "items" and clipboard_stuff.get("entities", []).size() > 0

func has_tile_types() -> bool:
	return clipboard_type == "items" and clipboard_stuff.get("tiles", []).size() > 0



func copy_entity_instances(entity_instances: Array) -> void:
	var serialized_instances: Array = []
	for instance in entity_instances:
		serialized_instances.append(instance.serialize())
	set_clipboard_stuff(serialized_instances, "serialized_entities")

func has_entity_instances() -> bool:
	return clipboard_type == "serialized_entities"

func get_serialized_entity_instances() -> Array[Dictionary]:
	if clipboard_type == "items":
		return clipboard_stuff.get("entities", [])
	return []


func copy_sprite_config(entity_definition: Dictionary) -> void:
	var sprite_conf_or_simple: Dictionary = entity_definition.get("sprite_config", {})
	if not sprite_conf_or_simple:
		sprite_conf_or_simple = {
			"is_simple": true,
			"texture": entity_definition['texture'],
			"tex_index": entity_definition['tex_index'],
		}
	set_clipboard_stuff(sprite_conf_or_simple.duplicate_deep(), "sprite_config")

func get_sprite_config() -> Dictionary:
	if clipboard_type == "sprite_config":
		return clipboard_stuff.duplicate_deep()
	return {}

func has_sprite_config() -> bool:
	return clipboard_type == "sprite_config"