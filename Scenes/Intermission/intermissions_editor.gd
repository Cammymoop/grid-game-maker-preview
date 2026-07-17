extends PanelContainer

const StyleEditor = preload("res://Scenes/GameEditor/bg_style_editor.gd")
const BgEffect = preload("res://Scenes/bg_effect_5.gd")

const IntermissionContentEditor = preload("res://Scenes/Intermission/intermission_content_editor.gd")

@export var intermission_id_input: LineEdit

@export var intermission_type_selector: OptionButton

@export var edit_new_intermission_button: Button
@export var edit_intermission_menu_button: MenuButton

@export var bg_style_edit_container: Control
@export var background_style_editor: StyleEditor
@export var background_style_preview: BgEffect

@export var intermission_content_editor: IntermissionContentEditor
@export var enable_custom_background_button: Button

@export var main_options_section: Control
@export var content_and_bg_section: Control
@export var content_section: Control

@export var hide_overlay_button: Button

var is_editing_intermission: bool = false
var editing_intermission_info: Dictionary = {}

var last_valid_id: String = ""
var last_saved_id: String = ""

var current_id_is_valid: bool = false

var old_content_items: Array = []

const TYPE_CREDITS: String = "credits"
const TYPE_INTERMISSION: String = "intermission"
const INTERMISSION_TYPES: Array[String] = [TYPE_CREDITS, TYPE_INTERMISSION]

func _ready() -> void:
    intermission_type_selector.clear()
    for type_id in INTERMISSION_TYPES.size():
        intermission_type_selector.add_item(INTERMISSION_TYPES[type_id], type_id)
    intermission_type_selector.selected = 0
    intermission_type_selector.item_selected.connect(on_intermission_type_selected)
    
    edit_new_intermission_button.pressed.connect(edit_new_intermission)
    
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
    
    get_viewport().gui_focus_changed.connect(on_gui_focus_changed)
    
    load_last_edited_intermission()
    if not is_editing_intermission:
        refresh_ui()
        pass#

func edit_new_intermission() -> void:
    var new_id: String = GameManager.get_available_numeric_intermission_id()
    var new_info: Dictionary = {
        "id": new_id,
        "type": TYPE_INTERMISSION,
        "content_items": [],
        "bg_style": {}
    }
    GameManager.update_intermission_info(new_id, new_info)
    load_intermission_from_id(new_id)

func load_last_edited_intermission() -> void:
    var last_edited_id: String = GameManager.get_current_game_profile_setting_1("last_edited_intermission_id", "")
    prints("last_edited_id: %s" % last_edited_id)
    if not last_edited_id:
        return
    load_intermission_from_id(last_edited_id)

func load_intermission_from_id(intermission_id: String) -> void:
    if not intermission_id or not GameManager.has_intermission_id(intermission_id):
        return
    is_editing_intermission = true
    editing_intermission_info = GameManager.get_intermission_info(intermission_id)
    if not editing_intermission_info:
        is_editing_intermission = false
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

func on_intermission_content_updated() -> void:
    if not is_editing_intermission:
        return
    editing_intermission_info["content_items"] = intermission_content_editor.get_contents_info()
    save_edited_intermission_info()

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
    background_style_preview.set_bg_style(bg_style)

# save using the last valid id if the current is invalid so data isn't lost unnecessarily
func save_edited_intermission_info() -> void:
    if not is_editing_intermission or not last_valid_id:
        return
    var save_info: = editing_intermission_info.duplicate_deep()
    save_info["id"] = last_valid_id
    GameManager.update_intermission_info(last_saved_id, save_info)
    last_saved_id = last_valid_id
    save_last_edited_intermission_id(last_valid_id)

func save_last_edited_intermission_id(intermission_id: String) -> void:
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
    make_overlay_ui_visible()
    if is_editing_intermission:
        intermission_id_input.text = editing_intermission_info.get("id", "")
        var intermission_type: String = editing_intermission_info.get("type", "")
        if not intermission_type in INTERMISSION_TYPES:
            intermission_type = TYPE_INTERMISSION
        intermission_type_selector.selected = INTERMISSION_TYPES.find(intermission_type)
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
        else:
            push_warning("Unknown intermission type: %s" % intermission_type)
    else:
        intermission_id_input.text = ""
        refresh_show_sections()

func refresh_show_sections(intermission_type: String = "") -> void:
    if not is_editing_intermission:
        intermission_type = ""
    
    content_and_bg_section.visible = intermission_type != ""
    content_section.visible = intermission_type == TYPE_INTERMISSION
    
    intermission_id_input.editable = intermission_type != ""
    intermission_type_selector.disabled = intermission_type == ""


func on_edit_intermission_menu_about_to_popup() -> void:
    var popup_menu: PopupMenu = edit_intermission_menu_button.get_popup()
    
    popup_menu.clear()
    var all_ids: Array[String] = GameManager.get_all_intermission_ids()
    for id in all_ids:
        popup_menu.add_radio_check_item(id)
        var idx: = popup_menu.item_count - 1
        if is_editing_intermission and id == last_saved_id:
            popup_menu.set_item_checked(idx, true)
            popup_menu.set_item_disabled(idx, true)

func on_edit_intermission_menu_selected(index: int) -> void:
    var popup_menu: PopupMenu = edit_intermission_menu_button.get_popup()
    var to_edit_id: String = popup_menu.get_item_text(index)
    load_intermission_from_id(to_edit_id)


func on_hide_overlay_pressed() -> void:
    if content_section.modulate != Color.WHITE:
        make_overlay_ui_visible()
    else:
        make_overlay_ui_transparent()

func make_overlay_ui_transparent() -> void:
    content_section.modulate = Color.TRANSPARENT
    bg_style_edit_container.modulate = Color.TRANSPARENT
    enable_custom_background_button.modulate = Color.TRANSPARENT

func make_overlay_ui_visible() -> void:
    content_section.modulate = Color.WHITE
    bg_style_edit_container.modulate = Color.WHITE
    enable_custom_background_button.modulate = Color.WHITE

func on_gui_focus_changed(_new_focus: Control) -> void:
    make_overlay_ui_visible()