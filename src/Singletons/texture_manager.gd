extends Node

signal textures_loaded
signal textures_remapped

var placeholder: = preload("res://assets/img/placeholder.png")
var placeholder_metadata = {
    'is_multiple_tiles': true,
    'tile_size': Vector2(32, 32),
    'size_in_tiles': Vector2(4, 4),
    'border': Vector2.ZERO,
    'separation': Vector2.ZERO,
}

var builtin_textures: Array[String] = [
    "tiles.png",
    "entityTiles.png",
    "playerVariants.png",
    "frog.png",
    "oversize_tiles.png",
    "oversize_tiles_2.png",
    "shapes32x.png",
    "borders.png",
]
var builtin_meta: = {}
var default_textures: Array[String] = [
    "tiles.png",
    "entityTiles.png",
]
var texture_names: Dictionary [int, String] = {}
var textures: Dictionary [int, Texture] = {}
var tiles_per_row: Dictionary [int, int] = {0: 16}
var texture_rows: Dictionary [int, int] = {}
var tile_sizes: = {}
var texture_meta: = {}

var greyscale_textures: Dictionary[int, Texture] = {}

var next_texture_id: int = 0

var texture_spec: Array

var im_ready: = false

const BUILTIN_IMAGE_DIR: = "res://assets/img/"

func setup() -> void:
    if texture_spec.size() == 0:
        for builtin_tex_name in default_textures:
            add_builtin_texture(builtin_tex_name)
    refresh_textures()
#
#	emit_signal("textures_loaded")
#	im_ready = true

func grab_builtin_metadata() -> void:
    var f = FileAccess.open("res://assets/builtin_texture_meta.json", FileAccess.READ)
    if not f:
        print_debug("Error loading builtin texture meta")
        return
    var result = Utility.parse_json(f.get_as_text())
    
    builtin_meta = fixup_texture_metas(result)

func fixup_texture_metas(metas: Dictionary) -> Dictionary:
    var new_dict = {}
    for key in metas:
        new_dict[key] = fixup_texture_meta(metas[key])
    return new_dict

func fixup_texture_meta(meta: Dictionary) -> Dictionary:
    var new_dict = {}
    for key in meta:
        if not meta[key] is Array or len(meta[key]) != 2:
            new_dict[key] = meta[key]
            continue
        new_dict[key] = Vector2(meta[key][0], meta[key][1])
    return new_dict

func clear() -> void:
    next_texture_id = 0
    textures = {}
    texture_rows = {}
    tiles_per_row = {}
    texture_names = {}

func get_texture_spec() -> Array:
    return texture_spec.duplicate_deep()

func add_texture(tex_spec: Dictionary) -> void:
    texture_spec.append(tex_spec)
    load_texture(tex_spec)

func is_builtin_loaded(builtin_tex_name: String) -> bool:
    for t in texture_spec:
        if t["type"] == "builtin" and t["name"] == builtin_tex_name:
            return true
    return false

func is_local_file_loaded(file_name: String, is_shared: bool = true) -> bool:
    for t in texture_spec:
        if t["type"] != "local_file" or t.get("is_shared", true) != is_shared:
            continue
        if t["image_name"] == file_name:
            return true
    return false

func add_local_texture(file_name: String, is_shared: bool = true) -> int:
    if is_local_file_loaded(file_name, is_shared):
        return -1
    var spec = {
        type = "local_file",
        is_shared = is_shared,
        image_name = file_name,
        texture_id = get_new_texture_id(),
        filter = false,
    }
    add_texture(spec)
    return spec["texture_id"]
func add_builtin_texture(tex_name: String) -> int:
    if is_builtin_loaded(tex_name):
        return -1
    var spec = {
        type = "builtin",
        name = tex_name, 
        texture_id = get_new_texture_id(),
        filter = false,
    }
    add_texture(spec)
    return spec["texture_id"]

func set_default_textures() -> void:
    next_texture_id = 0
    texture_spec = get_default_texture_spec()
    next_texture_id = texture_spec.size()
    refresh_textures()

func get_default_texture_spec() -> Array:
    var spec: = []
    var next_id = 0
    for texture_name in default_textures:
        spec.append({type = "builtin", texture_id = next_id, name = texture_name})
        next_id += 1
    return spec

func set_textures(from_texture_spec: Array) -> void:
    if not from_texture_spec:
        set_default_textures()
        return
    next_texture_id = 0
    texture_spec = from_texture_spec
    for spec_stuff in texture_spec:
        next_texture_id = maxi(next_texture_id, int(spec_stuff.get("texture_id", -1)) + 1)
    refresh_textures()

