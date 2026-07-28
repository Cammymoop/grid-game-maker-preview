extends VBoxContainer

signal close_level_select()
signal to_intermission_assignments()

const SingleLevelList = preload("res://Scenes/single_level_list.gd")
const LevelSelectUIRoot = preload("res://Scenes/level_select_root.gd")
const LevelListSettings = preload("res://Scenes/level_list_settings.gd")
const RearrangableListItem = preload("res://Scenes/rearrangable_list_item.gd")
const LevelListItem = preload("res://Scenes/level_list_item.gd")

var single_level_list_scene: = preload("res://Scenes/single_level_list.tscn")
var rearrangable_level_list_scn: = preload("res://Scenes/rearrangable_list_item.tscn")

var plus_texture: = preload("res://assets/img/button_icons/plus_small.png")
var minus_texture: = preload("res://assets/img/button_icons/minus_small.png")

@export var level_select_header_label: Label

@export var level_list_container: Control

@export var tabs_container: Control
@export var bundled_levels_tab_button: Button
@export var custom_levels_tab_button: Button

@export var edit_lists_button_container: Control
@export var add_new_list_button: Button
@export var rearrange_lists_button: Button

@export var import_levels_button: Button
@export var import_levels_button_container: Control

@export var level_list_settings: LevelListSettings

@export var rearrange_lists_back_container: Control
@export var rearrange_lists_back_button: Button

@export var expand_all_container: Control
@export var expand_all_button: Button

@export var list_scroll_container: ScrollContainer

@export var no_web_container: Control
@export var open_levels_folder_button: Button

@export var edit_autosave_container: Control
@export var edit_autosave_button: Button

@export var edit_intermissions_button: Button

@export var rearrange_add_list_container: Control
@export var rearrange_add_list_button: Button

var max_height_ratio: float = 0.82
var min_max_height: float = 100

var editing_settings_of_list: String = ""
var is_rearranging_lists: bool = false
var level_select_root: LevelSelectUIRoot

var fresh_open: = true

var any_edited: = false

var is_editing_locked: = false

var is_all_lists_expanded: = false

const CTX_MOVE_UP = 3
const CTX_MOVE_DOWN = 4
const CTX_MOVE_TO_TOP = 5
const CTX_MOVE_TO_BOTTOM = 6

const CTX_REMOVE_LIST = 14

const CTX_MAKE_LIST_CUSTOM = 21
const CTX_MAKE_LIST_BUNDLED = 22


const SHOW_COMP_HIDE = "Hide"
const SHOW_COMP_COMP_REQ_TOTAL = "Completed/Required/Total"
const SHOW_COMP_COMP_REQ = "Completed/Required"
const SHOW_COMP_COMP_TOTAL = "Completed/Total"
const SHOW_COMP_COMP_REQ_VIS_TOTAL = "Completed/Required/Visible Total"
const SHOW_COMP_VIS_TOTAL = "Completed/Visible Total"

const ShowCompletionOptions: Array[String] = [
    SHOW_COMP_HIDE, SHOW_COMP_COMP_REQ_TOTAL, SHOW_COMP_COMP_REQ, SHOW_COMP_COMP_TOTAL, SHOW_COMP_COMP_REQ_VIS_TOTAL, SHOW_COMP_VIS_TOTAL,
]

func _ready() -> void:
    import_levels_button.pressed.connect(on_import_levels_button_pressed)
    level_list_settings.request_close.connect(back_to_select_from_list_settings)
    level_list_settings.list_settings_edited.connect(on_list_settings_edited)
    
    if no_web_container:
        no_web_container.visible = not OS.has_feature("web")
    if open_levels_folder_button:
        open_levels_folder_button.pressed.connect(on_open_levels_folder_button_pressed)
    
    bundled_levels_tab_button.pressed.connect(on_bundled_levels_tab_button_pressed)
    custom_levels_tab_button.pressed.connect(on_custom_levels_tab_button_pressed)
    
    add_new_list_button.pressed.connect(on_add_new_list_button_pressed)
    rearrange_add_list_button.pressed.connect(on_add_new_list_button_pressed)

    rearrange_lists_button.pressed.connect(on_rearrange_lists_button_pressed)
    
    rearrange_lists_back_button.pressed.connect(on_rearrange_lists_back_button_pressed)
    
    edit_autosave_button.pressed.connect(on_edit_autosave_button_pressed)
    
    edit_intermissions_button.pressed.connect(to_intermission_assignments.emit)
    
    expand_all_button.pressed.connect(on_expand_all_button_pressed)

    refresh()
    back_to_select_from_list_settings()

