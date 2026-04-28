class_name PuzzleScriptSFXRAudioStream
extends RefCounted

const MIN_SAMPLE_RATE := 22050
const MASTER_VOLUME := 1.0
const DEFAULT_SOUND_VOLUME := 0.5
const BIT_DEPTH := 16

enum WaveType {
	SQUARE = 0,
	SAWTOOTH = 1,
	SINE = 2,
	NOISE = 3,
	TRIANGLE = 4,
	BREAKER = 5,
}

class Params:
	var wave_type: WaveType
	
	# Envelope
	var p_env_attack: = 0.0
	var p_env_sustain: = 0.3
	var p_env_punch: = 0.0
	var p_env_decay: = 0.4

	# Tone
	var p_base_freq: = 0.3 # Start frequency
	var p_freq_limit: = 0.0   # Min frequency cutoff
	var p_freq_ramp: = 0.0 # Slide (SIGNED)
	var p_freq_dramp: = 0.0   # Delta slide (SIGNED)
	# Vibrato
	var p_vib_strength: = 0.0 # Vibrato depth
	var p_vib_speed: = 0.0 # Vibrato speed

	# Tonal change
	var p_arp_mod: = 0.0  # Change amount (SIGNED)
	var p_arp_speed: = 0.0 # Change speed

	# Duty (wat's that?)
	var p_duty: = 0.0 # Square duty
	var p_duty_ramp: = 0.0 # Duty sweep (SIGNED)

	# Repeat
	var p_repeat_speed: = 0.0 # Repeat speed

	# Phaser
	var p_pha_offset: = 0.0   # Phaser offset (SIGNED)
	var p_pha_ramp: = 0.0 # Phaser sweep (SIGNED)

	# Low-pass filter
	var p_lpf_freq: = 1.0 # Low-pass filter cutoff
	var p_lpf_ramp: = 0.0 # Low-pass filter cutoff sweep (SIGNED)
	var p_lpf_resonance: = 0.0# Low-pass filter resonance
	# High-pass filter
	var p_hpf_freq: = 0.0 # High-pass filter cutoff
	var p_hpf_ramp: = 0.0 # High-pass filter cutoff sweep (SIGNED)

	# Sample parameters
	var sound_vol: = DEFAULT_SOUND_VOLUME
	var sample_rate: int = 5512
	var bit_depth: int = BIT_DEPTH

class GeneratorState extends Object:
	var rep_time: int = 0

	var fperiod: float = 0.0
	var period: int = 0
	var fmaxperiod: float = 0.0

	var fslide: float = 0.0
	var fdslide: float = 0.0

	var square_duty: float = 0.0
	var square_slide: float = 0.0

	var arp_mod: float = 0.0
	var arp_time: int = 0
	var arp_limit: int = 0

static func _append_sample_16(bytes: PackedByteArray, sample: float) -> void:
	var s := clamp(sample, -1.0, 1.0)
	var i := int(round(s * 32767.0))

	if i < -32768:
		i = -32768
	elif i > 32767:
		i = 32767

	var u := i & 0xFFFF
	bytes.append(u & 0xFF)
	bytes.append((u >> 8) & 0xFF)

# Based on puzzlescript sfxr.js
static func _append_sample_8(bytes: PackedByteArray, sample: float) -> void:
	var clamped := clampf(sample + 1, 0, 2)
	var value := int(floorf(128.0 * clamped)) & 0xFF
	bytes.append(value)

static func _append_wav_header(
	bytes: PackedByteArray,
	sample_rate: int,
	channels: int,
	bits_per_sample: int,
	data_size: int
) -> void:
	var byte_rate := sample_rate * channels * bits_per_sample / 8
	var block_align := channels * bits_per_sample / 8
	var chunk_size := 36 + data_size

	# RIFF
	bytes.append("R".unicode_at(0))
	bytes.append("I".unicode_at(0))
	bytes.append("F".unicode_at(0))
	bytes.append("F".unicode_at(0))

	_append_u32_le(bytes, chunk_size)

	# WAVE
	bytes.append("W".unicode_at(0))
	bytes.append("A".unicode_at(0))
	bytes.append("V".unicode_at(0))
	bytes.append("E".unicode_at(0))

	# fmt
	bytes.append("f".unicode_at(0))
	bytes.append("m".unicode_at(0))
	bytes.append("t".unicode_at(0))
	bytes.append(" ".unicode_at(0))

	_append_u32_le(bytes, 16) # PCM fmt chunk size
	_append_u16_le(bytes, 1) # PCM format
	_append_u16_le(bytes, channels)
	_append_u32_le(bytes, sample_rate)
	_append_u32_le(bytes, byte_rate)
	_append_u16_le(bytes, block_align)
	_append_u16_le(bytes, bits_per_sample)

	# data
	bytes.append("d".unicode_at(0))
	bytes.append("a".unicode_at(0))
	bytes.append("t".unicode_at(0))
	bytes.append("a".unicode_at(0))

	_append_u32_le(bytes, data_size)


