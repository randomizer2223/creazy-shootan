extends Control
## Main menu. A live bot battle on the selected map plays behind it.

signal start_pressed
signal map_changed

const ACCENT := Color(0.89, 0.33, 0.48)
const INK := Color(0.23, 0.14, 0.13)

var sel := {}  # selector name -> {"options": Array, "index": int, "label": Label}
var status: Label
var preview: TextureRect
var file_dialog: FileDialog
var _waiting_web := false
var _bg: Control
var _t := 0.0
var touch := DisplayServer.is_touchscreen_available()  # phone/tablet: bigger buttons


func _ready() -> void:
	theme = Cfg.ui_theme
	_fit()
	get_viewport().size_changed.connect(_fit)

	# darken the left side so the panel reads well over the demo battle
	# light background: soft sky, rolling hills and a few critters bobbing about
	var shade := Control.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(_draw_bg.bind(shade))
	add_child(shade)
	_bg = shade

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_top", 16 if touch else 40)
	margin.add_theme_constant_override("margin_bottom", 16 if touch else 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(580 if touch else 460, 0)
	col.add_theme_constant_override("separation", 8 if touch else 12)
	margin.add_child(col)

	var title := Label.new()
	title.text = "Creazy Shootan!"
	title.add_theme_font_size_override("font_size", 60 if touch else 76)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	title.add_theme_constant_override("shadow_offset_y", 8)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Cute critters. Big explosions."
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color.WHITE)
	sub.add_theme_color_override("font_outline_color", INK)
	sub.add_theme_constant_override("outline_size", 9)
	col.add_child(sub)
	sub.visible = not touch
	col.add_child(_spacer(4 if touch else 10))

	var panel := PanelContainer.new()
	col.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6 if touch else 10)
	panel.add_child(box)

	var maps: Array = []
	for n in MapGen.preset_names():
		maps.append(n)
	maps.append("Custom image")
	var map_idx := Cfg.map_index if Cfg.map_index >= 0 else maps.size() - 1
	box.add_child(_selector("map", "MAP", maps, map_idx))
	var bots := []
	for i in 8:
		bots.append(str(i))
	box.add_child(_selector("bots", "BOTS", bots, Cfg.bot_count))
	var diffs := []
	for d in Cfg.DIFFICULTIES:
		diffs.append(d["name"])
	box.add_child(_selector("diff", "BOT SKILL", diffs, Cfg.bot_difficulty))
	var reloads := []
	for m in Cfg.RELOAD_MODES:
		reloads.append(m["name"])
	box.add_child(_selector("reload", "RELOAD", reloads, Cfg.reload_mode))
	var kills := ["3", "5", "10", "15", "20", "30", "50"]
	box.add_child(_selector("kills", "KILLS TO WIN", kills, maxi(kills.find(str(Cfg.kill_limit)), 2)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var up := Button.new()
	up.text = "Upload image as map"
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up.pressed.connect(_on_upload)
	row.add_child(up)
	var fs := Button.new()
	fs.text = "Fullscreen"
	fs.pressed.connect(_toggle_fullscreen)
	row.add_child(fs)
	if touch:
		up.custom_minimum_size = Vector2(0, 56)
		fs.custom_minimum_size = Vector2(0, 56)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(0, 80)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.visible = Cfg.custom_map != null
	if Cfg.custom_map:
		preview.texture = ImageTexture.create_from_image(Cfg.custom_map)
	box.add_child(preview)

	var start := Button.new()
	start.text = "Play!"
	start.custom_minimum_size = Vector2(0, 84 if touch else 72)
	start.add_theme_font_size_override("font_size", 40)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		start.add_theme_color_override(c, Color.WHITE)
	start.add_theme_color_override("font_outline_color", INK)
	start.add_theme_constant_override("outline_size", 10)
	start.add_theme_stylebox_override("normal", Cfg.round_box(Color(1.0, 0.45, 0.6), INK, 5, 24, 8))
	start.add_theme_stylebox_override("hover", Cfg.round_box(Color(1.0, 0.58, 0.7), INK, 5, 24, 8))
	start.add_theme_stylebox_override("pressed", Cfg.round_box(Color(0.9, 0.38, 0.52), INK, 5, 24, 2))
	start.pressed.connect(_on_start)
	col.add_child(start)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	status.add_theme_color_override("font_color", Color.WHITE)
	status.add_theme_color_override("font_outline_color", INK)
	status.add_theme_constant_override("outline_size", 8)
	col.add_child(status)
	start.grab_focus()

	var ver := Label.new()
	ver.text = "prototype 0.5"
	if OS.has_feature("web"):
		var ms = JavaScriptBridge.eval("Math.round(performance.now())", true)
		if typeof(ms) in [TYPE_INT, TYPE_FLOAT]:
			ver.text += "  •  ready in %.1f s" % (float(ms) / 1000.0)
	ver.add_theme_font_size_override("font_size", 16)
	ver.add_theme_color_override("font_color", Color(INK, 0.75))
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(ver)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 14)


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _selector(key: String, label: String, options: Array, index: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(190 if touch else 170, 0)
	if touch:
		l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color(INK, 0.75))
	h.add_child(l)
	var left := Button.new()
	left.text = "<"
	left.custom_minimum_size = Vector2(70, 56) if touch else Vector2(44, 40)
	h.add_child(left)
	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.add_theme_color_override("font_color", ACCENT)
	if touch:
		val.add_theme_font_size_override("font_size", 24)
	h.add_child(val)
	var right := Button.new()
	right.text = ">"
	right.custom_minimum_size = Vector2(70, 56) if touch else Vector2(44, 40)
	h.add_child(right)
	sel[key] = {"options": options, "index": clampi(index, 0, options.size() - 1), "label": val}
	val.text = options[sel[key]["index"]]
	left.pressed.connect(_step.bind(key, -1))
	right.pressed.connect(_step.bind(key, 1))
	return h


func _step(key: String, d: int) -> void:
	var s: Dictionary = sel[key]
	var n: int = s["options"].size()
	s["index"] = (s["index"] + d + n) % n
	s["label"].text = s["options"][s["index"]]
	if key == "map":
		_apply_map()


func _apply_map() -> bool:
	var idx: int = sel["map"]["index"]
	if idx >= MapGen.PRESETS.size():
		if Cfg.custom_map == null:
			status.text = "Upload an image first"
			return false
		Cfg.map_index = -1
	else:
		Cfg.map_index = idx
	status.text = ""
	map_changed.emit()
	return true


func _on_start() -> void:
	var idx: int = sel["map"]["index"]
	if idx >= MapGen.PRESETS.size():
		if Cfg.custom_map == null:
			status.text = "Upload an image first"
			return
		Cfg.map_index = -1
	else:
		Cfg.map_index = idx
	Cfg.bot_count = sel["bots"]["index"]
	Cfg.bot_difficulty = sel["diff"]["index"]
	Cfg.reload_mode = sel["reload"]["index"]
	Cfg.kill_limit = int(sel["kills"]["options"][sel["kills"]["index"]])
	status.text = "Making the map..."
	start_pressed.emit()


# ---------- image upload ----------

func _on_upload() -> void:
	if OS.has_feature("web"):
		WebUpload.open_picker()
		_waiting_web = true
		status.text = "Choose an image (PNG, JPG, WEBP)"
	else:
		if file_dialog == null:
			file_dialog = FileDialog.new()
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.access = FileDialog.ACCESS_FILESYSTEM
			file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
			file_dialog.file_selected.connect(_on_file_selected)
			add_child(file_dialog)
		file_dialog.popup_centered(Vector2i(800, 500))


func _on_file_selected(path: String) -> void:
	_set_custom(Image.load_from_file(path))


const BG_CRITTERS := [
	[Vector2(0.62, 0.78), Color(1.0, 0.55, 0.7), 0], [Vector2(0.75, 0.70), Color(0.45, 0.75, 1.0), 1],
	[Vector2(0.88, 0.80), Color(0.6, 1.0, 0.45), 2],
]


var _live := false


## true when the live bot battle is running behind the menu
func set_live(on: bool) -> void:
	_live = on
	if _bg:
		_bg.queue_redraw()


func _draw_bg(c: Control) -> void:
	var s := c.size
	if _live:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(0.1, 0.05, 0.12, 0.25))
		return
	c.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
		PackedColorArray([Color("9fd4ff"), Color("c6b2ff"), Color("ffd0ea"), Color("ffe9c9")]))
	for h in [[0.15, 0.95, 0.42], [0.55, 1.05, 0.5], [0.95, 0.98, 0.45]]:
		c.draw_circle(Vector2(s.x * h[0], s.y * h[1] + s.y * 0.35), s.y * h[2], Color("b2f2bb"), true, -1.0, true)
	for k in BG_CRITTERS.size():
		var b: Array = BG_CRITTERS[k]
		var p := Vector2(s.x * b[0].x, s.y * b[0].y + sin(_t * 2.0 + k) * 10.0)
		Sprites.draw_critter(c, p, 4.0, b[1], -1 if k % 2 == 0 else 1, Vector2(-1, -0.3), _t * 6.0 + k, true, b[2], fmod(_t + k, 3.0) < 0.1)


func _process(d: float) -> void:
	_t += d
	if _bg:
		_bg.queue_redraw()
	if _waiting_web:
		var res := WebUpload.poll()
		if res.size() > 0:
			_waiting_web = false
			_set_custom(WebUpload.decode(res))


func _set_custom(img: Image) -> void:
	if img == null or img.is_empty():
		status.text = "Could not read that image"
		return
	Cfg.custom_map = img
	preview.texture = ImageTexture.create_from_image(img)
	preview.visible = true
	sel["map"]["index"] = MapGen.PRESETS.size()
	sel["map"]["label"].text = "Custom image"
	_apply_map()
