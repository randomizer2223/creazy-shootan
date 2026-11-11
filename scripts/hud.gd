extends CanvasLayer
## On-screen UI in a soft cartoon style: health, weapon bar, scoreboard, kill feed, hints.

const INK := Color(0.23, 0.14, 0.13)
const CREAM := Color(1.0, 0.96, 0.86)
const ACCENT := Color(1.0, 0.45, 0.6)
const SUN := Color(1.0, 0.85, 0.45)

var game
var panel: Control
var font: Font
var _box_cache := {}
var _fps_t := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	panel = Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	panel.draw.connect(_draw_hud)
	add_child(panel)


func _process(d: float) -> void:
	# the HUD doesn't need 60 redraws a second; 20 is plenty and saves a lot of CPU
	_fps_t -= d
	if _fps_t <= 0.0:
		_fps_t = 0.05
		panel.queue_redraw()


func _box(r: Rect2, bg := CREAM, radius := 16, border := 4) -> void:
	var key := "%s_%d_%d" % [bg.to_html(), radius, border]
	if not _box_cache.has(key):
		_box_cache[key] = Cfg.round_box(bg, INK, border, radius, 5)
	panel.draw_style_box(_box_cache[key], r)


func _text(pos: Vector2, s: String, size: int, col: Color, outline := 0) -> void:
	if outline > 0:
		panel.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(INK, col.a))
	panel.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_c(cx: float, y: float, s: String, size: int, col: Color, outline := 0) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(Vector2(roundf(cx - w / 2.0), y), s, size, col, outline)


func _draw_hud() -> void:
	if game == null or game.player == null:
		return
	var p: LWorm = game.player
	var size := panel.size

	# ---- player card ----
	_box(Rect2(16, 16, 290, 78))
	Sprites.draw_critter(panel, Vector2(56, 58), 2.6, p.color, 1, Vector2(1, 0), 0.0, false, p.accessory, false)
	_text(Vector2(96, 46), "You", 22, INK)
	_text(Vector2(200, 46), "%d HP" % ceili(maxf(p.hp, 0.0)), 20, INK)
	var hpf := clampf(p.hp / LWorm.MAX_HP, 0.0, 1.0)
	var bar := Rect2(96, 58, 190, 20)
	_box(bar, Color(0.95, 0.88, 0.8), 10, 3)
	if hpf > 0.0:
		_box(Rect2(bar.position, Vector2(maxf(bar.size.x * hpf, 22), bar.size.y)), Color("ff5c7a").lerp(Color("7ee081"), hpf), 10, 3)

	# ---- weapon bar (top left, under the player card) ----
	var n := p.weapons.size()
	var slot := 44.0
	var gap := 6.0
	var bx := 16.0
	var by := 128.0
	var cur_def: Dictionary = Weapons.LIST[p.current_weapon_id()]
	_text(Vector2(bx + 2, by - 10.0), cur_def["name"], 20, Color.WHITE, 7)
	for i in n:
		var wpn: Dictionary = p.weapons[i]
		var sel := i == p.cur
		var r := Rect2(bx + i * (slot + gap), by + (0.0 if sel else 4.0), slot, slot)
		var top := Weapons.is_top(wpn["id"])
		_box(r, SUN if sel else (Color("ffd6e4") if top else CREAM), 10, 3)
		panel.draw_texture_rect(Sprites.icon(wpn["id"]), Rect2(r.position + Vector2(5, 5), Vector2(34, 34)), false,
			Color(1, 1, 1, 1.0 if sel else 0.75))
		if sel:
			var cdf := p.cooldown_frac()
			if cdf > 0.0:
				panel.draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(slot - 6, (slot - 6) * cdf)), Color(INK, 0.35))
		_text(r.position + Vector2(5, 14), str(i + 1), 12, INK)
		if wpn["ammo"] >= 0:
			var am := "x%d" % wpn["ammo"]
			var aw := font.get_string_size(am, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			_text(r.position + Vector2(slot - aw - 4, slot - 5), am, 12, Color.WHITE, 4)
	_text(Vector2(bx + 2, by + slot + 24.0), "Switch weapon: mouse wheel  •  Q / E  •  1-9", 13, Color.WHITE, 4)

	# ---- scoreboard ----
	var sorted: Array = game.worms.duplicate()
	sorted.sort_custom(func(a, b): return a.kills > b.kills)
	var sw := 270.0
	var sx := size.x - sw - 16.0
	_box(Rect2(sx, 16, sw, 46 + sorted.size() * 26))
	_text(Vector2(sx + 16, 40), "First to %d  •  %s" % [Cfg.kill_limit, game.map_name], 14, Color(INK, 0.7))
	var yy := 66.0
	for w in sorted:
		panel.draw_circle(Vector2(sx + 24, yy - 6), 7, INK, true, -1.0, true)
		panel.draw_circle(Vector2(sx + 24, yy - 6), 5, w.color, true, -1.0, true)
		var nc := INK if w.alive else Color(INK, 0.4)
		_text(Vector2(sx + 40, yy), w.name, 18, nc)
		_text(Vector2(sx + sw - 64, yy), "%d / %d" % [w.kills, w.deaths], 18, nc)
		yy += 26.0

	# ---- kill feed ----
	var fy := 40.0
	for f in game.feed:
		var c: Color = f[2]
		c.a = clampf(f[1], 0.0, 1.0)
		_text_c(size.x / 2.0, fy, f[0], 20, c.lightened(0.2), 6)
		fy += 28.0

	# ---- pickup toast ----
	if game.toast[1] > 0.0:
		var a := clampf(game.toast[1], 0.0, 1.0)
		_text_c(size.x / 2.0, size.y - 90.0, game.toast[0], 30, Color(1, 1, 1, a), 9)

	# ---- center messages ----
	var center := size / 2.0
	if not p.alive and not game.game_over:
		_text_c(center.x, center.y - 70, "Respawn in %.1f" % maxf(p.respawn, 0.0), 40, Color.WHITE, 10)
	if game.paused:
		panel.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
		_text_c(center.x, center.y, "Paused", 64, SUN, 14)
		_text_c(center.x, center.y + 48, "Enter — resume     Esc — menu", 22, Color.WHITE, 6)
	if game.game_over:
		panel.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
		var wn: String = game.winner.name if game.winner else "?"
		_text_c(center.x, center.y - 10, wn + " wins!", 64, game.winner.color if game.winner else Color.WHITE, 14)
		_text_c(center.x, center.y + 44, "Press Enter", 22, Color.WHITE, 6)

	# ---- controls help (auto-hides, H toggles) ----
	var left: float = game.help_until - game.time
	if left > 0.0:
		var lines := [
			"A / D  move      W / Space  jump      S  dig",
			"Mouse  aim      Left click  fire",
			"Right click  rope   (W / S  shorter / longer)",
			"Esc  pause      H  help      F3  FPS",
		]
		var a := clampf(left, 0.0, 1.0)
		var ly := by + slot + 64.0
		_box(Rect2(16, ly - 22, 360, lines.size() * 19 + 16), Color(CREAM, 0.92 * a), 12, 3)
		for l in lines:
			_text(Vector2(28, ly), l, 14, Color(INK, a))
			ly += 19.0

	if game.show_fps:
		_text(Vector2(size.x / 2.0 - 40, size.y - 12), "FPS %d" % Engine.get_frames_per_second(), 18, Color.WHITE, 5)
