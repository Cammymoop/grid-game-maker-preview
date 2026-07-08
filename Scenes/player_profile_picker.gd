extends PanelContainer

@export var profile_label: Label
@export var edit_name_tex_button: TextureRect
@export var switch_profile_menu_button: MenuButton
@export var profile_name_input: LineEdit

@export var show_profile_name_container: Control
@export var edit_profile_name_container: Control

func _ready() -> void:
    switch_profile_menu_button.about_to_popup.connect(load_profile_list)
    switch_profile_menu_button.get_popup().index_pressed.connect(switch_profile)
    
    profile_name_input.text_changed.connect(on_profile_name_input_text_changed)
    profile_name_input.text_submitted.connect(on_profile_name_input_text_submitted)
    profile_name_input.focus_exited.connect(refresh)
    profile_name_input.editing_toggled.connect(on_profile_name_input_editing_toggled)
    
    edit_name_tex_button.gui_input.connect(tex_button_gui_input)
    refresh()

func tex_button_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        open_edit_profile_name()

func open_edit_profile_name() -> void:
    var profile_name: String = GameManager.get_profile_name()
    edit_profile_name_container.show()
    show_profile_name_container.hide()
    profile_name_input.text = profile_name
    profile_name_input.select_all_on_focus = true
    profile_name_input.grab_focus.call_deferred()

func refresh() -> void:
    var profile_name: String = GameManager.get_profile_name()
    profile_label.text = profile_name
    show_profile_name_container.show()
    edit_profile_name_container.hide()

func load_profile_list() -> void:
    var menu: PopupMenu = switch_profile_menu_button.get_popup()
    
    menu.clear()
    menu.add_item("Create New Profile")
    menu.add_separator()
    var profile_names: Dictionary = GameManager.get_profile_names()
    for profile_id in profile_names:
        menu.add_item(profile_names[profile_id])
        var idx: = menu.item_count - 1
        menu.set_item_metadata(idx, profile_id)

func switch_profile(menu_idx: int) -> void:
    if menu_idx == 0:
        switch_to_new_profile()
        return
    var menu: PopupMenu = switch_profile_menu_button.get_popup()
    var profile_id: String = menu.get_item_metadata(menu_idx)
    GameManager.load_player_profile(profile_id)
    refresh()

func switch_to_new_profile() -> void:
    GameManager.switch_to_new_player_profile()
    refresh()

func on_profile_name_input_text_changed(text: String) -> void:
    if not text:
        profile_name_input.placeholder_text = GameManager.get_profile_name()
        return
    else:
        profile_name_input.placeholder_text = ""
    GameManager.set_profile_name(text)

func on_profile_name_input_text_submitted(text: String) -> void:
    if text:
        GameManager.set_profile_name(text)
    refresh()

func on_profile_name_input_editing_toggled(toggled_on: bool) -> void:
    if not toggled_on:
        refresh()