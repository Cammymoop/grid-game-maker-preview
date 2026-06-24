extends Node

const Slot = Commands.Slot
const CC = Commands.CC

const V3_CMD_MAP: Dictionary = {
    CC.SELECT_DEFAULTS: "select_defaults",
    CC.SELECT_DEFAULT: "",
    CC.SELECT_NEAREST_ENTITY: "",
    CC.SELECT_ENTITY_AT: "",
    CC.SELECT_TILES_NAMED: "select_tiles_named",
    CC.SELECT_TILES_RECT: "select_tiles_rect",

    # Conditions
    CC.C_HAS_PROPERTY: "c_has_property",
    CC.C_HAS_NAME: "c_is_named",
    CC.C_CAN_MOVE: "c_can_move",
    CC.C_GET_PUSHED: "c_get_pushed",
    
    CC.C_IS_FACING: "c_is_facing",

    # Actions
    CC.A_DIE: "a_die",
    CC.A_MOVE: "a_move",
    CC.A_SWAP_TILES: "a_swap_tiles",
    CC.A_SET_TILES: "a_set_tiles",
    CC.A_QUIT: "quit",
    CC.A_SET_PROPERTY: "a_set_property",
    CC.A_PROPERTY_ADD: "a_property_add",
    CC.A_PROPERTY_SUBTRACT: "a_property_subtract",
    CC.A_REMOVE_PROPERTY: "a_remove_property",

    CC.A_SAVE_CHECKPOINT: "a_save_checkpoint",
    CC.A_LOAD_CHECKPOINT: "a_load_checkpoint",

    CC.A_CREATE_ENTITY: "a_create_entity",
    CC.A_TURN: "a_turn",
    CC.A_SEND_SIGNAL: "",
}

const all_events: Array[String] = [
	"blocks",
	"move_onto", "move_off_of",
    "i_move_onto", "i_move_onto_tile",
    "i_move_off_of", "i_move_off_of_tile",

	"finish_move_onto", "i_finish_move_onto",
	"finish_move_onto_tile", "i_finish_move_onto_tile",

    "half_moved_onto", "half_moved_off_of",
    "half_moved_onto_tile", "half_moved_off_of_tile",

    "covered_by_[property]", "uncovered_by_[property]",
	"when_signal_[signal]",

	"post_move_onto", "post_move_off_of",
	"post_move",
    
    "do_action_1", "do_action_2", "do_action_3",
    
    "was_blocked",

	"idle_update",
    "idle_on",
	"dying",
    
    "started_tailing",
    "stopped_tailing",
    
    "joined_bond_group",
    "left_bond_group",
    
    "turn_start",
    "pre_turn_end",
    "turn_end",
]

const NO_OTHER_EVENTS: = [
	"i_finish_move_onto_tile", "i_move_off_of_tile", "i_move_onto_tile", "half_moved_off_of_tile", "half_moved_onto_tile",
    "post_move", "idle_update",
    "joined_bond_group", "left_bond_group",
    "dying", "do_action_1", "do_action_2", "do_action_3",
]

const EMPTY_CONDITIONAL: = [{"v": "3", "conditions": []}]

enum ScriptType { GDSCRIPT, ORCHESTRATOR }

var scripts: Array[Dictionary] = []
var all_commands: Dictionary[String, Dictionary] = {}

const DEFAULT_SCRIPTS: = [ "basic_default" ]

# orchestrator expirement disabled atm
var add_orch_scripts: Array[String] = []#["res://cond_scripts/orch_cmds.torch"]

const BUILTIN_COMMANDS: Array[String] = ["and", "or", "xor", "not", "false", "true"]

var verbose = false

func _ready() -> void:
    for script_name in DEFAULT_SCRIPTS:
        add_command_script_auto(script_name, ScriptType.GDSCRIPT, null)
    for orch_script_path in add_orch_scripts:
        var script_name: String = orch_script_path.get_file().get_basename()
        var orch_script_inst: Node = load(orch_script_path).new()
        add_command_script(script_name, ScriptType.ORCHESTRATOR, orch_script_inst)
        for command in all_commands:
            if command.begins_with(script_name + "."):
                prints("Added orch command: %s" % command)

func get_all_events() -> Array[String]:
    return all_events.duplicate()

