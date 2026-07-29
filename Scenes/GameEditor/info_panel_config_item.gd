extends Control

const BetterTextureDialog = preload("res://src/GameEditor/BetterTextureDialog.gd")
const tex_picker_scn = preload("res://Scenes/GameEditor/BetterTextureDialog.tscn")

signal item_updated()
signal request_move_relative(direction: int)
signal request_move_to_top()
signal request_move_to_bottom()
signal request_remove()
signal request_duplicate()

@export var image_picker_icon_scale: float = 0.5

@export var not_found_icon: Texture2D

@export var order_button_up: ButtonContainer
@export var order_button_down: ButtonContainer
@export var remove_button: ButtonContainer


@export var icon_mode_picker: OptionButton
@export var pick_image_button: ButtonContainer
@export var icon_entity_name_input: LineEdit

@export var label_input: LineEdit

@export var separator_input: LineEdit


@export var value_prop_option: HBoxContainer
@export var entity_filter_option: HBoxContainer
@export var prop_filter_option: HBoxContainer
@export var hide_zero_value_option: HBoxContainer
@export var prop_truthy_suboption: HBoxContainer

@export var tracking_type_picker: OptionButton

@export var entity_name_label_1: Label
@export var entity_name_label_2: Label

@export var value_prop_input: FuzzyAutocompleteInput
@export var entity_filter_input: FuzzyAutocompleteInput
@export var prop_filter_input: FuzzyAutocompleteInput
@export var prop_truthy_picker: OptionButton

@export var hide_zero_toggle: CheckButton
@export var hide_empty_toggle: CheckButton

@export var include_pending_option: Control
@export var include_pending_mode_select: OptionButton


const CTX_MOVE_UP = 1
const CTX_MOVE_DOWN = 2

const CTX_MOVE_TO_TOP = 10 
const CTX_MOVE_TO_BOTTOM = 11

const CTX_DUPLICATE = 20

const CTX_REMOVE = 30


const PENDING_MODE_EXCLUDE = 0
const PENDING_MODE_INCLUDE_NO_SEPARATE = 1
const PENDING_MODE_INCLUDE_SMART_SEPARATE = 2
const PENDING_MODE_INCLUDE_ALWAYS_SEPARATE = 3


var icon_image_texture_id: int = -1
var icon_image_tex_index: int = -1
var icon_entity_id: int = -1


func _ready() -> void:
    order_button_up.pressed.connect(sort_button_pressed.bind(-1))
    order_button_down.pressed.connect(sort_button_pressed.bind(1))
    remove_button.pressed.connect(request_remove.emit)

    icon_entity_name_input.text_changed.connect(icon_entity_name_changed)
    
    icon_mode_picker.item_selected.connect(_some_option_button_changed)
    tracking_type_picker.item_selected.connect(_some_option_button_changed)
    prop_truthy_picker.item_selected.connect(_some_option_button_changed)

    value_prop_input.text_changed.connect(_some_text_updated)
    entity_filter_input.text_changed.connect(_some_text_updated)
    prop_filter_input.text_changed.connect(_some_text_updated)
    label_input.text_changed.connect(_some_text_updated)
    separator_input.text_changed.connect(_some_text_updated)
    
    hide_zero_toggle.toggled.connect(_some_button_toggled)
    hide_empty_toggle.toggled.connect(_some_button_toggled)
    
    pick_image_button.pressed.connect(show_image_picker)
    
    setup_pending_mode_select()

func setup_pending_mode_select() -> void:
    include_pending_mode_select.clear()
    include_pending_mode_select.add_item("Exclude", PENDING_MODE_EXCLUDE)
    include_pending_mode_select.add_item("Include", PENDING_MODE_INCLUDE_NO_SEPARATE)
    include_pending_mode_select.add_item("Set +Pending", PENDING_MODE_INCLUDE_SMART_SEPARATE)
    include_pending_mode_select.add_item("Set +Pending (Even if 0)", PENDING_MODE_INCLUDE_ALWAYS_SEPARATE)
    include_pending_mode_select.selected = PENDING_MODE_INCLUDE_NO_SEPARATE


