extends BaseConditionalScript

const DEFAULT_MAX_LOOPS: int = 10

func get_command_display_name(cmd_name: String, custom_meta_info: Dictionary) -> String:
	cmd_name = cmd_name.trim_prefix("a_").trim_prefix("c_")
	return super.get_command_display_name(cmd_name, custom_meta_info)

# --- COMMANDS ---

func desc_select_defaults() -> String:
	return "none|Reset all slots selections"
func cmd_select_defaults(slots: Dictionary) -> void:
	cond_resolver.select_reset(slots)

func desc_select_same_thing() -> String:
	return "pos,entity,number,string|<= Copy the selection from [source_slot:SlotInput] to this slot"
func cmd_select_same_thing(slots: Dictionary, chosen_slot: int, source_slot: int) -> void:
	if Commands.slot_is_value(chosen_slot) and Commands.slot_is_value(source_slot):
		_copy_value_slot_to_value_slot(slots, source_slot, chosen_slot)
	elif Commands.slot_is_value(chosen_slot) or Commands.slot_is_value(source_slot):
		return
	
	if Commands.slot_is_positions(chosen_slot) and Commands.slot_is_positions(source_slot):
		slots[chosen_slot] = slots[source_slot].duplicate()
	elif Commands.slot_is_entity(chosen_slot) and Commands.slot_is_entity(source_slot):
		slots[chosen_slot] = slots[source_slot]

func _copy_value_slot_to_value_slot(slots: Dictionary, from_slot: int, to_slot: int) -> void:
	if Commands.slot_is_string(from_slot) and Commands.slot_is_string(to_slot):
		slots[to_slot] = slots[from_slot]
		return
	var from_numeric: = get_value_slot_as_float(slots, from_slot)
	set_value_slot_as_number(slots, to_slot, from_numeric)

func desc_swap_slots() -> String:
	return "pos,entity,number,string|<=> [slot_b:SlotInput] Swap the selection of these slots"
func cmd_swap_slots(slots: Dictionary, chosen_slot: int, slot_b: int) -> void:
	if Commands.slot_is_value(chosen_slot) and Commands.slot_is_value(slot_b):
		_swap_value_slots(slots, chosen_slot, slot_b)
	elif Commands.slot_is_value(chosen_slot) or Commands.slot_is_value(slot_b):
		return
	
	if Commands.slot_is_positions(chosen_slot) and Commands.slot_is_positions(slot_b):
		var temp_positions: Array = slots[chosen_slot]
		slots[chosen_slot] = slots[slot_b]
		slots[slot_b] = temp_positions
	elif Commands.slot_is_entity(chosen_slot) and Commands.slot_is_entity(slot_b):
		var temp_entity: BaseEntity = slots[chosen_slot]
		slots[chosen_slot] = slots[slot_b]
		slots[slot_b] = temp_entity

func _swap_value_slots(slots: Dictionary, slot_a: int, slot_b: int) -> void:
	if Commands.slot_is_string(slot_a) and Commands.slot_is_string(slot_b):
		var temp: String = slots[slot_a]
		slots[slot_a] = slots[slot_b]
		slots[slot_b] = temp
		return

	var temp_numeric: = get_value_slot_as_float(slots, slot_a)
	set_value_slot_as_number(slots, slot_a, get_value_slot_as_float(slots, slot_b))
	set_value_slot_as_number(slots, slot_b, temp_numeric)


func desc_quit() -> Dictionary:
	return {
		"display_name": "Quit Conditional",
		"slot_type_hint": "none",
		"template_text": "Stop evaluating the rest of the conditional",
		"tooltip": "All remaining Commands in this step will be skipped, including Commands below in this list, all later steps will be skipped and not run.\n" \
					+ "The result of this conditional event will be the result of this step ignoring later steps."
	}
func cmd_quit(_slots: Dictionary) -> Dictionary:
	return {"result": true, "quit": true}

func desc_if_entity_is_moving() -> String:
	return "entity|If the entity is currently moving"
