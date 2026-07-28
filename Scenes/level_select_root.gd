extends Control

const LevelSelectUI = preload("res://Scenes/level_select_ui.gd")
const NewListPanel = preload("res://Scenes/GameEditor/new_list_panel.gd")

const IntermissionEditor = preload("res://Scenes/Intermission/intermissions_editor.gd")

@export var level_select_ui: LevelSelectUI

@export var darkener: ColorRect
@export var background_editor_container: Control
@export var bg_style_editor: Control
@export var add_new_list_panel: NewListPanel

@export var no_web_container: Control
@export var open_levels_folder_button: Button

@export var level_select_all: Control
@export var intermissions_all: Control

@export var edit_intermissions_container: Control

@export var edit_intermission_assignements_container: Control

@export var edit_intermission_assignements: Control
@export var edit_intermissions: IntermissionEditor

@export var game_view_container: Control

func _ready() -> void:
    if no_web_container:
        no_web_container.visible = not OS.has_feature("web")
    if open_levels_folder_button:
        open_levels_folder_button.pressed.connect(on_open_levels_folder_button_pressed)
    
    edit_intermissions.to_assignment_editor.connect(show_edit_intermission_assignements)
    edit_intermissions.to_level_list_editor.connect(back_from_edit_intermissions)
    edit_intermission_assignements.to_intermission_editor.connect(on_assignment_editor_to_intermission_editor)
    edit_intermission_assignements.to_intermission_editor_new.connect(on_assignments_edit_new_intermission)
    edit_intermission_assignements.request_back.connect(back_from_edit_intermissions)

    add_new_list_panel.hide()
    add_new_list_panel.add_list_requested.connect(adding_new_list)
    GameManager.level_state_loaded.connect(on_level_state_loaded)
    hide()
    level_select_ui.level_select_root = self
    level_select_ui.close_level_select.connect(on_level_select_ui_close_level_select)
    level_select_ui.to_intermission_assignments.connect(show_edit_intermission_assignements)
    
    level_select_all.hide()
    intermissions_all.hide()

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if intermissions_all.visible:
        if Utility.event_is_menu_back_just_pressed(event):
            accept_event()
            back_from_edit_intermissions()


func on_level_state_loaded() -> void:
    if visible:
        close_level_select()

func on_level_select_ui_close_level_select() -> void:
    close_level_select()

func open_level_select() -> void:
    show()
    darkener.show()
    GameManager.set_pause("level_select", true)
    level_select_all.show()
    level_select_ui.opening()

func close_level_select() -> void:
    GameManager.set_pause("level_select", false)
    if GameManager.is_in_level_edit_mode and level_select_ui.any_edited:
        GameManager.save_current_definition_if_auto_enabled()
        level_select_ui.any_edited = false
        #GlobalToaster.show_toast_message("Saved Def")
    if background_editor_container.visible:
        hide_background_editor()
    game_view_container.show()
    level_select_all.hide()
    _hide_intermission_editor_stuff()

    hide()

func _hide_intermission_editor_stuff() -> void:
    if intermissions_all.visible:
        edit_intermissions.remove_intermission_preview()
        hide_background_editor()
        intermissions_all.hide()

func close_intermission_editor() -> void:
    close_level_select()

func back_from_edit_intermissions() -> void:
    if not visible:
        return
    game_view_container.show()
    level_select_all.show()
    _hide_intermission_editor_stuff()


func show_edit_intermission_assignements() -> void:
    if not visible:
        open_level_select()
    game_view_container.show()
    level_select_all.hide()
    intermissions_all.show()
    edit_intermissions_container.hide()
    edit_intermissions.hide()
    edit_intermission_assignements_container.show()
    edit_intermission_assignements.show()
    edit_intermission_assignements.refresh_ui()
    darkener.show()

func show_edit_intermissions() -> void:
    _show_edit_intermissions()
    edit_intermissions.refresh_ui()

