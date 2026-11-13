class_name LoadingScreen
extends CanvasLayer
## Yuklanish ekrani: missiya nomi, maslahat va «Yuklanmoqda...» yozuvi.
## Jang sahnasi qurilayotganda ko'rinib turadi, keyin sekin yo'qoladi.
## Bog'liqlik: UiStyle, Loc.

var _root: Control


func setup(title_text: String) -> void:
	layer = 20
	_root = Control.new()
	_root.theme = UiStyle.make_theme()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.035, 0.03)
	_root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 22)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(vb)
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 120
	vb.offset_right = -120
	var t := UiStyle.label("TO'RT SALTANAT", 56, Color(1.0, 0.84, 0.35))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 10)
	vb.add_child(t)
	var m := UiStyle.label(title_text, 30, Color(0.95, 0.9, 0.8))
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(m)
	var tips: Array = Loc.tips()
	if not tips.is_empty():
		var tip := UiStyle.label(Loc.t("Maslahat") + ": " + str(tips[randi() % tips.size()]), 22, Color(0.75, 0.9, 1.0))
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(tip)
	var l := UiStyle.label("Yuklanmoqda...", 24, Color(1.0, 0.85, 0.5))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)


func close() -> void:
	if _root == null:
		queue_free()
		return
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
