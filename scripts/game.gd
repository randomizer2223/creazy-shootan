extends Node2D
## One match: map, worms, projectiles, weapon pickups, effects, camera.

signal exit_to_menu
signal map_ready
var is_map_ready := false

const BOT_NAMES := ["Petro", "Oksana", "Taras", "Myroslava", "Bohdan", "Yaryna", "Ostap", "Solomiia"]
const COLORS := [
	Color(1.0, 0.55, 0.7), Color(0.45, 0.75, 1.0), Color(0.6, 1.0, 0.45), Color(1.0, 0.8, 0.3),
	Color(0.8, 0.55, 1.0), Color(0.3, 1.0, 0.9), Color(1.0, 0.5, 0.25), Color(0.95, 0.95, 0.95),
]
const GLOW := {
	"bazooka": Color(1.0, 0.6, 0.2), "grenade": Color(0.4, 1.0, 0.3), "banana": Color(1.0, 0.95, 0.2),
	"shotgun": Color(0.9, 0.9, 1.0), "minigun": Color(1.0, 0.55, 0.25), "dirt": Color(0.8, 0.55, 0.25),
	"health": Color(1.0, 0.3, 0.35), "mega_bomb": Color(0.7, 0.6, 1.0), "homing": Color(1.0, 0.4, 0.4),
	"laser": Color(0.45, 0.95, 1.0), "napalm": Color(1.0, 0.45, 0.2), "pistol": Color(1, 1, 0.8), "uzi": Color(1, 0.7, 0.4),
}

# particle kinds
const P_DEBRIS := 0
const P_SMOKE := 1
const P_FIRE := 2
const P_SPARK := 3

var terrain: LTerrain
var drawer: Node2D
var glow: Node2D
var labels: Node2D
var cam: Camera2D
var hud: CanvasLayer
var touch: CanvasLayer  # on-screen controls for phones

var worms: Array = []
var bots: Array = []
var projectiles: Array = []
var crates: Array = []     # weapon pickups (LCrate)
var particles: Array = []  # [pos, vel, life, color, size, kind, max_life]
var flashes: Array = []    # [pos, radius, life, max_life]
var rings: Array = []      # [pos, radius, life, max_life]
var texts: Array = []      # [pos, text, life, color]
var blood: Array = []      # [pos, vel, life, size]
var gibs: Array = []       # [pos, vel, rot, rot_vel, life, texture_id]
var emitters: Array = []   # blood fountains: [pos, time_left]
var beams: Array = []      # laser beams: [from, to, life]
var show_fps := false
var feed: Array = []       # kill feed: [text, life, color]
var toast := ["", 0.0]
var player: LWorm

var rng := RandomNumberGenerator.new()
var crate_timer := 2.0
var shake := 0.0
var paused := false
var game_over := false
var winner: LWorm = null
var map_name := ""
var time := 0.0

# player controls
var mouse_aim := true
var key_elev := -0.3
var wheel_next := false
var wheel_prev := false
var help_until := 20.0  # controls help auto-hides; H toggles
var headless_test := false  # autotests: player is a bot too
var demo := false           # menu background: bots only, no HUD
var shots := 0
var fire_count := 0
var _demo_target := 0
var _demo_t := 0.0