func refresh_textures() -> void:
    im_ready = false
    for tex in texture_spec:
        load_texture(tex)
    
    textures_loaded.emit()
    im_ready = true

func load_texture(tex: Dictionary):
    var texture: Texture
    var texture_name: = ""
    var metadata: = {}
    if tex['type'] == 'local_file':
        texture_name = tex['image_name']
        var is_shared: bool = tex.get("is_shared", true)
        var for_game_name: String = "" if is_shared else GameManager.get_identified_game_name()
        texture = FilesManager.load_local_image_as_texture(texture_name, for_game_name)
        if texture:
            # Should have already prompted the user to make the texture metadata first but in case we get here make a basic default texture metadata
            if not unloaded_texture_has_metadata(texture_name, false, is_shared):
                var new_meta: = create_metadata_for_texture(texture, true)
                push_warning("No metadata for texture: " + texture_name + ", creating default metadata")
                FilesManager.update_local_image_metadata(texture_name, new_meta, for_game_name)
            metadata = FilesManager.get_local_image_metadata(texture_name, for_game_name)
        else:
            push_warning("Failed to load %s image: %s" % ["shared" if is_shared else "bundled", texture_name])
            texture = placeholder
            metadata = placeholder_metadata
    elif tex['type'] == 'builtin':
        texture_name = tex['name']
        texture = get_builtin_texture_as_texture(texture_name)
        if not builtin_meta:
            grab_builtin_metadata()
        metadata = builtin_meta[tex["name"]]
    elif tex['type'] == "registered":
        # TODO idea for referencing globally unique shared textures to use
        return
    
    _set_texture(int(tex['texture_id']), texture, texture_name, metadata)

func _set_texture(texture_id: int, texture: Texture, texture_name: String, metadata: Dictionary) -> void:
    texture_names[texture_id] = texture_name
    textures[texture_id] = texture
    texture_meta[texture_id] = metadata
    var border: Vector2 = metadata.get("border", Vector2.ZERO)
    tile_sizes[texture_id] = metadata['tile_size']
    var is_multiple_tiles: bool = metadata.get("is_multiple_tiles", true)
    if not is_multiple_tiles:
        var single_tile_rect: = Utility.get_rect_in_single_tile_texture_with_border(texture.get_size(), border)
        prints("single tile size:", texture_name, ",", single_tile_rect.size)
        tile_sizes[texture_id] = single_tile_rect.size
    var separation: Vector2 = metadata.get("separation", Vector2.ZERO)
    var grid_cells: Vector2i = Vector2i.ONE
    if is_multiple_tiles:
        grid_cells = Utility.get_tile_atlas_coords_size(texture.get_size(), tile_sizes[texture_id], border, separation)
    tiles_per_row[texture_id] = grid_cells.x
    texture_rows[texture_id] = grid_cells.y

func get_all_possible_textures() -> Dictionary:
    var texs: = {}
    texs.merge(get_all_builtin_textures())
    texs.merge(get_all_local_textures(), true)
    return texs

func get_all_possible_textures_info() -> Array[Dictionary]:
    var texs: Array[Dictionary] = []
    for tex_name in get_all_builtin_textures():
        texs.append({ "texture_name": tex_name, "is_builtin": true, "is_shared": false })
    for tex_name in get_all_bundled_textures():
        texs.append({ "texture_name": tex_name, "is_builtin": false, "is_shared": false })
    for tex_name in get_all_shared_textures():
        texs.append({ "texture_name": tex_name, "is_builtin": false, "is_shared": true })
    return texs

func get_all_builtin_textures() -> Dictionary:
    var texs: = {}
    for tex in builtin_textures:
        texs[tex] = load(BUILTIN_IMAGE_DIR + tex)
    
    return texs

func get_builtin_texture_as_texture(builtin_texture_name: String) -> Texture:
    if not builtin_texture_name in builtin_textures:
        return null
    return load(BUILTIN_IMAGE_DIR + builtin_texture_name)

func get_all_local_textures() -> Dictionary:
    var texs: = {}
    texs.merge(get_all_bundled_textures())
    texs.merge(get_all_shared_textures())
    return texs

func get_all_bundled_textures() -> Dictionary:
    var texs: = {}
    
    for bundled_image_name in FilesManager.get_all_bundled_image_names(GameManager.get_identified_game_name()):
        var loaded_tex: = FilesManager.load_local_image_as_texture(bundled_image_name, GameManager.get_identified_game_name())
        if loaded_tex:
            texs[bundled_image_name] = loaded_tex
        else:
            push_warning("Failed to load bundled image: " + bundled_image_name)
    return texs

