extends HBoxContainer

signal play_level(level_name: String)

@export var title_label: Label
@export var start_level_button: Button

var level_name: String = ""

func _ready() -> void:
    start_level_button.pressed.connect(on_start_level_button_pressed)

func set_is_unlocked(is_unlocked: bool) -> void:
    start_level_button.disabled = not is_unlocked

func set_level_name_and_title(new_name: String, new_title: String) -> void:
    level_name = new_name
    title_label.text = new_title

func on_start_level_button_pressed() -> void:
    if not level_name:
        return
    play_level.emit(level_name)