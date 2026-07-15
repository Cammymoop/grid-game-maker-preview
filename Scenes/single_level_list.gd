extends VBoxContainer

@export var expand_icon: Texture2D
@export var collapse_icon: Texture2D

const SingleLevelList = preload("res://Scenes/single_level_list.gd")

const LevelSelectUI = preload("res://Scenes/level_select_ui.gd")
const LevelListItem = preload("res://Scenes/level_list_item.gd")

signal play_level(level_list_name: String, level_name: String)
signal edited()
signal request_edit_list_settings(list_name: String)
signal list_membership_changed()
signal expanded_changed()

signal focus_up_down_attempted(level_list: SingleLevelList, direction: int)

signal request_single_list_context_menu(level_list: SingleLevelList)

var is_editing_locked: bool = false

var level_item_scene: = preload("res://Scenes/level_list_item.tscn")

@export var list_name_label: Label
@export var list_completion_label: Label
@export var level_item_container: Container
@export var edit_settings_icon_button: ButtonContainer
@export var export_list_button: Button

@export var expand_collapse_texture_button: TextureRect
@export var levels_section: Control

@export var remove_list_button: ButtonContainer

@export var is_list_of_unlisted_levels: bool = false

var is_expanded: bool = false

var level_list_name: String = ""
var is_bundled_list: bool = false

var has_list_below: bool = false
var has_list_above: bool = false

const CTX_MOVE_UP = 3
const CTX_MOVE_DOWN = 4
const CTX_MOVE_TO_TOP = 5
const CTX_MOVE_TO_BOTTOM = 6

const CTX_MOVE_TO_LIST_ABOVE = 12 
const CTX_MOVE_TO_LIST_BELOW = 13 

const CTX_MOVE_TO_FIRST_LIST = 16
const CTX_MOVE_TO_LAST_LIST = 17

const CTX_REMOVE_FROM_LIST = 21 
const CTX_REMOVE_FROM_ALL_LISTS = 22 


func _ready() -> void:
    if not GameManager.is_in_level_edit_mode:
        remove_list_button.visible = false

    export_list_button.pressed.connect(on_export_list_button_pressed)
    remove_list_button.pressed.connect(on_remove_list_button_pressed)
    
    expand_collapse_texture_button.gui_input.connect(on_expand_collapse_texture_button_gui_input)
    
    edit_settings_icon_button.button.gui_input.connect(on_list_button_gui_input.bind(edit_settings_icon_button.button))
    remove_list_button.button.gui_input.connect(on_list_button_gui_input.bind(remove_list_button.button))
    export_list_button.gui_input.connect(on_list_button_gui_input.bind(export_list_button))

    edit_settings_icon_button.pressed.connect(on_edit_list_settings_button_pressed)
    edit_settings_icon_button.visible = _is_in_edit_mode()
    export_list_button.visible = _is_in_edit_mode()
    if is_list_of_unlisted_levels:
        edit_settings_icon_button.visible = false
        export_list_button.visible = false

func visible_level_count() -> int:
    var count: int = 0
    for level_item in level_item_container.get_children():
        if not level_item is LevelListItem:
            continue
        count += 1
    return count

func focus_first_level_item() -> void:
    for level_item in level_item_container.get_children():
        if not level_item is LevelListItem:
            continue
        level_item.focus_level_list_item.call_deferred()
        break

func focus_last_level_item() -> void:
    var all_level_items: = level_item_container.get_children()
    all_level_items.reverse()
    for level_item in all_level_items:
        if not level_item is LevelListItem:
            continue
        level_item.focus_level_list_item.call_deferred()
        break

func has_current_level() -> bool:
    for level_item in level_item_container.get_children():
        if not level_item is LevelListItem:
            continue
        if level_item.is_current_level():
            return true
    return false

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.is_pressed():
        request_single_list_context_menu.emit(self)
        accept_event()

func lock_editing() -> void:
    is_editing_locked = true
    edit_settings_icon_button.disabled = true
    remove_list_button.disabled = true

func on_edit_list_settings_button_pressed() -> void:
    request_edit_list_settings.emit(level_list_name)

