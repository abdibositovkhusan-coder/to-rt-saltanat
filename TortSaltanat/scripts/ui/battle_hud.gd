class_name BattleHud
extends CanvasLayer
## Jang interfeysi: yuqori panel (oltin, yog'och, oziq, vazifa, tezlik, pauza), mini-xarita, tanlangan
## birlik/bino ma'lumoti, vaziyatga qarab o'zgaradigan buyruq tugmalari (qurish menyusi, o'rgatish,
## joylash), birliklarning o'zbekcha javoblari va g'alaba/mag'lubiyat oynasi.
## Bog'liqlik: Battle, TouchController, BattleOverlay, Minimap, UiStyle, GameData.

var battle: Battle
var root: Control
var overlay: BattleOverlay
var minimap: Minimap

var _ui: Array = []
var _info_title: Label
var _info_body: Label
var _voice: Label
var _voice_tween: Tween
var _timer_label: Label
var _pause_label: Label
var _gold_l: Label
var _wood_l: Label
var _food_l: Label
var _cmd_grid: GridContainer
var _btn_attack: Button = null
var _btn_box: Button = null
var _btn_speed: Button
var _btn_pause: Button
var _end_panel: PanelContainer
var _build_menu_open: bool = false
var _hero_menu_open: bool = false
var _learn_mode: bool = false
var _shop_page: int = 0
var _hero_bar: HBoxContainer
var _hero_bar_sig: String = ""
var _inv_panel: PanelContainer
var _inv_box: HBoxContainer
var _inv_sig: String = ""
var _ability_buttons: Array = []
var _cost_buttons: Array = []
var _temp_info_until: float = 0.0
var _temp_unit = null
var _temp_res = null


func setup(b: Battle) -> void:
	battle = b
	layer = 5
	root = Control.new()
	root.theme = UiStyle.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	overlay = BattleOverlay.new()
	overlay.battle = b
	root.add_child(overlay)

	_build_top_bar()
	_build_minimap()
	_build_info_panel()
	_build_commands()
	_build_hero_bar()
	_build_inventory()
	_build_voice()
	update_selection([])


# ---------------- Qurilish ----------------

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	root.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 6
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	bar.add_child(hb)
	_gold_l = UiStyle.label("Oltin: 0", 20, Color(1.0, 0.85, 0.3))
	_wood_l = UiStyle.label("Yog'och: 0", 20, Color(0.85, 0.65, 0.4))
	_food_l = UiStyle.label("Oziq: 0/0", 20, Color(0.7, 1.0, 0.6))
	hb.add_child(_gold_l)
	hb.add_child(_wood_l)
	hb.add_child(_food_l)
	var obj_text := str(battle.mission.get("objective", ""))
	if battle.ai != null:
		var dn := {"oson": "Oson", "orta": "O'rta", "qiyin": "Qiyin"}
		obj_text = Loc.t(obj_text) + "  ·  " + Loc.t("Raqib: %s (%s)") % [GameData.faction_short(str(battle.enemy_faction.get("id", ""))), Loc.t(str(dn.get(battle.ai.difficulty, "")))]
	var obj := UiStyle.label(obj_text, 17)
	_obj_label = obj
	_obj_suffix = obj_text.substr(Loc.t(str(battle.mission.get("objective", ""))).length())
	obj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hb.add_child(obj)
	_timer_label = UiStyle.label("", 18, Color(1.0, 0.55, 0.4))
	hb.add_child(_timer_label)
	_btn_speed = UiStyle.button("1x", Vector2(70, 44))
	_btn_speed.pressed.connect(_on_speed)
	hb.add_child(_btn_speed)
	_btn_pause = UiStyle.button("Pauza", Vector2(100, 44))
	_btn_pause.pressed.connect(_on_pause)
	hb.add_child(_btn_pause)
	var mb := UiStyle.button("Menyu", Vector2(100, 44))
	mb.pressed.connect(_open_game_menu)
	hb.add_child(mb)
	_ui.append(bar)

	_pause_label = UiStyle.label("PAUZA — buyruq berishingiz mumkin", 28, Color(1, 0.85, 0.3))
	root.add_child(_pause_label)
	_pause_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_pause_label.offset_top = 90
	_pause_label.offset_left = -260
	_pause_label.offset_right = 260
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.visible = false


func _build_minimap() -> void:
	var holder := PanelContainer.new()
	root.add_child(holder)
	holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	holder.offset_right = -8
	holder.offset_top = 70
	minimap = Minimap.new()
	minimap.battle = battle
	holder.add_child(minimap)
	_ui.append(holder)


