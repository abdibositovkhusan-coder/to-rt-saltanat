class_name MissionScript
extends Node
## Missiya skripti: g'alaba/mag'lubiyat shartlari va triggerlar (dialog, qo'shimcha qo'shin,
## yangi vazifa, xaritani ochish, oltin, tun, to'lqin). Missiya JSON'idagi "victory", "defeat"
## va "triggers" maydonlaridan o'qiydi. Har 0,25 soniyada tekshiradi.
## Bog'liqlik: Battle, Simulation, GameData, GameCommand.
##
## "victory": {"type": "destroy_all" | "survive" | "kill_targets" | "destroy_buildings" | "reach",
##             "seconds": 360, "tag": "nishon", "buildings": ["tosh_gor"], "area": [x, z, r], "unit": "alpomish"}
## "defeat":   {"protect_building": "hayot_daraxti", "protect_unit": "alpomish"}
## trigger:    {"id": "t1", "when": {...}, "do": [...], "every": 60, "until": 400}
##   when: time, area+unit/team, dead (tag), alive_below, built, hero_level, after (+delay)
##   do:   say, spawn, objective, reveal, gold, wood, night, wave, victory, defeat

var battle = null
var sim = null
var m: Dictionary = {}
var elapsed: float = 0.0
var objective: String = ""
var _victory: Dictionary = {}
var _defeat: Dictionary = {}
var _triggers: Array = []
var _fired: Dictionary = {}      # id -> elapsed vaqti
var _next_repeat: Dictionary = {}
var _acc: float = 0.0
var _tag_seen: Dictionary = {}   # teg -> hech bo'lmasa bir marta paydo bo'lganmi


func setup(b, mission: Dictionary, state: Dictionary = {}) -> void:
	battle = b
	sim = b.sim
	m = mission
	objective = str(mission.get("objective", ""))
	var v = mission.get("victory", {})
	_victory = v if v is Dictionary else {}
	var d = mission.get("defeat", {})
	_defeat = d if d is Dictionary else {}
	var tl = mission.get("triggers", [])
	if tl is Array:
		var n := 0
		for t in tl:
			if t is Dictionary:
				var tt: Dictionary = t.duplicate(true)
				if not tt.has("id"):
					tt["id"] = "t%d" % n
				_triggers.append(tt)
				n += 1
	if not state.is_empty():
		elapsed = float(state.get("elapsed", 0.0))
		objective = str(state.get("objective", objective))
		var f = state.get("fired", {})
		if f is Dictionary:
			_fired = f
		var r = state.get("repeat", {})
		if r is Dictionary:
			_next_repeat = r
		var ts = state.get("tags", {})
		if ts is Dictionary:
			_tag_seen = ts


func save_state() -> Dictionary:
	return {"elapsed": elapsed, "objective": objective, "fired": _fired, "repeat": _next_repeat, "tags": _tag_seen}


func victory_type() -> String:
	return str(_victory.get("type", "destroy_all"))


## Battle._process'dan chaqiriladi (o'yin vaqti bilan).
func step(dt: float) -> void:
	elapsed += dt
	_acc += dt
	if _acc < 0.25:
		return
	_acc = 0.0
	_note_tags()
	for t in _triggers:
		var id: String = str(t["id"])
		if t.has("every"):
			_repeat_step(t, id)
			continue
		if _fired.has(id):
			continue
		if _cond(t.get("when", {})):
			_fired[id] = elapsed
			_run(t.get("do", []))
	_timer_text()
	_check_end()


func _repeat_step(t: Dictionary, id: String) -> void:
	var start: float = float(t.get("from", 0.0))
	var until: float = float(t.get("until", 99999.0))
	if elapsed < start or elapsed > until:
		return
	var w = t.get("when", {})
	if w is Dictionary and not w.is_empty() and not _cond(w):
		return
	var nxt: float = float(_next_repeat.get(id, start))
	if elapsed >= nxt:
		_next_repeat[id] = elapsed + float(t["every"])
		_run(t.get("do", []))


