class_name SaveSystem
extends RefCounted
## O'yinni saqlash va kampaniya progressi.
## user://save_1.json — jang o'rtasidagi saqlash (bitta katak).
## user://progress.json — bajarilgan missiyalar ro'yxati.
## Bog'liqlik: GameData (kampaniya ro'yxati: res://data/campaign.json).

const SAVE_PATH := "user://save_1.json"
const PROGRESS_PATH := "user://progress.json"
const VERSION := 1


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func write_save(state: Dictionary) -> bool:
	state["save_version"] = VERSION
	state["saved_at"] = Time.get_datetime_string_from_system(false, true)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(state))
	f.close()
	return true


static func read_save() -> Dictionary:
	if not has_save():
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary and int(data.get("save_version", 0)) == VERSION:
		return data
	return {}


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------------- Kampaniya progressi ----------------

static func _progress() -> Dictionary:
	if not FileAccess.file_exists(PROGRESS_PATH):
		return {"completed": []}
	var data = JSON.parse_string(FileAccess.get_file_as_string(PROGRESS_PATH))
	if data is Dictionary and data.get("completed", null) is Array:
		return data
	return {"completed": []}


static func is_completed(mission_id: String) -> bool:
	var arr: Array = _progress()["completed"]
	return arr.has(mission_id)


static func mark_completed(mission_id: String) -> void:
	var p := _progress()
	var arr: Array = p["completed"]
	if arr.has(mission_id):
		return
	arr.append(mission_id)
	p["completed"] = arr
	var f := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(p))
		f.close()


## Kampaniya: bob ro'yxati va missiyalar tartibi.
static func campaign() -> Array:
	var d = GameData.load_json("res://data/campaign.json")
	if d is Dictionary and d.get("chapters", null) is Array:
		return d["chapters"]
	return []


## Missiya ochiqmi: har bobning birinchi missiyasi ochiq, keyingilari oldingisi bajarilgach.
## "requires_all" bobi (final) — boshqa barcha boblarning oxirgi missiyasi bajarilgach.
static func is_unlocked(mission_id: String) -> bool:
	var chapters := campaign()
	for ch in chapters:
		var ids: Array = ch.get("missions", [])
		var idx: int = ids.find(mission_id)
		if idx < 0:
			continue
		if idx > 0:
			return is_completed(str(ids[idx - 1]))
		if bool(ch.get("requires_all", false)):
			for other in chapters:
				if bool(other.get("requires_all", false)):
					continue
				var oids: Array = other.get("missions", [])
				if not oids.is_empty() and not is_completed(str(oids[oids.size() - 1])):
					return false
		return true
	return true
