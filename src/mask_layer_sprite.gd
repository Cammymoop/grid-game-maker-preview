class_name MaskLayerSprite
extends Node2D

signal dying_animation_finished

const DigitDisplay = preload("res://Scenes/digit_display.gd")

static var particle_types: Dictionary[String, PackedScene] = {
    "burning_smoke": preload("res://Scenes/Particles/burning_smoke.tscn"),
    "flames": preload("res://Scenes/Particles/flames.tscn"),
    "sparkles": preload("res://Scenes/Particles/sparkles.tscn"),

    "explode": preload("res://Scenes/Particles/explode_particles.tscn"),
    "dust_poof": preload("res://Scenes/Particles/dust_poof_particles.tscn"),
}

var digit_display_scn: PackedScene = preload("res://Scenes/digit_display.tscn")
var clipping_spr_scn: PackedScene = preload("res://src/Utility/sub_vp_friendly_clipping_sprite.tscn")

var replace_color_mat: ShaderMaterial = preload("res://src/Effects/sprite_with_replace_color.tres")
var replace_color_9_patch_mat: ShaderMaterial = preload("res://src/Effects/nine_patch_replace_color_spr.tres")

var layers: Array[Dictionary] = []
var current_rotation: float = 0
var _facing_lerp_from_rotation: float = 0.0
var _current_facing: int = 0
var elapsed_time: float = 0.0

var base_entity_id: int = -1
var base_entity_props: Dictionary = {}

var _animated_spinning: bool = false

var preview_info: Dictionary = {}

var layer_order_id: int = 0

var _all_modifiers: Dictionary = {}
var _animation_timers: Dictionary[String, float] = {}

var modifier_masks: Dictionary = {}
var modifier_effects: Dictionary = {}
var animated_effects: Dictionary = {}

var animated_modifiers: Array[String] = []

var prop_update_response: Dictionary[String, Array] = {}

var is_preview_mode: bool = false

var _local_prop_updated: = false
var _dying_with_animated_mod: String = ""
var parent_entity: BaseEntity = null

var _spawning_with_animated_mod: String = ""

var unoriented_center: Vector2 = Vector2.ZERO
var unoriented_bounds: Vector2 = Vector2(32, 32)
var simple_rotate: bool = true

var interpolate_facing_enabled: bool = true
var interp_facing_timer: float = 0.0
@export var facing_interp_duration: float = 0.24
@export_exp_easing() var interp_ease_param: float = 0.2

var interpolate_size_change_enabled: bool = true
var interp_size_change_mode: Utility.PosInterpStyle = Utility.PosInterpStyle.EASE_OUT
var interp_size_change_timer: float = 0.0
var interp_size_change_duration: float = 0.1

var _size_interp_from_offset: Vector2 = Vector2.ZERO
var _size_interp_from_scale: Vector2 = Vector2.ONE

var layer_root: Node2D = null
var large_auto_scale_enabled: bool = false
var large_auto_scale_size: Vector2 = Vector2.ONE

var _moving: bool = false

var _has_alternate_texture_source: bool = false
var _alternate_texture_source: Object = null

var _lingering_particle_lifetimes: Dictionary[Node2D, float] = {}

var rotation_prop: float = 0:
    get:
        return current_rotation
    set(new_rotation):
        set_sprite_rotation(new_rotation)

func _enter_tree() -> void:
    var parent: Node = get_parent()
    if not parent.is_node_ready():
        await parent.ready
    
    if parent is BaseEntity:
        parent_entity = parent
        parent.local_prop_changed.connect(_notify_local_prop_updated.unbind(1))
        is_preview_mode = EntityManager.is_entity_preview_mode
        EntityManager.entity_preview_mode_changed.connect(on_entity_preview_mode_changed)
    else:
        parent_entity = null

func ensure_layer_root() -> void:
    if not layer_root:
        layer_root = Node2D.new()
        layer_root.name = "LayerRoot"
        add_child(layer_root, true)

func _notify_local_prop_updated() -> void:
    _local_prop_updated = true

func _process(delta: float) -> void:
    particle_process(delta)

func particle_process(delta: float) -> void:
    for lingering_particle_layer in _lingering_particle_lifetimes.keys():
        _lingering_particle_lifetimes[lingering_particle_layer] -= delta
        if _lingering_particle_lifetimes[lingering_particle_layer] <= 0.0:
            prints("lingering particle layer %s is expiring" % lingering_particle_layer.name)
            lingering_particle_layer.queue_free()
            _lingering_particle_lifetimes.erase(lingering_particle_layer)

func sprite_process(delta_time: float, is_frozen: bool = false) -> void:
    elapsed_time += delta_time
    update_spinning_layers()
    if not is_frozen:
        update_head_facing_layers()
    if _local_prop_updated:
        _local_prop_updated = false
        if parent_entity:
            on_local_prop_update_frame(parent_entity)
    var is_visual_moving: bool = get_is_visual_moving();
    if parent_entity and _moving != is_visual_moving:
        _moving = is_visual_moving
        update_layers_moving_visibility()
    elif not parent_entity:
        update_layers_moving_visibility()
        
    if not is_frozen:
        if interpolate_facing_enabled:
            if interp_facing_timer > 0:
                interp_facing_timer = maxf(0, interp_facing_timer - delta_time)
                var eased_progress: float = ease(1 - (interp_facing_timer / facing_interp_duration), interp_ease_param)

                var to_angle: float = Utility.facing_rotation(parent_entity.facing)
                var interp_angle: float = lerp_angle(_facing_lerp_from_rotation, to_angle, eased_progress)
                set_sprite_rotation(interp_angle)
        if interpolate_size_change_enabled:
            if interp_size_change_timer > 0:
                interp_size_change_timer = maxf(0, interp_size_change_timer - delta_time)
                var size_change_progress: float = 1 - (interp_size_change_timer / interp_size_change_duration)
                var eased_progress: float = Utility.get_interp_factor(interp_size_change_mode, size_change_progress)
                
                scale = _size_interp_from_scale.lerp(large_auto_scale_size, eased_progress)
                var new_offset: Vector2 = _size_interp_from_offset.lerp(Vector2.ZERO, eased_progress)
                _update_oriented_position(new_offset)
                update_all_layers_shader_scale()

    process_animated_modifiers(delta_time, is_frozen)

func update_layers_moving_visibility() -> void:
    for layer_node in layer_root.get_children():
        if not layer_node.has_meta("show_when_moving"):
            continue
        layer_node.set_meta("moving_visible", _moving == layer_node.get_meta("show_when_moving"))
        update_layer_visible(layer_node)

func get_animated_modifiers_for_update(is_frozen: bool) -> Array[String]:
    if not is_frozen:
        return animated_modifiers
    var unfreezable_modifiers: Array[String] = []
    for mod_name in animated_modifiers:
        if _all_modifiers[mod_name].get("unfreezable", false):
            unfreezable_modifiers.append(mod_name)
    return unfreezable_modifiers