func start() -> void:
	rng.randomize()
	var bot_count := Cfg.bot_count  # read now: start() may wait for the map art
	var data: Dictionary
	if Cfg.map_index < 0 and Cfg.custom_map != null:
		data = MapGen.from_image(Cfg.custom_map)
		map_name = "Custom image"
	else:
		var preset: Dictionary = MapGen.PRESETS[Cfg.map_index]
		map_name = preset["name"]
		if preset["style"] == "art":
			data = await MapArt.build(preset["art"], self)
		if data.is_empty():
			data = MapGen.build(Cfg.map_index if preset["style"] != "art" else 1)

	terrain = LTerrain.new()
	add_child(terrain)
	terrain.setup(data["fg"], data["mask"], data["bg"], data["dirt"], data.get("outline", Color(0.23, 0.14, 0.13)))

	var dscript := preload("res://scripts/drawer.gd")
	drawer = dscript.new()
	drawer.game = self
	drawer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(drawer)
	glow = dscript.new()
	glow.game = self
	glow.mode = 1
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # glowing bullets, fire and flashes
	glow.material = mat
	add_child(glow)
	labels = dscript.new()
	labels.game = self
	labels.mode = 2
	add_child(labels)

	cam = Camera2D.new()
	cam.zoom = Vector2(2.4, 2.4)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = terrain.w
	cam.limit_bottom = terrain.h
	add_child(cam)
	cam.make_current()

	if not demo and OS.get_environment("L2_NOHUD") == "":
		hud = preload("res://scripts/hud.gd").new()
		hud.game = self
		add_child(hud)
		touch = preload("res://scripts/touch_controls.gd").new()
		touch.game = self
		add_child(touch)

	var as_bot := headless_test or demo
	player = _make_worm(0, "Bot Pixel" if demo else "You", COLORS[0], as_bot)
	for i in bot_count:
		_make_worm(i + 1, BOT_NAMES[i % BOT_NAMES.size()], COLORS[(i + 1) % COLORS.size()], true)
	cam.position = player.pos
	_announce_weapon(player)
	is_map_ready = true
	map_ready.emit()


func sfx(snd: String, vol := 0.0, pitch := 1.0, pos := Vector2.INF) -> void:
	if demo or headless_test:
		return
	Sfx.play(snd, vol, pitch, pos, cam.position if cam else Vector2.INF)


func _announce_weapon(w: LWorm) -> void:
	if w == player and not demo:
		toast = ["Your weapon: %s!" % Weapons.LIST[w.current_weapon_id()]["name"], 3.0]


func _make_worm(id: int, wname: String, col: Color, bot: bool) -> LWorm:
	var w := LWorm.new()
	w.id = id
	w.name = wname
	w.color = col
	w.is_bot = bot
	w.accessory = id
	w.spawn_at(terrain.find_spawn(rng))
	w.aim = 0.0 if rng.randf() < 0.5 else PI
	worms.append(w)
	if bot:
		bots.append(BotAI.new(w, self))
	return w


# ---------------- simulation ----------------

func _physics_process(dt: float) -> void:
	if paused or game_over or terrain == null:
		return
	time += dt
	if not (headless_test or demo):
		player.input = _player_input(dt)
	for b in bots:
		b.worm.input = b.get_input(dt)

	for w in worms:
		if w.alive:
			w.step(self, dt)
			w.handle_weapons(self, dt)
		else:
			w.respawn -= dt
			if w.respawn <= 0.0:
				w.spawn_at(terrain.find_spawn(rng))
				_announce_weapon(w)
				rings.append([w.pos, 14.0, 0.4, 0.4])

	for p in projectiles.duplicate():
		if p.alive:
			p.step(self, dt)
			if p.alive and p.def.get("trail", false):
				particles.append([p.pos - p.vel.normalized() * 3.0, Vector2(rng.randf_range(-6, 6), rng.randf_range(-12, -4)),
					0.5, Color(0.75, 0.72, 0.7, 0.5), 1.5, P_SMOKE, 0.5])
				particles.append([p.pos - p.vel.normalized() * 2.0, Vector2.ZERO, 0.08, Color(1.0, 0.6, 0.2), 2.5, P_FIRE, 0.08])
	projectiles = projectiles.filter(func(p): return p.alive)

	for c in crates:
		c.step(self, dt)
		for w in worms:
			if w.alive and c.alive and w.pos.distance_to(c.pos) < 13.0:
				_pickup(w, c)
	crates = crates.filter(func(c): return c.alive)

	crate_timer -= dt
	if crate_timer <= 0.0:
		crate_timer = rng.randf_range(3.5, 6.0)
		if crates.size() < 4 + worms.size() / 2:
			_spawn_crate()

	_update_effects(dt)
	_update_gore(dt)


