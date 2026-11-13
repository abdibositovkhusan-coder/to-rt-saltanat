class_name Unit
extends Node3D
## Bitta jangovar birlik: holatlar mashinasi (turish, yurish, hujum-yurish, hujum, ushlab turish),
## zarar hisoblash, regeneratsiya, o'lim. Mantiq sim_step() ichida (20 Hz), ko'rinish update_visual() da.
## Ishchilar uchun: yig'ish (GATHER), topshirish (RETURN), qurish (BUILD).
## Bog'liqlik: Simulation, UnitVisual, Projectile, GameData, ResourceNode, Building.

enum State { IDLE, MOVING, ATTACK_MOVING, ATTACKING, HOLD, DEAD, GATHER, RETURN, BUILD }

const MAP_HALF := 58.0

var uid: int = -1
var sim = null
var team: int = 0
var def: Dictionary = {}
var unit_id: String = ""
var display_name: String = ""
var role: String = ""

var max_hp: float = 100.0
var hp: float = 100.0
var hp_regen: float = 0.0
var armor: float = 0.0
var armor_type: String = "orta"
var damage_min: int = 5
var damage_max: int = 8
var attack_type: String = "oddiy"
var attack_range: float = 1.0
var attack_cooldown: float = 1.5
var move_speed: float = 3.0
var acquire_range: float = 8.0
var radius: float = 0.5
var bar_height: float = 2.3
var projectile_def: Dictionary = {}
var food: int = 0
var sight: float = 10.0
var fire_height: float = -1.0
var fog_visible: bool = true
var seen_by_enemy: bool = false
var tags: Array = []
var flying: bool = false
var min_range: float = 0.0
var heal_amount: float = 0.0
var heal_range: float = 0.0
var heal_cooldown: float = 2.0
var slow_timer: float = 0.0
var tier: int = 0
var pick_height: float = 1.0

# Asosiy (yaxshilanmagan) qiymatlar — texnologiyalar shular ustiga qo'shiladi
var base_damage_min: float = 0.0
var base_damage_max: float = 0.0
var base_armor: float = 0.0
var base_attack_range: float = 0.0
var base_heal: float = 0.0
var base_max_hp: float = 100.0
var _heal_cd: float = 0.0

# Holat effektlari: nom -> {"t": qolgan vaqt, "v": qiymat}
# stun, disarm, dmg_bonus, armor_bonus, speed_bonus, vuln, dr, lifesteal, mana_regen, no_death
var effects: Dictionary = {}
var last_attacker_team: int = -1
var xp_value: int = 0
var bounty: int = 0
var leash: float = 0.0
var home_pos: Vector3 = Vector3.ZERO
var _returning: bool = false
var camp_id: int = -1
var script_tag: String = ""   # missiya skripti uchun teg
var invulnerable: bool = false
var faction: String = ""
var rage: float = 0.0
var life_timer: float = -1.0
var on_hit: Dictionary = {}
var splash_melee: float = 0.0
var aura_damage: Dictionary = {}
var summoner: Dictionary = {}
var infinite_wood: bool = false
var _summon_cd: float = 5.0
var _summons: Array = []
var _aura_dmg_acc: float = 0.0
var _reborn: bool = false

# Ishchi
var is_worker: bool = false
var carry_max: int = 10
var carry_kind: String = ""
var carry_amount: int = 0
var gold_time: float = 1.6
var wood_time: float = 2.6
var gather_node_id: int = -1
var gather_kind: String = "gold"
var build_target_id: int = -1
var _work_timer: float = 0.0
var _anim_timer: float = 0.0

var alive: bool = true
var selected: bool = false
var state: int = State.IDLE
var sim_pos: Vector3 = Vector3.ZERO
var prev_pos: Vector3 = Vector3.ZERO
var facing: float = 0.0
var prev_facing: float = 0.0
var move_target: Vector3 = Vector3.ZERO
var target_id: int = -1
var last_attacker_id: int = -1

var _resume_state: int = State.IDLE
var _cooldown: float = 0.0
var _forced_target: bool = false
var _moving_now: bool = false
var visual: UnitVisual


