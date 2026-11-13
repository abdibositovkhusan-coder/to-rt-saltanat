class_name Simulation
extends Node
## O'yin mantiqi belgilangan tezlikda (20 Hz) ishlaydi; grafika esa oraliqni silliq to'ldiradi
## (interpolyatsiya). Buyruqlar navbati, birliklar va binolar ro'yxati, resurs manbalari (oltin koni, daraxt),
## jamoalar xazinasi (oltin, yog'och), oziq limiti, bino joylash tekshiruvi, o'qlar va to'qnashuvdan qochish.
## Yo'l topish to'ri (PathGrid) va tuman urushi (FogOfWar) havolasi ham shu yerda.
## Bog'liqlik: Unit, Building, ResourceNode, Projectile, GameCommand, PathGrid. "spawner" — Battle (yangi obyekt yaratadi).

signal unit_died(unit)
signal message(team, text)
signal building_completed(building)
signal unit_trained(unit, building)
signal ticked

const TICK_RATE := 20
const TICK_DT := 1.0 / TICK_RATE
const MAX_STEPS_PER_FRAME := 5
const FOOD_LIMIT := 120
const MAP_LIMIT := 54.0

var tick: int = 0
var speed: float = 1.0
var paused: bool = false
var units: Array = []
var projectiles: Array = []
var res_nodes: Array = []
var treasury: Dictionary = {0: {"oltin": 0, "yogoch": 0}, 1: {"oltin": 0, "yogoch": 0}}
var upgrades: Dictionary = {0: {}, 1: {}}
var dead_heroes: Dictionary = {0: [], 1: []}
var camps: Dictionary = {}
var drops: Array = []
var _timers: Array = []
var team_faction: Dictionary = {0: "odamlar", 1: "trollar"}
var is_night: bool = false
var ai_cast_chance: Dictionary = {}
var _karvon_acc: float = 0.0
var rng := RandomNumberGenerator.new()
var spawner = null
var grid := PathGrid.new()
var fog = null

var _by_id: Dictionary = {}
var _res_by_id: Dictionary = {}
var _next_id: int = 1
var _acc: float = 0.0
var _queue: Array = []


func _ready() -> void:
	rng.seed = 20261113


# ---------------- Ro'yxatga olish ----------------

func register(u) -> void:
	u.uid = _next_id
	_next_id += 1
	u.sim = self
	units.append(u)
	_by_id[u.uid] = u
	if u.is_building():
		grid.mark_circle(u.sim_pos, u.radius, 1)


func register_resource(n) -> void:
	n.uid = _next_id
	_next_id += 1
	res_nodes.append(n)
	_res_by_id[n.uid] = n
	grid.mark_circle(n.sim_pos, n.radius, 1)


func add_projectile(p) -> void:
	p.sim = self
	projectiles.append(p)


func get_unit(id: int):
	if id < 0:
		return null
	var u = _by_id.get(id, null)
	if u == null or not is_instance_valid(u) or not u.alive:
		return null
	return u


func get_res(id: int):
	if id < 0:
		return null
	var n = _res_by_id.get(id, null)
	if n == null or not is_instance_valid(n) or not n.alive:
		return null
	return n


## Kechiktirilgan ish (masalan, meteor tushishi).
func schedule(delay: float, cb: Callable) -> void:
	_timers.append({"at": tick + max(1, int(round(delay * TICK_RATE))), "cb": cb})


func push(cmd: GameCommand) -> void:
	cmd.tick = tick + 1
	_queue.append(cmd)


# ---------------- Xazina va oziq ----------------

func gold(team: int) -> int:
	return int(treasury.get(team, {}).get("oltin", 0))


func wood(team: int) -> int:
	return int(treasury.get(team, {}).get("yogoch", 0))


func set_treasury(team: int, oltin: int, yogoch: int) -> void:
	treasury[team] = {"oltin": oltin, "yogoch": yogoch}


func add_resource(team: int, kind: String, amount: int) -> void:
	if amount <= 0:
		return
	var key: String = "oltin" if kind == "gold" else "yogoch"
	if team == 0 and key == "oltin" and spawner != null and "stats" in spawner:
		spawner.stats["gold"] = int(spawner.stats["gold"]) + amount
	var t: Dictionary = treasury.get(team, {"oltin": 0, "yogoch": 0})
	t[key] = int(t.get(key, 0)) + amount
	treasury[team] = t


