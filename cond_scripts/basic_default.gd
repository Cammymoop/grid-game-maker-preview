extends BaseConditionalScript


func get_command_display_name(cmd_name: String) -> String:
	cmd_name = cmd_name.trim_prefix("a_").trim_prefix("c_")
	return cmd_name.capitalize()

# --- COMMANDS ---

func desc_select_defaults() -> String:
	return "none|Reset all slots selections"
func cmd_select_defaults(slots: Dictionary) -> void:
	cond_resolver.select_reset(slots)

func desc_quit() -> String:
	return "none|Skip the rest of the conditional"
func cmd_quit(_slots: Dictionary) -> Dictionary:
	return {"result": true, "quit": true}

func desc_select_tiles_named() -> String:
	return "pos|<= Select all positions where the tile [tile_name:TileNameInput] is found"
func cmd_select_tiles_named(slots: Dictionary, chosen_slot: Slot, tile_name: String) -> void:
	var tindex = MapManager.get_tile_index(tile_name)
	slots[chosen_slot] = MapManager.get_all_positions_of_tile(tindex)

func desc_filter_tiles_named() -> String:
	return "pos|<= Filter the positions to those where a tile named [tile_name:TileNameInput] [invert:InvertInput:is,is not] found"
func cmd_filter_tiles_named(slots: Dictionary, chosen_slot: Slot, tile_name: String, invert: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not slots[chosen_slot]:
		return
	var tindex = MapManager.get_tile_index(tile_name)
	var found_positions = MapManager.get_all_positions_of_tile(tindex)
	var filtered_positions: Array = []
	for current_pos in slots[chosen_slot]:
		if (current_pos in found_positions) != invert:
			filtered_positions.append(current_pos)
	slots[chosen_slot] = filtered_positions

func desc_select_tiles_rect() -> String:
	return "pos|<= Select positions within a rectangle\nstarting at [top_left:PositionInput:0,0]\nwith size [size:PositionInput:1,1]"
func cmd_select_tiles_rect(slots: Dictionary, chosen_slot: Slot, top_left: Vector2i, size: Vector2i) -> void:
	top_left = get_rel_position_arg(top_left, slots)
	var positions: Array = []
	for xi in range(size.x):
		for yi in range(size.y):
			positions.append(top_left + Vector2i(xi, yi))
	slots[chosen_slot] = positions

func desc_select_tiles_around() -> String:
	return "pos|<= Select positions within [radius:ValueInput] (full square)"
func cmd_select_tiles_around(slots: Dictionary, chosen_slot: int, radius: String) -> void:
	var radius_int: = int(radius)
	var top_left = get_context_position(slots) - Vector2i(radius_int, radius_int)
	var width: = radius_int * 2 + 1
	var positions: Array = []
	for xi in range(width):
		for yi in range(width):
			positions.append(top_left + Vector2i(xi, yi))
	slots[chosen_slot] = positions

func desc_select_entity_at() -> String:
	return "entity|<= Select an entity (ignoring self) at [at_pos_slot:SlotInput:pos] [invert:InvertInput:with,without] a [prop_name:PropertyInput] property"
func cmd_select_entity_at(slots: Dictionary, chosen_slot: int, at_pos_slot: int, prop_name: String, invert: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_positions(at_pos_slot):
		prints("cant select entity at %s" % at_pos_slot, "chosen slot %s is invalid" % chosen_slot)
		return
	var at_positions: Array = slots[at_pos_slot]
	if not at_positions:
		slots[chosen_slot] = null
		prints("no positions in slot %s" % at_pos_slot)
		return
	var filtered_entities: Array = EntityManager.get_entities_at_multiple(at_positions, slots[Slot.RED])
	prints("select entity at, pre-filter count: %s" % filtered_entities.size())
	filtered_entities = EntityManager.filter_entities_by_property(prop_name, filtered_entities, invert)
	prints("select entity at, post-filter count: %s" % filtered_entities.size(), "selecting first in slot %s" % chosen_slot)
	slots[chosen_slot] = filtered_entities[0] if filtered_entities else null

func desc_is_entity_at() -> String:
	return "pos|If there is an entity (ignoring self) at this location [invert:InvertInput:with,without] a [prop_name:PropertyInput] property"
func cmd_is_entity_at(slots: Dictionary, chosen_slot: int, prop_name: String, invert: bool) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		return false
	var at_positions: Array = slots[chosen_slot]
	if not at_positions:
		return false
	var entities_here: Array = EntityManager.get_entities_at_multiple(at_positions, slots[Slot.RED])
	entities_here = EntityManager.filter_entities_by_property(prop_name, entities_here, invert)
	prints("is entity with property %s at %s: %s" % [prop_name, at_positions, entities_here.size() > 0])
	return entities_here.size() > 0

func desc_c_has_property() -> String:
	return "entity,pos|If the entity/tile [invert:InvertInput:has,doesn't have] a [property_name:PropertyInput] property"
func cmd_c_has_property(slots: Dictionary, chosen_slot: int, invert: bool, property_name: String) -> bool:
	var selected = slots[chosen_slot]
	var result: bool
	if Commands.slot_is_entity(chosen_slot):
		result = EntityManager.entity_has_property(selected, property_name)
	else:
		if not selected:
			result = false
		else:
			result = MapManager.any_pos_has_property(selected, property_name)
	return not result if invert else result

func desc_c_is_named() -> String:
	return "entity|If the entity [invert:InvertInput:is,is not] named [check_name:EntityNameInput]"
func cmd_c_is_named(slots: Dictionary, chosen_slot: int, invert: bool, check_name: String) -> bool:
	var result = slots[chosen_slot].entity_name == check_name
	return not result if invert else result

func desc_c_can_move() -> String:
	return "entity|If the entity [invert:InvertInput:can,cannot] move this way [direction:DirectionInput]"
func cmd_c_can_move(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	var selected = slots[chosen_slot]
	var result = selected.can_i_move(resolve_direction_value(direction, slots))
	return not result if invert else result

func desc_c_get_pushed() -> String:
	return "entity|If the entity successfully gets pushed this way [direction:DirectionInput]\n" \
	     + "[keep_visual:BoolChoice:true,without turning,turning] to face that direction"
func cmd_c_get_pushed(slots: Dictionary, chosen_slot: int, direction: int, keep_visual: bool) -> bool:
	var selected = slots[chosen_slot]
	if selected.moving:
		return false
	var blue_entity = slots[Slot.BLUE]
	selected.set_current_steps_per_tile(blue_entity.steps_per_tile)
	var facing = resolve_direction_value(direction, slots)
	return selected.start_move(facing, not keep_visual)

func desc_c_is_facing() -> String:
	return "entity|If the entity [invert:InvertInput:is,is not] facing this way [direction:DirectionInput]"
func cmd_c_is_facing(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected = slots[chosen_slot]

	var result = selected.visual_facing == resolve_direction_value(direction, slots)
	return not result if invert else result

func desc_c_is_moving() -> String:
	return "entity|If the entity [invert:InvertInput:is,is not] moving this way [direction:DirectionInput]"
func cmd_c_is_moving(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected = slots[chosen_slot]

	var result = selected.facing == resolve_direction_value(direction, slots)
	return not result if invert else result

func desc_a_die() -> String:
	return "entity|The entity dies now"
func cmd_a_die(slots: Dictionary, chosen_slot: int) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		slots[chosen_slot].die()
	else:
		prints("failed to kill on slot %s" % chosen_slot)

func desc_a_move() -> String:
	return "entity|The entity starts moving this way [complex_dir:DirectionInput:1]"
func cmd_a_move(slots: Dictionary, chosen_slot: int, complex_dir: Dictionary) -> void:
	if Commands.slot_is_entity(chosen_slot):
		var selected = slots[chosen_slot]
		selected.start_move(resolve_complex_direction(complex_dir, slots))

func desc_a_swap_tiles() -> String:
	return "pos|Swap the tiles here, switching [a_name:TileNameInput] and [b_name:TileNameInput]"
func cmd_a_swap_tiles(slots: Dictionary, chosen_slot: int, a_name: String, b_name: String) -> void:
	var position_filter = slots[chosen_slot]
	var tile_a = MapManager.get_tile_index(a_name)
	var tile_b = MapManager.get_tile_index(b_name)
	var positions_a = MapManager.get_all_positions_of_tile(tile_a, position_filter)
	var positions_b = MapManager.get_all_positions_of_tile(tile_b, position_filter)
	MapManager.replace_tiles_at_array(positions_a, tile_b)
	MapManager.replace_tiles_at_array(positions_b, tile_a)

func desc_a_set_tiles() -> String:
	return "pos|Change the tile(s) here to [tile_name:TileNameInput]"
func cmd_a_set_tiles(slots: Dictionary, chosen_slot: int, tile_name: String) -> void:
	MapManager.replace_tiles_at_array(slots[chosen_slot], MapManager.get_tile_index(tile_name))

func desc_a_set_property() -> String:
	return "entity,pos|Set the entity or tile's [property_name:PropertyInput] property to [value:ValueInput]"
func cmd_a_set_property(slots: Dictionary, chosen_slot: int, property_name: String, value: Variant) -> void:
	if Commands.slot_is_entity(chosen_slot):
		if slots[chosen_slot]:
			slots[chosen_slot].set_local_property(property_name, value)
	elif Commands.slot_is_positions(chosen_slot):
		var positions: Array = slots[chosen_slot]
		if positions.size() > 0:
			MapManager.set_tile_property_at_multiple(positions, property_name, value)

func desc_a_property_add() -> String:
	return "entity|Add [amount:ValueInput] to the entity's [property_name:PropertyInput] property"
func cmd_a_property_add(slots: Dictionary, chosen_slot: int, property_name: String, amount: Variant) -> void:
	if Commands.slot_is_entity(chosen_slot):
		var selected = slots[chosen_slot]
		var existing = 0
		if selected.has_local_property(property_name):
			existing = int(selected.get_local_property(property_name))
		selected.set_local_property(property_name, existing + int(amount))

func desc_a_property_subtract() -> String:
	return "entity|Subtract [amount:ValueInput] from the entity's [property_name:PropertyInput] property\n" \
	     + "[autoremove:BoolChoice:true,remove the property if it reaches zero,allow values less than and including zero]"
func cmd_a_property_subtract(slots: Dictionary, chosen_slot: int, property_name: String, amount: Variant, autoremove: bool) -> void:
	if Commands.slot_is_entity(chosen_slot):
		var selected = slots[chosen_slot]
		var new_val = -float(amount)
		if selected.has_local_property(property_name):
			new_val += float(selected.get_local_property(property_name))

		if autoremove and (new_val <= 0 or is_zero_approx(new_val)):
			selected.remove_local_property(property_name)
		else:
			selected.set_local_property(property_name, new_val)

func desc_a_remove_property() -> String:
	return "entity,pos|Remove the entity or tile's [property_name:PropertyInput] property"
func cmd_a_remove_property(slots: Dictionary, chosen_slot: int, property_name: String) -> void:
	if Commands.slot_is_entity(chosen_slot):
		if slots[chosen_slot]:
			slots[chosen_slot].remove_local_property(property_name)
	elif Commands.slot_is_positions(chosen_slot):
		var positions: Array = slots[chosen_slot]
		if positions.size() > 0:
			MapManager.remove_tile_property_multiple(positions, property_name)

func desc_a_save_checkpoint() -> String:
	return "none|Save the current state as a checkpoint"
func cmd_a_save_checkpoint(_slots: Dictionary) -> void:
	GameManager.save_checkpoint()

func desc_a_load_checkpoint() -> String:
	return "none|Load the last saved checkpoint"
func cmd_a_load_checkpoint(_slots: Dictionary) -> void:
	GameManager.load_checkpoint()

func desc_a_create_entity() -> String:
	return "pos|Create a new [entity_name:EntityNameInput] entity here\n" \
	     + "facing this way [direction:DirectionInput] which is [is_moving:BoolChoice:false,moving,stationary]"
func cmd_a_create_entity(slots: Dictionary, chosen_slot: int, entity_name: String, direction: int, is_moving: bool) -> void:
	var entity_index = EntityManager.get_entity_index(entity_name)
	var facing = Utility.resolve_full_direction_to_facing(direction, slots)
	for pos in slots[chosen_slot]:
		var new_entity = EntityManager.create_entity(entity_index, pos, facing)
		if is_moving:
			new_entity.start_move(facing)

func desc_a_turn() -> String:
	return "entity|Turn the entity/tile to face this way [complex_dir:DirectionInput:1]"
func cmd_a_turn(slots: Dictionary, chosen_slot: int, complex_dir: Dictionary) -> void:
	if Commands.slot_is_entity(chosen_slot):
		if not slots[chosen_slot] or slots[chosen_slot].moving:
			return
		slots[chosen_slot].turn_to_facing(resolve_complex_direction(complex_dir, slots))
	elif Commands.slot_is_positions(chosen_slot):
		set_tiles_to_facing(slots, chosen_slot, resolve_complex_direction(complex_dir, slots))

func desc_next_level_exists() -> String:
	return "none|If the next level exists"
func cmd_next_level_exists(_slots: Dictionary) -> bool:
	return MapManager.has_next_level()

func desc_load_next_level() -> String:
	return "none|Load the next level"
func cmd_load_next_level(_slots: Dictionary) -> void:
	GameManager.try_load_next_level()

func desc_take_a_turn() -> String:
	return "entity|The entity takes a turn"
func cmd_take_a_turn(slots: Dictionary, chosen_slot: int) -> void:
	if Commands.slot_is_entity(chosen_slot):
		EntityManager.request_move(slots[chosen_slot])

func desc_send_signal() -> String:
	return "entity|The entity sends a [signal_name:SignalInput] signal"
func cmd_send_signal(slots: Dictionary, chosen_slot: int, signal_name: String) -> void:
	if Commands.slot_is_entity(chosen_slot):
		EntityManager.do_emit_signal(signal_name, slots[chosen_slot])

func desc_compare_property() -> String:
	return "entity,pos|If the entity/tile's [property_name:PropertyInput] property [comparison:OrderComparison] [value:ValueInput]"
func cmd_compare_property(slots: Dictionary, chosen_slot: int, property_name: String, comparison: String, value: Variant) -> bool:
	var selected = slots[chosen_slot]
	if Commands.slot_is_entity(chosen_slot) and selected:
		var prop: Property = EntityManager.get_entity_property(selected, property_name)
		if prop:
			var number_result = 0
			if prop.is_conditional():
				number_result = float(prop.resolve(selected, slots[Slot.RED], selected.tile_position))
				prints("number_result: ", number_result)
			else:
				number_result = float(prop.get_value())
			return Utility.check_comparison(number_result, float(value), comparison)
	elif Commands.slot_is_positions(chosen_slot) and selected:
		return MapManager.compare_multiple_pos_prop_value(selected, slots[Slot.RED], property_name, comparison, float(value))
	return false

func desc_exists() -> String:
	return "entity,pos|If there are any entities/tiles selected in the slot"
func cmd_exists(slots: Dictionary, chosen_slot: int) -> bool:
	var selected = slots[chosen_slot]
	if Commands.slot_is_entity(chosen_slot):
		return selected != null
	elif Commands.slot_is_positions(chosen_slot):
		return selected.size() > 0
	return false