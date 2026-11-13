class_name Hero
extends Unit
## Qahramon: 10 darajagacha o'sadi (tajriba — XP), har darajada ko'nikma ochkosi, 4 ta qobiliyat
## (3 oddiy × 3 daraja, ULTI 6-darajadan), mana, aura va passivlar, 6 katakli inventar.
## Dushman (AI) qahramonlari qobiliyatlarni o'zi o'rganadi va ishlatadi.
## Bog'liqlik: Unit, AbilityRunner, GameData, Simulation.

const MAX_LEVEL := 10
const INV_SIZE := 6

var hdef: Dictionary = {}
var hero_id: String = ""
var level: int = 1
var xp: int = 0
var skill_points: int = 1
var mana: float = 0.0
var max_mana: float = 0.0
var base_mana: float = 0.0
var mana_regen: float = 0.7
var abilities: Array = []
var ab_levels: Array = []
var ab_cd: Array = []
var inventory: Array = []
var growth: Dictionary = {}
var crit_chance: float = 0.0
var crit_mult: float = 2.0
var bounty_bonus: int = 0
var mercenary: bool = false

var _base_speed: float = 3.0
var _pending: Dictionary = {}
var _ai_think: float = 0.0
var _aura_acc: float = 0.0


func setup_hero(d: Dictionary, team_id: int, pos: Vector3, team_color: Color) -> void:
	setup(d, team_id, pos, team_color)
	hdef = d
	hero_id = unit_id
	mercenary = bool(d.get("mercenary", false))
	var g = d.get("growth", {})
	if g is Dictionary:
		growth = g
	base_mana = float(d.get("mana", 200))
	mana_regen = float(d.get("mana_regen", 0.7))
	_base_speed = move_speed
	var ab = d.get("abilities", [])
	if ab is Array:
		abilities = ab
	ab_levels = []
	ab_cd = []
	for a in abilities:
		ab_levels.append(0)
		ab_cd.append(0.0)
	inventory = []
	for i in INV_SIZE:
		inventory.append(null)
	max_mana = base_mana
	mana = max_mana
	pick_height += 0.3


func is_hero() -> bool:
	return true


func xp_reward() -> int:
	return 100 + 40 * level


func xp_needed() -> int:
	return int(GameData.XP_TABLE[min(level + 1, MAX_LEVEL)])


# ---------------- Ko'rsatkichlar ----------------

func val(i: int, key: String, default_value: float = 0.0) -> float:
	if i < 0 or i >= abilities.size():
		return default_value
	var v = abilities[i].get(key, null)
	if v is Array:
		if v.is_empty():
			return default_value
		var idx: int = clampi(int(ab_levels[i]) - 1, 0, v.size() - 1)
		return float(v[idx])
	if v == null:
		return default_value
	return float(v)


func max_ability_level(i: int) -> int:
	return 2 if bool(abilities[i].get("ult", false)) else 3


func _item_stats() -> Dictionary:
	var out := {"hp": 0.0, "damage": 0.0, "armor": 0.0, "mana": 0.0, "regen": 0.0, "mana_regen": 0.0, "speed": 0.0}
	for it in inventory:
		if it == null:
			continue
		var st = GameData.item_def(str(it["id"])).get("stats", {})
		if st is Dictionary:
			for k in st.keys():
				out[k] = float(out.get(k, 0.0)) + float(st[k])
	return out


func _extra_stats() -> Dictionary:
	var lv := level - 1
	var hp_add: float = float(growth.get("hp", 0)) * lv
	var dmg: float = float(growth.get("damage", 0)) * lv
	var arm: float = float(growth.get("armor", 0)) * lv
	crit_chance = 0.0
	bounty_bonus = 0
	for i in abilities.size():
		if int(ab_levels[i]) <= 0 or str(abilities[i].get("kind", "")) != "passive":
			continue
		var effect := str(abilities[i].get("effect", ""))
		if effect == "passive_armor":
			arm += val(i, "value")
		elif effect == "passive_crit":
			crit_chance = val(i, "value")
			crit_mult = float(abilities[i].get("mult", 2.0))
		elif effect == "passive_bounty":
			bounty_bonus = int(val(i, "value"))
	var st := _item_stats()
	return {"hp": hp_add + st["hp"], "damage": dmg + st["damage"], "armor": arm + st["armor"]}


