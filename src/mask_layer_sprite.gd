class_name MaskLayerSprite
extends Node2D

const DigitDisplay = preload("res://Scenes/digit_display.gd")

var digit_display_scn: PackedScene = preload("res://Scenes/digit_display.tscn")
var clipping_spr_scn: PackedScene = preload("res://src/Utility/sub_vp_friendly_clipping_sprite.tscn")

var layers: Array[Dictionary] = []
var current_rotation: float = 0

var preview_info: Dictionary = {}

var layer_order_id: int = 0

var modifier_masks: Dictionary = {}

var prop_update_response: Dictionary[String, Array] = {}

var is_preview_mode: bool = false

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
        parent.local_prop_changed.connect(on_local_properties_updated)
        EntityManager.entity_preview_mode_changed.connect(on_entity_preview_mode_changed)
    else:
        prints("not registering parent, not under an entity")

func on_entity_preview_mode_changed(enable_preview: bool) -> void:
    prints("entity preview mode changed to: %s" % enable_preview)
    is_preview_mode = enable_preview
    if preview_info:
        prints("I have preview info, refreshing layers, %s: (%s)" % [is_preview_mode, preview_info])
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

func set_main_layers(new_layers: Array) -> void:
    remove_main_layers()
    new_layers = new_layers.duplicate_deep()
    for new_main_layer in new_layers:
        new_main_layer["is_main_layer"] = true
        _append_layer(new_main_layer)
    refresh_layers()

func remove_main_layers() -> void:
    if not layers:
        return
    var new_layers: Array[Dictionary] = []
    for layer in layers:
        if not layer.get("is_main_layer", false):
            new_layers.append(layer)
    layers = new_layers

func append_layer(layer_info: Dictionary) -> void:
    _append_layer(layer_info.duplicate_deep())
    refresh_layers()

func _append_layer(layer_info: Dictionary) -> void:
    if not layer_info.has("mode"):
        layer_info["mode"] = "normal"
    layer_info["order_id"] = layer_order_id
    layer_order_id += 1
    layers.append(layer_info)

func refresh_layers() -> void:
    resort_layers()
    clear_children()
    prop_update_response.clear()
    if preview_info and is_preview_mode:
        prints("I have preview info and am in preview mode, creating preview layer")
        create_and_add_nodes_for_layer(preview_info, 0)
    else:
        if preview_info:
            prints("I have preview info and am not in preview mode, creating normal layers")
        for layer_index in layers.size():
            create_and_add_nodes_for_layer(layers[layer_index], layer_index)
    if is_inside_tree():
        on_local_properties_updated(get_parent() as BaseEntity)

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

func apply_modifier(modifier_name: String, modifier_layers: Array = [], modifier_mask_info: Dictionary = {}) -> void:
    if not modifier_name or has_applied_modifier(modifier_name):
        return
    for layer in modifier_layers:
        layer["modifier"] = modifier_name
        _append_layer(layer)
    modifier_masks[modifier_name] = modifier_mask_info.duplicate_deep()
    if modifier_mask_info:
        _apply_modifier_mask_modifier(modifier_name)
    refresh_layers()

func has_applied_modifier(modifier_name: String) -> bool:
    return modifier_name in modifier_masks

func remove_modifier(modifier_name: String) -> void:
    if not has_applied_modifier(modifier_name):
        return
    modifier_masks.erase(modifier_name)
    _remove_modifier_layers(modifier_name)
    _apply_most_recent_modifier_mask()
    refresh_layers()

func clear_modifiers() -> void:
    modifier_masks.clear()
    _remove_all_modifier_layers()
    _remove_main_layers_mask()
    refresh_layers()

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

func create_and_add_nodes_for_layer(layer_info: Dictionary, _layer_index: int) -> void:
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
            var layer_spr: = Sprite2D.new()
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
            
            if is_inside_tree():
                var entity: = get_parent() as BaseEntity
                if entity:
                    var prop_val: Variant = EntityManager.get_entity_prop_with_default(entity, prop_name, 0)
                    set_digit_display_number(prop_val, digit_display)
                else:
                    set_digit_display_number(layer_info.get("preview_number", 0), digit_display)
    
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

    main_layer_node.modulate = Utility.get_dict_color(layer_info, "mod_color", Color.WHITE)
    
    add_child(main_layer_node)
    var layer_scale: Vector2 = Utility.get_vector2_from_arr(layer_info.get("scale", [1,1]))
    var layer_offset: Vector2 = Utility.get_vector2_from_arr(layer_info.get("offset", [0,0]))
    main_layer_node.scale = layer_scale
    main_layer_node.position = layer_offset
    
    main_layer_node.set_meta("modifier", layer_info.get("modifier", ""))
    
    var layer_rotates: bool = layer_info.get("rotates", true)
    var sub_layer_rotates: bool = layer_rotates
    if is_masked:
        sub_layer_rotates = layer_info.get("mask_rotates", true)
        prints("layer_rotates: %s, sub_layer_rotates: %s" % [layer_rotates, sub_layer_rotates])

    main_layer_node.set_meta("rotates", layer_rotates)
    main_layer_node.set_meta("sub_layer_rotates", sub_layer_rotates)

    set_sprite_rotation(current_rotation)

func _add_prop_upate_callable(prop_name: String, update_func: Callable) -> void:
    if not prop_update_response.has(prop_name):
        prop_update_response[prop_name] = []
    prop_update_response[prop_name].append(update_func)

func on_local_properties_updated(entity: BaseEntity) -> void:
    if not entity:
        return
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

func clear_children() -> void:
    for child in get_children():
        child.queue_free()

func set_sprite_facing(facing: int) -> void:
    set_sprite_rotation(Utility.facing_rotation(facing))

func set_sprite_rotation(new_rotation: float) -> void:
    current_rotation = new_rotation
    for layer_node in get_children():
        var layer_rotates: bool = layer_node.get_meta("rotates")
        if layer_rotates:
            layer_node.rotation = new_rotation
        if layer_node.get_meta("sub_layer_rotates") != layer_rotates and layer_node.get_child_count() > 0:
            layer_node.get_child(0).rotation = (-2 * layer_node.rotation) + new_rotation

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
    
