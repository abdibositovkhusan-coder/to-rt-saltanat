class_name BuildingVisual
extends UnitVisual
## Binolarning 3D ko'rinishi (oddiy shakllardan): Odamlar — gumbazli markaz, uy, navkarxona, kamon maydoni;
## Trollar — tosh g'or, totem ustuni, arena. Qurilish jarayonida bino pastdan o'sib chiqadi, atrofida yog'och ustunlar.
## Bog'liqlik: UnitVisual (materiallar, shakllar, tanlash halqasi).

var _scaffold: Node3D
var _radius: float = 2.0


func build_building(style: String, tc: Color, team: int, r: float, model: String = "", model_scale: float = 1.0, model_yaw: float = 0.0, model_tint: String = "") -> void:
	scale_factor = 1.0
	team_color = tc
	_radius = r
	body = Node3D.new()
	add_child(body)
	if model != "":
		var m := ModelLib.instance(model)
		if m != null:
			m.scale = Vector3.ONE * model_scale
			m.rotation.y = deg_to_rad(model_yaw)
			body.add_child(m)
			if model_tint != "":
				ModelLib.tint(m, GameData.color(model_tint, Color.WHITE))
			_scaffold = ModelLib.instance("kaykit/medieval/building_scaffolding.gltf")
			if _scaffold != null:
				_scaffold.scale = Vector3.ONE * max(0.6, r * 1.05)
				add_child(_scaffold)
				_scaffold.visible = false
			else:
				_scaffold = Node3D.new()
				add_child(_scaffold)
			_add_flag(tc, r)
			_make_ring(team, r)
			return
	var stone := mat(Color(0.86, 0.78, 0.62))
	var stone_dark := mat(Color(0.7, 0.62, 0.48))
	var wood := mat(Color(0.45, 0.3, 0.16))
	var blue := mat(Color(0.18, 0.45, 0.78), 0.15)
	var gold := mat(Color(0.85, 0.68, 0.22), 0.3)
	var rock := mat(Color(0.42, 0.4, 0.38))
	var rock2 := mat(Color(0.33, 0.31, 0.3))
	var bone := mat(Color(0.92, 0.88, 0.76))
	var fire := mat(Color(1.0, 0.5, 0.15), 3.0, true)
	var team_m := mat(tc)
	match style:
		"hall":
			part(body, box(Vector3(4.4, 1.8, 4.4)), stone, Vector3(0, 0.9, 0))
			part(body, box(Vector3(3.2, 1.2, 3.2)), stone_dark, Vector3(0, 2.4, 0))
			var dome := part(body, sphere(1.5, 14), blue, Vector3(0, 3.0, 0))
			dome.scale = Vector3(1, 1.15, 1)
			part(body, cone(0.12, 0.8), gold, Vector3(0, 4.9, 0))
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					part(body, cone(0.32, 3.6, 0.26, 8), stone, Vector3(2.1 * sx, 1.8, 2.1 * sz))
					part(body, sphere(0.36, 8), blue, Vector3(2.1 * sx, 3.75, 2.1 * sz))
			part(body, box(Vector3(1.2, 1.4, 0.15)), mat(Color(0.25, 0.15, 0.08)), Vector3(0, 0.7, 2.22))
			part(body, box(Vector3(1.6, 0.25, 0.2)), team_m, Vector3(0, 1.55, 2.25))
		"house":
			part(body, box(Vector3(2.2, 1.3, 2.0)), stone, Vector3(0, 0.65, 0))
			var roof := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(2.5, 0.9, 2.2)
			roof.mesh = pm
			roof.material_override = mat(Color(0.55, 0.32, 0.2))
			roof.position = Vector3(0, 1.75, 0)
			body.add_child(roof)
			part(body, box(Vector3(0.6, 0.9, 0.1)), mat(Color(0.25, 0.15, 0.08)), Vector3(0, 0.45, 1.02))
			part(body, box(Vector3(0.4, 0.4, 0.1)), team_m, Vector3(0.7, 0.85, 1.02))
		"barracks":
			part(body, box(Vector3(3.6, 1.8, 3.4)), stone_dark, Vector3(0, 0.9, 0))
			for i in 5:
				part(body, box(Vector3(0.45, 0.45, 0.45)), stone_dark, Vector3(-1.6 + i * 0.8, 2.0, 1.5))
				part(body, box(Vector3(0.45, 0.45, 0.45)), stone_dark, Vector3(-1.6 + i * 0.8, 2.0, -1.5))
			part(body, box(Vector3(0.08, 2.4, 0.08)), wood, Vector3(1.4, 3.0, 1.2))
			part(body, box(Vector3(0.9, 0.55, 0.04)), team_m, Vector3(1.85, 3.9, 1.2))
			part(body, cone(0.55, 0.08, 0.55, 14), team_m, Vector3(0, 1.0, 1.72), Vector3(PI * 0.5, 0, 0))
			part(body, box(Vector3(1.1, 1.3, 0.1)), mat(Color(0.25, 0.15, 0.08)), Vector3(-0.9, 0.65, 1.72))
		"range":
			for i in 6:
				var a := TAU * i / 6.0
				part(body, box(Vector3(0.18, 1.0, 1.7)), wood, Vector3(cos(a) * 1.8, 0.5, sin(a) * 1.8), Vector3(0, -a, 0))
			part(body, box(Vector3(1.6, 1.3, 1.4)), stone, Vector3(-0.6, 0.65, -0.5))
			var rf := MeshInstance3D.new()
			var pm2 := PrismMesh.new()
			pm2.size = Vector3(1.9, 0.7, 1.6)
			rf.mesh = pm2
			rf.material_override = mat(Color(0.35, 0.5, 0.75))
			rf.position = Vector3(-0.6, 1.65, -0.5)
			body.add_child(rf)
			part(body, cone(0.6, 0.1, 0.6, 16), mat(Color(0.9, 0.9, 0.85)), Vector3(0.9, 1.1, 0.6), Vector3(PI * 0.5, 0, 0))
			part(body, cone(0.35, 0.11, 0.35, 16), mat(Color(0.85, 0.2, 0.15)), Vector3(0.9, 1.1, 0.62), Vector3(PI * 0.5, 0, 0))
			part(body, box(Vector3(0.1, 1.2, 0.1)), wood, Vector3(0.9, 0.5, 0.5))
		"cave":
			var r1 := part(body, sphere(2.6, 10), rock, Vector3(0, 0.8, 0))
			r1.scale = Vector3(1.1, 0.85, 1.0)
			part(body, sphere(1.4, 8), rock2, Vector3(1.6, 1.8, -0.8))
			part(body, sphere(1.1, 8), rock2, Vector3(-1.7, 1.5, -0.4))
			part(body, box(Vector3(1.4, 1.6, 0.4)), mat(Color(0.04, 0.03, 0.03)), Vector3(0, 0.8, 2.35))
			for sx in [-1.0, 1.0]:
				part(body, box(Vector3(0.12, 2.0, 0.12)), wood, Vector3(1.2 * sx, 1.0, 2.6))
				part(body, sphere(0.22, 6), bone, Vector3(1.2 * sx, 2.15, 2.6))
				part(body, sphere(0.12, 6), fire, Vector3(1.2 * sx, 1.7, 2.75))
			part(body, cone(0.12, 0.6), bone, Vector3(-0.5, 1.9, 2.4), Vector3(0.5, 0, 0.3))
			part(body, cone(0.12, 0.6), bone, Vector3(0.5, 1.9, 2.4), Vector3(0.5, 0, -0.3))
			part(body, box(Vector3(0.8, 0.5, 0.06)), team_m, Vector3(0, 1.85, 2.55))
		"totem":
			part(body, cone(0.55, 3.8, 0.42, 8), mat(Color(0.48, 0.33, 0.2)), Vector3(0, 1.9, 0))
			for i in 3:
				part(body, cone(0.6, 0.25, 0.6, 8), team_m if i % 2 == 0 else mat(Color(0.85, 0.3, 0.15)), Vector3(0, 0.9 + i * 1.0, 0))
			part(body, sphere(0.5, 8), mat(Color(0.48, 0.33, 0.2)), Vector3(0, 3.95, 0))
			for sx in [-1.0, 1.0]:
				part(body, cone(0.14, 0.9), bone, Vector3(0.55 * sx, 4.3, 0), Vector3(0, 0, -0.7 * sx))
				part(body, sphere(0.08, 6), fire, Vector3(0.18 * sx, 4.0, 0.42))
		"arena":
			for i in 8:
				var a2 := TAU * i / 8.0
				part(body, box(Vector3(0.6, rng_h(i), 0.5)), rock, Vector3(cos(a2) * 2.0, rng_h(i) * 0.5, sin(a2) * 2.0), Vector3(0, -a2, 0))
			part(body, cone(1.4, 0.15, 1.4, 16), mat(Color(0.35, 0.25, 0.15)), Vector3(0, 0.08, 0))
			part(body, sphere(0.35, 8), fire, Vector3(0, 0.4, 0))
			part(body, box(Vector3(0.1, 2.6, 0.1)), wood, Vector3(-2.0, 1.3, 2.0))
			part(body, box(Vector3(0.8, 0.6, 0.04)), team_m, Vector3(-1.6, 2.2, 2.0))
		"tower":
			part(body, cone(1.05, 4.4, 0.85, 10), stone, Vector3(0, 2.2, 0))
			part(body, cone(1.2, 0.5, 1.2, 10), stone_dark, Vector3(0, 4.6, 0))
			for i in 8:
				var a3 := TAU * i / 8.0
				part(body, box(Vector3(0.32, 0.4, 0.32)), stone_dark, Vector3(cos(a3) * 1.05, 5.05, sin(a3) * 1.05))
			part(body, cone(0.9, 1.3, 0.0, 10), blue, Vector3(0, 5.6, 0))
			part(body, cone(0.08, 0.5), gold, Vector3(0, 6.45, 0))
			for i in 3:
				var a4 := TAU * i / 3.0 + 0.5
				part(body, box(Vector3(0.12, 0.5, 0.12)), mat(Color(0.08, 0.06, 0.05)), Vector3(cos(a4) * 0.97, 3.2, sin(a4) * 0.97))
			part(body, box(Vector3(0.7, 0.35, 0.05)), team_m, Vector3(0, 4.15, 1.0))
		"guard_stone":
			var menhir := part(body, cone(0.95, 4.0, 0.55, 7), rock, Vector3(0, 2.0, 0))
			menhir.rotation.z = 0.05
			part(body, cone(1.4, 0.5, 1.2, 8), rock2, Vector3(0, 0.25, 0))
			for sx in [-1.0, 1.0]:
				part(body, sphere(0.13, 6), fire, Vector3(0.25 * sx, 3.1, 0.68))
			part(body, box(Vector3(0.6, 0.12, 0.08)), mat(Color(0.1, 0.08, 0.06)), Vector3(0, 2.6, 0.72))
			part(body, cone(0.12, 0.7), bone, Vector3(-0.55, 3.7, 0.2), Vector3(0, 0, 0.8))
			part(body, cone(0.12, 0.7), bone, Vector3(0.55, 3.7, 0.2), Vector3(0, 0, -0.8))
			part(body, box(Vector3(0.7, 0.4, 0.05)), team_m, Vector3(0, 1.4, 0.95))
			for i in 4:
				var a5 := TAU * i / 4.0
				part(body, sphere(0.35, 6), rock2, Vector3(cos(a5) * 1.4, 0.3, sin(a5) * 1.4))
		_:
			part(body, box(Vector3(r * 1.6, 1.5, r * 1.6)), stone, Vector3(0, 0.75, 0))

	# Qurilish ustunlari (qurilayotganda ko'rinadi)
	_scaffold = Node3D.new()
	add_child(_scaffold)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			part(_scaffold, box(Vector3(0.12, 2.4, 0.12)), wood, Vector3(r * 0.85 * sx, 1.2, r * 0.85 * sz))
	part(_scaffold, box(Vector3(r * 1.8, 0.1, 0.12)), wood, Vector3(0, 2.0, r * 0.85))
	part(_scaffold, box(Vector3(r * 1.8, 0.1, 0.12)), wood, Vector3(0, 2.0, -r * 0.85))
	_scaffold.visible = false

	_make_ring(team, r)