func setup(unit_def: Dictionary, team_id: int, pos: Vector3, team_color: Color) -> void:
	def = unit_def
	team = team_id
	unit_id = str(def.get("id", "unit"))
	display_name = str(def.get("name", unit_id))
	role = str(def.get("role", ""))
	max_hp = float(def.get("hp", 100))
	hp = max_hp
	hp_regen = float(def.get("hp_regen", 0.0))
	armor = float(def.get("armor", 0))
	armor_type = str(def.get("armor_type", "orta"))
	var dmg = def.get("damage", [5, 8])
	damage_min = int(dmg[0])
	damage_max = int(dmg[1])
	attack_type = str(def.get("attack_type", "oddiy"))
	attack_range = float(def.get("attack_range", 1.0))
	attack_cooldown = float(def.get("attack_cooldown", 1.5))
	move_speed = float(def.get("move_speed", 3.0))
	acquire_range = float(def.get("acquire_range", 8.0))
	radius = float(def.get("radius", 0.5))
	bar_height = float(def.get("bar_height", 2.3))
	var pd = def.get("projectile", {})
	if pd is Dictionary:
		projectile_def = pd
	food = int(def.get("food", 0))
	sight = float(def.get("sight", 10.0))
	xp_value = int(def.get("xp", 20 + food * 12))
	faction = str(def.get("faction", ""))
	var oh = def.get("on_hit", {})
	if oh is Dictionary:
		on_hit = oh
	splash_melee = float(def.get("splash_melee", 0.0))
	var ad = def.get("aura_damage", {})
	if ad is Dictionary:
		aura_damage = ad
	var sm = def.get("summoner", {})
	if sm is Dictionary:
		summoner = sm
	bounty = int(def.get("bounty", 0))
	leash = float(def.get("leash", 0.0))
	home_pos = pos
	var tg = def.get("tags", [])
	if tg is Array:
		tags = tg.duplicate()
	flying = bool(def.get("flying", false))
	min_range = float(def.get("min_range", 0.0))
	var hl = def.get("healer", null)
	if hl is Dictionary:
		heal_amount = float(hl.get("amount", 15))
		heal_range = float(hl.get("range", 6))
		heal_cooldown = float(hl.get("cooldown", 2.0))
	var wk = def.get("worker", null)
	if wk is Dictionary:
		is_worker = true
		carry_max = int(wk.get("carry", 10))
		gold_time = float(wk.get("gold_time", 1.6))
		wood_time = float(wk.get("wood_time", 2.6))
		infinite_wood = bool(wk.get("infinite_wood", false))
	sim_pos = pos
	prev_pos = pos
	position = pos
	visual = UnitVisual.new()
	add_child(visual)
	var look = def.get("look", {})
	if not (look is Dictionary):
		look = {}
	visual.build(look, team_color, team)
	pick_height = 1.0 * visual.scale_factor + float(look.get("fly_height", 0.0))
	capture_base()


## Texnologiyalar uchun asosiy qiymatlarni saqlab qo'yadi.
func capture_base() -> void:
	base_damage_min = damage_min
	base_damage_max = damage_max
	base_armor = armor
	base_attack_range = attack_range
	base_heal = heal_amount
	base_max_hp = max_hp


func has_tag(t: String) -> bool:
	return tags.has(t)


func _has_any_tag(list) -> bool:
	if not (list is Array):
		return false
	for t in list:
		if tags.has(str(t)):
			return true
	return false


## Jamoa texnologiyalarini hisobga olib, ko'rsatkichlarni qayta hisoblaydi.
func recompute_stats() -> void:
	if sim == null:
		return
	var dmg_add := 0.0
	var armor_add := 0.0
	var range_add := 0.0
	var heal_add := 0.0
	var hp_pct := 0.0
	var team_up: Dictionary = sim.upgrades.get(team, {})
	for id in team_up.keys():
		var lvl := int(team_up[id])
		if lvl <= 0:
			continue
		var ud := GameData.upgrade_def(str(id))
		var effects = ud.get("effects", [])
		if not (effects is Array):
			continue
		for e in effects:
			if not _has_any_tag(e.get("tags", [])):
				continue
			var add: float = float(e.get("add", 0)) * lvl
			var stat := str(e.get("stat", ""))
			if stat == "damage":
				dmg_add += add
			elif stat == "armor":
				armor_add += add
			elif stat == "range":
				range_add += add
			elif stat == "heal":
				heal_add += add
			elif stat == "hp_pct":
				hp_pct += add
	var ex := _extra_stats()
	dmg_add += float(ex.get("damage", 0.0))
	armor_add += float(ex.get("armor", 0.0))
	if base_damage_max > 0.0:
		damage_min = int(base_damage_min + dmg_add)
		damage_max = int(base_damage_max + dmg_add)
	armor = base_armor + armor_add
	if base_attack_range > 0.0:
		attack_range = base_attack_range + range_add
	if base_heal > 0.0:
		heal_amount = base_heal + heal_add
	var new_max: float = (base_max_hp + float(ex.get("hp", 0.0))) * (1.0 + hp_pct / 100.0)
	if abs(new_max - max_hp) > 0.01:
		var ratio: float = hp / max(max_hp, 1.0)
		max_hp = new_max
		hp = max_hp * ratio