static func _append_u16_le(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xFF)
	bytes.append((value >> 8) & 0xFF)


static func _append_u32_le(bytes: PackedByteArray, value: int) -> void:
	bytes.append(value & 0xFF)
	bytes.append((value >> 8) & 0xFF)
	bytes.append((value >> 16) & 0xFF)
	bytes.append((value >> 24) & 0xFF)


static func _repeat_state(ps: Params, s: GeneratorState) -> void:
	s.rep_time = 0

	s.fperiod = 100.0 / (ps.p_base_freq * ps.p_base_freq + 0.001)
	s.period = floori(s.fperiod)
	s.fmaxperiod = 100.0 / (ps.p_freq_limit * ps.p_freq_limit + 0.001)

	s.fslide = 1.0 - pow(ps.p_freq_ramp, 3.0) * 0.01
	s.fdslide = -pow(ps.p_freq_dramp, 3.0) * 0.000001

	s.square_duty = 0.5 - ps.p_duty * 0.5
	s.square_slide = -ps.p_duty_ramp * 0.00005

	if ps.p_arp_mod >= 0.0:
		s.arp_mod = 1.0 - pow(ps.p_arp_mod, 2.0) * 0.9
	else:
		s.arp_mod = 1.0 + pow(ps.p_arp_mod, 2.0) * 10.0

	s.arp_time = 0
	s.arp_limit = floori(pow(1.0 - ps.p_arp_speed, 2.0) * 20000.0 + 32.0)
	if ps.p_arp_speed == 1.0:
		s.arp_limit = 0


