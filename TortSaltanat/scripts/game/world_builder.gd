class_name WorldBuilder
extends RefCounted
## Dunyo qurish yordamchisi: osmon/yorug'lik holatlari (kun, shom, tun, zulmat), yer,
## daraxtlar, toshlar va chetdagi tog'lar. Jang ham, kino-sahna ham shundan foydalanadi.
## Modellar mavjud bo'lsa KayKit daraxt/tosh/tog'lari ishlatiladi.
## Bog'liqlik: UnitVisual (materiallar va shakllar), ModelLib.

const PRESETS := {
	"day": {"top": "#4f86c6", "horizon": "#cfe3f0", "ground": "#6f8f4a", "sun": "#fff2d6", "energy": 1.25, "ambient": 0.55, "angle": -55.0, "grass": "#5f8a3c"},
	"dusk": {"top": "#3b3a6b", "horizon": "#f0965a", "ground": "#5a4a3a", "sun": "#ffb070", "energy": 1.0, "ambient": 0.45, "angle": -20.0, "grass": "#5b7a3a"},
	"night": {"top": "#0b1430", "horizon": "#2a3d6a", "ground": "#1a2230", "sun": "#9fb8ff", "energy": 0.6, "ambient": 0.35, "angle": -50.0, "grass": "#2f4a3a"},
	"dark": {"top": "#07040c", "horizon": "#2a1238", "ground": "#100a14", "sun": "#b080ff", "energy": 0.45, "ambient": 0.25, "angle": -40.0, "grass": "#2a2233"},
}


static func build_environment(parent: Node, preset: String) -> Dictionary:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = Settings.shadows
	sun.rotation_degrees = Vector3(-55, 35, 0)
	parent.add_child(sun)

	var out := {"world_env": we, "env": env, "sky_mat": sm, "sun": sun}
	apply_preset(out, preset)
	return out


static func apply_preset(world: Dictionary, preset: String) -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["day"])
	var sm: ProceduralSkyMaterial = world["sky_mat"]
	sm.sky_top_color = Color.html(p["top"])
	sm.sky_horizon_color = Color.html(p["horizon"])
	sm.ground_bottom_color = Color.html(p["ground"])
	sm.ground_horizon_color = Color.html(p["horizon"]).darkened(0.3)
	var env: Environment = world["env"]
	env.ambient_light_energy = float(p["ambient"])
	var sun: DirectionalLight3D = world["sun"]
	sun.light_color = Color.html(p["sun"])
	sun.light_energy = float(p["energy"])
	sun.rotation_degrees = Vector3(float(p["angle"]), 35, 0)
	if world.has("ground_mat"):
		var gm: StandardMaterial3D = world["ground_mat"]
		gm.albedo_color = Color.html(p["grass"])