func is_hero() -> bool:
	return false


func xp_reward() -> int:
	return xp_value


## Qahramonlar uchun qo'shimcha ko'rsatkichlar (daraja, passivlar, narsalar).
func _extra_stats() -> Dictionary:
	return {}


func _crit_mult() -> float:
	return 1.0


# ---------------- Holat effektlari ----------------

func add_effect(effect_name: String, duration: float, value: float = 1.0) -> void:
	var cur = effects.get(effect_name, null)
	if cur == null:
		effects[effect_name] = {"t": duration, "v": value}
	else:
		cur["t"] = max(float(cur["t"]), duration)
		cur["v"] = max(float(cur["v"]), value)
	if effect_name == "stun" and visual:
		visual.set_stunned(true)


func has_effect(effect_name: String) -> bool:
	return effects.has(effect_name)


func eff(effect_name: String) -> float:
	var e = effects.get(effect_name, null)
	if e == null:
		return 0.0
	return float(e["v"])


func _tick_effects(dt: float) -> void:
	if effects.is_empty():
		return
	for k in effects.keys():
		var e: Dictionary = effects[k]
		e["t"] = float(e["t"]) - dt
		if float(e["t"]) <= 0.0:
			effects.erase(k)
			if k == "stun" and visual:
				visual.set_stunned(false)


## Davomiy ta'sirlar: tiklanish, qon ketishi, vaqtli hayot, aura zarari, chaqiruv.
func _ongoing_effects(dt: float) -> void:
	var rg := eff("regen")
	if rg > 0.0 and hp < max_hp:
		hp = min(max_hp, hp + rg * dt)
	var bl := eff("bleed")
	if bl > 0.0:
		hp -= bl * dt
		if hp <= 0.0:
			_die()
			return
	if life_timer > 0.0:
		life_timer -= dt
		if life_timer <= 0.0:
			last_attacker_team = -1
			_die()
			return
	if not aura_damage.is_empty():
		_aura_dmg_acc -= dt
		if _aura_dmg_acc <= 0.0:
			_aura_dmg_acc = 0.5
			var r: float = float(aura_damage.get("radius", 3.0))
			var dps: float = float(aura_damage.get("dps", 10.0))
			for o in sim.units:
				if o.alive and o.team != team and not o.invulnerable and o.sim_pos.distance_to(sim_pos) <= r + o.radius:
					o.take_damage(dps * 0.5, self)
					if aura_damage.has("weak"):
						o.add_effect("weak", 1.0, float(aura_damage["weak"]))
	if not summoner.is_empty():
		_summon_cd -= dt
		if _summon_cd <= 0.0 and state == State.ATTACKING:
			var live: Array = []
			for id in _summons:
				if sim.get_unit(id) != null:
					live.append(id)
			_summons = live
			if _summons.size() < int(summoner.get("max", 2)) and sim.spawner != null:
				_summon_cd = float(summoner.get("cooldown", 14))
				var s_unit = sim.spawner.spawn_unit(str(summoner.get("unit", "")), team, sim_pos + Vector3(sim.rng.randf_range(-1.5, 1.5), 0, sim.rng.randf_range(-1.5, 1.5)))
				if s_unit != null:
					s_unit.life_timer = float(summoner.get("life", 30))
					s_unit.xp_value = 5
					_summons.append(s_unit.uid)
					if visual:
						visual.play_cast()
					sim.spawner.spawn_effect("ring_dark", s_unit.sim_pos)