func is_non_level_item_control_focused(current_focus_owner: Control) -> bool:
    if not is_ancestor_of(current_focus_owner):
        return false
    if current_focus_owner == bundled_levels_tab_button or current_focus_owner == custom_levels_tab_button:
        return true
    if current_focus_owner == add_new_list_button or current_focus_owner == rearrange_lists_button:
        return true
    if current_focus_owner == import_levels_button or current_focus_owner == open_levels_folder_button:
        return true
    return false

# intervene when necessary to move level focus and expand/collapse level lists
func _unhandled_input(event: InputEvent) -> void:
    if is_rearranging_lists or is_in_list_settings_mode():
        return
    var is_move_up: = Utility.fixed_just_pressed_by_event("move_up", event)
    var is_move_down: = Utility.fixed_just_pressed_by_event("move_down", event)
    if not is_move_up and not is_move_down:
        return
    
    var current_focus_owner: = get_viewport().gui_get_focus_owner()
    if not current_focus_owner:
        var level_lists_with_visible_levels: = []
        for level_list in level_list_container.get_children():
            if not level_list is SingleLevelList:
                continue
            if level_list.visible_level_count() > 0:
                level_lists_with_visible_levels.append(level_list)
        if level_lists_with_visible_levels.size() == 0:
            if bundled_levels_tab_button.is_visible_in_tree():
                accept_event()
                bundled_levels_tab_button.grab_focus.call_deferred()
            return

        accept_event()
        var found_one: = false
        for level_list in level_lists_with_visible_levels:
            if level_list.is_expanded:
                level_list.focus_first_level_item()
                found_one = true
                break
        if not found_one:
            level_lists_with_visible_levels[0].set_expanded(true)
            level_lists_with_visible_levels[0].focus_first_level_item()
        return

func opening() -> void:
    editing_settings_of_list = ""
    is_rearranging_lists = false
    GameManager.recheck_level_list_unlocks()
    var is_in_custom_level: = GameManager.is_current_level_custom()
    if is_in_custom_level:
        custom_levels_tab_button.set_pressed_no_signal(true)
        bundled_levels_tab_button.set_pressed_no_signal(false)
    else:
        bundled_levels_tab_button.set_pressed_no_signal(true)
        custom_levels_tab_button.set_pressed_no_signal(false)
    fresh_open = true
    GameManager.load_non_bundled_level_lists_from_file()
    refresh()

func is_in_list_settings_mode() -> bool:
    return editing_settings_of_list != ""

func is_showing_custom_levels() -> bool:
    return custom_levels_tab_button.button_pressed

func refresh(scroll_to_level_name: String = "", scroll_to_level_list_name: String = "") -> void:
    is_editing_locked = not GameManager.is_in_level_edit_mode or GameManager.current_game_is_release_locked
    refresh_editing_locked()
    
    var is_settings_mode: = is_in_list_settings_mode()
    level_list_settings.visible = is_settings_mode

    if is_settings_mode:
        enable_background_editor()
    else:
        disable_background_editor()

    if not is_rearranging_lists and not is_settings_mode:
        editing_settings_of_list = ""
        is_rearranging_lists = false
        refresh_level_lists(scroll_to_level_name, scroll_to_level_list_name)
    elif is_in_list_settings_mode():
        refresh_list_settings()
    elif is_rearranging_lists:
        refresh_rearrangable_lists()
    
    if fresh_open:
        fresh_open = false

func refresh_editing_locked() -> void:
    var is_custom: = is_showing_custom_levels()
    var editable_order: = not (is_editing_locked and not is_custom)
    rearrange_lists_button.disabled = editable_order
    add_new_list_button.disabled = editable_order

