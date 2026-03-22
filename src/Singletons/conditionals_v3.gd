extends Node

const Slot = Commands.Slot
const CC = Commands.CC

const V3_CMD_MAP: Dictionary = {
    CC.SELECT_DEFAULTS: "select_defaults",
    CC.SELECT_DEFAULT: "",
    CC.SELECT_NEAREST_ENTITY: "",
    CC.SELECT_ENTITY_AT: "",
    CC.SELECT_TILES_NAMED: "",
    CC.SELECT_TILES_RECT: "",
	
	# Conditions
    CC.C_HAS_PROPERTY: "",
    CC.C_HAS_NAME: "",
    CC.C_CAN_MOVE: "",
    CC.C_GET_PUSHED: "",
	
	# Actions
    CC.A_DIE: "",
    CC.A_MOVE: "",
    CC.A_SWAP_TILES: "",
    CC.A_SET_TILES: "",
    CC.A_QUIT: "quit",
    CC.A_SET_PROPERTY: "",
    CC.A_PROPERTY_ADD: "",
    CC.A_PROPERTY_SUBTRACT: "",
    CC.A_REMOVE_PROPERTY: "",
	
    CC.A_SAVE_CHECKPOINT: "",
    CC.A_LOAD_CHECKPOINT: "",
	
    CC.A_CREATE_ENTITY: "",
    CC.A_TURN: "",
    CC.A_SEND_SIGNAL: "",
}

enum ScriptType { GDSCRIPT, ORCHESTRATOR }

var scripts: Array[Dictionary] = []
var all_conditionals: Dictionary[String, Dictionary] = {}

const DEFAULT_SCRIPTS: = [ "basic_default" ]

var verbose = false

var reset_slots: Dictionary = {}

func _ready() -> void:
    for script_name in DEFAULT_SCRIPTS:
        add_conditional_script(script_name, ScriptType.GDSCRIPT, null)

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

func slots_copy(slots: Dictionary) -> Dictionary:
    var slots_duplicate = slots.duplicate()
    slots[Slot.GREY] = slots[Slot.GREY].duplicate()
    slots[Slot.BLACK] = slots[Slot.BLACK].duplicate()
    return slots_duplicate

func add_conditional_script(script_name: String, script_type: int, script_inst: Object = null) -> void:
    if not script_inst:
        if script_type == ScriptType.GDSCRIPT:
            script_inst = load(_find_gdscript_file(script_name)).new()
    add_conditional_script_info({
        "name": script_name,
        "type": script_type,
        "instance": script_inst,
    })

func _find_gdscript_file(script_name: String) -> String:
    return "res://cond_scripts/" + script_name + ".gd"

func add_conditional_script_info(script_info: Dictionary) -> void:
    var script_index = scripts.size()
    scripts.append(script_info)
    register_script_conditionals(script_index)

func register_script_conditionals(script_index: int) -> void:
    var script_inst = scripts[script_index]["instance"]
    if script_inst.has_method("set_cond_resolver"):
        script_inst.set_cond_resolver(self)
    var script_name = scripts[script_index]["name"]
    for conditional in script_inst.list_conditionals():
        var full_name = script_name + "." + conditional["name"]
        if full_name in all_conditionals:
            push_warning("Overriding registered conditional: %s" % [full_name])
        all_conditionals[full_name] = conditional.duplicate()
        all_conditionals[full_name]["script_index"] = script_index

func conditions_collapse(condition_stack: Array) -> bool:
    var result = true
    for i_res in condition_stack:
        if not i_res:
            return i_res
        # Just top-most value for now
        result = i_res
    return result

func resolve_conditional(conditional: Dictionary, slots: Dictionary) -> Dictionary:
    reset_slots = slots_copy(slots)
    var overall_result = {"result": true, "quit": false}
    
    if verbose:
        for key: String in conditional:
            if key == "v":
                continue
            var other_keys: Array[String] = []
            if key != "conditions" and not key.begins_with("when "):
                other_keys.append(key)
            print_debug("ConditionalV3, found other keys: %s" % [other_keys])

    var condition_stack = []
    for cond_call in conditional.get("conditions", []):
        if overall_result["quit"]:
            break
        if typeof(cond_call) != TYPE_STRING:
            push_error("Conditional command is not a string: " + str(cond_call))
            continue
        if cond_call == "and" or cond_call == "or":
            var a = condition_stack.pop_back()
            var b = condition_stack.pop_back()
            condition_stack.append(a and b if cond_call == "and" else a or b)
        elif cond_call == "not":
            var top = condition_stack.pop_back()
            condition_stack.append(not top)
        else:
            var cmd_result = call_conditional_command(cond_call, slots)
            if cmd_result['quit']:
                overall_result["quit"] = true
            condition_stack.append(cmd_result["result"])
    
    if len(condition_stack) > 1:
        overall_result["result"] = conditions_collapse(condition_stack)
    elif len(condition_stack) == 1:
        overall_result["result"] = condition_stack[0]
    
    if overall_result["quit"]:
        return overall_result
    
    var cases: Array[String] = []
    for key: String in conditional:
        if key.begins_with("when "):
            cases.append(key.trim_prefix("when "))
    
    for case in cases:
        if overall_result["quit"]:
            break
        if not check_against_case(case, overall_result["result"]):
            continue
        var cmds: Array = conditional["when " + case]
        for cmd in cmds:
            var cmd_result = call_conditional_command(cmd, slots)
            if cmd_result['quit']:
                overall_result["quit"] = true

    return overall_result

func check_against_case(case: String, result_val: Variant) -> bool:
    case = case.strip_edges()
    if case == "always":
        return true

    if case in ["true", "false"]:
        return bool(result_val) == (case == "true")
    elif typeof(result_val) == TYPE_BOOL:
        return false
    
    if case.begins_with("'"):
        return case.trim_prefix("'").trim_suffix("'") == str(result_val).strip_edges()
    
    # no complex expressions or inequalities yet
    
    if not case.is_valid_float() or (typeof(result_val) == TYPE_STRING and not result_val.is_valid_float()):
        return false
    
    return float(case) == float(result_val)

func call_conditional_command(command_name: String, slots: Dictionary) -> Dictionary:
    if not command_name:
        push_error("Conditional command name is empty")
        return {"result": false, "quit": true}

    var main_name = command_name.split(":")[0]
    if not all_conditionals.has(main_name):
        push_error("Conditional Script not found for command: %s (%s)" % [main_name, command_name])
        return {"result": false, "quit": true}

    var raw_result = _call_conditional_command(main_name, command_name, slots)
    var result_type = typeof(raw_result)
    if result_type == TYPE_BOOL:
        return {"result": raw_result, "quit": false}
    elif result_type in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
        return {"result": raw_result, "quit": false}
    elif result_type == TYPE_DICTIONARY:
        if not raw_result:
            push_warning("command returned empty dictionary: %s" % [command_name])
        return raw_result
    else:
        # default return in case of command with no return value etc
        return {"result": true, "quit": false}

func _call_conditional_command(main_cmd_name: String, full_call_name: String, slots: Dictionary) -> Dictionary:
    var script_index = all_conditionals[main_cmd_name]["script_index"]
    var script_inst = scripts[script_index]["instance"]
    return script_inst.call_command(self, main_cmd_name, slots, full_call_name)

func select_reset(slots: Dictionary) -> void:
    slots.clear()
    slots.merge(reset_slots)
