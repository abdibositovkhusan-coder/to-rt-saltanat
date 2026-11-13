class_name EnemyAI
extends Node
## Raqib sun'iy intellekti. Uch qiyinlik darajasi (Oson, O'rta, Qiyin) va har saltanatning o'z uslubi:
##   Trollar — erta bosim; Yalmog'iz — tuman yoyish va tungi hujum; Elflar — kamonchilar, tungi hujum,
##   ishchilarga zarba; Odamlar — kengayish (ikkinchi baza) va karvonlar.
## Iqtisod: ishchilar, resurs, oziq binolari, ishlab chiqarish binolari, davr ko'tarish, tadqiqotlar.
## Jang: to'lqinlar, baza himoyasi, qahramonlar; Qiyin darajada — yarador askarlarni olib chiqish,
## eng zaif dushmanga zarba (fokus) va razvedka. AI aldamaydi: faqat o'zi ko'rgan narsani biladi.
## Bog'liqlik: Battle, Simulation, GameCommand, GameData, Unit, Building, Hero.

const LEVELS := {
	"oson": {"think": 2.0, "workers": 4, "wave_size": 4, "wave_growth": 1, "first_wave_add": 150.0, "max_heroes": 1,
		"tier_max": 2, "research_max": 0, "micro": false, "scout": false, "cast": 0.3, "keep_gold": 150},
	"orta": {"think": 1.0, "workers": 6, "wave_size": 5, "wave_growth": 2, "first_wave_add": 0.0, "max_heroes": 2,
		"tier_max": 3, "research_max": 1, "micro": false, "scout": false, "cast": 1.0, "keep_gold": 75},
	"qiyin": {"think": 0.5, "workers": 9, "wave_size": 6, "wave_growth": 2, "first_wave_add": -60.0, "max_heroes": 3,
		"tier_max": 3, "research_max": 3, "micro": true, "scout": true, "cast": 1.0, "keep_gold": 50},
}

var battle = null
var sim: Simulation
var team: int = 1
var faction: Dictionary = {}
var style: Dictionary = {}
var level: Dictionary = {}
var difficulty: String = "orta"

var _think: float = 1.0
var _time: float = 0.0
var _wave_size: int = 5
var _wave_growth: int = 2
var _first_wave: float = 240.0
var _target_workers: int = 6
var _waves: int = 0
var _build_cooldown: float = 0.0
var _defend_cooldown: float = 0.0
var _micro_cd: float = 2.0
var _known: Dictionary = {}
var _use_heroes: bool = false
var _retreating: Dictionary = {}
var _scouted: bool = false


func setup(b, s: Simulation, team_id: int, cfg: Dictionary, faction_def: Dictionary, diff: String = "orta") -> void:
	battle = b
	sim = s
	team = team_id
	faction = faction_def
	difficulty = diff if LEVELS.has(diff) else "orta"
	level = LEVELS[difficulty]
	var st = faction.get("ai", {})
	style = st if st is Dictionary else {}
	_wave_size = int(level["wave_size"])
	_wave_growth = int(style.get("wave_growth", level["wave_growth"]))
	_first_wave = max(60.0, float(cfg.get("first_wave", 240)) * float(style.get("first_wave_mult", 1.0)) + float(level["first_wave_add"]))
	_target_workers = int(level["workers"])
	_use_heroes = bool(cfg.get("heroes", false))
	sim.ai_cast_chance[team] = float(level["cast"])


func seconds_to_wave() -> float:
	return max(0.0, _first_wave - _time)


func _process(delta: float) -> void:
	if sim == null or battle == null or battle.over or sim.paused:
		return
	var dt := delta * sim.speed
	_time += dt
	_build_cooldown -= dt
	_defend_cooldown -= dt
	_micro_cd -= dt
	_think -= dt
	if _think > 0.0:
		return
	_think = float(level["think"])
	_decide()
	if bool(level["micro"]) and _micro_cd <= 0.0:
		_micro_cd = 2.0
		_micro()


# ---------------- Asosiy qaror ----------------