func recompute_stats() -> void:
	super.recompute_stats()
	var lv := level - 1
	var st := _item_stats()
	var new_max: float = base_mana + float(growth.get("mana", 0)) * lv + st["mana"]
	if new_max > max_mana:
		mana += new_max - max_mana
	max_mana = new_max
	mana = min(mana, max_mana)
	mana_regen = float(hdef.get("mana_regen", 0.7)) + st["mana_regen"]
	hp_regen = float(hdef.get("hp_regen", 0.5)) + st["regen"]
	move_speed = _base_speed * (1.0 + st["speed"])


func _crit_mult() -> float:
	if crit_chance > 0.0 and sim != null and sim.rng.randf() < crit_chance:
		return crit_mult
	return 1.0


# ---------------- Tajriba va o'rganish ----------------

func add_xp(n: int) -> void:
	if level >= MAX_LEVEL or n <= 0:
		return
	xp += n
	var leveled := false
	while level < MAX_LEVEL and xp >= int(GameData.XP_TABLE[level + 1]):
		level += 1
		skill_points += 1
		leveled = true
	if leveled:
		var old_max := max_hp
		recompute_stats()
		hp = min(max_hp, hp + (max_hp - old_max))
		if visual:
			visual.play_levelup()
		if team == 0:
			Audio.play("levelup")
		if sim:
			sim.message.emit(team, "%s %d-darajaga chiqdi!" % [display_name, level])


func can_learn(i: int) -> String:
	if i < 0 or i >= abilities.size():
		return "Qobiliyat yo'q"
	if skill_points <= 0:
		return "Ko'nikma ochkosi yo'q"
	var cur := int(ab_levels[i])
	if cur >= max_ability_level(i):
		return "To'liq o'rganilgan"
	var need: int = 6 + 4 * cur if bool(abilities[i].get("ult", false)) else 2 * cur + 1
	if level < need:
		return "Kerak: %d-daraja" % need
	return ""


func learn(i: int) -> String:
	var err := can_learn(i)
	if err != "":
		return err
	ab_levels[i] = int(ab_levels[i]) + 1
	skill_points -= 1
	recompute_stats()
	return ""


func ai_learn() -> void:
	var guard := 0
	while skill_points > 0 and guard < 8:
		guard += 1
		var pick := -1
		for i in abilities.size():
			if bool(abilities[i].get("ult", false)) and can_learn(i) == "":
				pick = i
		if pick < 0:
			var best_lvl := 99
			for i in abilities.size():
				if can_learn(i) == "" and int(ab_levels[i]) < best_lvl:
					best_lvl = int(ab_levels[i])
					pick = i
		if pick < 0:
			return
		learn(pick)


# ---------------- Qobiliyat ishlatish ----------------

func can_cast(i: int) -> String:
	if i < 0 or i >= abilities.size():
		return "Qobiliyat yo'q"
	if int(ab_levels[i]) <= 0:
		return "Avval o'rganing"
	if str(abilities[i].get("kind", "")) == "passive":
		return "Bu passiv qobiliyat"
	if float(ab_cd[i]) > 0.0:
		return "Tayyor emas (%d s)" % int(ceil(float(ab_cd[i])))
	if mana < val(i, "mana"):
		return "Mana yetarli emas"
	if has_effect("stun"):
		return "Karaxt holatda"
	return ""


func cast(i: int, tid: int, tpos: Vector3) -> String:
	var err := can_cast(i)
	if err != "":
		return err
	var kind := str(abilities[i].get("kind", ""))
	if kind == "none":
		_execute(i, null, sim_pos)
		return ""
	if kind == "unit":
		var t = sim.get_unit(tid)
		if t == null:
			return "Nishon yo'q"
		var want := str(abilities[i].get("target", "enemy"))
		if want == "enemy" and t.team == team:
			return "Dushmanni tanlang"
		if t.invulnerable:
			return "Bu nishonga ta'sir qilib bo'lmaydi"
	_pending = {"i": i, "tid": tid, "pos": tpos}
	self.target_id = -1
	state = State.IDLE
	return ""


