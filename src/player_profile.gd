class_name PlayerProfile
extends RefCounted

const FORMAT_VERSION: = "1"

var player_id: String = ""

var player_settings: Dictionary = {}

var game_saves: Dictionary = {}

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


func write_settings() -> void:
    var serialized_data: Dictionary = serialize_settings()
    FilesManager.save_profile_settings(player_id, serialized_data)


func ensure_game_save_exists(game_name: String) -> void:
    if game_name in game_saves:
        return
    game_saves[game_name] = {
        "what_is_this": "GGM game save file",
        "format_version": FORMAT_VERSION,
        "game_name": game_name,
    }
    write_game_save(game_name)


func get_game_save_data(for_game_name: String, data_key: String, default_value: Variant = null) -> Variant:
    if not for_game_name or not game_saves.has(for_game_name):
        return default_value
    return game_saves[for_game_name].get(data_key, default_value)

func set_game_save_data(for_game_name: String, data_key: String, value: Variant, flush: bool = true) -> void:
    if not for_game_name or not game_saves.has(for_game_name):
        ensure_game_save_exists(for_game_name)
    game_saves[for_game_name][data_key] = value
    if flush:
        write_game_save(for_game_name)

func write_current_game_save() -> void:
    var current_game: String = GameManager.get_game_name()
    write_game_save(current_game)

func write_game_save(game_name: String) -> void:
    if not game_name or not game_saves.has(game_name):
        return
    var serialized_data: Dictionary = JSON.from_native(game_saves[game_name])
    FilesManager.save_game_save_for_player(player_id, game_name, serialized_data)