func get_all_shared_textures() -> Dictionary:
    var texs: = {}
    for shared_user_tex in FilesManager.get_all_shared_image_names():
        if texs.has(shared_user_tex):
            continue
        var loaded_tex: = FilesManager.load_local_image_as_texture(shared_user_tex, "")
        if loaded_tex:
            texs[shared_user_tex] = loaded_tex
        else:
            push_warning("Failed to load shared image: " + shared_user_tex)
    return texs
    

func get_new_texture_id() -> int:
    var next_id: = next_texture_id
    next_texture_id += 1
    return next_id

func get_texture_name(texture_id: int) -> String:
    return texture_names[texture_id]

func get_current_texture_ids() -> Array:
    return texture_names.keys()

func get_current_texture_names() -> Array:
    var name_list: = []
    for texture_id in get_current_texture_ids():
        name_list.append(get_texture_name(texture_id))
    return name_list

func get_all_indexes() -> Array:
    return textures.keys()

func get_texture(texture_id: int) -> Texture:
    if not texture_id in textures:
        return placeholder
    return textures[texture_id]

func get_index_offset(texture_id: int, tile_index: int) -> Vector2:
    var border: Vector2 = texture_meta[texture_id].get("border", Vector2.ZERO)
    if not texture_meta[texture_id].get("is_multiple_tiles", true):
        return Utility.get_rect_in_single_tile_texture_with_border(tile_sizes[texture_id], border).position
    var tpr: int = get_tiles_per_row(texture_id)
    var tsize = tile_sizes[texture_id]
    var separation: Vector2 = texture_meta[texture_id].get("separation", Vector2.ZERO)
    return Utility.get_indexed_tile_offset_by_per_row(tile_index, tpr, tsize, border, separation)

func get_tiles_per_row(texture_id: int) -> int:
    return tiles_per_row[texture_id]

func get_texture_metadata(texture_id: int) -> Dictionary:
    return texture_meta.get(texture_id, {})

func get_index_rect(texture_id: int, tile_index: int) -> Rect2:
    if not texture_meta[texture_id].get("is_multiple_tiles", true):
        var border: Vector2 = texture_meta[texture_id].get("border", Vector2.ZERO)
        return Utility.get_rect_in_single_tile_texture_with_border(tile_sizes[texture_id], border)
    return Rect2(get_index_offset(texture_id, tile_index), tile_sizes[texture_id])

func get_texture_tile_size(texture_id: int) -> Vector2i:
    return tile_sizes[texture_id]

func get_index_atlas_coords(texture_id: int, tile_index: int) -> Vector2i:
    return Utility.get_indexed_tile_atlas_coords(tile_index, tiles_per_row[texture_id])

func create_metadata_for_texture(texture: Texture2D, as_savable_format: bool = false) -> Dictionary:
    var new_meta: = placeholder_metadata.duplicate_deep()

    new_meta["size"] = texture.get_size()
    if as_savable_format:
        new_meta["size"] = Utility.vector_to_list(new_meta["size"])
    new_meta["tile_size"] = Vector2(MapManager.tile_width, MapManager.tile_width)
    if as_savable_format:
        new_meta["tile_size"] = Utility.vector_to_list(new_meta["tile_size"])

    var size_tiles: Vector2i = (texture.get_size() / new_meta["tile_size"]).floor()
    new_meta["size_in_tiles"] = size_tiles
    if as_savable_format:
        new_meta["size_in_tiles"] = Utility.vector_to_list(new_meta["size_in_tiles"])
    
    new_meta["border"] = Vector2.ZERO
    new_meta["separation"] = Vector2.ZERO
    if as_savable_format:
        new_meta["border"] = Utility.vector_to_list(new_meta["border"])
        new_meta["separation"] = Utility.vector_to_list(new_meta["separation"])
    
    new_meta["is_multiple_tiles"] = true
    if size_tiles == Vector2i.ONE:
        new_meta["is_multiple_tiles"] = false

    return new_meta

func get_loaded_texture_id(of_name: String, is_builtin: bool = false, is_shared: bool = true) -> int:
    for tex_spec in texture_spec:
        var spec_name: String = tex_spec.get("name", "")
        if tex_spec["type"] == "local_file":
            spec_name = tex_spec.get("image_name", "")
        if not spec_name == of_name:
            continue
        if is_builtin:
            if tex_spec['type'] == 'builtin':
                return int(tex_spec['texture_id'])
        else:
            if tex_spec['type'] == 'local_file' and tex_spec.get("is_shared", true) == is_shared:
                return int(tex_spec['texture_id'])
    return -1


