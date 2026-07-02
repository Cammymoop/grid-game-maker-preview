extends Node

signal initial_sprite_previews_finished
signal entity_snapshots_updated

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

var entity_instance_cap: int = 100000

var entity_index_map: = {}
var entity_instance_map: = {}

var entity_sprite_snapshots: Dictionary[int, ImageTexture] = {}
var entity_sprite_snapshot_scales: Dictionary[int, float] = {}

var entity_signal_connections: = {}

var entity_list: Array = []
var bond_groups: Array = []
var _pending_half_move_actions: Array[BaseEntity] = []

var _entity_at_cache: Dictionary[Vector2i, Array] = {}
var _entity_leaving_cache: Dictionary[Vector2i, Array] = {}

#var _next_to_include_diagonal: bool = false

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

const DEFAULT_MOVE_SPEED: float = 6
const DEFAULT_TELEPORT_DURATION: float = 1/6.0
var default_idle_delay: float = 1/10.0
var idle_delay_frames: int = -1

var default_dying_effect: Dictionary = {}

var actions_only_for_camera_target: bool = false

var default_move_interp_style: Utility.PosInterpStyle = Utility.PosInterpStyle.CONTINUOUS_LINEAR
var default_teleport_interp_style: Utility.PosInterpStyle = Utility.PosInterpStyle.NONE

var process_phase: int = 0

var is_entity_preview_mode: bool = false

var timed_entity_events: Dictionary[int, Array] = {}

var _nested_related_moves: Dictionary = {}
var _cur_related_move_node: Dictionary = {}
var _finished_related_move_node: Dictionary = {}

var paused_at_start: bool = false

#var _move_resolution_stack: Array[Dictionary] = []
#var _move_stack_metadata: Dictionary = {}

func paused_visual_process(delta_time: float) -> void:
    for e in entity_list:
        e.sprite_process(delta_time)

func pressed_any_to_start() -> bool:
    for dir in ["up", "down", "left", "right"]:
        if Input.is_action_just_pressed("move_" + dir):
            return true
    for action_num in ["1", "2", "3"]:
        if Input.is_action_just_pressed("input_action_" + action_num):
            return true
    return false

func entity_list_process(delta_time: float) -> void:
    if paused_at_start:
        if pressed_any_to_start():
            paused_at_start = false

    if paused_at_start:
        paused_visual_process(delta_time)
        return

    var active_entities: Array[BaseEntity] = []
    var moving_entities: Array[BaseEntity] = []
    var idle_entities: Array[BaseEntity] = []
    
    var new_action_activations: Array[String] = []
    for action_num in ["1", "2", "3"]:
        if Input.is_action_just_pressed("input_action_" + action_num):
            new_action_activations.append("do_action_" + action_num)
            if action_num == "1" and GameManager.action_1_does_undo():
                if GameManager.has_undo_state():
                    GameManager.pop_and_load_undo_state.call_deferred()
                    return
        elif action_num == "3" and not GameManager.is_in_level_edit_mode and Input.is_action_just_pressed("input_action_3_no_editor"):
            new_action_activations.append("do_action_" + action_num)
    
    # Phased processing so each entity completes a phase before any entity processes the next phase
    
    _build_entity_at_cache()
    
    # Phase 1 - Timed entity events, Starting movement and start of move actions
    process_phase = 1
    if movement_mode != GameManager.MovementMode.MOVEMENT_CONTINUOUS and controller_frame:
        GameManager.cur_undo_is_current_state = false
        handle_turn_start_events()

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
    # also find entities that started moving after their turn to run starting actions
    process_phase = 2
    for e in idle_entities:
        if e.active:
            if e.moving:
                moving_entities.append(e)
            else:
                e.idle_ticks_elapsed += 1
    for e in idle_entities:
        if e.active and not e.moving and e.idle_ticks_elapsed >= idle_delay_frames:
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
    if moving_entities.size() > 0:
        pass#breakpoint
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

    handle_movement_mode_stuff()
    
    process_phase = 0

func handle_turn_start_events() -> void:
    for e in entity_list:
        if not e.active or not entity_has_property(e, "turn_start"):
            continue
        resolve_entity_interaction_event("turn_start", e, null, [e.get_moving_position()])

func handle_pre_turn_end_events() -> void:
    for e in entity_list:
        if not e.active or not entity_has_property(e, "pre_turn_end"):
            continue
        resolve_entity_interaction_event("pre_turn_end", e, null, [e.get_moving_position()])

func handle_turn_end_events() -> void:
    for e in entity_list:
        if not e.active or not entity_has_property(e, "turn_end"):
            continue
        resolve_entity_interaction_event("turn_end", e, null, [e.get_moving_position()])

func _build_entity_at_cache() -> void:
    _entity_at_cache.clear()
    _entity_leaving_cache.clear()
    for e in entity_list:
        _cache_entity_at_pos(e)

func _cache_entity_at_pos(e: BaseEntity) -> void:
    if e is LargeEntity:
        var main_positions: Array[Vector2i] = e.get_positions_at(e.next_tile_pos if e.moving else e.tile_position)
        for at_pos in main_positions:
            if not at_pos in _entity_at_cache:
                _entity_at_cache[at_pos] = []
            _entity_at_cache[at_pos].append(e)
        if e.moving:
            for leaving_pos in e.get_positions_at(e.tile_position):
                if not leaving_pos in _entity_leaving_cache:
                    _entity_leaving_cache[leaving_pos] = []
                _entity_leaving_cache[leaving_pos].append(e)
    else:
        var main_pos: Vector2i = e.next_tile_pos if e.moving else e.tile_position
        if not main_pos in _entity_at_cache:
            _entity_at_cache[main_pos] = []
        _entity_at_cache[main_pos].append(e)
        if e.moving:
            if not e.tile_position in _entity_leaving_cache:
                _entity_leaving_cache[e.tile_position] = []
            _entity_leaving_cache[e.tile_position].append(e)

func invalidate_cached_instance_at_pos(entity: BaseEntity, from_positions: Array[Vector2i]) -> void:
    for pos in from_positions:
        if pos in _entity_at_cache:
            _entity_at_cache[pos].erase(entity)
        if pos in _entity_leaving_cache:
            _entity_leaving_cache[pos].erase(entity)
    _cache_entity_at_pos(entity)

            

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

func handle_movement_mode_stuff() -> void:
    var all_settled: = false
    if movement_mode == GameManager.MovementMode.MOVEMENT_DISCRETE_WAIT and movements_enabled:
        if all_entities_settled():
            handle_pre_turn_end_events()
            all_settled = all_entities_settled()

    animation_frame_counter += 1
    var was_movement_enabled: = movements_enabled
    if movements_enabled:
        frame_counter += 1
    if movement_mode == GameManager.MovementMode.MOVEMENT_CONTINUOUS:
        return
    
    controller_frame = false
    if movements_enabled:
        if movement_mode == GameManager.MovementMode.MOVEMENT_DISCRETE:
            turn_frames_remaining -= 1
            if turn_frames_remaining <= 0:
                movements_enabled = false
        elif movement_mode == GameManager.MovementMode.MOVEMENT_DISCRETE_WAIT and all_settled:
            movements_enabled = false
    elif turn_requested:
        turn_requested = false
        turn_frames_remaining = requested_turn_frames
        movements_enabled = true
        controller_frame = true
    
    if was_movement_enabled and not movements_enabled:
        handle_turn_end_events()
        if GameManager.is_auto_undo_enabled():
            GameManager.push_undo_state(true)

func all_entities_settled() -> bool:
    var settled = true
    for e in entity_list:
        settled = settled and e.is_settled()
    return settled

