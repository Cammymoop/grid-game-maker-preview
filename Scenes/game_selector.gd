extends MarginContainer

signal changed_game(game_name: String)

@export var focus_panel: Panel

@export var game_title_label: Label

@export var prev_tex_button: TextureRect
@export var next_tex_button: TextureRect

@export var list_menu_tex_button: TextureRect
@export var game_list_menu: PopupMenu

@export var anim_speed: = 1.2
@export var flash_color: Color = Color(1.2, 1.2, 1.2, 1.0)
@export var flash_base_amt: = 0.9
@export var flash_delta: = 0.28

var game_list: Array[String] = []
var game_titles: Dictionary[String, String] = {}
var non_unique_titles: Array[String] = []

var anim_time: = 0.0

func _ready() -> void:
    focus_mode = Control.FOCUS_ALL
    focus_panel.visible = false
    focus_entered.connect(on_focus_entered)
    focus_exited.connect(on_focus_exited)
    
    if not GameManager.cur_game_name:
        pass

func get_display_title(game_name: String) -> String:
    var title: String = game_titles.get(game_name, game_name)
    if title in non_unique_titles:
        return "%s (%s)" % [title, game_name]
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
        game_list_menu.add_item(get_display_title(game_name))

func change_game(dir: int) -> void:
    refresh_game_list()
    if game_list.size() < 2:
        return
    var game_index: = game_list.find(GameManager.get_game_name())
    if game_index == -1:
        game_index = 0
    game_index = posmod(game_index + dir, game_list.size())
    
    var next_game_name: = game_list[game_index]
    if next_game_name and FilesManager.game_exists(next_game_name):
        GameManager.load_game_definition_from_file(next_game_name)
        updated_game()

func updated_game() -> void:
    pass

func _process(delta: float) -> void:
    if not has_focus():
        if anim_time > 0.0:
            anim_time = 0.0
            set_arrow_modulate(Color.WHITE)
        return
    
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