func _build_info_panel() -> void:
	var p := PanelContainer.new()
	root.add_child(p)
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_left = 8
	p.offset_bottom = -8
	p.custom_minimum_size = Vector2(330, 120)
	var vb := VBoxContainer.new()
	p.add_child(vb)
	_info_title = UiStyle.label("", 22, Color(1.0, 0.85, 0.35))
	_info_body = UiStyle.label("", 17)
	vb.add_child(_info_title)
	vb.add_child(_info_body)
	_ui.append(p)


func _build_commands() -> void:
	var p := PanelContainer.new()
	root.add_child(p)
	p.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -8
	p.offset_bottom = -8
	_cmd_grid = GridContainer.new()
	_cmd_grid.columns = 3
	_cmd_grid.add_theme_constant_override("h_separation", 8)
	_cmd_grid.add_theme_constant_override("v_separation", 8)
	p.add_child(_cmd_grid)
	_ui.append(p)


func _build_hero_bar() -> void:
	var holder := PanelContainer.new()
	root.add_child(holder)
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.offset_left = 8
	holder.offset_top = 70
	_hero_bar = HBoxContainer.new()
	_hero_bar.add_theme_constant_override("separation", 6)
	holder.add_child(_hero_bar)
	holder.visible = false
	_ui.append(holder)


func refresh_hero_bar() -> void:
	if _hero_bar == null or battle == null or battle.sim == null:
		return
	var heroes: Array = battle.player_heroes()
	var dead: Array = battle.sim.dead_heroes.get(0, [])
	var sig := ""
	for h in heroes:
		sig += "%s%d|" % [h.hero_id, h.level]
	for d in dead:
		sig += "x" + str(d.get("id", "")) + "|"
	if sig == _hero_bar_sig:
		return
	_hero_bar_sig = sig
	for c in _hero_bar.get_children():
		c.visible = false
		c.queue_free()
	for h in heroes:
		var hh = h
		var b := UiStyle.button("%s\n%d-daraja" % [h.display_name, h.level], Vector2(120, 52))
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func(): battle.select_hero(hh))
		_hero_bar.add_child(b)
	for d in dead:
		var b2 := UiStyle.button("%s\n(halok)" % str(GameData.unit_def(str(d.get("id", ""))).get("name", "")), Vector2(120, 52))
		b2.add_theme_font_size_override("font_size", 15)
		b2.modulate = Color(1, 1, 1, 0.5)
		_hero_bar.add_child(b2)
	_hero_bar.get_parent().visible = not heroes.is_empty() or not dead.is_empty()


func _build_inventory() -> void:
	_inv_panel = PanelContainer.new()
	root.add_child(_inv_panel)
	_inv_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_inv_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_inv_panel.offset_left = 8
	_inv_panel.offset_bottom = -150
	_inv_box = HBoxContainer.new()
	_inv_box.add_theme_constant_override("separation", 4)
	_inv_panel.add_child(_inv_box)
	_inv_panel.visible = false
	_ui.append(_inv_panel)


func _refresh_inventory() -> void:
	if _inv_panel == null:
		return
	var h = battle.selected_hero()
	if h == null:
		_inv_panel.visible = false
		_inv_sig = ""
		return
	var sig := str(h.uid) + str(h.inventory)
	if sig == _inv_sig and _inv_panel.visible:
		return
	_inv_sig = sig
	_inv_panel.visible = true
	for c in _inv_box.get_children():
		c.visible = false
		c.queue_free()
	for slot in Hero.INV_SIZE:
		var it = h.inventory[slot]
		var txt := "—"
		if it != null:
			var d := GameData.item_def(str(it["id"]))
			txt = str(d.get("name", "")).split(" ")[0]
			if bool(d.get("consumable", false)):
				txt += " ×%d" % int(it["charges"])
		var b := UiStyle.button(txt, Vector2(86, 44))
		b.add_theme_font_size_override("font_size", 13)
		var sl := slot
		b.pressed.connect(func(): battle.command_use_item(sl))
		_inv_box.add_child(b)


func _build_voice() -> void:
	_voice = UiStyle.label("", 24)
	root.add_child(_voice)
	_voice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_voice.offset_left = -360
	_voice.offset_right = 360
	_voice.offset_top = -200
	_voice.offset_bottom = -160
	_voice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voice.modulate.a = 0.0


# ---------------- Buyruq tugmalari (vaziyatga qarab) ----------------

func close_build_menu() -> void:
	_build_menu_open = false
	_hero_menu_open = false
	_learn_mode = false
	_shop_page = 0


