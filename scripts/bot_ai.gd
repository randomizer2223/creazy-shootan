class_name BotAI
extends RefCounted
## Простий бот: шукає ціль, бере ящики, цілиться з урахуванням балістики,
## стрибає через перешкоди, лізе на тросі вгору, стріляє крізь землю (прокопує).

var worm: LWorm
var game
var rng := RandomNumberGenerator.new()
var target: LWorm = null
var retarget_t := 0.0
var weapon_t := 0.0
var err_t := 0.0
var aim_err := 0.0
var wander_dir := 1
var wander_t := 0.0
var stuck_t := 0.0
var last_pos := Vector2.ZERO
var rope_t := 0.0
var rope_cd := 0.0
var react_t := 0.0
var had_los := false
var los_t := 0.0
var los_cache := false


func _init(w: LWorm, g) -> void:
	worm = w
	game = g
	rng.seed = hash(w.id * 7919 + 13)


func get_input(dt: float) -> Dictionary:
	var w := worm
	var inp := LWorm.empty_input()
	inp["aim"] = w.aim
	if not w.alive:
		return inp
	var diff: Dictionary = Cfg.DIFFICULTIES[Cfg.bot_difficulty]

	# --- вибір цілі ---
	retarget_t -= dt
	if retarget_t <= 0.0 or target == null or not target.alive:
		retarget_t = 1.0
		target = null
		var best := INF
		for o in game.worms:
			if o == w or not o.alive:
				continue
			var d: float = w.pos.distance_squared_to(o.pos)
			if d < best:
				best = d
				target = o

	var goal := w.pos
	var tdist := INF
	if target:
		goal = target.pos
		tdist = w.pos.distance_to(target.pos)
	var crate = _nearest_crate()
	var going_for_crate := false
	if crate != null:
		var cd: float = w.pos.distance_to(crate.pos)
		if cd < 200.0 and cd < tdist * 0.9:
			goal = crate.pos
			going_for_crate = true

	# --- рух ---
	var dx := goal.x - w.pos.x
	var keep := 6.0 if going_for_crate else 110.0
	wander_t -= dt
	if wander_t <= 0.0:
		wander_t = rng.randf_range(0.8, 2.0)
		wander_dir = -1 if rng.randf() < 0.5 else 1
	if absf(dx) > keep:
		inp["move"] = 1 if dx > 0.0 else -1
	elif not going_for_crate and rng.randf() < 0.6:
		inp["move"] = wander_dir

	# застряг?
	var moved := w.pos.distance_to(last_pos)
	if (inp["move"] != 0 or w.hook_state == 2) and moved < 0.35:
		stuck_t += dt
	else:
		stuck_t = maxf(0.0, stuck_t - dt * 1.5)
	last_pos = w.pos
	if stuck_t > 0.2 and w.on_ground:
		inp["jump"] = true

	# --- трос: лізти вгору, якщо ціль вище або застряг ---
	rope_cd -= dt
	var want_up := goal.y < w.pos.y - 60.0 and stuck_t < 0.5
	var rope_aim := w.aim
	var use_rope_aim := false
	if w.hook_state == 0 and want_up and rope_cd <= 0.0:
		var side := 1.0 if dx >= 0.0 else -1.0
		rope_aim = Vector2(side * rng.randf_range(0.2, 0.7), -1.0).angle()
		use_rope_aim = true
		inp["rope"] = true
		rope_cd = 1.2
		rope_t = 0.0
	elif w.hook_state == 1:
		inp["rope"] = false
	elif w.hook_state == 2:
		rope_t += dt
		inp["rope_dir"] = -1
		var release := rope_t > 2.2 or (w.pos.y < goal.y - 5.0 and not want_up) or w.rope_len <= 8.0
		if release:
			inp["rope"] = true  # повторне натискання відпускає
			rope_cd = 0.8

	# --- вибір зброї ---
	weapon_t -= dt
	if weapon_t <= 0.0:
		weapon_t = 0.6
		_pick_weapon(tdist)

	# --- приціл ---
	var desired := w.aim
	if target:
		desired = _ballistic_angle(w.pos, target.pos, w.current_weapon_id())
		err_t -= dt
		if err_t <= 0.0:
			err_t = 0.7
			aim_err = rng.randf_range(-1.0, 1.0) * float(diff["aim_error"])
		desired += aim_err
	var cur_aim := w.aim
	var delta := wrapf(desired - cur_aim, -PI, PI)
	cur_aim += clampf(delta, -6.0 * dt, 6.0 * dt)
	inp["aim"] = rope_aim if use_rope_aim else cur_aim

	# --- копання, якщо застряг ---
	if stuck_t > 0.6:
		if w.hook_state == 2:
			inp["rope"] = not w._prev.get("rope", false)
		inp["dig"] = true
		inp["aim"] = (goal - w.pos).angle()
		return inp

	# --- стрільба ---
	if target and not use_rope_aim:
		var wid := w.current_weapon_id()
		var def: Dictionary = Weapons.LIST[wid]
		var muzzle := w.pos + Vector2.from_angle(cur_aim) * 6.0
		los_t -= dt
		if los_t <= 0.0:
			los_t = 0.15
			los_cache = game.terrain.raycast(muzzle, target.pos, 2.0) == Vector2.INF
		var los: bool = los_cache
		if los and not had_los:
			react_t = float(diff["reaction"]) * rng.randf_range(0.6, 1.2)
		had_los = los
		react_t -= dt
		var blast: float = def["radius"]
		var obstacle: Vector2 = game.terrain.raycast(muzzle, muzzle + Vector2.from_angle(cur_aim) * (blast + 14.0))
		var safe := obstacle == Vector2.INF or blast < 6.0
		var aimed := absf(wrapf(desired - cur_aim, -PI, PI)) < 0.15
		if wid == "dirt":
			safe = false
		if aimed and safe and tdist < 520.0:
			if los and react_t <= 0.0:
				inp["fire"] = true
			elif not los and tdist < 260.0 and rng.randf() < dt * 1.2:
				inp["fire"] = true  # прокопуємось
	return inp


func _nearest_crate():
	var best = null
	var bd := INF
	for c in game.crates:
		if not c.alive:
			continue
		var d: float = worm.pos.distance_squared_to(c.pos)
		if d < bd:
			bd = d
			best = c
	return best


func _pick_weapon(tdist: float) -> void:
	var w := worm
	var pref := []
	if tdist < 110.0:
		pref = ["minigun", "laser", "shotgun", "napalm", "uzi"]
	elif tdist < 320.0:
		pref = ["homing", "laser", "banana", "mega_bomb", "napalm", "minigun", "grenade", "bazooka"]
	else:
		pref = ["homing", "laser", "minigun", "bazooka", "pistol"]
	for p in pref:
		for i in w.weapons.size():
			if w.weapons[i]["id"] == p:
				w.cur = i
				return


func _ballistic_angle(from: Vector2, to: Vector2, wid: String) -> float:
	var def: Dictionary = Weapons.LIST[wid]
	var g: float = LProjectile.GRAV * float(def["grav"])
	var v: float = def["speed"]
	var dx := to.x - from.x
	var x := absf(dx)
	var y := from.y - to.y  # вгору — додатнє
	if g < 1.0 or x < 1.0:
		return (to - from).angle()
	var v2 := v * v
	var disc := v2 * v2 - g * (g * x * x + 2.0 * y * v2)
	var theta := PI / 4.0
	if disc >= 0.0:
		theta = atan((v2 - sqrt(disc)) / (g * x))
	var side := 1.0 if dx >= 0.0 else -1.0
	return Vector2(side * cos(theta), -sin(theta)).angle()
