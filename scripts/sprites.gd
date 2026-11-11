class_name Sprites
## Cute cartoon art: weapon icons, gibs (made with Painter) and the critters (drawn live).

const INK := Color(0.23, 0.14, 0.13)
const OL := 0.9

static var _cache := {}
static var _critters := {}

const CRIT_UNITS := 24.0
const CRIT_ORIGIN := Vector2(12, 13)
static var _dot: ImageTexture = null


static func _shapes(id: String) -> Array:
	var W := Color(1, 1, 1, 0.55)
	match id:
		"bazooka":
			return [
				{"t": "box", "c": Vector2(6.5, 10.6), "h": Vector2(0.9, 1.8), "r": 0.5, "col": Color("a0663a"), "ol": OL},
				{"t": "capsule", "a": Vector2(2.6, 8.0), "b": Vector2(12.6, 7.2), "r": 2.3, "col": Color("7ccf6f"), "ol": OL},
				{"t": "box", "c": Vector2(1.9, 8.1), "h": Vector2(1.2, 2.8), "r": 0.7, "col": Color("ffa94d"), "ol": OL},
				{"t": "circle", "c": Vector2(13.6, 7.1), "r": 2.0, "col": Color("ff6b6b"), "ol": OL},
				{"t": "capsule", "a": Vector2(4.0, 6.7), "b": Vector2(11.0, 6.1), "r": 0.45, "col": W},
			]
		"grenade":
			return [
				{"t": "ring", "c": Vector2(11.0, 3.3), "r": 1.5, "th": 0.35, "col": Color("c9ced6"), "ol": OL},
				{"t": "box", "c": Vector2(8.0, 4.6), "h": Vector2(1.9, 1.3), "r": 0.5, "col": Color("aab2bd"), "ol": OL},
				{"t": "circle", "c": Vector2(8.0, 9.8), "r": 4.9, "col": Color("8fd66f"), "ol": OL},
				{"t": "capsule", "a": Vector2(5.2, 9.8), "b": Vector2(10.8, 9.8), "r": 0.35, "col": Color("5fa84a")},
				{"t": "circle", "c": Vector2(6.3, 8.0), "r": 1.3, "col": W},
			]
		"banana", "banana_small":
			return [
				{"t": "crescent", "c": Vector2(7.6, 7.4), "r": 6.6, "c2": Vector2(9.8, 4.4), "r2": 6.3, "col": Color("ffe066"), "ol": OL},
				{"t": "capsule", "a": Vector2(12.7, 2.7), "b": Vector2(14.0, 1.4), "r": 0.8, "col": Color("8a5a2b"), "ol": OL},
				{"t": "crescent", "c": Vector2(7.6, 7.4), "r": 5.6, "c2": Vector2(8.6, 5.6), "r2": 5.6, "col": Color(1, 1, 1, 0.35)},
			]
		"shotgun":
			return [
				{"t": "box", "c": Vector2(2.6, 9.8), "h": Vector2(1.7, 2.4), "r": 1.0, "rot": 0.35, "col": Color("c98b4f"), "ol": OL},
				{"t": "capsule", "a": Vector2(4.5, 6.6), "b": Vector2(14.8, 6.6), "r": 1.2, "col": Color("b8c2cf"), "ol": OL},
				{"t": "capsule", "a": Vector2(4.5, 8.6), "b": Vector2(13.6, 8.6), "r": 1.0, "col": Color("8e99a8"), "ol": OL},
				{"t": "box", "c": Vector2(5.6, 8.2), "h": Vector2(2.6, 1.8), "r": 0.8, "col": Color("d99a5c"), "ol": OL},
				{"t": "capsule", "a": Vector2(6.0, 6.1), "b": Vector2(13.5, 6.1), "r": 0.3, "col": W},
			]
		"minigun":
			return [
				{"t": "box", "c": Vector2(4.2, 12.0), "h": Vector2(1.0, 1.7), "r": 0.5, "col": Color("ffa94d"), "ol": OL},
				{"t": "capsule", "a": Vector2(6.0, 6.0), "b": Vector2(15.0, 6.0), "r": 0.8, "col": Color("b8c2cf"), "ol": OL},
				{"t": "capsule", "a": Vector2(6.0, 7.8), "b": Vector2(15.0, 7.8), "r": 0.8, "col": Color("b8c2cf"), "ol": OL},
				{"t": "capsule", "a": Vector2(6.0, 9.6), "b": Vector2(15.0, 9.6), "r": 0.8, "col": Color("b8c2cf"), "ol": OL},
				{"t": "box", "c": Vector2(4.6, 7.8), "h": Vector2(3.4, 3.2), "r": 1.4, "col": Color("7b8da6"), "ol": OL},
				{"t": "circle", "c": Vector2(4.6, 7.8), "r": 1.2, "col": Color("ff6b6b")},
			]
		"dirt":
			return [
				{"t": "box", "c": Vector2(6.2, 9.0), "h": Vector2(4.6, 2.6), "r": 1.2, "col": Color("b07a45"), "ol": OL},
				{"t": "box", "c": Vector2(12.4, 9.0), "h": Vector2(1.9, 3.6), "r": 0.9, "col": Color("7ccf6f"), "ol": OL},
				{"t": "circle", "c": Vector2(13.0, 3.6), "r": 2.0, "col": Color("8a5a2b"), "ol": OL},
				{"t": "circle", "c": Vector2(12.4, 3.0), "r": 0.6, "col": W},
				{"t": "capsule", "a": Vector2(3.0, 7.6), "b": Vector2(9.0, 7.6), "r": 0.35, "col": W},
			]
		"pistol":
			return [
				{"t": "box", "c": Vector2(5.4, 10.2), "h": Vector2(1.6, 2.9), "r": 0.8, "rot": 0.25, "col": Color("a0663a"), "ol": OL},
				{"t": "box", "c": Vector2(8.8, 7.0), "h": Vector2(5.0, 1.8), "r": 0.9, "col": Color("b8c2cf"), "ol": OL},
				{"t": "circle", "c": Vector2(13.4, 7.0), "r": 0.8, "col": INK},
				{"t": "capsule", "a": Vector2(5.0, 6.0), "b": Vector2(12.0, 6.0), "r": 0.35, "col": W},
			]
		"uzi":
			return [
				{"t": "box", "c": Vector2(8.0, 11.2), "h": Vector2(1.2, 2.8), "r": 0.5, "col": Color("ffa94d"), "ol": OL},
				{"t": "box", "c": Vector2(4.4, 10.0), "h": Vector2(1.3, 2.2), "r": 0.6, "rot": 0.2, "col": Color("5c6b80"), "ol": OL},
				{"t": "capsule", "a": Vector2(11.0, 6.8), "b": Vector2(15.0, 6.8), "r": 0.8, "col": Color("b8c2cf"), "ol": OL},
				{"t": "box", "c": Vector2(7.6, 7.2), "h": Vector2(4.4, 2.1), "r": 1.0, "col": Color("7b8da6"), "ol": OL},
				{"t": "capsule", "a": Vector2(4.6, 6.0), "b": Vector2(10.4, 6.0), "r": 0.35, "col": W},
			]
		"mega_bomb":
			return [
				{"t": "capsule", "a": Vector2(11.0, 5.2), "b": Vector2(13.2, 2.8), "r": 0.6, "col": Color("8a5a2b"), "ol": OL},
				{"t": "circle", "c": Vector2(8.0, 9.6), "r": 5.6, "col": Color("5a5a7a"), "ol": OL},
				{"t": "box", "c": Vector2(10.6, 5.6), "h": Vector2(1.6, 1.1), "r": 0.4, "rot": -0.7, "col": Color("8e99a8"), "ol": OL},
				{"t": "circle", "c": Vector2(13.6, 2.3), "r": 1.5, "col": Color("ffe066")},
				{"t": "circle", "c": Vector2(5.8, 7.4), "r": 1.6, "col": W},
				{"t": "circle", "c": Vector2(6.6, 10.6), "r": 0.8, "col": Color.WHITE},
				{"t": "circle", "c": Vector2(9.8, 10.6), "r": 0.8, "col": Color.WHITE},
			]
		"homing":
			return [
				{"t": "box", "c": Vector2(3.4, 8.0), "h": Vector2(1.3, 3.8), "r": 0.7, "col": Color("ff6b6b"), "ol": OL},
				{"t": "capsule", "a": Vector2(3.4, 8.0), "b": Vector2(11.6, 8.0), "r": 2.2, "col": Color("f2f4f8"), "ol": OL},
				{"t": "circle", "c": Vector2(12.6, 8.0), "r": 2.2, "col": Color("ff6b6b"), "ol": OL},
				{"t": "circle", "c": Vector2(8.0, 8.0), "r": 1.1, "col": Color("5bb8ff")},
				{"t": "capsule", "a": Vector2(4.5, 6.6), "b": Vector2(10.5, 6.6), "r": 0.35, "col": W},
			]
		"laser":
			return [
				{"t": "box", "c": Vector2(5.0, 11.0), "h": Vector2(1.2, 2.0), "r": 0.6, "rot": 0.2, "col": Color("8a6ad0"), "ol": OL},
				{"t": "capsule", "a": Vector2(9.5, 8.0), "b": Vector2(14.2, 8.0), "r": 1.1, "col": Color("6ef4ff"), "ol": OL},
				{"t": "box", "c": Vector2(6.4, 8.2), "h": Vector2(4.4, 2.4), "r": 1.3, "col": Color("c6b2ff"), "ol": OL},
				{"t": "circle", "c": Vector2(14.6, 8.0), "r": 1.0, "col": Color.WHITE},
				{"t": "circle", "c": Vector2(5.0, 8.2), "r": 0.9, "col": Color("ff74d8")},
				{"t": "circle", "c": Vector2(7.6, 8.2), "r": 0.9, "col": Color("6ef4ff")},
			]
		"napalm":
			return [
				{"t": "box", "c": Vector2(8.0, 3.9), "h": Vector2(2.2, 1.2), "r": 0.5, "col": Color("aab2bd"), "ol": OL},
				{"t": "box", "c": Vector2(8.0, 9.6), "h": Vector2(3.8, 4.6), "r": 1.6, "col": Color("ff6b6b"), "ol": OL},
				{"t": "circle", "c": Vector2(8.0, 10.4), "r": 2.0, "col": Color("ffd166")},
				{"t": "circle", "c": Vector2(8.0, 8.6), "r": 1.1, "col": Color("ffd166")},
				{"t": "capsule", "a": Vector2(5.6, 6.0), "b": Vector2(5.6, 12.6), "r": 0.4, "col": W},
			]
		"health":
			return [
				{"t": "circle", "c": Vector2(5.4, 6.6), "r": 3.4, "col": Color("ff5c7a"), "ol": OL},
				{"t": "circle", "c": Vector2(10.6, 6.6), "r": 3.4, "col": Color("ff5c7a"), "ol": OL},
				{"t": "box", "c": Vector2(8.0, 9.2), "h": Vector2(3.6, 3.6), "r": 0.9, "rot": PI / 4.0, "col": Color("ff5c7a"), "ol": OL},
				{"t": "circle", "c": Vector2(4.6, 5.4), "r": 1.1, "col": W},
			]
		"gib_meat":
			return [
				{"t": "circle", "c": Vector2(7.5, 8.5), "r": 4.6, "col": Color("ff7f9e"), "ol": OL},
				{"t": "circle", "c": Vector2(10.2, 6.6), "r": 3.2, "col": Color("ff7f9e"), "ol": OL},
				{"t": "circle", "c": Vector2(6.5, 9.5), "r": 1.6, "col": Color("d6456b")},
				{"t": "circle", "c": Vector2(10.4, 6.0), "r": 0.9, "col": W},
			]
		"gib_bone":
			return [
				{"t": "capsule", "a": Vector2(4.0, 8.0), "b": Vector2(12.0, 8.0), "r": 1.4, "col": Color("fff6e0"), "ol": OL},
				{"t": "circle", "c": Vector2(3.4, 6.8), "r": 1.7, "col": Color("fff6e0"), "ol": OL},
				{"t": "circle", "c": Vector2(3.4, 9.2), "r": 1.7, "col": Color("fff6e0"), "ol": OL},
				{"t": "circle", "c": Vector2(12.6, 6.8), "r": 1.7, "col": Color("fff6e0"), "ol": OL},
				{"t": "circle", "c": Vector2(12.6, 9.2), "r": 1.7, "col": Color("fff6e0"), "ol": OL},
			]
		"gib_eye":
			return [
				{"t": "circle", "c": Vector2(8.0, 8.0), "r": 4.6, "col": Color("ffffff"), "ol": OL},
				{"t": "circle", "c": Vector2(9.4, 8.0), "r": 2.4, "col": Color("5bb8ff")},
				{"t": "circle", "c": Vector2(9.9, 8.0), "r": 1.2, "col": INK},
				{"t": "circle", "c": Vector2(9.0, 7.0), "r": 0.6, "col": Color.WHITE},
				{"t": "capsule", "a": Vector2(3.6, 8.5), "b": Vector2(2.0, 10.5), "r": 0.6, "col": Color("ff5c7a"), "ol": 0.5},
			]
	return _shapes("bazooka")


