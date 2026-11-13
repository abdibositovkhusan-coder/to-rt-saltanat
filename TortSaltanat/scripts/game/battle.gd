class_name Battle
extends Node3D
## Bitta jang (missiya) sahnasi: dunyoni quradi, birliklar, binolar va resurs manbalarini joylashtiradi,
## tanlash va buyruqlarni boshqaradi, bino joylash rejimi ("arvoh" bino), dushman AI (iqtisodli yoki
## oddiy to'lqinlar) va g'alaba/mag'lubiyat shartlari.
## Bog'liqlik: Simulation, Unit, Building, ResourceNode, EnemyAI, RtsCamera, TouchController, BattleHud,
## WorldBuilder, GameData.

signal finished(victory: bool)
signal end_choice(choice: String)

const PICK_RADIUS_PX := 46.0

var mission: Dictionary = {}
var sim: Simulation
var cam: RtsCamera
var hud: BattleHud
var controller: TouchController
var ai: EnemyAI = null
var fog: FogOfWar = null
var player_start: Vector3 = Vector3.ZERO
var _fog_acc: float = 0.0
var day_time: float = 60.0
var _forced_night: float = 0.0
var _env_name: String = "day"
var _mist_nodes: Dictionary = {}
const DAY_LEN := 300.0
const NIGHT_LEN := 180.0
var world: Dictionary = {}
var selected: Array = []
var over: bool = false
var player_color: Color = Color(0.2, 0.4, 0.8)
var enemy_color: Color = Color(0.3, 0.6, 0.3)
var neutral_color: Color = Color(0.85, 0.55, 0.25)
var player_faction: Dictionary = {}
var enemy_faction: Dictionary = {}
var has_outro: bool = false

# Bino joylash rejimi
var placing_kind: String = ""
var ghost_pos: Vector3 = Vector3.ZERO
var ghost_valid: bool = false
var _ghost: Node3D = null
var _ghost_mat: StandardMaterial3D = null

var _enemy_attack_timer: float = 25.0
var _enemy_attacked: bool = false
var _wave_timer: float = 0.0
var _idle_worker_index: int = 0
var _rng := RandomNumberGenerator.new()


var stats: Dictionary = {"trained": 0, "lost": 0, "killed": 0, "built": 0, "gold": 0, "time": 0.0}
var _bursts: int = 0
var mission_id: String = ""
var campaign_mode: bool = false
var script: MissionScript = null


func setup(m: Dictionary, state: Dictionary = {}) -> void:
	mission = m
	var loading: bool = not state.is_empty()
	_rng.seed = 77
	has_outro = str(m.get("outro", "")) != "" or (campaign_mode and str(m.get("next", "")) != "")
	var env_name := str(m.get("env", "day"))
	_env_name = env_name
	var spots = m.get("clear_spots", [])
	if not (spots is Array):
		spots = []
	world = WorldBuilder.build_environment(self, env_name)
	WorldBuilder.build_ground(self, world, 120.0, env_name, 7, true, 27.0, spots)

	sim = Simulation.new()
	sim.spawner = self
	add_child(sim)
	sim.unit_died.connect(_on_unit_died)
	sim.message.connect(_on_sim_message)
	sim.building_completed.connect(_on_building_completed)
	sim.unit_trained.connect(_on_unit_trained)

	cam = RtsCamera.new()
	add_child(cam)
	cam.focus(GameData.vec3(m.get("camera_start", null), Vector3.ZERO), true)

	player_faction = GameData.faction_def(str(m.get("player_faction", "odamlar")))
	enemy_faction = GameData.faction_def(str(m.get("enemy_faction", "trollar")))
	player_color = GameData.color(player_faction.get("color", ""), player_color)
	enemy_color = GameData.color(enemy_faction.get("color", ""), enemy_color)
	if str(player_faction.get("id", "")) == str(enemy_faction.get("id", "")):
		enemy_color = Color(0.8, 0.2, 0.2)
	sim.team_faction = {0: str(player_faction.get("id", "odamlar")), 1: str(enemy_faction.get("id", "trollar"))}


	var pr = m.get("resources", {})
	var er = m.get("enemy_resources", pr)
	sim.set_treasury(0, int(pr.get("oltin", 0)), int(pr.get("yogoch", 0)))
	sim.set_treasury(1, int(er.get("oltin", 0)), int(er.get("yogoch", 0)))

	_spawn_resources(m)
	if loading:
		_restore_state(state)
	else:
		_spawn_buildings(m.get("player_buildings", []), 0)
		_spawn_buildings(m.get("enemy_buildings", []), 1)
		_spawn_group(m.get("player_units", []), 0, Vector3(1, 0, -0.6))
		_spawn_group(m.get("enemy_units", []), 1, Vector3(-1, 0, 0.6))
		_spawn_buildings(m.get("neutral_buildings", []), 2)
		_spawn_group(m.get("ally_units", []), 0, Vector3(1, 0, -0.6))
		_spawn_camps(m.get("creep_camps", []))
		if bool(m.get("auto_start", false)):
			_auto_start(m)

	# Tuman urushi
	if bool(m.get("fog", true)):
		fog = FogOfWar.new()
		add_child(fog)
		fog.setup(sim)
		sim.fog = fog
	var pc := Vector3.ZERO
	var pn := 0
	for u in sim.units:
		if u.team == 0:
			pc += u.sim_pos
			pn += 1
	player_start = pc / max(1, pn)
	if loading and fog != null:
		fog.set_explored_b64(str(state.get("fog", "")))
	_refresh_fog()

	var ai_cfg = m.get("ai", null)
	if ai_cfg is Dictionary and bool(ai_cfg.get("economy", false)):
		ai = EnemyAI.new()
		add_child(ai)
		ai.setup(self, sim, 1, ai_cfg, enemy_faction, str(m.get("difficulty", "orta")))
		# Dushman ishchilari darhol ishga tushadi
		for u in sim.units:
			if u.team == 1 and u.is_worker and not loading:
				var g = sim.nearest_resource("gold", u.sim_pos, 40.0)
				if g != null:
					u.order_gather(g.uid)
	hud = BattleHud.new()
	add_child(hud)
	hud.setup(self)

	controller = TouchController.new()
	add_child(controller)
	controller.setup(self, cam, hud)

	Audio.music(str(player_faction.get("id", "odamlar")))
	script = MissionScript.new()
	add_child(script)
	script.setup(self, m, state.get("script", {}) if loading else {})
	if script.objective != str(m.get("objective", "")):
		hud.set_objective(script.objective)

	_enemy_attack_timer = float(m.get("enemy_attack_after", 25))
	if loading:
		_enemy_attack_timer = float(state.get("enemy_attack_timer", _enemy_attack_timer))
		_enemy_attacked = bool(state.get("enemy_attacked", false))
		_wave_timer = float(state.get("wave_timer", 0.0))
		var ct = state.get("camera", null)
		if ct is Array and ct.size() >= 2:
			cam.focus(Vector3(float(ct[0]), 0, float(ct[1])), true)
		if hud:
			hud.say("Xabar", "Saqlangan o'yin yuklandi", 0)


