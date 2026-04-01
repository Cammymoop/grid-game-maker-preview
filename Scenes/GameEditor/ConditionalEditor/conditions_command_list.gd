extends GridContainer
class_name ConditionsCommandList

const CommandListItem = preload("res://src/GameEditor/ConditionalEditor/CommandListItem.gd")
const BoolCombinerPiece = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_piece.gd")

var bool_empty: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_empty.tscn")
var bool_single: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_single.tscn")
var bool_top: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_top.tscn")
var bool_middle: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_middle.tscn")
var bool_bottom: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_bottom.tscn")

var combiner_label: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/combiner_label.tscn")

var command_list_items: Array[CommandListItem] = []

var combiner_tree: Dictionary = {
    "first_command_index": 0,
    "function": "and",
    "children": [],
}

@export var combiner_label_h_offset: float = 0

var drag_move_threshold: float = 6

var resizing_combiner_tree: Dictionary = {}
var is_resizing_combiner: bool = false
var is_resizing_bottom: bool = false
var resizing_click_hold: bool = false
var resizing_hold_movement: Vector2 = Vector2.ZERO
var resizing_combiner_node: Dictionary = {}
var resizing_last_index: int = 0

const UNARY_FUNCTIONS = ["not"]

var resizer_margin: float = 8

var combiner_column_width: int = 16

var _dirty: bool = false

const CONTEXT_MENU_CHANGE_TO_AND = 1
const CONTEXT_MENU_CHANGE_TO_OR = 2
const CONTEXT_MENU_CHANGE_TO_NOT = 3
const CONTEXT_MENU_ADD_COMBINER = 10
const CONTEXT_MENU_REMOVE = 90

func _ready():
    var temp_bool_single: = bool_single.instantiate()
    combiner_column_width = temp_bool_single.get_combined_minimum_size().x + hsep()
    temp_bool_single.queue_free()
    
    _dirty = true

func _process(_delta: float) -> void:
    if visible and _dirty:
        rebuild_grid()

func set_command_list(new_list_items: Array) -> void:
    clear_commands()
    var just_commands: Array[CommandListItem] = []
    var command_index: int = -1
    var incoming_combiners: Dictionary[int, Array] = {}
    for new_list_item in new_list_items:
        if new_list_item is CommandListItem:
            command_index += 1
            just_commands.append(new_list_item)
        else:
            if command_index == -1:
                push_error("got a combiner before any commands")
                continue
            if not incoming_combiners.has(command_index):
                incoming_combiners[command_index] = []
            incoming_combiners[command_index].append(new_list_item)

    for command_item in just_commands:
        command_item.parent_list = self
    command_list_items = just_commands
    
    combiner_tree = build_combiner_tree_for_incoming_combiners(incoming_combiners, get_command_count())
    unset_explicit_top_level_end()

func build_combiner_tree_for_incoming_combiners(incoming_combiners: Dictionary[int, Array], total_commands: int) -> Dictionary:
    var top_level_combiners: Array[Dictionary] = []
    var to_check_indices: Array = []
    to_check_indices.append_array(incoming_combiners.keys())
    to_check_indices.sort()
    
    var safety: int = 10000
    while to_check_indices.size() > 0:
        var build_combiner_tree_at: int = to_check_indices.pop_back()
        var new_combiner: Dictionary = build_combiner_for_incoming_at(incoming_combiners, build_combiner_tree_at, 0)
        prints("new combiner before collapse: %s" % [new_combiner])
        new_combiner = collapse_redundant_combiners(new_combiner)
        var combiner_range: Array[int] = [new_combiner["first_command_index"], build_combiner_tree_at]
        to_check_indices = to_check_indices.filter(func(index: int): return not index_in_range(index, combiner_range))
        top_level_combiners.append(new_combiner)
        
        safety -= 1
        if safety <= 0:
            push_error("Safety limit reached, aborting combiner tree build")
            return {}
    
    var top_level_count: int = top_level_combiners.size()
    var add_top_level_default: bool = top_level_count == 0 or top_level_count > 1
    if top_level_count == 1:
        if top_level_combiners[0]["first_command_index"] > 0:
            add_top_level_default = true
        elif top_level_combiners[0].get("last_command_index", total_commands - 1) != total_commands - 1:
            add_top_level_default = true
    
    if add_top_level_default:
        return get_default_top_level_combiner(top_level_combiners)
    else:
        return top_level_combiners[0]

func get_default_top_level_combiner(with_children: Array) -> Dictionary:
    return {
        "first_command_index": 0,
        "function": "and",
        "children": with_children,
    }


