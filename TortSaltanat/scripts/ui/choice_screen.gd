class_name ChoiceScreen
extends Node
## Tanlov ekrani: savol va 2–4 ta javob tugmasi (masalan, finalda saltanat va yakunni tanlash).
## Bog'liqlik: UiStyle, Loc.

signal chosen(index: int)


func setup(question: String, options: Array) -> void:
	var vb := UiStyle.screen(self, "Tanlang")
	UiStyle.spacer(vb)
	var q := UiStyle.label(question, 30, Color(0.95, 0.92, 0.85))
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(q)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(list)
	for i in options.size():
		var o = options[i]
		var txt: String = str(o.get("text", "")) if o is Dictionary else str(o)
		var b := UiStyle.button(txt, Vector2(560, 64))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var idx: int = i
		b.pressed.connect(func(): chosen.emit(idx))
		list.add_child(b)
	UiStyle.spacer(vb)