func _add_flag(tc: Color, r: float) -> void:
	# Kichik jamoa bayrog'i — kimning binosi ekanini ajratish uchun
	var pole := part(self, box(Vector3(0.08, 2.2, 0.08)), mat(Color(0.4, 0.27, 0.15)), Vector3(r * 0.8, 1.1, r * 0.8))
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part(self, box(Vector3(0.7, 0.45, 0.04)), mat(tc, 0.3), Vector3(r * 0.8 + 0.37, 1.95, r * 0.8))


func _make_ring(team: int, r: float) -> void:
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 1.05
	tm.outer_radius = r * 1.18
	tm.rings = 32
	tm.ring_segments = 4
	ring.mesh = tm
	var rc: Color = Color(0.3, 1.0, 0.35) if team == 0 else Color(1.0, 0.3, 0.25)
	ring.material_override = mat(rc, 1.0, true)
	ring.position = Vector3(0, 0.05, 0)
	ring.scale = Vector3(1, 0.3, 1)
	ring.visible = false
	add_child(ring)


func rng_h(i: int) -> float:
	return 1.6 + float((i * 37) % 5) * 0.25


func set_progress(p: float) -> void:
	if body == null:
		return
	var k: float = clamp(p, 0.0, 1.0)
	body.scale = Vector3(1.0, lerp(0.12, 1.0, k), 1.0)
	if _scaffold:
		_scaffold.visible = k < 1.0