func can_afford(team: int, cost) -> bool:
	if not (cost is Dictionary):
		return true
	return gold(team) >= int(cost.get("oltin", 0)) and wood(team) >= int(cost.get("yogoch", 0))


func lack_text(team: int, cost) -> String:
	if not (cost is Dictionary):
		return ""
	if gold(team) < int(cost.get("oltin", 0)):
		return "Oltin yetarli emas!"
	if wood(team) < int(cost.get("yogoch", 0)):
		return "Yog'och yetarli emas!"
	return ""


func spend(team: int, cost) -> void:
	if not (cost is Dictionary):
		return
	var t: Dictionary = treasury.get(team, {"oltin": 0, "yogoch": 0})
	t["oltin"] = int(t.get("oltin", 0)) - int(cost.get("oltin", 0))
	t["yogoch"] = int(t.get("yogoch", 0)) - int(cost.get("yogoch", 0))
	treasury[team] = t


func refund(team: int, cost) -> void:
	if not (cost is Dictionary):
		return
	var t: Dictionary = treasury.get(team, {"oltin": 0, "yogoch": 0})
	t["oltin"] = int(t.get("oltin", 0)) + int(cost.get("oltin", 0))
	t["yogoch"] = int(t.get("yogoch", 0)) + int(cost.get("yogoch", 0))
	treasury[team] = t


func food_used(team: int) -> int:
	var f := 0
	for u in units:
		if not u.alive or u.team != team:
			continue
		if u.is_building():
			f += u.queued_food()
		else:
			f += u.food
	return f


func food_cap(team: int) -> int:
	var f := 0
	for u in units:
		if u.alive and u.team == team and u.is_building() and u.complete:
			f += u.food_provided
	return min(f, FOOD_LIMIT)


# ---------------- Texnologiyalar va davrlar ----------------

func upgrade_level(team: int, id: String) -> int:
	return int(upgrades.get(team, {}).get(id, 0))


func set_upgrade_level(team: int, id: String, level: int) -> void:
	var t: Dictionary = upgrades.get(team, {})
	t[id] = level
	upgrades[team] = t
	for u in units:
		if u.alive and u.team == team:
			u.recompute_stats()


func is_researching(team: int, id: String) -> bool:
	for u in units:
		if u.alive and u.team == team and u.is_building() and u.has_research_queued(id):
			return true
	return false


func tier(team: int) -> int:
	var t := 1
	for u in units:
		if u.alive and u.team == team and u.is_building() and u.complete:
			t = max(t, u.tier)
	return t


func has_building(team: int, id: String) -> bool:
	for u in units:
		if u.alive and u.team == team and u.is_building() and u.complete and (u.unit_id == id or u.counts_as(id)):
			return true
	return false


func heroes_of(team: int) -> Array:
	var out: Array = []
	for u in units:
		if u.alive and u.team == team and u.is_hero():
			out.append(u)
	return out


## Bu qahramon jamoada bormi (tirik, navbatda yoki o'lik)?
func hero_owned(team: int, id: String) -> bool:
	if count_kind(team, id) > 0:
		return true
	for s in dead_heroes.get(team, []):
		if str(s.get("id", "")) == id:
			return true
	for u in units:
		if u.alive and u.team == team and u.is_building() and u.has_revive_queued(id):
			return true
	return false


func hero_count(team: int) -> int:
	var n: int = dead_heroes.get(team, []).size()
	for u in units:
		if not u.alive or u.team != team:
			continue
		if u.is_hero():
			n += 1
		elif u.is_building():
			n += u.queued_heroes()
	return n


func take_dead_hero(team: int, id: String) -> Dictionary:
	var list: Array = dead_heroes.get(team, [])
	for i in list.size():
		if str(list[i].get("id", "")) == id:
			var s: Dictionary = list[i]
			list.remove_at(i)
			return s
	return {}


func count_kind(team: int, kind: String) -> int:
	var n := 0
	for u in units:
		if not u.alive or u.team != team:
			continue
		if u.is_building():
			n += u.queued_count(kind)
		elif u.unit_id == kind:
			n += 1
	return n


