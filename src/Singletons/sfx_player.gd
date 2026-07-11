extends Node

var named_sfx: Dictionary[String, Dictionary] = {}

var do_clean_after_refresh: bool = true

var ps_sfx_default_volume_linear: float = 1.0

var num_stream_players: int = 20
var stream_players: Array[AudioStreamPlayer] = []
var looping_players: Array[bool] = []
var cutoff_timers: Array[Timer] = []
var current_playing_sfx: Array[String] = []
var priorities: Array[float] = []

#var _next_force: int = 0

var default_looping_cutoff_time: float = 2.0

var default_restart_secs: float = 0.05

const WEB_PS_SFX_COMPENSATION: = 0.7
var ps_sfx_volume_compensation: float = 1.0


const BUILTIN_SAMPLE_STREAMS: Dictionary[String, AudioStreamWAV] = {
	"abscond": preload("res://assets/sound/wav_sfx/abscond_fast.wav"),
	"attention": preload("res://assets/sound/wav_sfx/attention.wav"),
	"boom": preload("res://assets/sound/wav_sfx/boom.wav"),
	"burn": preload("res://assets/sound/wav_sfx/burn.wav"),
	"cymbol": preload("res://assets/sound/wav_sfx/cymbol.wav"),
	"drip": preload("res://assets/sound/wav_sfx/drip.wav"),
	"drum": preload("res://assets/sound/wav_sfx/drum.wav"),
	"er": preload("res://assets/sound/wav_sfx/er.wav"),
	"fall": preload("res://assets/sound/wav_sfx/fall.wav"),
	"fanfare": preload("res://assets/sound/wav_sfx/fanfare.wav"),
	"knock": preload("res://assets/sound/wav_sfx/knock.wav"),
	"mystery": preload("res://assets/sound/wav_sfx/mystery.wav"),
	"oof": preload("res://assets/sound/wav_sfx/oof.wav"),
	"ouch": preload("res://assets/sound/wav_sfx/ouch.wav"),
	"pipes": preload("res://assets/sound/wav_sfx/pipes.wav"),
    "pop": preload("res://assets/sound/wav_sfx/pop.wav"),
	"scoot": preload("res://assets/sound/wav_sfx/scoot.wav"),
	"slide": preload("res://assets/sound/wav_sfx/slide.wav"),
	"spinout": preload("res://assets/sound/wav_sfx/spinout.wav"),
	"splash": preload("res://assets/sound/wav_sfx/splash.wav"),
	"squeak": preload("res://assets/sound/wav_sfx/squeak.wav"),
	"switch": preload("res://assets/sound/wav_sfx/switch.wav"),
	"tada": preload("res://assets/sound/wav_sfx/tada.wav"),
	"undo": preload("res://assets/sound/wav_sfx/undo.wav"),
}

var modified_streams: Dictionary[String, AudioStreamWAV] = {}

class SfxPlayOptions:
    var sfx_name: String
    var relative_volume: float = 1.0
    var relative_pitch: float = 1.0
    var priority: float = 10.0
    var self_polyphony: String = ""
    var min_duration: float = 0.0
    var custom_restart_threshold: float = -1.0

func get_sample_name_list() -> Array[String]:
    var sample_name_list: Array[String] = []
    sample_name_list.assign(BUILTIN_SAMPLE_STREAMS.keys())
    return sample_name_list

func get_sample_stream(sample_name: String) -> AudioStreamWAV:
    if not BUILTIN_SAMPLE_STREAMS.has(sample_name):
        push_error("unknown sample name: %s" % sample_name)
        return null
    return BUILTIN_SAMPLE_STREAMS[sample_name]

