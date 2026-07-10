extends PanelContainer

signal open_version_chooser()

@export var version_label: Label
@export var switch_version_button: Button

func _ready() -> void:
    switch_version_button.pressed.connect(on_switch_version_button_pressed)
    refresh_ui()

func refresh_ui() -> void:
    version_label.text = GameManager.get_full_version_string()

func on_switch_version_button_pressed() -> void:
    open_version_chooser.emit()
