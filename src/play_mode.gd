extends Node2D

func _shortcut_input(event: InputEvent) -> void:
    if get_tree().paused:
        _paused_shortcut_input(event)
        return

func _paused_shortcut_input(event: InputEvent) -> void:
    pass