static func icon(id: String) -> ImageTexture:
	if id == "banana_small":
		id = "banana"
	if not _cache.has(id):
		_cache[id] = Painter.render(_shapes(id), 72)
	return _cache[id]


## Soft round particle texture (white, alpha falls off to the edge).
static func dot() -> ImageTexture:
	if _dot == null:
		var s := 32
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		for y in s:
			for x in s:
				var d := Vector2(x + 0.5 - s / 2.0, y + 0.5 - s / 2.0).length() / (s / 2.0)
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
		img.generate_mipmaps()
		_dot = ImageTexture.create_from_image(img)
	return _dot


## Body of a critter baked into a texture (faces right). Eyes' pupils are drawn live.
static func critter_tex(col: Color, accessory: int) -> ImageTexture:
	var key := "%s_%d" % [col.to_html(), accessory % 4]
	if _critters.has(key):
		return _critters[key]
	var o := CRIT_ORIGIN
	var dark := col.darkened(0.3)
	var light := col.lightened(0.4)
	var sh: Array = []
	for fx in [-2.8, 2.8]:
		sh.append({"t": "ellipse", "c": o + Vector2(fx, 5.9), "e": Vector2(2.4, 1.7), "col": dark, "ol": OL})
	match accessory % 4:
		0:
			for ex in [-4.0, 4.0]:
				sh.append({"t": "circle", "c": o + Vector2(ex, -4.8), "r": 2.1, "col": col, "ol": OL})
				sh.append({"t": "circle", "c": o + Vector2(ex, -5.0), "r": 1.0, "col": Color("ffb3c7")})
		1:
			sh.append({"t": "capsule", "a": o + Vector2(0, -6), "b": o + Vector2(1.8, -9.4), "r": 0.45, "col": INK, "ol": 0.3})
			sh.append({"t": "circle", "c": o + Vector2(1.8, -9.8), "r": 1.5, "col": Color("ffe066"), "ol": OL})
		2:
			sh.append({"t": "capsule", "a": o + Vector2(0, -6), "b": o + Vector2(0, -8.6), "r": 0.45, "col": Color("5fa84a"), "ol": 0.4})
			sh.append({"t": "ellipse", "c": o + Vector2(-1.9, -9.0), "e": Vector2(1.9, 1.2), "col": Color("7ccf6f"), "ol": OL})
			sh.append({"t": "ellipse", "c": o + Vector2(1.9, -9.3), "e": Vector2(1.9, 1.2), "col": Color("7ccf6f"), "ol": OL})
		3:
			sh.append({"t": "capsule", "a": o + Vector2(-3.0, -4.6), "b": o + Vector2(-4.4, -8.2), "r": 1.0, "col": Color("fff0c2"), "ol": OL})
			sh.append({"t": "capsule", "a": o + Vector2(3.0, -4.6), "b": o + Vector2(4.4, -8.2), "r": 1.0, "col": Color("fff0c2"), "ol": OL})
	sh.append({"t": "circle", "c": o, "r": 6.5, "col": col, "ol": OL})
	sh.append({"t": "circle", "c": o + Vector2(0.8, 2.1), "r": 4.0, "col": light})
	sh.append({"t": "circle", "c": o + Vector2(-2.6, -3.4), "r": 1.4, "col": Color(1, 1, 1, 0.45)})
	sh.append({"t": "circle", "c": o + Vector2(4.6, 1.6), "r": 1.1, "col": Color(1.0, 0.45, 0.55, 0.55)})
	sh.append({"t": "circle", "c": o + Vector2(-0.6, 1.9), "r": 1.1, "col": Color(1.0, 0.45, 0.55, 0.55)})
	for ex in [-1.2, 3.6]:
		sh.append({"t": "circle", "c": o + Vector2(ex, -1.6), "r": 2.5, "col": INK})
		sh.append({"t": "circle", "c": o + Vector2(ex, -1.6), "r": 1.9, "col": Color.WHITE})
	sh.append({"t": "crescent", "c": o + Vector2(1.6, 0.9), "r": 1.5, "c2": o + Vector2(1.6, 0.1), "r2": 1.6, "col": INK})
	var tex := Painter.render(sh, 96, CRIT_UNITS)
	_critters[key] = tex
	return tex