func refresh_list_settings() -> void:
    rearrange_lists_button.hide()
    list_scroll_container.hide()
    edit_lists_button_container.hide()
    rearrange_lists_back_container.hide()
    rearrange_add_list_container.hide()
    edit_autosave_container.hide()

    level_select_header_label.hide()
    expand_all_container.hide()

    tabs_container.hide()
    import_levels_button_container.hide()
    
    prints("showing settings for list: %s" % [editing_settings_of_list])

    level_list_settings.show()
    level_list_settings.load_list_info(editing_settings_of_list)

func refresh_level_lists(scroll_to_level: String = "", scroll_to_list: String = "") -> void:
    tabs_container.show()
    list_scroll_container.show()
    rearrange_lists_button.show()
    rearrange_lists_back_container.hide()
    rearrange_add_list_container.hide()
    edit_autosave_container.hide()
    level_select_header_label.show()
    
    expand_all_container.show()

    edit_lists_button_container.visible = GameManager.is_in_level_edit_mode
    
    import_levels_button_container.visible = is_showing_custom_levels()
    if GameManager.is_in_level_edit_mode:
        import_levels_button_container.visible = true
    
    var scroll_to_item: Control = null

    clear_level_lists()
    if is_showing_custom_levels():
        for custom_level_list_info in GameManager.get_all_non_bundled_level_list_infos():
            _add_level_list(custom_level_list_info)
    else:
        if GameManager.is_in_level_edit_mode:
            for level_list_name in GameManager.get_list_of_level_lists(true):
                _add_level_list(GameManager._get_level_list(level_list_name))
        else:
            for visible_level_list in GameManager.get_all_visible_bundled_level_lists():
                _add_level_list(visible_level_list)

    if is_showing_custom_levels() or GameManager.is_in_level_edit_mode:
        var unlisted_levels: Array = GameManager.get_list_of_unlisted_levels()
        if unlisted_levels.size() > 0:
            add_unlisted_levels()
    
    var all_level_lists: Array[SingleLevelList] = []
    for child in level_list_container.get_children():
        var level_list: = child as SingleLevelList

        if not level_list:
            continue
        if is_all_lists_expanded:
            level_list.set_expanded(true, false)

        if level_list.is_list_of_unlisted_levels:
            if scroll_to_level and not scroll_to_list:
                level_list.set_expanded(true)
                scroll_to_item = level_list.get_level_item_by_name(scroll_to_level)
            continue

        all_level_lists.append(level_list)

        if level_list.level_list_name and level_list.level_list_name == scroll_to_list:
            level_list.set_expanded(true)
            if scroll_to_level:
                scroll_to_item = level_list.get_level_item_by_name(scroll_to_level)
            else:
                scroll_to_item = level_list

    for i in all_level_lists.size():
        var level_list: = all_level_lists[i]
        if not level_list:
            continue
        if i > 0:
            level_list.has_list_above = true
        if i < all_level_lists.size() - 1:
            level_list.has_list_below = true
    
    if GameManager.is_in_level_edit_mode:
        var autosave_level: = FilesManager.get_editor_autosave_level_name(GameManager.get_identified_game_name())
        if not autosave_level:
            edit_autosave_container.show()

    set_level_list_container_min_height()
    
    var none_has_current: = true
    var level_list_with_current: SingleLevelList = null
    for level_list in level_list_container.get_children():
        if not level_list is SingleLevelList:
            continue
        if level_list.has_current_level():
            none_has_current = false
            level_list_with_current = level_list
            break
    
    if fresh_open:
        if none_has_current:
            for level_list in level_list_container.get_children():
                if not level_list is SingleLevelList or level_list.visible_level_count() == 0:
                    continue
                level_list.set_expanded(true)
                if fresh_open:
                    level_list.focus_first_level_item()
        else:
            level_list_with_current.set_expanded(true)
            scroll_to_current_level(true)

    elif scroll_to_item:
        prints("scroll to control: %s" % [get_path_to(scroll_to_item)])
        scroll_to_control.bind(scroll_to_item).call_deferred()
    
    #if fresh_open:
        #scroll_to_current_level()

func _add_level_list(level_list_info: Dictionary) -> void:
    var single_level_list: SingleLevelList = single_level_list_scene.instantiate()
    _setup_level_list(single_level_list)
    level_list_container.add_child(single_level_list)
    single_level_list.load_level_list_info(level_list_info)