func _player_input(dt: float) -> Dictionary:
	if touch and touch.active:
		var tinp := LWorm.empty_input()
		touch.fill_input(tinp, player)
		return tinp
	var inp := LWorm.empty_input()
	var w := player
	var mv := 0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv += 1
	inp["move"] = mv
	var on_rope := w.hook_state == 2
	var both := Input.is_physical_key_pressed(KEY_A) and Input.is_physical_key_pressed(KEY_D)
	inp["dig"] = both or (Input.is_physical_key_pressed(KEY_S) and not on_rope)
	var w_key := Input.is_physical_key_pressed(KEY_W)
	var s_key := Input.is_physical_key_pressed(KEY_S)
	inp["jump"] = Input.is_physical_key_pressed(KEY_SPACE) or (w_key and not on_rope)
	if on_rope:
		inp["rope_dir"] = (-1 if w_key else 0) + (1 if s_key else 0)
	inp["fire"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_J) \
		or Input.is_physical_key_pressed(KEY_CTRL)
	inp["rope"] = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_physical_key_pressed(KEY_K) \
		or Input.is_physical_key_pressed(KEY_SHIFT)
	inp["next"] = Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_TAB) or wheel_next
	inp["prev"] = Input.is_physical_key_pressed(KEY_Q) or wheel_prev
	wheel_next = false
	wheel_prev = false
	for k in 9:
		if Input.is_physical_key_pressed(KEY_1 + k):
			inp["slot"] = k

	# aim: mouse, or arrow keys up/down
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_DOWN):
		if mouse_aim:
			mouse_aim = false
			key_elev = -absf(asin(clampf(sin(w.aim), -1.0, 1.0)))
		if Input.is_physical_key_pressed(KEY_UP):
			key_elev -= 2.4 * dt
		if Input.is_physical_key_pressed(KEY_DOWN):
			key_elev += 2.4 * dt
		key_elev = clampf(key_elev, -1.5, 1.4)
	if mouse_aim:
		inp["aim"] = (get_global_mouse_position() - w.pos).angle()
	else:
		var f := w.facing
		if mv != 0:
			f = mv
		inp["aim"] = Vector2(f * cos(key_elev), sin(key_elev)).angle()
	return inp


func _unhandled_input(event: InputEvent) -> void:
	if demo:
		return
	if event is InputEventKey and touch:
		touch.active = false  # a keyboard is being used: back to desktop controls
	if event is InputEventMouseMotion:
		mouse_aim = true
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel_prev = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel_next = true
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if game_over or paused:
					exit_to_menu.emit()
				else:
					paused = true
			KEY_ENTER, KEY_KP_ENTER:
				if paused:
					paused = false
				elif game_over:
					exit_to_menu.emit()
			KEY_F3:
				show_fps = not show_fps
			KEY_F1, KEY_H:
				help_until = 0.0 if time < help_until else time + 99999.0


# ---------------- weapons ----------------

func fire_weapon(w: LWorm, wid: String) -> void:
	shots += 1
	var def: Dictionary = Weapons.LIST[wid]
	match wid:
		"laser":
			sfx("laser", -4.0, 1.0, w.pos)
		"pistol", "uzi", "minigun":
			sfx("shot", -8.0 if wid != "pistol" else -4.0, 1.2 if wid == "uzi" else 1.0, w.pos)
		"shotgun":
			sfx("shot", 0.0, 0.7, w.pos)
		"dirt":
			sfx("throw", -6.0, 0.8, w.pos)
		_:
			sfx("throw", -4.0, 1.0, w.pos)
	if def.get("hitscan", false):
		_fire_laser(w, def)
		return
	var count: int = def["count"]
	var spread: float = def["spread"]
	var speed: float = def["speed"]
	for i in count:
		var a := w.aim + rng.randf_range(-spread, spread)
		var sp := speed * (rng.randf_range(0.85, 1.05) if count > 1 else 1.0)
		spawn_projectile(wid, w.pos + Vector2.from_angle(w.aim) * 9.0, Vector2.from_angle(a) * sp, w)
	if wid == "shotgun":
		w.vel -= Vector2.from_angle(w.aim) * 40.0
	var muzzle := w.pos + Vector2.from_angle(w.aim) * 13.0
	flashes.append([muzzle, 4.0, 0.06, 0.06])
	if wid != "dirt":
		particles.append([muzzle, Vector2.from_angle(w.aim) * 20.0, 0.4, Color(0.8, 0.8, 0.8, 0.4), 1.5, P_SMOKE, 0.4])


