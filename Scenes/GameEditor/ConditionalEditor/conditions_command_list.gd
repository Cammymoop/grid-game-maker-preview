extends GridContainer
class_name ConditionsCommandList

const CommandListItem = preload("res://src/GameEditor/ConditionalEditor/CommandListItem.gd")
const BoolCombinerPiece = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_piece.gd")

var bool_empty: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_empty.tscn")
var bool_single: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_single.tscn")
var bool_top: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_top.tscn")
var bool_middle: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_middle.tscn")
var bool_bottom: PackedScene = preload("res://Scenes/GameEditor/ConditionalEditor/bool_combiners/bool_combiner_bottom.tscn")

var command_list_items: Array[CommandListItem] = []

var combiner_tree: Dictionary = {
    "first_command_index": 0,
    "function": "and",
    "children": [],
}

const UNARY_FUNCTIONS = ["not"]

var combiner_column_width: int = 16

var _dirty: bool = false

func _ready():
    var temp_bool_single: = bool_single.instantiate()
    combiner_column_width = temp_bool_single.get_combined_minimum_size().x
    combiner_column_width += get_theme_constant("h_separation")
    temp_bool_single.queue_free()
    
    _dirty = true

func _process(_delta: float) -> void:
    if visible and _dirty:
        rebuild_grid()

func get_v3_command_data() -> Array:
    var commands: Array = []
    for command_item in command_list_items:
        commands.append(command_item.get_v3_call_string())
    var inserted_operations: Dictionary[int, Array] = {}
    insert_combiner_operations(calculate_all_index_ranges(), inserted_operations)
    var insert_after_indices: Array = inserted_operations.keys()
    insert_after_indices.sort()
    insert_after_indices.reverse()
    for insert_after_index in insert_after_indices:
        Utility.insert_array_at(commands, insert_after_index + 1, inserted_operations[insert_after_index])
    return commands

func insert_combiner_operations(index_ranges_subtree: Dictionary, inserted_operations: Dictionary[int, Array]) -> void:
    for child_range in index_ranges_subtree["children"]:
        insert_combiner_operations(child_range, inserted_operations)

    var last_index: int = index_ranges_subtree["index_range"][1]
    if not inserted_operations.has(last_index):
        inserted_operations[last_index] = []
    var num_ops: int = last_index - index_ranges_subtree["index_range"][0]
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
            #combiner_piece.set_border_and_bg_color(Color.WHITE, Color.WHITE)
            combiner_piece.tooltip_text = combiner_list[column_index]["root_node"]["function"].capitalize()
            add_child(combiner_piece)
        
        var margin_container: = get_list_item_margin_container(max_depth - combiner_list.size())
        margin_container.add_child(command_list_items[row_index])
        add_child(margin_container)

func get_list_item_margin_container(negative_column_count: int) -> MarginContainer:
    var margin_container: = MarginContainer.new()
    margin_container.add_theme_constant_override("margin_top", 0)
    margin_container.add_theme_constant_override("margin_bottom", 0)
    margin_container.add_theme_constant_override("margin_right", 0)
    margin_container.add_theme_constant_override("margin_left", -(negative_column_count * combiner_column_width))
    return margin_container
        

func clear_children() -> void:
    for child in get_children():
        remove_child(child)
        if _is_command_list_item(child):
            continue
        child.queue_free()

func _is_command_list_item(child: Control) -> bool:
    if child in command_list_items:
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

func calculate_all_index_ranges() -> Dictionary:
    if combiner_tree.has("last_command_index"):
        combiner_tree.erase("last_command_index")
    return index_ranges_recursive(combiner_tree, get_command_count() - 1)

func index_ranges_recursive(combiner_subtree: Dictionary, last_available_index: int) -> Dictionary:
    var children: Array = combiner_subtree["children"]
    var result: Dictionary = {"root_node": combiner_subtree, "index_range": [], "children": []}
    result["index_range"] = combiner_subtree_index_range(combiner_subtree, last_available_index)

    for child_index in children.size():
        var child_last_index: int = last_available_index
        if child_index < children.size() - 1:
            child_last_index = children[child_index + 1]["first_command_index"] - 1
        result["children"].append(index_ranges_recursive(children[child_index], child_last_index))
    return result

func remove_command_at(command_index: int) -> void:
    var cur_command_count: int = get_command_count()
    if command_index < 0 or command_index >= get_command_count():
        push_error("Command index out of bounds: %s" % [command_index])
        return
    if cur_command_count == 1:
        combiner_remove_all_commands()
    else:
        combiner_remove_index(command_index)
    command_list_items.remove_at(command_index)
    _dirty = true

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
    command_list_items.insert(insert_at_index, new_command)
    combiner_insert_index(calculate_all_index_ranges(), insert_at_index)
    _dirty = true

func append_command(new_command: CommandListItem) -> void:
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

    if inserted_index <= index_start:
        combiner_node["first_command_index"] += 1
    if combiner_node.has("last_command_index"):
        combiner_node["last_command_index"] += 1
        