func _decide() -> void:
	var workers: Array = []
	var army: Array = []
	var buildings: Array = []
	for u in sim.units:
		if not u.alive or u.team != team:
			continue
		if u.is_building():
			buildings.append(u)
		elif u.is_worker:
			workers.append(u)
		elif u.life_timer < 0.0:
			army.append(u)
	var hall = null
	for b in buildings:
		if b.complete and b.dropoff:
			hall = b
			break
	if hall == null:
		_attack_with(army)
		return

	_economy(hall, workers, buildings)
	_heroes(hall)
	_construct(hall, workers, buildings)
	_research(buildings)
	_train(buildings, workers)
	if _defend(army, buildings):
		return
	if bool(level["scout"]) and not _scouted and _time > 45.0 and not army.is_empty():
		_scouted = true
		var sc = army[0]
		sim.push(GameCommand.make(GameCommand.Type.MOVE, [sc.uid], _player_start(), -1, "", team))
	_maybe_wave(army)


func _economy(hall, workers: Array, buildings: Array) -> void:
	var worker_kind := str(faction.get("worker", ""))
	if worker_kind != "" and workers.size() + hall.queue.size() < _target_workers and hall.queue.size() < 2:
		sim.push(GameCommand.make(GameCommand.Type.TRAIN, [], Vector3.ZERO, hall.uid, worker_kind, team))
	var on_gold := 0
	for w in workers:
		if (w.state == Unit.State.GATHER or w.state == Unit.State.RETURN) and w.gather_kind == "gold":
			on_gold += 1
	var gold_target: int = max(2, int(ceil(workers.size() * 0.65)))
	for w in workers:
		if w.state != Unit.State.IDLE:
			continue
		var kind: String = "gold" if on_gold < gold_target else "wood"
		var n = sim.nearest_resource(kind, w.sim_pos, 45.0)
		if n == null:
			n = sim.nearest_resource("wood" if kind == "gold" else "gold", w.sim_pos, 45.0)
		if n != null:
			sim.push(GameCommand.make(GameCommand.Type.GATHER, [w.uid], Vector3.ZERO, n.uid, "", team))
			if n.kind == "gold":
				on_gold += 1


func _heroes(hall) -> void:
	if not _use_heroes or hall.queue.size() >= 2:
		return
	var dead: Array = sim.dead_heroes.get(team, [])
	if not dead.is_empty():
		var snap: Dictionary = dead[0]
		if sim.gold(team) >= 100 + 30 * int(snap.get("level", 1)) + 50:
			sim.push(GameCommand.make(GameCommand.Type.TRAIN, [], Vector3.ZERO, hall.uid, "revive:" + str(snap.get("id", "")), team))
		return
	var want: int = 1
	if _time > 420.0:
		want = 2
	if _time > 780.0:
		want = 3
	want = min(want, int(level["max_heroes"]))
	if sim.hero_count(team) >= want:
		return
	for hid in faction.get("heroes", []):
		var hk := str(hid)
		if not sim.hero_owned(team, hk) and sim.can_afford(team, GameData.unit_def(hk).get("cost", {})):
			sim.push(GameCommand.make(GameCommand.Type.TRAIN, [], Vector3.ZERO, hall.uid, hk, team))
			return


