extends PanelContainer

signal list_size_changed()

signal properties_changed()

signal entity_instance_props_edited(entity: BaseEntity)

signal request_conditional_editor(property_name: String, current_value: Variant, editable: bool)
signal request_new_property()
signal request_duplicate_property(property_name: String)

const ListItem = preload("res://Scenes/GameEditor/property_edit_list_item.gd")
const list_item_scn: PackedScene = preload("res://Scenes/GameEditor/property_edit_list_item.tscn")


@export var list_item_parent: Control
@export var scroll_container: ScrollContainer

@export var enable_local_props: bool = false
@export var edit_base_props_on_instance: bool = false

@export var is_entity: bool = true
@export var auto_update_entity_instance: bool = true

var enable_edit_base_props: bool = true

var editing_def_index: int = -1
var editing_entity: BaseEntity = null

var list_items_start_at_index: int = 0

var properties_info: Dictionary[int, Dictionary] = {}
const blank_property_info: Dictionary[String, Variant] = {
    "property_name": "",
    "is_base_definition_property": true,
    "is_overridden": false,
    "is_removed": false,
    "is_conditional": false,
    "value": true,
    "list_item": null,
}

var index_map: Dictionary[String, int] = {}

const _default_sorting_info: Dictionary = {
    "sort_by": "property_name",
    "main_sort_order": "ascending",
    "sort_conditional_local": -1,
    "sort_event_special": 2,
}
@export var sorting_info: Dictionary = {}

const CTX_DUPLICATE_PROPERTY = 4

const CTX_COPY_PROPERTY = 10
const CTX_COPY_ALL_PROPERTIES = 11
const CTX_COPY_ALL_OVERRIDES = 12

const CTX_PASTE_PROPERTIES_OVERWRITE = 20
const CTX_PASTE_PROPERTIES_NO_OVERWRITE = 21

const CTX_PASTE_LOCAL_PROPERTIES = 22
const CTX_PASTE_LOCAL_PROP_NO_OVERWRITE = 23

const CTX_PASTE_PROPERTY_VALUE = 28
const CTX_PASTE_LOCAL_PROP_VALUE = 29

const CTX_DELETE_PROPERTY = 40
const CTX_REMOVE_LOCAL_PROP = 41
const CTX_RESET_LOCAL_PROP = 42

const CONFLICTED_NAME: String = "NAME_CONFLICT_"
var conflicting_property_name: String = ""

var _next_index: int = 0

func _init() -> void:
    sorting_info.merge(_default_sorting_info)
    pass#reset_sorting_info()

func clear() -> void:
    _clear_list_items()
    properties_info.clear()
    index_map.clear()
    _next_index = 0
    list_size_changed.emit()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
        show_context_menu(null)
        accept_event()

func apply_edits_to_definition(to_definition_index: int = -1) -> void:
    if to_definition_index == -1:
        to_definition_index = editing_def_index
    if to_definition_index < 0:
        push_error("Cannot apply edits to definition: no valid definition index provided")
    var base_properties: Dictionary = get_base_properties_dict()
    if base_properties:
        if is_entity:
            EntityManager.entity_defs[to_definition_index]["properties"] = get_base_properties_dict()
        else:
            MapManager.tile_defs[to_definition_index]["properties"] = get_base_properties_dict()

func get_base_properties_dict() -> Dictionary:
    var base_properties: Dictionary = {}
    for i in properties_info.keys():
        var info: Dictionary[String, Variant] = properties_info[i]
        if info["property_name"] == "" or info["property_name"] == CONFLICTED_NAME:
            continue
        if info["is_base_definition_property"]:
            if info["is_overridden"]:
                push_error("trying to get base properties dict but one or more base properties are currently overridden")
                return {}
            base_properties[info["property_name"]] = info["value"]
    return base_properties

func get_properties_overridden_dict(overrides_only: bool) -> Dictionary:
    var overridden_props: Dictionary = {}
    for i in properties_info.keys():
        var info: Dictionary[String, Variant] = properties_info[i]
        if info["property_name"] == "" or info["property_name"] == CONFLICTED_NAME:
            continue
        if info["is_removed"]:
            if overrides_only:
                overridden_props[info["property_name"]] = "--REMOVED--"
            continue
        if overrides_only and not info["is_overridden"]:
            continue
        overridden_props[info["property_name"]] = info["value"]
    return overridden_props

func apply_properties_to_entity(clear_other_local_props: bool, to_entity: BaseEntity = null) -> void:
    if not to_entity:
        to_entity = editing_entity
    if not to_entity:
        push_error("Cannot apply properties to entity: no entity provided")
        return
    if not enable_local_props:
        push_error("Cannot apply properties to entity: local props are not enabled")
        return
    var prop_names: Array[String] = []
    for i in properties_info.keys():
        var info: Dictionary[String, Variant] = properties_info[i]
        prop_names.append(info["property_name"])
        if info["is_removed"]:
            to_entity._remove_local_property(info["property_name"])
        elif info["is_overridden"]:
            to_entity._set_local_property(info["property_name"], info["value"])
        elif info["is_base_definition_property"]:
            to_entity._reset_local_property(info["property_name"])

    if clear_other_local_props:
        for local_prop_name in to_entity.local_properties:
            if not local_prop_name in prop_names:
                to_entity._reset_local_property(local_prop_name)
        for removed_prop_name in to_entity.removed_properties:
            if not removed_prop_name in prop_names:
                to_entity._reset_local_property(removed_prop_name)
    to_entity._local_prop_changed()
    entity_instance_props_edited.emit(to_entity)