func _setup_level_list(lev_list: SingleLevelList) -> void:
    lev_list.play_level.connect(on_level_list_play_level)
    lev_list.edited.connect(on_level_list_edited)
    lev_list.list_membership_changed.connect(on_level_list_membership_changed)
    lev_list.request_edit_list_settings.connect(on_req_edit_list_settings)
    lev_list.request_single_list_context_menu.connect(on_request_single_list_context_menu)
    lev_list.expanded_changed.connect(on_level_list_expanded_changed.bind(lev_list))
    lev_list.focus_up_down_attempted.connect(on_level_list_focus_up_down_attempted)
    lev_list.list_item_focus_gotten.connect(on_level_list_item_focus_gotten)
    if is_editing_locked:
        lev_list.lock_editing()

func refresh_rearrangable_lists() -> void:
    tabs_container.show()
    list_scroll_container.show()
    rearrange_lists_button.hide()
    edit_lists_button_container.hide()
    rearrange_lists_back_container.show()
    rearrange_add_list_container.show()
    edit_autosave_container.hide()
    import_levels_button_container.hide()

    level_select_header_label.hide()
    expand_all_container.hide()

    clear_level_lists()
    var list_names: Array[String] = []
    if not custom_levels_tab_button.button_pressed:
        list_names = GameManager.get_list_of_level_lists(true)
    else:
        list_names = GameManager.get_list_of_non_bundled_level_lists()

    for list_name in list_names:
        var rearr_list: = rearrangable_level_list_scn.instantiate() as RearrangableListItem
        rearr_list.request_move_relative.connect(on_rearrangable_list_move_relative)
        rearr_list.request_context_menu.connect(on_rearrangable_list_request_context_menu)
        rearr_list.request_remove.connect(on_rearrangable_list_request_remove)
        rearr_list.set_list_name(list_name.trim_suffix("%"))

        var levels_in_list: = GameManager.get_levels_in_level_list(list_name)
        if levels_in_list.size() > 0:
            rearr_list.tooltip_text = "\n".join(levels_in_list)
            rearr_list.tooltip_text += "\nTotal: %d" % levels_in_list.size()
        else:
            rearr_list.tooltip_text = "Total: 0"

        level_list_container.add_child(rearr_list)
    for rearr_list in level_list_container.get_children():
        rearr_list.update_buttons_enable()
    set_level_list_container_min_height()

func add_unlisted_levels() -> void:
    var unlisted_level_list: SingleLevelList = single_level_list_scene.instantiate()
    unlisted_level_list.is_list_of_unlisted_levels = true
    _setup_level_list(unlisted_level_list)
    level_list_container.add_child(unlisted_level_list)
    unlisted_level_list.load_unlisted_levels()

func on_level_list_membership_changed(scroll_to_level: String, scroll_to_list: String) -> void:
    any_edited = true
    if not is_rearranging_lists:
        refresh(scroll_to_level, scroll_to_list)

func on_req_edit_list_settings(list_name: String) -> void:
    do_edit_settings_for_list(list_name)

func clear_level_lists() -> void:
    for child in level_list_container.get_children():
        level_list_container.remove_child(child)
        child.queue_free()

func on_level_list_edited() -> void:
    any_edited = true

func on_list_settings_edited() -> void:
    any_edited = true

func on_level_list_play_level(level_list_name: String, level_name: String) -> void:
    close()
    if GameManager.is_in_level_edit_mode:
        var map_editor: = Utility.get_map_editor()
        if map_editor:
            map_editor.load_level_in_list(level_name, level_list_name)
        #GameManager.current_level_list = level_list_name
        #GameManager.try_load_level(level_name)
    else:
        GameManager.move_to_level(level_list_name, level_name)

func close() -> void:
    close_level_select.emit()

func try_grab_focus() -> void:
    if is_in_list_settings_mode():
        level_list_settings.name_input.grab_focus.call_deferred()
    elif is_rearranging_lists:
        if level_list_container.get_child_count() > 1:
            for child in level_list_container.get_children():
                if child is RearrangableListItem:
                    child.down_button.grab_focus.call_deferred()
        else:
            rearrange_lists_back_button.grab_focus.call_deferred()
    else:
        for single_level_list in level_list_container.get_children():
            if not single_level_list is SingleLevelList:
                continue
            var focusable_list_item: LevelListItem = single_level_list.get_first_focusable_list_item()
            if focusable_list_item:
                focusable_list_item.focus_level_list_item.call_deferred()
                break