func show_image_picker() -> void:
    var picker: = tex_picker_scn.instantiate() as BetterTextureDialog
    picker.setup(maxi(0, icon_image_texture_id), maxi(0, icon_image_tex_index))
    picker.confirmed.connect(on_image_picked.bind(picker))
    add_child(picker)
    picker.popup_centered()

func on_image_picked(picker: BetterTextureDialog) -> void:
    icon_image_texture_id = picker.get_selected_texture()
    icon_image_tex_index = picker.get_selected_sub_index()
    refresh_ui()
    item_updated.emit()

func sort_button_pressed(direction: int) -> void:
    request_move_relative.emit(direction)

func _some_option_button_changed(_new_index: int) -> void:
    refresh_ui()
    item_updated.emit()

func _some_button_toggled(_new_pressed: bool) -> void:
    refresh_ui()
    item_updated.emit()


func icon_entity_name_changed(new_entity_name: String) -> void:
    if EntityManager.entity_name_exists(new_entity_name):
        icon_entity_id = EntityManager.get_entity_index(new_entity_name)
    else:
        icon_entity_id = -1
    refresh_ui()
    item_updated.emit()

func _some_text_updated(_text: String) -> void:
    refresh_ui()
    item_updated.emit()



func load_config_data(config_data: Dictionary) -> void:
    var is_entity_count: bool = config_data.get("type", "property") == "entity_count"
    var is_entity_flag_count: bool = config_data.get("type", "property") == "entity_flag_count"
    var is_filtered: bool = config_data.get("filtered", false)
    
    if is_entity_flag_count:
        tracking_type_picker.select(3)
    elif not is_entity_count and is_filtered:
        tracking_type_picker.select(1)
    elif not is_entity_count:
        tracking_type_picker.select(0)
    else:
        tracking_type_picker.select(2)
    
    icon_image_texture_id = -1
    icon_image_tex_index = -1
    icon_entity_id = -1
    icon_entity_name_input.text = ""

    var is_entity_icon: bool = config_data.get("entity_icon", -1) > -1
    var is_image_icon: bool = config_data.get("image_icon", -1) > -1 and config_data.get("image_icon_tex_index", -1) > -1
    if not is_entity_icon and not is_image_icon:
        icon_mode_picker.select(0)
    elif is_entity_icon:
        icon_mode_picker.select(1)
        icon_entity_id = config_data["entity_icon"]
        icon_entity_name_input.text = EntityManager.get_entity_name(icon_entity_id)
    elif is_image_icon:
        icon_mode_picker.select(2)
        icon_image_texture_id = config_data["image_icon"]
        icon_image_tex_index = config_data["image_icon_tex_index"]
    
    label_input.text = config_data.get("label", "")
    separator_input.text = config_data.get("separator", "")
    
    value_prop_input.text = config_data.get("value_prop", "")
    entity_filter_input.text = config_data.get("entity_name", "")
    prop_filter_input.text = config_data.get("filter_prop", "")
    
    if is_filtered:
        prop_truthy_picker.select(0 if config_data["filter_truthy"] else 1)
    else:
        prop_truthy_picker.select(0)
    
    hide_zero_toggle.set_pressed_no_signal(config_data.get("hide_zero_value", true))
    hide_empty_toggle.set_pressed_no_signal(config_data.get("hide_empty_value", true))
    
    if is_entity_flag_count:
        var is_include_pending: bool = config_data.get("include_pending", true)
        var is_separate_pending: bool = config_data.get("separate_pending", false)
        var is_always_separate: bool = config_data.get("always_separate", false)
        if not is_include_pending:
            Utility.opbtn_select_id(include_pending_mode_select, PENDING_MODE_EXCLUDE)
        elif not is_separate_pending:
            Utility.opbtn_select_id(include_pending_mode_select, PENDING_MODE_INCLUDE_NO_SEPARATE)
        elif not is_always_separate:
            Utility.opbtn_select_id(include_pending_mode_select, PENDING_MODE_INCLUDE_SMART_SEPARATE)
        else:
            Utility.opbtn_select_id(include_pending_mode_select, PENDING_MODE_INCLUDE_ALWAYS_SEPARATE)

    refresh_ui()


