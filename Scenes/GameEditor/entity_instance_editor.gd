extends Control

signal entity_props_edited(entity: BaseEntity)
signal entity_local_props_reset(entity: BaseEntity)
signal edited_something()
signal closing()
signal request_delete_entity(entity: BaseEntity)

const ConditionalEditor = preload("res://src/GameEditor/ConditionalEditor/ConditionalEditor.gd")

const Vector2iInput = preload("res://src/GameEditor/ConditionalEditor/vector2i_input.gd")

const PropertyEditList = preload("res://Scenes/GameEditor/property_edit_list.gd")
const PropertyEditListItem = preload("res://Scenes/GameEditor/property_edit_list_item.gd")

const NewPropertyPanel = preload("res://Scenes/GameEditor/new_property_panel.gd")
const new_property_panel_scn: = preload("res://Scenes/GameEditor/new_property_panel.tscn")

var conditional_editor_scn: = preload("res://Scenes/GameEditor/ConditionalEditor/ConditionalEditor.tscn")

@export var auto_pick_entity: bool = true

@export var property_edit_list: PropertyEditList
@export var popup_holder: Control

@export var entity_active_toggle: CheckButton

@export var add_property_button: ButtonContainer

@export var reset_local_props_button: Button

@export var large_entity_options: Control
@export var entity_size_input: Vector2iInput

@export var delete_entity_button: Button

var non_expanded_v_size_flags: int = Control.SIZE_SHRINK_CENTER
var prop_list_default_min_size: Vector2 = Vector2.ZERO
var edited_entity: BaseEntity = null

var edit_entity_pulse_period: float = 1.15

var close_on_focus_lost: = true

var _popup_panels: Array[Node] = []

func _ready() -> void:
    large_entity_options.hide()
    entity_size_input.value_changed.connect(on_entity_size_input_changed)
    
    delete_entity_button.pressed.connect(on_delete_entity_button_pressed)

    reset_local_props_button.pressed.connect(on_reset_local_props_button_pressed)

    property_edit_list.request_conditional_editor.connect(on_conditional_editor_requested)
    get_viewport().gui_focus_changed.connect(on_gui_focus_changed)
    if entity_active_toggle:
        entity_active_toggle.toggled.connect(on_entity_active_toggled)
    visibility_changed.connect(on_visibility_changed)
    if size_flags_vertical != Control.SIZE_EXPAND_FILL:
        non_expanded_v_size_flags = size_flags_vertical
    if property_edit_list:
        prop_list_default_min_size = property_edit_list.custom_minimum_size
    property_edit_list.list_size_changed.connect(on_property_edit_list_size_changed)
    property_edit_list.request_new_property.connect(show_add_property_panel)
    property_edit_list.request_duplicate_property.connect(on_duplicate_property_requested)
    property_edit_list.entity_instance_props_edited.connect(on_entity_instance_props_edited)
    hide()

func find_auto_pick() -> void:
    if auto_pick_entity:
        var auto_picked_entity = EntityManager.find_entity_with_property("player")
        if auto_picked_entity:
            open_instance_editor(auto_picked_entity)

func _process(_delta: float) -> void:
    if visible and edited_entity:
        var pulse_amt: = sin((Time.get_ticks_msec() / 1000.0) / edit_entity_pulse_period * TAU)
        edited_entity.modulate = Color.WHITE * (1 + (pulse_amt * 0.2 + 0.1))

func _shortcut_input(event: InputEvent) -> void:
    if GameManager.get_pause("pause_menu"):
        return
    if visible and Utility.event_is_menu_back_just_pressed(event):
        close_instance_editor()
        get_viewport().set_input_as_handled()

func on_reset_local_props_button_pressed() -> void:
    if not visible or not edited_entity:
        return
    edited_entity.reset_all_local_properties()
    property_edit_list.load_entity_instance_properties(edited_entity)
    entity_local_props_reset.emit(edited_entity)

func on_entity_instance_props_edited(entity: BaseEntity) -> void:
    edited_something.emit()
    entity_props_edited.emit(entity)

func open_instance_editor(entity: BaseEntity) -> void:
    if not entity:
        return
    unedit_entity()
    show()
    edited_entity = entity
    large_entity_options.visible = entity is LargeEntity
    if entity is LargeEntity:
        entity_size_input.set_value(Vector2i(entity.entity_size))

    if entity_active_toggle:
        entity_active_toggle.set_pressed_no_signal(entity.active)
    var title_label: = find_child("TitleLabel") as Label
    if title_label:
        var entity_name: = EntityManager.get_entity_name(entity.entity_index)
        title_label.text = "Edit %s Instance" % entity_name
    if property_edit_list:
        property_edit_list.load_entity_instance_properties(entity)
    get_gui_focus.call_deferred()

func get_gui_focus() -> void:
    var focus_owner = get_viewport().gui_get_focus_owner()
    if focus_owner and (focus_owner == self or is_ancestor_of(focus_owner)):
        return
    var to_focus: Control = _first_element_to_focus()
    if to_focus and to_focus.get_focus_mode_with_override() != Control.FOCUS_NONE:
        to_focus.grab_focus()
        if to_focus is LineEdit:
            to_focus.unedit.call_deferred()
    else:
        prints("focus node %s is unable to grab focus" % to_focus.get_path())

