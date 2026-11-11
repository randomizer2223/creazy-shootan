class_name MapArt
## Hand-drawn picture maps. The picture is painted with Godot's 2D drawing on a
## hidden viewport, then read back: everything on the "ground" layer is solid and
## destructible, the "sky" layer is the background.

const W := 1280
const H := 720
const INK := Color("3b2321")


## Returns {} if the picture could not be rendered (for example in headless mode).
static var _cache := {}


static func build(id: String, host: Node) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {}
	if _cache.has(id):
		return MapGen.copy(_cache[id])
	var d: Dictionary = await _render(id, host)
	if not d.is_empty():
		_cache[id] = d
		return MapGen.copy(d)
	return d


static func _render(id: String, host: Node) -> Dictionary:
	var fg_vp := _viewport(host, id, 0)
	var bg_vp := _viewport(host, id, 1)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var fg := fg_vp.get_texture().get_image()
	var bg := bg_vp.get_texture().get_image()
	fg_vp.queue_free()
	bg_vp.queue_free()
	if fg == null or fg.is_empty() or bg == null or bg.is_empty():
		return {}
	fg.convert(Image.FORMAT_RGBA8)
	bg.convert(Image.FORMAT_RGBA8)
	var data := fg.get_data()
	var mask := PackedByteArray()
	mask.resize(W * H)
	for i in W * H:
		var a := data[i * 4 + 3]
		if a >= 128:
			mask[i] = 1
			# undo premultiplied edges so colors stay bright
			if a < 255:
				var k := 255.0 / a
				data[i * 4] = mini(int(data[i * 4] * k), 255)
				data[i * 4 + 1] = mini(int(data[i * 4 + 1] * k), 255)
				data[i * 4 + 2] = mini(int(data[i * 4 + 2] * k), 255)
			data[i * 4 + 3] = 255
		else:
			data[i * 4] = 0
			data[i * 4 + 1] = 0
			data[i * 4 + 2] = 0
			data[i * 4 + 3] = 0
	var fimg := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, data)
	var dirt := [Color("ffb35c"), Color("ff9cbc"), Color("fff1d6"), Color("c99a62")]
	return {"fg": fimg, "bg": bg, "mask": mask, "dirt": dirt, "outline": INK}


