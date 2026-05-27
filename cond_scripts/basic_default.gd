extends BaseConditionalScript


func get_command_display_name(cmd_name: String, custom_meta_info: Dictionary) -> String:
	cmd_name = cmd_name.trim_prefix("a_").trim_prefix("c_")
	return super.get_command_display_name(cmd_name, custom_meta_info)

# --- COMMANDS ---

func desc_select_defaults() -> String:
	return "none|Reset all slots selections"
func cmd_select_defaults(slots: Dictionary) -> void:
	cond_resolver.select_reset(slots)

func desc_quit() -> Dictionary:
	return {
		"display_name": "Quit conditional",
		"slot_type_hint": "none",
		"template_text": "Stop evaluating the rest of the conditional",
		"tooltip": "Commands below in this list or in other lists will be skipped, all later steps will not be run.\n" \
					+ "The result of this conditional will be whatever the result of this step is regardless of if there are later steps."
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
		prints("moving check: no entity")
		return false
	return slots[chosen_slot].moving

func desc_if_entity_is_moving_or_starting_to_move() -> String:
	return "entity|If the entity is currently moving or starting to move"
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


func desc_select_tiles_named() -> String:
	return "pos|<= Select all positions where the tile [tile_name:TileNameInput] is found"
func cmd_select_tiles_named(slots: Dictionary, chosen_slot: Slot, tile_name: String) -> void:
	var tindex = MapManager.get_tile_index(tile_name)
	slots[chosen_slot] = MapManager.get_all_positions_of_tile(tindex)

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
		var at_pos: Vector2i = entity.get_moving_position()
		if not at_pos in slots[chosen_slot]:
			slots[chosen_slot].append(at_pos)

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
	filtered_entities = EntityManager.filter_entities_by_property(prop_name, filtered_entities, not truthy)
	slots[chosen_slot] = []
	for entity in filtered_entities:
		var at_pos: Vector2i = entity.get_moving_position()
		if not at_pos in slots[chosen_slot]:
			slots[chosen_slot].append(at_pos)

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

func desc_select_tiles_in_direction() -> String:
	return "pos|<= Select the position(s) [dist:ComplexScalarInput:int] spaces in this direction [compl_dir:DirectionInput:1] from [from_slot:SlotInput:pos,entity]"
func cmd_select_tiles_in_direction(slots: Dictionary, chosen_slot: int, compl_dir: Dictionary, dist: Dictionary, from_slot: int) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_positions(from_slot) or not Commands.slot_is_entity(from_slot):
		push_error("Invalid slots to select tile in direction: %s, %s" % [chosen_slot, from_slot])
		return
	var distance_int: = int(resolve_complex_scalar(dist, slots))
	var facing_vec: = Utility.facing_vector_i(resolve_complex_direction(compl_dir, slots))
	var from_positions: Array = slots[from_slot] if Commands.slot_is_positions(from_slot) else [slots[from_slot].get_moving_position()]
	var moved_positions: Array[Vector2i] = []
	var delta: = facing_vec * distance_int
	for from_pos in from_positions:
		moved_positions.append(from_pos + delta)
	slots[chosen_slot] = moved_positions

func desc_select_next_tile_after() -> String:
	return "pos|<= Select the [invert:InvertInput:next,previous] position in [in_positions_slot:SlotInput:pos] after the position of [after_pos_slot:SlotInput:pos,entity]"
func cmd_select_next_tile_after(slots: Dictionary, chosen_slot: int, in_positions_slot: int, after_pos_slot: int, invert: bool) -> void:
	if not Commands.slot_is_positions(chosen_slot) or not Commands.slot_is_positions(in_positions_slot) or not Commands.slot_has_position(after_pos_slot):
		push_error("Invalid slots to select next tile after: %s, %s, %s" % [chosen_slot, in_positions_slot, after_pos_slot])
		return
	var in_positions: Array = slots[in_positions_slot]
	if not in_positions:
		in_positions = MapManager.get_used_positions_in_all_layers()
	in_positions = Utility.get_reading_order_sorted_positions(in_positions)
	if not _slot_has_single_tile_position(slots, in_positions_slot):
		slots[chosen_slot] = in_positions[-1 if invert else 0]
	var after_pos: Vector2i = _single_tile_position_from_slot(slots, after_pos_slot)
	slots[chosen_slot] = [Utility.next_prev_pos_reading_order(in_positions, after_pos, invert)]

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
			if entity.can_i_teleport_to(check_pos, -2, -2):
				slots[chosen_slot] = [check_pos]
				return
		check_pos += delta
	slots[chosen_slot] = []


func _slot_has_single_tile_position(slots: Dictionary, slot: int) -> bool:
	if not slots[slot]:
		return false
	return true

func _single_tile_position_from_slot(slots: Dictionary, slot: int) -> Vector2i:
	if Commands.slot_is_positions(slot):
		return slots[slot][0]
	else:
		return slots[slot].get_moving_position()

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
	return "pos,entity|If the entity/tile is adjacent to [single_pos_slot:SlotInput:pos] [with_diagonal:BoolChoice:true,including,excluding] diagonally"
func cmd_if_position_is_adjacent(slots: Dictionary, chosen_slot: int, single_pos_slot: int, with_diagonal: bool) -> bool:
	if not Commands.slot_has_position(chosen_slot) or not Commands.slot_has_position(single_pos_slot):
		push_error("Invalid slots to check if position is adjacent: %s, %s" % [chosen_slot, single_pos_slot])
		return false
	if not _slot_has_single_tile_position(slots, chosen_slot):
		return false
	var ref_positions: Array = []
	if Commands.slot_is_entity(chosen_slot):
		if not slots[chosen_slot]:
			return false
		ref_positions = [slots[chosen_slot].get_moving_position()]
	else:
		ref_positions = slots[chosen_slot]
	var checking_pos: = _single_tile_position_from_slot(slots, chosen_slot)
	for ref_pos in ref_positions:
		if Utility.is_vec2i_adjacent(ref_pos, checking_pos, with_diagonal):
			return true
	return false

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
	return "entity|<= Select an active entity (ignoring self) at [at_pos_slot:SlotInput:pos] [invert:InvertInput:with,without] a [prop_name:PropertyInput] property"
func cmd_select_entity_at(slots: Dictionary, chosen_slot: int, at_pos_slot: int, prop_name: String, invert: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_positions(at_pos_slot):
		push_error("Invalid slots to select entity at: %s and %s" % [chosen_slot, at_pos_slot])
		return
	var at_positions: Array = slots[at_pos_slot]
	if not at_positions:
		slots[chosen_slot] = null
		return
	var filtered_entities: Array = EntityManager.get_entities_at_multiple(at_positions, slots[Slot.RED], [], true, false)
	if prop_name:
		filtered_entities = EntityManager.filter_entities_by_property(prop_name, filtered_entities, invert)
	slots[chosen_slot] = filtered_entities[0] if filtered_entities else null

func desc_select_named_entity_at() -> String:
	return "entity|<= Select an active entity (ignoring self) named [e_name:EntityNameInput] at [at_pos_slot:SlotInput:pos]"
func cmd_select_named_entity_at(slots: Dictionary, chosen_slot: int, at_pos_slot: int, e_name: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_positions(at_pos_slot):
		push_error("Invalid slots to select named entity at: %s and %s" % [chosen_slot, at_pos_slot])
		return
	var e_id: = get_id_of_complex_entity_name(e_name, slots)
	var at_positions: Array = slots[at_pos_slot]
	if not at_positions:
		slots[chosen_slot] = null
		return
	var filtered_entities: Array = EntityManager.get_entities_at_multiple(at_positions, slots[Slot.RED], [], true, false)
	for e in filtered_entities:
		if e.entity_index == e_id:
			slots[chosen_slot] = e
			return
	slots[chosen_slot] = null

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


func desc_select_number() -> String:
	return "number,string|<= Select the number [complex_num:ComplexScalarInput]"
func cmd_select_number(slots: Dictionary, chosen_slot: int, complex_num: Dictionary) -> void:
	set_value_slot_as_number(slots, chosen_slot, resolve_complex_scalar(complex_num, slots))

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
func cmd_select_random_direction(slots: Dictionary, chosen_slot: int, dir_options: String, exclude_dir: Dictionary) -> void:
	var choose_from: Array = rand_dir_options.get(dir_options, [0])
	if exclude_dir.get("type", "") != "ignore":
		var exclude_dir_val: int = resolve_complex_direction(exclude_dir, slots)
		var is_exclude: bool = exclude_dir.get("is_exclude", true)
		if is_exclude and exclude_dir_val in choose_from:
			choose_from.erase(exclude_dir_val)
		elif not is_exclude and exclude_dir_val not in choose_from:
			choose_from.append(exclude_dir_val)
	set_value_slot_as_number(slots, chosen_slot, Utility.random_list_element(choose_from))

func desc_add_text() -> String:
	return "string|<= Add [inserted_text:ComplexStringInput] to the [is_end:BoolChoice:true,end,beginning] of the slot\n" + \
	       "Separated by [separator:StringInput]"
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
	return "pos|If there is an active entity (ignoring self) at this location [invert:InvertInput:with,without] a [prop_name:PropertyInput] property"
func cmd_is_entity_at(slots: Dictionary, chosen_slot: int, prop_name: String, invert: bool) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		return false
	var at_positions: Array = slots[chosen_slot]
	if not at_positions:
		return false
	var entities_here: Array = EntityManager.get_entities_at_multiple(at_positions, slots[Slot.RED], [], false, false)
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
	return "pos|If any entity exists here with a [invert:InvertInput:true or non-zero,false or zero] [prop_name:PropertyInput] property\n" \
		+ "Excluding [exclude_entity:SlotInput:entity]"
func cmd_if_any_entity_exists(slots: Dictionary, chosen_slot: int, exclude_slot: int, invert: bool, prop_name: String) -> bool:
	if not Commands.slot_is_positions(chosen_slot):
		push_error("Slot for if any entity exists is not a positions slot: %s" % chosen_slot)
		return false
	var exclude_entity: BaseEntity = null
	if exclude_slot != -1:
		exclude_entity = slots[exclude_slot]
	var tile_positions: Array = slots[chosen_slot]
	if not tile_positions:
		var found_entities: Array = EntityManager.find_all_entities_with_truthy_property(prop_name, true, invert)
		found_entities.erase(exclude_entity)
		return found_entities.size() > 0

	for entity in EntityManager.get_entities_at_multiple(tile_positions, exclude_entity, [], true, false):
		if EntityManager.get_entity_prop_is_truthy(entity, prop_name, false) != invert:
			return true
	return false

func desc_c_can_move() -> String:
	return "entity|If the entity [invert:InvertInput:can,cannot] move this way [direction:DirectionInput]"
func cmd_c_can_move(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	var selected = slots[chosen_slot]
	var result = selected.can_i_move(resolve_direction_value(direction, slots))
	return not result if invert else result

func desc_c_get_pushed() -> String:
	return "entity|If the entity successfully gets pushed this way [direction:DirectionInput:1]\n" \
	     + "[keep_visual:BoolChoice:true,without turning,turning] to face that direction"
func cmd_c_get_pushed(slots: Dictionary, chosen_slot: int, direction: Variant, keep_visual: bool) -> bool:
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
	var got_pushed: bool = selected.start_move(facing, not keep_visual)
	return got_pushed

func desc_get_pushed_revertable() -> String:
	return "entity|If the entity successfully gets pushed this way [direction:DirectionInput:1]\n" \
	     + "(Reverted if the move that triggered this command fails)\n" \
	     + "[keep_visual:BoolChoice:true,without turning,turning] to face that direction"
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
	}
func cmd_c_is_facing(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected = slots[chosen_slot]

	var result = selected.facing == resolve_direction_value(direction, slots)
	return not result if invert else result

func desc_c_is_moving() -> Dictionary:
	return {
		"display_name": "If entity moving direction",
		"slot_type_hint": "entity",
		"template_text": "If the entity [invert:InvertInput:is,is not] moving this way [direction:DirectionInput]",
	}
func cmd_c_is_moving(slots: Dictionary, chosen_slot: int, invert: bool, direction: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		return false
	var selected = slots[chosen_slot]

	var result = selected.move_facing == resolve_direction_value(direction, slots)
	return not result if invert else result

func desc_a_die() -> Dictionary:
	return {
		"display_name": "Destroy entity (die). Uses the default dying efect for this entity type",
		"slot_type_hint": "entity",
		"template_text": "The entity dies now",
	}
func cmd_a_die(slots: Dictionary, chosen_slot: int) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		slots[chosen_slot].die()

func desc_destroy_entity_with_effect() -> String:
	return "entity|Destroy the entity playing the effect [death_eff_info:DyingEffectInput]"
func cmd_destroy_entity_with_effect(slots: Dictionary, chosen_slot: int, death_eff_info: Dictionary) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		if slots[chosen_slot].active or not slots[chosen_slot].dying:
			slots[chosen_slot].die_with_effect(death_eff_info)

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
	MapManager.replace_tiles_at_array(positions_a, tile_b)
	MapManager.replace_tiles_at_array(positions_b, tile_a)

func desc_a_set_tiles() -> String:
	return "pos|Change the tile(s) here to [tile_name:TileNameInput]"
func cmd_a_set_tiles(slots: Dictionary, chosen_slot: int, tile_name: String) -> void:
	MapManager.replace_tiles_at_array(slots[chosen_slot], MapManager.get_tile_index(tile_name))

func desc_erase_tiles() -> String:
	return "pos|Erase the tile(s) here"
func cmd_erase_tiles(slots: Dictionary, chosen_slot: int) -> void:
	MapManager.erase_tiles_and_effects_at_array(slots[chosen_slot])

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
	return new_entity

func desc_a_create_entity() -> String:
	return "pos|Create a new [entity_name:EntityNameInput:1] entity here\n" \
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
	return "entity|<= Select a new [entity_name:EntityNameInput] entity created at [pos_slot:SlotInput:pos,entity]\n" \
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
	slots[chosen_slot] = _create_entity_at(e_id, pos, facing, is_moving)


func desc_a_turn() -> String:
	return "entity,pos|Turn the entity/tile to face this way [complex_dir:DirectionInput:1]"
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

func desc_next_level_exists() -> String:
	return "none|If the next level exists"
func cmd_next_level_exists(_slots: Dictionary) -> bool:
	return true

func desc_load_next_level() -> String:
	return "none|Load the next level, with a [delay:ComplexScalarInput:default=1,step=0.1] second delay"
func cmd_load_next_level(slots: Dictionary, _slot: int, delay: Dictionary = {"type": "plain", "value": 1.0}) -> void:
	var delay_val: float = resolve_complex_scalar(delay, slots)
	GameManager.complete_for_advance()
	#GameManager.try_load_next_level(delay_val)
	prints("advancing level")
	GameManager.advance_level(delay_val)

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
				number_result = float(prop.resolve(selected, slots[Slot.RED], [selected.get_moving_position()]))
			else:
				number_result = float(prop.get_value())
			return Utility.check_comparison(number_result, compare_to_val, comparison)
	elif Commands.slot_is_positions(chosen_slot) and selected:
		return MapManager.compare_multiple_pos_prop_value(selected, slots[Slot.RED], property_name, comparison, compare_to_val)
	return false

func desc_compare_values() -> String:
	return "string,number|If the value in this slot is [comparison:OrderComparison] [compl_scalar:ComplexScalarInput]"
func cmd_compare_values(slots: Dictionary, chosen_slot: int, compl_scalar: Dictionary, comparison: String) -> bool:
	if not Commands.slot_is_value(chosen_slot):
		push_error("Invalid slot to compare values: %s" % chosen_slot)
		return false
	var compare_to_val: float = resolve_complex_scalar(compl_scalar, slots)
	var slot_value: = get_value_slot_as_float(slots, chosen_slot)
	return Utility.check_comparison(slot_value, compare_to_val, comparison)

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
	return "entity|Override the entity's move speed for the current/next movement to [speed:ComplexScalarInput]"
func cmd_override_move_speed(slots: Dictionary, chosen_slot: int, speed: Variant) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		slots[chosen_slot].set_move_speed_override(resolve_complex_scalar(speed, slots))

func desc_override_move_animation() -> String:
	return "entity|Override the entity's move animation for the current/next movement to [anim_style:MoveAnimStyleInput]"
func cmd_override_move_animation(slots: Dictionary, chosen_slot: int, anim_style: String) -> void:
	if Commands.slot_is_entity(chosen_slot) and slots[chosen_slot]:
		slots[chosen_slot].set_move_interp_override(BaseEntity.read_move_interp_style_string(anim_style))

func desc_trigger_custom_event() -> String:
	return "entity,pos|Trigger the [event_name:PropertyInput] custom event of the entity/tiles"
func cmd_trigger_custom_event(slots: Dictionary, chosen_slot: int, event_name: String) -> void:
	var pass_blue_entity: BaseEntity = null if chosen_slot == Slot.RED else slots[Slot.RED]
	if not pass_blue_entity:
		pass_blue_entity = slots[Slot.BLUE]
	if Commands.slot_is_entity(chosen_slot):
		EntityManager.resolve_entity_interaction_event(event_name, slots[chosen_slot], pass_blue_entity, [slots[chosen_slot].get_moving_position()])
	elif Commands.slot_is_positions(chosen_slot):
		MapManager.resolve_tiles_events(slots[chosen_slot], event_name, pass_blue_entity)

func desc_trigger_custom_event_for_each_entity() -> String:
	return "entity,pos|Trigger the [event_name:PropertyInput] custom event of the entity/tile for each entity ([include_self:InvertInput:excluding,including] self)\n" \
			+ "at [pos_filter_slot:SlotInput:pos] with a [truthy:BoolChoice:true,true or non-zero,false or zero] [prop_name:PropertyInput] property"
func cmd_trigger_custom_event_for_each_entity(
		slots: Dictionary, chosen_slot: int, event_name: String,
		pos_filter_slot: int, include_self: bool, truthy: bool, prop_name: String
	) -> void:
	var filter_positions: Array = slots[pos_filter_slot]
	var pos_filtered_enities: Array[BaseEntity] = []
	var self_exclude: BaseEntity = null if include_self else slots[Slot.RED]
	if filter_positions:
		pos_filtered_enities = EntityManager.get_entities_at_multiple(filter_positions, self_exclude, [], true, false)
	else:
		pos_filtered_enities = EntityManager.get_all_active_entities()
	var final_entities: Array[BaseEntity] = []
	for entity in pos_filtered_enities:
		if EntityManager.get_entity_prop_is_truthy(entity, prop_name, false) == truthy:
			final_entities.append(entity)

	if Commands.slot_is_entity(chosen_slot):
		for e in final_entities:
			EntityManager.resolve_entity_interaction_event(event_name, slots[chosen_slot], e, [slots[chosen_slot].get_moving_position()])
	elif Commands.slot_is_positions(chosen_slot):
		for e in final_entities:
			if slots[chosen_slot]:
				MapManager.resolve_tiles_events(slots[chosen_slot], event_name, e)
			else:
				MapManager.resolve_tiles_events([e.get_moving_position()], event_name, e)

func desc_trigger_custom_event_for_each_bonded_entity() -> String:
	return "entity,pos|Trigger the [event_name:PropertyInput] custom event of the entity/tile\n" \
			+ "for each entity bonded to [bonded_ref_slot:SlotInput:entity] ([include_self:BoolChoice:true,including,excluding] itself)"
func cmd_trigger_custom_event_for_each_bonded_entity(slots: Dictionary, chosen_slot: int, event_name: String, bonded_ref_slot: int, include_self: bool) -> void:
	if not Commands.slot_is_entity(chosen_slot) and not Commands.slot_is_positions(chosen_slot):
		push_error("Invalid slot to trigger custom event for each bonded entity: %s" % chosen_slot)
		return
	if not Commands.slot_is_entity(bonded_ref_slot):
		push_error("Invalid slot get bonded entities of: %s" % bonded_ref_slot)
		return
	if not slots[bonded_ref_slot]:
		return

	for inst_id in slots[chosen_slot].bond_group:
		if not include_self and inst_id == slots[bonded_ref_slot].instance_id:
			continue
		if EntityManager.has_instance(inst_id):
			var bonded_entity: BaseEntity = EntityManager.get_instance(inst_id)
			if Commands.slot_is_entity(chosen_slot):
				EntityManager.resolve_entity_interaction_event(event_name, slots[chosen_slot], bonded_entity, [bonded_entity.get_moving_position()])
			elif slots[chosen_slot]:
				MapManager.resolve_tiles_events(slots[chosen_slot], event_name, bonded_entity)
			else:
				MapManager.resolve_tiles_events([bonded_entity.get_moving_position()], event_name, bonded_entity)

func desc_delayed_custom_entity_event() -> String:
	return "entity|Trigger the [event_name:PropertyInput] custom event of the entity after a [delay:ComplexScalarInput:default=0.5,step=0.1] second delay\n" \
			+ "(If the entity is still active)"
func cmd_delayed_custom_entity_event(slots: Dictionary, chosen_slot: int, event_name: String, delay: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to trigger delayed custom entity event: %s" % chosen_slot)
		return
	if not slots[chosen_slot]:
		return
	EntityManager.add_delayed_entity_prop_event(slots[chosen_slot], event_name, resolve_complex_scalar(delay, slots))
		

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
	
func desc_show_mini_text_at() -> String:
	return "pos,entity|Temporarily show the text [text_slot:SlotInput:string,number]\n" \
	       + "[is_above:BoolChoice:true,above,at] this position/entity"
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
	elif Commands.slot_is_positions(chosen_slot):
		if not slots[chosen_slot]:
			push_error("Positions slot %s is empty" % chosen_slot)
		for tile_pos in slots[chosen_slot]:
			var message_pos: Vector2 = MapManager.get_world_pos_above(tile_pos) if is_above else MapManager.tile_to_world_position_centered(tile_pos)
			EffectsHelper.spawn_mini_text_at(mini_message, message_pos, -1, 2)
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
	return "entity|Apply the effect [effect_info:SpecialEffectInput] to the entity"
func cmd_apply_effect_to_entity(slots: Dictionary, chosen_slot: int, effect_info: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot]:
		push_error("Invalid slot or empty slot to apply effect to entity: %s" % chosen_slot)
		return
	if slots[chosen_slot]:
		var effect_color: Color = Utility.get_dict_color(effect_info, "color", Color.WHITE)
		EntityManager.apply_special_effect(slots[chosen_slot], effect_info["effect"], effect_color, effect_info.get("amount", 0.0))

func desc_entity_play_bump_effect() -> String:
	return "entity|The entity plays the short \"bump\" effect [effect_info:BumpEffectInput]"
func cmd_entity_play_bump_effect(slots: Dictionary, chosen_slot: int, effect_info: Dictionary) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot]:
		push_error("Invalid slot or empty slot to play bump effect: %s" % chosen_slot)
		return
	if slots[chosen_slot]:
		slots[chosen_slot].do_named_bump_effect(effect_info)

func desc_remove_effects_from_entity() -> String:
	return "entity|Remove all sprite effects from the entity"
func cmd_remove_effects_from_entity(slots: Dictionary, chosen_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not slots[chosen_slot]:
		push_error("Invalid slot or empty slot to remove effects from entity: %s" % chosen_slot)
		return
	if slots[chosen_slot] and not slots[chosen_slot].dying:
		EntityManager.clear_entity_special_effects(slots[chosen_slot])


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
	return "none|If the input action 1 is currently held down"
func cmd_if_action_1_is_held(_slots: Dictionary) -> bool:
	return Input.is_action_pressed(&"input_action_1")

func desc_if_action_2_is_held() -> String:
	return "none|If the input action 2 is currently held down"
func cmd_if_action_2_is_held(_slots: Dictionary) -> bool:
	return Input.is_action_pressed(&"input_action_2")

func desc_if_action_3_is_held() -> String:
	return "none|If the input action 3 is currently held down"
func cmd_if_action_3_is_held(_slots: Dictionary) -> bool:
	return Input.is_action_pressed(&"input_action_3")

func _get_directional_input_vector() -> Vector2:
	return Utility.input_vector_by_prefix("move_")

func _direction_approximately_matches(check_vec: Vector2, input_vec: Vector2) -> bool:
	if input_vec.length() < 0.2:
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

func desc_if_direction_is_not_held() -> String:
	return "none|If the directional input is not currently held"
func cmd_if_direction_is_not_held(_slots: Dictionary) -> bool:
	var directional_vec: = _get_directional_input_vector()
	return directional_vec.length() < 0.2


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
	slots[chosen_slot].start_teleport_to(from_pos + Utility.facing_vector_i(direction) * dist_val, -2, -2)

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
	return slots[chosen_slot].can_i_teleport_to(from_pos + Utility.facing_vector_i(direction) * dist_val, -2, -2)

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
	return slots[chosen_slot].start_teleport_to(from_pos + Utility.facing_vector_i(direction) * dist_val, -2, -2)

func desc_teleport_entity_to() -> String:
	return "entity|Teleport the entity to [to_position_slot:SlotInput:pos,entity]"
func cmd_teleport_entity_to(slots: Dictionary, chosen_slot: int, to_position_slot: int) -> void:
	_teleport_entity_to(slots, chosen_slot, to_position_slot)

func _teleport_entity_to(slots: Dictionary, chosen_slot: int, to_position_slot: int) -> bool:
	if not Commands.slot_has_position(to_position_slot) or not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slots to teleport entity to: %s and %s" % [chosen_slot, to_position_slot])
		return false
	if not slots[chosen_slot] or not _slot_has_single_tile_position(slots, to_position_slot):
		return false
	return slots[chosen_slot].start_teleport_to(_single_tile_position_from_slot(slots, to_position_slot), -2, -2)

func desc_if_entity_can_teleport_to() -> String:
	return "entity|If the entity can teleport to [to_position_slot:SlotInput:pos,entity]"
func cmd_if_entity_can_teleport_to(slots: Dictionary, chosen_slot: int, to_position_slot: int) -> bool:
	if not Commands.slot_has_position(to_position_slot) or not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slots to check if entity can teleport to: %s and %s" % [chosen_slot, to_position_slot])
		return false
	if not slots[chosen_slot] or not _slot_has_single_tile_position(slots, to_position_slot):
		return false
	return slots[chosen_slot].can_i_teleport_to(_single_tile_position_from_slot(slots, to_position_slot), -2, -2)

func desc_if_entity_gets_teleported_to() -> String:
	return "entity|If the entity successfully gets teleported to [to_position_slot:SlotInput:pos,entity]"
func cmd_if_entity_gets_teleported_to(slots: Dictionary, chosen_slot: int, to_position_slot: int) -> bool:
	return _teleport_entity_to(slots, chosen_slot, to_position_slot)


func desc_if_entity_is_bonded() -> String:
	return "entity|If the entity is currently bonded to other entities"
func cmd_if_entity_is_bonded(slots: Dictionary, chosen_slot: int) -> bool:
	if not Commands.slot_is_entity(chosen_slot):
		push_error("Invalid slot or empty slot to check if entity is bonded: %s" % chosen_slot)
		return false
	if not slots[chosen_slot]:
		return false
	return slots[chosen_slot].bond_group.size() > 0

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

func desc_bond_entity_with() -> String:
	return "entity|Bond the entity with this entity [bond_to_entity_slot:SlotInput:entity]"
func cmd_bond_entity_with(slots: Dictionary, chosen_slot: int, bond_to_entity_slot: int) -> void:
	if not Commands.slot_is_entity(chosen_slot) or not Commands.slot_is_entity(bond_to_entity_slot):
		push_error("Invalid slots to bond entity with: %s and %s" % [chosen_slot, bond_to_entity_slot])
		return
	if not slots[chosen_slot] or not slots[bond_to_entity_slot]:
		return
	EntityManager.merge_entity_bond_groups(slots[chosen_slot], slots[bond_to_entity_slot])

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
	all_entities = EntityManager.filter_entities_by_property(prop_name, all_entities, not truthy)
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


func desc_is_entity_tailing() -> String:
	return "entity|If the entity is currently [tailing:BoolChoice:true,tailing another entity,being tailed by another entity]"
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

func desc_select_tailing_entity() -> String:
	return "entity|<= Select an entity [tail_parent:BoolChoice:true,being tailed by,that is tailing] [ref_entity_slot:SlotInput:entity]"
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
		slots[chosen_slot] = EntityManager.get_instance(slots[chosen_slot].tailing.instance_id)
	else:
		var tailing_entities: Array[BaseEntity] = EntityManager.get_direct_tailing_entities(slots[ref_entity_slot])
		if tailing_entities.size() == 0:
			slots[chosen_slot] = null
			return
		slots[chosen_slot] = tailing_entities[0]


func desc_play_named_sfx() -> String:
	return "none|Play the [sfx_name:SFXNameInput] sound effect [do_restart:BoolChoice:false,restarting if already playing,if it isn't already playing]"
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