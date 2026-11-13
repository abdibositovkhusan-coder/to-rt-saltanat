class_name MainMenu
extends Node
## Bosh menyu: orqada sekin aylanayotgan 3D sahna (saltanatlar qo'shinlari va Yer Yuragi),
## tugmalar — Kampaniya, Tezkor jang, Muqaddima filmini ko'rish, Chiqish.
## Bog'liqlik: WorldBuilder, UnitVisual, GameData, UiStyle.

signal continue_pressed
signal campaign_pressed
signal quick_pressed
signal heroes_pressed
signal settings_pressed
signal credits_pressed
signal intro_pressed

var _stage: Node3D
var _cam: Camera3D
var _angle: float = 0.0


func _ready() -> void:
	_build_stage()
	_build_ui()


func _build_stage() -> void:
	_stage = Node3D.new()
	add_child(_stage)
	var w := WorldBuilder.build_environment(_stage, "dusk")
	WorldBuilder.build_ground(_stage, w, 120.0, "dusk", 11, true, 12.0)
	# Markazda Yer Yuragi
	var heart := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	sm.radial_segments = 4
	sm.rings = 2
	heart.mesh = sm
	heart.scale = Vector3(1, 1.7, 1)
	heart.position = Vector3(0, 2.6, 0)
	heart.material_override = UnitVisual.mat(Color(1.0, 0.88, 0.5), 2.5)
	heart.set_meta("spin", 0.8)
	heart.name = "Heart"
	_stage.add_child(heart)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.85, 0.5)
	l.light_energy = 2.0
	l.omni_range = 10.0
	l.position = Vector3(0, 2.6, 0)
	_stage.add_child(l)
	# To'rt saltanat vakillari
	var groups := [
		["navkar", "odamlar", Vector3(5, 0, 0), {}],
		["toshtish_troll", "trollar", Vector3(-5, 0, 0), {}],
		["", "elflar", Vector3(0, 0, 5), {"body": "elf", "cloth": "#2f8f7a", "weapon": "bow", "hood": true,
			"model": "kaykit/characters/Rogue_Hooded.glb", "tint": "#a8e6d6", "hide": ["Knife_Offhand", "1H_Crossbow", "Knife", "Throwable"], "anims": {"idle": "2H_Ranged_Aiming"}}],
		["", "yalmogiz", Vector3(0, 0, -5), {"body": "dead", "cloth": "#2a1238", "weapon": "staff", "glow": "#7fff3f", "eyes": "#7fff3f", "crown": true, "cape": "#1a0f24", "scale": 1.3,
			"model": "kaykit/characters/Skeleton_Mage.glb", "tint": "#cdb4ff"}],
	]
	for g in groups:
		var look: Dictionary = {}
		if g[0] != "":
			var d := GameData.unit_def(g[0])
			var lk = d.get("look", {})
			if lk is Dictionary:
				look = lk.duplicate()
		look.merge(g[3], true)
		look["base"] = false
		var fc := GameData.color(GameData.faction_def(g[1]).get("color", ""), Color.WHITE)
		for i in 3:
			var v := UnitVisual.new()
			_stage.add_child(v)
			v.build(look, fc, 0)
			var base: Vector3 = g[2]
			var side := Vector3(-base.z, 0, base.x).normalized()
			v.position = base + side * (i - 1) * 1.6 + base.normalized() * (0.0 if i == 1 else 0.8)
			v.rotation.y = atan2(-base.x, -base.z)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_stage.add_child(_cam)
	_cam.current = true


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 3
	add_child(ui)
	var root := Control.new()
	root.theme = UiStyle.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 9)
	root.add_child(vb)
	vb.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.offset_left = 70

	var title := UiStyle.label("TO'RT SALTANAT", 56, Color(1.0, 0.84, 0.35))
	title.add_theme_constant_override("outline_size", 12)
	vb.add_child(title)
	var sub := UiStyle.label("Afsonalar Urushi", 30, Color(0.95, 0.9, 0.82))
	vb.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	vb.add_child(gap)

	var entries: Array = []
	if SaveSystem.has_save():
		entries.append(["Davom ettirish", "continue"])
	entries.append(["Kampaniya", "campaign"])
	entries.append(["Tezkor jang", "quick"])
	entries.append(["Qahramonlar Zali", "heroes"])
	entries.append(["Sozlamalar", "settings"])
	entries.append(["Mualliflar", "credits"])
	entries.append(["Muqaddima filmini ko'rish", "intro"])
	entries.append(["Chiqish", "exit"])
	for e in entries:
		var b := UiStyle.button(str(e[0]), Vector2(380, 50))
		var act: String = str(e[1])
		b.pressed.connect(func(): _on_entry(act))
		vb.add_child(b)

	var ver := UiStyle.label("v1.0 · Kay Lousberg (KayKit) CC0", 16, Color(0.85, 0.85, 0.8))
	root.add_child(ver)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -14
	ver.offset_bottom = -10


func _on_entry(act: String) -> void:
	match act:
		"continue":
			continue_pressed.emit()
		"campaign":
			campaign_pressed.emit()
		"quick":
			quick_pressed.emit()
		"heroes":
			heroes_pressed.emit()
		"settings":
			settings_pressed.emit()
		"credits":
			credits_pressed.emit()
		"intro":
			intro_pressed.emit()
		_:
			get_tree().quit()


func _process(delta: float) -> void:
	_angle += delta * 0.12
	if _cam:
		_cam.position = Vector3(sin(_angle) * 15.0, 7.0, cos(_angle) * 15.0)
		_cam.look_at(Vector3(0, 1.6, 0), Vector3.UP)
	if _stage == null:
		return
	var heart: Node3D = _stage.get_node_or_null("Heart")
	if heart:
		heart.rotate_y(delta * 0.8)