func is_active() -> bool:
    return is_visible_in_tree() and not GameManager.get_pause("pause_menu")

func _shortcut_input(event: InputEvent) -> void:
    if not is_active():
        return
    if Utility.event_is_menu_back_just_pressed(event):
        accept_event()
        if is_rearranging_lists:
            is_rearranging_lists = false
            refresh()
        elif is_in_list_settings_mode():
            back_to_select_from_list_settings()
        else:
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


func return_to_level_select_mode() -> void:
    editing_settings_of_list = ""
    is_rearranging_lists = false
    refresh()

func do_edit_settings_for_list(list_name: String) -> void:
    is_rearranging_lists = false
    editing_settings_of_list = list_name
    refresh()

func back_to_select_from_list_settings() -> void:
    editing_settings_of_list = ""
    is_rearranging_lists = false
    refresh()


func save_list_order() -> void:
    if is_editing_locked and not custom_levels_tab_button.button_pressed:
        return
    if editing_settings_of_list or not level_list_container.get_child_count() > 0:
        return
    var new_order: Array = []
    for list_item in level_list_container.get_children():
        if list_item is RearrangableListItem:
            new_order.append(list_item.get_list_name())
        elif list_item is SingleLevelList and not list_item.is_list_of_unlisted_levels:
            new_order.append(list_item.level_list_name)
    if new_order.size() > 0:
        any_edited = true
        if not custom_levels_tab_button.button_pressed:
            GameManager.update_bundled_level_list_order(new_order)
        else:
            GameManager.update_non_bundled_level_lists_order(new_order)

func on_add_new_list_button_pressed() -> void:
    level_select_root.show_add_new_list_panel()

func on_rearrange_lists_button_pressed() -> void:
    if is_rearranging_lists:
        return
    is_rearranging_lists = true
    refresh()

func on_rearrangable_list_move_relative(list_item: RearrangableListItem, relative_index: int) -> void:
    var cur_index: = list_item.get_index()
    var total_lists: = level_list_container.get_child_count()
    var new_index: = clampi(cur_index + relative_index, 0, total_lists - 1)
    level_list_container.move_child(list_item, new_index)
    save_list_order()

func move_rearrangable_list_item_to(list_item: RearrangableListItem, new_index: int) -> void:
    var total_lists: = level_list_container.get_child_count()
    if new_index < 0 or new_index >= total_lists - 1:
        return
    level_list_container.move_child(list_item, new_index)
    save_list_order()

func on_rearrangable_list_request_context_menu(list_item: RearrangableListItem) -> void:
    var context_menu: = _get_list_context_menu_common()
    context_menu.id_pressed.connect(on_list_context_menu_id_pressed.bind(true, list_item))
    Utility.popup_context_menu_at_mouse(context_menu)

func on_request_single_list_context_menu(level_list: SingleLevelList) -> void:
    var context_menu: = _get_list_context_menu_common()
    context_menu.id_pressed.connect(on_list_context_menu_id_pressed.bind(false, level_list))
    Utility.popup_context_menu_at_mouse(context_menu)

func _get_list_context_menu_common() -> PopupMenu:
    var context_menu: = Utility.get_empty_context_menu()
    context_menu.add_item("Move up", CTX_MOVE_UP)
    context_menu.add_item("Move down", CTX_MOVE_DOWN)
    context_menu.add_item("Move to top", CTX_MOVE_TO_TOP)
    context_menu.add_item("Move to bottom", CTX_MOVE_TO_BOTTOM)
    context_menu.add_separator()
    if not is_showing_custom_levels():
        context_menu.add_item("Move to Custom Level Lists", CTX_MAKE_LIST_CUSTOM)
    else:
        context_menu.add_item("Move to Main Game Lists", CTX_MAKE_LIST_BUNDLED)
        if is_editing_locked:
            var idx: = context_menu.get_item_count() - 1
            context_menu.set_item_disabled(idx, true)
    context_menu.add_separator()
    context_menu.add_item("Remove List", CTX_REMOVE_LIST)
    
    # Disable all options for bundled lists if release locked
    if is_editing_locked and not is_showing_custom_levels():
        for idx in context_menu.get_item_count():
            context_menu.set_item_disabled(idx, true)
    return context_menu


