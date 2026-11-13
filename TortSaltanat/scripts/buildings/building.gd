class_name Building
extends Unit
## Bino: qurilish jarayoni (ishchilar construct() chaqiradi), birlik o'rgatish navbati (maks. 5),
## to'plash nuqtasi (rally), resurs topshirish joyi (bosh bino) va oziq berish.
## Unit'dan meros oladi — shuning uchun tanlanadi, hujumga uchraydi, sog'liq chizig'i bor, buziladi.
## Bog'liqlik: Unit, BuildingVisual, Simulation (resurs/oziq, yangi birlik yaratish).

const MAX_QUEUE := 5

var bdef: Dictionary = {}
var complete: bool = true
var progress: float = 1.0
var build_time: float = 30.0
var food_provided: int = 0
var trains: Array = []
var queue: Array = []
var train_progress: float = 0.0
var rally: Vector3 = Vector3.ZERO
var has_rally: bool = false
var dropoff: bool = false
var food_blocked: bool = false
var has_attack: bool = false


func setup_building(d: Dictionary, team_id: int, pos: Vector3, team_color: Color, is_complete: bool) -> void:
	bdef = d
	def = d
	team = team_id
	unit_id = str(d.get("id", "bino"))
	display_name = str(d.get("name", unit_id))
	role = str(d.get("role", ""))
	max_hp = float(d.get("hp", 1000))
	armor = float(d.get("armor", 5))
	armor_type = "mustahkam"
	radius = float(d.get("radius", 2.0))
	bar_height = float(d.get("bar_height", 4.0))
	build_time = max(1.0, float(d.get("build_time", 30)))
	food_provided = int(d.get("food", 0))
	dropoff = bool(d.get("dropoff", false))
	invulnerable = bool(d.get("neutral", false))
	var tr = d.get("trains", [])
	if tr is Array:
		trains = tr
	move_speed = 0.0
	acquire_range = 0.0
	damage_min = 0
	damage_max = 0
	attack_range = 0.0
	sight = float(d.get("sight", 9))
	var atk = d.get("attack", null)
	if atk is Dictionary:
		has_attack = true
		var dmg = atk.get("damage", [10, 12])
		damage_min = int(dmg[0])
		damage_max = int(dmg[1])
		attack_type = str(atk.get("attack_type", "teshuvchi"))
		attack_range = float(atk.get("range", 9.0))
		attack_cooldown = float(atk.get("cooldown", 1.2))
		fire_height = float(atk.get("fire_height", 4.0))
		var pd = atk.get("projectile", {})
		if pd is Dictionary:
			projectile_def = pd
	sim_pos = Vector3(pos.x, 0, pos.z)
	prev_pos = sim_pos
	position = sim_pos
	var bv := BuildingVisual.new()
	visual = bv
	add_child(bv)
	bv.build_building(str(d.get("style", "")), team_color, team_id, radius, str(d.get("model", "")), float(d.get("model_scale", 1.0)), float(d.get("model_yaw", 0.0)), str(d.get("tint", "")))
	if bool(d.get("troll_decor", false)):
		bv.add_troll_decor(radius)
	complete = is_complete
	if complete:
		progress = 1.0
		hp = max_hp
	else:
		progress = 0.0
		hp = max_hp * 0.1
	bv.set_progress(progress)
	bv.team_color = team_color
	tier = int(d.get("tier", 0))
	tags = ["building"]
	var dt = d.get("tags", [])
	if dt is Array:
		tags.append_array(dt)
	pick_height = 1.0
	capture_base()
	if sim != null:
		recompute_stats()


func is_holding() -> bool:
	return true


func is_building() -> bool:
	return true


func order_move(_pos: Vector3, _attack_move: bool) -> void:
	pass


func order_attack(_id: int) -> void:
	pass


func order_hold() -> void:
	pass


func set_rally(pos: Vector3) -> void:
	rally = pos
	has_rally = true


## Ishchi har tick'da chaqiradi.
func construct(dt: float) -> void:
	if complete or not alive:
		return
	var step: float = dt / build_time
	progress = min(1.0, progress + step)
	hp = min(max_hp, hp + max_hp * 0.9 * step)
	if visual:
		(visual as BuildingVisual).set_progress(progress)
	if progress >= 1.0:
		complete = true
		if sim:
			sim.on_building_complete(self)