func build_combiner_for_incoming_at(incoming_combiners: Dictionary[int, Array], at_command_index: int, stack_level: int) -> Dictionary:
    var stack_depth: int = 0
    if incoming_combiners.has(at_command_index):
        stack_depth = incoming_combiners[at_command_index].size()
    if stack_level + 1 > stack_depth:
        return {}
    

    var combiner_func: String = incoming_combiners[at_command_index][-(stack_level + 1)]
    var new_combiner: Dictionary = {
        "first_command_index": -1,
        "last_command_index": at_command_index,
        "function": combiner_func,
        "children": [],
    }
    var add_operands: int = 1 if combiner_func in UNARY_FUNCTIONS else 2
    var current_command_index: int = at_command_index
    for op_i in add_operands:
        var current_stack_level: int = stack_level + 1 if current_command_index == at_command_index else 0
        var next_combiner_here: Dictionary = build_combiner_for_incoming_at(incoming_combiners, current_command_index, current_stack_level)
        if next_combiner_here:
            new_combiner["children"].push_front(next_combiner_here)
            current_command_index = next_combiner_here["first_command_index"]
            new_combiner["first_command_index"] = current_command_index
        else:
            new_combiner["first_command_index"] = current_command_index
        current_command_index -= 1
    return new_combiner

func collapse_redundant_combiners(in_combiner_subtree: Dictionary) -> Dictionary:
    var my_func: String = in_combiner_subtree["function"]
    if in_combiner_subtree["children"].size() == 1 and my_func not in UNARY_FUNCTIONS:
        if _is_combiner_tree_redundant(in_combiner_subtree["children"][0], my_func):
            in_combiner_subtree["children"] = []
    
    for child_combiner in in_combiner_subtree["children"]:
        collapse_redundant_combiners(child_combiner)
    return in_combiner_subtree

func _is_combiner_tree_redundant(combiner_subtree: Dictionary, parent_func: String) -> bool:
    if parent_func in UNARY_FUNCTIONS:
        return false
    if combiner_subtree["function"] != parent_func or combiner_subtree["children"].size() > 1:
        return false

    if combiner_subtree["children"].size() == 0:
        return true
    else:
        return _is_combiner_tree_redundant(combiner_subtree["children"][0], parent_func)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        _handle_click(event as InputEventMouseButton)
    if event is InputEventMouseMotion:
        _handle_drag(event as InputEventMouseMotion)

func _handle_click(event: InputEventMouseButton) -> void:
    if not event.pressed:
        if resizing_click_hold:
            resizing_click_hold = false
        if is_resizing_combiner:
            accept_combiner_resize()

    if event.pressed:
        if is_resizing_combiner:
            if event.button_index == MOUSE_BUTTON_RIGHT:
                cancel_resizing_combiner()
            return

        var local_pos: = event.position
        var click_column: int = floori((local_pos.x + hsep()/2.0) / float(combiner_column_width))
        if click_column >= columns - 1:
            return
        
        var click_row: int = get_row_from_local_pos(local_pos)
        if click_row == -1:
            return
        
        var combiner_list: Array[Dictionary] = []
        var all_ranges: = calculate_all_index_ranges()
        get_row_combiner_list(all_ranges, click_row, combiner_list)
        if click_column >= combiner_list.size():
            # click is outside of combiner range, should be overlapping command list item
            return
        
        if event.button_index == MOUSE_BUTTON_RIGHT:
            do_combiner_context_menu(click_row, click_column)
        elif event.button_index == MOUSE_BUTTON_MIDDLE:
            test_change_combiner_func(combiner_list[click_column]["root_node"])
        elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
            add_child_combiner(combiner_list[click_column]["root_node"])
        elif event.button_index == MOUSE_BUTTON_LEFT:
            handle_start_click_hold(click_row, click_column, local_pos, combiner_list)

func get_combiner_node_at_grid_location(local_row: int, local_column: int) -> Dictionary:
    var all_ranges: = calculate_all_index_ranges()
    var combiner_list: Array[Dictionary] = []
    get_row_combiner_list(all_ranges, local_row, combiner_list)
    if local_column >= combiner_list.size():
        return {}
    return combiner_list[local_column]["root_node"]

func test_change_combiner_func(combiner_node: Dictionary) -> void:
    var funcs: Array[String] = ["and", "or", "not"]
    var next: int = posmod(funcs.find(combiner_node["function"]) + 1, funcs.size())
    change_combiner_func(combiner_node, funcs[next])

func handle_start_click_hold(click_row: int, click_column: int, local_pos: Vector2, combiner_list: Array[Dictionary]) -> void:
    if click_column == 0:
        return
    var in_resizer_area: String = is_local_pos_in_resizer_area(click_row, click_column, local_pos, combiner_list)
    if in_resizer_area:
        resizing_click_hold = true
        is_resizing_bottom = in_resizer_area == "bottom"
        resizing_hold_movement = Vector2.ZERO
        resizing_combiner_node = combiner_list[click_column]["root_node"]

