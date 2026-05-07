extends VBoxContainer

const LevelListItem = preload("res://Scenes/level_list_item.gd")

signal play_level(level_list_name: String, level_name: String)
signal edited()
signal request_edit_list_settings(list_name: String)
signal list_membership_changed()

var level_item_scene: = preload("res://Scenes/level_list_item.tscn")

@export var list_name_label: Label
@export var level_item_container: Container
@export var edit_list_settings_button: Button

@export var is_list_of_unlisted_levels: bool = false

var level_list_name: String = ""

const CTX_MOVE_UP = 3
const CTX_MOVE_DOWN = 4
const CTX_MOVE_TO_TOP = 5
const CTX_MOVE_TO_BOTTOM = 6

const CTX_MOVE_TO_LIST_ABOVE = 12 
const CTX_MOVE_TO_LIST_BELOW = 13 
const CTX_REMOVE_FROM_LIST = 14 


func _ready() -> void:
    edit_list_settings_button.pressed.connect(on_edit_list_settings_button_pressed)
    edit_list_settings_button.visible = _is_in_edit_mode()

func on_edit_list_settings_button_pressed() -> void:
    request_edit_list_settings.emit(level_list_name)

func _is_in_edit_mode() -> bool:
    return GameManager.is_in_level_edit_mode

func reload_list_info() -> void:
    var level_list_info: Dictionary = GameManager._get_level_list(level_list_name)
    if not level_list_info:
        push_error("Level list info is gone ;-;")
        queue_free()
        return
    if is_list_of_unlisted_levels:
        load_unlisted_levels()
    else:
        load_level_list_info(level_list_info)

func load_level_list_info(level_list_info: Dictionary) -> void:
    set_level_list_name(level_list_info.get("name", ""))
    setup_levels(level_list_info)

func load_unlisted_levels() -> void:
    level_list_name = "NONE"
    is_list_of_unlisted_levels = true
    list_name_label.text = "NO LIST"
    setup_levels({})

func set_level_list_name(new_level_list_name: String) -> void:
    level_list_name = new_level_list_name
    list_name_label.text = level_list_name

func setup_levels(level_list_info: Dictionary) -> void:
    clear_level_items()
    var show_locked_levels: bool = level_list_info.get("show_locked_levels", true)
    if _is_in_edit_mode():
        show_locked_levels = true
    var all_played_levels: Array = GameManager.get_game_save_data("played_levels", [])
    var all_completed_levels: Array = GameManager.get_game_save_data("completed_levels", [])
    var existing_levels: Array = []
    var unlocked_levels: Array = []
    if is_list_of_unlisted_levels:
        existing_levels = GameManager.get_list_of_unlisted_levels()
        existing_levels.sort()
        unlocked_levels = existing_levels
    else:
        existing_levels = GameManager.get_levels_in_level_list(level_list_name)
        unlocked_levels = GameManager.get_unlocked_levels_in_level_list(level_list_name)

    for level_name in existing_levels:
        var level_title: = FilesManager.get_level_title(GameManager.cur_game_name, level_name)
        var list_item: LevelListItem
        if is_list_of_unlisted_levels:
            list_item = _add_level_item(level_name, level_title, false, false)
        else:
            var level_code: = GameManager._level_code(level_list_name, level_name)
            list_item = _add_level_item(level_name, level_title, level_code in all_played_levels, level_code in all_completed_levels)
        if not show_locked_levels and not level_name in unlocked_levels:
            list_item.visible = false

    for list_item: LevelListItem in level_item_container.get_children():
        list_item.refresh_move_buttons()

func _add_level_item(with_level_name: String, with_level_title: String, as_played: bool, as_completed: bool) -> LevelListItem:
    var unlocked_levels: Array = GameManager.get_unlocked_levels_in_level_list(level_list_name)
    var this_is_unlocked: bool = with_level_name in unlocked_levels

    var level_item: Control = level_item_scene.instantiate()
    level_item.set_level_name_and_title(with_level_name, with_level_title)
    var is_edit: = _is_in_edit_mode()
    level_item.set_edit_mode(is_edit)
    if is_list_of_unlisted_levels:
        level_item.not_in_a_list()
    if not is_edit:
        level_item.set_is_completed_is_played(as_completed, as_played)
        level_item.set_is_unlocked(this_is_unlocked)
    level_item.play_level.connect(on_level_item_play_level)
    level_item.request_edit_level.connect(on_level_item_request_edit_level)
    level_item.request_context_menu.connect(on_level_item_request_context_menu)
    level_item.request_move_relative.connect(move_list_item_relative)
    level_item_container.add_child(level_item)
    return level_item

func on_level_item_play_level(level_name: String) -> void:
    if not level_list_name:
        push_warning("Level list name is not set for level list %s" % [get_path()])
        return
    play_level.emit(level_list_name, level_name)

func on_level_item_request_edit_level(level_name: String) -> void:
    if not level_name or not _is_in_edit_mode():
        return


func clear_level_items() -> void:
    for child in level_item_container.get_children():
        level_item_container.remove_child(child)
        child.queue_free()