func apply_edited_instance_property_update(for_property_name: String) -> void:
    if not for_property_name or not editing_entity:
        return
    var p_index: int = index_map.get(for_property_name, -1)
    if p_index == -1:
        # property was removed from the list entirely, reset the local prop if it was set
        editing_entity.reset_local_property(for_property_name)
        entity_instance_props_edited.emit(editing_entity)
        return

    var info: Dictionary[String, Variant] = properties_info[p_index]
    if info["is_removed"]:
        editing_entity.remove_local_property(for_property_name)
    elif info["is_overridden"]:
        editing_entity.set_local_property(for_property_name, info["value"])
    else:
        editing_entity.reset_local_property(for_property_name)
    entity_instance_props_edited.emit(editing_entity)


func reset_sorting_info() -> void:
    sorting_info = _default_sorting_info.duplicate()

func load_entity_definition_properties(the_definition: Dictionary, the_entity_index: int) -> void:
    load_item_definition_properties(the_definition, the_entity_index, true)

func load_item_definition_properties(the_definition: Dictionary, the_definition_index: int, is_def_entity: bool = false) -> void:
    is_entity = is_def_entity
    enable_local_props = false
    enable_edit_base_props = true
    if properties_info.size() > 0:
        clear()
    editing_def_index = the_definition_index
    editing_entity = null
    _load_def_props(the_definition)
    create_list_items()

func _load_def_props(the_definition: Dictionary) -> void:
    for prop_name in the_definition["properties"]:
        var info: Dictionary[String, Variant] = blank_property_info.duplicate()
        var index: = _next_index
        properties_info[index] = info
        _next_index += 1
        
        info["property_name"] = prop_name
        info["is_base_definition_property"] = true
        info["value"] = the_definition["properties"][prop_name]
        info["is_conditional"] = is_conditional(info["value"])
        index_map[prop_name] = index

func get_base_definition() -> Dictionary:
    if is_entity:
        return EntityManager.get_entity_definition(editing_def_index)
    else:
        return MapManager.get_tile_definition(editing_def_index)

func load_entity_instance_properties(the_entity: BaseEntity) -> void:
    is_entity = true
    enable_local_props = true
    enable_edit_base_props = edit_base_props_on_instance
    if sorting_info == _default_sorting_info:
        sorting_info["sort_event_special"] = -1 
        sorting_info["sort_conditional_local"] = 2
    if properties_info.size() > 0:
        clear()
    editing_entity = the_entity
    is_entity = true
    editing_def_index = the_entity.entity_index
    var the_definition: Dictionary = get_base_definition()
    _load_def_props(the_definition)
    
    for prop_name in the_entity.local_properties:
        var p_index: int = index_map.get(prop_name, -1)
        var info: Dictionary[String, Variant]
        if p_index != -1:
            info = properties_info[p_index]
        else:
            info = blank_property_info.duplicate()
            p_index = _next_index
            properties_info[p_index] = info
            _next_index += 1
            index_map[prop_name] = p_index
            info["property_name"] = prop_name
            info["is_base_definition_property"] = false

        info["is_overridden"] = true
        info["value"] = the_entity.get_local_property(prop_name)
        info["is_conditional"] = is_conditional(info["value"])
        info["is_removed"] = false
    
    for removed_prop_name in the_entity.removed_properties:
        var p_index: int = index_map.get(removed_prop_name, -1)
        if p_index == -1:
            push_error("Removed property not found in existing properties: %s" % removed_prop_name)
            continue
        var info: Dictionary[String, Variant] = properties_info[p_index]
        info["is_removed"] = true
        if info["is_overridden"]:
            push_warning("Property '%s' was set as both overridden and removed" % removed_prop_name)
            if not info["is_base_definition_property"]:
                push_error("Removed property not found in entity definition: %s" % removed_prop_name)
                info["is_removed"] = false
            else:
                info["value"] = the_definition["properties"][removed_prop_name]
                info["is_conditional"] = is_conditional(info["value"])
                info["is_overridden"] = false
    create_list_items()


func create_list_items() -> void:
    _clear_list_items()
    
    if conflicting_property_name:
        push_warning("Rebuilding list while conflicting property name is set: %s" % conflicting_property_name)
    
    var sorted_indices: = get_sorted_property_indices()
    for prop_index in sorted_indices:
        _add_list_item_for(prop_index)
    on_prop_name_width_changed()
    resort_list_items()
    list_size_changed.emit()

func _add_list_item_for(prop_index: int) -> void:
    var list_item: ListItem = list_item_scn.instantiate()
    _setup_list_item(list_item, prop_index)
    list_item_parent.add_child(list_item)

