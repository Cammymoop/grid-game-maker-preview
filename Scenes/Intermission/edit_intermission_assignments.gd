extends HBoxContainer

const IntermissionAssignmentList: = preload("res://Scenes/Intermission/intermission_assignment_list.gd")

signal request_back()

signal to_intermission_editor(with_intermission_id: String, in_custom_list: String, is_duplicate: bool)
signal to_intermission_editor_new(in_custom_list: String)

@export var main_content_container: Control

@export var before_start_assignment_list: IntermissionAssignmentList
@export var after_complete_assignment_list: IntermissionAssignmentList
@export var after_last_level_assignment_list: IntermissionAssignmentList

@export var editing_cur_level_disclaimer: Control

@export var game_fail_section: Control
@export var game_fail_assignment_list: IntermissionAssignmentList

@export var custom_failure_assignment_list: IntermissionAssignmentList

@export var before_container: Control
@export var after_container: Control

@export var list_or_list_name_section: Control
@export var type_label: Label
@export var level_or_list_name_label: Label

@export var next_nav_button: Button
@export var previous_nav_button: Button

@export var back_button: Button


@export var go_to_intermission_editor_button: Button
@export var edit_new_intermission_button: ButtonContainer

@onready var all_assignment_lists: Array[IntermissionAssignmentList] = [
    before_start_assignment_list,
    after_complete_assignment_list,
    after_last_level_assignment_list,
    custom_failure_assignment_list,
    game_fail_assignment_list,
]


enum Events {
    NEW_GAME,
    LEVEL_LIST_START,
    LEVEL_START,

    LEVEL_COMPLETE,
    LEVEL_LIST_COMPLETE,
    LEVEL_LIST_ALL_COMPLETE,
    GAME_COMPLETE,
    GAME_ALL_COMPLETE,
    
    DEFAULT_FAIL_STATE,
    CUSTOM_FAIL_STATE,
}

const EVENT_KEYS: = {
    Events.NEW_GAME: "new_game",
    Events.LEVEL_LIST_START: "before_start",
    Events.LEVEL_START: "before_start",

    Events.LEVEL_COMPLETE: "after_complete",
    Events.LEVEL_LIST_COMPLETE: "after_complete",
    Events.LEVEL_LIST_ALL_COMPLETE: "after_last_level",
    Events.GAME_COMPLETE: "game_complete",
    Events.GAME_ALL_COMPLETE: "all_levels_complete",
    
    Events.DEFAULT_FAIL_STATE: "fail_state",
    Events.CUSTOM_FAIL_STATE: "custom_fail",
}


enum Modes {
    GAME,
    BUNDLED_LISTS,
    CUSTOM_LISTS,
    LEVELS,
}

@export var mode_tab_buttons_container: Control

@export var game_mode_btn: Button
@export var bundled_lists_btn: Button
@export var custom_lists_btn: Button
@export var levels_btn: Button

var assignment_list_getting_duplicate: IntermissionAssignmentList

var current_level_list_name: String = ""
var current_level_name: String = ""

var remembered_level_name: String = ""
var remembered_bundled_list_name: String = ""
var remembered_custom_list_name: String = ""

func _ready() -> void:
    var potential_lists: = all_assignment_lists.duplicate()
    all_assignment_lists.clear()
    for a in potential_lists:
        if a:
            all_assignment_lists.append(a)
    
    for assignment_list in all_assignment_lists:
        assignment_list.list_edited.connect(on_any_assignment_changed)
        assignment_list.request_edit_intermission.connect(on_request_edit_intermission)
        assignment_list.request_edit_duplicate_intermission.connect(on_request_duplicate_intermission.bind(assignment_list))
    
    back_button.pressed.connect(request_back.emit)

    go_to_intermission_editor_button.pressed.connect(on_intermission_editor_button_pressed)
    edit_new_intermission_button.pressed.connect(on_new_intermission_button_pressed)
    
    next_nav_button.pressed.connect(on_navigate.bind(1))
    previous_nav_button.pressed.connect(on_navigate.bind(-1))
    
    game_mode_btn.pressed.connect(edit_assignments_for_game)
    bundled_lists_btn.pressed.connect(edit_first_bundled_list)
    custom_lists_btn.pressed.connect(edit_first_custom_list)
    levels_btn.pressed.connect(edit_first_level)


