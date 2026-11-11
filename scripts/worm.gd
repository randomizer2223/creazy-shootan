class_name LWorm
extends RefCounted
## Ворм: фізика руху, трос (ninja rope), інвентар зброї.
## Керується лише через словник input — однаково для гравця, бота і (в майбутньому) мережевого гравця.

const GRAV := 560.0
const WALK := 94.0
const JUMP_V := 215.0
const MAX_FALL := 500.0
const ROPE_SPEED := 900.0
const ROPE_MAX := 5000.0  # practically endless rope
const ROPE_MIN := 6.0
const MAX_HP := 100.0
# collision points: round critter, radius ~5.5 px
const OFFS := [Vector2(5.40, 0.00), Vector2(4.68, 2.80), Vector2(2.70, 4.85), Vector2(0.00, 5.60), Vector2(-2.70, 4.85), Vector2(-4.68, 2.80), Vector2(-5.40, 0.00), Vector2(-4.68, -2.80), Vector2(-2.70, -4.85), Vector2(-0.00, -5.60), Vector2(2.70, -4.85), Vector2(4.68, -2.80)]

var id := 0
var name := ""
var color := Color.WHITE
var is_bot := false

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var aim := 0.0  # кут прицілу у світових координатах (радіани)
var facing := 1
var on_ground := false
var hp := MAX_HP
var alive := true
var respawn := 0.0
var kills := 0
var deaths := 0
var last_hit_by: LWorm = null
var walk_anim := 0.0

var weapons: Array = []  # [{ "id": String, "ammo": int }]
var cur := 0
var cds := {}  # кулдаун кожної зброї

# трос: 0 — нема, 1 — гак летить, 2 — зачепився
var hook_state := 0
var hook_pos := Vector2.ZERO
var hook_vel := Vector2.ZERO
var hook_t := 0.0
var rope_len := 0.0
var rope_auto := false  # right after the hook grabs, the rope reels in by itself
const ROPE_SHORT := 90.0
const ROPE_REEL := 900.0

var dig_cd := 0.0
var blink_t := 3.0
var accessory := 0
var input := {}
var _prev := {}


static func empty_input() -> Dictionary:
	return {"move": 0, "jump": false, "fire": false, "rope": false, "rope_dir": 0,
		"aim": 0.0, "next": false, "prev": false, "slot": -1, "dig": false}


## Basic weapons are always there (slots 1-6) plus one random top weapon.
func reset_loadout(top := "") -> void:
	weapons = []
	for id in Weapons.BASIC:
		weapons.append({"id": id, "ammo": -1})
	cur = 1  # bazooka
	if top != "":
		weapons.append({"id": top, "ammo": int(Weapons.LIST[top]["ammo"])})
		cur = weapons.size() - 1
	cds.clear()


func spawn_at(p: Vector2) -> void:
	pos = p
	vel = Vector2.ZERO
	hp = MAX_HP
	alive = true
	hook_state = 0
	last_hit_by = null
	reset_loadout(Weapons.TOP[randi() % Weapons.TOP.size()])


## Out of shots: take another top weapon if we have one, otherwise the bazooka.
func best_weapon_index() -> int:
	for i in range(weapons.size() - 1, -1, -1):
		if Weapons.is_top(weapons[i]["id"]):
			return i
	return 1


func current_weapon_id() -> String:
	if weapons.is_empty():
		reset_loadout()
	cur = clampi(cur, 0, weapons.size() - 1)
	return weapons[cur]["id"]


func add_weapon(wid: String) -> void:
	var amount: int = Weapons.LIST[wid]["ammo"]
	for wpn in weapons:
		if wpn["id"] == wid:
			if wpn["ammo"] >= 0:
				wpn["ammo"] += amount
			return
	weapons.append({"id": wid, "ammo": amount})


func collides(t: LTerrain, p: Vector2) -> bool:
	var m := t.mask
	var tw := t.w
	var th := t.h
	for o in OFFS:
		var x := floori(p.x + o.x)
		var y := floori(p.y + o.y)
		if x < 0 or y < 0 or x >= tw or y >= th or m[y * tw + x] == 1:
			return true
	return false


func _edge(key: String) -> bool:
	return input.get(key, false) and not _prev.get(key, false)


## Один крок симуляції (60 разів на секунду).
func step(g, dt: float) -> void:
	var t: LTerrain = g.terrain
	if input.is_empty():
		input = empty_input()
	var mv: int = input["move"]

	if collides(t, pos):
		_unstick(t)
	on_ground = collides(t, pos + Vector2(0, 1))
	var was_ground := on_ground

	aim = input["aim"]
	facing = 1 if cos(aim) >= 0.0 else -1

	# --- трос ---
	if _edge("rope"):
		if hook_state == 0:
			hook_state = 1
			if g.has_method("sfx"):
				g.sfx("throw", -10.0, 1.7, pos)
			hook_pos = pos
			hook_vel = Vector2.from_angle(aim) * ROPE_SPEED
			hook_t = 0.0
		else:
			hook_state = 0
	if hook_state == 2 and _edge("jump"):
		hook_state = 0
		vel.y = minf(vel.y, -90.0)

	# --- копання (як у Liero) ---
	dig_cd -= dt
	if input.get("dig", false) and dig_cd <= 0.0:
		dig_cd = 0.1
		t.carve(pos + Vector2.from_angle(aim) * 6.0, 8.5, false)

	# --- рух ---
	if on_ground and hook_state != 2:
		vel.x = move_toward(vel.x, mv * WALK, 1100.0 * dt)
		if input["jump"]:
			vel.y = -JUMP_V
			on_ground = false
	else:
		var acc := 375.0 if hook_state == 2 else 238.0
		if mv != 0 and (vel.x * mv < WALK or hook_state == 2):
			vel.x += mv * acc * dt
		vel.x *= 1.0 - 0.15 * dt
	vel.y = minf(vel.y + GRAV * dt, MAX_FALL)

	_update_hook(t, dt)
	if hook_state == 2:
		var rd := float(input["rope_dir"])
		if rd != 0.0:
			rope_auto = false  # player takes over (W / S)
		if rope_auto:
			rope_len = move_toward(rope_len, ROPE_SHORT, ROPE_REEL * dt)
		else:
			rope_len = clampf(rope_len + rd * 140.0 * dt, ROPE_MIN, ROPE_MAX)
		var d := pos - hook_pos
		var dist := d.length()
		if dist > rope_len and dist > 0.01:
			var n := d / dist
			var vr := vel.dot(n)
			if vr > 0.0:
				vel -= n * vr
			vel -= n * minf((dist - rope_len) * 7.0, 400.0)
		if vel.length() > 650.0:
			vel = vel.normalized() * 650.0  # reeling in is fast but not a cannon

	_move(t, dt, was_ground)
	if on_ground and mv != 0:
		walk_anim += dt * 12.0
	_prev = input.duplicate()