func _ready():
    TextureManager.textures_remapped.connect(on_textures_remapped)
    #preload_controller_templates()
    process_physics_priority = 10
    if not GameManager.is_node_ready():
        await GameManager.ready
    idle_delay_frames = roundi(default_idle_delay * GameManager.get_tick_rate())
    
    GameManager.game_settings_changed.connect(on_game_settings_changed)
    
    GameManager.any_state_loaded.connect(on_any_state_loaded)

func on_any_state_loaded() -> void:
    if movement_mode != GameManager.MovementMode.MOVEMENT_CONTINUOUS:
        return
    paused_at_start = false
    #if GameManager._state_load_is_start_of_level
    if MapManager.is_level_start_paused():
        paused_at_start = true

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
    convert_legacy_format_stuff()
    fix_string_keys()
    fix_int_property_vals()
    create_index_map()
    create_defined_custom_signals()
    
    actions_only_for_camera_target = GameManager.get_game_setting("action_signal_sent_to", "all_entities") != "camera_target"
    update_default_dying_effect()
    
func update_default_dying_effect():
    var default_dying_effect_name: String = GameManager.get_game_setting("default_dying_effect", "")
    if not default_dying_effect_name or default_dying_effect_name.to_lower() == "none":
        default_dying_effect = {}
    elif default_dying_effect_name in SpriteEffects.DYING_EFFECTS:
        default_dying_effect = SpriteEffects.DYING_EFFECTS[default_dying_effect_name].duplicate_deep()
    else:
        push_warning("Unknown default dying effect (game setting): %s" % default_dying_effect_name)
        default_dying_effect = {}

func convert_legacy_format_stuff():
    for entity_id in entity_defs:
        if "intended_move_speed" in entity_defs[entity_id]:
            var intended_move_speed: float = float(entity_defs[entity_id]["intended_move_speed"])
            entity_defs[entity_id].erase("intended_move_speed")
            if intended_move_speed <= 0:
                continue
            entity_defs[entity_id]["properties"]["move-speed"] = intended_move_speed
                

func on_game_settings_changed():
    update_movement_mode()
    update_default_dying_effect()

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
    
    var def_tele_interp_string: = GameManager.get_game_setting("default_teleport_interp", "") as String
    if not def_tele_interp_string:
        default_teleport_interp_style = Utility.PosInterpStyle.NONE
    else:
        default_teleport_interp_style = BaseEntity.read_move_interp_style_string(def_tele_interp_string)
    
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

func on_entity_added(_entity: BaseEntity) -> void:
    resort_entity_list()
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
    clear_related_move_cache()
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
        if request_frames > 0:
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

func update_entity_definition(entity_id: int, entity_definition: Dictionary) -> void:
    if not entity_id in entity_defs:
        push_error("ERROR tried to update non-existing entity: " + str(entity_id))
        return
    entity_defs[entity_id] = entity_definition.duplicate_deep()
    refresh_definition()

func update_entity_def_properties(entity_id: int, properties: Dictionary) -> void:
    if not entity_id in entity_defs:
        push_error("ERROR tried to update properties of non-existing entity: " + str(entity_id))
        return
    entity_defs[entity_id]["properties"] = properties.duplicate_deep()
    refresh_definition()

func get_all_controllers() -> Array:
    return controller_templates.keys()

func new_entity(new_entity_definition: Dictionary) -> int:
    new_entity_definition = clean_for_existing_assets(new_entity_definition)
    var new_id: = max_entity_index() + 1
    entity_defs[new_id] = new_entity_definition
    if new_entity_definition.get("sprite_config", {}):
        render_single_sprite_preview(new_id)
    refresh_definition()
    return new_id

func _clean_dict_texture_id_for_existing_assets(incoming_dict: Dictionary) -> void:
    if not incoming_dict.has("texture"):
        return
    var texture_id: = int(incoming_dict["texture"])
    if not TextureManager.has_loaded_texture_id(texture_id):
        incoming_dict["texture"] = TextureManager.get_fallback_texture_id()
        incoming_dict["tex_index"] = 0
    else:
        var max_index: = TextureManager.get_max_texture_index(texture_id)
        incoming_dict["tex_index"] = mini(max_index, int(incoming_dict.get("tex_index", 0)))

func clean_for_existing_assets(incoming_definition: Dictionary) -> Dictionary:
    _clean_dict_texture_id_for_existing_assets(incoming_definition)
    if incoming_definition.has("preview_variant"):
        _clean_dict_texture_id_for_existing_assets(incoming_definition["preview_variant"])
    
    if incoming_definition.get("sprite_config", {}):
        for layer_dict in incoming_definition["sprite_config"].get("layers", []):
            _clean_dict_texture_id_for_existing_assets(layer_dict)
    return incoming_definition

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

func create_entity(entity_index: int, tile_position: Vector2i, facing: int = 0, activate: bool = true, from_editor: bool = false) -> Node2D:
    if entity_list.size() >= entity_instance_cap:
        return null
    var entity_info = entity_defs[entity_index]
    
    var entity: BaseEntity
    if "entity_type" in entity_info:
        entity = large_entity_template.instantiate()
    elif entity_info.get("can_be_large", false):
        entity = large_entity_template.instantiate()
    else: 
        entity = entity_template.instantiate()


    entity.entity_index = entity_index
    entity.instance_id = instance_counter
    entity_instance_map[entity.instance_id] = entity
    entity_list.append(entity)
    instance_counter += 1
    
    reset_entity_move_interp_style(entity)

    entity.update_cached_spt()

    setup_entity_controller(entity)
    entity.position = MapManager.tile_to_world_position(tile_position)
    entity.tile_position = tile_position
    entity.next_tile_pos = tile_position
    if entity is LargeEntity:
        setup_new_entity_size(entity)
    add_entity_to_world(entity)
    entity.initialize()
    setup_entity_sprite(entity)
    
    entity.set_move_facing(facing)
    entity.set_facing(facing, true)
    
    if "groups" in entity_info:
        for g in entity_info["groups"]:
            entity.add_to_group(g)
    
    entity.active = activate

    auto_bond_handler(entity)
    auto_tail_handler(entity)
    
    on_entity_added(entity)
    
    if activate and not from_editor:
        post_activated_actions(entity)
    
    MapManager.check_terrain_spr_mod_for_created(entity)
    
    return entity

func setup_new_entity_size(entity: BaseEntity) -> void:
    if not entity is LargeEntity:
        return
    
    var entity_def: Dictionary = entity_defs[entity.entity_index]
    var default_size: Vector2 = get_default_size_for_entity(entity.entity_index)

    entity.entity_size = default_size
    entity.set_default_mask()
    if entity_def.has("starting_mask_out"):
        for masked_pos in entity_def["starting_mask_out"]:
            var mask_pos_vec: Vector2i = Utility.get_vector2i_from_arr(masked_pos)
            entity.shape_mask[mask_pos_vec] = false

func get_default_size_for_entity(entity_id: int) -> Vector2:
    var entity_def: Dictionary = entity_defs.get(entity_id, {})
    if not entity_def.get("can_be_large", false):
        return Vector2.ONE
    return Utility.get_vector2_from_arr(entity_def.get("default_size", [1, 1]))

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

func reset_entity_controller(entity: BaseEntity) -> void:
    if entity.controller:
        entity.remove_child(entity.controller)
        entity.controller.queue_free()
    setup_entity_controller(entity)