## Laser: instant beam that melts a tunnel through the ground and hits the first critter.
func _fire_laser(w: LWorm, def: Dictionary) -> void:
	var dir := Vector2.from_angle(w.aim)
	var start := w.pos + dir * 9.0
	var p := start
	var hit: LWorm = null
	var carved := 0.0
	for i in 350:
		p += dir * 2.0
		if p.x < 0 or p.y < 0 or p.x > terrain.w or p.y > terrain.h:
			break
		hit = worm_at(p, 6.5, w)
		if hit:
			break
		if terrain.is_solid_v(p) and carved <= 0.0:
			terrain.carve(p, def["radius"], true)
			carved = 3.0
		carved -= 2.0
	beams.append([start, p, 0.18])
	flashes.append([p, 8.0, 0.12, 0.12])
	if hit:
		hit.vel += dir * float(def["knock"])
		damage_worm(hit, def["dmg"], w, dir)


## Napalm fire: hurts critters nearby and slowly melts the ground.
func burn(p: LProjectile) -> void:
	# melting the ground is the expensive part, so only do it now and then
	if rng.randf() < 0.35:
		terrain.carve(p.pos, p.def["radius"], false)
	for w in worms:
		if w.alive and w.pos.distance_to(p.pos) < 10.0:
			damage_worm(w, p.def["dmg"], p.owner, Vector2.UP)
	if rng.randf() < 0.1:
		particles.append([p.pos, Vector2(0, -20), 1.0, Color(0.3, 0.3, 0.3, 0.4), 3.0, P_SMOKE, 1.0])


func spawn_projectile(wid: String, p: Vector2, v: Vector2, owner: LWorm) -> LProjectile:
	var pr := LProjectile.new()
	pr.wid = wid
	pr.def = Weapons.LIST[wid]
	pr.pos = p
	pr.vel = v
	pr.owner = owner
	projectiles.append(pr)
	# keep napalm fires under control: oldest fires go out first
	if wid == "fire":
		fire_count += 1
		if fire_count > 160:
			for q in projectiles:
				if q.alive and q.wid == "fire":
					q.alive = false
					fire_count -= 1
					break
	return pr


func worm_at(p: Vector2, r: float, ignore: LWorm) -> LWorm:
	var r2 := r * r
	for w in worms:
		if w.alive and w != ignore and w.pos.distance_squared_to(p) <= r2:
			return w
	return null


func explode_projectile(p: LProjectile) -> void:
	if not p.alive:
		return
	p.alive = false
	var d := p.def
	if d.get("burn", false):
		fire_count -= 1
		return  # fire just goes out
	if d.get("dirt", 0.0) > 0.0:
		terrain.add_dirt(p.pos, d["dirt"])
		sfx("dirt", -4.0, 1.0, p.pos)
		for i in 14:
			particles.append([p.pos, Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20, 90), 0.6,
				terrain.dirt_colors[rng.randi() % terrain.dirt_colors.size()], 1.5, P_DEBRIS, 0.6])
		rings.append([p.pos, float(d["dirt"]), 0.25, 0.25])
		return
	explode(p.pos, d["radius"], d["dmg"], d["knock"], p.owner)
	var cl: int = d.get("cluster", 0)
	if cl > 0:
		for i in cl:
			var a := -PI / 2.0 + rng.randf_range(-1.2, 1.2)
			spawn_projectile(d["cluster_id"], p.pos, Vector2.from_angle(a) * rng.randf_range(140, 330), p.owner)