func on_list_context_menu_id_pressed(context_menu_id: int, is_rearrangable: bool, list_item: Node) -> void:
    if is_editing_locked and not is_showing_custom_levels():
        return
    if not is_rearrangable and list_item.is_list_of_unlisted_levels:
        return
    any_edited = true
    if context_menu_id == CTX_REMOVE_LIST:
        var list_item_index: = list_item.get_index()
        var scroll_to_list_name: String = ""
        for i in level_list_container.get_child_count():
            if (i == list_item_index - 1 or i == list_item_index + 1) and level_list_container.get_child(i) is SingleLevelList:
                var adj_list: = level_list_container.get_child(i) as SingleLevelList
                scroll_to_list_name = adj_list.level_list_name
        GameManager.remove_level_list(list_item.get_list_name())
        refresh("", scroll_to_list_name)
    elif context_menu_id in [CTX_MAKE_LIST_CUSTOM, CTX_MAKE_LIST_BUNDLED]:
        if not is_editing_locked:
            var to_bundled: = context_menu_id == CTX_MAKE_LIST_BUNDLED
            GameManager.change_level_list_is_bundled(list_item.get_list_name(), to_bundled)
            refresh()
    elif context_menu_id in [CTX_MOVE_UP, CTX_MOVE_DOWN]:
        var rel_index: = 1 if context_menu_id == CTX_MOVE_DOWN else -1
        if is_rearrangable:
            move_rearrangable_list_item_to(list_item, list_item.get_index() + rel_index)
        else:
            var list_name: String = list_item.level_list_name
            GameManager.move_level_list_relative(list_item.level_list_name, rel_index)
            refresh("", list_name)
    elif context_menu_id in [CTX_MOVE_TO_TOP, CTX_MOVE_TO_BOTTOM]:
        var to_index: = 0 if context_menu_id == CTX_MOVE_TO_TOP else level_list_container.get_child_count() - 1
        if is_rearrangable:
            move_rearrangable_list_item_to(list_item, to_index)
        else:
            GameManager.move_level_list_to_top_bottom(list_item.level_list_name, context_menu_id == CTX_MOVE_TO_TOP)
            refresh("", list_item.level_list_name)

func on_rearrange_lists_back_button_pressed() -> void:
    if not is_rearranging_lists:
        return
    is_rearranging_lists = false
    refresh()

func on_rearrangable_list_request_remove(list_item: RearrangableListItem) -> void:
    if is_editing_locked:
        return
    GameManager.remove_level_list(list_item.get_list_name())
    any_edited = true
    refresh()


func set_level_list_container_min_height() -> void:
    var viewport_height: = get_viewport_rect().size.y
    var max_height: = maxf(viewport_height * max_height_ratio, min_max_height)

    list_scroll_container.custom_minimum_size.y = 0
    var other_height: = get_minimum_size().y

    var list_height: = level_list_container.get_minimum_size().y
    if list_height + other_height >= max_height:
        list_scroll_container.custom_minimum_size.y = max_height - other_height
    else:
        list_scroll_container.custom_minimum_size.y = list_height + 4

func on_import_levels_button_pressed() -> void:
    GameManager.start_import_levels()


func on_bundled_levels_tab_button_pressed() -> void:
    refresh()

func on_custom_levels_tab_button_pressed() -> void:
    refresh()


func scroll_to_current_level(with_grab_focus: bool) -> void:
    await get_tree().process_frame
    var found_current_level: LevelListItem = null
    for level_list in level_list_container.get_children():
        if not level_list is SingleLevelList:
            continue
        for level_item in level_list.level_item_container.get_children():
            if not level_item is LevelListItem:
                continue
            if level_item.is_current_level():
                found_current_level = level_item
                break
        if found_current_level:
            break
    if found_current_level:
        if with_grab_focus:
            found_current_level.focus_level_list_item.call_deferred()
        scroll_to_control.bind(found_current_level).call_deferred()