func process_animated_modifiers(delta_time: float, is_frozen: bool) -> void:
    var expired_modifiers: Array[String] = []
    for mod_name in get_animated_modifiers_for_update(is_frozen):
        if not mod_name in _animation_timers:
            continue
        _animation_timers[mod_name] += delta_time
        #prints("mod %s, timer %s" % [mod_name, _animation_timers[mod_name]])
        var expire_time: float = _all_modifiers[mod_name].get("expire_time", 0)
        if expire_time > 0 and _animation_timers[mod_name] >= expire_time:
            expired_modifiers.append(mod_name)
    for mod_name in expired_modifiers:
        remove_modifier(mod_name)
        if _dying_with_animated_mod == mod_name:
            dying_animation_finished.emit()
    apply_animated_effects_to_sprite(delta_time)
    
func apply_animated_effects_to_sprite(delta_time: float = 0) -> void:
    if delta_time > 0 and not animated_effects:
        return
    for animated_effect_name in SpriteEffects.LOW_LEVEL_ANIM_EFFECTS:
        _apply_animated_effect_to_sprite(animated_effect_name, delta_time)


func on_entity_preview_mode_changed(enable_preview: bool) -> void:
    is_preview_mode = enable_preview
    if preview_info:
        refresh_layers()

func set_preview_info(new_preview_info: Dictionary) -> void:
    preview_info = new_preview_info.duplicate_deep()
    if not preview_info.has("mode"):
        preview_info["mode"] = "normal"
    if is_preview_mode:
        refresh_layers()

func set_base_entity_info(entity_id: int, new_props: Dictionary = {}) -> void:
    base_entity_id = entity_id
    base_entity_props = new_props.duplicate_deep()

func set_as_single(single_texture_id: int, tex_index: int, rotates: bool = true) -> void:
    var layer_info: Dictionary = {
        "mode": "normal",
        "texture": single_texture_id,
        "tex_index": tex_index,
        "rotates": rotates,
    }
    set_main_layers([layer_info])

# a bit hacky but we want to keep any extra info we save to layers for the updated layers, based on the layer order passed in
func set_main_layers(new_layers: Array) -> void:
    # get the _keys and order_id from all the current main layers, ignore all other keys so we dont add them into a layer which doesnt have that key set
    var old_main_layers: Dictionary[int, Dictionary] = {}
    for layer_info in layers:
        if layer_info.get("is_main_layer", false):
            var old_layer_copy: = {}
            for key in layer_info.keys():
                if key.begins_with("_") or key == "order_id":
                    old_layer_copy[key] = layer_info[key]
            old_main_layers[layer_info["main_layer_index"]] = old_layer_copy

    remove_main_layers()
    new_layers = new_layers.duplicate_deep()
    for main_layer_idx in new_layers.size():
        var new_main_layer: Dictionary = new_layers[main_layer_idx]
        new_main_layer["is_main_layer"] = true
        new_main_layer["main_layer_index"] = main_layer_idx
        var new_layer_order_id: int = -1
        if old_main_layers.has(main_layer_idx):
            new_main_layer.merge(old_main_layers[main_layer_idx], false)
            new_layer_order_id = old_main_layers[main_layer_idx]["order_id"]
        _append_layer(new_main_layer, new_layer_order_id)
    refresh_layers()
    
    base_entity_props.clear()

func remove_main_layers() -> void:
    if not layers:
        return
    var new_layers: Array[Dictionary] = []
    for layer in layers:
        if not layer.get("is_main_layer", false):
            new_layers.append(layer)
    layers = new_layers

func append_layer(layer_info: Dictionary, with_order_id: int = -1) -> void:
    _append_layer(layer_info.duplicate_deep(), with_order_id)
    refresh_layers()

func _append_layer(layer_info: Dictionary, with_order_id: int = -1) -> void:
    if not layer_info.has("mode"):
        layer_info["mode"] = "normal"
    if with_order_id != -1:
        layer_info["order_id"] = with_order_id
    else:
        layer_info["order_id"] = layer_order_id
        layer_order_id += 1
    layers.append(layer_info)

# any time layers are changed, recalculate the zero time for the spinning layers based on the current visual angle the layer based on that layer info was at
# this way changing layer rotation mode to spinning or changing spin speed doesn't cause any sudden jumps and spin speed can even be animated
func _track_layer_angles() -> void:
    for layer in layers:
        if not layer.get("rotates", true):
            layer.erase("_spin_time_zero")
            layer.erase("_prev_spinning")
            layer["_was_fixed"] = true
        else:
            if layer.has("spinning"):
                if layer.has("_prev_spinning"): # spin speed is changing
                    if layer["_prev_spinning"] != layer["spinning"]:
                        var cur_angle: float = _spin_angle(layer["_prev_spinning"], layer["_spin_time_zero"])
                        layer["_spin_time_zero"] = _reculculate_spin_zero_time(cur_angle, layer["spinning"])
                else: # changing to spinning from fixed or rotates with sprite
                    var prev_layer_angle: float = 0.0 if layer.get("_was_fixed", false) else current_rotation
                    layer["_spin_time_zero"] = _reculculate_spin_zero_time(prev_layer_angle, layer["spinning"])
                layer["_prev_spinning"] = layer["spinning"]
            else:
                layer.erase("_spin_time_zero")
                layer.erase("_prev_spinning")
            layer["_was_fixed"] = false

func refresh_layers() -> void:
    if not parent_entity and is_inside_tree():
        parent_entity = get_parent() as BaseEntity
    ensure_layer_root()
    clear_children()
    prop_update_response.clear()
    
    _track_layer_angles()
    resort_layer_infos()
    if preview_info and is_preview_mode:
        create_and_add_nodes_for_layer(preview_info, 0)
    else:
        for layer_index in layers.size():
            create_and_add_nodes_for_layer(layers[layer_index], layer_index)
    if parent_entity:
        refresh_cam_focus()
        _moving = get_is_visual_moving();
    update_layers_moving_visibility()
    if parent_entity:
        on_local_prop_update_frame(parent_entity)
    elif base_entity_id != -1:
        do_base_prop_update(base_entity_id)
    
    if _lingering_particle_lifetimes.size() > 0:
        resort_lingering_particle_layers()

func clear() -> void:
    modifier_masks.clear()
    layers.clear()
    layer_order_id = 0
    clear_children()

func _layer_sort_compare(layer_a: Dictionary, layer_b: Dictionary) -> bool:
    var same_priority: bool = layer_a.get("sort_priority", 0) == layer_b.get("sort_priority", 0)
    if same_priority:
        return layer_a["order_id"] < layer_b["order_id"]
    return layer_a.get("sort_priority", 0) < layer_b.get("sort_priority", 0)

func _layer_node_sort_compare(layer_a: Node2D, layer_b: Node2D) -> bool:
    var a_sort_priority: int = layer_a.get_meta("sort_priority", 0)
    var b_sort_priority: int = layer_b.get_meta("sort_priority", 0)
    if a_sort_priority == b_sort_priority:
        return layer_a.get_meta("order_id", -1) < layer_b.get_meta("order_id", -1)
    return a_sort_priority < b_sort_priority

func resort_layer_infos() -> void:
    layers.sort_custom(_layer_sort_compare)

func resort_lingering_particle_layers() -> void:
    if not layer_root:
        return
    
    var sorted_layers: Array[Node2D] = []
    sorted_layers.assign(layer_root.get_children())
    sorted_layers.sort_custom(_layer_node_sort_compare)
    for dest_index in sorted_layers.size():
        layer_root.move_child(sorted_layers[dest_index], dest_index)

