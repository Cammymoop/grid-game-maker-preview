extends Node

var named_sfx: Dictionary[String, Dictionary] = {}

var do_clean_after_refresh: bool = true

var ps_sfx_default_volume_linear: float = 1.0

var num_stream_players: int = 20
var stream_players: Array[AudioStreamPlayer] = []

var _next_force: int = 0

func _ready() -> void:
    for i in range(num_stream_players):
        var stream_player: = AudioStreamPlayer.new()
        stream_player.bus = "PSSfxBus"
        stream_player.volume_db = linear_to_db(ps_sfx_default_volume_linear)
        stream_players.append(stream_player)
        add_child(stream_player)

func refresh_game_sfx() -> void:
    for stream_player in stream_players:
        stream_player.set_meta("sfx_name", "")
    named_sfx.clear()
    var sfx_definitions: Array = GameManager.get_sfx_definitions().duplicate_deep()
    
    var all_used_seeds: Array = []
    for sfx_definition in sfx_definitions:
        if not sfx_definition:
            continue
        named_sfx[sfx_definition['name']] = sfx_definition
        if sfx_definition['type'] == 'ps_sfx':
            sfx_definition['ps_seed'] = int(sfx_definition['ps_seed'])
            all_used_seeds.append(sfx_definition['ps_seed'])
            # Pre-generate into the cache
            PuzzleScriptSFXR.get_sfx_stream(sfx_definition['ps_seed'])
    
    if do_clean_after_refresh:
        PuzzleScriptSFXR.clean_cache(all_used_seeds)

func _get_named_sfx_stream(sfx_name: String) -> AudioStream:
    var sfx_definition: Dictionary = named_sfx[sfx_name]
    if sfx_definition["type"] == "ps_sfx":
        return PuzzleScriptSFXR.get_sfx_stream(sfx_definition['ps_seed'])
    else:
        push_warning("Unknown sfx type: %s" % sfx_definition["type"])
        return null

func _is_playing_sfx(sfx_name: String) -> bool:
    for stream_player in stream_players:
        if stream_player.get_meta("sfx_name") == sfx_name and stream_player.playing:
            return true
    return false

func _get_free_stream_player() -> AudioStreamPlayer:
    for stream_player in stream_players:
        if not stream_player.playing:
            return stream_player
    return null

func _get_player_of_sfx(sfx_name: String) -> AudioStreamPlayer:
    for stream_player in stream_players:
        if stream_player.get_meta("sfx_name") == sfx_name:
            return stream_player
    return null

func play_named_sfx(sfx_name: String, do_restart: bool = true, force_play: bool = false) -> void:
    if _is_playing_sfx(sfx_name):
        if do_restart:
            restart_named_sfx(sfx_name)
        else:
            return
    var stream_player: AudioStreamPlayer = _get_free_stream_player()
    if not stream_player and not force_play:
        return
    elif not stream_player:
        stream_player = stream_players[_next_force]
        _next_force = posmod(_next_force + 1, num_stream_players)
        stream_player.stop()
    _play_named_on_player(sfx_name, stream_player)

func _play_named_on_player(sfx_name: String, player: AudioStreamPlayer) -> void:
    if not player.get_meta("sfx_name") == sfx_name:
        player.stream = _get_named_sfx_stream(sfx_name)
        player.set_meta("sfx_name", sfx_name)
    if not player.playing:
        player.play()
    else:
        push_warning("Trying to play sfx on a player without stopping it first")

func restart_named_sfx(sfx_name: String) -> void:
    var player: AudioStreamPlayer = _get_player_of_sfx(sfx_name)
    if not player:
        player = _get_free_stream_player()
    if not player:
        return
    player.stop()
    _play_named_on_player(sfx_name, player)

func keep_named_sfx_playing(sfx_name: String, force_play: bool = false) -> void:
    if _is_playing_sfx(sfx_name):
        return
    else:
        play_named_sfx(sfx_name, force_play)
