extends VBoxContainer

signal list_edited()

signal request_edit_intermission(intermission_id: String, in_custom_list: String)
signal request_edit_duplicate_intermission(intermission_id: String, in_custom_list: String)

const IntermissionAssignmentItem: = preload("res://Scenes/Intermission/intermission_assignment_item.gd")
var assignment_item_scn: = preload("res://Scenes/Intermission/intermission_assignment_item.tscn")

@export var add_assignment_button: ButtonContainer
@export var assignment_list_container: Control

var local_custom_list_name: String = ""

var requested_duplicate_at_index: int = -1

func _ready() -> void:
    add_assignment_button.pressed.connect(on_add_assignment_button_pressed)

func set_locked_mode(locked: bool) -> void:
    add_assignment_button.disabled = locked

func load_assignments(assignments: Array) -> void:
    var all_intermission_ids: Array[String] = GameManager.get_all_intermission_ids()
    var local_intermission_ids: = _get_local_intermissions()
    clear_assignment_list()
    for intermission_id in assignments:
        if not typeof(intermission_id) == TYPE_STRING:
            continue
        if intermission_id.begins_with(":"):
            if intermission_id.trim_prefix(":") not in local_intermission_ids:
                continue
        else:
            if intermission_id not in all_intermission_ids:
                continue
        add_assignment(intermission_id)
    refresh_up_down_buttons()

func get_assignments() -> Array:
    var assignments: = []
    for assignment_item: IntermissionAssignmentItem in assignment_list_container.get_children():
        assignments.append(assignment_item.get_intermission_id())
    return assignments


func on_add_assignment_button_pressed() -> void:
    _add_assignment_item()
    refresh_up_down_buttons()
    list_edited.emit()

func _add_assignment_item() -> IntermissionAssignmentItem:
    var assignment_item: = assignment_item_scn.instantiate()
    assignment_item.is_in_custom_list = local_custom_list_name != ""
    assignment_item.custom_list_name = local_custom_list_name
    assignment_list_container.add_child(assignment_item)
    assignment_item.setup_intermission_id_selector(_get_local_intermissions())
    assignment_item.request_move_relative.connect(move_assignment_item_relative.bind(assignment_item))
    assignment_item.request_move_top_bottom.connect(move_assignment_item_top_bottom.bind(assignment_item))
    assignment_item.request_edit.connect(edit_intermission_id)
    assignment_item.request_edit_duplicate.connect(edit_duplicate_intermission_id.bind(assignment_item))
    assignment_item.request_remove.connect(remove_assignment_item.bind(assignment_item))
    assignment_item.changed.connect(list_edited.emit)
    return assignment_item

func _get_local_intermissions() -> Array[String]:
    if not local_custom_list_name:
        return []
    return GameManager.get_all_intermissions_in_custom_list(local_custom_list_name)

func add_assignment(intermission_id: String) -> void:
    var assignment_item: = _add_assignment_item()
    assignment_item.set_intermission_id(intermission_id)
    refresh_up_down_buttons()
    list_edited.emit()

func clear_assignment_list() -> void:
    for child in assignment_list_container.get_children():
        assignment_list_container.remove_child(child)
        child.queue_free()

func refresh_up_down_buttons() -> void:
    for assignment_item in assignment_list_container.get_children():
        assignment_item.refresh_up_down_buttons()


func move_assignment_item_relative(direction: int, assignment_item: IntermissionAssignmentItem) -> void:
    var new_index = assignment_item.get_index() + direction
    if new_index < 0 or new_index >= assignment_list_container.get_child_count():
        return
    assignment_list_container.move_child(assignment_item, new_index)
    refresh_up_down_buttons()
    list_edited.emit()

func move_assignment_item_top_bottom(direction: int, assignment_item: IntermissionAssignmentItem) -> void:
    var new_index = 0 if direction == -1 else assignment_list_container.get_child_count() - 1
    assignment_list_container.move_child(assignment_item, new_index)
    refresh_up_down_buttons()
    list_edited.emit()

func remove_assignment_item(assignment_item: IntermissionAssignmentItem) -> void:
    assignment_list_container.remove_child(assignment_item)
    assignment_item.queue_free()
    refresh_up_down_buttons()
    list_edited.emit()

func edit_intermission_id(intermission_id: String) -> void:
    if intermission_id.begins_with(":"):
        if not local_custom_list_name:
            return
        intermission_id = intermission_id.trim_prefix(":")
        request_edit_intermission.emit(intermission_id, local_custom_list_name)
    else:
        request_edit_intermission.emit(intermission_id, "")

func edit_duplicate_intermission_id(intermission_id: String, assignment_item: IntermissionAssignmentItem) -> void:
    if not local_custom_list_name:
        return
    if intermission_id.begins_with(":"):
        push_warning("Asking to edit a local duplicate of already local intermission %s" % intermission_id)
        intermission_id = intermission_id.trim_prefix(":")
        request_edit_intermission.emit(intermission_id, local_custom_list_name)
        return
    
    requested_duplicate_at_index = assignment_item.get_index()
    request_edit_duplicate_intermission.emit(intermission_id, local_custom_list_name)

func local_duplicate_created_with_id(new_intermission_id: String) -> void:
    var item_index: = requested_duplicate_at_index
    requested_duplicate_at_index = -1
    if not new_intermission_id or item_index == -1:
        return
    var assignment_item: = assignment_list_container.get_child(item_index)
    if not assignment_item:
        return
    assignment_item.set_intermission_id(":" + new_intermission_id)
    list_edited.emit()