func get_config_data() -> Dictionary:
    var config_data: Dictionary = {}
    var is_entity_count: bool = tracking_type_picker.selected == 2
    var is_entity_flag_count: bool = tracking_type_picker.selected == 3

    config_data["type"] = "entity_count" if is_entity_count else "property"
    if is_entity_flag_count:
        config_data["type"] = "entity_flag_count"

    var is_filtered: bool = tracking_type_picker.selected in [1, 2]
    config_data["filtered"] = is_filtered
    if is_filtered:
        config_data["filter_prop"] = prop_filter_input.text.strip_edges()
        config_data["filter_truthy"] = prop_truthy_picker.selected == 0

    if is_entity_count or is_entity_flag_count:
        var entity_name: = entity_filter_input.text.strip_edges()
        if EntityManager.entity_name_exists(entity_name):
            config_data["entity_id"] = EntityManager.get_entity_index(entity_name)
        else:
            config_data["entity_id"] = -1
    else:
        config_data["camera_tracked"] = tracking_type_picker.selected == 0
        config_data["value_prop"] = value_prop_input.text.strip_edges()
    
    var has_icon: bool = icon_mode_picker.selected != 0
    var is_entity_icon: bool = icon_mode_picker.selected == 1
    var is_image_icon: bool = icon_mode_picker.selected == 2
    
    if has_icon:
        if is_entity_icon and icon_entity_id > -1:
            config_data["entity_icon"] = icon_entity_id
        elif is_image_icon and icon_image_texture_id > -1 and icon_image_tex_index > -1:
            config_data["image_icon"] = icon_image_texture_id
            config_data["image_icon_tex_index"] = icon_image_tex_index
    
    if label_input.text.strip_edges().length() > 0:
        config_data["label"] = label_input.text.strip_edges()
    if separator_input.text.strip_edges().length() > 0:
        config_data["separator"] = separator_input.text.strip_edges()
    
    config_data["hide_zero_value"] = hide_zero_toggle.button_pressed
    config_data["hide_empty_value"] = hide_empty_toggle.button_pressed
    if is_entity_count or is_entity_flag_count:
        config_data.erase("hide_empty_value")
    
    if is_entity_flag_count:
        var pending_mode_id: int = Utility.opbtn_get_selected_id(include_pending_mode_select)
        config_data["include_pending"] = is_pending_mode_include_pending(pending_mode_id)
        config_data["separate_pending"] = is_pending_mode_separate_pending(pending_mode_id)
        config_data["always_separate"] = is_pending_mode_always_separate(pending_mode_id)

    return config_data
    