# ---------------- Yaratish (Simulation "spawner" sifatida ham chaqiradi) ----------------

func team_color(team: int) -> Color:
	if team == 0:
		return player_color
	if team == 1:
		return enemy_color
	return neutral_color


func spawn_unit(kind: String, team: int, pos: Vector3):
	var d := GameData.unit_def(kind)
	if d.is_empty():
		return null
	var p := Vector3(pos.x, 0, pos.z)
	if bool(d.get("hero", false)):
		var h := Hero.new()
		add_child(h)
		h.setup_hero(d, team, p, team_color(team))
		sim.register(h)
		h.recompute_stats()
		h.hp = h.max_hp
		h.mana = h.max_mana
		FaceLib.attach_badge(h, kind, h.bar_height)
		if hud and team == 0:
			hud.refresh_hero_bar()
		return h
	var u := Unit.new()
	add_child(u)
	u.setup(d, team, p, team_color(team))
	sim.register(u)
	u.recompute_stats()
	return u


func spawn_building(kind: String, team: int, pos: Vector3, complete: bool):
	var d := GameData.building_def(kind)
	if d.is_empty():
		return null
	var b := Building.new()
	add_child(b)
	b.setup_building(d, team, pos, team_color(team), complete)
	sim.register(b)
	b.recompute_stats()
	return b


## Kichik vizual effektlar: "heal" — yashil shifo nuri, "blast" — portlash.
func spawn_effect(kind: String, pos: Vector3) -> void:
	if kind == "ring" or kind == "ring_dark":
		_ring_effect(pos, Color(1.0, 0.85, 0.3) if kind == "ring" else Color(0.6, 0.3, 0.9))
		return
	if kind == "meteor":
		_meteor_effect(pos)
		Audio.play_at("explosion", pos, sim)
		return
	if kind == "heal":
		Audio.play_at("heal", pos, sim)
	elif kind == "blast":
		burst(pos, Color(1.0, 0.55, 0.2), 14)
	var mi := MeshInstance3D.new()
	var c: Color = Color(0.45, 1.0, 0.5) if kind == "heal" else Color(1.0, 0.6, 0.2)
	mi.mesh = UnitVisual.sphere(0.35 if kind == "heal" else 0.8, 10)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.85)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	if fog != null and not fog.sees(0, pos):
		mi.visible = false
	var tw := mi.create_tween()
	if kind == "heal":
		tw.tween_property(mi, "position:y", pos.y + 1.2, 0.7)
		tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.7)
	else:
		tw.tween_property(mi, "scale", Vector3(2.4, 1.2, 2.4), 0.35)
		tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(mi.queue_free)


func _spawn_group(groups, team: int, face_dir: Vector3) -> void:
	if not (groups is Array):
		return
	for g in groups:
		var count := int(g.get("count", 1))
		var at := GameData.vec3(g.get("at", null), Vector3.ZERO)
		var cols := 4
		for i in count:
			var row := i / cols
			var col := i % cols
			var pos := at + Vector3((col - (cols - 1) * 0.5) * 1.6, 0, row * 1.6)
			var u = spawn_unit(str(g.get("id", "")), team, pos)
			if u == null:
				continue
			u.script_tag = str(g.get("tag", ""))
			apply_spawn_level(u, int(g.get("level", 0)))
			u.facing = atan2(face_dir.x, face_dir.z)
			u.prev_facing = u.facing
			u.rotation.y = u.facing


func _spawn_buildings(list, team: int) -> void:
	if not (list is Array):
		return
	for b in list:
		var bu = spawn_building(str(b.get("id", "")), team, GameData.vec3(b.get("at", null), Vector3.ZERO), bool(b.get("complete", true)))
		if bu != null:
			bu.script_tag = str(b.get("tag", ""))


## Saltanat ma'lumotidan boshlang'ich baza yaratadi (Tezkor jang uchun).
func _auto_start(m: Dictionary) -> void:
	var bases := [GameData.vec3(m.get("player_base", null), Vector3(-36, 0, 34)), GameData.vec3(m.get("enemy_base", null), Vector3(36, 0, -34))]
	var facs := [player_faction, enemy_faction]
	var teams = m.get("auto_start_teams", [0, 1])
	if not (teams is Array):
		teams = [0, 1]
	for tv in teams:
		var team: int = int(tv)
		var base: Vector3 = bases[team]
		var sgn: float = 1.0 if team == 0 else -1.0
		var st: Dictionary = facs[team].get("start", {})
		if st.is_empty():
			continue
		spawn_building(str(st.get("hall", "")), team, base, true)
		spawn_building(str(st.get("food", "")), team, base + Vector3(7, 0, 6) * sgn, true)
		spawn_building(str(st.get("food", "")), team, base + Vector3(3, 0, 8.5) * sgn, true)
		spawn_building(str(st.get("barracks", "")), team, base + Vector3(9, 0, -1) * sgn, true)
		var wk := str(st.get("worker", ""))
		for i in 5:
			spawn_unit(wk, team, base + Vector3(4 + (i % 3) * 1.4, 0, -4 - (i / 3) * 1.4) * sgn)
		var k := 0
		for pair in st.get("army", []):
			for j in int(pair[1]):
				spawn_unit(str(pair[0]), team, base + Vector3(5 + (k % 4) * 1.6, 0, 3 + (k / 4) * 1.6) * sgn)
				k += 1
	# Ishchilarni darhol oltinga yuboramiz (o'yinchi ham, AI ham)
	for u in sim.units:
		if u.is_worker:
			var g = sim.nearest_resource("gold", u.sim_pos, 40.0)
			if g != null:
				u.order_gather(g.uid)


