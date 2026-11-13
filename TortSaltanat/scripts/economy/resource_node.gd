class_name ResourceNode
extends Node3D
## Yig'iladigan resurs: oltin koni yoki daraxt. Ishchilar take() orqali oladi; tugasa yo'qoladi.
## Bog'liqlik: Simulation (ro'yxatda saqlaydi), UnitVisual (shakl va materiallar).

var uid: int = -1
var kind: String = "gold"
var amount: int = 0
var max_amount: int = 0
var radius: float = 2.2
var sim_pos: Vector3 = Vector3.ZERO
var alive: bool = true
var display_name: String = "Oltin koni"
var _body: Node3D


func setup(k: String, pos: Vector3, amt: int, rng: RandomNumberGenerator) -> void:
	kind = k
	amount = amt
	max_amount = amt
	sim_pos = Vector3(pos.x, 0, pos.z)
	position = sim_pos
	_body = Node3D.new()
	add_child(_body)
	if kind == "gold":
		radius = 2.3
		display_name = Loc.t("Oltin koni")
		var mine := ModelLib.instance("kaykit/medieval/building_mine_yellow.gltf")
		if mine != null:
			mine.scale = Vector3.ONE * 2.5
			mine.rotation.y = rng.randf_range(-0.6, 0.6)
			_body.add_child(mine)
			for i in 6:
				var a0 := rng.randf() * TAU
				UnitVisual.part(_body, UnitVisual.sphere(rng.randf_range(0.14, 0.26), 6), UnitVisual.mat(Color(1.0, 0.8, 0.2), 1.4),
					Vector3(cos(a0) * 2.3, 0.15, sin(a0) * 2.3))
			return
		var rock := UnitVisual.part(_body, UnitVisual.sphere(2.1, 9), UnitVisual.mat(Color(0.45, 0.4, 0.36)), Vector3(0, 0.6, 0))
		rock.scale = Vector3(1.2, 0.75, 1.0)
		UnitVisual.part(_body, UnitVisual.sphere(1.2, 8), UnitVisual.mat(Color(0.52, 0.47, 0.4)), Vector3(-1.1, 1.3, -0.6))
		for i in 9:
			var a := rng.randf() * TAU
			var r := rng.randf_range(1.0, 2.0)
			UnitVisual.part(_body, UnitVisual.sphere(rng.randf_range(0.15, 0.32), 6), UnitVisual.mat(Color(1.0, 0.8, 0.2), 1.2),
				Vector3(cos(a) * r, rng.randf_range(0.6, 1.7), sin(a) * r * 0.8))
		# Kirish (yog'och ramka)
		var wood := UnitVisual.mat(Color(0.42, 0.28, 0.15))
		UnitVisual.part(_body, UnitVisual.box(Vector3(0.18, 1.6, 0.18)), wood, Vector3(-0.6, 0.8, 1.95))
		UnitVisual.part(_body, UnitVisual.box(Vector3(0.18, 1.6, 0.18)), wood, Vector3(0.6, 0.8, 1.95))
		UnitVisual.part(_body, UnitVisual.box(Vector3(1.5, 0.2, 0.22)), wood, Vector3(0, 1.65, 1.95))
		UnitVisual.part(_body, UnitVisual.box(Vector3(1.0, 1.3, 0.1)), UnitVisual.mat(Color(0.05, 0.04, 0.03)), Vector3(0, 0.7, 1.9))
	else:
		radius = 0.55
		display_name = Loc.t("Daraxt")
		var s := rng.randf_range(0.85, 1.35)
		_body.scale = Vector3(s, s, s)
		_body.rotation.y = rng.randf() * TAU
		var tree_model: String = "kaykit/medieval/tree_single_A.gltf" if rng.randf() < 0.5 else "kaykit/medieval/tree_single_B.gltf"
		var tm := ModelLib.instance(tree_model)
		if tm != null:
			tm.scale = Vector3.ONE * 3.0
			_body.add_child(tm)
			return
		UnitVisual.part(_body, UnitVisual.cone(0.2, 1.4, 0.15, 6), UnitVisual.mat(Color(0.4, 0.27, 0.15)), Vector3(0, 0.7, 0))
		var green := Color(0.2, 0.42, 0.18).lerp(Color(0.3, 0.5, 0.2), rng.randf())
		UnitVisual.part(_body, UnitVisual.cone(1.0, 2.2, 0.0, 7), UnitVisual.mat(green), Vector3(0, 2.2, 0))
		UnitVisual.part(_body, UnitVisual.cone(0.75, 1.6, 0.0, 7), UnitVisual.mat(green.lightened(0.08)), Vector3(0, 3.1, 0))


func take(n: int, consume: bool = true) -> int:
	if not alive:
		return 0
	var got: int = min(n, amount)
	if not consume:
		return got
	amount -= got
	if amount <= 0:
		_deplete()
	return got


func _deplete() -> void:
	alive = false
	var tw := create_tween()
	if kind == "wood":
		tw.tween_property(_body, "rotation:z", PI * 0.5, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.8)
		tw.tween_property(self, "position:y", -2.0, 0.8)
		tw.tween_callback(queue_free)
	else:
		tw.tween_property(_body, "scale", Vector3(1.1, 0.35, 1.1), 1.2)