func on_level_item_request_context_menu(level_item: LevelListItem) -> void:
    if not level_item or not _is_in_edit_mode():
        return
    var total_items: int = level_item_container.get_child_count()
    var item_index: int = level_item.get_index()

    var context_menu: = Utility.get_empty_context_menu()
    context_menu.add_item("Move up", CTX_MOVE_UP)
    context_menu.add_item("Move down", CTX_MOVE_DOWN)
    context_menu.add_separator()
    context_menu.add_item("Move to top", CTX_MOVE_TO_TOP)
    context_menu.add_item("Move to bottom", CTX_MOVE_TO_BOTTOM)
    if item_index == 0:
        Utility.popupmenu_set_enabled_for_id(context_menu, CTX_MOVE_UP, false)
        Utility.popupmenu_set_enabled_for_id(context_menu, CTX_MOVE_TO_TOP, false)
    if item_index >= total_items - 1:
        Utility.popupmenu_set_enabled_for_id(context_menu, CTX_MOVE_DOWN, false)
        Utility.popupmenu_set_enabled_for_id(context_menu, CTX_MOVE_TO_BOTTOM, false)
    
    var has_next_list: bool = GameManager.level_list_has_next(level_list_name)
    var has_previous_list: bool = GameManager.level_list_has_previous(level_list_name)
    var total_lists: int = GameManager.get_list_of_level_lists().size()

    context_menu.add_separator()
    if is_list_of_unlisted_levels:
        if total_lists >= 1:
            context_menu.add_item("Move to first list", CTX_MOVE_TO_LIST_ABOVE)
            context_menu.add_item("Move to last list", CTX_MOVE_TO_LIST_BELOW)
    else:
        if has_next_list:
            context_menu.add_item("Move to next list", CTX_MOVE_TO_LIST_BELOW)
        if has_previous_list:
            context_menu.add_item("Move to previous list", CTX_MOVE_TO_LIST_ABOVE)
        context_menu.add_item("Remove from this list", CTX_REMOVE_FROM_LIST)

    context_menu.id_pressed.connect(on_context_menu_id_pressed.bind(level_item))
    add_child(context_menu)
    Utility.popup_context_menu_at_mouse(context_menu)

func move_list_item_relative(list_item: LevelListItem, relative_index: int) -> void:
    if not list_item or not level_item_container == list_item.get_parent():
        return
    var total_items: int = level_item_container.get_child_count()
    var current_index: int = list_item.get_index()
    var moved_index: int = clampi(current_index + relative_index, 0, total_items - 1)
    level_item_container.move_child(list_item, moved_index)
    update_saved_order()

func move_list_item_to(list_item: LevelListItem, new_index: int) -> void:
    var total_items: int = level_item_container.get_child_count()
    if new_index > total_items - 1:
        new_index = total_items - 1
    level_item_container.move_child(list_item, new_index)
    update_saved_order()

func update_saved_order() -> void:
    var level_list_info: Dictionary = GameManager._get_level_list(level_list_name)
    var level_names: Array = []
    for list_item: LevelListItem in level_item_container.get_children():
        if list_item and list_item.level_name:
            level_names.append(list_item.level_name)
    level_list_info["level_names"] = level_names
    edited.emit()

func on_context_menu_id_pressed(context_menu_id: int, for_list_item: LevelListItem) -> void:
    if context_menu_id in [CTX_MOVE_UP, CTX_MOVE_DOWN]:
        move_list_item_relative(for_list_item, 1 if context_menu_id == CTX_MOVE_DOWN else -1)
    elif context_menu_id in [CTX_MOVE_TO_TOP, CTX_MOVE_TO_BOTTOM]:
        var end_index: = level_item_container.get_child_count() - 1
        move_list_item_to(for_list_item, 0 if context_menu_id == CTX_MOVE_TO_TOP else end_index)
    elif context_menu_id == CTX_REMOVE_FROM_LIST:
        GameManager.remove_level_from_list(for_list_item.level_name, level_list_name)
        edited.emit()
        reload_list_info()
    elif context_menu_id in [CTX_MOVE_TO_LIST_ABOVE, CTX_MOVE_TO_LIST_BELOW]:
        if is_list_of_unlisted_levels:
            var total_lists: int = GameManager.get_list_of_level_lists().size()
            var to_index: = 0 if context_menu_id == CTX_MOVE_TO_LIST_ABOVE else total_lists - 1
            GameManager.add_level_to_list_index(for_list_item.level_name, to_index)
        else:
            var delta: = 1 if context_menu_id == CTX_MOVE_TO_LIST_BELOW else -1
            GameManager.move_level_to_relative_list(for_list_item.level_name, level_list_name, delta)
        list_membership_changed.emit()

func get_first_focusable_control() -> Control:
    for list_item: LevelListItem in level_item_container.get_children():
        if list_item.start_level_button.visible and not list_item.start_level_button.disabled:
            return list_item.start_level_button
        elif list_item.edit_level_button.visible and not list_item.edit_level_button.disabled:
            return list_item.edit_level_button
    return null