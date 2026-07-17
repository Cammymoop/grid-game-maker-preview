extends VBoxContainer

const IntermissionAssignmentItem: = preload("res://Scenes/Intermission/intermission_assignment_item.gd")
var assignment_item_scn: = preload("res://Scenes/Intermission/intermission_assignment_item.tscn")

@export var add_assignment_button: ButtonContainer
@export var assignment_list_container: Control


func _ready() -> void:
    add_assignment_button.pressed.connect(on_add_assignment_button_pressed)

func load_assignments(assignments: Array) -> void:
    var all_intermission_ids: = GameManager.get_all_intermission_ids()
    clear_assignment_list()
    for intermission_id in assignments:
        if not typeof(intermission_id) == TYPE_STRING or intermission_id not in all_intermission_ids:
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

func _add_assignment_item() -> IntermissionAssignmentItem:
    var assignment_item: = assignment_item_scn.instantiate()
    assignment_list_container.add_child(assignment_item)
    assignment_item.request_move_relative.connect(move_assignment_item_relative.bind(assignment_item))
    assignment_item.request_move_top_bottom.connect(move_assignment_item_top_bottom.bind(assignment_item))
    assignment_item.request_edit.connect(edit_intermission_id)
    assignment_item.request_remove.connect(remove_assignment_item.bind(assignment_item))
    return assignment_item

func add_assignment(intermission_id: String) -> void:
    var assignment_item: = _add_assignment_item()
    assignment_item.set_intermission_id(intermission_id)
    refresh_up_down_buttons()

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

func move_assignment_item_top_bottom(direction: int, assignment_item: IntermissionAssignmentItem) -> void:
    var new_index = 0 if direction == -1 else assignment_list_container.get_child_count() - 1
    assignment_list_container.move_child(assignment_item, new_index)
    refresh_up_down_buttons()

func remove_assignment_item(assignment_item: IntermissionAssignmentItem) -> void:
    assignment_list_container.remove_child(assignment_item)
    assignment_item.queue_free()
    refresh_up_down_buttons()

func edit_intermission_id(intermission_id: String) -> void:
    pass
