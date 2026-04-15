extends PanelContainer

signal request_remove(property_name: String)
signal request_override(property_name: String)
signal request_restore(property_name: String)
signal request_activate(list_item)
signal property_name_changed(old_name: String, new_name: String)
signal property_name_change_finalized(new_name: String)
signal property_value_changed(property_name: String, value: Variant)

signal request_convert_conditional(property_name: String, is_conditional: bool)

const MultiTypeInput = preload("res://Scenes/GameEditor/multi_type_input.gd")

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
@export var sub_item_container: Control

@export var icon_1: Control
@export var icon_2: Control

@export var name_section: Control
@export var name_label: RichTextLabel
@export var name_edit: LineEdit

@export var value_section: Control
@export var edit_value_button: Control
@export var value_label: RichTextLabel
@export var value_edit: MultiTypeInput

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
@export var active_highlighted_stylebox: StyleBox

var base_property_value: Variant = null

var is_base_definition_property: bool = true
var is_overridden: bool = false
var is_removed: bool = false

var _hovered: bool = false
var _is_active: bool = false
var _value_editting: bool = false

var _name_edited: bool = false
var _name_edited_from: String = ""

func _ready() -> void:
    remove_button.pressed.connect(on_remove_button_pressed)
    override_button.pressed.connect(on_override_button_pressed)
    name_edit.text_changed.connect(on_name_edit_text_changed)
    name_edit.editing_toggled.connect(on_name_edit_editing_toggled)
    
    value_edit.value_changed.connect(on_value_edited)
    value_edit.input_focus_out.connect(on_value_input_focus_out)
    value_edit.input_focus_in.connect(request_activate.emit.bind(self))
    
    value_edit.hide()
    value_label.show()
    
    if not sub_item_container:
        sub_item_container = self
    for child in sub_item_container.get_children():
        if child is Control:
            var has_control_children: bool = false
            if not child is ButtonContainer:
                for sub_sub_item in child.get_children():
                    if sub_sub_item is Control:
                        has_control_children = true
                        sub_sub_item.gui_input.connect(sub_item_gui_input.bind(sub_sub_item))
                        sub_sub_item.focus_entered.connect(sub_item_focus_entered.bind(sub_sub_item))
            if not has_control_children:
                child.gui_input.connect(sub_item_gui_input.bind(child))
                child.focus_entered.connect(sub_item_focus_entered.bind(child))

    add_theme_stylebox_override("panel", _normal_stylebox())
    set_prop_value(property_value)

func get_name_section_width() -> float:
    return name_section.get_minimum_size().x

func set_name_section_fixed_width(new_width: float) -> void:
    name_section.custom_minimum_size.x = new_width

func set_prop_value(new_value: Variant) -> void:
    property_value = new_value
    value_edit.set_value(new_value)
    if is_base_definition_property and not is_overridden and not is_removed:
        base_property_value = new_value
    refresh_ui()

func on_value_edited(new_value: Variant) -> void:
    if not is_active():
        request_activate.emit(self)
    property_value = new_value
    property_value_changed.emit(property_name, new_value)

func on_value_input_focus_out() -> void:
    stop_value_editting()

func _process(_delta: float) -> void:
    if not get_window().has_focus():
        if _hovered:
            add_theme_stylebox_override("panel", _normal_stylebox())
            _hovered = false
        return
    
    var mouse_over: = Rect2(Vector2.ZERO, get_size()).has_point(get_local_mouse_position())
    if not _hovered and mouse_over:
        add_theme_stylebox_override("panel", _highlighted_stylebox())
        _hovered = true
    elif _hovered and not mouse_over:
        add_theme_stylebox_override("panel", _normal_stylebox())
        _hovered = false

func _normal_stylebox() -> StyleBox:
    return active_stylebox if _is_active else inactive_stylebox

func _highlighted_stylebox() -> StyleBox:
    if _is_active:
        return active_highlighted_stylebox if active_highlighted_stylebox else active_stylebox
    else:
        return highlighted_stylebox

func set_active(new_is_active: bool) -> void:
    if _is_active == new_is_active:
        return
    _is_active = new_is_active
    if not _is_active:
        stop_value_editting()
    var mouse_over: = Rect2(Vector2.ZERO, get_size()).has_point(get_local_mouse_position())
    if not mouse_over:
        add_theme_stylebox_override("panel", _normal_stylebox())
    else:
        add_theme_stylebox_override("panel", _highlighted_stylebox())

func is_active() -> bool:
    return _is_active

func is_conditional() -> bool:
    if is_removed:
        return typeof(base_property_value) in [TYPE_DICTIONARY, TYPE_ARRAY]
    return typeof(property_value) in [TYPE_DICTIONARY, TYPE_ARRAY]

func is_bool() -> bool:
    if is_removed:
        return typeof(base_property_value) == TYPE_BOOL
    return typeof(property_value) == TYPE_BOOL

func is_number() -> bool:
    if is_removed:
        return typeof(base_property_value) in [TYPE_INT, TYPE_FLOAT]
    return typeof(property_value) in [TYPE_INT, TYPE_FLOAT]

func is_string() -> bool:
    if is_removed:
        return typeof(base_property_value) == TYPE_STRING
    return typeof(property_value) == TYPE_STRING

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
    start_value_editting()

