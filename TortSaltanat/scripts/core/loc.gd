class_name Loc
extends RefCounted
## Tarjima tizimi (o'zbek / rus / ingliz). Kalit — o'zbekcha matnning o'zi.
## Loc.t("Qurish") -> "Строить". Formatli matnlar ("Oltin: %d") naqsh sifatida ham taniladi:
## tayyor "Oltin: 120" matni ham tarjima qilinadi. Ma'lumot: res://data/localization.json.
## Bog'liqlik: yo'q (Settings tilni shu yerga o'rnatadi).

const LANGS := ["uz", "ru", "en"]
const LANG_NAMES := {"uz": "O'zbekcha", "ru": "Русский", "en": "English"}
## Ma'lumot fayllarida tarjima qilinadigan maydonlar
const DATA_KEYS := ["name", "title", "objective"]

static var lang: String = "uz"
static var _table: Dictionary = {}
static var _tips: Array = []
static var _patterns: Array = []   # [{re, specs, key}]
static var _loaded: bool = false
static var _memo: Dictionary = {}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/localization.json"
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return
	var t = data.get("t", {})
	if t is Dictionary:
		_table = t
	var tp = data.get("tips", [])
	if tp is Array:
		_tips = tp
	_build_patterns()


static func _lang_index() -> int:
	return LANGS.find(lang) - 1


static func set_lang(l: String) -> void:
	if not LANGS.has(l):
		l = "uz"
	lang = l
	_memo.clear()


## Asosiy tarjima funksiyasi.
static func t(s: String) -> String:
	if lang == "uz" or s == "":
		return s
	_ensure()
	if _memo.has(s):
		return str(_memo[s])
	var res: String = _translate(s)
	if _memo.size() > 3000:
		_memo.clear()
	_memo[s] = res
	return res


static func _translate(s: String) -> String:
	var r: String = _exact(s)
	if r != "":
		return r
	r = _pattern(s)
	if r != "":
		return r
	if s.contains("\n"):
		var parts: PackedStringArray = s.split("\n")
		var out: PackedStringArray = PackedStringArray()
		for p in parts:
			out.append(_line(p))
		return "\n".join(out)
	return s


static func _line(p: String) -> String:
	var r: String = _exact(p)
	if r != "":
		return r
	r = _pattern(p)
	if r != "":
		return r
	return p


static func _exact(s: String) -> String:
	var idx: int = _lang_index()
	if idx < 0:
		return ""
	var e = _table.get(s, null)
	if e is Array and e.size() > idx:
		var v: String = str(e[idx])
		if v != "":
			return v
	return ""


static func _escape(s: String) -> String:
	var special := "\\.^$|?*+()[]{}/"
	var out := ""
	for ch in s:
		if special.contains(ch):
			out += "\\" + ch
		else:
			out += ch
	return out


static func _build_patterns() -> void:
	_patterns.clear()
	for key in _table.keys():
		var k: String = str(key)
		if not k.contains("%"):
			continue
		var rx := "^"
		var specs: Array = []
		var i := 0
		var literal := 0
		while i < k.length():
			var ch: String = k[i]
			if ch == "%" and i + 1 < k.length():
				var nx: String = k[i + 1]
				if nx == "%":
					rx += "%"
					i += 2
					continue
				if nx == "s":
					rx += "(.+?)"
					specs.append("s")
					i += 2
					continue
				if nx == "d":
					rx += "(-?\\d+)"
					specs.append("d")
					i += 2
					continue
				if nx == "0" and i + 3 < k.length() and k[i + 3] == "d":
					rx += "(\\d+)"
					specs.append("d")
					i += 4
					continue
			rx += _escape(ch)
			literal += 1
			i += 1
		rx += "$"
		if literal < 3:
			continue
		var re := RegEx.new()
		if re.compile(rx) != OK:
			continue
		_patterns.append({"re": re, "specs": specs, "key": k, "lit": literal})
	# Uzunroq (aniqroq) naqshlar oldin tekshiriladi — oddiy saralash
	for i in range(1, _patterns.size()):
		var cur: Dictionary = _patterns[i]
		var j: int = i - 1
		while j >= 0 and int(_patterns[j]["lit"]) < int(cur["lit"]):
			_patterns[j + 1] = _patterns[j]
			j -= 1
		_patterns[j + 1] = cur


static func _pattern(s: String) -> String:
	for p in _patterns:
		var re: RegEx = p["re"]
		var m: RegExMatch = re.search(s)
		if m == null:
			continue
		var tmpl: String = _exact(str(p["key"]))
		if tmpl == "":
			return ""
		var specs: Array = p["specs"]
		var args: Array = []
		for gi in specs.size():
			var cap: String = m.get_string(gi + 1)
			if str(specs[gi]) == "d":
				args.append(int(cap))
			else:
				var trans: String = _exact(cap)
				args.append(trans if trans != "" else cap)
		if args.is_empty():
			return tmpl
		return tmpl % args
	return ""


## Ma'lumot (JSON) ichidagi nomlarni tarjima qiladi — GameData yuklashda chaqiradi.
static func localize_data(v: Variant) -> Variant:
	if lang == "uz":
		return v
	_ensure()
	if v is Dictionary:
		for k in v.keys():
			var val = v[k]
			if DATA_KEYS.has(str(k)) and val is String:
				var trans: String = _exact(val)
				if trans != "":
					v[k] = trans
			elif val is Dictionary or val is Array:
				localize_data(val)
	elif v is Array:
		for item in v:
			if item is Dictionary or item is Array:
				localize_data(item)
	return v


static func tips() -> Array:
	_ensure()
	var out: Array = []
	for tp in _tips:
		out.append(t(str(tp)))
	return out
