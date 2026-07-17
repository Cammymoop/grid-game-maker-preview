extends Control

signal request_remove()
signal request_edit(intermission_id: String)
signal request_edit_duplicate(intermission_id: String)

signal request_move_relative(direction: int)
signal request_move_top_bottom(direction: int)

@export var intermission_id_selector: OptionButton

@export var edit_button: ButtonContainer
@export var edit_duplicate_button: ButtonContainer

@export var up_button: ButtonContainer
@export var down_button: ButtonContainer

@export var remove_button: ButtonContainer

var base_locked: bool = false
var is_in_custom_list: bool = false
var custom_list_name: String = ""

func _ready() -> void:
    base_locked = GameManager.current_game_is_release_locked

    edit_button.pressed.connect(on_edit_button_pressed)
    up_button.pressed.connect(on_up_button_pressed)
    down_button.pressed.connect(on_down_button_pressed)
    remove_button.pressed.connect(on_remove_button_pressed)
    
    intermission_id_selector.item_selected.connect(on_selector_item_selected)

func setup_intermission_id_selector(with_local_intermissions: Array[String]) -> void:
    intermission_id_selector.clear()
    for intermission_id in GameManager.get_all_intermission_ids():
        intermission_id_selector.add_item(intermission_id)
    
    if with_local_intermissions.size() > 0:
        intermission_id_selector.add_separator(custom_list_name)
        for intermission_id in with_local_intermissions:
            intermission_id_selector.add_item(":" + intermission_id)

func refresh_up_down_buttons() -> void:
    if base_locked and not is_in_custom_list:
        up_button.disabled = true
        down_button.disabled = true
        return
    
    var max_index = get_parent().get_child_count() - 1
    var my_index = get_index()
    up_button.disabled = my_index == 0
    down_button.disabled = my_index == max_index

func set_intermission_id(intermission_id: String) -> void:
    Utility.opbtn_select_text(intermission_id_selector, intermission_id)
    refresh_is_local_intermission(intermission_id)

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

func on_selector_item_selected(index: int) -> void:
    var current_id: = intermission_id_selector.get_item_text(index)
    refresh_is_local_intermission(current_id)

func refresh_is_local_intermission(intermission_id: String) -> void:
    var is_local: = intermission_id.begins_with(":")
    
    if is_local:
        intermission_id_selector.tooltip_text = "Intermissions that start with ':' are stored inside this custom list"
    else:
        intermission_id_selector.tooltip_text = ""
    
    var completely_locked: = base_locked and not is_in_custom_list
    
    edit_button.disabled = completely_locked
    edit_duplicate_button.visible = not is_local and is_in_custom_list
    
    up_button.disabled = completely_locked
    down_button.disabled = completely_locked
    remove_button.disabled = completely_locked
    
    if edit_button.disabled:
        edit_button.tooltip_text = "Current game is a released version.\nGo to Game Editor to unlock, or edit intermissions in custom lists for custom content"
    else:
        edit_button.tooltip_text = ""