extends RefCounted
## Procedural placeholder SFX. Everything here is synthesised at runtime, so M2 has
## real audible feedback with zero binary assets and no licensing questions. The
## final art/audio pass (M3) replaces this with designed sound; the event wiring
## and API stay the same.

const MIX_RATE := 22050
const NAMES: Array[String] = ["place", "crate", "explode", "pickup", "hit", "win"]


static func make_stream(kind: String) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	match kind:
		"place":
			samples = _place()
		"crate":
			samples = _crate()
		"explode":
			samples = _explode()
		"pickup":
			samples = _pickup()
		"hit":
			samples = _hit()
		"win":
			samples = _win()
		_:
			return null
	return _to_stream(samples)


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var value := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	return samples


static func _noise(state: int) -> Array:
	# Tiny deterministic LCG so repeated builds sound identical.
	var next := (state * 1103515245 + 12345) & 0x7fffffff
	return [next, float(next % 10000) / 5000.0 - 1.0]


static func _fade(samples: PackedFloat32Array) -> PackedFloat32Array:
	var tail: int = mini(int(0.006 * MIX_RATE), samples.size())
	for i in tail:
		samples[samples.size() - 1 - i] *= float(i) / float(tail)
	return samples


static func _place() -> PackedFloat32Array:
	var samples := _buffer(0.11)
	var state := 7
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var env := exp(-26.0 * t) * minf(1.0, t / 0.004)
		var r: Array = _noise(state)
		state = r[0]
		samples[i] = sin(TAU * 185.0 * t) * 0.55 * env + r[1] * 0.18 * exp(-55.0 * t)
	samples = _fade(samples)
	return samples


static func _crate() -> PackedFloat32Array:
	var samples := _buffer(0.14)
	var state := 21
	var low := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var env := exp(-24.0 * t) * minf(1.0, t / 0.003)
		var r: Array = _noise(state)
		state = r[0]
		low += 0.18 * (r[1] - low)
		samples[i] = (low * 0.9 + sin(TAU * 130.0 * t) * 0.3) * env
	samples = _fade(samples)
	return samples


static func _explode() -> PackedFloat32Array:
	var samples := _buffer(0.50)
	var state := 99
	var low := 0.0
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var env := exp(-7.0 * t) * minf(1.0, t / 0.003)
		var r: Array = _noise(state)
		state = r[0]
		low += 0.22 * (r[1] - low)
		var rumble := sin(TAU * 52.0 * t) * 0.55 * exp(-4.5 * t)
		samples[i] = (r[1] * 0.55 + low * 0.85 + rumble) * env * 0.85
	samples = _fade(samples)
	return samples


static func _pickup() -> PackedFloat32Array:
	var samples := _buffer(0.18)
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var freq := 620.0 if t < 0.075 else 930.0
		var note_t := t if t < 0.075 else t - 0.075
		var env := exp(-14.0 * note_t) * minf(1.0, t / 0.004)
		samples[i] = sin(TAU * freq * t) * 0.42 * env
	samples = _fade(samples)
	return samples


static func _hit() -> PackedFloat32Array:
	var samples := _buffer(0.22)
	var state := 51
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var env := exp(-13.0 * t) * minf(1.0, t / 0.003)
		var r: Array = _noise(state)
		state = r[0]
		var square := 1.0 if sin(TAU * 118.0 * t) >= 0.0 else -1.0
		samples[i] = (square * 0.32 + r[1] * 0.30) * env
	samples = _fade(samples)
	return samples


static func _win() -> PackedFloat32Array:
	var samples := _buffer(0.75)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	for i in samples.size():
		var t := float(i) / MIX_RATE
		var value := 0.0
		for n in notes.size():
			var start := 0.16 * float(n)
			if t < start:
				continue
			var note_t := t - start
			value += sin(TAU * notes[n] * note_t) * 0.22 * exp(-6.5 * note_t)
		samples[i] = value * minf(1.0, t / 0.005)
	samples = _fade(samples)
	return samples
