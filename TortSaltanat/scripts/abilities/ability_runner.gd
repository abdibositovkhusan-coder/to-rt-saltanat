class_name AbilityRunner
extends RefCounted
## Qobiliyatlarni bajaruvchi: qahramon ma'lumotidagi "effect" turiga qarab ishlaydi.
## Turlar: strike (bitta nishonga zarba/karaxt/sekinlik/zaiflik), aoe (hududga zarar, kechikish bilan ham),
## ally_buff (ittifoqchilarga kuch), enemy_debuff (dushmanlarga qurolsizlik/sekinlik), self_buff (o'ziga kuch,
## kattalashish), dash (otilib borish), pull (dushmanni tortib kelish), reveal (tumanni ochish).
## Bog'liqlik: Hero, Unit, Simulation, Battle (effektlar).

static func run(hero, i: int, t, pos: Vector3) -> void:
	var a: Dictionary = hero.abilities[i]
	var effect := str(a.get("effect", ""))
	var sim = hero.sim
	match effect:
		"strike":
			if t == null:
				return
			_strike(hero, i, t)
		"aoe":
			var center: Vector3 = pos if str(a.get("kind", "")) == "point" else hero.sim_pos
			var delay: float = float(a.get("delay", 0.0))
			if delay > 0.0:
				_fx(sim, "meteor", center)
				var team: int = hero.team
				var dmg: float = hero.val(i, "damage")
				var stun: float = hero.val(i, "stun")
				var slow: float = hero.val(i, "slow")
				var r: float = float(a.get("radius", 3.0))
				sim.schedule(delay, func(): AbilityRunner._aoe_apply(sim, hero, team, center, r, dmg, stun, slow))
			else:
				_aoe_apply(sim, hero, hero.team, center, float(a.get("radius", 3.0)), hero.val(i, "damage"), hero.val(i, "stun"), hero.val(i, "slow"))
		"ally_buff":
			var r2: float = float(a.get("radius", 8.0))
			for o in sim.units:
				if o.alive and o.team == hero.team and not o.is_building() and o.sim_pos.distance_to(hero.sim_pos) <= r2:
					o.add_effect(str(a.get("buff", "")), hero.val(i, "duration", 10.0), hero.val(i, "value"))
			_fx(sim, "ring", hero.sim_pos)
		"enemy_debuff":
			var center2: Vector3 = pos if str(a.get("kind", "")) == "point" else hero.sim_pos
			var r3: float = float(a.get("radius", 4.0))
			var debuff := str(a.get("debuff", ""))
			var dur: float = hero.val(i, "duration", 4.0)
			var dmg2: float = hero.val(i, "damage")
			var slow2: float = hero.val(i, "slow")
			var dv: float = hero.val(i, "value", 1.0)
			if bool(a.get("night", false)) and sim.spawner != null and sim.spawner.has_method("force_night"):
				sim.spawner.force_night(dur)
			for o in _enemies_in(sim, hero.team, center2, r3):
				if debuff == "slow":
					o.apply_slow(dur)
				elif debuff != "":
					o.add_effect(debuff, dur, dv)
				if slow2 > 0.0:
					o.apply_slow(slow2)
				if dmg2 > 0.0:
					o.take_damage(dmg2, hero)
			_fx(sim, "ring_dark", center2)
		"self_buff":
			var dur2: float = hero.val(i, "duration", 10.0)
			var buffs = a.get("buffs", [])
			if buffs is Array:
				for b in buffs:
					hero.add_effect(str(b.get("name", "")), dur2, float(b.get("value", 0)))
			var sc: float = float(a.get("scale", 1.0))
			if sc != 1.0 and hero.visual:
				var v = hero.visual
				var base: Vector3 = v.scale
				v.create_tween().tween_property(v, "scale", base * sc, 0.4)
				sim.schedule(dur2, func(): AbilityRunner._restore_scale(v, base))
			_fx(sim, "ring", hero.sim_pos)
		"dash":
			if t == null:
				return
			var d: Vector3 = t.sim_pos - hero.sim_pos
			d.y = 0
			if d.length() > 0.1:
				hero.sim_pos = t.sim_pos - d.normalized() * (t.radius + hero.radius + 0.2)
			_strike(hero, i, t)
			hero.order_attack(t.uid)
		"pull":
			if t == null:
				return
			var d2: Vector3 = t.sim_pos - hero.sim_pos
			d2.y = 0
			if d2.length() > 0.1:
				t.sim_pos = hero.sim_pos + d2.normalized() * (t.radius + hero.radius + 1.0)
			_strike(hero, i, t)
		"heal_allies":
			var r4: float = float(a.get("radius", 8.0))
			var amount: float = hero.val(i, "value", 150.0)
			for o in sim.units:
				if o.alive and o.team == hero.team and not o.is_building() and o.sim_pos.distance_to(hero.sim_pos) <= r4:
					o.hp = min(o.max_hp, o.hp + amount)
					_fx(sim, "heal", o.sim_pos + Vector3(0, o.pick_height + 0.5, 0))
		"summon":
			var unit_id := str(a.get("unit", ""))
			var count := int(hero.val(i, "count", 1.0))
			var life: float = hero.val(i, "life", 30.0)
			for k in count:
				var ang: float = TAU * k / float(max(1, count))
				var sp: Vector3 = hero.sim_pos + Vector3(cos(ang) * 2.0, 0, sin(ang) * 2.0)
				var su = sim.spawner.spawn_unit(unit_id, hero.team, sp) if sim.spawner != null else null
				if su != null:
					su.life_timer = life
					su.xp_value = 5
					_fx(sim, "ring_dark", sp)
		"blink":
			var maxr: float = hero.val(i, "range", 10.0)
			var d3: Vector3 = pos - hero.sim_pos
			d3.y = 0
			if d3.length() > maxr:
				d3 = d3.normalized() * maxr
			_fx(sim, "ring_dark", hero.sim_pos)
			hero.sim_pos = hero.sim_pos + d3
			hero.prev_pos = hero.sim_pos
			hero.order_stop()
			_fx(sim, "ring_dark", hero.sim_pos)
		"drain":
			if t == null:
				return
			var dd: float = hero.val(i, "damage")
			t.take_damage(dd, hero)
			hero.hp = min(hero.max_hp, hero.hp + dd)
			_fx(sim, "heal", hero.sim_pos + Vector3(0, 2.0, 0))
			_fx(sim, "blast", t.sim_pos + Vector3(0, 1.0, 0))
		"multi_strike":
			var r5: float = float(a.get("radius", 7.0))
			var n := int(hero.val(i, "count", 5.0))
			var dm: float = hero.val(i, "damage")
			var list := _enemies_in(sim, hero.team, hero.sim_pos, r5)
			list.sort_custom(func(x, y): return x.sim_pos.distance_to(hero.sim_pos) < y.sim_pos.distance_to(hero.sim_pos))
			for k in min(n, list.size()):
				list[k].take_damage(dm, hero)
				_fx(sim, "blast", list[k].sim_pos + Vector3(0, 1.0, 0))
		"reveal":
			if sim.fog != null:
				sim.fog.add_reveal(hero.team, pos, float(a.get("radius", 8.0)), hero.val(i, "duration", 12.0))
			_fx(sim, "ring", pos)


