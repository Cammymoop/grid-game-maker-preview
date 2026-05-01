class_name PuzzleScriptSFXR
extends RefCounted

const Params = PuzzleScriptSFXRAudioStream.Params
const WaveType = PuzzleScriptSFXRAudioStream.WaveType

enum GeneratorType {
	pickupCoin = 0,
	laserShoot,
	explosion,
	powerUp,
	hitHurt,
	jump,
	blipSelect,
	pushSound,
	random,
	birdSound
}

class PSSfx:
	var seed_number: int
	var audio_stream: AudioStreamWAV
	
var _rng: PuzzleScriptRNG
var _seed: String = ""

static var sfx_cache: Dictionary[int, PSSfx] = {}

static func clean_cache(keep_seeds: Array) -> void:
	var keep_int_seeds: Array[int] = []
	keep_int_seeds.append_array(keep_seeds.map(func(x): return int(x)))
	var new_cache: Dictionary[int, PSSfx] = {}
	for cached_seed in sfx_cache.keys():
		if keep_int_seeds.has(cached_seed):
			new_cache[cached_seed] = sfx_cache[cached_seed]
	sfx_cache = new_cache


func make_seeded_rng(seed: String) -> void:
	_seed = seed
	_rng = PuzzleScriptRNG.new(_seed)

func frnd(range: float) -> float:
	return _rng.uniform() * range

func rnd(max: int) -> int:
	return floori(_rng.uniform() * (max + 1))



static func get_random_int_seed() -> int:
	return randi_range(0, 1000000)

static func rerandomize_seed(seed: int) -> int:
	var lower_part: int = seed % 100
	var new_seed: = get_random_int_seed() / 100
	return new_seed * 100 + lower_part

static func generate_random_sfx(generator_type: GeneratorType) -> PSSfx:
	return get_seeded_sfx(get_random_int_seed())

static func get_random_sfx_stream(generator_type: GeneratorType) -> AudioStreamWAV:
	return generate_random_sfx(generator_type).audio_stream

static func get_sfx_stream(puzzlescript_seed: int) -> AudioStreamWAV:
	return get_seeded_sfx(puzzlescript_seed).audio_stream

static func get_seeded_sfx(puzzlescript_seed: int) -> PSSfx:
	if sfx_cache.has(puzzlescript_seed):
		return sfx_cache[puzzlescript_seed]

	var rng_seed: String = str(int(puzzlescript_seed / 100.0))
	var generator_type: int = posmod(puzzlescript_seed % 100, len(GeneratorType))
	
	var sfx_generator: = PuzzleScriptSFXR.new()
	sfx_generator.make_seeded_rng(rng_seed)
	var generator_func: = Callable(sfx_generator, "gen_" + GeneratorType.keys()[generator_type])
	if not generator_func.is_valid():
		push_error("Function for generator type %s not found" % [GeneratorType.keys()[generator_type]])
		return null
	
	var sfx_params: = generator_func.call()
	var sfx: = PSSfx.new()
	sfx.seed_number = puzzlescript_seed
	sfx.audio_stream = PuzzleScriptSFXRAudioStream.generate_stream(sfx_params)
	sfx_cache[puzzlescript_seed] = sfx
	return sfx

func gen_pickupCoin() -> Params:
	var params: = Params.new()
	params.wave_type = floori(frnd(WaveType.size()))
	if params.wave_type == WaveType.NOISE:
		params.wave_type = WaveType.SQUARE
	params.p_base_freq = 0.4 + frnd(0.5)
	params.p_env_attack = 0.0
	params.p_env_sustain = frnd(0.1)
	params.p_env_decay = 0.1 + frnd(0.4)
	params.p_env_punch = 0.3 + frnd(0.3)
	if rnd(1):
		params.p_arp_speed = 0.5 + frnd(0.2)
		var num: = (int(frnd(7)) | 1) + 1
		var den: = num + (int(frnd(7)) | 1) + 2
		params.p_arp_mod = float(num) / float(den)
	return params

