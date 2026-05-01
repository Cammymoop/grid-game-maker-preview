extends Node

signal textures_loaded

var placeholder = preload("res://assets/img/placeholder.png")
var placeholder_metadata = {
    tile_size= Vector2(32, 32),
    size_in_tiles= Vector2(4, 4),
    border= Vector2.ZERO,
    separation= Vector2.ZERO,
}

var builtin_textures: Array[String] = [
    "tiles.png",
    "entityTiles.png",
    "playerVariants.png",
    "shapes32x.png",
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
    
    builtin_meta = fix_vecs_texture_metas(result)

func fix_vecs_texture_metas(metas: Dictionary) -> Dictionary:
    var new_dict = {}
    for key in metas:
        new_dict[key] = fix_vecs_texture_meta(metas[key])
    return new_dict

func fix_vecs_texture_meta(meta: Dictionary) -> Dictionary:
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

func add_local_texture(file_name: String) -> void:
    if is_local_file_loaded(file_name):
        return
    var spec = {
        type = "local_file",
        is_shared = true,
        image_name = file_name,
        texture_id = get_new_texture_id(),
        filter = false,
    }
    add_texture(spec)
func add_builtin_texture(tex_name: String) -> void:
    print_stack()
    if is_builtin_loaded(tex_name):
        return
    var spec = {
        type = "builtin",
        name = tex_name, 
        texture_id = get_new_texture_id(),
        filter = false,
    }
    add_texture(spec)

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
        texture = FilesManager.load_shared_image_as_texture(texture_name)
        if texture:
            # Should prompt the user to make the texture metadata first but in case we get here make a basic default texture metadata
            if not unloaded_texture_has_metadata(texture_name, false, tex.get("is_shared", true)):
                var new_meta: = create_metadata_for_texture(texture)
                push_warning("No metadata for texture: " + texture_name + ", creating default metadata")
                FilesManager.update_local_image_metadata(texture_name, new_meta)
            metadata = fix_vecs_texture_meta(FilesManager.get_local_image_metadata(texture_name))
        else:
            push_warning("Failed to load shared image: " + texture_name)
            texture = placeholder
            metadata = placeholder_metadata
    elif tex['type'] == 'builtin':
        texture_name = tex['name']
        texture = load(BUILTIN_IMAGE_DIR + texture_name)
        if not builtin_meta:
            grab_builtin_metadata()
        metadata = builtin_meta[tex["name"]]
    elif tex['type'] == "registered":
        # TODO handle keeping track of downloaded textures by global id
        return
    
    _set_texture(int(tex['texture_id']), texture, texture_name, metadata)

func _set_texture(texture_id: int, texture: Texture, texture_name: String, metadata: Dictionary) -> void:
        texture_names[texture_id] = texture_name
        textures[texture_id] = texture
        texture_meta[texture_id] = metadata
        var tile_size = metadata['tile_size']
        tile_sizes[texture_id] = tile_size
        tiles_per_row[texture_id] = int(texture.get_width() / tile_size.x)
        texture_rows[texture_id] = int(texture.get_height() / tile_size.y)

func get_unloaded_texture(texture_name: String, builtin: bool = false) -> Texture:
    if builtin:
        return load(BUILTIN_IMAGE_DIR + texture_name) as Texture
    
    return FilesManager.load_shared_image_as_texture(texture_name)

func get_all_possible_textures() -> Dictionary:
    var texs: = {}
    for tex in builtin_textures:
        texs[tex] = load(BUILTIN_IMAGE_DIR+ tex)
    
    for user_tex in FilesManager.get_all_image_names():
        var loaded_tex: = FilesManager.load_shared_image_as_texture(user_tex)
        if loaded_tex:
            texs[user_tex] = loaded_tex
        else:
            push_warning("Failed to load shared image: " + user_tex)
    
    return texs

func get_all_builtin_textures() -> Dictionary:
    var texs: = {}
    for tex in builtin_textures:
        texs[tex] = load(BUILTIN_IMAGE_DIR + tex)
    
    return texs

func get_all_user_textures() -> Dictionary:
    var texs: = {}
    
    for user_tex in FilesManager.get_all_image_names():
        var loaded_tex: = FilesManager.load_shared_image_as_texture(user_tex)
        if loaded_tex:
            texs[user_tex] = loaded_tex
        else:
            push_warning("Failed to load shared image: " + user_tex)
    
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
    var tpr: int = tiles_per_row[texture_id]
    var tsize = tile_sizes[texture_id]
    return Vector2(tile_index % tpr * tsize.x, floor(tile_index/float(tpr)) * tsize.y)

func get_tiles_per_row(texture_id: int) -> int:
    return tiles_per_row[texture_id]

func get_texture_metadata(texture_id: int) -> Dictionary:
    return texture_meta.get(texture_id, {})

func get_index_rect(texture_id: int, tile_index: int) -> Rect2:
    return Rect2(get_index_offset(texture_id, tile_index), tile_sizes[texture_id])

func get_texture_tile_size(texture_id: int) -> Vector2i:
    return tile_sizes[texture_id]

func get_index_atlas_coords(texture_id: int, tile_index: int) -> Vector2i:
    var tpr: int = tiles_per_row[texture_id]
    return Vector2i(tile_index % tpr, floor(tile_index/float(tpr)))

func get_last_sub_index(texture_id: int) -> int:
    var tpr: int = tiles_per_row[texture_id]
    var rows: int = texture_rows[texture_id]
    return (rows * tpr) - 1

func create_metadata_for_texture(texture: Texture2D) -> Dictionary:
    var new_meta: = placeholder_metadata.duplicate_deep()

    new_meta["size"] = Utility.vector_to_list(texture.get_size())
    var tile_size: = Vector2(MapManager.tile_width, MapManager.tile_width)
    new_meta["tile_size"] = Utility.vector_to_list(tile_size)

    var size_tiles: = (texture.get_size() / tile_size).floor()
    new_meta["size_in_tiles"] = Utility.vector_to_list(size_tiles)

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
                return tex_spec['texture_id']
        else:
            if tex_spec['type'] == 'local_file' and tex_spec.get("is_shared", true) == is_shared:
                return tex_spec['texture_id']
    return -1


func remove_loaded_texture_by_name(texture_name: String, is_builtin: bool = false, is_shared: bool = true) -> void:
    var the_texture_id: = get_loaded_texture_id(texture_name, is_builtin, is_shared)
    if the_texture_id == -1:
        return
    remove_loaded_texture_by_id(the_texture_id)

func remove_loaded_texture_by_id(texture_id: int) -> void:
    var spec_stuff: = {}
    for tex_spec in texture_spec:
        if tex_spec['texture_id'] == texture_id:
            spec_stuff = tex_spec
            break
    if not spec_stuff:
        return
    EntityManager.removing_texture_id(texture_id)
    MapManager.removing_texture_id(texture_id)
    
    _unload_texture(texture_id)
    texture_spec.erase(spec_stuff)

func _unload_texture(texture_id: int) -> void:
    textures.erase(texture_id)
    texture_names.erase(texture_id)
    texture_meta.erase(texture_id)
    tile_sizes.erase(texture_id)
    tiles_per_row.erase(texture_id)
    texture_rows.erase(texture_id)

func get_loaded_texture_info(texture_id: int) -> Dictionary:
    var spec_stuff: = {}
    for tex_spec in texture_spec:
        if tex_spec['texture_id'] == texture_id:
            spec_stuff = tex_spec
            break
    if not spec_stuff:
        return {}

    return {
        "texture_id": texture_id,
        "name": get_texture_name(texture_id),
        "texture": get_texture(texture_id),
        "is_builtin": spec_stuff['type'] == 'builtin',
        "is_shared": spec_stuff.get('is_shared', true),
        "metadata": {} if not texture_meta.has(texture_id) else texture_meta[texture_id],
    }


func unloaded_texture_has_metadata(texture_name: String, is_builtin: bool = false, is_shared: bool = true) -> bool:
    if is_builtin:
        if not builtin_meta:
            grab_builtin_metadata()
        return builtin_meta.has(texture_name)
    if not is_shared:
        push_error("Texture inside game not implemented yet")
    return FilesManager.has_local_image_metadata(texture_name)

func get_unloaded_texture_meta(texture_name: String, is_builtin: bool = false, is_shared: bool = true) -> Dictionary:
    if is_builtin:
        if not builtin_meta:
            grab_builtin_metadata()
        return builtin_meta[texture_name]
    if not is_shared:
        push_error("Texture inside game not implemented yet")
    var raw_meta: = FilesManager.get_local_image_metadata(texture_name)
    return fix_vecs_texture_meta(raw_meta)

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
    if not is_shared:
        push_error("Texture inside game not implemented yet")
    var texture_name: = get_texture_name(texture_id)
    var local_meta: = get_texture_metadata(texture_id)
    FilesManager.update_local_image_metadata(texture_name, _convert_texture_meta_for_saving(local_meta))

func set_texture_meta_by_name(texture_name: String, is_builtin: bool, is_shared: bool, new_meta: Dictionary) -> void:
    if is_builtin:
        push_error("Can't change builtin texture metadata")
        return
    new_meta = new_meta.duplicate_deep()
    var texture_id: = get_loaded_texture_id(texture_name, is_builtin, is_shared)
    if texture_id >= 0:
        texture_meta[texture_id] = new_meta
        save_loaded_texture_metadata(texture_id, is_builtin, is_shared)
        refresh_textures()
    elif not is_shared:
        push_error("Texture inside game not implemented yet")
    else:
        FilesManager.update_local_image_metadata(texture_name, _convert_texture_meta_for_saving(new_meta))

func has_loaded_texture_id(texture_id: int) -> bool:
    return texture_id in texture_names

func get_fallback_texture_id() -> int:
    if texture_spec.size() == 0:
        return -1
    return texture_spec[0]['texture_id']

func get_max_texture_index(texture_id: int) -> int:
    if not texture_rows.has(texture_id):
        return 0
    var rows: int = texture_rows[texture_id]
    var cols: int = tiles_per_row[texture_id]
    return rows * cols - 1
