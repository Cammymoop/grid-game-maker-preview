class_name BaseConditionalScript
extends Node

const SlotSelectorButton = preload("res://src/GameEditor/SlotSelectorButton.gd")

const CondResolver = preload("res://src/Singletons/conditionals_v3.gd")
const Slot = Commands.Slot

const CMD_FUNC_PREFIX = "cmd_"
const DESC_FUNC_PREFIX = "desc_"

var cond_resolver: CondResolver = null

class CommandError extends Object:
	var message: String

func list_commands() -> Array[Dictionary]:
	var cmd_infos: Array[Dictionary] = []
	for method_info in get_method_list():
		var method_name = method_info.name
		if method_name.begins_with(CMD_FUNC_PREFIX):
			var cmd_name = method_name.trim_prefix(CMD_FUNC_PREFIX)
			var custom_meta_info: Dictionary = get_command_meta_info(cmd_name)
			var meta_info: Dictionary = {
				"name": cmd_name,
				"args": get_command_arg_list(cmd_name, method_info),
				"template_text": "",
				"slot_type_hint": "all",
			}
			meta_info.merge(custom_meta_info, true)
			meta_info["display_name"] = get_command_display_name(cmd_name, custom_meta_info)
			if not meta_info.has("tooltip") and meta_info.get("template_text", ""):
				meta_info["tooltip"] = _convert_template_to_tooltip(meta_info["template_text"])
			cmd_infos.append(meta_info)
	return cmd_infos

# override this to customize how command name is generated
func get_command_display_name(cmd_name: String, custom_meta_info: Dictionary) -> String:
	if custom_meta_info.get("display_name", ""):
		return custom_meta_info["display_name"]
	return cmd_name.capitalize()

func get_command_meta_info(cmd: String) -> Dictionary:
	if not has_method(DESC_FUNC_PREFIX + cmd):
		return {
			"template_text": cmd.capitalize(),
		}
	var result: Variant = Callable(self, DESC_FUNC_PREFIX + cmd).call()
	if typeof(result) == TYPE_DICTIONARY:
		return result
	elif typeof(result) == TYPE_STRING:
		var info: Dictionary = {
			"template_text": result,
		}
		if result.contains("|"):
			info["slot_type_hint"] = result.split("|", true, 1)[0]
			info["template_text"] = result.split("|", true, 1)[1]
		if cmd.begins_with("c_") and not cmd.begins_with("c_get_"):
			info["non_action"] = true
		elif cmd.begins_with("a_"):
			info["non_condition"] = true
		return info
	else:
		push_error("Invalid result type for command meta info: %s (for command %s)" % [result, cmd])
		return {}

func _convert_template_to_tooltip(template_text: String) -> String:
	var regex: = RegEx.new()
	regex.compile("\\[([^]:]+)(:[^]]*)?\\]")
	var matches: = regex.search_all(template_text)
	matches.reverse()
	var tooltip: = template_text
	for arg_match in matches:
		tooltip = tooltip.substr(0, arg_match.get_start(0)) + "[%s]" % [arg_match.get_string(1)] + tooltip.substr(arg_match.get_end(0))
	return tooltip

func get_command_arg_list(cmd: String, method_info: Dictionary) -> Array[String]:
	if not has_method(CMD_FUNC_PREFIX + cmd):
		return []
	var raw_args: Array = method_info.args.slice(2)
	var arg_names: Array[String] = []
	for arg in raw_args:
		arg_names.append(arg.name)
	return arg_names

func set_cond_resolver(cond: CondResolver) -> void:
	cond_resolver = cond

func call_command(cmd: String, slots: Dictionary, full_call_str: String) -> Variant:
	if not has_method(CMD_FUNC_PREFIX + cmd):
		return {"result": false, "quit": false, "error": "command not found: %s" % [cmd]}

	var args: Array = call_string_to_args(full_call_str)
	return call_command_with_args(cmd, slots, args)

func call_command_with_args(cmd: String, slots: Dictionary, args: Array) -> Variant:
	var callable = Callable(self, CMD_FUNC_PREFIX + cmd)
	if not callable.is_valid():
		var err_str = "internal error: Command Callable is not valid: %s" % [CMD_FUNC_PREFIX + cmd]
		return {"result": false, "quit": false, "error": err_str}

	var cmd_result
	if callable.get_argument_count() == 1:
		cmd_result = callable.call(slots)
	else:
		cmd_result = callable.bindv([slots] + args).call()

	if cmd_result is CommandError:
		return {"result": false, "quit": false, "error": cmd_result.message}
	else:
		return cmd_result

# --- helpers ---

func call_string_to_args(call_str: String) -> Array:
	if not call_str.contains("::"):
		return []
	return parse_args(call_str.rsplit("::", true, 1)[-1])

func parse_args(args_raw: String) -> Array:
	var args_json_decode: Variant = JSON.parse_string(args_raw)
	if typeof(args_json_decode) == TYPE_ARRAY:
		return JSON.to_native(args_json_decode, false)
	return []

