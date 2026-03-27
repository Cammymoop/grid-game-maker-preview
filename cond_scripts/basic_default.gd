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
func cmd_select_tiles_around(slots: Dictionary, chosen_slot: int, radius: int) -> void:
	var top_left = get_context_position(slots) - Vector2i(radius, radius)
	var width: = radius * 2 + 1
	var positions: Array = []
	for xi in range(width):
		for yi in range(width):
			positions.append(top_left + Vector2i(xi, yi))
	slots[chosen_slot] = positions

func desc_c_has_property() -> String:
	return "entity,pos|If the entity/tile [invert:InvertInput:has,doesn't have] a [property_name:PropertyInput] property"
func cmd_c_has_property(slots: Dictionary, chosen_slot: int, invert: bool, property_name: String) -> bool:
	var selected = slots[chosen_slot]
	var result: bool
	if Commands.slot_is_entity(chosen_slot):
		result = EntityManager.entity_has_property(selected, property_name)
	else:
		if not selected or len(selected) < 1:
			result = false
		else:
			result = MapManager.get_tile_property_at(selected[0], property_name) != null
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
	selected.set_current_speed(blue_entity.steps_per_tile)
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
	if Commands.slot_is_entity(chosen_slot):
		slots[chosen_slot].die()

func desc_a_move() -> String:
	return "entity|The entity starts moving this way [direction:DirectionInput]"
func cmd_a_move(slots: Dictionary, chosen_slot: int, direction: int) -> void:
	if Commands.slot_is_entity(chosen_slot):
		var selected = slots[chosen_slot]
		selected.start_move(resolve_direction_value(direction, slots))

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
	return "entity|Set the entity's [property_name:PropertyInput] property to [value:ValueInput]"
func cmd_a_set_property(slots: Dictionary, chosen_slot: int, property_name: String, value: Variant) -> void:
	if Commands.slot_is_entity(chosen_slot):
		slots[chosen_slot].set_local_property(property_name, value)
	elif Commands.slot_is_positions(chosen_slot):
		for pos in slots[chosen_slot]:
			MapManager.set_tile_property_at(pos, property_name, value)

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
	return "entity|Remove the entity's [property_name:PropertyInput] property"
func cmd_a_remove_property(slots: Dictionary, chosen_slot: int, property_name: String) -> void:
	if Commands.slot_is_entity(chosen_slot):
		slots[chosen_slot].remove_local_property(property_name)

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
	return "entity|Turn the entity to face this way [direction:DirectionInput]"
func cmd_a_turn(slots: Dictionary, chosen_slot: int, direction: int) -> void:
	if Commands.slot_is_entity(chosen_slot):
		slots[chosen_slot].turn_to_facing(resolve_direction_value(direction, slots))
	elif Commands.slot_is_positions(chosen_slot):
		set_tiles_to_facing(slots, chosen_slot, resolve_direction_value(direction, slots))