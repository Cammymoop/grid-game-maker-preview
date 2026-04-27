extends Node

signal initial_sprite_previews_finished

const SpritePreviewer: = preload("res://Scenes/GameEditor/sprite_previewer.gd")
const sprite_previewer_scene: = preload("res://Scenes/GameEditor/sprite_previewer.tscn")

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

var entity_defs: Dictionary = {}
@onready var loaded_entity_defs: = entity_defs

var entity_index_map: = {}
var entity_instance_map: = {}

var entity_sprite_snapshots: Dictionary[int, ImageTexture] = {}
var entity_sprite_snapshot_scales: Dictionary[int, float] = {}

var entity_signal_connections: = {}

var entity_list: Array = []
var bond_groups: Array = []
var _pending_half_move_actions: Array[BaseEntity] = []

var initial_sprite_previews_created: bool = false
var im_ready: = false

var instance_counter: int = 0

var frame_counter: int = 0
var animation_frame_counter: int = 0

var movements_enabled: bool = true
var turn_requested: bool = false
var requested_turn_frames: int = 0
var turn_frames_remaining = 0
var controller_frame: bool = true
var movement_mode: int

var default_move_speed: float = 6
var default_teleport_duration: float = 1/6.0
var default_idle_delay: float = 1/10.0
var idle_delay_frames: int = -1

var actions_only_for_camera_target: bool = false

var default_move_interp_style: Utility.PosInterpStyle = Utility.PosInterpStyle.CONTINUOUS_LINEAR
var default_teleport_interp_style: Utility.PosInterpStyle = Utility.PosInterpStyle.NONE

var process_phase: int = 0

var is_entity_preview_mode: bool = false

var timed_entity_events: Dictionary[int, Array] = {}

func paused_visual_process(delta_time: float) -> void:
    for e in entity_list:
        e.sprite_process(delta_time)

func entity_list_process(delta_time: float) -> void:
    var active_entities: Array[BaseEntity] = []
    var moving_entities: Array[BaseEntity] = []
    var idle_entities: Array[BaseEntity] = []
    
    var new_action_activations: Array[String] = []
    for action_num in ["1", "2", "3"]:
        if Input.is_action_just_pressed("input_action_" + action_num):
            new_action_activations.append("do_action_" + action_num)
    
    # Phased processing so each entity completes a phase before any entity processes the next phase
    
    # Phase 1 - Timed entity events, Starting movement and start of move actions
    process_phase = 1
    for e in entity_list:
        var events_this_tick: Array[Dictionary] = []
        if e.instance_id in timed_entity_events.keys():
            var pending_events: Array[Dictionary] = []
            for event_info in timed_entity_events[e.instance_id]:
                var relevant_tick_counter: int = frame_counter
                if event_info.get("is_animation_tick", true):
                    relevant_tick_counter = animation_frame_counter
                if event_info["timeout_tick"] < relevant_tick_counter:
                    continue
                elif event_info["timeout_tick"] > relevant_tick_counter:
                    pending_events.append(event_info)
                else:
                    events_this_tick.append(event_info)
            timed_entity_events[e.instance_id] = pending_events

        if e.active:
            for event_info in events_this_tick:
                run_entity_event(e, event_info)
            if not e.moving and e.deferred_signals.size() > 0:
                e.process_deferred_signals()
            active_entities.append(e)
            if new_action_activations and (not actions_only_for_camera_target or GameManager.is_entity_current_camera_focus(e)):
                e.got_action_signals(new_action_activations)
            e.entity_process_starting_actions()
            if e.moving:
                moving_entities.append(e)
            else:
                if e.deferred_signals.size() > 0:
                    e.process_deferred_signals()
                idle_entities.append(e)
        e.sprite_process(delta_time)
    
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

func run_entity_event(entity: BaseEntity, event_info: Dictionary) -> void:
    if event_info.get("property_event", ""):
        resolve_entity_interaction_event(event_info["property_event"], entity, null, [entity.get_moving_position()])

func queue_half_move_actions_for(entity: BaseEntity) -> void:
    if process_phase != 3:
        push_error("ERROR: tried to queue half move actions for an entity outside of the moving phase")
        return
    _pending_half_move_actions.append(entity)

# this didn't work out, maybe revisit later
func should_bump_move() -> bool:
    return false
    #return process_phase >= 3

func _physics_process(delta: float) -> void:
    entity_list_process(delta)

    animation_frame_counter += 1
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
    
    if not initial_sprite_previews_created:
        await initial_sprite_previews_finished
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
        default_move_interp_style = Utility.PosInterpStyle.CONTINUOUS_LINEAR
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