static func _strike(hero, i: int, t) -> void:
	var dmg: float = hero.val(i, "damage")
	if dmg > 0.0:
		t.take_damage(dmg, hero)
	var stun: float = hero.val(i, "stun")
	if stun > 0.0 and t.alive:
		t.add_effect("stun", stun, 1.0)
	var slow: float = hero.val(i, "slow")
	if slow > 0.0 and t.alive:
		t.apply_slow(slow)
	var vuln: float = hero.val(i, "vuln")
	if vuln > 0.0 and t.alive:
		t.add_effect("vuln", hero.val(i, "duration", 8.0), vuln)
	_fx(hero.sim, "blast", t.sim_pos + Vector3(0, 1.0, 0))


static func _aoe_apply(sim, hero, team: int, center: Vector3, r: float, dmg: float, stun: float, slow: float) -> void:
	var src = hero if is_instance_valid(hero) and hero.alive else null
	for o in _enemies_in(sim, team, center, r):
		if dmg > 0.0:
			o.take_damage(dmg, src)
		if stun > 0.0 and o.alive:
			o.add_effect("stun", stun, 1.0)
		if slow > 0.0 and o.alive:
			o.apply_slow(slow)
	_fx(sim, "blast", center + Vector3(0, 0.4, 0))


static func _enemies_in(sim, team: int, center: Vector3, r: float) -> Array:
	var out: Array = []
	for o in sim.units:
		if not o.alive or o.team == team or o.invulnerable:
			continue
		if Vector2(o.sim_pos.x - center.x, o.sim_pos.z - center.z).length() <= r + o.radius:
			out.append(o)
	return out


static func _fx(sim, kind: String, pos: Vector3) -> void:
	if sim != null and sim.spawner != null and sim.spawner.has_method("spawn_effect"):
		sim.spawner.spawn_effect(kind, pos)


static func _restore_scale(v, base: Vector3) -> void:
	if v != null and is_instance_valid(v):
		v.create_tween().tween_property(v, "scale", base, 0.4)
