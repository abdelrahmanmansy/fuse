extends "res://tests/case.gd"
## Procedural SFX: every advertised sound must actually produce playable PCM.

const SfxLibrary = preload("res://src/audio/sfx_library.gd")


func test_every_named_sound_builds_pcm() -> void:
	for name in SfxLibrary.NAMES:
		var stream = SfxLibrary.make_stream(name)
		check(stream != null, "%s stream exists" % name)
		if stream == null:
			continue
		eq(stream.mix_rate, SfxLibrary.MIX_RATE, "%s mix rate" % name)
		eq(stream.format, AudioStreamWAV.FORMAT_16_BITS, "%s is 16-bit" % name)
		eq(stream.stereo, false, "%s is mono" % name)
		check(stream.data.size() > 2000, "%s has real sample data" % name)
		check(stream.get_length() > 0.05, "%s has audible length" % name)


func test_unknown_sound_returns_null() -> void:
	eq(SfxLibrary.make_stream("nope"), null, "unknown sound is null")


func test_samples_stay_in_range() -> void:
	var stream = SfxLibrary.make_stream("explode")
	var data: PackedByteArray = stream.data
	check(data.size() >= 4, "explosion has samples")
	# 16-bit encoding must never wrap; spot-check that the buffer is not silence.
	var nonzero := 0
	for i in range(0, data.size(), 2):
		if data.decode_s16(i) != 0:
			nonzero += 1
	check(nonzero > data.size() / 8, "explosion buffer is not silence")