func make_slots(owning_entity: BaseEntity, target_entity: BaseEntity, tile_positions: Array[Vector2i], arguments: Array = []) -> Dictionary:
    var slots = empty_slots()
    slots[Slot.RED] = owning_entity
    slots[Slot.BLUE] = target_entity
    slots[Slot.GREY] = tile_positions
    if owning_entity and owning_entity.friend_instance_id > -1:
        slots[Slot.PINK] = EntityManager.get_instance(owning_entity.friend_instance_id)
    
    if arguments:
        var arg_slots = [Slot.DARK_RED, Slot.DARK_BLUE, Slot.DARK_GREEN, Slot.DARK_ORANGE,]
        for i in range(min(4, len(arguments))):
            slots[arg_slots[i]] = arguments[i]
    return slots

func is_builtin(call_string: String) -> bool:
    return call_string in BUILTIN_COMMANDS

func slots_copy(slots: Dictionary) -> Dictionary:
    var slots_duplicate = slots.duplicate()
    slots[Slot.GREY] = slots[Slot.GREY].duplicate()
    slots[Slot.BLACK] = slots[Slot.BLACK].duplicate()
    slots[Slot.ORANGE] = slots[Slot.ORANGE].duplicate()
    return slots_duplicate

func add_command_script_auto(script_name: String, script_type: int, script_inst: Object = null) -> void:
    if not script_inst:
        if script_type == ScriptType.GDSCRIPT:
            script_inst = load(_find_gdscript_file(script_name)).new()
    add_command_script(script_name, script_type, script_inst)

func _find_gdscript_file(script_name: String) -> String:
    return "res://cond_scripts/" + script_name + ".gd"

func callstring_to_qualified_name(call_string: String) -> String:
    if call_string.contains("::"):
        return call_string.split("::", true, 1)[0]
    return call_string

func callstring_to_arg_string(call_string: String) -> String:
    if call_string.contains("::"):
        return call_string.split("::", true, 1)[1]
    return ""

func command_short_name(command_name: String) -> String:
    return command_name.rsplit(".")[-1]

func arg_values_to_arg_string(arg_values: Array) -> String:
    if arg_values.size() == 0:
        return ""
    return JSON.stringify(JSON.from_native(arg_values, false))

func arg_string_to_arg_values(arg_string: String) -> Array:
    if arg_string == "":
        return []
    return JSON.to_native(JSON.parse_string(arg_string), false)

func find_command_by_name(command_name: String) -> String:
    for qualified_name in all_commands:
        if qualified_name == command_name or qualified_name.ends_with("." + command_name):
            return qualified_name
    return ""

func get_command_info(qualified_name: String) -> Dictionary:
    if not all_commands.has(qualified_name):
        return {}
    return all_commands[qualified_name]

func get_command_slot_type_hint(qualified_name: String) -> Array:
    if not all_commands.has(qualified_name):
        return ["all"]
    elif "slot_type_hint" in all_commands[qualified_name]:
        var slot_type_hint: Array = all_commands[qualified_name]["slot_type_hint"].split(",", false)
        if "none" in slot_type_hint:
            return []
        return slot_type_hint
    else:
        return ["all"]

func add_command_script(script_name: String, script_type: int, script_inst: Object = null) -> void:
    add_command_script_info({
        "name": script_name,
        "type": script_type,
        "instance": script_inst,
    })

func add_command_script_info(script_info: Dictionary) -> void:
    var script_index = scripts.size()
    scripts.append(script_info)
    register_script_commands(script_index)

func register_script_commands(script_index: int) -> void:
    var script_inst = scripts[script_index]["instance"]
    if script_inst.has_method("set_cond_resolver"):
        script_inst.set_cond_resolver(self)
    var script_name = scripts[script_index]["name"]
    for command in script_inst.list_commands():
        var qualified_name = script_name + "." + command["name"]
        if qualified_name in all_commands:
            push_warning("Overriding registered command: %s" % [qualified_name])
        all_commands[qualified_name] = command.duplicate()
        all_commands[qualified_name]["script_index"] = script_index

func conditions_collapse(condition_stack: Array) -> bool:
    var result = true
    for i_res in condition_stack:
        if not i_res:
            return i_res
        # Just top-most value for now
        result = i_res
    return result