func _update_hook(t: LTerrain, dt: float) -> void:
	if hook_state == 1:
		hook_t += dt
		hook_vel.y += 120.0 * dt
		var d := hook_vel * dt
		var steps := maxi(1, int(ceil(d.length())))
		var s := d / steps
		for i in steps:
			hook_pos += s
			if t.is_solid_v(hook_pos):
				hook_state = 2
				rope_len = clampf(pos.distance_to(hook_pos), ROPE_MIN, ROPE_MAX)
				rope_auto = true
				return
		if hook_t > 4.0:
			hook_state = 0
	elif hook_state == 2:
		if not t.is_solid_v(hook_pos):
			hook_state = 0  # землю під гаком зруйнували


func _move(t: LTerrain, dt: float, was_ground: bool) -> void:
	var d := vel * dt
	var steps := int(ceil(maxf(absf(d.x), absf(d.y))))
	if steps > 0:
		var sx := d.x / steps
		var sy := d.y / steps
		var hit_x := false
		var hit_y := false
		for i in steps:
			if not hit_x and sx != 0.0:
				var np := pos + Vector2(sx, 0)
				if not collides(t, np):
					pos = np
				else:
					var climbed := false
					if on_ground or hook_state == 2 or absf(vel.y) < 80.0:
						for up in range(1, 4):
							var np2 := np + Vector2(0, -up)
							if not collides(t, np2):
								pos = np2
								climbed = true
								break
					if not climbed:
						hit_x = true
						vel.x = -vel.x * 0.2 if absf(vel.x) > 160.0 else 0.0
			if not hit_y and sy != 0.0:
				var np := pos + Vector2(0, sy)
				if not collides(t, np):
					pos = np
				else:
					hit_y = true
					if sy > 0.0:
						on_ground = true
					vel.y = -vel.y * 0.25 if absf(vel.y) > 260.0 else 0.0
	# прилипання до схилу при ходьбі вниз
	if was_ground and vel.y >= 0.0 and hook_state != 2 and not input.get("jump", false):
		if not collides(t, pos + Vector2(0, 1)):
			for k in range(1, 4):
				if collides(t, pos + Vector2(0, k + 1)):
					pos.y += k
					on_ground = true
					break


func _unstick(t: LTerrain) -> void:
	for r in range(1, 18):
		for dir in [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1),
				Vector2(-0.7, -0.7), Vector2(0.7, -0.7)]:
			var p: Vector2 = pos + dir * r
			if not collides(t, p):
				pos = p
				return


## Стрільба та перемикання зброї.
func handle_weapons(g, dt: float) -> void:
	for k in cds.keys():
		cds[k] = maxf(0.0, cds[k] - dt)
	if weapons.is_empty():
		reset_loadout()
	if input.get("next", false) and not _prev_weapon_flag("next"):
		cur = (cur + 1) % weapons.size()
	if input.get("prev", false) and not _prev_weapon_flag("prev"):
		cur = (cur - 1 + weapons.size()) % weapons.size()
	var slot: int = input.get("slot", -1)
	if slot >= 0 and slot < weapons.size():
		cur = slot
	cur = clampi(cur, 0, weapons.size() - 1)
	if input.get("fire", false):
		var wid: String = weapons[cur]["id"]
		if cds.get(wid, 0.0) <= 0.0:
			var def: Dictionary = Weapons.LIST[wid]
			g.fire_weapon(self, wid)
			cds[wid] = def["cd"] * Cfg.reload_mult()
			if weapons[cur]["ammo"] > 0:
				weapons[cur]["ammo"] -= 1
				if weapons[cur]["ammo"] == 0:
					weapons.remove_at(cur)
					cur = best_weapon_index()
					if weapons.is_empty():
						reset_loadout()
	_wprev["next"] = input.get("next", false)
	_wprev["prev"] = input.get("prev", false)


var _wprev := {}


func _prev_weapon_flag(k: String) -> bool:
	return _wprev.get(k, false)


func cooldown_frac() -> float:
	var wid := current_weapon_id()
	var total: float = Weapons.LIST[wid]["cd"] * Cfg.reload_mult()
	if total <= 0.0:
		return 0.0
	return clampf(cds.get(wid, 0.0) / total, 0.0, 1.0)