func is_local_pos_in_resizer_area(local_row: int, local_column: int, local_pos: Vector2, combiner_list: Array[Dictionary]) -> String:
    if local_column < 0 or local_column >= combiner_list.size():
        return ""

    var in_row_pos: Vector2 = local_pos - get_child(local_row * columns).position + Vector2(0, vsep()/2.0)
    var row_height: float = get_child(local_row * columns).size.y + vsep()
    var combiner_range: Array = combiner_list[local_column]["index_range"]
    if combiner_range[0] == local_row and in_row_pos.y < resizer_margin:
        return "top"
    elif combiner_range[1] == local_row and in_row_pos.y > row_height - resizer_margin:
        return "bottom"
    return ""

func _handle_drag(event: InputEventMouseMotion) -> void:
    var set_mouse_cursor_shape: = Control.CURSOR_ARROW
    if resizing_click_hold:
        resizing_hold_movement += (event as InputEventMouseMotion).relative
        if resizing_hold_movement.length() > drag_move_threshold:
            start_resizing_combiner(event.position)
    elif is_resizing_combiner:
        set_mouse_cursor_shape = Control.CURSOR_VSIZE
        update_resizing_combiner(event.position)
    else:
        var local_row: int = get_row_from_local_pos(event.position)
        var local_column: int = floori((event.position.x + hsep()/2.0) / float(combiner_column_width))
        if not (local_column < 0 or local_column >= columns - 1):
            var all_ranges: = calculate_all_index_ranges()
            var combiner_list: Array[Dictionary] = []
            get_row_combiner_list(all_ranges, local_row, combiner_list)
            
            var in_resizer_area: String = is_local_pos_in_resizer_area(local_row, local_column, event.position, combiner_list)
            if in_resizer_area:
                set_mouse_cursor_shape = Control.CURSOR_VSIZE
            else:
                set_mouse_cursor_shape = Control.CURSOR_ARROW
    
    if set_mouse_cursor_shape != mouse_default_cursor_shape:
        mouse_default_cursor_shape = set_mouse_cursor_shape

func change_combiner_func(combiner_node: Dictionary, new_func: String) -> void:
    combiner_node["function"] = new_func
    _dirty = true

func remove_combiner(combiner_node: Dictionary) -> void:
    if is_same(combiner_node, combiner_tree):
        return
    var parent_combiner: Dictionary = get_parent_combiner(combiner_node)
    parent_combiner["children"].erase(combiner_node)
    if combiner_node["children"].size() > 0:
        parent_combiner["children"].append_array(combiner_node["children"])
        sort_combiner_children(parent_combiner)
    _dirty = true

func add_child_combiner(parent_combiner: Dictionary) -> void:
    var new_combiner: Dictionary = {
        "first_command_index": parent_combiner["first_command_index"],
        "function": "and",
        "children": [],
    }
    if parent_combiner["children"].size() > 0:
        new_combiner["children"].append_array(parent_combiner["children"])
    parent_combiner["children"] = [new_combiner]
    _dirty = true

func get_v3_command_data() -> Array:
    if command_list_items.size() == 0:
        return []
    var commands: Array = []
    for command_item in command_list_items:
        commands.append(command_item.get_v3_call_string())
    var inserted_operations: Dictionary[int, Array] = {}
    var all_ranges: = calculate_all_index_ranges()
    normalize_combiner_tree(all_ranges)
    all_ranges = calculate_all_index_ranges()
    insert_combiner_operations(all_ranges, inserted_operations, true)
    var insert_after_indices: Array = inserted_operations.keys()
    insert_after_indices.sort()
    insert_after_indices.reverse()
    for insert_after_index in insert_after_indices:
        Utility.insert_array_at(commands, insert_after_index + 1, inserted_operations[insert_after_index])
    return commands

# remove all single-operand binary operator based combiners without removing their children
func normalize_combiner_tree(combiner_range: Dictionary) -> void:
    var child_count: int = combiner_range["children"].size()
    if child_count == 0:
        return
    var combiner_node: Dictionary = combiner_range["root_node"]
    for child_range in combiner_range["children"]:
        if child_range["root_node"]["function"] in UNARY_FUNCTIONS:
            normalize_combiner_tree(child_range)
            continue
        
        var is_redundant: bool = false
        if child_range["index_range"][0] == child_range["index_range"][1]:
            is_redundant = true
        elif child_range["children"].size() == 1:
            var child_child_index_range: Array[int] = child_range["children"][0]["index_range"]
            if range_contains_range(child_child_index_range, child_range["index_range"]):
                is_redundant = true
        
        if is_redundant:
            combiner_node["children"].append_array(child_range["root_node"]["children"])
            combiner_node["children"].erase(child_range["root_node"])
    
    sort_combiner_children(combiner_node)


