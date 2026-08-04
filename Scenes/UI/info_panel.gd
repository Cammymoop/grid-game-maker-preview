extends PanelContainer

const InfoItem = preload("res://Scenes/UI/info_item.gd")
const InfoList = preload("res://Scenes/info_list.gd")

@export var info_list: InfoList

var next_item_id: int = 0

var tracking_items: Dictionary = {}
var items_by_id: Dictionary = {}

var info_panel_enabled: bool = false

var entity_flag_counts_dirty: bool = true

func _ready() -> void:
    MapManager.persist_on_completion_changed.connect(map_persist_on_completion_changed)
    GameManager.any_state_loaded.connect(on_any_state_loaded)
    GameManager.flag_counts_changed.connect(on_flag_counts_changed)
    hide()
    info_panel_enabled = GameManager.get_game_setting("info_panel_enabled", false)
    var game_info_panel_settings: Dictionary = GameManager.get_game_setting("info_panel_items", {})
    if not game_info_panel_settings:
        info_panel_enabled = false

    if not info_panel_enabled:
        set_physics_process(false)
    else:
        make_items_from_info(game_info_panel_settings)


func make_items_from_info(new_items: Dictionary) -> void:
    clear_all()
    for key in new_items:
        var item_data: Dictionary = new_items[key]
        make_item_from_data(item_data)
    
    

func clear_all() -> void:
    items_by_id.clear()
    info_list.clear_items()
    tracking_items.clear()
    next_item_id = 0

func get_visible_item_count() -> int:
    var count: int = 0
    for child in info_list.get_children():
        if child is InfoItem and child.visible:
            count += 1
    return count

func on_info_updated() -> void:
    if get_visible_item_count() == 0:
        hide()
        return
    show()

func _get_next_item_id() -> int:
    var next: int = next_item_id
    next_item_id += 1
    return next

func _new_info_item() -> InfoItem:
    var new_item: = info_list.add_info_item()
    new_item.item_id = _get_next_item_id()
    items_by_id[new_item.item_id] = new_item
    return new_item


func make_item_from_data(item_data: Dictionary) -> InfoItem:
    var new_item: = _new_info_item()
    var filter_prop: String = item_data.get("filter_prop", "")
    var filter_truthy: bool = item_data.get("filter_truthy", true)

    if item_data.get("type", "property") == "property":
        if item_data.get("value_prop", ""):
            if item_data.get("camera_tracked", true):
                _set_camera_tracked_property_item(new_item, item_data["value_prop"])
            else:
                _set_filtered_property_item(new_item, filter_prop, filter_truthy, item_data["value_prop"])
    else:
        var entity_id: int = item_data.get("entity_id", -1)
        if item_data.get("type", "property") == "entity_count":
            _set_entity_count_item(new_item, entity_id, filter_prop, filter_truthy)
        else:
            var include_pending: bool = item_data.get("include_pending", true)
            var separate_pending: bool = item_data.get("separate_pending", false)
            var always_separate: bool = item_data.get("always_separate", false)
            _set_entity_flag_count_item(new_item, entity_id, include_pending, separate_pending, always_separate)
    
    if item_data.has("entity_icon"):
        tracking_items[new_item.item_id]["entity_icon"] = item_data["entity_icon"]
        new_item.set_icon_as_entity(item_data["entity_icon"])
    elif item_data.has("image_icon"):
        var image_icon_texture_id: int = item_data["image_icon"]
        if TextureManager.has_loaded_texture_id(image_icon_texture_id):
            var image_icon_tex_index: int = item_data.get("image_icon_index", 0)
            tracking_items[new_item.item_id]["image_icon"] = item_data["image_icon"]
            tracking_items[new_item.item_id]["image_icon_tex_index"] = image_icon_tex_index
            new_item.set_icon_texture(image_icon_texture_id, image_icon_tex_index)
    
    tracking_items[new_item.item_id]["label"] = item_data.get("label", "")
    tracking_items[new_item.item_id]["separator"] = item_data.get("separator", "")

    if item_data.get("label", ""):
        new_item.set_item_text(item_data["label"])
    else:
        new_item.set_item_text("")
    
    if item_data.has("separator"):
        new_item.set_item_separator_string(item_data["separator"])
    
    tracking_items[new_item.item_id]["hide_zero_value"] = item_data.get("hide_zero_value", true)
    tracking_items[new_item.item_id]["hide_empty_value"] = item_data.get("hide_empty_value", true)
    new_item.hide_zero_value = item_data.get("hide_zero_value", true)
    new_item.hide_empty_value = item_data.get("hide_empty_value", true)
    
    new_item.refresh_ui()
    
    return new_item

