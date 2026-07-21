extends PanelContainer

signal to_assignment_editor
signal to_level_list_editor

const StyleEditor = preload("res://Scenes/GameEditor/bg_style_editor.gd")
const BgEffect = preload("res://Scenes/bg_effect_5.gd")

const IntermissionAssignmentList = preload("res://Scenes/Intermission/intermission_assignment_list.gd")

const IntermissionContentEditor = preload("res://Scenes/Intermission/intermission_content_editor.gd")

const IntermissionUI = preload("res://Scenes/Intermission/intermission_ui.gd")

var intermission_ui_scn: = preload("res://Scenes/Intermission/intermission_ui_no_fade_in.tscn")

var editor_dark_bg_stylebox: = preload("res://assets/ui/editor_dark_bg_panel.tres")

@export var intermission_id_input: LineEdit

@export var intermission_type_selector: OptionButton

@export var edit_new_intermission_button: Button
@export var duplicate_button: Button
@export var edit_intermission_menu_button: MenuButton

@export var other_game_editor_only: Array[Control]

@export var storage_location_selector: OptionButton
@export var custom_list_name_selector: OptionButton

@export var bg_style_edit_container: Control
@export var background_style_editor: StyleEditor
@export var background_style_preview: BgEffect

@export var intermission_content_editor: IntermissionContentEditor
@export var enable_custom_background_button: Button

@export var main_options_section: Control
@export var content_and_bg_section: PanelContainer
@export var content_section: Control

@export var sequence_list_section: Control
@export var intermission_sequence_list: IntermissionAssignmentList

@export var hide_overlay_button: Button

@export var back_button: Button
@export var to_assignments_editor_button: Button

@export var game_editor_bg_container: Control
@export var main_options_section_panel: PanelContainer

@export var game_editor_intermission_preview_root: Control
@export var other_intermission_preview_root: Control

@export var bg_shade_selector: OptionButton
@export var show_continue_toggle: CheckButton

@export var show_only_once_toggle: CheckButton

var is_editing_inside_level_list: String = ""

var is_editing_intermission: bool = false
var editing_intermission_info: Dictionary = {}

var last_valid_id: String = ""
var last_saved_id: String = ""

var current_id_is_valid: bool = false

var old_content_items: Array = []

var game_editor_mode: bool = true

const TYPE_CREDITS: String = "credits"
const TYPE_INTERMISSION: String = "intermission"
const TYPE_SEQUENCE: String = "sequence"
const INTERMISSION_TYPES: Array[String] = [TYPE_CREDITS, TYPE_INTERMISSION, TYPE_SEQUENCE]

const STORAGE_BUNDLED: int = 5
const STORAGE_CUSTOM_LIST: int = 6

