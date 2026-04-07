extends Node

signal entity_list_updated
signal post_deserialize

var entity_template = preload("res://Scenes/BaseEntity.tscn")
var large_entity_template = preload("res://Scenes/LargeEntity.tscn")
var controller_templates = {}

var entity_defs = {
    0: {
        "name": "player",
        "texture": 1,
        "tex_index": 0,
        "intended_move_speed": 6,
        "controller": "InputController",
        "properties": {
            "pusher": true,
            "treads": true,
        },
        "groups": ["Player"],
    },
    1: {
        "name": "green_box",
        "texture": 1,
        "tex_index": 1,
        "properties": {
            "blocks": {"condition": "has_no_property pusher"},
            "move_onto": {"condition": "be_pushed forward"},
            "i_finish_move_onto_tile": {
                "condition": "tile_has_property wet",
                "actions": ["replace_tile greenery", "die"]
            }
        },
    },
    2: {
        "name": "bouncer",
        "texture": 1,
        "tex_index": 6,
        "intended_move_speed": 4,
        "controller": "BounceController",
        "properties": {
            "kills": true,
        },
    },
    3: {
        "name": "swap_box",
        "texture": 1,
        "tex_index": 8,
        "properties": {
            "blocks": {"condition": "has_no_property pusher"},
            "move_onto": {"condition": "be_pushed reverse"},
        },
    },
    4: {
        "name": "rotate_box",
        "texture": 1,
        "tex_index": 13,
        "properties": {
            "pusher": true,
            "no_rotation": true,
            "blocks": {"condition": "has_no_property pusher"},
            "move_onto": {"condition": "be_pushed turn_right"},
        },
    },
}
@onready var loaded_entity_defs = entity_defs

var entity_index_map = {}
var entity_instance_map = {}

var entity_signal_connections = {}

var entity_list = []
var bond_groups = []

var im_ready = false

var instance_counter = 0

var frame_counter = 0

var movements_enabled: bool = true
var turn_requested: bool = false
var requested_turn_frames: int = 0
var turn_frames_remaining = 0
var controller_frame: bool = true
var movement_mode: int

var default_move_speed: float = 6

func _physics_process(_delta):
    if movements_enabled:
        frame_counter += 1
    
    if movement_mode != GameManager.MovementMode.MOVEMENT_CONTINUOUS:
        controller_frame = false
        if movements_enabled:
            if movement_mode == GameManager.MovementMode.MOVEMENT_DISCRETE:
                turn_frames_remaining -= 1
                if turn_frames_remaining <= 0:
                    movements_enabled = false
            elif movement_mode == GameManager.MovementMode.MOVEMENT_DISCRETE_WAIT and all_entities_settled():
                movements_enabled = false
        elif turn_requested:
            turn_requested = false
            turn_frames_remaining = requested_turn_frames
            movements_enabled = true
            controller_frame = true

func all_entities_settled() -> bool:
    var settled = true
    for e in entity_list:
        settled = settled and e.is_settled()
    return settled

func _ready():
    preload_controller_templates()
    process_physics_priority = 10

func setup():
    fix_string_keys()
    if not TextureManager.im_ready:
        await TextureManager.textures_loaded
    create_index_map()
    create_defined_custom_signals()
    
    im_ready = true

func create_defined_custom_signals() -> void:
    for entity_id in entity_defs.keys():
        var entity_def = entity_defs[entity_id]
        for prop_name in entity_def["properties"].keys():
            _create_signal_for_prop(prop_name)

func _create_signal_for_prop(prop_name: String) -> void:
    if not prop_name.begins_with("when_signal_"):
        return
    var signal_name = prop_name.trim_prefix("when_signal_")
    if not has_user_signal(signal_name):
        create_signal(signal_name)

func create_signal(signal_name: StringName) -> void:
    add_user_signal(signal_name)

func connect_custom_signal(signal_name: String, callable: Callable) -> void:
    if not has_user_signal(signal_name):
        push_error("ERROR: custom signal not found: " + signal_name)
        return
    if callable.is_valid():
        connect(signal_name, callable)