## Kun va tun.
func force_night(duration: float) -> void:
	_forced_night = max(_forced_night, duration)


func _update_day_night(dt: float) -> void:
	day_time = fmod(day_time + dt, DAY_LEN + NIGHT_LEN)
	var night := day_time >= DAY_LEN or _forced_night > 0.0
	_forced_night = max(0.0, _forced_night - dt)
	sim.is_night = night
	# Yumshoq o'tish (20 soniya)
	var t := 0.0
	if _forced_night > 0.0:
		t = 1.0
	elif day_time >= DAY_LEN:
		t = clamp((day_time - DAY_LEN) / 20.0, 0.0, 1.0)
		var left: float = DAY_LEN + NIGHT_LEN - day_time
		t = min(t, clamp(left / 20.0, 0.0, 1.0))
	WorldBuilder.apply_blend(world, _env_name, "night", t)
	if hud:
		var rem: float = (DAY_LEN - day_time) if not night else (DAY_LEN + NIGHT_LEN - day_time)
		hud.set_daynight("Tun" if night else "Kun", int(rem))


func _update_mist_visuals() -> void:
	for u in sim.units:
		if not u.alive or not u.is_building():
			continue
		var r: float = sim.mist_radius(u)
		if r <= 0.0 or _mist_nodes.has(u.uid):
			continue
		var p := CPUParticles3D.new()
		p.amount = 28
		p.lifetime = 5.0
		p.preprocess = 5.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = r * 0.8
		p.direction = Vector3(0, 1, 0)
		p.spread = 30.0
		p.initial_velocity_min = 0.05
		p.initial_velocity_max = 0.2
		p.gravity = Vector3.ZERO
		p.scale_amount_min = 2.0
		p.scale_amount_max = 4.0
		p.mesh = UnitVisual.sphere(0.5, 6)
		p.material_override = UnitVisual.mat(Color(0.35, 0.15, 0.45, 0.16), 0.3, true, true)
		p.position = Vector3(u.sim_pos.x, 0.3, u.sim_pos.z)
		add_child(p)
		_mist_nodes[u.uid] = p
	for id in _mist_nodes.keys():
		if sim.get_unit(int(id)) == null:
			var n = _mist_nodes[id]
			if is_instance_valid(n):
				n.queue_free()
			_mist_nodes.erase(id)


func _spawn_camps(camps) -> void:
	if not (camps is Array):
		return
	var cid := 0
	for c in camps:
		cid += 1
		var at := GameData.vec3(c.get("at", null), Vector3.ZERO)
		sim.camps[cid] = str(c.get("drop", "oddiy"))
		var idx := 0
		for g in c.get("units", []):
			for i in int(g.get("count", 1)):
				var a := TAU * idx / 5.0
				var u = spawn_unit(str(g.get("id", "")), 2, at + Vector3(cos(a) * 1.6, 0, sin(a) * 1.6) * (0.0 if idx == 0 else 1.0))
				idx += 1
				if u != null:
					u.camp_id = cid
					u.home_pos = u.sim_pos
					u.facing = _rng.randf() * TAU
					u.prev_facing = u.facing


func spawn_drop(item_id: String, pos: Vector3) -> void:
	var d := ItemDrop.new()
	add_child(d)
	d.setup(item_id, pos)
	sim.drops.append(d)
	if hud:
		hud.say("Xabar", "Lagerdan narsa tushdi: " + str(GameData.item_def(item_id).get("name", "")), 0)


func spawn_text(pos: Vector3, text: String, c: Color, team: int = 0) -> void:
	if team != 0:
		return
	var l := Label3D.new()
	l.text = text
	l.modulate = c
	l.outline_modulate = Color(0, 0, 0, 1)
	l.font_size = 48
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", pos.y + 1.5, 1.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func _spawn_resources(m: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var nodes = m.get("resource_nodes", [])
	if nodes is Array:
		for r in nodes:
			var n := ResourceNode.new()
			add_child(n)
			n.setup(str(r.get("kind", "gold")), GameData.vec3(r.get("at", null), Vector3.ZERO), int(r.get("amount", 10000)), rng)
			sim.register_resource(n)
	var forests = m.get("forests", [])
	if forests is Array:
		for f in forests:
			var c := GameData.vec3(f.get("at", null), Vector3.ZERO)
			var rad := float(f.get("radius", 5.0))
			var count := int(f.get("count", 20))
			var placed: Array = []
			var tries := 0
			while placed.size() < count and tries < count * 30:
				tries += 1
				var a := rng.randf() * TAU
				var rr := sqrt(rng.randf()) * rad
				var p := c + Vector3(cos(a) * rr, 0, sin(a) * rr)
				var ok := true
				for q in placed:
					if p.distance_to(q) < 1.25:
						ok = false
						break
				if not ok:
					continue
				placed.append(p)
				var t := ResourceNode.new()
				add_child(t)
				t.setup("wood", p, int(f.get("amount", 60)), rng)
				sim.register_resource(t)


# ---------------- Har kadr ----------------