func insert_combiner_operations(index_ranges_subtree: Dictionary, inserted_operations: Dictionary[int, Array], is_top_level: bool = false) -> void:
    for child_range in index_ranges_subtree["children"]:
        insert_combiner_operations(child_range, inserted_operations)

    if is_top_level:
        # AND behavior is implicit at the top level
        if index_ranges_subtree["root_node"]["function"] == "and":
            return
        # special case exit needed because the top level combiner isn't normalized away
        # even if it takes two operands and there's only one command
        if command_list_items.size() == 1:
            if index_ranges_subtree["root_node"]["function"] not in UNARY_FUNCTIONS:
                return

    var last_index: int = index_ranges_subtree["index_range"][1]
    if not inserted_operations.has(last_index):
        inserted_operations[last_index] = []
    var num_ops: int = last_index - index_ranges_subtree["index_range"][0]
    for child_combiner in index_ranges_subtree["children"]:
        num_ops -= child_combiner["index_range"][1] - child_combiner["index_range"][0]
    var combiner_func: String = index_ranges_subtree["root_node"]["function"]
    if UNARY_FUNCTIONS.has(combiner_func):
        if num_ops != 0:
            push_error("Unary function '%s' has %d operands, expected 1" % [combiner_func, num_ops + 1])
            return
        inserted_operations[last_index].append(combiner_func)
    else:
        if num_ops < 1:
            push_error("Combiner function '%s' has %d operands, expected at least 2" % [combiner_func, num_ops + 1])
        for i in range(num_ops):
            inserted_operations[last_index].append(combiner_func)


func get_command_count() -> int:
    return command_list_items.size()

func rebuild_grid() -> void:
    _dirty = false
    clear_children()
    var command_count: int = get_command_count()
    var max_depth: int = get_combiner_subtree_depth(combiner_tree)
    if command_count < 2 and max_depth == 1:
        max_depth = 0
    columns = max_depth + 1

    var index_ranges: Dictionary = calculate_all_index_ranges()
    
    var row_heights: Array[int] = []
    var combiner_top_pieces: Array[Dictionary] = []
    for row_index in command_count:
        if max_depth == 0:
            add_child(command_list_items[row_index])
            continue
        var combiner_list: Array[Dictionary] = []
        get_row_combiner_list(index_ranges, row_index, combiner_list)
        
        for column_index in max_depth:
            if column_index >= combiner_list.size():
                var empty_piece: = bool_empty.instantiate()
                add_child(empty_piece)
                continue

            var is_top_edge: bool = combiner_list[column_index]["index_range"][0] == row_index
            var is_bottom_edge: bool = combiner_list[column_index]["index_range"][1] == row_index
            var combiner_piece: Control
            if is_top_edge and is_bottom_edge:
                combiner_piece = bool_single.instantiate()
            elif is_top_edge:
                combiner_piece = bool_top.instantiate()
            elif is_bottom_edge:
                combiner_piece = bool_bottom.instantiate()
            else:
                combiner_piece = bool_middle.instantiate()

            var combiner: = combiner_list[column_index]["root_node"] as Dictionary
            set_combiner_piece_style(combiner_piece, combiner["function"])
            combiner_piece.tooltip_text = combiner["function"].capitalize()
            add_child(combiner_piece)
            
            if is_top_edge:
                combiner_top_pieces.append({
                    "top_piece": combiner_piece,
                    "combiner": combiner,
                    "row_span": combiner_list[column_index]["index_range"][1] - combiner_list[column_index]["index_range"][0] + 1,
                })
        
        var margin_container: = get_list_item_margin_container(max_depth - combiner_list.size())
        var command_node: CommandListItem = command_list_items[row_index] as CommandListItem
        margin_container.add_child(command_node)
        add_child(margin_container)

        row_heights.append(command_node.size.y)
    
    for combiner_top_piece in combiner_top_pieces:
        var combiner: Dictionary = combiner_top_piece["combiner"]
        var start_row_index: int = combiner["first_command_index"]
        
        var total_height: int = 0
        for row_index in range(start_row_index, start_row_index + combiner_top_piece["row_span"]):
            total_height += row_heights[row_index]
        total_height += vsep() * (combiner_top_piece["row_span"] - 1)
        
        var new_label_anchor: Control = combiner_label.instantiate()
        var the_label: Label = new_label_anchor.get_node("Label")
        the_label.text = combiner["function"].to_upper()
        the_label.custom_minimum_size.x = total_height
        the_label.size.x = total_height
        combiner_top_piece["top_piece"].add_child(new_label_anchor)
        new_label_anchor.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
        new_label_anchor.position.x += combiner_label_h_offset

func set_combiner_piece_style(combiner_piece: BoolCombinerPiece, combiner_func: String) -> void:
    var base_colors: Dictionary = {
        "and": Color(0.8, 0.4, 0.4),
        "or": Color(0.4, 0.8, 0.4),
        "not": Color(0.9, 0.9, 0.9),
    }
    var func_base_color: Color = base_colors.get(combiner_func, Color.MAGENTA)
    var func_border_color: Color = func_base_color.darkened(0.5)
    
    combiner_piece.set_border_and_bg_color(func_border_color, func_base_color)