func _construct(hall, workers: Array, buildings: Array) -> void:
	if _build_cooldown > 0.0 or workers.size() == 0 or _has_incomplete(buildings):
		return
	# 1) Oziq binosi
	var free_food: int = sim.food_cap(team) - sim.food_used(team)
	var food_margin: int = 6 if bool(style.get("extra_mist", false)) else 4
	if free_food < food_margin and sim.food_cap(team) < Simulation.FOOD_LIMIT:
		var food_kind := _food_building()
		if food_kind != "" and _try_build(food_kind, hall.sim_pos, workers, 10.0):
			return
	# 2) Ustuvor binolar (masalan, Jon Tuxumi)
	for pk in style.get("priority_buildings", []):
		var pkk := str(pk)
		var pbd := GameData.building_def(pkk)
		if sim.count_buildings(team, pkk) == 0 and sim.meets(team, pbd.get("requires", {})) == "" and _try_build(pkk, hall.sim_pos, workers, 12.0):
			return
	# 3) Davrni ko'tarish
	var up_to := str(hall.bdef.get("upgrade_to", ""))
	if up_to != "" and hall.queue.is_empty() and hall.tier < int(level["tier_max"]) and _time > 220.0 * float(hall.tier):
		var ud2 := GameData.building_def(up_to)
		var uc = ud2.get("cost", {})
		if sim.gold(team) >= int(uc.get("oltin", 0)) + 150 and sim.wood(team) >= int(uc.get("yogoch", 0)):
			sim.push(GameCommand.make(GameCommand.Type.UPGRADE_BUILDING, [], Vector3.ZERO, hall.uid, "", team))
			_build_cooldown = 8.0
			return
	# 4) Kengayish (Odamlar uslubi): ikkinchi bosh bino boshqa oltin konida
	if bool(style.get("expand", false)) and difficulty != "oson" and sim.tier(team) >= 2 and _time > 420.0 and sim.gold(team) > 550:
		var halls := 0
		for b in buildings:
			if b.dropoff:
				halls += 1
		if halls < 2:
			var mine = _expansion_mine(hall)
			var hall_kind := str(faction.get("hall", ""))
			if mine != null and hall_kind != "":
				var center: Vector3 = mine.sim_pos + (Vector3.ZERO - mine.sim_pos).normalized() * 7.0
				if _try_build(hall_kind, center, workers, 20.0):
					return
	# 5) Minoralar
	var tower_kind := str(faction.get("tower", ""))
	if tower_kind != "" and (_waves > 0 or _time > 150.0) and sim.count_buildings(team, tower_kind) < int(style.get("towers", 2)):
		var td := GameData.building_def(tower_kind)
		if sim.gold(team) >= int(td.get("cost", {}).get("oltin", 0)) + 120:
			var toward = _player_target()
			var c: Vector3 = hall.sim_pos
			if toward != null:
				var tv: Vector3 = toward
				c = hall.sim_pos + (tv - hall.sim_pos).normalized() * 8.0
			if _try_build(tower_kind, c, workers, 12.0):
				return
	# 6) Ishlab chiqarish va tadqiqot binolari
	if sim.gold(team) > 450:
		for k in faction.get("builds", []):
			var kk := str(k)
			var bdk := GameData.building_def(kk)
			var trains_any: bool = not bdk.get("trains", []).is_empty()
			var research_any: bool = not bdk.get("research", []).is_empty() and int(level["research_max"]) > 0
			if bool(bdk.get("dropoff", false)) or (not trains_any and not research_any):
				continue
			var max_count: int = 2 if kk == str(faction.get("barracks", "")) and difficulty == "qiyin" else 1
			if sim.count_buildings(team, kk) >= max_count:
				continue
			if sim.meets(team, bdk.get("requires", {})) != "":
				continue
			if _try_build(kk, hall.sim_pos, workers, 15.0):
				return


func _research(buildings: Array) -> void:
	var rmax := int(level["research_max"])
	if rmax <= 0 or sim.gold(team) < 350:
		return
	for b in buildings:
		if not b.complete or not b.queue.is_empty():
			continue
		var list = b.bdef.get("research", [])
		if not (list is Array):
			continue
		for rid in list:
			var r := str(rid)
			var ug := GameData.upgrade_def(r)
			var levels = ug.get("levels", [])
			var lvl: int = sim.upgrade_level(team, r)
			if not (levels is Array) or lvl >= min(levels.size(), rmax) or sim.is_researching(team, r):
				continue
			var L: Dictionary = levels[lvl]
			if sim.tier(team) < int(L.get("tier", 1)):
				continue
			var cost = L.get("cost", {})
			if sim.gold(team) - int(cost.get("oltin", 0)) >= 200 and sim.wood(team) >= int(cost.get("yogoch", 0)):
				sim.push(GameCommand.make(GameCommand.Type.RESEARCH, [], Vector3.ZERO, b.uid, r, team))
				return


