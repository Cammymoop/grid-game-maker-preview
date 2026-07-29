class_name PlayerProfile
extends RefCounted

const FORMAT_VERSION: = "1"

var player_id: String = ""

var player_settings: Dictionary = {}

var game_saves: Dictionary = {}

const GAME_SAVE_DEFAULT_KEYS: = ["what_is_this", "format_version", "game_name"]

func serialize_settings() -> Dictionary:
    return JSON.from_native(player_settings)

static func deserialize_settings(data: Dictionary) -> Dictionary:
    return JSON.to_native(data)

static func get_profile_for_serialized_settings(new_player_id: String, data: Dictionary) -> PlayerProfile:
    var new_profile: = PlayerProfile.new()
    new_profile.player_id = new_player_id
    new_profile.player_settings = deserialize_settings(data)
    return new_profile

func add_game_save(game_save_data: Dictionary) -> void:
    var deserizlized_game_save_data: Dictionary = JSON.to_native(game_save_data)
    var the_game_name: String = deserizlized_game_save_data.get("game_name", "")
    if not the_game_name:
        push_warning("Game save data does not contain a game name")
        return
    game_saves[the_game_name] = deserizlized_game_save_data


# Get top-level profile settings data by key
func get_profile_setting(key: String, defualt_value: Variant) -> Variant:
    return player_settings.get(key, defualt_value)

# Get a profile setting value, the default value in case of not finding the setting is first for this version because it takes variable arguments for nested keys
func get_nested_profile_setting(defualt_value: Variant, ...keys: Array) -> Variant:
    return get_profile_setting_v(keys, defualt_value)

# Get a shallow or nested profile setting value by passing an array of nested keys
func get_profile_setting_v(keys: Array, default_value: Variant) -> Variant:
    if not keys:
        return default_value
    return _get_recursive(player_settings, keys, 0, default_value)

# set top-level profile settings data by key
func set_profile_setting(key: String, value: Variant, flush: bool = true) -> void:
    player_settings[key] = value
    if flush:
        write_settings()

func set_nested_profile_setting(value: Variant, ...keys: Array) -> void:
    set_profile_setting_v(keys, value, true)

func set_profile_setting_v(keys: Array, value: Variant, flush: bool = true) -> void:
    if not keys:
        return
    if keys.size() == 1:
        set_profile_setting(keys[0], value, flush)
    else:
        _set_nested(player_settings, keys, value)
        if flush:
            write_settings()


func write_settings() -> void:
    var serialized_data: Dictionary = serialize_settings()
    FilesManager.save_profile_settings(player_id, serialized_data)


func erase_game_save_progress(game_name: String) -> void:
    _make_new_game_save(game_name)
    write_game_save(game_name)

func ensure_game_save_exists(game_name: String) -> void:
    if game_name in game_saves:
        return
    _make_new_game_save(game_name)

func _make_new_game_save(game_name: String) -> void:
    game_saves[game_name] = {
        "what_is_this": "GGM game save file",
        "format_version": FORMAT_VERSION,
        "game_name": game_name,
    }
    write_game_save(game_name)

func is_empty_game_save(game_name: String) -> bool:
    if not game_name or not game_saves.has(game_name):
        return true
    if game_saves[game_name].size() > GAME_SAVE_DEFAULT_KEYS.size():
        return false
    return true


func get_game_save_data(for_game_name: String, data_key: String, default_value: Variant = null) -> Variant:
    if not for_game_name or not game_saves.has(for_game_name):
        return default_value
    return game_saves[for_game_name].get(data_key, default_value)

func get_game_save_data_root(for_game_name: String) -> Dictionary:
    if not for_game_name or not game_saves.has(for_game_name):
        return {}
    return game_saves[for_game_name]

func set_game_save_data(for_game_name: String, data_key: String, value: Variant, flush: bool = true) -> void:
    if data_key in GAME_SAVE_DEFAULT_KEYS:
        return

    if not for_game_name or not game_saves.has(for_game_name):
        ensure_game_save_exists(for_game_name)
    game_saves[for_game_name][data_key] = value
    if flush:
        write_game_save(for_game_name)