func scroll_to_control(to_control: Control) -> void:
    if not to_control.is_visible_in_tree():
        #push_warning("Control %s is not visible in tree" % [to_control.get_path()])
        return
    list_scroll_container.ensure_control_visible(to_control)
    var scroll_container_global_rect: = list_scroll_container.get_global_rect()
    var to_control_global_rect: = to_control.get_global_rect()
    var center_scroll_offset: =  to_control_global_rect.get_center() - scroll_container_global_rect.get_center()
    list_scroll_container.set_deferred("scroll_vertical", list_scroll_container.scroll_vertical + center_scroll_offset.y)

func on_open_levels_folder_button_pressed() -> void:
    if not FilesManager.game_exists(GameManager.get_identified_game_name()):
        GlobalToaster.show_toast_message("Game not saved, folder doesn't exist")
        return
    var levels_folder: = FilesManager.get_game_levels_dir(GameManager.get_identified_game_name())
    OS.shell_open(ProjectSettings.globalize_path(levels_folder))


func on_edit_autosave_button_pressed() -> void:
    if not GameManager.is_in_level_edit_mode:
        return
    var map_editor: = Utility.get_map_editor()
    if map_editor:
        map_editor.load_editor_autosave()
        close()

func on_level_list_expanded_changed(changed_list: SingleLevelList) -> void:
    if changed_list.is_expanded and not is_all_lists_expanded:
        for list in level_list_container.get_children():
            if list is SingleLevelList and list != changed_list:
                list.set_expanded(false, false)

    set_level_list_container_min_height()


func get_next_prev_level_list_with_items(level_list: SingleLevelList, direction: int) -> SingleLevelList:
    direction = signi(direction)
    if direction == 0:
        return null
    var list_index: = level_list.get_index()
    
    var new_index: = list_index + direction
    while new_index >= 0 and new_index < level_list_container.get_child_count():
        var next_level_list: = level_list_container.get_child(new_index)
        new_index += direction
        if not next_level_list is SingleLevelList:
            continue
        if next_level_list.visible_level_count() > 0:
            return next_level_list
    return null

func on_level_list_focus_up_down_attempted(from_level_list: SingleLevelList, direction: int) -> void:
    if not from_level_list:
        return

    var all_level_lists: Array[SingleLevelList] = []
    for level_list in level_list_container.get_children():
        if not level_list is SingleLevelList:
            continue
        all_level_lists.append(level_list)
    
    var next_level_list: = get_next_prev_level_list_with_items(from_level_list, direction)
    if not next_level_list:
        return
    
    accept_event()
    if not next_level_list.is_expanded:
        next_level_list.set_expanded(true)
    if direction == 1:
        next_level_list.focus_first_level_item()
    else:
        next_level_list.focus_last_level_item()
    
    if not is_all_lists_expanded:
        from_level_list.set_expanded(false)

func on_level_list_item_focus_gotten(level_list_item: LevelListItem) -> void:
    scroll_to_control(level_list_item)

func on_expand_all_button_pressed() -> void:
    set_expand_all_lists(not is_all_lists_expanded)

func set_expand_all_lists(new_is_expanded: bool) -> void:
    is_all_lists_expanded = new_is_expanded
    expand_all_button.icon = minus_texture if new_is_expanded else plus_texture

    if is_in_list_settings_mode() or is_rearranging_lists:
        return
    var focused_list: SingleLevelList = null
    var all_lists: Array[SingleLevelList] = []
    for child in level_list_container.get_children():
        if child is SingleLevelList:
            all_lists.append(child)
    
    if new_is_expanded:
        for list in all_lists:
            list.set_expanded(true, false)
    else:
        var focused_control: Control = get_viewport().gui_get_focus_owner()
        if focused_control and is_ancestor_of(focused_control):
            for list in all_lists:
                if list.is_ancestor_of(focused_control):
                    focused_list = list
                    break
            if not focused_list:
                for list in all_lists:
                    if list.has_current_level():
                        focused_list = list
                        break

        for list in all_lists:
            list.set_expanded(focused_list == list, false)
    
    set_level_list_container_min_height()