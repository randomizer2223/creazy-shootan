extends CanvasLayer
## On-screen controls for phones and tablets.
## Left half: floating stick to walk (push up to jump, up/down on the rope to climb).
## Right half: floating stick to aim; push it far to fire.
## Buttons: JUMP, ROPE, DIG, pause. Tap a weapon slot (top left) to switch weapon.

const STICK_R := 95.0
const INK := Color(0.23, 0.14, 0.13)
const CREAM := Color(1.0, 0.96, 0.86)

var game
var ui: Control
var font: Font
var active := false

var touches := {}  # index -> {"role": String, "origin": Vector2, "pos": Vector2}
var move_vec := Vector2.ZERO
var aim_vec := Vector2.ZERO
var aim_angle := 0.0
var aim_set := false
var fire := false
var jump := false
var rope := false
var dig := false
var slot := -1


func _ready() -> void:
	layer = 6
	font = ThemeDB.fallback_font
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.draw.connect(_draw_ui)
	add_child(ui)
	active = DisplayServer.is_touchscreen_available()


func _process(_d: float) -> void:
	if active:
		ui.queue_redraw()


func _buttons() -> Dictionary:
	var s := ui.size
	return {
		"jump": [Vector2(s.x - 330, s.y - 86), 56.0, "JUMP"],
		"rope": [Vector2(s.x - 310, s.y - 236), 50.0, "ROPE"],
		"dig": [Vector2(s.x - 170, s.y - 330), 42.0, "DIG"],
		"pause": [Vector2(s.x / 2.0, 34), 26.0, "II"],
	}


func _pause_buttons() -> Dictionary:
	var c := ui.size / 2.0
	return {"resume": Rect2(c.x - 150, c.y + 70, 300, 70), "menu": Rect2(c.x - 150, c.y + 156, 300, 70)}


func _input(event: InputEvent) -> void:
	if game == null or game.player == null:
		return
	if event is InputEventScreenTouch:
		active = true
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		if touches.has(event.index):
			touches[event.index]["pos"] = event.position
			_update(event.index)


func _press(i: int, p: Vector2) -> void:
	if game.game_over:
		game.exit_to_menu.emit()
		return
	if game.paused:
		var pb := _pause_buttons()
		if pb["resume"].has_point(p):
			game.paused = false
		elif pb["menu"].has_point(p):
			game.exit_to_menu.emit()
		return
	if game.hud:
		var hs: int = game.hud.slot_at(p)
		if hs >= 0:
			slot = hs
			return
	var b := _buttons()
	for key in b:
		if p.distance_to(b[key][0]) <= float(b[key][1]) * 1.25:
			if key == "pause":
				game.paused = true
				return
			touches[i] = {"role": key, "origin": p, "pos": p}
			set(key, true)
			return
	var role := "move" if p.x < ui.size.x * 0.5 else "aim"
	touches[i] = {"role": role, "origin": p, "pos": p}
	_update(i)


func _release(i: int) -> void:
	if not touches.has(i):
		return
	var role: String = touches[i]["role"]
	touches.erase(i)
	match role:
		"move":
			move_vec = Vector2.ZERO
		"aim":
			aim_vec = Vector2.ZERO
			fire = false
		_:
			set(role, false)


func _update(i: int) -> void:
	var t: Dictionary = touches[i]
	var v: Vector2 = (t["pos"] - t["origin"]) / STICK_R
	if v.length() > 1.0:
		v = v.normalized()
	if t["role"] == "move":
		move_vec = v
	elif t["role"] == "aim":
		aim_vec = v
		if v.length() > 0.2:
			aim_angle = v.angle()
			aim_set = true
		fire = v.length() > 0.6


## Builds the player's input from the touch state.
func fill_input(inp: Dictionary, w: LWorm) -> void:
	inp["move"] = -1 if move_vec.x < -0.35 else (1 if move_vec.x > 0.35 else 0)
	var on_rope := w.hook_state == 2
	if on_rope:
		inp["rope_dir"] = -1 if move_vec.y < -0.5 else (1 if move_vec.y > 0.5 else 0)
		inp["jump"] = jump
	else:
		inp["jump"] = jump or move_vec.y < -0.7
	inp["fire"] = fire
	inp["rope"] = rope
	inp["dig"] = dig
	inp["aim"] = aim_angle if aim_set else w.aim
	if slot >= 0:
		inp["slot"] = slot
		slot = -1


func _draw_ui() -> void:
	if not active or game == null:
		return
	var s := ui.size
	if game.paused:
		var pb := _pause_buttons()
		_pill(pb["resume"], "Resume", Color(1.0, 0.85, 0.45))
		_pill(pb["menu"], "Menu", Color(1.0, 0.45, 0.6))
		return
	if game.game_over:
		return
	# sticks: show a faint hint where they live, the real one where the finger is
	var have_move := false
	var have_aim := false
	for t in touches.values():
		if t["role"] == "move" or t["role"] == "aim":
			var o: Vector2 = t["origin"]
			var k: Vector2 = o + ((t["pos"] - o) as Vector2).limit_length(STICK_R)
			_stick(o, k, 0.9)
			if t["role"] == "move":
				have_move = true
			else:
				have_aim = true
	if not have_move:
		_stick(Vector2(150, s.y - 150), Vector2(150, s.y - 150), 0.35, "MOVE")
	if not have_aim:
		_stick(Vector2(s.x - 150, s.y - 150), Vector2(s.x - 150, s.y - 150), 0.35, "AIM + FIRE")
	var b := _buttons()
	for key in b:
		var c: Vector2 = b[key][0]
		var r: float = b[key][1]
		var held: bool = get(key) if key != "pause" else false
		ui.draw_circle(c, r + 4, Color(INK, 0.75), true, -1.0, true)
		ui.draw_circle(c, r, Color(1.0, 0.85, 0.45, 0.95) if held else Color(CREAM, 0.8), true, -1.0, true)
		var label: String = b[key][2]
		var fs := 22 if key != "pause" else 20
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ui.draw_string(font, c + Vector2(-tw / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)


func _stick(base: Vector2, knob: Vector2, alpha: float, label := "") -> void:
	ui.draw_circle(base, STICK_R, Color(INK, 0.25 * alpha), true, -1.0, true)
	ui.draw_arc(base, STICK_R, 0.0, TAU, 48, Color(CREAM, 0.6 * alpha), 4.0, true)
	ui.draw_circle(knob, 40, Color(INK, 0.6 * alpha), true, -1.0, true)
	ui.draw_circle(knob, 36, Color(CREAM, 0.85 * alpha), true, -1.0, true)
	if label != "":
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		ui.draw_string(font, base + Vector2(-tw / 2.0, STICK_R + 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.8))


func _pill(r: Rect2, label: String, col: Color) -> void:
	ui.draw_style_box(Cfg.round_box(col, INK, 5, 30, 6), r)
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	ui.draw_string(font, r.get_center() + Vector2(-tw / 2.0, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, INK)