func _refresh_fog() -> void:
	if fog == null:
		return
	fog.refresh(0.2)
	for u in sim.units:
		if u.team == 0:
			continue
		var vis: bool = fog.sees(0, u.sim_pos) and not (u.has_effect("invis") and not _near_player(u))
		u.fog_visible = vis
		if u.is_building():
			if vis:
				u.seen_by_enemy = true
			u.visible = u.seen_by_enemy
		else:
			u.visible = vis
	for n in sim.res_nodes:
		n.visible = fog.is_explored(0, n.sim_pos)
	for p in sim.projectiles:
		p.visible = fog.sees(0, p.sim_pos)


func _near_player(u) -> bool:
	for o in sim.units:
		if o.alive and o.team == 0 and o.sim_pos.distance_to(u.sim_pos) <= 1.6:
			return true
	return false


func is_seen(u) -> bool:
	if fog == null or u.team == 0:
		return true
	return u.fog_visible


func _process(delta: float) -> void:
	if sim != null and not sim.paused:
		_fog_acc += delta * sim.speed
		if _fog_acc >= 0.2:
			_update_day_night(_fog_acc)
			_fog_acc = 0.0
			_refresh_fog()
			_update_mist_visuals()
	if over or sim == null or sim.paused:
		return
	stats["time"] = float(stats["time"]) + delta * sim.speed
	if script != null:
		script.step(delta * sim.speed)
		if over:
			return
	if not bool(mission.get("auto_waves", true)):
		return
	if ai != null:
		var left := ai.seconds_to_wave()
		if hud:
			hud.set_timer_text("Birinchi hujumgacha: %d:%02d" % [int(left) / 60, int(left) % 60] if left > 0.0 else "")
		return
	var dt := delta * sim.speed
	if not _enemy_attacked:
		_enemy_attack_timer -= dt
		if hud:
			hud.set_timer_text("Dushman hujumigacha: %d s" % int(ceil(max(_enemy_attack_timer, 0.0))))
		if _enemy_attack_timer <= 0.0:
			_enemy_attacked = true
			if hud:
				hud.set_timer_text("")
				hud.say("Trollar sardori", "Hujumga! Vodiyning oltinlari bizniki!", 1)
			_enemy_wave()
			_wave_timer = 12.0
	else:
		_wave_timer -= dt
		if _wave_timer <= 0.0:
			_wave_timer = 12.0
			_enemy_wave()


func _enemy_wave() -> void:
	var center := Vector3.ZERO
	var n := 0
	for u in sim.units:
		if u.alive and u.team == 0:
			center += u.sim_pos
			n += 1
	if n == 0:
		return
	center /= n
	var ids: Array = []
	for u in sim.units:
		if u.alive and u.team == 1 and u.state == Unit.State.IDLE and not u.is_building():
			ids.append(u.uid)
	if ids.size() > 0:
		sim.push(GameCommand.make(GameCommand.Type.ATTACK_MOVE, ids, center, -1, "", 1))


func on_enemy_wave(n: int) -> void:
	Audio.play("horn", -3.0)
	if hud:
		var lines := ["Hujumga! Odamlar qishlog'ini tekislang!", "Yana boramiz! Ezib tashlang!", "Devlar keldi! Hech kim qolmasin!"]
		hud.say("Trollar sardori", lines[(n - 1) % lines.size()], 1)


func _ring_effect(pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.1
	tm.rings = 24
	tm.ring_segments = 4
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = Vector3(pos.x, 0.15, pos.z)
	mi.scale = Vector3(0.5, 0.3, 0.5)
	add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(6.0, 0.3, 6.0), 0.6)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.6)
	tw.tween_callback(mi.queue_free)


func _meteor_effect(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = UnitVisual.sphere(0.7, 10)
	mi.material_override = UnitVisual.mat(Color(1.0, 0.5, 0.15), 3.0, true)
	mi.position = pos + Vector3(-6, 18, -6)
	add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.2)
	l.light_energy = 3.0
	l.omni_range = 8.0
	mi.add_child(l)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", pos + Vector3(0, 0.5, 0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	cam.shake(0.0)


# ---------------- Tanlash ----------------

func select(list: Array) -> void:
	for u in selected:
		if is_instance_valid(u):
			u.set_selected(false)
	selected = []
	var units_only: Array = []
	var buildings: Array = []
	for u in list:
		if not is_instance_valid(u) or not u.alive:
			continue
		if u.team == 0:
			if u.is_building():
				buildings.append(u)
			else:
				units_only.append(u)
		elif u.is_building() and u.invulnerable and list.size() == 1:
			buildings.append(u)
	# Birliklar bo'lsa — faqat ular; aks holda bitta bino
	if not units_only.is_empty():
		selected = units_only
	elif not buildings.is_empty():
		selected = [buildings[0]]
	if not selected.is_empty():
		Audio.play("select", -5.0)
	for u in selected:
		u.set_selected(true)
	if controller:
		controller.set_attack_mode(false)
		controller.cast_index = -1
	if hud:
		hud.close_build_menu()
		hud.update_selection(selected)
	if selected.size() > 0 and not selected[0].is_building():
		var first = selected[0]
		hud.say(first.display_name, first.voice("select"), 0)


func select_all_army() -> void:
	var list: Array = []
	for u in sim.units:
		if u.alive and u.team == 0 and not u.is_building() and not u.is_worker:
			list.append(u)
	select(list)


func select_idle_worker() -> void:
	var idle: Array = []
	for u in sim.units:
		if u.alive and u.team == 0 and u.is_worker and u.state == Unit.State.IDLE:
			idle.append(u)
	if idle.is_empty():
		hud.say("Maslahat", "Bo'sh ishchi yo'q — hammasi ishda!", 0)
		return
	_idle_worker_index = (_idle_worker_index + 1) % idle.size()
	var w = idle[_idle_worker_index]
	select([w])
	cam.focus(w.sim_pos)


