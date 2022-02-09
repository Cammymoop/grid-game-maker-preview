extends Node

var all_events = [
	"blocks",
	"finish_move_onto_tile", "i_finish_move_onto_tile",
	"finish_move_onto", "i_finish_move_onto",
	"move_onto",
	"dying",
]

func get_all_events() -> Array:
	return all_events.duplicate()

func resolve_conditional(conditional_name, conditional_data, owning_entity, target_entity, tile_position):
	var condition_stack = []
	var conditions = []
	if "condition" in conditional_data:
		conditions = [conditional_data['condition']]
	elif "conditions" in conditional_data:
		conditions = conditional_data['conditions']
	
	for condition in conditions:
		if condition == "and" or condition == "or":
			var a = condition_stack.pop_back()
			var b = condition_stack.pop_back()
			condition_stack.append(a and b if condition == "and" else a or b)
		
		var split_condition = condition.split(' ')
		var c = split_condition[0]
		match c:
			"has_property", "has_no_property":
				var has_prop = EntityManager.get_entity_property(target_entity, split_condition[1]) != null
				condition_stack.append(has_prop if c == "has_property" else not has_prop)
			"i_have_property", "i_have_no_property":
				var has_prop = EntityManager.get_entity_property(owning_entity, split_condition[1]) != null
				condition_stack.append(has_prop if c == "has_property" else not has_prop)
			"has_name", "has_no_name":
				var is_named = target_entity.entity_name
				condition_stack.append(is_named if c == "has_name" else not is_named)
			"tile_has_property", "tile_has_no_property":
				var has_prop = MapManager.get_tile_property_at(tile_position, split_condition[1]) != null
				condition_stack.append(has_prop if c == "tile_has_property" else not has_prop)
			"tile_has_name", "tile_has_no_name":
				var found = MapManager.is_tile_here(MapManager.get_tile_index(split_condition[1]), tile_position)
				condition_stack.append(found if c == "tile_has_name" else not found)
			"be_pushed":
				if owning_entity.moving:
					condition_stack.append(false)
				else:
					owning_entity.set_real_speed(target_entity.steps_per_tile)
					var move_facing = Utility.resolve_relative_direction(split_condition[1], target_entity.facing)
					condition_stack.append(owning_entity.start_move(move_facing))
			_:
				print_debug("Unrecognized condition: " + c)
	
	if len(condition_stack) > 1:
		print_debug("Condition didnt fully resolve: " + conditional_name + " on " + EntityManager.get_entity_name(owning_entity))
	elif len(condition_stack) == 0:
		condition_stack = [true]
	
	var result = condition_stack[0]
	var quit = false
	if result and "actions" in conditional_data:
		for a in conditional_data['actions']:
			if do_action(a, owning_entity, target_entity, tile_position):
				quit = true
	elif not result and "not_actions" in conditional_data:
		for a in conditional_data['not_actions']:
			if do_action(a, owning_entity, target_entity, tile_position):
				quit = true
	
	if "always_actions" in conditional_data:
		for a in conditional_data['always_actions']:
			if do_action(a, owning_entity, target_entity, tile_position):
				quit = true
	
	var ret = {"quit": quit}
	
	if result:
		if "result" in conditional_data:
			ret['value'] = conditional_data["result"]
		else:
			ret['value'] = true
	else:
		if "not_result" in conditional_data:
			ret['value'] = conditional_data["not_result"]
		else:
			ret['value'] = false
	return ret

func do_action(action_data, owning_entity, target_entity, tile_position):
	var split_action = action_data.split(' ')
	var a = split_action[0]
	
	var quit = false
	match a:
		"die":
			owning_entity.die()
		"kill":
			target_entity.die()
		"save_checkpoint":
			GameManager.save_checkpoint()
		"reset_to_checkpoint":
			GameManager.load_checkpoint()
		"move", "you_move":
			var mover = owning_entity if a == "move" else target_entity
			if mover.moving:
				continue
			var move_facing = -1
			if split_action[1] == "target":
				move_facing = Utility.resolve_relative_direction(split_action[2], target_entity.facing)
			else:
				move_facing = Utility.resolve_relative_direction(split_action[1], owning_entity.facing)
			mover.start_move(move_facing)
		"replace_tile":
			MapManager.replace_tiles_at(tile_position, MapManager.get_tile_index(split_action[1]))
		"find_replace_tiles":
			var tile_from = MapManager.get_tile_index(split_action[1])
			var tile_to = MapManager.get_tile_index(split_action[2])
			MapManager.replace_tiles_at_array(MapManager.get_all_positions_of_tile(tile_from), tile_to)
		"find_swap_tiles":
			var total = len(split_action) - 1
			var tile_indexes = []
			for i in range(total):
				tile_indexes.append(MapManager.get_tile_index(split_action[i + 1]))
			
			var found_tiles = []
			for ti in tile_indexes:
				found_tiles.append(MapManager.get_all_positions_of_tile(ti))
			
			for i in range(len(tile_indexes)):
				var i2 = 0 if i == len(tile_indexes) - 1 else i + 1
				MapManager.replace_tiles_at_array(found_tiles[i], tile_indexes[i2])
		"fill_tile_rectangle", "fill_tile_rectangle_absolute":
			if len(split_action) < 6:
				print_debug("Not enough arguments to fill_tile_rectangle")
				continue
			var relative = a == "fill_tile_rectangle"
			
			var start_x = int(split_action[1]) + tile_position.x if relative else get_int_absolute(split_action[1])
			var start_y = int(split_action[2]) + tile_position.y if relative else get_int_absolute(split_action[2])
			var width = int(split_action[3]) if relative else get_int_absolute(split_action[3])
			var height = int(split_action[4]) if relative else get_int_absolute(split_action[4])
			
			var tile_index = MapManager.get_tile_index(split_action[5])
			var checker_tile = false
			if len(split_action) >= 7:
				checker_tile = MapManager.get_tile_index(split_action[6])
			MapManager.replace_tiles_in_rect(Rect2(start_x, start_y, width, height), tile_index, checker_tile)
		"turn", "you_turn":
			var ent = owning_entity if a == "turn" else target_entity
			if ent.moving:
				continue
			var new_facing = -1
			if split_action[1] == "target":
				new_facing = Utility.resolve_relative_direction(split_action[2], target_entity.facing)
			else:
				new_facing = Utility.resolve_relative_direction(split_action[1], owning_entity.facing)
			if new_facing > -1:
				ent.set_facing(new_facing)
		"set_property", "i_set_property":
			var ent = owning_entity if a == "i_set_property" else target_entity
			EntityManager.set_entity_property(ent, split_action[1], split_action[2])
		"unset_property", "i_unset_property":
			var ent = owning_entity if a == "i_unset_property" else target_entity
			ent.remove_local_property(split_action[1])
		"done":
			quit = true
		_:
			print_debug("Unrecognized action: " + a)
	return quit

func get_int_absolute(input_num: String) -> int:
	match input_num:
		"level_x":
			return int(MapManager.get_map_size().position.x)
		"level_y":
			return int(MapManager.get_map_size().position.y)
		"level_width":
			return int(MapManager.get_map_size().size.x)
		"level_height":
			return int(MapManager.get_map_size().size.y)
	return int(input_num)