const MAX_HEROES := 3


func can_train(kind: String) -> bool:
	if not complete:
		return false
	if trains.has(kind):
		return true
	# Bosh bino o'z saltanati qahramonlarini chaqiradi
	if dropoff and GameData.is_hero(kind):
		return str(GameData.unit_def(kind).get("faction", "")) == str(bdef.get("faction", ""))
	return false


func has_revive_queued(id: String) -> bool:
	for it in queue:
		if str(it["type"]) == "revive" and str(it["id"]) == id:
			return true
	return false


func queued_heroes() -> int:
	var n := 0
	for it in queue:
		var t := str(it["type"])
		if t == "revive":
			n += 1
		elif t == "unit" and GameData.is_hero(str(it["id"])):
			n += 1
	return n


## Qahramonni tiriltirish (bosh binoda).
func enqueue_revive(id: String) -> String:
	if not complete or not dropoff:
		return "Faqat bosh binoda tiriltiriladi"
	if queue.size() >= MAX_QUEUE:
		return "Navbat to'la"
	var snap: Dictionary = {}
	for s0 in sim.dead_heroes.get(team, []):
		if str(s0.get("id", "")) == id:
			snap = s0
	if snap.is_empty():
		return "Bunday halok bo'lgan qahramon yo'q"
	var lvl := int(snap.get("level", 1))
	var cost := {"oltin": 100 + 30 * lvl, "yogoch": 0}
	if not sim.can_afford(team, cost):
		return sim.lack_text(team, cost)
	sim.spend(team, cost)
	sim.take_dead_hero(team, id)
	var item := _make_item("revive", id, 15.0 + 4.0 * lvl, cost)
	item["snapshot"] = snap
	queue.append(item)
	return ""


## Choyxona: yollanma qahramon (yaqinda o'yinchi askari bo'lishi kerak).
func hire(for_team: int, id: String) -> String:
	var mercs = bdef.get("mercenaries", [])
	if not (mercs is Array) or not mercs.has(id):
		return "Bu yerda bunday qahramon yo'q"
	var near := false
	for u in sim.units:
		if u.alive and u.team == for_team and not u.is_building() and u.sim_pos.distance_to(sim_pos) <= radius + 10.0:
			near = true
			break
	if not near:
		return "Choyxona yonida askaringiz bo'lishi kerak"
	if sim.hero_owned(for_team, id):
		return "Bu qahramon allaqachon sizda"
	if sim.hero_count(for_team) >= MAX_HEROES:
		return "Ko'pi bilan %d ta qahramon" % MAX_HEROES
	var hd := GameData.unit_def(id)
	var cost = hd.get("cost", {})
	if not sim.can_afford(for_team, cost):
		return sim.lack_text(for_team, cost)
	sim.spend(for_team, cost)
	var h = sim.spawner.spawn_unit(id, for_team, sim_pos + Vector3(radius + 1.5, 0, radius + 1.5))
	if h != null:
		sim.on_unit_trained(h, self)
	return ""


## Navbat elementi: {"type": "unit"|"research"|"upgrade", "id": ..., "time": soniya, "cost": {...}}
func _make_item(t: String, id: String, time: float, cost) -> Dictionary:
	return {"type": t, "id": id, "time": max(1.0, time), "cost": cost if cost is Dictionary else {}}


## Askar navbatga qo'shish. Xato bo'lsa matn qaytaradi, muvaffaqiyatda bo'sh satr.
func enqueue(kind: String) -> String:
	if kind.begins_with("revive:"):
		return enqueue_revive(kind.substr(7))
	if not can_train(kind):
		return "Bu bino buni o'rgata olmaydi"
	if queue.size() >= MAX_QUEUE:
		return "Navbat to'la"
	if _upgrading():
		return "Bino yangilanmoqda"
	var ud := GameData.unit_def(kind)
	var req_err: String = sim.meets(team, ud.get("requires", {}))
	if req_err != "":
		return req_err
	if GameData.is_hero(kind):
		if sim.hero_owned(team, kind):
			return "Bu qahramon allaqachon bor"
		if sim.hero_count(team) >= MAX_HEROES:
			return "Ko'pi bilan %d ta qahramon" % MAX_HEROES
	var limit := int(ud.get("limit", 0))
	if limit > 0 and sim.count_kind(team, kind) >= limit:
		return "%s ko'pi bilan %d ta bo'ladi" % [ud.get("name", kind), limit]
	var cost = ud.get("cost", {})
	var need_food := int(ud.get("food", 1))
	if sim.food_used(team) + need_food > sim.food_cap(team):
		return "Oziq yetarli emas — Uy quring!"
	if not sim.can_afford(team, cost):
		return sim.lack_text(team, cost)
	sim.spend(team, cost)
	queue.append(_make_item("unit", kind, float(ud.get("train_time", 15)), cost))
	return ""