static func generate_stream(ps: Params) -> AudioStreamWAV:
    # Original JS implementation used a "repeat" inner js closure to modify some of the local variables.
    # I've moved those variatbles into the GeneratorState class so that we can use a helper method to do the same
	var s: GeneratorState = GeneratorState.new()
	_repeat_state(ps, s)

	var fltp := 0.0
	var fltdp := 0.0
	var fltw := pow(ps.p_lpf_freq, 3.0) * 0.1
	var fltw_d: float = 1.0 + ps.p_lpf_ramp * 0.0001
	var fltdmp := (
		5.0 / (1.0 + pow(ps.p_lpf_resonance, 2.0) * 20.0) * (0.01 + fltw)
	)
	if fltdmp > 0.8:
		fltdmp = 0.8

	var fltphp := 0.0
	var flthp := pow(ps.p_hpf_freq, 2.0) * 0.1
	var flthp_d: float = 1.0 + ps.p_hpf_ramp * 0.0003

	var vib_phase := 0.0
	var vib_speed := pow(ps.p_vib_speed, 2.0) * 0.01
	var vib_amp: float = ps.p_vib_strength * 0.5

	var env_vol := 0.0
	var env_stage := 0
	var env_time := 0
	var env_length := [
		int(floor(ps.p_env_attack * ps.p_env_attack * 100000.0)),
		int(floor(ps.p_env_sustain * ps.p_env_sustain * 100000.0)),
		int(floor(ps.p_env_decay * ps.p_env_decay * 100000.0))
	]
	var env_total_length: int = env_length[0] + env_length[1] + env_length[2]

	var phase := 0
	var fphase := pow(ps.p_pha_offset, 2.0) * 1020.0
	if ps.p_pha_offset < 0.0:
		fphase = -fphase

	var fdphase := pow(ps.p_pha_ramp, 2.0) * 1.0
	if ps.p_pha_ramp < 0.0:
		fdphase = -fdphase

	var iphase := abs(int(floor(fphase)))
	var ipp := 0
	var phaser_buffer: Array[float] = []
	phaser_buffer.resize(1024)
	for i in range(1024):
		phaser_buffer[i] = 0.0

	var noise_buffer: Array[float] = []
	noise_buffer.resize(32)
	for i in range(32):
		noise_buffer[i] = randf() * 2.0 - 1.0

	var rep_limit := int(floor(pow(1.0 - ps.p_repeat_speed, 2.0) * 20000.0 + 32.0))
	if ps.p_repeat_speed == 0.0:
		rep_limit = 0

	var gain := exp(ps.sound_vol) - 1.0

	var sample_sum := 0.0
	var num_summed := 0
	var summands := int(floor(44100.0 / ps.sample_rate))
	if summands < 1:
		summands = 1

	var output_sample_rate: int = ps.sample_rate
	var upsample_x4 := false
	if ps.sample_rate < MIN_SAMPLE_RATE:
		output_sample_rate = MIN_SAMPLE_RATE
		upsample_x4 = true

	var pcm_data := PackedByteArray()

	var sample := 0.0
	for t in range(1_000_000_000):
		if rep_limit != 0:
			s.rep_time += 1
			if s.rep_time >= rep_limit:
				_repeat_state(ps, s)

		if s.arp_limit != 0 and t >= s.arp_limit:
			s.arp_limit = 0
			s.fperiod *= s.arp_mod

		s.fslide += s.fdslide
		s.fperiod *= s.fslide
		if s.fperiod > s.fmaxperiod:
			s.fperiod = s.fmaxperiod
			if ps.p_freq_limit > 0.0:
				break

		var rfperiod := s.fperiod
		if vib_amp > 0.0:
			vib_phase += vib_speed
			rfperiod = s.fperiod * (1.0 + sin(vib_phase) * vib_amp)

		s.period = int(floor(rfperiod))
		if s.period < 8:
			s.period = 8

		s.square_duty += s.square_slide
		if s.square_duty < 0.0:
			s.square_duty = 0.0
		if s.square_duty > 0.5:
			s.square_duty = 0.5

		env_time += 1
		if env_time > env_length[env_stage]:
			env_time = 1
			env_stage += 1
			while env_stage < 3 and env_length[env_stage] == 0:
				env_stage += 1
			if env_stage == 3:
				break

		if env_stage == 0:
			if env_length[0] == 0:
				env_vol = 0.0
			else:
				env_vol = float(env_time) / float(env_length[0])
		elif env_stage == 1:
			if env_length[1] == 0:
				env_vol = 1.0
			else:
				env_vol = 1.0 + pow(1.0 - float(env_time) / float(env_length[1]), 1.0) * 2.0 * ps.p_env_punch
		else:
			if env_length[2] == 0:
				env_vol = 0.0
			else:
				env_vol = 1.0 - float(env_time) / float(env_length[2])

		fphase += fdphase
		iphase = abs(int(floor(fphase)))
		if iphase > 1023:
			iphase = 1023

		if flthp_d != 0.0:
			flthp *= flthp_d
			if flthp < 0.00001:
				flthp = 0.00001
			if flthp > 0.1:
				flthp = 0.1

		sample = 0.0
		for si in range(8):
			var sub_sample := 0.0
			phase += 1
			if phase >= s.period:
				phase %= s.period
				if ps.wave_type == WaveType.NOISE:
					for i in range(32):
						noise_buffer[i] = randf() * 2.0 - 1.0

			var fp := float(phase) / float(s.period)

			if ps.wave_type == WaveType.SQUARE:
				if fp < s.square_duty:
					sub_sample = 0.5
				else:
					sub_sample = -0.5
			elif ps.wave_type == WaveType.SAWTOOTH:
				sub_sample = 1.0 - fp * 2.0
			elif ps.wave_type == WaveType.SINE:
				sub_sample = sin(fp * 2.0 * PI)
			elif ps.wave_type == WaveType.NOISE:
				sub_sample = noise_buffer[int(floor(float(phase) * 32.0 / float(s.period)))]
			elif ps.wave_type == WaveType.TRIANGLE:
				sub_sample = abs(1.0 - fp * 2.0) - 1.0
			elif ps.wave_type == WaveType.BREAKER:
				sub_sample = abs(1.0 - fp * fp * 2.0) - 1.0
			else:
				push_error("bad wave type! %s" % [ps.wave_type])
				sub_sample = 0.0

			var pp := fltp
			fltw *= fltw_d
			if fltw < 0.0:
				fltw = 0.0
			if fltw > 0.1:
				fltw = 0.1

			if ps.p_lpf_freq != 1.0:
				fltdp += (sub_sample - fltp) * fltw
				fltdp -= fltdp * fltdmp
			else:
				fltp = sub_sample
				fltdp = 0.0

			fltp += fltdp

			fltphp += fltp - pp
			fltphp -= fltphp * flthp
			sub_sample = fltphp

			phaser_buffer[ipp & 1023] = sub_sample
			sub_sample += phaser_buffer[(ipp - iphase + 1024) & 1023]
			ipp = (ipp + 1) & 1023

			sample += sub_sample * env_vol

		sample_sum += sample
		num_summed += 1
		if num_summed < summands:
			continue

		num_summed = 0
		sample = sample_sum / float(summands)
		sample_sum = 0.0

		sample = sample / 8.0 * MASTER_VOLUME
		sample *= gain

		_append_sample_16(pcm_data, sample)
        
		if upsample_x4:
			_append_sample_16(pcm_data, sample)
			_append_sample_16(pcm_data, sample)
			_append_sample_16(pcm_data, sample)

	# Final partial sample flush, matching JS
	if summands > 0:
		sample = sample_sum / float(summands)
		sample = sample / 8.0 * MASTER_VOLUME
		sample *= gain

		_append_sample_16(pcm_data, sample)
        
		if upsample_x4:
			_append_sample_16(pcm_data, sample)
			_append_sample_16(pcm_data, sample)
			_append_sample_16(pcm_data, sample)

	var wav_bytes := PackedByteArray()
	var channels := 1
	var bits_per_sample := BIT_DEPTH
	_append_wav_header(
		wav_bytes,
		output_sample_rate,
		channels,
		bits_per_sample,
		pcm_data.size()
	)
	wav_bytes.append_array(pcm_data)

	var import_options := {
	}
	return AudioStreamWAV.load_from_buffer(wav_bytes, import_options)