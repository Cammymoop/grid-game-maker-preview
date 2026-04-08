@tool
extends Control

signal facing_pressed(facing: int)

@export var use_relative_icons: = false:
    set(value):
        use_relative_icons = value
        update_icons()

func _ready() -> void:
    update_icons()

func disable_all() -> void:
    _set_disabled(true)

func enable_all() -> void:
    _set_disabled(false)

func _set_disabled(disabled: bool) -> void:
    for button_name in ["PickUp", "PickLeft", "PickRight", "PickDown"]:
        var the_button: = find_child(button_name)
        if the_button:
            the_button.disabled = disabled


func btn_pressed(the_button: ButtonContainer) -> void:
    var direction_name: = the_button.name.to_lower().trim_prefix("pick")
    facing_pressed.emit(Utility.direction_to_facing(direction_name))

func update_icons() -> void:
    var icon_set: = StaticResources.RelativeDirIcon if use_relative_icons else StaticResources.DirectionIcon
    for button_name in ["PickUp", "PickLeft", "PickRight", "PickDown"]:
        var the_button: = find_child(button_name)
        if not the_button:
            push_error("Button not found: %s" % button_name)
            return
        var facing: = Utility.direction_to_facing(button_name.to_lower().trim_prefix("pick"))
        _set_btn_icon(the_button, icon_set[facing])

func _set_btn_icon(the_button: ButtonContainer, the_icon: Texture2D) -> void:
    the_button.find_child("Icon").texture = the_icon