## Draws a critter centred at pos: one baked texture plus live pupils.
static func draw_critter(ci: CanvasItem, pos: Vector2, scale: float, col: Color, facing: int,
		look: Vector2, walk: float, moving: bool, accessory: int, blink: bool) -> void:
	var bounce := sin(walk) * 0.07 if moving else 0.0
	var sx := scale * (1.0 + bounce)
	var sy := scale * (1.0 - bounce)
	var f := float(facing)
	ci.draw_set_transform(pos, 0.0, Vector2(sx * f, sy))
	ci.draw_texture_rect(critter_tex(col, accessory), Rect2(-CRIT_ORIGIN, Vector2(CRIT_UNITS, CRIT_UNITS)), false)
	var lk := look.normalized() * 0.8 if look.length() > 0.01 else Vector2.ZERO
	lk.x *= f  # we are in the flipped space
	for ex in [-1.2, 3.6]:
		var ec := Vector2(ex, -1.6)
		if blink:
			ci.draw_circle(ec, 2.1, col)
			ci.draw_line(ec + Vector2(-1.6, 0), ec + Vector2(1.6, 0), INK, 0.9)
		else:
			ci.draw_circle(ec + lk, 1.15, INK)
			ci.draw_circle(ec + lk + Vector2(-0.4, -0.45), 0.45, Color.WHITE)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
