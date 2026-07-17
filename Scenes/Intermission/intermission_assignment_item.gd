extends Control

signal request_remove()
signal request_edit(intermission_id: String)

signal request_move_relative(direction: int)
signal request_move_top_bottom(direction: int)

@export var intermission_id_selector: OptionButton

@export var edit_button: ButtonContainer

@export var up_button: ButtonContainer
@export var down_button: ButtonContainer

@export var remove_button: ButtonContainer


func _ready() -> void:
    edit_button.pressed.connect(on_edit_button_pressed)
    up_button.pressed.connect(on_up_button_pressed)
    down_button.pressed.connect(on_down_button_pressed)
    remove_button.pressed.connect(on_remove_button_pressed)

    setup_intermission_id_selector()

func setup_intermission_id_selector() -> void:
    intermission_id_selector.clear()
    for intermission_id in GameManager.get_all_intermission_ids():
        intermission_id_selector.add_item(intermission_id)

func refresh_up_down_buttons() -> void:
    var max_index = get_parent().get_child_count() - 1
    var my_index = get_index()
    up_button.disabled = my_index == 0
    down_button.disabled = my_index == max_index

func set_intermission_id(intermission_id: String) -> void:
    Utility.opbtn_select_text(intermission_id_selector, intermission_id)

func get_intermission_id() -> String:
    return Utility.opbtn_get_selected_text(intermission_id_selector)

func on_edit_button_pressed() -> void:
    request_edit.emit(get_intermission_id())

func on_remove_button_pressed() -> void:
    request_remove.emit()

func on_up_button_pressed() -> void:
    _move_pressed(-1)

func on_down_button_pressed() -> void:
    _move_pressed(1)

func _move_pressed(direction: int) -> void:
    if Input.is_action_pressed("editor_alt_mode_hold"):
        request_move_top_bottom.emit(direction)
    else:
        request_move_relative.emit(direction)