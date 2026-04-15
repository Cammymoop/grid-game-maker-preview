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
	return "pos|<= Select positions within [radius:ComplexScalarInput] (full square)"
func cmd_select_tiles_around(slots: Dictionary, chosen_slot: int, radius: Dictionary) -> void:
	var radius_int: = int(resolve_complex_scalar(radius, slots))
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
		push_error("Invalid slots to select entity at: %s and %s" % [chosen_slot, at_pos_slot])
		return
	var at_positions: Array = slots[at_pos_slot]
	if not at_positions:
		slots[chosen_slot] = null
		return
	var filtered_entities: Array = EntityManager.get_entities_at_multiple(at_positions, slots[Slot.RED])
	filtered_entities = EntityManager.filter_entities_by_property(prop_name, filtered_entities, invert)
	slots[chosen_slot] = filtered_entities[0] if filtered_entities else null

func desc_select_number() -> String:
	return "number,string|<= Select the number [complex_num:ComplexScalarInput]"
func cmd_select_number(slots: Dictionary, chosen_slot: int, complex_num: Dictionary) -> void:
	set_value_slot_as_number(slots, chosen_slot, resolve_complex_scalar(complex_num, slots))

func desc_select_text() -> String:
	return "string|<= Select the text [text_val:StringInput]"
func cmd_select_text(slots: Dictionary, chosen_slot: int, text_val: String) -> void:
	if Commands.slot_is_string(chosen_slot):
		slots[chosen_slot] = text_val
	else:
		push_error("Invalid slot to select text into: %s" % chosen_slot)

func desc_select_text_property() -> String:
	return "string|<= Select the text value of [target_slot:SlotInput:entity,pos]'s [property_name:PropertyInput] property"
func cmd_select_text_property(slots: Dictionary, chosen_slot: int, target_slot: int, property_name: String) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to select property value text into: %s" % chosen_slot)
		return
	
	if Commands.slot_is_entity(target_slot):
		if not slots[target_slot]:
			slots[chosen_slot] = ""
		else:
			slots[chosen_slot] = EntityManager.get_entity_prop_text_value(slots[target_slot], property_name)
	elif Commands.slot_is_positions(target_slot):
		if not slots[target_slot]:
			slots[chosen_slot] = ""
		else:
			slots[chosen_slot] = MapManager.get_tile_prop_text_value_at(slots[target_slot], property_name)
	else:
		push_error("Invalid slot to select property value text from: %s" % target_slot)

func desc_select_number_property() -> String:
	return "string,number|<= Select the text value of [target_slot:SlotInput:entity,pos]'s [property_name:PropertyInput] property"
func cmd_select_number_property(slots: Dictionary, chosen_slot: int, target_slot: int, property_name: String) -> void:
	if not Commands.slot_is_scalar(chosen_slot) and not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to select property value as scalar into: %s" % chosen_slot)
		return
	
	var prop_val: float = 0
	if Commands.slot_is_entity(target_slot):
		if slots[target_slot]:
			prop_val = EntityManager.get_entity_prop_scalar_value(slots[target_slot], property_name)
	elif Commands.slot_is_positions(target_slot):
		if slots[target_slot]:
			prop_val = MapManager.get_tile_prop_scalar_value_at(slots[target_slot], property_name)
	else:
		push_error("Invalid slot to select property value text from: %s" % target_slot)
		return
	set_value_slot_as_number(slots, chosen_slot, prop_val)

func desc_add_text() -> String:
	return "string|<= Add [inserted_text:StringInput] to the [is_end:BoolChoice:true,end,beginning] of the slot\n" + \
	       "Separated by [separator:StringInput]"
func cmd_add_text(slots: Dictionary, chosen_slot: int, inserted_text: String, separator: String, is_end: bool) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to add text into: %s" % chosen_slot)
		return
	var text: String = slots[chosen_slot]
	if not text.strip_edges():
		slots[chosen_slot] = inserted_text
	elif is_end:
		slots[chosen_slot] = text + separator + inserted_text
	else:
		slots[chosen_slot] = inserted_text + separator + text

func desc_add_number_to_text() -> String:
	return "string|<= Add [inserted_num:ComplexScalarInput] to the [is_end:BoolChoice:true,end,beginning] of the slot\n" + \
	       "Separated by [separator:StringInput]"
func cmd_add_number_to_text(slots: Dictionary, chosen_slot: int, inserted_num: Dictionary, separator: String, is_end: bool) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to add number to text into: %s" % chosen_slot)
		return
	var text: String = slots[chosen_slot]
	var inserted_text: String = str(resolve_complex_scalar(inserted_num, slots))
	if not text.strip_edges():
		slots[chosen_slot] = inserted_text
	elif is_end:
		slots[chosen_slot] = text + separator + inserted_text
	else:
		slots[chosen_slot] = inserted_text + separator + text

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