func do_emit_signal(signal_name: String, owning_entity = null, args = null) -> void:
    if not has_user_signal(signal_name):
        print_debug("ERROR: custom signal not found: " + signal_name)
        return
    emit_signal(signal_name, owning_entity, args)

func get_custom_signals() -> Array:
    var signals = []
    for signal_info in get_signal_list():
        if not has_user_signal(signal_info["name"]):
            continue
        signals.append(Signal(self, signal_info["name"]))
    return signals

func disconnect_all_custom_signals() -> void:
    for custom_sig in get_custom_signals():
        for sig_conn in custom_sig.get_connections():
            custom_sig.disconnect(sig_conn.callable)

func refresh_definition():
    update_movement_mode()
    fix_string_keys()
    create_index_map()
    create_defined_custom_signals()

func update_movement_mode():
    movement_mode = GameManager.get_game_setting("movement_mode", GameManager.MovementMode.MOVEMENT_CONTINUOUS)
    
    if movement_mode == GameManager.MovementMode.MOVEMENT_CONTINUOUS:
        controller_frame = true
        movements_enabled = true
    else:
        controller_frame = false
        movements_enabled = false
    
    #print_debug("MOVEMENT MODE is now " + GameManager.describe_movement_mode(movement_mode))

func clear():
    bond_groups = []

func fix_string_keys():
    var old_definition = entity_defs
    entity_defs = {}
    for key in old_definition:
        var intk: = int(key)
        entity_defs[intk] = old_definition[key]
        if "texture" in entity_defs[intk]:
            entity_defs[intk]["texture"] = int(entity_defs[intk]["texture"])
        if "tex_index" in entity_defs[intk]:
            entity_defs[intk]["tex_index"] = int(entity_defs[intk]["tex_index"])

func entity_order(a, b) -> bool:
    if a.entity_index == b.entity_index:
        return a.instance_id < b.instance_id
    return a.entity_index < b.entity_index

func refresh_entity_list():
    entity_instance_map = {}
    entity_list = get_tree().get_nodes_in_group("_entity_")
    resort_entity_list()
    for e in entity_list:
        entity_instance_map[e.instance_id] = e
    
    on_entity_list_changed()

func resort_entity_list() -> void:
    entity_list.sort_custom(entity_order)

func on_entity_added(entity: BaseEntity) -> void:
    entity_list.append(entity)
    resort_entity_list()
    entity_instance_map[entity.instance_id] = entity
    on_entity_list_changed()

func on_entity_list_changed() -> void:
    entity_list_updated.emit()

func clear_entity_list():
    disconnect_all_custom_signals()
    for entity in entity_list:
        if not entity:
            continue
        entity.remove_from_group("_entity_")
        entity.set_active(false)
        entity.queue_free()
    entity_list = []
    entity_instance_map = {}
    clear()

# In discrete mode we wont update entities at all until a move is requested
func request_move(entity) -> void:
    if movement_mode == GameManager.MovementMode.MOVEMENT_DISCRETE:
        requested_turn_frames = entity.steps_per_tile
    turn_requested = true

func get_instance(instance_id: int) -> BaseEntity:
    if not instance_id in entity_instance_map:
        return null
    return entity_instance_map[instance_id]

func update_entity_definition(entity_index, entity_definition):
    if not entity_index in entity_defs:
        print("ERROR tried to update non-existing entity: " + str(entity_index))
        return
    entity_defs[entity_index] = entity_definition
    refresh_definition()

func get_all_controllers() -> Array:
    return controller_templates.keys()

func new_entity(definition) -> int:
    var new_index = max_entity_index() + 1
    entity_defs[new_index] = definition
    refresh_definition()
    return new_index

func max_entity_index() -> int:
    var max_index = 0
    for e in entity_defs.keys():
        max_index = maxi(max_index, e)
    return max_index

func create_defaults() -> void:
    create_default_player()
    create_default_box()
    
func create_randoms() -> void:
    create_default_player()
    create_random_entity("green_box")
    create_random_entity("swap_box")
    create_random_entity("bouncer")

func create_default_player() -> void:
    if entity_index_map.has("player"):
        create_entity(get_entity_index("player"), Vector2(2, 2))
func create_default_box() -> void:
    pass

