extends Node

const CondResolver = preload("res://src/Singletons/conditionals_v3.gd")
const Slot = Commands.Slot

var cond_resolver: CondResolver = null

func list_conditionals() -> Array[Dictionary]:
	var cmd_infos: Array[Dictionary] = []
	for method_info in get_method_list():
		var method_name = method_info.name
		if method_name.begins_with("cmd_"):
			cmd_infos.append({"name": method_name.trim_prefix("cmd_")})
	return cmd_infos

func set_cond_resolver(cond: CondResolver) -> void:
	cond_resolver = cond

func call_command(resolver, command_name: String, slots: Dictionary, full_call_name: String) -> Dictionary:
	cond_resolver = resolver
	var parts = command_name.split(".", false, 1)
	var cmd = parts[1] if parts.size() > 1 else command_name
	if not has_method("cmd_" + cmd):
		print_debug("basic default: command not found: %s" % [cmd])
		return {"result": false, "quit": false}

	var args: Array = []
	var colon_idx = full_call_name.find(":")
	if colon_idx >= 0:
		args = Array(full_call_name.substr(colon_idx + 1).split(",", true))

	var callable = Callable(self, "cmd_" + cmd)
	var raw_result
	if callable.get_argument_count() == 1:
		raw_result = callable.call(slots)
	else:
		raw_result = callable.callv([slots] + args)

	if typeof(raw_result) == TYPE_BOOL:
		return {"result": raw_result, "quit": false}
	elif typeof(raw_result) == TYPE_DICTIONARY:
		return raw_result
	else:
		return {"result": true, "quit": false}

# --- helpers ---

func _slot_val(slots: Dictionary, slot_str: String):
	return slots[int(slot_str)]

func _resolve_direction(dir_str: String, entity) -> int:
	if Utility.is_absolute_direction(dir_str):
		return Utility.direction_to_facing(dir_str)
	if entity:
		return Utility.resolve_relative_direction(dir_str, entity.facing)
	return 0

func _get_int(input: String) -> int:
	match input:
		"level_x":     return int(MapManager.get_map_size().position.x)
		"level_y":     return int(MapManager.get_map_size().position.y)
		"level_width": return int(MapManager.get_map_size().size.x)
		"level_height":return int(MapManager.get_map_size().size.y)
	return int(input)

# --- COMMANDS ---

func cmd_select_defaults(slots: Dictionary) -> void:
	cond_resolver.select_reset(slots)

func cmd_quit(_slots: Dictionary) -> Dictionary:
	return {"result": true, "quit": true}

# Select: args = slot_str, tile_name
func cmd_select_tiles_named(slots: Dictionary, slot_str: String, tile_name: String) -> void:
	var tindex = MapManager.get_tile_index(tile_name)
	slots[int(slot_str)] = MapManager.get_all_positions_of_tile(tindex)

# Select: args = slot_str, rel_x, rel_y, width, height
func cmd_select_tiles_rect(slots: Dictionary, slot_str: String, x: String, y: String, w: String, h: String) -> void:
	var origin = slots[Slot.THIS_TILE]
	var top = origin + Vector2(_get_int(x), _get_int(y))
	var positions = []
	for xi in range(_get_int(w)):
		for yi in range(_get_int(h)):
			positions.append(top + Vector2(xi, yi))
	slots[int(slot_str)] = positions

# Condition: args = slot_str, invert, property_name
func cmd_c_has_property(slots: Dictionary, slot_str: String, invert: String, property_name: String) -> bool:
	var selected = _slot_val(slots, slot_str)
	var slot_id = int(slot_str)
	var result: bool
	if Commands.slot_is_entity(slot_id):
		result = EntityManager.entity_has_property(selected, property_name)
	else:
		if not selected or len(selected) < 1:
			result = false
		else:
			result = MapManager.get_tile_property_at(selected[0], property_name) != null
	prints("has property:", slot_str, property_name, "result:", result)
	return not result if invert == "true" else result

# Condition: args = slot_str, invert, check_name
func cmd_c_has_name(slots: Dictionary, slot_str: String, invert: String, check_name: String) -> bool:
	var selected = _slot_val(slots, slot_str)
	var result = selected.entity_name == check_name
	return not result if invert == "true" else result

