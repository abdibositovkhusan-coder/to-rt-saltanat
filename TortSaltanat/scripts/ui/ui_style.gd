class_name UiStyle
extends RefCounted
## Umumiy interfeys uslubi: to'q jigarrang panellar, oltin hoshiya, koshin-ko'k tugmalar.
## Telefon uchun katta tugmalar va shriftlar. Bog'liqlik: yo'q.

const GOLD := Color(0.83, 0.65, 0.23)
const PANEL_BG := Color(0.11, 0.08, 0.06, 0.88)
const BTN_BG := Color(0.16, 0.33, 0.58, 0.95)
const BTN_HOVER := Color(0.22, 0.42, 0.7, 0.98)
const BTN_PRESSED := Color(0.62, 0.45, 0.12, 1.0)


static func _flat(bg: Color, border: Color, bw: int, radius: int, margin: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 20
	th.set_stylebox("panel", "PanelContainer", _flat(PANEL_BG, GOLD, 2, 10, 10.0))
	th.set_stylebox("panel", "Panel", _flat(PANEL_BG, GOLD, 2, 10, 10.0))
	th.set_stylebox("normal", "Button", _flat(BTN_BG, GOLD.darkened(0.3), 2, 8, 8.0))
	th.set_stylebox("hover", "Button", _flat(BTN_HOVER, GOLD, 2, 8, 8.0))
	th.set_stylebox("pressed", "Button", _flat(BTN_PRESSED, GOLD.lightened(0.3), 2, 8, 8.0))
	th.set_stylebox("disabled", "Button", _flat(Color(0.25, 0.25, 0.25, 0.8), Color(0.4, 0.4, 0.4), 2, 8, 8.0))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color(1, 0.97, 0.88))
	th.set_color("font_hover_color", "Button", Color(1, 1, 1))
	th.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	th.set_color("font_color", "Label", Color(1, 0.96, 0.86))
	th.set_color("font_outline_color", "Label", Color(0, 0, 0))
	th.set_constant("outline_size", "Label", 4)
	return th


static func button(text: String, min_size: Vector2 = Vector2(130, 64)) -> Button:
	var b := Button.new()
	b.text = Loc.t(text)
	b.pressed.connect(func(): Audio.play("click", -6.0))
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b


static func label(text: String, font_size: int = 20, color: Color = Color(1, 0.96, 0.86)) -> Label:
	var l := Label.new()
	l.text = Loc.t(text)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func set_active(b: Button, active: bool) -> void:
	if active:
		b.add_theme_stylebox_override("normal", _flat(BTN_PRESSED, GOLD.lightened(0.3), 3, 8, 8.0))
	else:
		b.remove_theme_stylebox_override("normal")


## Menyu ekranlari uchun umumiy ildiz: CanvasLayer + to'q fon + ichki VBox.
## Qaytaradi: VBoxContainer (ekran mazmuni shu yerga qo'shiladi).
static func screen(owner_node: Node, title_text: String, layer: int = 4) -> VBoxContainer:
	var ui := CanvasLayer.new()
	ui.layer = layer
	owner_node.add_child(ui)
	var root := Control.new()
	root.theme = make_theme()
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
	vb.offset_top = 18
	vb.offset_bottom = -18
	var title := label(title_text, 40, Color(1.0, 0.84, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	return vb


static func hrow(parent: Control, sep: int = 10, centered: bool = true) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	if centered:
		r.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(r)
	return r


static func spacer(parent: Control) -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	return c
