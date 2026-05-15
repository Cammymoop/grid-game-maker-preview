class_name MaskLayerSprite
extends Node2D

signal dying_animation_finished

const DigitDisplay = preload("res://Scenes/digit_display.gd")

var digit_display_scn: PackedScene = preload("res://Scenes/digit_display.tscn")
var clipping_spr_scn: PackedScene = preload("res://src/Utility/sub_vp_friendly_clipping_sprite.tscn")

var replace_color_mat: ShaderMaterial = preload("res://src/Effects/sprite_with_replace_color.tres")

var layers: Array[Dictionary] = []
var current_rotation: float = 0
var _facing_rotation: float = 0.0
var _current_facing: int = 0
var elapsed_time: float = 0.0

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

var interpolate_facing_enabled: bool = true
var interp_facing_timer: float = 0.0
@export var interp_duration: float = 0.24
@export_exp_easing() var interp_ease_param: float = 0.2

var layer_root: Node2D = null

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

func sprite_process(delta_time: float) -> void:
    elapsed_time += delta_time
    update_spinning_layers()
    if _local_prop_updated:
        _local_prop_updated = false
        if parent_entity:
            on_local_prop_update_frame(parent_entity)
    if interpolate_facing_enabled:
        if interp_facing_timer > 0:
            interp_facing_timer = maxf(0, interp_facing_timer - delta_time)
            var eased_progress: float = ease(1 - (interp_facing_timer / interp_duration), interp_ease_param)

            var to_angle: float = Utility.facing_rotation(parent_entity.facing)
            var interp_angle: float = lerp_angle(_facing_rotation, to_angle, eased_progress)
            set_sprite_rotation(interp_angle)
    process_animated_modifiers(delta_time)

func process_animated_modifiers(delta_time: float) -> void:
    var expired_modifiers: Array[String]
    for mod_name in animated_modifiers:
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
    ensure_layer_root()
    resort_layers()
    clear_children()
    prop_update_response.clear()
    
    _track_layer_angles()
    if preview_info and is_preview_mode:
        create_and_add_nodes_for_layer(preview_info, 0)
    else:
        for layer_index in layers.size():
            create_and_add_nodes_for_layer(layers[layer_index], layer_index)
    if is_inside_tree():
        on_local_prop_update_frame(get_parent() as BaseEntity)

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

func resort_layers() -> void:
    layers.sort_custom(_layer_sort_compare)

func apply_modifier_info(modifier_info: Dictionary, is_dying_effect: bool = false) -> void:
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
        _animation_timers[modifier_name] = 0.0
        apply_animated_effects_to_sprite()
    if modifier_info.get("expire_time", 0) > 0:
        if is_dying_effect:
            _dying_with_animated_mod = modifier_name
        if not animated_modifiers.has(modifier_name):
            animated_modifiers.append(modifier_name)
    _all_modifiers[modifier_name] = modifier_info.duplicate_deep()
    refresh_layers()

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
    animated_effects.clear()
    animated_modifiers.clear()
    _animation_timers.clear()
    apply_animated_effects_to_sprite()
    refresh_layers()

func get_serialized_info() -> Dictionary:
    var serialized_info: Dictionary = {
        "current_rotation": current_rotation,
    }
    if not _all_modifiers.is_empty():
        serialized_info["modifiers"] = _all_modifiers.duplicate_deep()
        serialized_info["animation_timers"] = _animation_timers.duplicate()
    return serialized_info

func deserialize_sprite_info(info: Dictionary) -> void:
    clear_modifiers()
    if info.has("current_rotation"):
        current_rotation = info["current_rotation"]
    var animation_timers: Dictionary = info.get("animation_timers", {})
    for modifier_name in info.get("modifiers", {}):
        apply_modifier_info(info["modifiers"][modifier_name])
        if animation_timers.has(modifier_name):
            _animation_timers[modifier_name] = animation_timers[modifier_name]

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

