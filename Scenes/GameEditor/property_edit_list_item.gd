extends PanelContainer

signal request_remove(property_name: String)
signal request_override(property_name: String)
signal request_restore(property_name: String)
signal request_activate(list_item)
signal property_name_changed(old_name: String, new_name: String)
signal property_name_change_finalized(new_name: String)
signal property_value_changed(property_name: String, value: Variant)

signal request_convert_conditional(property_name: String, is_conditional: bool)

const event_icon: Texture2D = preload("res://assets/img/property_list/event_icon.png")
const special_prop_icon: Texture2D = preload("res://assets/img/property_list/special_prop_icon.png")

const conditional_icon: Texture2D = preload("res://assets/img/property_list/conditional_icon.png")
const local_prop_icon: Texture2D = preload("res://assets/img/property_list/local_prop_icon.png")

const no_icon: Texture2D = preload("res://assets/img/property_list/no_icon.png")

@export var property_name: String = ""
@export var property_value: Variant = true

@export var local_props_enabled: bool = true
@export var enable_edit_base_props: bool = true

@export_group("UI Refs")
@export var icon_button1: Control
@export var icon_button2: Control

@export var name_section: Control
@export var name_label: RichTextLabel
@export var name_edit: LineEdit

@export var value_section: Control
@export var value_label: RichTextLabel
@export var value_edit: Control

@export var override_button: Button
@export var remove_button: ButtonContainer

@export_group("Colors")
@export var normal_text_color: Color = Color.WHITE
@export var boolean_text_color: Color = Color.BLUE
@export var number_text_color: Color = Color.YELLOW
@export var conditional_desc_color: Color = Color.DIM_GRAY
@export var removed_text_color: Color = Color.RED
@export var removed_bool_text_color: Color = Color.RED
@export var removed_number_text_color: Color = Color.RED

@export var event_name_color: Color = Color.GREEN
@export var special_prop_name_color: Color = Color.PINK

@export_group("Styleboxes")
@export var inactive_stylebox: StyleBox
@export var active_stylebox: StyleBox
@export var highlighted_stylebox: StyleBox

var base_property_value: Variant = null

var is_base_definition_property: bool = true
var is_overridden: bool = false
var is_removed: bool = false

var _hovered: bool = false
var _is_active: bool = false

var _name_edited: bool = false
var _name_edited_from: String = ""

func _ready() -> void:
    remove_button.pressed.connect(on_remove_button_pressed)
    override_button.pressed.connect(on_override_button_pressed)
    name_edit.text_changed.connect(on_name_edit_text_changed)
    name_edit.editing_toggled.connect(on_name_edit_editing_toggled)

    add_theme_stylebox_override("panel", _normal_stylebox())
    set_prop_value(property_value)

func get_name_section_width() -> float:
    return name_section.get_minimum_size().x

func set_name_section_fixed_width(new_width: float) -> void:
    name_section.custom_minimum_size.x = new_width

func set_prop_value(new_value: Variant) -> void:
    property_value = new_value
    if is_base_definition_property and not is_overridden and not is_removed:
        base_property_value = new_value
    refresh_ui()

func _process(_delta: float) -> void:
    if not get_window().has_focus():
        return
    
    var mouse_over: = get_rect().has_point(get_local_mouse_position())
    if not _hovered and mouse_over:
        add_theme_stylebox_override("panel", highlighted_stylebox)
    elif _hovered and not mouse_over:
        add_theme_stylebox_override("panel", _normal_stylebox())

func _normal_stylebox() -> StyleBox:
    return active_stylebox if _is_active else inactive_stylebox

func set_active(new_is_active: bool) -> void:
    if _is_active == new_is_active:
        return
    _is_active = new_is_active
    var mouse_over: = get_rect().has_point(get_local_mouse_position())
    if not mouse_over:
        add_theme_stylebox_override("panel", _normal_stylebox())

func is_active() -> bool:
    return _is_active

func is_conditional() -> bool:
    if is_removed:
        return false
    return typeof(property_value) in [TYPE_DICTIONARY, TYPE_ARRAY]

func set_override_state(new_is_base: bool, new_is_override: bool, new_is_removed: bool, new_value: Variant) -> void:
    if new_is_override and new_is_removed:
        new_is_override = false
    is_base_definition_property = new_is_base
    is_overridden = new_is_override
    is_removed = new_is_removed
    set_prop_value(new_value)

func make_overridden() -> void:
    if not local_props_enabled or is_overridden or not is_base_definition_property:
        push_error("Cannot make property overridden: %s" % property_name)
        return
    var new_value: Variant = property_value
    if is_conditional():
        new_value = true
    set_override_state(is_base_definition_property, true, false, new_value)

func make_removed() -> void:
    if not is_base_definition_property:
        push_error("Cannot make property removed: %s" % property_name)
        return
    if is_removed:
        return
    set_override_state(true, false, true, base_property_value)

func on_remove_button_pressed() -> void:
    request_remove.emit(property_name)