## Talab bajarilganmi? Bajarilmagan bo'lsa — sababi (matn), aks holda bo'sh satr.
func meets(team: int, req) -> String:
	if not (req is Dictionary):
		return ""
	var need_tier := int(req.get("tier", 1))
	if tier(team) < need_tier:
		return "Kerak: %d-davr (bosh binoni yangilang)" % need_tier
	var bl = req.get("buildings", [])
	if bl is Array:
		for b in bl:
			if not has_building(team, str(b)):
				return "Kerak: %s" % str(GameData.building_def(str(b)).get("name", b))
	return ""


# ---------------- So'rovlar ----------------

func count_team(team: int) -> int:
	var n := 0
	for u in units:
		if u.alive and u.team == team:
			n += 1
	return n


func nearest_enemy(u, max_range: float):
	var best = null
	var best_d := max_range
	for o in units:
		if not o.alive or o.team == u.team:
			continue
		if o.invulnerable:
			continue
		if o.has_effect("invis") and u.sim_pos.distance_to(o.sim_pos) > 1.6:
			continue
		if fog != null and not fog.sees(u.team, o.sim_pos):
			continue
		if o.flying and not u.can_hit_air():
			continue
		var d: float = u.sim_pos.distance_to(o.sim_pos) - o.radius
		# Askarlar binolardan oldin nishonga olinadi
		if o.is_building():
			d += 3.0
		if d < best_d:
			best_d = d
			best = o
	return best


func nearest_resource(kind: String, pos: Vector3, max_dist: float):
	var best = null
	var best_d := max_dist
	for n in res_nodes:
		if not n.alive or n.kind != kind:
			continue
		var d: float = pos.distance_to(n.sim_pos)
		if d < best_d:
			best_d = d
			best = n
	return best


func resource_at(pos: Vector3, extra: float):
	for n in res_nodes:
		if n.alive and Vector2(pos.x - n.sim_pos.x, pos.z - n.sim_pos.z).length() <= n.radius + extra:
			return n
	return null


func nearest_dropoff(team: int, pos: Vector3):
	var best = null
	var best_d := INF
	for u in units:
		if u.alive and u.team == team and u.is_building() and u.complete and u.dropoff:
			var d: float = pos.distance_to(u.sim_pos)
			if d < best_d:
				best_d = d
				best = u
	return best


func can_place(bdef: Dictionary, pos: Vector3) -> bool:
	var r := float(bdef.get("radius", 2.0))
	if abs(pos.x) > MAP_LIMIT - r or abs(pos.z) > MAP_LIMIT - r:
		return false
	for u in units:
		if u.alive and u.is_building():
			if Vector2(pos.x - u.sim_pos.x, pos.z - u.sim_pos.z).length() < r + u.radius + 0.4:
				return false
	for n in res_nodes:
		if not n.alive:
			continue
		var gap: float = 1.6 if n.kind == "gold" else 0.2
		if Vector2(pos.x - n.sim_pos.x, pos.z - n.sim_pos.z).length() < r + n.radius + gap:
			return false
	return true


## Yalmog'iz: binolar faqat Qora Tuman ichiga quriladi (bosh binodan tashqari).
func mist_radius(b) -> float:
	var r: float = float(b.bdef.get("mist", 0.0))
	if r > 0.0 and upgrade_level(b.team, "qoraygan_yer") > 0:
		r *= 1.6
	return r


func mist_ok(team: int, bdef: Dictionary, pos: Vector3) -> bool:
	var fd := GameData.faction_def(str(team_faction.get(team, "")))
	if not bool(fd.get("mist_build", false)) or bool(bdef.get("dropoff", false)):
		return true
	for u in units:
		if u.alive and u.team == team and u.is_building():
			var r := mist_radius(u)
			if r > 0.0 and Vector2(pos.x - u.sim_pos.x, pos.z - u.sim_pos.z).length() <= r:
				return true
	return false


func can_place_team(team: int, bdef: Dictionary, pos: Vector3) -> bool:
	return can_place(bdef, pos) and mist_ok(team, bdef, pos)


func count_buildings(team: int, id: String) -> int:
	var n := 0
	for u in units:
		if u.alive and u.team == team and u.is_building() and u.unit_id == id:
			n += 1
	return n


# ---------------- Saltanat mexanikalari (har 0.5 s) ----------------