func on_entities_removed() -> void:
    for e in entity_list:
        e._handle_removed_entities()
    on_entity_list_changed()

func on_entity_list_changed() -> void:
    entity_list_updated.emit()

func clear():
    clear_entity_list()
    turn_requested = false
    update_movement_mode()
    process_phase = 0
    animation_frame_counter = 0
    frame_counter = 0

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
    timed_entity_events.clear()
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

func has_instance(instance_id: int) -> bool:
    return instance_id in entity_instance_map

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
    if entity_defs[entity_id]["properties"].has("museum-active"):
        return true if entity_defs[entity_id]["properties"]["museum-active"] else false
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
    entity.teleport_interp_style = default_teleport_interp_style
    var base_props: Dictionary = entity_defs[entity.entity_index]["properties"]
    if "move-animation" in base_props:
        var move_interp_str: Variant = get_entity_prop_with_default(entity, "move-animation", "")
        entity.move_interp_style = BaseEntity.read_move_interp_style_string(str(move_interp_str), default_move_interp_style)
    if "teleport-animation" in base_props:
        var teleport_interp_str: Variant = get_entity_prop_with_default(entity, "teleport-animation", "")
        entity.teleport_interp_style = BaseEntity.read_move_interp_style_string(str(teleport_interp_str), default_teleport_interp_style)

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
    setup_entity_sprite(entity)
    
    entity.set_move_facing(facing)
    entity.set_facing(facing, true)
    
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
    var auto_tail_val: Variant = get_entity_prop_with_default(entity, "auto-tail", false)
    if not auto_tail_val:
        return
    if typeof(auto_tail_val) == TYPE_STRING and auto_tail_val.to_lower() == "true":
        auto_tail_val = true
    
    var looking_at_tile = entity.tile_position + Utility.facing_vector_i(entity.facing)
    var entities_in_front = get_entities_at(looking_at_tile)
    for e in entities_in_front:
        if typeof(auto_tail_val) == TYPE_STRING and get_entity_prop_with_default(e, auto_tail_val, false):
            entity.set_tailing(e)
            entity.add_deferred_event("started_tailing", e.instance_id)
            break
        elif auto_tail_val:
            entity.set_tailing(e)
            entity.add_deferred_event("started_tailing", e.instance_id)
            break

func auto_bond_handler(entity: BaseEntity) -> void:
    if get_entity_prop_with_default(entity, "auto-bond", false):
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
    setup_entity_sprite(entity)
    entity.deserialize_sprite(serialized_entity)
    
    MapManager.check_terrain_spr_mod_for_created(entity)
    
    if refresh:
        refresh_entity_list()

func setup_entity_sprite(entity: BaseEntity) -> void:
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
    
    var turn_anim: String = GameManager.get_game_setting("default_turn_animation", "quick")
    if entity_has_property(entity, "turn-animation"):
        turn_anim = get_entity_prop_with_default(entity, "turn-animation", turn_anim)
    sprite.interpolate_facing_enabled = turn_anim != "none"

func serialize() -> Dictionary:
    var serialized_entity_system: Dictionary = {}
    serialized_entity_system["frame_counter"] = frame_counter
    serialized_entity_system["animation_frame_counter"] = animation_frame_counter
    serialized_entity_system["timed_entity_events"] = timed_entity_events.duplicate_deep()

    var serialized_entities: Array = []
    for e in entity_list:
        serialized_entities.append(e.serialize())
    serialized_entity_system["entity_list"] = serialized_entities
    serialized_entity_system["bond_groups"] = bond_groups.duplicate_deep()
    
    return serialized_entity_system

func deserialize(data: Dictionary) -> void:
    clear()
    frame_counter = data.get("frame_counter", 0)
    animation_frame_counter = data.get("animation_frame_counter", 0)
    if "timed_entity_events" in data:
        timed_entity_events.assign(data["timed_entity_events"].duplicate_deep())
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
        if e.bond_group:
            unbond_entity(e, false)
        else:
            e.add_deferred_event("joined_bond_group")
        group.append(e.instance_id)
        e.bond_group = group
    #bond_group_cull()

func bond_entity(entity, bond_group) -> void:
    entity.bond_group = bond_group
    bond_group.append(entity.instance_id)
    entity.add_deferred_event("joined_bond_group")

