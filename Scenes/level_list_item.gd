extends Control

const LevelListItem = preload("res://Scenes/level_list_item.gd")

signal request_context_menu(level_item: LevelListItem)
signal request_move_relative(level_item: LevelListItem, relative_index: int)
signal play_level(level_name: String)
signal request_edit_level(level_name: String, as_autosave: bool)

signal focus_up_down_attempted(level_item: LevelListItem, direction: int)

signal focus_gotten(level_item: LevelListItem)

@export var locked_color: Color
@export var completed_color: Color
@export var current_level_font: Font
@export var current_level_font_size: int = 22
@export var completed_font: Font
@export var unplayed_color: Color

@export var focus_panel: Panel

@export var title_label: Label
@export var start_level_button: ButtonContainer
@export var edit_level_button: Button
@export var edit_as_autosave_button: Button

@export var move_up_down_buttons: Control
@export var move_up_button: ButtonContainer
@export var move_down_button: ButtonContainer

@export var dot_icon: TextureRect
@export var check_icon: TextureRect
@export var locked_icon: TextureRect

@export var current_level_indicator: Control
@export var current_level_icon: TextureRect

@export var highlight_rect: ColorRect

var is_editing_locked: bool = false

var level_name: String = ""
var level_title: String = ""

var level_list_name: String = ""
var is_in_bundled_list: bool = false

var _not_in_a_list: bool = false

var is_unlocked: bool = true
var is_completed: bool = false
var is_played: bool = false

var _is_current_level: bool = false
var _is_edit_mode: bool = false

func _ready() -> void:
    focus_panel.hide()
    highlight_rect.hide()
    current_level_indicator.hide()

    start_level_button.pressed.connect(on_start_level_button_pressed)
    edit_level_button.pressed.connect(on_edit_level_button_pressed)
    edit_as_autosave_button.pressed.connect(on_edit_as_autosave_button_pressed)
    move_up_button.pressed.connect(on_relative_move_pressed.bind(-1))
    move_down_button.pressed.connect(on_relative_move_pressed.bind(1))
    
    start_level_button.button.gui_input.connect(on_sub_item_gui_input.bind(start_level_button.button))
    edit_level_button.gui_input.connect(on_sub_item_gui_input.bind(edit_level_button))
    
    get_viewport().gui_focus_changed.connect(on_gui_focus_changed)

    edit_as_autosave_button.visible = false

func set_all_info(level_info: Dictionary, is_list_of_unlisted_levels: bool, for_list_name: String, edit_lock: bool, is_bundled: bool) -> void:
    _not_in_a_list = is_list_of_unlisted_levels
    level_list_name = for_list_name
    is_editing_locked = edit_lock
    is_in_bundled_list = is_bundled
    
    level_name = level_info["level_name"]
    level_title = level_info["display_title"]

    _is_edit_mode = GameManager.is_in_level_edit_mode
    
    is_completed = level_info["is_completed"]
    is_played = level_info["is_played"]
    is_unlocked = level_info["is_unlocked"]
    
    do_is_current_level_check()

    refresh_ui()

func refresh_ui() -> void:
    move_up_down_buttons.visible = not _not_in_a_list and _is_edit_mode

    start_level_button.visible = not _is_edit_mode
    edit_level_button.visible = _is_edit_mode
    if not _not_in_a_list:
        move_up_down_buttons.visible = _is_edit_mode

    if _is_edit_mode and level_name.to_lower() != level_title.to_lower():
        title_label.text = "%s (%s)" % [level_title, level_name]
    else:
        title_label.text = level_title

    start_level_button.disabled = not is_unlocked
    start_level_button.tooltip_text = "Play level" if is_unlocked else "Locked"

    current_level_indicator.visible = _is_current_level
    highlight_rect.visible = _is_current_level

    refresh_icons_and_text()
    refresh_edit_as_autosave_button()

func is_current_level() -> bool:
    return _is_current_level

func on_relative_move_pressed(relative_index: int) -> void:
    request_move_relative.emit(self, relative_index)

func refresh_move_buttons() -> void:
    if _not_in_a_list:
        return
    var idx: = get_index()
    move_up_button.disabled = idx == 0
    move_down_button.disabled = idx == get_parent().get_child_count() - 1
    
func refresh_edit_as_autosave_button() -> void:
    edit_as_autosave_button.visible = false
    if _is_edit_mode:
        var autosave_level: = FilesManager.get_editor_autosave_level_name(GameManager.get_identified_game_name())
        if autosave_level != level_name:
            edit_as_autosave_button.visible = false
        else:
            edit_as_autosave_button.visible = true
            var is_autosave_newer: = FilesManager.get_editor_autosave_is_newer(GameManager.get_identified_game_name())
            edit_as_autosave_button.text = "Autosave " + ("(newer)" if is_autosave_newer else "(older)")

func do_is_current_level_check() -> void:
    var check_list: = ""
    if not _not_in_a_list:
        check_list = level_list_name
    _is_current_level = GameManager.is_level_select_current_level(check_list, level_name)

func refresh_icons_and_text() -> void:
    title_label.remove_theme_color_override("font_color")
    title_label.remove_theme_font_override("font")
    title_label.remove_theme_font_size_override("font_size")
    dot_icon.visible = is_unlocked and is_played and not is_completed
    check_icon.visible = is_unlocked and is_completed
    locked_icon.visible = not is_unlocked
    
    if is_completed:
        title_label.add_theme_color_override("font_color", completed_color)
        title_label.add_theme_font_override("font", completed_font)
    elif not is_unlocked:
        title_label.add_theme_color_override("font_color", locked_color)
    elif is_played:
        title_label.add_theme_color_override("font_color", dot_icon.self_modulate)
    elif start_level_button.visible:
        title_label.add_theme_color_override("font_color", unplayed_color)

    if _is_current_level:
        title_label.add_theme_font_override("font", current_level_font)
        title_label.add_theme_font_size_override("font_size", current_level_font_size)
    
    if not _is_edit_mode and not is_unlocked:
        start_level_button.visible = false

func on_start_level_button_pressed() -> void:
    if not level_name:
        return
    play_level.emit(level_name)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.is_pressed():
        request_context_menu.emit(self)
        accept_event()

func on_edit_level_button_pressed() -> void:
    if not level_name:
        return
    request_edit_level.emit(level_name, false)

func on_edit_as_autosave_button_pressed() -> void:
    if not level_name:
        return
    request_edit_level.emit(level_name, true)

func focus_level_list_item() -> void:
    if start_level_button.is_visible_in_tree():
        start_level_button.button.grab_focus()
    elif edit_level_button.is_visible_in_tree():
        edit_level_button.grab_focus()

func on_gui_focus_changed(new_focus_owner: Control) -> void:
    if new_focus_owner == self or is_ancestor_of(new_focus_owner):
        focus_panel.show()
        focus_gotten.emit(self)
    else:
        focus_panel.hide()

func on_sub_item_gui_input(event: InputEvent, sub_item: Control) -> void:
    var is_move_up: = Utility.fixed_just_pressed_by_event("move_up", event)
    var is_move_down: = Utility.fixed_just_pressed_by_event("move_down", event)
    if not is_move_up and not is_move_down or not sub_item.has_focus():
        return
    focus_up_down_attempted.emit(self, 1 if is_move_down else -1)

func can_be_focused() -> bool:
    if start_level_button.is_visible_in_tree():
        return true
    elif edit_level_button.is_visible_in_tree():
        return true
    return false