func gen_laserShoot() -> Params:
	var params := Params.new()
	params.wave_type = rnd(2)
	if params.wave_type == WaveType.SINE and rnd(1):
		params.wave_type = rnd(1)
	params.wave_type = floori(frnd(WaveType.size()))

	if params.wave_type == WaveType.NOISE:
		params.wave_type = WaveType.SQUARE

	params.p_base_freq = 0.5 + frnd(0.5)
	params.p_freq_limit = params.p_base_freq - 0.2 - frnd(0.6)
	if params.p_freq_limit < 0.2:
		params.p_freq_limit = 0.2
	params.p_freq_ramp = -0.15 - frnd(0.2)

	if rnd(2) == 0:
		params.p_base_freq = 0.3 + frnd(0.6)
		params.p_freq_limit = frnd(0.1)
		params.p_freq_ramp = -0.35 - frnd(0.3)

	if rnd(1):
		params.p_duty = frnd(0.5)
		params.p_duty_ramp = frnd(0.2)
	else:
		params.p_duty = 0.4 + frnd(0.5)
		params.p_duty_ramp = -frnd(0.7)

	params.p_env_attack = 0.0
	params.p_env_sustain = 0.1 + frnd(0.2)
	params.p_env_decay = frnd(0.4)

	if rnd(1):
		params.p_env_punch = frnd(0.3)

	if rnd(2) == 0:
		params.p_pha_offset = frnd(0.2)
		params.p_pha_ramp = -frnd(0.2)

	if rnd(1):
		params.p_hpf_freq = frnd(0.3)

	return params


func gen_explosion() -> Params:
	var params := Params.new()

	if rnd(1):
		params.p_base_freq = 0.1 + frnd(0.4)
		params.p_freq_ramp = -0.1 + frnd(0.4)
	else:
		params.p_base_freq = 0.2 + frnd(0.7)
		params.p_freq_ramp = -0.2 - frnd(0.2)

	params.p_base_freq *= params.p_base_freq

	if rnd(4) == 0:
		params.p_freq_ramp = 0.0

	if rnd(2) == 0:
		params.p_repeat_speed = 0.3 + frnd(0.5)

	params.p_env_attack = 0.0
	params.p_env_sustain = 0.1 + frnd(0.3)
	params.p_env_decay = frnd(0.5)

	if rnd(1) == 0:
		params.p_pha_offset = -0.3 + frnd(0.9)
		params.p_pha_ramp = -frnd(0.3)

	params.p_env_punch = 0.2 + frnd(0.6)

	if rnd(1):
		params.p_vib_strength = frnd(0.7)
		params.p_vib_speed = frnd(0.6)

	if rnd(2) == 0:
		params.p_arp_speed = 0.6 + frnd(0.3)
		params.p_arp_mod = 0.8 - frnd(1.6)

	return params