func _note_tags() -> void:
	for u in sim.units:
		if u.alive and u.script_tag != "":
			_tag_seen[u.script_tag] = true


# ---------------- Shartlar ----------------

func _cond(w) -> bool:
	if not (w is Dictionary) or w.is_empty():
		return true
	if w.has("time") and elapsed < float(w["time"]):
		return false
	if w.has("after"):
		var aid: String = str(w["after"])
		if not _fired.has(aid):
			return false
		if elapsed < float(_fired[aid]) + float(w.get("delay", 0.0)):
			return false
	if w.has("area"):
		var a: Array = w["area"]
		var team: int = int(w.get("team", 0))
		var who: String = str(w.get("unit", ""))
		if not _in_area(Vector3(float(a[0]), 0, float(a[1])), float(a[2]), team, who):
			return false
	if w.has("dead"):
		if _tag_count(str(w["dead"])) > 0 or not _tag_seen.has(str(w["dead"])):
			return false
	if w.has("alive_below"):
		var ab: Array = w["alive_below"]
		if _tag_count(str(ab[0])) >= int(ab[1]):
			return false
	if w.has("enemy_below"):
		if _team_count(1) >= int(w["enemy_below"]):
			return false
	if w.has("built"):
		if not _has_building(0, str(w["built"])):
			return false
	if w.has("hero_level"):
		var best := 0
		for u in sim.units:
			if u.alive and u.team == 0 and u.is_hero():
				best = maxi(best, int(u.level))
		if best < int(w["hero_level"]):
			return false
	return true


func _in_area(c: Vector3, r: float, team: int, who: String) -> bool:
	for u in sim.units:
		if not u.alive or u.team != team or u.is_building():
			continue
		if who != "" and u.unit_id != who:
			continue
		if Vector2(u.sim_pos.x - c.x, u.sim_pos.z - c.z).length() <= r:
			return true
	return false


func _tag_count(tag: String) -> int:
	var n := 0
	for u in sim.units:
		if u.alive and u.script_tag == tag:
			n += 1
	return n


func _team_count(team: int) -> int:
	var n := 0
	for u in sim.units:
		if u.alive and u.team == team:
			n += 1
	return n


func _has_building(team: int, kind: String) -> bool:
	for u in sim.units:
		if u.alive and u.team == team and u.is_building() and u.unit_id == kind:
			if not ("complete" in u) or u.complete:
				return true
	return false


# ---------------- Amallar ----------------

func _run(actions) -> void:
	if not (actions is Array):
		return
	for a in actions:
		if not (a is Dictionary):
			continue
		if a.has("say"):
			var s: Array = a["say"]
			var team: int = int(a.get("team", 0 if s.size() < 3 else int(s[2])))
			if battle.hud:
				battle.hud.say_long(str(s[0]), str(s[1]), team)
		if a.has("spawn"):
			_spawn(a["spawn"])
		if a.has("objective"):
			objective = str(a["objective"])
			if battle.hud:
				battle.hud.set_objective(objective)
				battle.hud.say("Vazifa", objective, 0)
		if a.has("reveal") and battle.fog != null:
			var r: Array = a["reveal"]
			battle.fog.add_reveal(0, Vector3(float(r[0]), 0, float(r[1])), float(r[2]), float(a.get("reveal_time", 20.0)))
		if a.has("gold"):
			sim.add_resource(0, "gold", int(a["gold"]))
		if a.has("wood"):
			sim.add_resource(0, "wood", int(a["wood"]))
		if a.has("night"):
			battle.force_night(float(a["night"]))
		if a.has("wave"):
			_send_wave(str(a.get("wave_tag", "")))
		if bool(a.get("victory", false)):
			battle.script_end(true)
		if bool(a.get("defeat", false)):
			battle.script_end(false)


