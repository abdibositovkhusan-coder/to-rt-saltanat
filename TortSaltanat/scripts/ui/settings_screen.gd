class_name SettingsScreen
extends Node
## Sozlamalar: til, musiqa va effektlar ovozi, soyalar, grafika sifati, kadr chastotasi.
## Til o'zgarsa ekran qayta quriladi (lang_changed signali). Bog'liqlik: Settings, Loc, UiStyle.

signal back
signal lang_changed

var _lang_btns: Dictionary = {}
var _q_btns: Dictionary = {}
var _fps_btns: Dictionary = {}
var _shadow_btn: Button


func _ready() -> void:
	var vb := UiStyle.screen(self, "Sozlamalar")
	UiStyle.spacer(vb)

	var r1 := UiStyle.hrow(vb)
	r1.add_child(_cap("Til"))
	for l in Loc.LANGS:
		var b := Button.new()
		b.text = str(Loc.LANG_NAMES[l])
		b.custom_minimum_size = Vector2(170, 56)
		b.focus_mode = Control.FOCUS_NONE
		var ll: String = str(l)
		b.pressed.connect(func(): _pick_lang(ll))
		r1.add_child(b)
		_lang_btns[ll] = b

	var r2 := UiStyle.hrow(vb)
	r2.add_child(_cap("Musiqa"))
	r2.add_child(_slider(Settings.music_vol, _on_music))
	var r3 := UiStyle.hrow(vb)
	r3.add_child(_cap("Ovoz effektlari"))
	r3.add_child(_slider(Settings.sfx_vol, _on_sfx))

	var r4 := UiStyle.hrow(vb)
	r4.add_child(_cap("Soyalar"))
	_shadow_btn = UiStyle.button("", Vector2(170, 56))
	_shadow_btn.pressed.connect(_toggle_shadows)
	r4.add_child(_shadow_btn)

	var r5 := UiStyle.hrow(vb)
	r5.add_child(_cap("Grafika sifati"))
	for e in [["past", "Past"], ["orta", "O'rta"], ["yuqori", "Yuqori"]]:
		var qb := UiStyle.button(str(e[1]), Vector2(150, 56))
		var qq: String = str(e[0])
		qb.pressed.connect(func(): _pick_quality(qq))
		r5.add_child(qb)
		_q_btns[qq] = qb

	var r6 := UiStyle.hrow(vb)
	r6.add_child(_cap("Kadr chastotasi"))
	for f in [30, 60]:
		var fb := UiStyle.button("%d FPS" % f, Vector2(150, 56))
		var ff: int = int(f)
		fb.pressed.connect(func(): _pick_fps(ff))
		r6.add_child(fb)
		_fps_btns[ff] = fb

	if Loc.lang != "uz":
		var note := UiStyle.label("Hikoya, dialoglar va qobiliyat tavsiflari hozircha o'zbekcha", 18, Color(0.8, 0.8, 0.75))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(note)
	UiStyle.spacer(vb)
	var rb := UiStyle.hrow(vb)
	var bb := UiStyle.button("Orqaga", Vector2(220, 64))
	bb.pressed.connect(_on_back)
	rb.add_child(bb)
	_refresh()


func _cap(t: String) -> Label:
	var l := UiStyle.label(t, 24, Color(1.0, 0.85, 0.5))
	l.custom_minimum_size = Vector2(260, 0)
	return l


func _slider(v: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = v
	s.custom_minimum_size = Vector2(420, 48)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(cb)
	return s


func _refresh() -> void:
	for k in _lang_btns.keys():
		UiStyle.set_active(_lang_btns[k], k == Loc.lang)
	for k in _q_btns.keys():
		UiStyle.set_active(_q_btns[k], k == Settings.quality)
	for k in _fps_btns.keys():
		UiStyle.set_active(_fps_btns[k], int(k) == Settings.max_fps)
	_shadow_btn.text = Loc.t("Yoqilgan" if Settings.shadows else "O'chirilgan")
	UiStyle.set_active(_shadow_btn, Settings.shadows)


func _pick_lang(l: String) -> void:
	if l == Loc.lang:
		return
	Settings.set_language(l)
	Settings.save_settings()
	lang_changed.emit()


func _on_music(v: float) -> void:
	Settings.music_vol = v
	Settings.apply()


func _on_sfx(v: float) -> void:
	Settings.sfx_vol = v
	Settings.apply()


func _toggle_shadows() -> void:
	Settings.shadows = not Settings.shadows
	_refresh()


func _pick_quality(q: String) -> void:
	Settings.quality = q
	Settings.apply_to_viewport(get_viewport())
	_refresh()


func _pick_fps(f: int) -> void:
	Settings.max_fps = f
	Settings.apply()
	_refresh()


func _on_back() -> void:
	Settings.save_settings()
	back.emit()