func refresh_commands() -> void:
	if _cmd_grid == null or battle == null:
		return
	for c in _cmd_grid.get_children():
		c.visible = false
		c.queue_free()
	_btn_attack = null
	_btn_box = null
	_cost_buttons = []
	if battle.over:
		return

	if battle.is_placing():
		var bd := GameData.building_def(battle.placing_kind)
		_add_btn("Joylash\n" + str(bd.get("name", "")), func(): battle.confirm_placement(), Vector2(170, 70))
		_add_btn("Bekor", func(): battle.cancel_placement())
		return

	var neutral = battle.selected_neutral()
	if neutral != null:
		_neutral_commands(neutral)
		return

	var hero = battle.selected_hero()
	if hero != null:
		_hero_commands(hero)
		return

	if _build_menu_open:
		for k in battle.player_faction.get("builds", []):
			var kind := str(k)
			var bd2 := GameData.building_def(kind)
			var btn := _add_btn("%s\n%s" % [bd2.get("name", kind), GameData.cost_text(bd2.get("cost", {}))], func(): _choose_building(kind), Vector2(170, 70))
			btn.add_theme_font_size_override("font_size", 16)
			_cost_buttons.append([btn, bd2.get("cost", {}), bd2.get("requires", {})])
		_add_btn("Orqaga", func(): _toggle_build_menu(false))
		_update_cost_buttons()
		return

	var b = battle.selected_building()
	if b != null and _hero_menu_open and b.dropoff:
		_hall_hero_commands(b)
		return
	if b != null:
		if b.complete:
			if b.dropoff:
				_add_btn("Qahramonlar", func(): _set_hero_menu(true), Vector2(150, 70))
			for k in b.trains:
				var kind2 := str(k)
				var ud := GameData.unit_def(kind2)
				var tb := _add_btn("%s\n%s" % [ud.get("name", kind2), GameData.cost_text(ud.get("cost", {}))], func(): battle.command_train(kind2), Vector2(150, 70))
				tb.add_theme_font_size_override("font_size", 15)
				_cost_buttons.append([tb, ud.get("cost", {}), ud.get("requires", {})])
			var research = b.bdef.get("research", [])
			if research is Array:
				for r in research:
					var rid := str(r)
					var ug := GameData.upgrade_def(rid)
					var levels = ug.get("levels", [])
					var lvl: int = battle.sim.upgrade_level(0, rid)
					if not (levels is Array) or lvl >= levels.size():
						continue
					var L: Dictionary = levels[lvl]
					var title: String = "%s %s" % [ug.get("name", rid), Building._roman(lvl + 1) if levels.size() > 1 else ""]
					var rb := _add_btn("%s\n%s" % [title.strip_edges(), GameData.cost_text(L.get("cost", {}))], func(): battle.command_research(rid), Vector2(150, 70))
					rb.add_theme_font_size_override("font_size", 14)
					rb.tooltip_text = str(ug.get("desc", ""))
					_cost_buttons.append([rb, L.get("cost", {}), {"tier": int(L.get("tier", 1))}])
			var to := str(b.bdef.get("upgrade_to", ""))
			if to != "" and b.queue.is_empty():
				var nd := GameData.building_def(to)
				var ub := _add_btn("Yangilash:\n%s %s" % [nd.get("name", to), GameData.cost_text(nd.get("cost", {}))], func(): battle.command_upgrade_building(), Vector2(150, 70))
				ub.add_theme_font_size_override("font_size", 15)
				_cost_buttons.append([ub, nd.get("cost", {}), nd.get("requires", {})])
			if not b.queue.is_empty():
				_add_btn("Navbatdan\nchiqarish", func(): battle.command_cancel_train(), Vector2(150, 70))
		_add_btn("Bekor", func(): battle.select([]))
		_update_cost_buttons()
		return

	var has_units: bool = not battle.selected.is_empty()
	var has_workers: bool = not battle.selection_workers().is_empty()
	if has_units:
		_btn_attack = _add_btn("Hujum", func(): _on_attack_mode())
		_add_btn("To'xta", func(): battle.command_stop())
		_add_btn("Ushla", func(): battle.command_hold())
		if has_workers:
			_add_btn("Qurish", func(): _toggle_build_menu(true))
		else:
			_btn_box = _add_btn("Ramka", func(): _toggle_box())
		_add_btn("Qo'shin", func(): battle.select_all_army())
		_add_btn("Bekor", func(): battle.select([]))
		if has_workers:
			_add_btn("Bo'sh\nishchi", func(): battle.select_idle_worker())
			_btn_box = _add_btn("Ramka", func(): _toggle_box())
	else:
		_add_btn("Qo'shin", func(): battle.select_all_army())
		_add_btn("Bo'sh\nishchi", func(): battle.select_idle_worker())
		_btn_box = _add_btn("Ramka", func(): _toggle_box())
	refresh_modes()


