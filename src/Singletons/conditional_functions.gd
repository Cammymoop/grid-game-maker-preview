extends Node

var all_events = [
	"blocks",
	"finish_move_onto_tile", "i_finish_move_onto_tile",
	"finish_move_onto", "i_finish_move_onto",
	"move_onto", "move_off_of",
	"post_move_onto", "post_move_off_of",
	"post_move",
	"when_signal_[signal]",
	"idle_update",
	"dying",
]

func get_all_events() -> Array:
	return all_events.duplicate()

func resolve_conditional(conditional_name, conditional_data, owning_entity, target_entity, tile_position, arguments):
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
			continue
		if condition == "not":
			var top = condition_stack.pop_back()
			condition_stack.append(not top)
			continue
		
		var split_condition = condition.split(' ')
		var c = split_condition[0]
		match c:
			"has_property", "has_no_property":
				var has_prop = EntityManager.get_entity_property(target_entity, split_condition[1]) != null
				condition_stack.append(has_prop if c == "has_property" else not has_prop)
			"property_equals":
				var arg = 1
				var ent = owning_entity
				var equals = false
				if split_condition[1] == "target":
					ent = target_entity
					arg += 1
				var prop_value = EntityManager.get_entity_property(ent, split_condition[arg])
				if prop_value.is_conditional():
					prop_value = prop_value.resolve(owning_entity, target_entity, tile_position)
				else:
					prop_value = prop_value.get_value()
					
				arg += 1
				if split_condition[arg].substr(0, 4) == "arg_":
					var arg_num = int(split_condition[arg].substr(4))
					var value2
					if len(arguments) >= arg_num:
						value2 = arguments[arg_num - 1]
					else:
						print_debug("Not enough arguments")
						condition_stack.append(false)
						continue
					equals = value2 == prop_value
				else:
					ent = owning_entity
					if split_condition[arg] == "target":
						ent = target_entity
						arg += 1
					var prop_value2 = EntityManager.get_entity_property(ent, split_condition[arg])
					if prop_value2.is_conditional():
						prop_value2 = prop_value2.resolve(owning_entity, target_entity, tile_position)
					else:
						prop_value2 = prop_value2.get_value()
					equals = prop_value == prop_value2
				
				condition_stack.append(equals)
			"can_move", "cant_move":
				var facing = split_condition[1]
				if facing == "target":
					facing = Utility.resolve_relative_direction(split_condition[2], target_entity.facing)
				else:
					if Utility.is_absolute_direction(facing):
						facing = Utility.direction_to_facing(facing)
					else:
						facing = Utility.resolve_relative_direction(facing, owning_entity.facing)
				var can_move = owning_entity.can_i_move(facing)
				condition_stack.append(can_move if c == "can_move" else not can_move)
			"is_entity_in_direction":
				var facing = split_condition[1]
				var arg = 1
				var check_visual = false
				var check_entity = owning_entity
				if split_condition[1] == "visual":
					check_visual = true
					arg += 1
				elif split_condition[1] == "target":
					check_entity = target_entity
				
				if facing == "tile":
					facing = Utility.resolve_relative_direction(split_condition[arg], MapManager.get_tile_facing_at(tile_position))
					arg += 1
				elif Utility.is_absolute_direction(facing):
					facing = Utility.direction_to_facing(facing)
				else:
					var ent_facing = check_entity.visual_facing if check_visual else check_entity.facing
					facing = Utility.resolve_relative_direction(facing, ent_facing)
				
				var check_position = owning_entity.tile_position + Utility.facing_vector(facing)
				var entities_are_there = len(EntityManager.get_entities_at(check_position, owning_entity)) > 0
				
				condition_stack.append(entities_are_there)
			"i_have_property", "i_have_no_property":
				var has_prop = EntityManager.get_entity_property(owning_entity, split_condition[1]) != null
				condition_stack.append(has_prop if c == "has_property" else not has_prop)
			"has_name", "has_no_name":
				var is_named = target_entity.entity_name == split_condition[1]
				condition_stack.append(is_named if c == "has_name" else not is_named)
			"i_am_moving", "is_moving":
				var is_moving = target_entity.moving if c == "is_moving" else owning_entity.moving
				condition_stack.append(is_moving)
			"named_entity_is_here", "named_entity_is_not_here":
				var entities_here = EntityManager.get_entities_at(tile_position, owning_entity)
				var name_is_here = false
				for e in entities_here:
					if e.entity_name == split_condition[1]:
						name_is_here = true
				condition_stack.append(name_is_here if c == "named_entity_is_here" else not name_is_here)
			"is_facing", "is_not_facing":
				var facing = split_condition[1]
				var arg = 1
				var check_visual = false
				if split_condition[1] == "visual":
					check_visual = true
					arg += 1
				if facing == "tile":
					facing = Utility.resolve_relative_direction(split_condition[arg], MapManager.get_tile_facing_at(tile_position))
					arg += 1
				elif Utility.is_absolute_direction(facing):
					facing = Utility.direction_to_facing(facing)
				else:
					var owner_facing = owning_entity.visual_facing if check_visual else owning_entity.facing
					facing = Utility.resolve_relative_direction(facing, owner_facing)
				var check_target_visual = false
				if arg < len(split_condition) - 1:
					if split_condition[arg] == "visual":
						check_target_visual = true
				
				var target_facing = target_entity.facing
				if check_target_visual:
					target_facing = target_entity.visual_facing
				var same_facing = target_facing == facing
				condition_stack.append(same_facing if c == "is_facing" else not same_facing)
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
					owning_entity.set_current_speed(target_entity.steps_per_tile)
					var move_facing = Utility.resolve_relative_direction(split_condition[1], target_entity.facing)
					var visual_turn = true
					if 2 <= len(split_condition) - 1:
						if split_condition[2] == "false":
							visual_turn = false
					condition_stack.append(owning_entity.start_move(move_facing, visual_turn))
			_:
				print_debug("Unrecognized condition: " + c)
	
	if len(condition_stack) > 1:
		print_debug("Condition didnt fully resolve: " + conditional_name + " on " + EntityManager.get_entity_name(owning_entity.entity_index))
	elif len(condition_stack) == 0:
		condition_stack = [true]
	
	var result = condition_stack[0]
	var quit = false
	if result and "actions" in conditional_data:
		for a in conditional_data['actions']:
			if do_action(a, owning_entity, target_entity, tile_position, arguments):
				quit = true
	elif not result and "not_actions" in conditional_data:
		for a in conditional_data['not_actions']:
			if do_action(a, owning_entity, target_entity, tile_position, arguments):
				quit = true
	
	if "always_actions" in conditional_data:
		for a in conditional_data['always_actions']:
			if do_action(a, owning_entity, target_entity, tile_position, arguments):
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

