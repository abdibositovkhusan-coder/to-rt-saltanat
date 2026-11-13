class_name UnitVisual
extends Node3D
## Birlikning 3D ko'rinishini oddiy shakllardan (low-poly) quradi: odam, troll, elf, o'lmas.
## "look" lug'ati bo'yicha: tana turi, ranglar, qurol, qalqon, dubulg'a, tishlar, toj, plash, ko'zlar.
## Keyinchalik .glb modellar bilan almashtirish mumkin. Yurish/hujum/o'lim animatsiyalari protsedural.
## Bog'liqlik: yo'q (Unit va CutscenePlayer ishlatadi).

static var _mat_cache: Dictionary = {}

var scale_factor: float = 1.0
var team_color: Color = Color.WHITE
var _slow_fx: MeshInstance3D = null
var _machine_arm: Node3D = null
var moving: bool = false
var body: Node3D
var ring: MeshInstance3D
var arm_r: Node3D
var arm_l: Node3D
var leg_r: Node3D
var leg_l: Node3D
var torso: MeshInstance3D

var _phase: float = 0.0
var _attacking: bool = false
var _dead: bool = false
var _body_kind: String = "human"
var _ranged_pose: bool = false
var _rest_arm: float = -0.25

# Model rejimi (KayKit .glb, animatsiyalari bilan)
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _anims: Dictionary = {}
var _cur_anim: String = ""

# Jonzot (procedural): oyoqlar, qanotlar, segmentlar
var _legs: Array = []
var _wings: Array = []
var _segments: Array = []
var _walker: bool = false
var _creature_root: Node3D = null