func resort_list_items() -> void:
    var sorted_indices: = get_sorted_property_indices()
    var to_index: int = list_items_start_at_index
    for prop_index in sorted_indices:
        var list_item: ListItem = properties_info[prop_index]["list_item"]
        if list_item.get_index() != to_index:
            list_item_parent.move_child(list_item, to_index)
        to_index += 1
    refresh_items_up_down_focus_neighbors()

func refresh_items_up_down_focus_neighbors() -> void:
    var all_list_items: Array[ListItem] = get_all_list_items()
    for i in all_list_items.size():
        var prev_item: ListItem = null
        var next_item: ListItem = null
        if i > 0:
            prev_item = all_list_items[i - 1]
        if i < all_list_items.size() - 1:
            next_item = all_list_items[i + 1]
        all_list_items[i].update_external_focus_neighbors(prev_item, next_item)

func _setup_list_item(list_item: ListItem, prop_index: int) -> void:
    properties_info[prop_index]["list_item"] = list_item
    list_item.local_props_enabled = enable_local_props
    list_item.enable_edit_base_props = enable_edit_base_props

    list_item.property_name = properties_info[prop_index]["property_name"]
    list_item.property_value = properties_info[prop_index]["value"]
    list_item.is_base_definition_property = properties_info[prop_index]["is_base_definition_property"]
    list_item.is_overridden = properties_info[prop_index]["is_overridden"]
    list_item.is_removed = properties_info[prop_index]["is_removed"]
    
    _setup_list_item_signals(list_item)

func _setup_list_item_signals(list_item: ListItem) -> void:
    list_item.request_remove.connect(on_prop_remove_requested)
    list_item.request_override.connect(on_prop_override_requested)
    list_item.request_restore.connect(restore_prop_name)
    
    list_item.property_name_changed.connect(on_property_name_changed)
    list_item.property_value_changed.connect(on_property_value_edited)
    list_item.property_name_change_finalized.connect(on_property_name_change_finalized)
    #list_item.request_convert_conditional.connect(convert_prop_is_conditional)
    list_item.request_conditional_editor.connect(on_conditional_editor_requested.bind(list_item))
    
    list_item.request_context_menu.connect(show_context_menu)
    
    list_item.request_activate.connect(set_active_list_item)

func on_conditional_editor_requested(prop_name: String, list_item: ListItem) -> void:
    var is_base_prop: bool = not list_item.is_overridden and not list_item.is_removed
    request_conditional_editor.emit(prop_name, list_item.property_value, enable_edit_base_props or not is_base_prop)

func convert_prop_is_conditional(prop_name: String, set_is_conditional: bool) -> void:
    var p_index: int = index_map.get(prop_name, -1)
    if p_index == -1:
        push_error("Property to convert conditional not found in list: %s" % prop_name)
        return
    var info: Dictionary[String, Variant] = properties_info[p_index]
    if info["is_conditional"] == set_is_conditional:
        push_warning("Property %s is already%s conditional" % [prop_name, "" if set_is_conditional else " not"])
        return
    if set_is_conditional:
        info["value"] = true
    else:
        info["value"] = [{}]
    info["is_conditional"] = set_is_conditional
    if info["list_item"]:
        properties_info[p_index]["list_item"].set_prop_value(info["value"])
    prop_changed(prop_name)
    resort_list_items()
    properties_changed.emit()

func set_prop_name_override_value(prop_name: String, new_value: Variant) -> void:
    var p_index: int = index_map.get(prop_name, -1)
    if not prop_name or p_index == -1:
        push_error("Cannot set property override value: %s, not found in list" % prop_name)
        return
    set_prop_index_overridden(p_index)
    change_prop_current_value(prop_name, new_value)

func set_prop_base_value_only(prop_name: String, new_base_value: Variant) -> void:
    var p_index: int = index_map.get(prop_name, -1)
    if not prop_name or p_index == -1:
        push_error("Cannot set property base value only: %s, not found in list" % prop_name)
        return
    var info: Dictionary[String, Variant] = properties_info[p_index]
    if not info["is_base_definition_property"]:
        push_error("Cannot set property base value only: %s, not a base definition property" % prop_name)
        return

    if info["is_overriden"]:
        var overriden_value: Variant = info["value"]
        restore_prop_name(prop_name)
        change_prop_current_value(prop_name, new_base_value)
        set_prop_name_override_value(prop_name, overriden_value)
    elif info["is_removed"]:
        restore_prop_name(prop_name)
        change_prop_current_value(prop_name, new_base_value)
        make_prop_removed(prop_name)
    else:
        change_prop_current_value(prop_name, new_base_value)


func change_prop_current_value(prop_name: String, new_value: Variant) -> void:
    var p_index: int = index_map.get(prop_name, -1)
    if not prop_name or p_index == -1:
        push_error("Cannot change property current value: %s, not found in list" % prop_name)
        return
    var info: Dictionary[String, Variant] = properties_info[p_index]
    info["value"] = new_value
    if info["list_item"]:
        info["list_item"].set_prop_value(new_value)
    prop_changed(prop_name)
    resort_list_items()
    properties_changed.emit()