# Condition: args = slot_str, invert, direction
func cmd_c_can_move(slots: Dictionary, slot_str: String, invert: String, direction: String) -> bool:
	var selected = _slot_val(slots, slot_str)
	var facing = _resolve_direction(direction, selected)
	var result = selected.can_i_move(facing)
	return not result if invert == "true" else result

# Condition/Action: push selected entity in direction, returns whether move succeeded
# args = slot_str, keep_visual, direction
func cmd_c_get_pushed(slots: Dictionary, slot_str: String, keep_visual: String, direction: String) -> bool:
	var selected = _slot_val(slots, slot_str)
	if selected.moving:
		return false
	var blue_entity = slots[Slot.BLUE]
	selected.set_current_speed(blue_entity.steps_per_tile)
	var facing = _resolve_direction(direction, selected)
	var visual_turn = keep_visual != "true"
	return selected.start_move(facing, visual_turn)

# Action: args = slot_str
func cmd_a_die(slots: Dictionary, slot_str: String) -> void:
	_slot_val(slots, slot_str).die()

# Action: args = slot_str, direction
func cmd_a_move(slots: Dictionary, slot_str: String, direction: String) -> void:
	var selected = _slot_val(slots, slot_str)
	selected.start_move(_resolve_direction(direction, selected))

# Action: args = slot_str, tile1_name, tile2_name  (swaps all tile1 ↔ tile2 within the slot's positions)
func cmd_a_swap_tiles(slots: Dictionary, slot_str: String, tile1: String, tile2: String) -> void:
	var position_filter = _slot_val(slots, slot_str)
	var tid_0 = MapManager.get_tile_index(tile1)
	var tid_1 = MapManager.get_tile_index(tile2)
	var positions_a = MapManager.get_all_positions_of_tile(tid_0, position_filter)
	var positions_b = MapManager.get_all_positions_of_tile(tid_1, position_filter)
	MapManager.replace_tiles_at_array(positions_a, tid_1)
	MapManager.replace_tiles_at_array(positions_b, tid_0)

# Action: args = slot_str, tile_name  (sets all positions in slot to the given tile)
func cmd_a_set_tiles(slots: Dictionary, slot_str: String, tile: String) -> void:
	prints("set tiles:", slot_str, tile)
	var selected = _slot_val(slots, slot_str)
	MapManager.replace_tiles_at_array(selected, MapManager.get_tile_index(tile))

# Action: args = slot_str, property_name, value
func cmd_a_set_property(slots: Dictionary, slot_str: String, property_name: String, value: String) -> void:
	_slot_val(slots, slot_str).set_local_property(property_name, value)

# Action: args = slot_str, property_name, amount
func cmd_a_property_add(slots: Dictionary, slot_str: String, property_name: String, amount: String) -> void:
	var selected = _slot_val(slots, slot_str)
	var existing = 0
	if selected.has_local_property(property_name):
		existing = int(selected.get_local_property(property_name))
	selected.set_local_property(property_name, existing + int(amount))

# Action: args = slot_str, property_name, amount [, "true" to auto-remove when <= 0]
func cmd_a_property_subtract(slots: Dictionary, slot_str: String, property_name: String, amount: String, autoremove: String = "false") -> void:
	var selected = _slot_val(slots, slot_str)
	var existing = 0
	if selected.has_local_property(property_name):
		existing = int(selected.get_local_property(property_name))
	var new_val = existing - int(amount)
	selected.set_local_property(property_name, new_val)
	if autoremove == "true" and new_val <= 0:
		selected.remove_local_property(property_name)

# Action: args = slot_str, property_name
func cmd_a_remove_property(slots: Dictionary, slot_str: String, property_name: String) -> void:
	_slot_val(slots, slot_str).remove_local_property(property_name)

func cmd_a_save_checkpoint(_slots: Dictionary) -> void:
	GameManager.save_checkpoint()

func cmd_a_load_checkpoint(_slots: Dictionary) -> void:
	GameManager.load_checkpoint()

