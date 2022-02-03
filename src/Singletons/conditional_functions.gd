extends Node


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
			"tile_has_property", "tile_has_no_property":
				var has_prop = MapManager.get_tile_property_at(tile_position, split_condition[1]) != null
				condition_stack.append(has_prop if c == "tile_has_property" else not has_prop)
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
	if result and "actions" in conditional_data:
		for a in conditional_data['actions']:
			do_action(a, owning_entity, target_entity, tile_position)
	elif not result and "not_actions" in conditional_data:
		for a in conditional_data['not_actions']:
			do_action(a, owning_entity, target_entity, tile_position)
	
	if "always_actions" in conditional_data:
		for a in conditional_data['always_actions']:
			do_action(a, owning_entity, target_entity, tile_position)
	
	if result:
		if "result" in conditional_data:
			return conditional_data["result"]
		else:
			return true
	else:
		if "not_result" in conditional_data:
			return conditional_data["not_result"]
		else:
			return false

func do_action(action_data, owning_entity, target_entity, tile_position):
	var split_action = action_data.split(' ')
	var a = split_action[0]
	match a:
		"die":
			owning_entity.die()
		"kill":
			target_entity.die()
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
		_:
			print_debug("Unrecognized action: " + a)