## Trollar: G'azab Olovi.
func add_rage(amount: float) -> void:
	if not tags.has("rage") or not alive:
		return
	if sim != null and sim.upgrade_level(team, "qadimgi_totem") > 0:
		amount *= 1.5
	rage += amount
	if rage >= 100.0:
		rage = 0.0
		add_effect("dmg_bonus", 8.0, 0.4)
		add_effect("enraged", 8.0, 1.0)
		if visual:
			var v = visual
			var base: Vector3 = v.scale
			v.create_tween().tween_property(v, "scale", base * 1.25, 0.3)
			if sim != null:
				sim.schedule(8.0, func(): Unit._unrage_visual(v, base))
		if sim != null and sim.spawner != null:
			sim.spawner.spawn_effect("blast", sim_pos + Vector3(0, 1.5, 0))


static func _unrage_visual(v, base: Vector3) -> void:
	if v != null and is_instance_valid(v):
		v.create_tween().tween_property(v, "scale", base, 0.4)


func effective_armor() -> float:
	return armor + eff("armor_bonus")


func can_hit_air() -> bool:
	return is_ranged()


func apply_slow(seconds: float) -> void:
	slow_timer = max(slow_timer, seconds)
	if visual:
		visual.set_slowed(true)


func counts_as(_id: String) -> bool:
	return false


func is_ranged() -> bool:
	return not projectile_def.is_empty()


func is_building() -> bool:
	return false


func is_holding() -> bool:
	return state == State.HOLD or (state == State.ATTACKING and _resume_state == State.HOLD)


func voice(kind: String) -> String:
	var lines = def.get("voice_" + kind, [])
	if lines is Array and lines.size() > 0:
		return str(lines[randi() % lines.size()])
	return ""


# ---------------- Buyruqlar ----------------

func order_move(pos: Vector3, attack_move: bool) -> void:
	move_target = _clamp_map(pos)
	target_id = -1
	_forced_target = false
	state = State.ATTACK_MOVING if attack_move else State.MOVING


func order_attack(id: int) -> void:
	target_id = id
	_forced_target = true
	_resume_state = State.IDLE
	state = State.ATTACKING


func order_gather(node_id: int) -> void:
	if not is_worker:
		return
	var n = sim.get_res(node_id) if sim else null
	if n != null:
		gather_kind = n.kind
	gather_node_id = node_id
	target_id = -1
	_work_timer = 0.0
	state = State.GATHER


func order_build(building_id: int) -> void:
	if not is_worker:
		return
	build_target_id = building_id
	target_id = -1
	state = State.BUILD


func order_return() -> void:
	if is_worker and carry_amount > 0:
		state = State.RETURN


func order_stop() -> void:
	target_id = -1
	_forced_target = false
	state = State.IDLE


func order_hold() -> void:
	target_id = -1
	_forced_target = false
	state = State.HOLD


# ---------------- Mantiq (20 Hz) ----------------

func sim_step(dt: float) -> void:
	prev_pos = sim_pos
	prev_facing = facing
	_moving_now = false
	if hp < max_hp and hp_regen > 0.0:
		hp = min(max_hp, hp + hp_regen * dt)
	_cooldown = max(0.0, _cooldown - dt)
	_tick_effects(dt)
	_ongoing_effects(dt)
	if not alive:
		return
	if has_effect("stun"):
		sim_pos = _clamp_map(sim_pos)
		return
	if leash > 0.0 and _leash_step(dt):
		sim_pos = _clamp_map(sim_pos)
		return
	if slow_timer > 0.0:
		slow_timer -= dt
		if slow_timer <= 0.0 and visual:
			visual.set_slowed(false)
	if heal_amount > 0.0 and state != State.DEAD:
		_heal_step(dt)

	if has_effect("enraged") and state != State.ATTACKING:
		_try_acquire(acquire_range + 6.0, State.IDLE)
	match state:
		State.IDLE:
			if not is_worker:
				_try_acquire(acquire_range, State.IDLE)
		State.HOLD:
			_try_acquire(attack_range + radius + 0.5, State.HOLD)
		State.MOVING:
			if _move_to(move_target, dt, 0.25):
				state = State.IDLE
		State.ATTACK_MOVING:
			if not _try_acquire(acquire_range, State.ATTACK_MOVING):
				if _move_to(move_target, dt, 0.25):
					state = State.IDLE
		State.ATTACKING:
			_do_attacking(dt)
		State.GATHER:
			_do_gather(dt)
		State.RETURN:
			_do_return(dt)
		State.BUILD:
			_do_build(dt)
	sim_pos = _clamp_map(sim_pos)


