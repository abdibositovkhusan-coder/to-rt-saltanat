class_name ModelLib
extends RefCounted
## 3D model kutubxonasi: res://assets/ ichidagi .glb/.gltf modellarni yuklaydi (keshlab), nusxa yaratadi,
## qismlarini yashiradi (masalan, ortiqcha qurollar), rang beradi (tint) va animatsiya pleyerini topadi.
## Model fayli bo'lmasa null qaytaradi — unda o'yin oddiy shakllardan yasalgan ko'rinishni ishlatadi.
## Modellar: KayKit (Kay Lousberg, CC0) — tools/fetch_models.sh orqali yuklanadi.
## Bog'liqlik: yo'q.

static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}
static var _tinted: Dictionary = {}
static var _looped: Dictionary = {}


static func full_path(rel: String) -> String:
	if rel.begins_with("res://"):
		return rel
	return "res://assets/" + rel


static func exists(rel: String) -> bool:
	if rel == "":
		return false
	return ResourceLoader.exists(full_path(rel))


static func scene(rel: String) -> PackedScene:
	if _scenes.has(rel):
		return _scenes[rel]
	var ps: PackedScene = null
	if exists(rel):
		var res = load(full_path(rel))
		if res is PackedScene:
			ps = res
	_scenes[rel] = ps
	return ps


static func instance(rel: String) -> Node3D:
	var ps := scene(rel)
	if ps == null:
		return null
	var n = ps.instantiate()
	if n is Node3D:
		return n
	if n != null:
		n.free()
	return null


## Modeldagi birinchi Mesh (MultiMesh uchun — daraxtlar, toshlar, tog'lar).
static func first_mesh(rel: String) -> Mesh:
	if _meshes.has(rel):
		return _meshes[rel]
	var m: Mesh = null
	var inst := instance(rel)
	if inst != null:
		var mi := _find_mesh_instance(inst)
		if mi != null:
			m = mi.mesh
		inst.free()
	_meshes[rel] = m
	return m


static func _find_mesh_instance(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh_instance(c)
		if r != null:
			return r
	return null


static func find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := find_anim_player(c)
		if r != null:
			return r
	return null


## Nomi aynan mos keladigan barcha tugunlarni yashiradi/ko'rsatadi.
static func set_part_visible(root: Node, part_name: String, v: bool) -> void:
	if root.name == part_name and root is Node3D:
		(root as Node3D).visible = v
	for c in root.get_children():
		set_part_visible(c, part_name, v)


## Barcha materiallarni berilgan rang bilan ko'paytiradi (masalan, trollar uchun yashil teri).
static func tint(root: Node, c: Color) -> void:
	if root is MeshInstance3D:
		var mi: MeshInstance3D = root
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var base := mi.get_active_material(i)
				if base is BaseMaterial3D:
					var key: String = "%d_%s" % [base.get_instance_id(), c.to_html()]
					var tm: Material = _tinted.get(key, null)
					if tm == null:
						var dup: BaseMaterial3D = base.duplicate()
						dup.albedo_color = (base as BaseMaterial3D).albedo_color * c
						tm = dup
						_tinted[key] = tm
					mi.set_surface_override_material(i, tm)
	for ch in root.get_children():
		tint(ch, c)


static func no_shadows(root: Node) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ch in root.get_children():
		no_shadows(ch)


static func make_loop(ap: AnimationPlayer, anim_name: String) -> void:
	if ap == null or anim_name == "" or not ap.has_animation(anim_name):
		return
	var a := ap.get_animation(anim_name)
	var key := a.get_instance_id()
	if _looped.has(key):
		return
	a.loop_mode = Animation.LOOP_LINEAR
	_looped[key] = true