func gen_birdSound() -> Params:
	var params := Params.new()

	if frnd(10) < 1:
		params.wave_type = floori(frnd(WaveType.size()))
		if params.wave_type == WaveType.NOISE:
			params.wave_type = WaveType.SQUARE

		params.p_env_attack = 0.4304400932967592 + frnd(0.2) - 0.1
		params.p_env_sustain = 0.15739346034252394 + frnd(0.2) - 0.1
		params.p_env_punch = 0.004488201744871758 + frnd(0.2) - 0.1
		params.p_env_decay = 0.07478075528212291 + frnd(0.2) - 0.1
		params.p_base_freq = 0.9865265720147687 + frnd(0.2) - 0.1
		params.p_freq_limit = 0 + frnd(0.2) - 0.1
		params.p_freq_ramp = -0.2995018224359539 + frnd(0.2) - 0.1

		if frnd(1.0) < 0.5:
			params.p_freq_ramp = 0.1 + frnd(0.15)

		params.p_freq_dramp = 0.004598608156964473 + frnd(0.1) - 0.05
		params.p_vib_strength = -0.2202799497929496 + frnd(0.2) - 0.1
		params.p_vib_speed = 0.8084998703158364 + frnd(0.2) - 0.1
		params.p_arp_mod = 0
		params.p_arp_speed = 0
		params.p_duty = -0.9031808754347107 + frnd(0.2) - 0.1
		params.p_duty_ramp = -0.8128699999808343 + frnd(0.2) - 0.1
		params.p_repeat_speed = 0.6014860189319991 + frnd(0.2) - 0.1
		params.p_pha_offset = -0.9424902314367765 + frnd(0.2) - 0.1
		params.p_pha_ramp = -0.1055482222272056 + frnd(0.2) - 0.1
		params.p_lpf_freq = 0.9989765717851521 + frnd(0.2) - 0.1
		params.p_lpf_ramp = -0.25051720626043017 + frnd(0.2) - 0.1
		params.p_lpf_resonance = 0.32777871505494693 + frnd(0.2) - 0.1
		params.p_hpf_freq = 0.0023548750981756753 + frnd(0.2) - 0.1
		params.p_hpf_ramp = -0.002375673204842568 + frnd(0.2) - 0.1
		return params

	if frnd(10) < 1:
		params.wave_type = floori(frnd(WaveType.size()))
		if params.wave_type == WaveType.NOISE:
			params.wave_type = WaveType.SQUARE

		params.p_env_attack = 0.5277795946672003 + frnd(0.2) - 0.1
		params.p_env_sustain = 0.18243733568468432 + frnd(0.2) - 0.1
		params.p_env_punch = -0.020159754546840117 + frnd(0.2) - 0.1
		params.p_env_decay = 0.1561353422051903 + frnd(0.2) - 0.1
		params.p_base_freq = 0.9028855606533718 + frnd(0.2) - 0.1
		params.p_freq_limit = -0.008842787837148716
		params.p_freq_ramp = -0.1
		params.p_freq_dramp = -0.012891241489551925
		params.p_vib_strength = -0.17923136138403065 + frnd(0.2) - 0.1
		params.p_vib_speed = 0.908263385610142 + frnd(0.2) - 0.1
		params.p_arp_mod = 0.41690153355414894 + frnd(0.2) - 0.1
		params.p_arp_speed = 0.0010766233195860703 + frnd(0.2) - 0.1
		params.p_duty = -0.8735363011184684 + frnd(0.2) - 0.1
		params.p_duty_ramp = -0.7397985366747507 + frnd(0.2) - 0.1
		params.p_repeat_speed = 0.0591789344172107 + frnd(0.2) - 0.1
		params.p_pha_offset = -0.9961184222777699 + frnd(0.2) - 0.1
		params.p_pha_ramp = -0.08234769395850523 + frnd(0.2) - 0.1
		params.p_lpf_freq = 0.9412475115697335 + frnd(0.2) - 0.1
		params.p_lpf_ramp = -0.18261358925834958 + frnd(0.2) - 0.1
		params.p_lpf_resonance = 0.24541438107389477 + frnd(0.2) - 0.1
		params.p_hpf_freq = -0.01831940280978611 + frnd(0.2) - 0.1
		params.p_hpf_ramp = -0.03857383633171346 + frnd(0.2) - 0.1
		return params

	if frnd(10) < 1:
		params.wave_type = floori(frnd(WaveType.size()))
		if params.wave_type == WaveType.NOISE:
			params.wave_type = WaveType.SQUARE

		params.p_env_attack = 0.4304400932967592 + frnd(0.2) - 0.1
		params.p_env_sustain = 0.15739346034252394 + frnd(0.2) - 0.1
		params.p_env_punch = 0.004488201744871758 + frnd(0.2) - 0.1
		params.p_env_decay = 0.07478075528212291 + frnd(0.2) - 0.1
		params.p_base_freq = 0.9865265720147687 + frnd(0.2) - 0.1
		params.p_freq_limit = 0 + frnd(0.2) - 0.1
		params.p_freq_ramp = -0.2995018224359539 + frnd(0.2) - 0.1
		params.p_freq_dramp = 0.004598608156964473 + frnd(0.2) - 0.1
		params.p_vib_strength = -0.2202799497929496 + frnd(0.2) - 0.1
		params.p_vib_speed = 0.8084998703158364 + frnd(0.2) - 0.1
		params.p_arp_mod = -0.46410459213693644 + frnd(0.2) - 0.1
		params.p_arp_speed = -0.10955361249587248 + frnd(0.2) - 0.1
		params.p_duty = -0.9031808754347107 + frnd(0.2) - 0.1
		params.p_duty_ramp = -0.8128699999808343 + frnd(0.2) - 0.1
		params.p_repeat_speed = 0.7014860189319991 + frnd(0.2) - 0.1
		params.p_pha_offset = -0.9424902314367765 + frnd(0.2) - 0.1
		params.p_pha_ramp = -0.1055482222272056 + frnd(0.2) - 0.1
		params.p_lpf_freq = 0.9989765717851521 + frnd(0.2) - 0.1
		params.p_lpf_ramp = -0.25051720626043017 + frnd(0.2) - 0.1
		params.p_lpf_resonance = 0.32777871505494693 + frnd(0.2) - 0.1
		params.p_hpf_freq = 0.0023548750981756753 + frnd(0.2) - 0.1
		params.p_hpf_ramp = -0.002375673204842568 + frnd(0.2) - 0.1
		return params

	if frnd(5) > 1:
		params.wave_type = floori(frnd(WaveType.size()))
		if params.wave_type == WaveType.NOISE:
			params.wave_type = WaveType.SQUARE

		if rnd(1):
			params.p_arp_mod = 0.2697849293151393 + frnd(0.2) - 0.1
			params.p_arp_speed = -0.3131172257760948 + frnd(0.2) - 0.1
			params.p_base_freq = 0.8090588299313949 + frnd(0.2) - 0.1
			params.p_duty = -0.6210022920964955 + frnd(0.2) - 0.1
			params.p_duty_ramp = -0.00043441813553182567 + frnd(0.2) - 0.1
			params.p_env_attack = 0.004321877246874195 + frnd(0.2) - 0.1
			params.p_env_decay = 0.1 + frnd(0.2) - 0.1
			params.p_env_punch = 0.061737781504416146 + frnd(0.2) - 0.1
			params.p_env_sustain = 0.4987252564798832 + frnd(0.2) - 0.1
			params.p_freq_dramp = 0.31700340314222614 + frnd(0.2) - 0.1
			params.p_freq_limit = 0 + frnd(0.2) - 0.1
			params.p_freq_ramp = -0.163380391341416 + frnd(0.2) - 0.1
			params.p_hpf_freq = 0.4709005021145149 + frnd(0.2) - 0.1
			params.p_hpf_ramp = 0.6924667290539194 + frnd(0.2) - 0.1
			params.p_lpf_freq = 0.8351398631384511 + frnd(0.2) - 0.1
			params.p_lpf_ramp = 0.36616557192873134 + frnd(0.2) - 0.1
			params.p_lpf_resonance = -0.08685777111664439 + frnd(0.2) - 0.1
			params.p_pha_offset = -0.036084571580025544 + frnd(0.2) - 0.1
			params.p_pha_ramp = -0.014806445085568108 + frnd(0.2) - 0.1
			params.p_repeat_speed = -0.8094368475518489 + frnd(0.2) - 0.1
			params.p_vib_speed = 0.4496665457171294 + frnd(0.2) - 0.1
			params.p_vib_strength = 0.23413762515532424 + frnd(0.2) - 0.1
		else:
			params.p_arp_mod = -0.35697118026766184 + frnd(0.2) - 0.1
			params.p_arp_speed = 0.3581140690559588 + frnd(0.2) - 0.1
			params.p_base_freq = 1.3260897696157528 + frnd(0.2) - 0.1
			params.p_duty = -0.30984900436710694 + frnd(0.2) - 0.1
			params.p_duty_ramp = -0.0014374759133411626 + frnd(0.2) - 0.1
			params.p_env_attack = 0.3160357835682254 + frnd(0.2) - 0.1
			params.p_env_decay = 0.1 + frnd(0.2) - 0.1
			params.p_env_punch = 0.24323114016870148 + frnd(0.2) - 0.1
			params.p_env_sustain = 0.4 + frnd(0.2) - 0.1
			params.p_freq_dramp = 0.2866475886237244 + frnd(0.2) - 0.1
			params.p_freq_limit = 0 + frnd(0.2) - 0.1
			params.p_freq_ramp = -0.10956352368742976 + frnd(0.2) - 0.1
			params.p_hpf_freq = 0.20772718017889846 + frnd(0.2) - 0.1
			params.p_hpf_ramp = 0.1564090637378835 + frnd(0.2) - 0.1
			params.p_lpf_freq = 0.6021372770637031 + frnd(0.2) - 0.1
			params.p_lpf_ramp = 0.24016227139979027 + frnd(0.2) - 0.1
			params.p_lpf_resonance = -0.08787383821160144 + frnd(0.2) - 0.1
			params.p_pha_offset = -0.381597686151701 + frnd(0.2) - 0.1
			params.p_pha_ramp = -0.0002481687661373495 + frnd(0.2) - 0.1
			params.p_repeat_speed = 0.07812112809425686 + frnd(0.2) - 0.1
			params.p_vib_speed = -0.13648848579133943 + frnd(0.2) - 0.1
			params.p_vib_strength = 0.0018874158972302657 + frnd(0.2) - 0.1

		return params

	params.wave_type = floori(frnd(WaveType.size()))
	if params.wave_type == 1 or params.wave_type == 3:
		params.wave_type = 2

	params.p_base_freq = 0.85 + frnd(0.15)
	params.p_freq_ramp = 0.3 + frnd(0.15)

	params.p_env_attack = 0 + frnd(0.09)
	params.p_env_sustain = 0.2 + frnd(0.3)
	params.p_env_decay = 0 + frnd(0.1)

	params.p_duty = frnd(2.0) - 1.0
	params.p_duty_ramp = pow(frnd(2.0) - 1.0, 3.0)

	params.p_repeat_speed = 0.5 + frnd(0.1)

	params.p_pha_offset = -0.3 + frnd(0.9)
	params.p_pha_ramp = -frnd(0.3)

	params.p_arp_speed = 0.4 + frnd(0.6)
	params.p_arp_mod = 0.8 + frnd(0.1)

	params.p_lpf_resonance = frnd(2.0) - 1.0
	params.p_lpf_freq = 1.0 - pow(frnd(1.0), 3.0)
	params.p_lpf_ramp = pow(frnd(2.0) - 1.0, 3.0)
	if params.p_lpf_freq < 0.1 and params.p_lpf_ramp < -0.05:
		params.p_lpf_ramp = -params.p_lpf_ramp

	params.p_hpf_freq = pow(frnd(1.0), 5.0)
	params.p_hpf_ramp = pow(frnd(2.0) - 1.0, 5.0)

	return params