func resolve_conditional(conditional: Variant, slots: Dictionary, extra_debug: bool = false) -> Dictionary:
    var regularized_conditional: Array[Dictionary] = []
    if typeof(conditional) == TYPE_ARRAY:
        regularized_conditional.assign(conditional)
    else:
        regularized_conditional.append(conditional)
    return _resolve_conditional(regularized_conditional, slots, extra_debug)

func _resolve_conditional(conditional: Array[Dictionary], slots: Dictionary, extra_debug: bool = false) -> Dictionary:
    slots["reset_slots"] = slots_copy(slots)
    
    var this_step_result = {"result": true, "quit": false}
    for i in conditional.size():
        this_step_result = _resolve_conditional_step(i, conditional[i], this_step_result, slots, extra_debug)
        if this_step_result["quit"]:
            break
    var reset_slots: Dictionary = slots["reset_slots"]
    if reset_slots[Slot.RED] and slots[Slot.PINK]:
        reset_slots[Slot.RED].friend_instance_id = slots[Slot.PINK].instance_id

    return this_step_result
    
func _resolve_conditional_step(step_index: int, cond_step: Dictionary, overall_result: Dictionary, slots: Dictionary, extra_debug: bool = false) -> Dictionary:
    var step_result = overall_result.duplicate()
    var break_step = false
    
    if verbose:
        for key: String in cond_step:
            if key == "v":
                continue
            var other_keys: Array[String] = []
            if key != "conditions" and not key.begins_with("when "):
                other_keys.append(key)
            print_debug("ConditionalV3, found other keys: %s" % [other_keys])
    
    if extra_debug:
        prints("resolving step:", step_index, "contents:", cond_step)

    var condition_stack = []
    for cond_call in cond_step.get("conditions", []):
        if step_result["quit"] or break_step:
            break
        if typeof(cond_call) != TYPE_STRING:
            push_error("Conditional command is not a string: " + str(cond_call))
            continue
        if cond_call == "and" or cond_call == "or":
            var a = condition_stack.pop_back()
            var b = condition_stack.pop_back()
            condition_stack.append(a and b if cond_call == "and" else a or b)
        elif cond_call == "false" or cond_call == "true":
            condition_stack.append(cond_call == "true")
        elif cond_call == "not":
            var top = condition_stack.pop_back()
            condition_stack.append(not top)
        else:
            var cmd_result = call_conditional_command(cond_call, slots)
            if cmd_result['quit']:
                step_result["quit"] = true
            elif cmd_result.get("break", false):
                break_step = true
            condition_stack.append(cmd_result["result"])
    
    if extra_debug:
        prints("condition stack: %s" % [condition_stack])
    
    if len(condition_stack) > 1:
        step_result["result"] = conditions_collapse(condition_stack)
    elif len(condition_stack) == 1:
        step_result["result"] = condition_stack[0]
    elif len(condition_stack) == 0:
        step_result["result"] = true
    
    if extra_debug:
        prints("step result: %s" % step_result)
    
    if step_result["quit"] or break_step:
        if extra_debug:
            prints("quitting step")
        return step_result
    
    var cases: Array[String] = []
    for key: String in cond_step:
        if key.begins_with("when "):
            cases.append(key.trim_prefix("when "))
    
    for case in cases:
        if step_result["quit"] or break_step:
            break
        if not check_against_case(case, step_result["result"]):
            if extra_debug and cond_step.get("when " + case, []).size() > 0:
                prints("skipping case: %s" % case)
            continue
        if extra_debug and cond_step.get("when " + case, []).size() > 0:
            prints("evaluating case: %s" % case)
        var cmds: Array = cond_step["when " + case]
        for cmd in cmds:
            if cmd == "true" or cmd == "false":
                step_result["result"] = cmd == "true"
                continue
            var cmd_result = call_conditional_command(cmd, slots)
            if cmd_result.has("step_result"):
                if extra_debug:
                    prints("result changed in case: %s to %s" % [case, cmd_result["step_result"]])
                step_result["result"] = cmd_result["step_result"]

            if cmd_result.get("quit", false):
                step_result["quit"] = true
            elif cmd_result.get("break", false):
                break_step = true
    
    if extra_debug:
        prints("step result after cases: %s" % step_result)

    return step_result

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