func can_research(id: String) -> bool:
	var r = bdef.get("research", [])
	return complete and r is Array and r.has(id)


## Texnologiya tadqiqoti.
func enqueue_research(id: String) -> String:
	if not can_research(id):
		return "Bu binoda bunday tadqiqot yo'q"
	if queue.size() >= MAX_QUEUE:
		return "Navbat to'la"
	if sim.is_researching(team, id):
		return "Bu tadqiqot allaqachon ketmoqda"
	var ug := GameData.upgrade_def(id)
	var levels = ug.get("levels", [])
	var lvl: int = sim.upgrade_level(team, id)
	if not (levels is Array) or lvl >= levels.size():
		return "Bu texnologiya to'liq o'rganilgan"
	var L: Dictionary = levels[lvl]
	if sim.tier(team) < int(L.get("tier", 1)):
		return "Kerak: %d-davr (bosh binoni yangilang)" % int(L.get("tier", 1))
	var cost = L.get("cost", {})
	if not sim.can_afford(team, cost):
		return sim.lack_text(team, cost)
	sim.spend(team, cost)
	queue.append(_make_item("research", id, float(L.get("time", 40)), cost))
	return ""


## Bosh binoni keyingi davrga yangilash (Qishloq Markazi → Qal'a → Poytaxt Saroyi).
func enqueue_upgrade() -> String:
	var to := str(bdef.get("upgrade_to", ""))
	if to == "" or not complete:
		return "Bu binoni yangilab bo'lmaydi"
	if not queue.is_empty():
		return "Avval navbatni bo'shating"
	var nd := GameData.building_def(to)
	var req_err: String = sim.meets(team, nd.get("requires", {}))
	if req_err != "":
		return req_err
	var cost = nd.get("cost", {})
	if not sim.can_afford(team, cost):
		return sim.lack_text(team, cost)
	sim.spend(team, cost)
	queue.append(_make_item("upgrade", to, float(nd.get("build_time", 60)), cost))
	return ""


func _upgrading() -> bool:
	for it in queue:
		if str(it["type"]) == "upgrade":
			return true
	return false


func has_research_queued(id: String) -> bool:
	for it in queue:
		if str(it["type"]) == "research" and str(it["id"]) == id:
			return true
	return false


func queued_count(kind: String) -> int:
	var n := 0
	for it in queue:
		if str(it["type"]) == "unit" and str(it["id"]) == kind:
			n += 1
	return n


func counts_as(id: String) -> bool:
	var ca = bdef.get("counts_as", [])
	return ca is Array and ca.has(id)


func cancel_last() -> void:
	if queue.is_empty():
		return
	var it: Dictionary = queue.pop_back()
	sim.refund(team, it.get("cost", {}))
	if str(it["type"]) == "revive" and it.has("snapshot"):
		var list: Array = sim.dead_heroes.get(team, [])
		list.append(it["snapshot"])
		sim.dead_heroes[team] = list
	if queue.is_empty():
		train_progress = 0.0


func queued_food() -> int:
	var f := 0
	for it in queue:
		if str(it["type"]) == "unit":
			f += int(GameData.unit_def(str(it["id"])).get("food", 1))
	return f


func current_train_ratio() -> float:
	if queue.is_empty():
		return 0.0
	return clamp(train_progress / max(float(queue[0]["time"]), 0.1), 0.0, 1.0)