func apply_modifier_info(modifier_info: Dictionary) -> void:
    modifier_info = modifier_info.duplicate_deep()
    if not modifier_info.has("name"):
        return
    var modifier_name: String = modifier_info["name"]
    if has_applied_modifier(modifier_name):
        return
    for layer in modifier_info.get("layers", []):
        layer["modifier"] = modifier_name
        _append_layer(layer)
    modifier_masks[modifier_name] = modifier_info.get("mask_info", {})
    if modifier_masks[modifier_name]:
        _apply_modifier_mask_modifier(modifier_name)
    if modifier_info.has("effects"):
        for effect_name in modifier_info["effects"]:
            _add_modifier_effect_stuff(effect_name, modifier_name, modifier_info["effects"][effect_name])
    if modifier_info.get("animated_effects", {}):
        if not animated_modifiers.has(modifier_name):
            animated_modifiers.append(modifier_name)
        for effect_name in modifier_info["animated_effects"]:
            _add_animated_modifier_effect(effect_name, modifier_name, modifier_info["animated_effects"][effect_name])
    if modifier_info.get("expire_time", 0) > 0:
        if not animated_modifiers.has(modifier_name):
            animated_modifiers.append(modifier_name)
        if modifier_info.get("is_dying_effect", false):
            _dying_with_animated_mod = modifier_name
        if modifier_info.get("is_spawning_effect", false):
            _spawning_with_animated_mod = modifier_name
    _all_modifiers[modifier_name] = modifier_info.duplicate_deep()
    refresh_layers()

    if modifier_name in animated_modifiers:
        _animation_timers[modifier_name] = 0.0
        apply_animated_effects_to_sprite()

func has_applied_modifier(modifier_name: String) -> bool:
    return modifier_name in _all_modifiers

func remove_modifier(modifier_name: String) -> void:
    if not has_applied_modifier(modifier_name):
        return
    modifier_masks.erase(modifier_name)
    _remove_modifier_effect_stuff(modifier_name)
    _remove_animated_modifier_effects(modifier_name)
    _remove_modifier_layers(modifier_name)
    _apply_most_recent_modifier_mask()
    _animation_timers.erase(modifier_name)
    _all_modifiers.erase(modifier_name)
    if animated_modifiers.has(modifier_name):
        animated_modifiers.erase(modifier_name)
        apply_animated_effects_to_sprite()
    refresh_layers()

func clear_modifiers() -> void:
    modifier_masks.clear()
    modifier_effects.clear()
    _remove_all_modifier_layers()
    _remove_main_layers_mask()
    _all_modifiers.clear()

    var had_animated_effects: bool = not animated_effects.is_empty()
    animated_effects.clear()
    animated_modifiers.clear()
    if had_animated_effects:
        apply_animated_effects_to_sprite()

    _animation_timers.clear()
    refresh_layers()

func get_serialized_info(default_rotation: float = 0.0) -> Dictionary:
    var serialized_info: Dictionary = {}
    if not is_equal_approx(current_rotation, default_rotation):
        serialized_info["current_rotation"] = current_rotation

    if not _all_modifiers.is_empty():
        serialized_info["modifiers"] = _all_modifiers.duplicate_deep()
        serialized_info["animation_timers"] = _animation_timers.duplicate()
    if _dying_with_animated_mod:
        serialized_info["dying_with_animated_mod"] = _dying_with_animated_mod
    if _spawning_with_animated_mod:
        serialized_info["spawning_with_animated_mod"] = _spawning_with_animated_mod
    return serialized_info

func deserialize_sprite_info(info: Dictionary, default_rotation: float = 0.0) -> void:
    clear_modifiers()
    if info.has("current_rotation"):
        current_rotation = info["current_rotation"]
    else:
        current_rotation = default_rotation

    var animation_timers: Dictionary = info.get("animation_timers", {})
    for modifier_name in info.get("modifiers", {}):
        apply_modifier_info(info["modifiers"][modifier_name])
        if animation_timers.has(modifier_name):
            _animation_timers[modifier_name] = animation_timers[modifier_name]
    if info.has("dying_with_animated_mod"):
        _dying_with_animated_mod = info["dying_with_animated_mod"]
    if info.has("spawning_with_animated_mod"):
        _spawning_with_animated_mod = info["spawning_with_animated_mod"]

func _remove_all_modifier_layers() -> void:
    var new_layers: Array[Dictionary] = []
    for layer in layers:
        if not layer.get("modifier", ""):
            new_layers.append(layer)
    layers = new_layers

func _remove_modifier_layers(modifier: String) -> void:
    var new_layers: Array[Dictionary] = []
    for layer in layers:
        if layer.get("modifier", "") != modifier:
            new_layers.append(layer)
    layers = new_layers

func _get_texture_by_id(texture_id: int) -> Texture:
    if _has_alternate_texture_source:
        return _alternate_texture_source.get_texture_by_id(texture_id)
    return TextureManager.get_texture(texture_id)

func _get_texture_sub_index_rect(texture_id: int, sub_index: int) -> Rect2:
    if _has_alternate_texture_source:
        return _alternate_texture_source.get_texture_sub_index_rect(texture_id, sub_index)
    return TextureManager.get_index_rect(texture_id, sub_index)

