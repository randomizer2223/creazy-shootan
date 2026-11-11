class_name LProjectile
extends RefCounted

const GRAV := 600.0

var wid := ""
var def: Dictionary
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var owner: LWorm
var t := 0.0
var alive := true
var burn_t := 0.0


func step(g, dt: float) -> void:
	t += dt
	var fuse: float = def["fuse"]
	if fuse > 0.0 and t >= fuse:
		g.explode_projectile(self)
		return
	vel.y += GRAV * float(def["grav"]) * dt
	if def.get("homing", false) and t > 0.2:
		var best: LWorm = null
		var bd := 420.0
		for w in g.worms:
			if w.alive and w != owner:
				var dd: float = w.pos.distance_to(pos)
				if dd < bd:
					bd = dd
					best = w
		if best:
			var want := (best.pos - pos).angle()
			var a := vel.angle()
			a += clampf(wrapf(want - a, -PI, PI), -4.5 * dt, 4.5 * dt)
			vel = Vector2.from_angle(a) * maxf(vel.length(), float(def["speed"]))
	if def.get("burn", false):
		burn_t -= dt
		if burn_t <= 0.0:
			burn_t = 0.2
			g.burn(self)
	var d := vel * dt
	var steps := maxi(1, int(ceil(maxf(absf(d.x), absf(d.y)))))
	var s := d / steps
	var terrain: LTerrain = g.terrain
	var bounce: float = def["bounce"]
	for i in steps:
		var np := pos + s
		if fuse == 0.0:
			var ignore: LWorm = owner if t < 0.12 else null
			if g.worm_at(np, 6.5, ignore) != null:
				pos = np
				g.explode_projectile(self)
				return
		if terrain.is_solid_v(np):
			if bounce > 0.0:
				var bx := terrain.is_solid(floori(np.x), floori(pos.y))
				var by := terrain.is_solid(floori(pos.x), floori(np.y))
				if bx:
					vel.x = -vel.x * bounce
				if by:
					vel.y = -vel.y * bounce
					vel.x *= 0.8
				if not bx and not by:
					vel = -vel * bounce
				if vel.length() < 25.0:
					vel = Vector2.ZERO
				return
			elif fuse == 0.0:
				pos = np
				g.explode_projectile(self)
				return
			else:
				vel = Vector2.ZERO
				return
		pos = np
	if pos.y > terrain.h + 50 or pos.x < -50 or pos.x > terrain.w + 50 or t > 20.0:
		if def.get("burn", false):
			g.fire_count -= 1
		alive = false