func gen_pushSound() -> Params:
	var params := Params.new()
	var push_sound_wave_rand: float = frnd(WaveType.size())
	params.wave_type = floori(push_sound_wave_rand)
	if params.wave_type == 2:
		params.wave_type += 1
	if params.wave_type == 0:
		params.wave_type = WaveType.NOISE

	params.p_base_freq = 0.1 + frnd(0.4)
	params.p_freq_ramp = 0.05 + frnd(0.2)

	params.p_env_attack = 0.01 + frnd(0.09)
	params.p_env_sustain = 0.01 + frnd(0.09)
	params.p_env_decay = 0.01 + frnd(0.09)

	params.p_repeat_speed = 0.3 + frnd(0.5)
	params.p_pha_offset = -0.3 + frnd(0.9)
	params.p_pha_ramp = -frnd(0.3)
	params.p_arp_speed = 0.6 + frnd(0.3)
	params.p_arp_mod = 0.8 - frnd(1.6)

	return params


func gen_powerUp() -> Params:
	var params := Params.new()

	if rnd(1):
		params.wave_type = WaveType.SAWTOOTH
	else:
		params.p_duty = frnd(0.6)

	params.wave_type = floori(frnd(WaveType.size()))
	if params.wave_type == WaveType.NOISE:
		params.wave_type = WaveType.SQUARE

	if rnd(1):
		params.p_base_freq = 0.2 + frnd(0.3)
		params.p_freq_ramp = 0.1 + frnd(0.4)
		params.p_repeat_speed = 0.4 + frnd(0.4)
	else:
		params.p_base_freq = 0.2 + frnd(0.3)
		params.p_freq_ramp = 0.05 + frnd(0.2)
		if rnd(1):
			params.p_vib_strength = frnd(0.7)
			params.p_vib_speed = frnd(0.6)

	params.p_env_attack = 0.0
	params.p_env_sustain = frnd(0.4)
	params.p_env_decay = 0.1 + frnd(0.4)

	return params


