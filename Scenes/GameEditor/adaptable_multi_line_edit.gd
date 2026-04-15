extends LineEdit

## Emitted whenever the text changes regardless of if there are multiple lines, new_text contains the full text unlike the text_changed signal
## which only contains the first line of the text
signal multi_line_text_changed(new_text: String)
## Like the editing_toggled signal of LineEdit but more accurately reflects how the multi-line version works
signal multi_line_editing_toggled(is_editing: bool)
## Like the editing_toggled signal of LineEdit but also emited when pressing enter in the multi-line input, use shift-enter to add a newline instead.
## `swap_enter_and_shift_enter = true` inverts this so shift-enter triggers text submit
signal multi_line_text_submitted(new_text: String)

@export var swap_enter_and_shift_enter: bool = false

@export var multi_line_popup: Window
@export var multi_line_input: TextEdit

const SPECIAL_PASTE: int = 500

@export var multi_line_contents: String = ""

var _indirect_text_change: bool = false
var _popup_panel_stylebox_top_margin: int = 0
var _popup_panel_left_margin: int = 0

func _ready() -> void:
    if text and not multi_line_contents:
        multi_line_contents = text
    var context_menu: = get_menu()
    var paste_index: = context_menu.get_item_index(MENU_PASTE)
    context_menu.set_item_id(paste_index, SPECIAL_PASTE)
    context_menu.id_pressed.connect(on_context_menu_id_pressed)
    
    text_changed.connect(on_text_changed)
    editing_toggled.connect(on_editing_toggled)
    resized.connect(on_resized)
    text_submitted.connect(multi_line_text_submitted.emit)
    
    multi_line_input.text_changed.connect(on_multi_line_text_changed)
    multi_line_input.focus_exited.connect(on_multi_line_focus_exited)
    multi_line_input.gui_input.connect(on_multi_line_gui_input)
    
    update_popup_margin()

func set_popup_panel_stylebox(stylebox: StyleBox) -> void:
    multi_line_popup.add_theme_stylebox_override("panel", stylebox)
    update_popup_margin()

func update_popup_margin() -> void:
    var popup_panel_stylebox: = multi_line_popup.get_theme_stylebox("panel")
    _popup_panel_stylebox_top_margin = popup_panel_stylebox.content_margin_top
    _popup_panel_left_margin = popup_panel_stylebox.content_margin_left

func set_text_contents(new_text: String) -> void:
    if new_text.contains("\n"):
        do_change_text_multi_line(new_text)
    else:
        do_change_text_single_line(new_text)

func do_change_text_multi_line(new_text: String, paste_mode: bool = false) -> void:
    var set_cursor_to: int = new_text.length()
    if paste_mode:
        if text and not multi_line_popup.visible:
            var selection_range: = get_selection_range()
            new_text = text.substr(0, selection_range[0]) + new_text + text.substr(selection_range[1])
            set_cursor_to = selection_range[0] + new_text.length()
    multi_line_contents = new_text
    multi_line_input.text = new_text
    text = new_text.split("\n", true, 1)[0]
    if not multi_line_popup.visible and is_editing():
        _open_multi_line_mode(set_cursor_to)
    else:
        on_multi_line_text_changed(false)

func do_change_text_single_line(new_text: String, paste_mode: bool = false) -> void:
    if new_text.contains("\n"):
        push_error("Setting single line text but it contains a newline")
        return
    if text and paste_mode:
        var selection_range: = get_selection_range()
        text = text.substr(0, selection_range[0]) + new_text + text.substr(selection_range[1])
    else:
        text = new_text
    multi_line_contents = text

func get_selection_range() -> Array[int]:
    if not has_selection():
        return [caret_column, caret_column]
    return [get_selection_from_column(), get_selection_to_column() + 1]

func grab_focus_and_edit() -> void:
    if multi_line_popup.visible:
        return
    grab_focus()
    edit()

func on_editing_toggled(now_is_editing: bool) -> void:
    if now_is_editing:
        if multi_line_contents.contains("\n"):
            _open_multi_line_mode()
        else:
            multi_line_editing_toggled.emit(true)

# Emit text_changed and multi_line_text_changed signals without replacing the multi_line_contents with the single line
func emit_text_changed() -> void:
    _indirect_text_change = true
    text_changed.emit(text)
    multi_line_text_changed.emit(multi_line_contents)

# Handle native text_changed signal, skip updating multi_line_contents if I'm emitting myself
func on_text_changed(new_single_line_text: String) -> void:
    if not _indirect_text_change:
        multi_line_contents = new_single_line_text
        multi_line_text_changed.emit(multi_line_contents)
    _indirect_text_change = false