func _ready() -> void:
    if GameManager.cur_scene == "Play":
        game_editor_mode = false
    
    
    visibility_changed.connect(on_visibility_changed)
    
    back_button.visible = not game_editor_mode
    back_button.pressed.connect(on_back_pressed)
    
    to_assignments_editor_button.pressed.connect(on_to_assignments_editor_pressed)

    intermission_type_selector.clear()
    for type_id in INTERMISSION_TYPES.size():
        intermission_type_selector.add_item(INTERMISSION_TYPES[type_id], type_id)
    intermission_type_selector.selected = 0
    intermission_type_selector.item_selected.connect(on_intermission_type_selected)
    
    storage_location_selector.clear()
    storage_location_selector.get_popup().add_item("Move to:")
    storage_location_selector.get_popup().set_item_disabled(0, true)
    storage_location_selector.add_item("Game", STORAGE_BUNDLED)
    storage_location_selector.add_item("Custom List", STORAGE_CUSTOM_LIST)
    
    storage_location_selector.item_selected.connect(on_storage_location_selected)
    custom_list_name_selector.item_selected.connect(on_custom_list_name_selected)
    
    bg_shade_selector.item_selected.connect(on_bg_shade_selected)
    show_continue_toggle.toggled.connect(on_show_continue_toggled)
    
    show_only_once_toggle.toggled.connect(on_show_only_once_toggled)
    
    if game_editor_mode:
        edit_new_intermission_button.pressed.connect(edit_new_intermission.bind(true))
    else:
        edit_new_intermission_button.pressed.connect(edit_new_intermission)
    duplicate_button.pressed.connect(duplicate_intermission)
    
    if not game_editor_mode:
        game_editor_bg_container.hide()
        content_and_bg_section.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
        main_options_section_panel.add_theme_stylebox_override("panel", editor_dark_bg_stylebox)
        
        for other_control in other_game_editor_only:
            other_control.hide()
    
    edit_intermission_menu_button.about_to_popup.connect(on_edit_intermission_menu_about_to_popup)
    var popup_menu: PopupMenu = edit_intermission_menu_button.get_popup()
    popup_menu.index_pressed.connect(on_edit_intermission_menu_selected)

    intermission_content_editor.items_updated.connect(on_intermission_content_updated)
    enable_custom_background_button.pressed.connect(on_enable_custom_background_pressed)
    
    background_style_editor.disable_custom_bg.connect(on_disable_custom_background)
    background_style_editor.edited_bg_style.connect(on_edited_bg_style)
    
    intermission_id_input.text_changed.connect(on_intermission_id_changed)
    
    hide_overlay_button.pressed.connect(on_hide_overlay_pressed)
    hide_overlay_button.mouse_entered.connect(make_overlay_ui_transparent)
    hide_overlay_button.mouse_exited.connect(make_overlay_ui_visible)
    hide_overlay_button.focus_exited.connect(make_overlay_ui_visible)
    
    intermission_sequence_list.list_edited.connect(on_intermission_sequence_list_edited)
    intermission_sequence_list.request_edit_intermission.connect(edit_intermission_from_sequence)
    intermission_sequence_list.request_edit_duplicate_intermission.connect(edit_duplicate_intermission_from_sequence)
    
    get_viewport().gui_focus_changed.connect(on_gui_focus_changed)
    
    if not GameManager.current_game_is_release_locked:
        load_last_edited_intermission()
        if not is_editing_intermission:
            refresh_ui()
            pass#
    else:
        refresh_ui()

func edit_new_intermission(force_bundled: bool = false, force_custom_list: String = "", try_intermission_id: String = "") -> String:
    if force_bundled:
        is_editing_inside_level_list = ""
    elif force_custom_list:
        is_editing_inside_level_list = force_custom_list

    if not try_intermission_id:
        try_intermission_id = Utility.random_animal() + " Text"
    var new_id: String = try_intermission_id

    if not new_id or GameManager.has_intermission_id(new_id, is_editing_inside_level_list):
        new_id = GameManager.get_available_numeric_intermission_id(is_editing_inside_level_list)
    var new_info: Dictionary = {
        "id": new_id,
        "type": TYPE_INTERMISSION,
        "content_items": [],
        "bg_style": {}
    }
    write_intermission_info(new_id, new_info, is_editing_inside_level_list)
    load_intermission_from_id(new_id)
    return new_id

func make_duplicate_into_list(from_intermission_id: String, to_list_name: String) -> String:
    if not GameManager.has_intermission_id(from_intermission_id):
        return ""
    
    var new_id: String = GameManager.append_numbered_intermission_id_suffix(from_intermission_id, "-copy")
    if GameManager.has_intermission_id(new_id, to_list_name):
        new_id = GameManager.get_available_numeric_intermission_id(to_list_name)
    var new_info: Dictionary = GameManager.get_intermission_info(from_intermission_id, to_list_name).duplicate_deep()
    new_info["id"] = new_id
    write_intermission_info(new_id, new_info, to_list_name)
    return new_id

func duplicate_intermission() -> void:
    if not is_editing_intermission:
        return
    var new_id: String = editing_intermission_info.get("id", "")
    new_id = GameManager.append_numbered_intermission_id_suffix(new_id, "-copy")
    if not new_id or GameManager.has_intermission_id(new_id, is_editing_inside_level_list):
        new_id = GameManager.get_available_numeric_intermission_id(is_editing_inside_level_list)
    var new_info: Dictionary = editing_intermission_info.duplicate_deep()
    new_info["id"] = new_id
    write_intermission_info(new_id, new_info, is_editing_inside_level_list)
    load_intermission_from_id(new_id)

