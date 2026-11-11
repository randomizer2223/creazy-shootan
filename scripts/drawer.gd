extends Node2D
## Draws everything that moves.
## mode 0: normal layer (pickups, ropes, critters, projectiles, gore, smoke)
## mode 1: additive glow layer (fire, flashes, sparks, tracers, pickup glow)
## mode 2: labels (names, damage numbers, pickup names)
## Particles use one soft texture, so the renderer can batch them (much faster than circles).

var game
var mode := 0
var _font: Font


func _draw() -> void:
	if game == null:
		return
	match mode:
		0:
			_draw_world()
		1:
			_draw_glow()
		2:
			_draw_labels()


func _soft(p: Vector2, r: float, c: Color) -> void:
	draw_texture_rect(Sprites.dot(), Rect2(p.x - r, p.y - r, r * 2.0, r * 2.0), false, c)


func _draw_world() -> void:
	var t: float = game.time

	# smoke (behind everything)
	for pt in game.particles:
		if pt[5] == game.P_SMOKE:
			var c: Color = pt[3]
			c.a *= clampf(pt[2] / pt[6], 0.0, 1.0)
			_soft(pt[0], pt[4] * 1.6, c)

	# weapon pickups float, so you see what they are
	for c in game.crates:
		var bob := sin(t * 3.0 + c.pos.x) * 1.5 - 4.0
		var icon := Sprites.icon(c.kind)
		draw_set_transform(c.pos + Vector2(0, bob), sin(t * 2.0 + c.pos.y) * 0.15, Vector2.ONE)
		draw_texture_rect(icon, Rect2(-8, -8, 16, 16), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		_soft(c.pos + Vector2(0, 5.5), 5.0, Color(0, 0, 0, 0.25))

	# ropes
	for w in game.worms:
		if w.alive and w.hook_state != 0:
			draw_line(w.pos, w.hook_pos, Sprites.INK, 2.2, true)
			draw_line(w.pos, w.hook_pos, Color("ffe0a3"), 1.0, true)
			draw_circle(w.hook_pos, 2.0, Sprites.INK, true, -1.0, true)
			draw_circle(w.hook_pos, 1.3, Color("c9ced6"), true, -1.0, true)

	# gibs
	for g in game.gibs:
		var a := clampf(g[4], 0.0, 1.0)
		draw_set_transform(g[0], g[2], Vector2.ONE)
		draw_texture_rect(Sprites.icon(g[5]), Rect2(-4.5, -4.5, 9, 9), false, Color(1, 1, 1, a))
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# projectiles
	for p in game.projectiles:
		var def: Dictionary = p.def
		if def.get("spin", false):
			var sz := 9.0 if p.wid == "banana_small" else (15.0 if p.wid == "mega_bomb" else 11.0)
			draw_set_transform(p.pos, p.t * 12.0, Vector2.ONE)
			draw_texture_rect(Sprites.icon(p.wid), Rect2(-sz / 2.0, -sz / 2.0, sz, sz), false)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			var fuse: float = def["fuse"]
			if fuse > 0.0:
				var left: float = fuse - p.t
				if left < 0.7 and int(left * 16.0) % 2 == 0:
					draw_circle(p.pos, 2.0, Color(1, 0.2, 0.2), true, -1.0, true)
		elif p.wid == "bazooka" or p.wid == "homing":
			draw_set_transform(p.pos, p.vel.angle(), Vector2.ONE)
			draw_texture_rect(Sprites.icon(p.wid), Rect2(-5, -5, 10, 10), false)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		elif p.wid == "fire":
			pass  # drawn in the glow layer
		elif p.wid == "dirt":
			draw_circle(p.pos, 3.6, Sprites.INK, true, -1.0, true)
			draw_circle(p.pos, 2.8, Color("b07a45"), true, -1.0, true)
		else:
			draw_rect(Rect2(p.pos - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), Color("fff3c4"))

	# critters
	for w in game.worms:
		if not w.alive:
			continue
		var blink: bool = fmod(t + w.id * 1.7, 3.5) < 0.12
		var moving: bool = w.on_ground and absf(w.vel.x) > 10.0
		Sprites.draw_critter(self, w.pos + Vector2(0, -2.4), 1.0, w.color, w.facing, Vector2.from_angle(w.aim),
			w.walk_anim, moving, w.accessory, blink)
		# weapon held in front, rotated to the aim
		var flip := 1.0 if cos(w.aim) >= 0.0 else -1.0
		draw_set_transform(w.pos + Vector2(0, 2.0), w.aim, Vector2(1, flip))
		draw_texture_rect(Sprites.icon(w.current_weapon_id()), Rect2(-2, -7, 14, 14), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# health bar
		var hpf := clampf(w.hp / LWorm.MAX_HP, 0.0, 1.0)
		var hb := Rect2(w.pos + Vector2(-9, -17), Vector2(18, 4))
		draw_rect(hb, Sprites.INK)
		draw_rect(Rect2(hb.position + Vector2(1, 1), Vector2(16 * hpf, 2)), Color("ff5c7a").lerp(Color("7ee081"), hpf))
		if w == game.player and not game.demo:
			var dir := Vector2.from_angle(w.aim)
			var ch: Vector2 = w.pos + dir * 30.0
			draw_arc(ch, 3.2, 0.0, TAU, 16, Sprites.INK, 2.2, true)
			draw_arc(ch, 3.2, 0.0, TAU, 16, Color.WHITE, 1.0, true)

	# blood droplets
	for b in game.blood:
		var s: float = b[3]
		draw_rect(Rect2(b[0] - Vector2(s, s) * 0.5, Vector2(s, s)), Color(0.75, 0.03, 0.1))

	# debris
	for pt in game.particles:
		if pt[5] == game.P_DEBRIS:
			var c: Color = pt[3]
			c.a = clampf(pt[2] * 3.0, 0.0, 1.0)
			var s: float = pt[4] * 1.3
			draw_rect(Rect2(pt[0], Vector2(s, s)), c)


func _draw_glow() -> void:
	var t: float = game.time
	for c in game.crates:
		var col: Color = game.GLOW.get(c.kind, Color.WHITE)
		var pulse := 0.5 + 0.5 * sin(t * 4.0 + c.pos.x)
		var p: Vector2 = c.pos + Vector2(0, sin(t * 3.0 + c.pos.x) * 1.5 - 4.0)
		_soft(p, 16.0, Color(col, 0.22 + 0.12 * pulse))
		draw_rect(Rect2(p.x - 0.75, p.y - 44.0, 1.5, 36.0), Color(col, 0.06 + 0.05 * pulse))

	for p in game.projectiles:
		var col: Color = p.def["color"]
		if p.wid == "shotgun" or p.wid == "minigun":
			var tail: Vector2 = p.pos - p.vel * 0.014
			draw_line(tail, p.pos, Color(col, 0.9), 1.2)
		elif p.wid == "bazooka" or p.wid == "homing":
			_soft(p.pos - p.vel.normalized() * 5.0, 6.0, Color(1.0, 0.55, 0.2, 0.6))
		elif p.wid == "fire":
			var fl := 0.7 + 0.3 * sin(t * 30.0 + p.pos.x)
			_soft(p.pos + Vector2(0, -2), 7.0 * fl, Color(1.0, 0.5, 0.15, 0.8))
			_soft(p.pos + Vector2(0, -3), 3.5 * fl, Color(1.0, 0.9, 0.5, 0.9))

	for pt in game.particles:
		var k: int = pt[5]
		if k == game.P_FIRE:
			var c: Color = pt[3]
			var f := clampf(pt[2] / pt[6], 0.0, 1.0)
			c = c.lerp(Color(0.9, 0.2, 0.1), 1.0 - f)
			c.a = f
			_soft(pt[0], pt[4] * (1.0 + f * 0.6), c)
		elif k == game.P_SPARK:
			var c: Color = pt[3]
			c.a = clampf(pt[2] * 2.0, 0.0, 1.0)
			var v: Vector2 = pt[1]
			draw_line(pt[0], pt[0] - v * 0.02, c, 1.0)

	for b in game.beams:
		var ba: float = clampf(b[2] / 0.18, 0.0, 1.0)
		draw_line(b[0], b[1], Color(0.3, 0.9, 1.0, ba * 0.5), 6.0)
		draw_line(b[0], b[1], Color(0.8, 1.0, 1.0, ba), 2.0)

	for f in game.flashes:
		var a: float = clampf(f[2] / f[3], 0.0, 1.0)
		_soft(f[0], f[1] * (1.9 - a * 0.5), Color(1.0, 0.75, 0.4, a * 0.9))
		_soft(f[0], f[1] * 0.9 * a, Color(1.0, 1.0, 0.9, a))

	for r in game.rings:
		var a: float = clampf(r[2] / r[3], 0.0, 1.0)
		var rad: float = r[1] * (1.0 - a * 0.7)
		draw_arc(r[0], rad, 0.0, TAU, 32, Color(1.0, 0.95, 0.8, a * 0.7), 2.0)


func _draw_labels() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	for w in game.worms:
		if w.alive and (w != game.player or game.demo):
			_label(w.pos + Vector2(0, -20), w.name, w.color.lightened(0.3))
	for c in game.crates:
		var nm: String = "HEALTH" if c.kind == "health" else Weapons.LIST[c.kind]["name"]
		var bob := sin(game.time * 3.0 + c.pos.x) * 1.5 - 4.0
		_label(c.pos + Vector2(0, bob - 11), nm, game.GLOW.get(c.kind, Color.WHITE).lightened(0.3))
	for t in game.texts:
		var c: Color = t[3]
		c.a = clampf(t[2] * 1.5, 0.0, 1.0)
		_label(t[0], t[1], c)


func _label(pos: Vector2, s: String, col: Color) -> void:
	# text is drawn at half scale; with camera zoom 2 it stays sharp
	var fs := 14
	var w := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5
	draw_set_transform((pos - Vector2(w / 2.0, 0)).round(), 0.0, Vector2(0.5, 0.5))
	draw_string(_font, Vector2(1.5, 1.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Sprites.INK, col.a * 0.9))
	draw_string(_font, Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)