func setup_entity_controller(entity: BaseEntity) -> void:
    var entity_id = entity.entity_index
    if entity_id in entity_defs and "controller" in entity_defs[entity_id]:
        var controller_name = entity_defs[entity_id]["controller"]
        if controller_name in controller_templates:
            var controller = get_new_controller(controller_name)
            if entity_defs[entity_id].has("controller_options"):
                controller.set_options(entity_defs[entity_id]["controller_options"])
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
    if not entity or entity.bond_group or not entity.active:
        return
    var auto_bond_val: String = Utility.property_value_nonempty_string(get_entity_prop_with_default(entity, "auto-bond", false), "false")
    if auto_bond_val.to_lower() == "true":
        auto_bond_val = "true"
    elif auto_bond_val.to_lower() == "false":
        auto_bond_val = "false"

    if auto_bond_val != "false":
        var bonded: = false
        var bond_to_entity_ids: Array = []
        if auto_bond_val == "true":
            bond_to_entity_ids = [entity.entity_index]
        else:
            bond_to_entity_ids = filter_entity_types_by_property(auto_bond_val)

        var bond_adjacent_val: Variant = get_entity_prop_with_default(entity, "auto-bond-adjacent", true)
        var is_bond_adjacent: bool = Utility.property_value_bool(bond_adjacent_val, true)
        var is_bond_adjacent_diagonal: bool = typeof(bond_adjacent_val) == TYPE_STRING and bond_adjacent_val.to_lower() == "diagonal"
        if is_bond_adjacent:
            var adjacent_positions: = Utility.get_adjacent_positions_of_multiple(get_all_positions_of_entity(entity), is_bond_adjacent_diagonal)
            var entities_to_bond: Array[BaseEntity] = []
            for e in get_entities_at_multiple(adjacent_positions):
                if not e.active or e.instance_id == entity.instance_id:
                    continue
                if auto_bond_val == "true":
                    if e.entity_index in bond_to_entity_ids:
                        entities_to_bond.append(e)
                elif get_entity_prop_is_truthy(e, auto_bond_val, false):
                    entities_to_bond.append(e)
            #prints("auto bond adjacent,", entity.entity_name, "found entities adjacent:", entities_to_bond.size())
            if entities_to_bond.size() > 0:
                entities_to_bond.append(entity)
                merge_entity_array_bond_groups(entities_to_bond)
        else:
            var bg_copy: Array = bond_groups.duplicate()
            bg_copy.reverse()
            for potential_group in bg_copy:
                if bonded:
                    break
                if not potential_group:
                    continue
                for instance_id in potential_group:
                    var group_entity: = get_instance(instance_id)
                    if group_entity.entity_index not in bond_to_entity_ids:
                        continue
                    bond_entity(entity, potential_group)
                    bonded = true
                    break
            
            # if any other existing entities with the correct ids, make a new group now to contain them
            if not bonded:
                var bondable_entities: Array[BaseEntity] = [entity]
                for e_id in bond_to_entity_ids:
                    bondable_entities.append_array(find_all_entities_by_index(e_id, true))
                merge_entity_array_bond_groups(bondable_entities)


func restore_entity(serialized_entity: Dictionary, refresh: bool = false) -> void:
    var entity: BaseEntity
    var entity_id: int = int(serialized_entity['entity_index'])
    if entity_defs[entity_id].get("can_be_large", false):
        entity = large_entity_template.instantiate()
    elif serialized_entity.get("entity_class", "BaseEntity") != "BaseEntity":
        entity = large_entity_template.instantiate()
    else:
        entity = entity_template.instantiate()
    
    entity.entity_index = entity_id
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
    sprite.set_base_entity_info(entity.entity_index)
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
    
    if entity is LargeEntity:
        entity.update_sprite_pos_scale()

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
    bond_groups = []
    for deserialized_bg in data.get("bond_groups", []).duplicate_deep():
        var new_bg: Array = []
        for instance_id in deserialized_bg:
            new_bg.append(int(instance_id))
        bond_groups.append(new_bg)

    for entity_data in data["entity_list"]:
        var entity_id: int = int(entity_data.get("entity_index", -1))
        if entity_id == -1 or not entity_id in entity_defs:
            continue
        restore_entity(entity_data)
    refresh_entity_list()
    instance_counter = 0
    for e in entity_list:
        instance_counter = maxi(instance_counter, e.instance_id + 1)
    
    post_deserialize.emit()

func create_bond_group(entities: Array, create_lonely_group: bool = false) -> void:
    if not entities:
        return
    var group = []
    bond_groups.append(group)
    var included_instances: Array[int] = []
    for e in entities:
        if has_instance(e.instance_id):
            included_instances.append(e.instance_id)
    var not_creating: bool = not create_lonely_group and included_instances.size() < 2
    if not_creating:
        prints("not making a group of only one entity", included_instances)

    for e in entities:
        if e.bond_group:
            var left_instances: Array[int] = []
            for inst_id in e.bond_group:
                if has_instance(inst_id) and inst_id not in included_instances:
                    left_instances.append(inst_id)
            if left_instances.size() < 2:
                disolve_entity_bond_group(e, false)
                # notify lonely group member of dissolution
                if left_instances.size() == 1:
                    var left_entity: BaseEntity = get_instance(left_instances[0])
                    if left_entity.active:
                        left_entity.add_deferred_event("left_bond_group")
            else:
                unbond_entity(e, false)
            
            if not_creating:
                e.add_deferred_event("left_bond_group")
        elif not not_creating:
            e.add_deferred_event("joined_bond_group")
    
    if not create_lonely_group and included_instances.size() < 2:
        return
    
    for e in entities:
        group.append(e.instance_id)
        e.bond_group = group
    #bond_group_cull()

func create_bond_group_directly(instance_list: Array, emit_joined: bool = false) -> void:
    bond_groups.append(instance_list)
    
    for inst_id in instance_list:
        if not has_instance(inst_id):
            continue
        var entity: BaseEntity = get_instance(inst_id)
        entity.bond_group = instance_list
        if emit_joined:
            entity.add_deferred_event("joined_bond_group")


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

func unbond_single_entity_with_lonely_group_dissolve(entity: BaseEntity, with_event: bool = false, lonely_event_if_active: bool = false) -> void:
    if not entity or not entity.bond_group:
        return
    var bg: Array = entity.bond_group
    bg.erase(entity.instance_id)
    if with_event:
        entity.add_deferred_event("left_bond_group")
    if bg.size() == 0:
        bond_groups.erase(bg)
        return

    if bg.size() == 1:
        if has_instance(bg[0]):
            var other_entity: BaseEntity = get_instance(bg[0])
            if not with_event and lonely_event_if_active and other_entity.active:
                with_event = true
            unbond_entity(other_entity, with_event)

func unbond_entities(entities: Array, with_event: bool = false) -> void:
    var bond_groups_with_removed_entities: Array = []
    for entity in entities:
        if not entity.bond_group:
            continue
        if entity.bond_group not in bond_groups_with_removed_entities:
            bond_groups_with_removed_entities.append(entity.bond_group)
    
    for entity in entities:
        unbond_entity(entity, with_event)
    
    for bond_group in bond_groups_with_removed_entities:
        if bond_group.size() == 1:
            disolve_entity_bond_group(get_instance(bond_group[0]), with_event)

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

func bond_group_start_move(bond_group: Array, steps_per_tile: int, move_facing: int, is_revertable: bool) -> bool:
    var instances = []

    var leftover_ids: Array[int] = []
    for entity_instance_id in bond_group:
        if not entity_instance_id in entity_instance_map:
            leftover_ids.append(entity_instance_id)
            continue
        instances.append(get_instance(entity_instance_id))
    
    for old_id in leftover_ids:
        bond_group.erase(old_id)
    
    var related_move_parent: = {}
    var is_top_level_move: = false
    if not _nested_related_moves:
        is_top_level_move = true
        _nested_related_moves = _fake_related_move()
        _cur_related_move_node = _nested_related_moves
    related_move_parent = _cur_related_move_node
    
    for entity in instances:
        if entity.moving:
            # Short circuit so we dont break by reverting a move on a currently moving entity
            return false
    
    # pre-set starting move for all instances before running any conditionals
    for entity in instances:
        entity._currently_starting_move = true
        entity._current_starting_move_facing = move_facing

    var move_allowed = true
    var first_related_move_node: = {}
    for entity in instances:
        # set change_visual_facing to false for group moves for now
        # good default but should be configurable somehow
        entity.set_steps_per_tile_override(steps_per_tile)
        if not entity.start_move(move_facing, false, true, is_revertable):
            move_allowed = false

        if not first_related_move_node and move_allowed:
            first_related_move_node = _finished_related_move_node
    
    # At least one of the entities in the bond group were blocked
    # Stop them all from moving
    if not move_allowed:
        for entity in instances:
            entity.revert_move_start()
        failed_group_move_start(related_move_parent, bond_group.duplicate())
    else:
        # use the first instead of last group move as the cannonical related move node
        _finished_related_move_node = first_related_move_node
        for entity in instances:
            post_move_actions(entity, entity.tile_position, entity.next_tile_pos)
            entity.actually_started_move()
    if is_top_level_move:
        clear_related_move_cache()
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
        if e.is_large() and e.is_half_at(tile_pos):
            entities_here.append(e)
        elif e.get_half_moved_position() == tile_pos:
            entities_here.append(e)
    return entities_here