func _execute(i: int, t, pos: Vector3) -> void:
	mana -= val(i, "mana")
	ab_cd[i] = val(i, "cooldown", 10.0)
	if visual:
		visual.play_cast()
	Audio.play_at("magic", sim_pos, sim)
	AbilityRunner.run(self, i, t, pos)


func _process_pending(dt: float) -> void:
	var i := int(_pending["i"])
	var a: Dictionary = abilities[i]
	var rng_cast: float = float(a.get("range", 6.0))
	var t = null
	var tpos: Vector3 = _pending["pos"]
	if str(a.get("kind", "")) == "unit":
		t = sim.get_unit(int(_pending["tid"]))
		if t == null:
			_pending = {}
			return
		tpos = t.sim_pos
	var extra: float = t.radius if t != null else 0.0
	if sim_pos.distance_to(tpos) > rng_cast + extra + radius:
		_move_to(tpos, dt, rng_cast * 0.9)
		return
	_face(tpos)
	if can_cast(i) != "":
		_pending = {}
		return
	_execute(i, t, tpos)
	_pending = {}


func cancel_cast() -> void:
	_pending = {}


func order_move(pos: Vector3, attack_move: bool) -> void:
	_pending = {}
	super.order_move(pos, attack_move)


func order_attack(id: int) -> void:
	_pending = {}
	super.order_attack(id)


func order_stop() -> void:
	_pending = {}
	super.order_stop()


# ---------------- Asosiy sikl ----------------

func sim_step(dt: float) -> void:
	mana = min(max_mana, mana + (mana_regen + eff("mana_regen")) * dt)
	for k in ab_cd.size():
		ab_cd[k] = max(0.0, float(ab_cd[k]) - dt)
	_aura_acc -= dt
	if _aura_acc <= 0.0:
		_aura_acc = 0.5
		_aura_step()
	if team != 0:
		_ai_think -= dt
		if _ai_think <= 0.0:
			_ai_think = 0.5
			ai_learn()
			_ai_cast()
	if not _pending.is_empty() and not has_effect("stun"):
		prev_pos = sim_pos
		prev_facing = facing
		_moving_now = false
		_tick_effects(dt)
		_process_pending(dt)
		sim_pos = _clamp_map(sim_pos)
		return
	super.sim_step(dt)


func _aura_step() -> void:
	for i in abilities.size():
		if int(ab_levels[i]) <= 0 or str(abilities[i].get("effect", "")) != "aura":
			continue
		var r: float = float(abilities[i].get("radius", 9.0))
		var buff := str(abilities[i].get("buff", ""))
		var v := val(i, "value")
		for o in sim.units:
			if o.alive and o.team == team and not o.is_building() and o.sim_pos.distance_to(sim_pos) <= r:
				o.add_effect(buff, 0.7, v)


## Dushman qahramoni uchun oddiy taktika: dushmanlar to'plangan joyga qobiliyat ishlatish.
func _ai_cast() -> void:
	if not _pending.is_empty() or has_effect("stun"):
		return
	if sim.rng.randf() > float(sim.ai_cast_chance.get(team, 1.0)):
		return
	var enemies: Array = []
	for o in sim.units:
		if o.alive and o.team != team and not o.invulnerable and o.sim_pos.distance_to(sim_pos) < 16.0:
			if sim.fog == null or sim.fog.sees(team, o.sim_pos):
				enemies.append(o)
	if enemies.is_empty():
		return
	for i in abilities.size():
		if can_cast(i) != "":
			continue
		var a: Dictionary = abilities[i]
		var kind := str(a.get("kind", ""))
		var effect := str(a.get("effect", ""))
		var is_ult := bool(a.get("ult", false))
		var radius_a: float = float(a.get("radius", 3.0))
		var rng_a: float = float(a.get("range", 6.0))
		if kind == "unit":
			var best = null
			var bd := INF
			for e in enemies:
				if e.is_building():
					continue
				var d: float = e.sim_pos.distance_to(sim_pos) - (6.0 if e.is_hero() else 0.0)
				if d < bd and e.sim_pos.distance_to(sim_pos) <= rng_a + 3.0:
					bd = d
					best = e
			if best != null:
				cast(i, best.uid, best.sim_pos)
				return
		elif kind == "point" and effect != "reveal":
			for e in enemies:
				if e.sim_pos.distance_to(sim_pos) > rng_a + 2.0:
					continue
				var n := 0
				for o in enemies:
					if o.sim_pos.distance_to(e.sim_pos) <= radius_a:
						n += 1
				if n >= 2 or e.is_hero():
					cast(i, -1, e.sim_pos)
					return
		elif kind == "none":
			var near := 0
			for e in enemies:
				if e.sim_pos.distance_to(sim_pos) <= max(radius_a, 7.0):
					near += 1
			var need: int = 3 if is_ult else 2
			if effect == "self_buff" and hp < max_hp * 0.6:
				need = 1
			if near >= need:
				cast(i, -1, sim_pos)
				return