static func mat(c: Color, emissive: float = 0.0, unshaded: bool = false, alpha: bool = false) -> StandardMaterial3D:
	var key: String = "%s_%s_%s_%s" % [c.to_html(true), emissive, unshaded, alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func sphere(r: float, segments: int = 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segments
	s.rings = max(4, segments / 2)
	return s


static func cone(r_bottom: float, h: float, r_top: float = 0.0, segments: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	return c


static func part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func build(look: Dictionary, team_col: Color, team: int) -> void:
	team_color = team_col
	_body_kind = str(look.get("body", "human"))
	scale_factor = float(look.get("scale", 1.0))
	scale = Vector3.ONE * scale_factor
	if str(look.get("creature", "")) != "":
		_build_creature_unit(look, team_col, team)
		return
	if str(look.get("model", "")) != "" and _build_model(look, team_col, team):
		return

	var cloth := GameData.color(look.get("cloth", ""), team_color)
	var metal := GameData.color(look.get("armor", ""), Color(0.6, 0.62, 0.66))
	var default_skin := Color(0.88, 0.7, 0.55)
	if _body_kind == "troll":
		default_skin = Color(0.43, 0.6, 0.32)
	elif _body_kind == "dead":
		default_skin = Color(0.8, 0.8, 0.85)
	elif _body_kind == "elf":
		default_skin = Color(0.95, 0.84, 0.74)
	var skin := GameData.color(look.get("skin", ""), default_skin)
	var dark := Color(0.18, 0.13, 0.1)

	body = Node3D.new()
	add_child(body)

	# O'lchamlar tana turiga qarab
	var torso_w := 0.55
	var torso_d := 0.32
	var torso_h := 0.7
	var leg_h := 0.8
	var head_r := 0.2
	var arm_len := 0.62
	var hunch := 0.0
	if _body_kind == "troll":
		torso_w = 0.78
		torso_d = 0.5
		torso_h = 0.75
		leg_h = 0.7
		head_r = 0.23
		arm_len = 0.85
		hunch = 0.28
	elif _body_kind == "elf":
		torso_w = 0.46
		torso_d = 0.28
		torso_h = 0.72
		leg_h = 0.88
		head_r = 0.18
	var hip_y := leg_h
	var torso_y := hip_y + torso_h * 0.5
	var shoulder_y := hip_y + torso_h - 0.06
	var head_y := hip_y + torso_h + head_r * 0.95

	# Oyoqlar
	leg_r = pivot(body, Vector3(-0.13 * (torso_w / 0.55), hip_y, 0))
	leg_l = pivot(body, Vector3(0.13 * (torso_w / 0.55), hip_y, 0))
	for leg in [leg_r, leg_l]:
		part(leg, box(Vector3(0.19, leg_h, 0.21)), mat(dark.lerp(cloth, 0.35)), Vector3(0, -leg_h * 0.5, 0))
		part(leg, box(Vector3(0.21, 0.12, 0.3)), mat(dark), Vector3(0, -leg_h + 0.06, 0.04))

	# Tana
	var upper := pivot(body, Vector3(0, hip_y, 0))
	upper.rotation.x = hunch
	torso = part(upper, box(Vector3(torso_w, torso_h, torso_d)), mat(cloth), Vector3(0, torso_h * 0.5, 0))
	part(upper, box(Vector3(torso_w + 0.04, 0.1, torso_d + 0.04)), mat(dark), Vector3(0, 0.05, 0))
	if look.get("shield", false) or look.get("helmet", false):
		# Ko'krak sovuti
		part(upper, box(Vector3(torso_w * 0.8, torso_h * 0.5, 0.05)), mat(metal), Vector3(0, torso_h * 0.62, torso_d * 0.5 + 0.02))

	# Bosh
	var head := pivot(upper, Vector3(0, head_y - hip_y, 0.02 + hunch * 0.35))
	part(head, sphere(head_r), mat(skin), Vector3.ZERO)
	if look.get("helmet", false):
		part(head, cone(head_r * 1.08, head_r * 0.9, head_r * 0.35), mat(metal), Vector3(0, head_r * 0.55, 0))
	if look.get("hood", false):
		part(head, sphere(head_r * 1.18), mat(cloth.darkened(0.15)), Vector3(0, 0.04, -0.04))
	if look.get("tusks", false):
		for sx in [-1.0, 1.0]:
			part(head, cone(0.035, 0.14), mat(Color(0.95, 0.92, 0.8)), Vector3(0.08 * sx, -0.08, head_r * 0.85))
		part(head, box(Vector3(head_r * 1.6, 0.06, 0.08)), mat(dark), Vector3(0, 0.07, head_r * 0.85))
	if _body_kind == "elf":
		for sx in [-1.0, 1.0]:
			part(head, cone(0.04, 0.22), mat(skin), Vector3(head_r * 0.95 * sx, 0.04, 0), Vector3(0, 0, -1.2 * sx))
	if look.get("crown", false):
		var gold := GameData.color(look.get("crown_color", ""), Color(0.85, 0.7, 0.2))
		for i in 5:
			var ang := TAU * i / 5.0
			part(head, cone(0.045, 0.2), mat(gold, 0.4), Vector3(cos(ang) * head_r * 0.75, head_r * 0.85, sin(ang) * head_r * 0.75))
	if look.has("eyes"):
		var ec := GameData.color(look.get("eyes", ""), Color(0.5, 1.0, 0.3))
		for sx in [-1.0, 1.0]:
			part(head, sphere(0.035, 6), mat(ec, 3.0, true), Vector3(0.07 * sx, 0.03, head_r * 0.9))
	if look.has("cape"):
		var cc := GameData.color(look.get("cape", ""), Color(0.6, 0.1, 0.1))
		part(upper, box(Vector3(torso_w * 0.95, torso_h + leg_h * 0.75, 0.04)), mat(cc), Vector3(0, torso_h - (torso_h + leg_h * 0.75) * 0.5, -torso_d * 0.5 - 0.04), Vector3(0.12, 0, 0))

	# Qo'llar
	arm_r = pivot(upper, Vector3(-(torso_w * 0.5 + 0.09), shoulder_y - hip_y, 0))
	arm_l = pivot(upper, Vector3(torso_w * 0.5 + 0.09, shoulder_y - hip_y, 0))
	for arm in [arm_r, arm_l]:
		part(arm, box(Vector3(0.15, arm_len, 0.17)), mat(cloth.lerp(skin, 0.4)), Vector3(0, -arm_len * 0.5, 0))
		part(arm, sphere(0.09, 8), mat(skin), Vector3(0, -arm_len, 0))
	arm_r.rotation.x = _rest_arm
	arm_l.rotation.x = _rest_arm

	var hand := Vector3(0, -arm_len, 0)
	var weapon := str(look.get("weapon", "none"))
	var wood := Color(0.45, 0.3, 0.16)
	match weapon:
		"sword":
			var w1 := pivot(arm_r, hand)
			w1.rotation.x = 1.45
			part(w1, box(Vector3(0.06, 0.85, 0.025)), mat(Color(0.85, 0.87, 0.9), 0.15), Vector3(0, 0.5, 0))
			part(w1, box(Vector3(0.24, 0.05, 0.06)), mat(Color(0.75, 0.6, 0.2)), Vector3(0, 0.08, 0))
		"axe":
			var w2 := pivot(arm_r, hand)
			w2.rotation.x = 1.45
			part(w2, box(Vector3(0.07, 0.95, 0.07)), mat(wood), Vector3(0, 0.4, 0))
			part(w2, box(Vector3(0.05, 0.32, 0.36)), mat(Color(0.5, 0.5, 0.52)), Vector3(0, 0.78, 0.14))
		"spear":
			var w3 := pivot(arm_r, hand)
			w3.rotation.x = 1.45
			part(w3, box(Vector3(0.05, 1.7, 0.05)), mat(wood), Vector3(0, 0.45, 0))
			part(w3, cone(0.07, 0.3), mat(Color(0.7, 0.72, 0.75)), Vector3(0, 1.43, 0))
		"bow":
			_ranged_pose = true
			var w4 := pivot(arm_l, hand)
			w4.rotation.x = 1.45
			part(w4, box(Vector3(0.04, 0.05, 1.15)), mat(wood), Vector3(0, 0.0, 0.0))
			part(w4, box(Vector3(0.01, 0.12, 1.1)), mat(Color(0.9, 0.9, 0.85)), Vector3(0, -0.08, 0))
		"staff":
			var w5 := pivot(arm_r, hand)
			w5.rotation.x = 1.45
			part(w5, box(Vector3(0.06, 1.5, 0.06)), mat(wood), Vector3(0, 0.3, 0))
			part(w5, sphere(0.11, 8), mat(GameData.color(look.get("glow", ""), Color(0.5, 0.8, 1.0)), 2.5, true), Vector3(0, 1.1, 0))
	if look.get("shield", false):
		var s := pivot(arm_l, hand + Vector3(0.05, 0.12, 0.08))
		part(s, cone(0.3, 0.06, 0.3, 14), mat(team_color), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
		part(s, sphere(0.07, 8), mat(Color(0.8, 0.65, 0.2)), Vector3(0, 0, 0.05))

	_build_ring(team, 0.55 if _body_kind != "troll" else 0.7)


## Faqat jonzotdan iborat birlik (ayiq, ilon, qush, ajdar, bo'ron).
func _build_creature_unit(look: Dictionary, tc: Color, team: int) -> void:
	body = Node3D.new()
	add_child(body)
	var c := CreatureBuilder.build(body, str(look.get("creature", "")), look)
	_take_creature(c)
	var fh := float(look.get("fly_height", 0.0))
	if fh > 0.0:
		body.position.y = fh
		var bob := create_tween().set_loops()
		bob.tween_property(body, "position:y", fh + 0.3, 1.1).set_trans(Tween.TRANS_SINE)
		bob.tween_property(body, "position:y", fh - 0.1, 1.1).set_trans(Tween.TRANS_SINE)
	_add_team_disc(tc, look)
	_build_ring(team, float(look.get("ring", 0.7)))


func _take_creature(c: Dictionary) -> void:
	_creature_root = c["root"]
	_legs = c["legs"]
	_wings = c["wings"]
	_segments = c["segments"]
	for i in _wings.size():
		var w: Node3D = _wings[i]
		var sgn: float = -1.0 if i % 2 == 0 else 1.0
		var tw := w.create_tween().set_loops()
		tw.tween_property(w, "rotation:z", 0.55 * sgn, 0.35).set_trans(Tween.TRANS_SINE)
		tw.tween_property(w, "rotation:z", -0.35 * sgn, 0.35).set_trans(Tween.TRANS_SINE)


func _add_team_disc(tc: Color, look: Dictionary) -> void:
	if not look.get("base", true):
		return
	var disc := MeshInstance3D.new()
	var r: float = float(look.get("ring", 0.6)) * 0.85
	disc.mesh = cone(r, 0.03, r, 18)
	disc.material_override = mat(Color(tc.r, tc.g, tc.b, 0.75), 0.4, true, true)
	disc.position = Vector3(0, 0.03, 0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)


## Haqiqiy 3D model (animatsiyali). Model topilmasa false — oddiy shakllar ishlatiladi.
func _build_model(look: Dictionary, tc: Color, team: int) -> bool:
	var m := ModelLib.instance(str(look.get("model", "")))
	if m == null:
		return false
	body = Node3D.new()
	add_child(body)
	var mount = look.get("mount", null)
	if mount is Dictionary:
		var c := CreatureBuilder.build(body, str(mount.get("kind", "horse")), mount)
		_take_creature(c)
		var rider := Node3D.new()
		rider.position.y = float(c["saddle"]) - 0.35
		body.add_child(rider)
		rider.add_child(m)
	else:
		body.add_child(m)
	_walker = bool(look.get("walker", false))
	if look.has("eyes_glow"):
		var ec := GameData.color(look.get("eyes_glow", ""), Color(1, 0.9, 0.4))
		for sx in [-1.0, 1.0]:
			part(body, sphere(0.09, 6), mat(ec, 3.0, true), Vector3(0.22 * sx, 2.3, 0.55))
	_model = m
	m.scale = Vector3.ONE * float(look.get("model_scale", 0.85))
	m.position.y = float(look.get("model_offset_y", 0.0))
	if look.get("strip_root", false) and m is MeshInstance3D:
		(m as MeshInstance3D).mesh = null
	var arm_name := str(look.get("machine_arm", ""))
	if arm_name != "":
		_machine_arm = _find_node3d(m, arm_name)
	if look.get("wheels", false):
		var wood := mat(Color(0.45, 0.3, 0.16))
		part(body, box(Vector3(1.3, 0.25, 1.7)), wood, Vector3(0, 0.5, 0))
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				part(body, cone(0.32, 0.14, 0.32, 12), mat(Color(0.3, 0.2, 0.12)), Vector3(0.72 * sx, 0.32, 0.6 * sz), Vector3(0, 0, PI * 0.5))
	var fh := float(look.get("fly_height", 0.0))
	if fh > 0.0:
		body.position.y = fh
		if look.get("carpet", false):
			part(body, box(Vector3(1.5, 0.06, 1.9)), mat(Color(0.7, 0.12, 0.15)), Vector3(0, 0.02, 0))
			part(body, box(Vector3(1.62, 0.04, 2.02)), mat(Color(0.85, 0.65, 0.2), 0.3), Vector3(0, 0.0, 0))
			part(body, box(Vector3(0.9, 0.07, 1.2)), mat(Color(0.15, 0.3, 0.6)), Vector3(0, 0.04, 0))
		var bob := create_tween().set_loops()
		bob.tween_property(body, "position:y", fh + 0.25, 1.2).set_trans(Tween.TRANS_SINE)
		bob.tween_property(body, "position:y", fh - 0.1, 1.2).set_trans(Tween.TRANS_SINE)
	var hide_list = look.get("hide", [])
	if hide_list is Array:
		for part_name in hide_list:
			ModelLib.set_part_visible(m, str(part_name), false)
	if look.has("tint"):
		ModelLib.tint(m, GameData.color(look.get("tint", ""), Color.WHITE))
	if look.has("skin_tint"):
		_tint_skin(m, GameData.color(look.get("skin_tint", ""), Color(0.45, 0.8, 0.35)))
	var widen: float = float(look.get("widen", 1.0))
	if widen != 1.0:
		m.scale = Vector3(m.scale.x * widen, m.scale.y, m.scale.z * widen)
	if bool(look.get("troll_face", false)):
		_add_troll_face(m, look)
	_anims = {"idle": "Idle", "walk": "Walking_A", "attack": "1H_Melee_Attack_Chop", "ranged": "", "death": "Death_A"}
	var extra = look.get("anims", {})
	if extra is Dictionary:
		_anims.merge(extra, true)
	_anim = ModelLib.find_anim_player(m)
	if _anim != null:
		ModelLib.make_loop(_anim, str(_anims["idle"]))
		ModelLib.make_loop(_anim, str(_anims["walk"]))
		_play("idle", 0.0)
	# Jamoa belgisi: oyoq ostida rangli doira (modellar jamoa rangida emas)
	_add_team_disc(tc, look)
	_build_ring(team, float(look.get("ring", 0.6)))
	return true


func _play(key: String, blend: float = 0.15) -> void:
	if _anim == null:
		return
	var anim_name := str(_anims.get(key, ""))
	if anim_name == "" or not _anim.has_animation(anim_name):
		return
	if _cur_anim == anim_name and _anim.is_playing():
		return
	_cur_anim = anim_name
	_anim.play(anim_name, blend)


func _find_node3d(n: Node, nm: String) -> Node3D:
	if n.name == nm and n is Node3D:
		return n
	for c in n.get_children():
		var r := _find_node3d(c, nm)
		if r != null:
			return r
	return null


func set_slowed(v: bool) -> void:
	if v and _slow_fx == null:
		_slow_fx = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.3
		tm.outer_radius = 0.42
		tm.rings = 16
		tm.ring_segments = 4
		_slow_fx.mesh = tm
		_slow_fx.material_override = mat(Color(0.45, 0.7, 1.0), 2.0, true)
		_slow_fx.position = Vector3(0, 2.3, 0)
		_slow_fx.scale = Vector3(1, 0.3, 1)
		add_child(_slow_fx)
	if _slow_fx != null:
		_slow_fx.visible = v


var _stun_fx: Node3D = null


func set_stunned(v: bool) -> void:
	if v and _stun_fx == null:
		_stun_fx = Node3D.new()
		add_child(_stun_fx)
		for i in 3:
			var a := TAU * i / 3.0
			part(_stun_fx, sphere(0.1, 6), mat(Color(1.0, 0.9, 0.3), 2.5, true), Vector3(cos(a) * 0.35, 0, sin(a) * 0.35))
		_stun_fx.position = Vector3(0, 2.5, 0)
		var tw := _stun_fx.create_tween().set_loops()
		tw.tween_property(_stun_fx, "rotation:y", TAU, 1.0).from(0.0)
	if _stun_fx != null:
		_stun_fx.visible = v


## Qahramon darajasi oshganda oltin nur.
func play_levelup() -> void:
	var r := MeshInstance3D.new()
	r.mesh = cone(0.9, 3.0, 0.4, 16)
	r.material_override = mat(Color(1.0, 0.85, 0.3, 0.45), 2.0, true, true)
	r.position = Vector3(0, 1.5, 0)
	add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "scale", Vector3(1.6, 1.2, 1.6), 0.8)
	tw.parallel().tween_property(r, "position:y", 2.5, 0.8)
	tw.tween_callback(r.queue_free)


## Qobiliyat ishlatilganda sehr animatsiyasi.
func play_cast() -> void:
	if _model != null and _anim != null:
		_attacking = true
		_cur_anim = ""
		var nm := "Spellcast_Raise"
		if _anim.has_animation(nm):
			_cur_anim = nm
			_anim.play(nm, 0.08)
		var tw0 := create_tween()
		tw0.tween_interval(0.7)
		tw0.tween_callback(_end_model_attack)
	else:
		play_attack(false)


func _end_model_attack() -> void:
	_attacking = false
	_cur_anim = ""


func _anim_length(key: String) -> float:
	if _anim == null:
		return 0.6
	var anim_name := str(_anims.get(key, ""))
	if anim_name == "" or not _anim.has_animation(anim_name):
		return 0.6
	return _anim.get_animation(anim_name).length


func _build_ring(team: int, rr: float) -> void:
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = rr * 0.86
	tm.outer_radius = rr
	tm.rings = 24
	tm.ring_segments = 4
	ring.mesh = tm
	var rc: Color = Color(0.3, 1.0, 0.35) if team == 0 else Color(1.0, 0.3, 0.25)
	ring.material_override = mat(rc, 1.0, true)
	ring.position = Vector3(0, 0.04, 0)
	ring.scale = Vector3(1, 0.3, 1)
	ring.visible = false
	add_child(ring)


func set_selected(v: bool) -> void:
	if ring:
		ring.visible = v


var _carry_node: Node3D = null


## Ishchi ko'tarib yurgan yuk: "gold" — oltin bo'lagi, "wood" — yog'och, "" — hech narsa.
func set_carry(kind: String) -> void:
	if _carry_node != null and is_instance_valid(_carry_node):
		_carry_node.queue_free()
	_carry_node = null
	if kind == "" or body == null:
		return
	_carry_node = Node3D.new()
	body.add_child(_carry_node)
	if kind == "gold":
		part(_carry_node, box(Vector3(0.3, 0.22, 0.25)), mat(Color(1.0, 0.8, 0.2), 1.0), Vector3(0, 1.15, 0.38))
	else:
		part(_carry_node, cone(0.1, 1.0, 0.1, 6), mat(Color(0.5, 0.34, 0.18)), Vector3(0.12, 1.75, -0.1), Vector3(0, 0, PI * 0.5))
		part(_carry_node, cone(0.1, 1.0, 0.1, 6), mat(Color(0.45, 0.3, 0.16)), Vector3(0.12, 1.92, -0.1), Vector3(0, 0, PI * 0.5))


func play_attack(ranged: bool) -> void:
	if _dead:
		return
	if _machine_arm != null:
		var twm := create_tween()
		twm.tween_property(_machine_arm, "rotation:x", -1.3, 0.18)
		twm.tween_property(_machine_arm, "rotation:x", 0.0, 0.9)
	if _model != null:
		_attacking = true
		var key: String = "ranged" if ranged and str(_anims.get("ranged", "")) != "" else "attack"
		_cur_anim = ""
		_play(key, 0.08)
		var tw0 := create_tween()
		tw0.tween_interval(max(0.25, _anim_length(key) * 0.85))
		tw0.tween_callback(_end_model_attack)
		return
	if arm_r == null:
		return
	_attacking = true
	var tw := create_tween()
	if ranged or _ranged_pose:
		var arm: Node3D = arm_l if _ranged_pose else arm_r
		tw.tween_property(arm, "rotation:x", -1.55, 0.15)
		tw.parallel().tween_property(arm_r, "rotation:x", -1.3, 0.15)
		tw.tween_interval(0.12)
		tw.tween_property(arm_r, "rotation:x", -0.9, 0.06)
		tw.tween_interval(0.15)
		tw.tween_property(arm, "rotation:x", _rest_arm, 0.25)
		tw.parallel().tween_property(arm_r, "rotation:x", _rest_arm, 0.25)
	else:
		tw.tween_property(arm_r, "rotation:x", -2.5, 0.16)
		tw.tween_property(arm_r, "rotation:x", -0.45, 0.1)
		tw.tween_property(arm_r, "rotation:x", _rest_arm, 0.22)
	tw.tween_callback(func(): _attacking = false)


func flash_hit() -> void:
	if _dead or body == null or _model != null:
		return
	var tw := create_tween()
	tw.tween_property(body, "scale", Vector3(1.08, 0.94, 1.08), 0.05)
	tw.tween_property(body, "scale", Vector3.ONE, 0.1)


func play_death() -> void:
	_dead = true
	moving = false
	if _model != null:
		_cur_anim = ""
		_play("death", 0.1)
		return
	if body == null:
		return
	var tw := create_tween()
	tw.tween_property(body, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(body, "position:y", 0.15, 0.45)


func _animate_creature(delta: float) -> void:
	if _dead:
		return
	if moving:
		_phase += delta * 8.0
	var s := sin(_phase)
	for i in _legs.size():
		var leg: Node3D = _legs[i]
		var sgn: float = 1.0 if (i % 2 == 0) != (i >= 2) else -1.0
		leg.rotation.x = lerp(leg.rotation.x, (s * 0.55 * sgn) if moving else 0.0, clamp(delta * 12.0, 0.0, 1.0))
	for i in _segments.size():
		var seg: Node3D = _segments[i]
		seg.position.x = sin(_phase * 0.8 + i * 0.7) * 0.15 * (1.0 if moving else 0.4)
	if _walker and body != null:
		body.rotation.z = sin(_phase * 0.5) * (0.07 if moving else 0.0)


func _process(delta: float) -> void:
	if _creature_root != null or _walker:
		if not moving:
			_phase += delta * 1.5
		_animate_creature(delta)
	if _model != null:
		if not _dead and not _attacking:
			_play("walk" if moving else "idle")
		return
	if _creature_root != null:
		return
	if _dead or leg_r == null:
		return
	if moving:
		_phase += delta * 9.0
		var s := sin(_phase)
		leg_r.rotation.x = s * 0.6
		leg_l.rotation.x = -s * 0.6
		if not _attacking:
			arm_r.rotation.x = _rest_arm - s * 0.35
			arm_l.rotation.x = _rest_arm + s * 0.35
		body.position.y = abs(sin(_phase)) * 0.05
	else:
		leg_r.rotation.x = lerp(leg_r.rotation.x, 0.0, delta * 10.0)
		leg_l.rotation.x = lerp(leg_l.rotation.x, 0.0, delta * 10.0)
		body.position.y = lerp(body.position.y, 0.0, delta * 10.0)
		# Nafas olish
		_phase += delta * 2.0
		if torso:
			torso.scale = Vector3(1.0 + sin(_phase) * 0.012, 1.0, 1.0)


# ---------------- Trollar qiyofasi ----------------

## Faqat teri qismlarini (bosh, qo'llar) bo'yaydi — kiyim o'z rangida qoladi.
func _tint_skin(root: Node, c: Color) -> void:
	if root is MeshInstance3D:
		var n: String = str(root.name)
		if n.ends_with("_Head") or n.ends_with("_ArmLeft") or n.ends_with("_ArmRight"):
			ModelLib.tint(root, c)
	for ch in root.get_children():
		_tint_skin(ch, c)


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for ch in root.get_children():
		var sk := _find_skeleton(ch)
		if sk != null:
			return sk
	return null


## Bosh suyagiga so'yloq tishlar, uzun o'tkir quloqlar, qalin qosh va kokil yopishtiradi.
func _add_troll_face(m: Node3D, look: Dictionary) -> void:
	var sk := _find_skeleton(m)
	if sk == null or sk.find_bone("head") < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	sk.add_child(att)
	var skin_c: Color = GameData.color(look.get("face_color", ""), Color(0.36, 0.58, 0.26))
	var tusk_c := Color(0.95, 0.92, 0.78)
	var hair_c: Color = GameData.color(look.get("hair_color", ""), Color(0.12, 0.08, 0.06))
	var skin_m := mat(skin_c)
	var tusk_m := mat(tusk_c)
	# So'yloq tishlar (pastki jag'dan yuqoriga)
	for sx in [-1.0, 1.0]:
		part(att, cone(0.065, 0.3, 0.0, 6), tusk_m, Vector3(0.2 * sx, 0.2, 0.47), Vector3(-0.35, 0, -0.3 * sx))
	# Uzun o'tkir quloqlar
	for sx in [-1.0, 1.0]:
		part(att, cone(0.13, 0.55, 0.0, 6), skin_m, Vector3(0.6 * sx, 0.55, -0.02), Vector3(0, 0, -sx * (PI * 0.5 - 0.35)))
	# Qalin qosh
	part(att, box(Vector3(0.78, 0.1, 0.14)), mat(skin_c.darkened(0.35)), Vector3(0, 0.72, 0.47), Vector3(0.25, 0, 0))
	# Kokil (mohawk)
	if not bool(look.get("no_hair", false)):
		part(att, box(Vector3(0.14, 0.3, 0.75)), mat(hair_c), Vector3(0, 1.02, -0.05))
		part(att, cone(0.08, 0.5, 0.0, 5), mat(hair_c), Vector3(0, 0.9, -0.5), Vector3(-1.9, 0, 0))
