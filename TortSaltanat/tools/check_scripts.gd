extends SceneTree
## CI uchun tekshiruv: res://scripts ichidagi barcha .gd fayllarni yuklaydi va
## JSON ma'lumot fayllarini tahlil qiladi. Xato bo'lsa "SKRIPT XATO" yozib, 1 kod bilan chiqadi.

func _init() -> void:
	var bad := 0
	for path in _find_files("res://scripts", ".gd"):
		var s = load(path)
		if s == null or not (s is Script) or not s.can_instantiate():
			print("SKRIPT XATO: ", path)
			bad += 1
		else:
			print("ok  ", path)
	for path in _find_files("res://data", ".json"):
		var txt := FileAccess.get_file_as_string(path)
		var parsed = JSON.parse_string(txt)
		if parsed == null:
			print("SKRIPT XATO (JSON): ", path)
			bad += 1
		else:
			print("ok  ", path)
	print("Tekshiruv tugadi. Xatolar: ", bad)
	quit(1 if bad > 0 else 0)


func _find_files(dir_path: String, ext: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := dir_path + "/" + name
			if dir.current_is_dir():
				out.append_array(_find_files(full, ext))
			elif name.ends_with(ext):
				out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out