func create_and_add_nodes_for_layer(layer_info: Dictionary, layer_index: int) -> void:
    if not layer_info or layer_info.get("mode", "empty") == "empty":
        return

    var main_layer_node: Node2D = null
    var is_masked: bool = false

    if layer_info.get("mode") == "normal":
        var layer_texture_id: int = int(layer_info.get("texture", -1))
        if layer_texture_id == -1:
            return
        
        var layer_tex: Texture = TextureManager.get_texture(layer_texture_id)
        var layer_tex_rect: Rect2 = TextureManager.get_index_rect(layer_texture_id, layer_info.get("tex_index", 0))
    
        
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

            var mask_src_tex: Texture = TextureManager.get_texture(mask_texture_id)
            var mask_tex_rect: Rect2 = TextureManager.get_index_rect(mask_texture_id, layer_info.get("mask_tex_index", 0))
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
    elif layer_info.get("mode") == "digits":
        var digit_display: = digit_display_scn.instantiate() as DigitDisplay
        main_layer_node = digit_display
        digit_display.pad_zeros = layer_info.get("pad_zeros", true)
        digit_display.set_max_digits(layer_info.get("max_digits", 1))
        
        if layer_info.get("property", ""):
            var prop_name: String = layer_info["property"]
            _add_prop_upate_callable(prop_name, set_digit_display_number.bind(digit_display))
            
            var entity_parent: BaseEntity = null
            if is_inside_tree():
                entity_parent = get_parent() as BaseEntity

            if entity_parent:
                var prop_val: Variant = EntityManager.get_entity_prop_with_default(entity_parent, prop_name, 0)
                set_digit_display_number.call_deferred(prop_val, digit_display)
            else:
                set_digit_display_number.call_deferred(layer_info.get("preview_number", 0), digit_display)
        else:
            set_digit_display_number.call_deferred(layer_info.get("digits_number", 1), digit_display)
    
    var offset_degrees: float = layer_info.get("offset_degrees", 0)
    main_layer_node.set_meta("offset_degrees", offset_degrees)
    
    if layer_info.get("when_property", ""):
        var when_property_name: String = layer_info["when_property"]
        if layer_info.get("when_prop_expression", ""):
            var expr: Expression = Expression.new()
            var err: = expr.parse(layer_info.get("when_prop_expression", ""), ["V"])
            if err != OK:
                push_error("Failed to parse expression: %s" % layer_info.get("when_prop_expression", ""))
                return
            _add_prop_upate_callable(when_property_name, show_hide_layer_expression.bind(main_layer_node, expr))
        else:
            _add_prop_upate_callable(when_property_name, show_hide_layer.bind(main_layer_node))

    var base_mod_color: Color = Utility.get_dict_color(layer_info, "mod_color", Color.WHITE)
    main_layer_node.set_meta("base_mod_color", base_mod_color)
    main_layer_node.modulate = base_mod_color
    
    var layer_offset: Vector2 = Utility.get_vector2_from_arr(layer_info.get("offset", [0,0]))
    var layer_pivot_offset: Vector2 = Utility.get_vector2_from_arr(layer_info.get("pivot", [0,0]))

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
            main_layer_node = pivot_node
            main_layer_node.set_meta("offset_degrees", 0)
    main_layer_node.name = layer_info.get("mode", "MODE") + str(layer_index)
    
    main_layer_node.z_index = int(layer_info.get("z_offset", 0))

    layer_root.add_child(main_layer_node, true)
    var layer_scale: Vector2 = Utility.get_vector2_from_arr(layer_info.get("scale", [1,1]))
    layer_scale *= _get_modifiers_scale()
    main_layer_node.scale = layer_scale
    
    main_layer_node.set_meta("modifier", layer_info.get("modifier", ""))
    
    var layer_rotates: bool = layer_info.get("rotates", true)
    var sub_layer_rotates: bool = layer_rotates
    if is_masked:
        sub_layer_rotates = layer_info.get("mask_rotates", true)

    main_layer_node.set_meta("rotates_with_sprite", layer_rotates)
    main_layer_node.set_meta("sub_layer_rotates", sub_layer_rotates)

    main_layer_node.set_meta("spinning_speed", layer_info.get("spinning", 0.0))
    main_layer_node.set_meta("spins", layer_info.has("spinning"))
    
    main_layer_node.set_meta("spin_zero_time", layer_info.get("_spin_time_zero", 0.0))

    if main_layer_node.get_meta("spins", false):
        _update_spinning_layer(main_layer_node)
    else:
        _set_sprite_layer_rotation(main_layer_node, current_rotation)
    
    if layer_info.get("is_main_layer", false) or layer_info.get("receives_effects", true):
        _apply_modifier_effects_to(main_layer_node)

func _add_prop_upate_callable(prop_name: String, update_func: Callable) -> void:
    if not prop_update_response.has(prop_name):
        prop_update_response[prop_name] = []
    prop_update_response[prop_name].append(update_func)

func on_local_prop_update_frame(entity: BaseEntity) -> void:
    for prop_name in prop_update_response:
        var prop_val: Variant = EntityManager.get_entity_prop_with_default(entity, prop_name, 0)
        for update_func in prop_update_response[prop_name]:
            update_func.call(prop_val)


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
    for effect_name in animated_effects:
        if animated_effects[effect_name].has(modifier_name):
            animated_effects[effect_name].erase(modifier_name)
            if animated_effects[effect_name].size() == 0:
                animated_effects.erase(effect_name)

func _add_animated_modifier_effect(effect_name: String, modifier_name: String, effect_stuff: Variant) -> void:
    if not animated_effects.has(effect_name):
        animated_effects[effect_name] = {}
    animated_effects[effect_name][modifier_name] = effect_stuff

