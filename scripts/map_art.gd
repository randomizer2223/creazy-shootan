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
	var dirt: Array = DIRT.get(id, DIRT["cats"])
	return {"fg": fimg, "bg": bg, "mask": mask, "dirt": dirt, "outline": INK}


## Colors used by the Dirt Cannon on each picture map.
const DIRT := {
	"cats": [Color("ffb35c"), Color("ff9cbc"), Color("fff1d6"), Color("c99a62")],
	"olympus": [Color("ffffff"), Color("e8f1ff"), Color("f5e6c8")],
	"trains": [Color("8a5a3b"), Color("6b4a34"), Color("a87a52")],
	"starry": [Color("2e5aa8"), Color("f2d14b"), Color("1f3b70")],
	"mona": [Color("6b5a32"), Color("4f5a3a"), Color("8a7448")],
	"paris": [Color("c9b28a"), Color("8fa3b8"), Color("e8c97a")],
	"farm": [Color("8a5a2b"), Color("f2d36b"), Color("7cc34a")],
}


static func _viewport(host: Node, id: String, layer: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = layer == 0
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := Node2D.new()
	canvas.draw.connect(func():
		var p := ArtPainter.new(canvas)
		p.call(id + ("_ground" if layer == 0 else "_sky"))
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

	# ---- more helpers ----
	func grad(top: Color, bottom: Color, r := Rect2(0, 0, W, H)) -> void:
		ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([top, top, bottom, bottom]))

	func rect(r: Rect2, col: Color) -> void:
		ci.draw_rect(r, col)

	func cloud(c: Vector2, s: float, col: Color) -> void:
		for o in [Vector2(-1.1, 0.25), Vector2(-0.45, -0.35), Vector2(0.35, -0.45), Vector2(1.05, 0.15), Vector2(0, 0.3)]:
			circle(c + o * 40.0 * s, 34.0 * s, col)

	func rrot(c: Vector2, size: Vector2, rot: float, col: Color, radius: float) -> void:
		ci.draw_set_transform(c, rot, Vector2.ONE)
		rbox(Rect2(-size / 2.0, size), col, radius)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)

	func star5(c: Vector2, r: float, col: Color) -> void:
		var pts := []
		for i in 10:
			var a := -PI / 2.0 + PI * i / 5.0
			pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
		poly(pts, col)

	func spiral(c: Vector2, r0: float, r1: float, turns: float, w: float, col: Color, a0 := 0.0) -> void:
		var pts := []
		var n := int(60 * turns)
		for i in n + 1:
			var t := float(i) / n
			pts.append(c + Vector2.from_angle(a0 + t * TAU * turns) * lerpf(r0, r1, t))
		line(pts, col, w)

	func wheel(c: Vector2, r: float, hub: Color) -> void:
		circle(c, r, INK)
		circle(c, r * 0.62, hub)
		for i in 4:
			var a := PI * i / 4.0
			line([c - Vector2.from_angle(a) * r * 0.6, c + Vector2.from_angle(a) * r * 0.6], INK, maxf(2.0, r * 0.12))
		circle(c, r * 0.22, INK)

	# =========================================================
	# MOUNT OLYMPUS
	# =========================================================
	func olympus_sky() -> void:
		grad(Color("8ec5ff"), Color("ffe3b3"))
		for i in 14:
			var a := PI * 0.05 + PI * 0.9 * i / 13.0
			poly([Vector2(640, -40), Vector2(640, -40) + Vector2.from_angle(a - 0.05) * 900, Vector2(640, -40) + Vector2.from_angle(a + 0.05) * 900], Color(1, 0.97, 0.75, 0.25))
		circle(Vector2(640, 20), 90, Color("fff1a8"))
		poly([Vector2(0, 560), Vector2(160, 420), Vector2(300, 520), Vector2(520, 380), Vector2(760, 520), Vector2(980, 400), Vector2(1280, 540), Vector2(1280, 720), Vector2(0, 720)], Color("cdbfea"))
		for x in range(0, 1300, 110):
			cloud(Vector2(x, 640 + (x % 3) * 12), 1.3, Color(1, 1, 1, 0.75))
		poly([Vector2(250, 40), Vector2(300, 40), Vector2(275, 95), Vector2(320, 95), Vector2(230, 200), Vector2(258, 120), Vector2(215, 120)], Color("ffe066"))
		text(Vector2(360, 250), "Oh my gods!", 30, Color("f08c00"), -0.12, 8, Color.WHITE)
		text(Vector2(1000, 160), "ZAP!", 44, Color("ffd43b"), 0.2, 9, Color("3b5bdb"))

	func olympus_ground() -> void:
		var white := Color("ffffff")
		var shade := Color("dce8ff")
		# cloud floor
		rect(Rect2(0, 690, W, 30), shade)
		for x in range(-20, 1320, 60):
			circle(Vector2(x, 712), 44, shade)
			circle(Vector2(x + 30, 696), 40, white)
		# the mountain
		poly([Vector2(0, 720), Vector2(0, 300), Vector2(90, 180), Vector2(170, 260), Vector2(250, 150), Vector2(380, 420), Vector2(430, 720)], Color("a99ad1"))
		poly([Vector2(250, 150), Vector2(212, 215), Vector2(240, 202), Vector2(262, 226), Vector2(292, 206)], white)
		poly([Vector2(90, 180), Vector2(62, 222), Vector2(88, 212), Vector2(112, 226), Vector2(130, 210)], white)
		for i in 6:
			line([Vector2(60 + i * 50, 420 + i * 30), Vector2(110 + i * 50, 400 + i * 30)], Color("9384c4"), 5)
		# temple on a cloud
		cloud(Vector2(640, 300), 2.2, white)
		rect(Rect2(500, 250, 280, 14), Color("efe4cc"))
		rect(Rect2(512, 236, 256, 14), Color("f6eedd"))
		for i in 6:
			var x := 525.0 + i * 46.0
			rect(Rect2(x, 140, 22, 96), Color("fbf6ea"))
			rect(Rect2(x - 4, 132, 30, 9), Color("efe4cc"))
			line([Vector2(x + 7, 145), Vector2(x + 7, 232)], Color("e6dcc5"), 2)
			line([Vector2(x + 15, 145), Vector2(x + 15, 232)], Color("e6dcc5"), 2)
		rect(Rect2(505, 112, 270, 22), Color("efe4cc"))
		text(Vector2(640, 122), "OLYMPUS", 18, Color("c9a24a"))
		poly([Vector2(498, 114), Vector2(782, 114), Vector2(640, 56)], Color("fbf6ea"))
		poly([Vector2(540, 106), Vector2(740, 106), Vector2(640, 70)], Color("f0e2c0"))
		# floating lightning bolt
		poly([Vector2(520, 420), Vector2(605, 420), Vector2(578, 468), Vector2(628, 468), Vector2(540, 565), Vector2(560, 495), Vector2(512, 495)], Color("ffd43b"))
		# Zeus (on his cloud), with a bolt in hand
		cloud(Vector2(1070, 640), 1.6, white)
		var z := Vector2(1070, 450)
		for i in 9:
			var a := PI * 0.15 + PI * 0.7 * i / 8.0
			circle(z + Vector2.from_angle(a) * 72 + Vector2(0, 20), 30, white)
		for i in 9:
			var a := PI + PI * i / 8.0
			circle(z + Vector2.from_angle(a) * 62, 24, white)
		circle(z, 66, Color("ffd9b8"))
		for i in 11:
			var a := PI * 1.05 + PI * 0.9 * i / 10.0
			ellipse(z + Vector2.from_angle(a) * 70, 13, 6, Color("69db7c"), a + PI / 2.0)
		ellipse(z + Vector2(-26, 32), 30, 13, white, 0.2)
		ellipse(z + Vector2(26, 32), 30, 13, white, -0.2)
		circle(z + Vector2(-24, -6), 7, INK)
		circle(z + Vector2(24, -6), 7, INK)
		line([z + Vector2(-40, -26), z + Vector2(-10, -18)], white, 9)
		line([z + Vector2(40, -26), z + Vector2(10, -18)], white, 9)
		circle(z + Vector2(0, 12), 9, Color("f5b895"))
		circle(z + Vector2(-44, 10), 9, Color(1, 0.55, 0.6, 0.6))
		circle(z + Vector2(44, 10), 9, Color(1, 0.55, 0.6, 0.6))
		poly([Vector2(1160, 300), Vector2(1205, 300), Vector2(1188, 350), Vector2(1220, 350), Vector2(1150, 450), Vector2(1168, 385), Vector2(1140, 385)], Color("ffd43b"))
		# amphora
		var v := Vector2(800, 600)
		rect(Rect2(v.x - 22, v.y - 115, 44, 50), Color("e8823a"))
		rbox(Rect2(v.x - 36, v.y - 125, 72, 16), Color("e8823a"), 8)
		ring(v + Vector2(-46, -70), 22, 8, INK, PI * 0.6, PI * 1.6)
		ring(v + Vector2(46, -70), 22, 8, INK, -PI * 0.6, PI * 0.6)
		ellipse(v, 58, 72, Color("e8823a"))
		rect(Rect2(v.x - 58, v.y - 12, 116, 22), INK)
		for i in 7:
			line([Vector2(v.x - 50 + i * 16, v.y - 6), Vector2(v.x - 50 + i * 16, v.y + 4), Vector2(v.x - 42 + i * 16, v.y + 4)], Color("e8823a"), 3)
		# small cloud steps
		cloud(Vector2(450, 115), 0.8, white)
		cloud(Vector2(900, 330), 1.0, white)
		cloud(Vector2(890, 520), 0.9, white)
		cloud(Vector2(1210, 200), 0.9, white)

	# =========================================================
	# CHOO-CHOO STATION
	# =========================================================
	func trains_sky() -> void:
		grad(Color("ff9f7a"), Color("ffe8c2"))
		circle(Vector2(980, 330), 80, Color("fff0b0"))
		var r := RandomNumberGenerator.new()
		r.seed = 11
		var x := 0.0
		while x < W:
			var bw := r.randf_range(40, 90)
			var bh := r.randf_range(80, 220)
			rect(Rect2(x, 560 - bh, bw, bh + 160), Color("d6a8c4"))
			x += bw + r.randf_range(0, 20)
		for c in [Vector2(260, 150), Vector2(320, 90), Vector2(400, 50)]:
			circle(c, 40, Color(1, 1, 1, 0.7))
		cloud(Vector2(700, 100), 1.0, Color(1, 1, 1, 0.6))
		cloud(Vector2(1150, 160), 0.9, Color(1, 1, 1, 0.6))
		text(Vector2(1010, 130), "CHOO CHOO!", 40, Color("e03131"), 0.1, 9, Color.WHITE)
		text(Vector2(640, 560), "all aboard!", 28, Color("1c7ed6"), -0.1, 8, Color.WHITE)

	func trains_ground() -> void:
		var wood := Color("8a5a3b")
		var rail := Color("7b8794")
		# ground + lower track
		rect(Rect2(0, 672, W, 48), Color("8a5a3b"))
		rect(Rect2(0, 664, W, 10), Color("a89a8a"))
		for x in range(0, W, 24):
			rect(Rect2(x, 664, 14, 6), Color("6b4a34"))
		line([Vector2(0, 662), Vector2(W, 662)], rail, 4)
		# bridge
		for px in [180.0, 440.0, 700.0, 960.0]:
			rect(Rect2(px, 416, 30, 250), Color("b8a99a"))
			for yy in range(430, 660, 22):
				line([Vector2(px, yy), Vector2(px + 30, yy)], Color("a08f80"), 2)
		for cx in [310.0, 570.0, 830.0]:
			ring(Vector2(cx, 520), 112, 14, Color("b8a99a"), PI, TAU)
		rect(Rect2(120, 400, 1040, 18), wood)
		for x in range(124, 1156, 22):
			rect(Rect2(x, 395, 12, 6), Color("6b4a34"))
		line([Vector2(120, 394), Vector2(1160, 394)], rail, 4)
		# steam locomotive
		rbox(Rect2(165, 320, 175, 62), Color("e03131"), 30)
		rbox(Rect2(320, 280, 92, 104), Color("c92a2a"), 10)
		rbox(Rect2(334, 294, 56, 40), Color("a5d8ff"), 6)
		rbox(Rect2(312, 268, 108, 16), INK, 6)
		rect(Rect2(195, 268, 26, 54), INK)
		rbox(Rect2(185, 256, 46, 16), INK, 6)
		circle(Vector2(268, 318), 16, Color("ffd43b"))
		line([Vector2(180, 335), Vector2(320, 335)], Color("ffd43b"), 4)
		poly([Vector2(168, 380), Vector2(136, 396), Vector2(170, 396)], Color("495057"))
		circle(Vector2(162, 345), 10, Color("fff3bf"))
		for wx in [212.0, 262.0, 312.0]:
			wheel(Vector2(wx, 384), 17, Color("ffd43b"))
		wheel(Vector2(372, 380), 21, Color("ffd43b"))
		# tender + passenger car
		rbox(Rect2(425, 340, 110, 48), Color("343a40"), 8)
		for i in 6:
			circle(Vector2(440 + i * 16, 340), 11, Color("212529"))
		wheel(Vector2(450, 386), 13, Color("adb5bd"))
		wheel(Vector2(510, 386), 13, Color("adb5bd"))
		rbox(Rect2(548, 308, 196, 80), Color("4dabf7"), 14)
		rbox(Rect2(540, 298, 212, 16), Color("1c7ed6"), 8)
		for i in 4:
			rbox(Rect2(562 + i * 45, 324, 32, 30), Color("fff3bf"), 6)
		wheel(Vector2(580, 386), 13, Color("adb5bd"))
		wheel(Vector2(712, 386), 13, Color("adb5bd"))
		# signal
		line([Vector2(850, 394), Vector2(850, 250)], INK, 8)
		rbox(Rect2(834, 222, 32, 64), INK, 8)
		circle(Vector2(850, 240), 9, Color("ff6b6b"))
		circle(Vector2(850, 268), 9, Color("69db7c"))
		# station on the bridge
		rect(Rect2(985, 300, 165, 96), Color("f4e3c1"))
		poly([Vector2(965, 302), Vector2(1170, 302), Vector2(1067, 236)], Color("c92a2a"))
		circle(Vector2(1067, 286), 20, Color.WHITE)
		line([Vector2(1067, 286), Vector2(1067, 272)], INK, 3)
		line([Vector2(1067, 286), Vector2(1078, 290)], INK, 3)
		rbox(Rect2(1045, 338, 44, 58), Color("8a5a3b"), 6)
		text(Vector2(1067, 322), "STATION", 14, Color("c92a2a"))
		# lower train: diesel + TNT wagon
		rbox(Rect2(850, 596, 220, 66), Color("1c7ed6"), 14)
		rect(Rect2(850, 628, 220, 10), Color("ffd43b"))
		rbox(Rect2(990, 556, 74, 48), Color("1864ab"), 10)
		rbox(Rect2(1002, 566, 50, 26), Color("a5d8ff"), 5)
		for wx in [880.0, 940.0, 1000.0, 1050.0]:
			wheel(Vector2(wx, 660), 13, Color("adb5bd"))
		rbox(Rect2(1086, 612, 150, 50), Color("f08c00"), 8)
		text(Vector2(1161, 637), "TNT", 26, Color("e03131"))
		wheel(Vector2(1110, 660), 13, Color("adb5bd"))
		wheel(Vector2(1212, 660), 13, Color("adb5bd"))
		# water tower
		rect(Rect2(20, 300, 160, 12), wood)
		for lx in [45.0, 155.0]:
			line([Vector2(lx, 220), Vector2(lx, 300)], INK, 7)
		line([Vector2(45, 260), Vector2(155, 290)], INK, 5)
		line([Vector2(155, 260), Vector2(45, 290)], INK, 5)
		rbox(Rect2(35, 140, 130, 84), wood, 12)
		for yy in [160.0, 190.0]:
			line([Vector2(35, yy), Vector2(165, yy)], Color("6b4a34"), 4)
		poly([Vector2(28, 142), Vector2(172, 142), Vector2(100, 96)], Color("6b4a34"))
		# steam puffs you can stand on
		cloud(Vector2(520, 190), 0.9, Color("f1f3f5"))
		cloud(Vector2(760, 150), 0.8, Color("f1f3f5"))
		cloud(Vector2(640, 520), 0.8, Color("f1f3f5"))

	# =========================================================
	# STARRY NIGHT (after Van Gogh, 1889)
	# =========================================================
	func _hill(x: float) -> float:
		return 565.0 + sin(x * 0.006 + 1.0) * 38.0 + sin(x * 0.017) * 14.0

	func _cyp(y: float) -> float:
		var t := clampf((720.0 - y) / 680.0, 0.0, 1.0)
		return 78.0 * pow(sin(PI * clampf(t * 0.95 + 0.05, 0.0, 1.0)), 0.8) * (1.0 - t * 0.55) + sin(y * 0.05) * 6.0

	func starry_sky() -> void:
		grad(Color("172a63"), Color("3c64b8"))
		var r := RandomNumberGenerator.new()
		r.seed = 5
		var centers := [Vector2(600, 190), Vector2(820, 240), Vector2(300, 140)]
		var cols := [Color("2c4a9a"), Color("4d74c9"), Color("6f93db"), Color("22397a"), Color("8fb0e8"), Color("c4d6f2")]
		for i in 2600:
			var p := Vector2(r.randf() * W, r.randf() * 560)
			var best: Vector2 = centers[0]
			for c in centers:
				if p.distance_to(c) < p.distance_to(best):
					best = c
			var a := (p - best).angle() + PI / 2.0 + r.randf_range(-0.25, 0.25)
			if p.distance_to(best) > 260:
				a = r.randf_range(-0.3, 0.3)
			line([p, p + Vector2.from_angle(a) * r.randf_range(10, 20)], cols[i % cols.size()], 4)
		for s in [Vector2(360, 90), Vector2(470, 300), Vector2(980, 90), Vector2(1010, 300), Vector2(1200, 330), Vector2(700, 330), Vector2(1200, 60)]:
			for k in 3:
				ring(s, 26 + k * 9, 4, Color(1.0, 0.9, 0.45, 0.5 - k * 0.12))
		ring(Vector2(1120, 120), 70, 10, Color(1.0, 0.85, 0.4, 0.4))
		poly([Vector2(0, 600), Vector2(220, 520), Vector2(480, 560), Vector2(800, 500), Vector2(1100, 540), Vector2(1280, 510), Vector2(1280, 720), Vector2(0, 720)], Color("1f3768"))

	func starry_ground() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 9
		# rolling hills
		var pts := []
		for i in 65:
			var x := i * 20.0
			pts.append(Vector2(x, _hill(x)))
		poly(pts + [Vector2(W, H), Vector2(0, H)], Color("24476b"))
		for i in 900:
			var p := Vector2(r.randf() * W, r.randf_range(520, 720))
			if p.y > _hill(p.x) + 6:
				var c: Color = [Color("1d3b5c"), Color("2f5d82"), Color("3f7a5f"), Color("1b3048")][i % 4]
				line([p, p + Vector2.from_angle(r.randf_range(-0.3, 0.3)) * 14], c, 4)
		# village
		var x := 430.0
		var i := 0
		while x < 1220.0:
			var hh := 34.0 + (i % 3) * 10.0
			var base := _hill(x + 22) + 4
			rect(Rect2(x, base - hh, 46, hh + 10), Color("5a7896"))
			poly([Vector2(x - 6, base - hh), Vector2(x + 52, base - hh), Vector2(x + 23, base - hh - 22)], Color("2a3f66"))
			rect(Rect2(x + 10, base - hh + 10, 9, 9), Color("f7d84a"))
			rect(Rect2(x + 27, base - hh + 10, 9, 9), Color("f7d84a"))
			x += 82.0
			i += 1
		var cb := _hill(780) + 4
		rect(Rect2(756, cb - 110, 52, 112), Color("5a7896"))
		poly([Vector2(754, cb - 108), Vector2(810, cb - 108), Vector2(782, cb - 240)], Color("2a3f66"))
		# cypress
		var left := []
		var right := []
		for k in 69:
			var y := 720.0 - k * 10.0
			var w := _cyp(y)
			left.append(Vector2(170 - w, y))
			right.push_front(Vector2(170 + w * 0.9, y))
		poly(left + right, Color("1c2b1f"))
		for k in 700:
			var p := Vector2(r.randf_range(90, 250), r.randf_range(60, 720))
			if absf(p.x - 170) < _cyp(p.y) - 5:
				var c: Color = [Color("2b4a2e"), Color("3d5f37"), Color("14201a"), Color("4a6b3a")][k % 4]
				line([p, p + Vector2.from_angle(-PI / 2.0 + r.randf_range(-0.35, 0.35)) * 16], c, 4)
		# swirls you can climb
		spiral(Vector2(600, 190), 120, 26, 1.5, 22, Color("a9c4f0"), 0.3)
		spiral(Vector2(600, 190), 120, 26, 1.5, 7, Color("e1ebff"), 0.3)
		spiral(Vector2(820, 240), 74, 18, 1.3, 18, Color("a9c4f0"), 2.0)
		spiral(Vector2(820, 240), 74, 18, 1.3, 6, Color("e1ebff"), 2.0)
		# moon and stars
		ring(Vector2(1120, 120), 42, 30, Color("f5c842"), -2.2, 1.4)
		for s in [Vector2(360, 90), Vector2(470, 300), Vector2(980, 90), Vector2(1010, 300), Vector2(1200, 330), Vector2(700, 330), Vector2(1200, 60)]:
			circle(s, 17, Color("f2d14b"))
			circle(s, 7, Color("fff8d6"))

	# =========================================================
	# MONA LISA (after Leonardo, c. 1503)
	# =========================================================
	func mona_sky() -> void:
		grad(Color("b9c49a"), Color("6f7d58"))
		poly([Vector2(0, 360), Vector2(150, 250), Vector2(300, 330), Vector2(420, 260), Vector2(420, 720), Vector2(0, 720)], Color("8fa8a2"))
		poly([Vector2(860, 280), Vector2(1000, 220), Vector2(1140, 300), Vector2(1280, 240), Vector2(1280, 720), Vector2(860, 720)], Color("8fa8a2"))
		line([Vector2(60, 700), Vector2(200, 600), Vector2(120, 520), Vector2(260, 450), Vector2(200, 400)], Color("c9b48a"), 12)
		line([Vector2(1240, 700), Vector2(1080, 600), Vector2(1180, 520), Vector2(1020, 460)], Color("8fb3b8"), 14)
		var r := RandomNumberGenerator.new()
		r.seed = 3
		for i in 700:
			var p := Vector2(r.randf() * W, r.randf() * H)
			line([p, p + Vector2.from_angle(r.randf_range(-0.4, 0.4)) * 12], Color(0.25, 0.22, 0.12, 0.12), 4)
		grad(Color(1.0, 0.85, 0.4, 0.12), Color(0.3, 0.2, 0.05, 0.25))

	func mona_ground() -> void:
		var gold := Color("c9a227")
		var dark_gold := Color("8a6d16")
		# landscape ledges
		var rock := Color("6b7a55")
		poly([Vector2(34, 520), Vector2(250, 500), Vector2(340, 540), Vector2(330, 566), Vector2(34, 580)], rock)
		poly([Vector2(80, 330), Vector2(270, 312), Vector2(250, 348), Vector2(90, 352)], rock)
		poly([Vector2(34, 180), Vector2(170, 170), Vector2(160, 200), Vector2(34, 210)], rock)
		poly([Vector2(960, 270), Vector2(1246, 250), Vector2(1246, 290), Vector2(980, 300)], rock)
		poly([Vector2(1150, 686), Vector2(1170, 540), Vector2(1200, 520), Vector2(1246, 560), Vector2(1246, 686)], rock)
		# bridge
		rect(Rect2(900, 450, 300, 20), Color("8a7a5a"))
		for bx in [930.0, 1030.0, 1130.0]:
			ring(Vector2(bx + 20, 520), 46, 12, Color("8a7a5a"), PI, TAU)
		for bx in [905.0, 1000.0, 1100.0, 1185.0]:
			rect(Rect2(bx, 470, 16, 60), Color("8a7a5a"))
		# her
		var hair := Color("2a1f14")
		var skin := Color("e8b98a")
		ellipse(Vector2(640, 260), 108, 138, hair)
		ellipse(Vector2(552, 400), 42, 100, hair)
		ellipse(Vector2(728, 400), 42, 100, hair)
		poly([Vector2(470, 420), Vector2(810, 420), Vector2(890, 686), Vector2(390, 686)], Color("3a3221"))
		rect(Rect2(612, 320, 56, 90), skin)
		ellipse(Vector2(640, 428), 74, 30, skin)
		line([Vector2(570, 430), Vector2(640, 452), Vector2(710, 430)], Color("c9a227"), 3)
		ellipse(Vector2(560, 600), 115, 42, Color("6b5a2e"), 0.18)
		ellipse(Vector2(720, 612), 115, 42, Color("6b5a2e"), -0.12)
		ellipse(Vector2(655, 598), 54, 22, skin, 0.1)
		ellipse(Vector2(705, 588), 42, 18, skin, -0.2)
		ellipse(Vector2(640, 252), 72, 92, skin)
		ellipse(Vector2(612, 240), 11, 5, INK)
		ellipse(Vector2(668, 240), 11, 5, INK)
		circle(Vector2(614, 240), 3, Color("5c3a1e"))
		circle(Vector2(670, 240), 3, Color("5c3a1e"))
		line([Vector2(640, 248), Vector2(636, 280), Vector2(644, 284)], Color("c48a62"), 3)
		ring(Vector2(640, 284), 22, 3, Color("8a4b3a"), 0.45, PI - 0.45)
		circle(Vector2(605, 280), 12, Color(0.9, 0.55, 0.45, 0.25))
		circle(Vector2(675, 280), 12, Color(0.9, 0.55, 0.45, 0.25))
		# golden frame
		for r in [Rect2(0, 0, W, 34), Rect2(0, 686, W, 34), Rect2(0, 0, 34, H), Rect2(W - 34, 0, 34, H)]:
			rect(r, gold)
		ci.draw_rect(Rect2(8, 8, W - 16, H - 16), Color("f3d97a"), false, 4)
		ci.draw_rect(Rect2(28, 28, W - 56, H - 56), dark_gold, false, 4)
		for c in [Vector2(17, 17), Vector2(W - 17, 17), Vector2(17, H - 17), Vector2(W - 17, H - 17)]:
			circle(c, 22, gold)
			circle(c, 10, dark_gold)
		text(Vector2(640, 703), "LA GIOCONDA  -  PLEASE DO NOT EXPLODE THE ART", 18, dark_gold)

	# =========================================================
	# PARIS
	# =========================================================
	func paris_sky() -> void:
		grad(Color("ffb3c6"), Color("ffe7c7"))
		circle(Vector2(300, 330), 70, Color("fff3c4"))
		poly([Vector2(0, 600), Vector2(0, 520), Vector2(120, 520), Vector2(160, 470), Vector2(200, 520), Vector2(400, 520), Vector2(400, 480), Vector2(520, 480), Vector2(560, 520), Vector2(1280, 520), Vector2(1280, 600)], Color("e6b7d2"))
		circle(Vector2(1180, 470), 46, Color("e6b7d2"))
		rect(Rect2(1134, 470, 92, 60), Color("e6b7d2"))
		for c in [Vector2(780, 150), Vector2(1040, 230), Vector2(180, 120)]:
			cloud(c, 0.9, Color(1, 1, 1, 0.7))
		var b := Vector2(230, 180)
		for i in 5:
			ellipse(b, 50 - i * 10, 60, [Color("ff6b6b"), Color("ffe066"), Color("4dabf7")][i % 3])
		rect(Rect2(b.x - 14, b.y + 70, 28, 20), Color("8a5a3b"))
		text(Vector2(1030, 110), "Oh là là!", 44, Color("e64980"), 0.12, 9, Color.WHITE)
		text(Vector2(470, 240), "bonjour", 28, Color("4263eb"), -0.15, 8, Color.WHITE)

	func paris_ground() -> void:
		var iron := Color("8c6a4f")
		var lattice := Color("a8846a")
		# cobblestone street
		rect(Rect2(0, 668, W, 52), Color("b5a48a"))
		for i in 64:
			circle(Vector2(i * 20 + (i % 2) * 10, 684 + (i % 3) * 10), 7, Color("a3927a"))
		# Eiffel tower
		var cx := 640.0
		for s in [-1.0, 1.0]:
			poly([Vector2(cx + s * 175, 668), Vector2(cx + s * 135, 668), Vector2(cx + s * 70, 470), Vector2(cx + s * 98, 470)], iron)
			poly([Vector2(cx + s * 96, 470), Vector2(cx + s * 70, 470), Vector2(cx + s * 26, 330), Vector2(cx + s * 46, 330)], iron)
		ring(Vector2(cx, 700), 118, 14, iron, PI, TAU)
		for k in 3:
			var y0 := 668.0 - k * 66.0
			var y1 := y0 - 66.0
			var w0 := 140.0 - k * 22.0
			var w1 := w0 - 22.0
			line([Vector2(cx - w0, y0), Vector2(cx + w1, y1)], lattice, 5)
			line([Vector2(cx + w0, y0), Vector2(cx - w1, y1)], lattice, 5)
		rbox(Rect2(cx - 125, 455, 250, 20), iron, 6)
		for x in range(int(cx - 115), int(cx + 120), 14):
			line([Vector2(x, 455), Vector2(x, 446)], iron, 3)
		line([Vector2(cx - 120, 446), Vector2(cx + 120, 446)], iron, 3)
		line([Vector2(cx - 60, 455), Vector2(cx + 30, 330)], lattice, 4)
		line([Vector2(cx + 60, 455), Vector2(cx - 30, 330)], lattice, 4)
		rbox(Rect2(cx - 62, 318, 124, 16), iron, 5)
		poly([Vector2(cx - 44, 320), Vector2(cx + 44, 320), Vector2(cx + 12, 150), Vector2(cx - 12, 150)], iron)
		for y in range(170, 320, 26):
			line([Vector2(cx - 30 + (320 - y) * 0.1, y), Vector2(cx + 30 - (320 - y) * 0.1, y + 26)], lattice, 3)
		rbox(Rect2(cx - 26, 140, 52, 12), iron, 4)
		poly([Vector2(cx - 9, 142), Vector2(cx + 9, 142), Vector2(cx + 2, 38), Vector2(cx - 2, 38)], iron)
		# Arc de Triomphe
		var stone := Color("e9dcc0")
		rect(Rect2(60, 380, 250, 96), stone)
		rect(Rect2(70, 470, 72, 200), stone)
		rect(Rect2(228, 470, 72, 200), stone)
		ring(Vector2(185, 476), 52, 14, stone, PI, TAU)
		rect(Rect2(52, 372, 266, 14), Color("d8c9a8"))
		for i in 5:
			rect(Rect2(85 + i * 46, 400, 26, 34), Color("d8c9a8"))
		# Parisian buildings with mansard roofs
		var bx := [Rect2(900, 470, 120, 200), Rect2(1030, 420, 130, 250), Rect2(1170, 450, 110, 220)]
		for b in bx:
			rect(b, Color("f1e3c8"))
			poly([b.position, Vector2(b.end.x, b.position.y), Vector2(b.end.x - 14, b.position.y - 42), Vector2(b.position.x + 14, b.position.y - 42)], Color("7d8fa8"))
			rect(Rect2(b.position.x + 30, b.position.y - 70, 14, 30), Color("c97a5a"))
			for wy in range(int(b.position.y) + 20, int(b.end.y) - 50, 46):
				for wx in range(int(b.position.x) + 14, int(b.end.x) - 20, 30):
					rect(Rect2(wx, wy, 16, 24), Color("9fb4cc"))
				line([Vector2(b.position.x + 8, wy + 26), Vector2(b.end.x - 8, wy + 26)], INK, 3)
		for i in 6:
			rect(Rect2(905 + i * 19, 600, 19, 22), Color("e03131") if i % 2 == 0 else Color.WHITE)
		# street lamps
		for lx in [380.0, 820.0]:
			line([Vector2(lx, 668), Vector2(lx, 560)], INK, 6)
			circle(Vector2(lx, 552), 12, Color("ffe9a8"))
		# floating croissant and baguette
		ring(Vector2(420, 360), 44, 26, Color("e8a84a"), PI * 1.1, PI * 1.9)
		for k in 4:
			var a := PI * 1.2 + k * PI * 0.17
			line([Vector2(420, 360) + Vector2.from_angle(a) * 32, Vector2(420, 360) + Vector2.from_angle(a) * 56], Color("c47f2a"), 3)
		rrot(Vector2(860, 320), Vector2(190, 30), -0.12, Color("e3a857"), 15)
		for k in 4:
			var p := Vector2(800 + k * 40, 325 - k * 5)
			line([p + Vector2(-8, -6), p + Vector2(8, 4)], Color("c47f2a"), 3)

	# =========================================================
	# HAPPY FARM
	# =========================================================
	func farm_sky() -> void:
		grad(Color("8fd3ff"), Color("eafaff"))
		for i in 12:
			var a := TAU * i / 12.0
			poly([Vector2(1150, 90) + Vector2.from_angle(a - 0.1) * 70, Vector2(1150, 90) + Vector2.from_angle(a + 0.1) * 70, Vector2(1150, 90) + Vector2.from_angle(a) * 110], Color("ffd43b"))
		circle(Vector2(1150, 90), 60, Color("ffe066"))
		for h in [Vector2(150, 760), Vector2(500, 800), Vector2(900, 780), Vector2(1250, 760)]:
			circle(h, 260, Color("b2f2bb"))
		for c in [Vector2(520, 110), Vector2(760, 170), Vector2(180, 70)]:
			cloud(c, 1.0, Color(1, 1, 1, 0.85))
		var m := Vector2(960, 420)
		poly([m + Vector2(-26, 0), m + Vector2(26, 0), m + Vector2(14, -130), m + Vector2(-14, -130)], Color("dfe7ef"))
		for k in 4:
			var a := 0.5 + k * PI / 2.0
			line([m + Vector2(0, -130), m + Vector2(0, -130) + Vector2.from_angle(a) * 80], Color("adb5bd"), 10)
		for b in [Vector2(300, 200), Vector2(330, 185), Vector2(620, 250)]:
			line([b + Vector2(-8, -4), b, b + Vector2(8, -4)], INK, 2)
		text(Vector2(640, 300), "moo?", 32, Color("e64980"), 0.12, 8, Color.WHITE)

	func farm_ground() -> void:
		# field
		var pts := []
		for i in 65:
			var x := i * 20.0
			pts.append(Vector2(x, 640 + sin(x * 0.02) * 6))
		poly(pts + [Vector2(W, H), Vector2(0, H)], Color("7cc34a"))
		rect(Rect2(0, 660, W, 60), Color("9a6a3c"))
		for x in range(10, 400, 26):
			for y in [672.0, 692.0, 710.0]:
				circle(Vector2(x, y), 6, Color("5c9e31"))
		# fence
		for fx in range(0, 380, 60):
			rect(Rect2(fx, 580, 10, 62), Color("c99a62"))
		line([Vector2(0, 592), Vector2(380, 592)], Color("c99a62"), 7)
		line([Vector2(0, 616), Vector2(380, 616)], Color("c99a62"), 7)
		# cow
		var cw := Vector2(150, 520)
		for lx in [-60.0, -30.0, 30.0, 60.0]:
			rect(Rect2(cw.x + lx - 8, cw.y + 30, 16, 92), Color("f8f9fa"))
			rect(Rect2(cw.x + lx - 8, cw.y + 110, 16, 12), INK)
		rbox(Rect2(cw.x - 90, cw.y - 50, 180, 90), Color("f8f9fa"), 40)
		ellipse(cw + Vector2(-30, -10), 28, 20, INK, 0.3)
		ellipse(cw + Vector2(40, 10), 22, 16, INK, -0.2)
		ellipse(cw + Vector2(0, 40), 22, 12, Color("ffb3c7"))
		line([cw + Vector2(-90, -20), cw + Vector2(-112, 20)], INK, 4)
		var hd := cw + Vector2(105, -50)
		poly([hd + Vector2(-22, -30), hd + Vector2(-34, -52), hd + Vector2(-12, -38)], Color("fff3bf"))
		poly([hd + Vector2(22, -30), hd + Vector2(34, -52), hd + Vector2(12, -38)], Color("fff3bf"))
		rbox(Rect2(hd - Vector2(38, 38), Vector2(76, 76)), Color("f8f9fa"), 30)
		ellipse(hd + Vector2(0, 22), 32, 18, Color("ffb3c7"))
		circle(hd + Vector2(-10, 22), 4, INK)
		circle(hd + Vector2(10, 22), 4, INK)
		eye(hd + Vector2(-14, -8), 8, Vector2(0.5, 0.2))
		eye(hd + Vector2(14, -8), 8, Vector2(0.5, 0.2))
		# sunflowers
		for f in [[Vector2(330, 640), 300.0], [Vector2(365, 640), 250.0]]:
			var base: Vector2 = f[0]
			var top := base - Vector2(0, f[1])
			line([base, top], Color("40a043"), 7)
			ellipse(top + Vector2(-16, 80), 16, 7, Color("40a043"), -0.5)
			for k in 12:
				circle(top + Vector2.from_angle(TAU * k / 12.0) * 22, 11, Color("ffd43b"))
			circle(top, 18, Color("8a5a2b"))
		# red barn
		rect(Rect2(400, 420, 280, 222), Color("d64545"))
		poly([Vector2(380, 422), Vector2(700, 422), Vector2(660, 330), Vector2(540, 282), Vector2(420, 330)], Color("a83232"))
		line([Vector2(380, 422), Vector2(420, 330), Vector2(540, 282), Vector2(660, 330), Vector2(700, 422)], Color.WHITE, 6)
		rect(Rect2(510, 340, 60, 50), INK)
		for k in 5:
			line([Vector2(514 + k * 12, 390), Vector2(520 + k * 12, 362)], Color("ffd43b"), 3)
		rbox(Rect2(480, 520, 120, 122), Color("b83a3a"), 4)
		line([Vector2(480, 520), Vector2(600, 642)], Color.WHITE, 8)
		line([Vector2(600, 520), Vector2(480, 642)], Color.WHITE, 8)
		ci.draw_rect(Rect2(480, 520, 120, 122), Color.WHITE, false, 6)
		# silo
		rect(Rect2(708, 330, 84, 312), Color("c9ced6"))
		for y in range(360, 640, 40):
			line([Vector2(708, y), Vector2(792, y)], Color("aab2bd"), 3)
		circle(Vector2(750, 330), 42, Color("aab2bd"))
		# hay
		rbox(Rect2(840, 580, 120, 62), Color("f2c94c"), 30)
		for k in 6:
			line([Vector2(855 + k * 17, 590), Vector2(862 + k * 17, 630)], Color("d9a62e"), 2)
		for b in [Rect2(980, 584, 70, 58), Rect2(1052, 584, 70, 58), Rect2(1016, 526, 70, 58)]:
			rbox(b, Color("f2c94c"), 8)
			line([Vector2(b.position.x + 20, b.position.y), Vector2(b.position.x + 20, b.end.y)], Color("c9902a"), 3)
			line([Vector2(b.end.x - 20, b.position.y), Vector2(b.end.x - 20, b.end.y)], Color("c9902a"), 3)
		# tractor
		rbox(Rect2(1120, 560, 130, 56), Color("40a043"), 12)
		rbox(Rect2(1180, 494, 64, 70), Color("2f9e44"), 10)
		rbox(Rect2(1190, 504, 44, 32), Color("a5d8ff"), 6)
		line([Vector2(1140, 560), Vector2(1140, 520)], INK, 6)
		wheel(Vector2(1215, 618), 40, Color("ffd43b"))
		wheel(Vector2(1135, 626), 24, Color("ffd43b"))
		# clouds to climb on
		cloud(Vector2(300, 190), 0.9, Color.WHITE)
		cloud(Vector2(860, 230), 1.0, Color.WHITE)
		cloud(Vector2(1120, 360), 0.8, Color.WHITE)
		cloud(Vector2(600, 150), 0.7, Color.WHITE)