func _set_hero_menu(v: bool) -> void:
	_hero_menu_open = v
	refresh_commands()


func _hall_hero_commands(b) -> void:
	for hid in battle.player_faction.get("heroes", []):
		var hk := str(hid)
		if battle.sim.hero_owned(0, hk):
			continue
		var hd := GameData.unit_def(hk)
		var label: String = "%s\n%s" % [hd.get("name", hk), GameData.cost_text(hd.get("cost", {}))]
		if bool(hd.get("friend", false)):
			label = "Do'st: " + label
		var hb := _add_btn(label, func(): battle.command_train(hk), Vector2(150, 70))
		hb.add_theme_font_size_override("font_size", 15)
		hb.tooltip_text = str(hd.get("title", ""))
		_cost_buttons.append([hb, hd.get("cost", {})])
	for d in battle.sim.dead_heroes.get(0, []):
		var did := str(d.get("id", ""))
		var lvl := int(d.get("level", 1))
		var cost := {"oltin": 100 + 30 * lvl}
		var rb := _add_btn("Tiriltirish:\n%s %do" % [GameData.unit_def(did).get("name", did), cost["oltin"]], func(): battle.command_train("revive:" + did), Vector2(150, 70))
		rb.add_theme_font_size_override("font_size", 14)
		_cost_buttons.append([rb, cost])
	_add_btn("Orqaga", func(): _set_hero_menu(false))
	_update_cost_buttons()


func _neutral_commands(n) -> void:
	if bool(n.bdef.get("shop", false)):
		var list: Array = []
		for it in GameData.items():
			if bool(it.get("shop", false)):
				list.append(it)
		var per := 7
		var pages: int = int(ceil(float(list.size()) / per))
		_shop_page = clampi(_shop_page, 0, max(0, pages - 1))
		for i in range(_shop_page * per, min(list.size(), (_shop_page + 1) * per)):
			var it: Dictionary = list[i]
			var iid := str(it.get("id", ""))
			var ib := _add_btn("%s\n%do" % [it.get("name", iid), int(it.get("cost", 0))], func(): battle.command_buy(iid), Vector2(150, 64))
			ib.add_theme_font_size_override("font_size", 13)
			ib.tooltip_text = str(it.get("desc", ""))
			_cost_buttons.append([ib, {"oltin": int(it.get("cost", 0))}])
		_add_btn("Keyingi\n(%d/%d)" % [_shop_page + 1, pages], func(): _next_shop_page(pages))
		_add_btn("Bekor", func(): battle.select([]))
		_update_cost_buttons()
		return
	var mercs = n.bdef.get("mercenaries", [])
	if mercs is Array:
		for mid in mercs:
			var mk := str(mid)
			var md := GameData.unit_def(mk)
			var mb := _add_btn("%s\n%s" % [md.get("name", mk), GameData.cost_text(md.get("cost", {}))], func(): battle.command_hire(mk), Vector2(170, 70))
			mb.add_theme_font_size_override("font_size", 14)
			_cost_buttons.append([mb, md.get("cost", {})])
	_add_btn("Bekor", func(): battle.select([]))
	_update_cost_buttons()


func _next_shop_page(pages: int) -> void:
	_shop_page = (_shop_page + 1) % max(1, pages)
	refresh_commands()


