extends Node

var move_mode = "facing"

@onready var parent = get_parent()

var options: Dictionary = {
	"target_entity_property": {"display_name": "Chase Entities with property", "type": "property"},
	"always_update_target": {"display_name": "Immediately switch to closer target", "type": "bool"},
	"only_target_active": {"display_name": "Only target active entities", "type": "bool"},
}

var target_entity_property: String = "player"
var only_target_active: bool = true
var always_update_target: bool = false
var targeted_entity: BaseEntity = null

func get_options() -> Dictionary:
	return options

func set_options(new_options: Dictionary) -> void:
	if "target_entity_property" in new_options:
		target_entity_property = new_options["target_entity_property"]
	if "always_update_target" in new_options:
		always_update_target = new_options["always_update_target"]

func get_default_options() -> Dictionary:
	return {
		"target_entity_property": target_entity_property,
		"always_update_target": always_update_target,
		"only_target_active": only_target_active,
	}

func get_option_values() -> Dictionary:
	return {
		"target_entity_property": target_entity_property,
		"always_update_target": always_update_target,
		"only_target_active": only_target_active,
	}

func get_max_move_intentions() -> int:
	return 2

func get_move(attempt_num: int):
	if not EntityManager.controller_frame:
		return -1
	
	if attempt_num == 0:
		update_targeted_entity()
	if not targeted_entity:
		return -1
		
	var position_delta: = Vector2i(targeted_entity.next_tile_pos - parent.tile_position)
	if position_delta == Vector2i.ZERO:
		return -1
	
	var intended_move_facing: = -1
	if attempt_num == 0:
		intended_move_facing = Utility.biased_vector_to_facing(position_delta, true)
	else:
		intended_move_facing = Utility.vector_to_facing_alternate(position_delta, true, true)
	return intended_move_facing

func update_targeted_entity() -> void:
	if not target_entity_property:
		return
	if not always_update_target:
		if targeted_entity and EntityManager.is_valid_entity_in_world(targeted_entity):
			return
	targeted_entity = EntityManager.find_closest_entity_with_property(target_entity_property, parent.tile_position, [parent], not only_target_active)
