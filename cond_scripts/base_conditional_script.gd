class_name BaseConditionalScript
extends Node

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
			var meta_info: Dictionary = {
				"name": cmd_name,
				"display_name": get_command_display_name(cmd_name),
				"args": get_command_arg_list(cmd_name, method_info),
				"template_text": "",
				"slot_type_hint": "all",
			}
			meta_info.merge(get_command_meta_info(cmd_name), true)
			cmd_infos.append(meta_info)
	return cmd_infos

func get_command_display_name(cmd_name: String) -> String:
	return cmd_name.capitalize()

func get_command_meta_info(cmd: String) -> Dictionary:
	if not has_method(DESC_FUNC_PREFIX + cmd):
		return {
			"template_text": cmd.capitalize(),
		}
	var result: Variant = Callable(self, DESC_FUNC_PREFIX + cmd).call()
	if typeof(result) == TYPE_STRING:
		if result.contains("|"):
			return {
				"slot_type_hint": result.split("|", true, 1)[0],
				"template_text": result.split("|", true, 1)[1],
			}
		else:
			return {
				"template_text": result,
			}
	elif typeof(result) == TYPE_DICTIONARY:
		return result
	else:
		push_error("Invalid result type for command meta info: %s (for command %s)" % [result, cmd])
		return {}

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
	return slots[Slot.THIS_TILE]

func resolve_direction_value(dir_value: int, slots: Dictionary) -> int:
	return Utility.resolve_full_direction_to_facing(dir_value, slots)

func resolve_complex_direction(complex_direction: Dictionary, slots: Dictionary) -> int:
	if complex_direction["type"] == "plain":
		return resolve_direction_value(complex_direction["direction"], slots)
	elif complex_direction["type"] == "slot_reference":
		var referenced_facing: int = slots[complex_direction["slot_id"]]
		return resolve_direction_value(complex_direction.get("direction", 0) | referenced_facing, slots)
	else:
		push_error("Invalid complex direction type: %s" % [complex_direction["type"]])
		return 0

func set_tiles_to_facing(slots: Dictionary, slot_id: int, facing: int) -> void:
	if not Commands.slot_is_positions(slot_id):
		push_warning("set_tiles_to_facing: Slot is not a tile position: %s" % [slot_id])
		return
	
	for pos in slots[slot_id]:
		MapManager.set_tile_facing_at(pos, facing)