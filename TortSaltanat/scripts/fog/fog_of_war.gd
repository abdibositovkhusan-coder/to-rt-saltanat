class_name FogOfWar
extends Node3D
## Tuman urushi: har ikki jamoa uchun "hozir ko'rinadi" va "ilgari ko'rilgan" kataklar (120×120, 1 m).
## Har bir birlik/bino o'z ko'rish radiusida tumanni ochadi. O'yinchi uchun yer ustida qorong'i qatlam
## chiziladi: ko'rilmagan — qora, ilgari ko'rilgan — xira, hozir ko'rinadi — ochiq.
## Dushman AI ham faqat o'zi ko'rgan narsani biladi (aldamaydi).
## Bog'liqlik: Simulation (birliklar ro'yxati).

const SIZE := 120
const HALF := 60.0
const N := SIZE * SIZE

var sim = null
var texture: ImageTexture
var _vis := PackedByteArray()
var _exp := PackedByteArray()
var _img_data := PackedByteArray()
var _image: Image
var _circles: Dictionary = {}
var _reveals: Array = []


func setup(s) -> void:
	sim = s
	_vis.resize(N * 2)
	_vis.fill(0)
	_exp.resize(N * 2)
	_exp.fill(0)
	_img_data.resize(N * 4)
	_img_data.fill(0)
	for i in N:
		_img_data[i * 4 + 3] = 255
	_image = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, _img_data)
	texture = ImageTexture.create_from_image(_image)
	_build_plane()


func _build_plane() -> void:
	var y := 0.09
	var verts := PackedVector3Array([Vector3(-HALF, y, -HALF), Vector3(HALF, y, -HALF), Vector3(HALF, y, HALF), Vector3(-HALF, y, HALF)])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var idx := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.02, 0.02, 0.05, 1.0)
	m.albedo_texture = texture
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mi.material_override = m
	add_child(mi)


func _circle(r: int) -> PackedInt32Array:
	if _circles.has(r):
		return _circles[r]
	var out := PackedInt32Array()
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if dx * dx + dz * dz <= r * r:
				out.append(dx)
				out.append(dz)
	_circles[r] = out
	return out


func _index(pos: Vector3) -> int:
	var cx := clampi(int(floor(pos.x + HALF)), 0, SIZE - 1)
	var cz := clampi(int(floor(pos.z + HALF)), 0, SIZE - 1)
	return cz * SIZE + cx


func sees(team: int, pos: Vector3) -> bool:
	if team < 0 or team > 1:
		return true   # neytral jonzotlar tumandan cheklanmaydi
	return _vis[team * N + _index(pos)] == 1


func is_explored(team: int, pos: Vector3) -> bool:
	if team < 0 or team > 1:
		return true
	return _exp[team * N + _index(pos)] == 1


func reveal_all(team: int) -> void:
	for i in N:
		_exp[team * N + i] = 1


## Vaqtinchalik ochish (masalan, «Dalil» qobiliyati).
func add_reveal(team: int, pos: Vector3, r: float, duration: float) -> void:
	_reveals.append({"team": team, "pos": pos, "r": r, "t": duration})


func refresh(dt: float = 0.2) -> void:
	if sim == null:
		return
	_vis.fill(0)
	var night_mult: float = 0.75 if (sim.is_night) else 1.0
	for u in sim.units:
		if not u.alive:
			continue
		var sgt: float = u.sight
		if not u.has_tag("elf"):
			sgt *= night_mult
		_stamp(u.team, u.sim_pos, int(round(sgt)))
	var keep: Array = []
	for rv in _reveals:
		_stamp(int(rv["team"]), rv["pos"], int(round(float(rv["r"]))))
		rv["t"] = float(rv["t"]) - dt
		if float(rv["t"]) > 0.0:
			keep.append(rv)
	_reveals = keep
	# O'yinchi (0-jamoa) uchun tasvirni yangilash
	for i in N:
		var a := 0
		if _vis[i] == 0:
			a = 140 if _exp[i] == 1 else 255
		_img_data[i * 4 + 3] = a
	_image.set_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, _img_data)
	texture.update(_image)


func _stamp(team: int, pos: Vector3, r: int) -> void:
	if team < 0 or team > 1:
		return
	var off := _circle(max(1, r))
	var cx := clampi(int(floor(pos.x + HALF)), 0, SIZE - 1)
	var cz := clampi(int(floor(pos.z + HALF)), 0, SIZE - 1)
	var base := team * N
	var k := 0
	var n := off.size()
	while k < n:
		var x := cx + off[k]
		var z := cz + off[k + 1]
		k += 2
		if x < 0 or z < 0 or x >= SIZE or z >= SIZE:
			continue
		var idx := base + z * SIZE + x
		_vis[idx] = 1
		_exp[idx] = 1


## Saqlash uchun: ko'rilgan hududlar xaritasi (base64).
func explored_b64() -> String:
	return Marshalls.raw_to_base64(_exp)


func set_explored_b64(b64: String) -> void:
	if b64 == "":
		return
	var raw: PackedByteArray = Marshalls.base64_to_raw(b64)
	if raw.size() == _exp.size():
		_exp = raw