func create_and_add_nodes_for_layer(layer_info: Dictionary, layer_index: int) -> void:
    if not layer_info or layer_info.get("mode", "empty") == "empty":
        return

            
    var main_layer_node: Node2D = null
    var is_masked: bool = false

    if layer_info.get("mode") == "normal":
        var layer_texture_id: int = int(layer_info.get("texture", -1))
        if layer_texture_id == -1:
            return
        
        var layer_tex: Texture = _get_texture_by_id(layer_texture_id)
        var layer_tex_rect: Rect2 = _get_texture_sub_index_rect(layer_texture_id, layer_info.get("tex_index", 0))
    
        
        is_masked = layer_info.get("masked", false)
        var mask_texture_id: int = -1
        if is_masked:
            mask_texture_id = layer_info.get("mask_texture", -1)
            if mask_texture_id == -1:
                is_masked = false

        if is_masked:
            var clipping_spr: = clipping_spr_scn.instantiate()
            clipping_spr.texture = layer_tex
            clipping_spr.region_rect = layer_tex_rect
            clipping_spr.region_enabled = true
            main_layer_node = clipping_spr

            var mask_src_tex: Texture = _get_texture_by_id(mask_texture_id)
            var mask_tex_rect: Rect2 = _get_texture_sub_index_rect(mask_texture_id, layer_info.get("mask_tex_index", 0))
            var mask_clip_outer: bool = layer_info.get("mask_clip_outer", true)
            var mask_is_bw: bool = layer_info.get("mask_is_bw", false)

            # clipping sprite template comes with the mask sprite, just need to add the texture
            # note the mask must cover the size of the clipping sprite for it to work as intended
            var mask_spr: = clipping_spr.get_child(0)
            mask_spr.texture = create_bw_mask_from_texture_region(mask_src_tex, mask_tex_rect, mask_is_bw, mask_clip_outer)
        else:
            var layer_spr: = _get_new_unmasked_sprite()
            layer_spr.texture = layer_tex
            layer_spr.region_rect = layer_tex_rect
            layer_spr.region_enabled = true
            main_layer_node = layer_spr

            var scale_as_9_patch: bool = layer_info.get("scale_as_9_patch", false)
            main_layer_node.set_meta("scale_as_9_patch", scale_as_9_patch)
            if scale_as_9_patch:
                var shader_mat: = main_layer_node.material as ShaderMaterial
                var layer_corner_size: Vector2 = Utility.get_vector2_from_arr(layer_info.get("9_patch_corner_size", [0.375, 0.375]))
                main_layer_node.set_meta("nine_patch_corner_size", layer_corner_size)
                shader_mat.set_shader_parameter("patch_size", Vector2.ONE - (layer_corner_size * 2.0));

    elif layer_info.get("mode") == "digits":
        var digit_display: = digit_display_scn.instantiate() as DigitDisplay
        main_layer_node = digit_display
        digit_display.pad_zeros = layer_info.get("pad_zeros", true)
        digit_display.set_max_digits(layer_info.get("max_digits", 1))
        
        if layer_info.get("property", ""):
            var prop_name: String = layer_info["property"]
            _add_prop_upate_callable(prop_name, set_digit_display_number.bind(digit_display))
        else:
            set_digit_display_number.call_deferred(layer_info.get("digits_number", 1), digit_display)
    elif layer_info.get("mode") == "particles":
        var particles_type: String = layer_info.get("particles_type", "")
        if not particles_type in particle_types:
            push_warning("Invalid particles type: %s" % particles_type)
            return

        main_layer_node = get_or_recycle_particle_layer(particles_type)
        apply_particle_layer_info(layer_info, main_layer_node)
        #main_layer_node = particle_types[particles_type].instantiate()

        main_layer_node.set_meta("particles_type", particles_type)
    
    # now setup pivot indirection so the main layer node will be able to get all the meta info properly later
    var offset_degrees: float = layer_info.get("offset_degrees", 0)
    main_layer_node.set_meta("offset_degrees", offset_degrees)
    
    var layer_offset: Vector2 = Utility.get_vector2_from_arr(layer_info.get("offset", [0,0]))
    var layer_pivot_offset: Vector2 = Utility.get_vector2_from_arr(layer_info.get("pivot", [0,0]))
    
    main_layer_node.set_meta("is_pivot_dummy", false)

    if layer_pivot_offset != layer_offset:
        var relative_offset: Vector2 = layer_offset - layer_pivot_offset
        if is_masked:
            main_layer_node.position = layer_pivot_offset
            var rotated_layer_offset: = relative_offset.rotated(-deg_to_rad(offset_degrees))
            main_layer_node.offset = rotated_layer_offset
        else:
            var pivot_node: Node2D = Node2D.new()
            pivot_node.add_child(main_layer_node)
            main_layer_node.position = relative_offset
            main_layer_node.rotation = deg_to_rad(offset_degrees)
            pivot_node.position = layer_pivot_offset
            # this meta was set above, make sure to copy it over
            if main_layer_node.has_meta("scale_as_9_patch"):
                pivot_node.set_meta("scale_as_9_patch", main_layer_node.get_meta("scale_as_9_patch"))
                pivot_node.set_meta("nine_patch_corner_size", main_layer_node.get_meta("nine_patch_corner_size", Vector2.ONE * 0.25))
            main_layer_node = pivot_node
            main_layer_node.set_meta("offset_degrees", 0)
            main_layer_node.set_meta("is_pivot_dummy", true)
    
    main_layer_node.set_meta("is_particle_layer", layer_info.get("mode") == "particles")

    main_layer_node.name = layer_info.get("mode", "MODE") + str(layer_index)
    main_layer_node.set_meta("unscaled_static_pos", main_layer_node.position)
    
    main_layer_node.set_meta("order_id", layer_info.get("order_id", -1))
    main_layer_node.set_meta("sort_priority", layer_info.get("sort_priority", 0))
    
    if layer_info.get("when_property", ""):
        var when_property_name: String = layer_info["when_property"]
        if layer_info.get("when_prop_expression", {}):
            var expr: Expression = Expression.new()
            var input_expr_str: String = GGMExpressionBuilder.make_expression_data_str(layer_info["when_prop_expression"])
            var safe_expr_str: String = GGMExpressionBuilder.get_safe_godot_expression_string(input_expr_str, ["V"])
            var err: = expr.parse(safe_expr_str, ["V"])
            if err != OK:
                push_error("Failed to parse expression: %s" % safe_expr_str)
                return
            _add_prop_upate_callable(when_property_name, show_hide_layer_expression.bind(expr, main_layer_node))
        else:
            var is_truthy: bool = not layer_info.get("when_prop_falsey", false)
            _add_prop_upate_callable(when_property_name, show_hide_layer.bind(main_layer_node, is_truthy))


    var base_mod_color: Color = Utility.get_dict_color(layer_info, "mod_color", Color.WHITE)
    main_layer_node.set_meta("base_mod_color", base_mod_color)
    main_layer_node.modulate = base_mod_color
    
    if not main_layer_node.has_meta("scale_as_9_patch"):
        main_layer_node.set_meta("scale_as_9_patch", false)
    
    if layer_info.get("when_camera_focus", "ignore") != "ignore":
        main_layer_node.set_meta("show_when_cam_focus", layer_info["when_camera_focus"] != "hide")
        if GameManager.cur_scene == "Play":
            check_register_cam_focus_updates()
    
    if layer_info.get("when_moving", "ignore") != "ignore":
        main_layer_node.set_meta("show_when_moving", layer_info["when_moving"] != "hide")
    
    main_layer_node.z_index = int(layer_info.get("z_offset", 0))

    if not main_layer_node.get_parent() == layer_root:
        layer_root.add_child(main_layer_node, true)
    var layer_scale: Vector2 = Utility.get_vector2_from_arr(layer_info.get("scale", [1,1]))
    main_layer_node.set_meta("static_scale", layer_scale)
    main_layer_node.scale = layer_scale
    
    main_layer_node.set_meta("modifier", layer_info.get("modifier", ""))
    
    var layer_rotates: bool = layer_info.get("rotates", true)
    var sub_layer_rotates: bool = layer_rotates
    if is_masked:
        sub_layer_rotates = layer_info.get("mask_rotates", true)
    
    if layer_info.get("rotates_to_head", false):
        main_layer_node.set_meta("rotates_with_sprite", false)
        main_layer_node.set_meta("sub_layer_rotates", sub_layer_rotates)
        main_layer_node.set_meta("faces_head", true)
    else:
        main_layer_node.set_meta("rotates_with_sprite", layer_rotates)
        main_layer_node.set_meta("sub_layer_rotates", sub_layer_rotates)
        main_layer_node.set_meta("faces_head", false)

    main_layer_node.set_meta("spinning_speed", layer_info.get("spinning", 0.0))
    main_layer_node.set_meta("spins", layer_info.has("spinning"))
    
    main_layer_node.set_meta("spin_zero_time", layer_info.get("_spin_time_zero", 0.0))

    if main_layer_node.get_meta("spins", false):
        _update_spinning_layer(main_layer_node)
    else:
        _set_sprite_layer_rotation(main_layer_node, current_rotation)
    
    if layer_info.get("is_main_layer", false) or layer_info.get("receives_effects", true):
        _apply_modifier_effects_to(main_layer_node)
    
    if main_layer_node.get_meta("scale_as_9_patch", false):
        var shader_mat: = get_layer_node_material(main_layer_node)
        shader_mat.set_shader_parameter("cur_scale_for_patch", main_layer_node.scale * scale)

