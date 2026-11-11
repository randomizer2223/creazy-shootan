class_name MapGen
## Генерація мап. Повертає {"fg": Image, "bg": Image, "mask": PackedByteArray, "dirt": Array[Color]}.
## 10 вбудованих мап + будь-яка картинка гравця.

const PRESETS := [
	{"name": "Cat Chaos", "style": "art", "art": "cats", "seed": 1},
	{"name": "Cookie Caves", "style": "cave", "seed": 101, "freq": 0.008,
		"pal": ["a8683a", "c98a52", "e6b07a"], "top": "7a4a2a", "top_h": 0, "sky": []},
	{"name": "Green Islands", "style": "islands", "seed": 202, "freq": 0.006,
		"pal": ["9a6440", "b67b50", "d29a6a"], "top": "86de5c", "top_h": 7, "sky": ["7cc8ff", "e6f6ff"]},
	{"name": "Ice Cave", "style": "cave", "seed": 303, "freq": 0.007,
		"pal": ["86bfe8", "aedcf7", "eefaff"], "top": "ffffff", "top_h": 6, "sky": []},
	{"name": "Volcano", "style": "islands", "seed": 404, "freq": 0.007,
		"pal": ["6a4258", "86506a", "ff8a5a"], "top": "ffb347", "top_h": 5, "sky": ["4a2350", "ff9a7a"]},
	{"name": "Desert", "style": "dunes", "seed": 505, "freq": 0.01,
		"pal": ["e8b46a", "f2c886", "fbe2b0"], "top": "fff2cf", "top_h": 5, "sky": ["ffb08a", "fff2d8"]},
	{"name": "Jungle", "style": "cave", "seed": 606, "freq": 0.009,
		"pal": ["4a8a42", "64a852", "94d462"], "top": "c2f56e", "top_h": 6, "sky": []},
	{"name": "Candy Kingdom", "style": "islands", "seed": 707, "freq": 0.008,
		"pal": ["ff8fc0", "ffb5d8", "fff0f8"], "top": "a8f0e0", "top_h": 8, "sky": ["c6b2ff", "ffe8f6"]},
	{"name": "The Moon", "style": "craters", "seed": 808, "freq": 0.005,
		"pal": ["9494b8", "b0b0d0", "d8d8ee"], "top": "eeeefa", "top_h": 4, "sky": ["1c1c44", "4a4a80"]},
	{"name": "Cheese World", "style": "cheese", "seed": 909, "freq": 0.02,
		"pal": ["f5c040", "ffd65a", "ffe98e"], "top": "fff2b8", "top_h": 0, "sky": []},
	{"name": "Neon City", "style": "city", "seed": 1010, "freq": 0.01,
		"pal": ["4a3878", "5c4890", "6ef4ff"], "top": "ff74d8", "top_h": 4, "sky": ["1e1240", "6a3290"]},
]

const W := 1280
const H := 720


static func preset_names() -> Array:
	var out := []
	for p in PRESETS:
		out.append(p["name"])
	return out


static var _cache_index := -1
static var _cache: Dictionary = {}


## Same map as last time (menu background -> match) is reused instead of generated again.
static func build(index: int) -> Dictionary:
	if index == _cache_index and not _cache.is_empty():
		return copy(_cache)
	var d := _build(index)
	_cache_index = index
	_cache = d
	return copy(d)


## The match changes the ground mask, so each user gets its own copy of it.
static func copy(d: Dictionary) -> Dictionary:
	var c := d.duplicate()
	c["mask"] = (d["mask"] as PackedByteArray).duplicate()
	return c