func create_random_entity(entity_name) -> void:
    if not entity_index_map.has(entity_name):
        return
    var tries = 20
    
    while tries > 0:
        tries -= 1
        var entity_pos = Vector2(Utility.random_int_range(1, 11), Utility.random_int_range(1, 11))
        if MapManager.is_blocked(entity_pos):
            continue
        create_entity(get_entity_index(entity_name), entity_pos)
        break

func get_entity_texture(entity_index: int):
    return TextureManager.get_texture(entity_defs[entity_index]['texture'])

func get_entity_texture_rect(entity_index: int):
    return TextureManager.get_index_rect(entity_defs[entity_index]['texture'], entity_defs[entity_index]['tex_index'])

func get_new_controller(controller_name: String):
    return controller_templates[controller_name].instantiate()

func add_entity_to_world(entity: BaseEntity) -> void:
    var destination = Utility.get_world().get_node("Entities")
    for c in destination.get_children():
        if c.entity_index > entity.entity_index:
            destination.add_child(entity)
            destination.move_child(entity, c.get_index())
            return
    destination.add_child(entity)

func create_entity(entity_index: int, tile_position: Vector2i, facing: int = 0, activate: bool = true) -> Node2D:
    var entity_info = entity_defs[entity_index]
    
    var entity: BaseEntity
    if "entity_type" in entity_info:
        entity = large_entity_template.instantiate()
    else: 
        entity = entity_template.instantiate()

    var intended_move_speed: = float(entity_info.get("intended_move_speed", default_move_speed))
    if intended_move_speed <= 0:
        intended_move_speed = default_move_speed
    entity.set_intended_move_speed(intended_move_speed)

    entity.entity_index = entity_index
    setup_entity_controller(entity)
    entity.position = MapManager.tile_to_world_position(tile_position)
    add_entity_to_world(entity)
    entity.initialize()
    setup_entity_texture(entity)
    
    entity.set_facing(facing)
    if entity.visual_turn_on_move:
        entity.set_visual_facing(facing)
    
    if "groups" in entity_info:
        for g in entity_info["groups"]:
            entity.add_to_group(g)
    
    entity.instance_id = instance_counter
    instance_counter += 1
    
    auto_bond_handler(entity)
    auto_tail_handler(entity)
    
    if activate:
        entity.set_active(true)
    on_entity_added(entity)
    
    post_created_at_actions(entity)
    
    MapManager.check_terrain_spr_mod_for_created(entity)
    
    return entity

func post_created_at_actions(entity: BaseEntity) -> void:
    var at_pos: = entity.get_stationary_position()
    var sitting_on_entities: Array = get_entities_at(at_pos, entity)
    for e in sitting_on_entities:
        resolve_entity_interaction_event("i_finish_move_onto", entity, e, at_pos)
    if entity.active:
        for e in sitting_on_entities:
            resolve_entity_interaction_event("finish_move_onto", e, entity, at_pos)

func setup_entity_controller(entity: BaseEntity) -> void:
    var entity_index = entity.entity_index
    if entity_index in entity_defs and "controller" in entity_defs[entity_index]:
        var controller_name = entity_defs[entity_index]["controller"]
        if controller_name in controller_templates:
            var controller = get_new_controller(controller_name)
            if entity_defs[entity_index].has("controller_options"):
                controller.set_options(entity_defs[entity_index]["controller_options"])
            entity.add_child(controller)
            entity.set_controller(controller)

func auto_tail_handler(entity: BaseEntity) -> void:
    var auto_tail_val: Variant = get_entity_prop_with_default(entity, "auto_tail", false)
    if not auto_tail_val:
        return
    if typeof(auto_tail_val) == TYPE_STRING and auto_tail_val.to_lower() == "true":
        auto_tail_val = true
    
    var looking_at_tile = entity.tile_position + Utility.facing_vector(entity.facing)
    var entities_in_front = get_entities_at(looking_at_tile)
    for e in entities_in_front:
        if typeof(auto_tail_val) == TYPE_STRING and get_entity_prop_with_default(e, auto_tail_val, false):
            entity.set_tailing(e)
            break
        elif auto_tail_val:
            entity.set_tailing(e)
            break