# ---------------- Inventar ----------------

func free_slot() -> int:
	for i in INV_SIZE:
		if inventory[i] == null:
			return i
	return -1


func add_item(id: String) -> bool:
	var slot := free_slot()
	if slot < 0:
		return false
	var d := GameData.item_def(id)
	if d.is_empty():
		return false
	inventory[slot] = {"id": id, "charges": int(d.get("charges", 0))}
	recompute_stats()
	if sim:
		sim.message.emit(team, "%s: %s olindi" % [display_name, d.get("name", id)])
	return true


func use_item(slot: int) -> String:
	if slot < 0 or slot >= INV_SIZE or inventory[slot] == null:
		return "Bo'sh katak"
	var it: Dictionary = inventory[slot]
	var d := GameData.item_def(str(it["id"]))
	if not bool(d.get("consumable", false)):
		return str(d.get("desc", ""))
	var use = d.get("use", {})
	var kind := str(use.get("type", ""))
	var v: float = float(use.get("value", 0))
	if kind == "heal":
		hp = min(max_hp, hp + v)
		if sim.spawner:
			sim.spawner.spawn_effect("heal", sim_pos + Vector3(0, pick_height + 0.5, 0))
	elif kind == "mana":
		mana = min(max_mana, mana + v)
	elif kind == "teleport":
		var h = sim.nearest_dropoff(team, sim_pos)
		if h == null:
			return "Bosh bino yo'q"
		sim_pos = h.sim_pos + Vector3(h.radius + 1.5, 0, h.radius + 1.5)
		prev_pos = sim_pos
		state = State.IDLE
	elif kind == "heal_area" or kind == "buff_area":
		var r: float = float(use.get("radius", 8))
		for o in sim.units:
			if o.alive and o.team == team and not o.is_building() and o.sim_pos.distance_to(sim_pos) <= r:
				if kind == "heal_area":
					o.hp = min(o.max_hp, o.hp + v)
				else:
					o.add_effect(str(use.get("buff", "")), float(use.get("duration", 10)), v)
		if sim.spawner:
			sim.spawner.spawn_effect("heal" if kind == "heal_area" else "ring", sim_pos + Vector3(0, 0.5, 0))
	elif kind == "self_buff":
		add_effect(str(use.get("buff", "")), float(use.get("duration", 10)), v)
	it["charges"] = int(it["charges"]) - 1
	if int(it["charges"]) <= 0:
		inventory[slot] = null
		recompute_stats()
	return ""


# ---------------- Tiriltirish uchun holat ----------------

func snapshot() -> Dictionary:
	return {"id": hero_id, "level": level, "xp": xp, "skill_points": skill_points,
		"ab_levels": ab_levels.duplicate(), "inventory": inventory.duplicate(true)}


func restore(s: Dictionary) -> void:
	level = int(s.get("level", 1))
	xp = int(s.get("xp", 0))
	skill_points = int(s.get("skill_points", 0))
	var al = s.get("ab_levels", [])
	if al is Array and al.size() == ab_levels.size():
		ab_levels = al.duplicate()
	var inv = s.get("inventory", [])
	if inv is Array and inv.size() == INV_SIZE:
		inventory = inv.duplicate(true)
	recompute_stats()
	hp = max_hp
	mana = max_mana