## Neytral yirtqichlar lageridan uzoqlashsa, qaytib, sog'ayib oladi.
func _leash_step(dt: float) -> bool:
	if _returning:
		hp = min(max_hp, hp + max_hp * 0.25 * dt)
		if _step_towards(home_pos, dt, 0.5):
			_returning = false
			state = State.IDLE
		return true
	if sim_pos.distance_to(home_pos) > leash:
		_returning = true
		target_id = -1
		state = State.IDLE
		return true
	return false


func _try_acquire(r: float, resume: int) -> bool:
	if damage_max <= 0:
		return false
	var e = sim.nearest_enemy(self, r)
	if e == null:
		return false
	target_id = e.uid
	_forced_target = false
	_resume_state = resume
	state = State.ATTACKING
	return true


func _do_attacking(dt: float) -> void:
	var t = sim.get_unit(target_id)
	if t == null:
		target_id = -1
		_forced_target = false
		state = _resume_state
		# Yaqinda boshqa dushman bo'lsa, darhol unga o'tamiz.
		if state == State.IDLE or state == State.ATTACK_MOVING:
			_try_acquire(acquire_range, state)
		return
	if t.flying and not can_hit_air():
		target_id = -1
		state = _resume_state
		return
	var d: float = sim_pos.distance_to(t.sim_pos)
	var reach: float = attack_range + radius + t.radius
	if min_range > 0.0 and d < min_range:
		# Juda yaqin — manjaniq ota olmaydi
		if not _forced_target:
			target_id = -1
			state = _resume_state
		return
	if d > reach:
		if _resume_state == State.HOLD:
			target_id = -1
			state = State.HOLD
			return
		# Juda uzoqqa qochgan dushmanni (majburiy bo'lmasa) quvlamaymiz.
		if not _forced_target and d > acquire_range * 1.8:
			target_id = -1
			state = _resume_state
			return
		_move_to(t.sim_pos, dt, reach * 0.9)
		return
	_face(t.sim_pos)
	if has_effect("disarm"):
		return
	if _cooldown <= 0.0:
		_cooldown = attack_cooldown
		if visual:
			visual.play_attack(is_ranged())
		add_rage(6.0)
		if is_ranged():
			_fire_projectile(t)
		else:
			var dmg := roll_damage(t)
			t.take_damage(dmg, self)
			Audio.play_at("sword" if damage_max < 30 else "hit", sim_pos, sim)
			var ls := eff("lifesteal")
			if ls > 0.0:
				hp = min(max_hp, hp + dmg * ls)
			_apply_on_hit(t)
			if splash_melee > 0.0:
				for o in sim.units:
					if o != t and o.alive and o.team != team and not o.invulnerable and o.sim_pos.distance_to(t.sim_pos) <= splash_melee + o.radius:
						o.take_damage(dmg * 0.5, self)


# ---------------- Ishchi mantiqi ----------------

func _do_gather(dt: float) -> void:
	var n = sim.get_res(gather_node_id)
	if n == null:
		n = sim.nearest_resource(gather_kind, sim_pos, 18.0)
		if n == null:
			state = State.RETURN if carry_amount > 0 else State.IDLE
			return
		gather_node_id = n.uid
	if carry_amount > 0 and carry_kind != n.kind:
		carry_amount = 0
		_update_carry_visual()
	if carry_amount >= carry_max:
		state = State.RETURN
		return
	var reach: float = n.radius + radius + 0.35
	if sim_pos.distance_to(n.sim_pos) > reach:
		_move_to(n.sim_pos, dt, reach - 0.1)
		_work_timer = 0.0
		return
	_face(n.sim_pos)
	_work_timer += dt
	_anim_timer -= dt
	if _anim_timer <= 0.0 and visual:
		_anim_timer = 0.8
		visual.play_attack(false)
	var need: float = gold_time if n.kind == "gold" else wood_time
	if _work_timer >= need:
		_work_timer = 0.0
		var got: int = n.take(carry_max, not (infinite_wood and n.kind == "wood"))
		if got > 0:
			carry_kind = n.kind
			carry_amount = got
			_update_carry_visual()
			state = State.RETURN