func auto_bond_handler(entity: BaseEntity) -> void:
    if get_entity_prop_with_default(entity, "auto_bond", false):
        var bonded: = false
        for potential_group in bond_groups:
            # This doesn't keep track of which groups were created as auto-bond groups for specific entities, more work to do later
            if not potential_group:
                continue
            if get_instance(potential_group[0]).entity_index == entity.entity_index:
                bond_entity(entity, potential_group)
                bonded = true
                break
        if not bonded:
            create_bond_group([entity])

func restore_entity(serialized_entity: Dictionary, refresh: bool = false) -> void:
    var entity: BaseEntity
    if not "entity_class" in serialized_entity or serialized_entity["entity_class"] == "BaseEntity":
        entity = entity_template.instantiate()
    else:
        entity = large_entity_template.instantiate()
    
    entity.pre_init()
    entity.deserialize(serialized_entity)
    add_entity_to_world(entity)
    entity.initialize() # initialize after deserializing
    setup_entity_texture(entity)
    
    MapManager.check_terrain_spr_mod_for_created(entity)
    
    if refresh:
        refresh_entity_list()

func setup_entity_texture(entity: BaseEntity) -> void:
    var texture_index = entity_defs[entity.entity_index]['texture']
    var texture_sub_index = entity_defs[entity.entity_index]['tex_index']
    var sprite: MaskLayerSprite = entity.sprite
    var sprite_config: Dictionary = entity_defs[entity.entity_index].get("sprite_config", {})
    if sprite_config and sprite_config.get("layers", []):
        sprite.set_main_layers(sprite_config["layers"])
    else:
        sprite.set_as_single(texture_index, texture_sub_index)

func serialize() -> Dictionary:
    var serialized_entities: Array = []
    for e in entity_list:
        serialized_entities.append(e.serialize())
    
    return {"entity_list": serialized_entities, "bond_groups": bond_groups.duplicate_deep()}

func deserialize(data: Dictionary) -> void:
    clear_entity_list()
    for entity_data in data["entity_list"]:
        restore_entity(entity_data)
    bond_groups = data["bond_groups"]
    refresh_entity_list()
    instance_counter = 0
    for e in entity_list:
        instance_counter = maxi(instance_counter, e.instance_id + 1)
    
    emit_signal("post_deserialize")

func create_bond_group(entities: Array) -> void:
    var group = []
    bond_groups.append(group)
    for e in entities:
        group.append(e.instance_id)
        e.bond_group = group

func bond_entity(entity, bond_group) -> void:
    entity.bond_group = bond_group
    bond_group.append(entity.instance_id)

func unbond_entity(entity: BaseEntity, cull_empty: bool = true) -> void:
    if entity.bond_group:
        var bg: Array = entity.bond_group
        bg.remove_at(bg.find(entity.instance_id))
        entity.bond_group = []
        if cull_empty:
            bond_group_cull()

func bond_group_cull() -> void:
    var to_remove: Array[int] = []
    for bg_index in bond_groups.size():
        if bond_groups[bg_index].size() < 1:
            # In reverse order so removal is easy
            to_remove.push_back(bg_index)
    for i in to_remove:
        bond_groups.remove_at(i)

func find_bond_group_of_entity(entity: BaseEntity) -> Array:
    for bg in bond_groups:
        if bg.has(entity.instance_id):
            return bg
    return []

func bond_group_start_move(bond_group: Array, steps_per_tile: int, move_facing: int) -> bool:
    var instances = []
    for entity_instance_id in bond_group:
        instances.append(get_instance(entity_instance_id))
    
    for entity in instances:
        if entity.moving:
            # Short circuit so we dont break by reverting a move on a currently moving entity
            return false
    
    var move_allowed = true
    for entity in instances:
        # set change visual facing to false for group moves for now
        # good default but should be configurable somehow
        entity.set_current_steps_per_tile(steps_per_tile)
        if not entity.start_move(move_facing, false, true):
            move_allowed = false
    
    # At least one of the entities in the bond group were blocked
    # Stop them all from moving
    if not move_allowed:
        for entity in instances:
            entity.revert_move_start()
    else:
        for entity in instances:
            post_move_actions(entity, entity.tile_position, entity.next_tile_pos)
            entity.actually_started_move()
    return move_allowed