func refresh_ui() -> void:
    var is_entity_count: bool = tracking_type_picker.selected == 2
    var is_entity_flag_count: bool = tracking_type_picker.selected == 3
    var is_filtered: bool = tracking_type_picker.selected in [1, 2]
    
    if is_entity_count:
        entity_filter_input.placeholder_text = "<Any type>"
    else:
        entity_filter_input.placeholder_text = "[entity name]"
    
    entity_filter_option.visible = is_entity_count or is_entity_flag_count
    value_prop_option.visible = not (is_entity_count or is_entity_flag_count)
    prop_filter_option.visible = is_filtered
    hide_empty_toggle.visible = not (is_entity_count or is_entity_flag_count)
    
    include_pending_option.visible = is_entity_flag_count
    
    entity_name_label_1.visible = is_entity_count
    entity_name_label_2.visible = is_entity_flag_count
    
    if is_filtered:
        prop_truthy_suboption.visible = prop_filter_input.text.strip_edges().length() > 0
    
    var has_icon: bool = icon_mode_picker.selected != 0
    var is_entity_icon: bool = icon_mode_picker.selected == 1
    var is_image_icon: bool = icon_mode_picker.selected == 2
    
    icon_entity_name_input.visible = is_entity_icon
    pick_image_button.visible = has_icon
    pick_image_button.disabled = not is_image_icon
    if is_image_icon:
        if TextureManager.has_loaded_texture_id(icon_image_texture_id):
            var atlas_texture: = Utility.atlas_texture_from_texture_index(icon_image_texture_id, icon_image_tex_index)
            pick_image_button.set_icon(atlas_texture)
            pick_image_button.reset_icon_scale()
        else:
            pick_image_button.set_icon(not_found_icon)
            pick_image_button.set_icon_scale(2)
    else:
        var entity_name: = icon_entity_name_input.text.strip_edges()
        if EntityManager.entity_name_exists(entity_name):
            var entity_id: int = EntityManager.get_entity_index(entity_name)
            var entity_icon: = EntityManager.get_entity_sprite_snapshot(entity_id)
            var ui_scale: float = GameManager.get_default_pixel_scale() * image_picker_icon_scale
            var entity_icon_scale: float = EntityManager.get_entity_sprite_snapshot_scale(entity_id, false, false)

            pick_image_button.set_icon(entity_icon)
            pick_image_button.set_icon_scale(entity_icon_scale * ui_scale)
        else:
            pick_image_button.set_icon(not_found_icon)
            pick_image_button.set_icon_scale(2)
    
    if icon_entity_name_input.visible and icon_entity_name_input.text:
        icon_entity_name_input.update_highlight()
    if entity_filter_input.visible and entity_filter_input.text:
        entity_filter_input.update_highlight()
    if prop_filter_input.visible and prop_filter_input.text:
        prop_filter_input.update_highlight()
    if value_prop_input.visible and value_prop_input.text:
        value_prop_input.update_highlight()

func show_context_menu() -> void:
    var context_menu: = Utility.get_empty_context_menu()
    context_menu.add_item("Move Up", CTX_MOVE_UP)
    context_menu.add_item("Move Down", CTX_MOVE_DOWN)
    context_menu.add_item("Move to Top", CTX_MOVE_TO_TOP)
    context_menu.add_item("Move to Bottom", CTX_MOVE_TO_BOTTOM)
    context_menu.add_item("Duplicate", CTX_DUPLICATE)
    context_menu.add_item("Remove", CTX_REMOVE)
    context_menu.id_pressed.connect(on_context_menu_id_pressed)
    Utility.popup_context_menu_at_mouse(context_menu)

func on_context_menu_id_pressed(context_menu_id: int) -> void:
    if context_menu_id in [CTX_MOVE_UP, CTX_MOVE_DOWN]:
        var dir: int = -1 if context_menu_id == CTX_MOVE_UP else 1
        request_move_relative.emit(dir)
    elif context_menu_id == CTX_MOVE_TO_TOP:
        request_move_to_top.emit()
    elif context_menu_id == CTX_MOVE_TO_BOTTOM:
        request_move_to_bottom.emit()
    elif context_menu_id == CTX_DUPLICATE:
        request_duplicate.emit()
    elif context_menu_id == CTX_REMOVE:
        request_remove.emit()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
        show_context_menu()

func is_pending_mode_include_pending(pending_mode_id: int) -> bool:
    return pending_mode_id != PENDING_MODE_EXCLUDE

func is_pending_mode_separate_pending(pending_mode_id: int) -> bool:
    if not is_pending_mode_include_pending(pending_mode_id):
        return false
    return pending_mode_id != PENDING_MODE_INCLUDE_NO_SEPARATE

func is_pending_mode_always_separate(pending_mode_id: int) -> bool:
    return pending_mode_id == PENDING_MODE_INCLUDE_ALWAYS_SEPARATE