func _physics_process(_delta: float) -> void:
    if not info_panel_enabled:
        hide()
        set_physics_process(false)
        return
    if not visible:
        show()
    update_items.call_deferred()

func update_items() -> void:

    var filter_props_truthy: Array[String] = []
    var filter_props_falsey: Array[String] = []
    var filter_ids: Array[int] = []
    for item_id in tracking_items:
        var item_data: Dictionary = tracking_items[item_id]
        var is_filtered: bool = item_data.get("filtered", false)
        var filter_prop: String = item_data.get("filter_prop", "")
        var filter_truthy: bool = item_data.get("filter_truthy", true)

        if is_filtered and filter_prop:
            if filter_truthy and filter_prop not in filter_props_truthy:
                filter_props_truthy.append(filter_prop)
            elif not filter_truthy and filter_prop not in filter_props_falsey:
                filter_props_falsey.append(filter_prop)
        if tracking_items[item_id].get("type", "property") in ["entity_count", "entity_flag_count"]:
            var filter_id: int = item_data.get("entity_id", -1)
            if filter_id > -1 and filter_id not in filter_ids:
                filter_ids.append(filter_id)
    
    var entities_by_id: = {}
    for id in filter_ids:
        entities_by_id[id] = EntityManager.find_all_entities_by_index(id, true)
    
    var entities_by_truthy: = {}
    for prop in filter_props_truthy:
        entities_by_truthy[prop] = EntityManager.find_all_entities_with_truthy_property(prop, true, [], false)
    var entities_by_falsey: = {}
    for prop in filter_props_falsey:
        entities_by_falsey[prop] = EntityManager.find_all_entities_with_truthy_property(prop, true, [], true)
    
    for item_id in tracking_items:
        var item_data: Dictionary = tracking_items[item_id]
        var item: InfoItem = items_by_id[item_id]

        var type: String = item_data.get("type", "property")
        var is_filtered: bool = item_data.get("filtered", false)
        var filter_prop: String = item_data.get("filter_prop", "")
        var filter_truthy: bool = item_data.get("filter_truthy", true)
        
        var item_enabled: bool = true
        if type == "property":
            var included_entities: Array[BaseEntity] = []
            if is_filtered and filter_prop:
                if filter_truthy:
                    included_entities.append_array(entities_by_truthy[filter_prop])
                else:
                    included_entities.append_array(entities_by_falsey[filter_prop])
            elif not item_data.get("camera_tracked", true):
                included_entities.append_array(EntityManager.get_all_active_entities())

            if item_data.get("camera_tracked", true):
                var follow_entity: BaseEntity = GameManager.get_camera_focus_entity()
                var old_included: = included_entities
                included_entities = []
                if follow_entity:
                    if is_filtered and filter_prop:
                        for entity in old_included:
                            if entity.instance_id == follow_entity.instance_id:
                                included_entities.append(entity)
                    else:
                        included_entities = [follow_entity]

            if included_entities:
                included_entities.sort_custom(_entity_instance_sort)
                if included_entities.size() > 0:
                    var first_entity: BaseEntity = included_entities[0]
                    var prop_value: Variant = EntityManager.get_entity_prop_with_default(first_entity, item_data["value_prop"], "")
                    if typeof(prop_value) in [TYPE_INT, TYPE_FLOAT]:
                        item.set_item_number(float(prop_value), true)
                    elif typeof(prop_value) == TYPE_STRING and prop_value.length() > 0:
                        item.set_item_value_string(prop_value)
                    else:
                        item_enabled = false
                else:
                    item_enabled = false
            else:
                item_enabled = false
        elif type == "entity_flag_count":
            var entity_id: int = item_data.get("entity_id", -1)
            if entity_id == -1:
                item_enabled = false
                continue
            if not entity_flag_counts_dirty:
                continue
            var include_pending: bool = item_data.get("include_pending", true)
            var separate_pending: bool = item_data.get("separate_pending", false)
            var always_separate: bool = item_data.get("always_separate", false)
            
            if not include_pending or not separate_pending:
                var count: int = GameManager.count_entity_flags_by_entity_id(entity_id, include_pending)
                prints("count for flags for entity %d: %d" % [entity_id, count])
                item.set_item_number(count, true)
            elif separate_pending:
                var without_pending: int = GameManager.count_entity_flags_by_entity_id(entity_id, false)
                var with_pending: int = GameManager.count_entity_flags_by_entity_id(entity_id, true)
                if not always_separate and with_pending == without_pending:
                    item.set_item_number(without_pending, true)
                else:
                    var pending_additional: int = maxi(0, with_pending - without_pending)
                    item.set_item_text("%d +%d" % [without_pending, pending_additional])
        else:
            var entity_id: int = item_data.get("entity_id", -1)
            var included_entities: Array[BaseEntity] = []
            if entity_id > -1:
                included_entities.append_array(entities_by_id[entity_id])
            else:
                included_entities.append_array(EntityManager.get_all_active_entities())
            if is_filtered and filter_prop:
                var old_included: = included_entities
                included_entities = []

                var filter_from: = entities_by_truthy if filter_truthy else entities_by_falsey
                var prop_filtered: Array[BaseEntity] = filter_from[filter_prop]
                for entity in old_included:
                    if entity in prop_filtered:
                        included_entities.append(entity)
                item.set_item_number(included_entities.size(), true)
        
        if item.enabled != item_enabled:
            item.set_enabled(item_enabled)
    entity_flag_counts_dirty = false
    on_info_updated()

                
        