func _show_edit_intermissions() -> void:
    if not visible:
        open_level_select()
    game_view_container.hide()
    level_select_all.hide()
    intermissions_all.show()
    edit_intermissions_container.show()
    edit_intermissions.show()
    edit_intermission_assignements_container.hide()
    edit_intermission_assignements.hide()
    darkener.hide()

func on_assignment_editor_to_intermission_editor(intermission_id: String, in_custom_list: String, is_duplicate: bool) -> void:
    if not intermission_id:
        if in_custom_list:
            open_intermission_editor_for_custom_list(in_custom_list)
        else:
            _show_edit_intermissions()
            edit_intermissions.refresh_ui()
        return
    
    if GameManager.current_game_is_release_locked and not in_custom_list and not is_duplicate:
        return
    
    if is_duplicate:
        if not in_custom_list:
            var custom_list_names: = GameManager.get_list_of_non_bundled_level_lists()
            if custom_list_names.size() > 0:
                in_custom_list = custom_list_names[0]
            if not in_custom_list:
                edit_intermission_assignements.return_duplicate_intermission_id("")
                return
        var new_intermission_id: = open_duplicate_intermisson_in_editor(intermission_id, in_custom_list)
        edit_intermission_assignements.return_duplicate_intermission_id(new_intermission_id)
    else:
        open_intermission_editor_for_intermission(intermission_id, in_custom_list)

func on_assignments_edit_new_intermission(in_custom_list: String) -> void:
    var is_bundled: = not in_custom_list
    _show_edit_intermissions()
    if GameManager.current_game_is_release_locked and is_bundled:
        edit_intermissions.load_nothing()
        return
    edit_intermissions.edit_new_intermission(is_bundled, in_custom_list)




func show_background_editor() -> void:
    darkener.hide()
    background_editor_container.show()
    GameManager.bg_style_changed.emit()
    bg_style_editor.load_bg_style.call_deferred()

func hide_background_editor() -> void:
    darkener.show()
    background_editor_container.hide()
    GameManager.bg_style_changed.emit()

func show_add_new_list_panel() -> void:
    add_new_list_panel.open_panel()

func adding_new_list(list_name: String) -> void:
    var is_bundled: = not level_select_ui.custom_levels_tab_button.button_pressed
    if is_bundled and GameManager.current_game_is_release_locked:
        is_bundled = false
    GameManager.add_empty_level_list(list_name, is_bundled)
    level_select_ui.any_edited = true
    level_select_ui.refresh()

func on_open_levels_folder_button_pressed() -> void:
    if not FilesManager.game_exists(GameManager.get_identified_game_name()):
        GlobalToaster.show_toast_message("Game not saved, folder doesn't exist")
        return
    var levels_folder: = FilesManager.get_game_levels_dir(GameManager.get_identified_game_name())
    OS.shell_open(ProjectSettings.globalize_path(levels_folder))


func open_intermission_editor_for_custom_list(custom_list_name: String) -> void:
    var all_intermission_ids: = GameManager.get_all_intermission_ids_from_custom_list(custom_list_name)
    _show_edit_intermissions()
    if all_intermission_ids.size() > 0:
        edit_intermissions.load_intermission_from_id(all_intermission_ids[0], custom_list_name)
    else:
        edit_intermissions.load_nothing()

func open_intermission_editor_for_intermission(intermission_id: String, in_custom_list: String = "") -> void:
    if not intermission_id:
        return
    if GameManager.current_game_is_release_locked and not in_custom_list:
        return
    _show_edit_intermissions()
    edit_intermissions.load_intermission_from_id(intermission_id, in_custom_list)


func open_duplicate_intermisson_in_editor(from_bundled_intermission_id: String, to_custom_list: String) -> String:
    var new_intermission_id: = GameManager.duplicate_bundled_intermission_into_custom_list(to_custom_list, from_bundled_intermission_id)
    if new_intermission_id:
        open_intermission_editor_for_intermission(new_intermission_id, to_custom_list)
    else:
        GlobalToaster.show_toast_message("Something not work :<")
    return new_intermission_id