func flash_hit() -> void:
	if _dead or body == null:
		return
	var base: Vector3 = body.scale
	var tw := create_tween()
	tw.tween_property(body, "position:x", 0.08, 0.04)
	tw.tween_property(body, "position:x", -0.08, 0.04)
	tw.tween_property(body, "position:x", 0.0, 0.04)
	body.scale = base


func play_death() -> void:
	_dead = true
	if body == null:
		return
	if _scaffold:
		_scaffold.visible = false
	var ruin := ModelLib.instance("kaykit/medieval/building_destroyed.gltf")
	if ruin != null:
		ruin.scale = Vector3.ONE * max(0.8, _radius * 1.1)
		add_child(ruin)
	var tw := create_tween()
	tw.tween_property(body, "scale:y", 0.15, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(body, "rotation:z", 0.15, 1.2)


## Trollar binolari: atrofida yog'och qoziqlar (palisad), old tomonda ikkita katta so'yloq,
## tepada bosh suyagi belgisi — odamlar binosidan ajralib tursin.
func add_troll_decor(r: float) -> void:
	if body == null:
		return
	var wood := mat(Color(0.36, 0.24, 0.13))
	var bone := mat(Color(0.93, 0.89, 0.76))
	var n: int = maxi(8, int(r * 6.0))
	for i in n:
		var a: float = TAU * float(i) / float(n)
		if absf(wrapf(a - PI * 0.5, -PI, PI)) < 0.45:
			continue   # old tomonda kirish yo'li ochiq
		var p := Vector3(cos(a), 0, sin(a)) * (r * 1.02)
		var h: float = 1.0 + 0.35 * float(i % 3)
		var stake := part(body, cone(0.13, h, 0.0, 5), wood, p + Vector3(0, h * 0.5, 0))
		stake.rotation = Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)
	for sx in [-1.0, 1.0]:
		var t := part(body, cone(0.22, 1.9, 0.0, 6), bone, Vector3(0.95 * sx, 0.9, r * 1.05))
		t.rotation = Vector3(0.35, 0, -0.45 * sx)
	part(body, sphere(0.42, 8), bone, Vector3(0, 0.55, r * 1.12))
	for sx in [-1.0, 1.0]:
		part(body, sphere(0.09, 5), mat(Color(0.95, 0.35, 0.1), 2.0, true), Vector3(0.15 * sx, 0.6, r * 1.12 + 0.36))