func make_removed() -> void:
    if not is_base_definition_property:
        push_error("Cannot make property removed: %s" % property_name)
        return
    if is_removed:
        return
    set_override_state(true, false, true, base_property_value)
    stop_value_editting()

func on_remove_button_pressed() -> void:
    stop_value_editting()
    request_remove.emit(property_name)

func on_override_button_pressed() -> void:
    stop_value_editting()
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

func set_control_icon(control: Control, icon_tex: Texture, tooltip_txt: String = "", mod_color: Color = Color.WHITE) -> void:
    control.modulate = mod_color
    control.tooltip_text = tooltip_txt
    if control is Button:
        control.icon = icon_tex
    elif control is TextureRect:
        control.texture = icon_tex
    elif control.has_method("set_icon"):
        control.set_icon(icon_tex)


func refresh_ui() -> void:
    name_edit.visible = not is_base_definition_property or enable_edit_base_props
    name_label.visible = not name_edit.visible
    if name_label.visible:
        name_label.text = get_rich_name_text()
    name_edit.text = property_name
    
    refresh_value_edit()
    
    if local_props_enabled and is_overridden or is_removed:
        var override_tooltip: String = "Local Property Override" + (" (Overridden as Removed)" if is_removed else "")
        set_control_icon(icon_1, local_prop_icon, override_tooltip)
    elif is_conditional():
        set_control_icon(icon_1, conditional_icon, "Conditional")
    else:
        set_control_icon(icon_1, no_icon)
    
    if is_event_name(property_name):
        set_control_icon(icon_2, event_icon, "Event", event_name_color)
    elif is_special_prop_name(property_name):
        set_control_icon(icon_2, special_prop_icon, "Special Property", special_prop_name_color)
    else:
        set_control_icon(icon_2, no_icon)
    
    override_button.visible = is_base_definition_property and local_props_enabled

    if is_base_definition_property and local_props_enabled:
        override_button.text = "restore" if is_overridden or is_removed else "override"
        remove_button.disabled = is_removed and not enable_edit_base_props
    elif is_base_definition_property and not enable_edit_base_props:
        remove_button.disabled = true
    else:
        remove_button.disabled = false

func refresh_value_edit() -> void:
    value_edit.set_value(base_property_value)

    _show_hide_edit_value_button()
    value_label.visible = not _value_editting
    if value_label.visible:
        value_label.text = get_rich_value_text()

func _show_hide_edit_value_button() -> void:
    edit_value_button.visible = false
    if not _value_editting:
        if is_overridden or (enable_edit_base_props and not is_removed):
            edit_value_button.visible = true

func start_value_editting() -> void:
    if not is_active():
        request_activate.emit(self)
    if _value_editting:
        return
    if is_removed or (not is_overridden and not enable_edit_base_props):
        if local_props_enabled:
            request_override.emit(property_name)
        return
    _value_editting = true
    value_label.hide()
    value_edit.show()
    value_edit.set_value(property_value)
    value_edit.try_grab_focus()
    _show_hide_edit_value_button()

func stop_value_editting() -> void:
    if not _value_editting:
        return
    _value_editting = false
    value_edit.hide()
    value_label.show()
    value_label.text = get_rich_value_text()
    _show_hide_edit_value_button()

func is_special_prop_name(prop_name: String) -> bool:
    return GameManager.is_special_prop_name(prop_name)

func is_event_name(prop_name: String) -> bool:
    return GameManager.is_event_name(prop_name)

func sub_item_gui_input(event: InputEvent, sub_item: Control) -> void:
    if sub_item == edit_value_button:
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
            start_value_editting()
            accept_event()
            return
    any_gui_input(event)

func _gui_input(event: InputEvent) -> void:
    any_gui_input(event)

func any_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.is_pressed():
        if not is_active():
            request_activate.emit(self)
            return
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.double_click:
                start_value_editting()
            else:
                stop_value_editting()

func sub_item_focus_entered(sub_item: Control) -> void:
    if sub_item and not (value_edit == sub_item or value_edit.is_ancestor_of(sub_item)):
        stop_value_editting()
    request_activate.emit(self)

func get_value_text() -> String:
    var use_value: Variant = base_property_value if not is_overridden else property_value
    if typeof(use_value) == TYPE_BOOL:
        return str(use_value).capitalize() + " " + ("👍" if use_value else "😔")
    elif typeof(use_value) == TYPE_STRING and use_value.contains("\n"):
        return use_value.split("\n", true, 1)[0] + " (...)"
    if use_value == null:
        return "--"
    return Utility.property_value_or_conditional_to_string(use_value)


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
            text_color = event_name_color.darkened(0.15)
        elif is_special_prop:
            text_color = special_prop_name_color.darkened(0.15)
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
        val_text = get_value_text()
        text_color = removed_text_color if is_removed else normal_text_color
        if is_bool():
            text_color = removed_bool_text_color if is_removed else boolean_text_color
        elif is_number():
            text_color = removed_number_text_color if is_removed else number_text_color

    if is_removed:
        val_text = "[s]%s[/s]" % val_text
    elif is_base_definition_property and not is_overridden:
        text_color.a = 0.75
    return _colored(val_text, text_color)