func get_or_recycle_particle_layer(particles_type: String) -> Node2D:
    for layer in _lingering_particle_lifetimes.keys():
        if layer.get_meta("particles_type") == particles_type:
            resume_particle_layer(layer)
            return layer
    return particle_types[particles_type].instantiate()

func resume_particle_layer(particle_layer: Node2D) -> void:
    if particle_layer.has_method("continue_emitting"):
        particle_layer.continue_emitting()
    elif particle_layer is GPUParticles2D:
        particle_layer.emitting = true

func make_particle_layer_stop_emitting(particle_layer: Node2D) -> void:
    if particle_layer.has_method("stop_emitting"):
        particle_layer.stop_emitting()
    elif particle_layer is GPUParticles2D:
        particle_layer.emitting = false

func apply_particle_layer_info(_layer_info: Dictionary, _particle_layer: Node2D) -> void:
    pass

func check_register_cam_focus_updates() -> void:
    if not GameManager.game_camera_target_changed.is_connected(refresh_cam_focus):
        GameManager.game_camera_target_changed.connect(refresh_cam_focus.unbind(1))

func refresh_cam_focus() -> void:
    var is_in_focus: bool = GameManager.is_entity_current_camera_focus(parent_entity)
    for layer_node in layer_root.get_children():
        if not layer_node.has_meta("show_when_cam_focus"):
            continue
        layer_node.set_meta("camera_visible", is_in_focus == layer_node.get_meta("show_when_cam_focus"))
        update_layer_visible(layer_node)

func _add_prop_upate_callable(prop_name: String, update_func: Callable) -> void:
    if not prop_update_response.has(prop_name):
        prop_update_response[prop_name] = []
    prop_update_response[prop_name].append(update_func)

func on_local_prop_update_frame(entity: BaseEntity) -> void:
    for prop_name in prop_update_response:
        var raw_val: Variant = EntityManager.get_entity_prop_with_default(entity, prop_name, 0.0)
        var num_val: = Utility.property_value_scalar(raw_val, 0.0)
        for update_func in prop_update_response[prop_name]:
            update_func.call(num_val)

func do_base_prop_update(for_entity_id: int) -> void:
    var props: Dictionary = base_entity_props
    if not props:
        var entity_def: Dictionary = EntityManager.entity_defs.get(for_entity_id, {})
        if not entity_def:
            return
        props = entity_def.get("properties", {})
    for prop_name in prop_update_response:
        var num_val: = Utility.property_value_scalar(props.get(prop_name, 0.0), 0.0)
        for update_func in prop_update_response[prop_name]:
            update_func.call(num_val)


func _apply_most_recent_modifier_mask() -> void:
    var mod_names: = modifier_masks.keys()
    mod_names.reverse()
    for mod_name in mod_names:
        if modifier_masks[mod_name]:
            _apply_modifier_mask_modifier(mod_name)
            return
    _remove_main_layers_mask()

func _apply_modifier_mask_modifier(modifier_name: String) -> void:
    if not modifier_name in modifier_masks:
        push_error("Modifier mask not found: %s" % modifier_name)
        return
    _modify_main_layers_mask(modifier_masks[modifier_name])

func _modify_main_layers_mask(mask_info: Dictionary) -> void:
    if not mask_info:
        return
    for layer in layers:
        if not layer.get("is_main_layer", false):
            continue
        layer.merge(mask_info, true)

func _remove_main_layers_mask() -> void:
    for layer in layers:
        if not layer.get("is_main_layer", false):
            continue
        layer["masked"] = false

func _add_modifier_effect_stuff(effect_name: String, modifier_name: String, effect_stuff: Variant) -> void:
    if not modifier_effects.has(effect_name):
        modifier_effects[effect_name] = {}
    modifier_effects[effect_name][modifier_name] = effect_stuff

func _remove_modifier_effect_stuff(modifier_name: String) -> void:
    for effect_name in modifier_effects:
        if modifier_effects[effect_name].has(modifier_name):
            modifier_effects[effect_name].erase(modifier_name)
            if modifier_effects[effect_name].size() == 0:
                modifier_effects.erase(effect_name)

func _add_animated_modifier_effect(effect_name: String, modifier_name: String, effect_stuff: Variant) -> void:
    if not animated_effects.has(effect_name):
        animated_effects[effect_name] = {}
    animated_effects[effect_name][modifier_name] = effect_stuff

func _remove_animated_modifier_effects(for_modifier_name: String) -> void:
    for effect_name in animated_effects.keys():
        if animated_effects[effect_name].has(for_modifier_name):
            animated_effects[effect_name].erase(for_modifier_name)
            if animated_effects[effect_name].size() == 0:
                animated_effects.erase(effect_name)

func clear_children() -> void:
    if not layer_root:
        return
    for child in layer_root.get_children():
        if child.get_meta("is_particle_layer", false):
            linger_or_remove_particle_layer(child)
            continue
        child.queue_free()
        layer_root.remove_child(child)

func linger_or_remove_particle_layer(particle_layer: Node2D) -> void:
    var linger_time: float = get_particle_layer_remaining_linger_time(particle_layer)
    if linger_time < 0.0:
        particle_layer.queue_free()
        return
    make_particle_layer_stop_emitting(particle_layer)
    _lingering_particle_lifetimes[particle_layer] = linger_time

func set_sprite_facing(facing: int, immediate: bool = false) -> void:
    if interpolate_facing_enabled and not immediate:
        _facing_lerp_from_rotation = current_rotation
        _current_facing = facing
        interp_facing_timer = facing_interp_duration
    else:
        set_sprite_rotation(Utility.facing_rotation(facing))

func set_sprite_rotation(new_rotation: float, setting_anim_spin_rotation: bool = false) -> void:
    if not setting_anim_spin_rotation:
        current_rotation = new_rotation
    if _animated_spinning and not setting_anim_spin_rotation:
        return
    if not layer_root:
        return
    for layer_node in layer_root.get_children():
        if not layer_node.get_meta("spins", false):
            _set_sprite_layer_rotation(layer_node, new_rotation)

func _set_sprite_layer_rotation(layer_node: Node2D, new_rotation: float) -> void:
    if layer_node.get_meta("faces_head", false):
        return
    var layer_rotates: bool = layer_node.get_meta("rotates_with_sprite", true)
    var offset_rotation: float = deg_to_rad(layer_node.get_meta("offset_degrees", 0))
    if layer_rotates:
        new_rotation += offset_rotation
    else:
        new_rotation = offset_rotation
    layer_node.rotation = new_rotation
    var main_layer_rotation: float = layer_node.rotation - offset_rotation
    if layer_node.get_meta("sub_layer_rotates") != layer_rotates and layer_node.get_child_count() > 0:
        layer_node.get_child(0).rotation = (-2 * main_layer_rotation) + new_rotation

func update_spinning_layers() -> void:
    if _animated_spinning:
        return
    for layer_node in get_children():
        if layer_node.get_meta("spins", false):
            _update_spinning_layer(layer_node)

