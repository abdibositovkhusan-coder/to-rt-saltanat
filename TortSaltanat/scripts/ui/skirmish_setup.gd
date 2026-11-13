class_name SkirmishSetup
extends Node
## Tezkor jang sozlamasi: o'yinchi saltanatini tanlaydi (4 ta), raqib saltanatini (yoki tasodifiy)
## va vaqtni (kun/shom). «Boshlash» bosilganda start signali yuboriladi.
## Bog'liqlik: UiStyle, GameData.

signal start(player_faction: String, enemy_faction: String, env: String, difficulty: String)
signal back

const FACTIONS := ["odamlar", "trollar", "elflar", "yalmogiz"]

var _player: String = "odamlar"
var _enemy: String = "tasodifiy"
var _env: String = "day"
var _diff: String = "orta"
var _diff_btns: Dictionary = {}
var _player_btns: Dictionary = {}
var _enemy_btns: Dictionary = {}
var _env_btns: Dictionary = {}
var _desc: Label


func _ready() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 4
	add_child(ui)
	var root := Control.new()
	root.theme = UiStyle.make_theme()
	ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.05, 0.04)
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	root.add_child(vb)
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 40
	vb.offset_right = -40
	vb.offset_top = 20
	vb.offset_bottom = -20

	var title := UiStyle.label("Saltanatingizni tanlang", 40, Color(1.0, 0.84, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	for f in FACTIONS:
		var fd := GameData.faction_def(f)
		var b := UiStyle.button("%s\n%s" % [fd.get("name", f), fd.get("title", "")], Vector2(270, 90))
		b.add_theme_font_size_override("font_size", 17)
		var col := GameData.color(fd.get("color", ""), Color.GRAY)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.darkened(0.35)
		sb.border_color = col.lightened(0.3)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", sb)
		var ff: String = f
		b.pressed.connect(func(): _pick_player(ff))
		row.add_child(b)
		_player_btns[f] = b

	_desc = UiStyle.label("", 18)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(900, 90)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_desc)

	var lbl2 := UiStyle.label("Raqib:", 24, Color(1.0, 0.7, 0.55))
	lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lbl2)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row2)
	for f in FACTIONS + ["tasodifiy"]:
		var label: String = "Tasodifiy" if f == "tasodifiy" else GameData.faction_short(f)
		var eb := UiStyle.button(label, Vector2(170, 56))
		var ef: String = f
		eb.pressed.connect(func(): _pick_enemy(ef))
		row2.add_child(eb)
		_enemy_btns[f] = eb

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 10)
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row3)
	for e in [["day", "Kunduzi"], ["dusk", "Shom"], ["night", "Tunda"]]:
		var vb2 := UiStyle.button(str(e[1]), Vector2(150, 50))
		var ee: String = str(e[0])
		vb2.pressed.connect(func(): _pick_env(ee))
		row3.add_child(vb2)
		_env_btns[ee] = vb2

	var row_d := HBoxContainer.new()
	row_d.add_theme_constant_override("separation", 10)
	row_d.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row_d)
	row_d.add_child(UiStyle.label("Qiyinlik:", 22, Color(1.0, 0.85, 0.5)))
	for e in [["oson", "Oson"], ["orta", "O'rta"], ["qiyin", "Qiyin"]]:
		var db := UiStyle.button(str(e[1]), Vector2(150, 50))
		var dd: String = str(e[0])
		db.pressed.connect(func(): _pick_diff(dd))
		row_d.add_child(db)
		_diff_btns[dd] = db

	var row4 := HBoxContainer.new()
	row4.add_theme_constant_override("separation", 16)
	row4.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row4)
	var back_b := UiStyle.button("Orqaga", Vector2(200, 64))
	back_b.pressed.connect(func(): back.emit())
	row4.add_child(back_b)
	var go := UiStyle.button("Boshlash!", Vector2(260, 64))
	go.add_theme_font_size_override("font_size", 24)
	go.pressed.connect(_on_go)
	row4.add_child(go)

	_pick_player("odamlar")
	_pick_enemy("tasodifiy")
	_pick_env("day")
	_pick_diff("orta")


func _pick_diff(d: String) -> void:
	_diff = d
	for k in _diff_btns.keys():
		UiStyle.set_active(_diff_btns[k], k == d)


func _pick_player(f: String) -> void:
	_player = f
	for k in _player_btns.keys():
		var b: Button = _player_btns[k]
		b.modulate = Color(1, 1, 1, 1) if k == f else Color(1, 1, 1, 0.55)
	var fd := GameData.faction_def(f)
	_desc.text = "%s\n%s" % [fd.get("desc", ""), fd.get("mechanic", "")]


func _pick_enemy(f: String) -> void:
	_enemy = f
	for k in _enemy_btns.keys():
		UiStyle.set_active(_enemy_btns[k], k == f)


func _pick_env(e: String) -> void:
	_env = e
	for k in _env_btns.keys():
		UiStyle.set_active(_env_btns[k], k == e)


func _on_go() -> void:
	var enemy := _enemy
	if enemy == "tasodifiy":
		var others: Array = []
		for f in FACTIONS:
			if f != _player:
				others.append(f)
		enemy = str(others[randi() % others.size()])
	start.emit(_player, enemy, _env, _diff)