func on_property_value_edited(prop_name: String, new_value: Variant) -> void:
    var p_index: int = index_map.get(prop_name, -1)
    if p_index == -1:
        push_error("Property value changed but not found in list: %s" % prop_name)
        return
    properties_info[p_index]["value"] = new_value
    prop_changed(prop_name)
    resort_list_items()
    properties_changed.emit()

func is_instance_update() -> bool:
    return is_entity and auto_update_entity_instance and editing_entity

func prop_changed(prop_name: String) -> void:
    if is_instance_update():
        apply_edited_instance_property_update(prop_name)

func all_props_changed() -> void:
    if is_instance_update():
        apply_properties_to_entity(true)

func on_property_name_changed(_old_name: String, _new_name: String) -> void:
    on_prop_name_width_changed()
    return

func _rename_prop_from_item(old_name: String, new_name: String) -> void:
    if not old_name:
        push_error("Old name is empty")
        return
    if not new_name or old_name == new_name:
        return

    if old_name == conflicting_property_name:
        old_name = CONFLICTED_NAME
    var p_index: int = index_map.get(old_name, -1)
    if p_index == -1:
        push_error("Property not found in index map: %s" % old_name)
        return
    elif not enable_edit_base_props and properties_info[p_index]["is_base_definition_property"]:
        push_error("Cannot edit base definition property name: %s" % old_name)
        return

    var rename_to: = new_name
    if index_map.has(new_name):
        if old_name != CONFLICTED_NAME and conflicting_property_name and conflicting_property_name != new_name:
            push_error("Multiple property name conflicts at once. %s -- %s" % [conflicting_property_name, new_name])
            return
        else:
            conflicting_property_name = new_name
            rename_to = CONFLICTED_NAME

    index_map.erase(old_name)
    index_map[rename_to] = p_index
    properties_info[p_index]["property_name"] = rename_to
    resort_list_items()
    on_prop_name_width_changed()
    properties_changed.emit()

func on_property_name_change_finalized(old_prop_name: String, new_prop_name: String) -> void:
    _rename_prop_from_item(old_prop_name, new_prop_name)
    all_props_changed()

func resolve_name_conflict_as_overwrite() -> void:
    var conflicting_index: int = index_map.get(CONFLICTED_NAME, -1)
    var existing_index: int = index_map.get(conflicting_property_name, -1)
    if not conflicting_index or not existing_index:
        return
    if not enable_edit_base_props and properties_info[existing_index]["is_base_definition_property"]:
        if properties_info[conflicting_index]["is_base_definition_property"]:
            push_error("Cannot edit base definition property name: %s" % conflicting_property_name)
        else:
            push_warning("Cannot overwrite base property, removing conflicting prop instead: %s" % conflicting_property_name)
            remove_prop_index(conflicting_index)
        return
    remove_prop_index(existing_index)
    index_map.erase(CONFLICTED_NAME)
    index_map[conflicting_property_name] = conflicting_index
    properties_info[conflicting_index]["property_name"] = conflicting_property_name
    conflicting_property_name = ""
    all_props_changed()
    list_size_changed.emit()
    resort_list_items()
    properties_changed.emit()

func remove_conflicting_property() -> void:
    var conflicting_index: int = index_map.get(CONFLICTED_NAME, -1)
    if conflicting_index == -1 or not conflicting_property_name:
        push_error("No conflicting property to remove")
        return
    remove_prop_index(conflicting_index)
    conflicting_property_name = ""
    all_props_changed()
    list_size_changed.emit()
    properties_changed.emit()
    resort_list_items()

func remove_prop_index(index: int) -> void:
    var info: Dictionary[String, Variant] = properties_info[index]
    if not info["list_item"]:
        push_warning("Removing property from info when no list item is set: %s" % info["property_name"])
    list_item_parent.remove_child(info["list_item"])
    info["list_item"].queue_free()
    index_map.erase(info["property_name"])
    properties_info.erase(index)

func remove_prop_name(prop_name: String) -> void:
    if not prop_name:
        push_error("Remove property by name: prop_name is empty")
        return
    var index: int = index_map.get(prop_name, -1)
    if index == -1:
        push_error("Property to remove not found in list: %s" % prop_name)
    elif prop_name == conflicting_property_name:
        push_error("Ambiguous remove property by name because of existing conflict: %s" % prop_name)
    else:
        remove_prop_index(index)
    list_size_changed.emit()
    properties_changed.emit()

func on_prop_remove_requested(prop_name: String) -> void:
    if prop_name and prop_name == conflicting_property_name:
        push_error("Ambiguous set remove property by name because of existing conflict: %s" % prop_name)
        return
    if not enable_local_props:
        if not enable_edit_base_props:
            push_error("Cannot remove properties because base property editing is disabled")
            return
        remove_prop_name(prop_name)
        return
    
    var p_index: int = index_map.get(prop_name, -1)
    if p_index == -1:
        push_error("Property to remove not found in list: %s" % prop_name)
        return

    if properties_info[p_index]["is_removed"]:
        if not enable_edit_base_props:
            push_error("Cannot remove base property: %s, editing base properties is disabled" % prop_name)
        else:
            remove_prop_index(p_index)
    elif not properties_info[p_index]["is_base_definition_property"]:
        remove_prop_index(p_index)
    else:
        set_prop_index_removed(p_index)
    prop_changed(prop_name)
    resort_list_items()
    properties_changed.emit()