func update_head_facing_layers() -> void:
    var heading_to_head: float = 0
    if parent_entity and parent_entity.tailing and EntityManager.has_instance(parent_entity.tailing.instance_id):
        heading_to_head = (parent_entity.tailing.position - parent_entity.position).rotated(PI/2).angle()
    for layer_node in layer_root.get_children():
        if not layer_node.get_meta("faces_head", false):
            continue
        layer_node.rotation = heading_to_head

func _update_spinning_layer(layer_node: Node2D) -> void:
    var spin_speed: float = layer_node.get_meta("spinning_speed", 0.0)
    var offset_rotation: float = deg_to_rad(layer_node.get_meta("offset_degrees", 0))
    layer_node.rotation = _spin_angle(spin_speed, layer_node.get_meta("spin_zero_time")) + offset_rotation
    if layer_node.get_child_count() > 0:
        if layer_node.get_meta("sub_layer_rotates") == false:
            layer_node.get_child(0).rotation = -(layer_node.rotation - offset_rotation)
        else:
            layer_node.get_child(0).rotation = -offset_rotation

func _spin_angle(spin_speed: float, zero_time_offset: float) -> float:
    if spin_speed == 0:
        return zero_time_offset
    return Utility.normalize_angle((elapsed_time - zero_time_offset) * spin_speed * TAU)

func _reculculate_spin_zero_time(cur_angle: float, target_spin_speed: float) -> float:
    if target_spin_speed == 0:
        return cur_angle
    return elapsed_time - Utility.normalize_angle(cur_angle) / (target_spin_speed * TAU)

# Helpers for making expanded mask textures
func create_bw_mask_from_texture_region(tex: Texture2D, tex_rect: Rect2i, tex_is_bw_mask: bool, clip_outer: bool) -> Texture:
    if tex_is_bw_mask:
        return create_bw_mask_from_bw_texture_region(tex, tex_rect, clip_outer)
    else:
        return create_bw_mask_from_texture_region_alpha(tex, tex_rect, clip_outer)

func create_bw_mask_from_bw_texture_region(tex: Texture2D, tex_rect: Rect2i, clip_outer: bool) -> Texture:
    var mask_img: Image = create_expanded_mask_from_rect(tex, tex_rect, Color.BLACK, clip_outer)
    return ImageTexture.create_from_image(mask_img)

func create_bw_mask_from_texture_region_alpha(tex: Texture2D, tex_rect: Rect2i, clip_outer: bool) -> Texture:
    var region_img: Image = Image.create(tex_rect.size.x, tex_rect.size.y, false, Image.FORMAT_RGBA8)
    var src_img: Image = tex.get_image()
    for y in tex_rect.size.y:
        for x in tex_rect.size.x:
            var src_pixel: Color = src_img.get_pixel(x, y)
            # alpha to grey-white, full opaque
            region_img.set_pixel(x, y, Color(src_pixel.a, src_pixel.a, src_pixel.a, 1.0))
    return ImageTexture.create_from_image(expand_image_with_color(region_img, Color.BLACK if clip_outer else Color.WHITE))

# expand on an Image source, needed if I first need to convert colors
func expand_image_with_color(content_img: Image, bg_color: Color) -> Image:
    var full_size: Vector2i = Vector2i.ONE * MapManager.tile_width * 2
    var dest_offset: Vector2i = Vector2i((Vector2(full_size - content_img.size) / 2.0).floor())
    var full_size_img: Image = Image.create(full_size.x, full_size.y, false, Image.FORMAT_RGBA8)
    full_size_img.fill(bg_color)
    full_size_img.blit_rect(content_img, Rect2i(Vector2.ZERO, content_img.size), dest_offset)
    return full_size_img

# expand on a region from a Texture2D source
func create_expanded_mask_from_rect(tex: Texture2D, tex_rect: Rect2i, clip_color: Color, clip_outer: bool) -> Image:
    var texture_region_size: Vector2i = tex_rect.size
    var src_img: Image = tex.get_image()
    var full_size: Vector2i = Vector2i.ONE * MapManager.tile_width * 2
    var mask_img: Image = Image.create(full_size.x, full_size.y, false, Image.FORMAT_RGBA8)

    var dest_offset: Vector2i = Vector2i((Vector2(full_size - texture_region_size) / 2.0).floor())
    var bg_color: Color = clip_color if clip_outer else Color.WHITE
    mask_img.fill(bg_color)
    mask_img.blit_rect(src_img, tex_rect, dest_offset)
    return mask_img

# These versions are for creating white/transparent masks, because of transparent VP screen texture lacking transparency in 2D, which is being used by clip_children, I'm switching to custom shader and BW mask
# see above
func create_expanded_bw_mask_from_rect(tex: Texture2D, tex_rect: Rect2i, clip_outer: bool) -> Image:
    return create_expanded_mask_from_rect(tex, tex_rect, Color.BLACK, clip_outer)

func create_alpha_mask_from_texture_region(tex: Texture2D, tex_rect: Rect2i, tex_is_bw_mask: bool, clip_outer: bool) -> Texture:
    if tex_is_bw_mask:
        return create_alpha_mask_from_bw_texture_region(tex, tex_rect, clip_outer)
    else:
        return create_alpha_mask_from_texture_region_alpha(tex, tex_rect, clip_outer)

func create_alpha_mask_from_texture_region_alpha(tex: Texture2D, tex_rect: Rect2i, clip_outer: bool) -> Texture:
    var mask_img: Image = create_expanded_mask_from_rect(tex, tex_rect, Color.TRANSPARENT, clip_outer)
    mask_img.fix_alpha_edges()
    return ImageTexture.create_from_image(mask_img)

func create_alpha_mask_from_bw_texture_region(tex: Texture2D, tex_rect: Rect2i, clip_outer: bool) -> Texture:
    var mask_img: Image = create_expanded_bw_mask_from_rect(tex, tex_rect, clip_outer)
    for y in mask_img.get_height():
        for x in mask_img.get_width():
            mask_img.set_pixel(x, y, Color.WHITE if mask_img.get_pixel(x, y).r > 0.5 else Color.TRANSPARENT)
    mask_img.fix_alpha_edges()
    return ImageTexture.create_from_image(mask_img)

func set_digit_display_number(new_number: Variant, digit_display: DigitDisplay) -> void:
    if typeof(new_number) == TYPE_BOOL:
        digit_display.set_number(1 if new_number else 0)
    elif typeof(new_number) in [TYPE_INT, TYPE_FLOAT]:
        digit_display.set_number(int(new_number))
    elif typeof(new_number) == TYPE_STRING and new_number.is_valid_float():
        digit_display.set_number(int(float(new_number)))
    else:
        digit_display.set_number(0)

func show_hide_layer(new_prop_value: Variant, layer_node: Node2D, is_truthy: bool) -> void:
    layer_node.set_meta("property_visible", Utility.truthy(new_prop_value) == is_truthy)
    update_layer_visible(layer_node)

func show_hide_layer_expression(new_prop_value: Variant, expression: Expression, layer_node: Node2D) -> void:
    var result: Variant = expression.execute([new_prop_value])
    if expression.has_execute_failed():
        push_error("Failed to execute expression: %s" % expression.get_error_text())
        layer_node.set_meta("property_visible", false)
    else:
        layer_node.set_meta("property_visible", Utility.truthy(result))
    update_layer_visible(layer_node)