func _is_in_edit_mode() -> bool:
    return GameManager.is_in_level_edit_mode

func reload_list_info() -> void:
    if is_list_of_unlisted_levels:
        load_unlisted_levels()
    else:
        load_level_list_named(level_list_name)

func load_level_list_info(level_list_info: Dictionary) -> void:
    load_level_list_named(level_list_info.get("name", ""))

func load_level_list_named(with_level_list_name: String) -> void:
    export_list_button.visible = false
    remove_list_button.visible = false
    if not with_level_list_name:
        clear_level_items()
        return
    set_level_list_name(with_level_list_name)
    var level_list_info: Dictionary = GameManager._get_level_list(level_list_name)
    if not level_list_info:
        clear_level_items()
        return

    var is_edit: = _is_in_edit_mode()
    export_list_button.visible = is_edit
    remove_list_button.visible = is_edit
    refresh_list()
    update_list_completion_label()

func load_unlisted_levels() -> void:
    export_list_button.visible = false
    remove_list_button.visible = false
    level_list_name = "NONE"
    is_list_of_unlisted_levels = true
    list_name_label.text = "[Unlisted Levels]"
    is_bundled_list = false
    refresh_list()
    list_completion_label.visible = false

func update_list_completion_label() -> void:
    var show_completion: bool = GameManager.should_show_list_completion(level_list_name)
    list_completion_label.visible = show_completion
    if show_completion:
        list_completion_label.text = GameManager.get_list_completion_text(level_list_name)
        list_completion_label.tooltip_text = GameManager.get_list_completion_tooltip(level_list_name)

func set_level_list_name(new_level_list_name: String) -> void:
    level_list_name = new_level_list_name
    list_name_label.text = level_list_name
    is_bundled_list = GameManager.is_level_list_bundled(level_list_name)

func refresh_list() -> void:
    levels_section.visible = is_expanded
    
    if is_expanded:
        expand_collapse_texture_button.texture = collapse_icon
    else:
        expand_collapse_texture_button.texture = expand_icon

    clear_level_items()
    var levels_with_info: Array[Dictionary] = GameManager.get_levels_to_show_in_level_list(level_list_name, _is_in_edit_mode(), is_list_of_unlisted_levels)
    for level_info in levels_with_info:
        if level_info["is_hidden"]:
            continue
        _add_level_item(level_info)

    refresh_all_items_move_buttons()

#func _add_level_item(with_level_name: String, with_level_title: String, as_played: bool, as_completed: bool) -> LevelListItem:
func _add_level_item(level_info: Dictionary) -> LevelListItem:
    var level_item: Control = level_item_scene.instantiate()
    level_item.is_editing_locked = is_editing_locked
    level_item.is_in_bundled_list = is_bundled_list
    level_item.set_level_name_and_title(level_info["level_name"], level_info["display_title"])
    if is_list_of_unlisted_levels:
        level_item.not_in_a_list()
    else:
        level_item.level_list_name = level_list_name
    var is_edit: = _is_in_edit_mode()
    level_item.set_edit_mode(is_edit)
    if not is_edit:
        level_item.set_is_completed_is_played(level_info["is_completed"], level_info["is_played"])
        level_item.set_is_unlocked(level_info["is_unlocked"])
    level_item.play_level.connect(on_level_item_play_level)
    level_item.request_edit_level.connect(on_level_item_request_edit_level)
    level_item.request_context_menu.connect(on_level_item_request_context_menu)
    level_item.request_move_relative.connect(move_list_item_relative)
    level_item.focus_up_down_attempted.connect(on_level_item_focus_up_down_attempted)
    level_item_container.add_child(level_item)
    return level_item

func on_level_item_play_level(level_name: String) -> void:
    if not level_list_name:
        push_warning("Level list name is not set for level list %s" % [get_path()])
        return
    play_level.emit(level_list_name, level_name)