static func build_ground(parent: Node3D, world: Dictionary, size: float, preset: String, seed_value: int, decor: bool, clear_radius: float = 22.0, clear_spots: Array = []) -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["day"])
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color.html(p["grass"])
	gm.roughness = 1.0
	ground.material_override = gm
	parent.add_child(ground)
	world["ground_mat"] = gm

	# Yo'l (chegara bo'ylab tuproq yo'lak)
	var road := MeshInstance3D.new()
	road.mesh = UnitVisual.box(Vector3(size * 0.9, 0.02, 5.0))
	road.material_override = UnitVisual.mat(Color(0.55, 0.45, 0.3))
	road.position = Vector3(0, 0.01, 0)
	road.rotation.y = deg_to_rad(-30)
	parent.add_child(road)

	if not decor:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half := size * 0.5

	# Daraxtlar — MultiMesh (telefon uchun tez)
	var tree_positions: Array = []
	var tries := 0
	while tree_positions.size() < 140 and tries < 2000:
		tries += 1
		var pos := Vector3(rng.randf_range(-half + 3, half - 3), 0, rng.randf_range(-half + 3, half - 3))
		if pos.length() < clear_radius:
			continue
		# O'yinchi va dushman boshlang'ich joylarini bo'sh qoldiramiz
		if pos.distance_to(Vector3(-15, 0, 9)) < 10.0 or pos.distance_to(Vector3(15, 0, -9)) < 10.0:
			continue
		if _in_spots(pos, clear_spots):
			continue
		tree_positions.append(pos)
	var tree_a := ModelLib.first_mesh("kaykit/medieval/tree_single_A.gltf")
	var tree_b := ModelLib.first_mesh("kaykit/medieval/tree_single_B.gltf")
	if tree_a != null and tree_b != null:
		# Haqiqiy daraxt modellari (KayKit)
		var na: int = tree_positions.size() / 2
		var mm_a := _multimesh(parent, tree_a, null, na)
		var mm_b := _multimesh(parent, tree_b, null, tree_positions.size() - na)
		for i in tree_positions.size():
			var s := rng.randf_range(2.6, 4.2)
			var b := Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
			var pos: Vector3 = tree_positions[i]
			if i < na:
				mm_a.set_instance_transform(i, Transform3D(b, pos))
			else:
				mm_b.set_instance_transform(i - na, Transform3D(b, pos))
	else:
		var trunk_mm := _multimesh(parent, UnitVisual.cone(0.18, 1.4, 0.13, 6), UnitVisual.mat(Color(0.4, 0.27, 0.15)), tree_positions.size())
		var crown_mm := _multimesh(parent, UnitVisual.cone(1.1, 2.6, 0.0, 7), UnitVisual.mat(Color.html(p["grass"]).darkened(0.35)), tree_positions.size())
		for i in tree_positions.size():
			var s := rng.randf_range(0.8, 1.5)
			var b := Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
			var pos: Vector3 = tree_positions[i]
			trunk_mm.set_instance_transform(i, Transform3D(b, pos + Vector3(0, 0.7 * s, 0)))
			crown_mm.set_instance_transform(i, Transform3D(b, pos + Vector3(0, 2.4 * s, 0)))

	# Toshlar
	var rock_count := 40
	var rock_mesh := ModelLib.first_mesh("kaykit/medieval/rock_single_C.gltf")
	var rock_mm: MultiMesh
	if rock_mesh != null:
		rock_mm = _multimesh(parent, rock_mesh, null, rock_count)
	else:
		rock_mm = _multimesh(parent, UnitVisual.sphere(0.6, 6), UnitVisual.mat(Color(0.5, 0.5, 0.52)), rock_count)
	for i in rock_count:
		var pos := Vector3(rng.randf_range(-half + 2, half - 2), 0.0 if rock_mesh != null else 0.1, rng.randf_range(-half + 2, half - 2))
		var s := rng.randf_range(0.4, 1.3)
		if rock_mesh != null:
			s *= 6.0
		if _in_spots(pos, clear_spots):
			s = 0.01
		var b := Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.3, s * 0.7, s))
		rock_mm.set_instance_transform(i, Transform3D(b, pos))

	# Chetdagi tog'lar
	var mount_count := 28
	var mountains: Array = []
	for nm in ["mountain_A", "mountain_B", "mountain_C", "mountain_A_grass_trees"]:
		var mm_mesh := ModelLib.first_mesh("kaykit/medieval/%s.gltf" % nm)
		if mm_mesh != null:
			mountains.append(mm_mesh)
	if mountains.size() > 0:
		var per: Array = []
		for k in mountains.size():
			per.append([])
		for i in mount_count:
			var ang := TAU * i / mount_count + rng.randf_range(-0.05, 0.05)
			var r := half + rng.randf_range(3.0, 9.0)
			var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
			var s := rng.randf_range(9.0, 14.0)
			var b := Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.4), s))
			per[i % mountains.size()].append(Transform3D(b, pos))
		for k in mountains.size():
			var list: Array = per[k]
			var mmk := _multimesh(parent, mountains[k], null, list.size())
			for j in list.size():
				mmk.set_instance_transform(j, list[j])
	else:
		var mount_mm := _multimesh(parent, UnitVisual.cone(9.0, 14.0, 0.0, 6), UnitVisual.mat(Color(0.42, 0.4, 0.42)), mount_count)
		var snow_mm := _multimesh(parent, UnitVisual.cone(3.3, 5.0, 0.0, 6), UnitVisual.mat(Color(0.95, 0.96, 1.0)), mount_count)
		for i in mount_count:
			var ang := TAU * i / mount_count + rng.randf_range(-0.05, 0.05)
			var r := half + rng.randf_range(2.0, 8.0)
			var pos := Vector3(cos(ang) * r, 0, sin(ang) * r)
			var s := rng.randf_range(0.8, 1.6)
			var b := Basis().scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
			mount_mm.set_instance_transform(i, Transform3D(b, pos + Vector3(0, 7.0 * b.y.y, 0)))
			snow_mm.set_instance_transform(i, Transform3D(b, pos + Vector3(0, 11.6 * b.y.y, 0)))


static func _multimesh(parent: Node3D, mesh: Mesh, m, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	parent.add_child(mmi)
	return mm


static func _in_spots(pos: Vector3, spots: Array) -> bool:
	for sp in spots:
		if sp is Array and sp.size() >= 4:
			if Vector2(pos.x - float(sp[0]), pos.z - float(sp[2])).length() < float(sp[3]):
				return true
	return false


## Ikki holat orasida yumshoq o'tish (kun → tun).
static func apply_blend(world: Dictionary, a: String, b: String, t: float) -> void:
	if world.is_empty():
		return
	var pa: Dictionary = PRESETS.get(a, PRESETS["day"])
	var pb: Dictionary = PRESETS.get(b, PRESETS["night"])
	var sm: ProceduralSkyMaterial = world["sky_mat"]
	sm.sky_top_color = Color.html(pa["top"]).lerp(Color.html(pb["top"]), t)
	sm.sky_horizon_color = Color.html(pa["horizon"]).lerp(Color.html(pb["horizon"]), t)
	sm.ground_bottom_color = Color.html(pa["ground"]).lerp(Color.html(pb["ground"]), t)
	sm.ground_horizon_color = sm.sky_horizon_color.darkened(0.3)
	var env: Environment = world["env"]
	env.ambient_light_energy = lerp(float(pa["ambient"]), float(pb["ambient"]), t)
	var sun: DirectionalLight3D = world["sun"]
	sun.light_color = Color.html(pa["sun"]).lerp(Color.html(pb["sun"]), t)
	sun.light_energy = lerp(float(pa["energy"]), float(pb["energy"]), t)
	if world.has("ground_mat"):
		var gm: StandardMaterial3D = world["ground_mat"]
		gm.albedo_color = Color.html(pa["grass"]).lerp(Color.html(pb["grass"]), t)