func get_entities_at_multiple(tile_positions: Array, exclude_entity: Object = null, exclude_list: Array = [], include_moving_away: bool = false, include_inactive: bool = false) -> Array:
    var entities_here: Array = []
    if process_phase == 0:
        for e in entity_list:
            if not include_inactive and not e.active:
                continue
            if e == exclude_entity or (exclude_list and e.instance_id in exclude_list):
                continue
            if e.is_at_multiple(tile_positions, include_moving_away):
                entities_here.append(e)
    else:
        for pos in tile_positions:
            if not pos in _entity_at_cache:
                continue
            for e in _entity_at_cache[pos]:
                if e == exclude_entity or (exclude_list and e.instance_id in exclude_list):
                    continue
                if not e in entities_here and (include_inactive or e.active):
                    entities_here.append(e)
        if include_moving_away:
            for pos in tile_positions:
                if not pos in _entity_leaving_cache:
                    continue
                for e in _entity_leaving_cache[pos]:
                    if e == exclude_entity or (exclude_list and e.instance_id in exclude_list):
                        continue
                    if not e in entities_here and (include_inactive or e.active):
                        entities_here.append(e)
    return entities_here

func get_entities_next_to_multiple(tile_positions: Array, exclude_list: Array = [], include_inactive: bool = false) -> Array:
    return get_entities_next_to_multiple_move_from(tile_positions, -1, exclude_list, include_inactive)

func get_entities_next_to_multiple_move_from(tile_positions: Array, move_direction: int, exclude_list: Array = [], include_inactive: bool = false) -> Array:
    var adjacent_positions: Array[Vector2i] = []
    var adjacent_entities: Array = []
    var facing_vectors: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

    for pos in tile_positions:
        for dir in facing_vectors.size():
            if dir == move_direction:
                continue
            #if dir >= 4 and Vector2(facing_vectors[dir]).dot(Vector2(facing_vectors[move_direction])) > 0:
                #continue
            var adjacent_pos: Vector2i = pos + facing_vectors[dir]
            if adjacent_pos in adjacent_positions or not adjacent_pos in _entity_at_cache:
                continue
            adjacent_positions.append(pos + facing_vectors[dir])
    
    for pos in adjacent_positions:
        for e in _entity_at_cache[pos]:
            if (not include_inactive and not e.active) or (exclude_list and e.instance_id in exclude_list):
                continue
            if e in adjacent_entities:
                continue
            adjacent_entities.append(e)
    return adjacent_entities

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

func filter_entity_types_by_property(prop_name: String, invert: bool = false) -> Array:
    var filtered_ids: Array = []
    for e_id in entity_defs.keys():
        if entity_def_has_truthy_property_no_conditional(e_id, prop_name) != invert:
            filtered_ids.append(e_id)
    return filtered_ids

func entity_def_has_truthy_property_no_conditional(e_id: int, prop_name: String) -> bool:
    if not e_id in entity_defs:
        return false
    var entity_def_props: Dictionary = entity_defs[e_id]["properties"]
    if not prop_name in entity_def_props:
        return false
    var prop_val: Variant = entity_def_props[prop_name]
    if typeof(prop_val) in [TYPE_DICTIONARY, TYPE_ARRAY]:
        return false
    elif prop_val:
        return true
    return false

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
    
    if not moving_entity.active:
        return
    
    var adjacent_entities: = get_entities_next_to_multiple(onto_positions, [], false)
    var entities_positions: Dictionary[BaseEntity, Array] = {}
    for e in adjacent_entities:
        entities_positions[e] = get_all_positions_of_entity(e)

    if entity_has_property(moving_entity, "i_finish_move_next_to"):
        for e in adjacent_entities:
            var this_intersect_pos: Array[Vector2i] = Utility.filter_adjacent_positions_of_multiple(entities_positions[e], onto_positions)
            resolve_entity_interaction_event("i_finish_move_next_to", moving_entity, e, this_intersect_pos)
    if not moving_entity.active:
        return
    for e in adjacent_entities:
        if not entity_has_property(e, "finish_move_next_to"):
            continue
        var this_intersect_pos: Array[Vector2i] = Utility.filter_adjacent_positions_of_multiple(onto_positions, entities_positions[e])
        resolve_entity_interaction_event("finish_move_next_to", e, moving_entity, this_intersect_pos)

func resolve_entity_interaction_old(event_name: String, actor, interactee, at_tile_position: Vector2i, extra_debug: bool = false) -> void:
    resolve_entity_interaction_event(event_name, actor, interactee, [at_tile_position], extra_debug)

func resolve_entity_interaction_event(event_name: String, actor, interactee, at_tile_positions: Array, extra_debug: bool = false) -> void:
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
        skip_entity_inst_ids.assign(moving_entity.bond_group.duplicate())
    var entities_here: = get_entities_at_multiple(leaving_ps, moving_entity, skip_entity_inst_ids)
    
    if entity_has_property(moving_entity, "i_move_off_of"):
        for e in entities_here:
            skip_entity_inst_ids.append(e.instance_id)
            if not conditional_entity_interaction("i_move_off_of", moving_entity, e, leaving_ps, true):
                result = false
    for e in entities_here:
        if not conditional_entity_interaction("move_off_of", e, moving_entity, leaving_ps, true):
            result = false
    if not result:
        return false
    
    if not moving_entity._this_move_is_teleport:
        var entities_moving_away_from: = get_entities_next_to_multiple_move_from(leaving_ps, moving_entity.move_facing, skip_entity_inst_ids)
        if entity_has_property(moving_entity, "i_move_away_from"):
            for e in entities_moving_away_from:
                if not conditional_entity_interaction("i_move_away_from", moving_entity, e, leaving_ps, true):
                    result = false
        for e in entities_moving_away_from:
            if not conditional_entity_interaction("move_away_from", e, moving_entity, leaving_ps, true):
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
        var frontier: = {}
        if entity.is_large():
            frontier = entity.get_current_move_frontier()
        var from_positions: Array = frontier.from if frontier else [entity.get_stationary_position()]
        for from_pos in from_positions:
            if not from_pos in half_moved_at_positions:
                half_moved_at_positions[from_pos] = {"leaving": [], "entering": []}
            half_moved_at_positions[from_pos]["leaving"].append(entity)
        var to_positions: Array = frontier.to if frontier else [entity.get_moving_position()]
        for to_pos in to_positions:
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

func can_move_to_multiple(moving_entity: BaseEntity, tile_positions: Array[Vector2i], change_facing_to: int = -1) -> bool:
    var old_facing: int = moving_entity.facing
    if change_facing_to >= 0:
        moving_entity.set_facing_only(change_facing_to)

    var entities_here: = get_entities_at_multiple(tile_positions, moving_entity)
    for e in entities_here:
        var blocks: = get_entity_property(e, "blocks")
        if blocks:
            if blocks.is_conditional():
                if blocks.resolve(e, moving_entity, [e.get_moving_position()]):
                    return false
            else:
                if blocks.get_value():
                    return false
    moving_entity.set_facing_only(old_facing)
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