func get_rel_position_arg(arg: Variant, slots: Dictionary) -> Vector2i:
	if typeof(arg) == TYPE_VECTOR2:
		arg = Vector2i(arg)
	var context_pos = get_context_position(slots)
	if not typeof(arg) == TYPE_VECTOR2I:
		return context_pos
	return context_pos + arg

func get_position_arg(base_value: Variant, slots: Dictionary, is_relative: bool = true) -> Vector2i:
	if is_relative:
		return get_rel_position_arg(base_value, slots)
	elif typeof(base_value) == TYPE_VECTOR2I or typeof(base_value) == TYPE_VECTOR2:
		return Vector2i(base_value)
	else:
		return Vector2i.ZERO

func get_context_position(slots: Dictionary) -> Vector2i:
	if slots[Slot.RED]:
		return slots[Slot.RED].get_moving_position()
	elif slots[Slot.GREY]:
		return slots[Slot.GREY][0]
	else:
		return Vector2i.ZERO

func resolve_variant_direction_value(dir_value: Variant, slots: Dictionary) -> int:
	if typeof(dir_value) == TYPE_INT:
		return resolve_direction_value(dir_value, slots)
	elif typeof(dir_value) == TYPE_DICTIONARY:
		return resolve_complex_direction(dir_value, slots)
	else:
		push_error("Invalid direction value type: %s" % [typeof(dir_value)])
		return 0

func resolve_direction_value(dir_value: int, slots: Dictionary) -> int:
	return Utility.resolve_full_direction_to_facing(dir_value, slots)

func resolve_complex_direction(complex_direction: Dictionary, slots: Dictionary) -> int:
	if complex_direction["type"] == "plain":
		return resolve_direction_value(complex_direction["direction"], slots)
	elif complex_direction["type"] == "slot_reference":
		var slot_facing_val: int = Utility.valid_direction_or(slots[complex_direction["slot_id"]], 0)
		var relative_bits: int = complex_direction.get("direction", 0) & ~Utility.DIR_MASK
		return resolve_direction_value(relative_bits | slot_facing_val, slots)
	else:
		push_error("Invalid complex direction type: %s" % [complex_direction["type"]])
		return 0

func resolve_complex_scalar(complex_scalar: Dictionary, slots: Dictionary) -> float:
	if complex_scalar["type"] == "plain":
		return complex_scalar["value"]
	elif complex_scalar["type"] == "slot_value":
		var chosen_slot: int = complex_scalar["slot_id"]
		if Commands.slot_is_argument(chosen_slot):
			push_error("Arguments not implemented")
			return 0
		if Commands.slot_is_scalar(chosen_slot) or Commands.slot_is_string(chosen_slot):
			return float(slots[chosen_slot])
		else:
			push_error("Invalid complex scalar slot: %s" % [chosen_slot])
			return 0
	else:
		push_error("Invalid complex scalar type: %s" % [complex_scalar["type"]])
		return 0

func set_tiles_to_facing(slots: Dictionary, slot_id: int, facing: int) -> void:
	if not Commands.slot_is_positions(slot_id):
		push_warning("set_tiles_to_facing: Slot is not a tile position: %s" % [slot_id])
		return
	
	for pos in slots[slot_id]:
		MapManager.set_tile_facing_at(pos, facing)

func set_value_slot_as_number(slots: Dictionary, slot_id: int, value: float) -> void:
	if Commands.slot_is_int(slot_id):
		slots[slot_id] = int(value)
	elif Commands.slot_is_float(slot_id):
		slots[slot_id] = float(value)
	elif Commands.slot_is_string(slot_id):
		if Utility.is_float_integer(value):
			slots[slot_id] = str(roundi(value))
		else:
			slots[slot_id] = str(value)
	else:
		push_error("Invalid slot to put a number into: %s" % slot_id)

func get_value_slot_as_int(slots: Dictionary, slot_id: int) -> int:
	if Commands.slot_is_scalar(slot_id):
		return int(slots[slot_id])
	elif Commands.slot_is_string(slot_id):
		var str_value: String = slots[slot_id]
		if not str_value.is_valid_float():
			return 0
		return roundi(float(str_value))
	else:
		push_error("Non-value slot or get int not implemented: %s" % slot_id)
		return 0

func get_value_slot_as_float(slots: Dictionary, slot_id: int) -> float:
	if Commands.slot_is_scalar(slot_id):
		return float(slots[slot_id])
	elif Commands.slot_is_string(slot_id):
		var str_value: String = slots[slot_id]
		if not str_value.is_valid_float():
			return 0
		return float(str_value)
	else:
		push_error("Non-value slot or get float not implemented: %s" % slot_id)
		return 0

func get_value_slot_as_string(slots: Dictionary, slot_id: int) -> String:
	if Commands.slot_is_scalar(slot_id):
		return str(slots[slot_id])
	elif Commands.slot_is_string(slot_id):
		return slots[slot_id]
	else:
		push_error("Non-value slot or get string not implemented: %s" % slot_id)
		return ""

