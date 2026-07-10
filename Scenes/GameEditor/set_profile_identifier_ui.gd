extends VBoxContainer

@export var ok_button: Button

@export var profile_identifier_input: LineEdit

func _ready() -> void:
    ok_button.pressed.connect(hide)
    
    profile_identifier_input.text_changed.connect(on_identifier_text_changed)
    profile_identifier_input.text_submitted.connect(hide)

func on_identifier_text_changed(text: String) -> void:
    var sanitized_identifier: String = GameManager.sanitize_identifier(text)
    GameManager.set_profile_identifier(sanitized_identifier)
    if sanitized_identifier != profile_identifier_input.text:
        profile_identifier_input.text = sanitized_identifier
        profile_identifier_input.caret_column = sanitized_identifier.length()

func _shortcut_input(event: InputEvent) -> void:
    if Utility.event_is_menu_back_just_pressed(event):
        hide()