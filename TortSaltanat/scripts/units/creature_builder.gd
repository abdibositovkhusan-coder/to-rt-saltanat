class_name CreatureBuilder
extends RefCounted
## Bepul to'plamlarda yo'q jonzotlarni oddiy shakllardan (low-poly) yasaydi:
## ot, mamont, bug'u, ayiq, ilon, tovuq oyoqlari, qush (Humo, Simurg'), ajdar (1–3 boshli), bo'ron.
## Natija: {"root": Node3D, "legs": [pivot...], "wings": [pivot...], "segments": [...], "saddle": balandlik}
## Bog'liqlik: UnitVisual (shakl va materiallar).

static func build(parent: Node3D, kind: String, look: Dictionary) -> Dictionary:
	var root := Node3D.new()
	parent.add_child(root)
	var size: float = float(look.get("size", 1.0))
	root.scale = Vector3.ONE * size
	var col := GameData.color(look.get("color", ""), Color(0.5, 0.4, 0.3))
	var acc := GameData.color(look.get("accent", ""), col.lightened(0.3))
	var eye_c := GameData.color(look.get("eyes", ""), Color(1.0, 0.85, 0.3))
	var out := {"root": root, "legs": [], "wings": [], "segments": [], "saddle": 1.5}
	match kind:
		"horse", "deer":
			_quadruped(root, out, col, acc, eye_c, 0.75, 1.75, 0.95, 0.17, kind == "deer")
		"mammoth":
			_mammoth(root, out, col, acc, eye_c)
		"bear":
			_bear(root, out, col, acc, eye_c)
		"serpent":
			_serpent(root, out, col, acc, eye_c, bool(look.get("wings", false)))
		"chicken":
			_chicken_legs(root, out, col)
		"bird":
			_bird(root, out, col, acc, eye_c)
		"dragon":
			_dragon(root, out, col, acc, eye_c, int(look.get("heads", 1)))
		"storm":
			_storm(root, out, col, acc)
	out["saddle"] = float(out["saddle"]) * size
	return out


