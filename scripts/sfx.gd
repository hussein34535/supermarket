extends Node

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _idx: int = 0
var _ambient: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_streams["pickup"] = _tone([[420, 0.045], [680, 0.055]], 0.3)
	_streams["place"] = _tone([[880, 0.06], [1320, 0.09]], 0.32)
	_streams["error"] = _tone([[190, 0.08], [140, 0.1]], 0.3)
	_streams["drop"] = _tone([[260, 0.05], [150, 0.07]], 0.3)
	_streams["upgrade"] = _tone([[620, 0.05], [830, 0.05], [1100, 0.08]], 0.28)
	_streams["milestone"] = _tone([[660, 0.07], [880, 0.07], [1100, 0.1]], 0.3)
	_streams["win"] = _tone([[523, 0.12], [659, 0.12], [784, 0.12], [1046, 0.22]], 0.32)
	_streams["beep"] = _tone([[1500, 0.035], [1900, 0.03]], 0.2)
	_streams["cash"] = _tone([[1180, 0.04], [1560, 0.045], [2100, 0.09]], 0.26)
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _room_tone()
	_ambient.volume_db = -10.0
	_ambient.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_ambient)
	_ambient.play()


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(sound, null)
	if stream == null:
		return
	var p := _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.volume_db = volume_db
	p.play()


func _tone(notes: Array, volume: float = 0.25) -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	for note in notes:
		var freq: float = note[0]
		var dur: float = note[1]
		var n := int(rate * dur)
		for i in n:
			var t := float(i) / float(rate)
			var env := pow(1.0 - float(i) / float(n), 1.4)
			var v := sin(TAU * freq * t) * env * volume
			v += sin(TAU * freq * 2.0 * t) * env * volume * 0.15
			var iv := int(clampf(v, -1.0, 1.0) * 32767.0)
			data.append(iv & 0xFF)
			data.append((iv >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _room_tone() -> AudioStreamWAV:
	var rate := 22050
	var dur := 4.0
	var n := int(rate * dur)
	var data := PackedByteArray()
	for i in n:
		var t := float(i) / float(rate)
		var v := sin(TAU * 50.0 * t) * 0.010
		v += sin(TAU * 100.0 * t + 0.4) * 0.005
		v += sin(TAU * 150.0 * t + 1.1) * 0.0025
		v *= 0.82 + sin(TAU * 0.25 * t) * 0.18
		var iv := int(clampf(v, -1.0, 1.0) * 32767.0)
		data.append(iv & 0xFF)
		data.append((iv >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
