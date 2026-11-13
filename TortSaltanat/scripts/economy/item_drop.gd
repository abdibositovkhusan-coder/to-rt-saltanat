class_name ItemDrop
extends Node3D
## Yerga tushgan narsa (yirtqichlar lageridan). Qahramon yaqinidan o'tsa, avtomatik oladi.
## Bog'liqlik: Simulation (drops ro'yxati), GameData.

var item_id: String = ""
var sim_pos: Vector3 = Vector3.ZERO


func setup(id: String, pos: Vector3) -> void:
	item_id = id
	sim_pos = Vector3(pos.x, 0, pos.z)
	position = sim_pos
	var d := GameData.item_def(id)
	var c := Color(0.8, 0.8, 0.8)
	match str(d.get("rarity", "oddiy")):
		"noyob":
			c = Color(0.35, 0.6, 1.0)
		"epik":
			c = Color(0.75, 0.35, 1.0)
		"afsonaviy":
			c = Color(1.0, 0.65, 0.15)
	var chest := ModelLib.instance("kaykit/medieval/crate_A_big.gltf")
	if chest != null:
		chest.scale = Vector3.ONE * 3.0
		add_child(chest)
	else:
		UnitVisual.part(self, UnitVisual.box(Vector3(0.6, 0.5, 0.5)), UnitVisual.mat(Color(0.5, 0.33, 0.18)), Vector3(0, 0.25, 0))
	var glow := UnitVisual.part(self, UnitVisual.sphere(0.25, 8), UnitVisual.mat(c, 3.0, true), Vector3(0, 1.1, 0))
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 1.5
	l.omni_range = 4.0
	l.position = Vector3(0, 1.2, 0)
	add_child(l)
	var tw := glow.create_tween().set_loops()
	tw.tween_property(glow, "position:y", 1.4, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(glow, "position:y", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


func picked() -> void:
	queue_free()