func _ready() -> void:
    if OS.has_feature("web"):
        ps_sfx_volume_compensation = WEB_PS_SFX_COMPENSATION
    priorities.resize(num_stream_players)
    looping_players.resize(num_stream_players)
    looping_players.fill(false)
    current_playing_sfx.resize(num_stream_players)
    for i in num_stream_players:
        var stream_player: = AudioStreamPlayer.new()
        stream_player.set_meta("player_idx", i)
        stream_player.bus = "SfxBus"
        stream_player.volume_db = linear_to_db(ps_sfx_default_volume_linear)
        stream_players.append(stream_player)
        add_child(stream_player)
        var cutoff_timer: = Timer.new()
        cutoff_timers.append(cutoff_timer)
        cutoff_timer.one_shot = true
        cutoff_timer.timeout.connect(on_cutoff_timer_timeout.bind(i))
        add_child(cutoff_timer)

func _process(_delta: float) -> void:
    for i in num_stream_players:
        if priorities[i] < 0:
            continue
        if not stream_players[i].playing:
            priorities[i] = -1
            current_playing_sfx[i] = ""

func refresh_game_sfx() -> void:
    for stream_player in stream_players:
        stream_player.set_meta("sfx_name", "")
    modified_streams.clear()
    named_sfx.clear()
    var sfx_definitions: Array = GameManager.get_sfx_definitions().duplicate_deep()
    
    var all_used_seeds: Array = []
    var ps_sfx_streams: Array[AudioStreamWAV] = []
    for sfx_definition in sfx_definitions:
        if not sfx_definition:
            continue
        named_sfx[sfx_definition['name']] = sfx_definition
        if sfx_definition['type'] == 'ps_sfx':
            sfx_definition['ps_seed'] = int(sfx_definition['ps_seed'])
            all_used_seeds.append(sfx_definition['ps_seed'])
            # Pre-generate into the cache, also keep for registering as a sample on web
            ps_sfx_streams.append(PuzzleScriptSFXR.get_sfx_stream(sfx_definition['ps_seed']))
            sfx_definition['loops'] = false
            sfx_definition['restart_threshold'] = default_restart_secs
        elif sfx_definition['type'] == "sample":
            if not BUILTIN_SAMPLE_STREAMS.has(sfx_definition['sample_name']):
                push_error("unknown sample name: %s" % sfx_definition['sample_name'])
                named_sfx.erase(sfx_definition['name'])
                continue
            var wav_stream: = BUILTIN_SAMPLE_STREAMS[sfx_definition['sample_name']].duplicate()
            sfx_definition['sample_stream'] = wav_stream
            modified_streams[sfx_definition['sample_name']] = wav_stream
            var loops: bool = false
            if sfx_definition.has('loop'):
                loops = true
                if sfx_definition['loop'] == "pingpong":
                    wav_stream.loop_mode = AudioStreamWAV.LOOP_PINGPONG
                else:
                    wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
            var loop_duration: float = wav_stream.get_length()
            if sfx_definition.has('loop_start') or sfx_definition.has('loop_end'):
                var total_samples: int = Utility.get_wav_stream_total_samples(wav_stream)
                var start_amt: float = clampf(sfx_definition.get('loop_start', 0.0), 0.0, 1.0)
                var end_amt: float = clampf(sfx_definition.get('loop_end', 1.0), 0.0, 1.0)
                wav_stream.loop_begin = roundi(start_amt * total_samples)
                wav_stream.loop_end = roundi(end_amt * total_samples)
                loop_duration *= end_amt - start_amt

            sfx_definition['loops'] = loops
            if loops:
                if sfx_definition.has('default_loops'):
                    sfx_definition['default_duration'] = loop_duration * sfx_definition.get('default_loops')
                else:
                    sfx_definition['default_duration'] = default_looping_cutoff_time
            else:
                sfx_definition['default_duration'] = wav_stream.get_length()
            
            if sfx_definition.get('restart_threshold', -1.0) < 0:
                sfx_definition['restart_threshold'] = default_restart_secs
    
    if OS.has_feature("web"):
        for ps_sfx_stream in ps_sfx_streams:
            if not AudioServer.is_stream_registered_as_sample(ps_sfx_stream):
                AudioServer.register_stream_as_sample(ps_sfx_stream)
        for modified_stream in modified_streams.values():
            if not AudioServer.is_stream_registered_as_sample(modified_stream):
                AudioServer.register_stream_as_sample(modified_stream)

    
    if do_clean_after_refresh:
        PuzzleScriptSFXR.clean_cache(all_used_seeds)