func get_list_item_margin_container(negative_column_count: int) -> MarginContainer:
    var margin_container: = MarginContainer.new()
    margin_container.add_theme_constant_override("margin_top", 0)
    margin_container.add_theme_constant_override("margin_bottom", 0)
    margin_container.add_theme_constant_override("margin_right", 0)
    margin_container.add_theme_constant_override("margin_left", -(negative_column_count * combiner_column_width))
    return margin_container
        

func clear_commands() -> void:
    clear_children()
    for command_item in command_list_items:
        command_item.queue_free()
    command_list_items = []
    _dirty = true

func clear_children() -> void:
    for child in get_children():
        remove_child(child)
        if _is_command_list_item(child):
            if child is MarginContainer:
                child.remove_child(child.get_child(0))
                child.queue_free()
            continue
        child.queue_free()

func _is_command_list_item(child: Control) -> bool:
    if child is CommandListItem and child in command_list_items:
        return true
    if child is MarginContainer:
        return child.get_child(0) in command_list_items
    return false

func get_combiner_subtree_depth(combiner_subtree: Dictionary) -> int:
    var max_child_depth: int = 0
    for sub_subtree in combiner_subtree["children"]:
        max_child_depth = maxi(max_child_depth, get_combiner_subtree_depth(sub_subtree))
    return max_child_depth + 1

func is_index_in_range(index_ranges: Dictionary, index: int) -> bool:
    return index >= index_ranges["index_range"][0] and index <= index_ranges["index_range"][1]

func get_row_combiner_list(index_ranges: Dictionary, row_index: int, combiner_list: Array[Dictionary]) -> void:
    combiner_list.append(index_ranges)
    for child_range in index_ranges["children"]:
        if is_index_in_range(child_range, row_index):
            get_row_combiner_list(child_range, row_index, combiner_list)

# Handling Combiner Tree

func combiner_subtree_index_range(combiner_subtree: Dictionary, last_available_index: int) -> Array[int]:
    var index_range: Array[int] = [combiner_subtree["first_command_index"], combiner_subtree.get("last_command_index", last_available_index)]
    return index_range

func unset_explicit_top_level_end() -> void:
    if combiner_tree.has("last_command_index") and combiner_tree["function"] not in UNARY_FUNCTIONS:
        combiner_tree.erase("last_command_index")

func calculate_all_index_ranges() -> Dictionary:
    unset_explicit_top_level_end()
    return index_ranges_recursive(combiner_tree, get_command_count() - 1)

func calculate_combiner_subtree_index_ranges(combiner_subtree: Dictionary, last_available_index: int) -> Dictionary:
    return index_ranges_recursive(combiner_subtree, last_available_index)

func get_combiner_node_last_index(combiner_node: Dictionary) -> int:
    if combiner_node.has("last_command_index"):
        return combiner_node["last_command_index"]
    var node_range: = get_combiner_node_calculated_range(combiner_node)
    return node_range[1]

func get_combiner_node_calculated_range(combiner_node: Dictionary) -> Array[int]:
    var all_ranges: = calculate_all_index_ranges()
    var found_range: = recursive_get_range_of_node(all_ranges, combiner_node)
    if not found_range:
        push_error("Combiner node not found in calculated index ranges: %s" % [combiner_node])
        return []
    return found_range["index_range"]

func recursive_get_range_of_node(ranges: Dictionary, node: Dictionary) -> Dictionary:
    if is_same(ranges["root_node"], node):
        return ranges
    for child_range in ranges["children"]:
        var found_range: = recursive_get_range_of_node(child_range, node)
        if found_range:
            return found_range
    return {}

func index_ranges_recursive(combiner_subtree: Dictionary, last_available_index: int) -> Dictionary:
    var children: Array = combiner_subtree["children"]
    var result: Dictionary = {"root_node": combiner_subtree, "index_range": [], "children": []}
    result["index_range"] = combiner_subtree_index_range(combiner_subtree, last_available_index)
    var last_index: int = result["index_range"][1]

    for child_index in children.size():
        var child_last_index: int = last_index
        if child_index < children.size() - 1:
            child_last_index = children[child_index + 1]["first_command_index"] - 1
        result["children"].append(index_ranges_recursive(children[child_index], child_last_index))
    return result

func get_command_index(command_item: CommandListItem) -> int:
    return command_list_items.find(command_item)

func remove_command(command_item: CommandListItem) -> void:
    var command_index: int = command_list_items.find(command_item)
    if command_index != -1:
        remove_command_at(command_index)