func do_action(action_data, owning_entity, target_entity, tile_position, arguments):
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
		"copy_move_speed", "send_move_speed":
			var to_ent = owning_entity if a == "copy_move_speed" else target_entity
			var from_ent = target_entity if a == "copy_move_speed" else owning_entity
			to_ent.set_current_speed(from_ent.steps_per_tile)
		"move", "you_move":
			var mover = owning_entity if a == "move" else target_entity
			if mover.moving:
				return false
			var move_facing = -1
			var arg = 2
			if split_action[1] == "target":
				move_facing = Utility.resolve_relative_direction(split_action[2], target_entity.facing)
				arg += 1
			else:
				move_facing = Utility.resolve_relative_direction(split_action[1], owning_entity.facing)
			
			var visual_turn = true
			if arg <= len(split_action) - 1:
				if split_action[arg] == "false":
					visual_turn = false
			mover.start_move(move_facing, visual_turn)
		"replace_tile":
			MapManager.replace_tiles_at(tile_position, MapManager.get_tile_index(split_action[1]))
		"make_entity":
			var index = EntityManager.get_entity_index(split_action[1])
			var at_position = tile_position
			var at_facing = owning_entity.facing
			
			var arg = 2
			if arg <= len(split_action) - 1:
				if split_action[arg] == "target":
					at_facing = Utility.resolve_relative_direction(split_action[arg + 1], target_entity.facing)
					arg += 2
				else:
					if Utility.is_absolute_direction(split_action[arg]):
						at_facing = Utility.direction_to_facing(split_action[arg])
					else:
						at_facing = Utility.resolve_relative_direction(split_action[arg], owning_entity.facing)
					arg += 1
			
			var new_entity = EntityManager.create_entity(index, at_position, at_facing)
			if arg <= len(split_action) - 1:
				if split_action[arg] == "true":
					new_entity.start_move(at_facing)
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
				return false
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
				return false
			var new_facing = -1
			var arg = 2
			if split_action[1] == "target":
				new_facing = Utility.resolve_relative_direction(split_action[2], target_entity.facing)
				arg += 1
			else:
				if Utility.is_absolute_direction(split_action[1]):
					new_facing = Utility.direction_to_facing(split_action[1])
				elif split_action[1].substr(0, 5) == "prop":
					# TODO this currently turns based on actual int facing values gotten from properties
					# At some point this should handle direction strings, including relative
					var prop_name = split_action[2]
					var prop = EntityManager.get_entity_property(owning_entity, prop_name)
					if prop:
						if prop.is_conditional():
							new_facing = int(prop.resolve(owning_entity, target_entity, tile_position, arguments))
						else:
							new_facing = int(prop.get_value())
					arg += 1
				else:
					new_facing = Utility.resolve_relative_direction(split_action[1], owning_entity.facing)
			if new_facing > -1:
				var secondary = false
				if arg <= len(split_action) - 1:
					secondary = split_action[arg]
				if not secondary or secondary != "visual":
					ent.set_facing(new_facing)
				if (not secondary and ent.visual_turn_on_move) or (bool(secondary) and secondary != "actual"):
					ent.set_visual_facing(new_facing)
		"set_property", "i_set_property":
			var val = true
			if len(split_action) > 2:
				val = split_action[2]
				if val.to_lower() == "true":
					val = true
				elif val.to_lower() == "false":
					val = false
				elif val.substr(0, 4) == "arg_":
					var arg_num = int(val.substr(4))
					if len(arguments) >= arg_num:
						val = arguments[arg_num - 1]
					else:
						print_debug("Not enough arguments")
			var ent = owning_entity if a == "i_set_property" else target_entity
			EntityManager.set_entity_property(ent, split_action[1], val)
		"increment_property", "decrement_property":
			var ent = owning_entity
			var prop_name = split_action[1]
			if split_action[1] == "target":
				ent = target_entity
				prop_name = split_action[2]
			var val = EntityManager.get_entity_property(ent, prop_name)
			if val.is_conditional():
				print_debug("Cant increment/decrement conditional")
				return false
			val = val.get_value() + (1 if a == "increment_property" else -1)
			EntityManager.set_entity_property(ent, prop_name, val)
		"save_facing":
			EntityManager.set_entity_property(owning_entity, split_action[1], target_entity.facing)
		"unset_property", "i_unset_property":
			var ent = owning_entity if a == "i_unset_property" else target_entity
			ent.remove_local_property(split_action[1])
		"send_signal":
			var ent = owning_entity
			var arg_start = 2
			if len(split_action) > 2 and split_action[2] == "target":
				arg_start = 3
				ent = target_entity
			
			var args: = []
			if arg_start < len(split_action) - 1:
				args = split_action.slice(arg_start)
			EntityManager.do_emit_signal(split_action[1], ent, args)
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