func has_game_save_data(for_game_name: String, data_key: String) -> bool:
    if not for_game_name or not game_saves.has(for_game_name):
        return false
    return data_key in game_saves[for_game_name]

func write_current_game_save() -> void:
    var current_game: String = GameManager.get_identified_game_name()
    write_game_save(current_game)

func write_game_save(game_name: String) -> void:
    if not game_name or not game_saves.has(game_name):
        return
    var serialized_data: Dictionary = JSON.from_native(game_saves[game_name])
    FilesManager.save_game_save_for_player(player_id, game_name, serialized_data)



func _arr_key(arr_key: Variant) -> int:
    if typeof(arr_key) == TYPE_INT:
        return arr_key
    elif typeof(arr_key == TYPE_FLOAT):
        return int(arr_key)
    elif typeof(arr_key) == TYPE_STRING and arr_key.is_valid_int():
        return int(arr_key)
    else:
        return -1

func _get_recursive(data: Variant, keys: Array, key_index: int, def: Variant) -> Variant:
    var next_data: Variant = null
    if typeof(data) == TYPE_ARRAY:
        var arr_key: int = _arr_key(keys[key_index])
        if arr_key < 0 or arr_key >= data.size():
            return def
        else:
            if key_index == keys.size() - 1:
                return data[arr_key]
            next_data = data[arr_key]
    elif typeof(data) in [TYPE_OBJECT, TYPE_DICTIONARY]:
        if not keys[key_index] in data:
            return def
        else:
            if key_index == keys.size() - 1:
                return data.get(keys[key_index])
            next_data = data.get(keys[key_index])
    else:
        push_error("Unexpected type: %s" % [type_string(typeof(data))])
        return def
    if next_data == null:
        return def
    return _get_recursive(next_data, keys, key_index + 1, def)

func _get_ensure_level(data: Variant, keys: Array, key_index: int) -> Variant:
    var next_data: Variant = null
    var final_key: bool = key_index == keys.size() - 1
    if typeof(data) == TYPE_ARRAY:
        var arr_key: int = _arr_key(keys[key_index])
        if arr_key < 0 or arr_key >= data.size():
            # does not ensure array size
            return null
        else:
            if final_key:
                return data[arr_key]
            next_data = data[arr_key]
    elif typeof(data) in [TYPE_OBJECT, TYPE_DICTIONARY]:
        if not keys[key_index] in data or data[keys[key_index]] == null:
            data[keys[key_index]] = {}
            next_data = data[keys[key_index]]
            if final_key:
                return next_data
        else:
            if final_key:
                return data.get(keys[key_index])
            next_data = data.get(keys[key_index])
    else:
        push_error("Unexpected type: %s" % [type_string(typeof(data))])
        return null
    if next_data == null:
        return null
    return _get_ensure_level(next_data, keys, key_index + 1)

func _set_nested(data: Variant, keys: Array, new_value: Variant) -> void:
    if not keys or keys.size() < 2:
        push_error("_set_nested called with less than 2 nested keys")
        return
    var set_key: Variant = keys[-1]
    var containing_data: Variant = _get_ensure_level(data, keys.slice(0, -1), 0)
    if containing_data == null:
        push_error("Could not set nested keys: %s, incompatible existing structure" % [keys])
        return

    if typeof(containing_data) == TYPE_DICTIONARY:
        containing_data[set_key] = new_value
    elif typeof(containing_data) == TYPE_ARRAY:
        var arr_key: int = _arr_key(set_key)
        if arr_key == containing_data.size() or arr_key == -1:
            containing_data.append(new_value)
        elif arr_key == -2:
            containing_data.push_front(new_value)
        elif arr_key >= 0 and arr_key < containing_data.size():
            containing_data[arr_key] = new_value
        else:
            push_error("Array index out of bounds: %s (%s)" % [arr_key, containing_data.size()])
            return
    elif typeof(containing_data) == TYPE_OBJECT and containing_data != null:
        if set_key not in containing_data:
            push_error("Set key %s not found in containing object %s" % [set_key, containing_data])
            return
        containing_data.set(set_key, new_value)
    else:
        push_error("Unexpected type: %s" % [type_string(typeof(containing_data))])