func edit_first_bundled_list() -> void:
    var all_bundled_lists: Array = GameManager.get_list_of_level_lists(true)
    if all_bundled_lists.size() == 0:
        push_error("No bundled lists found")
        return
    if remembered_bundled_list_name in all_bundled_lists:
        edit_assignments_for_level_list(remembered_bundled_list_name)
    else:
        edit_assignments_for_level_list(all_bundled_lists[0])

func edit_first_custom_list() -> void:
    var all_custom_lists: Array[String] = GameManager.get_list_of_non_bundled_level_lists()
    if all_custom_lists.size() == 0:
        push_error("No custom lists found")
        return
    if remembered_custom_list_name in all_custom_lists:
        edit_assignments_for_level_list(remembered_custom_list_name)
    else:
        edit_assignments_for_level_list(all_custom_lists[0])

func edit_first_level() -> void:
    var all_levels: Array[String] = GameManager.get_all_existing_levels_sorted_by_chronology()
    if all_levels.size() == 0:
        push_error("No levels found")
        return
    if remembered_level_name in all_levels:
        edit_assignments_for_level(remembered_level_name)
    else:
        edit_assignments_for_level(all_levels[0])


func edit_assignments_for_level_list(level_list_name: String) -> void:
    if not level_list_name or level_list_name not in GameManager.get_list_of_level_lists():
        push_error("Invalid level list name: %s" % level_list_name)
        return
    
    current_level_list_name = level_list_name
    current_level_name = ""
    var is_bundled_list: bool = GameManager.is_level_list_bundled(level_list_name)
    var new_mode: = Modes.BUNDLED_LISTS if is_bundled_list else Modes.CUSTOM_LISTS
    set_current_mode(new_mode)
    
    if is_bundled_list:
        remembered_bundled_list_name = level_list_name
    else:
        remembered_custom_list_name = level_list_name
    
    refresh_ui()

func edit_assignments_for_level(level_name: String) -> void:
    if not level_name or not FilesManager.level_exists(GameManager.get_identified_game_name(), level_name):
        push_error("Invalid level name: %s" % level_name)
        return
    
    current_level_name = level_name
    remembered_level_name = level_name
    current_level_list_name = ""
    set_current_mode(Modes.LEVELS)
    
    refresh_ui()

func edit_assignments_for_game() -> void:
    current_level_name = ""
    current_level_list_name = ""
    set_current_mode(Modes.GAME)
    
    refresh_ui()


func refresh_ui() -> void:
    assignment_list_getting_duplicate = null
    var current_mode: = get_current_mode()
    var locked: bool = GameManager.current_game_is_release_locked
    
    list_or_list_name_section.visible = current_mode in [Modes.BUNDLED_LISTS, Modes.CUSTOM_LISTS, Modes.LEVELS]
    if list_or_list_name_section.visible:
        if current_mode == Modes.LEVELS:
            type_label.text = "Level:"
            level_or_list_name_label.text = FilesManager.get_level_title(GameManager.get_identified_game_name(), current_level_name)
        else:
            type_label.text = "List:"
            level_or_list_name_label.text = current_level_list_name
    
    game_fail_section.visible = current_mode == Modes.GAME
    
    edit_new_intermission_button.disabled = locked
    if locked and current_mode == Modes.CUSTOM_LISTS:
        edit_new_intermission_button.disabled = current_level_list_name == ""
    
    var all_bundled_lists: Array = GameManager.get_list_of_level_lists(true)
    var all_custom_lists: Array[String] = GameManager.get_list_of_non_bundled_level_lists()
    
    bundled_lists_btn.disabled = all_bundled_lists.size() == 0
    custom_lists_btn.disabled = all_custom_lists.size() == 0
    levels_btn.disabled = FilesManager.get_level_list(GameManager.get_identified_game_name()).size() == 0
    
    main_content_container.visible = true
    if current_mode == Modes.CUSTOM_LISTS:
        if all_custom_lists.size() == 0:
            main_content_container.hide()
    elif current_mode == Modes.BUNDLED_LISTS:
        if all_bundled_lists.size() == 0:
            main_content_container.hide()
    
    var completely_locked: = locked and current_mode != Modes.CUSTOM_LISTS
    if locked and current_mode == Modes.LEVELS:
        completely_locked = GameManager.is_level_bundled(current_level_name)

    for assignment_list in all_assignment_lists:
        assignment_list.clear_assignment_list()
        assignment_list.set_locked_mode(completely_locked)
    
    refresh_assignment_lists()
    
    if current_mode == Modes.LEVELS and current_level_name and current_level_name == GameManager.loaded_level_name:
        editing_cur_level_disclaimer.visible = true
    else:
        editing_cur_level_disclaimer.visible = false
    
    if current_mode == Modes.CUSTOM_LISTS:
        var cur_list_index: = all_custom_lists.find(current_level_list_name)
        if cur_list_index == -1:
            next_nav_button.disabled = false
            previous_nav_button.disabled = false
        else:
            next_nav_button.disabled = cur_list_index == all_custom_lists.size() - 1
            previous_nav_button.disabled = cur_list_index == 0
    elif current_mode == Modes.BUNDLED_LISTS:
        var cur_list_index: = all_bundled_lists.find(current_level_list_name)
        if cur_list_index == -1:
            next_nav_button.disabled = false
            previous_nav_button.disabled = false
        else:
            next_nav_button.disabled = cur_list_index == all_bundled_lists.size() - 1
            previous_nav_button.disabled = cur_list_index == 0
    elif current_mode == Modes.LEVELS:
        var all_levels_orderd: Array[String] = GameManager.get_all_existing_levels_sorted_by_chronology()
        var current_index: = all_levels_orderd.find(current_level_name)
        if current_index == -1:
            next_nav_button.disabled = false
            previous_nav_button.disabled = false
        else:
            next_nav_button.disabled = current_index == all_levels_orderd.size() - 1
            previous_nav_button.disabled = current_index == 0