func selected_building():
	if selected.size() == 1 and is_instance_valid(selected[0]) and selected[0].is_building() and selected[0].team == 0:
		return selected[0]
	return null


func selected_neutral():
	if selected.size() == 1 and is_instance_valid(selected[0]) and selected[0].is_building() and selected[0].invulnerable:
		return selected[0]
	return null


func selected_hero():
	if selected.size() == 1 and is_instance_valid(selected[0]) and selected[0].alive and selected[0].is_hero() and selected[0].team == 0:
		return selected[0]
	return null


func player_heroes() -> Array:
	return sim.heroes_of(0) if sim else []


func select_hero(h) -> void:
	if h == null or not is_instance_valid(h) or not h.alive:
		return
	select([h])
	cam.focus(h.sim_pos)


func selection_workers() -> Array:
	var out: Array = []
	for u in selected:
		if is_instance_valid(u) and u.alive and not u.is_building() and u.is_worker:
			out.append(u)
	return out


func screen_pos_of(u) -> Variant:
	var wp: Vector3 = u.global_position + Vector3(0, u.pick_height, 0)
	if cam.cam.is_position_behind(wp):
		return null
	return cam.cam.unproject_position(wp)


func _screen_radius(pos: Vector3, r: float) -> float:
	var a: Vector3 = pos + Vector3(0, 0.5, 0)
	var b: Vector3 = a + cam.cam.global_transform.basis.x * r
	if cam.cam.is_position_behind(a) or cam.cam.is_position_behind(b):
		return 0.0
	return cam.cam.unproject_position(a).distance_to(cam.cam.unproject_position(b))


func pick_unit(screen: Vector2):
	var best = null
	var best_score := 1.0
	for u in sim.units:
		if not u.alive or not u.visible:
			continue
		var sp = screen_pos_of(u)
		if sp == null:
			continue
		var spv: Vector2 = sp
		var thr: float = PICK_RADIUS_PX
		if u.is_building():
			spv = cam.cam.unproject_position(u.global_position + Vector3(0, 1.0, 0))
			thr = max(PICK_RADIUS_PX, _screen_radius(u.sim_pos, u.radius) * 1.1)
		var score: float = spv.distance_to(screen) / thr
		if u.is_building():
			score += 0.25
		if score < best_score:
			best_score = score
			best = u
	return best


func pick_resource(screen: Vector2):
	var g = cam.ground_point(screen)
	if g == null:
		return null
	var gp: Vector3 = g
	var best = null
	var best_d := INF
	for n in sim.res_nodes:
		if not n.alive or not n.visible:
			continue
		var d: float = Vector2(gp.x - n.sim_pos.x, gp.z - n.sim_pos.z).length()
		var reach: float = n.radius + (1.2 if n.kind == "wood" else 0.8)
		if d < reach and d < best_d:
			best_d = d
			best = n
	return best


func select_in_rect(r: Rect2) -> void:
	var list: Array = []
	for u in sim.units:
		if not u.alive or u.team != 0:
			continue
		var sp = screen_pos_of(u)
		if sp != null and r.has_point(sp):
			list.append(u)
	select(list)


func select_same_type_on_screen(ref) -> void:
	var view := get_viewport().get_visible_rect()
	var list: Array = []
	for u in sim.units:
		if not u.alive or u.team != 0 or u.unit_id != ref.unit_id:
			continue
		var sp = screen_pos_of(u)
		if sp != null and view.has_point(sp):
			list.append(u)
	select(list)


# ---------------- Buyruqlar ----------------

func _ids() -> Array:
	var ids: Array = []
	for u in selected:
		if is_instance_valid(u) and u.alive and not u.is_building():
			ids.append(u.uid)
	return ids


func _voice_sfx() -> void:
	Audio.play("order", -5.0)


func _voice(kind: String) -> void:
	if not selected.is_empty():
		_voice_sfx()
	if selected.size() > 0 and hud:
		var u = selected[randi() % selected.size()]
		if u.is_building():
			return
		var line: String = u.voice(kind)
		if line == "" and kind == "work":
			line = u.voice("move")
		hud.say(u.display_name, line, 0)


func command_move(pos: Vector3) -> void:
	var b = selected_building()
	if b != null:
		command_rally(pos)
		return
	var ids := _ids()
	if ids.is_empty():
		return
	sim.push(GameCommand.make(GameCommand.Type.MOVE, ids, pos))
	spawn_marker(pos, Color(0.4, 1.0, 0.4))
	_voice("move")


func command_attack_move(pos: Vector3) -> void:
	var ids := _ids()
	if ids.is_empty():
		return
	sim.push(GameCommand.make(GameCommand.Type.ATTACK_MOVE, ids, pos))
	spawn_marker(pos, Color(1.0, 0.45, 0.2))
	_voice("attack")


func command_attack(target) -> void:
	var ids := _ids()
	if ids.is_empty() or target == null:
		return
	sim.push(GameCommand.make(GameCommand.Type.ATTACK, ids, target.sim_pos, target.uid))
	spawn_marker(target.sim_pos, Color(1.0, 0.2, 0.2))
	_voice("attack")


func command_stop() -> void:
	var ids := _ids()
	if not ids.is_empty():
		sim.push(GameCommand.make(GameCommand.Type.STOP, ids))


func command_hold() -> void:
	var ids := _ids()
	if not ids.is_empty():
		sim.push(GameCommand.make(GameCommand.Type.HOLD, ids))
		_voice("move")


func command_gather(node) -> void:
	var ids := _ids()
	if ids.is_empty() or node == null:
		return
	sim.push(GameCommand.make(GameCommand.Type.GATHER, ids, node.sim_pos, node.uid))
	spawn_marker(node.sim_pos, Color(1.0, 0.85, 0.3))
	_voice("work")


func command_help_build(b) -> void:
	var w := selection_workers()
	if w.is_empty() or b == null:
		return
	var ids: Array = []
	for u in w:
		ids.append(u.uid)
	sim.push(GameCommand.make(GameCommand.Type.HELP_BUILD, ids, b.sim_pos, b.uid))
	_voice("work")


