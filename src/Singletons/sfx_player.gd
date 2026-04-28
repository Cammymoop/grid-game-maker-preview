extends Node

var named_sfx: Dictionary[String, Dictionary] = {}

var do_clean_after_refresh: bool = true

var ps_sfx_default_volume_linear: float = 1.0

var stream_player: AudioStreamPlayer = null

func _ready() -> void:
    stream_player = AudioStreamPlayer.new()
    stream_player.bus = "PSSfxBus"
    stream_player.volume_db = linear_to_db(ps_sfx_default_volume_linear)
    add_child(stream_player)

func refresh_game_sfx() -> void:
    named_sfx.clear()
    var sfx_definitions: Array = GameManager.get_sfx_definitions()
    
    var all_used_seeds: Array = []
    for sfx_definition in sfx_definitions:
        if not sfx_definition:
            continue
        named_sfx[sfx_definition['name']] = sfx_definition
        if sfx_definition['type'] == 'ps_sfx':
            all_used_seeds.append(int(sfx_definition['ps_seed']))
            # Pre-generate into the cache
            PuzzleScriptSFXR.get_sfx_stream(int(sfx_definition['ps_seed']))
    
    if do_clean_after_refresh:
        PuzzleScriptSFXR.clean_cache(all_used_seeds)