func explode(pos: Vector2, radius: float, dmg: float, knock: float, owner: LWorm) -> void:
	# debris colors are sampled from the ground before it is destroyed
	var debris_cols := []
	for i in 5:
		var q := pos + Vector2.from_angle(rng.randf() * TAU) * radius * 0.6
		var qi := Vector2i(clampi(int(q.x), 0, terrain.w - 1), clampi(int(q.y), 0, terrain.h - 1))
		if terrain.is_solid(qi.x, qi.y):
			debris_cols.append(terrain.img.get_pixelv(qi * terrain.ss + Vector2i(terrain.pp, terrain.pp)))
	terrain.carve(pos, radius)
	if radius >= 14.0:
		sfx("boom", lerpf(-8.0, 2.0, clampf((radius - 14.0) / 32.0, 0.0, 1.0)), 1.0 - clampf(radius / 140.0, 0.0, 0.3), pos)
	elif radius >= 6.0:
		sfx("boom_small", -8.0, 1.0, pos)

	var reach := radius + 12.0
	for w in worms:
		if not w.alive:
			continue
		var dist: float = w.pos.distance_to(pos)
		if dist < reach:
			var f := 1.0 - dist / reach
			var dir: Vector2 = (w.pos - pos).normalized() if dist > 0.5 else Vector2.UP
			w.vel += dir * knock * f + Vector2(0, -knock * 0.25 * f)
			w.on_ground = false
			damage_worm(w, dmg * f, owner, dir)
	for pr in projectiles:
		if pr.alive and float(pr.def["bounce"]) > 0.0:
			var dist: float = pr.pos.distance_to(pos)
			if dist < reach and dist > 0.5:
				pr.vel += (pr.pos - pos).normalized() * knock * (1.0 - dist / reach)
	for c in crates:
		var dist: float = c.pos.distance_to(pos)
		if dist < reach and dist > 0.5:
			c.vel += (c.pos - pos).normalized() * knock * 0.6 * (1.0 - dist / reach)

	# effects
	var big := radius >= 10.0
	flashes.append([pos, radius * 1.3, 0.16, 0.16])
	if big:
		rings.append([pos, radius * 1.6, 0.3, 0.3])
	var nfire := int(clampf(radius * 1.8, 4, 52))
	for i in nfire:
		particles.append([pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * radius * 0.5,
			Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10, 30 + radius * 2.5) + Vector2(0, -20),
			rng.randf_range(0.2, 0.5), Color(1.0, rng.randf_range(0.45, 0.85), 0.15), rng.randf_range(2.0, 4.0) * (radius / 16.0 + 0.4), P_FIRE, 0.5])
	var nsmoke := int(clampf(radius * 1.0, 2, 28))
	for i in nsmoke:
		var g := rng.randf_range(0.18, 0.35)
		particles.append([pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * radius * 0.6,
			Vector2(rng.randf_range(-15, 15), rng.randf_range(-30, -8)),
			rng.randf_range(0.8, 1.6), Color(g, g, g, 0.55), rng.randf_range(3.0, 6.0) * (radius / 16.0 + 0.3), P_SMOKE, 1.6])
	var ndeb := int(clampf(radius * 1.6, 6, 60))
	for i in ndeb:
		var col: Color = Color(1.0, rng.randf_range(0.5, 0.9), 0.3)
		var kind := P_SPARK
		if debris_cols.size() > 0 and rng.randf() < 0.7:
			col = debris_cols[rng.randi() % debris_cols.size()]
			kind = P_DEBRIS
		particles.append([pos, Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(40, 60 + radius * 6),
			rng.randf_range(0.4, 1.0), col, rng.randf_range(1.0, 2.0), kind, 1.0])
	if player and pos.distance_to(player.pos) < 400.0:
		shake = minf(shake + radius * 0.14, 7.0)


func damage_worm(w: LWorm, amount: float, by: LWorm, dir := Vector2.UP) -> void:
	if not w.alive or amount <= 0.0:
		return
	w.hp -= amount
	if amount >= 10.0:
		sfx("splat", -10.0, 1.2, w.pos)
	var drops := int(clampf(amount * 2.4, 5, 75))
	if blood.size() > 1100:
		drops = mini(drops, 4)
	bleed(w.pos, dir, drops, 60.0 + amount * 4.0)
	if by != null:
		w.last_hit_by = by
	if amount >= 8.0:
		texts.append([w.pos + Vector2(rng.randf_range(-4, 4), -14), "-%d" % int(round(amount)), 0.9, Color(1, 0.4, 0.35)])
	if w.hp <= 0.0:
		_kill(w)