func get_entities_at(tile_position: Vector2, exclude_entity: Object = null, exclude_list: Array = [], include_moving_away: bool = false) -> Array:
    var entities_here: Array = []
    for e in entity_list:
        if e == exclude_entity or (exclude_list and e.instance_id in exclude_list):
            continue
        if e is LargeEntity:
            if e.is_at(tile_position):
                entities_here.append(e)
        else:
            if e.moving:
                if e.next_tile_pos == tile_position or (include_moving_away and e.tile_position == tile_position):
                    entities_here.append(e)
            elif e.tile_position == tile_position:
                entities_here.append(e)
    return entities_here

func get_entities_at_multiple(tile_positions: Array, exclude_entity: Object = null, exclude_list: Array = [], include_moving_away: bool = false) -> Array:
    var entities_here: Array = []
    for e in entity_list:
        if e == exclude_entity or (exclude_list and e.instance_id in exclude_list):
            continue
        if e.is_at_multiple(tile_positions, include_moving_away):
            entities_here.append(e)
    return entities_here

func find_entity_by_index(entity_index: int, first: bool = true) -> BaseEntity:
    for i in Utility.array_iter(entity_list, not first):
        if entity_list[i].entity_index == entity_index:
            return entity_list[i]
    return null

func find_entity_with_property(prop_name: String, first: bool = true) -> BaseEntity:
    for i in Utility.array_iter(entity_list, not first):
        if entity_has_property(entity_list[i], prop_name):
            return entity_list[i]
    return null

func filter_entities_by_property(prop_name: String, entities: Array, invert: bool = false) -> Array:
    var filtered_entities: Array = []
    for i in entities.size():
        if entity_has_property(entities[i], prop_name) != invert:
            filtered_entities.append(entities[i])
    return filtered_entities

func find_entity_with_truthy_property(prop_name: String, first: bool = true) -> BaseEntity:
    for i in Utility.array_iter(entity_list, not first):
        if get_entity_prop_with_default(entity_list[i], prop_name, false):
            return entity_list[i]
    return null

func find_closest_entity_with_property(prop_name: String, from_position: Vector2i, exclude_list: Array = []) -> BaseEntity:
    var closest_dist: float = -1
    var closest_entity: BaseEntity = null
    for entity in entity_list:
        if entity in exclude_list or not entity_has_property(entity, prop_name):
            continue
        var euclidean_dist: = from_position.distance_to(entity.tile_position)
        if closest_dist < 0 or euclidean_dist < closest_dist:
            closest_dist = euclidean_dist
            closest_entity = entity
    return closest_entity

func create_index_map() -> void:
    entity_index_map = {}
    
    for entity_index in entity_defs:
        var entity_info = entity_defs[entity_index]
        
        if entity_info['name'] in entity_index_map:
            print_debug("WARNING: entity name already in use: " + entity_info['name'])
        entity_index_map[entity_info['name']] = entity_index

func preload_controller_templates() -> void:
    var controller_class_files = []
    var controllers_path = "res://Scenes/Controllers/"
    var directory_walker: = DirAccess.open(controllers_path)
    if not directory_walker:
        print_debug("error opening controller class path")
        return

    directory_walker.list_dir_begin()
    
    var file_name = directory_walker.get_next()
    while file_name != "":
        if not directory_walker.current_is_dir():
            if file_name.ends_with(".tscn"):
                controller_class_files.append(file_name)
        file_name = directory_walker.get_next()
    
    for fname in controller_class_files:
        var controller_name = fname.get_basename()
        controller_templates[controller_name] = load(controllers_path + fname)

func finish_move(moving_entity, onto_positions: Array) -> void:
    var entities_here: Array = []
    var entities_overlapped_at: Array = []
    for onto_position in onto_positions:
        for entity_here in get_entities_at(onto_position, moving_entity):
            if not entity_here in entities_here:
                entities_here.append(entity_here)
                entities_overlapped_at.append(onto_position)

    for i in entities_here.size():
        resolve_entity_interaction_event("i_finish_move_onto", moving_entity, entities_here[i], entities_overlapped_at[i])
    if moving_entity.active:
        for i in entities_here.size():
            resolve_entity_interaction_event("finish_move_onto", entities_here[i], moving_entity, entities_overlapped_at[i])

