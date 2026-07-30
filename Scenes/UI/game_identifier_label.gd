extends Label

var is_on_main_menu: bool = false

func _ready() -> void:
    is_on_main_menu = GameManager.cur_scene == "Menu"

func _gui_input(event: InputEvent) -> void:
    if not is_on_main_menu:
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.is_pressed():
        open_context_menu()

func open_context_menu() -> void:
    var context_menu: = Utility.get_empty_context_menu()
    context_menu.add_item("Switch Versions")
    context_menu.index_pressed.connect(on_context_menu_index_pressed)
    add_child(context_menu)
    Utility.popup_context_menu_at_mouse(context_menu)

func on_context_menu_index_pressed(_index: int) -> void:
    if not is_on_main_menu:
        return
    var main_menu_root: = find_parent("MainMenu")
    if main_menu_root:
        main_menu_root.show_version_chooser_panel()