func get_static_entity_prop_with_default(entity: BaseEntity, property_name: String, default_value: Variant) -> Variant:
    if not entity_has_property(entity, property_name):
        return default_value
    var prop: Property = get_entity_property(entity, property_name)
    if prop.is_conditional():
        return false
    else:
        return prop.get_value()

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

func get_entity_prop_is_truthy(entity: BaseEntity, property_name: String, default_val: bool = false, custom_ctx_entity: BaseEntity = null) -> bool:
    if not entity_has_property(entity, property_name):
        return default_val
    return Property.resolve_truthy(get_entity_property(entity, property_name), entity, custom_ctx_entity, entity.tile_position)

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
        if instance_id in entity_instance_map:
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
    var input_list: = to_remove_entities
    to_remove_entities = []
    for entity in input_list:
        if not entity.instance_id in entity_instance_map:
            continue
        to_remove_entities.append(entity)
        entity.set_active(false)

    for entity in to_remove_entities:
        if entity.bond_group:
            unbond_single_entity_with_lonely_group_dissolve(entity, false, true)

    for entity in to_remove_entities:
        if entity in entity_signal_connections:
            for connected_sig in entity_signal_connections.get(entity, []):
                var signal_connections = get_signal_connection_list(connected_sig)
                for sig_conn in signal_connections:
                    if (sig_conn.callable as Callable).get_object() == entity:
                        sig_conn.signal.disconnect(sig_conn.callable)
            entity_signal_connections.erase(entity)
        entity.remove_from_group("_entity_")
        entity_instance_map.erase(entity.instance_id)
        entity_list.erase(entity)
        entity.queue_free()
    
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

func get_default_move_speed() -> float:
    return GameManager.get_game_setting("entity_move_speed", DEFAULT_MOVE_SPEED)

func get_default_spt() -> int:
    return BaseEntity._speed_to_spt(get_default_move_speed())

func get_default_tele_steps() -> int:
    var def_duration: float = GameManager.get_game_setting("default_teleport_duration", DEFAULT_TELEPORT_DURATION)
    return ceili(def_duration * GameManager.get_full_tick_rate())

func switch_entities_preview_mode(enable_preview: bool) -> void:
    is_entity_preview_mode = enable_preview
    entity_preview_mode_changed.emit(enable_preview)

func save_entity_sprite_snapshot(entity_id: int, snapshot: ImageTexture, snapshot_zoom: float = -1) -> void:
    if snapshot_zoom < 0:
        snapshot_zoom = GameManager.get_default_pixel_scale()
    entity_sprite_snapshots[entity_id] = snapshot
    entity_sprite_snapshot_scales[entity_id] = snapshot_zoom

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
        "effects": { "scale": [0.75, 0.75], },
    },
    "Grow": {
        "name": "effect-grow",
        "effects": { "scale": [1.25, 1.25], },
    },
    "Color": {
        "name": "effect-color",
        "effects": { "replace_color": { "color": "#FFFFFF", "amount": 1.0 } },
    },
    "Multiplied Color": {
        "name": "effect-multiplied-color",
        "effects": { "modulate": { "color": "#FFFFFFFF" } },
    },
    "Sparkling": {
        "name": "bump-sparkle",
        "layers": [{
            "mode": "particles",
            "particles_type": "sparkles",
            "receives_effects": false,
            "mod_color": "#FFFFFFFF",
        }],
    },
}

func special_effect_with_amount(effect_name: String, amount: float) -> Dictionary:
    var effect_info: Dictionary = special_effects[effect_name].duplicate_deep()
    if effect_name in ["Shrink", "Grow"]:
        var scale_val: float = 1 + amount if effect_name == "Grow" else 1 - amount
        effect_info["effects"]["scale"] = [scale_val, scale_val]
    return effect_info

func apply_special_effect(entity: BaseEntity, effect_name: String, color_param: Color = Color.WHITE, with_amount: float = 0.0) -> void:
    if not entity or not effect_name in special_effects:
        return
    var effect_info: Dictionary = special_effect_with_amount(effect_name, with_amount)
    if effect_name == "Color":
        effect_info["effects"]["replace_color"]["color"] = Utility.color_string_no_alpha(color_param)
        effect_info["effects"]["replace_color"]["amount"] = color_param.a
    elif effect_name == "Multiplied Color":
        effect_info["effects"]["modulate"]["color"] = Utility.color_string(color_param, true)
    elif effect_name == "Sparkling":
        effect_info["layers"][0]["mod_color"] = Utility.color_string(color_param, true)
    entity.add_sprite_modifier(effect_info)

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
    if not GameManager.get_cam_setting("follow_entity_by", "controller") != "instances":
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
    var follow_mode: String = GameManager.get_cam_setting("follow_entity_by", "controller")
    if follow_mode in ["name", "property"] and not GameManager.get_cam_setting("follow_entity", ""):
        return false

    var follow_text: String = GameManager.get_cam_setting("follow_entity", "")
    var is_name_match: = entity_name_exists(follow_text) and get_entity_index(follow_text) == entity.entity_index
    
    if follow_mode == "controller":
        return is_entity_controller_type(entity, follow_text if follow_text else "InputController")
    elif follow_mode == "name":
        return is_name_match
    elif follow_mode == "property":
        return get_entity_prop_is_truthy(entity, follow_text)
    elif follow_mode == "name or property":
        return is_name_match or get_entity_prop_is_truthy(entity, follow_text)
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

func remove_delayed_entity_prop_event(entity: BaseEntity, prop_event_name: String) -> void:
    if not entity.instance_id in timed_entity_events:
        return
    var new_events: Array[Dictionary] = []
    for event_info in timed_entity_events[entity.instance_id]:
        if event_info["property_event"] != prop_event_name:
            new_events.append(event_info)
    timed_entity_events[entity.instance_id] = new_events

func merge_entity_bond_groups(entity1: BaseEntity, entity2: BaseEntity) -> void:
    if entity1.bond_group and entity1.bond_group.has(entity2.instance_id):
        prints("group already merged")
        return

    if not entity1.bond_group and not entity2.bond_group:
        prints("creating new bond group with ", entity1.instance_id, "and", entity2.instance_id)
        create_bond_group([entity1, entity2])
        return
    elif not entity1.bond_group or not entity2.bond_group:
        bond_entity(
            entity2 if entity1.bond_group else entity1,
            entity1.bond_group if entity1.bond_group else entity2.bond_group
        )
        return
    
    var all_entities: Array[BaseEntity] = []
    for inst_id in entity1.bond_group:
        if has_instance(inst_id):
            all_entities.append(get_instance(inst_id))
    for inst_id in entity2.bond_group:
        if has_instance(inst_id):
            all_entities.append(get_instance(inst_id))
    create_bond_group(all_entities)

func merge_entity_array_bond_groups(entities: Array[BaseEntity]) -> void:
    var old_bond_groups: Array = bond_groups.duplicate()
    bond_groups = []
    for bg in old_bond_groups:
        if bg.size() > 0:
            bond_groups.append(bg)
            
    prints("merge_entity_array_bond_groups,", entities.size(), "entities")
    prints(entities.map(func(e: BaseEntity): return e.instance_id))
    if entities.size() < 2:
        prints("not enough entities to make a bond group")
        return
    
    var entity_a: BaseEntity = entities.pop_front()
    for entity_b in entities:
        prints("merging", entity_a.instance_id, "with", entity_b.instance_id)
        merge_entity_bond_groups(entity_a, entity_b)
    
    prints("all bond groups:", bond_groups)
    