func _hero_commands(h) -> void:
	_ability_buttons = []
	for i in h.abilities.size():
		var a: Dictionary = h.abilities[i]
		var idx := i
		var lvl := int(h.ab_levels[i])
		var maxl: int = h.max_ability_level(i)
		var dots: String = "%d/%d" % [lvl, maxl]
		var txt := ""
		var btn: Button
		if _learn_mode:
			txt = "+ %s\n%s" % [a.get("name", ""), dots]
			btn = _add_btn(txt, func(): _learn(idx), Vector2(150, 64))
			if h.can_learn(i) != "":
				btn.modulate = Color(0.6, 0.6, 0.6, 0.45)
		else:
			var extra: String = "passiv" if str(a.get("kind", "")) == "passive" else "%d mana" % int(h.val(i, "mana"))
			txt = "%s\n%s %s" % [a.get("name", ""), dots, extra]
			btn = _add_btn(txt, func(): _ability_pressed(idx), Vector2(150, 64))
			if lvl <= 0:
				btn.modulate = Color(0.6, 0.6, 0.6, 0.45)
		btn.add_theme_font_size_override("font_size", 13)
		btn.tooltip_text = str(a.get("desc", ""))
		_ability_buttons.append(btn)
	if _learn_mode:
		_add_btn("Orqaga", func(): _set_learn(false))
	else:
		var lb := _add_btn("O'rganish\n(+%d)" % h.skill_points, func(): _set_learn(true))
		if h.skill_points <= 0:
			lb.modulate = Color(1, 1, 1, 0.5)
		else:
			UiStyle.set_active(lb, true)
		_btn_attack = _add_btn("Hujum", func(): _on_attack_mode())
		_add_btn("To'xta", func(): battle.command_stop())
		_add_btn("Ushla", func(): battle.command_hold())
		_add_btn("Bekor", func(): battle.select([]))
	refresh_modes()


func _set_learn(v: bool) -> void:
	_learn_mode = v
	refresh_commands()


func _learn(i: int) -> void:
	battle.command_learn(i)
	# Natija keyingi tick'da — biroz kutib yangilaymiz
	get_tree().create_timer(0.15).timeout.connect(_after_learn)


func _after_learn() -> void:
	var h = battle.selected_hero() if battle else null
	if h != null and h.skill_points <= 0:
		_learn_mode = false
	refresh_commands()


func _ability_pressed(i: int) -> void:
	var h = battle.selected_hero()
	if h == null:
		return
	var err: String = h.can_cast(i)
	if err != "":
		say(h.display_name, err, 0)
		return
	var kind := str(h.abilities[i].get("kind", ""))
	if kind == "none":
		battle.command_cast(i, -1, h.sim_pos)
	else:
		battle.controller.set_cast_mode(i)
		say("Maslahat", "Nishonni tanlang: " + ("dushmanga bosing" if kind == "unit" else "xaritaga bosing"), 0)


func _add_btn(text: String, cb: Callable, min_size: Vector2 = Vector2(130, 64)) -> Button:
	var btn := UiStyle.button(text, min_size)
	btn.pressed.connect(cb)
	_cmd_grid.add_child(btn)
	return btn


func _update_cost_buttons() -> void:
	for entry in _cost_buttons:
		var btn = entry[0]
		if not is_instance_valid(btn):
			continue
		var locked := false
		if entry.size() > 2:
			locked = battle.sim.meets(0, entry[2]) != ""
		if locked:
			btn.modulate = Color(0.6, 0.6, 0.6, 0.45)
		elif battle.sim.can_afford(0, entry[1]):
			btn.modulate = Color(1, 1, 1, 1)
		else:
			btn.modulate = Color(1, 1, 1, 0.55)


func _toggle_box() -> void:
	battle.controller.set_box_mode(not battle.controller.box_mode)


func _toggle_build_menu(open: bool) -> void:
	_build_menu_open = open
	refresh_commands()


func _choose_building(kind: String) -> void:
	_build_menu_open = false
	battle.begin_placement(kind)
	refresh_commands()


# ---------------- Ochiq funksiyalar ----------------

func is_over_ui(pos: Vector2) -> bool:
	for c in _ui:
		if is_instance_valid(c) and c.visible and c.get_global_rect().has_point(pos):
			return true
	return false


func set_box(r: Rect2) -> void:
	if overlay:
		overlay.box = r


var _daynight_label: Label = null


func set_daynight(phase: String, seconds_left: int) -> void:
	if _daynight_label == null and _timer_label != null:
		_daynight_label = UiStyle.label("", 18, Color(0.8, 0.9, 1.0))
		_timer_label.get_parent().add_child(_daynight_label)
		_timer_label.get_parent().move_child(_daynight_label, _timer_label.get_index())
	if _daynight_label:
		_daynight_label.text = "%s %d:%02d" % [Loc.t(phase), seconds_left / 60, seconds_left % 60]
		_daynight_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0) if phase == "Tun" else Color(1.0, 0.92, 0.6))


func set_timer_text(t: String) -> void:
	if _timer_label:
		_timer_label.text = Loc.t(t)


var _obj_label: Label = null
var _obj_suffix: String = ""


func set_objective(t: String) -> void:
	if _obj_label:
		_obj_label.text = Loc.t(t) + _obj_suffix