func _train(buildings: Array, workers: Array) -> void:
	var prefer: Dictionary = style.get("prefer", {})
	for b in buildings:
		if not b.complete or b.dropoff or b.trains.is_empty() or b.queue.size() >= 2:
			continue
		var options: Array = []
		var weights: Array = []
		for tk in b.trains:
			var tdef := GameData.unit_def(str(tk))
			if tdef.get("worker", null) != null:
				continue
			if sim.meets(team, tdef.get("requires", {})) != "":
				continue
			options.append(str(tk))
			weights.append(float(prefer.get(str(tk), 1.0)))
		if options.is_empty():
			continue
		var kind2 := _weighted(options, weights)
		var ud := GameData.unit_def(kind2)
		var keep: int = int(level["keep_gold"]) if workers.size() < _target_workers else 0
		var cost = ud.get("cost", {})
		if sim.gold(team) - keep >= int(cost.get("oltin", 0)) and sim.wood(team) >= int(cost.get("yogoch", 0)) and sim.food_used(team) + int(ud.get("food", 1)) <= sim.food_cap(team):
			sim.push(GameCommand.make(GameCommand.Type.TRAIN, [], Vector3.ZERO, b.uid, kind2, team))


func _defend(army: Array, buildings: Array) -> bool:
	if _defend_cooldown > 0.0:
		return false
	var threat = _threat_near(buildings)
	if threat == null:
		return false
	var ids: Array = []
	for a in army:
		if not _retreating.has(a.uid):
			ids.append(a.uid)
	if ids.is_empty():
		return false
	sim.push(GameCommand.make(GameCommand.Type.ATTACK_MOVE, ids, threat.sim_pos, -1, "", team))
	_defend_cooldown = 6.0
	return true


func _maybe_wave(army: Array) -> void:
	if _time < _first_wave:
		return
	var idle: Array = []
	for a in army:
		if _retreating.has(a.uid):
			continue
		if a.state == Unit.State.IDLE or a.state == Unit.State.HOLD:
			idle.append(a)
	if idle.size() < _wave_size:
		return
	# Tungi hujum uslubi: kunduzi kutadi (agar qo'shin juda katta bo'lmasa)
	if bool(style.get("night_attack", false)) and not sim.is_night and idle.size() < int(_wave_size * 1.6):
		return
	_attack_with(idle)
	_waves += 1
	_wave_size += _wave_growth
	if battle.has_method("on_enemy_wave"):
		battle.on_enemy_wave(_waves)


func _attack_with(units: Array) -> void:
	if units.is_empty():
		return
	var target = null
	if bool(style.get("harass_workers", false)) and _waves % 2 == 0:
		var mine = sim.nearest_resource("gold", _player_start(), 25.0)
		if mine != null:
			target = mine.sim_pos
	if target == null:
		target = _player_target()
	if target == null:
		return
	var ids: Array = []
	for u in units:
		ids.append(u.uid)
	sim.push(GameCommand.make(GameCommand.Type.ATTACK_MOVE, ids, target, -1, "", team))


# ---------------- Qiyin daraja: mikro ----------------

func _micro() -> void:
	var hall = sim.nearest_dropoff(team, _player_start())
	for u in sim.units:
		if not u.alive or u.team != team or u.is_building() or u.is_worker:
			continue
		# Yarador askarni orqaga olib chiqish
		if _retreating.has(u.uid):
			if u.hp > u.max_hp * 0.75:
				_retreating.erase(u.uid)
			continue
		if hall != null and u.state == Unit.State.ATTACKING and u.hp < u.max_hp * 0.25 and u.sim_pos.distance_to(hall.sim_pos) > 12.0:
			_retreating[u.uid] = true
			sim.push(GameCommand.make(GameCommand.Type.MOVE, [u.uid], hall.sim_pos, -1, "", team))
			continue
		# Fokus: masofadagi eng zaif dushmanga
		if u.state != Unit.State.ATTACKING:
			continue
		var best = null
		var best_ratio := 1.01
		var reach: float = u.attack_range + u.radius + 2.0
		for o in sim.units:
			if not o.alive or o.team != 1 - team or o.is_building() or o.invulnerable:
				continue
			if o.flying and not u.can_hit_air():
				continue
			if u.sim_pos.distance_to(o.sim_pos) > reach + o.radius:
				continue
			if not _can_see(o.sim_pos):
				continue
			var ratio: float = o.hp / max(o.max_hp, 1.0)
			if o.is_hero():
				ratio -= 0.15
			if ratio < best_ratio:
				best_ratio = ratio
				best = o
		if best != null and best.uid != u.target_id:
			sim.push(GameCommand.make(GameCommand.Type.ATTACK, [u.uid], best.sim_pos, best.uid, "", team))
	for id in _retreating.keys():
		if sim.get_unit(int(id)) == null:
			_retreating.erase(id)