func load_last_edited_intermission() -> void:
    var last_edited_id: String = GameManager.get_current_game_profile_setting_1("last_edited_intermission_id", "")
    if not last_edited_id:
        return
    load_intermission_from_id(last_edited_id)

func load_intermission_from_id(intermission_id: String, from_custom_list: String = "") -> void:
    is_editing_intermission = false
    is_editing_inside_level_list = ""
    if not intermission_id or not GameManager.has_intermission_id(intermission_id, from_custom_list):
        refresh_ui()
        return
    if not is_editing_inside_level_list and GameManager.current_game_is_release_locked:
        refresh_ui()
        return
    is_editing_intermission = true
    is_editing_inside_level_list = from_custom_list

    editing_intermission_info = GameManager.get_intermission_info(intermission_id, from_custom_list)
    if not editing_intermission_info:
        is_editing_intermission = false
        is_editing_inside_level_list = ""
        refresh_ui()
        return
    last_saved_id = editing_intermission_info["id"]
    set_current_id_is_valid(true)
    var type: String = editing_intermission_info.get("type", "")
    old_content_items = []
    if type == TYPE_INTERMISSION:
        old_content_items = editing_intermission_info.get("content_items", [])
    save_last_edited_intermission_id(intermission_id)
    refresh_ui()

func load_nothing() -> void:
    is_editing_intermission = false
    is_editing_inside_level_list = ""
    refresh_ui()

func on_intermission_content_updated() -> void:
    if not is_editing_intermission:
        return
    editing_intermission_info["content_items"] = intermission_content_editor.get_contents_info()
    save_edited_intermission_info()
    update_intermission_preview()

func on_enable_custom_background_pressed() -> void:
    background_style_editor.manual_copy_game_bg_style()
    var bg_style: Dictionary = background_style_editor.manual_info
    editing_intermission_info["bg_style"] = bg_style
    update_bg_preview(bg_style)
    refresh_show_bg_style_ui()

func refresh_show_bg_style_ui() -> void:
    if not is_editing_intermission:
        return

    var has_custom_bg: bool = editing_intermission_info.get("bg_style", {}).size() > 0
    if editing_intermission_info.get("type", "") == TYPE_SEQUENCE:
        enable_custom_background_button.get_parent().hide()
        bg_style_edit_container.hide()
        return

    if has_custom_bg:
        enable_custom_background_button.get_parent().hide()
        bg_style_edit_container.show()
    else:
        bg_style_edit_container.hide()
        enable_custom_background_button.get_parent().show()

func on_disable_custom_background() -> void:
    if not is_editing_intermission:
        return
    editing_intermission_info["bg_style"] = {}
    update_bg_preview(GameManager.get_game_bg_info())
    save_edited_intermission_info()
    refresh_show_bg_style_ui()

func on_edited_bg_style(bg_style: Dictionary) -> void:
    editing_intermission_info["bg_style"] = bg_style
    update_bg_preview(bg_style)
    save_edited_intermission_info()
    refresh_show_bg_style_ui()

func update_bg_preview(bg_style: Dictionary) -> void:
    if not is_visible_in_tree():
        return
    background_style_preview.no_auto_update = true
    background_style_preview.set_bg_style(bg_style)

# save using the last valid id if the current is invalid so data isn't lost unnecessarily
func save_edited_intermission_info() -> void:
    if not is_editing_intermission or not last_valid_id or not last_saved_id:
        return
    if not is_editing_inside_level_list and GameManager.current_game_is_release_locked:
        return

    var save_info: = editing_intermission_info.duplicate_deep()
    save_info["id"] = last_valid_id
    write_intermission_info(last_saved_id, save_info, is_editing_inside_level_list)
    last_saved_id = last_valid_id
    save_last_edited_intermission_id(last_valid_id)