func unbond_entity(entity: BaseEntity, with_event: bool = false) -> void:
    if entity.bond_group:
        var bg: Array = entity.bond_group
        if bg.size() == 1:
            bond_groups.erase(bg)
        else:
            bg.remove_at(bg.find(entity.instance_id))
        entity.bond_group = []
        if with_event:
            entity.add_deferred_event("left_bond_group")

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

func find_closest_entity_with_truthy_property(prop_name: String, from_position: Vector2i, is_truthy: bool = true, exclude_list: Array = [], include_inactive: bool = false) -> BaseEntity:
    var closest_dist: float = -1
    var closest_entity: BaseEntity = null
    for entity in entity_list:
        if not include_inactive and not entity.active or entity in exclude_list:
            continue
        var value: = get_entity_prop_is_truthy(entity, prop_name, false)
        if value != is_truthy:
            continue
        var euclidean_dist: = from_position.distance_to(entity.get_moving_position())
        if closest_dist < 0 or euclidean_dist < closest_dist:
            closest_dist = euclidean_dist
            closest_entity = entity
    return closest_entity

func find_closest_entity_with_id(id: int, from_position: Vector2i, exclude_list: Array = [], include_inactive: bool = false) -> BaseEntity:
    var closest_dist: float = -1
    var closest_entity: BaseEntity = null
    for entity in entity_list:
        if entity.entity_index != id:
            continue
        if not include_inactive and not entity.active or entity in exclude_list:
            continue
        var euclidean_dist: = from_position.distance_to(entity.get_moving_position())
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
        if not conditional_entity_interaction("i_move_off_of", moving_entity, e, leaving_ps, true):
            result = false
    for e in entities_here:
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
        elif "inherit-properties" in def_props:
            var inherit_from: = get_entity_index(def_props["inherit-properties"])
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
    if "inherit-properties" in entity_props:
        var from = get_entity_index(entity_props["inherit-properties"])
        has = has or property_name in entity_defs[from]["properties"]
    return has

func get_entity_property_list(entity: BaseEntity) -> Array:
    var props: Dictionary = {}
    var definition_props = entity_defs[entity.entity_index]["properties"]
    Utility.set_keys(props, definition_props.keys())
    Utility.set_keys(props, entity.local_properties.keys())
    if "inherit-properties" in definition_props:
        var inherit_from = get_entity_index(definition_props["inherit-properties"])
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
            remove_entity(entity, false)
    on_entities_removed()

func get_all_entities_depending_on(entity: BaseEntity, include_self: bool = true) -> Array[BaseEntity]:
    var collected_instances: Array[int] = []
    _collect_entity_subordinates(entity.instance_id, collected_instances)
    if include_self:
        collected_instances.append(entity.instance_id)
    var entities: Array[BaseEntity] = []
    for instance_id in collected_instances:
        entities.append(entity_instance_map[instance_id])
    return entities

func _collect_entity_subordinates(of_instance_id: int, collected: Array[int]) -> void:
    if not entity_index_map.has(of_instance_id):
        return
    for subordinate_id in entity_index_map[of_instance_id].subordinate_entities:
        if not subordinate_id in collected:
            collected.append(subordinate_id)
            _collect_entity_subordinates(subordinate_id, collected)

func remove_entity(entity: BaseEntity, do_emit: bool = true) -> void:
    _remove_entities(get_all_entities_depending_on(entity), do_emit)

func _remove_entities(to_remove_entities: Array[BaseEntity], do_emit: bool = true) -> void:
    for entity in to_remove_entities:
        if not entity.instance_id in entity_instance_map:
            continue
        if entity in entity_signal_connections:
            for connected_sig in entity_signal_connections.get(entity, []):
                var signal_connections = get_signal_connection_list(connected_sig)
                for sig_conn in signal_connections:
                    if (sig_conn.callable as Callable).get_object() == entity:
                        sig_conn.signal.disconnect(sig_conn.callable)
            entity_signal_connections.erase(entity)
        entity_instance_map.erase(entity.instance_id)
        entity_list.erase(entity)
        if entity.bond_group:
            unbond_entity(entity, false)
        entity.remove_from_group("_entity_")
        entity.set_active(false)
        entity.call_deferred("queue_free")
    
    if do_emit:
        on_entities_removed()

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

func get_default_tele_steps() -> int:
    return ceili(default_teleport_duration * GameManager.get_full_tick_rate())

func switch_entities_preview_mode(enable_preview: bool) -> void:
    is_entity_preview_mode = enable_preview
    entity_preview_mode_changed.emit(enable_preview)

