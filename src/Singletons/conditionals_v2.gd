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

var Slot = Commands.Slot

var CommandCodes = Commands.CC

var FIRST_CONDITION = CommandCodes.C_HAS_PROPERTY
var FIRST_ACTION = CommandCodes.A_DIE

var original_me
var original_them
var original_here

func make_slots(owning_entity, target_entity, tile_position, arguments = []) -> Dictionary:
	var slots = {}
	slots[Slot.RED] = owning_entity
	slots[Slot.BLUE] = target_entity
	slots[Slot.GREY] = [tile_position]
	slots[Slot.BLACK] = []
	slots[Slot.THIS_TILE] = tile_position
	
	if arguments:
		var arg_slots = [Slot.DARK_RED, Slot.DARK_BLUE, Slot.DARK_GREEN, Slot.DARK_ORANGE,]
		for i in range(min(4, len(arguments))):
			slots[arg_slots[i]] = arguments[i]
	return slots

func slot_value(slots: Dictionary, slot: int):
	if not slots.has(slot):
		return null
	return slots[slot]

func get_all_events() -> Array:
	return all_events.duplicate()

func and_array(arr: Array) -> bool:
	var res = true
	for item in arr:
		res = res and item
	return res

func resolve_conditional(conditional: Dictionary, slots: Dictionary):
	original_me = slots[Slot.RED]
	original_them = slots[Slot.BLUE]
	original_here = slots[Slot.GREY]
	
	var condition_stack = []
	for condition in conditional.conditions:
		if typeof(condition) == TYPE_STRING:
			if condition == "and" or condition == "or":
				var a = condition_stack.pop_back()
				var b = condition_stack.pop_back()
				condition_stack.append(a and b if condition == "and" else a or b)
			elif condition == "not":
				var top = condition_stack.pop_back()
				condition_stack.append(not top)
		else:
			condition_stack.append(do_command_data(condition, slots))
	
#	if len(condition_stack) > 1:
#		print_debug("Conditions not fully resolved: " + str(condition_stack))
#		assert(false)
	
	var final_result = true
	if len(condition_stack) > 1:
		final_result = and_array(condition_stack)
	elif condition_stack:
		final_result = condition_stack[0]
	
	var quit = false
	
	if final_result:
		for action in conditional.get("true_actions", []):
			if do_command_data(action, slots):
				quit = true
		
		if "true_result" in conditional:
			final_result = conditional["true_result"]
	else:
		for action in conditional.get("false_actions", []):
			if do_command_data(action, slots):
				quit = true
		
		if "false_result" in conditional:
			final_result = conditional["false_result"]
	
	for action in conditional.get("always_actions", []):
		if do_command_data(action, slots):
			quit = true
	
	return {"result": final_result, "quit": quit}

func do_command_data(command_data: Dictionary, slots: Dictionary):
	return do_command(command_data["code"], command_data["slot"], slots, command_data["options"])

func do_command(command_code: int, selected_slot: int, slots: Dictionary, command_options: Array = []):
	if Commands.is_action(command_code):
		return do_action(command_code, selected_slot, slots, command_options)
	elif Commands.is_condition(command_code):
		return do_condition(command_code, selected_slot, slots, command_options)
	else:
		return do_other(command_code, selected_slot, slots, command_options)

