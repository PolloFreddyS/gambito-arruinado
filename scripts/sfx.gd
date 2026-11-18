extends Node
## Sonidos sintetizados en código (autoload "Sfx"). No hay archivos de audio.

const RATE := 22050
var streams := {}
var players: Array[AudioStreamPlayer] = []
var next := 0
var muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	_build()


func play(id: String, pitch: float = 1.0, vol: float = 0.0) -> void:
	if muted or not streams.has(id):
		return
	var p := players[next]
	next = (next + 1) % players.size()
	p.stream = streams[id]
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	p.volume_db = vol
	p.play()


func _make(dur: float, gen: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = gen.call(t, float(i) / n)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


static func _sweep(t: float, f0: float, f1: float, d: float) -> float:
	return sin(TAU * (f0 * t + (f1 - f0) * t * t / (2.0 * d)))


func _build() -> void:
	streams["pop"] = _make(0.09, func(t: float, k: float): return _sweep(t, 420.0, 1100.0, 0.09) * pow(1.0 - k, 2.0) * 0.6)
	streams["click"] = _make(0.03, func(t: float, k: float): return sin(TAU * 900.0 * t) * (1.0 - k) * 0.4)
	streams["tick"] = _make(0.045, func(t: float, k: float): return (1.0 if sin(TAU * 1100.0 * t) > 0.0 else -1.0) * pow(1.0 - k, 2.0) * 0.25)
	var st := [0.0]
	streams["land"] = _make(0.16, func(t: float, k: float):
		st[0] = st[0] * 0.8 + randf_range(-1.0, 1.0) * 0.2
		return (_sweep(t, 170.0, 45.0, 0.16) * 0.8 + st[0] * 0.8) * pow(1.0 - k, 2.5))
	var sb := [0.0]
	streams["boom"] = _make(0.75, func(t: float, k: float):
		sb[0] = sb[0] * 0.86 + randf_range(-1.0, 1.0) * 0.14
		var crack := randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - k * 20.0)
		return (sb[0] * 2.6 * pow(1.0 - k, 2.2) + _sweep(t, 95.0, 30.0, 0.75) * pow(1.0 - k, 1.4) * 0.9 + crack * 0.6) * 0.9)
	var sbb := [0.0]
	streams["bigboom"] = _make(1.3, func(t: float, k: float):
		sbb[0] = sbb[0] * 0.92 + randf_range(-1.0, 1.0) * 0.08
		var crack := randf_range(-1.0, 1.0) * maxf(0.0, 1.0 - k * 25.0)
		var rumble := sin(TAU * 42.0 * t + sin(TAU * 3.0 * t) * 2.0) * pow(1.0 - k, 1.2)
		return (sbb[0] * 3.6 * pow(1.0 - k, 1.8) + rumble * 0.8 + crack * 0.7) * 0.9)
	streams["coin"] = _make(0.22, func(t: float, k: float):
		var f := 988.0 if t < 0.07 else 1319.0
		return (1.0 if sin(TAU * f * t) > 0.0 else -1.0) * 0.18 * pow(1.0 - k, 1.5))
	var sw := [0.0]
	streams["whoosh"] = _make(0.32, func(t: float, k: float):
		var a := lerpf(0.04, 0.5, sin(k * PI))
		sw[0] = sw[0] * (1.0 - a) + randf_range(-1.0, 1.0) * a
		return sw[0] * sin(k * PI) * 0.9)
	streams["spawn"] = _make(0.35, func(t: float, k: float): return _sweep(t, 1400.0, 260.0, 0.35) * (1.0 - k) * 0.35)
	streams["fanfare"] = _make(1.0, func(t: float, k: float):
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var idx := mini(int(t / 0.11), 3)
		var f: float = notes[idx]
		var local := t - idx * 0.11
		var env := 1.0 if idx < 3 else maxf(0.0, 1.0 - (t - 0.33) / 0.67)
		var sq := 1.0 if sin(TAU * f * t) > 0.0 else -1.0
		return (sq * 0.15 + sin(TAU * f * 2.0 * t) * 0.1) * env * minf(1.0, local * 60.0))
	streams["sad"] = _make(1.6, func(t: float, k: float):
		var notes := [392.0, 370.0, 349.2, 329.6]
		var idx := mini(int(t / 0.32), 3)
		var f: float = notes[idx] * (1.0 + (sin(TAU * 6.0 * t) * 0.02 if idx == 3 else 0.0))
		var ph := fmod(f * t, 1.0)
		var env := 1.0 if idx < 3 else maxf(0.0, 1.0 - (t - 0.96) / 0.64)
		return (ph * 2.0 - 1.0) * 0.22 * env)
	streams["glass"] = _make(0.5, func(t: float, k: float):
		return (sin(TAU * 2637.0 * t) * 0.3 + sin(TAU * 3520.0 * t * 1.01) * 0.25 + randf_range(-1.0, 1.0) * maxf(0.0, 0.5 - k * 4.0)) * pow(1.0 - k, 3.0))
	streams["alarm"] = _make(0.6, func(t: float, k: float):
		var f := 660.0 if fmod(t, 0.15) < 0.075 else 880.0
		return (1.0 if sin(TAU * f * t) > 0.0 else -1.0) * 0.14 * (1.0 - k))
	streams["freeze"] = _make(0.5, func(t: float, k: float): return (sin(TAU * 1800.0 * t) * sin(TAU * 7.0 * t) + randf_range(-0.3, 0.3)) * 0.25 * (1.0 - k))
	streams["buy"] = _make(0.35, func(t: float, k: float):
		var f := 1046.5 if t < 0.08 else (1318.5 if t < 0.16 else 1568.0)
		return (1.0 if sin(TAU * f * t) > 0.0 else -1.0) * 0.14 * pow(1.0 - k, 1.2))
	streams["deny"] = _make(0.25, func(t: float, k: float): return (1.0 if sin(TAU * 140.0 * t) > 0.0 else -1.0) * 0.2 * (1.0 - k))
