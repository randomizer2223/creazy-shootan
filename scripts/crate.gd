class_name LCrate
extends RefCounted
## Ящик зі зброєю або аптечка. Падає з гравітацією, зникає при підбиранні.

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var kind := ""  # id зброї або "health"
var alive := true
var t := 0.0


func step(g, dt: float) -> void:
	t += dt
	var terrain: LTerrain = g.terrain
	vel.y = minf(vel.y + 400.0 * dt, 300.0)
	vel.x *= 1.0 - 2.0 * dt
	var d := vel * dt
	var steps := maxi(1, int(ceil(maxf(absf(d.x), absf(d.y)))))
	var s := d / steps
	for i in steps:
		var np := pos + s
		if _hits(terrain, np):
			if _hits(terrain, Vector2(np.x, pos.y)):
				vel.x = 0.0
			if _hits(terrain, Vector2(pos.x, np.y)):
				vel.y = 0.0
			return
		pos = np
	if _hits(terrain, pos):
		pos.y -= 1.0


func _hits(terrain: LTerrain, p: Vector2) -> bool:
	for o in [Vector2(-3, 4), Vector2(0, 4), Vector2(3, 4), Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4)]:
		if terrain.is_solid_v(p + o):
			return true
	return false