func _first_element_to_focus() -> Control:
    var all_list_items: = property_edit_list.get_all_list_items()
    if all_list_items.size() > 0:
        return all_list_items[0]
    return add_property_button.button

func unedit_entity() -> void:
    if edited_entity:
        edited_entity.modulate = Color.WHITE

func close_instance_editor() -> void:
    unedit_entity()
    hide()

func on_property_edit_list_size_changed() -> void:
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    await get_tree().process_frame
    #var current_max_height: float = size.y
    var max_list_height: float = property_edit_list.size.y

    var prop_list_expanded_height: = property_edit_list.get_minimum_list_height()
    if prop_list_expanded_height <= max_list_height:
        size_flags_vertical = non_expanded_v_size_flags
        property_edit_list.custom_minimum_size.y = prop_list_expanded_height
    else:
        property_edit_list.custom_minimum_size = prop_list_default_min_size

func _on_add_property_button_pressed() -> void:
    show_add_property_panel()

func on_duplicate_property_requested(property_name: String) -> void:
    show_add_property_panel(property_name)

func show_add_property_panel(duplicate_prop_name: String = "") -> void:
    _close_panel_popups()
    if not popup_holder:
        push_error("popup_holder not set")
        return
    var new_property_panel: NewPropertyPanel = new_property_panel_scn.instantiate()
    if duplicate_prop_name:
        new_property_panel.prefill_prop_name = duplicate_prop_name
        new_property_panel.name_chosen.connect(on_duplicate_property_name_chosen.bind(duplicate_prop_name))
        new_property_panel.set_title_text("Duplicate '%s'" % duplicate_prop_name)
    else:
        new_property_panel.name_chosen.connect(on_new_property_name_chosen)
    new_property_panel.cancelled.connect(get_add_prop_input_focus)
    _popup_panels.append(new_property_panel)
    popup_holder.add_child(new_property_panel)

func get_add_prop_input_focus() -> void:
    add_property_button.button.grab_focus.call_deferred()

func _close_panel_popups() -> void:
    for panel in _popup_panels:
        if panel and panel.has_method("close_panel"):
            panel.close_panel()
    _popup_panels.clear()

func on_new_property_name_chosen(property_name: String, as_conditional: bool) -> void:
    if property_edit_list:
        property_edit_list.add_new_or_duplicate_property(property_name, as_conditional)

func on_duplicate_property_name_chosen(property_name: String, as_conditional: bool, duplicate_of: String) -> void:
    if property_edit_list:
        property_edit_list.add_new_or_duplicate_property(property_name, as_conditional, duplicate_of)

func on_visibility_changed() -> void:
    if not visible:
        closing.emit()

func on_entity_active_toggled(active: bool) -> void:
    if edited_entity:
        edited_entity.set_active(active)
    edited_something.emit()

func on_gui_focus_changed(to_focus_owner: Control) -> void:
    if not visible or not is_visible_in_tree():
        return

    if close_on_focus_lost:
        if to_focus_owner != self and not is_ancestor_of(to_focus_owner):
            close_instance_editor()

func on_conditional_editor_requested(property_name: String, current_value: Variant, editable: bool) -> void:
    show_conditional_editor(property_name, current_value, editable)

func show_conditional_editor(property_name: String, current_value: Variant, editable: bool) -> void:
    if typeof(current_value) not in [TYPE_DICTIONARY, TYPE_ARRAY]:
        push_error("requesting to open conditional editor but value is not a dict or array: %s" % [current_value])
        return
    var new_conditional_editor: = conditional_editor_scn.instantiate() as ConditionalEditor
    new_conditional_editor.editable = editable
    new_conditional_editor.event_name = property_name
    new_conditional_editor.has_me_entity_slot = true
    new_conditional_editor.has_them_entity_slot = property_name not in ConditionalsV3.NO_OTHER_EVENTS
    if not current_value:
        current_value = ConditionalsV3.EMPTY_CONDITIONAL
    add_child(new_conditional_editor)
    new_conditional_editor.load_conditional_data(current_value)
    new_conditional_editor.save_conditional.connect(on_save_conditional_prop.bind(property_name))
    new_conditional_editor.transient = true

    new_conditional_editor.popup_centered()

func on_save_conditional_prop(new_conditional_value: Variant, prop_name: String) -> void:
    property_edit_list.set_prop_conditional_value(prop_name, new_conditional_value)

func on_entity_size_input_changed(new_size: Vector2i) -> void:
    if not edited_entity or not edited_entity is LargeEntity:
        return
    new_size = new_size.maxi(1)
    entity_size_input.set_value(new_size)
    edited_entity.update_size(new_size)
    edited_something.emit()

func on_delete_entity_button_pressed() -> void:
    if edited_entity:
        request_delete_entity.emit(edited_entity)
    close_instance_editor()