func _remove_animated_modifier_effects(for_modifier_name: String) -> void:
    for effect_name in animated_effects.keys():
        if animated_effects[effect_name].has(for_modifier_name):
            prints("removing animated effect %s for modifier %s" % [effect_name, for_modifier_name])
            animated_effects[effect_name].erase(for_modifier_name)
            if animated_effects[effect_name].size() == 0:
                animated_effects.erase(effect_name)
        else:
            prints("effect %s not included in modifier %s" % [effect_name, for_modifier_name])

func clear_children() -> void:
    if not layer_root:
        return
    for child in layer_root.get_children():
        child.queue_free()

func set_sprite_facing(facing: int, immediate: bool = false) -> void:
    if interpolate_facing_enabled and not immediate:
        _facing_rotation = current_rotation
        _current_facing = facing
        interp_facing_timer = interp_duration
    else:
        set_sprite_rotation(Utility.facing_rotation(facing))

func set_sprite_rotation(new_rotation: float, force: bool = false) -> void:
    if _animated_spinning and not force:
        return
    if not _animated_spinning:
        current_rotation = new_rotation
    if not layer_root:
        return
    for layer_node in layer_root.get_children():
        if not layer_node.get_meta("spins", false):
            _set_sprite_layer_rotation(layer_node, new_rotation)

func _set_sprite_layer_rotation(layer_node: Node2D, new_rotation: float) -> void:
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
    return ImageTexture.create_from_image(mask_img)

func create_alpha_mask_from_bw_texture_region(tex: Texture2D, tex_rect: Rect2i, clip_outer: bool) -> Texture:
    var mask_img: Image = create_expanded_bw_mask_from_rect(tex, tex_rect, clip_outer)
    for y in mask_img.get_height():
        for x in mask_img.get_width():
            mask_img.set_pixel(x, y, Color.WHITE if mask_img.get_pixel(x, y).r > 0.5 else Color.TRANSPARENT)
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

func show_hide_layer(new_prop_value: Variant, layer_node: Node2D) -> void:
    if new_prop_value:
        layer_node.show()
    else:
        layer_node.hide()

func show_hide_layer_expression(new_prop_value: Variant, expression: Expression, layer_node: Node2D) -> void:
    var result: Variant = expression.execute([new_prop_value])
    if expression.has_execute_failed():
        push_error("Failed to execute expression: %s" % expression.get_error_text())
        layer_node.hide()
        return

    if result:
        layer_node.show()
    else:
        layer_node.hide()

func _apply_modifier_effects_to(layer_node: Node2D) -> void:
    layer_node.scale *= _get_modifiers_scale()
    _apply_modifier_transforms_to(layer_node)
    _apply_mod_replace_color_to(layer_node)
    _apply_mod_modulate_to(layer_node)

func _apply_mod_replace_color_to(layer_node: Node2D) -> void:
    var active_replace_color: Dictionary = _get_static_replace_color()
    if layer_node.material and layer_node.material is ShaderMaterial:
        layer_node.material.set_shader_parameter("replace_color", active_replace_color["color"])
        layer_node.material.set_shader_parameter("replace_amt", active_replace_color["amount"])

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
        if layer_node.material and layer_node.material is ShaderMaterial:
            layer_node.material.set_shader_parameter("replace_color", color)
            layer_node.material.set_shader_parameter("replace_amt", amount)

func _apply_mod_modulate_to(layer_node: Node2D) -> void:
    var modulate_modifiers: Array = modifier_effects.get("modulate", {}).keys()
    if modulate_modifiers.size() < 1:
        return
    var base_mod_color: Color = layer_node.get_meta("base_mod_color", Color.WHITE)
    var active_modulate: Dictionary = modifier_effects.get("modulate", {})[modulate_modifiers[-1]]
    layer_node.modulate = Utility.get_dict_color(active_modulate, "color", Color.WHITE) * base_mod_color

func _get_modifiers_scale() -> Vector2:
    var m_scale: Vector2 = Vector2.ONE
    for mod_name in modifier_effects.get("scale", {}):
        m_scale *= Utility.get_vector2_from_arr(modifier_effects["scale"][mod_name])
    return m_scale

func _apply_modifier_transforms_to(layer_node: Node2D) -> void:
    var m_transform: Transform2D = Transform2D.IDENTITY
    for modifier_name in modifier_effects.get("transform", {}):
        var this_transform: Transform2D = Utility.get_transform2d_from_arr(modifier_effects["transform"][modifier_name])
        m_transform = this_transform * m_transform
    layer_node.transform = m_transform * layer_node.transform

func _get_new_unmasked_sprite() -> Sprite2D:
    var new_sprite: Sprite2D = Sprite2D.new()
    new_sprite.material = replace_color_mat.duplicate()
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
    layer_root.scale = total_scale

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