func disolve_entity_bond_group(entity: BaseEntity, with_event: bool = true) -> void:
    if not entity.bond_group:
        return
    var bond_group_of_entity: Array = find_bond_group_of_entity(entity)
    for inst_id in bond_group_of_entity:
        if has_instance(inst_id):
            var bonded_entity: BaseEntity = get_instance(inst_id)
            unbond_entity(bonded_entity, false)
            if with_event:
                bonded_entity.add_deferred_event("left_bond_group")

func break_bond_group_into_connected_groups(bond_group: Array, with_diagonal: bool, with_event: bool = true) -> void:
    var all_entities: Array[BaseEntity] = []
    var entity_positions: Dictionary[int, Array] = {}
    for inst_id in bond_group:
        if has_instance(inst_id):
            var entity: BaseEntity = get_instance(inst_id)
            all_entities.append(entity)
            entity_positions[inst_id] = get_all_positions_of_entity(entity)
    if not all_entities:
        return
    disolve_entity_bond_group(all_entities[0], false)
    
    var connected_groups: Array = []
    for entity in all_entities:
        var is_in_existing: bool = false
        var existing_indices: Array[int] = []
        var this_positions: Array[Vector2i] = entity_positions[entity.instance_id]
        for i in connected_groups.size():
            for e in connected_groups[i]:
                var other_positions: Array[Vector2i] = entity_positions[e.instance_id]
                if Utility.is_any_position_adjacent(this_positions, other_positions, with_diagonal):
                    is_in_existing = true
                    existing_indices.append(i)
                    break # now check next subgroup
        
        if not is_in_existing:
            connected_groups.append(Array([entity.instance_id], TYPE_INT, "", null))
            continue
        
        if existing_indices.size() == 1:
            connected_groups[existing_indices[0]].append(entity.instance_id)
        elif existing_indices.size() > 1:
            var merged_group: Array = []
            existing_indices.reverse()
            for i in existing_indices:
                merged_group.append_array(connected_groups[i])
                connected_groups.remove_at(i)
            connected_groups.append(merged_group)
    
    for group in connected_groups:
        if group.size() == 1:
            if with_event:
                var entity: BaseEntity = get_instance(group[0])
                entity.add_deferred_event("left_bond_group")
            continue
        create_bond_group_directly(group, false)

func break_all_bond_groups_into_connected(with_diagonal: bool, with_event: bool = true) -> void:
    for bond_group in bond_groups:
        break_bond_group_into_connected_groups(bond_group, with_diagonal, with_event)

func removing_texture_id(texture_id_to_remove: int) -> void:
    var fallback_tex: int = TextureManager.get_fallback_texture_id()
    for entity_id in entity_defs.keys():
        _remap_texture_id_in_entity(entity_id, texture_id_to_remove, fallback_tex, 0)

func remapping_texture_id(from_texture_id: int, into_texture_id: int) -> void:
    for entity_id in entity_defs.keys():
        _remap_texture_id_in_entity(entity_id, from_texture_id, into_texture_id)

func _remap_texture_id_in_entity(entity_id: int, from_texture_id: int, into_texture_id: int, overwrite_index_with: int = -1) -> void:
    _remap_texture_id_in_dict(entity_defs[entity_id], from_texture_id, into_texture_id, overwrite_index_with)
    if "preview_variant" in entity_defs[entity_id]:
        _remap_texture_id_in_dict(entity_defs[entity_id]["preview_variant"], from_texture_id, into_texture_id, overwrite_index_with)
    if "sprite_config" in entity_defs[entity_id]:
        for layer_dict in entity_defs[entity_id]["sprite_config"].get("layers", []):
            _remap_texture_id_in_dict(layer_dict, from_texture_id, into_texture_id, overwrite_index_with)

func _remap_texture_id_in_dict(dict: Dictionary, from_texture_id: int, into_texture_id: int, overwrite_index_with: int = -1) -> void:
    if "texture" in dict and int(dict["texture"]) == from_texture_id:
        dict["texture"] = into_texture_id
        if overwrite_index_with >= 0 and "tex_index" in dict:
                dict["tex_index"] = overwrite_index_with
    if "mask_texture" in dict and int(dict["mask_texture"]) == from_texture_id:
        dict["mask_texture"] = into_texture_id
        if overwrite_index_with >= 0 and "mask_tex_index" in dict:
            dict["mask_tex_index"] = overwrite_index_with

func _is_dict_using_texture_id(dict: Dictionary, texture_id: int) -> bool:
    if int(dict.get("texture", -1)) == texture_id or int(dict.get("mask_texture", -1)) == texture_id:
        return true
    return false

func _is_entity_using_texture_id(entity_id: int, texture_id: int) -> bool:
    if _is_dict_using_texture_id(entity_defs[entity_id], texture_id):
        return true
    if "preview_variant" in entity_defs[entity_id]:
        return _is_dict_using_texture_id(entity_defs[entity_id]["preview_variant"], texture_id)
    if "sprite_config" in entity_defs[entity_id]:
        for layer_dict in entity_defs[entity_id]["sprite_config"].get("layers", []):
            if _is_dict_using_texture_id(layer_dict, texture_id):
                return true
    return false

func is_texture_id_in_use(texture_id: int) -> bool:
    for entity_id in entity_defs.keys():
        if _is_entity_using_texture_id(entity_id, texture_id):
            return true
    return false

func rerender_entity_sprite_preview(entity_id: int) -> void:
    prints("rerendering entity sprite preview for entity %s" % get_entity_name(entity_id))
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
    # setting it to hidden breaks the rendering, probably the subviewport container's fault
    sprite_previewer.position.x = -10000
    return sprite_previewer

func build_sprite_previews() -> void:
    entity_sprite_snapshots.clear()
    var entities_to_gen_for: Array[int] = []
    for entity_id in entity_defs.keys():
        if entity_defs[entity_id].get("sprite_config", {}):
            entities_to_gen_for.append(entity_id)
    if not entities_to_gen_for:
        initial_sprite_previews_created = true
        initial_sprite_previews_finished.emit()
        return

    var sprite_previewer: = _get_snapshot_renderer()
    for entity_id in entities_to_gen_for:
        var entity_def: Dictionary = entity_defs[entity_id]
        if not entity_def.get("sprite_config", {}):
            continue
        await _update_sprite_preview_for_entity(entity_id, entity_def, sprite_previewer)

    sprite_previewer.queue_free()
    initial_sprite_previews_created = true
    initial_sprite_previews_finished.emit()

func render_single_sprite_preview(entity_id: int) -> void:
    var entity_def: Dictionary = entity_defs[entity_id]

    var sprite_previewer: = _get_snapshot_renderer()
    sprite_previewer.update_sprite_config(entity_def, entity_id)

    var sub_vp: SubViewport = sprite_previewer.get_subviewport()
    await Utility.force_rerender_subviewport(sub_vp)
    var img_tex: ImageTexture = ImageTexture.create_from_image(sub_vp.get_texture().get_image())
    save_entity_sprite_snapshot(entity_id, img_tex, 1)
    sprite_previewer.queue_free()
    entity_snapshots_updated.emit()

func _update_sprite_preview_for_entity(entity_id: int, entity_def: Dictionary, sprite_previewer: SpritePreviewer) -> void:
    if not entity_def.get("preview_variant", {}).is_empty():
        return
    sprite_previewer.update_sprite_config(entity_def, entity_id)
    var sub_vp: SubViewport = sprite_previewer.get_subviewport()

    await Utility.force_rerender_subviewport(sub_vp)
    var img_tex: ImageTexture = ImageTexture.create_from_image(sub_vp.get_texture().get_image())
    save_entity_sprite_snapshot(entity_id, img_tex, 1)