func cmd_if_entity_is_moving(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity is moving: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	return slots[chosen_slot].moving

func desc_if_entity_is_starting_to_move() -> String:
	return "entity|If the entity is currently checking if it can move"
func cmd_if_entity_is_starting_to_move(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity is moving: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	return slots[chosen_slot]._currently_starting_move and not slots[chosen_slot].moving

func desc_if_entity_is_moving_or_starting_to_move() -> String:
	return "entity|If the entity is currently moving or currently checking if it can move"
func cmd_if_entity_is_moving_or_starting_to_move(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity is moving: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	if slots[chosen_slot].moving:
		return true
	if slots[chosen_slot]._currently_starting_move:
		return true
	return false

func desc_if_entity_is_half_done_moving() -> String:
	return "entity|If the entity is moving (or teleporting) and is at least halfway through the move"
func cmd_if_entity_is_half_done_moving(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity is half done moving: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	return slots[chosen_slot].is_half_done_moving()

func desc_select_all_positions_with_any_tile() -> String:
	return "pos|<= Select all positions where any tile exists in the level"
func cmd_select_all_positions_with_any_tile(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		return
	slots[chosen_slot] = MapManager.get_used_positions_in_all_layers()

func desc_filter_positions_with_any_tile() -> String:
	return "pos|<= Filter the positions in this slot to those where [is_exists:BoolChoice:true,any tile exists,false,no tile exists] in the level"
func cmd_filter_positions_with_any_tile(slots: Dictionary, chosen_slot: int, is_exists: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		return
	if not slots[chosen_slot]:
		return
	var filtered_positions: Array = []
	for pos in slots[chosen_slot]:
		if MapManager.tile_exists_at(pos) == is_exists:
			filtered_positions.append(pos)
	slots[chosen_slot] = filtered_positions

func desc_exclude_positions() -> String:
	return "pos|<= Remove all positions in [exclusion_slot:SlotInput:pos] from the slot's selection (Difference)"
func cmd_exclude_positions(slots: Dictionary, chosen_slot: int, exclusion_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_positions(exclusion_slot):
		push_error("Invalid slots to exclude positions: %s and %s" % [chosen_slot, exclusion_slot])
		return
	if not slots[chosen_slot] or not slots[exclusion_slot]:
		return
	var old_selection: Array = slots[chosen_slot]
	slots[chosen_slot] = []
	for pos in old_selection:
		if pos not in slots[exclusion_slot]:
			slots[chosen_slot].append(pos)

func desc_include_positions() -> String:
	return "pos|<= Add all positions in [exclusion_slot:SlotInput:pos] to the slot's selection (Union)"
func cmd_include_positions(slots: Dictionary, chosen_slot: int, inclusion_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_positions(inclusion_slot):
		push_error("Invalid slots to include positions: %s and %s" % [chosen_slot, inclusion_slot])
		return
	if not slots[chosen_slot] or not slots[inclusion_slot]:
		return
	for extra_pos in slots[inclusion_slot]:
		if not extra_pos in slots[chosen_slot]:
			slots[chosen_slot].append(extra_pos)

func desc_select_overlapping_positions() -> String:
	return "pos|<= Select only the positions in this slot that are also selected in [overlap_slot:SlotInput:pos] (Intersection)"
func cmd_select_overlapping_positions(slots: Dictionary, chosen_slot: int, overlap_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_positions(overlap_slot):
		push_error("Invalid slots to select overlapping positions: %s and %s" % [chosen_slot, overlap_slot])
		return
	if not slots[chosen_slot] or not slots[overlap_slot]:
		slots[chosen_slot] = []
		return
	var old_selection: Array = slots[chosen_slot]
	slots[chosen_slot] = []
	for pos in old_selection:
		if pos in slots[overlap_slot]:
			slots[chosen_slot].append(pos)

func desc_select_number_of_positions() -> String:
	return "number,string|<= Select the number of positions selected in [pos_slot:SlotInput:pos]"
func cmd_select_number_of_positions(slots: Dictionary, chosen_slot: int, pos_slot: int) -> void:
	if not Commands.slot_is_positions(pos_slot) or not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slots to select number of positions: %s, %s" % [pos_slot, chosen_slot])
		return
	set_value_slot_as_number(slots, chosen_slot, slots[pos_slot].size())

func desc_select_tiles_named() -> String:
	return "pos|<= Select all positions where a tile [tile_name:TileNameInput] is found"
func cmd_select_tiles_named(slots: Dictionary, chosen_slot: Slot, tile_name: String) -> void:
	if not MapManager.tile_name_exists(tile_name):
		slots[chosen_slot] = []
		return
	var tindex = MapManager.get_tile_index(tile_name)
	slots[chosen_slot] = MapManager.get_all_positions_of_tile(tindex)

func desc_if_named_tile_is_at_position() -> String:
	return "pos|If a [tile_name:TileNameInput] tile [invert:InvertInput:is,is not] found at [is_all:BoolChoice:false,all,any] of the positions in this slot"
func cmd_if_named_tile_is_at_position(slots: Dictionary, chosen_slot: int, tile_name: String, invert: bool, is_all: bool) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to check if tile is named: %s" % chosen_slot)
		return false
	if not MapManager.tile_name_exists(tile_name):
		return invert
	var t_id: = MapManager.get_tile_index(tile_name)
	var positions: Array = slots[chosen_slot]
	if positions.size() == 0:
		return invert
	return MapManager.is_tile_id_at_multiple(t_id, positions, is_all)

func _get_prop_filtered_tile_positions(slots: Dictionary, property_name: String, truthy: bool, invert: bool, pos_filter_slot: int = -1) -> Array[Vector2i]:
	var with_pos_filter: bool = pos_filter_slot >= 0
	var pos_filter: Array = []
	if with_pos_filter:
		pos_filter = slots[pos_filter_slot]
	return MapManager.get_all_positions_of_tile_by_property(property_name, truthy, invert, with_pos_filter, pos_filter)

func desc_select_tiles_with_property() -> String:
	return "pos|<= Select the positions of all tiles [invert:InvertInput:with,without] a [truthy:BoolChoice:true,true or non-zero,false or zero] [property_name:PropertyInput] property"
func cmd_select_tiles_with_property(slots: Dictionary, chosen_slot: int, property_name: String, truthy: bool, invert: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to select tiles with property: %s" % chosen_slot)
		return
	slots[chosen_slot] = _get_prop_filtered_tile_positions(slots, property_name, truthy, invert)

func desc_select_tiles_with_property_at() -> String:
	return "pos|<= Select the positions of all tiles at [pos_filter_slot:SlotInput:pos] [invert:InvertInput:with,without] a [truthy:BoolChoice:true,true or non-zero,false or zero] " \
		+ "[property_name:PropertyInput] property"
func cmd_select_tiles_with_property_at(slots: Dictionary, chosen_slot: int, property_name: String, truthy: bool, invert: bool, pos_filter_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to select tiles with property: %s" % chosen_slot)
		return
	slots[chosen_slot] = _get_prop_filtered_tile_positions(slots, property_name, truthy, invert, pos_filter_slot)

func desc_if_tiles_with_property_are_at() -> String:
	return "pos|If a tile [inv_prop:InvertInput:with,without] a [truthy:BoolChoice:true,true or non-zero,false or zero] [property_name:PropertyInput] property\n" \
	    + "[invert:InvertInput:is,is not] found at [is_all:BoolChoice:false,all,any] of the positions in this slot"
func cmd_if_tiles_with_property_are_at(slots: Dictionary, chosen_slot: int, inv_prop: bool, property_name: String, truthy: bool, invert: bool, is_all: bool) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to check if tiles with property are at: %s" % chosen_slot)
		return false
	var check_pos_count: = len(slots[chosen_slot])
	if check_pos_count == 0:
		return invert
	var filtered_positions: = _get_prop_filtered_tile_positions(slots, property_name, truthy, inv_prop, chosen_slot)
	var filtered_count: = filtered_positions.size()

	if filtered_count < check_pos_count and filtered_count > 0:
		return not is_all
	else:
		return (filtered_count == 0) == invert


func desc_if_non_empty_tiles_at_positions() -> String:
	return "pos|If there is a tile (not empty) at [is_all:BoolChoice:false,all,any] of the positions in this slot"
func cmd_if_non_empty_tiles_at_positions(slots: Dictionary, chosen_slot: int, is_all: bool) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to check if tile is at position: %s" % chosen_slot)
		return false
	var positions: Array = slots[chosen_slot]
	if positions.size() == 0:
		return false
	for pos in positions:
		var tile_here: int = MapManager.get_tile_index_at(pos)
		if tile_here == -1 and is_all:
			return false
		elif tile_here != -1 and not is_all:
			return true
	
	return is_all

func desc_if_empty_tiles_at_positions() -> String:
	return "pos|If there are no tiles at [is_all:BoolChoice:false,all,any] of the positions in this slot"
func cmd_if_empty_tiles_at_positions(slots: Dictionary, chosen_slot: int, is_all: bool) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to check if tile is at position: %s" % chosen_slot)
		return false
	var positions: Array = slots[chosen_slot]
	if positions.size() == 0:
		return false
	for pos in positions:
		var tile_here: int = MapManager.get_tile_index_at(pos)
		if tile_here != -1 and is_all:
			return false
		elif tile_here == -1 and not is_all:
			return true
	
	return is_all

func desc_select_named_entity_positions() -> String:
	return "pos|<= Select all positions where an active entity named [e_name:EntityNameInput] is found within [pos_filter:SlotInput:pos]\n" \
			+ "Excluding [exclude_slot:SlotInput:entity,none]"
func cmd_select_named_entity_positions(slots: Dictionary, chosen_slot: Slot, e_name: Dictionary, pos_filter: int, exclude_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_positions(pos_filter):
		push_error("Invalid slot to select named entity positions into: %s" % chosen_slot)
		return
	var e_id: = get_id_of_complex_entity_name(e_name, slots)
	if e_id < 0:
		return
	var exclude_entity: BaseEntity = get_entity_from_slot(exclude_slot, slots)
	var filtered_entities: Array = []
	if slots[pos_filter]:
		filtered_entities = EntityManager.get_entities_at_multiple(slots[pos_filter], exclude_entity, [])
	else:
		filtered_entities = EntityManager.get_all_active_entities()
	filtered_entities = filtered_entities.filter(func(e: BaseEntity) -> bool: return e.entity_index == e_id)
	slots[chosen_slot] = []
	for entity in filtered_entities:
		for pos in EntityManager.get_all_positions_of_entity(entity):
			if not pos in slots[chosen_slot]:
				slots[chosen_slot].append(pos)

func desc_select_entity_positions() -> String:
	return "pos|<= Select all positions within [pos_filter:SlotInput:pos] where an active entity\n" \
			+ "with a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property is found excluding [exclude_slot:SlotInput:entity,none]"
func cmd_select_entity_positions(slots: Dictionary, chosen_slot: Slot, prop_name: String, truthy: bool, pos_filter: int, exclude_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_positions(pos_filter):
		push_error("Invalid slot to select entity positions into: %s" % chosen_slot)
		return
	var exclude_entity: BaseEntity = get_entity_from_slot(exclude_slot, slots)
	var filtered_entities: Array = []
	if slots[pos_filter]:
		filtered_entities = EntityManager.get_entities_at_multiple(slots[pos_filter], exclude_entity, [])
	else:
		filtered_entities = EntityManager.get_all_active_entities()
	filtered_entities = EntityManager.filter_entities_by_property(prop_name, filtered_entities, [], truthy)
	slots[chosen_slot] = []
	for entity in filtered_entities:
		for pos in EntityManager.get_all_positions_of_entity(entity):
			if not pos in slots[chosen_slot]:
				slots[chosen_slot].append(pos)

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

func desc_select_tiles_rect() -> Dictionary:
	return {
		"slot_type_hint": "pos",
		"template_text": "<= (deprecated) Select positions within a rectangle\nstarting at [top_left:PositionInput:0,0]\nwith size [size:PositionInput:1,1]",
		"is_deprecated": true,
	}
func cmd_select_tiles_rect(slots: Dictionary, chosen_slot: Slot, top_left: Vector2i, size: Vector2i) -> void:
	top_left = get_rel_position_arg(top_left, slots)
	var positions: Array = []
	for xi in range(size.x):
		for yi in range(size.y):
			positions.append(top_left + Vector2i(xi, yi))
	slots[chosen_slot] = positions

func desc_select_rectangular_region() -> Dictionary:
	return {
		"slot_type_hint": "pos",
		"template_text": "<= Select positions within a rectangle starting at [top_left:PositionInput:0,0] from the single position in [relative_to_slot:SlotInput:pos,entity]\n"
			+ "with a width of [width:ComplexScalarInput:int] and height of [height:ComplexScalarInput:int]",
	}
func cmd_select_rectangular_region(slots: Dictionary, chosen_slot: Slot, top_left: Vector2i, width: Dictionary, height: Dictionary, relative_to_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_has_position(relative_to_slot):
		push_error("Invalid slots to select rectangular region: %s, %s" % [chosen_slot, relative_to_slot])
		return
	var relative_to_pos: = Vector2i.ZERO
	if _slot_has_single_tile_position(slots, relative_to_slot):
		relative_to_pos = _single_tile_position_from_slot(slots, relative_to_slot)
	var width_int: = roundi(resolve_complex_scalar(width, slots))
	var height_int: = roundi(resolve_complex_scalar(height, slots))
	var size: = Vector2i(width_int, height_int)
	slots[chosen_slot] = Utility.positions_rect_iter(relative_to_pos + top_left, size)

func desc_select_centered_rectangular_region() -> Dictionary:
	return {
		"slot_type_hint": "pos",
		"template_text": "<= Select positions within a rectangle centered on the single position in [relative_to_slot:SlotInput:pos,entity]\n" \
			+ "with a width of [width:ComplexScalarInput:int] and height of [height:ComplexScalarInput:int]\n" \
			+ "left/right center bias: [bias_left:BoolChoice:true,left,right] up/down bias: [bias_up:BoolChoice:true,up,down]"
	}
func cmd_select_centered_rectangular_region(slots: Dictionary, chosen_slot: Slot, width: Dictionary, height: Dictionary, relative_to_slot: int, bias_left: bool, bias_up: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_has_position(relative_to_slot):
		push_error("Invalid slots to select rectangular region: %s, %s" % [chosen_slot, relative_to_slot])
		return
	var relative_to_pos: = Vector2i.ZERO
	if _slot_has_single_tile_position(slots, relative_to_slot):
		relative_to_pos = _single_tile_position_from_slot(slots, relative_to_slot)
	var width_int: = maxi(1, roundi(resolve_complex_scalar(width, slots)))
	var height_int: = maxi(1, roundi(resolve_complex_scalar(height, slots)))
	var size: = Vector2i(width_int, height_int)
	# use (size - 1)/2 to center the rectangle on the discrete position
	var top_left: = Vector2(relative_to_pos) - (Vector2(size - Vector2i.ONE) / 2.0)
	top_left.x = floorf(top_left.x) if bias_left else ceilf(top_left.x)
	top_left.y = floorf(top_left.y) if bias_up else ceilf(top_left.y)
	slots[chosen_slot] = Utility.positions_rect_iter(Vector2i(top_left), size)

func desc_select_tiles_in_direction() -> String:
	return "pos|<= Select the position(s) [dist:ComplexScalarInput:int] spaces in this direction [compl_dir:DirectionInput:1] from [from_slot:SlotInput:pos,entity]"
func cmd_select_tiles_in_direction(slots: Dictionary, chosen_slot: int, compl_dir: Dictionary, dist: Dictionary, from_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_has_position(from_slot):
		push_error("Invalid slots to select tile in direction: %s, %s" % [chosen_slot, from_slot])
		return
	var distance_int: = roundi(resolve_complex_scalar(dist, slots))
	var facing_vec: = Utility.facing_vector_i(resolve_complex_direction(compl_dir, slots))
	var from_positions: Array = slots[from_slot] if Commands.slot_is_positions(from_slot) else EntityManager.get_all_positions_of_entity(slots[from_slot])
	var moved_positions: Array[Vector2i] = []
	var delta: = facing_vec * distance_int
	for from_pos in from_positions:
		moved_positions.append(from_pos + delta)
	slots[chosen_slot] = moved_positions

func desc_select_positions_moved_in_direction() -> String:
	return "pos|<= move the selection of positions in this slot [dist:ComplexScalarInput:int] grid spaces in this direction [compl_dir:DirectionInput:1]"
func cmd_select_positions_moved_in_direction(slots: Dictionary, chosen_slot: int, dist: Dictionary, compl_dir: Dictionary) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slots to move pos selection in direction: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	var distance_int: = roundi(resolve_complex_scalar(dist, slots))
	var facing_vec: = Utility.facing_vector_i(resolve_complex_direction(compl_dir, slots))
	var moved_positions: Array[Vector2i] = []
	var delta: = facing_vec * distance_int
	for from_pos in slots[chosen_slot]:
		moved_positions.append(from_pos + delta)
	slots[chosen_slot] = moved_positions

func desc_select_positions_moved_by_x_y() -> String:
	return "pos|<= move the selection of positions in this slot by [x:ComplexScalarInput:int] in the x axis and [y:ComplexScalarInput:int] in the y axis"
func cmd_select_positions_moved_by_x_y(slots: Dictionary, chosen_slot: int, x: Dictionary, y: Dictionary) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slots to move pos selection in direction: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	var x_int: = roundi(resolve_complex_scalar(x, slots))
	var y_int: = roundi(resolve_complex_scalar(y, slots))
	var delta_vec: = Vector2i(x_int, y_int)
	var moved_positions: Array[Vector2i] = []
	for from_pos in slots[chosen_slot]:
		moved_positions.append(from_pos + delta_vec)
	slots[chosen_slot] = moved_positions

func desc_select_next_tile_after() -> String:
	return "pos|<= Select the [invert:InvertInput:next,previous] position (reading order) in [in_positions_slot:SlotInput:pos] after the position of [after_pos_slot:SlotInput:pos,entity]"
func cmd_select_next_tile_after(slots: Dictionary, chosen_slot: int, in_positions_slot: int, after_pos_slot: int, invert: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_positions(in_positions_slot) or not Commands.slot_has_position(after_pos_slot):
		push_error("Invalid slots to select next tile after: %s, %s, %s" % [chosen_slot, in_positions_slot, after_pos_slot])
		return
	var in_positions: Array = slots[in_positions_slot]
	if not in_positions:
		in_positions = MapManager.get_used_positions_in_all_layers()
	in_positions = Utility.get_reading_order_sorted_positions(in_positions)
	if not _slot_has_single_tile_position(slots, after_pos_slot):
		slots[chosen_slot] = in_positions[-1 if invert else 0]
	var after_pos: Vector2i = _single_tile_position_from_slot(slots, after_pos_slot)
	slots[chosen_slot] = [Utility.next_prev_pos_reading_order(in_positions, after_pos, invert)]

func desc_select_closest_position_to() -> String:
	return "pos|<= Select the closest position in [in_positions:SlotInput:pos] to [ref_pos_slot:SlotInput:pos,entity] by [distance_mode:DistanceModeInput]"
func cmd_select_closest_position_to(slots: Dictionary, chosen_slot: int, in_positions: int, ref_pos_slot: int, distance_mode: String) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_positions(in_positions) or not Commands.slot_has_position(ref_pos_slot):
		push_error("Invalid slots to select closest position to: %s, %s, %s" % [chosen_slot, ref_pos_slot, in_positions])
		return
	if not _slot_has_single_tile_position(slots, ref_pos_slot):
		if slots[in_positions]:
			slots[chosen_slot] = [slots[in_positions][0]]
		else:
			slots[chosen_slot] = []
		return
	var ref_pos: Vector2i = _single_tile_position_from_slot(slots, ref_pos_slot)
	if not slots[in_positions]:
		slots[chosen_slot] = [ref_pos]
		return

	slots[chosen_slot] = [biased_closest_position_to(ref_pos, slots[in_positions], distance_mode)]


func desc_select_first_teleport_in_direction() -> String:
	return "pos|<= Select the first position in [in_positions_slot:SlotInput:pos] that [entity_slot:SlotInput:entity] can teleport to\n" \
			+ "in this direction [compl_dir:DirectionInput:1] from [single_pos_slot:SlotInput:pos,entity]"
func cmd_select_first_teleport_in_direction(slots: Dictionary, chosen_slot: int, in_positions_slot: int, entity_slot: int, compl_dir: Dictionary, single_pos_slot: int) -> void:
	_select_first_last_teleport_in_direction(slots, chosen_slot, in_positions_slot, entity_slot, compl_dir, single_pos_slot, true)

func desc_select_last_teleport_in_direction() -> String:
	return "pos|<= Select the last valid position in [in_positions_slot:SlotInput:pos] that [entity_slot:SlotInput:entity] can teleport to\n" \
			+ "in this direction [compl_dir:DirectionInput:1] from [single_pos_slot:SlotInput:pos,entity]"
func cmd_select_last_teleport_in_direction(slots: Dictionary, chosen_slot: int, in_positions_slot: int, entity_slot: int, compl_dir: Dictionary, single_pos_slot: int) -> void:
	_select_first_last_teleport_in_direction(slots, chosen_slot, in_positions_slot, entity_slot, compl_dir, single_pos_slot, false)

func _select_first_last_teleport_in_direction(slots: Dictionary, chosen_slot: int, in_positions_slot: int, entity_slot: int, compl_dir: Dictionary, single_pos_slot: int, is_first: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_entity(entity_slot) or not Commands.slot_has_position(single_pos_slot):
		push_error("Invalid slots to select first teleport in direction: %s, %s, %s, %s" % [chosen_slot, in_positions_slot, entity_slot, single_pos_slot])
		return
	if not slots[entity_slot] or not _slot_has_single_tile_position(slots, single_pos_slot):
		slots[chosen_slot] = []
		return
	var delta: = Utility.facing_vector_i(resolve_complex_direction(compl_dir, slots))
	if delta == Vector2i.ZERO:
		slots[chosen_slot] = []
		return
	var origin_pos: Vector2i = _single_tile_position_from_slot(slots, single_pos_slot)
	var map_bounding_box: = MapManager.get_map_size()
	var check_pos: Vector2i = origin_pos + delta
	if not map_bounding_box.has_point(check_pos):
		slots[chosen_slot] = []
		return

	var entity: BaseEntity = slots[entity_slot]
	var in_positions: Array = slots[in_positions_slot]
	
	var entity_teleport_from_pos: Vector2i = entity.get_moving_position()
	if origin_pos != entity_teleport_from_pos and entity.is_large():
		if origin_pos in entity.get_positions_at(entity_teleport_from_pos):
			entity_teleport_from_pos = origin_pos
		
	if not is_first:
		# start from the map edge in the direction of the delta and search backwards
		while map_bounding_box.has_point(check_pos):
			check_pos += delta
		check_pos -= delta
		delta = -delta

	while map_bounding_box.has_point(check_pos):
		if check_pos == origin_pos:
			# reverse look checked all positions from map edge
			break
		if not in_positions or in_positions.has(check_pos):
			if entity.can_i_teleport_to(entity_teleport_from_pos, check_pos, -1, -2):
				slots[chosen_slot] = [check_pos]
				return
		check_pos += delta
	slots[chosen_slot] = []


func _slot_has_single_tile_position(slots: Dictionary, slot: int) -> bool:
	if slot < 0:
		return false
	if not Commands.slot_has_position(slot) or not slots[slot]:
		return false
	return true

func _single_tile_position_from_slot(slots: Dictionary, slot: int) -> Vector2i:
	if Commands.slot_is_positions(slot):
		return slots[slot][0]
	else:
		return slots[slot].get_moving_position()

func desc_select_single_position_from_x_y() -> String:
	return "pos|<= Select the single tile position from absolute x: [x:ComplexScalarInput] and y: [y:ComplexScalarInput] coordinates"
func cmd_select_single_position_from_x_y(slots: Dictionary, chosen_slot: int, x: Dictionary, y: Dictionary) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to select single position from x and y: %s" % chosen_slot)
		return
	var x_int: = roundi(resolve_complex_scalar(x, slots))
	var y_int: = roundi(resolve_complex_scalar(y, slots))
	slots[chosen_slot] = Vector2i(x_int, y_int)

func desc_include_exclude_position_from_x_y() -> String:
	return "pos|<= [is_include:BoolChoice:true,Include,Exclude] the single tile position (x: [x:ComplexScalarInput], y: [y:ComplexScalarInput]) from the positions in this slot"
func cmd_include_exclude_position_from_x_y(slots: Dictionary, chosen_slot: int, x: Dictionary, y: Dictionary, pos_slot: int, is_include: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to include exclude position from x and y: %s" % chosen_slot)
		return
	var x_int: = roundi(resolve_complex_scalar(x, slots))
	var y_int: = roundi(resolve_complex_scalar(y, slots))
	var single_pos: Vector2i = Vector2i(x_int, y_int)
	if is_include:
		if single_pos in slots[pos_slot]:
			slots[chosen_slot].append(single_pos)
	else:
		slots[chosen_slot].erase(single_pos)

func desc_select_x_y_coordinate_of_position() -> String:
	return "number,string|<= Select the [is_x:BoolChoice:true,x,y] coordinate of the single tile position in [pos_slot:SlotInput:pos]"
func cmd_select_x_y_coordinate_of_position(slots: Dictionary, chosen_slot: int, pos_slot: int, is_x: bool) -> void:
	if not Commands.slot_is_int(chosen_slot) or not Commands.slot_has_position(pos_slot):
		push_error("Invalid slots to select x coordinate of position: %s, %s" % [chosen_slot, pos_slot])
		return
	if not _slot_has_single_tile_position(slots, pos_slot):
		set_value_slot_as_number(slots, chosen_slot, 0)
		return
	var single_pos: Vector2i = _single_tile_position_from_slot(slots, pos_slot)
	set_value_slot_as_number(slots, chosen_slot, single_pos[0 if is_x else 1])

func desc_select_adjacent_tile() -> String:
	return "pos|<= Select the single position adjacent to [from_slot:SlotInput:pos,entity] in this direction [compl_dir:DirectionInput:1]"
func cmd_select_adjacent_tile(slots: Dictionary, chosen_slot: int, from_slot: int, compl_dir: Dictionary) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_has_position(from_slot):
		push_error("Invalid slots to select adjacent tile: %s, %s" % [chosen_slot, from_slot])
		return
	if not _slot_has_single_tile_position(slots, from_slot):
		slots[chosen_slot] = []
		return
	var from_pos: Vector2i = _single_tile_position_from_slot(slots, from_slot)
	slots[chosen_slot] = [from_pos + Utility.facing_vector_i(resolve_complex_direction(compl_dir, slots))]

func desc_if_position_is_adjacent() -> String:
	return "pos,entity|If the entity or tile position is adjacent to the single position in [single_pos_slot:SlotInput:pos] [with_diagonal:BoolChoice:true,including,excluding] diagonally"
func cmd_if_position_is_adjacent(slots: Dictionary, chosen_slot: int, single_pos_slot: int, with_diagonal: bool) -> bool:
	if not Commands.slot_has_position(chosen_slot) or not Commands.slot_has_position(single_pos_slot):
		push_error("Invalid slots to check if position is adjacent: %s, %s" % [chosen_slot, single_pos_slot])
		return false
	if not _slot_has_single_tile_position(slots, single_pos_slot):
		return false

	var ref_positions: Array = []
	if Commands.slot_is_entity(chosen_slot):
		if not slots[chosen_slot]:
			return false
		ref_positions = EntityManager.get_all_positions_of_entity(slots[chosen_slot])
	else:
		ref_positions = slots[chosen_slot]

	var checking_pos: = _single_tile_position_from_slot(slots, single_pos_slot)
	for ref_pos in ref_positions:
		if Utility.is_vec2i_adjacent(ref_pos, checking_pos, with_diagonal):
			return true
	return false

func desc_select_tiles_around() -> String:
	return "pos|<= Select all positions within [radius:ComplexScalarInput] (square radius) of [ref_pos_slot:SlotInput:pos,entity]"
func cmd_select_tiles_around(slots: Dictionary, chosen_slot: int, radius: Dictionary, ref_pos_slot: int = Commands.Slot.RED) -> void:
	if not Commands.slot_has_position(ref_pos_slot):
		push_error("Invalid slot to select tiles around: %s" % ref_pos_slot)
		return
	if not _slot_has_single_tile_position(slots, ref_pos_slot):
		slots[chosen_slot] = []
		return

	var center_pos: Vector2i = _single_tile_position_from_slot(slots, ref_pos_slot)
	slots[chosen_slot] = Utility.positions_square_radius_iter(center_pos, resolve_complex_scalar(radius, slots))

func desc_select_tiles_within_distance() -> String:
	return "pos|<= Select all positions within [distance:ComplexScalarInput] of this single position [ref_pos_slot:SlotInput:pos,entity] using [distance_mode:DistanceModeInput] distance"
func cmd_select_tiles_within_distance(slots: Dictionary, chosen_slot: int, distance: Dictionary, ref_pos_slot: int, distance_mode: String) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_has_position(ref_pos_slot):
		push_error("Invalid slots to select tiles within distance: %s and %s" % [chosen_slot, ref_pos_slot])
		return
	if distance_mode == "long axis":
		cmd_select_tiles_around(slots, chosen_slot, distance, ref_pos_slot)
		return

	if not _slot_has_single_tile_position(slots, ref_pos_slot):
		slots[chosen_slot] = []
		return
	var max_distance: float = resolve_complex_scalar(distance, slots)
	var ref_pos: Vector2i = _single_tile_position_from_slot(slots, ref_pos_slot)
	var positions: Array = []
	for pos in Utility.positions_square_radius_iter(ref_pos, max_distance):
		if Utility.get_distance_of_positions_by_mode(pos, ref_pos, distance_mode) <= max_distance:
			positions.append(pos)
	slots[chosen_slot] = positions

func desc_select_entity_at() -> Dictionary:
	return {
		"template_text": "<= Select an active entity (ignoring self) at [at_pos_slot:SlotInput:pos] [invert:InvertInput:with,without] a [prop_name:PropertyInput] property",
		"slot_type_hint": "entity",
		"is_deprecated": true,
	}
func cmd_select_entity_at(slots: Dictionary, chosen_slot: int, at_pos_slot: int, prop_name: String, invert: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_positions(at_pos_slot):
		push_error("Invalid slots to select entity at: %s and %s" % [chosen_slot, at_pos_slot])
		return
	var at_positions: Array = slots[at_pos_slot]
	if not at_positions:
		slots[chosen_slot] = null
		return
	var filtered_entities: Array = EntityManager.get_entities_at_multiple(at_positions, slots[Slot.RED], [], false)
	if prop_name:
		filtered_entities = EntityManager.filter_entities_by_property(prop_name, filtered_entities, [], true, invert)
	slots[chosen_slot] = filtered_entities[0] if filtered_entities else null

func desc_select_entity_with_property() -> Dictionary:
	return {
		"template_text": "<= Select the [is_first:BoolChoice:true,first,last] active entity with a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property ignoring [ignore_slot:SlotInput:entity,none]",
		"slot_type_hint": "entity",
	}
func cmd_select_entity_with_property(slots: Dictionary, chosen_slot: int, truthy: bool, prop_name: String, ignore_slot: int, is_first: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not (ignore_slot == SlotSelectorButton.NONE_SLOTS or Commands.slot_is_entity(ignore_slot)):
		push_error("invalid slots to select entity with property: %s and %s" % [chosen_slot, ignore_slot])
		return
	if not prop_name:
		slots[chosen_slot] = null
		return
	var ignore_list: Array[int] = []
	if ignore_slot != SlotSelectorButton.NONE_SLOTS and slots[ignore_slot]:
		ignore_list.append(slots[ignore_slot].instance_id)
	var found: = EntityManager.find_entity_with_truthy_property(prop_name, is_first, ignore_list, not truthy)
	slots[chosen_slot] = found

func desc_select_entity_with_property_at() -> String:
	return "entity|<= Select the [is_first:BoolChoice:true,first,last] active entity [invert:InvertInput:with,without] a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property " \
		+ "at [at_pos_slot:SlotInput:pos] ignoring [ignore_slot:SlotInput:entity,none]"
func cmd_select_entity_with_property_at(slots: Dictionary, chosen_slot: int, at_pos_slot: int, is_first: bool, prop_name: String, truthy: bool, invert: bool, ignore_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not (ignore_slot == SlotSelectorButton.NONE_SLOTS or Commands.slot_is_entity(ignore_slot)):
		push_error("invalid slots to select entity with property: %s and %s" % [chosen_slot, ignore_slot])
		return
	if not prop_name:
		slots[chosen_slot] = null
		return
	var ignore_list: Array[int] = []
	if ignore_slot != SlotSelectorButton.NONE_SLOTS and slots[ignore_slot]:
		ignore_list.append(slots[ignore_slot].instance_id)
	var at_positions: Array = slots[at_pos_slot]
	var filtered_entities: Array = []
	if at_positions:
		filtered_entities = EntityManager.get_entities_at_multiple(at_positions, null, ignore_list, false)
	else:
		filtered_entities = EntityManager.get_all_active_entities()

	if prop_name:
		filtered_entities = EntityManager.filter_entities_by_property(prop_name, filtered_entities, [], truthy, invert)
	if not filtered_entities:
		slots[chosen_slot] = null
		return
	
	if is_first:
		slots[chosen_slot] = filtered_entities[0]
	else:
		slots[chosen_slot] = filtered_entities[-1]

func desc_select_named_entity_at() -> String:
	return "entity|<= Select an active entity (ignoring self) named [e_name:EntityNameInput] at [at_pos_slot:SlotInput:pos]"
func cmd_select_named_entity_at(slots: Dictionary, chosen_slot: int, at_pos_slot: int, e_name: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_positions(at_pos_slot):
		push_error("Invalid slots to select named entity at: %s and %s" % [chosen_slot, at_pos_slot])
		return
	var e_id: = get_id_of_complex_entity_name(e_name, slots)
	var at_positions: Array = slots[at_pos_slot]
	if not at_positions or e_id < 0:
		slots[chosen_slot] = null
		return
	var filtered_entities: Array = EntityManager.get_entities_at_multiple(at_positions, slots[Slot.RED], [], false, false)
	for e in filtered_entities:
		if e.entity_index == e_id:
			slots[chosen_slot] = e
			return
	slots[chosen_slot] = null

func desc_select_named_entity() -> String:
	return "entity|<= Select the [is_first:BoolChoice:true,first,last] active entity named [e_name:EntityNameInput] ignoring [ignore_slot:SlotInput:entity,none]"
func cmd_select_named_entity(slots: Dictionary, chosen_slot: int, e_name: Dictionary, ignore_slot: int, is_first: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not (ignore_slot == SlotSelectorButton.NONE_SLOTS or Commands.slot_is_entity(ignore_slot)):
		push_error("Invalid slots to select named entity: %s and %s" % [chosen_slot, ignore_slot])
		return
	var e_id: = get_id_of_complex_entity_name(e_name, slots)
	if e_id < 0:
		slots[chosen_slot] = null
		return
	var ignore_list: Array[int] = []
	if ignore_slot != SlotSelectorButton.NONE_SLOTS and slots[ignore_slot]:
		ignore_list.append(slots[ignore_slot].instance_id)
	slots[chosen_slot] = EntityManager.find_entity_by_index(e_id, is_first, ignore_list)

func desc_select_nearest_entity() -> String:
	return "entity|<= Select the nearest entity to [ref_entity_slot:SlotInput:entity] (ignoring itself) with a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property"
func cmd_select_nearest_entity(slots: Dictionary, chosen_slot: int, ref_entity_slot: int, truthy: bool, prop_name: String) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(ref_entity_slot):
		push_error("Invalid slot to select nearest entity from: %s" % chosen_slot)
		return
	var ref_entity: BaseEntity = slots[ref_entity_slot]
	if not ref_entity:
		slots[chosen_slot] = null
		return
	var found_entity: BaseEntity = EntityManager.find_closest_entity_with_truthy_property(prop_name, ref_entity.get_moving_position(), truthy, [ref_entity])
	slots[chosen_slot] = found_entity

func desc_select_nearest_named_entity() -> String:
	return "entity|<= Select the nearest [complex_e_name:EntityNameInput] entity to [ref_entity_slot:SlotInput:entity] (ignoring itself)"
func cmd_select_nearest_named_entity(slots: Dictionary, chosen_slot: int, ref_entity_slot: int, complex_e_name: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(ref_entity_slot):
		push_error("Invalid slot to select nearest named entity from: %s" % chosen_slot)
		return
	var e_id: = get_id_of_complex_entity_name(complex_e_name, slots)
	var ref_entity: BaseEntity = slots[ref_entity_slot]
	if not e_id >= 0 or not ref_entity:
		slots[chosen_slot] = null
		return
	slots[chosen_slot] = EntityManager.find_closest_entity_with_id(e_id, ref_entity.get_moving_position(), [ref_entity])

func desc_select_name_of_entity() -> String:
	return "string|<= Select the name of the entity in [target_slot:SlotInput:entity]"
func cmd_select_name_of_entity(slots: Dictionary, chosen_slot: int, target_slot: int) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to select entity name into: %s" % chosen_slot)
		return
	if not Commands.slot_is_entity(target_slot):
		push_error("Invalid slot to select entity name from: %s" % target_slot)
		return
	if slots[target_slot]:
		slots[chosen_slot] = slots[target_slot].entity_name
	else:
		slots[chosen_slot] = ""

func desc_select_first_entity_in_direction() -> String:
	return "entity|<= Select the first entity in a direct line in this direction [compl_dir:DirectionInput:1]\n" \
			+ "from [single_pos_slot:SlotInput:pos,entity] with a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property\n" \
			+ "stopping [before:BoolChoice:true,before,after] hitting a tile with a [t_truthy:BoolChoice:true,true or non-zero,false or zero] [t_prop_name:PropertyInput] property"
func cmd_select_first_entity_in_direction(slots: Dictionary, chosen_slot: int, single_pos_slot: int, compl_dir: Dictionary, truthy: bool, prop_name: String, before: bool, t_truthy: bool, t_prop_name: String) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_has_position(single_pos_slot):
		push_error("Invalid slots to select first entity in direction: %s, %s" % [chosen_slot, single_pos_slot])
		return
	var origin_pos: Vector2i = _single_tile_position_from_slot(slots, single_pos_slot)
	var delta: = Utility.facing_vector_i(resolve_complex_direction(compl_dir, slots))
	
	var map_bounds: = MapManager.get_map_size().grow(5)
	
	var check_pos: = origin_pos
	var break_next: = false
	for i in 10000:
		if break_next:
			break
		check_pos += delta
		if MapManager.is_empty_blocking_at(check_pos) or not map_bounds.has_point(check_pos):
			break
		if MapManager.conditional_tile_event([check_pos], t_prop_name, null, false) == t_truthy:
			if before:
				break
			else:
				break_next = true
		var found_entities: = EntityManager.get_entities_at_multiple([check_pos], null, [])
		
		# stationary entities first, then higher IDs (later in entity list) first
		found_entities.reverse()
		var ordered_entities: Array[BaseEntity] = []
		for e in found_entities:
			if not e.moving:
				ordered_entities.append(e)
		for e in found_entities:
			if not e in ordered_entities:
				ordered_entities.append(e)
		for e in ordered_entities:
			if EntityManager.get_entity_prop_is_truthy(e, prop_name, false) == truthy:
				slots[chosen_slot] = e
				return
	
	slots[chosen_slot] = null

func desc_select_position_of_first_tile_or_entity_in_direction() -> String:
	return "pos|<= Select the position [before:BoolChoice:false,before,where] the first entity or tile exists\n" \
			+ "in a direct line in this direction [compl_dir:DirectionInput:1]\n" \
			+ "from [single_pos_slot:SlotInput:pos,entity] with a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property"
func cmd_select_position_of_first_tile_or_entity_in_direction(slots: Dictionary, chosen_slot: int, before: bool, single_pos_slot: int, compl_dir: Dictionary, truthy: bool, prop_name: String) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_has_position(single_pos_slot):
		push_error("Invalid slots to select position of first tile or entity in direction: %s, %s" % [chosen_slot, single_pos_slot])
		return
	var origin_pos: Vector2i = _single_tile_position_from_slot(slots, single_pos_slot)
	var delta: = Utility.facing_vector_i(resolve_complex_direction(compl_dir, slots))
	
	var map_bounds: = MapManager.get_map_size().grow(5)
	
	var cur_pos: = origin_pos
	for i in 10000:
		var next_pos: = cur_pos + delta
		if MapManager.is_empty_blocking_at(next_pos) or not map_bounds.has_point(next_pos):
			slots[chosen_slot] = [cur_pos]
			return
		if MapManager.conditional_tile_event([next_pos], prop_name, null, false) == truthy:
			slots[chosen_slot] = [cur_pos if before else next_pos]
			return
		var entities_here: = EntityManager.get_entities_half_at(next_pos)
		var stopped: = false
		for e in entities_here:
			if EntityManager.get_entity_prop_is_truthy(e, prop_name, false) == truthy:
				stopped = true
		if stopped:
			slots[chosen_slot] = [cur_pos if before else next_pos]
			return
		cur_pos = next_pos
	slots[chosen_slot] = []


func desc_select_number() -> String:
	return "number,string|<= Select the number [complex_num:ComplexScalarInput]"
func cmd_select_number(slots: Dictionary, chosen_slot: int, complex_num: Dictionary) -> void:
	set_value_slot_as_number(slots, chosen_slot, resolve_complex_scalar(complex_num, slots))

func desc_select_number_property() -> String:
	return "string,number|<= Select the numeric value of [target_slot:SlotInput:entity,pos]'s [property_name:PropertyInput] property"
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

func desc_select_text() -> String:
	return "string|<= Select the text [text_val:ComplexStringInput]"
func cmd_select_text(slots: Dictionary, chosen_slot: int, text_val: Dictionary) -> void:
	if Commands.slot_is_string(chosen_slot):
		slots[chosen_slot] = get_complex_string_value(text_val, slots)
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

func desc_is_the_same_entity() -> String:
	return "entity|If the entity is the same entity as [ref_entity_slot:SlotInput:entity]"
func cmd_is_the_same_entity(slots: Dictionary, chosen_slot: int, ref_entity_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(ref_entity_slot):
		push_error("Invalid slots to check if same entity: %s and %s" % [chosen_slot, ref_entity_slot])
		return false
	var selected: BaseEntity = slots[chosen_slot]
	var ref_entity: BaseEntity = slots[ref_entity_slot]
	if not selected or not ref_entity:
		return false
	return selected.instance_id == ref_entity.instance_id

func desc_select_direction() -> String:
	return "int|<= Select the direction [complex_dir:DirectionInput:1]"
func cmd_select_direction(slots: Dictionary, chosen_slot: int, complex_dir: Dictionary) -> void:
	set_value_slot_as_number(slots, chosen_slot, resolve_complex_direction(complex_dir, slots))

func desc_select_rotated_direction() -> String:
	return "int|<= Select the direction [direction:DirectionInput:1] rotated by [rotate_dir:DirectionInput:2]"
func cmd_select_rotated_direction(slots: Dictionary, chosen_slot: int, direction: Dictionary, rotate_dir: Dictionary) -> void:
	var dir_a: int = resolve_complex_direction(direction, slots)
	var dir_b: int = resolve_complex_direction(rotate_dir, slots)
	set_value_slot_as_number(slots, chosen_slot, Utility.facing_rotated(dir_a, dir_b))

func desc_if_is_valid_direction() -> String:
	return "int|If the number in this slot represents a valid orthogonal direction (0-3)"
func cmd_if_is_valid_direction(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_int(chosen_slot):
		return false
	return Utility.is_valid_facing(slots[chosen_slot])

var rand_dir_options: Dictionary = {
	"any": [0, 1, 2, 3],
	"horizontal": [0, 1],
	"vertical": [2, 3],
	"up/right": [0, 1],
	"up/left": [0, 1],
	"down/right": [2, 3],
	"down/left": [2, 3],
	"not up": [1, 2, 3],
	"not down": [0, 1, 3],
	"not left": [0, 2, 3],
	"not right": [0, 1, 2],
}

func desc_select_random_direction() -> String:
	return "int|<= Select a random [dir_options:RandomDirectionOptionsInput] direction [exclude_dir:ExcludeDirectionInput]"
func cmd_select_random_direction(slots: Dictionary, chosen_slot: int, dir_options: String = "any", exclude_dir: Dictionary = {}) -> void:
	var choose_from: Array = rand_dir_options.get(dir_options, [0])
	if exclude_dir.get("type", "ignore") != "ignore":
		var exclude_dir_val: int = resolve_complex_direction(exclude_dir, slots)
		var is_exclude: bool = exclude_dir.get("is_exclude", true)
		if is_exclude and exclude_dir_val in choose_from:
			choose_from.erase(exclude_dir_val)
		elif not is_exclude and exclude_dir_val not in choose_from:
			choose_from.append(exclude_dir_val)
	set_value_slot_as_number(slots, chosen_slot, Utility.random_list_element(choose_from))

func desc_add_text() -> Dictionary:
	return {
		"slot_type_hint": "string",
		"template_text": "<= Add [inserted_text:ComplexStringInput] to the [is_end:BoolChoice:true,end,beginning] of the slot\n" + \
		       "Separated by [separator:StringInput]",
		"extra_keywords": ["string", "concatenate"],
	}
func cmd_add_text(slots: Dictionary, chosen_slot: int, inserted_text: Dictionary, separator: String, is_end: bool) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to add text into: %s" % chosen_slot)
		return
	var text: String = slots[chosen_slot]
	var resolved_insert: String = get_complex_string_value(inserted_text, slots)
	if not text.strip_edges():
		slots[chosen_slot] = resolved_insert
	elif is_end:
		slots[chosen_slot] = text + separator + resolved_insert
	else:
		slots[chosen_slot] = resolved_insert + separator + text

func desc_add_text_property() -> Dictionary:
	return {
		"slot_type_hint": "string",
		"template_text": "<= Add the text value of [target_slot:SlotInput:entity,pos]'s [property_name:PropertyInput] property\n" \
		       + "to the [is_end:BoolChoice:true,end,beginning] of the slot, separated by [separator:StringInput]",
		"extra_keywords": ["string", "concatenate"],
	}
func cmd_add_text_property(slots: Dictionary, chosen_slot: int, target_slot: int, property_name: String, separator: String, is_end: bool) -> void:
	if not Commands.slot_is_string(chosen_slot) or (not Commands.slot_is_positions(target_slot) and not Commands.slot_is_entity(target_slot)):
		push_error("Invalid slots to add text property into: %s and %s" % [chosen_slot, target_slot])
		return
	var text: String = slots[chosen_slot]
	var resolved_insert: String = ""
	if Commands.slot_is_entity(target_slot):
		if slots[target_slot]:
			resolved_insert = EntityManager.get_entity_prop_text_value(slots[target_slot], property_name)
	elif Commands.slot_is_positions(target_slot):
		if slots[target_slot]:
			resolved_insert = MapManager.get_tile_prop_text_value_at(slots[target_slot], property_name)

	if not text.strip_edges():
		slots[chosen_slot] = resolved_insert
	elif is_end:
		slots[chosen_slot] = text + separator + resolved_insert
	else:
		slots[chosen_slot] = resolved_insert + separator + text


func desc_add_number_to_text() -> String:
	return "string|<= Add [inserted_num:ComplexScalarInput] to the [is_end:BoolChoice:true,end,beginning] of the text in this slot\n" + \
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

func desc_select_combined_text() -> Dictionary:
	return {
		"slot_type_hint": "string",
		"template_text": "<= Select the textual result of joining/combining [text_a:ComplexPropValueInput] and [text_b:ComplexPropValueInput]\n" \
			+ "Sepearated by [separator:StringInput]",	
		"extra_keywords": ["string", "concatenate", "add", "join"],
	}
func cmd_select_combined_text(slots: Dictionary, chosen_slot: int, text_a: Dictionary, text_b: Dictionary, separator: String) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to combine text into: %s" % chosen_slot)
	
	var text_a_val: String = resolve_complex_prop_value(text_a, slots)
	var text_b_val: String = resolve_complex_prop_value(text_b, slots)
	slots[chosen_slot] = text_a_val + separator + text_b_val

func desc_is_entity_at() -> Dictionary:
	return {
		"slot_type_hint": "pos",
		"template_text": "If there is an active entity (ignoring self) at this location [invert:InvertInput:with,without] a [prop_name:PropertyInput] property",
		"is_deprecated": true,
	}
func cmd_is_entity_at(slots: Dictionary, chosen_slot: int, prop_name: String, invert: bool) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		return false
	var at_positions: Array = slots[chosen_slot]
	if not at_positions:
		return false
	var entities_here: Array = EntityManager.get_entities_at_multiple(at_positions, slots[Slot.RED], [], false, false)
	entities_here = EntityManager.filter_entities_by_property(prop_name, entities_here, [], invert)
	return entities_here.size() > 0

func desc_if_entity_with_property_at() -> String:
	return "pos|If there is any active entity at this location [invert:InvertInput:with,without] a [is_truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property, excluding [exclude_slot:SlotInput:entity,none]"
func cmd_if_entity_with_property_at(slots: Dictionary, chosen_slot: int, prop_name: String, is_truthy: bool, invert: bool, exclude_slot: int) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		return false
	var ignore_list: Array = []
	if exclude_slot != SlotSelectorButton.NONE_SLOTS and slots[exclude_slot]:
		ignore_list.append(slots[exclude_slot].instance_id)

	var at_positions: Array = slots[chosen_slot]
	if not at_positions:
		return false
	var entities_here: Array = EntityManager.get_entities_at_multiple(at_positions, slots[Slot.RED], ignore_list, false, false)
	entities_here = EntityManager.filter_entities_by_property(prop_name, entities_here, [], is_truthy, invert)
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
		result = MapManager.check_multiple_pos_for_property_bool(slots[chosen_slot], slots[Slot.RED], property_name, true)
	#prints("if prop", property_name, "is", str(is_truthy), "prop val is: ", result)
	return result if is_truthy else not result

func desc_if_all_tiles_property_value() -> String:
	return "pos|If all the tiles here have a [is_truthy:BoolChoice:true,true or non-zero,false or zero] [property_name:PropertyInput] property"
func cmd_if_all_tiles_property_value(slots: Dictionary, chosen_slot: int, property_name: String, is_truthy: bool) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Slot for if all tiles property value is not a positions slot: %s" % chosen_slot)
		return false
	return MapManager.check_multiple_pos_for_property_bool(slots[chosen_slot], slots[Slot.RED], property_name, is_truthy, true)

func desc_c_is_named() -> String:
	return "entity|If the entity [invert:InvertInput:is,is not] named [check_name:EntityNameInput:1]"
func cmd_c_is_named(slots: Dictionary, chosen_slot: int, invert: bool, check_name: Variant) -> bool:
	var result = slots[chosen_slot].entity_name == get_complex_or_string_as_string(check_name, slots)
	return not result if invert else result

func desc_if_all_entities_property() -> String:
	return "pos|If [is_all:BoolChoice:true,every,any] [entity_name:EntityNameInput:1] entity here has a [invert:InvertInput:true or non-zero,false or zero] [property_name:PropertyInput] property"
func cmd_if_all_entities_property(slots: Dictionary, chosen_slot: int, entity_name: Variant, is_all: bool, invert: bool, property_name: String) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Slot for if all entities property is not a positions slot: %s" % chosen_slot)
		return false
	var e_id: = get_id_of_str_or_complex_entity_name(entity_name, slots)
	if e_id < 0:
		push_error("Entity name does not exist: %s" % get_complex_or_string_as_string(entity_name, slots))
		return false
	var tile_positions: Array = slots[chosen_slot]
	var all_entities: Array = EntityManager.find_all_entities_by_index(e_id, true)
	if all_entities.size() == 0:
		return false
	var filtered_enities: Array[BaseEntity] = []
	for entity in all_entities:
		if tile_positions and entity.get_moving_position() not in tile_positions:
			continue
		filtered_enities.append(entity)
	if filtered_enities.size() == 0:
		return false
	for entity in filtered_enities:
		if not EntityManager.entity_has_property(entity, property_name) and is_all:
			return invert
		var truthy_result: = EntityManager.get_entity_prop_is_truthy(entity, property_name)
		if invert:
			truthy_result = not truthy_result
		if not truthy_result and is_all:
			return false
		elif truthy_result and not is_all:
			return true
	return is_all

func desc_if_any_entity_exists() -> String:
	return "pos|If any entity exists here with a [is_falsey:BoolChoice:false,false or zero,true or non-zero] [prop_name:PropertyInput] property\n" \
		+ "Excluding [exclude_slot:SlotInput:entity,none]"
func cmd_if_any_entity_exists(slots: Dictionary, chosen_slot: int, exclude_slot: int, is_falsey: bool, prop_name: String) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Slot for if any entity exists is not a positions slot: %s" % chosen_slot)
		return false
	var tile_positions: Array = slots[chosen_slot]
	var ignore_list: Array = []
	if exclude_slot != SlotSelectorButton.NONE_SLOTS and slots[exclude_slot]:
		ignore_list.append(slots[exclude_slot].instance_id)

	if not tile_positions:
		var found_entities: Array = EntityManager.find_all_entities_with_truthy_property(prop_name, true, ignore_list, not is_falsey)
		return found_entities.size() > 0
	else:
		var found_entities: Array = EntityManager.find_entities_by_truthy_property_at_multiple(prop_name, tile_positions, not is_falsey, false, ignore_list)
		return found_entities.size() > 0

func desc_if_entity_exists_at_all_positions() -> String:
	return "pos|If at least one active entity with a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property exists at every position here"
func cmd_if_entity_exists_at_all_positions(slots: Dictionary, chosen_slot: int, truthy: bool, prop_name: String) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Slot for if entity exists at all positions is not a positions slot: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	var all_valid_entities: Array[BaseEntity] = EntityManager.find_all_entities_with_truthy_property(prop_name, true, [], truthy)
	var entities_cur_positions: Dictionary[BaseEntity, Array] = {}
	for pos in slots[chosen_slot]:
		if EntityManager.process_phase != 0:
			if pos not in EntityManager._entity_at_cache:
				return false
		var found_entity: = false
		for e in all_valid_entities:
			if not e in entities_cur_positions:
				entities_cur_positions[e] = EntityManager.get_all_positions_of_entity(e)
			if pos in entities_cur_positions[e]:
				found_entity = true
				break
		if not found_entity:
			return false
	return true

func desc_c_can_move() -> String:
	return "entity|If the entity [invert:InvertInput:can,cannot] move this way [direction:DirectionInput]"
func cmd_c_can_move(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	var selected = slots[chosen_slot]
	var result = selected.can_i_move(resolve_direction_value(direction, slots))
	return not result if invert else result

func desc_c_get_pushed() -> String:
	return "entity|If the entity successfully gets pushed this way [direction:DirectionInput:1,alt_default]\n" \
	     + "[keep_visual:BoolChoice:true,without turning,turning] to face that direction"
func cmd_c_get_pushed(slots: Dictionary, chosen_slot: int, direction: Variant, keep_visual: bool) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected: BaseEntity = slots[chosen_slot]
	if not selected:
		return true
	if selected.moving:
		return false
	var blue_entity: BaseEntity = slots[Slot.BLUE]
	# Pick an appropriate move speed
	if blue_entity and blue_entity.get_steps_per_tile() > 0:
		selected.set_steps_per_tile_override(blue_entity.get_steps_per_tile())
	elif selected.get_native_steps_per_tile() > 0:
		selected.set_native_move_speed()
	else:
		selected.set_steps_per_tile_override(EntityManager.get_default_spt())
	if blue_entity:
		selected.move_interp_style = blue_entity.move_interp_style
	var facing = resolve_variant_direction_value(direction, slots)
	var got_pushed: bool = selected.start_move(facing, not keep_visual)
	return got_pushed

func desc_get_pushed_revertable() -> String:
	return "entity|If the entity successfully gets pushed this way [direction:DirectionInput:1,alt_default]\n" \
	     + "[keep_visual:BoolChoice:true,without turning,turning] to face that direction\n" \
	     + "(Reverted if the move that triggered this command fails)"
func cmd_get_pushed_revertable(slots: Dictionary, chosen_slot: int, direction: Variant, keep_visual: bool) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected: BaseEntity = slots[chosen_slot]
	if selected.moving:
		return false
	var blue_entity: BaseEntity = slots[Slot.BLUE]
	# Pick an appropriate move speed
	if blue_entity and blue_entity.get_steps_per_tile() > 0:
		selected.set_steps_per_tile_override(blue_entity.get_steps_per_tile())
	elif selected.get_native_steps_per_tile() > 0:
		selected.set_native_move_speed()
	else:
		selected.set_steps_per_tile_override(EntityManager.get_default_spt())
	if blue_entity:
		selected.move_interp_style = blue_entity.move_interp_style
	var facing = resolve_variant_direction_value(direction, slots)
	var got_pushed: bool = selected.start_move(facing, not keep_visual, false, true)
	return got_pushed

func desc_c_is_facing() -> Dictionary:
	return {
		"display_name": "If entity facing direction",
		"slot_type_hint": "entity",
		"template_text": "If the entity [invert:InvertInput:is,is not] facing this way [direction:DirectionInput]",
		"is_deprecated": true,
	}
func cmd_c_is_facing(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected = slots[chosen_slot]

	var result = selected.facing == resolve_direction_value(direction, slots)
	return not result if invert else result

func desc_if_entity_facing_direction_matches() -> Dictionary:
	return {
		"display_name": "If entity facing direction matches",
		"slot_type_hint": "entity",
		"template_text": "If the entity [invert:InvertInput:is,is not] facing this way [compl_dir:DirectionInput:1]",
	}
func cmd_if_entity_facing_direction_matches(slots: Dictionary, chosen_slot: int, invert: bool, compl_dir: Dictionary) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected = slots[chosen_slot]

	var direction: int = resolve_complex_direction(compl_dir, slots)
	var result = selected.facing != -1 and selected.facing == direction
	return not result if invert else result

func desc_c_is_moving() -> Dictionary:
	return {
		"display_name": "If entity moving direction",
		"slot_type_hint": "entity",
		"template_text": "If the entity [invert:InvertInput:is,is not] moving this way [direction:DirectionInput]",
		"is_deprecated": true,
	}
func cmd_c_is_moving(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected = slots[chosen_slot]

	var result = selected.move_facing == resolve_direction_value(direction, slots)
	return not result if invert else result

func desc_if_entity_moving_direction_matches() -> Dictionary:
	return {
		"display_name": "If entity moving direction matches",
		"slot_type_hint": "entity",
		"template_text": "If the entity [invert:InvertInput:is,is not] moving this way [compl_dir:DirectionInput:1]",
	}
func cmd_if_entity_moving_direction_matches(slots: Dictionary, chosen_slot: int, invert: bool, compl_dir: Dictionary) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected = slots[chosen_slot]

	var direction: int = resolve_complex_direction(compl_dir, slots)
	var result = selected.move_facing != -1 and selected.move_facing == direction
	return not result if invert else result

func desc_select_direction_to_position() -> String:
	return "int|<= Select the direction to the single position [to_pos_slot:SlotInput:pos,entity] from [from_pos_slot:SlotInput:pos,entity]"
func cmd_select_direction_to_position(slots: Dictionary, chosen_slot: int, to_pos_slot: int, from_pos_slot: int) -> void:
	if not Commands.slot_is_scalar(chosen_slot) or not Commands.slot_has_position(to_pos_slot) or not Commands.slot_has_position(from_pos_slot):
		push_error("Invalid slots to select direction to position: %s and %s" % [chosen_slot, to_pos_slot])
		return
	if not _slot_has_single_tile_position(slots, from_pos_slot) or not _slot_has_single_tile_position(slots, to_pos_slot):
		slots[chosen_slot] = -1
	var from_pos: Vector2i = _single_tile_position_from_slot(slots, from_pos_slot)
	var to_pos: Vector2i = _single_tile_position_from_slot(slots, to_pos_slot)
	slots[chosen_slot] = Utility.get_direction_from_delta(from_pos, to_pos)

func desc_a_die() -> Dictionary:
	return {
		"display_name": "Destroy entity",
		"slot_type_hint": "entity",
		"template_text": "The entity dies now. (Uses default dying effect) [dying_eff_dir:DefaultableDirectionInput]",
		"extra_keywords": ["die"],
	}
func cmd_a_die(slots: Dictionary, chosen_slot: int, dying_eff_dir: Dictionary = {}) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		if dying_eff_dir.get("is_default", true):
			slots[chosen_slot].die()
		else:
			var dying_eff_dir_params: Dictionary = {"direction": resolve_complex_direction(dying_eff_dir["direction"], slots)}
			slots[chosen_slot].die({}, -1, dying_eff_dir_params)

func desc_destroy_entity_with_effect() -> String:
	return "entity|Destroy the entity playing the effect [death_eff_info:DyingEffectInput], with [die_dir:DefaultableDirectionInput]"
func cmd_destroy_entity_with_effect(slots: Dictionary, chosen_slot: int, death_eff_info: Dictionary, die_dir: Dictionary = {}) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		if not die_dir.get("is_default", true):
			death_eff_info["direction"] = resolve_complex_direction(die_dir["direction"], slots)
		if slots[chosen_slot].active or not slots[chosen_slot].dying:
			slots[chosen_slot].die_with_named_effect(death_eff_info)

func desc_destroy_entity_immediately() -> String:
	return "entity|Destroy the entity instantly, skipping it's default dying effect"
func cmd_destroy_entity_immediately(slots: Dictionary, chosen_slot: int) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		slots[chosen_slot].die({"none": true})

func desc_a_move() -> String:
	return "entity|The entity starts moving this way [complex_dir:DirectionInput:1]"
func cmd_a_move(slots: Dictionary, chosen_slot: int, complex_dir: Dictionary) -> void:
	if Commands.slot_is_entity(chosen_slot):
		var selected: BaseEntity = slots[chosen_slot]
		var move_facing: int = resolve_complex_direction(complex_dir, slots)
		if Utility.is_valid_facing(move_facing):
			selected.start_move(resolve_complex_direction(complex_dir, slots))

func desc_move_facing() -> String:
	return "entity|The entity starts moving this way [compl_move:DirectionInput:1] while facing this way [compl_face:DirectionInput:1]\n" \
	     + "[revertable:BoolChoice:true,(revertable),(non-revertable)]"
func cmd_move_facing(slots: Dictionary, chosen_slot: int, compl_move: Dictionary, compl_face: Dictionary, revertable: bool = false) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		var selected: BaseEntity = slots[chosen_slot]
		selected.set_facing(resolve_complex_direction(compl_face, slots))
		selected.start_move(resolve_complex_direction(compl_move, slots), false, false, revertable)

func desc_a_swap_tiles() -> String:
	return "pos|Swap the tiles here, switching [a_name:TileNameInput] and [b_name:TileNameInput]"
func cmd_a_swap_tiles(slots: Dictionary, chosen_slot: int, a_name: String, b_name: String) -> void:
	var position_filter = slots[chosen_slot]
	var tile_a = MapManager.get_tile_index(a_name)
	var tile_b = MapManager.get_tile_index(b_name)
	var positions_a = MapManager.get_all_positions_of_tile(tile_a, position_filter)
	var positions_b = MapManager.get_all_positions_of_tile(tile_b, position_filter)
	MapManager.replace_tiles_at_multiple(positions_a, tile_b)
	MapManager.replace_tiles_at_multiple(positions_b, tile_a)

func desc_a_set_tiles() -> String:
	return "pos|Change the tile(s) here to [tile_name:TileNameInput]"
func cmd_a_set_tiles(slots: Dictionary, chosen_slot: int, tile_name: String) -> void:
	MapManager.replace_tiles_at_multiple(slots[chosen_slot], MapManager.get_tile_index(tile_name))

func desc_erase_tiles_or_text() -> Dictionary:
	return {
		"display_name": "Erase tiles",
		"slot_type_hint": "pos",
		"template_text": "Erase the [erase_mode:CustomStringEnum:tiles and permanent text,tiles,permanent text] at these positions"
	}
func cmd_erase_tiles_or_text(slots: Dictionary, chosen_slot: int, erase_mode: String) -> void:
	if erase_mode == "tiles and permanent text":
		MapManager.erase_tiles_and_effects_at_multiple(slots[chosen_slot])
	elif erase_mode == "tiles":
		MapManager.erase_tiles_at_multiple(slots[chosen_slot])
	elif erase_mode == "permanent text":
		MapManager.erase_effects_at_multiple(slots[chosen_slot])

func desc_a_set_property() -> String:
	return "entity,pos|Set the entity or tile's [property_name:PropertyInput] property to [value:ComplexPropValueInput:compat]"
func cmd_a_set_property(slots: Dictionary, chosen_slot: int, property_name: String, value: Variant) -> void:
	var converted_value: Variant = resolve_complex_compat_prop_value(value, slots)

	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		slots[chosen_slot].set_local_property(property_name, converted_value)
	elif Commands.slot_is_positions(chosen_slot):
		var positions: Array = slots[chosen_slot]
		if positions.size() == 0:
			positions = MapManager.get_used_positions_in_all_layers()
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
	     + "[autoremove:BoolChoice:true,reset the property if it reaches zero,allow values less than and including zero]"
func cmd_a_property_subtract(slots: Dictionary, chosen_slot: int, property_name: String, amount: Dictionary, autoremove: bool) -> void:
	if Commands.slot_is_entity(chosen_slot):
		var selected: = slots[chosen_slot] as BaseEntity
		if selected:
			var existing = EntityManager.get_entity_prop_with_default(selected, property_name, 0)
			var new_val: float = existing - resolve_complex_scalar(amount, slots)

			if autoremove and (new_val <= 0 or is_zero_approx(new_val)):
				selected.reset_local_property(property_name)
			else:
				selected.set_local_property(property_name, new_val)
		else:
			prints("subtract prop, no selected entity")

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

func _create_entity_at(e_id: int, pos: Vector2i, facing: int, is_moving: bool) -> BaseEntity:
	var new_entity = EntityManager.create_entity(e_id, pos, facing)
	if is_moving:
		if new_entity.get_native_steps_per_tile() <= 0:
			new_entity.set_steps_per_tile_override(EntityManager.get_default_spt())
		new_entity.start_move(facing)
	EntityManager.post_gameplay_entity_created(new_entity)
	return new_entity

func desc_a_create_entity() -> String:
	return "pos|Create a new [entity_name:EntityNameInput:1] entity at these position(s)\n" \
	     + "facing this way [direction:DirectionInput] which is [is_moving:BoolChoice:false,moving,stationary]"
func cmd_a_create_entity(slots: Dictionary, chosen_slot: int, entity_name: Variant, direction: int, is_moving: bool) -> void:
	var e_id: = get_id_of_str_or_complex_entity_name(entity_name, slots)
	if e_id < 0:
		push_error("Entity name does not exist: %s" % get_complex_or_string_as_string(entity_name, slots))
		return
	var facing = Utility.resolve_full_direction_to_facing(direction, slots)
	for pos in slots[chosen_slot]:
		_create_entity_at(e_id, pos, facing, is_moving)

func desc_select_created_entity() -> String:
	return "entity|<= Select a new [entity_name:EntityNameInput] entity created at each position in [pos_slot:SlotInput:pos,entity]\n" \
		+ "facing this way [compl_dir:DirectionInput:1] which is [is_moving:BoolChoice:false,moving,stationary]"
func cmd_select_created_entity(slots: Dictionary, chosen_slot: int, entity_name: Dictionary, pos_slot: int, compl_dir: Dictionary, is_moving: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_has_position(pos_slot):
		push_error("Invalid slots to select created entity: %s and %s" % [chosen_slot, pos_slot])
		return
	var e_id: = get_id_of_complex_entity_name(entity_name, slots)
	if e_id < 0:
		push_error("Entity name does not exist: %s" % get_complex_string_value(entity_name, slots))
		return

	var pos: Vector2i = get_single_position_from_slot(pos_slot, slots)
	var facing: int = resolve_complex_direction(compl_dir, slots)
	var created: = _create_entity_at(e_id, pos, facing, is_moving)
	slots[chosen_slot] = created

func desc_select_just_created_entity() -> String:
	return "entity|<= Select the most recently created entity (this game tick only)"
func cmd_select_just_created_entity(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot to select just created entity into: %s" % chosen_slot)
		return
	slots[chosen_slot] = EntityManager.get_just_created_entity()

func desc_created_entity_spawn_animation() -> String:
	return "none|The most recently created entity (this game tick) plays the [anim_info:SpawnEffectInput] animation, with the direction: [anim_dir:DefaultableDirectionInput]" \
		+ " for [duration:ComplexScalarInput:default=0.5,step=0.1] seconds"
func cmd_created_entity_spawn_animation(slots: Dictionary, _slot: int, anim_info: Dictionary, anim_dir: Dictionary, duration: Dictionary) -> void:
	if anim_info.get("name", "").to_lower() == "none":
		return
	var eff_duration_val: float = resolve_complex_scalar(duration, slots)
	if eff_duration_val > 0:
		anim_info["duration"] = eff_duration_val
	if not anim_dir["is_default"]:
		anim_info["direction"] = resolve_complex_direction(anim_dir["direction"], slots)
	EntityManager.last_created_entity_play_spawn_effect(anim_info)

func desc_play_spawn_animation() -> String:
	return "entity|This entity plays the [anim_info:SpawnEffectInput] animation, with the direction: [anim_dir:DefaultableDirectionInput]" \
		+ " for [duration:ComplexScalarInput:default=0.5,step=0.1] seconds"
func cmd_play_spawn_animation(slots: Dictionary, chosen_slot: int, anim_info: Dictionary, anim_dir: Dictionary, duration: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot to play spawn animation on: %s" % chosen_slot)
		return
	if not slots[chosen_slot] or anim_info.get("name", "").to_lower() == "none":
		return
	var eff_duration_val: float = resolve_complex_scalar(duration, slots)
	if eff_duration_val > 0:
		anim_info["duration"] = eff_duration_val
	if not anim_dir["is_default"]:
		anim_info["direction"] = resolve_complex_direction(anim_dir["direction"], slots)
	slots[chosen_slot].do_named_or_default_spawn_effect(anim_info, false)

func desc_a_turn() -> Dictionary:
	return {
		"display_name": "Change Entity or Tile Facing Direction",
		"slot_type_hint": "entity,pos",
		"template_text": "Turn the entity/tile to face this way [complex_dir:DirectionInput:1]",
		"extra_keywords": ["turn"],
	}
func cmd_a_turn(slots: Dictionary, chosen_slot: int, complex_dir: Dictionary) -> void:
	if Commands.slot_is_entity(chosen_slot):
		if not slots[chosen_slot]:
			return
		if not slots[chosen_slot].moving:
			slots[chosen_slot].turn_to_facing(resolve_complex_direction(complex_dir, slots))
		else:
			# can't change the move facing while moving
			slots[chosen_slot].set_facing(resolve_complex_direction(complex_dir, slots))
	elif Commands.slot_is_positions(chosen_slot):
		set_tiles_to_facing(slots, chosen_slot, resolve_complex_direction(complex_dir, slots))


func desc_select_current_level_name() -> String:
	return "string|<= Select the unique internal name of the current level"
func cmd_select_current_level_name(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to select level list name into: %s" % chosen_slot)
		return
	slots[chosen_slot] = GameManager.loaded_level_name

func desc_select_current_level_title() -> String:
	return "string|<= Select the display title of the current level"
func cmd_select_current_level_title(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to select level title into: %s" % chosen_slot)
		return
	slots[chosen_slot] = MapManager.get_level_title()

func desc_select_level_title() -> String:
	return "string|<= Select the display title of the level with the internal name [level_name:LevelNameInput]"
func cmd_select_level_title(slots: Dictionary, chosen_slot: int, level_name: Dictionary) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to select level title into: %s" % chosen_slot)
		return
	var level_name_str: String = resolve_complex_string(level_name, slots)
	if not level_name_str:
		slots[chosen_slot] = ""
		return
	slots[chosen_slot] = FilesManager.get_level_title(GameManager.get_identified_game_name(), level_name_str)

func desc_select_current_level_list_name() -> String:
	return "string|<= Select the name of the current level list"
func cmd_select_current_level_list_name(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_string(chosen_slot):
		push_error("Invalid slot to select level list name into: %s" % chosen_slot)
		return
	slots[chosen_slot] = GameManager.current_level_list

func desc_if_current_level_list_is_hidden() -> String:
	return "none|If the current level is in a hidden list"
func cmd_if_current_level_list_is_hidden(_slots: Dictionary) -> bool:
	if not GameManager.current_level_list:
		return false
	if not GameManager.is_level_list_bundled(GameManager.current_level_list):
		return false
	var level_list_info: = GameManager._get_level_list(GameManager.current_level_list)
	return level_list_info.get("always_hidden", false)

func desc_if_playing_custom_level() -> String:
	return "none|If the current level [invert:InvertInput:is,is not] a custom level"
func cmd_if_playing_custom_level(_slots: Dictionary, _slot: int, invert: bool) -> bool:
	return GameManager.is_current_level_custom() != invert


func desc_next_level_exists() -> String:
	return "none|If there is or will be an unlocked level to advance to after completing this level"
func cmd_next_level_exists(_slots: Dictionary) -> bool:
	return GameManager.has_level_advance()

func desc_load_next_level() -> Dictionary:
	return {
		"display_name": "Complete and Advance Level (Deprecated)",
		"is_deprecated": true,
		"slot_type_hint": "none",
		"template_text": "(Deprecated, use 'Advance to Next Level') Complete this level. Load the next level, with a [delay:ComplexScalarInput:default=1,step=0.1] second delay",
	}
func cmd_load_next_level(slots: Dictionary, _slot: int, delay: Dictionary = {"type": "plain", "value": 1.0}) -> void:
	var delay_val: float = resolve_complex_scalar(delay, slots)
	GameManager.advance_level(delay_val)

func desc_advance_to_next_level() -> Dictionary:
	return {
		"display_name": "Advance to Next Level",
		"slot_type_hint": "none",
		"template_text": "Advance to the next level, with a [delay:ComplexScalarInput:default=1,step=0.1] second delay\n" \
			+ "[do_complete:BoolChoice:true,Complete,Do not complete] the current level\n" \
			+ "Extra transition intermission: [with_intermission_id:IntermissionIdInput]",
	}
func cmd_advance_to_next_level(_slots: Dictionary, _slot: int, delay: Dictionary, do_complete: bool, with_intermission_id: String) -> void:
	var delay_val: float = resolve_complex_scalar(delay, _slots)
	var with_intermissions: Array[String] = []
	if with_intermission_id:
		with_intermissions.append(with_intermission_id)
	if do_complete:
		GameManager.advance_level(delay_val, "", with_intermissions)
	else:
		GameManager.move_to_next_level(delay_val, with_intermissions)

func desc_complete_level_and_show_level_select() -> String:
	return "none|Leave this level, [do_complete:BoolChoice:true,completing,not completing] the level. Show the level select screen after a [delay:ComplexScalarInput:default=1,step=0.1] second delay\n" \
		+ "Extra transition intermission: [with_intermission_id:IntermissionIdInput]"
func cmd_complete_level_and_show_level_select(_slots: Dictionary, _slot: int, delay: Dictionary, do_complete: bool, with_intermission_id: String) -> void:
	var delay_val: float = resolve_complex_scalar(delay, _slots)
	var with_intermissions: Array[String] = []
	if with_intermission_id:
		with_intermissions.append(with_intermission_id)
	if do_complete:
		GameManager.complete_and_move_to_level_select(delay_val, with_intermissions)
	else:
		GameManager.move_to_level_select(delay_val, with_intermissions)

func desc_exit_to_level_select() -> String:
	return "none|Leave the current level without completing, show the level select screen after a [delay:ComplexScalarInput:default=1,step=0.1] second delay"
func cmd_exit_to_level_select(_slots: Dictionary, _slot: int, delay: Dictionary) -> void:
	var delay_val: float = resolve_complex_scalar(delay, _slots)
	GameManager.move_to_level_select(delay_val)

func desc_complete_level_without_leaving() -> String:
	return "none|Complete this level (without leaving the level) Extra completion intermission: [with_intermission_id:IntermissionIdInput]"
func cmd_complete_level_without_leaving(_slots: Dictionary, _slot: int, with_intermission_id: String) -> void:
	var extra_intermissions: Array[String] = []
	if with_intermission_id:
		extra_intermissions.append(with_intermission_id)
	GameManager.complete_current_level_without_transition(extra_intermissions)

func desc_load_first_level_of_list() -> String:
	return "none|Unlock and load the first level of the level list [list_val:LevelListNameInput] with a [delay:ComplexScalarInput:default=1,step=0.1] second delay\n" \
		+ "[complete_current:BoolChoice:true,Complete,Do not complete] the current level\n" \
		+ "Extra transition intermission: [with_intermission_id:IntermissionIdInput]"
func cmd_load_first_level_of_list(_slots: Dictionary, _slot: int, list_val: Dictionary, delay: Dictionary, complete_current: bool, with_intermission_id: String) -> void:
	var list_name: String = resolve_complex_string(list_val, _slots)
	var delay_val: float = resolve_complex_scalar(delay, _slots)
	var extra_intermissions: Array[String] = []
	if with_intermission_id:
		extra_intermissions.append(with_intermission_id)
	if not list_name:
		if complete_current:
			GameManager.complete_current_level_without_transition(extra_intermissions)
		return
	GameManager.move_to_level_list_start(list_name, delay_val, complete_current, extra_intermissions)

func desc_if_level_is_in_list() -> String:
	return "none|If the level [level_val:LevelNameInput] is in the level list [list_val:LevelListNameInput]"
func cmd_if_level_is_in_list(_slots: Dictionary, _slot: int, level_val: Dictionary, list_val: Dictionary) -> bool:
	var list_name: String = resolve_complex_string(list_val, _slots)
	var level_name: String = resolve_complex_string(level_val, _slots)
	if not list_name or not level_name:
		return false
	var levels_in_list: Array = GameManager.get_levels_in_level_list(list_name)
	return level_name in levels_in_list

func desc_if_level_is_unlocked() -> String:
	return "none|If the level [level_val:LevelNameInput] in the level list [list_val:LevelListNameInput] is unlocked"
func cmd_if_level_is_unlocked(_slots: Dictionary, _slot: int, level_val: Dictionary, list_val: Dictionary) -> bool:
	var list_name: String = resolve_complex_string(list_val, _slots)
	var level_name: String = resolve_complex_string(level_val, _slots)
	if not level_name:
		return false

	if not list_name:
		return GameManager.is_level_unlocked_in_any_list(level_name)
	else:
		return GameManager.is_level_unlocked_in_list(list_name, level_name)

func desc_if_current_level_is_completed() -> String:
	return "none|If the current level has already been completed"
func cmd_if_current_level_is_completed(_slots: Dictionary) -> bool:
	return GameManager.is_current_level_completed()

func desc_if_level_is_completed() -> String:
	return "none|If the level [level_val:LevelNameInput] in the level list [list_val:LevelListNameInput] has been completed"
func cmd_if_level_is_completed(_slots: Dictionary, _slot: int, level_val: Dictionary, list_val: Dictionary) -> bool:
	var list_name: String = resolve_complex_string(list_val, _slots)
	var level_name: String = resolve_complex_string(level_val, _slots)
	if not level_name:
		return false
	if not list_name:
		list_name = GameManager.get_list_containing_level(level_name)
	return GameManager.is_level_completed_in_list(list_name, level_name)

func desc_load_level_within_list() -> String:
	return "none|Unlock and load the level [level_val:LevelNameInput] within the level list [list_val:LevelListNameInput] with a [delay:ComplexScalarInput:default=1,step=0.1] second delay\n" \
		+ "[complete_current:BoolChoice:true,Complete,Do not complete] the current level\n" \
		+ "Extra transition intermission: [with_intermission_id:IntermissionIdInput]"
func cmd_load_level_within_list(_slots: Dictionary, _slot: int, level_val: Dictionary, list_val: Dictionary, delay: Dictionary, complete_current: bool, with_intermission_id: String) -> void:
	var list_name: String = resolve_complex_string(list_val, _slots)
	var level_name: String = resolve_complex_string(level_val, _slots)
	var delay_val: float = resolve_complex_scalar(delay, _slots)
	var extra_intermissions: Array[String] = []
	if with_intermission_id:
		extra_intermissions.append(with_intermission_id)
	if not level_name:
		if complete_current:
			GameManager.complete_current_level_without_transition(extra_intermissions)
		return
	
	if complete_current:
		GameManager.complete_and_move_to_level(list_name, level_name, delay_val, extra_intermissions)
	else:
		GameManager.move_to_level(list_name, level_name, delay_val, extra_intermissions)


func desc_take_a_turn() -> String:
	return "entity|The entity causes a turn to start (Discrete movement modes)"
func cmd_take_a_turn(slots: Dictionary, chosen_slot: int) -> void:
	if not EntityManager.is_discrete_mode():
		return
	if Commands.slot_is_entity(chosen_slot):
		EntityManager.request_move(slots[chosen_slot])

func desc_if_is_start_of_turn() -> String:
	return "none|If this is the start of a turn (Discrete mode)"
func cmd_if_is_start_of_turn(_slots: Dictionary) -> bool:
	return EntityManager.controller_frame

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
				number_result = float(prop.resolve(selected, slots[Slot.RED], [selected.get_moving_position()]))
			else:
				number_result = float(prop.get_value())
			return Utility.check_comparison(number_result, compare_to_val, comparison)
	elif Commands.slot_is_positions(chosen_slot) and selected:
		return MapManager.compare_multiple_pos_prop_value(selected, slots[Slot.RED], property_name, comparison, compare_to_val)
	return false

func desc_compare_values() -> String:
	return "string,number|If the numeric value in this slot is [comparison:OrderComparison] [compl_scalar:ComplexScalarInput]"
func cmd_compare_values(slots: Dictionary, chosen_slot: int, compl_scalar: Dictionary, comparison: String) -> bool:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to compare values: %s" % chosen_slot)
		return false
	var compare_to_val: float = resolve_complex_scalar(compl_scalar, slots)
	var slot_value: = get_value_slot_as_float(slots, chosen_slot)
	return Utility.check_comparison(slot_value, compare_to_val, comparison)

func desc_compare_text() -> Dictionary:
	return {
		"slot_type_hint": "string,number",
		"template_text": "If the textual value in this slot is [comparison:OrderComparison] [compl_text:ComplexStringInput] (alphabetically)",
		"extra_keywords": ["text", "compare"],
	}
func cmd_compare_text(slots: Dictionary, chosen_slot: int, compl_text: Dictionary, comparison: String) -> bool:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to compare text: %s" % chosen_slot)
	var slot_value: String = get_value_slot_as_string(slots, chosen_slot)
	var compare_to_val: String = resolve_complex_string(compl_text, slots)
	return Utility.check_alphanum_comparison(slot_value, compare_to_val, comparison)

func desc_exists() -> Dictionary:
	return {
		"display_name": "If Slot Contains Anything",
		"slot_type_hint": "entity,pos,string",
		"template_text": "If there is any entities/tiles/text selected in the slot",
		"extra_keywords": ["exists"],
	}
func cmd_exists(slots: Dictionary, chosen_slot: int) -> bool:
	var selected = slots[chosen_slot]
	if Commands.slot_is_entity(chosen_slot):
		return selected != null
	elif Commands.slot_is_positions(chosen_slot):
		return selected.size() > 0
	elif Commands.slot_is_string(chosen_slot):
		return selected.size() > 0
	return false

func desc_override_move_speed() -> String:
	return "entity|Override the entity's move speed for the current/next movement to [speed:ComplexScalarInput]"
func cmd_override_move_speed(slots: Dictionary, chosen_slot: int, speed: Variant) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		slots[chosen_slot].set_move_speed_override(resolve_complex_scalar(speed, slots))

func desc_override_teleport_speed_proportional() -> String:
	return "entity|Override the entity's current teleport move speed to be proportional to the distance traveled"
func cmd_override_teleport_speed_proportional(slots: Dictionary, chosen_slot: int) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		var entity: BaseEntity = slots[chosen_slot]
		if entity.moving:
			var move_distance: int = (entity.next_tile_pos - entity.tile_position).length()
			var base_steps_per_tile: int = entity.get_native_steps_per_tile()
			entity.set_steps_per_tile_override(ceili(base_steps_per_tile * move_distance))

func desc_override_move_animation() -> String:
	return "entity|Override the entity's move animation for the current/next movement to [anim_style:MoveAnimStyleInput]"
func cmd_override_move_animation(slots: Dictionary, chosen_slot: int, anim_style: String) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		slots[chosen_slot].set_move_interp_override(BaseEntity.read_move_interp_style_string(anim_style))

func desc_if_custom_conditional_event_result() -> Dictionary:
	return {
		"slot_type_hint": "entity,pos",
		"template_text": "If the result of triggering the [event_name:PropertyInput] custom event of the entity/tile is [truthy:BoolChoice:true,true or non-zero,false or zero]\n" \
			+ "with [blue_entity_slot:SlotInput:entity,none] as the *blue entity",
		"feature_tags": ["custom event"],
	}
func cmd_if_custom_conditional_event_result(slots: Dictionary, chosen_slot: int, event_name: String, blue_entity_slot: int, truthy: bool) -> bool:
	if not Commands.slot_is_entity(chosen_slot) and not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot (entity/pos) for custom conditional event result: %s" % chosen_slot)
		return false
	if blue_entity_slot != SlotSelectorButton.NONE_SLOTS and not Commands.slot_is_entity(blue_entity_slot):
		push_error("Invalid slot (blue entity) for custom conditional event result: %s" % blue_entity_slot)
		return false
	var result: bool = false
	if Commands.slot_is_entity(chosen_slot):
		result = EntityManager.get_entity_prop_is_truthy(slots[chosen_slot], event_name, false, slots[blue_entity_slot])
	elif Commands.slot_is_positions(chosen_slot):
		if slots[chosen_slot]:
			result = MapManager.conditional_tile_event(slots[chosen_slot], event_name, slots[blue_entity_slot], truthy)
		else:
			result = false
	return result == truthy

func desc_trigger_custom_event() -> Dictionary:
	return {
		"slot_type_hint": "entity,pos",
		"template_text": "(deprecated) Trigger the [event_name:PropertyInput] custom event of the entity/tiles",
		"tooltip": "deprecated: use trigger_custom_event_immediate instead",
		"feature_tags": ["custom event"],
		"is_deprecated": true,
	}
func cmd_trigger_custom_event(slots: Dictionary, chosen_slot: int, event_name: String) -> void:
	var pass_blue_entity: BaseEntity = null if chosen_slot == Slot.RED else slots[Slot.RED]
	if not pass_blue_entity:
		pass_blue_entity = slots[Slot.BLUE]
	
	var event_call: Callable = Callable()
	if Commands.slot_is_entity(chosen_slot):
		event_call = EntityManager.resolve_entity_interaction_event.bind(event_name, slots[chosen_slot], pass_blue_entity, [slots[chosen_slot].get_moving_position()])
	elif Commands.slot_is_positions(chosen_slot):
		event_call = MapManager.resolve_tiles_events.bind(slots[chosen_slot], event_name, pass_blue_entity)
	
	event_call.call()

func desc_trigger_custom_event_immediate() -> Dictionary:
	return {
		"slot_type_hint": "entity,pos",
		"template_text": "Trigger the [event_name:PropertyInput] custom event of the entity/tiles [is_immediate:BoolChoice:true,now,immediately after this event]",
		"feature_tags": ["custom event"],
	}
func cmd_trigger_custom_event_immediate(slots: Dictionary, chosen_slot: int, event_name: String, is_immediate: bool = true) -> void:
	var pass_blue_entity: BaseEntity = null if chosen_slot == Slot.RED else slots[Slot.RED]
	if not pass_blue_entity:
		pass_blue_entity = slots[Slot.BLUE]
	
	var event_call: Callable = Callable()
	if Commands.slot_is_entity(chosen_slot):
		if slots[chosen_slot]:
			event_call = EntityManager.resolve_entity_interaction_event.bind(event_name, slots[chosen_slot], pass_blue_entity, [slots[chosen_slot].get_moving_position()])
	elif Commands.slot_is_positions(chosen_slot):
		event_call = MapManager.resolve_tiles_events.bind(slots[chosen_slot], event_name, pass_blue_entity)
	
	if event_call.is_valid():
		if is_immediate:
			event_call.call()
		else:
			ConditionalsV3.add_deferred_call(event_call)

func desc_trigger_custom_event_for_each_entity() -> Dictionary:
	return {
		"slot_type_hint": "entity,pos",
		"template_text": "Trigger the [event_name:PropertyInput] custom event of the entity/tile for each entity ([include_self:InvertInput:excluding,including] self)\n" \
			+ "at [pos_filter_slot:SlotInput:pos] with a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property, [is_immediate:BoolChoice:true,now,immediately after this event]",
		"feature_tags": ["custom event"],
	}
func cmd_trigger_custom_event_for_each_entity(
		slots: Dictionary, chosen_slot: int, event_name: String,
		pos_filter_slot: int, include_self: bool, truthy: bool, prop_name: String,
		is_immediate: bool = true
	) -> void:
	var filter_positions: Array = slots[pos_filter_slot]
	var pos_filtered_enities: Array[BaseEntity] = []
	var self_exclude: BaseEntity = null if include_self else slots[Slot.RED]
	if filter_positions:
		pos_filtered_enities.assign(EntityManager.get_entities_at_multiple(filter_positions, self_exclude, [], true, false))
	else:
		pos_filtered_enities.assign(EntityManager.get_all_active_entities())
	var final_entities: Array[BaseEntity] = []
	for entity in pos_filtered_enities:
		if EntityManager.get_entity_prop_is_truthy(entity, prop_name, false) == truthy:
			final_entities.append(entity)

	var deferred_calls: Array[Callable] = []
	if Commands.slot_is_entity(chosen_slot):
		for e in final_entities:
			if is_immediate:
				EntityManager.resolve_entity_interaction_event(event_name, slots[chosen_slot], e, [slots[chosen_slot].get_moving_position()])
			else:
				deferred_calls.append(EntityManager.resolve_entity_interaction_event.bind(event_name, slots[chosen_slot], e, [slots[chosen_slot].get_moving_position()]))
	elif Commands.slot_is_positions(chosen_slot):
		for e in final_entities:
			if slots[chosen_slot]:
				if is_immediate:
					MapManager.resolve_tiles_events(slots[chosen_slot], event_name, e)
				else:
					deferred_calls.append(MapManager.resolve_tiles_events.bind(slots[chosen_slot], event_name, e))
			else:
				if is_immediate:
					MapManager.resolve_tiles_events([e.get_moving_position()], event_name, e)
				else:
					deferred_calls.append(MapManager.resolve_tiles_events.bind([e.get_moving_position()], event_name, e))
	
	for c in deferred_calls:
		ConditionalsV3.add_deferred_call(c)

func desc_trigger_custom_event_for_each_bonded_entity() -> Dictionary:
	return {
		"slot_type_hint": "entity,pos",
		"template_text": "Trigger the [event_name:PropertyInput] custom event of the entity/tile\n" \
			+ "for each entity bonded to [bonded_ref_slot:SlotInput:entity] ([include_self:BoolChoice:true,including,excluding] itself), [is_immediate:BoolChoice:true,now,immediately after this event]",
		"feature_tags": ["custom event"],
	}
func cmd_trigger_custom_event_for_each_bonded_entity(slots: Dictionary, chosen_slot: int, event_name: String, bonded_ref_slot: int, include_self: bool, is_immediate: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) and not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to trigger custom event for each bonded entity: %s" % chosen_slot)
		return
	if not Commands.slot_is_entity(bonded_ref_slot):
		push_error("Invalid slot get bonded entities of: %s" % bonded_ref_slot)
		return
	if not slots[bonded_ref_slot]:
		return

	var deferred_calls: Array[Callable] = []
	for inst_id in slots[chosen_slot].bond_group:
		if not include_self and inst_id == slots[bonded_ref_slot].instance_id:
			continue
		if EntityManager.has_instance(inst_id):
			var bonded_entity: BaseEntity = EntityManager.get_instance(inst_id)
			if Commands.slot_is_entity(chosen_slot):
				if is_immediate:
					EntityManager.resolve_entity_interaction_event(event_name, slots[chosen_slot], bonded_entity, [bonded_entity.get_moving_position()])
				else:
					deferred_calls.append(EntityManager.resolve_entity_interaction_event.bind(event_name, slots[chosen_slot], bonded_entity, [bonded_entity.get_moving_position()]))
			elif slots[chosen_slot]:
				if is_immediate:
					MapManager.resolve_tiles_events(slots[chosen_slot], event_name, bonded_entity)
				else:
					deferred_calls.append(MapManager.resolve_tiles_events.bind(slots[chosen_slot], event_name, bonded_entity))
			else:
				if is_immediate:
					MapManager.resolve_tiles_events([bonded_entity.get_moving_position()], event_name, bonded_entity)
				else:
					deferred_calls.append(MapManager.resolve_tiles_events.bind([bonded_entity.get_moving_position()], event_name, bonded_entity))
	
	for c in deferred_calls:
		ConditionalsV3.add_deferred_call(c)

func desc_trigger_custom_event_for_each_tailing_entity() -> Dictionary:
	return {
		"slot_type_hint": "entity,pos",
		"template_text": "Trigger the [event_name:PropertyInput] custom event of the entity/tile\n" \
			+ "for each entity tailing [tail_dir:TailDirInput] [tail_ref_slot:SlotInput:entity] ([include_self:BoolChoice:true,including,excluding] itself), [is_immediate:BoolChoice:true,now,immediately after this event]",
		"feature_tags": ["tailing", "custom event"],
	}
func cmd_trigger_custom_event_for_each_tailing_entity(slots: Dictionary, chosen_slot: int, event_name: String, tail_dir: String, tail_ref_slot: int, include_self: bool, is_immediate: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) and not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to trigger custom event for each bonded entity: %s" % chosen_slot)
		return
	if not Commands.slot_is_entity(tail_ref_slot):
		push_error("Invalid slot get tailing entities of: %s" % tail_ref_slot)
		return
	if not slots[tail_ref_slot]:
		return

	var with_behind: bool = tail_dir != "ahead of"
	var with_ahead: bool = tail_dir != "behind"
	var exclude_list: Array[BaseEntity] = []
	if not include_self:
		exclude_list.append(slots[tail_ref_slot])
	var tailing_entities: = EntityManager.get_entity_tailing_chain(slots[tail_ref_slot], with_behind, with_ahead, exclude_list)
	tailing_entities = EntityManager.get_sorted_tailing_chain(tailing_entities)
	
	var deferred_calls: Array[Callable] = []
	for e in tailing_entities:
		if Commands.slot_is_entity(chosen_slot):
			if is_immediate:
				EntityManager.resolve_entity_interaction_event(event_name, slots[chosen_slot], e, [e.get_moving_position()])
			else:
				deferred_calls.append(EntityManager.resolve_entity_interaction_event.bind(event_name, slots[chosen_slot], e, [e.get_moving_position()]))
		elif slots[chosen_slot]:
			if is_immediate:
				MapManager.resolve_tiles_events(slots[chosen_slot], event_name, e)
			else:
				deferred_calls.append(MapManager.resolve_tiles_events.bind(slots[chosen_slot], event_name, e))
		else:
			if is_immediate:
				MapManager.resolve_tiles_events([e.get_moving_position()], event_name, e)
			else:
				deferred_calls.append(MapManager.resolve_tiles_events.bind([e.get_moving_position()], event_name, e))
	
	for c in deferred_calls:
		ConditionalsV3.add_deferred_call(c)

func desc_trigger_custom_event_for_each_position() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "Trigger the [event_name:PropertyInput] custom event of the entity at each position in [in_positions_slot:SlotInput:pos], [is_immediate:BoolChoice:true,now,immediately after this event]",
		"feature_tags": ["custom event"],
	}
func cmd_trigger_custom_event_for_each_position(slots: Dictionary, chosen_slot: int, event_name: String, in_positions_slot: int, is_immediate: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_positions(in_positions_slot):
		push_error("Invalid slots to trigger custom event for each position: %s and %s" % [chosen_slot, in_positions_slot])
		return
	if not slots[chosen_slot]:
		return
	var positions: Array = slots[in_positions_slot]
	if not positions:
		positions = MapManager.get_used_positions_in_all_layers()
		
	var deferred_calls: Array[Callable] = []
	for pos in positions:
		if is_immediate:
			EntityManager.resolve_entity_interaction_event(event_name, slots[chosen_slot], null, [pos])
		else:
			deferred_calls.append(EntityManager.resolve_entity_interaction_event.bind(event_name, slots[chosen_slot], null, [pos]))
	
	for c in deferred_calls:
		ConditionalsV3.add_deferred_call(c)

func desc_trigger_custom_event_for_tile_at_each_position() -> Dictionary:
	return {
		"slot_type_hint": "pos",
		"template_text": "Trigger the [event_name:PropertyInput] custom event of the each tile at the positions in this slot,\n" \
			+ "with the entity [blue_entity_slot:SlotInput:entity,none] as the *blue entity, [is_immediate:BoolChoice:true,now,immediately after this event]",
		"feature_tags": ["custom event"],
	}
func cmd_trigger_custom_event_for_tile_at_each_position(slots: Dictionary, chosen_slot: int, event_name: String, blue_entity_slot: int, is_immediate: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot) or (blue_entity_slot != SlotSelectorButton.NONE_SLOTS and not Commands.slot_is_entity(blue_entity_slot)):
		push_error("Invalid slots to trigger custom event for each position: %s" % [chosen_slot])
		return
	var blue_entity: BaseEntity = null
	if blue_entity_slot != SlotSelectorButton.NONE_SLOTS:
		blue_entity = slots[blue_entity_slot]

	var positions: Array = slots[chosen_slot]
	if not positions:
		positions = MapManager.get_used_positions_in_all_layers()
	
	if is_immediate:
		MapManager.resolve_tile_individual_events(positions, event_name, blue_entity)
	else:
		ConditionalsV3.add_deferred_call(MapManager.resolve_tile_individual_events.bind(positions, event_name, blue_entity))

func desc_delayed_custom_entity_event() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "Trigger the [event_name:PropertyInput] custom event of the entity after a [delay:ComplexScalarInput:default=0.5,step=0.1] second delay\n" \
			+ "(If the entity is still active at that time)",
		"feature_tags": ["custom event"],
	}
func cmd_delayed_custom_entity_event(slots: Dictionary, chosen_slot: int, event_name: String, delay: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to trigger delayed custom entity event: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	EntityManager.add_delayed_entity_prop_event(slots[chosen_slot], event_name, resolve_complex_scalar(delay, slots))

func desc_cancel_delayed_custom_entity_event() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "Cancel all delayed [event_name:PropertyInput] custom events of the entity that haven't triggered yet",
		"feature_tags": ["custom event"],
	}
func cmd_cancel_delayed_custom_entity_event(slots: Dictionary, chosen_slot: int, event_name: String) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to cancel delayed custom entity event: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	EntityManager.remove_delayed_entity_prop_event(slots[chosen_slot], event_name)
		

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
	return "entity|If the entity is intending to move this way [complex_dir:DirectionInput:1]"
func cmd_is_intended_move_direction(slots: Dictionary, chosen_slot: int, complex_dir: Dictionary) -> bool:
	if not _entity_has_controller_intention_count(slots, chosen_slot):
		return false
	var intended_move_facing: int = slots[chosen_slot].soft_check_intended_move_facing()
	if intended_move_facing == -1:
		return false
	return intended_move_facing == resolve_complex_direction(complex_dir, slots)
	
func desc_show_mini_text_at() -> Dictionary:
	return {
		"non_condition": true,
		"is_deprecated": true,
		"slot_type_hint": "pos,entity",
		"tooltip": "Deprecated, use 'Create popup text' or 'Create permanent text' instead",
		"template_text": "Temporarily show the text [text_slot:SlotInput:string,number]\n" \
			+ "[is_above:BoolChoice:true,above,at] this position/entity",
	}
func cmd_show_mini_text_at(slots: Dictionary, chosen_slot: int, text_slot: int, is_above: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot) and not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot to show mini text at: %s" % chosen_slot)
		return

	var mini_message: String = get_value_slot_as_string(slots, text_slot)
	if Commands.slot_is_entity(chosen_slot):
		if slots[chosen_slot]:
			var message_pos: Vector2 = EntityManager.get_pos_above(slots[chosen_slot]) if is_above else slots[chosen_slot].get_center_position()
			EffectsHelper.spawn_mini_text_at(mini_message, message_pos, -1, 2)
		else:
			push_error("Entity slot %s is empty" % chosen_slot)
	else:
		if not slots[chosen_slot]:
			push_error("Positions slot %s is empty" % chosen_slot)
		for tile_pos in slots[chosen_slot]:
			var message_pos: Vector2 = MapManager.get_world_pos_above(tile_pos) if is_above else MapManager.tile_to_world_position_centered(tile_pos)
			EffectsHelper.spawn_mini_text_at(mini_message, message_pos, -1, 2)

func desc_create_popup_text() -> Dictionary:
	return {
		"non_condition": true,
		"slot_type_hint": "pos,entity",
		"template_text": "Create a pop-up text message [is_above:BoolChoice:true,above,at] this position/entity. Text: [text:ComplexStringInput]\n" \
			+ "font size: [font_size:ComplexScalarInput:default=9.0] fill: [fill_color:ColorInput:default=#ffffff] outline: [outline_color:ColorInput:default=#000000]" \
			+ " seconds: [popup_time:ComplexScalarInput:default=1,step=0.1] z-offset: [z_offset:ComplexScalarInput:default=0,step=1]"
			+ " alignment: [is_center:BoolChoice:true,centered,left-aligned]"
	}
func cmd_create_popup_text(
	slots: Dictionary, chosen_slot: int,
	is_above: bool,
	text: Dictionary,
	font_size: Dictionary,
	fill_color: Dictionary,
	outline_color: Dictionary,
	popup_time: Dictionary,
	z_offset: Dictionary,
	is_center: bool
) -> void:
	_create_text_effect(slots, chosen_slot, is_above, {
		"text": text,
		"font_size": font_size,
		"fill_color": fill_color,
		"outline_color": outline_color,
		"popup_time": popup_time,
		"z_offset": z_offset,
		"is_center": is_center,
	})

func desc_create_permanent_text() -> Dictionary:
	return {
		"non_condition": true,
		"slot_type_hint": "pos,entity",
		"template_text": "Create a pop-up text message [is_above:BoolChoice:true,above,at] this position/entity. Text: [text:ComplexStringInput]\n" \
			+ "font size: [font_size:ComplexScalarInput:default=9.0] fill: [fill_color:ColorInput:default=#ffffff] outline: [outline_color:ColorInput:default=#000000]" \
			+ " z-offset: [z_offset:ComplexScalarInput:default=0,step=1] alignment: [is_center:BoolChoice:true,centered,left-aligned]" \
			+ " position offset: [offset:Vector2Input]px"
	}
func cmd_create_permanent_text(
	slots: Dictionary, chosen_slot: int,
	is_above: bool,
	text: Dictionary,
	font_size: Dictionary,
	fill_color: Dictionary,
	outline_color: Dictionary,
	z_offset: Dictionary,
	is_center: bool,
	offset: Vector2
) -> void:
	_create_text_effect(slots, chosen_slot, is_above, {
		"text": text,
		"font_size": font_size,
		"fill_color": fill_color,
		"outline_color": outline_color,
		"popup_time": 0,
		"z_offset": z_offset,
		"is_center": is_center,
	}, offset)


func _create_text_effect(slots: Dictionary, pos_slot: int, is_above: bool, args: Dictionary, pixel_offset: Vector2 = Vector2.ZERO) -> void:
	if not Commands.slot_is_positions(pos_slot) and not Commands.slot_is_entity(pos_slot):
		push_error("Invalid slot to create popup text at: %s" % pos_slot)
		return

	var message_str: String = resolve_complex_string(args["text"], slots)
	var message_positions: Array[Vector2] = []
	if Commands.slot_is_entity(pos_slot):
		if slots[pos_slot]:
			message_positions.append(EntityManager.get_pos_above(slots[pos_slot]) if is_above else slots[pos_slot].get_center_position())
		else:
			push_error("Entity slot %s is empty" % pos_slot)
			return
	else:
		if not slots[pos_slot]:
			push_error("Positions slot %s is empty" % pos_slot)
			return
		for tile_pos in slots[pos_slot]:
			message_positions.append(MapManager.get_world_pos_above(tile_pos) if is_above else MapManager.tile_to_world_position_centered(tile_pos))
	
	for pos in message_positions:
		var popup_time: float = 0
		if args.has("popup_time"):
			popup_time = resolve_complex_scalar(args["popup_time"], slots)
		var popup_msg_options: Dictionary = {
			"text": message_str,
			"font_size": resolve_complex_scalar(args["font_size"], slots),
			"fill_color": resolve_complex_color(args["fill_color"], slots),
			"outline_color": resolve_complex_color(args["outline_color"], slots),
			"popup_time": popup_time,
			"z_offset": resolve_complex_scalar(args["z_offset"], slots),
			"h_align": HORIZONTAL_ALIGNMENT_CENTER if args["is_center"] else HORIZONTAL_ALIGNMENT_LEFT,
		}
		if popup_time > 0:
			var global_pos: Vector2 = pos
			global_pos += pixel_offset
			EffectsHelper.spawn_text_effect(global_pos, popup_msg_options)
		else:
			popup_msg_options["pos_offset"] = pixel_offset
			MapManager.create_persistant_text_effect_from_info(pos, popup_msg_options)

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
	
func desc_true() -> Dictionary:
	return {
		"non_condition": true,
		"slot_type_hint": "none",
		"template_text": "Set this step's result to True",
	}
func cmd_true(_slots: Dictionary) -> Dictionary:
	return {"step_result": true}

func desc_false() -> Dictionary:
	return {
		"non_condition": true,
		"slot_type_hint": "none",
		"template_text": "Set this step's result to False",
	}
func cmd_false(_slots: Dictionary) -> Dictionary:
	return {"step_result": false}

func desc_number_result() -> Dictionary:
	return {
		"non_condition": true,
		"slot_type_hint": "number,string",
		"template_text": "Change this step's result to be the numeric value of this slot",
	}
func cmd_number_result(slots: Dictionary, chosen_slot: int) -> Dictionary:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to get number result from: %s" % chosen_slot)
		return {"step_result": 0.0}
	# might be float or int
	var numeric_val: Variant = get_value_slot_as_number(slots, chosen_slot)
	return {"step_result": numeric_val}

func desc_text_result() -> Dictionary:
	return {
		"non_condition": true,
		"slot_type_hint": "number,string",
		"template_text": "Change this step's result to be the text value of this slot",
	}
func cmd_text_result(slots: Dictionary, chosen_slot: int) -> Dictionary:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to get text result from: %s" % chosen_slot)
		return {"step_result": ""}
	return {"step_result": get_value_slot_as_string(slots, chosen_slot)}

func desc_property_result() -> Dictionary:
	return {
		"non_condition": true,
		"slot_type_hint": "entity",
		"template_text": "Change this step's result to be the value of the [property_name:PropertyInput] property of this entity",
	}
func cmd_property_result(slots: Dictionary, chosen_slot: int, property_name: String) -> Dictionary:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot to get property result from: %s" % chosen_slot)
		return {"step_result": false}
	if not slots[chosen_slot]:
		return {"step_result": false}
	return {"step_result": EntityManager.get_entity_prop_with_default(slots[chosen_slot], property_name, false)}


func desc_make_entity_dependent() -> String:
	return "entity|Make the entity dependent on this entity [on_entity_slot:SlotInput:entity]"
func cmd_make_entity_dependent(slots: Dictionary, chosen_slot: int, on_entity_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(on_entity_slot):
		push_error("Invalid slots to make entity dependent: %s and %s" % [chosen_slot, on_entity_slot])
		return
	if on_entity_slot == chosen_slot or not slots[on_entity_slot] or not slots[chosen_slot]:
		return
	slots[on_entity_slot].add_dependant_entity(slots[chosen_slot])

func desc_make_entity_independent() -> String:
	return "entity|Make the entity stop depending on this entity [on_entity_slot:SlotInput:entity]"
func cmd_make_entity_independent(slots: Dictionary, chosen_slot: int, on_entity_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(on_entity_slot):
		push_error("Invalid slots to make entity independent: %s and %s" % [chosen_slot, on_entity_slot])
		return
	if on_entity_slot == chosen_slot or not slots[on_entity_slot] or not slots[chosen_slot]:
		return
	slots[on_entity_slot].remove_dependant_entity(slots[chosen_slot])

func desc_make_entity_fully_independent() -> String:
	return "entity|Make the entity stop depending on all other entities"
func cmd_make_entity_fully_independent(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot]:
		push_error("Invalid slot or empty slot to make entity fully independent: %s" % chosen_slot)
		return
	slots[chosen_slot].stop_depending_on_all()

func desc_set_entity_as_active() -> String:
	return "entity|Set the entity as [is_active:BoolChoice:true,active,inactive]"
func cmd_set_entity_as_active(slots: Dictionary, chosen_slot: int, is_active: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot]:
		push_error("Invalid slot or empty slot to set entity as active: %s" % chosen_slot)
		return
	if slots[chosen_slot]:
		slots[chosen_slot].set_active(is_active)

func desc_apply_effect_to_entity() -> String:
	return "entity|Apply the (ongoing) effect [effect_info:SpecialEffectInput] to the entity"
func cmd_apply_effect_to_entity(slots: Dictionary, chosen_slot: int, effect_info: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot]:
		push_error("Invalid slot or empty slot to apply effect to entity: %s" % chosen_slot)
		return
	if slots[chosen_slot]:
		var effect_color: Color = Utility.get_dict_color(effect_info, "color", Color.WHITE)
		EntityManager.apply_special_effect(slots[chosen_slot], effect_info["effect"], effect_color, effect_info.get("amount", 0.0))

func desc_remove_effects_from_entity() -> String:
	return "entity|Remove all (ongoing) sprite effects from the entity"
func cmd_remove_effects_from_entity(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot]:
		push_error("Invalid slot or empty slot to remove effects from entity: %s" % chosen_slot)
		return
	if slots[chosen_slot] and not slots[chosen_slot].dying:
		EntityManager.clear_entity_special_effects(slots[chosen_slot])

func desc_remove_sprite_effect_from_entity() -> String:
	return "entity|Remove the (ongoing) sprite effect [effect_name:SpecialEffectInput] from the entity"
func cmd_remove_sprite_effect_from_entity(slots: Dictionary, chosen_slot: int, effect_name: String) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot]:
		push_error("Invalid slot or empty slot to remove sprite effect from entity: %s" % chosen_slot)
		return
	if slots[chosen_slot] and not slots[chosen_slot].dying:
		EntityManager.remove_special_effect(slots[chosen_slot], effect_name)

func desc_entity_play_bump_effect() -> String:
	return "entity|The entity plays the short \"bump\" effect [effect_info:BumpEffectInput]"
func cmd_entity_play_bump_effect(slots: Dictionary, chosen_slot: int, effect_info: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot]:
		push_error("Invalid slot or empty slot to play bump effect: %s" % chosen_slot)
		return
	if slots[chosen_slot]:
		slots[chosen_slot].do_named_bump_effect(effect_info)

func desc_entity_play_bump_effect_with_direction_and_duration() -> String:
	return "entity|The entity plays the short \"bump\" effect [effect_info:BumpEffectInput], with the direction: [eff_dir:DefaultableDirectionInput] for [duration:ComplexScalarInput:default=0.5,step=0.1] seconds"
func cmd_entity_play_bump_effect_with_direction_and_duration(slots: Dictionary, chosen_slot: int, effect_info: Dictionary, eff_dir: Dictionary, duration: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot]:
		push_error("Invalid slot or empty slot to play bump effect: %s" % chosen_slot)
		return
	if not eff_dir["is_default"]:
		effect_info["direction"] = resolve_complex_direction(eff_dir["direction"], slots)
	var duration_val: float = resolve_complex_scalar(duration, slots)
	if duration_val > 0.0:
		effect_info["duration"] = duration_val
	if slots[chosen_slot]:
		slots[chosen_slot].do_named_bump_effect(effect_info)


func desc_do_screen_shake() -> String:
	return "none|Shake the screen! Intensity [intensity:ComplexScalarInput:default=2.0,step=0.1]" \
	       + " for [duration:ComplexScalarInput:default=0.5,step=0.1] seconds"
func cmd_do_screen_shake(slots: Dictionary, _slot: int, intensity: Dictionary, duration: Dictionary) -> void:
	if GameManager.game_camera and GameManager.game_camera.active:
		var intensity_val: float = resolve_complex_scalar(intensity, slots)
		var duration_val: float = resolve_complex_scalar(duration, slots)
		GameManager.game_camera.do_screen_shake(intensity_val, duration_val)

func desc_stop_screen_shake() -> String:
	return "none|Stop shaking the screen"
func cmd_stop_screen_shake(_slots: Dictionary) -> void:
	if GameManager.game_camera and GameManager.game_camera.active:
		GameManager.game_camera.stop_screen_shake()

func desc_if_action_1_is_held() -> String:
	return "none|If the input action 1 [is_just_pressed:BoolChoice:false,was just pressed,is currently held down]"
func cmd_if_action_1_is_held(_slots: Dictionary, _slot: int, is_just_pressed: bool) -> bool:
	if is_just_pressed:
		return Input.is_action_just_pressed(&"input_action_1")
	else:
		return Input.is_action_pressed(&"input_action_1")

func desc_if_action_2_is_held() -> String:
	return "none|If the input action 2 [is_just_pressed:BoolChoice:false,was just pressed,is currently held down]"
func cmd_if_action_2_is_held(_slots: Dictionary, _slot: int, is_just_pressed: bool) -> bool:
	if is_just_pressed:
		return Input.is_action_just_pressed(&"input_action_2")
	else:
		return Input.is_action_pressed(&"input_action_2")

func desc_if_action_3_is_held() -> String:
	return "none|If the input action 3 [is_just_pressed:BoolChoice:false,was just pressed,is currently held down]"
func cmd_if_action_3_is_held(_slots: Dictionary, _slot: int, is_just_pressed: bool) -> bool:
	if is_just_pressed:
		return Input.is_action_just_pressed(&"input_action_3")
	else:
		return Input.is_action_pressed(&"input_action_3")

func _get_directional_input_vector(just_pressed_only: bool = false) -> Vector2:
	if just_pressed_only:
		return Utility.input_just_pressed_vector_by_prefix("move_")
	return Utility.input_vector_by_prefix("move_")

func _direction_approximately_matches(check_vec: Vector2, input_vec: Vector2) -> bool:
	if input_vec.length_squared() < 0.04: # 0.2 * 0.2
		return false
	if check_vec.abs().max_axis_index() != input_vec.abs().max_axis_index():
		return false
	if check_vec.dot(input_vec) < 0.0:
		return false
	return true

func desc_if_direction_is_held() -> String:
	return "none|If the directional intput is currently pointing this way [compl_dir:DirectionInput:1]"
func cmd_if_direction_is_held(slots: Dictionary, _slot: int, compl_dir: Dictionary) -> bool:
	var direction: int = resolve_complex_direction(compl_dir, slots)
	if direction == -1:
		return false
	return _direction_approximately_matches(Utility.facing_vector(direction), _get_directional_input_vector())

func desc_if_direction_was_just_pressed() -> String:
	return "none|If the directional input just started to be held this way [compl_dir:DirectionInput:1]"
func cmd_if_direction_was_just_pressed(slots: Dictionary, _slot: int, compl_dir: Dictionary) -> bool:
	var direction: int = resolve_complex_direction(compl_dir, slots)
	if direction == -1:
		return false
	return Utility.is_input_direction_just_pressed(direction, "move_")

func desc_if_any_direction_is_held() -> String:
	return "none|If the directional input is currently held in any direction"
func cmd_if_any_direction_is_held(_slots: Dictionary) -> bool:
	var directional_vec: = _get_directional_input_vector()
	return directional_vec.length() >= 0.2

func desc_if_any_direction_was_just_pressed() -> String:
	return "none|If the directional input just started to be held in any direction"
func cmd_if_any_direction_was_just_pressed(_slots: Dictionary) -> bool:
	var just_pressed_vec_abs: = _get_directional_input_vector(true).abs()
	return just_pressed_vec_abs.x + just_pressed_vec_abs.y > 0.0

func desc_select_held_direction() -> String:
	return "int|<= Select the direction that is currently being held, biased [bias_vertical:BoolChoice:true,vertically,horizontally]"
func cmd_select_held_direction(slots: Dictionary, chosen_slot: int, bias_vertical: bool) -> void:
	if not Commands.slot_is_int(chosen_slot):
		push_error("Invalid slot or empty slot to select held direction: %s" % chosen_slot)
		return
	var held_vec: = _get_directional_input_vector()
	slots[chosen_slot] = Utility.biased_vector_to_facing(held_vec, bias_vertical)

func desc_select_just_pressed_direction() -> String:
	return "int|<= Select the direction that just started to become held, biased [bias_vertical:BoolChoice:true,vertically,horizontally]"
func cmd_select_just_pressed_direction(slots: Dictionary, chosen_slot: int, bias_vertical: bool) -> void:
	if not Commands.slot_is_int(chosen_slot):
		push_error("Invalid slot or empty slot to select just pressed direction: %s" % chosen_slot)
		return
	var held_vec: = _get_directional_input_vector(true)
	var biased_dir: = Utility.biased_vector_to_facing(held_vec, bias_vertical)

	slots[chosen_slot] = biased_dir


func desc_camera_next_focus() -> String:
	return "none|Move the camera focus to the next valid target"
func cmd_camera_next_focus(_slots: Dictionary) -> void:
	GameManager.game_camera.follow_next(1)

func desc_camera_previous_focus() -> String:
	return "none|Move the camera focus to the previous valid target"
func cmd_camera_previous_focus(_slots: Dictionary) -> void:
	GameManager.game_camera.follow_next(-1)

func desc_select_camera_focus() -> String:
	return "entity|Select the entity that is currently the camera focus"
func cmd_select_camera_focus(slots: Dictionary, chosen_slot: int) -> void:
	slots[chosen_slot] = GameManager.get_camera_focus_entity()

func desc_select_next_or_previous_camera_focus() -> String:
	return "entity|Select the [is_next:BoolChoice:true,next,previous] valid camera focus"
func cmd_select_other_camera_focus(slots: Dictionary, chosen_slot: int, is_next: bool) -> void:
	slots[chosen_slot] = GameManager.get_next_prev_camera_focus(1 if is_next else -1)

func desc_camera_focus_default() -> String:
	return "none|Change the camera targets and focus to the default setting"
func cmd_camera_focus_default(_slots: Dictionary) -> void:
	GameManager.reset_camera_follow()

func desc_if_entity_is_camera_target() -> String:
	return "entity|If the entity is currently a valid camera target"
func cmd_if_entity_is_camera_target(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity is camera target: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	return EntityManager.is_entity_in_camera_following(slots[chosen_slot])

func desc_if_entity_is_camera_focus() -> String:
	return "entity|If the entity is currently the camera focus"
func cmd_if_entity_is_camera_focus(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity is camera focus: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	return GameManager.is_entity_current_camera_focus(slots[chosen_slot])

func desc_focus_camera_on_named_entity() -> String:
	return "none|Set the camera targets to be entities named [compl_ent_name:EntityNameInput]"
func cmd_focus_camera_on_named_entity(slots: Dictionary, _slot: int, compl_ent_name: Dictionary) -> void:
	var ent_name: String = get_complex_string_value(compl_ent_name, slots)
	GameManager.change_camera_follow_to_entity_name(ent_name)

func desc_focus_camera_on_entity_by_property() -> String:
	return "none|Set the camera targets to be entities with a true or non-zero [property_name:PropertyInput] property"
func cmd_focus_camera_on_entity_by_property(_slots: Dictionary, _slot: int, property_name: String) -> void:
	GameManager.change_camera_follow_to_entity_property(property_name)

func desc_focus_camera_on_specific_entity() -> String:
	return "entity|Set the camera target and focus to only this entity"
func cmd_focus_camera_on_specific_entity(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to focus camera on specific entity: %s" % chosen_slot)
		return
	if slots[chosen_slot]:
		GameManager.set_camera_follow_instances([slots[chosen_slot].instance_id])
	else:
		GameManager.set_camera_follow_instances([])

func desc_focus_camera_add_specific_entity() -> String:
	return "entity|Add this entity to the camera follow list (removes focus by name/property)"
func cmd_focus_camera_add_specific_entity(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to add specific entity to camera follow list: %s" % chosen_slot)
		return
	if slots[chosen_slot]:
		EntityManager.add_camera_following_instance(slots[chosen_slot].instance_id)

func desc_focus_camera_remove_specific_entity() -> String:
	return "entity|Remove this entity from the camera follow list (if following by list of specific entities)"
func cmd_focus_camera_remove_specific_entity(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to remove specific entity from camera follow list: %s" % chosen_slot)
		return
	if slots[chosen_slot]:
		EntityManager.remove_camera_following_instance(slots[chosen_slot].instance_id)

func desc_teleport_in_direction() -> String:
	return "entity|Teleport the entity [dist:ComplexScalarInput:int:default=2] spaces in this direction [compl_dir:DirectionInput:1]"
func cmd_teleport_in_direction(slots: Dictionary, chosen_slot: int, compl_dir: Dictionary, dist: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to teleport in direction: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	var direction: int = resolve_complex_direction(compl_dir, slots)
	if direction == -1:
		return
	var dist_val: = int(resolve_complex_scalar(dist, slots))
	var from_pos: Vector2i = slots[chosen_slot].get_moving_position()
	slots[chosen_slot].start_teleport_to(from_pos + Utility.facing_vector_i(direction) * dist_val, -1, -2)

func desc_if_entity_can_teleport_in_direction() -> String:
	return "entity|If the entity can teleport [dist:ComplexScalarInput:int:default=2] spaces in this direction [compl_dir:DirectionInput:1]"
func cmd_if_entity_can_teleport_in_direction(slots: Dictionary, chosen_slot: int, compl_dir: Dictionary, dist: Dictionary) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity can teleport in direction: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	var direction: int = resolve_complex_direction(compl_dir, slots)
	if direction == -1:
		return false
	var dist_val: = int(resolve_complex_scalar(dist, slots))
	var from_pos: Vector2i = slots[chosen_slot].get_moving_position()
	return slots[chosen_slot].can_i_teleport_to(from_pos + Utility.facing_vector_i(direction) * dist_val, -1, -2)

func desc_if_entity_gets_teleported_in_direction() -> String:
	return "entity|If the entity successfully gets teleported [dist:ComplexScalarInput:int:default=2] spaces\n" \
	       + "in this direction [compl_dir:DirectionInput:1]"
func cmd_if_entity_gets_teleported_in_direction(slots: Dictionary, chosen_slot: int, compl_dir: Dictionary, dist: Dictionary) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to teleport in direction: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	var direction: int = resolve_complex_direction(compl_dir, slots)
	if direction == -1:
		return false
	var dist_val: = int(resolve_complex_scalar(dist, slots))
	var from_pos: Vector2i = slots[chosen_slot].get_moving_position()
	return slots[chosen_slot].start_teleport_to(from_pos, from_pos + Utility.facing_vector_i(direction) * dist_val, -1, -2)

func desc_teleport_entity_to() -> String:
	return "entity|Teleport the entity to [to_position_slot:SlotInput:pos,entity]"
func cmd_teleport_entity_to(slots: Dictionary, chosen_slot: int, to_position_slot: int) -> void:
	_teleport_entity_to(slots, chosen_slot, to_position_slot, false)

func _teleport_entity_to(slots: Dictionary, chosen_slot: int, to_position_slot: int, with_from_pos: bool, manual_from_pos: Vector2i = Vector2i.ZERO, rotate_to_facing: int = -2) -> bool:
	if not Commands.slot_has_position(to_position_slot) or not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slots to teleport entity to: %s and %s" % [chosen_slot, to_position_slot])
		return false
	if not slots[chosen_slot] or not _slot_has_single_tile_position(slots, to_position_slot):
		return false
	var from_pos: Vector2i = manual_from_pos
	if not with_from_pos:
		from_pos = slots[chosen_slot].get_moving_position()
	return slots[chosen_slot].start_teleport_to(from_pos, _single_tile_position_from_slot(slots, to_position_slot), -1, rotate_to_facing)

func desc_if_entity_can_teleport_to() -> String:
	return "entity|If the entity can teleport to [to_position_slot:SlotInput:pos,entity]"
func cmd_if_entity_can_teleport_to(slots: Dictionary, chosen_slot: int, to_position_slot: int) -> bool:
	if not Commands.slot_has_position(to_position_slot) or not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slots to check if entity can teleport to: %s and %s" % [chosen_slot, to_position_slot])
		return false
	if not slots[chosen_slot] or not _slot_has_single_tile_position(slots, to_position_slot):
		return false
	var from_pos: Vector2i = slots[chosen_slot].get_moving_position()
	return slots[chosen_slot].can_i_teleport_to(from_pos, _single_tile_position_from_slot(slots, to_position_slot), -1, -2)

func desc_if_entity_can_teleport_to_from() -> String:
	return "entity|If the entity can teleport to [to_position_slot:SlotInput:pos,entity] from [from_pos_slot:SlotInput:pos,entity]\n" \
			+ "(This version is for LARGE entities, small entities have no need to specify the from position)"
func cmd_if_entity_can_teleport_to_from(slots: Dictionary, chosen_slot: int, to_pos_slot: int, from_pos_slot: int) -> bool:
	if not Commands.slot_has_position(to_pos_slot) or not Commands.slot_has_position(from_pos_slot) or not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slots to check if entity can teleport to from: %s and %s and %s" % [chosen_slot, to_pos_slot, from_pos_slot])
		return false
	if not slots[chosen_slot] or not _slot_has_single_tile_position(slots, to_pos_slot) or not _slot_has_single_tile_position(slots, from_pos_slot):
		return false
	var from_pos: Vector2i = _single_tile_position_from_slot(slots, from_pos_slot)
	var to_pos: Vector2i = _single_tile_position_from_slot(slots, to_pos_slot)
	return slots[chosen_slot].can_i_teleport_to(from_pos, to_pos, -1, -2)

func desc_if_entity_can_teleport_to_from_rotating() -> String:
	return "entity|If the entity can teleport to [to_position_slot:SlotInput:pos,entity] from [from_pos_slot:SlotInput:pos,entity]\n" \
			+ "while rotating to face this direction [compl_dir:DirectionInput:1]"
func cmd_if_entity_can_teleport_to_from_rotating(slots: Dictionary, chosen_slot: int, to_pos_slot: int, from_pos_slot: int, compl_dir: Dictionary) -> bool:
	if not Commands.slot_has_position(to_pos_slot) or not Commands.slot_has_position(from_pos_slot) or not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slots to check if entity can teleport to from: %s and %s and %s" % [chosen_slot, to_pos_slot, from_pos_slot])
		return false
	if not slots[chosen_slot] or not _slot_has_single_tile_position(slots, to_pos_slot) or not _slot_has_single_tile_position(slots, from_pos_slot):
		return false
	var direction: int = resolve_complex_direction(compl_dir, slots)
	if direction == -1:
		direction = -2
	var from_pos: Vector2i = _single_tile_position_from_slot(slots, from_pos_slot)
	var to_pos: Vector2i = _single_tile_position_from_slot(slots, to_pos_slot)
	return slots[chosen_slot].can_i_teleport_to(from_pos, to_pos, -1, direction)


func desc_if_entity_gets_teleported_to() -> String:
	return "entity|If the entity successfully gets teleported to [to_position_slot:SlotInput:pos,entity]"
func cmd_if_entity_gets_teleported_to(slots: Dictionary, chosen_slot: int, to_position_slot: int) -> bool:
	return _teleport_entity_to(slots, chosen_slot, to_position_slot, false)

func desc_if_entity_gets_teleported_to_from() -> String:
	return "entity|If the entity successfully gets teleported to [to_position_slot:SlotInput:pos,entity] from [from_pos_slot:SlotInput:pos,entity]\n" \
			+ "(This version is for LARGE entities, small entities have no need to specify the from position)"
func cmd_if_entity_gets_teleported_to_from(slots: Dictionary, chosen_slot: int, to_pos_slot: int, from_pos_slot: int) -> bool:
	if not Commands.slot_has_position(from_pos_slot):
		push_error("Invalid slot or empty slot to teleport entity to from: %s and %s" % [chosen_slot, from_pos_slot])
		return false
	if not _slot_has_single_tile_position(slots, from_pos_slot):
		return false
	var from_pos: Vector2i = _single_tile_position_from_slot(slots, from_pos_slot)
	return _teleport_entity_to(slots, chosen_slot, to_pos_slot, true, from_pos)

func desc_if_entity_gets_teleported_to_from_rotating() -> String:
	return "entity|If the entity successfully gets teleported to [to_position_slot:SlotInput:pos,entity] from [from_pos_slot:SlotInput:pos,entity]\n" \
			+ "while rotating to face this direction [compl_dir:DirectionInput:1]"
func cmd_if_entity_gets_teleported_to_from_rotating(slots: Dictionary, chosen_slot: int, to_pos_slot: int, from_pos_slot: int, compl_dir: Dictionary) -> bool:
	if not Commands.slot_has_position(from_pos_slot) or not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to teleport entity to from: %s and %s" % [chosen_slot, from_pos_slot])
		return false
	if not _slot_has_single_tile_position(slots, from_pos_slot):
		return false
	var direction: int = resolve_complex_direction(compl_dir, slots)
	if direction == -1:
		direction = -2
	var from_pos: Vector2i = _single_tile_position_from_slot(slots, from_pos_slot)
	return _teleport_entity_to(slots, chosen_slot, to_pos_slot, true, from_pos, direction)


func desc_if_entity_is_bonded() -> String:
	return "entity|If the entity is currently bonded to other entities"
func cmd_if_entity_is_bonded(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity is bonded: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	return slots[chosen_slot].bond_group.size() > 0

func desc_if_entity_is_bonded_with() -> String:
	return "entity|If the entity is currently bonded to [check_entity_slot:SlotInput:entity]"
func cmd_if_entity_is_bonded_with(slots: Dictionary, chosen_slot: int, check_entity_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(check_entity_slot):
		push_error("Invalid slots to check if entity is bonded with: %s and %s" % [chosen_slot, check_entity_slot])
		return false
	if not slots[chosen_slot] or not slots[check_entity_slot] or not slots[chosen_slot].bond_group:
		return false
	return slots[chosen_slot].bond_group.has(slots[check_entity_slot].instance_id)

func desc_bond_entity_with() -> String:
	return "entity|Bond the entity with this entity [bond_to_entity_slot:SlotInput:entity]"
func cmd_bond_entity_with(slots: Dictionary, chosen_slot: int, bond_to_entity_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(bond_to_entity_slot):
		push_error("Invalid slots to bond entity with: %s and %s" % [chosen_slot, bond_to_entity_slot])
		return
	if not slots[chosen_slot] or not slots[bond_to_entity_slot]:
		return
	EntityManager.merge_entity_bond_groups(slots[chosen_slot], slots[bond_to_entity_slot])

func desc_unbond_entity() -> String:
	return "entity|Unbond [whole_group:BoolChoice:true,all entities bonded to the entity,the entity itself only] from all other entities"
func cmd_unbond_entity(slots: Dictionary, chosen_slot: int, whole_group: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to unbond entity: %s" % chosen_slot)
		return
	if slots[chosen_slot]:
		if whole_group:
			EntityManager.disolve_entity_bond_group(slots[chosen_slot])
		else:
			EntityManager.unbond_entity(slots[chosen_slot], true)

func desc_break_bond_group_into_connected_groups() -> String:
	return "entity|Split the entity's bond group into connected groups of adjacent entities [with_diagonal:BoolChoice:false,including,ignoring] diagonal connections"
func cmd_break_bond_group_into_connected_groups(slots: Dictionary, chosen_slot: int, with_diagonal: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to break bond group into connected groups: %s" % chosen_slot)
		return
	if not slots[chosen_slot] or not slots[chosen_slot].bond_group:
		return
	EntityManager.break_bond_group_into_connected_groups(slots[chosen_slot], with_diagonal)

func desc_break_all_bond_groups_into_connected() -> String:
	return "none|Split all bonded groups of entities into connected groups of adjacent entities [with_diagonal:BoolChoice:false,including,ignoring] diagonal connections"
func cmd_break_all_bond_groups_into_connected(_slots: Dictionary, _slot: int, with_diagonal: bool) -> void:
	EntityManager.break_all_bond_groups_into_connected(with_diagonal)

func desc_select_positions_of_bonded_entities() -> String:
	return "pos|<= Select the positions of all entities bonded to [entity_slot:SlotInput:entity]"
func cmd_select_positions_of_bonded_entities(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	if not Commands.slot_is_entity(entity_slot):
		push_error("Invalid slot to select positions of bonded entities: %s" % entity_slot)
		return
	slots[chosen_slot] = []
	if not slots[entity_slot] or not slots[entity_slot].bond_group:
		return
	for instance_id in slots[entity_slot].bond_group:
		var entity: BaseEntity = EntityManager.get_instance(instance_id)
		if entity:
			for new_pos in EntityManager.get_all_positions_of_entity(entity):
				if not new_pos in slots[chosen_slot]:
					slots[chosen_slot].append(new_pos)

func desc_select_math() -> String:
	return "number|<= Select the numerical result of [a:ComplexScalarInput] [operator:BinaryMathOperatorInput] [b:ComplexScalarInput]"
func cmd_select_math(slots: Dictionary, chosen_slot: int, a: Dictionary, operator: String, b: Dictionary) -> void:
	var a_val: float = resolve_complex_scalar(a, slots)
	var b_val: float = resolve_complex_scalar(b, slots)
	if operator == "+" or operator == "-":
		set_value_slot_as_number(slots, chosen_slot, a_val + (b_val * (1 if operator == "+" else -1)))
	elif operator == "*":
		set_value_slot_as_number(slots, chosen_slot, a_val * b_val)
	elif operator == "/":
		if Commands.slot_is_int(chosen_slot):
			set_value_slot_as_number(slots, chosen_slot, floori(a_val / b_val))
		else:
			set_value_slot_as_number(slots, chosen_slot, a_val / b_val)
	elif operator == "%":
		set_value_slot_as_number(slots, chosen_slot, fposmod(a_val, b_val))
	elif operator == "^":
		set_value_slot_as_number(slots, chosen_slot, pow(a_val, b_val))

func desc_select_random_number() -> String:
	return "number|<= Select a random number between [min_scalar:ComplexScalarInput] and [max_scalar:ComplexScalarInput] inclusive"
func cmd_select_random_number(slots: Dictionary, chosen_slot: int, min_scalar: Dictionary, max_scalar: Dictionary) -> void:
	var min_val: float = resolve_complex_scalar(min_scalar, slots)
	var max_val: float = resolve_complex_scalar(max_scalar, slots)
	set_value_slot_as_number(slots, chosen_slot, randf_range(min_val, max_val))

func desc_select_number_clamped() -> String:
	return "number|<= Select the number [value:ComplexScalarInput] clamped between [min_scalar:ComplexScalarInput] and [max_scalar:ComplexScalarInput]"
func cmd_select_number_clamped(slots: Dictionary, chosen_slot: int, value: Dictionary, min_scalar: Dictionary, max_scalar: Dictionary) -> void:
	var value_val: float = resolve_complex_scalar(value, slots)
	var min_val: float = resolve_complex_scalar(min_scalar, slots)
	var max_val: float = resolve_complex_scalar(max_scalar, slots)
	set_value_slot_as_number(slots, chosen_slot, clampf(value_val, min_val, max_val))

func desc_select_random_tile() -> String:
	return "pos|<= Select a random tile position in [from_pos_slot:SlotInput:pos]"
func cmd_select_random_tile(slots: Dictionary, chosen_slot: int, from_pos_slot: int) -> void:
	if not Commands.slot_has_position(from_pos_slot) or not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slots to select random tile position: %s and %s" % [chosen_slot, from_pos_slot])
		return
	var from_positions: Array = slots[from_pos_slot]
	if not from_positions:
		from_positions = MapManager.get_used_positions_in_all_layers()
	slots[chosen_slot] = [Utility.random_list_element(from_positions)]

func desc_select_random_entity() -> String:
	return "entity|<= Select a random active entity at [from_pos_slot:SlotInput:pos] ignoring [ignore_entity_slot:SlotInput:entity]"
func cmd_select_random_entity(slots: Dictionary, chosen_slot: int, from_pos_slot: int, ignore_entity_slot: int) -> void:
	if not Commands.slot_is_positions(from_pos_slot) or not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(ignore_entity_slot):
		push_error("Invalid slots to select random entity: %s, %s and %s" % [chosen_slot, from_pos_slot, ignore_entity_slot])
		return
	var from_positions: Array = slots[from_pos_slot]
	var all_entities: Array[BaseEntity] = []
	if not from_positions:
		all_entities = EntityManager.get_all_active_entities()
	else:
		all_entities = EntityManager.get_entities_at_multiple(from_positions)
	all_entities.erase(slots[ignore_entity_slot])
	if all_entities.size() == 0:
		slots[chosen_slot] = null
	else:
		slots[chosen_slot] = Utility.random_list_element(all_entities)

func desc_select_random_filtered_entity() -> String:
	return "entity|<= Select a random active entity at [from_pos_slot:SlotInput:pos] ignoring [ignore_entity_slot:SlotInput:entity]\n" \
			+ "with a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property"
func cmd_select_random_filtered_entity(slots: Dictionary, chosen_slot: int, from_pos_slot: int, ignore_entity_slot: int, truthy: bool, prop_name: String) -> void:
	if not Commands.slot_is_positions(from_pos_slot) or not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(ignore_entity_slot):
		push_error("Invalid slots to select random entity: %s, %s and %s" % [chosen_slot, from_pos_slot, ignore_entity_slot])
		return
	var from_positions: Array = slots[from_pos_slot]
	var all_entities: Array[BaseEntity] = []
	if not from_positions:
		all_entities = EntityManager.get_all_active_entities()
	else:
		all_entities = EntityManager.get_entities_at_multiple(from_positions)
	all_entities.erase(slots[ignore_entity_slot])
	all_entities = EntityManager.filter_entities_by_property(prop_name, all_entities, [], not truthy)
	if all_entities.size() == 0:
		slots[chosen_slot] = null
	else:
		slots[chosen_slot] = Utility.random_list_element(all_entities)

func desc_select_random_entity_name() -> String:
	return "string|<= Select the name of a random type of entity"
func cmd_select_random_entity_name(slots: Dictionary, chosen_slot: int) -> void:
	slots[chosen_slot] = Utility.random_list_element(EntityManager.get_all_entity_names())

func desc_select_random_tile_name() -> String:
	return "string|<= Select the name of a random type of tile"
func cmd_select_random_tile_name(slots: Dictionary, chosen_slot: int) -> void:
	slots[chosen_slot] = Utility.random_list_element(MapManager.get_all_tile_names())

func _select_random_string_s_e_filtered(slots: Dictionary, all_strings: Array[String], chosen_slot: int, invert: bool, start_end: String, filter: Dictionary) -> void:
	var filtered_strings: Array[String] = _filter_strings_s_e_contains(slots, all_strings, invert, start_end, filter)
	if filtered_strings.size() == 0:
		slots[chosen_slot] = ""
	else:
		slots[chosen_slot] = Utility.random_list_element(filtered_strings)

func _filter_strings_s_e_contains(slots: Dictionary, all_strings: Array[String], invert: bool, start_end: String, filter: Dictionary) -> Array[String]:
	var filtered_strings: Array[String] = []
	var filter_text: String = get_complex_string_value(filter, slots)
	for the_string in all_strings:
		if Utility.check_string_start_end_contains(the_string, start_end, filter_text) != invert:
			filtered_strings.append(the_string)
	return filtered_strings

func desc_select_random_entity_name_containing() -> String:
	return "string|<= Select a random entity name that [invert:InertInput:does,doesn't] [start_end:StartEndContainInput] [filter:ComplexStringInput]"
func cmd_select_random_entity_name_containing(slots: Dictionary, chosen_slot: int, invert: bool, start_end: String, filter: Dictionary) -> void:
	_select_random_string_s_e_filtered(slots, EntityManager.get_all_entity_names(), chosen_slot, invert, start_end, filter)

func desc_select_random_tile_name_containing() -> String:
	return "string|<= Select a random tile name that [invert:InertInput:does,doesn't] [start_end:StartEndContainInput] [filter:ComplexStringInput]"
func cmd_select_random_tile_name_containing(slots: Dictionary, chosen_slot: int, invert: bool, start_end: String, filter: Dictionary) -> void:
	_select_random_string_s_e_filtered(slots, MapManager.get_all_tile_names(), chosen_slot, invert, start_end, filter)


func _filter_items_by_default_property(item_definitions: Dictionary, invert: bool, prop_name: String, include_conditional: bool) -> Array[int]:
	var filtered_item_ids: Array[int] = []
	for item_id in item_definitions.keys():
		var item_default_props: Dictionary = item_definitions[item_id].get("properties", {})
		var or_false_val: Variant = item_default_props.get(prop_name, false)
		var is_truthy: bool = false
		if typeof(or_false_val) in [TYPE_DICTIONARY, TYPE_ARRAY]:
			is_truthy = include_conditional
		elif or_false_val:
			is_truthy = true

		if is_truthy != invert:
			filtered_item_ids.append(item_id)
	return filtered_item_ids

func desc_select_random_entity_name_prop_filtered() -> String:
	return "string|<= Select the name of a random entity which has a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] default property" \
			+ "[include_conditional:BoolChoice:true,include,exclude] if the default value is a conditional"
func cmd_select_random_entity_name_prop_filtered(slots: Dictionary, chosen_slot: int, truthy: bool, prop_name: String, include_conditional: bool) -> void:
	var filtered_entity_ids: Array[int] = _filter_items_by_default_property(EntityManager.entity_defs, truthy, prop_name, include_conditional)
	slots[chosen_slot] = EntityManager.get_entity_name(Utility.random_list_element(filtered_entity_ids))

func desc_select_random_tile_name_prop_filtered() -> String:
	return "string|<= Select the name of a random tile which has a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] default property" \
			+ "[include_conditional:BoolChoice:true,include,exclude] if the default value is a conditional"
func cmd_select_random_tile_name_prop_filtered(slots: Dictionary, chosen_slot: int, truthy: bool, prop_name: String, include_conditional: bool) -> void:
	var filtered_tile_ids: Array[int] = _filter_items_by_default_property(MapManager.tile_defs, truthy, prop_name, include_conditional)
	slots[chosen_slot] = MapManager.get_tile_name(Utility.random_list_element(filtered_tile_ids))


func desc_is_entity_tailing() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "If the entity is currently [tailing:BoolChoice:true,tailing another entity,being tailed by another entity]",
		"feature_tags": ["tailing"],
	}
func cmd_is_entity_tailing(slots: Dictionary, chosen_slot: int, tailing: bool) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity is tailing: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	if tailing:
		return slots[chosen_slot].tailing != null
	else:
		return EntityManager.get_direct_tailing_entities(slots[chosen_slot]).size() > 0

func desc_select_tailing_entity() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "Select an entity [tail_parent:BoolChoice:true,being tailed by,that is tailing] [ref_entity_slot:SlotInput:entity]",
		"feature_tags": ["tailing"],
	}
func cmd_select_tailing_entity(slots: Dictionary, chosen_slot: int, tail_parent: bool, ref_entity_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to select tailing entity: %s" % chosen_slot)
		return
	if not slots[ref_entity_slot]:
		return
	if tail_parent:
		if not slots[ref_entity_slot].tailing or not EntityManager.has_instance(slots[ref_entity_slot].tailing.instance_id):
			slots[chosen_slot] = null
			return
		slots[chosen_slot] = EntityManager.get_instance(slots[ref_entity_slot].tailing.instance_id)
	else:
		var tailing_entities: Array[BaseEntity] = EntityManager.get_direct_tailing_entities(slots[ref_entity_slot])
		if tailing_entities.size() == 0:
			slots[chosen_slot] = null
			return
		slots[chosen_slot] = tailing_entities[0]

func desc_select_tailing_positions() -> Dictionary:
	return {
		"slot_type_hint": "pos",
		"template_text": "Select the positions of all entities tailing [tail_dir:TailDirInput:behind,ahead of] [ref_entity_slot:SlotInput:entity]\n" \
			+ "([include_self:BoolChoice:true,including,excluding] itself)",
		"feature_tags": ["tailing"],
	}
func cmd_select_tailing_positions(slots: Dictionary, chosen_slot: int, tail_dir: String, ref_entity_slot: int, include_self: bool) -> void:
	if not Commands.slot_is_entity(ref_entity_slot) or not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slots to select tailing positions: %s and %s" % [chosen_slot, ref_entity_slot])
		return
	if not slots[ref_entity_slot]:
		slots[chosen_slot] = []
		return
	var with_behind: bool = tail_dir != "ahead of"
	var with_ahead: bool = tail_dir != "behind"
	var exclude_list: Array[BaseEntity] = []
	if not include_self:
		exclude_list.append(slots[ref_entity_slot])
	var tailing_entities: = EntityManager.get_entity_tailing_chain(slots[ref_entity_slot], with_behind, with_ahead, exclude_list)
	slots[chosen_slot] = []
	for e in tailing_entities:
		slots[chosen_slot].append(e.get_moving_position())

func desc_start_tailing() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "The entity starts tailing behind this entity [head_entity:SlotInput:entity]",
		"feature_tags": ["tailing"],
	}
func cmd_start_tailing(slots: Dictionary, chosen_slot: int, head_entity: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(head_entity):
		push_error("Invalid slots to start tailing: %s and %s" % [chosen_slot, head_entity])
		return
	if not slots[chosen_slot] or not slots[head_entity] or slots[chosen_slot] == slots[head_entity]:
		return
	if slots[chosen_slot].tailing:
		slots[chosen_slot].untail()
	slots[chosen_slot].set_tailing(slots[head_entity])

func desc_stop_tailling() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "The entity stops tailing the entity ahead of it in the tailing chain",
		"feature_tags": ["tailing"],
	}
func cmd_stop_tailling(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to stop tailing: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	slots[chosen_slot].untail()

func desc_remove_tail() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "Cut off entities tailing behind the entity",
		"feature_tags": ["tailing"],
	}
func cmd_remove_tail(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to remove tail: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	var tailing_entities: Array[BaseEntity] = EntityManager.get_direct_tailing_entities(slots[chosen_slot])
	for e in tailing_entities:
		e.untail()

func select_tail_size() -> Dictionary:
	return {
		"slot_type_hint": "number",
		"template_text": "Select the total number of entities in the tailing chain of [entity_slot:SlotInput:entity]",
		"feature_tags": ["tailing"],
	}
func cmd_select_tail_size(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	if not Commands.slot_is_value(chosen_slot) or not Commands.slot_is_entity(entity_slot):
		push_error("Invalid slot or empty slot to select tail size: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		set_value_slot_as_number(slots, chosen_slot, 0)
		return
	var all_tailing_entities: = EntityManager.get_entity_tailing_chain(slots[entity_slot], true, true)
	set_value_slot_as_number(slots, chosen_slot, all_tailing_entities.size())

func desc_convert_tailing_chain_to_bond_group() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "Convert the tailing chain of [entity_slot:SlotInput:entity] to a bond group",
		"feature_tags": ["tailing", "bond groups"],
	}
func cmd_convert_tailing_chain_to_bond_group(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(entity_slot):
		push_error("Invalid slots to convert tailing chain to bond group: %s and %s" % [chosen_slot, entity_slot])
		return
	if not slots[entity_slot]:
		return
	var all_tailing_entities: = EntityManager.get_entity_tailing_chain(slots[entity_slot], true, true)
	all_tailing_entities = EntityManager.get_sorted_tailing_chain(all_tailing_entities)
	for e in all_tailing_entities:
		e.untail()
		if e.bond_group:
			EntityManager.unbond_entity(e, false)
	EntityManager.create_bond_group(all_tailing_entities)

func desc_convert_bond_group_to_tailing_chain() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "Convert the bond group of [entity_slot:SlotInput:entity] to a tailing chain",
		"feature_tags": ["tailing", "bond groups"],
	}
func cmd_convert_bond_group_to_tailing_chain(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(entity_slot):
		push_error("Invalid slots to convert bond group to tailing chain: %s and %s" % [chosen_slot, entity_slot])
		return
	if not slots[entity_slot]:
		return
	var bond_group: Array = slots[entity_slot].bond_group
	if bond_group.size() < 2:
		return
	EntityManager.convert_sorted_group_to_tailing_chain(bond_group)


func desc_play_named_sfx() -> String:
	return "none|Play the [sfx_name:SFXNameInput] sound effect [do_restart:BoolChoice:true,restarting if already playing,if it isn't already playing]"
func cmd_play_named_sfx(slots: Dictionary, _slot: int, sfx_name: Dictionary, do_restart: bool) -> void:
	if not sfx_name:
		return
	var sfx_name_str: String = get_complex_string_value(sfx_name, slots)
	var sfx_options: = SfxPlayer.playback_options(sfx_name_str, "restart" if do_restart else "one")
	var op_props: Array[String] = ['sfx_name', 'relative_volume', 'relative_pitch', 'self_polyphony']
	var op_vals: Array = []
	for prop in op_props:
		op_vals.append(sfx_options.get(prop))
	SfxPlayer.play_sfx_options(sfx_options)

func desc_keep_named_sfx_playing() -> String:
	return "none|Keep the [sfx_name:SFXNameInput] sound effect playing (start if it isn't playing)"
func cmd_keep_named_sfx_playing(slots: Dictionary, _slot: int, sfx_name: Dictionary) -> void:
	if not sfx_name:
		return
	var sfx_name_str: String = get_complex_string_value(sfx_name, slots)
	var sfx_options: = SfxPlayer.playback_options(sfx_name_str, "keep_playing")
	SfxPlayer.play_sfx_options(sfx_options)

func desc_if_entity_is_large() -> String:
	return "entity|If the entity is currently LARGE (occupying more than on grid space)"
func cmd_if_entity_is_large(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity is large: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	return slots[chosen_slot].is_large()

func desc_select_position_of_entity() -> String:
	return "pos|<= Select the main position currently occupied by this entity [entity_slot:SlotInput:entity]"
func cmd_select_position_of_entity(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	if not Commands.slot_is_entity(entity_slot) or not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slots to select position of entity: %s and %s" % [chosen_slot, entity_slot])
		return
	if not slots[entity_slot]:
		slots[chosen_slot] = []
		return
	slots[chosen_slot] = [slots[entity_slot].get_moving_position()]

func desc_select_all_positions_of_entity() -> String:
	return "pos|<= Select all positions currently occupied by this entity [entity_slot:SlotInput:entity]"
func cmd_select_all_positions_of_entity(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	if not Commands.slot_is_entity(entity_slot) or not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slots to select positions of entity: %s and %s" % [chosen_slot, entity_slot])
		return
	if not slots[entity_slot]:
		slots[chosen_slot] = []
		return
	slots[chosen_slot] = EntityManager.get_all_positions_of_entity(slots[entity_slot])

func desc_select_position_entity_moving_from() -> String:
	return "pos|<= Select the position the entity is moving away from [entity_slot:SlotInput:entity]"
func cmd_select_position_entity_moving_from(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	if not Commands.slot_is_entity(entity_slot) or not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slots to select position entity moving from: %s and %s" % [chosen_slot, entity_slot])
		return
	if not slots[entity_slot]:
		slots[chosen_slot] = []
		return
	slots[chosen_slot] = [slots[entity_slot].get_stationary_position()]

func desc_select_all_positions_entity_moving_from() -> String:
	return "pos|<= Select all positions the entity is moving away from [entity_slot:SlotInput:entity]"
func cmd_select_all_positions_entity_moving_from(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	if not Commands.slot_is_entity(entity_slot) or not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slots to select all positions entity moving from: %s and %s" % [chosen_slot, entity_slot])
		return
	if not slots[entity_slot]:
		slots[chosen_slot] = []
		return
	if not slots[entity_slot].is_large():
		slots[chosen_slot] = [slots[entity_slot].get_stationary_position()]
	else:
		slots[chosen_slot] = slots[entity_slot].get_positions_at(slots[entity_slot].get_stationary_position())

func desc_filter_select_furthest_positions() -> String:
	return "pos|<= Filter the positions in [from_pos_slot:SlotInput:pos] to those that are the furthest\n" \
			+ "in the direction [compl_dir:DirectionInput:1]"
func cmd_filter_select_furthest_positions(slots: Dictionary, chosen_slot: int, from_pos_slot: int, compl_dir: Dictionary) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_positions(from_pos_slot):
		push_error("Invalid slots to filter select furthest positions: %s and %s" % [chosen_slot, from_pos_slot])
		return
	var dir_val: int = resolve_complex_direction(compl_dir, slots)
	if not slots[from_pos_slot]:
		var map_bounds: = MapManager.get_map_size()
		var border_rect: = Utility.get_rect2i_border_in_facing_direction(map_bounds, dir_val)
		slots[chosen_slot] = Utility.filter_positions_in_rect(slots[from_pos_slot], border_rect)
		return
	else:
		slots[chosen_slot] = Utility.filter_positions_furthest_in_direction(slots[from_pos_slot], dir_val)

func desc_set_large_entity_size() -> String:
	return "entity|Set the LARGE size of the entity to [size:Vector2iInput]"
func cmd_set_large_entity_size(slots: Dictionary, chosen_slot: int, size: Vector2i) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to set large entity size: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	slots[chosen_slot].update_size(size)

func desc_set_large_entity_width() -> String:
	return "entity|Set the LARGE width to [width:number]"
func cmd_set_large_entity_width(slots: Dictionary, chosen_slot: int, width: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to set large entity width and height: %s" % chosen_slot)
		return
	if not slots[chosen_slot] or not slots[chosen_slot] is LargeEntity:
		return
	var height: int = slots[chosen_slot].entity_size.y
	slots[chosen_slot].update_size(Vector2i(width, height))

func desc_select_large_entity_width() -> String:
	return "number|<= Select the LARGE width of [entity_slot:SlotInput:entity]"
func cmd_select_large_entity_width(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	_select_large_entity_size_axis(slots, chosen_slot, entity_slot, 0)

func desc_select_large_entity_height() -> String:
	return "number|<= Select the LARGE height of [entity_slot:SlotInput:entity]"
func cmd_select_large_entity_height(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	_select_large_entity_size_axis(slots, chosen_slot, entity_slot, 1)

func desc_select_large_entity_size_in_direction() -> String:
	return "number|<= Select the LARGE size (width or height) of [entity_slot:SlotInput:entity] in the direction [compl_dir:DirectionInput:1]"
func cmd_select_large_entity_size_in_direction(slots: Dictionary, chosen_slot: int, entity_slot: int, compl_dir: Dictionary) -> void:
	var facing_dir: = resolve_complex_direction(compl_dir, slots)
	_select_large_entity_size_axis(slots, chosen_slot, entity_slot, Utility.facing_to_axis_index(facing_dir))

func _select_large_entity_size_axis(slots: Dictionary, select_into_slot: int, entity_slot: int, axis: int) -> void:
	if not Commands.slot_is_entity(entity_slot) or not Commands.slot_is_scalar(select_into_slot):
		push_error("Invalid slots to select large entity width: %s and %s" % [select_into_slot, entity_slot])
		return
	if not slots[entity_slot]:
		set_value_slot_as_number(slots, select_into_slot, 0)
		return
	if not slots[entity_slot].is_large():
		set_value_slot_as_number(slots, select_into_slot, 1)
		return
	var oriented_size: Vector2i = slots[entity_slot].get_oriented_size()
	set_value_slot_as_number(slots, select_into_slot, oriented_size[axis])

func desc_stretch_a_large_entity_to_position() -> String:
	return "entity|Stretch the entity's LARGE size so that it [inclusive:BoolChoice:true,reaches,reaches up to] [target_pos_slot:SlotInput:pos,entity]" \
			+ " (don't turn the entity)"
func cmd_stretch_a_large_entity_to_position(slots: Dictionary, chosen_slot: int, inclusive: bool, target_pos_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_has_position(target_pos_slot):
		push_error("Invalid slots to stretch a large entity to position: %s, %s and %s" % [chosen_slot, target_pos_slot])
		return
	var the_entity: = slots[chosen_slot] as LargeEntity
	if not the_entity:
		prints("no entity in slot or it's not a large entity")
		return
	if not _slot_has_single_tile_position(slots, target_pos_slot):
		prints("no single tile position in slot", target_pos_slot)
		return
	var target_pos: Vector2i = get_single_position_from_slot(target_pos_slot, slots)
	prints("target pos:", target_pos, "large entity positions:", EntityManager.get_all_positions_of_entity(the_entity))
	#var original_target_pos: = target_pos
	var entity_pos: Vector2i = the_entity.get_moving_position()
	var pos_rect: = the_entity.get_pos_rect_at(entity_pos)
	prints("pos rect:", pos_rect)
	if not pos_rect.has_point(target_pos):
		var target_rect: = Rect2i(target_pos, Vector2i.ONE)
		var combined: = pos_rect.merge(target_rect)
		entity_pos = Utility.rect2i_opposite_inner_corner(combined, target_pos)
	
	# pull target inward if not inclusive
	var inclusive_size: Vector2i = Vector2i(entity_pos - target_pos).abs()
	if not inclusive and (inclusive_size.x > 1 or inclusive_size.y > 1):
		if inclusive_size.x > 1:
			target_pos.x += sign(entity_pos.x - target_pos.x)
		if inclusive_size.y > 1:
			target_pos.y += sign(entity_pos.y - target_pos.y)
	
	#prints("before stretching", the_entity.get_moving_position(), Vector2i(the_entity.entity_size), "inclusive:", inclusive, "orig target:", original_target_pos)
	#prints("attempting to stretch", the_entity.entity_name, the_entity.instance_id, "corners:", entity_pos, target_pos)
	the_entity.update_size_by_corners(entity_pos, target_pos, false)

func desc_shrink_entity_in_direction_by() -> String:
	return "entity|Shrink the entity's LARGE size from the direction [compl_dir:DirectionInput:1] by [amount:ComplexScalarInput:int]"
func cmd_shrink_entity_in_direction(slots: Dictionary, chosen_slot: int, compl_dir: Dictionary, amount: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to shrink entity in direction: %s" % chosen_slot)
		return
	var the_entity: = slots[chosen_slot] as LargeEntity
	if not the_entity:
		return
	the_entity.shrink_in_direction(resolve_complex_direction(compl_dir, slots), true, int(resolve_complex_scalar(amount, slots)))

func desc_grow_entity_in_direction_by() -> String:
	return "entity|Grow the entity's LARGE size in the direction [compl_dir:DirectionInput:1] by [amount:ComplexScalarInput:int]"
func cmd_grow_entity_in_direction(slots: Dictionary, chosen_slot: int, compl_dir: Dictionary, amount: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to grow entity in direction: %s" % chosen_slot)
		return
	var the_entity: = slots[chosen_slot] as LargeEntity
	if not the_entity:
		return
	the_entity.grow_in_direction(resolve_complex_direction(compl_dir, slots), true, int(resolve_complex_scalar(amount, slots)))


func desc_set_large_entity_size_in_direction() -> String:
	return "entity|Set the LARGE width/height in the direction [compl_dir:DirectionInput:1] to [new_size:ComplexScalarInput:int]"
func cmd_set_large_entity_size_in_direction(slots: Dictionary, chosen_slot: int, compl_dir: Dictionary, new_size: Dictionary) -> void:
	var dir_value: = resolve_complex_direction(compl_dir, slots)
	_set_entity_slot_size_in_dir(slots, chosen_slot, dir_value, int(resolve_complex_scalar(new_size, slots)))

func desc_set_large_entity_height_in_direction() -> String:
	return "entity|Set the LARGE height in the direction [compl_dir:DirectionInput:1] to [new_height:ComplexScalarInput:int]"
func cmd_set_large_entity_height_in_direction(slots: Dictionary, chosen_slot: int, compl_dir: Dictionary, new_height: Dictionary) -> void:
	var the_dir: = resolve_complex_direction(compl_dir, slots)
	if the_dir != 0 and the_dir != 2:
		return
	_set_entity_slot_size_in_dir(slots, chosen_slot, the_dir, int(resolve_complex_scalar(new_height, slots)))

func desc_set_large_entity_width_in_direction() -> String:
	return "entity|Set the LARGE width in the direction [compl_dir:DirectionInput:1] to [new_width:ComplexScalarInput:int]"
func cmd_set_large_entity_width_in_direction(slots: Dictionary, chosen_slot: int, compl_dir: Dictionary, new_width: Dictionary) -> void:
	var the_dir: = resolve_complex_direction(compl_dir, slots)
	if the_dir != 1 and the_dir != 3:
		return
	_set_entity_slot_size_in_dir(slots, chosen_slot, the_dir, int(resolve_complex_scalar(new_width, slots)))

func _set_entity_slot_size_in_dir(slots: Dictionary, chosen_slot: int, dir_value: int, new_size: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to set large entity height: %s" % chosen_slot)
		return
	var the_entity: = slots[chosen_slot] as LargeEntity
	if not the_entity:
		return
	the_entity.set_size_in_direction(dir_value, false, new_size)


func desc_set_large_entity_width_height() -> String:
	return "entity|Set the entity's LARGE width to [width:ComplexScalarInput:int] and height to [height:ComplexScalarInput:int]"
func cmd_set_large_entity_width_height(slots: Dictionary, chosen_slot: int, width: int, height: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to set large entity width and height: %s" % chosen_slot)
		return
	if not slots[chosen_slot] or not slots[chosen_slot] is LargeEntity:
		return
	slots[chosen_slot].update_size(Vector2i(width, height))

func desc_select_distance_between() -> String:
	return "number|<= Select the [distance_mode:DistanceModeInput] distance between the position of [pos1_slot:SlotInput:pos,entity] and [pos2_slot:SlotInput:pos,entity]"
func cmd_select_distance_between(slots: Dictionary, chosen_slot: int, pos1_slot: int, pos2_slot: int, distance_mode: String = "") -> void:
	if not Commands.slot_has_position(pos1_slot) or not Commands.slot_has_position(pos2_slot):
		push_error("Invalid slots to select distance between: %s and %s" % [pos1_slot, pos2_slot])
		return
	if not _slot_has_single_tile_position(slots, pos1_slot) or not _slot_has_single_tile_position(slots, pos2_slot):
		set_value_slot_as_number(slots, chosen_slot, 0)
		return
	var pos1: Vector2i = get_single_position_from_slot(pos1_slot, slots)
	var pos2: Vector2i = get_single_position_from_slot(pos2_slot, slots)
	var distance: float = Utility.get_distance_of_positions_by_mode(pos1, pos2, distance_mode)
	set_value_slot_as_number(slots, chosen_slot, distance)

func desc_if_positions_align_orthogonally() -> String:
	return "pos|If the single position in this slot aligns orthogonally (same row or column) with the single position in [ref_pos_slot:SlotInput:pos,entity]"
func cmd_if_positions_align_orthogonally(slots: Dictionary, chosen_slot: int, ref_pos_slot: int) -> bool:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_has_position(ref_pos_slot):
		push_error("Invalid slots to check if positions align orthogonally: %s, %s" % [chosen_slot, ref_pos_slot])
		return false
	if not _slot_has_single_tile_position(slots, chosen_slot) or not _slot_has_single_tile_position(slots, ref_pos_slot):
		return false
	var pos_a: Vector2i = _single_tile_position_from_slot(slots, chosen_slot)
	var pos_b: Vector2i = _single_tile_position_from_slot(slots, ref_pos_slot)
	return Utility.do_positions_align_orthogonally(pos_a, pos_b)

func desc_if_positions_align_diagonally() -> String:
	return "pos|If the single position in this slot aligns exactly diagonally with the single position in [ref_pos_slot:SlotInput:pos,entity]"
func cmd_if_positions_align_diagonally(slots: Dictionary, chosen_slot: int, ref_pos_slot: int) -> bool:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_has_position(ref_pos_slot):
		push_error("Invalid slots to check if positions align diagonally: %s, %s" % [chosen_slot, ref_pos_slot])
		return false
	if not _slot_has_single_tile_position(slots, chosen_slot) or not _slot_has_single_tile_position(slots, ref_pos_slot):
		return false
	var pos_a: Vector2i = _single_tile_position_from_slot(slots, chosen_slot)
	var pos_b: Vector2i = _single_tile_position_from_slot(slots, ref_pos_slot)
	return Utility.do_positions_align_diagonally(pos_a, pos_b)


func if_entity_has_controller() -> String:
	return "entity|If the entity has a controller"
func cmd_if_entity_has_controller(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity has controller: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	return slots[chosen_slot].controller != null

func desc_swap_entity_controllers() -> String:
	return "entity|Swap the entity's controller with [other_entity_slot:SlotInput:entity]"
func cmd_swap_entity_controllers(slots: Dictionary, chosen_slot: int, other_entity: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(other_entity):
		push_error("Invalid slots to swap entity controllers: %s and %s" % [chosen_slot, other_entity])
		return
	if not slots[chosen_slot] or not slots[other_entity]:
		return
	var controller1: Node = slots[chosen_slot].pop_controller()
	var controller2: Node = slots[other_entity].pop_controller()
	if controller2:
		slots[chosen_slot].replace_controller(controller2)
	if controller1:
		slots[other_entity].replace_controller(controller1)

func desc_copy_entity_controller() -> String:
	return "entity|Copy the entity's controller to [other_entity_slot:SlotInput:entity]"
func cmd_copy_entity_controller(slots: Dictionary, chosen_slot: int, other_entity: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(other_entity):
		push_error("Invalid slots to swap entity controllers: %s and %s" % [chosen_slot, other_entity])
		return
	if not slots[chosen_slot] or not slots[other_entity]:
		return

	if slots[chosen_slot].controller:
		var duplicate_controller: Node = EntityManager.get_controller_duplicate(slots[chosen_slot].controller)
		slots[other_entity].replace_controller(duplicate_controller)
	else:
		slots[other_entity].pop_controller()

func desc_reset_entity_controller() -> String:
	return "entity|Reset the entity's controller to the default of the entity type"
func cmd_reset_entity_controller(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to reset entity controller: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	EntityManager.reset_entity_controller(slots[chosen_slot])

func desc_remove_entity_controller() -> String:
	return "entity|Remove the entity's controller"
func cmd_remove_entity_controller(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to remove entity controller: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	slots[chosen_slot].pop_controller()


func desc_create_undo_point() -> String:
	return "none|Create a new undo point at the end of this game tick, enabling rewinding to the previous undo point"
func cmd_create_undo_point(_slots: Dictionary) -> void:
	EntityManager.request_create_undo()

func desc_mark_changed_since_last_undo() -> String:
	return "none|Mark the current state as changed since the last added undo point, enabling rewinding to it"
func cmd_mark_changed_since_last_undo(_slots: Dictionary) -> void:
	GameManager.cur_undo_is_current_state = false

func desc_undo() -> String:
	return "none|Load the next available undo point (after this event)"
func cmd_undo(_slots: Dictionary) -> void:
	GameManager.pop_and_load_undo_state.call_deferred()


func desc_select_save_file_value() -> String:
	return "number,string|<= Select the save file value [key_val:ComplexStringInput]"
func cmd_select_save_file_value(slots: Dictionary, chosen_slot: int, key_val: Dictionary) -> void:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to select save file value into: %s" % chosen_slot)
		return
	var key_str: String = resolve_complex_string(key_val, slots)
	var value: Variant = GameManager.get_game_save_data_or_dummy("::cmd::%s" % key_str, "")
	if typeof(value) in [TYPE_ARRAY, TYPE_DICTIONARY]:
		if Commands.slot_is_scalar(chosen_slot):
			set_value_slot_as_number(slots, chosen_slot, 0)
		else:
			slots[chosen_slot] = ""

	if Commands.slot_is_string(chosen_slot):
		slots[chosen_slot] = str(value)
	elif not Utility.is_variant_valid_scalar(value):
		set_value_slot_as_number(slots, chosen_slot, 0)
	else:
		set_value_slot_as_number(slots, chosen_slot, float(value))

func desc_if_save_file_value_is_set() -> String:
	return "none|If the save file value [key_val:ComplexStringInput] is set to [truthy_option:CustomStringEnum:anything,true or non-zero,false or zero]"
func cmd_if_save_file_value_is_set(slots: Dictionary, _slot: int, key_val: Dictionary, truthy_option: String) -> bool:
	var key_str: String = resolve_complex_string(key_val, slots)
	if truthy_option == "anything":
		return GameManager.has_game_save_data_or_dummy("::cmd::%s" % key_str)
	else:
		var check_truthy: bool = truthy_option.contains("true")
		var truthy_result: = Utility.property_value_bool(GameManager.get_game_save_data_or_dummy("::cmd::%s" % key_str, false), false)
		return truthy_result == check_truthy


func desc_set_save_file_value() -> String:
	return "none|Set the save file value [key_val:ComplexStringInput] to [val:MultiTypeInput]"
func cmd_set_save_file_value(slots: Dictionary, _slot: int, key_val: Dictionary, val: Dictionary) -> void:
	var key_str: String = resolve_complex_string(key_val, slots)
	var value: Variant = resolve_complex_multi_type_val(val, slots)
	GameManager.set_game_save_data_or_dummy("::cmd::%s" % key_str, value)

func desc_add_to_save_file_value() -> String:
	return "none|Add [to_add:ComplexScalarInput] to the save file value [key_val:ComplexStringInput]"
func cmd_add_to_save_file_value(slots: Dictionary, _slot: int, key_val: Dictionary, to_add: Dictionary) -> void:
	var key_str: String = resolve_complex_string(key_val, slots)
	var to_add_val: float = resolve_complex_scalar(to_add, slots)
	GameManager.add_game_save_data_or_dummy("::cmd::%s" % key_str, to_add_val)

func desc_set_save_file_value_on_level_completed() -> String:
	return "none|Set the save file value [key_val:ComplexStringInput] to [val:MultiTypeInput] once the current level is completed"
func cmd_set_save_file_value_on_level_completed(slots: Dictionary, _slot: int, key_val: Dictionary, val: Dictionary) -> void:
	var key_str: String = resolve_complex_string(key_val, slots)
	var value: Variant = resolve_complex_multi_type_val(val, slots)
	MapManager.set_save_persist_on_completion("::cmd::%s" % key_str, value)

func desc_add_to_save_file_value_on_level_completed() -> String:
	return "none|Add [to_add:ComplexScalarInput] to the save file value [key_val:ComplexStringInput] once the current level is completed"
func cmd_add_to_save_file_value_on_level_completed(slots: Dictionary, _slot: int, key_val: Dictionary, to_add: Dictionary) -> void:
	var key_str: String = resolve_complex_string(key_val, slots)
	var to_add_val: float = resolve_complex_scalar(to_add, slots)
	MapManager.add_save_persist_on_completion("::cmd::%s" % key_str, to_add_val)

func desc_reset_level_complete_save_file_adds() -> String:
	return "none|Remove pending adds to the save file value [key_val:ComplexStringInput] on level completion"
func cmd_reset_level_complete_save_file_adds(slots: Dictionary, _slot: int, key_val: Dictionary) -> void:
	var key_str: String = resolve_complex_string(key_val, slots)
	MapManager.clear_save_adds_for("::cmd::%s" % key_str)

func desc_select_level_complete_save_file_adds() -> String:
	return "number,string|<= Select the pending adds to the save file value [key_val:ComplexStringInput] on level completion"
func cmd_select_level_complete_save_file_adds(slots: Dictionary, chosen_slot: int, key_val: Dictionary) -> void:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to select level complete save file adds into: %s" % chosen_slot)
		return
	var key_str: String = resolve_complex_string(key_val, slots)
	var adds: float = MapManager.get_save_adds_for("::cmd::%s" % key_str)
	set_value_slot_as_number(slots, chosen_slot, adds)

func desc_if_save_file_flag_is_set() -> String:
	return "none|If the save file flag [key_val:ComplexStringInput] is set [or_persist:BoolChoice:true,or will be set once level is completed,now]"
func cmd_if_save_file_flag_is_set(slots: Dictionary, _slot: int, key_val: Dictionary, or_persist: bool) -> bool:
	var key_str: String = resolve_complex_string(key_val, slots)
	var is_persist_set: bool = false
	if or_persist:
		is_persist_set = MapManager.is_flag_persist_on_completion("::cmd-flag::%s" % key_str)
	return is_persist_set or GameManager.has_game_save_data_or_dummy("::cmd-flag::%s" % key_str)

func desc_if_save_file_flag_is_waiting_on_completion() -> String:
	return "none|If the save file flag [key_val:ComplexStringInput] is not currently set, but will be once this level is completed"
func cmd_if_save_file_flag_is_waiting_on_completion(slots: Dictionary, _slot: int, key_val: Dictionary) -> bool:
	var key_str: String = resolve_complex_string(key_val, slots)
	if MapManager.is_flag_persist_on_completion("::cmd-flag::%s" % key_str):
		return not GameManager.has_game_save_data_or_dummy("::cmd-flag::%s" % key_str)
	return false

func desc_set_save_file_flag() -> String:
	return "none|Set the save file flag [key_val:ComplexStringInput] right now"
func cmd_set_save_file_flag(slots: Dictionary, _slot: int, key_val: Dictionary) -> void:
	var key_str: String = resolve_complex_string(key_val, slots)
	GameManager.set_game_save_data_or_dummy("::cmd-flag::%s" % key_str, true)
	MapManager.clear_any_persist_on_completion_for("::cmd-flag::%s" % key_str)

func desc_clear_save_file_flag() -> String:
	return "none|Clear the save file flag [key_val:ComplexStringInput] right now"
func cmd_clear_save_file_flag(slots: Dictionary, _slot: int, key_val: Dictionary) -> void:
	var key_str: String = resolve_complex_string(key_val, slots)
	GameManager.clear_game_save_data_or_dummy("::cmd-flag::%s" % key_str)
	MapManager.clear_any_persist_on_completion_for("::cmd-flag::%s" % key_str)

func desc_set_or_clear_save_file_flag_on_level_completed() -> String:
	return "none|[is_set:BoolChoice:true,Set,Clear] the save file flag [key_val:ComplexStringInput] once the current level is completed"
func cmd_set_save_file_flag_on_level_completed(slots: Dictionary, _slot: int, key_val: Dictionary, is_set: bool) -> void:
	var key_str: String = resolve_complex_string(key_val, slots)
	if is_set:
		MapManager.set_save_persist_on_completion("::cmd-flag::%s" % key_str, true)
	else:
		MapManager.set_clear_save_persist_on_completion("::cmd-flag::%s" % key_str)


func _unique_flag_for_entity(entity: BaseEntity) -> String:
	if not entity:
		return ""
	var unique_id: String = str(entity.instance_id)
	if EntityManager.entity_has_property(entity, "id"):
		var prop_id: String = Utility.property_value_to_string(EntityManager.get_entity_prop_with_default(entity, "id", ""))
		if prop_id:
			unique_id = prop_id
	return "::cmd-flag::entity-flag-%s::_LEV_%s_ENT_%s" % [entity.entity_index, GameManager.get_current_level_code(), unique_id]

func desc_select_unique_flag_for_entity() -> Dictionary:
	return {
		"slot_type_hint": "string",
		"template_text": "<= Select a unique flag name for this entity [entity_slot:SlotInput:entity]",
		"extra_keywords": ["save file"],
		"feature_tags": ["game save data"],
		"tooltip": "If the entity is created after the level starts, set the 'id' property to a consistent, unique value in order for this to work.",
	}
func cmd_select_unique_flag_for_entity(slots: Dictionary, chosen_slot: int, entity_slot: int) -> void:
	if not Commands.slot_is_entity(entity_slot):
		push_error("Invalid slot to select unique flag for entity: %s" % entity_slot)
		return
	if not slots[entity_slot]:
		slots[chosen_slot] = ""
		return
	slots[chosen_slot] = _unique_flag_for_entity(slots[entity_slot]).trim_prefix("::cmd-flag::")

func if_unique_save_file_flag_is_set() -> Dictionary:
	return {
		"slot_type_hint": "entity",
		"template_text": "If the unique flag for this entity is set [or_persist:BoolChoice:true,or will be once level is completed,now]",
		"feature_tags": ["game save data"],
		"tooltip": "If the entity is created after the level starts, set the 'id' property to a consistent, unique value in order for this to work.",
	}
func cmd_if_unique_save_file_flag_is_set(slots: Dictionary, chosen_slot: int, or_persist: bool) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot to check if unique save file flag is set: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	var unique_flag: String = _unique_flag_for_entity(slots[chosen_slot])
	if not unique_flag:
		return false
	var is_persist_on_complete: bool = false
	if or_persist:
		is_persist_on_complete = MapManager.is_flag_persist_on_completion(unique_flag)
	return is_persist_on_complete or GameManager.has_game_save_data_or_dummy(unique_flag)

func desc_set_or_clear_unique_save_file_flag() -> String:
	return "entity|[is_set:BoolChoice:true,Set,Clear] the unique save file flag for this entity [on_completed:BoolChoice:false,once the current level is completed,now]"
func cmd_set_or_clear_unique_save_file_flag(slots: Dictionary, chosen_slot: int, is_set: bool, on_completed: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot to set unique save file flag: %s" % chosen_slot)
		return
	var unique_flag: String = _unique_flag_for_entity(slots[chosen_slot])
	if not unique_flag:
		return
	if is_set:
		if on_completed:
			MapManager.set_save_persist_on_completion(unique_flag, true)
		else:
			GameManager.set_game_save_data_or_dummy(unique_flag, true)
			MapManager.clear_any_persist_on_completion_for(unique_flag)
	else:
		if on_completed:
			MapManager.set_clear_save_persist_on_completion(unique_flag)
		else:
			GameManager.clear_game_save_data_or_dummy(unique_flag)
			MapManager.clear_any_persist_on_completion_for(unique_flag)


func desc_select_number_of_saved_flags_for_entity_type() -> String:
	return "number,string|<= Select the number of set, unique save file flags for entities of the same type as [ref_entity:SlotInput:entity]\n" \
		+ "[include_pending:BoolChoice:true,Including flags pending level completion,Excluding flags pending level completion]"
func cmd_select_number_of_saved_flags_for_entity_type(slots: Dictionary, chosen_slot: int, ref_entity: int, include_pending: bool) -> void:
	if not Commands.slot_is_entity(ref_entity):
		push_error("Invalid slot to select number of saved flags for entity type: %s" % ref_entity)
		return
	if not slots[ref_entity]:
		set_value_slot_as_number(slots, chosen_slot, 0)
		return
	var count: int = _get_unique_flag_count_for_entity_id(slots[ref_entity].entity_index, include_pending)
	set_value_slot_as_number(slots, chosen_slot, count)

func desc_select_number_of_saved_flags_for_named_entity() -> String:
	return "number,string|<= Select the number of set, unique save file flags for entities of the type named [entity_name:ComplexStringInput]\n" \
		+ "[include_pending:BoolChoice:true,Including flags pending level completion,Excluding flags pending level completion]"
func cmd_select_number_of_saved_flags_for_named_entity(slots: Dictionary, chosen_slot: int, entity_name: Dictionary, include_pending: bool) -> void:
	var entity_name_str: String = resolve_complex_string(entity_name, slots)
	if not EntityManager.entity_name_exists(entity_name_str):
		set_value_slot_as_number(slots, chosen_slot, 0)
		return
	var count: = _get_unique_flag_count_for_entity_id(EntityManager.get_entity_index(entity_name_str), include_pending)
	set_value_slot_as_number(slots, chosen_slot, count)

func _get_unique_flag_count_for_entity_id(entity_id: int, include_pending: bool) -> int:
	return GameManager.count_entity_flags_by_entity_id(entity_id, include_pending)


func desc_toggle_property() -> String:
	return "entity,pos|Toggle the entity or tile's [property_name:PropertyInput] property between true and false"
func cmd_toggle_property(slots: Dictionary, chosen_slot: int, property_name: String) -> void:
	if Commands.slot_is_entity(chosen_slot):
		if slots[chosen_slot]:
			var cur_value: Variant = EntityManager.get_entity_prop_with_default(slots[chosen_slot], property_name, false)
			slots[chosen_slot].set_local_property(property_name, not Utility.property_value_bool(cur_value))
	elif Commands.slot_is_positions(chosen_slot):
		var positions: Array = slots[chosen_slot]
		if positions.size() > 0:
			for pos in positions:
				var cur_value: Variant = MapManager.get_tile_property_at(pos, property_name)
				MapManager.set_tile_property_for_all_tiles_at(pos, property_name, not Utility.property_value_bool(cur_value))


func desc_if_loop_detected() -> String:
	return "none|If a logic loop has been detected with a limit of [max_loops:ComplexScalarInput:int,default=%s]" % [DEFAULT_MAX_LOOPS]
func cmd_if_loop_detected(slots: Dictionary, _slot: int, max_loops: Dictionary) -> bool:
	var max_loops_val: int = resolve_complex_scalar(max_loops, slots)
	if max_loops_val <= 0:
		max_loops_val = DEFAULT_MAX_LOOPS
	return ConditionalsV3.is_loop_detected(max_loops_val)

func desc_if_named_loop_detected() -> String:
	return "none|If a logic loop has been detected (counter name [loop_name:ComplexStringInput]) with a limit of [max_loops:ComplexScalarInput:int,default=%s]" % [DEFAULT_MAX_LOOPS]
func cmd_if_named_loop_detected(slots: Dictionary, _slot: int, loop_name: Dictionary, max_loops: Dictionary) -> bool:
	var max_loops_val: int = resolve_complex_scalar(max_loops, slots)
	if max_loops_val <= 0:
		max_loops_val = DEFAULT_MAX_LOOPS
	var loop_name_str: String = resolve_complex_string(loop_name, slots)
	return ConditionalsV3.is_loop_detected(max_loops_val, loop_name_str)


func desc_fail_state() -> String:
	return "none|Show the default fail state overlay"
func cmd_fail_state(_slots: Dictionary) -> void:
	GameManager.show_current_fail_state_intermission_as_overlay()

func desc_custom_failure_intermission() -> String:
	return "none|Show the intermission [intermission_id:IntermissionIdInput] as a fail state overlay"
func cmd_custom_failure_intermission(_slots: Dictionary, _slot: int, intermission_id: String) -> void:
	GameManager.show_custom_fail_state_overlay(intermission_id)

func desc_show_intermission_overlay() -> String:
	return "none|Show the intermission [intermission_id:IntermissionIdInput] overlaying the current level"
func cmd_show_intermission_overlay(_slots: Dictionary, _slot: int, intermission_id: String) -> void:
	GameManager.show_overlay_intermissions(Array([intermission_id], TYPE_STRING, "", null))

func desc_if_has_viewed_intermission() -> String:
	return "none|If the player has viewed the intermission [intermission_id:IntermissionIdInput:include_reserved_flags=true]"
func cmd_if_has_viewed_intermission(_slots: Dictionary, _slot: int, intermission_id: String) -> bool:
	return GameManager.has_intermission_flag(intermission_id)


func desc_if_game_is_completed() -> String:
	return "none|If the game is completed (Regular Completion)"
func cmd_if_game_is_completed(_slots: Dictionary) -> bool:
	return GameManager.is_game_completed()

func desc_if_all_levels_are_completed() -> String:
	return "none|If all (non-custom) levels in the game are completed"
func cmd_if_all_levels_are_completed(_slots: Dictionary) -> bool:
	return GameManager.is_every_level_completed()

func desc_if_level_list_is_completed() -> String:
	return "none|If the level list [level_list_name:LevelListNameInput] is completed"
func cmd_if_level_list_is_completed(_slots: Dictionary, level_list_name: String) -> bool:
	return GameManager.is_level_list_completed(level_list_name)

func desc_if_all_level_lists_are_completed() -> String:
	return "none|If all completable, non-custom level lists in the game are completed"
func cmd_if_all_level_lists_are_completed(_slots: Dictionary) -> bool:
	return GameManager.is_every_bundled_completable_list_complete()


func desc_select_number_of_named_entities() -> String:
	return "number,string|<= Select the number of active entities named [entity_name:ComplexStringInput]"
func cmd_select_number_of_named_entities(slots: Dictionary, chosen_slot: int, entity_name: Dictionary) -> void:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to select count of named entities: %s" % chosen_slot)
		return
	var entity_name_str: String = resolve_complex_string(entity_name, slots)
	if not EntityManager.entity_name_exists(entity_name_str):
		set_value_slot_as_number(slots, chosen_slot, 0)
		return
	var count: int = EntityManager.get_entity_count_by_id(EntityManager.get_entity_index(entity_name_str))
	set_value_slot_as_number(slots, chosen_slot, count)

func desc_select_number_of_entities_with_property() -> String:
	return "number,string|<= Select the number of active entities [invert:InvertInput:true,with,without] a [truthy:BoolChoice:true,true or non-zero,false or zero] " \
		+ "[property_name:PropertyInput] property excluding [exclude_entity:SlotInput:entity,none]"
func cmd_select_number_of_entities_with_property(slots: Dictionary, chosen_slot: int, property_name: String, truthy: bool, invert: bool, exclude_entity: int) -> void:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to select count of entities with property: %s" % chosen_slot)
		return
	var ignore_list: Array = []
	if exclude_entity != SlotSelectorButton.NONE_SLOTS and slots[exclude_entity]:
		ignore_list.append(slots[exclude_entity].instance_id)
	var count: int = EntityManager.get_entity_count_by_property(property_name, ignore_list, truthy, invert)
	set_value_slot_as_number(slots, chosen_slot, count)

func desc_select_number_of_entities_at() -> String:
	return "number,string|<= Select the number of active entities [invert:InvertInput:true,with,without] a [truthy:BoolChoice:true,true or non-zero,false or zero] " \
	+ "[property_name:PropertyInput] property at [pos_slot:SlotInput:pos] excluding [exclude_entity:SlotInput:entity,none]"
func cmd_select_number_of_entities_at(slots: Dictionary, chosen_slot: int, property_name: String, truthy: bool, invert: bool, pos_slot: int, exclude_entity: int) -> void:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to select count of entities with property: %s" % chosen_slot)
		return
	var ignore_list: Array = []
	if exclude_entity != SlotSelectorButton.NONE_SLOTS and slots[exclude_entity]:
		ignore_list.append(slots[exclude_entity].instance_id)

	var filtered_entities: Array = []
	if slots[pos_slot]:
		filtered_entities = EntityManager.get_entities_at_multiple(slots[pos_slot], null, [])
	else:
		filtered_entities = EntityManager.get_all_active_entities()
	filtered_entities = EntityManager.filter_entities_by_property(property_name, filtered_entities, ignore_list, truthy, invert)
	set_value_slot_as_number(slots, chosen_slot, filtered_entities.size())




func desc_if_all_entities_overlap_named_entity_or_tile() -> String:
	return "none|If [is_all:BoolChoice:true,all,any] entities named [primary_name:EntityNameInput] [invert:InvertInput:overlap,do not overlap] positions with an entity or tile named [target_name:EntityTileNameInput]"
func cmd_if_all_entities_overlap_named_entity_or_tile(slots: Dictionary, _slot: int, is_all: bool, primary_name: Dictionary, invert: bool, target_name: Dictionary) -> bool:
	var primary_name_str: String = resolve_complex_string(primary_name, slots)
	if not EntityManager.entity_name_exists(primary_name_str):
		return false
	var primary_entity_id: = EntityManager.get_entity_index(primary_name_str)
	var large_check_required: bool = EntityManager.can_entity_id_be_large(primary_entity_id)

	var target_name_str: String = resolve_complex_string(target_name, slots)
	var target_entity_id: int = -1
	var target_tile_id: int = -1
	if EntityManager.entity_name_exists(target_name_str):
		target_entity_id = EntityManager.get_entity_index(target_name_str)
	if MapManager.tile_name_exists(target_name_str):
		target_tile_id = MapManager.get_tile_index(target_name_str)
	if target_entity_id == -1 and target_tile_id == -1:
		return false
	
	var primary_positions: = EntityManager.get_all_positions_of_active_entities_by_id(primary_entity_id)
	var target_intersection: Array[Vector2i] = []
	if target_entity_id != -1:
		var check_entity_pos: = EntityManager.get_all_positions_of_active_entities_by_id(target_entity_id)
		target_intersection = Utility.intersect_positions(primary_positions, check_entity_pos)
		if (is_all == invert) and target_intersection.size() > 0:
			return not is_all

	if target_tile_id != -1:
		var check_tile_pos: = MapManager.get_all_positions_of_tile(target_tile_id)
		var tile_intersection: = Utility.intersect_positions(primary_positions, check_tile_pos)
		target_intersection = Utility.arr_set_union(target_intersection, tile_intersection)
		if (is_all == invert) and target_intersection.size() > 0:
			return not is_all
	
	if is_all != invert:
		if not large_check_required:
			for pos in primary_positions:
				if pos not in target_intersection:
					return not is_all
		else:
			for entity in EntityManager.get_all_active_entities_by_id(primary_entity_id):
				var entity_positions: = EntityManager.get_all_positions_of_entity(entity)
				if not Utility.do_positions_intersect(entity_positions, target_intersection):
					return not is_all
	return is_all

func desc_if_entity_overlaps_named_entity_or_tile() -> String:
	return "entity|If this entity [invert:InvertInput:overlaps,does not overlap] position with an entity or tile named [target_name:EntityTileNameInput]"
func cmd_if_entity_overlaps_named_entity_or_tile(slots: Dictionary, chosen_slot: int, invert: bool, target_name: Dictionary) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot to check if entity overlaps named entity or tile: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	var target_name_str: String = resolve_complex_string(target_name, slots)
	var target_entity_id: int = -1
	var target_tile_id: int = -1
	if EntityManager.entity_name_exists(target_name_str):
		target_entity_id = EntityManager.get_entity_index(target_name_str)
	if MapManager.tile_name_exists(target_name_str):
		target_tile_id = MapManager.get_tile_index(target_name_str)
	if target_entity_id == -1 and target_tile_id == -1:
		return false
	
	var target_positions: Array[Vector2i] = []
	if target_tile_id != -1:
		target_positions = MapManager.get_all_positions_of_tile(target_tile_id)
	if target_entity_id != -1:
		for entity_pos in EntityManager.get_all_positions_of_active_entities_by_id(target_entity_id):
			if not entity_pos in target_positions:
				target_positions.append(entity_pos)
	if target_positions.size() == 0:
		return false
	var entity_positions: = EntityManager.get_all_positions_of_entity(slots[chosen_slot])

	return Utility.do_positions_intersect(entity_positions, target_positions) != invert

func desc_select_number_of_entities_overlapping_named() -> String:
	return "number,string|<= Select the number of active entities named [primary_name:EntityNameInput] which [invert:InvertInput:overlap,do not overlap] an entity or tile named [target_name:EntityTileNameInput]"
func cmd_select_number_of_entities_overlapping_named(slots: Dictionary, chosen_slot: int, primary_name: Dictionary, invert: bool, target_name: Dictionary) -> void:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to select count of entities overlapping: %s" % chosen_slot)
		return
	var target_name_str: String = resolve_complex_string(target_name, slots)
	var target_entity_id: int = -1
	var target_tile_id: int = -1
	var primary_name_str: String = resolve_complex_string(primary_name, slots)
	if not EntityManager.entity_name_exists(primary_name_str):
		set_value_slot_as_number(slots, chosen_slot, 0)
		return
	var primary_entity_id: int = EntityManager.get_entity_index(primary_name_str)
	var primary_entities: = EntityManager.find_all_entities_by_index(primary_entity_id, true)

	if EntityManager.entity_name_exists(target_name_str):
		target_entity_id = EntityManager.get_entity_index(target_name_str)
	if MapManager.tile_name_exists(target_name_str):
		target_tile_id = MapManager.get_tile_index(target_name_str)
	if target_entity_id == -1 and target_tile_id == -1:
		set_value_slot_as_number(slots, chosen_slot, primary_entities.size() if invert else 0)
		return
	
	var count: int = primary_entities.size() if invert else 0
	var target_positions: Array[Vector2i] = []
	if target_tile_id != -1:
		target_positions = MapManager.get_all_positions_of_tile(target_tile_id)
	if target_entity_id != -1:
		for entity_pos in EntityManager.get_all_positions_of_active_entities_by_id(target_entity_id):
			if not entity_pos in target_positions:
				target_positions.append(entity_pos)
	if target_positions.size() == 0:
		set_value_slot_as_number(slots, chosen_slot, count)
		return
	
	for entity in primary_entities:
		var entity_positions: = EntityManager.get_all_positions_of_entity(entity)
		if Utility.do_positions_intersect(entity_positions, target_positions):
			if invert:
				count -= 1
			else:
				count += 1
	set_value_slot_as_number(slots, chosen_slot, count)



func desc_if_all_tiles_overlap_entity() -> String:
	return "none|If [is_all:BoolChoice:true,all,any] tiles [invert_tile_prop:InvertInput:with,without] a [tile_truthy:BoolChoice:true,true or non-zero,false or zero] [tile_prop:PropertyInput] property [invert:InvertInput:overlap,do not overlap] an entity\n" \
		+ "[invert_prop:InvertInput:with,without] a [ent_truthy:BoolChoice:true,true or non-zero,false or zero] [property_name:PropertyInput] property"
func cmd_if_all_tiles_overlap_entity(
		slots: Dictionary,
		_slot: int,
		is_all: bool,
		invert: bool,
		invert_tile_prop: bool, tile_truthy: bool, tile_prop: String,
		invert_prop: bool, ent_truthy: bool, ent_prop: String) -> bool:
	return _tile_overlap_ent_prop_check(
		slots,
		is_all,
		invert,
		SlotSelectorButton.NONE_SLOTS,
		invert_tile_prop, tile_truthy, tile_prop,
		invert_prop, ent_truthy, ent_prop
	)

func desc_if_all_tiles_overlap_entity_at() -> String:
	return "none|If [is_all:BoolChoice:true,all,any] tiles at [pos_filter_slot:SlotInput:pos] [invert_tile_prop:InvertInput:with,without] a [tile_truthy:BoolChoice:true,true or non-zero,false or zero] [tile_prop:PropertyInput] property [invert:InvertInput:overlap,do not overlap] an entity\n" \
		+ "[invert_prop:InvertInput:with,without] a [ent_truthy:BoolChoice:true,true or non-zero,false or zero] [property_name:PropertyInput] property"
func cmd_if_all_tiles_overlap_entity_at(
		slots: Dictionary,
		_slot: int,
		is_all: bool,
		invert: bool,
		pos_filter_slot: int,
		invert_tile_prop: bool, tile_truthy: bool, tile_prop: String,
		invert_prop: bool, ent_truthy: bool, ent_prop: String) -> bool:
	return _tile_overlap_ent_prop_check(
		slots,
		is_all,
		invert,
		pos_filter_slot,
		invert_tile_prop, tile_truthy, tile_prop,
		invert_prop, ent_truthy, ent_prop
	)

func _tile_overlap_ent_prop_check(
		slots: Dictionary,
		is_all: bool,
		invert: bool,
		pos_filter_slot: int,
		invert_tile_prop: bool, tile_truthy: bool, tile_prop: String,
		invert_prop: bool, ent_truthy: bool, ent_prop: String) -> bool:
	var tile_positions: Array[Vector2i] = _get_prop_filtered_tile_positions(slots, tile_prop, tile_truthy, invert_tile_prop, pos_filter_slot)

	var with_pos_filter: bool = pos_filter_slot != SlotSelectorButton.NONE_SLOTS
	var pos_filter: Array = slots[pos_filter_slot]

	var filtered_entities: Array = []
	if with_pos_filter:
		filtered_entities = EntityManager.get_entities_at_multiple(pos_filter, null, [])
	else:
		filtered_entities = EntityManager.get_all_active_entities()
	filtered_entities = EntityManager.filter_entities_by_property(ent_prop, filtered_entities, [], ent_truthy, invert_prop)
	var all_entity_positions: Array[Vector2i] = []
	for entity in filtered_entities:
		all_entity_positions = Utility.arr_set_union(all_entity_positions, EntityManager.get_all_positions_of_entity(entity))
	
	for tile_pos in tile_positions:
		if tile_pos not in all_entity_positions:
			if is_all == invert:
				return not is_all
		elif is_all != invert:
			return not is_all
	return is_all

func _get_tile_overlap_ent_prop_positions(
		slots: Dictionary,
		pos_filter_slot: int,
		invert_tile_prop: bool, tile_truthy: bool, tile_prop: String,
		invert_prop: bool, ent_truthy: bool, ent_prop: String) -> Array[Vector2i]:
	var tile_positions: Array[Vector2i] = _get_prop_filtered_tile_positions(slots, tile_prop, tile_truthy, invert_tile_prop, pos_filter_slot)

	var with_pos_filter: bool = pos_filter_slot != SlotSelectorButton.NONE_SLOTS
	var pos_filter: Array = slots[pos_filter_slot]

	var filtered_entities: Array = []
	if with_pos_filter:
		filtered_entities = EntityManager.get_entities_at_multiple(pos_filter, null, [])
	else:
		filtered_entities = EntityManager.get_all_active_entities()
	filtered_entities = EntityManager.filter_entities_by_property(ent_prop, filtered_entities, [], ent_truthy, invert_prop)

	var filtered_positions: Array[Vector2i] = []
	for entity in filtered_entities:
		for entity_pos in EntityManager.get_all_positions_of_entity(entity):
			if entity_pos not in filtered_positions and entity_pos in tile_positions:
				filtered_positions.append(entity_pos)
	return filtered_positions

func desc_select_tiles_overlapping_entity_with_property() -> String:
	return "pos|<= Select the positions of all tiles [invert_tile_prop:InvertInput:with,without] a [tile_truthy:BoolChoice:true,true or non-zero,false or zero] [tile_prop:PropertyInput] property which [invert:InvertInput:overlap,do not overlap] an entity\n" \
		+ "[invert_prop:InvertInput:with,without] a [ent_truthy:BoolChoice:true,true or non-zero,false or zero] [property_name:PropertyInput] property"
func cmd_select_tiles_overlapping_entity_with_property(slots: Dictionary, chosen_slot: int, invert_tile_prop: bool, tile_truthy: bool, tile_prop: String, invert_prop: bool, ent_truthy: bool, ent_prop: String) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to select tiles overlapping entity with property: %s" % chosen_slot)
		return
	slots[chosen_slot] = _get_tile_overlap_ent_prop_positions(
		slots,
		SlotSelectorButton.NONE_SLOTS,
		invert_tile_prop, tile_truthy, tile_prop,
		invert_prop, ent_truthy, ent_prop
	)
	
func desc_select_tiles_overlapping_entity_with_property_at() -> String:
	return "pos|<= Select the positions of all tiles at [pos_filter_slot:SlotInput:pos] [invert_tile_prop:InvertInput:with,without] a [tile_truthy:BoolChoice:true,true or non-zero,false or zero] [tile_prop:PropertyInput] property which [invert:InvertInput:overlap,do not overlap] an entity\n" \
		+ "[invert_prop:InvertInput:with,without] a [ent_truthy:BoolChoice:true,true or non-zero,false or zero] [property_name:PropertyInput] property"
func cmd_select_tiles_overlapping_entity_with_property_at(slots: Dictionary, chosen_slot: int, invert_tile_prop: bool, tile_truthy: bool, tile_prop: String, invert_prop: bool, ent_truthy: bool, ent_prop: String, pos_filter_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to select tiles overlapping entity with property: %s" % chosen_slot)
		return
	slots[chosen_slot] = _get_tile_overlap_ent_prop_positions(
		slots,
		pos_filter_slot,
		invert_tile_prop, tile_truthy, tile_prop,
		invert_prop, ent_truthy, ent_prop
	)


func desc_if_all_entities_overlap_by_property() -> String:
	return "none|If [is_all:BoolChoice:true,all,any] entities [invert_primary:InvertInput:with,without] a [primary_truthy:BoolChoice:true,true or non-zero,false or zero] [primary_prop:PropertyInput] property [invert:InvertInput:overlap,do not overlap] another entity\n" \
		+ "[invert_other:InvertInput:with,without] a [other_truthy:BoolChoice:true,true or non-zero,false or zero] [other_prop:PropertyInput] property"
func cmd_if_all_entities_overlap_by_property(slots: Dictionary, _slot: int, is_all: bool, invert: bool, invert_primary: bool, primary_truthy: bool, primary_prop: String, invert_other: bool, other_truthy: bool, other_prop: String) -> bool:
	return _ent_overlap_ent_prop_check(
		slots,
		is_all,
		invert,
		SlotSelectorButton.NONE_SLOTS,
		invert_primary, primary_truthy, primary_prop,
		invert_other, other_truthy, other_prop
	)

func desc_if_all_entities_overlap_by_property_at() -> String:
	return "none|If [is_all:BoolChoice:true,all,any] entities at [pos_filter_slot:SlotInput:pos] [invert_primary:InvertInput:with,without] a [primary_truthy:BoolChoice:true,true or non-zero,false or zero] [primary_prop:PropertyInput] property [invert:InvertInput:overlap,do not overlap] another entity\n" \
		+ "[invert_other:InvertInput:with,without] a [other_truthy:BoolChoice:true,true or non-zero,false or zero] [other_prop:PropertyInput] property"
func cmd_if_all_entities_overlap_by_property_at(slots: Dictionary, _slot: int, is_all: bool, invert: bool, pos_filter_slot: int, invert_primary: bool, primary_truthy: bool, primary_prop: String, invert_other: bool, other_truthy: bool, other_prop: String) -> bool:
	return _ent_overlap_ent_prop_check(
		slots,
		is_all,
		invert,
		pos_filter_slot,
		invert_primary, primary_truthy, primary_prop,
		invert_other, other_truthy, other_prop
	)

func desc_select_positions_where_entities_overlap() -> String:
	return "pos|<= Select all the positions where an entity [invert_primary:InvertInput:with,without] a [primary_truthy:BoolChoice:true,true or non-zero,false or zero] [primary_prop:PropertyInput] property [invert:InvertInput:overlaps,does not overlap] another entity\n" \
		+ "[invert_other:InvertInput:with,without] a [other_truthy:BoolChoice:true,true or non-zero,false or zero] [other_prop:PropertyInput] property"
func cmd_select_positions_where_entities_overlap(slots: Dictionary, chosen_slot: int, invert: bool, invert_primary: bool, primary_truthy: bool, primary_prop: String, invert_other: bool, other_truthy: bool, other_prop: String) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to select positions where entities overlap: %s" % chosen_slot)
		return
	slots[chosen_slot] = _get_ent_overlap_ent_positions(
		slots,
		invert,
		SlotSelectorButton.NONE_SLOTS,
		invert_primary, primary_truthy, primary_prop,
		invert_other, other_truthy, other_prop
	)

func desc_filter_selected_positions_where_entities_overlap() -> String:
	return "pos|<= Select all the positions within [pos_filter_slot:SlotInput:pos] where an entity [invert_primary:InvertInput:with,without] a [primary_truthy:BoolChoice:true,true or non-zero,false or zero] [primary_prop:PropertyInput] property [invert:InvertInput:overlaps,does not overlap] another entity\n" \
		+ "[invert_other:InvertInput:with,without] a [other_truthy:BoolChoice:true,true or non-zero,false or zero] [other_prop:PropertyInput] property"
func cmd_filter_selected_positions_where_entities_overlap(slots: Dictionary, chosen_slot: int, invert: bool, pos_filter_slot: int, invert_primary: bool, primary_truthy: bool, primary_prop: String, invert_other: bool, other_truthy: bool, other_prop: String) -> void:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to filter selected positions where entities overlap: %s" % chosen_slot)
		return
	slots[chosen_slot] = _get_ent_overlap_ent_positions(
		slots,
		invert,
		pos_filter_slot,
		invert_primary, primary_truthy, primary_prop,
		invert_other, other_truthy, other_prop
	)

func desc_select_number_of_overlapping_entities() -> String:
	return "number,string|<= Select the number of entities [invert_primary:InvertInput:with,without] a [primary_truthy:BoolChoice:true,true or non-zero,false or zero] [primary_prop:PropertyInput] property which [invert:InvertInput:overlap,do not overlap] any other entity\n" \
		+ "[invert_other:InvertInput:with,without] a [other_truthy:BoolChoice:true,true or non-zero,false or zero] [other_prop:PropertyInput] property"
func cmd_select_number_of_overlapping_entities(slots: Dictionary, chosen_slot: int, invert: bool, invert_primary: bool, primary_truthy: bool, primary_prop: String, invert_other: bool, other_truthy: bool, other_prop: String) -> void:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to select number of overlapping entities: %s" % chosen_slot)
		return
	slots[chosen_slot] = _get_ent_overlap_ent_count(
		slots,
		invert,
		SlotSelectorButton.NONE_SLOTS,
		invert_primary, primary_truthy, primary_prop,
		invert_other, other_truthy, other_prop
	)

func desc_select_number_of_overlapping_entities_at() -> String:
	return "number,string|<= Select the number of entities at [pos_filter_slot:SlotInput:pos] [invert_primary:InvertInput:with,without] a [primary_truthy:BoolChoice:true,true or non-zero,false or zero] [primary_prop:PropertyInput] property which [invert:InvertInput:overlap,do not overlap] any other entity\n" \
		+ "[invert_other:InvertInput:with,without] a [other_truthy:BoolChoice:true,true or non-zero,false or zero] [other_prop:PropertyInput] property"
func cmd_select_number_of_overlapping_entities_at(slots: Dictionary, chosen_slot: int, invert: bool, pos_filter_slot: int, invert_primary: bool, primary_truthy: bool, primary_prop: String, invert_other: bool, other_truthy: bool, other_prop: String) -> void:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to select number of overlapping entities: %s" % chosen_slot)
		return
	slots[chosen_slot] = _get_ent_overlap_ent_count(
		slots,
		invert,
		pos_filter_slot,
		invert_primary, primary_truthy, primary_prop,
		invert_other, other_truthy, other_prop
	)

func _ent_overlap_ent_prop_check(
		slots: Dictionary,
		is_all: bool,
		invert: bool,
		pos_filter_slot: int,
		invert_primary: bool, primary_truthy: bool, primary_prop: String,
		invert_other: bool, other_truthy: bool, other_prop: String) -> bool:
	var with_pos_filter: bool = pos_filter_slot != SlotSelectorButton.NONE_SLOTS
	var pos_filter: Array = slots[pos_filter_slot]

	var primary_entities: Array = EntityManager.find_entities_by_property(primary_prop, primary_truthy, invert_primary, [], with_pos_filter, pos_filter)
	var other_entities: Array = EntityManager.find_entities_by_property(other_prop, other_truthy, invert_other, [], with_pos_filter, pos_filter)
	var other_positions: Array[Vector2i] = []
	for other_entity in other_entities:
		var positions: = EntityManager.get_all_positions_of_entity(other_entity)
		other_positions = Utility.arr_set_union(other_positions, positions)
	
	for primary_entity in primary_entities:
		var primary_positions: = EntityManager.get_all_positions_of_entity(primary_entity)
		if not Utility.do_positions_intersect(primary_positions, other_positions):
			if is_all == invert:
				return not is_all
		elif is_all != invert:
			return not is_all
	return is_all

func _get_ent_overlap_ent_count(
		slots: Dictionary,
		invert: bool,
		pos_filter_slot: int,
		invert_primary: bool, primary_truthy: bool, primary_prop: String,
		invert_other: bool, other_truthy: bool, other_prop: String) -> int:
	var with_pos_filter: bool = pos_filter_slot != SlotSelectorButton.NONE_SLOTS
	var pos_filter: Array = slots[pos_filter_slot]

	var primary_entities: Array = EntityManager.find_entities_by_property(primary_prop, primary_truthy, invert_primary, [], with_pos_filter, pos_filter)
	var other_entities: Array = EntityManager.find_entities_by_property(other_prop, other_truthy, invert_other, [], with_pos_filter, pos_filter)
	var other_positions: Array[Vector2i] = []
	for other_entity in other_entities:
		var positions: = EntityManager.get_all_positions_of_entity(other_entity)
		other_positions = Utility.arr_set_union(other_positions, positions)
	
	var count: int = 0
	for primary_entity in primary_entities:
		var primary_positions: = EntityManager.get_all_positions_of_entity(primary_entity)
		if Utility.do_positions_intersect(primary_positions, other_positions):
			count += 1
	if invert:
		return primary_entities.size() - count
	else:
		return count

func _get_ent_overlap_ent_positions(
		slots: Dictionary,
		invert: bool,
		pos_filter_slot: int,
		invert_primary: bool, primary_truthy: bool, primary_prop: String,
		invert_other: bool, other_truthy: bool, other_prop: String) -> Array[Vector2i]:
	var with_pos_filter: bool = pos_filter_slot != SlotSelectorButton.NONE_SLOTS
	var pos_filter: Array = slots[pos_filter_slot]

	var primary_entities: Array = EntityManager.find_entities_by_property(primary_prop, primary_truthy, invert_primary, [], with_pos_filter, pos_filter)
	var primary_positions: Array[Vector2i] = []
	for primary_entity in primary_entities:
		var positions: = EntityManager.get_all_positions_of_entity(primary_entity)
		primary_positions = Utility.arr_set_union(primary_positions, positions)

	var other_entities: Array = EntityManager.find_entities_by_property(other_prop, other_truthy, invert_other, [], with_pos_filter, pos_filter)
	var other_positions: Array[Vector2i] = []
	for other_entity in other_entities:
		var positions: = EntityManager.get_all_positions_of_entity(other_entity)
		other_positions = Utility.arr_set_union(other_positions, positions)
	
	if invert:
		return Utility.inverse_intersect_positions(primary_positions, other_positions)
	else:
		return Utility.intersect_positions(primary_positions, other_positions)