func _faction_tick() -> void:
	var dt := 0.5
	for u in units:
		if not u.alive:
			continue
		# Elflar: Oy va Quyosh
		if u.has_tag("elf") and not u.is_building():
			if is_night:
				if u.state == Unit.State.IDLE or u.state == Unit.State.HOLD or u.state == Unit.State.GATHER:
					u.add_effect("invis", 0.7, 1.0)
				if upgrade_level(u.team, "oy_barakasi") > 0:
					u.add_effect("regen", 0.7, 2.0)
			else:
				u.add_effect("dmg_bonus", 0.7, 0.15)
		if not u.is_building() or not u.complete:
			continue
		# Elflar: Ildiz Tarmog'i
		if str(u.bdef.get("faction", "")) == "elflar":
			var reach: float = 14.0 * (1.5 if upgrade_level(u.team, "chuqur_ildizlar") > 0 else 1.0)
			for o in units:
				if o != u and o.alive and o.team == u.team and o.is_building() and o.complete and o.sim_pos.distance_to(u.sim_pos) <= reach:
					u.add_effect("regen", 0.7, 3.0)
					u.add_effect("rooted", 0.7, 1.0)
					break
		# Yalmog'iz: Qora Tuman
		var mr := mist_radius(u)
		if mr > 0.0:
			for o in units:
				if not o.alive or o.is_building() or o.flying:
					continue
				if Vector2(o.sim_pos.x - u.sim_pos.x, o.sim_pos.z - u.sim_pos.z).length() > mr:
					continue
				if o.team == u.team:
					o.add_effect("regen", 0.7, 3.0)
				elif not o.invulnerable and o.team != 2:
					o.apply_slow(0.7)
	# Odamlar: Karvon Yo'li
	_karvon_acc += dt
	if _karvon_acc >= 20.0:
		_karvon_acc = 0.0
		for team in [0, 1]:
			if str(team_faction.get(team, "")) != "odamlar":
				continue
			var halls: Array = []
			for u in units:
				if u.alive and u.team == team and u.is_building() and u.complete and u.dropoff:
					halls.append(u)
			if halls.size() >= 2:
				var g: int = 30 * (halls.size() - 1)
				add_resource(team, "gold", g)
				message.emit(team, "Karvon keldi: +%d oltin" % g)
				if spawner != null and spawner.has_method("spawn_text"):
					spawner.spawn_text(halls[1].sim_pos + Vector3(0, 4, 0), "+%d" % g, Color(1, 0.85, 0.2), team)


func on_building_complete(b) -> void:
	building_completed.emit(b)


func on_unit_trained(u, b) -> void:
	unit_trained.emit(u, b)


# ---------------- Asosiy sikl ----------------

func _process(delta: float) -> void:
	if not paused:
		_acc += delta * speed
		var steps := 0
		while _acc >= TICK_DT and steps < MAX_STEPS_PER_FRAME:
			_step()
			_acc -= TICK_DT
			steps += 1
		if steps >= MAX_STEPS_PER_FRAME:
			_acc = 0.0
	var alpha: float = clamp(_acc / TICK_DT, 0.0, 1.0)
	for u in units:
		u.update_visual(alpha)
	for p in projectiles:
		p.update_visual(alpha)


func _step() -> void:
	tick += 1
	var q := _queue
	_queue = []
	for cmd in q:
		_apply(cmd)
	if not _timers.is_empty():
		var keep_t: Array = []
		for tm in _timers:
			if int(tm["at"]) <= tick:
				var cb: Callable = tm["cb"]
				if cb.is_valid():
					cb.call()
			else:
				keep_t.append(tm)
		_timers = keep_t
	if not drops.is_empty():
		_pickup_step()
	if tick % 10 == 0:
		_faction_tick()
	for u in units.duplicate():
		if u.alive:
			u.sim_step(TICK_DT)
	_separate()
	for p in projectiles.duplicate():
		p.sim_step(TICK_DT)
		if p.done:
			projectiles.erase(p)
			p.finish()
	for u in units.duplicate():
		if not u.alive:
			units.erase(u)
			_by_id.erase(u.uid)
			if u.is_building():
				grid.mark_circle(u.sim_pos, u.radius, -1)
			_on_death(u)
			unit_died.emit(u)
	for n in res_nodes.duplicate():
		if not n.alive:
			res_nodes.erase(n)
			_res_by_id.erase(n.uid)
			grid.mark_circle(n.sim_pos, n.radius, -1)
	ticked.emit()