func _do_return(dt: float) -> void:
	var h = sim.nearest_dropoff(team, sim_pos)
	if h == null:
		state = State.IDLE
		return
	var reach: float = h.radius + radius + 0.5
	if sim_pos.distance_to(h.sim_pos) > reach:
		_move_to(h.sim_pos, dt, reach - 0.1)
		return
	sim.add_resource(team, carry_kind, carry_amount)
	carry_amount = 0
	_update_carry_visual()
	state = State.GATHER


func _do_build(dt: float) -> void:
	var b = sim.get_unit(build_target_id)
	if b == null or not b.is_building() or b.complete:
		build_target_id = -1
		state = State.IDLE
		if b != null and b.is_building() and b.dropoff and carry_amount > 0:
			state = State.RETURN
		return
	var reach: float = b.radius + radius + 0.5
	if sim_pos.distance_to(b.sim_pos) > reach:
		_move_to(b.sim_pos, dt, reach - 0.1)
		return
	_face(b.sim_pos)
	b.construct(dt)
	_anim_timer -= dt
	if _anim_timer <= 0.0 and visual:
		_anim_timer = 0.7
		visual.play_attack(false)


func _heal_step(dt: float) -> void:
	_heal_cd -= dt
	if _heal_cd > 0.0:
		return
	if state != State.IDLE and state != State.HOLD and state != State.ATTACK_MOVING and state != State.MOVING:
		return
	var best = null
	var best_missing := 1.0
	for o in sim.units:
		if not o.alive or o.team != team or o.is_building():
			continue
		if sim_pos.distance_to(o.sim_pos) > heal_range + o.radius:
			continue
		var missing: float = o.max_hp - o.hp
		if missing > best_missing:
			best_missing = missing
			best = o
	if best == null:
		_heal_cd = 0.4
		return
	_heal_cd = heal_cooldown
	best.hp = min(best.max_hp, best.hp + heal_amount)
	_face(best.sim_pos)
	if visual:
		visual.play_attack(false)
	if sim.spawner != null and sim.spawner.has_method("spawn_effect"):
		sim.spawner.spawn_effect("heal", best.sim_pos + Vector3(0, best.pick_height + 0.6, 0))


func _update_carry_visual() -> void:
	if visual:
		visual.set_carry(carry_kind if carry_amount > 0 else "")


func _apply_on_hit(t) -> void:
	if on_hit.is_empty() or t == null or not t.alive:
		return
	if on_hit.has("slow"):
		t.apply_slow(float(on_hit["slow"]))
	if on_hit.has("bleed"):
		t.add_effect("bleed", float(on_hit.get("bleed_time", 4)), float(on_hit["bleed"]))
	if on_hit.has("weak"):
		t.add_effect("weak", float(on_hit.get("weak_time", 4)), float(on_hit["weak"]))


func roll_damage(target) -> float:
	var base: float = float(sim.rng.randi_range(damage_min, damage_max))
	base *= (1.0 + eff("dmg_bonus")) * _crit_mult() * (1.0 - clamp(eff("weak"), 0.0, 0.8))
	var mult: float = GameData.damage_mult(attack_type, target.armor_type)
	var a: float = target.effective_armor()
	var reduction: float = 0.0
	if a >= 0.0:
		reduction = (a * 0.06) / (1.0 + a * 0.06)
	else:
		reduction = -(1.0 - pow(0.94, -a))
	return max(1.0, base * mult * (1.0 - reduction))


func _fire_projectile(t) -> void:
	var p := Projectile.new()
	get_parent().add_child(p)
	var fh: float = fire_height if fire_height > 0.0 else 1.4 * visual.scale_factor
	var start: Vector3 = sim_pos + Vector3(0, fh, 0)
	p.launch(self, t, start, roll_damage(t), projectile_def)
	sim.add_projectile(p)
	var pk: String = str(projectile_def.get("kind", "arrow"))
	Audio.play_at("arrow" if pk == "arrow" or pk == "spear" else ("hit" if pk == "rock" else "magic"), sim_pos, sim)