func resolve_entity_interaction_event(event_name: String, actor, interactee, at_tile_position: Vector2) -> void:
    var event_prop: = get_entity_property(actor, event_name)
    if event_prop and event_prop.is_conditional():
        event_prop.resolve(actor, interactee, at_tile_position)

func get_entity_interaction_bool_result(event_name: String, defualt_result: bool, actor, interactee, at_tile_position: Vector2) -> bool:
    var event_prop: = get_entity_property(actor, event_name)
    if not event_prop:
        return defualt_result
    if event_prop.is_conditional():
        return event_prop.resolve(actor, interactee, at_tile_position)
    else:
        return event_prop.get_value()

func attempt_move(moving_entity, tile_position, group_move=false) -> bool:
    var entities_here: = []
    if group_move:
        entities_here = get_entities_at(moving_entity.tile_position, null, moving_entity.bond_group)
    else:
        entities_here = get_entities_at(moving_entity.tile_position, moving_entity)
    for e in entities_here:
        if not get_entity_interaction_bool_result("move_off_of", true, e, moving_entity, moving_entity.tile_position):
            return false
    
    var entities_there: = []
    if group_move:
        entities_there = get_entities_at(tile_position, null, moving_entity.bond_group)
    else:
        entities_there = get_entities_at(tile_position, moving_entity)
    for e in entities_there:
        if e in entities_here:
            continue
        var blocks: = get_entity_property(e, "blocks")
        if blocks:
            if blocks.is_conditional():
                if blocks.resolve(e, moving_entity, tile_position):
                    return false
            elif blocks.get_value():
                return false
        
        if not get_entity_interaction_bool_result("move_onto", true, e, moving_entity, tile_position):
            return false
        
    return true

func post_move_actions(moving_entity, from_position, to_position, exclude_group: Array = []) -> void:
    var entities_start = get_entities_at(from_position, moving_entity, exclude_group)
    for e in entities_start:
        resolve_entity_interaction_event("post_move_off_of", e, moving_entity, from_position)
    
    var entities_destination = get_entities_at(to_position, moving_entity, exclude_group)
    for e in entities_destination:
        resolve_entity_interaction_event("post_move_onto", e, moving_entity, to_position)
    
    MapManager.post_move_actions(moving_entity, from_position, to_position)

func post_die_actions(dying_entity: BaseEntity) -> void:
    if not dying_entity.moving:
        var at_pos: = dying_entity.get_stationary_position()
        var sitting_on_entities: Array = get_entities_at(at_pos, dying_entity)
        for e in sitting_on_entities:
            resolve_entity_interaction_event("post_move_off_of", e, dying_entity, at_pos)

func post_move_multi_pos(moving_entity, moved_off_positions: Array, moved_onto_positions: Array, exclude_group: Array = []) -> void:
    var entities_moved_off: Array = []
    var entities_moved_off_at: Array = []
    for moved_off_position in moved_off_positions:
        for entity_here in get_entities_at(moved_off_position, moving_entity, exclude_group):
            if not entity_here in entities_moved_off:
                entities_moved_off.append(entity_here)
                entities_moved_off_at.append(moved_off_position)
    for i in entities_moved_off.size():
        var e = entities_moved_off[i]
        resolve_entity_interaction_event("post_move_off_of", e, moving_entity, entities_moved_off_at[i])
    
    var entities_moved_onto: Array = []
    var entities_moved_onto_at: Array = []
    for moved_onto_position in moved_onto_positions:
        for entity_there in get_entities_at(moved_onto_position, moving_entity, exclude_group):
            if not entity_there in entities_moved_onto:
                entities_moved_onto.append(entity_there)
                entities_moved_onto_at.append(moved_onto_position)
    for i in entities_moved_onto.size():
        var e = entities_moved_onto[i]
        resolve_entity_interaction_event("post_move_onto", e, moving_entity, entities_moved_onto_at[i])