func write_intermission_info(update_id: String, intermission_info: Dictionary, inside_level_list: String = "") -> void:
    GameManager.update_intermission_info(update_id, intermission_info, inside_level_list)
    if not game_editor_mode and not inside_level_list:
        GameManager.save_current_definition_if_auto_enabled()

func save_last_edited_intermission_id(intermission_id: String) -> void:
    if is_editing_inside_level_list:
        return
    GameManager.set_current_game_profile_setting_1("last_edited_intermission_id", intermission_id)

func on_intermission_id_changed(new_id: String) -> void:
    if not is_editing_intermission:
        return

    if not validate_intermission_id(new_id):
        new_id = filter_to_valid_id(new_id)
        intermission_id_input.text = new_id
        intermission_id_input.caret_column = new_id.length()
    editing_intermission_info["id"] = new_id
    check_for_unique_id()
    if current_id_is_valid:
        save_edited_intermission_info()

func check_for_unique_id() -> void:
    var current_id = editing_intermission_info.get("id", "")
    if not current_id:
        set_current_id_is_valid(false)
    elif GameManager.has_intermission_id(current_id):
        set_current_id_is_valid(false)
    else:
        set_current_id_is_valid(true)

func set_current_id_is_valid(is_valid: bool) -> void:
    current_id_is_valid = is_valid
    if is_valid:
        last_valid_id = editing_intermission_info["id"]
        intermission_id_input.remove_theme_color_override("font_color")
    else:
        intermission_id_input.add_theme_color_override("font_color", Color.RED)

func on_intermission_type_selected(type_id: int) -> void:
    if not is_editing_intermission:
        return
    var type: String = INTERMISSION_TYPES[type_id]
    change_type_to(type)

func change_type_to(type: String) -> void:
    if not is_editing_intermission:
        return
    editing_intermission_info["type"] = type
    if type != TYPE_INTERMISSION:
        old_content_items = editing_intermission_info.get("content_items", [])
        editing_intermission_info.erase("content_items")
    else:
        editing_intermission_info["content_items"] = old_content_items

    save_edited_intermission_info()
    refresh_show_sections(type)


func change_storage_location_to(is_bundled: bool, custom_list_name: String = "") -> bool:
    if not is_editing_intermission:
        return false
    if is_bundled:
        custom_list_name = ""

    var new_saved_id: String = ""
    if not is_editing_inside_level_list and is_bundled:
        # no op
        return false
    elif is_editing_inside_level_list != "" and is_editing_inside_level_list == custom_list_name:
        #no op
        return false
    elif is_editing_inside_level_list:
        if is_bundled:
            if GameManager.current_game_is_release_locked:
                return false
            new_saved_id = GameManager.import_intermission_from_custom_list(is_editing_inside_level_list, last_saved_id)
        else:
            new_saved_id = GameManager.move_intermission_between_custom_lists(is_editing_inside_level_list, custom_list_name, last_saved_id)
    else:
        if GameManager.current_game_is_release_locked:
            new_saved_id = GameManager.duplicate_bundled_intermission_into_custom_list(custom_list_name, last_saved_id, "-copy")
        else:
            new_saved_id = GameManager.move_intermission_to_custom_list(custom_list_name, last_saved_id)
    
    if new_saved_id:
        last_saved_id = new_saved_id
        is_editing_inside_level_list = custom_list_name
        refresh_ui()
        return true
    return false



# valid identifier characters and ' ' and '-', no spaces around the edges
func _is_valid_id_char(id_char: String) -> bool:
    if id_char.is_valid_int() or id_char == ' ' or id_char == '-':
        return true
    return id_char.is_valid_ascii_identifier()

func validate_intermission_id(new_id: String) -> bool:
    if not new_id or new_id.strip_edges().length() != new_id.length():
        return false
    for id_char in new_id:
        if not _is_valid_id_char(id_char):
            return false
    return true

func filter_to_valid_id(new_id: String) -> String:
    var valid_id: String = ""
    for id_char in new_id.strip_edges():
        if _is_valid_id_char(id_char):
            valid_id += id_char
    return valid_id


