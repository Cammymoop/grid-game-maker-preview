extends VBoxContainer

signal close_level_select()

const SingleLevelList = preload("res://Scenes/single_level_list.gd")
const LevelSelectUIRoot = preload("res://Scenes/level_select_root.gd")
const LevelListSettings = preload("res://Scenes/level_list_settings.gd")
const RearrangableListItem = preload("res://Scenes/rearrangable_list_item.gd")

var single_level_list_scene: = preload("res://Scenes/single_level_list.tscn")
var rearrangable_level_list_scn: = preload("res://Scenes/rearrangable_list_item.tscn")

@export var level_list_container: Control

@export var edit_lists_button_container: Control
@export var add_new_list_button: Button
@export var rearrange_lists_button: Button
@export var import_levels_button: Button

@export var level_list_settings: LevelListSettings

@export var rearrange_lists_back_container: Control
@export var rearrange_lists_back_button: Button

@export var list_scroll_container: ScrollContainer

var max_height_ratio: float = 0.82
var min_max_height: float = 100

var editing_settings_of_list: String = ""
var is_rearranging_lists: bool = false
var level_select_root: LevelSelectUIRoot

var any_edited: bool = false

var is_editing_locked: bool = false

const CTX_MOVE_UP = 3
const CTX_MOVE_DOWN = 4
const CTX_MOVE_TO_TOP = 5
const CTX_MOVE_TO_BOTTOM = 6

const CTX_REMOVE_LIST = 14


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
    
    add_new_list_button.pressed.connect(on_add_new_list_button_pressed)
    rearrange_lists_button.pressed.connect(on_rearrange_lists_button_pressed)
    
    rearrange_lists_back_button.pressed.connect(on_rearrange_lists_back_button_pressed)
    refresh()
    back_to_select_from_list_settings()

func is_in_list_settings_mode() -> bool:
    return editing_settings_of_list != ""

func refresh() -> void:
    is_editing_locked = not GameManager.is_in_level_edit_mode or GameManager.current_game_is_release_locked
    refresh_editing_locked()

    if is_editing_locked or (editing_settings_of_list == "" and not is_rearranging_lists):
        editing_settings_of_list = ""
        is_rearranging_lists = false
        refresh_level_lists()
    elif is_in_list_settings_mode():
        refresh_list_settings()
    elif is_rearranging_lists:
        refresh_rearrangable_lists()

func refresh_editing_locked() -> void:
    rearrange_lists_button.disabled = is_editing_locked
    add_new_list_button.disabled = is_editing_locked

func refresh_list_settings() -> void:
    rearrange_lists_button.hide()
    list_scroll_container.hide()
    edit_lists_button_container.hide()
    rearrange_lists_back_container.hide()

    level_list_settings.show()
    if level_list_settings.editing_list_name != editing_settings_of_list:
        level_list_settings.load_list_info(editing_settings_of_list)
    return

func refresh_level_lists() -> void:
    list_scroll_container.show()
    rearrange_lists_button.show()
    rearrange_lists_back_container.hide()

    edit_lists_button_container.visible = GameManager.is_in_level_edit_mode

    clear_level_lists()
    if GameManager.is_in_level_edit_mode:
        for level_list_name in GameManager.get_list_of_level_lists():
            _add_level_list(GameManager._get_level_list(level_list_name))
    else:
        for unlocked_level_list in GameManager.get_all_unlocked_level_lists():
            _add_level_list(unlocked_level_list)
    var unlisted_levels: Array = GameManager.get_list_of_unlisted_levels()
    if unlisted_levels.size() > 0:
        add_unlisted_levels()
    set_level_list_container_min_height()

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
    if is_editing_locked:
        lev_list.lock_editing()

func refresh_rearrangable_lists() -> void:
    list_scroll_container.show()
    rearrange_lists_button.hide()
    edit_lists_button_container.hide()
    rearrange_lists_back_container.show()

    clear_level_lists()
    for list_name in GameManager.get_list_of_level_lists():
        var rearr_list: = rearrangable_level_list_scn.instantiate() as RearrangableListItem
        rearr_list.request_move_relative.connect(on_rearrangable_list_move_relative)
        rearr_list.request_context_menu.connect(on_rearrangable_list_request_context_menu)
        rearr_list.request_remove.connect(on_rearrangable_list_request_remove)
        rearr_list.set_list_name(list_name)

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

func on_level_list_membership_changed() -> void:
    any_edited = true
    if not is_rearranging_lists:
        refresh()

func on_req_edit_list_settings(list_name: String) -> void:
    do_edit_settings_for_list(list_name)

func clear_level_lists() -> void:
    rearrange_lists_back_container.visible = false
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
        GameManager.goto_level_in_level_list(level_list_name, level_name)

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
    if level_list_settings.visible:
        return
    any_edited = true
    editing_settings_of_list = list_name
    level_list_settings.load_list_info(list_name)
    level_list_settings.show()
    list_scroll_container.hide()
    edit_lists_button_container.hide()
    if level_select_root:
        level_select_root.show_background_editor()

func back_to_select_from_list_settings() -> void:
    if not level_list_settings.visible:
        return
    editing_settings_of_list = ""
    level_list_settings.hide()
    list_scroll_container.show()
    edit_lists_button_container.show()
    if level_select_root:
        level_select_root.hide_background_editor()
    is_rearranging_lists = false
    refresh()


func save_list_order() -> void:
    if is_editing_locked:
        return
    if editing_settings_of_list or not level_list_container.get_child_count() > 0:
        return
    if level_list_container.get_child(0) is SingleLevelList:
        return
    var new_order: Array = []
    for list_item in level_list_container.get_children():
        new_order.append(list_item.get_list_name())
    GameManager.update_bundled_level_list_order(new_order)
    any_edited = true

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
    var context_menu: = Utility.get_empty_context_menu()
    context_menu.add_item("Move up", CTX_MOVE_UP)
    context_menu.add_item("Move down", CTX_MOVE_DOWN)
    context_menu.add_item("Move to top", CTX_MOVE_TO_TOP)
    context_menu.add_item("Move to bottom", CTX_MOVE_TO_BOTTOM)
    context_menu.add_separator()
    context_menu.add_item("Remove List", CTX_REMOVE_LIST)
    context_menu.id_pressed.connect(on_rearrangable_list_context_menu_id_pressed.bind(list_item))
    if is_editing_locked:
        for idx in context_menu.get_item_count():
            context_menu.set_item_disabled(idx, true)
    Utility.popup_context_menu_at_mouse(context_menu)

func on_rearrangable_list_context_menu_id_pressed(context_menu_id: int, list_item: RearrangableListItem) -> void:
    if is_editing_locked:
        return
    if context_menu_id == CTX_REMOVE_LIST:
        GameManager.remove_level_list(list_item.get_list_name())
        any_edited = true
        refresh()
    elif context_menu_id in [CTX_MOVE_UP, CTX_MOVE_DOWN]:
        var rel_index: = 1 if context_menu_id == CTX_MOVE_DOWN else -1
        move_rearrangable_list_item_to(list_item, list_item.get_index() + rel_index)
        any_edited = true
    elif context_menu_id in [CTX_MOVE_TO_TOP, CTX_MOVE_TO_BOTTOM]:
        var to_index: = 0 if context_menu_id == CTX_MOVE_TO_TOP else level_list_container.get_child_count() - 1
        move_rearrangable_list_item_to(list_item, to_index)
        any_edited = true

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
        list_scroll_container.custom_minimum_size.y = list_height

func on_import_levels_button_pressed() -> void:
    GameManager.start_import_levels()