func make_prop_removed(prop_name: String) -> void:
    if not editing_entity or not enable_local_props:
        push_error("Cannot make property removed: %s, not editing an entity or local props are disabled" % prop_name)
        return
    var p_index: int = index_map.get(prop_name, -1)
    if p_index == -1:
        push_error("Property to remove not found in list: %s" % prop_name)
        return
    var info: Dictionary[String, Variant] = properties_info[p_index]
    if not info["is_base_definition_property"]:
        push_error("Cannot set removed property: %s, not a base definition property" % info["property_name"])
        return
    set_prop_index_removed(p_index)
    prop_changed(prop_name)
    resort_list_items()
    properties_changed.emit()

func set_prop_index_removed(index: int) -> void:
    var info: Dictionary[String, Variant] = properties_info[index]
    if not info["is_base_definition_property"]:
        push_error("Cannot set removed property: %s, not a base definition property" % info["property_name"])
        return
    var prop_name: String = info["property_name"]
    if info["is_overridden"]:
        info["is_overridden"] = false
        info["value"] = EntityManager.get_entity_definition(editing_def_index)["properties"][prop_name]
    properties_info[index]["is_removed"] = true
    if info["list_item"]:
        properties_info[index]["list_item"].make_removed()

func restore_prop_name(prop_name: String) -> void:
    var p_index: int = index_map.get(prop_name, -1)
    if not prop_name or p_index == -1:
        push_error("Property to restore not found in list: %s" % prop_name)
        return
    if prop_name == conflicting_property_name:
        push_error("Ambiguous restore property by name because of existing conflict: %s" % prop_name)
        return
    var info: Dictionary[String, Variant] = properties_info[p_index]
    if not info["is_base_definition_property"]:
        push_error("Cannot restore property: %s, not a base definition property" % prop_name)
        return
    info["is_removed"] = false
    if info["is_overridden"]:
        info["value"] = EntityManager.get_entity_definition(editing_def_index)["properties"][prop_name]
        info["is_overridden"] = false
    if info["list_item"]:
        properties_info[p_index]["list_item"].set_override_state(true, false, false, info["value"])
    prop_changed(prop_name)
    resort_list_items()
    properties_changed.emit()

func on_prop_override_requested(prop_name: String) -> void:
    if not enable_local_props:
        push_error("Cannot override properties because only editing definition properties")
        return
    var p_index: int = index_map.get(prop_name, -1)
    if p_index == -1:
        push_error("Property to override not found in list: %s" % prop_name)
        return
    elif prop_name and prop_name == conflicting_property_name:
        push_error("Ambiguous set override property by name because of existing conflict: %s" % prop_name)
        return
    set_prop_index_overridden(p_index)
    resort_list_items()

func set_prop_index_overridden(index: int) -> void:
    var info: Dictionary[String, Variant] = properties_info[index]
    if info["is_overridden"]:
        return
    info["is_removed"] = false
    info["is_overridden"] = true
    if info["list_item"]:
        properties_info[index]["list_item"].make_overridden()
    prop_changed(info["property_name"])

func _clear_list_items() -> void:
    for list_item in get_all_list_items():
        list_item_parent.remove_child(list_item)
        list_item.queue_free()
    for index in properties_info:
        properties_info[index]["list_item"] = null

func get_sorted_property_indices() -> Array[int]:
    var prop_indices: Array[int] = []
    prop_indices.assign(properties_info.keys())
    prop_indices.sort_custom(prop_index_sort_func)
    return prop_indices


func get_sort_value(prop_info: Dictionary[String, Variant]) -> String:
    if sorting_info["sort_by"] == "property_name":
        return prop_info["property_name"]
    elif sorting_info["sort_by"] == "value":
        if prop_info["is_conditional"]:
            return str(prop_info["value"]).substr(0, 100)
        else:
            return str(prop_info["value"])
    else:
        push_error("Invalid sort by: %s" % sorting_info["sort_by"])
        return ""

func is_event(info: Dictionary[String, Variant]) -> bool:
    return GameManager.is_event_name(info["property_name"])

func is_spec(info: Dictionary[String, Variant]) -> bool:
    return GameManager.is_special_prop_name(info["property_name"])

func is_conditional(prop_value: Variant) -> bool:
    return typeof(prop_value) in [TYPE_DICTIONARY, TYPE_ARRAY]

func is_local(info: Dictionary[String, Variant]) -> bool:
    return info["is_overridden"] or info["is_removed"]

func increment_sort_category(is_event_special: bool) -> void:
    if is_event_special:
        sorting_info["sort_conditional_local"] = -1
        sorting_info["sort_event_special"] = wrapi(sorting_info["sort_event_special"] - 1, -1, 3)
    else:
        sorting_info["sort_event_special"] = -1
        sorting_info["sort_conditional_local"] = wrapi(sorting_info["sort_conditional_local"] - 1, -1, 3)
        

