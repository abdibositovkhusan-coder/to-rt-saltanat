class_name CreditsScreen
extends Node
## Mualliflar ekrani. Bog'liqlik: UiStyle, Loc.

signal back


func _ready() -> void:
	var vb := UiStyle.screen(self, "Mualliflar")
	var lines := [
		["G'oya va loyiha muallifi", "Husan"],
		["Kod: Claude (Anthropic) yordamida", ""],
		["3D modellar", "Kay Lousberg — KayKit (CC0): Adventurers, Skeletons, Medieval Hexagon, Halloween Bits"],
		["O'yin dvigateli", "Godot Engine 4.3 (MIT)"],
	]
	UiStyle.spacer(vb)
	for ln in lines:
		var a := UiStyle.label(str(ln[0]), 26, Color(1.0, 0.85, 0.5))
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(a)
		if str(ln[1]) != "":
			var b := Label.new()
			b.text = str(ln[1])
			b.add_theme_font_size_override("font_size", 22)
			b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(b)
	var thx := UiStyle.label("Rahmat!", 34, Color(1.0, 0.84, 0.35))
	thx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(thx)
	UiStyle.spacer(vb)
	var r := UiStyle.hrow(vb)
	var bb := UiStyle.button("Orqaga", Vector2(220, 64))
	bb.pressed.connect(_on_back)
	r.add_child(bb)


func _on_back() -> void:
	back.emit()