func save_entity_sprite_snapshot(entity_index: int, snapshot: ImageTexture, snapshot_zoom: float = -1) -> void:
    if snapshot_zoom < 0:
        snapshot_zoom = GameManager.get_default_pixel_scale()
    entity_sprite_snapshots[entity_index] = snapshot
    entity_sprite_snapshot_scales[entity_index] = snapshot_zoom

func entity_has_preview_variant(entity_index: int) -> bool:
    return not entity_defs[entity_index].get("preview_variant", {}).is_empty()

func get_entity_sprite_snapshot(entity_index: int, preview: bool = false) -> Texture2D:
    if not entity_sprite_snapshots.has(entity_index) or (entity_has_preview_variant(entity_index) and preview):
        return Utility.atlas_texture_from_entity_index(entity_index, preview)
    else:
        return entity_sprite_snapshots[entity_index]

# Get the scale that a sprite snapshot should be displayed at, if for_ui the scale is the one used by default in UI elements
# otherwise it should match 1 to 1 scale of world pixels
func get_entity_sprite_snapshot_scale(entity_index: int, preview: bool = false, for_ui: bool = true) -> float:
    var ui_scale: float = 1
    if for_ui:
        ui_scale = GameManager.get_default_pixel_scale()
    if not entity_sprite_snapshots.has(entity_index) or (entity_has_preview_variant(entity_index) and preview):
        return ui_scale
    else:
        var snapshot_scale: float = entity_sprite_snapshot_scales.get(entity_index, GameManager.get_default_pixel_scale())
        return ui_scale / snapshot_scale

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

var special_effects: Dictionary = {
    "Shrink": {
        "name": "effect-shrink",
        "effects": {
            "scale": [0.65, 0.65],
        },
    },
    "Grow": {
        "name": "effect-grow",
        "effects": {
            "scale": [1.25, 1.25],
        },
    },
}

func apply_special_effect(entity: BaseEntity, effect_name: String) -> void:
    if not entity or not effect_name in special_effects:
        return
    entity.add_sprite_modifier(special_effects[effect_name])

func remove_special_effect(entity: BaseEntity, effect_name: String) -> void:
    if not entity or not effect_name in special_effects:
        return
    entity.remove_sprite_modifier(special_effects[effect_name])

func clear_entity_special_effects(entity: BaseEntity) -> void:
    if not entity:
        return
    for effect_name in special_effects:
        entity.remove_sprite_modifier(special_effects[effect_name])

func get_camera_following_instances() -> Array:
    if not GameManager.get_cam_setting("follow_entity_by", "property") != "instances":
        return []
    
    var new_instance_list: Array = []
    var follow_entities: Array = []
    for instance_id in GameManager.get_cam_setting("follow_entity_instances", []):
        if not instance_id in entity_instance_map:
            continue
        new_instance_list.append(instance_id)
        follow_entities.append(get_instance(instance_id))
    GameManager.set_cam_setting("follow_entity_instances", new_instance_list)
    return follow_entities

func remove_camera_following_instance(instance_id: int) -> void:
    var cur_instances: Array = get_camera_following_instances()
    if not cur_instances:
        return
    if instance_id in cur_instances:
        cur_instances.erase(instance_id)
        GameManager.set_cam_setting("follow_entity_instances", cur_instances)
        GameManager.camera_refollow()

func is_entity_in_camera_following(entity: BaseEntity) -> bool:
    var follow_mode: String = GameManager.get_cam_setting("follow_entity_by", "property")
    if follow_mode in ["name", "property"] and not GameManager.get_cam_setting("follow_entity", ""):
        return false

    if follow_mode == "name":
        var follow_name: String = GameManager.get_cam_setting("follow_entity", "")
        if entity_name_exists(follow_name) and get_entity_index(follow_name) == entity.entity_index:
            return true
        else:
            return false
    elif follow_mode == "property":
        var follow_property: String = GameManager.get_cam_setting("follow_entity", "")
        return get_entity_prop_is_truthy(entity, follow_property)
    elif follow_mode == "instances":
        var follow_instances: Array = get_camera_following_instances()
        return entity.instance_id in follow_instances
    return false

func _add_timed_entity_event(instance_id: int, event_info: Dictionary) -> void:
    if not instance_id in timed_entity_events:
        timed_entity_events[instance_id] = []
    timed_entity_events[instance_id].append(event_info)

func _get_timeout_tick_after(delay_seconds: float, animtion_tick: bool = true) -> int:
    var relevant_tick: int = animation_frame_counter if animtion_tick else frame_counter
    return relevant_tick + roundi(delay_seconds * GameManager.get_tick_rate())