static func _build(index: int) -> Dictionary:
	var p: Dictionary = PRESETS[clampi(index, 0, PRESETS.size() - 1)]
	if p["style"] == "art":
		p = PRESETS[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = p["seed"]
	var mask := PackedByteArray()
	mask.resize(W * H)
	var noise := FastNoiseLite.new()
	noise.seed = p["seed"]
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = p["freq"]
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var nd := noise.get_image(W, H).get_data()

	match p["style"]:
		"cave":
			_mask_cave(mask, nd, rng)
		"islands":
			_mask_islands(mask, nd)
		"dunes":
			_mask_dunes(mask, nd)
		"craters":
			_mask_islands(mask, nd)
			_add_craters(mask, rng)
		"cheese":
			_mask_cheese(mask, rng)
		"city":
			_mask_city(mask, nd, rng)
	return _colorize(mask, p)


# ---------- форми мап ----------

static func _circle(mask: PackedByteArray, c: Vector2, r: float, val: int) -> void:
	var ri := int(ceil(r))
	var r2 := r * r
	for y in range(maxi(int(c.y) - ri, 0), mini(int(c.y) + ri, H - 1) + 1):
		var dy := float(y) - c.y
		for x in range(maxi(int(c.x) - ri, 0), mini(int(c.x) + ri, W - 1) + 1):
			var dx := float(x) - c.x
			if dx * dx + dy * dy <= r2:
				mask[y * W + x] = val


static func _mask_cave(mask: PackedByteArray, nd: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var n := W * H
	for i in n:
		mask[i] = 1 if nd[i] > 105 else 0
	for k in 7:
		_circle(mask, Vector2(rng.randf_range(80, W - 80), rng.randf_range(80, H - 80)), rng.randf_range(28, 55), 0)


static func _mask_islands(mask: PackedByteArray, nd: PackedByteArray) -> void:
	for y in H:
		var g := float(y) / H * 290.0 - 150.0
		var row := y * W
		for x in W:
			mask[row + x] = 1 if float(nd[row + x]) + g > 150.0 else 0


static func _mask_dunes(mask: PackedByteArray, nd: PackedByteArray) -> void:
	for x in W:
		var surf := H * 0.62 + sin(x * 0.008) * 55.0 + sin(x * 0.023 + 1.0) * 22.0
		for y in H:
			var i := y * W + x
			var v := float(nd[i])
			var solid := float(y) > surf + (v - 128.0) * 0.25
			if not solid and y < H * 0.5 and v > 212.0:
				solid = true  # летючі пласкі острівці
			mask[i] = 1 if solid else 0


static func _add_craters(mask: PackedByteArray, rng: RandomNumberGenerator) -> void:
	for k in 28:
		var x := rng.randi_range(30, W - 30)
		var y := 0
		while y < H - 1 and mask[y * W + x] == 0:
			y += 1
		var r := rng.randf_range(14, 48)
		_circle(mask, Vector2(x, y + r * 0.35), r, 0)


static func _mask_cheese(mask: PackedByteArray, rng: RandomNumberGenerator) -> void:
	mask.fill(1)
	for y in 45:
		for x in W:
			mask[y * W + x] = 0
	for k in 150:
		_circle(mask, Vector2(rng.randf_range(10, W - 10), rng.randf_range(30, H - 10)), rng.randf_range(6, 40), 0)


static func _mask_city(mask: PackedByteArray, nd: PackedByteArray, rng: RandomNumberGenerator) -> void:
	mask.fill(0)
	var ground := H - 70
	for y in range(ground, H):
		for x in W:
			mask[y * W + x] = 1
	var x := rng.randi_range(10, 40)
	while x < W - 40:
		var bw := rng.randi_range(50, 120)
		var bh := rng.randi_range(120, 470)
		for y in range(ground - bh, ground):
			for xx in range(x, mini(x + bw, W)):
				mask[y * W + xx] = 1
		# дах-антена
		if rng.randf() < 0.5:
			var ax := x + bw / 2
			for y in range(ground - bh - 30, ground - bh):
				for xx in range(ax - 1, ax + 2):
					mask[y * W + xx] = 1
		x += bw + rng.randi_range(25, 80)
	# летючі білборди
	for k in 6:
		var bx := rng.randi_range(40, W - 160)
		var by := rng.randi_range(60, 260)
		for y in range(by, by + 12):
			for xx in range(bx, bx + rng.randi_range(70, 120)):
				if xx < W:
					mask[y * W + xx] = 1


# ---------- розфарбовування ----------

static func _colorize(mask: PackedByteArray, p: Dictionary) -> Dictionary:
	var pal: Array = []
	for hx in p["pal"]:
		pal.append(Color.html(hx))
	var top := Color.html(p["top"])
	var top_h: int = p["top_h"]
	var sky: Array = []
	for hx in p["sky"]:
		sky.append(Color.html(hx))
	var style: String = p["style"]
	var is_city := style == "city"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p["seed"]) * 31 + 5

	var detail := FastNoiseLite.new()
	detail.seed = int(p["seed"]) + 7
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.frequency = 0.02
	detail.fractal_octaves = 2
	var dd := detail.get_image(W, H).get_data()

	# color lookup tables (LUT) for speed
	var lut := PackedByteArray()
	lut.resize(256 * 3)
	var blut := PackedByteArray()
	blut.resize(256 * 3)
	for v in 256:
		var t := v / 255.0
		var c: Color = pal[0].lerp(pal[1], smoothstep(0.0, 0.75, t))
		if t > 0.8:
			c = c.lerp(pal[2], (t - 0.8) / 0.2 * 0.8)
		if is_city:
			c = pal[0].lerp(pal[1], t)
		var b := c.darkened(0.5).lerp(Color(0.25, 0.2, 0.35), 0.25)
		lut[v * 3] = c.r8
		lut[v * 3 + 1] = c.g8
		lut[v * 3 + 2] = c.b8
		blut[v * 3] = b.r8
		blut[v * 3 + 1] = b.g8
		blut[v * 3 + 2] = b.b8

	# sky: one color per row + two layers of distant hills
	var has_sky := sky.size() == 2
	var sky_rows := PackedByteArray()
	var hills := PackedFloat32Array()
	var hills2 := PackedFloat32Array()
	var h1 := Color.BLACK
	var h2 := Color.BLACK
	if has_sky:
		sky_rows.resize(H * 3)
		for y in H:
			var c: Color = sky[0].lerp(sky[1], pow(float(y) / H, 0.8))
			sky_rows[y * 3] = c.r8
			sky_rows[y * 3 + 1] = c.g8
			sky_rows[y * 3 + 2] = c.b8
		hills.resize(W)
		hills2.resize(W)
		var ph := rng.randf() * 10.0
		for x in W:
			hills[x] = H * 0.5 + sin(x * 0.006 + ph) * 55.0 + sin(x * 0.017 + ph * 2.0) * 22.0 + sin(x * 0.05) * 5.0
			hills2[x] = H * 0.36 + sin(x * 0.004 + ph * 3.0) * 70.0 + sin(x * 0.011) * 25.0
		h1 = sky[1].lerp(pal[0], 0.35).lerp(sky[0], 0.35).darkened(0.25)
		h2 = sky[1].lerp(sky[0], 0.45).lerp(h1, 0.35)
	var tr := top.r8
	var tg := top.g8
	var tb := top.b8
	var neon: Color = pal[2]
	var city_ground := H - 70

	var fg := PackedByteArray()
	fg.resize(W * H * 4)
	var bg := PackedByteArray()
	bg.resize(W * H * 4)
	var run := PackedInt32Array()
	run.resize(W)
	run.fill(0)
	# icing drips under the top layer
	var drip := PackedInt32Array()
	drip.resize(W)
	var dph := rng.randf() * 10.0
	for x in W:
		drip[x] = maxi(0, int(sin(x * 0.13 + dph) * 2.5 + sin(x * 0.047) * 2.0 + 1.0)) if top_h > 0 else 0

	for y in H:
		var row := y * W
		for x in W:
			var i := row + x
			var o := i * 4
			var v := dd[i]
			var grain := ((i * 1103515245 + 12345) >> 16) & 15
			if mask[i] != 0:
				run[x] += 1
				if run[x] <= top_h + drip[x] and top_h > 0:
					var gv := (grain >> 2) - 2
					fg[o] = clampi(tr + gv, 0, 255)
					fg[o + 1] = clampi(tg + gv, 0, 255)
					fg[o + 2] = clampi(tb + gv, 0, 255)
				elif is_city and y < city_ground and (x % 10) < 4 and (y % 14) < 6 and ((x / 10 + y / 14) % 3) != 0:
					var lit := 1.0 if ((x / 10 * 7 + y / 14 * 3) % 5) != 0 else 0.35
					fg[o] = int(neon.r8 * lit)
					fg[o + 1] = int(neon.g8 * lit)
					fg[o + 2] = int(neon.b8 * lit)
				else:
					var dk := 1.0
					var gr := (grain >> 2) - 2
					fg[o] = clampi(int(lut[v * 3] * dk) + gr, 0, 255)
					fg[o + 1] = clampi(int(lut[v * 3 + 1] * dk) + gr, 0, 255)
					fg[o + 2] = clampi(int(lut[v * 3 + 2] * dk) + gr, 0, 255)
				fg[o + 3] = 255
			else:
				run[x] = 0
			if has_sky and mask[i] == 0:
				var fy := float(y)
				if fy > hills[x]:
					bg[o] = h1.r8
					bg[o + 1] = h1.g8
					bg[o + 2] = h1.b8
				elif fy > hills2[x]:
					bg[o] = h2.r8
					bg[o + 1] = h2.g8
					bg[o + 2] = h2.b8
				else:
					bg[o] = sky_rows[y * 3]
					bg[o + 1] = sky_rows[y * 3 + 1]
					bg[o + 2] = sky_rows[y * 3 + 2]
			else:
				# underground / caves: dark dirt, like in Liero
				bg[o] = blut[v * 3]
				bg[o + 1] = blut[v * 3 + 1]
				bg[o + 2] = blut[v * 3 + 2]
			bg[o + 3] = 255

	# --- rocks buried in the ground ---
	if not is_city:
		var stone: Color = pal[2].lerp(pal[1], 0.3)
		if style == "cheese":
			stone = pal[2].lightened(0.2)
		for k in 150:
			var cx := rng.randi_range(8, W - 9)
			var cy := rng.randi_range(8, H - 9)
			if mask[cy * W + cx] != 1 or cy < 14 or mask[(cy - 12) * W + cx] != 1:
				continue
			var r := rng.randf_range(1.8, 5.0)
			var ri := int(ceil(r))
			for yy in range(maxi(cy - ri, 0), mini(cy + ri, H - 1) + 1):
				for xx in range(maxi(cx - ri, 0), mini(cx + ri, W - 1) + 1):
					var dx := float(xx - cx)
					var dy := float(yy - cy)
					var d := sqrt(dx * dx + dy * dy)
					var ii := yy * W + xx
					if d > r or mask[ii] != 1:
						continue
					var c := stone
					if d > r - 1.0:
						c = stone.darkened(0.15)
					else:
						var light := (-dx * 0.6 - dy * 0.8) / maxf(r, 1.0)
						c = stone.lightened(light * 0.35) if light > 0.0 else stone.darkened(-light * 0.3)
					var oo := ii * 4
					fg[oo] = c.r8
					fg[oo + 1] = c.g8
					fg[oo + 2] = c.b8

	# --- sky decorations: stars or clouds ---
	if has_sky:
		var dark_sky: bool = sky[0].get_luminance() < 0.2
		if dark_sky:
			for k in 700:
				var x := rng.randi_range(0, W - 1)
				var y := rng.randi_range(0, H - 1)
				var i := y * W + x
				if mask[i] != 0 or float(y) > hills2[x]:
					continue
				var b := rng.randf_range(0.4, 1.0)
				var o := i * 4
				bg[o] = int(lerpf(bg[o], 255, b))
				bg[o + 1] = int(lerpf(bg[o + 1], 255, b))
				bg[o + 2] = int(lerpf(bg[o + 2], 240, b))
		else:
			for k in 14:
				var cx := rng.randf_range(0, W)
				var cy := rng.randf_range(30, H * 0.35)
				for blob in 5:
					var bx := cx + rng.randf_range(-50, 50)
					var by := cy + rng.randf_range(-8, 8)
					var rx := rng.randf_range(25, 55)
					var ry := rx * rng.randf_range(0.35, 0.5)
					for y in range(maxi(int(by - ry), 0), mini(int(by + ry), H - 1) + 1):
						for x in range(maxi(int(bx - rx), 0), mini(int(bx + rx), W - 1) + 1):
							var nx := (x - bx) / rx
							var ny := (y - by) / ry
							var d := nx * nx + ny * ny
							var i := y * W + x
							if d > 1.0 or mask[i] != 0 or float(y) > hills2[x]:
								continue
							var a := clampf((1.0 - d) * 2.0, 0.0, 0.85)
							var shade := 1.0 if ny < 0.2 else 0.9
							var o := i * 4
							bg[o] = int(lerpf(bg[o], 255 * shade, a))
							bg[o + 1] = int(lerpf(bg[o + 1], 255 * shade, a))
							bg[o + 2] = int(lerpf(bg[o + 2], 255 * shade, a))

	var fimg := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, fg)
	var bimg := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, bg)
	return {"fg": fimg, "bg": bimg, "mask": mask, "dirt": pal.duplicate(), "outline": pal[0].darkened(0.6)}