# Returns true to short-circuit resolving further actions
func do_action(command_code: int, selected_slot: int, slots: Dictionary, command_options: Array = []) -> bool:
	var selected = null
	if selected_slot > -1:
		selected = slot_value(slots, selected_slot)
	
	match command_code:
		CommandCodes.A_QUIT:
			return true
		CommandCodes.A_DIE:
			selected.die()
		CommandCodes.A_MOVE:
			selected.start_move(Utility.resolve_full_direction_to_facing(command_options[0], slots))
		CommandCodes.A_SWAP_TILES:
			var tid_0 = MapManager.get_tile_index(command_options[0])
			var tid_1 = MapManager.get_tile_index(command_options[1])
			var tile_positions_a = MapManager.get_all_positions_of_tile(tid_0, selected)
			var tile_positions_b = MapManager.get_all_positions_of_tile(tid_1, selected)
			MapManager.replace_tiles_at_array(tile_positions_a, tid_1)
			MapManager.replace_tiles_at_array(tile_positions_b, tid_0)
		CommandCodes.A_SET_TILES:
			var tid = MapManager.get_tile_index(command_options[0])
			MapManager.replace_tiles_at_array(selected, tid)
		
		CommandCodes.A_SET_PROPERTY:
			var value = command_options[1]
			selected.set_local_property(command_options[0], value)
		CommandCodes.A_PROPERTY_ADD:
			var existing_val = 0
			if selected.has_local_property(command_options[0]):
				existing_val = int(selected.get_local_property(command_options[0]))
			selected.set_local_property(command_options[0], existing_val + int(command_options[1])) # TODO support float or save actual type data to json
		CommandCodes.A_PROPERTY_SUBTRACT:
			var existing_val = 0
			if selected.has_local_property(command_options[0]):
				existing_val = int(selected.get_local_property(command_options[0]))
			var new_val = existing_val - int(command_options[1])
			selected.set_local_property(command_options[0], new_val)
			if command_options[2] and new_val <= 0:
				selected.remove_local_property(command_options[0])
		CommandCodes.A_REMOVE_PROPERTY:
			selected.remove_local_property(command_options[0])
		
		CommandCodes.A_SAVE_CHECKPOINT:
			GameManager.save_checkpoint()
		CommandCodes.A_LOAD_CHECKPOINT:
			GameManager.load_checkpoint()
		
	return false

func do_condition(command_code: int, selected_slot: int, slots: Dictionary, command_options: Array = []):
	var selected = slots[selected_slot]
	match command_code:
		CommandCodes.C_HAS_PROPERTY:
			var result = false
			if Commands.slot_is_entity(selected_slot):
				result = EntityManager.entity_has_property(selected, command_options[1])
			else:
				if len(selected) < 1:
					result = false
				else:
					result = MapManager.get_tile_property_at(selected[0], command_options[1]) != null
			return not result if command_options[0] else result
		CommandCodes.C_HAS_NAME:
			var result = selected.entity_name == str(command_options[1])
			return not result if command_options[0] else result
		CommandCodes.C_CAN_MOVE:
			var facing = Utility.resolve_full_direction_to_facing(command_options[1], slots)
			var result = selected.can_i_move(facing)
			return not result if command_options[0] else result
		
		CommandCodes.C_GET_PUSHED:
			if selected.moving:
				return false
			else:
				var facing = Utility.resolve_full_direction_to_facing(command_options[0], slots)
				
				var blue_entity = slots[Slot.BLUE]
				selected.set_current_speed(blue_entity.steps_per_tile)
				
				var visual_turn = not command_options[1]
				return selected.start_move(facing, visual_turn)

func do_other(command_code: int, selected_slot: int, slots: Dictionary, command_options: Array = []):
	#var selected = slots[selected_slot]
	match command_code:
		CommandCodes.SELECT_DEFAULTS:
			slots[Slot.RED] = original_me
			slots[Slot.BLUE] = original_them
			slots[Slot.GREY] = [original_here]
			slots[Slot.BLACK] = []
#			match command_options[0]:
#				"me":
#					slots[selected_slot] = original_me
#				"them":
#					slots[selected_slot] = original_them
#				"here":
#					slots[selected_slot] = original_here
		CommandCodes.SELECT_TILES_NAMED:
			var tindex = MapManager.get_tile_index(command_options[0])
			slots[selected_slot] = MapManager.get_all_positions_of_tile(tindex)
			print(slot_value(slots, selected_slot))
		CommandCodes.SELECT_TILES_RECT:
			var top_position = Vector2(int(command_options[0]), int(command_options[1]))
			top_position += slot_value(slots, Slot.THIS_TILE)
			slots[selected_slot] = []
			for xi in range(int(command_options[2])):
				for yi in range(int(command_options[3])):
					slots[selected_slot].append(top_position + Vector2(xi, yi))
			print(slot_value(slots, selected_slot))
			pass
	
	return true

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