func update_layer_visible(layer_node: Node2D) -> void:
    var vis: bool = layer_node.get_meta("property_visible", true)
    if layer_node.has_meta("moving_visible"):
        vis = vis and layer_node.get_meta("moving_visible")
    if layer_node.has_meta("camera_visible"):
        vis = vis and layer_node.get_meta("camera_visible")
    layer_node.visible = vis

func _apply_modifier_effects_to(layer_node: Node2D) -> void:
    _update_layer_node_scale(layer_node, layer_node.scale * _get_modifiers_scale())
    _apply_modifier_transforms_to(layer_node)
    _apply_mod_replace_color_to(layer_node)
    _apply_mod_modulate_to(layer_node)
    
    _apply_mod_z_offset_to(layer_node)

    # update the base scale and unscaled static pos so it now accounts for the static transform modifier
    layer_node.set_meta("static_scale", layer_node.scale)
    layer_node.set_meta("unscaled_static_pos", layer_node.position / layer_node.scale)
    # shader param for 9 patch scale is automatically set after this func for every layer

func _apply_mod_replace_color_to(layer_node: Node2D) -> void:
    var active_replace_color: Dictionary = _get_static_replace_color()
    var shader_mat: = get_layer_node_material(layer_node)
    if shader_mat:
        shader_mat.set_shader_parameter("replace_color", active_replace_color["color"])
        shader_mat.set_shader_parameter("replace_amt", active_replace_color["amount"])

func _get_static_replace_color() -> Dictionary:
    var replace_color_modifiers: Array = modifier_effects.get("replace_color", {}).keys()
    if replace_color_modifiers.size() < 1:
        return { "color": Color.WHITE, "amount": 0.0 }
    var active_replace_color: Dictionary = modifier_effects.get("replace_color", {})[replace_color_modifiers[-1]]
    return {
        "color": Utility.get_dict_color(active_replace_color, "color", Color.WHITE),
        "amount": active_replace_color.get("amount", 0.0),
    }

func _set_all_layers_replace_color(color: Color, amount: float) -> void:
    for layer_node in layer_root.get_children():
        var shader_mat: = get_layer_node_material(layer_node)
        if shader_mat:
            shader_mat.set_shader_parameter("replace_color", color)
            shader_mat.set_shader_parameter("replace_amt", amount)

func _set_all_layers_anim_scale(anim_scale: Vector2) -> void:
    for layer_node in layer_root.get_children():
        _update_layer_node_scale(layer_node, anim_scale * _get_layer_base_scale(layer_node))

func _update_layer_node_scale(layer_node: Node2D, new_scale: Vector2) -> void:
    layer_node.scale = new_scale
    layer_node.position = layer_node.get_meta("unscaled_static_pos", Vector2.ZERO) * layer_node.scale
    if layer_node.get_meta("scale_as_9_patch"):
        var shader_mat: = get_layer_node_material(layer_node)
        if shader_mat:
            shader_mat.set_shader_parameter("cur_scale_for_patch", layer_node.scale * scale)

func update_all_layers_shader_scale() -> void:
    if not layer_root:
        return
    for layer_node in layer_root.get_children():
        if layer_node.get_meta("scale_as_9_patch"):
            var shader_mat: = get_layer_node_material(layer_node)
            if shader_mat:
                shader_mat.set_shader_parameter("cur_scale_for_patch", layer_node.scale * scale)

func _apply_mod_modulate_to(layer_node: Node2D) -> void:
    var modulate_effects: Dictionary = modifier_effects.get("modulate", {})
    if modulate_effects.size() < 1:
        return
    var base_mod_color: Color = layer_node.get_meta("base_mod_color", Color.WHITE)
    var active_modulate: Dictionary = modulate_effects[modulate_effects.keys()[-1]]
    layer_node.modulate = Utility.get_dict_color(active_modulate, "color", Color.WHITE) * base_mod_color

func _apply_mod_z_offset_to(layer_node: Node2D) -> void:
    var z_offset_effects: Dictionary = modifier_effects.get("z_offset", {})
    if z_offset_effects.size() < 1:
        return
    var active_z_offset: Dictionary = z_offset_effects[z_offset_effects.keys()[-1]]
    layer_node.z_index += active_z_offset.get("offset", 0)

func _get_modifiers_scale() -> Vector2:
    var m_scale: Vector2 = Vector2.ONE
    for mod_name in modifier_effects.get("scale", {}):
        m_scale *= Utility.get_vector2_from_arr(modifier_effects["scale"][mod_name])
    return m_scale

func _get_layer_base_scale(layer_node: Node2D) -> Vector2:
    return layer_node.get_meta("static_scale", Vector2.ONE)

func _apply_modifier_transforms_to(layer_node: Node2D) -> void:
    var m_transform: Transform2D = Transform2D.IDENTITY
    for modifier_name in modifier_effects.get("transform", {}):
        var this_transform: Transform2D = Utility.get_transform2d_from_arr(modifier_effects["transform"][modifier_name])
        m_transform = this_transform * m_transform
    layer_node.transform = m_transform * layer_node.transform

func _get_new_unmasked_sprite() -> Sprite2D:
    var new_sprite: Sprite2D = Sprite2D.new()
    #new_sprite.material = replace_color_mat.duplicate()
    new_sprite.material = replace_color_9_patch_mat.duplicate()
    return new_sprite


func _apply_animated_effect_to_sprite(effect_name: String, delta_time: float) -> void:
    var method_name: String = "_anim___%s" % effect_name
    if has_method(method_name):
        call(method_name, animated_effects.get(effect_name, {}), delta_time)

func _get_anim_t(effect_data: Dictionary, mod_name: String) -> float:
    if effect_data.get("two_stage", false):
        return _get_two_stage_anim_t(effect_data, mod_name)
    var base_duration: float = effect_data.get("base_duration", 1.0)
    var t: float = (_animation_timers[mod_name] - effect_data.get("time_offset", 0.0)) / base_duration
    if effect_data.has("ease_param"):
        t = ease(t, effect_data["ease_param"])
    return t

func _get_two_stage_anim_t(effect_data: Dictionary, mod_name: String) -> float:
    var base_duration: float = effect_data.get("base_duration", 1.0)
    var mid_point: float = effect_data.get("mid_point", 0.5)
    var base_t: float = (_animation_timers[mod_name] - effect_data.get("time_offset", 0.0)) / base_duration
    if base_t < mid_point:
        var stage_1_t: float = base_t / mid_point
        if effect_data.has("ease_param"):
            stage_1_t = ease(stage_1_t, effect_data["ease_param"])
        return stage_1_t
    else:
        var stage_2_t: float =  1 - ((base_t - mid_point) / (1 - mid_point))
        if effect_data.has("ease_param_2"):
            stage_2_t = ease(stage_2_t, effect_data["ease_param_2"])
        return stage_2_t

func _anim___scale(effect_stack: Dictionary, _delta_time: float) -> void:
    var total_scale: = Vector2.ONE
    for mod_name in effect_stack:
        var effect_data: Dictionary = effect_stack[mod_name]
        var t: float = _get_anim_t(effect_data, mod_name)
        var scale_from: = Utility.get_vector2_from_arr(effect_data.get("scale_from", [1,1]))
        var scale_to: = Utility.get_vector2_from_arr(effect_data.get("scale_to", [1,1]))
        total_scale *= scale_from.lerp(scale_to, t)
    _set_all_layers_anim_scale(total_scale)

