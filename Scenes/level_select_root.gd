extends Control

const NewListPanel = preload("res://Scenes/GameEditor/new_list_panel.gd")

@export var level_select_ui: VBoxContainer

@export var darkener: ColorRect
@export var background_editor_container: Control
@export var bg_style_editor: Control
@export var add_new_list_panel: NewListPanel

func _ready() -> void:
    add_new_list_panel.hide()
    add_new_list_panel.add_list_requested.connect(adding_new_list)
    GameManager.level_state_loaded.connect(on_level_state_loaded)
    hide()
    level_select_ui.level_select_root = self
    level_select_ui.close_level_select.connect(on_level_select_ui_close_level_select)

func on_level_state_loaded() -> void:
    if visible:
        close_level_select()

func on_level_select_ui_close_level_select() -> void:
    close_level_select()

func open_level_select() -> void:
    GameManager.set_pause("level_select", true)
    level_select_ui.refresh()
    show()

func close_level_select() -> void:
    GameManager.set_pause("level_select", false)
    if GameManager.is_in_level_edit_mode and level_select_ui.any_edited:
        GameManager.save_current_game_definition()
        level_select_ui.any_edited = false
        GlobalToaster.show_toast_message("Saved Changes")
    if background_editor_container.visible:
        hide_background_editor()
    hide()

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
    GameManager.add_level_list(list_name)
    level_select_ui.any_edited = true
    if level_select_ui.editing_level_list:
        return
    if level_select_ui.is_rearranging_lists:
        level_select_ui.refresh_rearrangable_lists()
    else:
        level_select_ui.refresh_level_list()