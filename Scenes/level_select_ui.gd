extends VBoxContainer

signal close_level_select()

const SingleLevelList = preload("res://Scenes/single_level_list.gd")
const LevelSelectUIRoot = preload("res://Scenes/level_select_root.gd")

var single_level_list_scene: = preload("res://Scenes/single_level_list.tscn")

@export var level_list_container: Control
@export var add_new_list_button: Button

var level_select_root: LevelSelectUIRoot

var any_edited: bool = false

func _ready() -> void:
    refresh_level_list()

func refresh() -> void:
    add_new_list_button.visible = GameManager.is_in_level_edit_mode
    refresh_level_list()

func refresh_level_list() -> void:
    clear_level_lists()
    for unlocked_level_list in GameManager.get_all_unlocked_level_lists():
        _add_level_list(unlocked_level_list)

func _add_level_list(level_list_info: Dictionary) -> void:
    var single_level_list: SingleLevelList = single_level_list_scene.instantiate()
    single_level_list.play_level.connect(on_level_list_play_level)
    single_level_list.edited.connect(on_level_list_edited)
    level_list_container.add_child(single_level_list)
    single_level_list.load_level_list_info(level_list_info)

func clear_level_lists() -> void:
    for child in level_list_container.get_children():
        level_list_container.remove_child(child)
        child.queue_free()

func on_level_list_edited() -> void:
    any_edited = true

func on_level_list_play_level(level_list_name: String, level_name: String) -> void:
    close()
    if GameManager.is_in_level_edit_mode:
        GameManager.current_level_list = level_list_name
        GameManager.try_load_level(level_name)
    else:
        GameManager.goto_level_in_level_list(level_list_name, level_name)

func close() -> void:
    close_level_select.emit()

func try_grab_focus() -> void:
    for single_level_list in level_list_container.get_children():
        var first_focusable_control: Control = single_level_list.get_first_focusable_control()
        if first_focusable_control:
            first_focusable_control.grab_focus.call_deferred()
            break

func is_active() -> bool:
    return is_visible_in_tree() and not GameManager.get_pause("pause_menu")

func _shortcut_input(event: InputEvent) -> void:
    if not is_active():
        return
    if Utility.event_is_menu_back_just_pressed(event):
        prints("menu back on level select ui", visible, is_visible_in_tree())
        close()
        GameManager.open_pause_menu()
    
func _process(_delta: float) -> void:
    if not is_active():
        return
    var current_focus_owner: = get_viewport().gui_get_focus_owner()
    if current_focus_owner and is_ancestor_of(current_focus_owner):
        return

    for focus_move_action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
        if Input.is_action_just_pressed(focus_move_action):
            try_grab_focus()

func enable_background_editor() -> void:
    if level_select_root:
        level_select_root.show_background_editor()

func disable_background_editor() -> void:
    if level_select_root:
        level_select_root.hide_background_editor()