## Uzunroq ko'rinadigan dialog (missiya skripti uchun): matn uzunligiga qarab ushlab turiladi.
func say_long(speaker: String, text: String, team: int) -> void:
	say(speaker, text, team)
	if _voice_tween and _voice_tween.is_valid():
		_voice_tween.kill()
	_voice.modulate.a = 1.0
	_voice_tween = create_tween()
	_voice_tween.tween_interval(clampf(2.0 + text.length() * 0.06, 3.0, 8.0))
	_voice_tween.tween_property(_voice, "modulate:a", 0.0, 0.6)


func say(speaker: String, text: String, team: int) -> void:
	if text == "" or _voice == null:
		return
	_voice.text = "%s: «%s»" % [Loc.t(speaker), Loc.t(text)]
	_voice.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0) if team == 0 else Color(1.0, 0.7, 0.55))
	if _voice_tween and _voice_tween.is_valid():
		_voice_tween.kill()
	_voice.modulate.a = 1.0
	_voice_tween = create_tween()
	_voice_tween.tween_interval(1.8)
	_voice_tween.tween_property(_voice, "modulate:a", 0.0, 0.6)


func refresh_modes() -> void:
	if battle == null or battle.controller == null:
		return
	if _btn_attack != null and is_instance_valid(_btn_attack):
		UiStyle.set_active(_btn_attack, battle.controller.attack_mode)
	if _btn_box != null and is_instance_valid(_btn_box):
		UiStyle.set_active(_btn_box, battle.controller.box_mode)
	for i in _ability_buttons.size():
		var ab = _ability_buttons[i]
		if is_instance_valid(ab):
			UiStyle.set_active(ab, battle.controller.cast_index == i)


func update_selection(list: Array) -> void:
	if _info_title == null:
		return
	_temp_unit = null
	_temp_res = null
	refresh_commands()
	if list.is_empty():
		_info_title.text = Loc.t("Hech narsa tanlanmagan")
		_info_body.text = Loc.t("Askar yoki binoga bosing.\nDehqon bilan konga yoki daraxtga bosing — yig'adi.\nQora joylar — hali ko'rilmagan hudud.")
		return
	if list.size() == 1:
		_fill_info(list[0])
		return
	var counts := {}
	for u in list:
		counts[u.display_name] = int(counts.get(u.display_name, 0)) + 1
	_info_title.text = Loc.t("%d ta birlik tanlandi") % list.size()
	var lines: Array = []
	for k in counts.keys():
		lines.append("%s × %d" % [k, counts[k]])
	_info_body.text = "\n".join(PackedStringArray(lines))


func _fill_info(u) -> void:
	if u.is_building():
		_fill_building_info(u)
		return
	if u.is_hero():
		_info_title.text = Loc.t("%s — %d-daraja") % [u.display_name, u.level]
		var xp_txt: String = Loc.t("maks.") if u.level >= Hero.MAX_LEVEL else "%d/%d" % [u.xp, u.xp_needed()]
		_info_body.text = Loc.t("%s\nSog'liq: %d/%d · Mana: %d/%d\nZarar: %d–%d · Sovut: %d · XP: %s") % [
			str(u.hdef.get("title", "")), int(ceil(u.hp)), int(u.max_hp), int(u.mana), int(u.max_mana),
			u.damage_min, u.damage_max, int(u.effective_armor()), xp_txt]
		return
	_info_title.text = u.display_name
	var txt: String = Loc.t("%s\nSog'liq: %d / %d\nZarar: %d–%d (%s)  Sovut: %d") % [
		u.role, int(ceil(u.hp)), int(u.max_hp), u.damage_min, u.damage_max, u.attack_type, int(u.armor)]
	if u.is_worker:
		var st: String = "Bo'sh"
		if u.state == Unit.State.GATHER:
			st = "Oltin qazimoqda" if u.gather_kind == "gold" else "Daraxt kesmoqda"
		elif u.state == Unit.State.RETURN:
			st = "Yukni olib bormoqda"
		elif u.state == Unit.State.BUILD:
			st = "Qurmoqda"
		elif u.state == Unit.State.MOVING:
			st = "Yo'lda"
		var cargo: String = ""
		if u.carry_amount > 0:
			cargo = Loc.t(" · yuk: %d %s") % [u.carry_amount, Loc.t("oltin" if u.carry_kind == "gold" else "yog'och")]
		txt = Loc.t("%s\nSog'liq: %d / %d\nHolat: %s%s") % [u.role, int(ceil(u.hp)), int(u.max_hp), Loc.t(st), cargo]
	_info_body.text = txt


