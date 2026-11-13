class_name CampaignScreen
extends Node
## Kampaniya ekrani: boblar va missiyalar ro'yxati. Bajarilgan missiya belgilanadi,
## keyingisi oldingisi bajarilgandan keyin ochiladi. Bog'liqlik: SaveSystem, GameData, UiStyle, Loc.

signal play(mission_id: String)
signal back


func _ready() -> void:
	var vb := UiStyle.screen(self, "Kampaniya")
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	sc.add_child(list)
	var n := 0
	for ch in SaveSystem.campaign():
		var head := UiStyle.label(str(ch.get("title", "")), 30, Color(1.0, 0.8, 0.4))
		list.add_child(head)
		var fname: String = GameData.faction_short(str(ch.get("faction", "")))
		if fname != "":
			var sub := UiStyle.label(fname, 20, Color(0.8, 0.8, 0.75))
			list.add_child(sub)
		for mid in ch.get("missions", []):
			n += 1
			var mission_id: String = str(mid)
			var m := GameData.mission_def(mission_id)
			if m.is_empty():
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			list.add_child(row)
			var unlocked: bool = SaveSystem.is_unlocked(mission_id)
			var done: bool = SaveSystem.is_completed(mission_id)
			var txt := VBoxContainer.new()
			txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(txt)
			var tl := Label.new()
			tl.text = str(m.get("title", mission_id))
			tl.add_theme_font_size_override("font_size", 24)
			tl.add_theme_color_override("font_color", Color(1, 0.96, 0.86) if unlocked else Color(0.55, 0.55, 0.55))
			txt.add_child(tl)
			var ol := Label.new()
			ol.text = str(m.get("objective", ""))
			ol.add_theme_font_size_override("font_size", 18)
			ol.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ol.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8) if unlocked else Color(0.5, 0.5, 0.5))
			txt.add_child(ol)
			var status := UiStyle.label("Bajarildi" if done else "", 20, Color(0.5, 1.0, 0.55) if done else Color(1.0, 0.5, 0.4))
			status.custom_minimum_size = Vector2(150, 0)
			row.add_child(status)
			if not unlocked and bool(ch.get("requires_all", false)):
				status.text = Loc.t("Barcha 4 bobni tugating")
			var pb := UiStyle.button("Boshlash" if unlocked else "Qulflangan", Vector2(180, 60))
			pb.disabled = not unlocked
			pb.pressed.connect(func(): play.emit(mission_id))
			row.add_child(pb)
	var rb := UiStyle.hrow(vb)
	var bb := UiStyle.button("Orqaga", Vector2(220, 60))
	bb.pressed.connect(_on_back)
	rb.add_child(bb)


func _on_back() -> void:
	back.emit()