func remove_loaded_texture_by_name(texture_name: String, is_builtin: bool = false, is_shared: bool = true) -> void:
    var the_texture_id: = get_loaded_texture_id(texture_name, is_builtin, is_shared)
    if the_texture_id == -1:
        return
    remove_loaded_texture_by_id(the_texture_id)

func _unload_texture(texture_id: int) -> void:
    textures.erase(texture_id)
    texture_names.erase(texture_id)
    texture_meta.erase(texture_id)
    tile_sizes.erase(texture_id)
    tiles_per_row.erase(texture_id)
    texture_rows.erase(texture_id)

func get_loaded_texture_info(texture_id: int) -> Dictionary:
    var spec_stuff: = {}
    var spec_index: int = -1
    for i in texture_spec.size():
        var tex_spec: Dictionary = texture_spec[i]
        if int(tex_spec['texture_id']) == texture_id:
            spec_index = i
            spec_stuff = tex_spec
            break
    if not spec_stuff:
        return {}

    return {
        "texture_id": texture_id,
        "spec_index": spec_index,
        "name": get_texture_name(texture_id),
        "texture": get_texture(texture_id),
        "is_builtin": spec_stuff['type'] == 'builtin',
        "is_shared": spec_stuff.get('is_shared', true) and not spec_stuff['type'] == 'builtin',
        "metadata": {} if not texture_meta.has(texture_id) else texture_meta[texture_id],
    }


func unloaded_texture_has_metadata(texture_name: String, is_builtin: bool = false, is_shared: bool = true) -> bool:
    if is_builtin:
        if not builtin_meta:
            grab_builtin_metadata()
        return builtin_meta.has(texture_name)
    var for_game_name: String = "" if is_shared else GameManager.get_identified_game_name()
    return FilesManager.has_local_image_metadata(texture_name, for_game_name)

func _convert_texture_meta_for_saving(metadata: Dictionary) -> Dictionary:
    metadata = metadata.duplicate_deep()
    for key in metadata:
        if metadata[key] is Vector2:
            metadata[key] = Utility.vector_to_list(metadata[key])
    return metadata

func save_loaded_texture_metadata(texture_id: int, is_builtin: bool = false, is_shared: bool = true) -> void:
    if is_builtin:
        push_error("Can't change builtin texture metadata")
        return
    var for_game_name: String = "" if is_shared else GameManager.get_identified_game_name()
    var texture_name: = get_texture_name(texture_id)
    var local_meta: = get_texture_metadata(texture_id)
    FilesManager.update_local_image_metadata(texture_name, _convert_texture_meta_for_saving(local_meta), for_game_name)

func set_texture_meta_by_name(texture_name: String, is_builtin: bool, is_shared: bool, new_meta: Dictionary, for_game_name: String = "") -> void:
    if is_builtin:
        push_error("Can't change builtin texture metadata")
        return
    prints("setting texture meta by name: ", texture_name, "is_builtin: ", is_builtin, "is_shared: ", is_shared, "new_meta: ", new_meta)
    new_meta = new_meta.duplicate_deep()
    var texture_id: = get_loaded_texture_id(texture_name, is_builtin, is_shared)
    if texture_id >= 0:
        texture_meta[texture_id] = new_meta
        save_loaded_texture_metadata(texture_id, is_builtin, is_shared)
        refresh_textures()
    if is_shared:
        for_game_name = ""
    if not is_shared and not for_game_name:
        for_game_name = GameManager.get_identified_game_name()
    FilesManager.update_local_image_metadata(texture_name, _convert_texture_meta_for_saving(new_meta), for_game_name)

func get_texture_metadata_by_name(texture_name: String, is_builtin: bool, is_shared: bool, containing_game_name: String = "") -> Dictionary:
    if is_builtin:
        if not builtin_meta:
            grab_builtin_metadata()
        return builtin_meta.get(texture_name, {})

    if is_shared:
        containing_game_name = ""
    elif not containing_game_name:
        containing_game_name = GameManager.get_identified_game_name()
    return FilesManager.get_local_image_metadata(texture_name, containing_game_name)

func get_texture_by_name(texture_name: String, is_builtin: bool, is_shared: bool, containing_game_name: String = "") -> Texture2D:
    if is_builtin:
        return get_builtin_texture_as_texture(texture_name)
    if is_shared:
        containing_game_name = ""
    elif not containing_game_name:
        containing_game_name = GameManager.get_identified_game_name()
    return FilesManager.load_local_image_as_texture(texture_name, containing_game_name)

func has_loaded_texture_id(texture_id: int) -> bool:
    return texture_id in texture_names

func get_fallback_texture_id() -> int:
    if texture_spec.size() == 0:
        return -1
    return int(texture_spec[0]['texture_id'])

