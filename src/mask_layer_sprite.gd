class_name MaskLayerSprite
extends Node2D

var layers: Array[Dictionary] = []
var current_rotation: float = 0

var layer_order_id: int = 0

var modifier_masks: Dictionary = {}

var rotation_prop: float = 0:
    get:
        return current_rotation
    set(new_rotation):
        set_sprite_rotation(new_rotation)

func set_as_single(single_texture_id: int, tex_index: int, rotates: bool = true) -> void:
    var layer_info: Dictionary = {
        "type": "regular",
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
    if not layer_info.has("type"):
        layer_info["type"] = "regular"
    layer_info["order_id"] = layer_order_id
    layer_order_id += 1
    layers.append(layer_info)

func refresh_layers() -> void:
    resort_layers()
    clear_children()
    for layer_info in layers:
        create_and_add_nodes_for_layer(layer_info)

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

func create_and_add_nodes_for_layer(layer_info: Dictionary) -> void:
    if not layer_info or layer_info.get("type", "empty") == "empty":
        return
    var layer_texture_id: int = layer_info.get("texture", -1)
    if layer_texture_id == -1:
        return
    
    var layer_tex: Texture = TextureManager.get_texture(layer_texture_id)
    var layer_tex_rect: Rect2 = TextureManager.get_index_rect(layer_texture_id, layer_info.get("tex_index", 0))
    var layer_spr: = Sprite2D.new()
    layer_spr.texture = layer_tex
    layer_spr.region_rect = layer_tex_rect
    layer_spr.region_enabled = true
    var main_layer_node: Node2D = layer_spr
    
    var is_masked: bool = layer_info.get("masked", false)
    var mask_texture_id: int = -1
    if is_masked:
        mask_texture_id = layer_info.get("mask_texture", -1)
        if mask_texture_id == -1:
            is_masked = false
    
    if is_masked:
        var mask_tex_rect: Rect2 = TextureManager.get_index_rect(mask_texture_id, layer_info.get("mask_tex_index", 0))
        var mask_clip_outer: bool = layer_info.get("mask_clip_outer", true)
        var mask_is_bw: bool = layer_info.get("mask_is_bw", false)

        var mask_spr: = Sprite2D.new()
        mask_spr.texture = create_alpha_mask_from_texture_region(TextureManager.get_texture(mask_texture_id), mask_tex_rect, mask_is_bw, mask_clip_outer)
        mask_spr.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
        main_layer_node = mask_spr
        main_layer_node.add_child(layer_spr)
    
    add_child(main_layer_node)
    var layer_scale: Vector2 = layer_info.get("scale", Vector2.ONE)
    var layer_offset: Vector2 = layer_info.get("offset", Vector2.ZERO)
    main_layer_node.scale = layer_scale
    main_layer_node.position = layer_offset
    
    main_layer_node.set_meta("modifier", layer_info.get("modifier", ""))
    
    var layer_rotates: bool = layer_info.get("rotates", true)
    var sub_layer_rotates: bool = false
    if is_masked:
        sub_layer_rotates = layer_rotates
        layer_rotates = layer_info.get("mask_rotates", false)

    main_layer_node.set_meta("rotates", layer_rotates)
    main_layer_node.set_meta("sub_layer_rotates", sub_layer_rotates)

    set_sprite_rotation(current_rotation)


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
        if layer_node.get_meta("rotates"):
            layer_node.rotation = new_rotation
            if not layer_node.get_meta("sub_layer_rotates"):
                for sub_node in layer_node.get_children():
                    sub_node.rotation = -new_rotation
        elif layer_node.get_meta("sub_layer_rotates"):
            for sub_node in layer_node.get_children():
                sub_node.rotation = new_rotation

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

func create_expanded_bw_mask_from_rect(tex: Texture2D, tex_rect: Rect2i, clip_outer: bool) -> Image:
    return create_expanded_mask_from_rect(tex, tex_rect, Color.BLACK, clip_outer)

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