func on_cutoff_timer_timeout(player_idx: int) -> void:
    var player: = stream_players[player_idx]
    if player.playing:
        player.stop()

func _set_cutoff_time(player_idx: int, cutoff_time: float) -> void:
    var cutoff_timer: = cutoff_timers[player_idx]
    if cutoff_time <= 0:
        cutoff_timer.stop()
    else:
        cutoff_timer.start(cutoff_time)

func _set_min_cutoff_time(player_idx: int, min_cutoff_time: float) -> void:
    if min_cutoff_time <= 0:
        return
    var cutoff_timer: = cutoff_timers[player_idx]
    if not cutoff_timer.is_stopped():
        _set_cutoff_time(player_idx, maxf(cutoff_timer.time_left, min_cutoff_time))

func _get_named_sfx_stream(sfx_name: String) -> AudioStream:
    var sfx_definition: Dictionary = named_sfx[sfx_name]
    if sfx_definition["type"] == "ps_sfx":
        return PuzzleScriptSFXR.get_sfx_stream(sfx_definition['ps_seed'])
    elif sfx_definition["type"] == "sample":
        return sfx_definition["sample_stream"]
    else:
        push_warning("Unknown sfx type: %s" % sfx_definition["type"])
        return null

func _check_playing_threshold(player_idx: int, threshold: float, stopped_result: bool = true) -> bool:
    if not stream_players[player_idx].playing:
        return stopped_result
    var player: = stream_players[player_idx]
    if looping_players[player_idx] and player.get_stream_playback().get_loop_count() > 0:
        return true
    
    # Note: intentionally using raw uninterpolated time reported by get_playback_position(), this is the point that playback will be at
    #   when the next mix will occur (it's the end of the last mixed interval), so it is also exactly the relevant time for when actions
    #   such as stopping or restarting the sfx will happen
    var threshold_seconds: float = threshold * stream_players[player_idx].get_stream().get_length()
    return player.get_playback_position() >= threshold_seconds

func _set_stream_player_to_named_sfx(player_idx: int, sfx_name: String) -> void:
    stream_players[player_idx].stream = _get_named_sfx_stream(sfx_name)
    current_playing_sfx[player_idx] = sfx_name
    looping_players[player_idx] = named_sfx[sfx_name].get('loops', false)
    var target_bus: = "SfxBus"
    if named_sfx[sfx_name].get("type", "ps_sfx") == "ps_sfx":
        target_bus = "LowPassSfx"
    stream_players[player_idx].bus = target_bus


func _is_playing_sfx(sfx_name: String) -> bool:
    for i in num_stream_players:
        if current_playing_sfx[i] == sfx_name:
            return true
    return false

func _get_player_of_named_sfx(sfx_name: String) -> int:
    for i in num_stream_players:
        if current_playing_sfx[i] == sfx_name:
            return i
    return -1

func _find_free_player() -> int:
    for i in num_stream_players:
        if priorities[i] < 0:
            return i
    return -1

func _find_player_for_priority(priority: float) -> int:
    var free_player: int = _find_free_player()
    if free_player != -1:
        return free_player
    for i in num_stream_players:
        if priorities[i] < priority:
            return i
    return -1

func _find_player_for_options(options: SfxPlayOptions) -> int:
    var polyphony: String = options.self_polyphony
    if not polyphony or polyphony == "ignore":
        return _find_player_for_priority(options.priority)
    else:
        var idx: int = _get_player_of_named_sfx(options.sfx_name)
        if polyphony in ["restart", "keep_playing"]:
            if idx != -1:
                return idx
            return _find_player_for_priority(options.priority)
        elif polyphony == "one" and idx == -1:
            return _find_player_for_priority(options.priority)
    return -1

