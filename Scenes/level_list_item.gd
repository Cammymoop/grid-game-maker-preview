extends Control

const LevelListItem = preload("res://Scenes/level_list_item.gd")

signal request_context_menu(level_item: LevelListItem)
signal request_move_relative(level_item: LevelListItem, relative_index: int)
signal play_level(level_name: String)
signal request_edit_level(level_name: String, as_autosave: bool)

@export var locked_color: Color
@export var completed_color: Color
@export var current_level_font: Font
@export var current_level_font_size: int = 22
@export var completed_font: Font
@export var unplayed_color: Color

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
    highlight_rect.hide()
    current_level_icon.hide()
    current_level_indicator.visible = true
    refresh_current_level_indicator()
    refresh_icons_and_text()
    start_level_button.pressed.connect(on_start_level_button_pressed)
    edit_level_button.pressed.connect(on_edit_level_button_pressed)
    edit_as_autosave_button.pressed.connect(on_edit_as_autosave_button_pressed)
    move_up_button.pressed.connect(on_relative_move_pressed.bind(-1))
    move_down_button.pressed.connect(on_relative_move_pressed.bind(1))

    edit_as_autosave_button.visible = false
    refresh_move_buttons()

func is_current_level() -> bool:
    return _is_current_level

func not_in_a_list() -> void:
    _not_in_a_list = true
    move_up_down_buttons.visible = false

func on_relative_move_pressed(relative_index: int) -> void:
    request_move_relative.emit(self, relative_index)
    refresh_move_buttons()

func refresh_move_buttons() -> void:
    if _not_in_a_list or not is_inside_tree():
        return
    var idx: = get_index()
    move_up_button.disabled = idx == 0
    move_down_button.disabled = idx == get_parent().get_child_count() - 1

func set_edit_mode(is_edit: bool) -> void:
    _is_edit_mode = is_edit
    #current_level_indicator.visible = not is_edit
    start_level_button.visible = not is_edit
    edit_level_button.visible = is_edit
    if not _not_in_a_list:
        move_up_down_buttons.visible = is_edit
    refresh_move_buttons()
    refresh_current_level_indicator()
    set_level_name_and_title(level_name, level_title)
    refresh_edit_as_autosave_button()
    
func refresh_edit_as_autosave_button() -> void:
    if _is_edit_mode:
        var autosave_level: = FilesManager.get_editor_autosave_level_name(GameManager.get_identified_game_name())
        if autosave_level != level_name:
            edit_as_autosave_button.visible = false
        else:
            edit_as_autosave_button.visible = true
            var is_autosave_newer: = FilesManager.get_editor_autosave_is_newer(GameManager.get_identified_game_name())
            edit_as_autosave_button.text = "Autosave " + ("(newer)" if is_autosave_newer else "(older)")
    else:
        edit_as_autosave_button.visible = false

func set_level_name_and_title(new_name: String, new_title: String) -> void:
    level_name = new_name
    level_title = new_title
    if _is_edit_mode and level_name.to_lower() != level_title.to_lower():
        title_label.text = "%s (%s)" % [level_title, level_name]
    else:
        title_label.text = level_title

func setup_current_level_indicator() -> void:
    current_level_indicator.visible = true
    refresh_current_level_indicator()

func refresh_current_level_indicator() -> void:
    if not current_level_indicator.visible:
        highlight_rect.hide()
        return
    if GameManager.cur_scene == "Play" and GameManager.loaded_level_name:
        if GameManager.loaded_level_name == level_name:
            _is_current_level = false
            if not GameManager.current_level_list and _not_in_a_list:
                _is_current_level = true
            elif GameManager.current_level_list == level_list_name:
                _is_current_level = true
            if _is_current_level:
                current_level_icon.show()
                highlight_rect.show()
                refresh_icons_and_text()

func set_is_completed_is_played(new_is_completed: bool, new_is_played: bool) -> void:
    is_completed = new_is_completed
    is_played = new_is_played
    refresh_icons_and_text()

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

    refresh_edit_as_autosave_button()

func set_is_unlocked(new_is_unlocked: bool) -> void:
    is_unlocked = new_is_unlocked
    start_level_button.disabled = not is_unlocked
    start_level_button.tooltip_text = "Play level" if is_unlocked else "Locked"
    refresh_icons_and_text()

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