## Navbatdagi birinchi ish nomi (interfeys uchun).
func queue_label() -> String:
	if queue.is_empty():
		return ""
	var it: Dictionary = queue[0]
	var id := str(it["id"])
	match str(it["type"]):
		"unit":
			return str(GameData.unit_def(id).get("name", id))
		"research":
			var lvl: int = sim.upgrade_level(team, id) + 1
			return "%s %s" % [GameData.upgrade_def(id).get("name", id), _roman(lvl)]
		"upgrade":
			return "Yangilash: " + str(GameData.building_def(id).get("name", id))
		"revive":
			return "Tiriltirish: " + str(GameData.unit_def(id).get("name", id))
	return id


static func _roman(n: int) -> String:
	var r := ["", "I", "II", "III", "IV", "V"]
	return r[clampi(n, 0, 5)]


func sim_step(dt: float) -> void:
	prev_pos = sim_pos
	prev_facing = facing
	_tick_effects(dt)
	if complete:
		var rg := eff("regen")
		if rg > 0.0 and hp < max_hp:
			hp = min(max_hp, hp + rg * dt)
	if complete and has_attack:
		_tower_step(dt)
	if not complete or queue.is_empty():
		return
	var it: Dictionary = queue[0]
	train_progress += dt
	if train_progress < float(it["time"]):
		return
	train_progress = 0.0
	queue.pop_front()
	var id := str(it["id"])
	match str(it["type"]):
		"unit":
			_spawn_trained(id)
		"research":
			var lvl: int = sim.upgrade_level(team, id) + 1
			sim.set_upgrade_level(team, id, lvl)
			sim.message.emit(team, "Tadqiqot tugadi: %s %s" % [GameData.upgrade_def(id).get("name", id), _roman(lvl)])
		"upgrade":
			_become(id)
		"revive":
			var h = _spawn_trained(id)
			if h != null and h.is_hero() and it.has("snapshot"):
				h.restore(it["snapshot"])


## Bino boshqa turga aylanadi (masalan, Qishloq Markazi → Qal'a).
func _become(id: String) -> void:
	var nd := GameData.building_def(id)
	if nd.is_empty():
		return
	var ratio: float = hp / max(max_hp, 1.0)
	var keep_radius := radius
	var old_visual := visual
	var team_color: Color = old_visual.team_color if old_visual != null else Color.WHITE
	setup_building(nd, team, sim_pos, team_color, true)
	radius = keep_radius
	hp = max_hp * max(ratio, 0.5)
	if old_visual != null and is_instance_valid(old_visual):
		old_visual.queue_free()
	if selected and visual:
		visual.set_selected(true)
	recompute_stats()
	sim.message.emit(team, "%s tayyor! Yangi imkoniyatlar ochildi" % display_name)
	sim.on_building_complete(self)


func _spawn_trained(kind: String):
	if sim == null or sim.spawner == null:
		return null
	var dir := Vector3(0, 0, 1)
	if has_rally:
		var d: Vector3 = rally - sim_pos
		d.y = 0
		if d.length() > 0.1:
			dir = d.normalized()
	var pos: Vector3 = sim_pos + dir * (radius + 1.0)
	var u = sim.spawner.spawn_unit(kind, team, pos)
	if u == null:
		return null
	if has_rally:
		var res = sim.resource_at(rally, 1.5)
		if res != null and u.is_worker:
			u.order_gather(res.uid)
		else:
			u.order_move(rally, false)
	elif u.is_worker:
		var g = sim.nearest_resource("gold", sim_pos, 30.0)
		if g != null:
			u.order_gather(g.uid)
	sim.on_unit_trained(u, self)
	return u


## Minora: masofadagi eng yaqin ko'rinadigan dushmanga o'q/xarsang otadi.
func _tower_step(dt: float) -> void:
	_cooldown = max(0.0, _cooldown - dt)
	var t = sim.get_unit(target_id)
	if t != null:
		var d: float = sim_pos.distance_to(t.sim_pos) - t.radius
		if d > attack_range or (sim.fog != null and not sim.fog.sees(team, t.sim_pos)):
			t = null
	if t == null:
		t = sim.nearest_enemy(self, attack_range)
		target_id = t.uid if t != null else -1
	if t == null or _cooldown > 0.0:
		return
	_cooldown = attack_cooldown
	_fire_projectile(t)