func get_tile_texture_id_fallback() -> int:
    if is_builtin_loaded("tiles.png"):
        return get_loaded_texture_id("tiles.png", true, false)
    return get_fallback_texture_id()

func get_entity_texture_id_fallback() -> int:
    if is_builtin_loaded("tiles.png"):
        return get_loaded_texture_id("entityTiles.png", true, false)
    return get_fallback_texture_id()

func get_max_texture_index(texture_id: int) -> int:
    if not tiles_per_row.has(texture_id) or not texture_rows.has(texture_id):
        return 0
    var rows: int = texture_rows[texture_id]
    var cols: int = tiles_per_row[texture_id]
    return rows * cols - 1

func _unique_bundled_image_name(image_base_name: String) -> String:
    return _unique_image_name(image_base_name, true)

func _unique_image_name(image_base_name: String, bundled_image: bool = true) -> String:
    if bundled_image and not GameManager.get_identified_game_name():
        return ""
    return _unique_image_name_for_game(image_base_name, bundled_image, GameManager.get_identified_game_name())

func _unique_image_name_for_game(image_base_name: String, bundled_image: bool, game_name: String) -> String:
    if not image_base_name or (bundled_image and not game_name):
        return ""
    var bundled_image_name: String = image_base_name
    var for_game_name: String = game_name if bundled_image else ""
    for i in 1001:
        if not FilesManager.local_image_file_exists(bundled_image_name, for_game_name):
            break
        var extra_word: String = "Bundled" if bundled_image else "Shared"
        bundled_image_name = image_base_name.get_basename() + "(" + extra_word + "-" + str(i) + ").png"
        if i == 1000:
            push_error("Failed to find a unique name for bundled image: " + image_base_name)
            return ""
    return bundled_image_name

func is_using_any_shared_images() -> bool:
    for tex_spec_item in texture_spec:
        if tex_spec_item['type'] == 'local_file' and tex_spec_item.get('is_shared', true):
            return true
    return false

func bundle_all_used_shared_images() -> bool:
    # keep copy to revert to if any operations fail
    var old_spec: = texture_spec
    texture_spec = texture_spec.duplicate_deep()
    var copied_files: Array[String] = []
    
    var success: = true
    for tex_spec_item in texture_spec:
        var is_local_shared: bool = tex_spec_item['type'] == 'local_file' and tex_spec_item.get('is_shared', true)
        if not is_local_shared:
            continue

        var tex_meta: = get_texture_metadata(int(tex_spec_item['texture_id']))
        var bundled_image_name: String = _unique_bundled_image_name(Utility.sanitize_for_filename(tex_spec_item['image_name'], true, true))
        if not bundled_image_name:
            success = false
            break
        if not FilesManager.copy_shared_image_into_game(tex_spec_item['image_name'], bundled_image_name, GameManager.get_identified_game_name()):
            success = false
            break
        copied_files.append(bundled_image_name)
        
        # update to be a bundled image
        tex_spec_item['image_name'] = bundled_image_name
        tex_spec_item['is_shared'] = false
        FilesManager.update_local_image_metadata(bundled_image_name, _convert_texture_meta_for_saving(tex_meta), GameManager.get_identified_game_name())
    
    if not success:
        for copied_file in copied_files:
            FilesManager.delete_local_image(copied_file, GameManager.get_identified_game_name())
        texture_spec = old_spec
        return false
    
    refresh_textures()
    return true

func make_texture_id_bundled(texture_id: int) -> bool:
    var info: = get_loaded_texture_info(texture_id)
    if not info:
        return false
    if info["is_builtin"]:
        return make_builtin_image_bundled(info["name"])
    elif info.get("is_shared", true):
        return make_shared_image_bundled(info["name"])
    # otherwise it's already bundled
    return true

func make_shared_image_bundled(shared_texture_name: String) -> bool:
    var game_name: String = GameManager.get_identified_game_name()
    if not game_name:
        return false

    var sanitized_name: = Utility.sanitize_for_filename(shared_texture_name, true, true)
    if not FilesManager.local_image_file_exists(sanitized_name, ""):
        return false
    var bundled_name: = _unique_bundled_image_name(sanitized_name)
    if not bundled_name:
        return false
    if not FilesManager.copy_shared_image_into_game(sanitized_name, bundled_name, game_name):
        return false
    
    var tex_meta: = get_texture_metadata_by_name(shared_texture_name, false, true)
    set_texture_meta_by_name(bundled_name, false, false, tex_meta)
    
    for tex_spec_item in texture_spec:
        if tex_spec_item['type'] != 'local_file' or tex_spec_item.get('is_shared', true):
            continue
        elif tex_spec_item['image_name'] == sanitized_name:
            tex_spec_item['image_name'] = bundled_name
            tex_spec_item['is_shared'] = false
            break
    refresh_textures()
    return true