func _play_sfx_options_on_player(player_idx: int, options: SfxPlayOptions) -> void:
    if not options.sfx_name:
        return
    _set_stream_player_to_named_sfx(player_idx, options.sfx_name)
    var is_playing: bool = stream_players[player_idx].playing
    var is_looping: bool = looping_players[player_idx]
    var sfx_info: Dictionary = named_sfx[options.sfx_name]
    var player: = stream_players[player_idx]

    player.volume_linear = sfx_info.get("volume", 1.0) * options.relative_volume
    if sfx_info.get("type", "ps_sfx") == "ps_sfx":
        player.volume_linear *= ps_sfx_volume_compensation
    player.pitch_scale = sfx_info.get("pitch", 1.0) * options.relative_pitch
    priorities[player_idx] = options.priority

    var duration: float = 0
    if is_looping:
        duration = options.min_duration
        if duration <= 0:
            duration = sfx_info['default_duration']

    if options.self_polyphony == "keep_playing":
        if not is_playing:
            player.play()
            _set_cutoff_time(player_idx, duration)
        else:
            _set_min_cutoff_time(player_idx, duration)
    elif is_playing:
        if options.self_polyphony == "restart":
            var restart_threshold: float = options.custom_restart_threshold
            if restart_threshold < 0:
                restart_threshold = sfx_info['restart_threshold']
            if _check_playing_threshold(player_idx, restart_threshold):
                player.play()
                _set_cutoff_time(player_idx, duration)
    else:
        player.play()
        _set_cutoff_time(player_idx, duration)

func play_sfx_options(options: SfxPlayOptions) -> void:
    var player_idx: int = _find_player_for_options(options)
    if player_idx == -1:
        return
    _play_sfx_options_on_player(player_idx, options)

func playback_options(sfx_name: String, polyphony_mode: String = "restart", min_duration: float = 0, volume: float = 1, pitch: float = 1) -> SfxPlayOptions:
    var op: = SfxPlayOptions.new()
    op.sfx_name = sfx_name
    op.self_polyphony = polyphony_mode
    op.min_duration = min_duration
    op.relative_volume = volume
    op.relative_pitch = pitch
    return op














#func play_named_sfx(sfx_name: String, do_restart: bool = true, force_play: bool = false) -> void:
#    if _is_playing_sfx(sfx_name):
#        if do_restart:
#            restart_named_sfx(sfx_name)
#        else:
#            return
#    var stream_player: AudioStreamPlayer = _get_free_stream_player()
#    if not stream_player and not force_play:
#        return
#    elif not stream_player:
#        stream_player = stream_players[_next_force]
#        _next_force = posmod(_next_force + 1, num_stream_players)
#        stream_player.stop()
#    _play_named_on_player(sfx_name, stream_player)
#
#func _play_named_on_player(sfx_name: String, player: AudioStreamPlayer) -> void:
#    if not player.get_meta("sfx_name") == sfx_name:
#        player.stream = _get_named_sfx_stream(sfx_name)
#        player.set_meta("sfx_name", sfx_name)
#    if not player.playing:
#        player.play()
#    else:
#        push_warning("Trying to play sfx on a player without stopping it first")
#
#func restart_named_sfx(sfx_name: String) -> void:
#    var player: AudioStreamPlayer = _get_player_of_sfx(sfx_name)
#    if not player:
#        player = _get_free_stream_player()
#    if not player:
#        return
#    player.stop()
#    _play_named_on_player(sfx_name, player)
#
#func keep_named_sfx_playing(sfx_name: String, force_play: bool = false) -> void:
#    if _is_playing_sfx(sfx_name):
#        return
#    else:
#        play_named_sfx(sfx_name, force_play)
#
