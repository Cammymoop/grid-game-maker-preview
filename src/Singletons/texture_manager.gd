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
    "shapes32x.png",
]
var builtin_meta: = {}
var default_textures: Array[String] = [
    "tiles.png",
    "entityTiles.png",
    "shapes32x.png",
]
var texture_names: Dictionary [int, String] = {}
var textures: Dictionary [int, Texture] = {}
var tiles_per_row: Dictionary [int, int] = {0: 16}
var texture_rows: Dictionary [int, int] = {}
var tile_sizes: = {}
var texture_meta: = {}

var texture_spec: Array

var im_ready: = false

const BUILTIN_IMAGE_DIR: = "res://assets/img/"

func setup() -> void:
    for t in builtin_textures:
        add_builtin_texture(t)
    reload_spec()
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
        if t["type"] != "builtin":
            continue
        if t["name"] == builtin_tex_name:
            return true
    return false

func is_local_file_loaded(file_name: String) -> bool:
    for t in texture_spec:
        if t["type"] != "local_file":
            continue
        if t["image_name"] == file_name:
            return true
    return false

func add_local_texture(file_name: String) -> void:
    if is_local_file_loaded(file_name):
        return
    var spec = {type = "local_file", image_name = file_name, texture_id = get_new_texture_index(), filter = false}
    add_texture(spec)
func add_builtin_texture(tex_name: String) -> void:
    if is_builtin_loaded(tex_name):
        return
    var spec = {type = "builtin", name = tex_name, texture_id = get_new_texture_index()}
    add_texture(spec)

func set_default_textures() -> void:
    texture_spec = get_default_texture_spec()
    reload_spec()

func get_default_texture_spec() -> Array:
    var spec: = []
    var next_id = 0
    for texture_name in default_textures:
        spec.append({type = "builtin", texture_id = next_id, name = texture_name})
        next_id += 1
    return spec

func set_textures(from_texture_spec: Array) -> void:
    texture_spec = from_texture_spec
    reload_spec()

func reload_spec() -> void:
    im_ready = false
    for tex in texture_spec:
        load_texture(tex)
    
    emit_signal("textures_loaded")
    im_ready = true

func load_texture(tex: Dictionary):
    var texture: Texture
    var texture_name: = ""
    var metadata: = {}
    if tex['type'] == 'local_file':
        texture_name = tex['image_name']
        texture = FilesManager.load_shared_image_as_texture(tex['image_name'])
        if texture:
            metadata = fix_vecs_texture_meta(FilesManager.get_local_image_metadata(tex['image_name']))
        else:
            push_warning("Failed to load shared image: " + tex['image_name'])
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
    

func get_new_texture_index() -> int:
    var index = 0
    for ti in textures:
        index = max(index, ti+1)
    return index

func get_texture_name(texture_index: int) -> String:
    return texture_names[texture_index]

func get_texture_name_list() -> Array:
    var tlist = []
    for i in textures:
        tlist.append(get_texture_name(i))
    
    return tlist

func get_all_indexes() -> Array:
    return textures.keys()

func get_texture(texture_index: int) -> Texture:
    if not texture_index in textures:
        return placeholder
    return textures[texture_index]

func get_index_offset(texture_index: int, tile_index: int) -> Vector2:
    var tpr: int = tiles_per_row[texture_index]
    var tsize = tile_sizes[texture_index]
    return Vector2(tile_index % tpr * tsize.x, floor(tile_index/float(tpr)) * tsize.y)

func get_tiles_per_row(texture_index: int) -> int:
    return tiles_per_row[texture_index]

func get_texture_metadata(texture_index: int) -> Dictionary:
    return texture_meta[texture_index]

func get_index_rect(texture_index: int, tile_index: int) -> Rect2:
    return Rect2(get_index_offset(texture_index, tile_index), tile_sizes[texture_index])

func get_texture_tile_size(texture_index: int) -> Vector2i:
    return tile_sizes[texture_index]

func get_index_atlas_coords(texture_index: int, tile_index: int) -> Vector2i:
    var tpr: int = tiles_per_row[texture_index]
    return Vector2i(tile_index % tpr, floor(tile_index/float(tpr)))

func get_last_sub_index(texture_index: int) -> int:
    var tpr: int = tiles_per_row[texture_index]
    var rows: int = texture_rows[texture_index]
    return (rows * tpr) - 1