func take_damage(amount: float, attacker) -> void:
	if not alive or invulnerable:
		return
	amount *= (1.0 + eff("vuln")) * (1.0 - clamp(eff("dr"), 0.0, 0.9))
	hp -= amount
	add_rage(4.0)
	if attacker != null and is_instance_valid(attacker):
		last_attacker_team = attacker.team
	if visual:
		visual.flash_hit()
	if attacker != null and is_instance_valid(attacker):
		last_attacker_id = attacker.uid
		# Bekor turgan birlik o'ziga hujum qilganga javob qaytaradi.
		if state == State.IDLE:
			target_id = attacker.uid
			_forced_target = false
			_resume_state = State.IDLE
			state = State.ATTACKING
	if hp <= 0.0 and has_effect("no_death"):
		hp = 1.0
	if hp <= 0.0 and bool(def.get("rebirth", false)) and not _reborn:
		_reborn = true
		hp = max_hp
		if sim != null and sim.spawner != null:
			sim.spawner.spawn_effect("blast", sim_pos + Vector3(0, 2.0, 0))
			sim.message.emit(team, "%s kuldan qayta tug'ildi!" % display_name)
		return
	if hp <= 0.0:
		_die()


func _die() -> void:
	hp = 0.0
	alive = false
	state = State.DEAD
	selected = false
	if visual:
		visual.set_selected(false)
		visual.play_death()
	if sim != null:
		Audio.play_at("explosion" if is_building() else "death", sim_pos, sim)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(self, "position:y", -1.5, 1.2)
	tw.tween_callback(queue_free)


var _path := PackedVector3Array()
var _path_i: int = 0
var _path_goal: Vector3 = Vector3(INF, 0, INF)
var _repath_cd: float = 0.0


## To'siqlarni aylanib o'tib maqsadga yurish. Yetib kelganda (yoki yaqinroq borib bo'lmasa) true.
func _move_to(goal: Vector3, dt: float, stop_dist: float) -> bool:
	var flat := Vector3(goal.x, 0, goal.z)
	if sim_pos.distance_to(flat) <= stop_dist:
		_path = PackedVector3Array()
		return true
	_repath_cd -= dt
	if flying:
		return _step_towards(flat, dt, stop_dist)
	var grid = sim.grid if sim else null
	if grid == null or grid.line_clear(sim_pos, flat, stop_dist + 0.3):
		_path = PackedVector3Array()
		return _step_towards(flat, dt, stop_dist)
	if _path.is_empty() or _path_goal.distance_to(flat) > 1.5:
		if _repath_cd <= 0.0:
			_repath_cd = 0.6
			_path = grid.find_path(sim_pos, flat)
			_path_i = 0
			_path_goal = flat
		if _path.is_empty():
			return _step_towards(flat, dt, stop_dist)
	while _path_i < _path.size() - 1 and sim_pos.distance_to(_path[_path_i]) < 0.6:
		_path_i += 1
	if _path_i < _path.size() - 1 and grid.line_clear(sim_pos, _path[_path_i + 1], 0.0):
		_path_i += 1
	var wp: Vector3 = _path[_path_i]
	if _path_i >= _path.size() - 1:
		if _step_towards(wp, dt, 0.3):
			_path = PackedVector3Array()
			return true
		return false
	_step_towards(wp, dt, 0.1)
	return false


func _step_towards(target: Vector3, dt: float, stop_dist: float) -> bool:
	var d: Vector3 = target - sim_pos
	d.y = 0
	var dist := d.length()
	if dist <= stop_dist:
		return true
	var stepv: float = move_speed * dt * (0.55 if slow_timer > 0.0 else 1.0) * (1.0 + eff("speed_bonus"))
	_face(target)
	_moving_now = true
	if stepv >= dist:
		sim_pos = Vector3(target.x, 0, target.z)
		return true
	sim_pos += d / dist * stepv
	return false


func _face(target: Vector3) -> void:
	var d: Vector3 = target - sim_pos
	if Vector2(d.x, d.z).length() > 0.01:
		facing = atan2(d.x, d.z)


func _clamp_map(p: Vector3) -> Vector3:
	return Vector3(clamp(p.x, -MAP_HALF, MAP_HALF), 0.0, clamp(p.z, -MAP_HALF, MAP_HALF))


# ---------------- Ko'rinish ----------------

func update_visual(alpha: float) -> void:
	if not alive:
		return
	var p: Vector3 = prev_pos.lerp(sim_pos, alpha)
	position = Vector3(p.x, 0.0, p.z)
	rotation.y = lerp_angle(prev_facing, facing, alpha)
	if visual:
		visual.moving = _moving_now


func set_selected(v: bool) -> void:
	selected = v and alive
	if visual:
		visual.set_selected(selected)


func hp_ratio() -> float:
	return clamp(hp / max_hp, 0.0, 1.0)
