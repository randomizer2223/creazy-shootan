class_name LTerrain
extends Node2D
## Destructible per-pixel map.
## mask[y*w+x]: 1 = solid ground, 0 = empty, 2 = decoration (not solid).
## The color image is split into chunks; only changed chunks are re-uploaded to the GPU.
## A shader draws smooth cartoon edges with an outline and soft lighting.

const CH := 128
const P := 4  # padding around the image so the edge shader can look at neighbours

const SHADER := """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(0.23, 0.14, 0.13, 1.0);
uniform float outline_px = 1.7;
uniform float edge_px = 2.5;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	float a = c.a;
	vec3 col = c.rgb / max(a, 0.0001);
	float n = a;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		n = max(n, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px * outline_px).a);
	}
	float inner = smoothstep(0.4, 0.6, a);
	float outer = smoothstep(0.4, 0.6, n);
	float up = texture(TEXTURE, UV - vec2(0.0, px.y * edge_px)).a;
	float down = texture(TEXTURE, UV + vec2(0.0, px.y * edge_px)).a;
	col = mix(col, min(col * 1.18 + 0.12, vec3(1.0)), (1.0 - up) * 0.85);
	col = mix(col, col * 0.62, (1.0 - down) * 0.7);
	COLOR = vec4(mix(outline_color.rgb, col, inner), outer);
}
"""

var w := 0   # map size in world pixels (= physics mask size)
var h := 0
var ss := 1  # picture pixels per world pixel (2 = sharper "HD" picture)
var pp := P  # padding in picture pixels
var mask := PackedByteArray()
var img: Image  # picture, padded by pp on every side
var bg_tex: ImageTexture
var chunks_x := 0
var chunks_y := 0
var textures: Array[ImageTexture] = []
var dirty := PackedByteArray()
var any_dirty := false
var dirt_colors: Array = []
var rng := RandomNumberGenerator.new()
var _bg_node: Node2D