# ---------------- O'lim: tajriba, mukofot, narsalar ----------------

func _on_death(u) -> void:
	var killer: int = u.last_attacker_team
	if killer == 0 or killer == 1:
		if killer != u.team:
			var heroes: Array = []
			for h in units:
				if h.alive and h.team == killer and h.is_hero() and h.sim_pos.distance_to(u.sim_pos) <= 15.0:
					heroes.append(h)
			if not heroes.is_empty():
				var share: int = int(ceil(float(u.xp_reward()) / heroes.size()))
				for h in heroes:
					h.add_xp(share)
			var gold_gain: int = u.bounty
			for h in heroes:
				gold_gain += h.bounty_bonus
			if gold_gain > 0:
				add_resource(killer, "gold", gold_gain)
				if spawner != null and spawner.has_method("spawn_text"):
					spawner.spawn_text(u.sim_pos + Vector3(0, 2.2, 0), "+%d" % gold_gain, Color(1.0, 0.85, 0.2), killer)
	var egg = null
	if u.has_tag("soul") and (u.team == 0 or u.team == 1) and u.life_timer < 0.0:
		for b in units:
			if b.alive and b.team == u.team and b.is_building() and b.complete and bool(b.bdef.get("soul_egg", false)):
				egg = b
				break
	if u.is_hero() and (u.team == 0 or u.team == 1):
		if egg != null:
			_soul_respawn(egg, u.unit_id, u.snapshot())
		else:
			var list: Array = dead_heroes.get(u.team, [])
			list.append(u.snapshot())
			dead_heroes[u.team] = list
			message.emit(u.team, "%s halok bo'ldi — bosh binoda tiriltirish mumkin" % u.display_name)
	elif egg != null:
		_soul_respawn(egg, u.unit_id, {})
	if u.camp_id >= 0 and camps.has(u.camp_id):
		var left := 0
		for o in units:
			if o.alive and o.camp_id == u.camp_id and o != u:
				left += 1
		if left == 0:
			var rarity := str(camps[u.camp_id])
			camps.erase(u.camp_id)
			var item_id := random_item(rarity)
			if item_id != "" and spawner != null and spawner.has_method("spawn_drop"):
				spawner.spawn_drop(item_id, u.sim_pos)


## Jon Tuxumi: elita birlik/qahramon tuxum yonida qayta tiriladi.
func _soul_respawn(egg, id: String, snap: Dictionary) -> void:
	var team: int = egg.team
	var delay: float = 10.0 if upgrade_level(team, "jon_ignasi") > 0 else 20.0
	message.emit(team, "%s Jon Tuxumida %d soniyadan keyin tiriladi" % [GameData.unit_def(id).get("name", id), int(delay)])
	var pos: Vector3 = egg.sim_pos + Vector3(egg.radius + 1.2, 0, 0)
	schedule(delay, func(): _do_soul_respawn(egg, team, id, pos, snap))


func _do_soul_respawn(egg, team: int, id: String, pos: Vector3, snap: Dictionary) -> void:
	if spawner == null:
		return
	var egg_alive: bool = egg != null and is_instance_valid(egg) and egg.alive
	if not egg_alive:
		if not snap.is_empty():
			var list: Array = dead_heroes.get(team, [])
			list.append(snap)
			dead_heroes[team] = list
		return
	var u = spawner.spawn_unit(id, team, pos)
	if u != null and not snap.is_empty() and u.is_hero():
		u.restore(snap)
	if u != null:
		spawner.spawn_effect("ring_dark", pos)


func random_item(rarity: String) -> String:
	var pool: Array = []
	for it in GameData.items():
		if str(it.get("rarity", "")) == rarity:
			pool.append(str(it.get("id", "")))
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]


func _pickup_step() -> void:
	for d in drops.duplicate():
		if not is_instance_valid(d):
			drops.erase(d)
			continue
		for h in units:
			if h.alive and h.is_hero() and h.sim_pos.distance_to(d.sim_pos) <= 1.6 and h.free_slot() >= 0:
				if h.add_item(d.item_id):
					drops.erase(d)
					d.picked()
					break


