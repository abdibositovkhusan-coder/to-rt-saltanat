class_name GameData
extends RefCounted
## Ma'lumot fayllarini (res://data/*.json) yuklaydi va keshlaydi.
## Birliklar, saltanatlar, missiyalar, kino-sahnalar va zarar jadvali shu yerdan o'qiladi.
## Bog'liqlik: yo'q (boshqa hamma skriptlar shundan foydalanadi).

static var _cache: Dictionary = {}


static func load_json(path: String) -> Variant:
	if _cache.has(path):
		return _cache[path]
	if not FileAccess.file_exists(path):
		push_error("Fayl topilmadi: " + path)
		return {}
	var txt: String = FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	if data == null:
		push_error("JSON xato: " + path)
		data = {}
	if path != "res://data/localization.json":
		data = Loc.localize_data(data)
	_cache[path] = data
	return data


static func clear_cache() -> void:
	_cache.clear()


static func unit_def(id: String) -> Dictionary:
	if id == "":
		return {}
	var path: String = "res://data/units/%s.json" % id
	if not FileAccess.file_exists(path):
		path = "res://data/heroes/%s.json" % id
	if not FileAccess.file_exists(path):
		return {}
	var d = load_json(path)
	if d is Dictionary:
		return d
	return {}


static func is_hero(id: String) -> bool:
	return bool(unit_def(id).get("hero", false))


static func items() -> Array:
	var d = load_json("res://data/items/items.json")
	if d is Dictionary and d.get("items", null) is Array:
		return d["items"]
	return []


static func item_def(id: String) -> Dictionary:
	for it in items():
		if str(it.get("id", "")) == id:
			return it
	return {}


## Xp jadvali: n-darajaga chiqish uchun jami tajriba.
const XP_TABLE := [0, 0, 200, 500, 900, 1400, 2000, 2700, 3500, 4400, 5400]


static func building_def(id: String) -> Dictionary:
	var d = load_json("res://data/buildings/%s.json" % id)
	if d is Dictionary:
		return d
	return {}


static func upgrade_def(id: String) -> Dictionary:
	var d = load_json("res://data/upgrades/%s.json" % id)
	if d is Dictionary:
		return d
	return {}


static func cost_text(cost) -> String:
	if not (cost is Dictionary):
		return ""
	var parts: Array = []
	if int(cost.get("oltin", 0)) > 0:
		parts.append(Loc.t("%do") % int(cost["oltin"]))
	if int(cost.get("yogoch", 0)) > 0:
		parts.append(Loc.t("%dy") % int(cost["yogoch"]))
	return " ".join(PackedStringArray(parts))


static func faction_def(id: String) -> Dictionary:
	var d = load_json("res://data/factions/%s.json" % id)
	if d is Dictionary:
		return d
	return {}


## Saltanatning qisqa nomi (masalan "Elflar"), tarjima bilan.
static func faction_short(id: String) -> String:
	var shorts := {"odamlar": "Odamlar", "trollar": "Trollar", "elflar": "Elflar", "yalmogiz": "Yalmog'iz"}
	return Loc.t(str(shorts.get(id, id)))


static func mission_def(id: String) -> Dictionary:
	var d = load_json("res://data/missions/%s.json" % id)
	if d is Dictionary:
		return d
	return {}


static func cutscene_def(id: String) -> Dictionary:
	var d = load_json("res://data/cutscenes/%s.json" % id)
	if d is Dictionary:
		return d
	return {}


static func damage_mult(attack_type: String, armor_type: String) -> float:
	var t = load_json("res://data/damage_table.json")
	if t is Dictionary and t.has(attack_type):
		var row = t[attack_type]
		if row is Dictionary and row.has(armor_type):
			return float(row[armor_type])
	return 1.0


static func vec3(a, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


static func color(s, fallback: Color = Color.WHITE) -> Color:
	if s is String and s != "":
		return Color.from_string(s, fallback)
	return fallback
