class_name Projectile
extends Node3D
## O'q / nayza: nishonni kuzatib uchadi (yoyma traektoriya bilan), tekkanda zarar beradi.
## Bog'liqlik: Simulation (sim_step chaqiradi), Unit (take_damage).

var sim = null
var done: bool = false
var shooter_id: int = -1
var target_id: int = -1
var damage: float = 10.0
var speed: float = 20.0
var arc: float = 1.0
var splash: float = 0.0
var slow: float = 0.0
var shooter_team: int = -1
var weak: float = 0.0
var weak_time: float = 4.0
var kind: String = "arrow"

var _shooter = null
var _start: Vector3
var _last_target_pos: Vector3
var _progress: float = 0.0
var _total: float = 1.0
var sim_pos: Vector3
var prev_pos: Vector3


func launch(shooter, target, start: Vector3, dmg: float, pdef: Dictionary) -> void:
	_shooter = shooter
	shooter_id = shooter.uid
	target_id = target.uid
	damage = dmg
	speed = float(pdef.get("speed", 20.0))
	arc = float(pdef.get("arc", 1.0))
	splash = float(pdef.get("splash", 0.0))
	slow = float(pdef.get("slow", 0.0))
	shooter_team = shooter.team
	weak = float(pdef.get("weak", 0.0))
	weak_time = float(pdef.get("weak_time", 4.0))
	_start = start
	_last_target_pos = target.sim_pos + Vector3(0, target.pick_height + 0.2, 0)
	_total = max(0.5, start.distance_to(_last_target_pos))
	sim_pos = start
	prev_pos = start
	position = start
	kind = str(pdef.get("kind", "arrow"))
	var wood := Color(0.45, 0.3, 0.16)
	if kind.begins_with("magic") or kind == "fire":
		var c: Color = Color(0.55, 0.75, 1.0)
		if kind == "fire":
			c = Color(1.0, 0.55, 0.15)
		elif kind == "magic_green":
			c = Color(0.5, 1.0, 0.35)
		elif kind == "magic_purple":
			c = Color(0.75, 0.4, 1.0)
		UnitVisual.part(self, UnitVisual.sphere(0.22, 8), UnitVisual.mat(c, 3.0, true), Vector3.ZERO)
		UnitVisual.part(self, UnitVisual.sphere(0.12, 6), UnitVisual.mat(Color(1, 1, 1), 2.0, true), Vector3(0, 0, -0.25))
		var l := OmniLight3D.new()
		l.light_color = c
		l.light_energy = 1.2
		l.omni_range = 3.0
		add_child(l)
	elif kind == "rock":
		var rock := ModelLib.instance("kaykit/medieval/projectile_catapult.gltf")
		if rock != null:
			rock.scale = Vector3.ONE * 2.6
			add_child(rock)
		else:
			UnitVisual.part(self, UnitVisual.sphere(0.32, 7), UnitVisual.mat(Color(0.45, 0.42, 0.4)), Vector3.ZERO)
	elif kind == "spear":
		UnitVisual.part(self, UnitVisual.box(Vector3(0.05, 0.05, 1.3)), UnitVisual.mat(wood), Vector3.ZERO)
		UnitVisual.part(self, UnitVisual.cone(0.06, 0.25), UnitVisual.mat(Color(0.4, 0.75, 0.3), 0.6), Vector3(0, 0, 0.75), Vector3(PI * 0.5, 0, 0))
	else:
		UnitVisual.part(self, UnitVisual.box(Vector3(0.03, 0.03, 0.8)), UnitVisual.mat(wood), Vector3.ZERO)
		UnitVisual.part(self, UnitVisual.box(Vector3(0.08, 0.08, 0.1)), UnitVisual.mat(Color(1, 1, 0.9), 0.8, true), Vector3(0, 0, -0.38))


func sim_step(dt: float) -> void:
	if done:
		return
	prev_pos = sim_pos
	var t = sim.get_unit(target_id)
	if t != null:
		_last_target_pos = t.sim_pos + Vector3(0, t.pick_height + 0.2, 0)
		_total = max(0.5, _start.distance_to(_last_target_pos))
	_progress += speed * dt
	var k: float = clamp(_progress / max(_total, 0.01), 0.0, 1.0)
	var flat: Vector3 = _start.lerp(_last_target_pos, k)
	flat.y += sin(k * PI) * arc
	sim_pos = flat
	if k >= 1.0:
		done = true
		var shooter = sim.get_unit(shooter_id)
		if t != null:
			var dmg := damage
			if kind == "fire" and t.has_tag("rage"):
				dmg *= 1.5
			t.take_damage(dmg, shooter)
			if slow > 0.0 and t.alive:
				t.apply_slow(slow)
			if weak > 0.0 and t.alive:
				t.add_effect("weak", weak_time, weak)
		if splash > 0.0:
			var impact := Vector3(_last_target_pos.x, 0, _last_target_pos.z)
			for o in sim.units.duplicate():
				if not o.alive or o.team == shooter_team or o == t:
					continue
				if Vector2(o.sim_pos.x - impact.x, o.sim_pos.z - impact.z).length() <= splash + o.radius:
					o.take_damage(damage * 0.5, shooter)
			if sim.spawner != null and sim.spawner.has_method("spawn_effect"):
				sim.spawner.spawn_effect("blast", impact + Vector3(0, 0.3, 0))
			Audio.play_at("explosion", impact, sim)


func update_visual(alpha: float) -> void:
	var p: Vector3 = prev_pos.lerp(sim_pos, alpha)
	var dir: Vector3 = sim_pos - prev_pos
	position = p
	if dir.length() > 0.001 and abs(dir.normalized().y) < 0.98:
		look_at(p + dir, Vector3.UP)
		rotate_object_local(Vector3.UP, PI)


func finish() -> void:
	queue_free()