func save_local_copy_of_local_image(from_name: String, from_shared: bool, to_name: String, to_shared: bool, from_game_name: String = "", to_game_name: String = "") -> String:
    var from_g: String = ""
    if not from_shared:
        if not from_game_name:
            from_g = GameManager.get_identified_game_name()
        else:
            from_g = from_game_name
    
    var to_g: String = ""
    if not to_shared:
        if not to_game_name:
            to_g = GameManager.get_identified_game_name()
        else:
            to_g = to_game_name

    if (not from_shared and not from_g) or (not to_shared and not to_g):
        return ""

    if FilesManager.local_image_file_exists(to_name, to_g):
        to_name = _unique_image_name_for_game(to_name, not to_shared, to_g)

    var success: = FilesManager.copy_local_image_to_local(from_name, from_g, to_name, to_g)
    if not success:
        return ""
    
    var tex_meta: = get_texture_metadata_by_name(from_name, false, from_shared, from_g)
    set_texture_meta_by_name(to_name, false, to_shared, tex_meta, to_g)
    return to_name

func save_bundled_image_between_games(image_name: String, from_game_name: String, to_game_name: String) -> String:
    return save_local_copy_of_local_image(image_name, false, image_name, false, from_game_name, to_game_name)


func _get_builtin_texture_as_image(texture_name: String) -> Image:
    if not texture_name in builtin_textures:
        return null
    return load(BUILTIN_IMAGE_DIR + texture_name).get_image()

func save_builtin_copy_to_local(builtin_image_name: String, to_game_name: String = "", convert_texture_id: bool = true) -> String:
    if not builtin_image_name in builtin_textures:
        return ""
    var local_image_name: = _unique_image_name_for_game(builtin_image_name, to_game_name != "", to_game_name)
    if not FilesManager.save_local_image(_get_builtin_texture_as_image(builtin_image_name), local_image_name, to_game_name):
        return ""
    
    if not builtin_meta:
        grab_builtin_metadata()
    var tex_meta: Dictionary = builtin_meta[builtin_image_name].duplicate_deep()
    set_texture_meta_by_name(local_image_name, false, to_game_name == "", tex_meta, to_game_name)
    
    # convert the usage of that builtin image in the current game to use the local copy
    if convert_texture_id and to_game_name == GameManager.get_identified_game_name():
        for tex_spec_item in texture_spec:
            if tex_spec_item['type'] != 'builtin' or tex_spec_item['name'] != builtin_image_name:
                continue
            tex_spec_item['type'] = 'local_file'
            tex_spec_item['image_name'] = local_image_name
            tex_spec_item.erase('name')
            tex_spec_item['is_shared'] = to_game_name == ""
        refresh_textures()

    return local_image_name

# Duplicate the builtin image into the game bundle location and remap the old usage to the copy
func make_builtin_image_bundled(builtin_image_name: String) -> bool:
    if not GameManager.get_identified_game_name():
        return false
    return save_builtin_copy_to_local(builtin_image_name, GameManager.get_identified_game_name(), true) != ""

func remap_texture_id_to_image(texture_id: int, to_image_name: String, to_builtin: bool, to_shared: bool) -> bool:
    if not texture_id in textures:
        return false
    # ensure the target image exists
    if to_builtin:
        if to_image_name not in builtin_textures:
            return false
    else:
        var for_game_name: String = "" if to_shared else GameManager.get_identified_game_name()
        if not FilesManager.local_image_file_exists(to_image_name, for_game_name):
            return false
    
    var info: = get_loaded_texture_info(texture_id)
    if info['is_builtin'] == to_builtin and info['is_shared'] == (to_shared and not to_builtin):
        if info['name'] == to_image_name:
            return true
    
    var to_type_str: = "builtin" if to_builtin else "local_file"
    var name_check_key: = "name" if to_builtin else "image_name"
    var current_tex_spec_item: = {}
    for tex_spec_item in texture_spec:
        var this_texture_id: = int(tex_spec_item['texture_id'])
        if this_texture_id == texture_id:
            current_tex_spec_item = tex_spec_item
        # if the target is already in use, merge the two ids
        if tex_spec_item['type'] == to_type_str and tex_spec_item[name_check_key] == to_image_name:
            if to_builtin or tex_spec_item.get('is_shared', true) == to_shared:
                prints("merge remapping into id:", this_texture_id)
                return merge_remap_texture_id_into_texture_id(texture_id, this_texture_id)
    
    if not current_tex_spec_item:
        # should already have been handled, but unable to find the spec item for this texture id
        push_warning("Unable to find the spec item for this texture id")
        return false
    # otherwise, convert the entry to the new target
    current_tex_spec_item['type'] = to_type_str
    if to_builtin:
        current_tex_spec_item['name'] = to_image_name
        current_tex_spec_item.erase('image_name')
        current_tex_spec_item.erase('is_shared')
    else:
        current_tex_spec_item['image_name'] = to_image_name
        current_tex_spec_item.erase('name')
        current_tex_spec_item['is_shared'] = to_shared
    
    refresh_textures()
    textures_remapped.emit()
    return true