static func _shade(fg: PackedByteArray, o: int, amt: float) -> void:
	for c in 3:
		var v := float(fg[o + c])
		if amt > 0.0:
			v += (255.0 - v) * amt
		else:
			v *= 1.0 + amt
		fg[o + c] = clampi(int(v), 0, 255)


## Будь-яка картинка як мапа.
## Якщо в картинці є прозорість — прозоре стає порожнечею.
## Якщо картинка непрозора (фото) — у ній прориваються печери.
static func from_image(src: Image) -> Dictionary:
	var im: Image = src.duplicate()
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	var sw := im.get_width()
	var sh := im.get_height()
	var s := minf(1600.0 / sw, 1000.0 / sh)
	if sw * s < 800.0:
		s = 800.0 / sw
	var nw := clampi(int(sw * s), 64, 2000)
	var nh := clampi(int(sh * s), 64, 1400)
	im.resize(nw, nh, Image.INTERPOLATE_BILINEAR)
	var data := im.get_data()
	var n := nw * nh

	var transparent := 0
	var samples := 0
	for i in range(0, n, 7):
		samples += 1
		if data[i * 4 + 3] < 128:
			transparent += 1
	var has_alpha := transparent > samples * 0.03

	var mask := PackedByteArray()
	mask.resize(n)
	if has_alpha:
		for i in n:
			mask[i] = 1 if data[i * 4 + 3] >= 128 else 0
	else:
		var noise := FastNoiseLite.new()
		noise.seed = randi()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		noise.frequency = 0.004
		noise.fractal_octaves = 3
		var nd := noise.get_image(nw, nh).get_data()
		for i in n:
			mask[i] = 0 if nd[i] > 185 else 1
	var dirt: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for k in 200:
		if dirt.size() >= 6:
			break
		var i := rng.randi_range(0, n - 1)
		if mask[i] != 0:
			dirt.append(Color8(data[i * 4], data[i * 4 + 1], data[i * 4 + 2]))
	for i in n:
		data[i * 4 + 3] = 255 if mask[i] != 0 else 0
	var dark: Image = im.duplicate()
	dark.adjust_bcs(0.35, 1.0, 0.7)
	var bg := Image.create(nw, nh, false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.11, 0.13, 0.2))
	bg.blend_rect(dark, Rect2i(0, 0, nw, nh), Vector2i.ZERO)
	var fimg := Image.create_from_data(nw, nh, false, Image.FORMAT_RGBA8, data)
	return {"fg": fimg, "bg": bg, "mask": mask, "dirt": dirt}