func remove_command_at(command_index: int) -> void:
    prints("removing command at index %d" % [command_index])
    var cur_command_count: int = get_command_count()
    if command_index < 0 or command_index >= get_command_count():
        push_error("Command index out of bounds: %s" % [command_index])
        return
    if cur_command_count == 1:
        combiner_remove_all_commands()
    else:
        combiner_remove_index(command_index)
    prints("removing from cmd list")
    command_list_items.remove_at(command_index)
    prints("command list:", command_list_items)
    _dirty = true

func move_command_to_before_index(command_item: CommandListItem, new_index: int) -> void:
    var from_index: int = command_list_items.find(command_item)
    if new_index == from_index or new_index - 1 == from_index:
        return
    elif new_index > from_index:
        new_index -= 1
    remove_command_at(from_index)
    insert_command_at(command_item, new_index)

func combiner_remove_all_commands() -> void:
    combiner_tree["children"] = []

func combiner_remove_index(command_index: int) -> void:
    combiner_remove_index_recursive(calculate_all_index_ranges(), command_index)

func combiner_remove_index_recursive(index_ranges_subtree: Dictionary, removed_index: int) -> bool:
    var index_start: int = index_ranges_subtree["index_range"][0]
    var index_end: int = index_ranges_subtree["index_range"][1]
    
    if removed_index > index_end:
        # NOTE: if next sibling starts and ends on the removed index and is followed by a gap, we should
        #       set an explicit end index here if it wasn't set already
        return true

    if removed_index == index_start and index_start == index_end:
        # self and children need to be removed
        return false
    
    var combiner_node: Dictionary = index_ranges_subtree["root_node"]

    if index_ranges_subtree["children"].size() > 0:
        for child_range in index_ranges_subtree["children"]:
            var child_remains: = combiner_remove_index_recursive(child_range, removed_index)
            if not child_remains:
                combiner_node["children"].erase(child_range["root_node"])
    
    if combiner_node.has("last_command_index"):
        combiner_node["last_command_index"] -= 1
    if combiner_node["first_command_index"] > removed_index:
        combiner_node["first_command_index"] -= 1
    return true

func insert_command_at(new_command: CommandListItem, insert_at_index: int) -> void:
    if insert_at_index == get_command_count():
        append_command(new_command)
        return
    new_command.parent_list = self
    command_list_items.insert(insert_at_index, new_command)
    combiner_insert_index(calculate_all_index_ranges(), insert_at_index)
    _dirty = true

func replace_command_at(command_index: int, new_command: CommandListItem) -> void:
    if command_index < 0 or command_index >= get_command_count():
        push_error("Command index out of bounds: %s" % [command_index])
    new_command.parent_list = self
    var replaced_command = command_list_items[command_index]
    replaced_command.queue_free()
    command_list_items[command_index] = new_command
    _dirty = true

func append_command(new_command: CommandListItem) -> void:
    var top_level_combiner_command: String = combiner_tree["function"]
    if top_level_combiner_command in UNARY_FUNCTIONS:
        combiner_tree = get_default_top_level_combiner([combiner_tree])
    unset_explicit_top_level_end()
    new_command.parent_list = self
    command_list_items.append(new_command)
    _dirty = true

# deep version: Tries to put the new command at the deepest tree level possible at that index (not expanding adjacent combiners)
func combiner_insert_index(index_ranges_subtree: Dictionary, inserted_index: int) -> void:
    if inserted_index == get_command_count():
        return

    var index_start: int = index_ranges_subtree["index_range"][0]
    var index_end: int = index_ranges_subtree["index_range"][1]
    var combiner_node: Dictionary = index_ranges_subtree["root_node"]

    if inserted_index - 1 == index_end and not combiner_node.has("last_command_index"):
        combiner_node["last_command_index"] = index_end
        return
    elif inserted_index > index_end:
        return
    
    for child_range in index_ranges_subtree["children"]:
        combiner_insert_index(child_range, inserted_index)

    if inserted_index <= index_start and not is_same(combiner_node, combiner_tree):
        combiner_node["first_command_index"] += 1
    if combiner_node.has("last_command_index"):
        combiner_node["last_command_index"] += 1
        


func get_parent_combiner(parent_of: Dictionary, at_combiner_node: Dictionary = {}) -> Dictionary:
    if not at_combiner_node:
        at_combiner_node = combiner_tree
    for child_combiner in at_combiner_node["children"]:
        if is_same(child_combiner, parent_of):
            return at_combiner_node
        var found_parent: = get_parent_combiner(parent_of, child_combiner)
        if found_parent:
            return found_parent
    return {}

func get_parent_path(parents_of: Dictionary, at_combiner_node: Dictionary) -> Array:
    if is_same(at_combiner_node, parents_of):
        return []
    for child_combiner_index in at_combiner_node["children"].size():
        var child_combiner: Dictionary = at_combiner_node["children"][child_combiner_index]
        if is_same(child_combiner, parents_of):
            return [child_combiner_index]
        var parent_path: = get_parent_path(parents_of, child_combiner)
        if parent_path.size() > 0:
            parent_path.insert(0, child_combiner_index)
            return parent_path
    return []