func command_train(kind: String) -> void:
	var b = selected_building()
	if b == null:
		return
	sim.push(GameCommand.make(GameCommand.Type.TRAIN, [], Vector3.ZERO, b.uid, kind, 0))


func command_cancel_train() -> void:
	var b = selected_building()
	if b == null:
		return
	sim.push(GameCommand.make(GameCommand.Type.CANCEL_TRAIN, [], Vector3.ZERO, b.uid, "", 0))


func command_research(id: String) -> void:
	var b = selected_building()
	if b == null:
		return
	sim.push(GameCommand.make(GameCommand.Type.RESEARCH, [], Vector3.ZERO, b.uid, id, 0))


func command_upgrade_building() -> void:
	var b = selected_building()
	if b == null:
		return
	sim.push(GameCommand.make(GameCommand.Type.UPGRADE_BUILDING, [], Vector3.ZERO, b.uid, "", 0))


# ---------------- Qahramon buyruqlari ----------------

func command_cast(index: int, target_id: int, pos: Vector3) -> void:
	var h = selected_hero()
	if h == null:
		return
	var err: String = h.can_cast(index)
	if err != "":
		hud.say(h.display_name, err, 0)
		return
	sim.push(GameCommand.make(GameCommand.Type.CAST, [h.uid], pos, target_id, str(index), 0))
	_voice("attack")


func command_learn(index: int) -> void:
	var h = selected_hero()
	if h == null:
		return
	var err: String = h.can_learn(index)
	if err != "":
		hud.say(h.display_name, err, 0)
		return
	sim.push(GameCommand.make(GameCommand.Type.LEARN, [h.uid], Vector3.ZERO, -1, str(index), 0))


func command_use_item(slot: int) -> void:
	var h = selected_hero()
	if h == null:
		return
	var it = h.inventory[slot]
	if it == null:
		return
	var d := GameData.item_def(str(it["id"]))
	if not bool(d.get("consumable", false)):
		hud.say(str(d.get("name", "")), str(d.get("desc", "")), 0)
		return
	sim.push(GameCommand.make(GameCommand.Type.USE_ITEM, [h.uid], Vector3.ZERO, slot, "", 0))


func command_buy(item_id: String) -> void:
	var shop = selected_neutral()
	if shop == null:
		return
	var best = null
	var best_d := INF
	for h in player_heroes():
		var d: float = h.sim_pos.distance_to(shop.sim_pos)
		if d < best_d:
			best_d = d
			best = h
	if best == null or best_d > shop.radius + 9.0:
		hud.say("Karvonsaroy", "Qahramoningizni do'kon yoniga olib keling", 0)
		return
	sim.push(GameCommand.make(GameCommand.Type.BUY_ITEM, [best.uid], Vector3.ZERO, shop.uid, item_id, 0))


func command_hire(hero_id: String) -> void:
	var tav = selected_neutral()
	if tav == null:
		return
	sim.push(GameCommand.make(GameCommand.Type.HIRE, [], Vector3.ZERO, tav.uid, hero_id, 0))


func command_rally(pos: Vector3) -> void:
	var b = selected_building()
	if b == null:
		return
	sim.push(GameCommand.make(GameCommand.Type.RALLY, [], pos, b.uid, "", 0))
	spawn_marker(pos, Color(1.0, 1.0, 0.4))
	hud.say(b.display_name, "To'plash nuqtasi belgilandi", 0)


# ---------------- Bino joylash ----------------

func begin_placement(kind: String) -> void:
	var bd := GameData.building_def(kind)
	if bd.is_empty():
		return
	var req_err: String = sim.meets(0, bd.get("requires", {}))
	if req_err != "":
		hud.say("Maslahat", req_err, 0)
		return
	if not sim.can_afford(0, bd.get("cost", {})):
		hud.say("Maslahat", sim.lack_text(0, bd.get("cost", {})), 0)
		return
	cancel_placement()
	placing_kind = kind
	_ghost = Node3D.new()
	add_child(_ghost)
	var r := float(bd.get("radius", 2.0))
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = Color(0.3, 1.0, 0.3, 0.35)
	var base := MeshInstance3D.new()
	base.mesh = UnitVisual.cone(r, 0.08, r, 24)
	base.material_override = _ghost_mat
	base.position = Vector3(0, 0.05, 0)
	_ghost.add_child(base)
	var body := MeshInstance3D.new()
	body.mesh = UnitVisual.box(Vector3(r * 1.5, 1.6, r * 1.5))
	body.material_override = _ghost_mat
	body.position = Vector3(0, 0.8, 0)
	_ghost.add_child(body)
	# Kamera markaziga yaqin joydan boshlaymiz
	move_ghost(cam.target)
	hud.refresh_commands()
	hud.say("Maslahat", "Xaritaga bosib joyni tanlang, keyin «Joylash»", 0)


func move_ghost(pos: Vector3) -> void:
	if _ghost == null:
		return
	ghost_pos = Vector3(snapped(pos.x, 0.5), 0, snapped(pos.z, 0.5))
	_ghost.position = ghost_pos
	ghost_valid = sim.can_place_team(0, GameData.building_def(placing_kind), ghost_pos)
	if _ghost_mat:
		_ghost_mat.albedo_color = Color(0.3, 1.0, 0.3, 0.35) if ghost_valid else Color(1.0, 0.25, 0.2, 0.4)


func confirm_placement() -> void:
	if placing_kind == "":
		return
	if not ghost_valid:
		hud.say("Maslahat", "Bu yerga qurib bo'lmaydi — boshqa joy tanlang", 0)
		return
	var w := selection_workers()
	if w.is_empty():
		hud.say("Maslahat", "Qurish uchun ishchi tanlang", 0)
		cancel_placement()
		return
	var ids: Array = []
	for u in w:
		ids.append(u.uid)
	sim.push(GameCommand.make(GameCommand.Type.BUILD, ids, ghost_pos, -1, placing_kind, 0))
	spawn_marker(ghost_pos, Color(1.0, 0.85, 0.3))
	_voice("work")
	cancel_placement()