static func _m(c: Color, e: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	return UnitVisual.mat(c, e, unshaded)


static func _leg(root: Node3D, out: Dictionary, pos: Vector3, length: float, thick: float, c: Color) -> void:
	var p := UnitVisual.pivot(root, pos)
	UnitVisual.part(p, UnitVisual.box(Vector3(thick, length, thick)), _m(c), Vector3(0, -length * 0.5, 0))
	UnitVisual.part(p, UnitVisual.box(Vector3(thick * 1.2, 0.1, thick * 1.4)), _m(c.darkened(0.5)), Vector3(0, -length + 0.05, 0.02))
	out["legs"].append(p)


static func _eyes(parent: Node3D, pos: Vector3, spread: float, c: Color, r: float = 0.05) -> void:
	for sx in [-1.0, 1.0]:
		UnitVisual.part(parent, UnitVisual.sphere(r, 6), _m(c, 2.5, true), pos + Vector3(spread * sx, 0, 0))


static func _quadruped(root: Node3D, out: Dictionary, col: Color, acc: Color, eye_c: Color, w: float, l: float, h: float, leg_t: float, antlers: bool) -> void:
	var body_y := h + 0.35
	UnitVisual.part(root, UnitVisual.box(Vector3(w, 0.7, l)), _m(col), Vector3(0, body_y, 0))
	var neck := UnitVisual.pivot(root, Vector3(0, body_y + 0.2, l * 0.45))
	neck.rotation.x = -0.7
	UnitVisual.part(neck, UnitVisual.box(Vector3(w * 0.45, 0.85, 0.35)), _m(col), Vector3(0, 0.4, 0))
	var head := UnitVisual.pivot(neck, Vector3(0, 0.85, 0.05))
	head.rotation.x = 1.1
	UnitVisual.part(head, UnitVisual.box(Vector3(w * 0.42, 0.32, 0.6)), _m(col), Vector3(0, 0, 0.18))
	_eyes(head, Vector3(0, 0.08, 0.15), w * 0.22, eye_c, 0.04)
	if antlers:
		for sx in [-1.0, 1.0]:
			var a := UnitVisual.part(head, UnitVisual.box(Vector3(0.05, 0.6, 0.05)), _m(acc.lightened(0.2), 0.6), Vector3(0.12 * sx, 0.35, -0.05), Vector3(0.2, 0, 0.4 * sx))
			UnitVisual.part(a, UnitVisual.box(Vector3(0.04, 0.3, 0.04)), _m(acc.lightened(0.2), 0.6), Vector3(0, 0.2, 0.1), Vector3(0.6, 0, 0))
	else:
		UnitVisual.part(neck, UnitVisual.box(Vector3(0.08, 0.7, 0.12)), _m(acc.darkened(0.4)), Vector3(0, 0.45, -0.18))
	UnitVisual.part(root, UnitVisual.box(Vector3(0.1, 0.6, 0.1)), _m(acc.darkened(0.3)), Vector3(0, body_y - 0.1, -l * 0.55), Vector3(-0.5, 0, 0))
	# Egar
	UnitVisual.part(root, UnitVisual.box(Vector3(w + 0.06, 0.12, 0.6)), _m(Color(0.45, 0.2, 0.15)), Vector3(0, body_y + 0.38, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_leg(root, out, Vector3(w * 0.32 * sx, h, l * 0.36 * sz), h, leg_t, col.darkened(0.15))
	out["saddle"] = body_y + 0.4


static func _mammoth(root: Node3D, out: Dictionary, col: Color, acc: Color, eye_c: Color) -> void:
	var b := UnitVisual.part(root, UnitVisual.sphere(1.0, 10), _m(col), Vector3(0, 1.8, 0))
	b.scale = Vector3(0.95, 0.85, 1.25)
	var head := UnitVisual.pivot(root, Vector3(0, 2.0, 1.15))
	UnitVisual.part(head, UnitVisual.sphere(0.6, 8), _m(col), Vector3.ZERO)
	_eyes(head, Vector3(0, 0.15, 0.48), 0.25, eye_c)
	var trunk := UnitVisual.part(head, UnitVisual.cone(0.2, 1.3, 0.1, 6), _m(col.darkened(0.1)), Vector3(0, -0.6, 0.55), Vector3(0.3, 0, 0))
	trunk.name = "trunk"
	for sx in [-1.0, 1.0]:
		UnitVisual.part(head, UnitVisual.cone(0.09, 1.1, 0.02, 6), _m(Color(0.95, 0.92, 0.82)), Vector3(0.3 * sx, -0.4, 0.55), Vector3(1.1, 0, -0.25 * sx))
		UnitVisual.part(head, UnitVisual.box(Vector3(0.1, 0.55, 0.45)), _m(col.darkened(0.2)), Vector3(0.55 * sx, 0.05, 0))
	UnitVisual.part(root, UnitVisual.box(Vector3(1.3, 0.15, 1.0)), _m(Color(0.5, 0.25, 0.15)), Vector3(0, 2.62, -0.1))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_leg(root, out, Vector3(0.5 * sx, 1.15, 0.6 * sz), 1.15, 0.38, col.darkened(0.1))
	out["saddle"] = 2.7


static func _bear(root: Node3D, out: Dictionary, col: Color, acc: Color, eye_c: Color) -> void:
	var b := UnitVisual.part(root, UnitVisual.sphere(0.7, 10), _m(col), Vector3(0, 1.0, 0))
	b.scale = Vector3(0.9, 0.85, 1.35)
	var head := UnitVisual.pivot(root, Vector3(0, 1.2, 0.95))
	UnitVisual.part(head, UnitVisual.sphere(0.38, 8), _m(col), Vector3.ZERO)
	UnitVisual.part(head, UnitVisual.box(Vector3(0.28, 0.22, 0.3)), _m(col.lightened(0.15)), Vector3(0, -0.08, 0.32))
	_eyes(head, Vector3(0, 0.1, 0.3), 0.14, eye_c)
	for sx in [-1.0, 1.0]:
		UnitVisual.part(head, UnitVisual.sphere(0.11, 6), _m(col), Vector3(0.24 * sx, 0.3, 0))
		UnitVisual.part(head, UnitVisual.cone(0.04, 0.16), _m(acc, 0.5), Vector3(0.08 * sx, -0.22, 0.42), Vector3(PI, 0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_leg(root, out, Vector3(0.38 * sx, 0.65, 0.5 * sz), 0.65, 0.26, col.darkened(0.15))
	out["saddle"] = 1.7


static func _serpent(root: Node3D, out: Dictionary, col: Color, acc: Color, eye_c: Color, wings: bool) -> void:
	var n := 7
	for i in n:
		var r: float = lerp(0.42, 0.16, float(i) / n)
		var seg := UnitVisual.part(root, UnitVisual.sphere(r, 8), _m(col if i % 2 == 0 else col.darkened(0.15)), Vector3(0, 0.45, 0.3 - i * 0.42))
		out["segments"].append(seg)
	var head := UnitVisual.pivot(root, Vector3(0, 0.75, 0.85))
	UnitVisual.part(head, UnitVisual.box(Vector3(0.42, 0.28, 0.6)), _m(col), Vector3.ZERO)
	_eyes(head, Vector3(0, 0.12, 0.18), 0.14, eye_c)
	UnitVisual.part(head, UnitVisual.box(Vector3(0.05, 0.05, 0.25)), _m(Color(0.9, 0.2, 0.2)), Vector3(0, -0.1, 0.42))
	for i in 4:
		UnitVisual.part(root, UnitVisual.cone(0.08, 0.3), _m(acc, 0.5), Vector3(0, 0.85 - i * 0.05, 0.3 - i * 0.42))
	if wings:
		for sx in [-1.0, 1.0]:
			var wp := UnitVisual.pivot(root, Vector3(0.3 * sx, 0.7, 0.1))
			UnitVisual.part(wp, UnitVisual.box(Vector3(1.4, 0.04, 0.8)), _m(acc, 1.2), Vector3(0.7 * sx, 0, 0))
			out["wings"].append(wp)
	out["saddle"] = 0.95


static func _chicken_legs(root: Node3D, out: Dictionary, col: Color) -> void:
	for sx in [-1.0, 1.0]:
		var p := UnitVisual.pivot(root, Vector3(0.45 * sx, 1.9, 0))
		UnitVisual.part(p, UnitVisual.cone(0.12, 1.0, 0.09, 6), _m(col), Vector3(0, -0.5, 0.15), Vector3(0.3, 0, 0))
		var knee := UnitVisual.pivot(p, Vector3(0, -1.0, 0.3))
		UnitVisual.part(knee, UnitVisual.cone(0.08, 0.9, 0.06, 6), _m(col), Vector3(0, -0.45, -0.12), Vector3(-0.3, 0, 0))
		for k in 3:
			UnitVisual.part(knee, UnitVisual.box(Vector3(0.06, 0.05, 0.4)), _m(col.darkened(0.2)), Vector3((k - 1) * 0.12, -0.88, 0.05), Vector3(0, (k - 1) * 0.5, 0))
		out["legs"].append(p)
	out["saddle"] = 1.9


static func _bird(root: Node3D, out: Dictionary, col: Color, acc: Color, eye_c: Color) -> void:
	var b := UnitVisual.part(root, UnitVisual.sphere(0.45, 10), _m(col, 0.4), Vector3(0, 0, 0))
	b.scale = Vector3(0.9, 0.8, 1.5)
	var head := UnitVisual.pivot(root, Vector3(0, 0.3, 0.7))
	UnitVisual.part(head, UnitVisual.sphere(0.24, 8), _m(col, 0.4), Vector3.ZERO)
	UnitVisual.part(head, UnitVisual.cone(0.08, 0.3), _m(Color(1.0, 0.75, 0.2)), Vector3(0, -0.02, 0.28), Vector3(PI * 0.5, 0, 0))
	_eyes(head, Vector3(0, 0.07, 0.18), 0.1, eye_c, 0.04)
	UnitVisual.part(head, UnitVisual.cone(0.06, 0.35), _m(acc, 1.0), Vector3(0, 0.3, -0.05), Vector3(-0.4, 0, 0))
	for sx in [-1.0, 1.0]:
		var wp := UnitVisual.pivot(root, Vector3(0.3 * sx, 0.1, 0.05))
		var w1 := UnitVisual.part(wp, UnitVisual.box(Vector3(1.3, 0.05, 0.6)), _m(col, 0.5), Vector3(0.65 * sx, 0, 0))
		UnitVisual.part(w1, UnitVisual.box(Vector3(0.9, 0.04, 0.4)), _m(acc, 1.0), Vector3(0.75 * sx, 0, -0.05))
		out["wings"].append(wp)
	for k in 3:
		UnitVisual.part(root, UnitVisual.box(Vector3(0.12, 0.04, 0.8)), _m(acc, 1.0), Vector3((k - 1) * 0.15, 0.05, -0.85), Vector3(0.2, (k - 1) * 0.3, 0))
	out["saddle"] = 0.5


static func _dragon(root: Node3D, out: Dictionary, col: Color, acc: Color, eye_c: Color, heads: int) -> void:
	var b := UnitVisual.part(root, UnitVisual.sphere(0.6, 10), _m(col), Vector3(0, 0, 0))
	b.scale = Vector3(0.9, 0.8, 1.6)
	var hn: int = clampi(heads, 1, 3)
	for h in hn:
		var off: float = (h - (hn - 1) * 0.5) * 0.45
		var neck := UnitVisual.pivot(root, Vector3(off, 0.2, 0.8))
		neck.rotation = Vector3(-0.6, off * 0.6, 0)
		UnitVisual.part(neck, UnitVisual.cone(0.16, 1.0, 0.11, 6), _m(col), Vector3(0, 0.5, 0))
		var head := UnitVisual.pivot(neck, Vector3(0, 1.0, 0))
		head.rotation.x = 0.9
		var hc: Color = [acc, Color(0.6, 0.85, 1.0), Color(0.6, 1.0, 0.4)][h % 3]
		UnitVisual.part(head, UnitVisual.box(Vector3(0.28, 0.24, 0.5)), _m(col), Vector3(0, 0, 0.15))
		UnitVisual.part(head, UnitVisual.box(Vector3(0.22, 0.06, 0.35)), _m(hc, 1.5), Vector3(0, -0.13, 0.25))
		_eyes(head, Vector3(0, 0.08, 0.3), 0.09, eye_c, 0.035)
		for sx in [-1.0, 1.0]:
			UnitVisual.part(head, UnitVisual.cone(0.04, 0.25), _m(acc.darkened(0.3)), Vector3(0.1 * sx, 0.18, -0.05), Vector3(-0.5, 0, 0))
	for sx in [-1.0, 1.0]:
		var wp := UnitVisual.pivot(root, Vector3(0.4 * sx, 0.3, 0.1))
		UnitVisual.part(wp, UnitVisual.box(Vector3(2.0, 0.05, 1.1)), _m(col.lightened(0.15)), Vector3(1.0 * sx, 0, 0))
		UnitVisual.part(wp, UnitVisual.box(Vector3(2.0, 0.08, 0.08)), _m(acc, 0.8), Vector3(1.0 * sx, 0.04, 0.5))
		out["wings"].append(wp)
	for i in 5:
		UnitVisual.part(root, UnitVisual.sphere(0.22 - i * 0.03, 6), _m(col), Vector3(0, -0.05 - i * 0.04, -0.9 - i * 0.32))
	UnitVisual.part(root, UnitVisual.cone(0.15, 0.4), _m(acc, 0.8), Vector3(0, -0.25, -2.55), Vector3(-PI * 0.5, 0, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_leg(root, out, Vector3(0.35 * sx, -0.25, 0.4 * sz), 0.45, 0.14, col.darkened(0.2))
	out["saddle"] = 0.6


static func _storm(root: Node3D, out: Dictionary, col: Color, acc: Color) -> void:
	var p := CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, 0.5, 0)
	p.angular_velocity_min = 180.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.mesh = UnitVisual.sphere(0.25, 6)
	p.material_override = UnitVisual.mat(Color(col.r, col.g, col.b, 0.55), 0.6, true, true)
	root.add_child(p)
	for i in 3:
		var c := UnitVisual.part(root, UnitVisual.cone(0.9 - i * 0.25, 3.2 - i * 0.6, 0.15, 10), UnitVisual.mat(Color(acc.r, acc.g, acc.b, 0.25), 1.5, true, true), Vector3(0, 1.6 - i * 0.3, 0), Vector3(PI, 0, 0))
		out["segments"].append(c)
	_eyes(root, Vector3(0, 2.4, 0.4), 0.18, Color(0.8, 0.5, 1.0), 0.09)
	out["saddle"] = 3.0
