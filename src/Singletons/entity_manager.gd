extends Node

signal entity_preview_mode_changed(enable_preview: bool)
signal entity_list_updated
signal entity_became_active(entity: BaseEntity)
signal post_deserialize

var entity_template: = preload("res://Scenes/BaseEntity.tscn")
var large_entity_template: = preload("res://Scenes/LargeEntity.tscn")
var controller_templates: = {
    "InputController": preload("res://Scenes/Controllers/InputController.tscn"),
    "BounceController": preload("res://Scenes/Controllers/BounceController.tscn"),
    "creature_controller": preload("res://Scenes/Controllers/creature_controller.tscn"),
    "random_creature_controller": preload("res://Scenes/Controllers/random_creature_controller.tscn"),
    "direct_chase_controller": preload("res://Scenes/Controllers/direct_chase_controller.tscn"),
}

var entity_defs: Dictionary = {
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
@onready var loaded_entity_defs: = entity_defs

var entity_index_map: = {}
var entity_instance_map: = {}

var entity_sprite_snapshots: Dictionary[int, ImageTexture] = {}

var entity_signal_connections: = {}

var entity_list: Array = []
var bond_groups: Array = []
var _pending_half_move_actions: Array[BaseEntity] = []

var im_ready: = false

var instance_counter: int = 0

var frame_counter: int = 0

var movements_enabled: bool = true
var turn_requested: bool = false
var requested_turn_frames: int = 0
var turn_frames_remaining = 0
var controller_frame: bool = true
var movement_mode: int

var default_move_speed: float = 6
var default_idle_delay: float = 1/10.0
var idle_delay_frames: int = -1

var actions_only_for_camera_target: bool = false

var default_move_interp_style: BaseEntity.MoveInterpStyle = BaseEntity.MoveInterpStyle.CONTINUOUS_LINEAR

var process_phase: int = 0

var is_entity_preview_mode: bool = false

func paused_visual_process() -> void:
    for e in entity_list:
        e.sprite_process()

func entity_list_process() -> void:
    var active_entities: Array[BaseEntity] = []
    var moving_entities: Array[BaseEntity] = []
    var idle_entities: Array[BaseEntity] = []
    
    var new_action_activations: Array[String] = []
    for action_num in ["1", "2", "3"]:
        if Input.is_action_just_pressed("input_action_" + action_num):
            new_action_activations.append("do_action_" + action_num)
    
    # Phased processing so each entity completes a phase before any entity processes the next phase
    
    # Phase 1 - Starting movement and start of move actions
    process_phase = 1
    for e in entity_list:
        if e.active:
            active_entities.append(e)
            if new_action_activations:
                e.got_action_signals(new_action_activations)
            e.entity_process_starting_actions()
            if e.moving:
                moving_entities.append(e)
            else:
                idle_entities.append(e)
        e.sprite_process()
    
    # Phase 2 - Update idle tick counter (for non-moving) and idle actions
    process_phase = 2
    for e in idle_entities:
        if e.active:
            e.idle_ticks_elapsed += 1
    for e in idle_entities:
        if e.active and e.idle_ticks_elapsed >= idle_delay_frames:
            MapManager.entity_idle_actions(e)
            e.entity_process_idle_actions()
            e.idle_ticks_elapsed = 0
    if frame_counter % idle_delay_frames == 0:
        MapManager.idle_actions()
    
    # Phase 3 - Moving progress and mid-move actions
    # if an entity starts moving during this phase it will not be processed as moving until the next tick
    process_phase = 3
    var entities_that_finished_moving: Array[BaseEntity] = []
    _pending_half_move_actions.clear()
    for e in moving_entities:
        if e.active:
            e.idle_ticks_elapsed = 0
            e.entity_process_moving_actions()
            if not e.moving:
                entities_that_finished_moving.append(e)
    if _pending_half_move_actions:
        process_half_moves()
    
    # Phase 4 - All entities moved for the frame, now process actions resulting from completed moves
    process_phase = 4
    for e in entities_that_finished_moving:
        if e.active:
            e.process_finish_move()
    
    process_phase = 0

func queue_half_move_actions_for(entity: BaseEntity) -> void:
    if process_phase != 3:
        push_error("ERROR: tried to queue half move actions for an entity outside of the moving phase")
        return
    _pending_half_move_actions.append(entity)

func should_bump_move() -> bool:
    return false
    #return process_phase >= 3

func _physics_process(_delta):
    entity_list_process()

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
    #preload_controller_templates()
    process_physics_priority = 10
    if not GameManager.is_node_ready():
        await GameManager.ready
    idle_delay_frames = roundi(default_idle_delay * GameManager.get_tick_rate())
    
    GameManager.game_settings_changed.connect(on_game_settings_changed)

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

func do_emit_signal(signal_name: String, owning_entity: BaseEntity = null, args: Array = []) -> void:
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
    fix_int_property_vals()
    create_index_map()
    create_defined_custom_signals()
    
    actions_only_for_camera_target = GameManager.get_game_setting("action_signal_sent_to", "all_entities") != "camera_target"

func on_game_settings_changed():
    update_movement_mode()

func update_movement_mode():
    movement_mode = GameManager.get_game_setting("movement_mode", GameManager.MovementMode.MOVEMENT_CONTINUOUS)
    
    if movement_mode == GameManager.MovementMode.MOVEMENT_CONTINUOUS:
        controller_frame = true
        movements_enabled = true
    else:
        controller_frame = false
        movements_enabled = false
    
    var def_move_interp_string: = GameManager.get_game_setting("default_move_interp", "") as String
    if not def_move_interp_string:
        default_move_interp_style = BaseEntity.MoveInterpStyle.CONTINUOUS_LINEAR
    else:
        default_move_interp_style = BaseEntity.read_move_interp_style_string(def_move_interp_string)
    
    #print_debug("MOVEMENT MODE is now " + GameManager.describe_movement_mode(movement_mode))

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

func fix_int_property_vals():
    for entity_id in entity_defs.keys():
        var entity_props: Dictionary = entity_defs[entity_id].get("properties", {})
        for prop_name in entity_props.keys():
            if typeof(entity_props[prop_name]) == TYPE_FLOAT and Utility.is_float_integer(entity_props[prop_name]):
                entity_props[prop_name] = int(entity_props[prop_name])

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

func clear():
    clear_entity_list()
    turn_requested = false
    update_movement_mode()
    process_phase = 0

func clear_entity_list():
    disconnect_all_custom_signals()
    for entity in entity_list:
        if not entity:
            continue
        entity.remove_from_group("_entity_")
        set_entity_active(entity, false)
        entity.queue_free()
    entity_list = []
    entity_instance_map = {}
    clear_bond_groups()

func clear_bond_groups():
    bond_groups = []

# In discrete mode we wont update entities at all until a move is requested
func request_move(entity: BaseEntity, request_frames: int = -1) -> void:
    if movement_mode == GameManager.MovementMode.MOVEMENT_CONTINUOUS:
        return
    if movement_mode == GameManager.MovementMode.MOVEMENT_DISCRETE:
        if request_frames:
            requested_turn_frames = request_frames
        elif entity:
            requested_turn_frames = entity.get_steps_per_tile()
        else:
            requested_turn_frames = idle_delay_frames
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
    create_entity_contain_insensitive("player", Vector2i(2, 2), true)
    create_entity_contain_insensitive("box", Vector2i(3, 2))
    
func create_randoms() -> void:
    create_entity_contain_insensitive("player", Vector2i(2, 2), true)
    create_random_entity("green_box")
    create_random_entity("swap_box")
    create_random_entity("bouncer")

func _get_museum_entity_ids() -> Array[int]:
    var entity_ids: Array[int] = []
    for entity_id in entity_defs:
        if entity_defs[entity_id].get("no-museum", false):
            continue
        entity_ids.append(entity_id)
    return entity_ids

func is_entity_id_museum_active(entity_id: int) -> bool:
    if entity_defs[entity_id].has("museum-active"):
        return true if entity_defs[entity_id]["museum-active"] else false
    return GameManager.get_game_setting("museum_all_without_controller_active", true) and not entity_id_has_controller(entity_id)

func create_museum(player_pos: Vector2i, museum_start_pos: Vector2i, museum_spacing: Vector2i) -> Vector2i:
    if entity_defs.size() < 1:
        return Vector2i.ZERO
    if museum_spacing.x == 0: museum_spacing.x = 1
    if museum_spacing.y == 0: museum_spacing.y = 1

    var rows: int = 4
    var default_row_width: int = 5
    
    var entity_ids: = _get_museum_entity_ids()
    var num_entities: int = entity_ids.size()
    rows = mini(rows, ceili(num_entities / float(default_row_width)))
    var per_row: int = ceili(num_entities / float(rows))
    
    var label_offset: = Vector2.UP * MapManager.tile_width * 0.25
    for i in num_entities:
        var e_id = entity_ids[i]
        var row_col: = Vector2i(i % per_row, floori(i / float(per_row)))
        var at_tile_pos: = museum_start_pos + row_col * museum_spacing
        
        create_entity(e_id, at_tile_pos, 0, is_entity_id_museum_active(e_id))
        
        # Labels
        var e_name: = get_entity_name(e_id)
        MapManager.create_persistant_text_effect(e_name, at_tile_pos + Vector2i.DOWN, label_offset, -2)
    
    create_entity_contain_insensitive("player", player_pos, true)
    
    return museum_spacing.sign() + Vector2i(per_row - 1, rows - 1) * museum_spacing

func create_entity_contain_insensitive(partial_name: String, at_pos: Vector2i, or_first_entity: bool = false) -> void:
    if entity_defs.size() < 1:
        return
    var found_index = _get_entity_index_name_insensitive(partial_name)
    if found_index == -1 and or_first_entity:
        found_index = entity_defs.keys()[0]
    if found_index != -1:
        create_entity(found_index, at_pos)

func _get_entity_index_name_insensitive(partial_name: String) -> int:
    partial_name = partial_name.to_lower()
    for entity_index in entity_defs.keys():
        if entity_defs[entity_index]["name"].to_lower().contains(partial_name):
            return entity_index
    return -1

func create_random_entity(entity_name) -> void:
    var found_index = _get_entity_index_name_insensitive(entity_name)
    if found_index == -1:
        return

    var tries = 20
    while tries > 0:
        tries -= 1
        var entity_pos = Vector2(Utility.random_int_range(1, 11), Utility.random_int_range(1, 11))
        if MapManager.is_blocked(entity_pos):
            continue
        create_entity(get_entity_index(entity_name), entity_pos)
        break

func get_entity_texture(entity_index: int, preview: bool = false):
    if not preview or entity_defs[entity_index].get("preview_variant", {}).is_empty():
        return TextureManager.get_texture(entity_defs[entity_index]['texture'])
    else:
        return TextureManager.get_texture(entity_defs[entity_index]['preview_variant']['texture'])

func get_entity_texture_rect(entity_index: int, preview: bool = false):
    var tex_from: Dictionary = entity_defs[entity_index]
    if preview and tex_from.get("preview_variant", {}):
        tex_from = tex_from["preview_variant"]
    return TextureManager.get_index_rect(tex_from['texture'], tex_from['tex_index'])

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

func reset_entity_move_interp_style(entity: BaseEntity) -> void:
    entity.move_interp_style = default_move_interp_style
    var base_props: Dictionary = entity_defs[entity.entity_index]["properties"]
    if "move-animation" in base_props:
        var def: = BaseEntity.MoveInterpStyle.NONE
        var move_interp_str: Variant = get_entity_prop_with_default(entity, "move-animation", def)
        if move_interp_str:
            entity.move_interp_style = BaseEntity.read_move_interp_style_string(str(move_interp_str))
        else:
            entity.move_interp_style = default_move_interp_style

func create_entity(entity_index: int, tile_position: Vector2i, facing: int = 0, activate: bool = true) -> Node2D:
    var entity_info = entity_defs[entity_index]
    
    var entity: BaseEntity
    if "entity_type" in entity_info:
        entity = large_entity_template.instantiate()
    else: 
        entity = entity_template.instantiate()


    entity.entity_index = entity_index
    entity.instance_id = instance_counter
    instance_counter += 1
    
    reset_entity_move_interp_style(entity)

    entity.update_cached_spt()

    setup_entity_controller(entity)
    entity.position = MapManager.tile_to_world_position(tile_position)
    entity.tile_position = tile_position
    entity.next_tile_pos = tile_position
    add_entity_to_world(entity)
    entity.initialize()
    setup_entity_texture(entity)
    
    entity.set_move_facing(facing)
    if entity.visual_turn_on_move:
        entity.set_facing(facing)
    
    if "groups" in entity_info:
        for g in entity_info["groups"]:
            entity.add_to_group(g)
    
    auto_bond_handler(entity)
    auto_tail_handler(entity)
    
    entity.active = activate
    on_entity_added(entity)
    
    if activate:
        post_activated_actions(entity)
    
    MapManager.check_terrain_spr_mod_for_created(entity)
    
    return entity

func post_activated_actions(entity: BaseEntity) -> void:
    if not entity.active:
        return
    var at_pos: = entity.get_stationary_position()
    var sitting_on_entities: Array = get_entities_at(at_pos, entity)
    for e in sitting_on_entities:
        resolve_entity_interaction_old("i_finish_move_onto", entity, e, at_pos)
    if not entity.active:
        return
    for e in sitting_on_entities:
        resolve_entity_interaction_old("finish_move_onto", e, entity, at_pos)

func entity_id_has_controller(entity_id: int) -> bool:
    var controller_name: String = entity_defs[entity_id].get("controller", "")
    if controller_name and controller_name in controller_templates:
        return true
    return false

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
    
    var looking_at_tile = entity.tile_position + Utility.facing_vector_i(entity.facing)
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
    
    entity.entity_index = int(serialized_entity['entity_index'])
    entity.pre_init()
    entity.deserialize(serialized_entity)
    add_entity_to_world(entity)
    entity.initialize() # initialize after deserializing
    
    reset_entity_move_interp_style(entity)
    setup_entity_texture(entity)
    
    MapManager.check_terrain_spr_mod_for_created(entity)
    
    if refresh:
        refresh_entity_list()

func setup_entity_texture(entity: BaseEntity) -> void:
    var texture_index = entity_defs[entity.entity_index]['texture']
    var texture_sub_index = entity_defs[entity.entity_index]['tex_index']
    var sprite_config: Dictionary = entity_defs[entity.entity_index].get("sprite_config", {})

    var sprite: MaskLayerSprite = entity.sprite
    if sprite_config and sprite_config.get("layers", []):
        sprite.set_main_layers(sprite_config["layers"])
    else:
        sprite.set_as_single(texture_index, texture_sub_index)

    if entity_defs[entity.entity_index].get("preview_variant", {}):
        sprite.set_preview_info(entity_defs[entity.entity_index]["preview_variant"])

func serialize() -> Dictionary:
    var serialized_entities: Array = []
    for e in entity_list:
        serialized_entities.append(e.serialize())
    
    return {"entity_list": serialized_entities, "bond_groups": bond_groups.duplicate_deep()}

func deserialize(data: Dictionary) -> void:
    clear()
    bond_groups = data["bond_groups"].duplicate_deep()
    for entity_data in data["entity_list"]:
        restore_entity(entity_data)
    refresh_entity_list()
    instance_counter = 0
    for e in entity_list:
        instance_counter = maxi(instance_counter, e.instance_id + 1)
    
    post_deserialize.emit()

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
        entity.set_steps_per_tile_override(steps_per_tile)
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

func get_entities_at(tile_position: Vector2i, exclude_entity: Object = null, exclude_list: Array = [], include_moving_away: bool = false, include_inactive: bool = false) -> Array:
    var entities_here: Array = []
    for e in entity_list:
        if not include_inactive and not e.active:
            continue
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

func get_entities_half_at(tile_pos: Vector2i, exclude_entity: Object = null, exclude_list: Array = [], include_inactive: bool = false) -> Array:
    var entities_here: Array = []
    for e in entity_list:
        if not include_inactive and not e.active:
            continue
        if e == exclude_entity or (exclude_list and e.instance_id in exclude_list):
            continue
        if e.get_half_moved_position() == tile_pos:
            entities_here.append(e)
    return entities_here

func get_entities_at_multiple(tile_positions: Array, exclude_entity: Object = null, exclude_list: Array = [], include_moving_away: bool = false, include_inactive: bool = false) -> Array:
    var entities_here: Array = []
    for e in entity_list:
        if not include_inactive and not e.active:
            continue
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

func find_all_entities_by_index(entity_index: int, active_only: bool = false) -> Array[BaseEntity]:
    var entities: Array[BaseEntity] = []
    for i in entity_list:
        if i.entity_index == entity_index and (not active_only or i.active):
            entities.append(i)
    return entities

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

func find_all_entities_with_truthy_property(prop_name: String, active_only: bool = false, invert: bool = false) -> Array[BaseEntity]:
    var found_entities: Array[BaseEntity] = []
    for i in entity_list:
        if (not active_only or i.active) and get_entity_prop_with_default(i, prop_name, false) != invert:
            found_entities.append(i)
    return found_entities

func find_closest_entity_with_property(prop_name: String, from_position: Vector2i, exclude_list: Array = [], include_inactive: bool = false) -> BaseEntity:
    var closest_dist: float = -1
    var closest_entity: BaseEntity = null
    for entity in entity_list:
        if not include_inactive and not entity.active:
            continue
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
    if not moving_entity.active:
        return
    moving_entity.process_deferred_signals()

    var entities_here: Array = []
    var entities_overlapped_at: Array = []
    for onto_position in onto_positions:
        for entity_here in get_entities_at(onto_position, moving_entity):
            if not entity_here in entities_here:
                entities_here.append(entity_here)
                entities_overlapped_at.append(onto_position)

    for i in entities_here.size():
        resolve_entity_interaction_old("i_finish_move_onto", moving_entity, entities_here[i], entities_overlapped_at[i])
    if not moving_entity.active:
        return
    for i in entities_here.size():
        resolve_entity_interaction_old("finish_move_onto", entities_here[i], moving_entity, entities_overlapped_at[i])

func resolve_entity_interaction_old(event_name: String, actor, interactee, at_tile_position: Vector2i, extra_debug: bool = false) -> void:
    resolve_entity_interaction_event(event_name, actor, interactee, [at_tile_position], extra_debug)

func resolve_entity_interaction_event(event_name: String, actor, interactee, at_tile_positions: Array[Vector2i], extra_debug: bool = false) -> void:
    var event_prop: = get_entity_property(actor, event_name)
    if event_prop and event_prop.is_conditional():
        event_prop.resolve(actor, interactee, at_tile_positions, [], extra_debug)

func conditional_entity_interaction(event_name: String, actor: BaseEntity, interactee: BaseEntity, at_tile_positions: Array[Vector2i], defaut_result: bool = true, extra_debug: bool = false) -> bool:
    var event_prop: = get_entity_property(actor, event_name)
    if not event_prop:
        return defaut_result
    return Property.resolve_truthy(event_prop, actor, interactee, at_tile_positions, [], extra_debug)

func attempt_move_leave(moving_entity: BaseEntity, leaving_ps: Array[Vector2i], skip_entity_inst_ids: Array[int] = [], is_group_move: bool = false) -> bool:
    var result: = true
    if not conditional_entity_interaction("i_move_off_of_tile", moving_entity, null, leaving_ps, true):
        result = false
    
    if is_group_move:
        skip_entity_inst_ids = moving_entity.bond_group.duplicate()
    var entities_here: = get_entities_at_multiple(leaving_ps, moving_entity, skip_entity_inst_ids)
    for e in entities_here:
        skip_entity_inst_ids.append(e.instance_id)
        if not conditional_entity_interaction("move_off_of", e, moving_entity, leaving_ps, true):
            result = false
    return result

func attempt_move_enter(moving_entity: BaseEntity, tile_move_allowed: bool, entering_ps: Array[Vector2i], skip_entity_inst_ids: Array[int]) -> bool:
    var result: = tile_move_allowed
    var entities_there: = get_entities_at_multiple(entering_ps, moving_entity, skip_entity_inst_ids)
    for e in entities_there.duplicate():
        if conditional_entity_interaction("blocks", e, moving_entity, entering_ps, false):
            result = false
    # Skip move_onto checks if anything before blocked movement
    if not result:
        return false

    if not conditional_entity_interaction("i_move_onto_tile", moving_entity, null, entering_ps, true):
        result = false
    
    for e in entities_there:
        if not conditional_entity_interaction("i_move_onto", moving_entity, e, entering_ps, true):
            result = false
    for e in entities_there:
        if not conditional_entity_interaction("move_onto", e, moving_entity, entering_ps, true):
            result = false
    return result

func process_half_moves() -> void:
    var half_moved_at_positions: Dictionary[Vector2i, Dictionary] = {}
    for entity in _pending_half_move_actions:
        if not entity.active:
            continue
        entity._pending_half_move = false
        var from_pos: = entity.get_stationary_position()
        if not from_pos in half_moved_at_positions:
            half_moved_at_positions[from_pos] = {"leaving": [], "entering": []}
        half_moved_at_positions[from_pos]["leaving"].append(entity)
        var to_pos: = entity.get_moving_position()
        if not to_pos in half_moved_at_positions:
            half_moved_at_positions[to_pos] = {"leaving": [], "entering": []}
        half_moved_at_positions[to_pos]["entering"].append(entity)

    for hm_pos in half_moved_at_positions:
        half_moved_at_positions[hm_pos]["other_entities"] = get_entities_half_at(hm_pos, null, half_moved_at_positions[hm_pos]["entering"])
        if half_moved_at_positions[hm_pos]["leaving"].size() > 0:
            half_moved_leaving_at(hm_pos, half_moved_at_positions[hm_pos]["leaving"], half_moved_at_positions[hm_pos]["other_entities"])
            MapManager.half_moved_leaving_at(hm_pos, half_moved_at_positions[hm_pos]["leaving"])
    
    for hm_pos in half_moved_at_positions:
        if half_moved_at_positions[hm_pos]["entering"].size() > 0:
            half_moved_entering_at(hm_pos, half_moved_at_positions[hm_pos]["entering"], half_moved_at_positions[hm_pos]["other_entities"])
            MapManager.half_moved_entering_at(hm_pos, half_moved_at_positions[hm_pos]["entering"])
    
    # TODO handle covered tracking here
    
# symmetrical event processing for half-move changes

func half_moved_leaving_at(at_position: Vector2i, leaving_entities: Array, other_entities: Array) -> void:
    for i in leaving_entities.size():
        var entity: BaseEntity = leaving_entities[i]
        var interacted: Array[BaseEntity] = []
        for other_entity: BaseEntity in other_entities:
            resolve_entity_interaction_old("half_moved_off_of", entity, other_entity, at_position)

            interacted.append(other_entity)
        var to_pos: = entity.get_moving_position()
        for j in leaving_entities.size() - 1 - i:
            var other_entity: BaseEntity = leaving_entities[j]
            if other_entity.get_moving_position() == to_pos:
                continue
            resolve_entity_interaction_old("half_moved_off_of", entity, other_entity, at_position)
            interacted.append(other_entity)
        
        for other_entity: BaseEntity in interacted:
            resolve_entity_interaction_old("half_moved_off_of", other_entity, entity, at_position)

func half_moved_entering_at(at_position: Vector2i, entering_entities: Array, other_entities: Array) -> void:
    for i in entering_entities.size():
        var entity: BaseEntity = entering_entities[i]
        var interacted: Array[BaseEntity] = []
        for other_entity: BaseEntity in other_entities:
            resolve_entity_interaction_old("half_moved_onto", entity, other_entity, at_position)
            interacted.append(other_entity)
        var from_pos: = entity.get_stationary_position()
        for j in entering_entities.size() - 1 - i:
            var other_entity: BaseEntity = entering_entities[j]
            if other_entity.get_stationary_position() == from_pos:
                continue
            resolve_entity_interaction_old("half_moved_onto", entity, other_entity, at_position)
            interacted.append(other_entity)
        
        for other_entity: BaseEntity in interacted:
            resolve_entity_interaction_old("half_moved_onto", other_entity, entity, at_position)

func post_move_actions(moving_entity, from_position, to_position, exclude_group: Array = []) -> void:
    if not moving_entity.active:
        return

    var entities_at_start_pos = get_entities_at(from_position, moving_entity, exclude_group)
    for e in entities_at_start_pos:
        resolve_entity_interaction_old("post_move_off_of", e, moving_entity, from_position)
    if not moving_entity.active:
        return
    
    var entities_destination = get_entities_at(to_position, moving_entity, exclude_group)
    for e in entities_destination:
        resolve_entity_interaction_old("post_move_onto", e, moving_entity, to_position)
    if not moving_entity.active:
        return
    
    MapManager.post_move_actions(moving_entity, from_position, to_position)

func post_die_actions(dying_entity: BaseEntity) -> void:
    if not dying_entity.moving:
        var at_pos: = dying_entity.get_stationary_position()
        var sitting_on_entities: Array = get_entities_at(at_pos, dying_entity)
        for e in sitting_on_entities:
            resolve_entity_interaction_old("post_move_off_of", e, dying_entity, at_pos)

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
        resolve_entity_interaction_old("post_move_off_of", e, moving_entity, entities_moved_off_at[i])
    
    var entities_moved_onto: Array = []
    var entities_moved_onto_at: Array = []
    for moved_onto_position in moved_onto_positions:
        for entity_there in get_entities_at(moved_onto_position, moving_entity, exclude_group):
            if not entity_there in entities_moved_onto:
                entities_moved_onto.append(entity_there)
                entities_moved_onto_at.append(moved_onto_position)
    for i in entities_moved_onto.size():
        var e = entities_moved_onto[i]
        resolve_entity_interaction_old("post_move_onto", e, moving_entity, entities_moved_onto_at[i])

func can_move_to(moving_entity: BaseEntity, tile_position: Vector2i) -> bool:
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

func set_entity_property(entity: BaseEntity, property_name: String, property_value: Variant) -> void:
    entity.set_local_property(property_name, property_value)

func remove_entity_property(entity: BaseEntity, property_name: String) -> void:
    entity.remove_local_property(property_name)

func get_entity_property(entity: BaseEntity, property_name: String) -> Property:
    if entity.is_property_removed(property_name):
        return null
    var raw_property_val: Variant = null
    if entity.has_local_property(property_name):
        raw_property_val = entity.get_local_property(property_name)
    else:
        var def_props = entity_defs[entity.entity_index]["properties"]
        if property_name in def_props:
            raw_property_val = def_props[property_name]
        elif "inherit_properties" in def_props:
            var inherit_from: = get_entity_index(def_props["inherit_properties"])
            var inherit_props: Dictionary = entity_defs[inherit_from]["properties"]
            if not property_name in inherit_props:
                return null
            raw_property_val = inherit_props[property_name]
        else:
            return null
    var property = Property.new()
    property.set_value(raw_property_val)
    property.set_name(property_name)
    return property

func get_entity_prop_with_default(entity: BaseEntity, property_name: String, default_value: Variant) -> Variant:
    if not entity_has_property(entity, property_name):
        return default_value
    var prop: Property = get_entity_property(entity, property_name)
    if prop.is_conditional():
        return prop.resolve(entity, null, [entity.get_moving_position()])
    else:
        return prop.get_value()

func get_entity_prop_text_value(entity: BaseEntity, property_name: String, default_value: String = "") -> String:
    if not entity_has_property(entity, property_name):
        return default_value
    var prop: Property = get_entity_property(entity, property_name)
    var prop_value: Variant = prop.get_or_resolve(entity, null, entity.tile_position)
    if typeof(prop_value) == TYPE_STRING and prop_value == "":
        return default_value
    return Utility.property_value_nonempty_string(prop_value, default_value)

func get_entity_prop_scalar_value(entity: BaseEntity, property_name: String, default_value: float = 0.0) -> float:
    if not entity_has_property(entity, property_name):
        return default_value
    var prop: Property = get_entity_property(entity, property_name)
    var prop_value: Variant = prop.get_or_resolve(entity, null, entity.tile_position)
    return Utility.property_value_scalar(prop_value, default_value)

func get_entity_prop_is_truthy(entity: BaseEntity, property_name: String, default_val: bool = false) -> bool:
    if not entity_has_property(entity, property_name):
        return default_val
    return Property.resolve_truthy(get_entity_property(entity, property_name), entity, null, entity.tile_position)

func entity_has_property(entity: BaseEntity, property_name: String) -> bool:
    if not entity:
        return false
    if entity.is_property_removed(property_name):
        return false

    var entity_props: Dictionary = entity_defs[entity.entity_index]["properties"]
    var has = entity.has_local_property(property_name) 
    has = has or property_name in entity_props
    if "inherit_properties" in entity_props:
        var from = get_entity_index(entity_props["inherit_properties"])
        has = has or property_name in entity_defs[from]["properties"]
    return has

func get_entity_property_list(entity: BaseEntity) -> Array:
    var props: Dictionary = {}
    var definition_props = entity_defs[entity.entity_index]["properties"]
    Utility.set_keys(props, definition_props.keys())
    Utility.set_keys(props, entity.local_properties.keys())
    if "inherit_properties" in definition_props:
        var inherit_from = get_entity_index(definition_props["inherit_properties"])
        Utility.set_keys(props, entity_defs[inherit_from]["properties"].keys())
    for removed_prop in entity.removed_properties:
        props.erase(removed_prop)
    
    return props.keys()

func get_entity_definition(entity_index: int) -> Dictionary:
    return entity_defs[entity_index].duplicate(true)

func remove_entity_definition(entity_index: int) -> void:
    erase_all_entities_with_id(entity_index)
    var entity_name = entity_defs[entity_index]["name"]
    entity_index_map.erase(entity_name)
    entity_defs.erase(entity_index)

func erase_all_entities_with_id(entity_index: int) -> void:
    for entity in entity_list:
        if entity.entity_index == entity_index:
            remove_entity(entity)

func remove_entity(entity: BaseEntity) -> void:
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

func get_entity_index(entity_name: String) -> int:
    return entity_index_map[entity_name]

func entity_name_exists(entity_name: String) -> bool:
    return entity_name in entity_index_map

func get_entity_name(entity_index: int) -> String:
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

func get_pos_above(entity: BaseEntity) -> Vector2i:
    var entity_pos: = entity.get_center_position()
    return entity_pos + Vector2.UP * (entity.get_half_size().y + MapManager.tile_width * 0.25)

func get_default_spt() -> int:
    return BaseEntity._speed_to_spt(default_move_speed)

func switch_entities_preview_mode(enable_preview: bool) -> void:
    is_entity_preview_mode = enable_preview
    entity_preview_mode_changed.emit(enable_preview)

func save_entity_sprite_snapshot(entity_index: int, snapshot: ImageTexture) -> void:
    entity_sprite_snapshots[entity_index] = snapshot

func entity_has_preview_variant(entity_index: int) -> bool:
    return not entity_defs[entity_index].get("preview_variant", {}).is_empty()

func get_entity_sprite_snapshot(entity_index: int, preview: bool = false) -> Texture2D:
    if not entity_sprite_snapshots.has(entity_index) or (entity_has_preview_variant(entity_index) and preview):
        return Utility.atlas_texture_from_entity_index(entity_index, preview)
    else:
        return entity_sprite_snapshots[entity_index]

func get_entity_sprite_snapshot_scale(entity_index: int, preview: bool = false, for_ui: bool = true) -> float:
    if not entity_sprite_snapshots.has(entity_index) or (entity_has_preview_variant(entity_index) and preview):
        return GameManager.get_default_pixel_scale() if for_ui else 1.0
    else:
        return 1.0 if for_ui else 1.0 / GameManager.get_default_pixel_scale()

func set_entity_active(entity: BaseEntity, new_is_active: bool) -> void:
    entity.active = new_is_active
    if new_is_active:
        post_activated_actions(entity)
        entity_became_active.emit(entity)

func get_all_active_entities() -> Array[BaseEntity]:
    var active_entities: Array[BaseEntity] = []
    for entity in entity_list:
        if entity.active:
            active_entities.append(entity)
    return active_entities