func sort_combiner_children(combiner: Dictionary) -> void:
    var sorter: = func(a: Dictionary, b: Dictionary) -> bool: return a["first_command_index"] < b["first_command_index"]
    combiner["children"].sort_custom(sorter)


# Utility

func index_in_range(index: int, the_range: Array[int]) -> bool:
    return index >= the_range[0] and index <= the_range[1]

func ranges_overlap(range_a: Array[int], range_b: Array[int]) -> bool:
    return range_a[0] <= range_b[1] and range_a[1] >= range_b[0]

func range_contains_range(range_container: Array[int], range_containee: Array[int]) -> bool:
    return range_container[0] <= range_containee[0] and range_container[1] >= range_containee[1]

func remove_range_overlap(range_to_cut: Array[int], cutter_range: Array[int]) -> Array[int]:
    return [mini(range_to_cut[0], cutter_range[1] + 1), maxi(range_to_cut[1], cutter_range[0] - 1)]

func remove_range_spillover(range_to_cut: Array[int], cutter_range: Array[int]) -> Array[int]:
    return [maxi(range_to_cut[0], cutter_range[0]), mini(range_to_cut[1], cutter_range[1])]

func hsep() -> int:
    return int(get_theme_constant("h_separation"))

func vsep() -> int:
    return int(get_theme_constant("v_separation"))

func get_row_from_local_pos(local_pos: Vector2) -> int:
    var num_rows: int = ceili(get_child_count() / float(columns))
    for row_index in num_rows:
        var row_element: Control = get_child(row_index * columns)
        var row_start_y: int = int(row_element.position.y)
        if row_index != 0:
            row_start_y -= vsep()/2.0
        var row_end_y: int = row_start_y + row_element.size.y + vsep()
        if row_index == 0:
            row_end_y -= vsep()/2.0
        if local_pos.y >= row_start_y and local_pos.y < row_end_y:
            return row_index
    return -1

# Handling Interactively dragging top or bottom of combiner to resize

func start_resizing_combiner(local_pos: Vector2) -> void:
    resizing_click_hold = false
    is_resizing_combiner = true
    resizing_last_index = get_combiner_node_last_index(resizing_combiner_node)
    resizing_combiner_tree = combiner_tree
    combiner_tree = resizing_combiner_tree.duplicate(true)
    update_resizing_combiner(local_pos)

# Accepts current resize, discarding old tree copy in resizing_combiner_tree in favor of the current combiner_tree
func accept_combiner_resize() -> void:
    is_resizing_combiner = false
    resizing_click_hold = false
    resizing_combiner_tree = {}
    _dirty = true

# Cancels current resize, restoring the original combiner_tree
func cancel_resizing_combiner() -> void:
    is_resizing_combiner = false
    resizing_click_hold = false
    combiner_tree = resizing_combiner_tree
    resizing_combiner_tree = {}
    _dirty = true

func update_resizing_combiner(local_pos: Vector2) -> void:
    var current_row: int = get_row_from_local_pos(local_pos)

    var row_element: Control = get_child(current_row * columns)
    var in_row_pos: Vector2 = local_pos - row_element.position + Vector2(0, vsep()/2.0)
    var row_height: float = row_element.size.y + vsep()/2.0

    var resizer_at_row_index: int = current_row + 1 if in_row_pos.y >= row_height/2.0 else current_row
    var new_range: Array[int] = [resizing_combiner_node["first_command_index"], resizing_last_index]
    if is_resizing_bottom:
        new_range[1] = maxi(new_range[0], resizer_at_row_index - 1)
    else:
        new_range[0] = mini(new_range[1], resizer_at_row_index)
    var resized_version: = get_combiner_copy_for_resizing()
    resize_combiner_smart(resized_version, new_range, resizing_last_index)
    _dirty = true

func get_combiner_copy_for_resizing() -> Dictionary:
    var path_to_combiner_node: Array = get_parent_path(resizing_combiner_node, resizing_combiner_tree)
    combiner_tree = resizing_combiner_tree.duplicate(true)
    var duplicated_node: Dictionary = combiner_tree
    for path_index in path_to_combiner_node:
        duplicated_node = duplicated_node["children"][path_index]
    return duplicated_node

# Resize combiners in-place, dropping, shortening, or enveloping children and siblings as necessary