static func _viewport(host: Node, id: String, layer: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = layer == 0
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Node2D.new()
	canvas.draw.connect(func():
		var p := ArtPainter.new(canvas)
		if id == "cats":
			if layer == 0:
				p.cats_ground()
			else:
				p.cats_sky()
	)
	vp.add_child(canvas)
	host.add_child(vp)
	return vp


## Drawing helpers + the pictures themselves.
class ArtPainter:
	var ci: CanvasItem
	var font: Font

	func _init(c: CanvasItem) -> void:
		ci = c
		font = ThemeDB.fallback_font

	# ---- helpers ----
	func circle(c: Vector2, r: float, col: Color) -> void:
		ci.draw_circle(c, r, col, true, -1.0, true)

	func ring(c: Vector2, r: float, w: float, col: Color, a0 := 0.0, a1 := TAU) -> void:
		ci.draw_arc(c, r, a0, a1, 64, col, w, true)

	func ellipse(c: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
		var pts := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
		ci.draw_colored_polygon(pts, col)

	func poly(pts: Array, col: Color) -> void:
		ci.draw_colored_polygon(PackedVector2Array(pts), col)

	func line(pts: Array, col: Color, w: float) -> void:
		ci.draw_polyline(PackedVector2Array(pts), col, w, true)

	func rbox(r: Rect2, col: Color, radius: float) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(int(radius))
		sb.anti_aliasing = true
		ci.draw_style_box(sb, r)

	func text(pos: Vector2, s: String, size: int, col: Color, rot := 0.0, outline := 0, ocol := INK) -> void:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		ci.draw_set_transform(pos, rot, Vector2.ONE)
		if outline > 0:
			ci.draw_string_outline(font, Vector2(-w / 2.0, size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, ocol)
		ci.draw_string(font, Vector2(-w / 2.0, size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)

	func eye(c: Vector2, r: float, look: Vector2) -> void:
		circle(c, r + 5, INK)
		circle(c, r, Color.WHITE)
		circle(c + look * r * 0.45, r * 0.45, INK)
		circle(c + look * r * 0.45 + Vector2(-r * 0.15, -r * 0.18), r * 0.14, Color.WHITE)

	func cat_face(c: Vector2, s: float, fur: Color, derp := false) -> void:
		# ears
		for sx in [-1.0, 1.0]:
			poly([c + Vector2(sx * 30, -28) * s, c + Vector2(sx * 52, -78) * s, c + Vector2(sx * 6, -50) * s], fur)
			poly([c + Vector2(sx * 30, -38) * s, c + Vector2(sx * 45, -66) * s, c + Vector2(sx * 16, -50) * s], Color("ff9cbc"))
		ellipse(c, 62 * s, 50 * s, fur)
		# eyes
		if derp:
			eye(c + Vector2(-22, -6) * s, 15 * s, Vector2(0.7, 0.6))
			eye(c + Vector2(24, -10) * s, 11 * s, Vector2(-0.6, -0.7))
		else:
			eye(c + Vector2(-22, -8) * s, 12 * s, Vector2(0.3, 0.2))
			eye(c + Vector2(22, -8) * s, 12 * s, Vector2(0.3, 0.2))
		# nose, mouth, blep
		poly([c + Vector2(-6, 8) * s, c + Vector2(6, 8) * s, c + Vector2(0, 15) * s], Color("ff6f9a"))
		line([c + Vector2(-14, 18) * s, c + Vector2(-7, 23) * s, c + Vector2(0, 16) * s, c + Vector2(7, 23) * s, c + Vector2(14, 18) * s], INK, 3.0 * s)
		rbox(Rect2(c + Vector2(-5, 20) * s, Vector2(10, 13) * s), Color("ff6f9a"), 5 * s)
		# blush + whiskers
		circle(c + Vector2(-38, 14) * s, 7 * s, Color(1, 0.5, 0.6, 0.7))
		circle(c + Vector2(38, 14) * s, 7 * s, Color(1, 0.5, 0.6, 0.7))
		for sx in [-1.0, 1.0]:
			line([c + Vector2(sx * 40, 4) * s, c + Vector2(sx * 72, -4) * s], INK, 2.5 * s)
			line([c + Vector2(sx * 40, 12) * s, c + Vector2(sx * 74, 14) * s], INK, 2.5 * s)

	# =========================================================
	# CAT CHAOS
	# =========================================================
	func cats_sky() -> void:
		# sky gradient
		ci.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]),
			PackedColorArray([Color("9fd4ff"), Color("c6b2ff"), Color("ffd0ea"), Color("ffe9c9")]))
		# rainbow
		var rb := [Color("ff6b6b"), Color("ffa94d"), Color("ffe066"), Color("8ce99a"), Color("74c0fc"), Color("b197fc")]
		for i in rb.size():
			ring(Vector2(640, 760), 600 - i * 16, 16, Color(rb[i], 0.75), PI, TAU)
		# sun with sunglasses
		var sun := Vector2(640, 250)
		for i in 16:
			var a := TAU * i / 16.0
			poly([sun + Vector2.from_angle(a - 0.12) * 105, sun + Vector2.from_angle(a + 0.12) * 105, sun + Vector2.from_angle(a) * 150], Color("ffd43b"))
		circle(sun, 100, Color("ffe066"))
		rbox(Rect2(sun + Vector2(-78, -30), Vector2(66, 36)), INK, 10)
		rbox(Rect2(sun + Vector2(12, -30), Vector2(66, 36)), INK, 10)
		ci.draw_rect(Rect2(sun + Vector2(-14, -24), Vector2(28, 8)), INK)
		ci.draw_rect(Rect2(sun + Vector2(-66, -24), Vector2(16, 8)), Color(1, 1, 1, 0.6))
		ci.draw_rect(Rect2(sun + Vector2(24, -24), Vector2(16, 8)), Color(1, 1, 1, 0.6))
		ring(sun + Vector2(0, 22), 34, 6, INK, 0.3, PI - 0.3)
		# clouds (one is a cat)
		for c in [Vector2(170, 330), Vector2(1120, 420), Vector2(900, 90), Vector2(380, 560)]:
			for o in [Vector2(-40, 8), Vector2(0, -10), Vector2(40, 6), Vector2(10, 14)]:
				circle(c + o, 34, Color(1, 1, 1, 0.9))
		var cc := Vector2(240, 120)
		circle(cc, 48, Color(1, 1, 1, 0.92))
		poly([cc + Vector2(-38, -20), cc + Vector2(-30, -70), cc + Vector2(-6, -42)], Color(1, 1, 1, 0.92))
		poly([cc + Vector2(38, -20), cc + Vector2(30, -70), cc + Vector2(6, -42)], Color(1, 1, 1, 0.92))
		circle(cc + Vector2(-16, -6), 5, Color("9fb8d8"))
		circle(cc + Vector2(16, -6), 5, Color("9fb8d8"))
		ring(cc + Vector2(0, 8), 8, 3, Color("9fb8d8"), 0.3, PI - 0.3)
		# meme-ish shouting text
		text(Vector2(250, 470), "much boom", 34, Color("ff74d8"), -0.2, 8, Color.WHITE)
		text(Vector2(1030, 250), "wow", 48, Color("4dabf7"), 0.25, 9, Color.WHITE)
		text(Vector2(1040, 560), "very war", 30, Color("40c057"), -0.15, 8, Color.WHITE)
		text(Vector2(820, 470), "such cute", 28, Color("fab005"), 0.18, 8, Color.WHITE)
		text(Vector2(430, 300), "meow?", 30, Color("845ef7"), 0.1, 8, Color.WHITE)
		# sparkles
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 60:
			var p := Vector2(rng.randf() * W, rng.randf() * H * 0.8)
			var s := rng.randf_range(2, 5)
			poly([p + Vector2(0, -s * 2), p + Vector2(s * 0.5, 0), p + Vector2(0, s * 2), p + Vector2(-s * 0.5, 0)], Color(1, 1, 1, 0.8))
			poly([p + Vector2(-s * 2, 0), p + Vector2(0, s * 0.5), p + Vector2(s * 2, 0), p + Vector2(0, -s * 0.5)], Color(1, 1, 1, 0.8))
		# soft hills
		for h in [Vector2(120, 760), Vector2(420, 800), Vector2(900, 790), Vector2(1220, 770)]:
			circle(h, 220, Color("b2f2bb"))

	func cats_ground() -> void:
		# ---- wavy grass floor ----
		var top := []
		var low := []
		for i in 65:
			var x := i * 20.0
			top.append(Vector2(x, H - 46 + sin(x * 0.03) * 8.0))
			low.append(Vector2(x, H - 36 + sin(x * 0.03) * 8.0))
		poly(top + [Vector2(W, H), Vector2(0, H)], Color("69db7c"))
		poly(low + [Vector2(W, H), Vector2(0, H)], Color("c98a52"))
		for i in 40:
			circle(Vector2(i * 33 + 10, H - 14 + (i % 3) * 4), 3, Color("a8723f"))

		# ---- giant derpy cat (center) ----
		var c := Vector2(640, 620)
		var fur := Color("ffb35c")
		for sx in [-1.0, 1.0]:
			poly([c + Vector2(sx * 120, -140), c + Vector2(sx * 230, -300), c + Vector2(sx * 30, -190)], fur)
			poly([c + Vector2(sx * 120, -160), c + Vector2(sx * 200, -270), c + Vector2(sx * 60, -195)], Color("ff9cbc"))
		ellipse(c, 270, 205, fur)
		for i in 3:
			rbox(Rect2(c + Vector2(-48 + i * 34, -200), Vector2(18, 62 - abs(i - 1) * 14)), Color("f08a3c"), 9)
		ellipse(c + Vector2(0, 70), 150, 90, Color("ffe3bf"))
		eye(c + Vector2(-95, -40), 58, Vector2(0.75, 0.55))
		eye(c + Vector2(100, -55), 40, Vector2(-0.7, -0.6))
		poly([c + Vector2(-20, 20), c + Vector2(20, 20), c + Vector2(0, 42)], Color("ff6f9a"))
		line([c + Vector2(-55, 55), c + Vector2(-28, 72), c + Vector2(0, 50), c + Vector2(28, 72), c + Vector2(55, 55)], INK, 8)
		rbox(Rect2(c + Vector2(-20, 64), Vector2(40, 52)), Color("ff6f9a"), 20)
		line([c + Vector2(0, 72), c + Vector2(0, 100)], Color("e64980"), 4)
		circle(c + Vector2(-170, 40), 28, Color(1, 0.5, 0.6, 0.6))
		circle(c + Vector2(170, 40), 28, Color(1, 0.5, 0.6, 0.6))
		for sx in [-1.0, 1.0]:
			line([c + Vector2(sx * 175, 0), c + Vector2(sx * 290, -30)], INK, 7)
			line([c + Vector2(sx * 175, 25), c + Vector2(sx * 300, 25)], INK, 7)

		# ---- cat loaf (top left) ----
		var lf := Rect2(95, 200, 270, 110)
		for sx in [0.25, 0.75]:
			var ex: float = lf.position.x + lf.size.x * sx
			poly([Vector2(ex - 26, lf.position.y + 14), Vector2(ex, lf.position.y - 30), Vector2(ex + 26, lf.position.y + 14)], Color("e6a65e"))
		rbox(lf, Color("e6a65e"), 54)
		rbox(Rect2(lf.position + Vector2(14, 46), lf.size - Vector2(28, 56)), Color("ffd9a0"), 36)
		ring(Vector2(lf.position.x + 95, lf.position.y + 42), 12, 5, INK, PI + 0.3, TAU - 0.3)
		ring(Vector2(lf.position.x + 175, lf.position.y + 42), 12, 5, INK, PI + 0.3, TAU - 0.3)
		ring(Vector2(lf.position.x + 125, lf.position.y + 58), 9, 4, INK, 0.2, PI - 0.2)
		ring(Vector2(lf.position.x + 145, lf.position.y + 58), 9, 4, INK, 0.2, PI - 0.2)
		text(Vector2(lf.position.x + 135, lf.position.y + 88), "LOAF", 26, Color("b8742f"))

		# ---- donut (top left corner, the hole is a real hole) ----
		var dn := Vector2(95, 85)
		ring(dn, 42, 40, Color("e8b071"))
		ring(dn, 42, 30, Color("ff8fc0"), PI * 0.95, TAU * 1.05)
		var srng := RandomNumberGenerator.new()
		srng.seed = 3
		for i in 14:
			var a := srng.randf_range(PI, TAU)
			var p := dn + Vector2.from_angle(a) * srng.randf_range(33, 52)
			var sc: Color = [Color("74c0fc"), Color("ffe066"), Color.WHITE, Color("8ce99a")][i % 4]
			line([p, p + Vector2.from_angle(srng.randf() * TAU) * 7], sc, 3)

		# ---- floating MEOW letters (solid!) ----
		text(Vector2(640, 110), "MEOW", 130, Color("ffd43b"), -0.04, 22, Color("e8590c"))

		# ---- paw platform (left middle) ----
		var pw := Vector2(285, 440)
		ellipse(pw, 70, 58, Color("fff1d6"))
		ellipse(pw + Vector2(0, 14), 32, 26, Color("ff9cbc"))
		for o in [Vector2(-42, -26), Vector2(-15, -44), Vector2(15, -44), Vector2(42, -26)]:
			ellipse(pw + o, 13, 15, Color("ff9cbc"))

		# ---- pizza slice (bottom left) ----
		poly([Vector2(40, 560), Vector2(290, 530), Vector2(190, 690)], Color("ffd43b"))
		line([Vector2(40, 560), Vector2(290, 530)], Color("d9822b"), 26)
		for p in [Vector2(140, 580), Vector2(205, 600), Vector2(185, 645), Vector2(110, 560), Vector2(240, 560)]:
			circle(p, 14, Color("e03131"))
			circle(p + Vector2(-4, -4), 4, Color(1, 1, 1, 0.4))

		# ---- fish skeleton (right middle) ----
		var fy := 335.0
		line([Vector2(880, fy), Vector2(1110, fy)], Color("fff6e0"), 12)
		for i in 6:
			var x := 915.0 + i * 33.0
			line([Vector2(x, fy - 42 + i * 3), Vector2(x + 8, fy), Vector2(x, fy + 42 - i * 3)], Color("fff6e0"), 9)
		poly([Vector2(885, fy), Vector2(835, fy - 45), Vector2(835, fy + 45)], Color("fff6e0"))
		circle(Vector2(1140, fy), 36, Color("fff6e0"))
		line([Vector2(1132, fy - 18), Vector2(1150, fy)], INK, 5)
		line([Vector2(1150, fy - 18), Vector2(1132, fy)], INK, 5)
		line([Vector2(1158, fy + 14), Vector2(1172, fy + 8)], INK, 4)

		# ---- cat in a box (top right): if it fits, it sits ----
		var bx := Rect2(1000, 150, 180, 92)
		cat_face(Vector2(1090, 128), 0.8, Color("a9b3c4"))
		rbox(bx, Color("c99a62"), 8)
		poly([bx.position, bx.position + Vector2(-34, -28), bx.position + Vector2(10, -24), bx.position + Vector2(40, 0)], Color("d9ad74"))
		poly([bx.position + Vector2(bx.size.x, 0), bx.position + Vector2(bx.size.x + 34, -28), bx.position + Vector2(bx.size.x - 10, -24), bx.position + Vector2(bx.size.x - 40, 0)], Color("d9ad74"))
		text(bx.get_center() + Vector2(0, 4), "IF I FITS", 24, Color("8a5a2b"))
		text(bx.get_center() + Vector2(0, 32), "I SITS", 20, Color("8a5a2b"))

		# ---- yarn ball (bottom right) ----
		var yb := Vector2(1150, 600)
		circle(yb, 82, Color("ff8fc0"))
		for i in 5:
			ring(yb + Vector2(-20 + i * 10, -10 + i * 6), 60 - i * 9, 5, Color("e64980"), 0.4 + i * 0.5, 2.6 + i * 0.5)
		line([yb + Vector2(-70, 40), Vector2(1010, 640), Vector2(960, 668), Vector2(900, 672)], Color("e64980"), 7)

		# ---- small kitten on a cloud-ish step (right low middle) ----
		cat_face(Vector2(960, 470), 0.55, Color("ffe066"), true)
		rbox(Rect2(890, 495, 140, 26), Color("fff1d6"), 13)