func _fill_building_info(b) -> void:
	_info_title.text = b.display_name
	var lines: Array = []
	lines.append(Loc.t("Sog'liq: %d / %d") % [int(ceil(b.hp)), int(b.max_hp)])
	if not b.complete:
		lines.append(Loc.t("Qurilmoqda: %d%%") % int(b.progress * 100.0))
		lines.append(Loc.t("Dehqonni tanlab, binoga bosing — yordam beradi"))
	else:
		lines.append(b.role)
		if not b.queue.is_empty():
			var extra: String = ""
			if b.queue.size() > 1:
				extra = Loc.t("  (+%d navbatda)") % (b.queue.size() - 1)
			lines.append("Jarayon: %s %d%%%s" % [b.queue_label(), int(b.current_train_ratio() * 100.0), extra])
		if b.food_provided > 0:
			lines.append(Loc.t("Oziq beradi: +%d") % b.food_provided)
		if b.has_attack:
			lines.append(Loc.t("Zarar: %d–%d · masofa: %d") % [b.damage_min, b.damage_max, int(b.attack_range)])
		if b.has_effect("rooted"):
			lines.append(Loc.t("Ildiz tarmog'iga ulangan (+3 sog'liq/s)"))
		if float(b.bdef.get("mist", 0.0)) > 0.0:
			lines.append(Loc.t("Qora Tuman yoyadi"))
	_info_body.text = "\n".join(PackedStringArray(lines))


func show_enemy_info(u) -> void:
	_temp_unit = u
	_temp_res = null
	_temp_info_until = Time.get_ticks_msec() / 1000.0 + 3.0
	_fill_info(u)
	_info_title.text = Loc.t("Dushman: %s") % u.display_name


func show_resource_info(n) -> void:
	_temp_res = n
	_temp_unit = null
	_temp_info_until = Time.get_ticks_msec() / 1000.0 + 3.0
	_info_title.text = n.display_name
	_info_body.text = Loc.t("Qolgan: %d %s\nDehqonni tanlab, shu yerga bosing") % [n.amount, Loc.t("oltin" if n.kind == "gold" else "yog'och")]