func get_complex_string_value(complex_string: Dictionary, slots: Dictionary) -> String:
	if complex_string["type"] == "plain":
		return str(complex_string["value"])
	elif complex_string["type"] == "slot_value":
		var chosen_slot: int = complex_string["slot_id"]
		if not Commands.slot_is_value(chosen_slot):
			push_error("Invalid complex string slot: %s" % [chosen_slot])
			return ""
		else:
			return get_value_slot_as_string(slots, chosen_slot)
	else:
		push_error("Invalid complex string type: %s" % [complex_string["type"]])
		return ""

func get_complex_or_string_as_string(complex_or_string: Variant, slots: Dictionary) -> String:
	if typeof(complex_or_string) == TYPE_STRING:
		return complex_or_string
	if not typeof(complex_or_string) == TYPE_DICTIONARY:
		push_error("Invalid type for complex or string: %s" % [typeof(complex_or_string)])
		return ""
	return get_complex_string_value(complex_or_string, slots)

func _get_id_of_entity_name(entity_name: String) -> int:
	if not EntityManager.entity_name_exists(entity_name):
		return -1
	return EntityManager.get_entity_index(entity_name)

func get_id_of_str_or_complex_entity_name(str_or_complex_entity_name: Variant, slots: Dictionary) -> int:
	if typeof(str_or_complex_entity_name) == TYPE_STRING:
		return _get_id_of_entity_name(str_or_complex_entity_name)
	if not typeof(str_or_complex_entity_name) == TYPE_DICTIONARY:
		push_error("Invalid type for str or complex entity name: %s" % [typeof(str_or_complex_entity_name)])
		return -1
	return get_id_of_complex_entity_name(str_or_complex_entity_name, slots)

func get_id_of_complex_entity_name(complex_entity_name: Dictionary, slots: Dictionary) -> int:
	var name_str: String = get_complex_string_value(complex_entity_name, slots)
	return _get_id_of_entity_name(name_str)

func get_single_position_from_slot(slot_id: int, slots: Dictionary, fallback_pos: Vector2i = Vector2i.ZERO) -> Vector2i:
	if not Commands.slot_has_position(slot_id):
		push_error("Invalid slot to get single position from: %s" % [slot_id])
		return fallback_pos
	elif not slots[slot_id]:
		return fallback_pos
	if Commands.slot_is_positions(slot_id):
		return slots[slot_id][0]
	else:
		return slots[slot_id].get_moving_position()

func resolve_complex_compat_prop_value(complex_prop_value: Variant, slots: Dictionary) -> Variant:
	if typeof(complex_prop_value) == TYPE_STRING:
		return Utility.property_value_from_string(complex_prop_value)
	elif typeof(complex_prop_value) == TYPE_DICTIONARY:
		return resolve_complex_prop_value(complex_prop_value, slots)
	else:
		push_error("Invalid complex prop value type: %s" % [typeof(complex_prop_value)])
		return 0

func resolve_complex_prop_value(complex_prop_value: Dictionary, slots: Dictionary) -> Variant:
	if complex_prop_value["type"] == "plain":
		return complex_prop_value["value"]
	elif complex_prop_value["type"] == "slot_value":
		var chosen_slot: int = complex_prop_value["slot_id"]
		if Commands.slot_is_value(chosen_slot):
			return slots[chosen_slot]
		elif Commands.slot_is_argument(chosen_slot):
			push_error("Arguments not implemented")
			return 0
		else:
			push_error("Invalid complex prop value slot: %s" % [chosen_slot])
			return 0
	else:
		push_error("Invalid complex prop value native type: %s" % [complex_prop_value["type"]])
		return 0

func get_entity_from_slot(slot_id: int, slots: Dictionary) -> BaseEntity:
	if slot_id == SlotSelectorButton.NONE_SLOTS:
		return null
	if not Commands.slot_is_entity(slot_id):
		push_error("Invalid slot to get entity from: %s" % [slot_id])
		return null
	return slots[slot_id]

func resolve_complex_string(complex_string: Dictionary, slots: Dictionary) -> String:
	if complex_string["type"] == "plain":
		return str(complex_string["value"])
	elif complex_string["type"] == "slot_value":
		var chosen_slot: int = complex_string["slot_id"]
		if Commands.slot_is_value(chosen_slot):
			return get_value_slot_as_string(slots, chosen_slot)
		else:
			push_error("Invalid complex string slot: %s" % [chosen_slot])
			return ""
	else:
		push_error("Invalid complex string type: %s" % [complex_string["type"]])
		return ""

func resolve_complex_multi_type_val(complex_multi_type_val: Dictionary, slots: Dictionary) -> Variant:
	if complex_multi_type_val["type"] == "plain":
		return complex_multi_type_val["value"]
	elif complex_multi_type_val["type"] == "slot_value":
		var chosen_slot: int = complex_multi_type_val["slot_id"]
		if Commands.slot_is_value(chosen_slot):
			return slots[chosen_slot]
		else:
			push_error("Invalid complex multi type value slot: %s" % [chosen_slot])
			return 0
	else:
		push_error("Invalid complex multi type value type: %s" % [complex_multi_type_val["type"]])
		return 0