func cancel_placement() -> void:
	placing_kind = ""
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_mat = null
	if hud:
		hud.refresh_commands()


func is_placing() -> bool:
	return placing_kind != ""


func spawn_marker(pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 0.9
	tm.rings = 20
	tm.ring_segments = 4
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = Vector3(pos.x, 0.06, pos.z)
	mi.scale = Vector3(1.2, 0.3, 1.2)
	add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.3, 0.3, 0.3), 0.5)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(mi.queue_free)


# ---------------- Hodisalar ----------------

## Uchqunlar to'plami (o'lim, qurilish, zarba). Telefon uchun bir vaqtda 12 tadan oshmaydi.
func burst(pos: Vector3, c: Color, amount: int = 10) -> void:
	if _bursts >= 12 or Settings.quality == "past":
		return
	_bursts += 1
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.mesh = UnitVisual.sphere(0.07, 4)
	p.material_override = UnitVisual.mat(c, 1.2, true)
	p.position = pos
	add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(_burst_done.bind(p))


func _burst_done(p: Node) -> void:
	_bursts = maxi(0, _bursts - 1)
	if is_instance_valid(p):
		p.queue_free()


func _on_sim_message(team, text) -> void:
	if team == 0 and str(text).begins_with("Karvon"):
		Audio.play("coin")
	if team == 0 and hud and str(text) != "":
		hud.say("Xabar", str(text), 0)


func _on_building_completed(b) -> void:
	if b.team == 0:
		stats["built"] = int(stats["built"]) + 1
		burst(b.sim_pos + Vector3(0, 0.5, 0), Color(1.0, 0.85, 0.4), 16)
		Audio.play("done", -3.0)
	if b.team == 0 and hud:
		hud.say(b.display_name, "Qurilish tugadi!", 0)
		hud.refresh_commands()
		hud.update_selection(selected)


func _on_unit_trained(u, _b) -> void:
	if u.team == 0:
		stats["trained"] = int(stats["trained"]) + 1
	if u.team == 0 and hud:
		hud.say(u.display_name, u.voice("select"), 0)


func _on_unit_died(u) -> void:
	if not over:
		if u.team == 0:
			stats["lost"] = int(stats["lost"]) + 1
		elif u.team == 1:
			stats["killed"] = int(stats["killed"]) + 1
	if fog == null or fog.sees(0, u.sim_pos):
		burst(u.sim_pos + Vector3(0, 0.8, 0), Color(0.85, 0.8, 0.7) if not u.is_building() else Color(0.5, 0.45, 0.4), 18 if u.is_building() else 10)
	if selected.has(u):
		selected.erase(u)
		if hud:
			hud.update_selection(selected)
	if over:
		return
	if sim.count_team(0) == 0:
		_end(false)
	elif sim.count_team(1) == 0 and (script == null or script.victory_type() == "destroy_all"):
		_end(true)


## Missiya skripti g'alaba yoki mag'lubiyat e'lon qiladi.
func script_end(victory: bool) -> void:
	if over:
		return
	_end(victory)


## Qahramonni boshlang'ich darajaga ko'taradi (missiya ma'lumotidagi "level").
func apply_spawn_level(u, lvl: int) -> void:
	if lvl <= 1 or u == null or not u.is_hero():
		return
	var need: int = int(GameData.XP_TABLE[mini(lvl, GameData.XP_TABLE.size() - 1)])
	u.add_xp(need - int(u.xp))
	u.hp = u.max_hp
	u.mana = u.max_mana
	if u.team != 0:
		u.ai_learn()


func _end(victory: bool) -> void:
	over = true
	Audio.play("victory" if victory else "defeat")
	cancel_placement()
	finished.emit(victory)
	if hud:
		hud.show_end(victory, has_outro)


func choose_end(choice: String) -> void:
	end_choice.emit(choice)


# ---------------- Saqlash va yuklash ----------------

func save_game() -> bool:
	if over:
		return false
	return SaveSystem.write_save(save_state())


static func _v2(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.z, 0.01)]