func resize_combiner_smart(resized_node: Dictionary, new_range: Array[int], current_last_index: int) -> void:
    var parent_combiner: Dictionary = get_parent_combiner(resized_node)
    var parent_range: Dictionary = calculate_combiner_subtree_index_ranges(parent_combiner, current_last_index)
    var this_range: Dictionary = parent_range["children"][parent_combiner["children"].find(resized_node)]
    var old_range: Array[int] = this_range["index_range"]

    new_range[0] = maxi(new_range[0], maxi(0, parent_range["index_range"][0]))
    new_range[1] = mini(new_range[1], mini(get_command_count() - 1, parent_range["index_range"][1]))

    if old_range == new_range:
        return
    
    if range_contains_range(this_range["index_range"], new_range):
        _resize_smart_down(resized_node, new_range, this_range, parent_combiner)
    else:
        _resize_smart_up(resized_node, new_range, parent_range)
    
    sort_combiner_children(parent_combiner)
    sort_combiner_children(resized_node)
    
    var loop_path_found: = check_for_loops(parent_combiner, [-1])
    if loop_path_found:
        prints("Oops! looping dictionary created!", loop_path_found)
        parent_combiner["children"] = []

func check_for_loops(combiner_subtree: Dictionary, current_path: Array, encountered_nodes: Array[Dictionary] = []) -> Array:
    if combiner_subtree in encountered_nodes:
        return current_path
    encountered_nodes.append(combiner_subtree)
    for child_index in combiner_subtree["children"].size():
        var loop_path_found: = check_for_loops(combiner_subtree["children"][child_index], current_path + [child_index], encountered_nodes.duplicate())
        if loop_path_found:
            return loop_path_found
    return []


func _resize_smart_down(resized_node: Dictionary, new_range: Array[int], subtree_ranges: Dictionary, drop_to_parent: Dictionary) -> void:
    var old_range: Array[int] = subtree_ranges["index_range"]
    
    for child_range_info in subtree_ranges["children"]:
        var child_range: Array[int] = child_range_info["index_range"]
        if range_contains_range(new_range, child_range):
            continue
        
        if ranges_overlap(new_range, child_range):
            # need to shorten this child. recurse, passing reference to which combiner they drop nested children to
            var new_child_range: Array[int] = remove_range_spillover(child_range, new_range)
            _resize_smart_down(child_range_info["root_node"], new_child_range, child_range_info, drop_to_parent)
        else:
            # child is now completely outside the new range, drop to the parent of the lowest combiner being resized
            drop_to_parent["children"].append(child_range_info["root_node"])
            resized_node["children"].erase(child_range_info["root_node"])

    resized_node["first_command_index"] = new_range[0]
    if new_range[1] != old_range[1]:
        resized_node["last_command_index"] = new_range[1]

func _resize_smart_up(resized_node: Dictionary, new_range: Array[int], parent_range: Dictionary) -> void:
    var old_range: Array[int] = []
    for sibling_range_info in parent_range["children"]:
        if is_same(sibling_range_info["root_node"], resized_node):
            old_range = sibling_range_info["index_range"]
            continue
        var sibling_range: Array[int] = sibling_range_info["index_range"]
        if range_contains_range(new_range, sibling_range):
            resized_node["children"].append(sibling_range_info["root_node"])
            parent_range["root_node"]["children"].erase(sibling_range_info["root_node"])
        elif ranges_overlap(new_range, sibling_range):
            var new_sibling_range: Array[int] = remove_range_overlap(sibling_range, new_range)
            _resize_smart_down(sibling_range_info["root_node"], new_sibling_range, sibling_range_info, resized_node)

    resized_node["first_command_index"] = new_range[0]
    if new_range[1] != old_range[1]:
        resized_node["last_command_index"] = new_range[1]

func do_combiner_context_menu(local_row: int, local_column: int) -> void:
    var context_menu = PopupMenu.new()
    context_menu.add_item("And", CONTEXT_MENU_CHANGE_TO_AND) 
    context_menu.add_item("Or", CONTEXT_MENU_CHANGE_TO_OR)
    context_menu.add_item("Not", CONTEXT_MENU_CHANGE_TO_NOT)
    context_menu.add_separator()
    context_menu.add_item("Add sub-group", CONTEXT_MENU_ADD_COMBINER)
    context_menu.add_item("Remove", CONTEXT_MENU_REMOVE)
    context_menu.id_pressed.connect(on_combiner_context_id_pressed.bind(local_row, local_column))
    get_window().add_child(context_menu)
    Utility.popup_context_menu_at_mouse(context_menu)

func on_combiner_context_id_pressed(context_id: int, local_row: int, local_column: int) -> void:
    var combiner_node: = get_combiner_node_at_grid_location(local_row, local_column)
    if not combiner_node:
        return
    if context_id == CONTEXT_MENU_REMOVE:
        remove_combiner(combiner_node)
    elif context_id == CONTEXT_MENU_ADD_COMBINER:
        add_child_combiner(combiner_node)
    elif context_id == CONTEXT_MENU_CHANGE_TO_AND:
        change_combiner_func(combiner_node, "and")
    elif context_id == CONTEXT_MENU_CHANGE_TO_OR:
        change_combiner_func(combiner_node, "or")
    elif context_id == CONTEXT_MENU_CHANGE_TO_NOT:
        change_combiner_func(combiner_node, "not")
    