func _apply(cmd: GameCommand) -> void:
	if cmd.type == GameCommand.Type.CAST or cmd.type == GameCommand.Type.LEARN or cmd.type == GameCommand.Type.USE_ITEM \
			or cmd.type == GameCommand.Type.BUY_ITEM or cmd.type == GameCommand.Type.HIRE:
		_apply_hero_cmd(cmd)
		return
	# Bino bilan bog'liq buyruqlar
	if cmd.type == GameCommand.Type.TRAIN or cmd.type == GameCommand.Type.CANCEL_TRAIN or cmd.type == GameCommand.Type.RALLY \
			or cmd.type == GameCommand.Type.RESEARCH or cmd.type == GameCommand.Type.UPGRADE_BUILDING:
		var b = get_unit(cmd.target_id)
		if b == null or not b.is_building():
			return
		if cmd.type == GameCommand.Type.TRAIN:
			var err: String = b.enqueue(cmd.kind)
			if err != "":
				message.emit(b.team, err)
		elif cmd.type == GameCommand.Type.RESEARCH:
			var err2: String = b.enqueue_research(cmd.kind)
			if err2 != "":
				message.emit(b.team, err2)
		elif cmd.type == GameCommand.Type.UPGRADE_BUILDING:
			var err3: String = b.enqueue_upgrade()
			if err3 != "":
				message.emit(b.team, err3)
		elif cmd.type == GameCommand.Type.CANCEL_TRAIN:
			b.cancel_last()
		else:
			b.set_rally(cmd.target_pos)
		return

	var list: Array = []
	for id in cmd.unit_ids:
		var u = get_unit(id)
		if u != null and not u.is_building():
			list.append(u)
	if list.is_empty():
		return

	if cmd.type == GameCommand.Type.BUILD:
		_apply_build(cmd, list)
		return
	if cmd.type == GameCommand.Type.GATHER:
		var n = get_res(cmd.target_id)
		if n == null:
			return
		for u in list:
			if u.is_worker:
				u.order_gather(n.uid)
			else:
				u.order_move(n.sim_pos + (u.sim_pos - n.sim_pos).normalized() * (n.radius + 1.5), false)
		return
	if cmd.type == GameCommand.Type.HELP_BUILD:
		for u in list:
			if u.is_worker:
				u.order_build(cmd.target_id)
		return

	# Guruh uchun formatsiya: nishon atrofida panjara shaklida joy ajratamiz.
	var offsets := _formation_offsets(list, cmd.target_pos)
	for i in list.size():
		var u = list[i]
		if cmd.type == GameCommand.Type.MOVE:
			u.order_move(cmd.target_pos + offsets[i], false)
		elif cmd.type == GameCommand.Type.ATTACK_MOVE:
			u.order_move(cmd.target_pos + offsets[i], true)
		elif cmd.type == GameCommand.Type.ATTACK:
			u.order_attack(cmd.target_id)
		elif cmd.type == GameCommand.Type.STOP:
			u.order_stop()
		elif cmd.type == GameCommand.Type.HOLD:
			u.order_hold()


func _apply_hero_cmd(cmd: GameCommand) -> void:
	if cmd.type == GameCommand.Type.HIRE:
		var tav = get_unit(cmd.target_id)
		if tav == null or not tav.is_building():
			return
		var err_h: String = tav.hire(cmd.team, cmd.kind)
		if err_h != "":
			message.emit(cmd.team, err_h)
		return
	var h = get_unit(cmd.unit_ids[0]) if not cmd.unit_ids.is_empty() else null
	if h == null or not h.is_hero():
		return
	var err := ""
	if cmd.type == GameCommand.Type.CAST:
		var idx := int(cmd.kind)
		err = h.cast(idx, cmd.target_id, cmd.target_pos)
	elif cmd.type == GameCommand.Type.LEARN:
		err = h.learn(int(cmd.kind))
	elif cmd.type == GameCommand.Type.USE_ITEM:
		err = h.use_item(cmd.target_id)
	elif cmd.type == GameCommand.Type.BUY_ITEM:
		var shop = get_unit(cmd.target_id)
		if shop == null:
			return
		var d := GameData.item_def(cmd.kind)
		if d.is_empty() or not bool(d.get("shop", false)):
			err = "Bu narsa sotilmaydi"
		elif h.sim_pos.distance_to(shop.sim_pos) > shop.radius + 9.0:
			err = "Qahramon do'konga yaqin bo'lishi kerak"
		elif h.free_slot() < 0:
			err = "Inventar to'la"
		elif gold(h.team) < int(d.get("cost", 0)):
			err = "Oltin yetarli emas!"
		else:
			spend(h.team, {"oltin": int(d.get("cost", 0))})
			h.add_item(cmd.kind)
	if err != "":
		message.emit(h.team, err)