func _spawn(spec) -> void:
	var list: Array = spec if spec is Array else [spec]
	for g in list:
		if not (g is Dictionary):
			continue
		var team: int = int(g.get("team", 1))
		var at: Vector3 = GameData.vec3(g.get("at", null), Vector3.ZERO)
		var count: int = int(g.get("count", 1))
		var spawned: Array = []
		for i in count:
			var ang: float = TAU * float(i) / float(maxi(1, count))
			var rad: float = 0.0 if count == 1 else 1.4 + 0.25 * float(count)
			var off: Vector3 = Vector3(cos(ang), 0, sin(ang)) * rad
			var u = battle.spawn_unit(str(g.get("id", "")), team, at + off)
			if u == null:
				continue
			u.script_tag = str(g.get("tag", ""))
			battle.apply_spawn_level(u, int(g.get("level", 0)))
			spawned.append(u)
			if battle.fog == null or team == 0:
				battle.spawn_effect("ring", u.sim_pos)
		if spawned.is_empty():
			continue
		var ids: Array = []
		for u in spawned:
			ids.append(u.uid)
		if g.has("move_to"):
			var mt := GameData.vec3(g["move_to"], at)
			sim.push(GameCommand.make(GameCommand.Type.ATTACK_MOVE, ids, mt, -1, "", team))
		elif bool(g.get("attack", false)) and team == 1:
			sim.push(GameCommand.make(GameCommand.Type.ATTACK_MOVE, ids, _player_center(), -1, "", 1))


func _player_center() -> Vector3:
	# Avval binolar (baza), bo'lmasa qo'shin markazi
	var c := Vector3.ZERO
	var n := 0
	for u in sim.units:
		if u.alive and u.team == 0 and u.is_building():
			c += u.sim_pos
			n += 1
	if n == 0:
		for u in sim.units:
			if u.alive and u.team == 0:
				c += u.sim_pos
				n += 1
	if n == 0:
		return Vector3.ZERO
	return c / float(n)


func _send_wave(tag: String) -> void:
	var ids: Array = []
	for u in sim.units:
		if u.alive and u.team == 1 and not u.is_building() and not u.is_worker:
			if tag != "" and u.script_tag != tag:
				continue
			if u.state == Unit.State.IDLE or u.state == Unit.State.HOLD:
				ids.append(u.uid)
	if not ids.is_empty():
		sim.push(GameCommand.make(GameCommand.Type.ATTACK_MOVE, ids, _player_center(), -1, "", 1))


# ---------------- G'alaba / mag'lubiyat ----------------

func _timer_text() -> void:
	if battle.hud == null:
		return
	if victory_type() == "survive":
		var left: int = int(ceil(maxf(0.0, float(_victory.get("seconds", 300)) - elapsed)))
		battle.hud.set_timer_text(Loc.t("Omon qoling: %d:%02d") % [left / 60, left % 60])


func _check_end() -> void:
	if battle.over:
		return
	# Mag'lubiyat
	var pb: String = str(_defeat.get("protect_building", ""))
	if pb != "" and not _has_building(0, pb) and elapsed > 2.0:
		battle.script_end(false)
		return
	var pu: String = str(_defeat.get("protect_unit", ""))
	if pu != "" and elapsed > 2.0:
		var found := false
		for u in sim.units:
			if u.alive and u.team == 0 and u.unit_id == pu:
				found = true
				break
		if not found:
			battle.script_end(false)
			return
	# G'alaba
	match victory_type():
		"survive":
			if elapsed >= float(_victory.get("seconds", 300)):
				battle.script_end(true)
		"kill_targets":
			var tag: String = str(_victory.get("tag", "nishon"))
			if _tag_seen.has(tag) and _tag_count(tag) == 0:
				battle.script_end(true)
		"destroy_buildings":
			var left := 0
			for kind in _victory.get("buildings", []):
				for u in sim.units:
					if u.alive and u.team == 1 and u.is_building() and u.unit_id == str(kind):
						left += 1
			if left == 0 and elapsed > 2.0:
				battle.script_end(true)
		"reach":
			var a: Array = _victory.get("area", [0, 0, 5])
			if _in_area(Vector3(float(a[0]), 0, float(a[1])), float(a[2]), 0, str(_victory.get("unit", ""))):
				battle.script_end(true)
		_:
			pass