## fg may be larger than the mask (2x for sharp picture maps); bg can be any size.
func setup(fg: Image, solid: PackedByteArray, bg: Image, dcolors: Array, outline := Color(0.23, 0.14, 0.13)) -> void:
	if fg.get_format() != Image.FORMAT_RGBA8:
		fg.convert(Image.FORMAT_RGBA8)
	ss = maxi(1, int(round(sqrt(float(fg.get_width() * fg.get_height()) / solid.size()))))
	w = fg.get_width() / ss
	h = fg.get_height() / ss
	pp = P * ss
	img = Image.create(w * ss + 2 * pp, h * ss + 2 * pp, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.blit_rect(fg, Rect2i(0, 0, w * ss, h * ss), Vector2i(pp, pp))
	mask = solid
	if bg.get_format() != Image.FORMAT_RGBA8:
		bg.convert(Image.FORMAT_RGBA8)
	bg_tex = ImageTexture.create_from_image(bg)
	chunks_x = ceili(float(w) / CH)
	chunks_y = ceili(float(h) / CH)
	textures.clear()
	for cy in chunks_y:
		for cx in chunks_x:
			textures.append(ImageTexture.create_from_image(img.get_region(_padded_rect(cx, cy))))
	dirty.resize(chunks_x * chunks_y)
	dirty.fill(0)
	dirt_colors = dcolors if dcolors.size() > 0 else [Color(0.6, 0.4, 0.2)]

	# background is a separate node without the edge shader
	_bg_node = Node2D.new()
	_bg_node.show_behind_parent = true
	_bg_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_bg_node.draw.connect(func(): _bg_node.draw_texture_rect(bg_tex, Rect2(0, 0, w, h), false))
	add_child(_bg_node)

	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("outline_color", outline)
	mat.set_shader_parameter("outline_px", 1.7 * ss)
	mat.set_shader_parameter("edge_px", 2.5 * ss)
	if OS.get_environment("L2_NOSHADER") == "":
		material = mat
	queue_redraw()


func _chunk_size(cx: int, cy: int) -> Vector2i:
	return Vector2i(mini(CH, w - cx * CH), mini(CH, h - cy * CH))


## Chunk area inside the padded picture (picture pixels).
func _padded_rect(cx: int, cy: int) -> Rect2i:
	var s := _chunk_size(cx, cy)
	return Rect2i(cx * CH * ss, cy * CH * ss, s.x * ss + 2 * pp, s.y * ss + 2 * pp)


func is_solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return true  # map borders are solid
	return mask[y * w + x] == 1


func is_solid_v(p: Vector2) -> bool:
	return is_solid(floori(p.x), floori(p.y))


func _mark(x0: int, y0: int, x1: int, y1: int) -> void:
	# padding means a pixel can show up in a neighbouring chunk too
	var c0 := clampi((x0 - P) / CH, 0, chunks_x - 1)
	var c1 := clampi((x1 + P) / CH, 0, chunks_x - 1)
	var r0 := clampi((y0 - P) / CH, 0, chunks_y - 1)
	var r1 := clampi((y1 + P) / CH, 0, chunks_y - 1)
	for cy in range(r0, r1 + 1):
		for cx in range(c0, c1 + 1):
			dirty[cy * chunks_x + cx] = 1
	any_dirty = true


## Cuts a round hole. Returns the number of destroyed world pixels.
func carve(c: Vector2, r: float, scorch := true) -> int:
	if r <= 0.0:
		return 0
	var edge := 2.5 if scorch else 0.0
	var ri := int(ceil(r + edge))
	var cx := int(c.x)
	var cy := int(c.y)
	var x0 := maxi(cx - ri, 0)
	var x1 := mini(cx + ri, w - 1)
	var y0 := maxi(cy - ri, 0)
	var y1 := mini(cy + ri, h - 1)
	if x0 > x1 or y0 > y1:
		return 0
	var r2 := r * r
	var removed := 0
	# physics
	for y in range(y0, y1 + 1):
		var dy := float(y) - c.y
		var row := y * w
		for x in range(x0, x1 + 1):
			var idx := row + x
			if mask[idx] == 0:
				continue
			var dx := float(x) - c.x
			if dx * dx + dy * dy <= r2:
				mask[idx] = 0
				removed += 1
	if removed == 0 and not scorch:
		return 0
	# picture: each row of the hole is one fill_rect (fast), then a thin scorched rim
	var clear := Color(0, 0, 0, 0)
	var re := r + edge
	var inv := 1.0 / ss
	var px0 := x0 * ss
	var px1 := (x1 + 1) * ss - 1
	for yy in range(y0 * ss, (y1 + 1) * ss):
		var dy := (yy + 0.5) * inv - c.y
		if absf(dy) > re:
			continue
		var outer := sqrt(maxf(re * re - dy * dy, 0.0))
		var inner := sqrt(maxf(r2 - dy * dy, 0.0)) if absf(dy) <= r else -1.0
		var a0 := clampi(int(ceil((c.x - outer) * ss - 0.5)), px0, px1)
		var a1 := clampi(int(floor((c.x + outer) * ss - 0.5)), px0, px1)
		if inner >= 0.0:
			var b0 := clampi(int(ceil((c.x - inner) * ss - 0.5)), px0, px1 + 1)
			var b1 := clampi(int(floor((c.x + inner) * ss - 0.5)), px0 - 1, px1)
			if b1 >= b0:
				img.fill_rect(Rect2i(b0 + pp, yy + pp, b1 - b0 + 1, 1), clear)
			if scorch:
				for xx in range(a0, b0):
					_darken(xx + pp, yy + pp)
				for xx in range(b1 + 1, a1 + 1):
					_darken(xx + pp, yy + pp)
		elif scorch:
			for xx in range(a0, a1 + 1):
				_darken(xx + pp, yy + pp)
	_mark(x0, y0, x1, y1)
	return removed


func _darken(x: int, y: int) -> void:
	var old := img.get_pixel(x, y)
	if old.a > 0.0:
		img.set_pixel(x, y, old.darkened(0.1))


## Creates a circle of ground where it is empty now.
func add_dirt(c: Vector2, r: float) -> int:
	var ri := int(ceil(r))
	var cx := int(c.x)
	var cy := int(c.y)
	var x0 := maxi(cx - ri, 0)
	var x1 := mini(cx + ri, w - 1)
	var y0 := maxi(cy - ri, 0)
	var y1 := mini(cy + ri, h - 1)
	if x0 > x1 or y0 > y1:
		return 0
	var r2 := r * r
	var bw := x1 - x0 + 1
	var fresh := PackedByteArray()
	fresh.resize(bw * (y1 - y0 + 1))
	var added := 0
	for y in range(y0, y1 + 1):
		var dy := float(y) - c.y
		var row := y * w
		for x in range(x0, x1 + 1):
			var idx := row + x
			if mask[idx] == 1:
				continue
			var dx := float(x) - c.x
			if dx * dx + dy * dy <= r2:
				mask[idx] = 1
				fresh[(y - y0) * bw + (x - x0)] = 1
				added += 1
	if added == 0:
		return 0
	var base: Color = dirt_colors[rng.randi() % dirt_colors.size()]
	var inv := 1.0 / ss
	for yy in range(y0 * ss, (y1 + 1) * ss):
		var wy := yy / ss
		var dy := (yy + 0.5) * inv - c.y
		for xx in range(x0 * ss, (x1 + 1) * ss):
			if fresh[(wy - y0) * bw + (xx / ss - x0)] == 0:
				continue
			var dx := (xx + 0.5) * inv - c.x
			var t := sqrt(dx * dx + dy * dy) / r
			img.set_pixel(xx + pp, yy + pp, base.lightened((1.0 - t) * 0.15 - dy / r * 0.08))
	_mark(x0, y0, x1, y1)
	return added


## Paints blood (or anything) onto existing ground.
func stain(c: Vector2, r: float, col: Color) -> void:
	var ri := int(ceil(r))
	var cx := int(c.x)
	var cy := int(c.y)
	var x0 := maxi(cx - ri, 0)
	var x1 := mini(cx + ri, w - 1)
	var y0 := maxi(cy - ri, 0)
	var y1 := mini(cy + ri, h - 1)
	if x0 > x1 or y0 > y1:
		return
	var r2 := r * r
	var touched := false
	var inv := 1.0 / ss
	for yy in range(y0 * ss, (y1 + 1) * ss):
		var dy := (yy + 0.5) * inv - c.y
		var row := (yy / ss) * w
		for xx in range(x0 * ss, (x1 + 1) * ss):
			if mask[row + xx / ss] == 0:
				continue
			var dx := (xx + 0.5) * inv - c.x
			var d2 := dx * dx + dy * dy
			if d2 <= r2:
				var old := img.get_pixel(xx + pp, yy + pp)
				if old.a <= 0.0:
					continue
				img.set_pixel(xx + pp, yy + pp, Color(old.lerp(col, col.a * (1.0 - d2 / r2 * 0.5)), old.a))
				touched = true
	if touched:
		_mark(x0, y0, x1, y1)


## First solid point on segment a->b, or Vector2.INF if the path is clear.
func raycast(a: Vector2, b: Vector2, step := 1.0) -> Vector2:
	var d := b - a
	var steps := int(ceil(maxf(absf(d.x), absf(d.y)) / step))
	if steps <= 0:
		return Vector2.INF if not is_solid_v(a) else a
	var s := d / steps
	var p := a
	for i in steps + 1:
		if is_solid_v(p):
			return p
		p += s
	return Vector2.INF


func area_free(p: Vector2, r: int) -> bool:
	for y in range(-r, r + 1, 2):
		for x in range(-r, r + 1, 2):
			if is_solid(int(p.x) + x, int(p.y) + y):
				return false
	return true


## Finds a free spot, preferably standing on ground. Carves a hole if nothing is found.
func find_spawn(r: RandomNumberGenerator) -> Vector2:
	for attempt in 400:
		var p := Vector2(r.randi_range(24, w - 24), r.randi_range(24, h - 24))
		if not area_free(p, 8):
			continue
		var y := p.y
		while y < h - 10 and not is_solid(int(p.x), int(y) + 9):
			y += 1.0
		var q := Vector2(p.x, y)
		if area_free(q, 7) and y < h - 12:
			return q
	var p2 := Vector2(r.randi_range(40, w - 40), r.randi_range(40, h - 40))
	carve(p2, 16)
	return p2


## Uploads changed chunks to the GPU, but at most a few per frame so heavy
## destruction (napalm, minigun) never stalls the frame.
const MAX_UPLOADS := 6
var _scan := 0


func _process(_delta: float) -> void:
	if not any_dirty:
		return
	var n := chunks_x * chunks_y
	var done := 0
	var left := false
	for k in n:
		var i := (_scan + k) % n
		if dirty[i] == 0:
			continue
		if done >= MAX_UPLOADS:
			left = true
			break
		dirty[i] = 0
		textures[i].update(img.get_region(_padded_rect(i % chunks_x, i / chunks_x)))
		done += 1
		_scan = (i + 1) % n
	any_dirty = left


func _draw() -> void:
	for cy in chunks_y:
		for cx in chunks_x:
			var s := _chunk_size(cx, cy)
			draw_texture_rect_region(textures[cy * chunks_x + cx], Rect2(cx * CH, cy * CH, s.x, s.y),
				Rect2(pp, pp, s.x * ss, s.y * ss))