func _kill(w: LWorm) -> void:
	w.alive = false
	w.hp = 0.0
	w.deaths += 1
	w.respawn = 3.0
	w.hook_state = 0
	var k := w.last_hit_by
	if k != null and k != w:
		k.kills += 1
		feed.append([k.name + " fragged " + w.name, 5.0, k.color])
	else:
		w.kills -= 1
		feed.append([w.name + " blew himself up", 5.0, w.color])
	if feed.size() > 5:
		feed.pop_front()
	sfx("squeak", -4.0, 1.0, w.pos)
	sfx("splat", 0.0, 0.8, w.pos)
	# gore: lots of blood, guts, bones and an eyeball
	bleed(w.pos, Vector2.UP, 210, 280.0)
	emitters.append([w.pos, 1.2])
	var parts := ["gib_meat", "gib_meat", "gib_meat", "gib_bone", "gib_bone", "gib_eye", "gib_meat", "gib_bone",
		"gib_meat", "gib_meat", "gib_meat", "gib_bone", "gib_bone", "gib_eye", "gib_meat", "gib_bone"]
	for id in parts:
		gibs.append([w.pos + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)),
			Vector2.from_angle(rng.randf_range(-PI, 0.0)) * rng.randf_range(90, 240),
			rng.randf() * TAU, rng.randf_range(-12, 12), rng.randf_range(7.0, 10.0), id])
	if gibs.size() > 160:
		gibs = gibs.slice(gibs.size() - 160)
	flashes.append([w.pos, 14.0, 0.15, 0.15])
	rings.append([w.pos, 22.0, 0.35, 0.35])
	if k != null and k.kills >= Cfg.kill_limit and not demo:
		game_over = true
		winner = k


# ---------------- weapon pickups ----------------

func _spawn_crate() -> void:
	var c := LCrate.new()
	c.pos = terrain.find_spawn(rng) + Vector2(0, -6)
	c.kind = "health" if rng.randf() < 0.22 else Weapons.TOP[rng.randi() % Weapons.TOP.size()]
	crates.append(c)
	rings.append([c.pos, 16.0, 0.5, 0.5])


func _pickup(w: LWorm, c: LCrate) -> void:
	c.alive = false
	var col: Color = GLOW.get(c.kind, Color.WHITE)
	rings.append([c.pos, 18.0, 0.35, 0.35])
	if w == player:
		sfx("pickup", -2.0)
	if c.kind == "health":
		w.hp = minf(LWorm.MAX_HP, w.hp + 40.0)
		texts.append([c.pos + Vector2(0, -10), "+40 HP", 1.4, Color(0.5, 1.0, 0.5)])
		if w == player:
			toast = ["+40 HP", 2.0]
	else:
		w.add_weapon(c.kind)
		# auto-equip what you just picked up
		for i in w.weapons.size():
			if w.weapons[i]["id"] == c.kind:
				w.cur = i
		var wname: String = Weapons.LIST[c.kind]["name"]
		texts.append([c.pos + Vector2(0, -10), wname, 1.4, col])
		if w == player:
			toast = ["Got %s!  [%d]" % [wname, w.cur + 1], 2.5]


# ---------------- effects ----------------

## Sprays blood droplets. They fly, then paint the ground where they land.
func bleed(pos: Vector2, dir: Vector2, count: int, speed: float) -> void:
	for i in count:
		var a := dir.angle() + rng.randf_range(-1.3, 1.3)
		blood.append([pos + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)),
			Vector2.from_angle(a) * rng.randf_range(speed * 0.25, speed) + Vector2(0, -40),
			rng.randf_range(1.0, 2.5), rng.randf_range(0.8, 1.8)])
	if blood.size() > 2200:
		blood = blood.slice(blood.size() - 2200)


