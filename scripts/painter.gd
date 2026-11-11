class_name Painter
## Renders smooth cartoon shapes with a dark outline into a texture, using signed distance functions.
## Shapes live in a 16x16 "unit" box (y down). Shape types:
##  circle {c, r}   ellipse {c, e}   box {c, h, r, rot}   capsule {a, b, r}
##  crescent {c, r, c2, r2}   ring {c, r, th}
## Every shape has "col"; shapes with "ol" (outline width in units) get an outline drawn first.

const OUTLINE := Color(0.23, 0.14, 0.13)


static func sdf(s: Dictionary, p: Vector2) -> float:
	match s["t"]:
		"circle":
			return p.distance_to(s["c"]) - s["r"]
		"ellipse":
			var e: Vector2 = s["e"]
			var q: Vector2 = (p - s["c"]) / e
			return (q.length() - 1.0) * minf(e.x, e.y)
		"box":
			var q: Vector2 = p - s["c"]
			if s.has("rot"):
				q = q.rotated(-float(s["rot"]))
			var r: float = s.get("r", 0.0)
			var hh: Vector2 = s["h"]
			var d := q.abs() - hh + Vector2(r, r)
			return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length() + minf(maxf(d.x, d.y), 0.0) - r
		"capsule":
			var a: Vector2 = s["a"]
			var ba: Vector2 = s["b"] - a
			var pa := p - a
			var hh := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
			return (pa - ba * hh).length() - s["r"]
		"crescent":
			return maxf(p.distance_to(s["c"]) - s["r"], -(p.distance_to(s["c2"]) - s["r2"]))
		"ring":
			return absf(p.distance_to(s["c"]) - s["r"]) - s["th"]
	return 1e9


static func _over(dst: Color, src: Color) -> Color:
	var a := src.a + dst.a * (1.0 - src.a)
	if a <= 0.0001:
		return Color(0, 0, 0, 0)
	var r := (src.r * src.a + dst.r * dst.a * (1.0 - src.a)) / a
	var g := (src.g * src.a + dst.g * dst.a * (1.0 - src.a)) / a
	var b := (src.b * src.a + dst.b * dst.a * (1.0 - src.a)) / a
	return Color(r, g, b, a)


static func _bbox(s: Dictionary) -> Rect2:
	match s["t"]:
		"circle":
			var r: float = s["r"]
			return Rect2(s["c"] - Vector2(r, r), Vector2(r, r) * 2.0)
		"ellipse":
			var e: Vector2 = s["e"]
			return Rect2(s["c"] - e, e * 2.0)
		"box":
			var l: float = (s["h"] as Vector2).length()
			return Rect2(s["c"] - Vector2(l, l), Vector2(l, l) * 2.0)
		"capsule":
			var r: float = s["r"]
			var a: Vector2 = s["a"]
			var b: Vector2 = s["b"]
			var mn := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(r, r)
			var mx := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(r, r)
			return Rect2(mn, mx - mn)
		"crescent":
			var r: float = s["r"]
			return Rect2(s["c"] - Vector2(r, r), Vector2(r, r) * 2.0)
		"ring":
			var r: float = s["r"] + s["th"]
			return Rect2(s["c"] - Vector2(r, r), Vector2(r, r) * 2.0)
	return Rect2(0, 0, 999, 999)


## Renders shapes to a res x res texture. Only pixels inside each shape's box are evaluated.
static func render(shapes: Array, res := 48, units := 16.0) -> ImageTexture:
	var k := units / res
	var buf := PackedColorArray()
	buf.resize(res * res)
	buf.fill(Color(0, 0, 0, 0))
	for pass_i in 2:
		for s in shapes:
			var ol: float = s.get("ol", 0.0)
			if pass_i == 0 and ol <= 0.0:
				continue
			var grow := (ol if pass_i == 0 else 0.0) + k * 2.0
			var bb := _bbox(s).grow(grow)
			var x0 := clampi(int(bb.position.x / k), 0, res - 1)
			var y0 := clampi(int(bb.position.y / k), 0, res - 1)
			var x1 := clampi(int(bb.end.x / k) + 1, 0, res - 1)
			var y1 := clampi(int(bb.end.y / k) + 1, 0, res - 1)
			var c: Color = OUTLINE if pass_i == 0 else s["col"]
			var off := ol if pass_i == 0 else 0.0
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					var p := Vector2((x + 0.5) * k, (y + 0.5) * k)
					var cov := clampf(0.5 - (sdf(s, p) - off) / k, 0.0, 1.0)
					if cov > 0.0:
						var i := y * res + x
						buf[i] = _over(buf[i], Color(c, c.a * cov))
	var img := Image.create(res, res, false, Image.FORMAT_RGBA8)
	for y in res:
		for x in res:
			img.set_pixel(x, y, buf[y * res + x])
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
