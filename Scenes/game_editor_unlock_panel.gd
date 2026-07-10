extends PanelContainer

@export var set_profile_identifier_ui: Control

@export var edit_in_place_button: ButtonContainer
@export var edit_my_identifier_button: ButtonContainer

@export var current_version_label: Label
@export var edit_in_place_version_label: Label
@export var edit_with_my_identifier_version_label: Label

@export var edit_identifier_button: Button

var next_version_number: String = ""

func _ready() -> void:
    edit_identifier_button.pressed.connect(on_edit_identifier_button_pressed)
    
    GameManager.profile_switched.connect(refresh_current_identifier)
    
    current_version_label.text = GameManager.get_full_version_string()
    
    var release_info: Dictionary = GameManager.get_release_info()
    var base_version: Vector2i = Utility.get_vector2i_from_arr(release_info["base_version"])
    next_version_number = _version_number_to_string(GameManager.increment_game_version(base_version))
    
    edit_in_place_version_label.text = GameManager.get_identified_game_name(true) + " " + _version_number_to_string(base_version)
    refresh_current_identifier()
    
    set_profile_identifier_ui.hidden.connect(switch_to_unlock_panel)
    
    edit_in_place_button.pressed.connect(do_unlock.bind(false))
    edit_my_identifier_button.pressed.connect(do_unlock.bind(true))

func do_unlock(use_my_identifier: bool) -> void:
    if use_my_identifier:
        GameManager.unrelease_as_copy_with_identifier(GameManager.get_profile_identifier())
    else:
        GameManager.unrelease_lock()

func _version_number_to_string(version: Vector2i) -> String:
    return str(version.x) + "." + str(version.y)

func refresh_current_identifier() -> void:
    var my_identifier: String = GameManager.get_profile_identifier()
    
    if not my_identifier:
        edit_my_identifier_button.disabled = true
        edit_my_identifier_button.set_button_tooltip("Please set an identifier for this profile using the button to the right.")
    else:
        edit_my_identifier_button.disabled = false
        edit_my_identifier_button.set_button_tooltip("")

    var my_version_string: = GameManager.display_format_game_name_and_identifier(my_identifier, GameManager.get_game_name())
    my_version_string += " " + next_version_number
    
    if my_identifier and my_identifier == GameManager.get_game_identifier():
        edit_my_identifier_button.disabled = true
    
    edit_with_my_identifier_version_label.text = my_version_string


func on_edit_identifier_button_pressed() -> void:
    switch_to_set_identifier()


func switch_to_set_identifier() -> void:
    hide()
    set_profile_identifier_ui.show()

func switch_to_unlock_panel() -> void:
    refresh_current_identifier()
    show()
    set_profile_identifier_ui.hide()