func gen_hitHurt() -> Params:
	var params := Params.new()
	params.wave_type = rnd(2)

	if params.wave_type == WaveType.SINE:
		params.wave_type = WaveType.NOISE
	if params.wave_type == WaveType.SQUARE:
		params.p_duty = frnd(0.6)

	params.wave_type = floori(frnd(WaveType.size()))
	params.p_base_freq = 0.2 + frnd(0.6)
	params.p_freq_ramp = -0.3 - frnd(0.4)
	params.p_env_attack = 0.0
	params.p_env_sustain = frnd(0.1)
	params.p_env_decay = 0.1 + frnd(0.2)

	if rnd(1):
		params.p_hpf_freq = frnd(0.3)

	return params


func gen_jump() -> Params:
	var params := Params.new()
	params.wave_type = WaveType.SQUARE
	params.wave_type = floori(frnd(WaveType.size()))
	if params.wave_type == WaveType.NOISE:
		params.wave_type = WaveType.SQUARE

	params.p_duty = frnd(0.6)
	params.p_base_freq = 0.3 + frnd(0.3)
	params.p_freq_ramp = 0.1 + frnd(0.2)
	params.p_env_attack = 0.0
	params.p_env_sustain = 0.1 + frnd(0.3)
	params.p_env_decay = 0.1 + frnd(0.2)

	if rnd(1):
		params.p_hpf_freq = frnd(0.3)
	if rnd(1):
		params.p_lpf_freq = 1.0 - frnd(0.6)

	return params