func refresh_ui() -> void:
    refresh_storage_location_selectors()
    duplicate_button.disabled = not is_editing_intermission

    make_overlay_ui_visible()
    if is_editing_intermission:
        intermission_id_input.text = editing_intermission_info.get("id", "")
        var intermission_type: String = editing_intermission_info.get("type", "")
        if not intermission_type in INTERMISSION_TYPES:
            intermission_type = TYPE_INTERMISSION
        intermission_type_selector.selected = INTERMISSION_TYPES.find(intermission_type)
        
        if intermission_type == TYPE_SEQUENCE:
            intermission_type_selector.tooltip_text = "Sequence of other intermissions"
        elif intermission_type == TYPE_CREDITS:
            intermission_type_selector.tooltip_text = "Show the credits defined for the game in the Credits section of the Game tab"
        else:
            intermission_type_selector.tooltip_text = ""
        
        show_only_once_toggle.set_pressed_no_signal(editing_intermission_info.get("show_only_once", false))

        refresh_show_sections(intermission_type)
        var custom_bg_info: Dictionary = editing_intermission_info.get("bg_style", {})
        if custom_bg_info:
            background_style_editor.load_manual_bg_style(custom_bg_info)
            update_bg_preview(custom_bg_info)
        else:
            update_bg_preview(GameManager.get_game_bg_info())
        refresh_show_bg_style_ui()
        if intermission_type == TYPE_CREDITS:
            pass
        elif intermission_type == TYPE_INTERMISSION:
            intermission_content_editor.load_contents_info(editing_intermission_info.get("content_items", []))
            
            var shade_light: bool = editing_intermission_info.get("light_background", true)
            var shade_dark: bool = editing_intermission_info.get("dark_background", false)
            if shade_light:
                bg_shade_selector.selected = 1
            elif shade_dark:
                bg_shade_selector.selected = 2
            else:
                bg_shade_selector.selected = 0
            show_continue_toggle.button_pressed = editing_intermission_info.get("show_continue", true)
        elif intermission_type == TYPE_SEQUENCE:
            intermission_sequence_list.local_custom_list_name = is_editing_inside_level_list
            intermission_sequence_list.load_assignments(editing_intermission_info.get("sequence_ids", []))
        else:
            push_warning("Unknown intermission type: %s" % intermission_type)
    else:
        intermission_id_input.text = ""
        refresh_show_sections()
    
    update_intermission_preview()

func refresh_show_sections(intermission_type: String = "") -> void:
    if not is_editing_intermission:
        intermission_type = ""
    
    content_and_bg_section.visible = intermission_type != ""
    content_section.visible = intermission_type == TYPE_INTERMISSION
    
    sequence_list_section.visible = intermission_type == TYPE_SEQUENCE
    
    intermission_id_input.editable = intermission_type != ""
    intermission_type_selector.disabled = intermission_type == ""

func refresh_storage_location_selectors() -> void:
    storage_location_selector.disabled = not is_editing_intermission

    custom_list_name_selector.clear()
    var all_custom_list_names: Array[String] = GameManager.get_list_of_non_bundled_level_lists()
    if is_editing_inside_level_list and is_editing_inside_level_list not in all_custom_list_names:
        if not GameManager.current_game_is_release_locked:
            if not change_storage_location_to(true):
                GlobalToaster.show_toast_message("Something went wrong")
                load_nothing()
                return

    for custom_list_name in all_custom_list_names:
        custom_list_name_selector.add_item(custom_list_name)
        if is_editing_inside_level_list == custom_list_name:
            custom_list_name_selector.selected = custom_list_name_selector.item_count - 1

    if not is_editing_intermission:
        Utility.opbtn_select_id(storage_location_selector, STORAGE_BUNDLED)
        if GameManager.current_game_is_release_locked:
            Utility.opbtn_select_id(storage_location_selector, STORAGE_CUSTOM_LIST)
            custom_list_name_selector.selected = 0
        else:
            custom_list_name_selector.visible = false
        return

    custom_list_name_selector.visible = is_editing_inside_level_list != ""
    var storage_location_id: = STORAGE_BUNDLED if is_editing_inside_level_list == "" else STORAGE_CUSTOM_LIST
    Utility.opbtn_select_id(storage_location_selector, storage_location_id)
    
    storage_location_selector.disabled = all_custom_list_names.size() == 0 or GameManager.current_game_is_release_locked