func merge_remap_texture_id_into_texture_id(merge_from_texture_id: int, into_texture_id: int) -> bool:
    var info: = get_loaded_texture_info(merge_from_texture_id)
    var into_info: = get_loaded_texture_info(into_texture_id)
    if not info or not into_info:
        return false

    return _remap_of_texture_id_into_texture_id(merge_from_texture_id, into_texture_id)

func _remap_of_texture_id_into_texture_id(from_texture_id: int, into_texture_id: int) -> bool:
    var info: = get_loaded_texture_info(from_texture_id)
    if not info:
        return false
    EntityManager.remapping_texture_id(from_texture_id, into_texture_id)
    MapManager.remapping_texture_id(from_texture_id, into_texture_id)
    GameManager.remap_texture_id_in_game_and_levels(from_texture_id, into_texture_id)
    
    _unload_texture(from_texture_id)
    texture_spec.remove_at(info["spec_index"])
    refresh_textures()
    textures_remapped.emit()
    return true

func remove_loaded_texture_by_id(texture_id: int) -> void:
    var spec_stuff: = {}
    for tex_spec in texture_spec:
        if int(tex_spec['texture_id']) == texture_id:
            spec_stuff = tex_spec
            break
    if not spec_stuff:
        return
    EntityManager.removing_texture_id(texture_id)
    MapManager.removing_texture_id(texture_id)
    
    _unload_texture(texture_id)
    texture_spec.erase(spec_stuff)
    refresh_textures()
    textures_remapped.emit()

func has_texture_id(texture_id: int) -> bool:
    for tex_spec in texture_spec:
        if int(tex_spec['texture_id']) == texture_id:
            return true
    return false

func is_texture_id_in_use(texture_id: int, only_bundled_levels: bool = true) -> bool:
    if not texture_id in textures:
        return false
    if EntityManager.is_texture_id_in_use(texture_id) or MapManager.is_texture_id_in_use(texture_id):
        return true
    if GameManager.is_texture_id_used_in_game_or_levels(texture_id, only_bundled_levels):
        return true
    return false

func make_duplicate_of_image(copy_to_shared: bool, from_name: String, from_builtin: bool, from_shared: bool) -> bool:
    if not copy_to_shared and not GameManager.get_identified_game_name():
        return false
    if from_builtin:
        var for_game_name: String = "" if copy_to_shared else GameManager.get_identified_game_name()
        return save_builtin_copy_to_local(from_name, for_game_name, false) != ""
    else:
        return save_local_copy_of_local_image(from_name, from_shared, from_name, copy_to_shared) != ""
        
func find_loaded_texture_id(texture_name: String, is_builtin: bool, is_shared: bool) -> int:
    for tex_spec in texture_spec:
        if is_builtin:
            if tex_spec['type'] == 'builtin' and tex_spec['name'] == texture_name:
                return int(tex_spec['texture_id'])
        elif tex_spec['type'] == 'local_file':
            if tex_spec['image_name'] == texture_name and tex_spec.get('is_shared', true) == is_shared:
                return int(tex_spec['texture_id'])
    return -1

func has_enabled_shared_images() -> bool:
    for tex_spec in texture_spec:
        if tex_spec['type'] == 'local_file' and tex_spec.get('is_shared', true):
            return true
    return false

# Do not change logic or order, used by hash calculation
func get_all_used_bundled_texture_ids() -> Array[int]:
    return get_all_used_bundled_texture_ids_from_spec(texture_spec)
func get_all_used_bundled_texture_ids_from_spec(from_texture_spec: Array) -> Array[int]:
    var bundled_texture_ids: Array[int] = []
    for tex_spec in from_texture_spec:
        if tex_spec['type'] == 'local_file' and not tex_spec.get('is_shared', true):
            bundled_texture_ids.append(int(tex_spec['texture_id']))
    bundled_texture_ids.sort()
    return bundled_texture_ids