func on_any_assignment_changed() -> void:
    update_and_save_current()

func on_navigate(direction: int) -> void:
    var current_mode: = get_current_mode()
    
    if current_mode == Modes.CUSTOM_LISTS or current_mode == Modes.BUNDLED_LISTS:
        var all_custom_lists: Array[String] = []
        if current_mode == Modes.CUSTOM_LISTS:
            all_custom_lists = GameManager.get_list_of_non_bundled_level_lists()
        else:
            all_custom_lists.assign(GameManager.get_list_of_level_lists(true))
        var current_index: = all_custom_lists.find(current_level_list_name)
        if current_index == -1:
            current_index = 0
        current_index = clampi(current_index + direction, 0, all_custom_lists.size() - 1)
        edit_assignments_for_level_list(all_custom_lists[current_index])
    elif current_mode == Modes.LEVELS:
        var all_levels: Array[String] = GameManager.get_all_existing_levels_sorted_by_chronology()
        var current_index: = all_levels.find(current_level_name)
        if current_index == -1:
            current_index = 0
        current_index = clampi(current_index + direction, 0, all_levels.size() - 1)
        edit_assignments_for_level(all_levels[current_index])
    

func get_current_mode() -> Modes:
    if game_mode_btn.button_pressed:
        return Modes.GAME
    if bundled_lists_btn.button_pressed:
        return Modes.BUNDLED_LISTS
    if custom_lists_btn.button_pressed:
        return Modes.CUSTOM_LISTS
    if levels_btn.button_pressed:
        return Modes.LEVELS
    return Modes.GAME

func set_current_mode(mode: Modes) -> void:
    game_mode_btn.set_pressed_no_signal(mode == Modes.GAME)
    bundled_lists_btn.set_pressed_no_signal(mode == Modes.BUNDLED_LISTS)
    custom_lists_btn.set_pressed_no_signal(mode == Modes.CUSTOM_LISTS)
    levels_btn.set_pressed_no_signal(mode == Modes.LEVELS)


func on_intermission_editor_button_pressed() -> void:
    if get_current_mode() == Modes.CUSTOM_LISTS and current_level_list_name:
        to_intermission_editor.emit("", current_level_list_name, false)
    else:
        to_intermission_editor.emit("", "", false)

func on_new_intermission_button_pressed() -> void:
    var current_mode: = get_current_mode()
    if current_mode == Modes.CUSTOM_LISTS and current_level_list_name:
        to_intermission_editor_new.emit(current_level_list_name)
    else:
        to_intermission_editor_new.emit("")


func on_request_edit_intermission(intermission_id: String, in_custom_list: String) -> void:
    to_intermission_editor.emit(intermission_id, in_custom_list, false)

func on_request_duplicate_intermission(intermission_id: String, in_custom_list: String, assignment_list: IntermissionAssignmentList) -> void:
    assignment_list_getting_duplicate = assignment_list
    to_intermission_editor.emit(intermission_id, in_custom_list, true)