func _get_all_entities_that_are_tailing_something(include_inactive: bool = false) -> Array[BaseEntity]:
    var tailing_entities: Array[BaseEntity] = []
    for entity in entity_list:
        if not entity.tailing or (not include_inactive and not entity.active):
            continue
        tailing_entities.append(entity)
    return tailing_entities

func get_entities_tailing_behind(head_entity: BaseEntity, include_self: bool = false) -> Array[BaseEntity]:
    var exclude_list: Array[BaseEntity] = []
    if not include_self:
        exclude_list.append(head_entity)
    return get_entity_tailing_chain(head_entity, true, false, exclude_list, false)

func get_direct_tailing_entities(of_entity: BaseEntity) -> Array[BaseEntity]:
    if not of_entity:
        return []
    var tailing_entities: Array[BaseEntity] = []
    for tailing_entity in _get_all_entities_that_are_tailing_something():
        if tailing_entity.tailing.instance_id == of_entity.instance_id:
            tailing_entities.append(tailing_entity)
    return tailing_entities

func get_tailing_chain_head_entity(reference_entity: BaseEntity, allow_self: bool = true) -> BaseEntity:
    if not reference_entity or not reference_entity.active:
        return null
    if not allow_self and not reference_entity.tailing:
        return null
    var front_chain: = get_entity_tailing_chain(reference_entity, false, true, [], false)
    if front_chain.size() == 0:
        return reference_entity if allow_self else null
    for e in front_chain:
        if not e.tailing:
            return e
    return null

# tailing chain could branch tailward, this returns the first found tip entity with at least the maximum chain length
func get_tailing_tail_tip(reference_entity: BaseEntity) -> BaseEntity:
    if not reference_entity or not reference_entity.active:
        return null
    var tailing_behind: = get_entity_tailing_chain(reference_entity, true, false, [reference_entity], false)
    if tailing_behind.size() == 0:
        return null
    var ref_inst_id: int = reference_entity.instance_id
    var tailing_ref_ids: Array = tailing_behind.map(func(e: BaseEntity): return e.instance_id)
    var chain_lengths: Dictionary[int, int] = {}
    var max_chain_length: int = 0
    for tailing_entity in tailing_behind:
        var this_id: int = tailing_entity.instance_id
        var tailing_id: int = tailing_entity.tailing.instance_id
        var chain_length: int = 0
        if tailing_id == ref_inst_id:
            chain_length = 1
        elif tailing_id in chain_lengths:
            chain_length = chain_lengths[tailing_id] + 1
        else:
            var chain: Array[int] = [this_id]
            var next_id: int = tailing_id
            var safetey: = 10000
            while next_id != ref_inst_id and next_id in tailing_ref_ids:
                if not EntityManager.has_instance(next_id):
                    push_error("Tailing entity instance id not found: " + str(next_id))
                    return null
                chain.append(next_id)
                var next_entity: BaseEntity = get_instance(next_id)
                if not next_entity.tailing:
                    break
                next_id = next_entity.tailing.instance_id
                safetey -= 1
                if safetey <= 0:
                    push_error("Tailing tip loop max iterations reached, stopping")
                    return null
            chain_length = chain.size()
        max_chain_length = maxi(max_chain_length, chain_length)
        chain_lengths[this_id] = chain_length

    if max_chain_length > 0:
        for inst_id in chain_lengths:
            if chain_lengths[inst_id] == max_chain_length:
                return get_instance(inst_id)
    push_error("Unable to find the tail tip for an unknown reason")
    return null


func get_entity_tailing_chain(reference_entity: BaseEntity, with_behind: bool, with_in_front: bool, exclude_list: Array[BaseEntity] = [], include_inactive: bool = false) -> Array[BaseEntity]:
    if not reference_entity:
        return []
    var all_tailing: Array[BaseEntity] = _get_all_entities_that_are_tailing_something(include_inactive)

    var exclude_instances: Array[int] = []
    exclude_instances.assign(exclude_list.map(func(e: BaseEntity): return e.instance_id))
    
    var entire_chain: Array[BaseEntity] = [reference_entity]
    var chain_instances: Array[int] = [reference_entity.instance_id]
    var filtered_chain: Array[BaseEntity] = []
    if reference_entity.instance_id not in exclude_instances and (reference_entity.active or include_inactive):
        filtered_chain.append(reference_entity)

    if not with_in_front and not with_behind:
        return filtered_chain

    var check_in_front: bool = with_in_front and reference_entity.tailing
    
    # loop until no more entities found
    var new_added: bool = true
    for i in 10000:
        if not new_added:
            break
        new_added = false
        for e in all_tailing:
            if e.instance_id in chain_instances:
                continue
            if check_in_front:
                for chain_entity in entire_chain:
                    if chain_entity.tailing.instance_id != e.instance_id:
                        continue
                    new_added = true
                    entire_chain.append(e)
                    chain_instances.append(e.instance_id)
                    if e.instance_id not in exclude_instances:
                        filtered_chain.append(e)
                    break

            if with_behind and e.tailing.instance_id in chain_instances:
                new_added = true
                entire_chain.append(e)
                chain_instances.append(e.instance_id)
                if e.instance_id not in exclude_instances:
                    filtered_chain.append(e)

    return filtered_chain

func on_textures_remapped() -> void:
    build_sprite_previews()

func get_default_dying_effect_for_entity_id(entity_id: int) -> Dictionary:
    if not entity_id in entity_defs:
        push_error("Entity id not found: %s" % entity_id)
        return {}
    var dying_effect_prop_val: Variant = entity_defs[entity_id]["properties"].get("dying-effect", "")
    if typeof(dying_effect_prop_val) != TYPE_STRING:
        prints("entity dying-effect is the wrong type: %s" % type_string(typeof(dying_effect_prop_val)))
        return default_dying_effect
    if dying_effect_prop_val.to_lower() == "none":
        return {}
    if not dying_effect_prop_val or not dying_effect_prop_val in SpriteEffects.DYING_EFFECTS:
        return default_dying_effect
    return SpriteEffects.DYING_EFFECTS[dying_effect_prop_val]

func track_move_starting(moving_entity: BaseEntity, is_group_move: bool = false, is_revertable: bool = false) -> Dictionary:
    if not moving_entity:
        return {}
    if not _nested_related_moves:
        var new_move_node: = _new_related_move(moving_entity, is_revertable)
        _nested_related_moves["group_move"] = is_group_move
        if is_group_move:
            _nested_related_moves = _fake_related_move()
            _nested_related_moves["child_moves"].append(new_move_node)
        else:
            _nested_related_moves = new_move_node
        _cur_related_move_node = new_move_node
    else:
        var new_move_node: = _append_related_move(moving_entity, is_revertable)
        new_move_node["group_move"] = is_group_move
        _cur_related_move_node = new_move_node
    return _cur_related_move_node

func clear_related_move_cache() -> void:
    _nested_related_moves = {}
    _cur_related_move_node = {}
    _finished_related_move_node = {}

func _new_related_move(moving_entity: BaseEntity, is_revertable: bool = false) -> Dictionary:
    return {
        "moving_entity": moving_entity,
        "fake": false,
        "group_move": false,
        "revertable": is_revertable,
        "instance_id": moving_entity.instance_id,
        "child_moves": [],
    }

func _fake_related_move() -> Dictionary:
    return {
        "moving_entity": null,
        "fake": true,
        "group_move": false,
        "revertable": false,
        "instance_id": -1,
        "child_moves": [],
    }

# only call if just started move succeeded
func set_just_started_move_as_revertable(as_revertable: bool) -> void:
    if not _nested_related_moves or not _finished_related_move_node:
        push_error("Cant set move revertable status")
        return
    if _finished_related_move_node["group_move"]:
        var group_instance_ids: Array = _finished_related_move_node["moving_entity"].bond_group.duplicate()
        var sibling_nodes: Array = _get_sibling_move_nodes(_finished_related_move_node)
        for sibling_node in sibling_nodes:
            if sibling_node["fake"] or sibling_node["instance_id"] not in group_instance_ids:
                continue
            sibling_node["revertable"] = as_revertable
    else:
        _finished_related_move_node["revertable"] = as_revertable