func _apply_build(cmd: GameCommand, list: Array) -> void:
	var workers: Array = []
	for u in list:
		if u.is_worker:
			workers.append(u)
	if workers.is_empty() or spawner == null:
		return
	var team: int = workers[0].team
	var bd := GameData.building_def(cmd.kind)
	if bd.is_empty():
		return
	var req_err := meets(team, bd.get("requires", {}))
	if req_err != "":
		message.emit(team, req_err)
		return
	var lim := int(bd.get("limit", 0))
	if lim > 0 and count_buildings(team, cmd.kind) >= lim:
		message.emit(team, "%s ko'pi bilan %d ta bo'ladi" % [bd.get("name", cmd.kind), lim])
		return
	if not can_place(bd, cmd.target_pos):
		message.emit(team, "Bu yerga qurib bo'lmaydi")
		return
	if not mist_ok(team, bd, cmd.target_pos):
		message.emit(team, "Faqat Qora Tuman ichiga qurish mumkin")
		return
	var cost = bd.get("cost", {})
	if not can_afford(team, cost):
		message.emit(team, lack_text(team, cost))
		return
	spend(team, cost)
	var b = spawner.spawn_building(cmd.kind, team, cmd.target_pos, false)
	if b == null:
		refund(team, cost)
		return
	for w in workers:
		w.order_build(b.uid)
	message.emit(team, "%s qurilmoqda" % b.display_name)


func _formation_offsets(list: Array, target: Vector3) -> Array:
	var out: Array = []
	var n := list.size()
	if n == 1:
		out.append(Vector3.ZERO)
		return out
	var center := Vector3.ZERO
	for u in list:
		center += u.sim_pos
	center /= n
	var dir := (target - center)
	dir.y = 0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	var right := Vector3(dir.z, 0, -dir.x)
	var cols := int(ceil(sqrt(float(n))))
	var spacing := 1.5
	# Jangchilar oldinda, uzoqdan otuvchilar orqada turishi uchun saralaymiz.
	var order: Array = list.duplicate()
	order.sort_custom(func(a, b): return a.attack_range < b.attack_range)
	var slot := {}
	for i in order.size():
		var row := i / cols
		var col := i % cols
		var x := (col - (cols - 1) * 0.5) * spacing
		var z := -row * spacing
		slot[order[i]] = right * x + dir * z
	for u in list:
		out.append(slot[u])
	return out


func _separate() -> void:
	var n := units.size()
	for i in n:
		var a = units[i]
		if not a.alive:
			continue
		for j in range(i + 1, n):
			var b = units[j]
			if not b.alive:
				continue
			if a.flying != b.flying:
				continue
			var a_fixed: bool = a.is_holding()
			var b_fixed: bool = b.is_holding()
			if a_fixed and b_fixed:
				continue
			var d: Vector3 = b.sim_pos - a.sim_pos
			d.y = 0
			var min_d: float = a.radius + b.radius
			var dist := d.length()
			if dist >= min_d:
				continue
			if dist < 0.001:
				d = Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
				dist = max(d.length(), 0.001)
			var push_v: Vector3 = d / dist * (min_d - dist)
			if a_fixed:
				b.sim_pos += push_v
			elif b_fixed:
				a.sim_pos -= push_v
			else:
				a.sim_pos -= push_v * 0.5
				b.sim_pos += push_v * 0.5
	# Resurs manbalari (kon, daraxtlar) ham to'siq
	for u in units:
		if not u.alive or u.is_building() or u.flying:
			continue
		for r in res_nodes:
			if not r.alive:
				continue
			var d2: Vector3 = u.sim_pos - r.sim_pos
			d2.y = 0
			var min_d2: float = u.radius + r.radius
			var dist2 := d2.length()
			if dist2 < min_d2 and dist2 > 0.001:
				u.sim_pos += d2 / dist2 * (min_d2 - dist2)