func return_duplicate_intermission_id(intermission_id: String) -> void:
    if not assignment_list_getting_duplicate:
        return
    assignment_list_getting_duplicate.local_duplicate_created_with_id(intermission_id)
    assignment_list_getting_duplicate = null


func _set_or_erase_assignment_list(in_dict: Dictionary, key: String, assignment_list: Array) -> void:
    if not assignment_list:
        in_dict.erase(key)
    else:
        in_dict[key] = assignment_list

func refresh_assignment_lists() -> void:
    var current_mode: = get_current_mode()
    
    if current_mode == Modes.BUNDLED_LISTS or current_mode == Modes.CUSTOM_LISTS:
        if not current_level_list_name:
            return
        var list_info: Dictionary = GameManager._get_level_list(current_level_list_name)
        if not list_info:
            push_error("unable to get level list info for %s" % current_level_list_name)
            return
        var assignments_dict: = {}
        if typeof(list_info.get("intermission_assignments", {})) == TYPE_DICTIONARY:
            assignments_dict = list_info.get("intermission_assignments", {})
        before_start_assignment_list.load_assignments(assignments_dict.get("before_start", []))
        after_complete_assignment_list.load_assignments(assignments_dict.get("after_complete", []))
        after_last_level_assignment_list.load_assignments(assignments_dict.get("after_last_level", []))
        if custom_failure_assignment_list:
            custom_failure_assignment_list.load_assignments(assignments_dict.get("custom_fail", []))
    elif current_mode == Modes.LEVELS:
        if not current_level_name:
            return
        if GameManager.cur_scene == "Play" and GameManager.loaded_level_name == current_level_name:
            refresh_current_level_assignments()
            return

        if not FilesManager.level_exists(GameManager.get_identified_game_name(), current_level_name):
            return
        var cur_map_metadata: Dictionary = GameManager.get_map_metadata_from_level_file(current_level_name)
        var assignments_dict: Dictionary = {}
        if typeof(cur_map_metadata.get("intermission_assignments", {})) == TYPE_DICTIONARY:
            assignments_dict = cur_map_metadata.get("intermission_assignments", {})
        before_start_assignment_list.load_assignments(assignments_dict.get("before_start", []))
        after_complete_assignment_list.load_assignments(assignments_dict.get("after_complete", []))
        if custom_failure_assignment_list:
            custom_failure_assignment_list.load_assignments(assignments_dict.get("custom_fail", []))
    elif current_mode == Modes.GAME:
        var game_intermission_assignments: Variant = GameManager.get_game_setting("default_intermissions", {})
        if typeof(game_intermission_assignments) != TYPE_DICTIONARY:
            game_intermission_assignments = {}
        before_start_assignment_list.load_assignments(game_intermission_assignments.get("new_game", []))
        after_complete_assignment_list.load_assignments(game_intermission_assignments.get("game_complete", []))
        after_last_level_assignment_list.load_assignments(game_intermission_assignments.get("all_levels_complete", []))
        game_fail_assignment_list.load_assignments(game_intermission_assignments.get("fail_state", []))
        prints("game fail state assignments: %s" % [game_intermission_assignments.get("fail_state", [])])