func _entity_instance_sort(a: BaseEntity, b: BaseEntity) -> bool:
    return a.instance_id < b.instance_id


func _set_entity_count_item(item: InfoItem, entity_id: int, prop_name: String, prop_truthy: bool) -> void:
    item.set_item_number(0, true)
    if entity_id > -1:
        item.set_icon_as_entity(entity_id)
    tracking_items[item.item_id] = {
        "type": "entity_count",
        "entity_id": entity_id,
        "filtered": true,
        "filter_prop": prop_name,
        "filter_truthy": prop_truthy,
    }

func _set_entity_flag_count_item(item: InfoItem, entity_id: int, include_pending: bool, separate_pending: bool, always_separate: bool) -> void:
    item.set_item_number(0, true)
    if entity_id > -1:
        item.set_icon_as_entity(entity_id)
    tracking_items[item.item_id] = {
        "type": "entity_flag_count",
        "entity_id": entity_id,
        "include_pending": include_pending,
        "separate_pending": separate_pending,
        "always_separate": always_separate,
    }

func _set_camera_tracked_property_item(item: InfoItem, prop_name: String) -> void:
    item.set_item_value_string("")
    tracking_items[item.item_id] = {
        "type": "property",
        "camera_tracked": true,
        "filtered": false,
        "value_prop": prop_name,
    }

func _set_filtered_property_item(item: InfoItem, filter_prop: String, filter_truthy: bool, value_prop: String) -> void:
    item.set_item_value_string("")
    tracking_items[item.item_id] = {
        "type": "property",
        "camera_tracked": false,
        "filtered": true,
        "filter_prop": filter_prop,
        "filter_truthy": filter_truthy,
        "value_prop": value_prop,
    }

func map_persist_on_completion_changed() -> void:
    entity_flag_counts_dirty = true

func on_any_state_loaded() -> void:
    entity_flag_counts_dirty = true

func on_flag_counts_changed() -> void:
    entity_flag_counts_dirty = true