func on_storage_location_selected(index: int) -> void:
    if not is_editing_intermission:
        return
    var moved: bool = false
    var storage_location_id: = storage_location_selector.get_item_id(index)
    if storage_location_id == STORAGE_BUNDLED:
        moved = change_storage_location_to(true)
    elif storage_location_id == STORAGE_CUSTOM_LIST:
        var all_custom_list_names: Array[String] = GameManager.get_list_of_non_bundled_level_lists()
        if all_custom_list_names.size():
            var custom_list_name: String = all_custom_list_names[0]
            moved = change_storage_location_to(false, custom_list_name)
    
    if not moved:
        refresh_ui()

func on_custom_list_name_selected(index: int) -> void:
    if not is_editing_intermission:
        return
    if not change_storage_location_to(false, custom_list_name_selector.get_item_text(index)):
        refresh_ui()


func on_edit_intermission_menu_about_to_popup() -> void:
    var popup_menu: PopupMenu = edit_intermission_menu_button.get_popup()
    
    popup_menu.clear()
    var lists_by_storage_location: Dictionary = GameManager.get_lists_of_intermission_ids_by_storage_location()
    for id in lists_by_storage_location["bundled"]:
        popup_menu.add_radio_check_item(id)
        var idx: = popup_menu.item_count - 1
        if GameManager.current_game_is_release_locked:
            popup_menu.set_item_disabled(idx, true)
        if is_editing_intermission and not is_editing_inside_level_list and id == last_saved_id:
            popup_menu.set_item_checked(idx, true)
            popup_menu.set_item_disabled(idx, true)
    
    var custom_list_submenus: Dictionary = {}
    for custom_list_name in lists_by_storage_location["custom_lists"]:
        if lists_by_storage_location["custom_lists"][custom_list_name].size() == 0:
            continue

        var custom_list_submenu: PopupMenu = PopupMenu.new()
        custom_list_submenu.set_meta("custom_list_name", custom_list_name)
        var is_editing_in_this_list: bool = is_editing_intermission and is_editing_inside_level_list == custom_list_name
        for id in lists_by_storage_location["custom_lists"][custom_list_name]:
            custom_list_submenu.add_radio_check_item(":" + id)
            var idx: = custom_list_submenu.item_count - 1
            if is_editing_in_this_list and id == last_saved_id:
                custom_list_submenu.set_item_checked(idx, true)
                custom_list_submenu.set_item_disabled(idx, true)
        custom_list_submenus[custom_list_name] = custom_list_submenu

    if not custom_list_submenus.size() > 0:
        return

    popup_menu.add_separator("In Custom List")
    for custom_list_name in custom_list_submenus:
        var submenu: PopupMenu = custom_list_submenus[custom_list_name]
        popup_menu.add_submenu_node_item(custom_list_name, submenu)
        submenu.index_pressed.connect(on_edit_intermission_in_custom_list_selected.bind(submenu))


func on_edit_intermission_menu_selected(index: int) -> void:
    var popup_menu: PopupMenu = edit_intermission_menu_button.get_popup()
    var to_edit_id: String = popup_menu.get_item_text(index)
    load_intermission_from_id(to_edit_id)

func on_edit_intermission_in_custom_list_selected(index: int, custom_list_submenu: PopupMenu) -> void:
    var custom_list_name: String = custom_list_submenu.get_meta("custom_list_name", "")
    if not custom_list_name:
        return
    var to_edit_id: String = custom_list_submenu.get_item_text(index).trim_prefix(":")
    load_intermission_from_id(to_edit_id, custom_list_name)


func on_hide_overlay_pressed() -> void:
    if content_section.modulate != Color.WHITE:
        make_overlay_ui_visible()
    else:
        make_overlay_ui_transparent()