func _anim___offset(effect_stack: Dictionary, _delta_time: float) -> void:
    var accumulated_offset: = Vector2.ZERO
    for mod_name in effect_stack:
        var effect_data: Dictionary = effect_stack[mod_name]
        var t: float = _get_anim_t(effect_data, mod_name)
        var offset_from: = Utility.get_vector2_from_arr(effect_data.get("offset_from", [0,0]))
        var offset_to: = Utility.get_vector2_from_arr(effect_data.get("offset_to", [0,0]))
        accumulated_offset += offset_from.lerp(offset_to, t)
    layer_root.position = accumulated_offset

func _anim___replace_color(effect_stack: Dictionary, _delta_time: float) -> void:
    var use_color: Color = Color.WHITE
    var use_amt: float = 0
    if effect_stack.size() >= 1:
        var active_color_mod: String = effect_stack.keys()[-1]
        var active_replace: Dictionary = effect_stack[active_color_mod]
        var t: float = _get_anim_t(active_replace, active_color_mod)
        var color_to: Color = Utility.get_dict_color(active_replace, "color_to", Color.WHITE)
        if active_replace.has("color_from"):
            var color_from: Color = Utility.get_dict_color(active_replace, "color_from", Color.WHITE)
            use_color = color_from.lerp(color_to, t)
        else:
            use_color = color_to
        #use_color = Utility.lerp_ok_hsl_color(from_color, to_color, t)
        var amt_from: float = active_replace.get("amount_from", 0.0)
        var amt_to: float = active_replace.get("amount_to", 0.0)
        use_amt = lerpf(amt_from, amt_to, t)
    var anim_color_overlay: Color = use_color
    anim_color_overlay.a = 1
    var static_replace_color_info: Dictionary = _get_static_replace_color()
    var static_color: Color = static_replace_color_info["color"]
    static_color.a = 1
    var static_contribution: float = (1 - use_amt) * static_replace_color_info["amount"]
    var final_color: = anim_color_overlay.lerp(static_color, static_contribution)
    var final_amt: float = use_amt + static_contribution
    _set_all_layers_replace_color(final_color, final_amt)
    
func _anim___fade(effect_stack: Dictionary, _delta_time: float) -> void:
    var accum_inverse_fade: float = 1.0
    for mod_name in effect_stack:
        var effect_data: Dictionary = effect_stack[mod_name]
        var t: float = _get_anim_t(effect_data, mod_name)
        var fade_from: float = effect_data.get("fade_from", 0.0)
        var fade_to: float = effect_data.get("fade_to", 0.0)
        accum_inverse_fade *= 1 - lerpf(fade_from, fade_to, t)
    layer_root.modulate.a = clampf(accum_inverse_fade, 0.0, 1.0)

func _anim___spin(effect_stack: Dictionary, _delta_time: float) -> void:
    var active_spin: = {}
    var active_spin_mod: String = ""
    if effect_stack.size() >= 1:
        active_spin_mod = effect_stack.keys()[-1]
        active_spin = effect_stack[active_spin_mod]
    
    if active_spin:
        _animated_spinning = true
        var t: float = _get_anim_t(active_spin, active_spin_mod)
        var total_rotation: float = active_spin.get("total_rotation", 1.0)
        var angle: float = total_rotation * t * TAU
        set_sprite_rotation(current_rotation + angle, true)
    else:
        if _animated_spinning:
            _animated_spinning = false
            set_sprite_rotation(current_rotation)

func get_is_visual_moving() -> bool:
    if not parent_entity:
        return false
    return parent_entity.is_visual_moving()

func set_sprite_size(new_unoriented_bounds: Vector2, update_pos_now: bool = true) -> void:
    unoriented_bounds = new_unoriented_bounds
    unoriented_center = unoriented_bounds / 2
    simple_rotate = unoriented_bounds.x == unoriented_bounds.y
    if update_pos_now:
        _update_oriented_position()

func _update_oriented_position(with_offset: Vector2 = Vector2.ZERO) -> void:
    if simple_rotate or _current_facing % 2 == 0:
        position = unoriented_center
    else:
        position = Vector2(unoriented_center.y, unoriented_center.x)
    position += with_offset

func set_large_auto_scale(enable: bool, new_size: Vector2 = Vector2.ONE) -> void:
    large_auto_scale_enabled = enable
    large_auto_scale_size = new_size
    if not large_auto_scale_enabled:
        scale = Vector2.ONE
    else:
        scale = large_auto_scale_size
    update_all_layers_shader_scale()

func set_large_size_with_position_and_interpolation(new_size: Vector2, tile_pos_delta: Vector2i) -> void:
    if not interpolate_size_change_enabled:
        push_warning("Interpolate size change is disabled, but set_large_size_with_position_and_interpolation was called")
        set_large_auto_scale(true, new_size)
        return

    var old_center: Vector2 = large_auto_scale_size / 2
    var new_center: Vector2 = new_size / 2
    var center_offset: Vector2 = old_center - new_center

    _size_interp_from_scale = large_auto_scale_size
    _size_interp_from_offset = -((Vector2(tile_pos_delta) - center_offset) * MapManager.tile_width)
    interp_size_change_timer = interp_size_change_duration

    large_auto_scale_enabled = true
    large_auto_scale_size = new_size
    
    # also update unoriented_bounds and unoriented_center
    set_sprite_size(new_size * MapManager.tile_width, false)

func get_layer_node_material(layer_node: Node2D) -> ShaderMaterial:
    if layer_node.get_meta("is_pivot_dummy"):
        return layer_node.get_child(0).material as ShaderMaterial
    return layer_node.material as ShaderMaterial

func early_end_spawning_effect() -> void:
    if not _spawning_with_animated_mod:
        return
    if not _all_modifiers.has(_spawning_with_animated_mod):
        push_error("Spawning with animated mod not found: %s" % _spawning_with_animated_mod)
        return
    var expire_time: float = _all_modifiers[_spawning_with_animated_mod].get("expire_time", 0.0)
    if expire_time <= 0:
        _all_modifiers[_spawning_with_animated_mod]["expire_time"] = 1.0
        expire_time = 1.0
    _animation_timers[_spawning_with_animated_mod] = expire_time + 1.0
    process_animated_modifiers(0, false)

func set_alternate_texture_source(new_alternate_texture_source: Object) -> void:
    if not new_alternate_texture_source:
        _has_alternate_texture_source = false
        _alternate_texture_source = null
        return
    _has_alternate_texture_source = true
    _alternate_texture_source = new_alternate_texture_source


func get_particle_layer_remaining_linger_time(particle_layer: Node2D) -> float:
    if particle_layer in _lingering_particle_lifetimes:
        return _lingering_particle_lifetimes[particle_layer]
    
    if particle_layer is GPUParticles2D:
        prints("particle layer %s is a GPUParticles2D, lifetime: %s, speed_scale: %s" % [particle_layer.name, particle_layer.lifetime, particle_layer.speed_scale])
        return particle_layer.lifetime / particle_layer.speed_scale
    elif particle_layer.has_method("get_linger_time"):
        prints("particle layer %s has get_linger_time method, returning %s" % [particle_layer.name, particle_layer.get_linger_time()])
        return particle_layer.get_linger_time()
    prints("particle layer %s has no linger time, returning 0.0" % particle_layer.name)
    return 0.0
