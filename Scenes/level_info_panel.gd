extends Control

@export var game_name_label: Label
@export var level_title_label: Label
@export var level_subtitle_label: Label

@export var level_info_subpanel: Control

@export var pause_menu: Control

func _ready() -> void:
    visibility_changed.connect(on_visibility_changed)
    
    if pause_menu and pause_menu.has_signal("level_metadata_changed"):
        pause_menu.level_metadata_changed.connect(refresh_ui)
    GameManager.any_state_loaded.connect(refresh_ui)
    
    level_info_subpanel.visible = GameManager.get_game_setting("level_info_above_pause", true)

func on_visibility_changed() -> void:
    if visible:
        refresh_ui()

func force_show_level_info() -> void:
    level_info_subpanel.visible = true

func refresh_ui() -> void:
    game_name_label.text = GameManager.get_game_title()

    level_title_label.text = MapManager.get_level_title()
    var level_subtitle: = MapManager.get_level_subtitle()
    level_subtitle_label.text = level_subtitle
    level_subtitle_label.visible = level_subtitle != ""
    
    level_info_subpanel.visible = GameManager.get_game_setting("level_info_above_pause", true)