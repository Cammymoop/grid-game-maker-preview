extends Node

const CondResolver = preload("res://src/Singletons/conditionals_v3.gd")

var cond_resolver: CondResolver = null

func list_commands() -> Array[Dictionary]:
    var cmd_infos: Array[Dictionary] = []
    for method_info in get_method_list():
        var method_name = method_info.name
        if method_name.begins_with("cmd_"):
            cmd_infos.append({"name": method_name.trim_prefix("cmd_")})
    return cmd_infos

func set_cond_resolver(cond: CondResolver) -> void:
    cond_resolver = cond

func call_command(command_name: String, slots: Dictionary, full_call_name: String) -> Dictionary:
    if not has_method(command_name):
        print_debug("basic default: command not found: %s" % [command_name])
        return {"result": false, "quit": false}
    var split_call: PackedStringArray = full_call_name.split(":", false, 1)
    var args: Array = []
    if len(split_call) > 1:
        args = Array(split_call[1].split(",", true))

    var callable = Callable(self, "cmd_" + command_name)
    if callable.get_argument_count() == 1:
        return callable.call(slots)
    else:
        return callable.callv([slots] + args)

# COMMANDS

func cmd_select_defaults(slots: Dictionary) -> void:
    cond_resolver.select_reset(slots)

func cmd_quit(_slots) -> Dictionary:
    return {"result": true, "quit": true}