func compare_prop_info(a: Dictionary[String, Variant], b: Dictionary[String, Variant]) -> bool:
    var category_sort: = func (a_v: int, b_v: int, preferred: int) -> bool:
        if preferred == 1:
            return a_v == 1 or b_v == 0
        return a_v > b_v if preferred == 2 else a_v < b_v

    if sorting_info["sort_event_special"] != -1:
        var a_v: int = 2 if is_event(a) else (1 if is_spec(a) else 0)
        var b_v: int = 2 if is_event(b) else (1 if is_spec(b) else 0)
        if a_v != b_v:
            return category_sort.call(a_v, b_v, sorting_info["sort_event_special"])
    elif sorting_info["sort_conditional_local"] != -1:
        var a_v: int = 2 if is_local(a) else (1 if a["is_conditional"] else 0)
        var b_v: int = 2 if is_local(b) else (1 if b["is_conditional"] else 0)
        if a_v != b_v:
            return  category_sort.call(a_v, b_v, sorting_info["sort_conditional_local"])

    var order: int = get_sort_value(a).nocasecmp_to(get_sort_value(b))
    if sorting_info["main_sort_order"] == "ascending":
        return order < 0
    else:
        return order > 0

func prop_index_sort_func(a: int, b: int) -> bool:
    return compare_prop_info(properties_info[a], properties_info[b])


func get_all_list_items() -> Array[ListItem]:
    var list_items: Array[ListItem] = []
    for i in list_item_parent.get_child_count():
        if i < list_items_start_at_index:
            continue
        var list_item: Node = list_item_parent.get_child(i)
        if not list_item is ListItem:
            push_error("List item at index %d is not a ListItem" % [i])
            list_items.append(null)
        else:
            list_items.append(list_item)
    return list_items

func get_list_item_count() -> int:
    return get_all_list_items().size()

func on_prop_name_width_changed() -> void:
    var list_items: = get_all_list_items()
    var max_name_width: float = _get_max_property_name_width(list_items)
    
    for list_item: ListItem in list_items:
        list_item.set_name_section_fixed_width(max_name_width)

func _get_max_property_name_width(list_items: Array) -> float:
    var max_name_width: float = 0.0
    for list_item: ListItem in list_items:
        max_name_width = maxf(max_name_width, list_item.get_name_section_width())
    return max_name_width


func find_active_list_item() -> ListItem:
    for list_item: ListItem in get_all_list_items():
        if list_item.is_active():
            return list_item
    return null

func set_active_list_item(new_active_list_item: ListItem) -> void:
    for list_item: ListItem in get_all_list_items():
        list_item.set_active(list_item == new_active_list_item)
    active_list_item_changed(new_active_list_item)

func navigate_list_item_relative(amount: int) -> void:
    var active_list_item: ListItem = find_active_list_item()
    if not active_list_item:
        return
    var total_items: int = list_item_parent.get_child_count()
    var cur_index: int = active_list_item.get_index()
    var new_index: int = clampi(cur_index + amount, list_items_start_at_index, total_items - 1)
    var new_list_item: ListItem = list_item_parent.get_child(new_index) as ListItem
    if not new_list_item:
        push_error("List item at index %d is not a ListItem: %s" % [new_index, new_list_item])
        return
    set_active_list_item(new_list_item)


func active_list_item_changed(new_active_list_item: ListItem) -> void:
    if not scroll_container:
        push_error("Scroll container not set")
        return
    await get_tree().process_frame
    scroll_container.ensure_control_visible(new_active_list_item)
    

func get_minimum_list_height() -> float:
    if not scroll_container:
        push_error("Scroll container not set")
        return 100
    # minimum list height is the minimum height of the list inside the scroll container plus however much margin the base list panel adds
    var self_margin_height: float = get_minimum_size().y - scroll_container.get_minimum_size().y
    return self_margin_height + scroll_container.get_child(0).get_minimum_size().y

func _add_new_property(property_name: String, as_conditional: bool, include_value: bool = false, value: Variant = null, as_overridden: bool = false) -> int:
    prints("adding prop:", property_name)
    if not enable_local_props and not enable_edit_base_props:
        push_error("Cannot add properties because local props are disabled and base property editing is disabled")
        return -1
    
    var new_index: int = index_map.get(property_name, -1)
    if new_index != -1:
        # replacing an existing property
        remove_prop_index(new_index)
    else:
        new_index = _next_index
        _next_index += 1
    var info: Dictionary[String, Variant] = blank_property_info.duplicate()
    info["property_name"] = property_name
    properties_info[new_index] = info
    index_map[property_name] = new_index

    if include_value:
        info["is_base_definition_property"] = not as_overridden
        info["is_overridden"] = as_overridden
    elif enable_local_props:
        info["is_base_definition_property"] = false
        info["is_overridden"] = true

    if include_value:
        info["value"] = value
    elif as_conditional:
        info["value"] = {}
    else:
        info["value"] = GameManager.get_default_value_for_prop_name(property_name)
    prints("adding new property: %s, include_value: %s, default for name: %s, value: %s" % [property_name, include_value, GameManager.get_default_value_for_prop_name(property_name), info["value"]])

    if typeof(info["value"]) in [TYPE_DICTIONARY, TYPE_ARRAY]:
        info["is_conditional"] = true
    _add_list_item_for(new_index)
    return new_index