func make_overlay_ui_transparent() -> void:
    content_section.modulate = Color.TRANSPARENT
    bg_style_edit_container.modulate = Color.TRANSPARENT
    enable_custom_background_button.modulate = Color.TRANSPARENT
    if not game_editor_mode:
        main_options_section_panel.modulate = Color.TRANSPARENT

func make_overlay_ui_visible() -> void:
    content_section.modulate = Color.WHITE
    bg_style_edit_container.modulate = Color.WHITE
    enable_custom_background_button.modulate = Color.WHITE
    main_options_section_panel.modulate = Color.WHITE

func on_gui_focus_changed(_new_focus: Control) -> void:
    make_overlay_ui_visible()

func on_back_pressed() -> void:
    if game_editor_mode:
        return
    to_level_list_editor.emit()

func on_to_assignments_editor_pressed() -> void:
    if game_editor_mode:
        GameManager.is_in_level_edit_mode = true
        GameManager.change_scene("Play", false, "intermission-assignment-editor")
    else:
        to_assignment_editor.emit()

func update_intermission_preview() -> void:
    if not is_visible_in_tree():
        remove_intermission_preview()
        return
    if not is_editing_intermission or editing_intermission_info.get("type", "") != TYPE_INTERMISSION:
        remove_intermission_preview()
        return
    
    var preview_root: Control
    if game_editor_mode:
        preview_root = game_editor_intermission_preview_root
    else:
        preview_root = other_intermission_preview_root 
    for child in preview_root.get_children():
        if child is IntermissionUI:
            child.setup_with_info(editing_intermission_info.duplicate_deep())
            return
    
    var intermission_ui: = intermission_ui_scn.instantiate() as IntermissionUI
    
    preview_root.add_child(intermission_ui)
    intermission_ui.setup_with_info(editing_intermission_info.duplicate_deep())


func remove_intermission_preview() -> void:
    var preview_root: Control
    if game_editor_mode:
        preview_root = game_editor_intermission_preview_root
    else:
        preview_root = other_intermission_preview_root
    for child in preview_root.get_children():
        preview_root.remove_child(child)
        child.queue_free()


func on_visibility_changed() -> void:
    if not game_editor_mode and not is_visible_in_tree():
        background_style_preview.no_auto_update = false
        background_style_preview.refresh_bg_style()

    if game_editor_mode and is_visible_in_tree():
        refresh_ui()

func on_bg_shade_selected(index: int) -> void:
    if not is_editing_intermission or not editing_intermission_info.get("type", "") == TYPE_INTERMISSION:
        return
    editing_intermission_info["light_background"] = index == 1
    editing_intermission_info["dark_background"] = index == 2
    save_edited_intermission_info()
    update_intermission_preview()

func on_show_continue_toggled(button_pressed: bool) -> void:
    if not is_editing_intermission or not editing_intermission_info.get("type", "") == TYPE_INTERMISSION:
        return
    editing_intermission_info["show_continue"] = button_pressed
    save_edited_intermission_info()
    update_intermission_preview()


func on_show_only_once_toggled(_button_pressed: bool) -> void:
    save_edited_intermission_info()


func update_intermission_sequence() -> void:
    if not is_editing_intermission or not editing_intermission_info.get("type", "") == TYPE_SEQUENCE:
        return
    editing_intermission_info["sequence_ids"] = intermission_sequence_list.get_assignments()

func on_intermission_sequence_list_edited() -> void:
    update_intermission_sequence()
    save_edited_intermission_info()

func edit_intermission_from_sequence(intermission_id: String, custom_list_name: String) -> void:
    load_intermission_from_id(intermission_id, custom_list_name)

func edit_duplicate_intermission_from_sequence(intermission_id: String, to_list_name: String) -> void:
    var duplicate_id: String = make_duplicate_into_list(intermission_id, to_list_name)
    intermission_sequence_list.local_duplicate_created_with_id(duplicate_id)
    update_intermission_sequence()
    save_edited_intermission_info()
    load_intermission_from_id(duplicate_id, to_list_name)