# Do not change logic used by hash calculation
func get_bundled_texture_image_name(texture_id: int) -> String:
    return get_bundled_texture_image_name_from_spec(texture_spec, texture_id)
func get_bundled_texture_image_name_from_spec(from_texture_spec: Array, texture_id: int) -> String:
    for tex_spec_item in from_texture_spec:
        if int(tex_spec_item['texture_id']) != texture_id:
            continue
        if not tex_spec_item['type'] == 'local_file' or tex_spec_item.get('is_shared', true):
            continue
        return tex_spec_item['image_name']
    return ""


func make_foreign_texture_lookup(foreign_texture_spec: Array, for_game_name: String = "") -> Dictionary:
    var lookup: Dictionary = {
        "errors": Array([], TYPE_INT, "", null),
        "bundled_images": {},
        "metadata": {},
        "tile_sizes": {},
        "builtin_names": {},
        "shared_names": {},
    }
    for tex_spec_item in foreign_texture_spec:
        if not tex_spec_item.has('texture_id') or typeof(tex_spec_item['texture_id']) not in [TYPE_INT, TYPE_FLOAT]:
            continue

        var texture_id: int = int(tex_spec_item['texture_id'])
        if texture_id < 0:
            lookup["errors"].append(texture_id)
            continue
        lookup[texture_id] = placeholder
        lookup["tile_sizes"][texture_id] = placeholder_metadata["tile_size"]

        if tex_spec_item['type'] == 'builtin':
            if tex_spec_item['name'] in builtin_textures:
                lookup[texture_id] = get_builtin_texture_as_texture(tex_spec_item['name'])
                if not builtin_meta:
                    grab_builtin_metadata()
                var meta: Dictionary = builtin_meta.get(tex_spec_item['name'], {})
                lookup["tile_sizes"][texture_id] = meta.get("tile_size", Vector2(32, 32))
                lookup["builtin_names"][texture_id] = tex_spec_item['name']
                lookup["metadata"][texture_id] = meta.duplicate_deep()
            else:
                lookup["errors"].append(texture_id)
        elif tex_spec_item['type'] == 'local_file':
            var is_shared: bool = tex_spec_item.get('is_shared', true)
            var image_name: String = tex_spec_item.get('image_name', "")
            if image_name:
                var ref_game_name: String = "" if is_shared else for_game_name
                var loaded_local_image = FilesManager.load_local_image_as_texture(image_name, ref_game_name)
                if not loaded_local_image:
                    lookup["errors"].append(texture_id)
                else:
                    lookup[texture_id] = loaded_local_image
                    var meta: Dictionary = FilesManager.get_local_image_metadata(image_name, ref_game_name)
                    lookup["tile_sizes"][texture_id] = meta.get("tile_size", placeholder_metadata["tile_size"])
                    lookup["metadata"][texture_id] = meta.duplicate_deep()
                    if is_shared:
                        lookup["shared_names"][texture_id] = image_name
                    else:
                        lookup["bundled_images"][texture_id] = image_name
            else:
                lookup["errors"].append(texture_id)
                lookup[texture_id] = placeholder
    return lookup


func load_and_copy_from_foreign_lookup(lookup: Dictionary, from_game_name: String, limit_to_ids: Array) -> Dictionary[int, int]:
    var remaps: Dictionary[int, int] = {}

    for builtin_id in lookup["builtin_names"]:
        if not builtin_id in limit_to_ids:
            continue
        var builtin_name: String = lookup["builtin_names"][builtin_id]
        if is_builtin_loaded(builtin_name):
            remaps[builtin_id] = find_loaded_texture_id(builtin_name, true, false)
        else:
            remaps[builtin_id] = add_builtin_texture(builtin_name)
    
    for shared_id in lookup["shared_names"]:
        if not shared_id in limit_to_ids:
            continue
        var shared_name: String = lookup["shared_names"][shared_id]
        if is_local_file_loaded(shared_name, true):
            remaps[shared_id] = find_loaded_texture_id(shared_name, false, true)
        else:
            remaps[shared_id] = add_local_texture(shared_name, true)
    
    var this_game_name: String = GameManager.get_identified_game_name()
    for bundled_id in lookup["bundled_images"]:
        if not bundled_id in limit_to_ids:
            continue
        var bundled_name: String = lookup["bundled_images"][bundled_id]
        var imported_as_name: String = save_bundled_image_between_games(bundled_name, from_game_name, this_game_name)
        if not imported_as_name:
            push_warning("Failed to copy bundled image between games: " + bundled_name)
            remaps[bundled_id] = -1
            continue
        remaps[bundled_id] = add_local_texture(imported_as_name, false)
    
    return remaps


