class_name Sfx
## 程序化音效：AudioStreamWAV 16bit PCM 生成，零外部资产

static var _cache := {}

static func _tone(freq: float, ms: int, decay: float, kind: String, vol: float) -> AudioStreamWAV:
	var n := int(44100.0 * ms / 1000.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / 44100.0
		var env := pow(1.0 - float(i) / n, decay)
		var v := 0.0
		match kind:
			"square": v = signf(sin(TAU * freq * t))
			"noise": v = randf() * 2.0 - 1.0
			"sweep": v = sin(TAU * (freq + 300.0 * t / (ms / 1000.0)) * t)
			_: v = sin(TAU * freq * t)
		var sample := int(clampf(v * env * vol, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = data
	return wav

## 预置音效集：hit/pickup/level/tame/burn
static func get_sfx(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		match name:
			"hit": _cache[name] = _tone(220.0, 70, 3.0, "square", 0.12)
			"pickup": _cache[name] = _tone(660.0, 60, 2.5, "sine", 0.10)
			"level": _cache[name] = _tone(440.0, 260, 1.5, "sweep", 0.14)
			"tame": _cache[name] = _tone(330.0, 420, 1.2, "sweep", 0.16)
			"burn": _cache[name] = _tone(90.0, 160, 2.0, "noise", 0.08)
			_: _cache[name] = _tone(440.0, 60, 3.0, "sine", 0.08)
	return _cache[name]