func update_and_save_current() -> void:
    var current_mode: = get_current_mode()
    var locked: bool = GameManager.current_game_is_release_locked
    
    if current_mode == Modes.BUNDLED_LISTS or current_mode == Modes.CUSTOM_LISTS:
        if not current_level_list_name or (locked and GameManager.is_level_list_bundled(current_level_list_name)):
            return
        var list_info: Dictionary = GameManager._get_level_list(current_level_list_name)
        if not list_info:
            return
        if not list_info.has("intermission_assignments") or typeof(list_info["intermission_assignments"]) != TYPE_DICTIONARY:
            list_info["intermission_assignments"] = {}
        var assgn: Dictionary = list_info["intermission_assignments"]
        _set_or_erase_assignment_list(assgn, "before_start", before_start_assignment_list.get_assignments())
        _set_or_erase_assignment_list(assgn, "after_complete", after_complete_assignment_list.get_assignments())
        _set_or_erase_assignment_list(assgn, "after_last_level", after_last_level_assignment_list.get_assignments())
        if custom_failure_assignment_list:
            _set_or_erase_assignment_list(assgn, "custom_fail", custom_failure_assignment_list.get_assignments())
        GameManager.set_level_list_data(current_level_list_name, "intermission_assignments", assgn)
        if current_mode == Modes.BUNDLED_LISTS:
            GameManager.save_current_definition_if_auto_enabled()
    elif current_mode == Modes.GAME:
        var game_intermission_assignments: Dictionary = {}
        if typeof(GameManager.get_game_setting("default_intermissions", {})) == TYPE_DICTIONARY:
            game_intermission_assignments = GameManager.get_game_setting("default_intermissions", {})
        _set_or_erase_assignment_list(game_intermission_assignments, "new_game", before_start_assignment_list.get_assignments())
        _set_or_erase_assignment_list(game_intermission_assignments, "game_complete", after_complete_assignment_list.get_assignments())
        _set_or_erase_assignment_list(game_intermission_assignments, "all_levels_complete", after_last_level_assignment_list.get_assignments())
        _set_or_erase_assignment_list(game_intermission_assignments, "fail_state", game_fail_assignment_list.get_assignments())
        prints("saving game intermission assignments: %s" % game_intermission_assignments)
        GameManager.set_game_setting("default_intermissions", game_intermission_assignments)
        GameManager.save_current_definition_if_auto_enabled()
    elif current_mode == Modes.LEVELS:
        if not current_level_name:
            return
        if GameManager.cur_scene == "Play" and GameManager.loaded_level_name == current_level_name:
            update_and_save_edited_level()
        else:
            if not FilesManager.level_exists(GameManager.get_identified_game_name(), current_level_name):
                return
            if locked and GameManager.is_level_bundled(current_level_name):
                return
            var cur_map_metadata: Dictionary = GameManager.get_map_metadata_from_level_file(current_level_name)
            
            if not cur_map_metadata.has("intermission_assignments") or typeof(cur_map_metadata["intermission_assignments"]) != TYPE_DICTIONARY:
                cur_map_metadata["intermission_assignments"] = {}
            var assgn: Dictionary = cur_map_metadata["intermission_assignments"]
            _set_or_erase_assignment_list(assgn, "before_start", before_start_assignment_list.get_assignments())
            _set_or_erase_assignment_list(assgn, "after_complete", after_complete_assignment_list.get_assignments())
            if custom_failure_assignment_list:
                _set_or_erase_assignment_list(assgn, "custom_fail", custom_failure_assignment_list.get_assignments())
            
            GameManager.set_map_metadata_into_level_file(current_level_name, cur_map_metadata)

# In case we're editing assignments of the edited level, make sure to take all the current metadata into account
# and force save because that's better than potentially leaving it hanging probably
func update_and_save_edited_level() -> void:
    var map_editor: = Utility.get_map_editor()
    if not map_editor:
        return
    
    var cur_map_assignments: Variant = MapManager.get_metadata_value("intermission_assignments", {})
    if typeof(cur_map_assignments) != TYPE_DICTIONARY:
        cur_map_assignments = {}
    _set_or_erase_assignment_list(cur_map_assignments, "before_start", before_start_assignment_list.get_assignments())
    _set_or_erase_assignment_list(cur_map_assignments, "after_complete", after_complete_assignment_list.get_assignments())
    if custom_failure_assignment_list:
        _set_or_erase_assignment_list(cur_map_assignments, "custom_fail", custom_failure_assignment_list.get_assignments())
    MapManager.set_metadata_value("intermission_assignments", cur_map_assignments, true)
    
    if not map_editor.save_current_or_save_as(Callable(), true):
        push_error("Editing assignments of edited level but was unable to save")

func refresh_current_level_assignments() -> void:
    var cur_map_assignments: Variant = MapManager.get_metadata_value("intermission_assignments", {})
    if not typeof(cur_map_assignments) == TYPE_DICTIONARY:
        cur_map_assignments = {}
    
    before_start_assignment_list.load_assignments(cur_map_assignments.get("before_start", []))
    after_complete_assignment_list.load_assignments(cur_map_assignments.get("after_complete", []))
    if custom_failure_assignment_list:
        custom_failure_assignment_list.load_assignments(cur_map_assignments.get("custom_fail", []))


static func get_event_key(event_id: Events) -> String:
    if not event_id in Events.values():
        push_error("Invalid event id: %s" % event_id)
    if not event_id in EVENT_KEYS:
        push_error("No event key for event id: %s (%s)" % [event_id, EVENT_KEYS.find_key(event_id)])
    return EVENT_KEYS[event_id]