func add_delayed_entity_prop_event(entity: BaseEntity, prop_event_name: String, delay: float, is_anim_delay: bool = true) -> void:
    _add_timed_entity_event(entity.instance_id, {
        "is_animation_tick": is_anim_delay,
        "timeout_tick": _get_timeout_tick_after(delay, is_anim_delay),
        "property_event": prop_event_name,
    })

func merge_entity_bond_groups(entity1: BaseEntity, entity2: BaseEntity) -> void:
    if not entity1.bond_group and not entity2.bond_group:
        create_bond_group([entity1, entity2])
    elif not entity1.bond_group or not entity2.bond_group:
        bond_entity(entity2 if entity1.bond_group else entity1, entity1.bond_group if entity1.bond_group else entity2.bond_group)
    
    var all_entities: Array[BaseEntity] = []
    for inst_id in entity1.bond_group:
        if has_instance(inst_id):
            all_entities.append(get_instance(inst_id))
    for inst_id in entity2.bond_group:
        if has_instance(inst_id):
            all_entities.append(get_instance(inst_id))
    create_bond_group(all_entities)

func disolve_entity_bond_group(entity: BaseEntity) -> void:
    if not entity.bond_group:
        return
    var bond_group_of_entity: Array = find_bond_group_of_entity(entity)
    for inst_id in bond_group_of_entity:
        if has_instance(inst_id):
            var bonded_entity: BaseEntity = get_instance(inst_id)
            unbond_entity(bonded_entity, true)

func removing_texture_id(_texture_id: int) -> void:
    pass

func rerender_entity_sprite_preview(entity_id: int) -> void:
    var entity_def: Dictionary = entity_defs[entity_id]
    if not entity_def.get("preview_variant", {}).is_empty():
        if entity_sprite_snapshots.has(entity_id):
            entity_sprite_snapshots.erase(entity_id)
            entity_sprite_snapshot_scales.erase(entity_id)
    else:
        await render_single_sprite_preview(entity_id)

func _get_snapshot_renderer() -> SpritePreviewer:
    var sprite_previewer: = sprite_previewer_scene.instantiate() as SpritePreviewer
    add_child(sprite_previewer)
    sprite_previewer.hide_bg()
    sprite_previewer.set_custom_preview_size(1, 0.25)
    sprite_previewer.get_subviewport().recenter()
    return sprite_previewer

func build_sprite_previews() -> void:
    entity_sprite_snapshots.clear()
    var entities_to_gen_for: Array[int] = []
    for entity_id in entity_defs.keys():
        if entity_defs[entity_id].get("preview_variant", {}).is_empty():
            entities_to_gen_for.append(entity_id)
    if not entities_to_gen_for:
        initial_sprite_previews_created = true
        initial_sprite_previews_finished.emit()
        return

    var sprite_previewer: = _get_snapshot_renderer()
    for entity_id in entities_to_gen_for:
        var entity_def: Dictionary = entity_defs[entity_id]
        if not entity_def.get("preview_variant", {}).is_empty():
            continue
        await _update_sprite_preview_for_entity(entity_id, entity_def, sprite_previewer)

    sprite_previewer.queue_free()
    initial_sprite_previews_created = true
    initial_sprite_previews_finished.emit()

func render_single_sprite_preview(entity_id: int) -> void:
    var entity_def: Dictionary = entity_defs[entity_id]

    var sprite_previewer: = _get_snapshot_renderer()
    sprite_previewer.update_sprite_config(entity_def)

    var sub_vp: SubViewport = sprite_previewer.get_subviewport()
    await Utility.force_rerender_subviewport(sub_vp)
    var img_tex: ImageTexture = ImageTexture.create_from_image(sub_vp.get_texture().get_image())
    save_entity_sprite_snapshot(entity_id, img_tex, 1)
    sprite_previewer.queue_free()

func _update_sprite_preview_for_entity(entity_id: int, entity_def: Dictionary, sprite_previewer: SpritePreviewer) -> void:
    if not entity_def.get("preview_variant", {}).is_empty():
        return
    sprite_previewer.update_sprite_config(entity_def)
    var sub_vp: SubViewport = sprite_previewer.get_subviewport()

    await Utility.force_rerender_subviewport(sub_vp)
    var img_tex: ImageTexture = ImageTexture.create_from_image(sub_vp.get_texture().get_image())
    save_entity_sprite_snapshot(entity_id, img_tex, 1)