func _append_related_move(moving_entity: BaseEntity, is_revertable: bool = false) -> Dictionary:
    if not _cur_related_move_node or not _cur_related_move_node.has("child_moves"):
        push_error("None or invalid current related move node")
        return {}
    var new_move_node: Dictionary = _new_related_move(moving_entity, is_revertable)
    _cur_related_move_node["child_moves"].append(new_move_node)
    return new_move_node

func just_finished_move_start(related_move_node: Dictionary, move_result: bool) -> void:
    if not related_move_node or not _nested_related_moves:
        push_error("None or invalid move node or node tree")
        return

    if move_result:
        _finished_related_move_node = related_move_node
    elif not related_move_node["group_move"]:
        _failed_move_start(related_move_node)
    
    # not ideal implementation, but should always need to set the parent of this move as the current move again
    if _nested_related_moves and not is_same(_nested_related_moves, related_move_node):
        var move_parent: = _get_parent_move_node(related_move_node)
        if move_parent and not is_same(_cur_related_move_node, move_parent):
            _cur_related_move_node = move_parent

    if _nested_related_moves and is_same(_nested_related_moves, related_move_node):
        _nested_related_moves = {}
        _cur_related_move_node = {}

func failed_group_move_start(parent_related_move: Dictionary, instance_ids: Array) -> void:
    if not parent_related_move or not instance_ids:
        return
    for child_move_node in parent_related_move["child_moves"]:
        if child_move_node["instance_id"] in instance_ids:
            # group move failing already reverts group member movements, trigger revert on grandchild related moves
            for grandchild in child_move_node["child_moves"]:
                _failed_move_start(grandchild)
    _cur_related_move_node = parent_related_move

func _failed_move_start(related_move_node: Dictionary) -> void:
    _revert_related_move_node(related_move_node)
    if not is_same(_nested_related_moves, related_move_node):
        var parent_node: = _get_parent_move_node(related_move_node)
        if parent_node:
            parent_node["child_moves"].erase(related_move_node)

func _get_parent_move_node(related_move_node: Dictionary, at_node: Dictionary = {}) -> Dictionary:
    if not at_node:
        if is_same(_nested_related_moves, related_move_node):
            return {}
        at_node = _nested_related_moves
    for child_move_node in at_node["child_moves"]:
        if is_same(child_move_node, related_move_node):
            return at_node
        var found_parent: = _get_parent_move_node(related_move_node, child_move_node)
        if found_parent:
            return found_parent
    return {}

func _get_sibling_move_nodes(related_move_node: Dictionary) -> Array:
    if is_same(_nested_related_moves, related_move_node):
        return []
    var parent_node: = _get_parent_move_node(related_move_node)
    if not parent_node:
        return []
    return parent_node["child_moves"].duplicate()

func _revert_related_move_node(related_move_node: Dictionary) -> void:
    if related_move_node["revertable"]:
        for child_move_node in related_move_node["child_moves"]:
            _revert_related_move_node(child_move_node)
        if not related_move_node["fake"]:
            related_move_node["moving_entity"].revert_move_start()

# Not using this idea atm
#func is_entity_move_started_within_stack(entity: BaseEntity) -> bool:
#    if not entity or not _move_resolution_stack:
#        return false
#    return entity.instance_id in _move_stack_metadata.get("started_move_instances", [])
#
#func _move_resolution_stack_pop() -> void:
#    if not _move_resolution_stack:
#        return
#    if _move_resolution_stack.size() == 1:
#        _move_resolution_stack.clear()
#        _move_stack_metadata.clear()
#    else:
#        _move_resolution_stack.pop_back()
#
#func _add_move_resolution_start(entity: BaseEntity) -> void:
#    if not entity:
#        return
#    var stack_entry: Dictionary = {
#        "entity": entity,
#        "instance_id": entity.instance_id,
#    }
#    _move_resolution_stack.append(stack_entry)
#
#func _add_instance_move_start_to_stack_meta(instance_id: int) -> void:
#    if not _move_resolution_stack:
#        return
#    if not _move_stack_metadata.has("started_move_instances"):
#        _move_stack_metadata["started_move_instances"] = Array([], TYPE_INT, "", null)
#    if instance_id in _move_stack_metadata["started_move_instances"]:
#        return
#    _move_stack_metadata["started_move_instances"].append(instance_id)

func get_sorted_tailing_chain(tailing_chain: Array) -> Array[BaseEntity]:
    var sorted: Array[BaseEntity] = []
    
    var left_to_check: = tailing_chain.duplicate()
    while left_to_check.size() > 0:
        var next_headmost: BaseEntity = null
        for e in left_to_check:
            if not e.tailing or e.tailing in sorted:
                next_headmost = e
                break
        if not next_headmost:
            break
        sorted.append(next_headmost)
        left_to_check.erase(next_headmost)
    return sorted

func convert_sorted_group_to_tailing_chain(sorted_instance_ids: Array, ensure_adjacent: bool = true) -> void:
    if sorted_instance_ids.size() < 2 or not sorted_instance_ids[0].bond_group:
        return

    var entity_arr: Array[BaseEntity] = []
    var ahead_entity: BaseEntity = null
    for next_id in sorted_instance_ids:
        if not has_instance(next_id):
            continue
        entity_arr.append(get_instance(next_id))
        if not ahead_entity:
            ahead_entity = get_instance(next_id)
            continue

        var next_entity: BaseEntity = get_instance(next_id)
        if ensure_adjacent:
            if not Utility.is_pos_adjacent(ahead_entity.get_moving_position(), next_entity.get_moving_position()):
                continue
        
        ahead_entity.set_tailing(next_entity)
    
    unbond_entities(entity_arr, true)
        
func get_controller_duplicate(controller: Node) -> Node:
    var controller_script: Script = controller.get_script()
    if not controller_script:
        return null
    var controller_duplicate: Node = controller_script.new()
    if controller_duplicate.has_method("set_options"):
        controller_duplicate.set_options(controller.get_option_values())
    return controller_duplicate

func get_all_with_controller_type(controller_type: String, include_inactive: bool = false) -> Array[BaseEntity]:
    if not controller_type:
        return []
    var controller_inst: Node = controller_templates[controller_type].instantiate()
    var controller_script: Script = controller_inst.get_script()
    controller_inst.queue_free()

    var entities: Array[BaseEntity] = []
    for entity in entity_list:
        if not include_inactive and not entity.active:
            continue
        if entity.controller and entity.controller.get_script() == controller_script:
            entities.append(entity)
    return entities

func is_entity_controller_type(entity: BaseEntity, controller_type: String) -> bool:
    if not entity or not entity.controller:
        return false
    var controller_inst: Node = controller_templates[controller_type].instantiate()
    var controller_script: Script = entity.controller.get_script()
    controller_inst.queue_free()
    return entity.controller.get_script() == controller_script

func get_all_positions_of_entity(entity: BaseEntity, include_moving_away: bool = false) -> Array[Vector2i]:
    var positions: Array[Vector2i] = []
    if not entity.is_large():
        positions.append(entity.get_moving_position())
        if include_moving_away and entity.moving:
            positions.append(entity.get_stationary_position())
    else:
        positions.append_array(entity.get_positions_at(entity.get_moving_position()))
        if include_moving_away and entity.moving:
            for away_pos in entity.get_positions_at(entity.get_stationary_position()):
                if away_pos not in positions:
                    positions.append(away_pos)
    return positions
        
func is_discrete_mode() -> bool:
    return GameManager.get_game_mode() != GameManager.MovementMode.MOVEMENT_CONTINUOUS