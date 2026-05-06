extends VBoxContainer

signal request_close()

const ScalarValueInput = preload("res://src/GameEditor/ConditionalEditor/scalar_value_input.gd")

@export var back_button: Button

@export var name_input: LineEdit
@export var do_progressive_unlock_toggle: CheckButton
@export var progressive_unlock_num_container: Control
@export var progressive_unlock_num_input: ScalarValueInput

var editing_list_name: String = ""


func _ready() -> void:
    back_button.pressed.connect(request_close.emit)
    name_input.text_changed.connect(on_name_input_text_changed)
    do_progressive_unlock_toggle.toggled.connect(on_do_progressive_unlock_toggled)
    progressive_unlock_num_input.value_changed.connect(prop_unlock_num_changed)
    if editing_list_name and visible:
        refresh_ui()

func load_list_info(list_name: String) -> void:
    editing_list_name = list_name
    var list_info: = _get_list_info()
    if not list_info:
        push_error("Editing unknown level list: %s" % list_name)
        return
    refresh_ui()

func _get_list_info() -> Dictionary:
    if not editing_list_name:
        return {}
    return GameManager._get_level_list(editing_list_name)

func on_do_progressive_unlock_toggled(toggled_on: bool) -> void:
    progressive_unlock_num_container.visible = toggled_on
    if toggled_on:
        set_prog_unlock_num()
    else:
        var list_info: = _get_list_info()
        if not list_info:
            return
        list_info.erase("progressive_locked_levels")

func prop_unlock_num_changed(_new_value: float) -> void:
    set_prog_unlock_num()

func set_prog_unlock_num() -> void:
    var list_info: = _get_list_info()
    if not list_info:
        return
    var num_input_number: = int(progressive_unlock_num_input.get_value())
    list_info["progressive_locked_levels"] = num_input_number


func on_name_input_text_changed(new_text: String) -> void:
    var list_info: = _get_list_info()
    if not list_info:
        return
    list_info["name"] = new_text


func refresh_ui() -> void:
    name_input.text = editing_list_name
    var list_info: = _get_list_info()
    if not list_info:
        return
    var prog_unlock_num: = int(list_info.get("progressive_locked_levels", 0))
    do_progressive_unlock_toggle.button_pressed = prog_unlock_num > 0
    progressive_unlock_num_container.visible = prog_unlock_num > 0
    progressive_unlock_num_input.set_value(maxi(1, prog_unlock_num))