func add_pasted_new_properties_with_values(property_names: Array, prop_values: Array, as_override: bool) -> void:
    for i in property_names.size():
        var property_name: String = property_names[i]
        if property_name in index_map:
            push_error("Property already exists: %s" % property_name)
            continue
        _add_new_property(property_name, false, true, prop_values[i], as_override)
    on_prop_name_width_changed()
    list_size_changed.emit()
    resort_list_items()
    all_props_changed()
    properties_changed.emit()


func add_new_or_duplicate_property(property_name: String, as_conditional: bool, is_duplicate_of: String = "") -> void:
    var duplicate_of_index: int = index_map.get(is_duplicate_of, -1)
    var duplicate_value: Variant = null
    if is_duplicate_of and duplicate_of_index != -1:
        as_conditional = properties_info[duplicate_of_index]["is_conditional"]
        duplicate_value = properties_info[duplicate_of_index]["value"]
        if typeof(duplicate_value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
            duplicate_value = duplicate_value.duplicate_deep()

    var new_index: int = _add_new_property(property_name, as_conditional)
    if new_index != -1:
        if is_duplicate_of:
            properties_info[new_index]["value"] = duplicate_value
            if typeof(duplicate_value) in [TYPE_DICTIONARY, TYPE_ARRAY]:
                properties_info[new_index]["is_conditional"] = true
        properties_info[new_index]["list_item"].start_value_editting()
        on_prop_name_width_changed()
        resort_list_items()
        list_size_changed.emit()
        if is_instance_update():
            apply_edited_instance_property_update(property_name)
        properties_changed.emit()

func show_context_menu(for_list_item: ListItem) -> void:
    var context_menu = Utility.get_empty_context_menu()
    if for_list_item:
        context_menu.add_item("Duplicate", CTX_DUPLICATE_PROPERTY)
        context_menu.add_item("Copy Property", CTX_COPY_PROPERTY)
    context_menu.add_item("Copy All Properties", CTX_COPY_ALL_PROPERTIES)
    if enable_local_props and editing_entity:
        context_menu.add_item("Copy All Property Overrides", CTX_COPY_ALL_OVERRIDES)
    
    if CurrentClipboard.has_properties():
        context_menu.add_separator("Paste")
        if enable_local_props and editing_entity:
            context_menu.add_item("Paste Properties (Overrides)", CTX_PASTE_LOCAL_PROPERTIES)
            context_menu.add_item("Paste Properties (Overrides, Don't Override Existing)", CTX_PASTE_LOCAL_PROP_NO_OVERWRITE)
        if not editing_entity or edit_base_props_on_instance:
            var base_text: = " as Default" if editing_entity else ""
            context_menu.add_item("Paste%s Properties" % base_text, CTX_PASTE_PROPERTIES_OVERWRITE)
            context_menu.add_item("Paste%s Properties (Only unset properties)" % base_text, CTX_PASTE_PROPERTIES_NO_OVERWRITE)
        if for_list_item and CurrentClipboard.has_property_value():
            if editing_entity and enable_local_props:
                context_menu.add_item("Paste Property Value (Override)", CTX_PASTE_LOCAL_PROP_VALUE)
            if not editing_entity or edit_base_props_on_instance:
                var base_text: = " as Default" if editing_entity else ""
                context_menu.add_item("Paste Property Value%s" % base_text, CTX_PASTE_PROPERTY_VALUE)
    
    if for_list_item:
        context_menu.add_separator("Remove")
        var is_base_def_prop: bool = for_list_item.is_base_definition_property
        if editing_entity and enable_local_props:
            if is_base_def_prop:
                if not for_list_item.is_removed:
                    context_menu.add_item("Override As Removed", CTX_REMOVE_LOCAL_PROP)
                if for_list_item.is_overridden or for_list_item.is_removed:
                    context_menu.add_item("Reset Overriden Property", CTX_RESET_LOCAL_PROP)
            else:
                context_menu.add_item("Remove Property", CTX_DELETE_PROPERTY)
        if not editing_entity or (edit_base_props_on_instance and is_base_def_prop):
            var base_text: = " Default" if editing_entity else ""
            context_menu.add_item("Delete%s Property" % base_text, CTX_DELETE_PROPERTY)
    var is_for_single_prop: bool = for_list_item != null
    context_menu.id_pressed.connect(on_context_menu_id_pressed.bind(is_for_single_prop, for_list_item))
    Utility.popup_context_menu_at_mouse(context_menu)

func on_context_menu_id_pressed(context_menu_id: int, is_for_single_prop: bool, for_list_item: ListItem = null) -> void:
    if not get_window().has_focus():
        get_window().grab_focus()
    var prop_name: = for_list_item.property_name if for_list_item else ""
    if context_menu_id == CTX_DUPLICATE_PROPERTY:
        if is_for_single_prop:
            request_duplicate_property.emit(for_list_item.property_name)
    elif context_menu_id in [CTX_DELETE_PROPERTY, CTX_REMOVE_LOCAL_PROP, CTX_RESET_LOCAL_PROP]:
        var index_of_prop: int = index_map.get(prop_name, -1)
        if not is_for_single_prop or index_of_prop == -1:
            return
        var info: Dictionary[String, Variant] = properties_info[index_of_prop]
        if not info["is_base_definition_property"] and context_menu_id == CTX_REMOVE_LOCAL_PROP:
            return
        if context_menu_id == CTX_DELETE_PROPERTY:
            remove_prop_name(prop_name)
        elif context_menu_id == CTX_REMOVE_LOCAL_PROP:
            make_prop_removed(prop_name)
        elif context_menu_id == CTX_RESET_LOCAL_PROP:
            restore_prop_name(prop_name)
    elif context_menu_id in [CTX_COPY_PROPERTY, CTX_COPY_ALL_PROPERTIES, CTX_COPY_ALL_OVERRIDES]:
        var is_single_prop: = context_menu_id == CTX_COPY_PROPERTY and is_for_single_prop
        var properties_dict: = get_properties_overridden_dict(context_menu_id == CTX_COPY_ALL_OVERRIDES)
        if is_single_prop and prop_name in properties_dict:
            CurrentClipboard.copy_property_value(prop_name, properties_dict[prop_name])
        else:
            CurrentClipboard.copy_properties(properties_dict)
    else:
        if not CurrentClipboard.has_properties():
            return
        #paste
        if context_menu_id in [CTX_PASTE_PROPERTY_VALUE, CTX_PASTE_LOCAL_PROP_VALUE]:
            if not is_for_single_prop or not prop_name in index_map:
                return
            var single_prop_value: Variant = CurrentClipboard.get_property_value()
            if context_menu_id == CTX_PASTE_LOCAL_PROP_VALUE:
                set_prop_name_override_value(prop_name, single_prop_value)
            else:
                set_prop_base_value_only(prop_name, single_prop_value)
        elif context_menu_id in [CTX_PASTE_LOCAL_PROPERTIES, CTX_PASTE_LOCAL_PROP_NO_OVERWRITE]:
            if not editing_entity or not enable_local_props:
                return

            var to_set_props: Dictionary = CurrentClipboard.get_properties()
            var do_overwrite: = context_menu_id == CTX_PASTE_LOCAL_PROPERTIES
            var new_properties: Array[String] = []
            var new_property_values: Array = []
            for to_set_prop_name in to_set_props.keys():
                if not do_overwrite and index_map.has(to_set_prop_name):
                    continue
                if typeof(to_set_props[to_set_prop_name]) == TYPE_STRING and to_set_props[to_set_prop_name] == "--REMOVED--":
                    make_prop_removed(to_set_prop_name)
                else:
                    if to_set_prop_name in index_map:
                        set_prop_name_override_value(to_set_prop_name, to_set_props[to_set_prop_name])
                    else:
                        new_properties.append(to_set_prop_name)
                        new_property_values.append(to_set_props[to_set_prop_name])
            if new_properties.size() > 0:
                add_pasted_new_properties_with_values(new_properties, new_property_values, true)
        elif context_menu_id in [CTX_PASTE_PROPERTIES_OVERWRITE, CTX_PASTE_PROPERTIES_NO_OVERWRITE]:
            if editing_entity and not edit_base_props_on_instance:
                return
            var do_overwrite: = context_menu_id == CTX_PASTE_PROPERTIES_OVERWRITE
            var to_set_props: Dictionary = CurrentClipboard.get_properties()
            
            var new_properties: Array[String] = []
            var new_property_values: Array = []
            for to_set_prop_name in to_set_props.keys():
                if typeof(to_set_props[to_set_prop_name]) == TYPE_STRING and to_set_props[to_set_prop_name] == "--REMOVED--":
                    continue
                if not do_overwrite and index_map.has(to_set_prop_name):
                    continue
                
                if not to_set_prop_name in index_map:
                    new_properties.append(to_set_prop_name)
                    new_property_values.append(to_set_props[to_set_prop_name])
                else:
                    if editing_entity:
                        set_prop_base_value_only(to_set_prop_name, to_set_props[to_set_prop_name])
                    else:
                        change_prop_current_value(to_set_prop_name, to_set_props[to_set_prop_name])
            if new_properties.size() > 0:
                add_pasted_new_properties_with_values(new_properties, new_property_values, false)

func focus_in_edit_mode(property_name: String) -> void:
    var p_index: int = index_map.get(property_name, -1)
    if p_index == -1:
        push_error("Property not found in list: %s" % property_name)
        return
    var list_item: ListItem = properties_info[p_index]["list_item"]
    if not list_item.is_active():
        set_active_list_item(list_item)
    list_item.start_value_editting()
    if properties_info[p_index]["is_conditional"]:
        request_conditional_editor.emit(property_name, properties_info[p_index]["value"], true)

func set_prop_conditional_value(property_name: String, new_value: Variant) -> void:
    var p_index: int = index_map.get(property_name, -1)
    if p_index == -1:
        push_error("Property not found in list: %s" % property_name)
        return
    var info: Dictionary[String, Variant] = properties_info[p_index]
    info["value"] = new_value
    if info["list_item"]:
        info["list_item"].set_prop_value(new_value)
    prop_changed(property_name)
    resort_list_items()
    properties_changed.emit()