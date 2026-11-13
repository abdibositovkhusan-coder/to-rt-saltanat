class_name HeroesHall
extends Node
## Qahramonlar Zali: har bir saltanatning qahramonlari — 3D ko'rinishi (aylanib turadi),
## unvoni, ko'rsatkichlari va 4 ta qobiliyati. Bog'liqlik: GameData, UnitVisual, UiStyle, Loc.

signal back

const FACTIONS := ["odamlar", "trollar", "elflar", "yalmogiz"]

var _fac_btns: Dictionary = {}
var _hero_row: HBoxContainer
var _hero_btns: Dictionary = {}
var _name_l: Label
var _stats_l: Label
var _abil_box: VBoxContainer
var _stage: Node3D
var _model: Node3D = null
var _faction: String = "odamlar"


func _ready() -> void:
	var vb := UiStyle.screen(self, "Qahramonlar Zali")
	var r1 := UiStyle.hrow(vb)
	for f in FACTIONS:
		var b := UiStyle.button(GameData.faction_short(f), Vector2(190, 52))
		var ff: String = f
		b.text = GameData.faction_short(f)
		b.pressed.connect(func(): _pick_faction(ff))
		r1.add_child(b)
		_fac_btns[ff] = b
	_hero_row = UiStyle.hrow(vb)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	# 3D ko'rinish
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(340, 340)
	body.add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.size = Vector2i(340, 340)
	svc.add_child(sv)
	_stage = Node3D.new()
	sv.add_child(_stage)
	var cam := Camera3D.new()
	cam.fov = 35.0
	cam.position = Vector3(0, 1.6, 5.2)
	_stage.add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	cam.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.3
	_stage.add_child(sun)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.7, 0.65)
	env.ambient_light_energy = 0.8
	we.environment = env
	_stage.add_child(we)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	_name_l = UiStyle.label("", 30, Color(1.0, 0.85, 0.4))
	info.add_child(_name_l)
	_stats_l = UiStyle.label("", 19, Color(0.92, 0.92, 0.88))
	info.add_child(_stats_l)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info.add_child(sc)
	_abil_box = VBoxContainer.new()
	_abil_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_abil_box.add_theme_constant_override("separation", 6)
	sc.add_child(_abil_box)

	var rb := UiStyle.hrow(vb)
	var bb := UiStyle.button("Orqaga", Vector2(220, 60))
	bb.pressed.connect(_on_back)
	rb.add_child(bb)
	_pick_faction("odamlar")


func _process(delta: float) -> void:
	if _model != null and is_instance_valid(_model):
		_model.rotate_y(delta * 0.6)


func _pick_faction(f: String) -> void:
	_faction = f
	for k in _fac_btns.keys():
		UiStyle.set_active(_fac_btns[k], k == f)
	for c in _hero_row.get_children():
		c.visible = false
		c.queue_free()
	_hero_btns.clear()
	var fd := GameData.faction_def(f)
	var heroes: Array = []
	var hl = fd.get("heroes", [])
	if hl is Array:
		heroes = hl.duplicate()
	if f == "odamlar":
		heroes.append("afandi")
	var first: String = ""
	for h in heroes:
		var hid: String = str(h)
		var d := GameData.unit_def(hid)
		if d.is_empty():
			continue
		if first == "":
			first = hid
		var b := Button.new()
		b.text = str(d.get("name", hid))
		b.custom_minimum_size = Vector2(200, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _pick_hero(hid))
		_hero_row.add_child(b)
		_hero_btns[hid] = b
	if first != "":
		_pick_hero(first)


func _pick_hero(hid: String) -> void:
	for k in _hero_btns.keys():
		UiStyle.set_active(_hero_btns[k], k == hid)
	var d := GameData.unit_def(hid)
	_name_l.text = "%s — %s" % [d.get("name", hid), d.get("title", "")]
	var dmg = d.get("damage", [0, 0])
	var dmin: int = 0
	var dmax: int = 0
	if dmg is Array and dmg.size() >= 2:
		dmin = int(dmg[0])
		dmax = int(dmg[1])
	_stats_l.text = "%s: %d   %s: %d   %s: %d–%d   %s: %d\n%s" % [
		Loc.t("Sog'liq"), int(d.get("hp", 0)), Loc.t("Mana"), int(d.get("mana", 0)),
		Loc.t("Zarar"), dmin, dmax, Loc.t("Sovut"), int(d.get("armor", 0)), str(d.get("role", ""))]
	for c in _abil_box.get_children():
		c.visible = false
		c.queue_free()
	var abs_list = d.get("abilities", [])
	if abs_list is Array:
		for a in abs_list:
			if not (a is Dictionary):
				continue
			var head: String = str(a.get("name", ""))
			if bool(a.get("ult", false)):
				head += "  (" + Loc.t("Ultimativ (6-daraja)") + ")"
			var hl := UiStyle.label(head, 22, Color(0.6, 0.85, 1.0) if not bool(a.get("ult", false)) else Color(1.0, 0.7, 0.35))
			_abil_box.add_child(hl)
			var dl := Label.new()
			dl.text = str(a.get("desc", ""))
			dl.add_theme_font_size_override("font_size", 18)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_abil_box.add_child(dl)
	_show_model(d)


func _show_model(d: Dictionary) -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = null
	var look: Dictionary = {}
	var lk = d.get("look", {})
	if lk is Dictionary:
		look = lk.duplicate()
	look["base"] = false
	var fc := GameData.color(GameData.faction_def(_faction).get("color", ""), Color.WHITE)
	var v := UnitVisual.new()
	_stage.add_child(v)
	v.build(look, fc, 0)
	FaceLib.attach_badge(v, str(d.get("id", "")), 1.9)
	_model = v


func _on_back() -> void:
	back.emit()