func call_conditional_command(call_str: String, slots: Dictionary) -> Dictionary:
    if not call_str:
        push_error("Conditional command name/call string is empty")
        return {"result": false, "quit": true}

    var command_qualified_name: String = ""
    if call_str.contains("::"):
        command_qualified_name = call_str.split("::", true, 1)[0]
    else:
        command_qualified_name = call_str

    if not all_commands.has(command_qualified_name):
        push_error("Conditional Script not found for command: %s (%s)" % [command_qualified_name, call_str])
        return {"result": false, "quit": true}
    
    var cmd_script = scripts[all_commands[command_qualified_name]["script_index"]]["instance"]
    var command_name = command_qualified_name.rsplit(".", true, 1)[-1]

    var raw_result = _call_conditional_command(cmd_script, command_name, slots, call_str)
    var result_type = typeof(raw_result)
    if result_type == TYPE_BOOL:
        return {"result": raw_result, "quit": false}
    elif result_type in [TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
        return {"result": raw_result, "quit": false}
    elif result_type == TYPE_DICTIONARY:
        if not raw_result:
            push_warning("command returned empty dictionary: %s" % [call_str])
        return raw_result
    else:
        # default return in case of command with no return value etc
        return {"result": true, "quit": false}

func _call_conditional_command(cmd_script: Node, main_cmd_name: String, slots: Dictionary, full_call_str: String) -> Variant:
    return cmd_script.call_command(main_cmd_name, slots, full_call_str)

func select_reset(slots: Dictionary) -> void:
    slots.clear()
    var reset_slots: Dictionary = slots["reset_slots"]
    for key in slots:
        if key == "reset_slots":
            continue
        slots[key] = reset_slots[key]
        if typeof(slots[key]) == TYPE_ARRAY:
            slots[key] = slots[key].duplicate()

func select_reset_slot(slots: Dictionary, slot_id: Slot) -> void:
    slots[slot_id] = slots["reset_slots"][slot_id]
    if typeof(slots[slot_id]) == TYPE_ARRAY:
        slots[slot_id] = slots[slot_id].duplicate()

func empty_slots() -> Dictionary:
    return {
        Slot.RED: null,
        Slot.BLUE: null,
        Slot.WHITE: null,
        Slot.PINK: null,
        Slot.GREY: [],
        Slot.BLACK: [],
        Slot.ORANGE: [],
        Slot.A: 0,
        Slot.B: 0,
        Slot.C: 0,
        Slot.X: 0.0,
        Slot.Y: 0.0,
        Slot.Z: 0.0,
        Slot.I: "",
        Slot.II: "",
        Slot.III: "",
        Slot.DARK_RED: null,
        Slot.DARK_BLUE: null,
        Slot.DARK_GREEN: null,
        Slot.DARK_ORANGE: null,
    }

func get_event_hint_text(event_name: String) -> String:
    if not event_name in EVENT_HINT_TEXT:
        return ""
    return EVENT_HINT_TEXT[event_name]

const EVENT_HINT_TEXT: Dictionary[String, String] = {
	"blocks": "Conditional Event.\nIf true, the incoming entity will be blocked and will not be able to move onto this entity/tile",
	"move_onto": "Conditional Event.\nIf false, the incoming entity will not be allowed to move onto this entity/tile",
    "move_off_of": "Conditional Event.\nIf false, the outgoing entity will not be allowed to move off of this entity/tile",
    "i_move_onto": "Conditional Event.\nIf false, this entity will not be allowed to move onto the other entity at the target location",
    "i_move_onto_tile": "Conditional Event.\nIf false, this entity will not be allowed to move onto the tile at the target location",
    "i_move_off_of": "Conditional Event.\nIf false, this entity will not be allowed to move off of the other entity at this location",
    "i_move_off_of_tile": "Conditional Event.\nIf false, this entity will not be allowed to move off of the tile at this location",

	"finish_move_onto": "Unconditional Event.\nEntities only. Resolved when another entity finishes moving onto this entity",
	"finish_move_onto_tile": "Unconditional Event.\nTiles only. Resolved every time an entity finishes moving to a tile position with this tile",
	"i_finish_move_onto": "Unconditional Event.\nResolved when the entity finishes moving onto another entity",
	"i_finish_move_onto_tile": "Unconditional Event.\nResolved every time the entity finishes moving to a new tile position",

    "half_moved_onto": "Unconditional Event.\nEntities only. Resolved when this entity begins overlapping with another entity (past half-way point of movement)",
    "half_moved_off_of": "Unconditional Event.\nEntities only. Resolved when this entity begins overlapping with another entity (past half-way point of movement)",
    "half_moved_onto_tile": "Unconditional Event.\nTiles only. Resolved when an entity passes the half-way point moving to tile position with this tile",
    "half_moved_off_of_tile": "Unconditional Event.\nTiles only. Resolved when an entity passes the half-way point moving from tile position with this tile",

    "covered_by_[property]": "Not Implemented Yet x.x",
    "uncovered_by_[property]": "Not Implemented Yet x.x",
	"when_signal_[signal]": "Unconditional Event.\nResolved when any Conditional triggers a signal with this name (if moving, will resolve as soon as this entity is done moving)",

	"post_move_onto": "Unconditional Event.\nEntities only. Resolved immediately once another entity has started moving onto this entity",
    "post_move_off_of": "Unconditional Event.\nEntities only. Resolved immediately once another entity has started moving off of this entity",
	"post_move": "Unconditional Event.\nEntities only. Resolved immediately once this entity has started moving to a new tile position",
    
    "do_action_1": "Unconditional Event.\nResolved when action 1 is pressed (if this entity can receive action events)",
    "do_action_2": "Unconditional Event.\nResolved when action 2 is pressed (if this entity can receive action events)",
    "do_action_3": "Unconditional Event.\nResolved when action 3 is pressed (if this entity can receive action events)",
    
    "was_blocked": "Unconditional Event.\nResolved when this entity is blocked from moving (by another entity or tile)",

	"idle_update": "Unconditional Event.\nFor entities, resolved every idle interval after the entity stops moving.\nFor tiles, resolved every idle interval for every tile type",
    "idle_on": "Unconditional Event.\nTiles only, resolved for any idle entity on this tile every idle interval (after that entity stopped moving)",
	"dying": "Unconditional Event.\nEntities only, resolved when the entity is being destroyed",
    
    "started_tailing": "Unconditional Event.\nResolved when this entity starts tailing another entity",
    "stopped_tailing": "Unconditional Event.\nResolved when this entity stops tailing another entity",
    
    "joined_bond_group": "Unconditional Event.\nResolved when this entity becomes bonded to a bond group of entities",
    "left_bond_group": "Unconditional Event.\nResolved when this entity leaves all bond groups",
    
    "turn_start": "[Discrete Movement Modes Only]\nEntities only, Resolved at the start of every game turn.",
    "pre_turn_end": "[Discrete+ Only]\nEntities only, Resolved when a game turn is about to end.",
    "turn_end": "[Discrete Movement Modes Only]\nEntities only, Resolved at the end of every game turn.",
}

const EVENT_CATEGORIES: Dictionary[String, String] = {
    "blocks": "move events",
    "was_blocked": "move events",

    "move_off_of": "move events",
    "i_move_off_of": "move events",
    "i_move_off_of_tile": "move events",
    
    "move_onto": "move events",
    "i_move_onto": "move events",
    "i_move_onto_tile": "move events",
    
    "post_move_off_of": "move events",
    "post_move_onto": "move events",
    "post_move": "move events",
    
    "half_moved_off_of": "move events",
    "half_moved_off_of_tile": "move events",
    "half_moved_onto": "move events",
    "half_moved_onto_tile": "move events",
    
    "finish_move_onto": "move events",
    "i_finish_move_onto": "move events",
    "finish_move_onto_tile": "move events",
    "i_finish_move_onto_tile": "move events",
    
    "do_action_1": "input events",
    "do_action_2": "input events",
    "do_action_3": "input events",
    
    "idle_update": "other",
    "idle_on": "other",
    "dying": "other",
    
    "started_tailing": "other",
    "stopped_tailing": "other",
    
    "joined_bond_group": "other",
    "left_bond_group": "other",
    "when_signal_[signal]": "other",
    
    "turn_start": "turn events",
    "pre_turn_end": "turn events",
    "turn_end": "turn events",
}