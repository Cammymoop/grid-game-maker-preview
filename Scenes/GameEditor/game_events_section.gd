extends FoldableContainer

signal settings_updated

const ListAndLevelInput = preload("res://Scenes/GameEditor/list_and_level_input.gd")
const LevelListNameInput = preload("res://Scenes/GameEditor/ConditionalEditor/level_list_name_input.gd")

@export var game_end_has_transition_toggle: CheckButton

@export var game_end_transition_option: Control
@export var game_end_code_input: ListAndLevelInput

@export var game_completion_mode_selector: OptionButton

@export var specific_completion_level_option: Control
@export var specific_completion_level_code_input: ListAndLevelInput

@export var specific_completion_list_option: Control
@export var specific_completion_list_input: LevelListNameInput

@export var to_intermission_assignments_button: ButtonContainer

const SettingsKeys = {
    "game_end_transition": "game_end_replace_transition",
    "game_end_code": "game_end_transition_level_code",
    "game_completion_mode": "game_completion_mode",
    "specific_completion_key": "specific_completion_key",
}

const GameCompletionModes = {
    GameManager.COMPLETION__ALL_LISTS: "All Lists Completed",
    GameManager.COMPLETION__ALL_LEVELS: "All Levels Completed",
    GameManager.COMPLETION__SPECIFIC_LIST: "Specific List Completed",
    GameManager.COMPLETION__SPECIFIC_LEVEL_CODE: "Specific Level Completed",
}


func _ready() -> void:
    game_end_has_transition_toggle.toggled.connect(on_game_end_has_transition_toggled)
    game_end_code_input.value_changed.connect(on_game_end_code_input_value_changed)
    
    game_completion_mode_selector.item_selected.connect(on_game_completion_mode_selected)
    specific_completion_level_code_input.value_changed.connect(on_completion_code_value_changed)
    specific_completion_list_input.either_value_changed.connect(on_specific_list_value_changed)
    
    to_intermission_assignments_button.pressed.connect(on_to_intermission_assignments_button_pressed)
    
    setup_game_completion_mode_selector()
    
    refresh_ui()

func setup_game_completion_mode_selector() -> void:
    game_completion_mode_selector.clear()
    for id in GameCompletionModes.size():
        var mode_str: String = GameCompletionModes.keys()[id]
        var mode_description: String = GameCompletionModes[mode_str]
        game_completion_mode_selector.add_item(mode_description, id)
        var idx: int = game_completion_mode_selector.item_count - 1
        game_completion_mode_selector.set_item_metadata(idx, mode_str)
    game_completion_mode_selector.selected = 0

func refresh_ui() -> void:
    var has_game_end_transition: bool = GameManager.get_game_setting(SettingsKeys.game_end_transition, false)
    game_end_has_transition_toggle.set_pressed_no_signal(has_game_end_transition)
    
    game_end_transition_option.visible = has_game_end_transition
    
    if has_game_end_transition:
        var game_end_code: String = GameManager.get_game_setting(SettingsKeys.game_end_code, "")
        if game_end_code and GameManager.is_a_level_code(game_end_code):
            game_end_code_input.set_value(game_end_code)
        else:
            game_end_code_input.set_value("")
    
    var completion_mode_and_key: Array = GameManager.get_game_completion_mode_and_key()
    var completion_mode: String = completion_mode_and_key[0]
    var specific_key: String = completion_mode_and_key[1]
    
    var is_specific_level: bool = completion_mode == GameManager.COMPLETION__SPECIFIC_LEVEL_CODE
    var is_specific_list: bool = completion_mode == GameManager.COMPLETION__SPECIFIC_LIST
    
    specific_completion_level_option.visible = is_specific_level
    specific_completion_list_option.visible = is_specific_list
    
    if is_specific_level:
        specific_completion_level_code_input.set_value(specific_key)
    elif is_specific_list:
        var value_dict: Dictionary = { "type": "plain", "value": specific_key }
        specific_completion_list_input.set_value(value_dict)
    
    var mode_selector_id: int = GameCompletionModes.keys().find(completion_mode)
    Utility.opbtn_select_id(game_completion_mode_selector, mode_selector_id)


func on_game_end_has_transition_toggled(toggled_on: bool) -> void:
    GameManager.set_game_setting(SettingsKeys.game_end_transition, toggled_on)
    if toggled_on:
        save_game_end_code()
    refresh_ui()
    settings_updated.emit()

func on_game_end_code_input_value_changed() -> void:
    save_game_end_code()

func save_game_end_code() -> void:
    var game_end_code: String = game_end_code_input.get_value()
    if GameManager.is_level_code_valid(game_end_code):
        GameManager.set_game_setting(SettingsKeys.game_end_code, game_end_code)
    else:
        GameManager.set_game_setting(SettingsKeys.game_end_code, "")
    settings_updated.emit()

func on_game_completion_mode_selected(index: int) -> void:
    var mode_str: String = game_completion_mode_selector.get_item_metadata(index)
    GameManager.set_game_setting(SettingsKeys.game_completion_mode, mode_str)
    GameManager.set_game_setting(SettingsKeys.specific_completion_key, "")

    var completion_mode_and_key: Array = GameManager.get_game_completion_mode_and_key()
    GameManager.set_game_setting(SettingsKeys.specific_completion_key, completion_mode_and_key[1])
    refresh_ui()
    settings_updated.emit()

func on_completion_code_value_changed() -> void:
    var completion_code: String = specific_completion_level_code_input.get_value()
    if GameManager.is_level_code_valid(completion_code):
        GameManager.set_game_setting(SettingsKeys.specific_completion_key, completion_code)
    else:
        GameManager.set_game_setting(SettingsKeys.specific_completion_key, "")
    settings_updated.emit()

func on_specific_list_value_changed() -> void:
    var value_dict: Dictionary = specific_completion_list_input.get_value()
    var list_name: String = value_dict.get("value", "")
    if list_name and GameManager.is_level_list_bundled(list_name):
        GameManager.set_game_setting(SettingsKeys.specific_completion_key, list_name)
    else:
        GameManager.set_game_setting(SettingsKeys.specific_completion_key, "")
    settings_updated.emit()

func on_to_intermission_assignments_button_pressed() -> void:
    GameManager.is_in_level_edit_mode = true
    GameManager.change_scene("Play", false, "intermission-assignment-editor")