func _update_gore(dt: float) -> void:
	for e in emitters:
		e[1] -= dt
		for k in 6:
			blood.append([e[0] + Vector2(rng.randf_range(-2, 2), -2), Vector2(rng.randf_range(-60, 60), rng.randf_range(-260, -120)),
				2.0, rng.randf_range(1.0, 2.0)])
	emitters = emitters.filter(func(e): return e[1] > 0.0)

	var keep: Array = []
	for b in blood:
		b[1].y += 420.0 * dt
		var np: Vector2 = b[0] + b[1] * dt
		b[2] -= dt
		if terrain.is_solid_v(np):
			terrain.stain(np, b[3] + 0.8, Color(0.62, 0.02, 0.08, 0.8))
			continue
		b[0] = np
		if b[2] > 0.0:
			keep.append(b)
	blood = keep

	for g in gibs:
		g[1].y += 420.0 * dt
		var np: Vector2 = g[0] + g[1] * dt
		if terrain.is_solid_v(np):
			if terrain.is_solid_v(Vector2(np.x, g[0].y)):
				g[1].x *= -0.4
			if terrain.is_solid_v(Vector2(g[0].x, np.y)):
				if absf(g[1].y) > 60.0:
					terrain.stain(np, 2.5, Color(0.6, 0.02, 0.08, 0.85))
				g[1].y *= -0.35
				g[1].x *= 0.7
			g[3] *= 0.6
		else:
			g[0] = np
			if g[1].length() > 120.0 and rng.randf() < 0.3:
				blood.append([g[0], g[1] * 0.2, 0.8, 1.0])
		g[2] += g[3] * dt
		g[4] -= dt
	gibs = gibs.filter(func(g): return g[4] > 0.0)


func _update_effects(dt: float) -> void:
	for pt in particles:
		match pt[5]:
			P_DEBRIS, P_SPARK:
				pt[1].y += 300.0 * dt
				var np: Vector2 = pt[0] + pt[1] * dt
				if pt[5] == P_DEBRIS and terrain.is_solid_v(np):
					pt[1] *= -0.3
				else:
					pt[0] = np
			P_SMOKE:
				pt[1] *= 1.0 - 1.5 * dt
				pt[1].y -= 10.0 * dt
				pt[0] += pt[1] * dt
				pt[4] += 4.0 * dt
			P_FIRE:
				pt[1] *= 1.0 - 4.0 * dt
				pt[1].y -= 30.0 * dt
				pt[0] += pt[1] * dt
		pt[2] -= dt
	particles = particles.filter(func(pt): return pt[2] > 0.0)
	if particles.size() > 2200:
		particles = particles.slice(particles.size() - 2200)
	for f in flashes:
		f[2] -= dt
	flashes = flashes.filter(func(f): return f[2] > 0.0)
	for r in rings:
		r[2] -= dt
	rings = rings.filter(func(r): return r[2] > 0.0)
	for b in beams:
		b[2] -= dt
	beams = beams.filter(func(b): return b[2] > 0.0)
	for t in texts:
		t[0].y -= 14.0 * dt
		t[2] -= dt
	texts = texts.filter(func(t): return t[2] > 0.0)
	for f in feed:
		f[1] -= dt
	feed = feed.filter(func(f): return f[1] > 0.0)
	toast[1] = maxf(0.0, toast[1] - dt)


func _process(delta: float) -> void:
	if terrain == null:
		return
	var follow: LWorm = player
	if demo:
		_demo_t -= delta
		if _demo_t <= 0.0:
			_demo_t = 6.0
			_demo_target = rng.randi() % worms.size()
		follow = worms[_demo_target]
	elif not player.alive and player.last_hit_by != null and player.last_hit_by.alive:
		follow = player.last_hit_by
	var target := follow.pos
	if follow == player and mouse_aim and player.alive and not demo:
		target += (get_global_mouse_position() - player.pos) * 0.15
	cam.position = cam.position.lerp(target, 1.0 - exp(-(2.0 if demo else 8.0) * delta))
	shake = maxf(0.0, shake - 20.0 * delta)
	cam.offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	if OS.get_environment("L2_NODRAW") == "":
		drawer.queue_redraw()
		glow.queue_redraw()
		labels.queue_redraw()