func gen_blipSelect() -> Params:
	var params := Params.new()
	params.wave_type = rnd(1)
	params.wave_type = floori(frnd(WaveType.size()))
	if params.wave_type == WaveType.NOISE:
		params.wave_type = rnd(1)

	if params.wave_type == WaveType.SQUARE:
		params.p_duty = frnd(0.6)

	params.p_base_freq = 0.2 + frnd(0.4)
	params.p_env_attack = 0.0
	params.p_env_sustain = 0.1 + frnd(0.1)
	params.p_env_decay = frnd(0.2)
	params.p_hpf_freq = 0.1

	return params


func gen_random() -> Params:
	var params := Params.new()
	params.wave_type = floori(frnd(WaveType.size()))
	params.p_base_freq = pow(frnd(2.0) - 1.0, 2.0)

	if rnd(1):
		params.p_base_freq = pow(frnd(2.0) - 1.0, 3.0) + 0.5

	params.p_freq_limit = 0.0
	params.p_freq_ramp = pow(frnd(2.0) - 1.0, 5.0)

	if params.p_base_freq > 0.7 and params.p_freq_ramp > 0.2:
		params.p_freq_ramp = -params.p_freq_ramp
	if params.p_base_freq < 0.2 and params.p_freq_ramp < -0.05:
		params.p_freq_ramp = -params.p_freq_ramp

	params.p_freq_dramp = pow(frnd(2.0) - 1.0, 3.0)
	params.p_duty = frnd(2.0) - 1.0
	params.p_duty_ramp = pow(frnd(2.0) - 1.0, 3.0)
	params.p_vib_strength = pow(frnd(2.0) - 1.0, 3.0)
	params.p_vib_speed = frnd(2.0) - 1.0
	params.p_env_attack = pow(frnd(2.0) - 1.0, 3.0)
	params.p_env_sustain = pow(frnd(2.0) - 1.0, 2.0)
	params.p_env_decay = frnd(2.0) - 1.0
	params.p_env_punch = pow(frnd(0.8), 2.0)

	if params.p_env_attack + params.p_env_sustain + params.p_env_decay < 0.2:
		params.p_env_sustain += 0.2 + frnd(0.3)
		params.p_env_decay += 0.2 + frnd(0.3)

	params.p_lpf_resonance = frnd(2.0) - 1.0
	params.p_lpf_freq = 1.0 - pow(frnd(1.0), 3.0)
	params.p_lpf_ramp = pow(frnd(2.0) - 1.0, 3.0)

	if params.p_lpf_freq < 0.1 and params.p_lpf_ramp < -0.05:
		params.p_lpf_ramp = -params.p_lpf_ramp

	params.p_hpf_freq = pow(frnd(1.0), 5.0)
	params.p_hpf_ramp = pow(frnd(2.0) - 1.0, 5.0)
	params.p_pha_offset = pow(frnd(2.0) - 1.0, 3.0)
	params.p_pha_ramp = pow(frnd(2.0) - 1.0, 3.0)
	params.p_repeat_speed = frnd(2.0) - 1.0
	params.p_arp_speed = frnd(2.0) - 1.0
	params.p_arp_mod = frnd(2.0) - 1.0

	return params