func show_end(victory: bool, has_outro: bool) -> void:
	refresh_commands()
	_end_panel = PanelContainer.new()
	root.add_child(_end_panel)
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_end_panel.add_child(vb)
	var title := UiStyle.label("G'ALABA!" if victory else "MAG'LUBIYAT", 48, Color(1.0, 0.85, 0.3) if victory else Color(1.0, 0.4, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var txt: String = "Dushman butunlay yengildi!" if victory else "Vodiy himoyachilari yengildi..."
	var body := UiStyle.label(txt, 22)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(body)
	var st: Dictionary = battle.stats
	var secs: int = int(st.get("time", 0.0))
	var stat_txt: String = Loc.t("Vaqt: %d:%02d · Tayyorlangan: %d · Qurilgan: %d\nYo'q qilingan dushman: %d · Yo'qotish: %d · Yig'ilgan oltin: %d") % [
		secs / 60, secs % 60, int(st.get("trained", 0)), int(st.get("built", 0)),
		int(st.get("killed", 0)), int(st.get("lost", 0)), int(st.get("gold", 0))]
	var sl := UiStyle.label(stat_txt, 18, Color(0.85, 0.9, 1.0))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sl)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	if victory and has_outro:
		var cont := UiStyle.button("Davom etish", Vector2(190, 64))
		cont.pressed.connect(func(): battle.choose_end("continue"))
		hb.add_child(cont)
	var retry := UiStyle.button("Qayta o'ynash", Vector2(190, 64))
	retry.pressed.connect(func(): battle.choose_end("retry"))
	hb.add_child(retry)
	var menu := UiStyle.button("Menyu", Vector2(150, 64))
	menu.pressed.connect(func(): battle.choose_end("menu"))
	hb.add_child(menu)
	_ui.append(_end_panel)
	_end_panel.modulate.a = 0.0
	create_tween().tween_property(_end_panel, "modulate:a", 1.0, 0.5)


# ---------------- Tugmalar ----------------

func _on_attack_mode() -> void:
	if battle.selected.is_empty():
		say("Maslahat", "Avval askarlarni tanlang", 0)
		return
	battle.controller.set_attack_mode(not battle.controller.attack_mode)
	if battle.controller.attack_mode:
		say("Maslahat", "Endi xaritaga bosing — yo'lda uchraganga hujum qiladi", 0)


func _on_speed() -> void:
	var s: float = battle.sim.speed
	if s < 1.25:
		s = 1.5
	elif s < 1.75:
		s = 2.0
	else:
		s = 1.0
	battle.sim.speed = s
	_btn_speed.text = ("%sx" % s).replace(".0x", "x")


func _on_pause() -> void:
	battle.sim.paused = not battle.sim.paused
	_pause_label.visible = battle.sim.paused
	_btn_pause.text = Loc.t("Davom" if battle.sim.paused else "Pauza")


var _refresh_acc: float = 0.0
var _last_building_sig: String = ""


func _process(delta: float) -> void:
	if battle == null or battle.sim == null:
		return
	var sim: Simulation = battle.sim
	_gold_l.text = Loc.t("Oltin: %d") % sim.gold(0)
	_wood_l.text = Loc.t("Yog'och: %d") % sim.wood(0)
	var used: int = sim.food_used(0)
	var cap: int = sim.food_cap(0)
	_food_l.text = Loc.t("Oziq: %d/%d") % [used, cap]
	_food_l.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if used >= cap and cap > 0 else Color(0.7, 1.0, 0.6))

	var now: float = Time.get_ticks_msec() / 1000.0
	if _temp_unit != null or _temp_res != null:
		if now > _temp_info_until:
			_temp_unit = null
			_temp_res = null
			update_selection(battle.selected)
		elif _temp_unit != null:
			if not is_instance_valid(_temp_unit) or not _temp_unit.alive:
				_temp_unit = null
				update_selection(battle.selected)
			else:
				_fill_info(_temp_unit)
				_info_title.text = Loc.t("Dushman: %s") % _temp_unit.display_name
	elif battle.selected.size() == 1 and is_instance_valid(battle.selected[0]):
		_fill_info(battle.selected[0])

	_refresh_acc += delta
	if _refresh_acc > 0.5:
		_refresh_acc = 0.0
		_update_cost_buttons()
		refresh_hero_bar()
		_refresh_inventory()
		var hsel = battle.selected_hero()
		if hsel != null:
			var hsig: String = "%d|%d|%s|%d" % [hsel.uid, hsel.skill_points, str(hsel.ab_levels), int(hsel.mana / 10.0)]
			if hsig != _last_building_sig:
				_last_building_sig = hsig
				refresh_commands()
		# Bino tanlangan bo'lsa, navbat holati o'zgarganda tugmalarni yangilaymiz
		var sb = battle.selected_building()
		if sb != null:
			var sig: String = "%s|%d|%s" % [sb.unit_id, sb.queue.size(), str(battle.sim.upgrades.get(0, {}))]
			if sig != _last_building_sig:
				_last_building_sig = sig
				refresh_commands()


# ---------------- O'yin menyusi (pauza) ----------------

var _game_menu: PanelContainer = null
var _menu_was_paused: bool = false


func _open_game_menu() -> void:
	if _game_menu != null and is_instance_valid(_game_menu):
		return
	_menu_was_paused = battle.sim.paused
	battle.sim.paused = true
	_game_menu = PanelContainer.new()
	root.add_child(_game_menu)
	_game_menu.set_anchors_preset(Control.PRESET_CENTER)
	_game_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_game_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_game_menu.add_child(vb)
	var t := UiStyle.label("Pauza", 36, Color(1.0, 0.85, 0.35))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	var b1 := UiStyle.button("Davom", Vector2(320, 60))
	b1.pressed.connect(_close_game_menu)
	vb.add_child(b1)
	if not battle.over:
		var b2 := UiStyle.button("Saqlash", Vector2(320, 60))
		b2.pressed.connect(_on_save_pressed)
		vb.add_child(b2)
		var b3 := UiStyle.button("Saqlab menyuga chiqish", Vector2(320, 60))
		b3.pressed.connect(_on_save_exit)
		vb.add_child(b3)
	var b4 := UiStyle.button("Jangni tark etish", Vector2(320, 60))
	b4.pressed.connect(_on_leave)
	vb.add_child(b4)


func _close_game_menu() -> void:
	if _game_menu != null and is_instance_valid(_game_menu):
		_game_menu.visible = false
		_game_menu.queue_free()
	_game_menu = null
	battle.sim.paused = _menu_was_paused
	_pause_label.visible = battle.sim.paused


func _on_save_pressed() -> void:
	var ok: bool = battle.save_game()
	_close_game_menu()
	say("Xabar", "O'yin saqlandi" if ok else "Saqlab bo'lmadi", 0)


func _on_save_exit() -> void:
	battle.save_game()
	battle.choose_end("menu")


func _on_leave() -> void:
	battle.choose_end("menu")
