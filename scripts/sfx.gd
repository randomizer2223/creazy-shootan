extends Node
## Sound effects (autoload "Sfx"). All sounds are synthesized in code at startup,
## so there are no audio files to load.

const RATE := 22050
const VOICES := 16

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _recent := {}  # name -> [times] to avoid 16 identical booms at once
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	# build the sounds a moment after start-up so they don't delay the menu
	get_tree().create_timer(0.8).timeout.connect(_build)


func _build() -> void:
	_sounds["boom"] = _make(0.7, _boom.bind(1.0))
	_sounds["boom_small"] = _make(0.3, _boom.bind(2.2))
	_sounds["shot"] = _make(0.09, _shot)
	_sounds["throw"] = _make(0.16, _throw)
	_sounds["laser"] = _make(0.28, _laser)
	_sounds["pickup"] = _make(0.24, _pickup)
	_sounds["splat"] = _make(0.22, _splat)
	_sounds["squeak"] = _make(0.18, _squeak)
	_sounds["dirt"] = _make(0.15, _dirt)


## Plays a sound. vol_db 0 = normal. pos (world) makes far sounds quieter.
func play(snd: String, vol_db := 0.0, pitch := 1.0, pos := Vector2.INF, listener := Vector2.INF) -> void:
	if not _sounds.has(snd):
		return
	if pos != Vector2.INF and listener != Vector2.INF:
		var d := pos.distance_to(listener)
		if d > 900.0:
			return
		vol_db -= d / 45.0
	# limit how many copies of the same sound start within 60 ms
	var now := Time.get_ticks_msec()
	var times: Array = _recent.get(snd, [])
	times = times.filter(func(t): return now - t < 60)
	if times.size() >= 3:
		return
	times.append(now)
	_recent[snd] = times
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _sounds[snd]
	p.volume_db = vol_db
	p.pitch_scale = pitch * rng.randf_range(0.93, 1.07)
	p.play()


# ---------- synthesis ----------

func _make(seconds: float, gen: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var state := {"lp": 0.0, "lp2": 0.0, "ph": 0.0}
	for i in n:
		var t := float(i) / RATE
		var v: float = gen.call(t, seconds, state)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _noise() -> float:
	return rng.randf_range(-1.0, 1.0)


func _boom(t: float, dur: float, st: Dictionary, sharp: float) -> float:
	var env := exp(-t * 5.0 * sharp)
	var cut := 0.04 + 0.25 * exp(-t * 8.0)
	st["lp"] = lerpf(st["lp"], _noise(), cut * sharp * 0.6)
	st["lp2"] = lerpf(st["lp2"], st["lp"], 0.3)
	var thump := sin(TAU * (55.0 * sharp) * t * (1.0 - t * 0.4)) * exp(-t * 9.0 * sharp)
	return (st["lp2"] * 3.2 + thump * 0.9) * env


func _shot(t: float, dur: float, st: Dictionary) -> float:
	st["lp"] = lerpf(st["lp"], _noise(), 0.5)
	var click := sin(TAU * 180.0 * t) * exp(-t * 60.0)
	return (st["lp"] * 0.9 + click * 0.6) * exp(-t * 45.0)


func _throw(t: float, dur: float, st: Dictionary) -> float:
	var x := t / dur
	st["lp"] = lerpf(st["lp"], _noise(), 0.05 + 0.25 * x)
	return st["lp"] * 2.2 * sin(PI * x) * 0.8


func _laser(t: float, dur: float, st: Dictionary) -> float:
	var f := lerpf(1900.0, 250.0, pow(t / dur, 0.6))
	st["ph"] += f / RATE
	var sq := 1.0 if fmod(st["ph"], 1.0) < 0.5 else -1.0
	return (sin(TAU * st["ph"]) * 0.6 + sq * 0.15) * exp(-t * 7.0)


func _pickup(t: float, dur: float, st: Dictionary) -> float:
	var notes := [660.0, 880.0, 1320.0]
	var k := mini(int(t / 0.07), 2)
	var lt := t - k * 0.07
	return sin(TAU * notes[k] * t) * exp(-lt * 18.0) * 0.6


func _splat(t: float, dur: float, st: Dictionary) -> float:
	st["lp"] = lerpf(st["lp"], _noise(), 0.12)
	var wob := 1.0 + 0.5 * sin(TAU * 30.0 * t)
	return st["lp"] * 2.6 * wob * exp(-t * 14.0)


func _squeak(t: float, dur: float, st: Dictionary) -> float:
	var f := lerpf(700.0, 1500.0, t / dur)
	st["ph"] += f / RATE
	return sin(TAU * st["ph"]) * sin(PI * t / dur) * 0.45


func _dirt(t: float, dur: float, st: Dictionary) -> float:
	st["lp"] = lerpf(st["lp"], _noise(), 0.08)
	return st["lp"] * 2.5 * exp(-t * 18.0)
