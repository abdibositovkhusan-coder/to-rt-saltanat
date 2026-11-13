class_name PathGrid
extends RefCounted
## Yo'l topish to'ri: xarita 120×120 katakka bo'lingan (1 katak = 1 metr). Binolar, oltin konlari va
## daraxtlar to'siq sifatida belgilanadi (hisoblagich bilan — ustma-ust to'siqlar to'g'ri olib tashlanadi).
## Yo'l Godot'ning tezkor AStarGrid2D'si bilan topiladi, keyin "ip tortish" usulida silliqlanadi.
## Bog'liqlik: yo'q (Simulation saqlaydi, Unit._move_to ishlatadi).

const SIZE := 120
const HALF := 60.0
const UNIT_PAD := 0.45

var astar := AStarGrid2D.new()
var _count := PackedInt32Array()


func _init() -> void:
	astar.region = Rect2i(0, 0, SIZE, SIZE)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	_count.resize(SIZE * SIZE)
	_count.fill(0)


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x + HALF)), 0, SIZE - 1), clampi(int(floor(p.z + HALF)), 0, SIZE - 1))


func center_of(c: Vector2i) -> Vector3:
	return Vector3(c.x - HALF + 0.5, 0.0, c.y - HALF + 0.5)


func _in(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE and c.y < SIZE


## To'siq qo'shish (delta = +1) yoki olib tashlash (delta = -1). r — obyekt radiusi.
func mark_circle(center: Vector3, r: float, delta: int) -> void:
	var rr: float = r + UNIT_PAD
	var c0 := cell_of(center)
	var span := int(ceil(rr)) + 1
	var flat := Vector3(center.x, 0, center.z)
	for dx in range(-span, span + 1):
		for dz in range(-span, span + 1):
			var c := c0 + Vector2i(dx, dz)
			if not _in(c):
				continue
			if center_of(c).distance_to(flat) > rr:
				continue
			var idx := c.y * SIZE + c.x
			var before := _count[idx]
			_count[idx] = max(0, before + delta)
			var now_solid := _count[idx] > 0
			if now_solid != (before > 0):
				astar.set_point_solid(c, now_solid)


func is_solid_cell(c: Vector2i) -> bool:
	if not _in(c):
		return true
	return _count[c.y * SIZE + c.x] > 0


func is_solid(p: Vector3) -> bool:
	return is_solid_cell(cell_of(p))


## a dan b gacha to'g'ri chiziq to'siqsizmi? Boshidagi 0.6 m va oxiridagi ignore_end metr hisobga olinmaydi.
func line_clear(a: Vector3, b: Vector3, ignore_end: float) -> bool:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := d.length()
	if length < 0.01:
		return true
	var dir := d / length
	var t := 0.6
	var limit: float = length - ignore_end
	while t < limit:
		if is_solid(a + dir * t):
			return false
		t += 0.5
	return true


func nearest_free(c: Vector2i, toward: Vector3, max_r: int = 10) -> Vector2i:
	if _in(c) and not is_solid_cell(c):
		return c
	for r in range(1, max_r + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if abs(dx) != r and abs(dz) != r:
					continue
				var n := c + Vector2i(dx, dz)
				if not _in(n) or is_solid_cell(n):
					continue
				var dd: float = center_of(n).distance_to(toward)
				if dd < best_d:
					best_d = dd
					best = n
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


## Yo'l nuqtalari (silliqlangan). Bo'sh massiv — yo'l topilmadi.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var s := nearest_free(cell_of(from), from)
	var g := nearest_free(cell_of(to), from)
	if s.x < 0 or g.x < 0:
		return out
	if s == g:
		out.append(center_of(g))
		return out
	var ids = astar.get_id_path(s, g)
	if ids.is_empty():
		return out
	var raw: Array = []
	for c in ids:
		raw.append(center_of(c))
	# Agar maqsad bo'sh katakda bo'lsa — aniq nuqtaga boramiz
	if not is_solid(to):
		raw[raw.size() - 1] = Vector3(to.x, 0, to.z)
	# Ip tortish: ko'rinib turgan eng uzoq nuqtaga to'g'ri boramiz
	var i := 0
	var cur: Vector3 = from
	while i < raw.size():
		var j: int = raw.size() - 1
		while j > i and not line_clear(cur, raw[j], 0.0):
			j -= 1
		out.append(raw[j])
		cur = raw[j]
		i = j + 1
	return out
