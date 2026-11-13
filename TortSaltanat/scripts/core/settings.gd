class_name Settings
extends RefCounted
## O'yin sozlamalari: til, musiqa va effektlar ovozi, soyalar, grafika sifati, kadr chastotasi.
## user://settings.cfg faylida saqlanadi. Bog'liqlik: Loc, GameData.

const PATH := "user://settings.cfg"

static var lang: String = "uz"
static var music_vol: float = 0.7
static var sfx_vol: float = 0.8
static var shadows: bool = true
static var quality: String = "yuqori"   # past | orta | yuqori
static var max_fps: int = 60
static var _loaded: bool = false


static func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		lang = str(cf.get_value("o'yin", "lang", lang))
		music_vol = float(cf.get_value("ovoz", "music", music_vol))
		sfx_vol = float(cf.get_value("ovoz", "sfx", sfx_vol))
		shadows = bool(cf.get_value("grafika", "shadows", shadows))
		quality = str(cf.get_value("grafika", "quality", quality))
		max_fps = int(cf.get_value("grafika", "max_fps", max_fps))
	else:
		# Birinchi ishga tushish: telefon tiliga qarab tanlaymiz
		var sys: String = OS.get_locale_language()
		if sys == "ru":
			lang = "ru"
		elif sys == "uz":
			lang = "uz"
		elif sys == "en":
			lang = "en"
	_loaded = true
	apply()


static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("o'yin", "lang", lang)
	cf.set_value("ovoz", "music", music_vol)
	cf.set_value("ovoz", "sfx", sfx_vol)
	cf.set_value("grafika", "shadows", shadows)
	cf.set_value("grafika", "quality", quality)
	cf.set_value("grafika", "max_fps", max_fps)
	cf.save(PATH)


static func set_language(l: String) -> void:
	if l == Loc.lang:
		return
	lang = l
	Loc.set_lang(l)
	GameData.clear_cache()


static func _bus(bus_name: String) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx


static func _set_vol(bus_name: String, v: float) -> void:
	var idx: int = _bus(bus_name)
	AudioServer.set_bus_mute(idx, v <= 0.01)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.01, v)))


static func apply() -> void:
	Loc.set_lang(lang)
	_set_vol("Music", music_vol)
	_set_vol("SFX", sfx_vol)
	Engine.max_fps = max_fps


## 3D sahna yaratilgandan keyin chaqiriladi (soyalar va o'lcham sifati).
static func apply_to_viewport(vp: Viewport) -> void:
	if vp == null:
		return
	var sc: float = 1.0
	if quality == "past":
		sc = 0.6
	elif quality == "orta":
		sc = 0.8
	vp.scaling_3d_scale = sc
	vp.msaa_3d = Viewport.MSAA_DISABLED if quality == "past" else Viewport.MSAA_2X


static func quality_names() -> Array:
	return ["past", "orta", "yuqori"]