func on_override_button_pressed() -> void:
    if not local_props_enabled or not is_base_definition_property:
        return
    if is_overridden or is_removed:
        request_restore.emit(property_name)
    else:
        request_override.emit(property_name)

func on_name_edit_text_changed(new_name: String) -> void:
    if is_base_definition_property and not enable_edit_base_props:
        return
    var old_name = property_name
    property_name = new_name
    property_name_changed.emit(old_name, property_name)
    if name_edit.is_editing():
        _name_edited = true
    else:
        property_name_change_finalized.emit(property_name)
        _name_edited = false

func on_name_edit_editing_toggled(is_editing: bool) -> void:
    if is_editing:
        _name_edited_from = property_name
    elif _name_edited:
        property_name_change_finalized.emit(property_name)
        _name_edited = false


func on_prop_value_edited(new_value: Variant) -> void:
    property_value_changed.emit(property_name, new_value)

func refresh_ui() -> void:
    show_name_edit_or_label()
    if name_label.visible:
        name_label.text = get_rich_name_text()
    name_edit.text = property_name
    show_value_edit_or_label()
    if value_label.visible:
        value_label.text = get_rich_value_text()
    
    if is_event_name(property_name):
        icon_button1.texture_normal = event_icon
        icon_button1.modulate = event_name_color
        icon_button1.tooltip_text = "Event"
    elif is_special_prop_name(property_name):
        icon_button1.texture_normal = special_prop_icon
        icon_button1.modulate = special_prop_name_color
        icon_button1.tooltip_text = "Special Property"
    else:
        icon_button1.texture_normal = no_icon
        icon_button1.modulate = Color.WHITE
        icon_button1.tooltip_text = ""
    
    if local_props_enabled and is_overridden or is_removed:
        icon_button2.texture_normal = local_prop_icon
        icon_button2.tooltip_text = "Local Property Override" + (" (Overridden as Removed)" if is_removed else "")
    elif is_conditional():
        icon_button2.texture_normal = conditional_icon
        icon_button2.tooltip_text = "Conditional"
    else:
        icon_button2.texture_normal = no_icon
        icon_button2.tooltip_text = ""
    
    override_button.visible = is_base_definition_property and local_props_enabled

    if is_base_definition_property and local_props_enabled:
        override_button.text = "restore" if is_overridden or is_removed else "override"
        remove_button.disabled = is_removed and not enable_edit_base_props
    elif is_base_definition_property and not enable_edit_base_props:
        remove_button.disabled = true
    else:
        remove_button.disabled = false
    
    refresh_value_edit()

func refresh_value_edit() -> void:
    pass


func show_name_edit_or_label() -> void:
    name_edit.visible = not is_base_definition_property or enable_edit_base_props
    name_label.visible = not name_edit.visible

func show_value_edit_or_label() -> void:
    value_label.visible = true

func is_special_prop_name(prop_name: String) -> bool:
    return GameManager.is_special_prop_name(prop_name)

func is_event_name(prop_name: String) -> bool:
    return GameManager.is_event_name(prop_name)

func sub_item_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.is_pressed():
        request_activate.emit(self)


func is_fade_base_prop() -> bool:
    return local_props_enabled and is_base_definition_property and not is_overridden

func _colored(in_text: String, as_color: Color) -> String:
    return "[color=%s]%s[/color]" % [Utility.color_string(as_color, false), in_text]

func get_rich_name_text() -> String:
    var prop_name = property_name

    var is_special_prop: bool = is_special_prop_name(prop_name)
    var is_event_prop: bool = is_event_name(prop_name)
    var text_color: Color = normal_text_color
    if is_removed:
        prop_name = "[s]%s[/s]" % prop_name
        text_color = removed_text_color
        if is_event_prop:
            text_color = event_name_color.darkened(0.8)
        elif is_special_prop:
            text_color = special_prop_name_color.darkened(0.8)
    else:
        if is_event_prop:
            text_color = event_name_color
        elif is_special_prop:
            text_color = special_prop_name_color
    if text_color != normal_text_color:
        prop_name = _colored(prop_name, text_color)
    return prop_name

func get_rich_value_text() -> String:
    var val_text: String = ""
    var text_color: Color = normal_text_color
    if is_conditional():
        val_text = "{CONDITIONAL}"
        text_color = removed_text_color if is_removed else conditional_desc_color
    else:
        val_text = str(property_value)
        text_color = removed_text_color if is_removed else normal_text_color
        if typeof(property_value) == TYPE_BOOL:
            text_color = removed_bool_text_color if is_removed else boolean_text_color
        elif typeof(property_value) in [TYPE_INT, TYPE_FLOAT]:
            text_color = removed_number_text_color if is_removed else number_text_color

    if is_removed:
        val_text = "[s]%s[/s]" % val_text
    elif is_base_definition_property and not is_overridden:
        text_color.a = 0.75
    return _colored(val_text, text_color)