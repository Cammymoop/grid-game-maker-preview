extends PanelContainer

signal add_list_requested(list_name: String)

@export var close_button: Button
@export var add_button: Button
@export var name_input: LineEdit

func _ready() -> void:
    set_process_input(false)
    close_button.pressed.connect(close_panel)
    add_button.pressed.connect(add_list)

func _input(event: InputEvent) -> void:
    if not visible:
        return
    if Utility.event_is_menu_back_just_pressed(event):
        close_panel()
        accept_event()

func open_panel() -> void:
    name_input.text = ""
    name_input.grab_focus.call_deferred()
    set_process_input(true)
    show()

func close_panel() -> void:
    set_process_input(false)
    hide()

func add_list() -> void:
    var list_name: = name_input.text.strip_edges()
    if list_name:
        add_list_requested.emit(name_input.text)
    close_panel()