func on_level_item_request_edit_level(level_name: String, as_autosave: bool) -> void:
    if not level_name or not _is_in_edit_mode():
        return
    var map_editor: = Utility.get_map_editor()
    if map_editor:
        if as_autosave:
            map_editor.load_editor_autosave()
        elif is_list_of_unlisted_levels:
            map_editor.load_level_in_list(level_name, "")
        else:
            map_editor.load_level_in_list(level_name, level_list_name)

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
    if not is_list_of_unlisted_levels:
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
    
    var total_lists: int = get_total_list_count()

    context_menu.add_separator()
    if not is_list_of_unlisted_levels:
        context_menu.add_item("Move to next list", CTX_MOVE_TO_LIST_BELOW)
        if not has_list_below:
            context_menu.set_item_disabled(context_menu.item_count - 1, true)
        context_menu.add_item("Move to previous list", CTX_MOVE_TO_LIST_ABOVE)
        if not has_list_above:
            context_menu.set_item_disabled(context_menu.item_count - 1, true)

    if total_lists >= 1:
        context_menu.add_item("Move to first list", CTX_MOVE_TO_FIRST_LIST)
        if not has_list_above and not is_list_of_unlisted_levels:
            context_menu.set_item_disabled(context_menu.item_count - 1, true)
        context_menu.add_item("Move to last list", CTX_MOVE_TO_LAST_LIST)
        if not has_list_below and not is_list_of_unlisted_levels:
            context_menu.set_item_disabled(context_menu.item_count - 1, true)

    if not is_list_of_unlisted_levels:
        context_menu.add_item("Remove from this list", CTX_REMOVE_FROM_LIST)
    
    if GameManager.is_level_in_any_list(level_item.level_name):
        context_menu.add_item("Remove level from all lists", CTX_REMOVE_FROM_ALL_LISTS)

    context_menu.id_pressed.connect(on_context_menu_id_pressed.bind(level_item))
    add_child(context_menu)
    Utility.popup_context_menu_at_mouse(context_menu)

func is_showing_custom_levels() -> bool:
    if not is_list_of_unlisted_levels and level_list_name:
        return not GameManager.is_level_list_bundled(level_list_name)
    var level_select_ui: = find_parent("LevelSelectUI") as LevelSelectUI
    if level_select_ui:
        prints("asking level select ui for custom levels")
        return level_select_ui.is_showing_custom_levels()
    prints("unable to find level select ui")
    return false

func get_total_list_count() -> int:
    if is_showing_custom_levels():
        return GameManager.get_list_of_non_bundled_level_lists().size()
    else:
        return GameManager.get_list_of_level_lists(true).size()

func move_list_item_relative(list_item: LevelListItem, relative_index: int) -> void:
    if not list_item or not level_item_container == list_item.get_parent():
        return
    var total_items: int = level_item_container.get_child_count()
    var current_index: int = list_item.get_index()
    var moved_index: int = clampi(current_index + relative_index, 0, total_items - 1)
    level_item_container.move_child(list_item, moved_index)
    refresh_all_items_move_buttons()
    update_saved_order()

func move_list_item_to(list_item: LevelListItem, new_index: int) -> void:
    var total_items: int = level_item_container.get_child_count()
    if new_index > total_items - 1:
        new_index = total_items - 1
    level_item_container.move_child(list_item, new_index)
    refresh_all_items_move_buttons()
    update_saved_order()

