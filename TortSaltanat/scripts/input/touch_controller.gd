class_name TouchController
extends Node
## Telefon boshqaruvi: bosish (tanlash/yuborish/hujum), ikki marta bosish (shu turdagilarni tanlash),
## bir barmoq bilan surish (kamera yoki ramka bilan tanlash), ikki barmoq (siljitish + chimchilab zoom).
## Kompyuterda: sichqoncha g'ildiragi zoom, o'ng tugma — yuborish.
## Bog'liqlik: Battle, RtsCamera, BattleHud.

const TAP_MOVE_PX := 20.0
const TAP_TIME := 0.4
const DOUBLE_TAP_TIME := 0.4

var battle: Battle
var cam: RtsCamera
var hud: BattleHud

var box_mode: bool = false
var attack_mode: bool = false
var cast_index: int = -1

var _touches: Dictionary = {}
var _multi: bool = false
var _box_active: bool = false
var _pinch_dist: float = 0.0
var _pinch_mid: Vector2 = Vector2.ZERO
var _last_tap_time: float = -10.0
var _last_tap_uid: int = -1


func setup(b: Battle, c: RtsCamera, h: BattleHud) -> void:
	battle = b
	cam = c
	hud = h


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _unhandled_input(event: InputEvent) -> void:
	if battle == null or battle.over:
		return
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom_by(0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom_by(1.1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_command_at(event.position)


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		var over_ui := hud.is_over_ui(e.position)
		_touches[e.index] = {"start": e.position, "pos": e.position, "time": _now(), "ui": over_ui, "moved": false}
		var active := _active_points()
		if active.size() >= 2:
			_multi = true
			_box_active = false
			hud.set_box(Rect2())
			_pinch_dist = max(1.0, active[0].distance_to(active[1]))
			_pinch_mid = (active[0] + active[1]) * 0.5
		return

	if not _touches.has(e.index):
		return
	var t: Dictionary = _touches[e.index]
	_touches.erase(e.index)
	if t["ui"]:
		return
	if _box_active:
		_box_active = false
		var r := Rect2(t["start"], e.position - t["start"]).abs()
		hud.set_box(Rect2())
		battle.select_in_rect(r)
		return
	if _multi:
		if _touches.is_empty():
			_multi = false
		return
	if not t["moved"] and _now() - float(t["time"]) < TAP_TIME:
		_tap(e.position)


func _active_points() -> Array:
	var pts: Array = []
	for k in _touches.keys():
		var t: Dictionary = _touches[k]
		if not t["ui"]:
			pts.append(t["pos"])
	return pts


func _on_drag(e: InputEventScreenDrag) -> void:
	if not _touches.has(e.index):
		return
	var t: Dictionary = _touches[e.index]
	if t["ui"]:
		return
	var prev: Vector2 = t["pos"]
	t["pos"] = e.position
	var start: Vector2 = t["start"]
	if start.distance_to(e.position) > TAP_MOVE_PX:
		t["moved"] = true

	var active := _active_points()
	if active.size() >= 2:
		var mid: Vector2 = (active[0] + active[1]) * 0.5
		var dist: float = max(1.0, active[0].distance_to(active[1]))
		cam.drag_pan(_pinch_mid, mid)
		cam.zoom_by(_pinch_dist / dist)
		_pinch_mid = mid
		_pinch_dist = dist
		return
	if _multi or not t["moved"]:
		return
	if box_mode:
		_box_active = true
		hud.set_box(Rect2(start, e.position - start).abs())
	else:
		cam.drag_pan(prev, e.position)


func _tap(pos: Vector2) -> void:
	# Bino joylash rejimi: bosilgan joyga "arvoh" bino ko'chadi
	if battle.is_placing():
		var gp = cam.ground_point(pos)
		if gp != null:
			battle.move_ghost(gp)
		return
	# Qobiliyat nishonini tanlash rejimi
	if cast_index >= 0:
		var ci := cast_index
		set_cast_mode(-1)
		var tu = battle.pick_unit(pos)
		var gpos = cam.ground_point(pos)
		var h = battle.selected_hero()
		if h == null:
			return
		var kind := str(h.abilities[ci].get("kind", ""))
		if kind == "unit":
			if tu == null:
				hud.say("Maslahat", "Nishon sifatida dushmanni tanlang", 0)
				return
			battle.command_cast(ci, tu.uid, tu.sim_pos)
		elif gpos != null:
			battle.command_cast(ci, -1, gpos)
		return
	var u = battle.pick_unit(pos)
	if u != null:
		if u.is_building() and u.invulnerable:
			battle.select([u])
			return
		if u.team == 0:
			# Ishchilar tanlangan bo'lsa va tugallanmagan binoga bosilsa — qurishga yordam
			if u.is_building() and not u.complete and not battle.selection_workers().is_empty():
				battle.command_help_build(u)
				return
			var now := _now()
			if now - _last_tap_time < DOUBLE_TAP_TIME and _last_tap_uid == u.uid and not u.is_building():
				battle.select_same_type_on_screen(u)
				_last_tap_time = -10.0
			else:
				battle.select([u])
				_last_tap_time = now
				_last_tap_uid = u.uid
		else:
			if not battle._ids().is_empty():
				battle.command_attack(u)
				set_attack_mode(false)
			else:
				hud.show_enemy_info(u)
		return
	var res = battle.pick_resource(pos)
	if res != null:
		if not battle.selection_workers().is_empty():
			battle.command_gather(res)
			return
		if battle.selected_building() == null:
			hud.show_resource_info(res)
			if battle._ids().is_empty():
				return
	_command_at(pos)


func _command_at(pos: Vector2) -> void:
	var g = cam.ground_point(pos)
	if g == null or battle.selected.is_empty():
		return
	if battle.is_placing():
		battle.move_ghost(g)
		return
	var target = battle.pick_unit(pos)
	if target != null and target.team != 0:
		battle.command_attack(target)
	elif attack_mode:
		battle.command_attack_move(g)
	else:
		var res = battle.pick_resource(pos)
		if res != null and not battle.selection_workers().is_empty():
			battle.command_gather(res)
		else:
			battle.command_move(g)
	set_attack_mode(false)


func set_attack_mode(v: bool) -> void:
	attack_mode = v
	if hud:
		hud.refresh_modes()


func set_cast_mode(index: int) -> void:
	cast_index = index
	if hud:
		hud.refresh_modes()


func set_box_mode(v: bool) -> void:
	box_mode = v
	if hud:
		hud.refresh_modes()
