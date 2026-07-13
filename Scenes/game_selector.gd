extends MarginContainer

signal changed_game(game_name: String)

@export var focus_panel: Panel

@export var game_title_label: Label

@export var game_identifier_label: Label

@export var prev_tex_button: Control
@export var next_tex_button: Control

@export var list_menu_tex_button: Control
@export var game_list_menu: PopupMenu

@export var anim_speed: = 1.2
@export var flash_color: Color = Color(1.2, 1.2, 1.2, 1.0)
@export var flash_base_amt: = 0.9
@export var flash_delta: = 0.28

@export var edited_title_outline_color: Color = Color.ORANGE

var game_list: Array[String] = []
var game_titles: Dictionary[String, String] = {}
var non_unique_titles: Array[String] = []

var anim_time: = 0.0
var _min_width: = 0.0
var _width_extra: = 0.0

@export var _root_container: Container

func _ready() -> void:
    _min_width = size.x
    var main_menu_panel: Control = find_parent("MainMenu")
    _width_extra = 100 + (main_menu_panel.size.x - _min_width) + 2

    focus_mode = Control.FOCUS_ALL
    focus_panel.visible = false
    focus_entered.connect(on_focus_entered)
    focus_exited.connect(on_focus_exited)
    
    get_viewport().size_changed.connect(update_title_text)
    
    update_title_text()
    
    next_tex_button.gui_input.connect(on_tex_button_gui_input.bind(next_tex_button))
    prev_tex_button.gui_input.connect(on_tex_button_gui_input.bind(prev_tex_button))
    list_menu_tex_button.gui_input.connect(on_tex_button_gui_input.bind(list_menu_tex_button))
    
    game_list_menu.index_pressed.connect(on_game_list_menu_index_pressed)

func update_title_text() -> void:
    refresh_game_list()
    game_title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    game_title_label.size_flags_horizontal = Control.SIZE_FILL
    if not GameManager.get_identified_game_name():
        game_title_label.text = "..."
    else:
        game_title_label.text = get_display_title(GameManager.get_identified_game_name(), false)
        if not GameManager.current_game_is_release_locked:
            game_title_label.add_theme_constant_override("outline_size", 6)
            game_title_label.add_theme_color_override("font_outline_color", edited_title_outline_color)
        else:
            game_title_label.remove_theme_constant_override("outline_size")
            game_title_label.remove_theme_color_override("font_outline_color")
    
    await get_tree().process_frame
    var root_container_width: = _root_container.size.x
    var vp: Viewport = get_viewport()
    if root_container_width > vp.size.x:
        # title overrun detected
        game_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        game_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        custom_minimum_size.x = vp.size.x - _width_extra
    else:
        custom_minimum_size.x = 0
    
    game_identifier_label.text = GameManager.get_identified_game_name(true)

func get_name_with_identifier_or_question_mark(game_name: String) -> String:
    if not game_name.contains("/"):
        return "?/" + game_name
    return game_name

func get_unqualified_game_name(game_name: String) -> String:
    if game_name.contains("/"):
        return game_name.split("/", true, 1)[1].strip_edges()
    return game_name

func get_display_title(game_name: String, non_unique_with_id: bool) -> String:
    var title: String = game_titles.get(game_name, get_unqualified_game_name(game_name))
    if non_unique_with_id and title in non_unique_titles:
        return "%s (%s)" % [title, get_name_with_identifier_or_question_mark(game_name)]
    return title

func refresh_game_list() -> void:
    non_unique_titles = []
    game_list = []
    var game_data = FilesManager.get_game_list_with_titles()
    var existing_titles: Array[String] = []
    for g in game_data:
        game_list.append(g['game_name'])
        game_titles[g['game_name']] = g['game_title']
        if g['game_title'] not in existing_titles:
            existing_titles.append(g['game_title'])
        else:
            non_unique_titles.append(g['game_title'])

    game_list_menu.clear()
    for game_name in game_list:
        game_list_menu.add_item(get_display_title(game_name, true))

func change_game(dir: int) -> void:
    refresh_game_list()
    if game_list.size() < 2:
        return
    var game_index: = game_list.find(GameManager.get_identified_game_name())
    if game_index == -1:
        game_index = 0
    game_index = posmod(game_index + dir, game_list.size())
    
    var next_game_name: = game_list[game_index]
    if next_game_name and FilesManager.game_exists(next_game_name):
        GameManager.load_game_definition_from_file(next_game_name)
        updated_game()

func updated_game() -> void:
    update_title_text()
    changed_game.emit(GameManager.get_identified_game_name())

func _process(delta: float) -> void:
    if not has_focus():
        if anim_time > 0.0:
            anim_time = 0.0
            set_arrow_modulate(Color.WHITE)
        return
    
    if Input.is_action_just_pressed("ui_select"):
        if not game_list_menu.visible:
            show_game_list_menu()
    
    anim_time += delta
    var arrow_mod: = flash_color * (flash_base_amt + sin(anim_time * TAU * anim_speed) * flash_delta)
    arrow_mod.a = 1.0
    set_arrow_modulate(arrow_mod)

func set_arrow_modulate(color: Color) -> void:
    prev_tex_button.modulate = color
    next_tex_button.modulate = color

func _gui_input(event: InputEvent) -> void:
    if not has_focus():
        return
    if Input.is_action_just_pressed_by_event("move_left", event):
        change_game(-1)
        accept_event()
    elif Input.is_action_just_pressed_by_event("move_right", event):
        change_game(1)
        accept_event()

func on_focus_entered() -> void:
    focus_panel.visible = true

func on_focus_exited() -> void:
    focus_panel.visible = false

func show_game_list_menu() -> void:
    refresh_game_list()
    if game_list_menu.visible:
        hide_game_list_menu()
    game_list_menu.popup_centered()

func hide_game_list_menu() -> void:
    game_list_menu.hide()

func on_tex_button_gui_input(event: InputEvent, tex_btn: Control) -> void:
    if not event is InputEventMouseButton or event.is_pressed() or not event.button_index == MOUSE_BUTTON_LEFT:
        return
    if is_same(tex_btn, list_menu_tex_button):
        show_game_list_menu()
    else:
        var dir: int = 1 if is_same(tex_btn, next_tex_button) else -1
        change_game(dir)
    if not has_focus():
        grab_focus.call_deferred()
    accept_event()

func on_game_list_menu_index_pressed(index: int) -> void:
    var game_name: = game_list[index]
    if game_name and FilesManager.game_exists(game_name):
        GameManager.load_game_definition_from_file(game_name)
        updated_game()
    await get_tree().process_frame
    await get_tree().process_frame
    hide_game_list_menu()