func can_move_to(moving_entity, tile_position) -> bool:
    var entities_here = get_entities_at(tile_position, moving_entity)
    for e in entities_here:
        var blocks: = get_entity_property(e, "blocks")
        if blocks:
            if blocks.is_conditional():
                if blocks.resolve(e, moving_entity, tile_position):
                    return false
            else:
                if blocks.get_value():
                    return false
    return true

func set_entity_property(entity, property_name, property_value) -> void:
    entity.set_local_property(property_name, property_value)

func get_entity_property(entity, property_name) -> Property:
    var value = null
    if not entity.has_local_property(property_name):
        var def_props = entity_defs[entity.entity_index]["properties"]
        if property_name in def_props:
            value = def_props[property_name]
        elif "inherit_properties" in def_props:
            var inherit_from = get_entity_index(def_props["inherit_properties"])
            var inherit_props = entity_defs[inherit_from]["properties"]
            if not property_name in inherit_props:
                return null
            value = inherit_props[property_name]
        else:
            return null
    else:
        value = entity.get_local_property(property_name)
    var property = Property.new()
    property.set_value(value)
    property.set_name(property_name)
    return property

func get_entity_prop_with_default(entity, property_name, default_value) -> Variant:
    if not entity_has_property(entity, property_name):
        return default_value
    var prop: Property = get_entity_property(entity, property_name)
    if prop.is_conditional():
        return prop.resolve(entity, null, entity.tile_position)
    else:
        return prop.get_value()

func entity_has_property(entity, property_name: String) -> bool:
    var entity_props = entity_defs[entity.entity_index]["properties"]
    var has = entity.has_local_property(property_name) 
    has = has or property_name in entity_props
    if "inherit_properties" in entity_props:
        var from = get_entity_index(entity_props["inherit_properties"])
        has = has or property_name in entity_defs[from]["properties"]
    return has

func get_entity_property_list(entity) -> Array:
    var props: Dictionary = {}
    var definition_props = entity_defs[entity.entity_index]["properties"]
    Utility.set_keys(props, definition_props.keys())
    Utility.set_keys(props, entity.local_properties.keys())
    if "inherit_properties" in definition_props:
        var inherit_from = get_entity_index(definition_props["inherit_properties"])
        Utility.set_keys(props, entity_defs[inherit_from]["properties"].keys())
    
    return props.keys()

func get_entity_definition(entity_index) -> Dictionary:
    return entity_defs[entity_index].duplicate(true)

func remove_entity_definition(entity_index) -> void:
    erase_all_entities_with_id(entity_index)
    var entity_name = entity_defs[entity_index]["name"]
    entity_index_map.erase(entity_name)
    entity_defs.erase(entity_index)

func erase_all_entities_with_id(entity_index) -> void:
    for entity in entity_list:
        if entity.entity_index == entity_index:
            remove_entity(entity)

func remove_entity(entity) -> void:
    if entity in entity_signal_connections:
        for connected_sig in entity_signal_connections.get(entity, []):
            var signal_connections = get_signal_connection_list(connected_sig)
            for sig_conn in signal_connections:
                if (sig_conn.callable as Callable).get_object() == entity:
                    sig_conn.signal.disconnect(sig_conn.callable)
        entity_signal_connections.erase(entity)
    entity_list.erase(entity)
    if entity.bond_group:
        unbond_entity(entity)
    entity.remove_from_group("_entity_")
    entity.set_active(false)
    entity.call_deferred("queue_free")
    
    on_entity_list_changed()

func get_all_entity_indexes() -> Array:
    var keys = entity_defs.keys()
    keys.sort()
    return keys

func get_entity_index(entity_name) -> int:
    return entity_index_map[entity_name]

func entity_name_exists(entity_name) -> bool:
    return entity_name in entity_index_map

func get_entity_name(entity_index) -> String:
    return entity_defs[entity_index]['name']

func get_all_entity_names() -> Array[String]:
    var names: Array[String] = []
    for e in entity_defs.values():
        var e_name: String = e["name"]
        if not e_name in names:
            names.append(e_name)
    return names

func is_valid_entity(entity: Object) -> bool:
    if not entity or not is_instance_valid(entity):
        return false
    return entity is BaseEntity

func is_valid_entity_in_world(entity: Object) -> bool:
    if not is_valid_entity(entity):
        return false
    return entity in entity_list