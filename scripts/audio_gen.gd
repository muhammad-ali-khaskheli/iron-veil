class_name AudioGen
## Generates all sounds procedurally so the game needs no audio assets.

const RATE := 22050

static var _cache: Dictionary = {}


## Cached lookup so each sound is only synthesised once.
static func get_sfx(sfx_name: String) -> AudioStreamWAV:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var s: AudioStreamWAV
	match sfx_name:
		"rifle": s = shot(0.22, 18.0, 0.5)
		"shotgun": s = shot(0.45, 9.0, 1.0, 1.0)
		"pistol": s = shot(0.16, 24.0, 0.35, 0.8)
		"enemy": s = shot(0.2, 20.0, 0.3, 0.7)
		"click": s = click()
		"hit": s = hit()
		"hurt": s = hurt()
		"ambient": s = ambient()
		_: s = click()
	_cache[sfx_name] = s
	return s


static func _make(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


## Noise burst with a low thump. decay: higher = shorter. thump: bass amount.
static func shot(length: float, decay: float, thump: float, volume: float = 0.9) -> AudioStreamWAV:
	var n: int = int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var lp: float = 0.0
	for i in n:
		var t: float = float(i) / RATE
		var env: float = exp(-t * decay)
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.55)
		var boom: float = sin(TAU * (90.0 - 60.0 * minf(t * 6.0, 1.0)) * t) * thump
		out[i] = (lp * env + boom * exp(-t * decay * 0.7)) * volume
	return _make(out)


static func click(length: float = 0.06) -> AudioStreamWAV:
	var n: int = int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / RATE
		out[i] = sin(TAU * 1800.0 * t) * exp(-t * 70.0) * 0.5
	return _make(out)


static func hit() -> AudioStreamWAV:
	var n: int = int(0.12 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / RATE
		out[i] = sin(TAU * 900.0 * t) * exp(-t * 40.0) * 0.5
	return _make(out)


static func hurt() -> AudioStreamWAV:
	var n: int = int(0.25 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / RATE
		out[i] = (sin(TAU * 110.0 * t) + sin(TAU * 73.0 * t)) * 0.4 * exp(-t * 12.0)
	return _make(out)


## Seamless dark drone, 4 seconds. All frequencies are multiples of 0.25 Hz.
static func ambient() -> AudioStreamWAV:
	var dur: float = 4.0
	var n: int = int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t: float = float(i) / RATE
		var v: float = 0.0
		v += sin(TAU * 55.0 * t) * 0.25
		v += sin(TAU * 82.5 * t) * 0.15
		v += sin(TAU * 110.25 * t) * 0.08 * (0.5 + 0.5 * sin(TAU * 0.25 * t))
		v += sin(TAU * 164.75 * t) * 0.04 * (0.5 + 0.5 * sin(TAU * 0.5 * t))
		out[i] = v * 0.6
	return _make(out, true)