static func _from_v2(a, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and a.size() >= 2:
		return Vector3(float(a[0]), 0, float(a[1]))
	return fallback


## Jangning to'liq holatini lug'atga yig'adi (JSON uchun).
func save_state() -> Dictionary:
	var st := {}
	st["mission_id"] = mission_id
	st["campaign"] = campaign_mode
	var ov := {}
	for k in ["player_faction", "enemy_faction", "env", "difficulty", "auto_start", "title", "outro", "choice_tag"]:
		if mission.has(k):
			ov[k] = mission[k]
	st["overrides"] = ov
	st["tick"] = sim.tick
	st["day_time"] = day_time
	st["treasury"] = {"0": [sim.gold(0), sim.wood(0)], "1": [sim.gold(1), sim.wood(1)]}
	st["upgrades"] = {"0": sim.upgrades.get(0, {}), "1": sim.upgrades.get(1, {})}
	st["dead_heroes"] = {"0": sim.dead_heroes.get(0, []), "1": sim.dead_heroes.get(1, [])}
	var camps := {}
	for k in sim.camps.keys():
		camps[str(k)] = sim.camps[k]
	st["camps"] = camps
	st["enemy_attack_timer"] = _enemy_attack_timer
	st["enemy_attacked"] = _enemy_attacked
	st["wave_timer"] = _wave_timer
	st["camera"] = _v2(cam.target)
	var res_list: Array = []
	for n in sim.res_nodes:
		if n.alive:
			res_list.append([n.kind, _v2(n.sim_pos), n.amount])
	st["resources"] = res_list
	var units: Array = []
	var buildings: Array = []
	for u in sim.units:
		if not u.alive:
			continue
		if u.is_building():
			buildings.append(_save_building(u))
		else:
			units.append(_save_unit(u))
	st["units"] = units
	st["buildings"] = buildings
	var drops: Array = []
	for d in sim.drops:
		if is_instance_valid(d) and d is ItemDrop:
			drops.append([str(d.item_id), _v2(d.sim_pos)])
	st["drops"] = drops
	if fog != null:
		st["fog"] = fog.explored_b64()
	if script != null:
		st["script"] = script.save_state()
	return st


func _save_unit(u) -> Dictionary:
	var e := {"k": u.unit_id, "t": u.team, "p": _v2(u.sim_pos), "hp": snappedf(u.hp, 0.1), "f": snappedf(u.facing, 0.01)}
	if u.camp_id >= 0:
		e["camp"] = u.camp_id
		e["home"] = _v2(u.home_pos)
	if u.life_timer > 0.0:
		e["life"] = u.life_timer
	if u.script_tag != "":
		e["tag"] = u.script_tag
	if u.is_worker:
		e["work"] = u.gather_kind if (u.state == Unit.State.GATHER or u.state == Unit.State.RETURN) else ""
		e["carry"] = [u.carry_kind, u.carry_amount]
	if u.is_hero():
		e["hero"] = u.snapshot()
		e["mana"] = snappedf(u.mana, 0.1)
	return e


func _save_building(b) -> Dictionary:
	var e := {"k": b.unit_id, "t": b.team, "p": _v2(b.sim_pos), "hp": snappedf(b.hp, 0.1),
		"done": b.complete, "prog": snappedf(b.progress, 0.001), "tag": b.script_tag}
	if not b.queue.is_empty():
		e["queue"] = b.queue.duplicate(true)
		e["tp"] = b.train_progress
	if b.has_rally:
		e["rally"] = _v2(b.rally)
	return e


func _restore_state(st: Dictionary) -> void:
	sim.tick = int(st.get("tick", 0))
	day_time = float(st.get("day_time", 60.0))
	var treas = st.get("treasury", {})
	for key in ["0", "1"]:
		var arr = treas.get(key, null)
		if arr is Array and arr.size() >= 2:
			sim.set_treasury(int(key), int(arr[0]), int(arr[1]))
	var ups = st.get("upgrades", {})
	var dh = st.get("dead_heroes", {})
	for key in ["0", "1"]:
		var team: int = int(key)
		var u_team = ups.get(key, {})
		var fixed := {}
		if u_team is Dictionary:
			for rid in u_team.keys():
				fixed[str(rid)] = int(u_team[rid])
		sim.upgrades[team] = fixed
		var d_team = dh.get(key, [])
		sim.dead_heroes[team] = d_team if d_team is Array else []
	var camps = st.get("camps", {})
	if camps is Dictionary:
		for k in camps.keys():
			sim.camps[int(k)] = str(camps[k])
	# Resurslar: saqlangan miqdorni eng yaqin manbaga beramiz, qolganlari tugagan
	var saved: Array = st.get("resources", [])
	var used := {}
	for n in sim.res_nodes:
		var best := -1
		var best_d := 1.5
		for i in saved.size():
			if used.has(i):
				continue
			var r = saved[i]
			if str(r[0]) != n.kind:
				continue
			var dd: float = _from_v2(r[1]).distance_to(Vector3(n.sim_pos.x, 0, n.sim_pos.z))
			if dd < best_d:
				best_d = dd
				best = i
		if best >= 0:
			used[best] = true
			n.amount = int(saved[best][2])
		else:
			n.take(n.amount)
	for e in st.get("buildings", []):
		_load_building(e)
	for e in st.get("units", []):
		_load_unit(e)
	for d in st.get("drops", []):
		if d is Array and d.size() >= 2:
			spawn_drop(str(d[0]), _from_v2(d[1]))


func _load_building(e: Dictionary) -> void:
	var b = spawn_building(str(e.get("k", "")), int(e.get("t", 0)), _from_v2(e.get("p", null)), bool(e.get("done", true)))
	if b == null:
		return
	b.hp = clampf(float(e.get("hp", b.max_hp)), 1.0, b.max_hp)
	b.script_tag = str(e.get("tag", ""))
	if not b.complete:
		b.progress = float(e.get("prog", 0.0))
		if b.visual != null:
			b.visual.set_progress(b.progress)
	var q = e.get("queue", null)
	if q is Array:
		b.queue = q
		b.train_progress = float(e.get("tp", 0.0))
	if e.has("rally"):
		b.rally = _from_v2(e["rally"])
		b.has_rally = true


func _load_unit(e: Dictionary) -> void:
	var u = spawn_unit(str(e.get("k", "")), int(e.get("t", 0)), _from_v2(e.get("p", null)))
	if u == null:
		return
	if e.has("hero"):
		u.restore(e["hero"])
		u.mana = clampf(float(e.get("mana", u.max_mana)), 0.0, u.max_mana)
		if hud and u.team == 0:
			hud.refresh_hero_bar()
	u.hp = clampf(float(e.get("hp", u.max_hp)), 1.0, u.max_hp)
	u.facing = float(e.get("f", 0.0))
	u.prev_facing = u.facing
	u.rotation.y = u.facing
	if e.has("camp"):
		u.camp_id = int(e["camp"])
		u.home_pos = _from_v2(e.get("home", null), u.sim_pos)
	if e.has("life"):
		u.life_timer = float(e["life"])
	u.script_tag = str(e.get("tag", ""))
	if u.is_worker:
		var c = e.get("carry", null)
		if c is Array and c.size() >= 2:
			u.carry_kind = str(c[0])
			u.carry_amount = int(c[1])
			u.visual.set_carry(u.carry_kind if u.carry_amount > 0 else "")
		var work: String = str(e.get("work", ""))
		if work != "":
			var g = sim.nearest_resource(work, u.sim_pos, 40.0)
			if g != null:
				u.order_gather(g.uid)
