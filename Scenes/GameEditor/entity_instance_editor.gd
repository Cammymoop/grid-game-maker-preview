extends Control

signal entity_props_edited(entity: BaseEntity)
signal closing()
signal cancel_popups()

const PropertyEditList = preload("res://Scenes/GameEditor/property_edit_list.gd")

const NewPropertyPanel = preload("res://Scenes/GameEditor/new_property_panel.gd")
const new_property_panel_scn: = preload("res://Scenes/GameEditor/new_property_panel.tscn")

@export var auto_pick_entity: bool = true

@export var property_edit_list: PropertyEditList
@export var popup_holder: Control

var non_expanded_v_size_flags: int = Control.SIZE_SHRINK_CENTER
var prop_list_default_min_size: Vector2 = Vector2.ZERO
var edited_entity: BaseEntity = null

var edit_entity_pulse_period: float = 1.15

func _ready() -> void:
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
    if visible and Utility.fixed_just_pressed_by_event("escape", event):
        close_instance_editor()
        get_viewport().set_input_as_handled()

func on_entity_instance_props_edited(entity: BaseEntity) -> void:
    entity_props_edited.emit(entity)

func open_instance_editor(entity: BaseEntity) -> void:
    if not entity:
        return
    unedit_entity()
    show()
    edited_entity = entity
    var title_label: = find_child("TitleLabel") as Label
    if title_label:
        var entity_name: = EntityManager.get_entity_name(entity.entity_index)
        title_label.text = "Edit %s Instance" % entity_name
    if property_edit_list:
        property_edit_list.load_entity_instance_properties(entity)

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
    cancel_popups.emit()
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
    cancel_popups.connect(new_property_panel.close_panel)
    popup_holder.add_child(new_property_panel)

func on_new_property_name_chosen(property_name: String, alt_mode: bool) -> void:
    if property_edit_list:
        property_edit_list.add_new_or_duplicate_property(property_name, alt_mode)

func on_duplicate_property_name_chosen(property_name: String, alt_mode: bool, duplicate_of: String) -> void:
    if property_edit_list:
        property_edit_list.add_new_or_duplicate_property(property_name, alt_mode, duplicate_of)

func on_visibility_changed() -> void:
    if not visible:
        closing.emit()