func desc_if_property_value() -> String:
	return "entity,pos|If the entity/tile's [property_name:PropertyInput] property is [is_truthy:BoolChoice:true,true or non-zero,false or zero]"
func cmd_if_property_value(slots: Dictionary, chosen_slot: int, property_name: String, is_truthy: bool) -> bool:
	var result: bool = false
	if Commands.slot_is_entity(chosen_slot):
		result = EntityManager.get_entity_prop_is_truthy(slots[chosen_slot], property_name)
	else:
		result = MapManager.check_multiple_pos_for_property_bool(slots[chosen_slot], slots[Slot.RED], property_name, is_truthy)
	#prints("if prop", property_name, "is", str(is_truthy), "prop val is: ", result)
	return result if is_truthy else not result

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
	selected.set_steps_per_tile_override(blue_entity.get_steps_per_tile())
	var facing = resolve_direction_value(direction, slots)
	return selected.start_move(facing, not keep_visual)

func desc_c_is_facing() -> String:
	return "entity|If the entity [invert:InvertInput:is,is not] facing this way [direction:DirectionInput]"
func cmd_c_is_facing(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected = slots[chosen_slot]

	var result = selected.facing == resolve_direction_value(direction, slots)
	return not result if invert else result

func desc_c_is_moving() -> String:
	return "entity|If the entity [invert:InvertInput:is,is not] moving this way [direction:DirectionInput]"
func cmd_c_is_moving(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected = slots[chosen_slot]

	var result = selected.move_facing == resolve_direction_value(direction, slots)
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

func desc_erase_tiles() -> String:
	return "pos|Erase the tile(s) here"
func cmd_erase_tiles(slots: Dictionary, chosen_slot: int) -> void:
	MapManager.replace_tiles_at_array(slots[chosen_slot], -1)

func desc_a_set_property() -> String:
	return "entity,pos|Set the entity or tile's [property_name:PropertyInput] property to [value:StringInput]"
func cmd_a_set_property(slots: Dictionary, chosen_slot: int, property_name: String, value: String) -> void:
	var converted_value: Variant = value
	if value == "true" or value == "false":
		converted_value = value == "true"
	elif value.is_valid_float():
		if value.is_valid_int():
			converted_value = int(value)
		else:
			converted_value = float(value)

	if Commands.slot_is_entity(chosen_slot):
		if slots[chosen_slot]:
			slots[chosen_slot].set_local_property(property_name, converted_value)
	elif Commands.slot_is_positions(chosen_slot):
		var positions: Array = slots[chosen_slot]
		if positions.size() > 0:
			MapManager.set_tile_property_at_multiple(positions, property_name, converted_value)

func desc_a_property_add() -> String:
	return "entity|Add [amount:ComplexScalarInput] to the entity's [property_name:PropertyInput] property"
func cmd_a_property_add(slots: Dictionary, chosen_slot: int, property_name: String, amount: Dictionary) -> void:
	if Commands.slot_is_entity(chosen_slot):
		var selected: = slots[chosen_slot] as BaseEntity
		if selected:
			var existing = EntityManager.get_entity_prop_with_default(selected, property_name, 0)
			selected.set_local_property(property_name, existing + resolve_complex_scalar(amount, slots))

func desc_a_property_subtract() -> String:
	return "entity|Subtract [amount:ComplexScalarInput] from the entity's [property_name:PropertyInput] property\n" \
	     + "[autoremove:BoolChoice:true,remove the property if it reaches zero,allow values less than and including zero]"
func cmd_a_property_subtract(slots: Dictionary, chosen_slot: int, property_name: String, amount: Dictionary, autoremove: bool) -> void:
	if Commands.slot_is_entity(chosen_slot):
		var selected: = slots[chosen_slot] as BaseEntity
		if selected:
			var existing = EntityManager.get_entity_prop_with_default(selected, property_name, 0)
			var new_val: float = existing - resolve_complex_scalar(amount, slots)

			if autoremove and (new_val <= 0 or is_zero_approx(new_val)):
				if selected.has_local_property(property_name):
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

func desc_reset_property_to_default() -> String:
	return "entity,pos|Reset the entity or tile's [property_name:PropertyInput] property to the default value"
func cmd_reset_property_to_default(slots: Dictionary, chosen_slot: int, property_name: String) -> void:
	if Commands.slot_is_entity(chosen_slot):
		if slots[chosen_slot]:
			slots[chosen_slot].reset_local_property(property_name)
	elif Commands.slot_is_positions(chosen_slot):
		var positions: Array = slots[chosen_slot]
		if positions.size() > 0:
			MapManager.remove_tile_property_multiple(positions, property_name)

func desc_a_save_checkpoint() -> String:
	return "none|Save the current state as a checkpoint"
func cmd_a_save_checkpoint(_slots: Dictionary) -> void:
	GameManager.save_checkpoint.call_deferred()

func desc_a_load_checkpoint() -> String:
	return "none|Load the last saved checkpoint"
func cmd_a_load_checkpoint(_slots: Dictionary) -> void:
	GameManager.load_checkpoint.call_deferred()

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
	return "entity,pos|If the entity/tile's [property_name:PropertyInput] property [comparison:OrderComparison] [num_val:ComplexScalarInput]"
func cmd_compare_property(slots: Dictionary, chosen_slot: int, property_name: String, comparison: String, num_val: Dictionary) -> bool:
	var selected = slots[chosen_slot]
	var compare_to_val: float = resolve_complex_scalar(num_val, slots)
	if Commands.slot_is_entity(chosen_slot) and selected:
		var prop: Property = EntityManager.get_entity_property(selected, property_name)
		if prop:
			var number_result = 0
			if prop.is_conditional():
				number_result = float(prop.resolve(selected, slots[Slot.RED], selected.tile_position))
			else:
				number_result = float(prop.get_value())
			return Utility.check_comparison(number_result, compare_to_val, comparison)
	elif Commands.slot_is_positions(chosen_slot) and selected:
		return MapManager.compare_multiple_pos_prop_value(selected, slots[Slot.RED], property_name, comparison, compare_to_val)
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

func desc_override_move_speed() -> String:
	return "entity|Override the entity's move speed for the current movement to [speed:ComplexScalarInput]"
func cmd_override_move_speed(slots: Dictionary, chosen_slot: int, speed: Variant) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		slots[chosen_slot].set_move_speed_override(resolve_complex_scalar(speed, slots))

func desc_trigger_custom_event() -> String:
	return "entity,pos|Trigger the [event_name:PropertyInput] custom event for the entity/tiles"
func cmd_trigger_custom_event(slots: Dictionary, chosen_slot: int, event_name: String) -> void:
	if Commands.slot_is_entity(chosen_slot):
		EntityManager.resolve_entity_interaction_event(event_name, slots[chosen_slot], slots[Slot.RED], slots[chosen_slot].get_moving_position())
	elif Commands.slot_is_positions(chosen_slot):
		MapManager.resolve_tile_event(slots[chosen_slot], event_name, slots[Slot.BLUE])

func _entity_has_controller_intention_count(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot] or slots[chosen_slot].moving:
		return false
	return slots[chosen_slot].has_move_intentions()

func desc_has_intended_move_direction() -> String:
	return "entity|If the entity has an intended move direction"
func cmd_has_intended_move_direction(slots: Dictionary, chosen_slot: int) -> bool:
	if not _entity_has_controller_intention_count(slots, chosen_slot):
		return false
	return slots[chosen_slot].soft_check_intended_move_facing() != -1

func desc_is_intended_move_direction() -> String:
	return "entity|If the entity is intended to move this way [complex_dir:DirectionInput:1]"
func cmd_is_intended_move_direction(slots: Dictionary, chosen_slot: int, complex_dir: Dictionary) -> bool:
	if not _entity_has_controller_intention_count(slots, chosen_slot):
		return false
	var intended_move_facing: int = slots[chosen_slot].soft_check_intended_move_facing()
	if intended_move_facing == -1:
		return false
	return intended_move_facing == resolve_complex_direction(complex_dir, slots)
	
func desc_show_mini_text_at() -> String:
	return "pos,entity|Temporarily show the text [text_slot:SlotInput:string,number] [is_above:BoolChoice:true,above,at] this position/entity"
func cmd_show_mini_text_at(slots: Dictionary, chosen_slot: int, text_slot: int, is_above: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot) and not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot to show mini text at: %s" % chosen_slot)
		return

	var mini_message: String = get_value_slot_as_string(slots, text_slot)
	if Commands.slot_is_entity(chosen_slot):
		if slots[chosen_slot]:
			var message_pos: Vector2 = EntityManager.get_pos_above(slots[chosen_slot]) if is_above else slots[chosen_slot].get_center_position()
			EffectsHelper.spawn_mini_text_at(mini_message, message_pos)
		else:
			push_error("Entity slot %s is empty" % chosen_slot)
	elif Commands.slot_is_positions(chosen_slot):
		if not slots[chosen_slot]:
			push_error("Positions slot %s is empty" % chosen_slot)
		for tile_pos in slots[chosen_slot]:
			var message_pos: Vector2 = MapManager.get_world_pos_above(tile_pos) if is_above else MapManager.tile_to_world_position_centered(tile_pos)
			EffectsHelper.spawn_mini_text_at(mini_message, message_pos)
	else:
		push_error("Invalid slot to show mini text at: %s" % chosen_slot)

func desc_show_textbox() -> String:
	return "string|Show a textbox with the text fom this slot"
func cmd_show_textbox(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Not a string slot: %s" % chosen_slot)
		return
	GameManager.show_the_textbox(get_value_slot_as_string(slots, chosen_slot))

func desc_dismiss_textbox() -> String:
	return "none|Dismiss the textbox"
func cmd_dismiss_textbox(_slots: Dictionary) -> void:
	GameManager.dismiss_the_textbox()
	
	