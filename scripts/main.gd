extends Node
## Точка входу: перемикає меню та гру.

var menu: Control
var game: Node2D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		_selftest()
		return
	for a in args:
		if a == "--perf":
			_perf()
			return
		if a.begins_with("--shot="):
			_shot(int(a.get_slice("=", 1)))
			return
	show_menu()


func show_menu() -> void:
	if game:
		game.queue_free()
		game = null
	_start_demo()
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.name = "MenuLayer"
	add_child(layer)
	menu = preload("res://scripts/menu.gd").new()
	layer.add_child(menu)
	menu.start_pressed.connect(start_game)
	menu.map_changed.connect(_on_map_changed)


var demo: Node2D
var _demo_gen := 0


## Bot battle on the selected map, shown behind the menu.
func _start_demo() -> void:
	if demo:
		demo.queue_free()
		demo = null
	var keep := Cfg.bot_count
	Cfg.bot_count = 4
	demo = preload("res://scripts/game.gd").new()
	demo.demo = true
	add_child(demo)
	move_child(demo, 0)
	demo.start()
	Cfg.bot_count = keep


func _on_map_changed() -> void:
	_demo_gen += 1
	var my := _demo_gen
	await get_tree().create_timer(0.35).timeout
	if my == _demo_gen and menu != null:
		_start_demo()


func start_game() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if demo:
		demo.queue_free()
		demo = null
	menu.get_parent().queue_free()
	menu = null
	game = preload("res://scripts/game.gd").new()
	add_child(game)
	game.exit_to_menu.connect(show_menu, CONNECT_DEFERRED)
	game.start()


## Автотест без вікна: генерує всі мапи і проганяє бій ботів.
func _selftest() -> void:
	var t0 := Time.get_ticks_msec()
	for i in MapGen.PRESETS.size():
		var s := Time.get_ticks_msec()
		var d := MapGen.build(i)
		var solid := 0
		var m: PackedByteArray = d["mask"]
		for k in range(0, m.size(), 97):
			solid += m[k]
		print("map %d %s: %d ms, solid %.0f%%" % [i, MapGen.PRESETS[i]["name"], Time.get_ticks_msec() - s,
			100.0 * solid / (m.size() / 97.0)])
	var photo := Image.create(900, 600, false, Image.FORMAT_RGBA8)
	photo.fill(Color(0.3, 0.6, 0.2))
	var s2 := Time.get_ticks_msec()
	var dc := MapGen.from_image(photo)
	print("custom image map: %d ms, size %s" % [Time.get_ticks_msec() - s2, dc["fg"].get_size()])

	Cfg.bot_count = 5
	Cfg.reload_mode = 2
	Cfg.map_index = 1
	Cfg.kill_limit = 999
	game = preload("res://scripts/game.gd").new()
	game.headless_test = true
	add_child(game)
	game.start()
	var frames := 60 * 60
	var s3 := Time.get_ticks_msec()
	for f in frames:
		game._physics_process(1.0 / 60.0)
		if f % 600 == 0:
			game.terrain._process(0.0)
			var line := "t=%ds shots=%d |" % [f / 60, game.shots]
			for w in game.worms:
				line += " %s(%d,%d)%s" % [w.name.substr(0, 6), int(w.pos.x), int(w.pos.y), "R" if w.hook_state == 2 else ""]
			print(line)
	var el := Time.get_ticks_msec() - s3
	print("simulated %d frames in %d ms (%.2f ms/frame)" % [frames, el, float(el) / frames])
	for w in game.worms:
		print("  %s kills %d deaths %d hp %.0f weapons %d" % [w.name, w.kills, w.deaths, w.hp, w.weapons.size()])
	print("projectiles %d crates %d particles %d" % [game.projectiles.size(), game.crates.size(), game.particles.size()])
	print("selftest total %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit()


## Скріншот мапи для перевірки: --shot=<номер мапи>  (-1 = меню)
func _shot(idx: int) -> void:
	if idx < 0:
		show_menu()
	else:
		Cfg.map_index = idx
		Cfg.bot_count = 5
		Cfg.reload_mode = 1
		game = preload("res://scripts/game.gd").new()
		game.headless_test = true
		add_child(game)
		game.start()
	await get_tree().create_timer(5.0).timeout
	print("FPS: ", Engine.get_frames_per_second())
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/shot_%d.png" % idx)
	if game:
		game.cam.zoom = Vector2(1280.0 / game.terrain.w, 720.0 / game.terrain.h)
		game.cam.position = Vector2(game.terrain.w, game.terrain.h) / 2.0
		game.cam.position_smoothing_enabled = false
		game.set_process(false)
		game.cam.offset = Vector2.ZERO
		game.drawer.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/shot_%d_full.png" % idx)
	get_tree().quit()


## CPU timing without a GPU: --perf
func _perf() -> void:
	Cfg.map_index = 1
	Cfg.bot_count = 7
	Cfg.reload_mode = 1
	game = preload("res://scripts/game.gd").new()
	game.headless_test = true
	add_child(game)
	game.start()
	var only := OS.get_environment("L2_ONLY")
	if only != "":
		for w in game.worms:
			w.weapons = [{"id": only, "ammo": 99999}]
			w.cur = 0
	var proc := 0.0
	var phys := 0.0
	var n := 0
	var t0 := Time.get_ticks_msec()
	var maxf_ := 0
	while Time.get_ticks_msec() - t0 < 12000:
		await get_tree().process_frame
		if only != "" and Engine.get_process_frames() % 10 == 0:
			var w0: LWorm = game.worms[0]
			w0.aim = randf_range(-PI, 0)
			game.fire_weapon(w0, only)
		var fc := 0
		for q in game.projectiles:
			if q.wid == "fire":
				fc += 1
		maxf_ = maxi(maxf_, fc)
		if Time.get_ticks_msec() - t0 > 2000:
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			n += 1
	print("max fires alive: ", maxf_, " shots ", game.shots)
	print("frames %d  fps %d  process %.2f ms  physics %.2f ms  particles %d blood %d projectiles %d fires %d" % [n, Engine.get_frames_per_second(),
		proc / n * 1000.0, phys / n * 1000.0, game.particles.size(), game.blood.size(), game.projectiles.size(), game.fire_count])
	get_tree().quit()
