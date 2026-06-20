extends TextEdit

func _handle_unicode_input(unicode_char: int, caret_index: int) -> void:
    if unicode_char == ord("a"):
        return

func _gui_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_text_caret_left"):
        accept_event()