# ---------------- Yordamchilar ----------------

func _weighted(options: Array, weights: Array) -> String:
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := sim.rng.randf() * total
	for i in options.size():
		r -= float(weights[i])
		if r <= 0.0:
			return str(options[i])
	return str(options[options.size() - 1])


func _food_building() -> String:
	for k in faction.get("builds", []):
		var bd := GameData.building_def(str(k))
		if int(bd.get("food", 0)) > 0 and not bool(bd.get("dropoff", false)):
			return str(k)
	return ""


func _try_build(kind: String, center: Vector3, workers: Array, cooldown: float) -> bool:
	var bd := GameData.building_def(kind)
	if bd.is_empty() or not sim.can_afford(team, bd.get("cost", {})):
		return false
	var lim := int(bd.get("limit", 0))
	if lim > 0 and sim.count_buildings(team, kind) >= lim:
		return false
	var spot = _find_spot(bd, center)
	if spot == null:
		return false
	var builder = workers[sim.rng.randi() % workers.size()]
	sim.push(GameCommand.make(GameCommand.Type.BUILD, [builder.uid], spot, -1, kind, team))
	_build_cooldown = cooldown
	return true


func _expansion_mine(hall):
	var best = null
	var best_d := INF
	for n in sim.res_nodes:
		if not n.alive or n.kind != "gold":
			continue
		if n.sim_pos.distance_to(hall.sim_pos) < 18.0:
			continue
		if n.sim_pos.distance_to(_player_start()) < 30.0:
			continue
		var near_building := false
		for b in sim.units:
			if b.alive and b.is_building() and b.dropoff and b.sim_pos.distance_to(n.sim_pos) < 14.0:
				near_building = true
				break
		if near_building:
			continue
		var d: float = n.sim_pos.distance_to(hall.sim_pos)
		if d < best_d:
			best_d = d
			best = n
	return best


func _has_incomplete(buildings: Array) -> bool:
	for b in buildings:
		if not b.complete:
			return true
	return false


func _find_spot(bd: Dictionary, center: Vector3):
	for i in 40:
		var a := sim.rng.randf() * TAU
		var r := sim.rng.randf_range(6.0, 14.0)
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		if sim.can_place_team(team, bd, p):
			return p
	return null


func _can_see(pos: Vector3) -> bool:
	return sim.fog == null or sim.fog.sees(team, pos)


func _player_start() -> Vector3:
	if battle != null and "player_start" in battle:
		return battle.player_start
	return Vector3.ZERO


func _threat_near(buildings: Array):
	for u in sim.units:
		if not u.alive or u.team != 1 - team or u.is_building():
			continue
		if not _can_see(u.sim_pos):
			continue
		for b in buildings:
			if u.sim_pos.distance_to(b.sim_pos) < b.radius + 12.0:
				return u
	return null


## Faqat ko'rgan (yoki ilgari ko'rib eslab qolgan) nishonlar. Hech narsa ma'lum bo'lmasa —
## o'yinchining boshlang'ich joyi (RTS'da boshlang'ich joylar hammaga ma'lum).
func _player_target():
	var my_center := Vector3.ZERO
	for u in sim.units:
		if u.alive and u.team == team and u.is_building() and u.dropoff:
			my_center = u.sim_pos
	for u in sim.units:
		if u.alive and u.team == 1 - team and u.is_building() and _can_see(u.sim_pos):
			_known[u.uid] = u.sim_pos
	for id in _known.keys():
		if sim.get_unit(int(id)) == null:
			_known.erase(id)
	var best = null
	var best_d := INF
	for u in sim.units:
		if not u.alive or u.team != 1 - team:
			continue
		if not _can_see(u.sim_pos) and not _known.has(u.uid):
			continue
		var d: float = u.sim_pos.distance_to(my_center)
		if u.is_building():
			d -= 5.0
		if d < best_d:
			best_d = d
			best = u
	if best != null:
		return best.sim_pos
	return _player_start()