# Open the multi-line edit popup, set the cursor to the given position or the end of the text and grab focus (as if calling edit() but TextEdit doesn't work like that)
func _open_multi_line_mode(set_cursor_to: int = -1) -> void:
    if set_cursor_to < 0:
        set_cursor_to = multi_line_contents.length()
    _show_multi_line(set_cursor_to)

func _show_multi_line(set_cursor_to: int = -1) -> void:
    multi_line_input.custom_minimum_size = size
    multi_line_input.text = multi_line_contents
    multi_line_popup.child_controls_changed()
    #multi_line_popup.reset_size()
    var was_editing: = is_editing()
    multi_line_popup.popup()
    await get_tree().process_frame
    set_multi_line_minimum_height()
    adjust_popup_size_position()
    multi_line_input.grab_focus()
    if not was_editing:
        multi_line_editing_toggled.emit(true)

    if select_all_on_focus:
        multi_line_input.select_all()
    if set_cursor_to >= 0:
        var new_cursor_position: = Utility.get_line_and_column_of_char_index(multi_line_contents, set_cursor_to)
        multi_line_input.set_caret_line(new_cursor_position.y)
        multi_line_input.set_caret_column(new_cursor_position.x)

func _gui_input(event: InputEvent) -> void:
    if Utility.fixed_just_pressed_by_event("ui_paste", event, true):
        on_context_menu_id_pressed(SPECIAL_PASTE)
        accept_event()
    elif event is InputEventKey and Utility.fixed_just_pressed_by_event("ui_text_submit", event, false):
        if is_editing() and not multi_line_popup.visible:
            if event.shift_pressed == false if not swap_enter_and_shift_enter else true:
                pass # use default to trigger text_submitted and unedit
            else:
                prints("pretending to paste a newline")
                do_change_text_multi_line("\n", true)
                accept_event()

func on_context_menu_id_pressed(context_menu_id: int) -> void:
    if context_menu_id == SPECIAL_PASTE:
        if not DisplayServer.clipboard_has():
            return
        var clipboard_text: = DisplayServer.clipboard_get()
        while clipboard_text.ends_with("\n"):
            clipboard_text = clipboard_text.trim_suffix("\n")

        if not clipboard_text.contains("\n"):
            do_change_text_single_line(clipboard_text, true)
        else:
            do_change_text_multi_line(clipboard_text, true)
        emit_text_changed()

func on_resized() -> void:
    if multi_line_popup.visible:
        multi_line_input.custom_minimum_size = size
        multi_line_popup.child_controls_changed()
        adjust_popup_size_position()

func on_multi_line_text_changed(do_emit_text_changed: bool = true) -> void:
    set_multi_line_minimum_height()
    multi_line_contents = multi_line_input.text
    text = multi_line_contents.split("\n", true, 1)[0]
    adjust_popup_size_position()
    if do_emit_text_changed:
        emit_text_changed()

func set_multi_line_minimum_height() -> void:
    if not multi_line_popup.visible:
        return
    if multi_line_input.scroll_fit_content_height:
        var min_height: = multi_line_input.get_minimum_size().y
        if min_height > get_viewport().size.y * 0.8:
            multi_line_input.scroll_fit_content_height = false
            multi_line_input.custom_minimum_size.y = get_viewport().size.y * 0.8
    else:
        if multi_line_input.custom_minimum_size.y > multi_line_input.get_minimum_size().y:
            multi_line_input.scroll_fit_content_height = true
            multi_line_input.custom_minimum_size.y = size.y

func adjust_popup_size_position() -> void:
    if not is_visible_in_tree():
        return
    multi_line_popup.reset_size()
    var target_pos: = get_screen_position()
    multi_line_popup.position = target_pos - Vector2(_popup_panel_left_margin, _popup_panel_stylebox_top_margin)
    Utility.clamp_window_within_window(multi_line_popup, get_window())

func on_multi_line_focus_exited() -> void:
    multi_line_popup.hide()
    if is_editing():
        unedit()
    multi_line_editing_toggled.emit(false)

func on_multi_line_gui_input(event: InputEvent) -> void:
    var closing: bool = false
    if Utility.fixed_just_pressed_by_event("ui_cancel", event, true):
        closing = true
    elif Utility.fixed_just_pressed_by_event("escape", event, true):
        closing = true
    if closing:
        multi_line_input.accept_event()
        multi_line_input.release_focus()
        return
    
    # TODO somehow detect if touch or virtual keyboard is used, and dont trigger text submit
    if event is InputEventKey and Utility.fixed_just_pressed_by_event("ui_text_submit", event, false):
        if event.shift_pressed == false if not swap_enter_and_shift_enter else true:
            # releasing focus will close the popup and unedit the line edit if it was in edit mode
            multi_line_input.release_focus()
            multi_line_text_submitted.emit(multi_line_contents)
        else:
            multi_line_input.insert_text_at_caret("\n")
        multi_line_input.accept_event()