func refresh_all_items_move_buttons() -> void:
    for list_item in level_item_container.get_children():
        if not list_item is LevelListItem:
            continue
        list_item.refresh_move_buttons()

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
        if not is_list_of_unlisted_levels:
            GameManager.remove_level_from_list(for_list_item.level_name, level_list_name)
            list_membership_changed.emit()
    elif context_menu_id == CTX_REMOVE_FROM_ALL_LISTS:
        GameManager._remove_level_from_all_lists(for_list_item.level_name)
        list_membership_changed.emit()
    elif context_menu_id in [CTX_MOVE_TO_LIST_ABOVE, CTX_MOVE_TO_LIST_BELOW, CTX_MOVE_TO_FIRST_LIST, CTX_MOVE_TO_LAST_LIST]:
        if is_list_of_unlisted_levels:
            if context_menu_id in [CTX_MOVE_TO_LIST_ABOVE, CTX_MOVE_TO_LIST_BELOW]:
                return
        if context_menu_id == CTX_MOVE_TO_LIST_ABOVE:
            if not has_list_above:
                return
            GameManager.move_level_to_relative_list(for_list_item.level_name, level_list_name, -1)
        elif context_menu_id == CTX_MOVE_TO_LIST_BELOW:
            if not has_list_below:
                return
            GameManager.move_level_to_relative_list(for_list_item.level_name, level_list_name, 1)
        else:
            if is_list_of_unlisted_levels:
                var total_lists: int = get_total_list_count()
                var to_index: = 0 if context_menu_id == CTX_MOVE_TO_FIRST_LIST else total_lists - 1
                GameManager.add_level_to_list_index(for_list_item.level_name, not is_showing_custom_levels(), to_index)
            else:
                var is_bundled: = GameManager.is_level_list_bundled(level_list_name)
                var all_lists: Array[String] = []
                if is_bundled:
                    all_lists = GameManager.get_list_of_level_lists(true)
                else:
                    all_lists = GameManager.get_list_of_non_bundled_level_lists()
                var idx: int = 0 if context_menu_id == CTX_MOVE_TO_FIRST_LIST else all_lists.size() - 1
                GameManager.move_level_to_level_list(for_list_item.level_name, all_lists[idx], level_list_name)
        list_membership_changed.emit()

func get_first_focusable_list_item() -> LevelListItem:
    for list_item in level_item_container.get_children():
        if not list_item is LevelListItem:
            continue
        if list_item.can_be_focused():
            return list_item
    return null

func on_export_list_button_pressed() -> void:
    if not level_list_name:
        return
    GameManager.export_level_list(level_list_name)

func on_remove_list_button_pressed() -> void:
    if not GameManager.is_in_level_edit_mode or not level_list_name:
        return
    GameManager.remove_level_list(level_list_name)
    list_membership_changed.emit()

func set_expanded(new_is_expanded: bool, do_emit: bool = true) -> void:
    is_expanded = new_is_expanded
    refresh_list()
    if do_emit:
        expanded_changed.emit()

func on_expand_collapse_texture_button_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
        accept_event()
        set_expanded(not is_expanded)

func on_level_item_focus_up_down_attempted(level_item: LevelListItem, direction: int) -> void:
    var all_level_items: Array[LevelListItem] = []
    for item in level_item_container.get_children():
        if not item is LevelListItem:
            continue
        all_level_items.append(item)

    var current_index: int = all_level_items.find(level_item)
    var new_index: int = current_index + direction
    if new_index < 0 or new_index >= all_level_items.size():
        on_level_item_focus_up_down_out(direction)
        return

    while not all_level_items[new_index].can_be_focused():
        new_index += direction
        if new_index < 0 or new_index >= all_level_items.size():
            on_level_item_focus_up_down_out(direction)
            return

    accept_event()
    all_level_items[new_index].focus_level_list_item.call_deferred()

func on_level_item_focus_up_down_out(direction: int) -> void:
    if direction < 0:
        for list_button in [export_list_button, edit_settings_icon_button.button, remove_list_button.button]:
            if list_button.is_visible_in_tree():
                accept_event()
                list_button.grab_focus.call_deferred()
                return
    focus_up_down_attempted.emit(self, direction)

func on_list_button_gui_input(event: InputEvent, button: Control) -> void:
    if button == export_list_button and Utility.fixed_just_pressed_by_event("move_right", event):
        if remove_list_button.is_visible_in_tree():
            accept_event()
            remove_list_button.button.grab_focus.call_deferred()
        return

    if not button.has_focus():
        return
    var is_move_up: = Utility.fixed_just_pressed_by_event("move_up", event)
    var is_move_down: = Utility.fixed_just_pressed_by_event("move_down", event)
    if not is_move_up and not is_move_down:
        return
    var direction: int = 1 if is_move_down else -1
    
    if is_move_down:
        for list_item in level_item_container.get_children():
            if not list_item is LevelListItem:
                continue
            if list_item.can_be_focused():
                accept_event()
                list_item.focus_level_list_item.call_deferred()
                return
    focus_up_down_attempted.emit(self, direction)