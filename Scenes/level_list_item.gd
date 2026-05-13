extends Control

const LevelListItem = preload("res://Scenes/level_list_item.gd")

signal request_context_menu(level_item: LevelListItem)
signal request_move_relative(level_item: LevelListItem, relative_index: int)
signal play_level(level_name: String)
signal request_edit_level(level_name: String)

@export var locked_color: Color
@export var completed_color: Color
@export var current_level_font: Font
@export var current_level_font_size: int = 22
@export var completed_font: Font
@export var unplayed_color: Color

@export var title_label: Label
@export var start_level_button: ButtonContainer
@export var edit_level_button: Button

@export var move_up_down_buttons: Control
@export var move_up_button: ButtonContainer
@export var move_down_button: ButtonContainer

@export var dot_icon: TextureRect
@export var check_icon: TextureRect
@export var locked_icon: TextureRect

@export var current_level_indicator: Control
@export var current_level_icon: TextureRect

@export var highlight_rect: ColorRect

var level_name: String = ""

var _not_in_a_list: bool = false

var is_unlocked: bool = true
var is_completed: bool = false
var is_played: bool = false

var _is_current_level: bool = false

func _ready() -> void:
    highlight_rect.hide()
    current_level_icon.hide()
    current_level_indicator.visible = true
    update_current_level_indicator()
    refresh_icons_and_text()
    start_level_button.pressed.connect(on_start_level_button_pressed)
    edit_level_button.pressed.connect(on_edit_level_button_pressed)
    move_up_button.pressed.connect(on_relative_move_pressed.bind(-1))
    move_down_button.pressed.connect(on_relative_move_pressed.bind(1))
    refresh_move_buttons()

func not_in_a_list() -> void:
    _not_in_a_list = true
    move_up_down_buttons.visible = false

func on_relative_move_pressed(relative_index: int) -> void:
    request_move_relative.emit(self, relative_index)
    refresh_move_buttons()

func refresh_move_buttons() -> void:
    if not move_up_down_buttons.visible or not is_inside_tree():
        return
    var idx: = get_index()
    move_up_button.disabled = idx == 0
    move_down_button.disabled = idx == get_parent().get_child_count() - 1

func set_edit_mode(is_edit: bool) -> void:
    #current_level_indicator.visible = not is_edit
    start_level_button.visible = not is_edit
    edit_level_button.visible = is_edit
    move_up_down_buttons.visible = is_edit
    refresh_move_buttons()
    update_current_level_indicator()

func set_level_name_and_title(new_name: String, new_title: String) -> void:
    level_name = new_name
    title_label.text = new_title

func update_current_level_indicator() -> void:
    if not current_level_indicator.visible:
        highlight_rect.hide()
        return
    if GameManager.cur_scene == "Play" and GameManager.loaded_level_name:
        if GameManager.loaded_level_name == level_name:
            _is_current_level = true
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

func set_is_unlocked(new_is_unlocked: bool) -> void:
    is_unlocked = new_is_unlocked
    start_level_button.disabled = not is_unlocked
    refresh_icons_and_text()

func on_start_level_button_pressed() -> void:
    if not level_name:
        return
    play_level.emit(level_name)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.is_pressed():
        request_context_menu.emit(self)

func on_edit_level_button_pressed() -> void:
    if not level_name:
        return
    request_edit_level.emit(level_name)